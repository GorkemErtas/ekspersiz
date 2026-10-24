"""Compare the completed RT-DETR alternative with the frozen RF-DETR experiment stage."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from .rtdetr_evaluate import evaluate_checkpoint
from .rtdetr_export import export
from .transfer_verify import verify
from .transfer_report import write_markdown
from .signatures import split_signature


def read(path):
    for attempt in range(5):
        try:
            return json.loads(path.read_text(encoding='utf-8'))
        except json.JSONDecodeError:
            if attempt==4:
                raise
            time.sleep(.1)


def write(path,value):
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def compact(result):
    return {k:v for k,v in result.items() if k not in ('predictions','calibration')}


def main(args):
    while read(args.run/'experiment.json')['status']=='started':
        if not args.wait:
            raise ValueError('Training is incomplete')
        time.sleep(30)
    experiment=read(args.run/'experiment.json')
    if experiment['status']!='completed':
        raise ValueError('Cannot finalize failed training')
    if args.output.exists() or args.models.exists():
        raise ValueError('Use new comparison and bundle directories')
    args.output.mkdir(parents=True)
    report=read(args.source)
    for split,expected in report['protocol']['split_sha256'].items():
        path=args.data/f'{split}.json'
        if (hashlib.sha256(path.read_bytes()).hexdigest()!=expected
                and split_signature(read(path))!=report['protocol'].get('portable_split_sha256',{}).get(split)):
            raise ValueError('Frozen comparison labels changed')
    checkpoint=args.run/'best'
    val_path=args.output/'rtdetr-r18-val.json'
    val=evaluate_checkpoint(checkpoint,args.data/'val.json',val_path)
    fixtures={name:Path(value['path']) for name,value in report['part_compatibility_review']['fixtures'].items()}
    export(checkpoint,args.part_checkpoint,args.run/'experiment.json',args.models,list(fixtures.values()),val['calibration']['selected']['threshold'])
    validation_error=None
    try:
        verify(args.models,args.data/'val.json',val_path,args.output/'rtdetr-r18-onnx-val.json')
    except ValueError as error:
        validation_error=str(error)
    row={'run':str(args.run),'checkpoint':str(checkpoint),'validation_file':str(val_path),
         'validation':compact(val),'calibration':val['calibration'],'bundle':str(args.models),
         'validation_accuracy_check_error':validation_error,'cpu':{}}
    report['candidates']['rtdetr-r18']=row
    # The GPU is idle now. Remeasure every model in isolated, two-thread CPU processes.
    for name,candidate in report['candidates'].items():
        candidate['cpu']={}
        for label,photo in fixtures.items():
            target=args.output/f'{name}-cpu-{label}.json'
            subprocess.run([str(args.runtime_python),'-m','ml.transfer_benchmark','--bundle',candidate['bundle'],
                            '--image',str(photo),'--output',str(target)],check=True)
            candidate['cpu'][label]=read(target)
    for label,photo in fixtures.items():
        target=args.output/f'baseline-cpu-{label}.json'
        subprocess.run([str(args.runtime_python),'-m','ml.benchmark','--bundle','models/hitl-416',
                        '--image',str(photo),'--output',str(target)],check=True)
        report['baseline']['cpu'][label]=read(target)
    envelope=report['protocol']['local_cpu_selection_envelope']
    eligible={name:candidate for name,candidate in report['candidates'].items()
              if not candidate.get('validation_accuracy_check_error')
              and all(m['photo_pipeline_ms_p95']<=envelope['maximum_photo_p95_ms']
                      and m['peak_process_mib']<=envelope['maximum_vision_process_mib'] for m in candidate['cpu'].values())}
    selected=max(eligible,key=lambda name:eligible[name]['validation']['damage']['mAP50_95'])
    report['previous_rf_stage_decision']=report['decision']
    report['decision']={'selected':selected,'basis':'Best validation bbox mAP50:95 among measured candidates within declared local CPU envelope',
                        'local_resource_eligible':list(eligible),'production_approved':False}
    report['additional_rtdetr_protocol']=read(Path('../docs/ml/TRANSFER_RTDETR_PROTOCOL.json'))
    report['additional_rtdetr_protocol']['source_result']=str(args.source)
    report['additional_rtdetr_protocol']['source_result_sha256']=hashlib.sha256(args.source.read_bytes()).hexdigest()
    write(args.output/'decision-before-test.json',report['decision'])
    test_path=args.output/'rtdetr-r18-test.json'
    result=evaluate_checkpoint(checkpoint,args.data/'test.json',test_path)
    row['test']=compact(result)
    try:
        verify(args.models,args.data/'test.json',test_path,args.output/'rtdetr-r18-onnx-test.json')
    except ValueError as error:
        row['accuracy_check_error']=str(error)
    row['onnx_test']=read(args.output/'rtdetr-r18-onnx-test.json')
    delta={key:abs(row['onnx_test']['part'][key]-report['baseline']['test']['part'][key])
           for key in ('mAP50_95','mAP50','precision','recall')}
    if any(value>=1e-4 for value in delta.values()):
        raise ValueError(f'Part regression in the RT-DETR candidate: {delta}')
    report['part_compatibility_review']['part_metric_differences']['rtdetr-r18']=delta
    external=evaluate_checkpoint(checkpoint,Path('evaluation-runs/syndcar-audit/external.json'),args.output/'rtdetr-r18-external.json')
    row['external_shared_classes']=compact(external)
    observed_best=max(report['candidates'],key=lambda name:report['candidates'][name]['onnx_test']['damage']['mAP50_95'])
    report['production_model_selected']=None
    report['historical_test_observation']={
        'highest_bbox_mAP50_95_candidate':observed_best,
        'not_used_for_pretest_selection':True,
        'validation_selection_won_historical_test':observed_best==selected,
        'note':'The validation-only research selection is retained for audit. No candidate qualifies for production; do not silently switch or promote using the historical test.'}
    chosen=report['candidates'][selected]['onnx_test']['api_quality_gated_operating_point']
    report['release_gate_failures']=[{'metric':key,'observed':chosen[key],'minimum':minimum}
                                    for key,minimum in (('precision',.8),('recall',.8),('mAP50_95',.4)) if chosen[key]<minimum]
    report['production_approved']=False
    report['deployment_performed']=False
    write(args.output/'results.json',report)
    write(Path('../docs/ml/TRANSFER_RESULTS.json'),report)
    write_markdown(report,Path('../docs/ml/TRANSFER_RESULTS.md'))
    print(json.dumps({'selected':selected,'rtdetr_val_mAP50_95':val['damage']['mAP50_95'],
                      'rtdetr_test_mAP50_95':row['onnx_test']['damage']['mAP50_95'],'production_approved':False}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',type=Path,default=Path('training-runs/rtdetr-r18-640'))
    parser.add_argument('--source',type=Path,default=Path('evaluation-runs/transfer-reviewed-v3/results.json'))
    parser.add_argument('--data',type=Path,default=Path('datasets/hitl-coco'))
    parser.add_argument('--output',type=Path,default=Path('evaluation-runs/transfer-rtdetr-final'))
    parser.add_argument('--models',type=Path,default=Path('models/transfer-rtdetr-final'))
    parser.add_argument('--runtime-python',type=Path,default=Path('venv/Scripts/python.exe'))
    parser.add_argument('--part-checkpoint',type=Path,default=Path('training-runs/hitl-tiny-416/best.pth'))
    parser.add_argument('--wait',action='store_true')
    main(parser.parse_args())
