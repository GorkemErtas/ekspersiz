"""Isolated CPU vision benchmark: no PyTorch import and no production activation."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np
from PIL import Image
from app.vision.processing import decode_image, quality, preprocess, postprocess, match_parts


def peak_memory_mib():
    if sys.platform=='win32':
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_=[('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)]+[
                (n,ctypes.c_size_t) for n in ('PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage',
                    'QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage')]
        counters=Counters();counters.cb=ctypes.sizeof(counters)
        ctypes.windll.kernel32.GetCurrentProcess.restype=wintypes.HANDLE
        process=ctypes.windll.kernel32.GetCurrentProcess()
        get_info=ctypes.windll.psapi.GetProcessMemoryInfo
        get_info.argtypes=[wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD]
        if not get_info(process,ctypes.byref(counters),counters.cb):
            raise OSError('Cannot measure native peak working set')
        return counters.PeakWorkingSetSize/1024**2
    import resource
    value=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return value/(1024**2 if sys.platform=='darwin' else 1024)


def main():
    import onnxruntime as ort
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True)
    p.add_argument('--image',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--repeats',type=int,default=20)
    a=p.parse_args()
    manifest=json.loads((a.bundle/'manifest.json').read_text())
    catalog=json.loads((a.bundle/'classes.json').read_text(encoding='utf-8'))
    categories={t:sorted([c for c in catalog['categories'] if c['task']==t],key=lambda c:c['task_index']) for t in ('damage','part')}
    if hashlib.sha256((a.bundle/'model.onnx').read_bytes()).hexdigest()!=manifest['model_sha256']:
        raise ValueError('Model hash mismatch')
    opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
    start=time.perf_counter();session=ort.InferenceSession(str(a.bundle/'model.onnx'),sess_options=opts,providers=['CPUExecutionProvider'])
    load_ms=(time.perf_counter()-start)*1000
    image_bytes=a.image.read_bytes()
    forward=[];total=[]
    for i in range(a.repeats+2):
        begin=time.perf_counter();image=decode_image(image_bytes)
        quality_result=quality(image)
        pixels,ratio=preprocess(image,manifest['input_size'])
        before=time.perf_counter();outputs=session.run(['damage','part'],{'images':pixels[None]})
        after=time.perf_counter()
        detections={t:postprocess(output,categories[t],ratio,image.width,image.height,manifest['threshold'],manifest['nms_threshold'])
                    for t,output in zip(('damage','part'),outputs)}
        for damage in detections['damage']:
            match_parts(damage,detections['part'])
        if i>=2:
            forward.append((after-before)*1000);total.append((time.perf_counter()-begin)*1000)
        detected_counts={t:len(d) for t,d in detections.items()}
        del image,pixels,outputs,detections
    report={'input_size':manifest['input_size'],'providers':session.get_providers(),'threads':2,
        'session_load_ms':load_ms,'forward_ms_median':float(np.median(forward)),
        'photo_pipeline_ms_median':float(np.median(total)),'photo_pipeline_ms_p95':float(np.percentile(total,95)),
        'peak_process_mib':peak_memory_mib(),'torch_imported': 'torch' in sys.modules,
        'detections':detected_counts,'repeats':a.repeats,'photometric_suitable':quality_result['suitable'],
        'photo_pipeline_includes':['decode','photometric_quality','letterbox','two_head_forward','nms','part_matching'],
        'note':'Local CPU process; excludes Assistant/E5 memory, network, image upload, JVM and Gemini.'}
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))


if __name__=='__main__':
    main()
