"""Publish compact dataset evidence; no raw images, labels, or masks are modified."""
from collections import Counter, defaultdict
import hashlib
import importlib.metadata as metadata
import json
from pathlib import Path

from PIL import Image


def main():
    root=Path(__file__).resolve().parents[2]
    raw=root/'ai-service/datasets/raw'
    prepared=root/'ai-service/datasets/hitl-coco'
    counts=Counter();images=defaultdict(set);masks=Counter();shapes=Counter();human_labelers=Counter()
    original_class_ids=defaultdict(set)
    fingerprint=hashlib.sha256()
    for source in sorted(raw.iterdir()):
        for category in json.loads((source/'meta.json').read_text(encoding='utf-8'))['classes']:
            original_class_ids[category['title']].add(category['id'])
        for path in sorted(source.glob('**/ann/*.json')):
            content=path.read_bytes()
            fingerprint.update(str(path.relative_to(raw)).encode()+hashlib.sha256(content).digest())
            ann=json.loads(content)
            for obj in ann['objects']:
                name=obj['classTitle'];counts[name]+=1;images[name].add(str(path))
                human_labelers[obj.get('labelerLogin','MISSING')]+=1
                shapes[obj.get('geometryType','MISSING')]+=1
        for path in sorted(source.glob('**/img/*')):
            fingerprint.update(str(path.relative_to(raw)).encode()+hashlib.sha256(path.read_bytes()).digest())
        for kind in ('masks_human','masks_machine'):
            for path in source.glob(f'**/{kind}/*'):
                with Image.open(path) as image:
                    image.verify()
                masks[kind]+=1
    audit=json.loads((prepared/'audit.json').read_text(encoding='utf-8'))
    catalog=json.loads((prepared/'classes.json').read_text(encoding='utf-8'))
    report={**audit,'raw_class_counts':{c['name']:{'task':c['task'],'images':len(images[c['name']]),
            'annotations':counts[c['name']], 'source_class_ids':sorted(original_class_ids[c['name']])} for c in catalog['categories']},
        'raw_annotations':sum(counts.values()),'geometry_types':dict(shapes),'mask_files_verified':dict(masks),
        'annotation_provenance':{'human_attributed_objects':sum(v for k,v in human_labelers.items() if k!='MISSING'),
            'missing_labeler_objects':human_labelers['MISSING'],
            'note':'Publisher describes human annotation. Directory name masks_machine alone does not prove machine-generated annotations.'},
        'raw_image_annotation_fingerprint':fingerprint.hexdigest(),
        'dataset_license':{'spdx':'CC0-1.0','verified_date':'2026-10-24',
            'source':'https://humansintheloop.org/resources/datasets/car-parts-and-car-damages-dataset/'}}
    report.pop('source_root',None)
    out=root/'docs/ml';out.mkdir(parents=True,exist_ok=True)
    (out/'HITL_DATASET_AUDIT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    headers=['| Görev | Orijinal sınıf | Görüntü | Anotasyon | Kullanılabilir anotasyon |','| --- | --- | ---: | ---: | ---: |']
    for c in catalog['categories']:
        name=c['name'];r=report['raw_class_counts'][name]
        headers.append(f'| {c["task"]} | {name} | {r["images"]} | {r["annotations"]} | {report["class_counts"][name]["annotations"]} |')
    (out/'HITL_CLASS_COUNTS.md').write_text('# HITL gerçek sınıf sayıları\n\n'+ '\n'.join(headers)+'\n',encoding='utf-8')
    packages={}
    for name in ('torch','numpy','pillow','onnx','onnxruntime','pycocotools','protobuf','ml_dtypes','flatbuffers','python-multipart'):
        info=metadata.metadata(name)
        packages[name]={'version':metadata.version(name),'license_expression':info.get('License-Expression'),
            'license':info.get('License'),'homepage':info.get('Home-page'),
            'license_files':[str(p) for p in metadata.files(name) or [] if 'license' in str(p).lower() or 'notice' in str(p).lower()]}
    (out/'ML_DEPENDENCY_LICENSES.json').write_text(json.dumps(packages,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'source_images':report['source_images'],'raw_annotations':sum(counts.values()),
        'usable_images':report['images'],'usable_annotations':report['annotations'],
        'paired_images':report['paired_task_images'],'fingerprint':fingerprint.hexdigest()}))


if __name__=='__main__':
    main()
