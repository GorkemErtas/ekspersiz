from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from threading import Lock

import numpy as np

from .processing import decode_image, preprocess, postprocess, quality, match_parts


class VisionUnavailable(RuntimeError):
    pass


class UnifiedVisionRuntime:
    """Only ONNX Runtime is imported for vision; training code is never imported."""
    def __init__(self):
        self._lock=Lock()
        self._config_lock=Lock()
        self._inference_lock=Lock()
        self._session=None
        self._config_cache=None
        self._loaded_signature=None

    def _configuration(self):
        with self._config_lock:
            return self._read_configuration()

    def _read_configuration(self):
        if os.getenv('DAMAGE_ANALYSIS_ENABLED','false').lower()!='true':
            raise VisionUnavailable('Hasar analizi geçici olarak kullanılamıyor.')
        bundle=Path(os.environ.get('DAMAGE_MODEL_BUNDLE','models/unified'))
        try:
            manifest=json.loads((bundle/'manifest.json').read_text(encoding='utf-8'))
            ensemble=manifest.get('format')=='ensemble-v1'
            if manifest.get('format') not in (None, 'ensemble-v1'):
                raise ValueError('Unsupported bundle format')
            model_files=('damage.onnx','part.onnx') if ensemble else ('model.onnx',)
            signature=(str(bundle.resolve()),tuple((p.stat().st_size,p.stat().st_mtime_ns)
                for p in (bundle/'manifest.json',bundle/'classes.json',*(bundle/f for f in model_files))))
            if self._loaded_signature is not None and signature != self._loaded_signature:
                raise ValueError('Bundle changed; restart the service to load a new immutable bundle')
            if self._config_cache is not None and self._config_cache[0]==signature:
                return self._config_cache[1:]
            if manifest['schema_version']!='hitl-v1' or manifest.get('production_approved') is not True:
                raise ValueError('Model has not passed the release gate')
            if manifest.get('export_smoke_only') is True:
                raise ValueError('An export smoke fixture cannot be activated')
            if ensemble:
                if manifest['input_sizes'] not in ({'damage':384,'part':416}, {'damage':512,'part':416}, {'damage':640,'part':416}):
                    raise ValueError('Unsupported ensemble sizes')
                if manifest['outputs']!=['boxes','logits','part'] or manifest['num_queries'] not in (100,300) or manifest['num_select']!=manifest['num_queries']:
                    raise ValueError('Unsupported ensemble outputs')
                family=manifest.get('damage_family','rfdetr')
                profiles={'rfdetr':('RGB-square-bilinear-no-antialias-ImageNet-v1','RGB-square-PIL-bilinear-ImageNet-v1'),
                          'rtdetr':('RGB-square-PIL-bilinear-rescale01-v1',)}
                if family not in profiles or manifest['damage_preprocessing'] not in profiles[family] or manifest['part_preprocessing']!='BGR-letterbox-114-v1':
                    raise ValueError('Unsupported ensemble preprocessing')
                if family=='rtdetr' and (manifest['input_sizes']['damage']!=640 or manifest['num_queries']!=300):
                    raise ValueError('Unsupported RT-DETR signature')
                if not .25 <= manifest['threshold'] <= 1 or not .25 <= manifest['part_threshold'] <= 1:
                    raise ValueError('Invalid ensemble threshold')
            elif manifest['input_size'] not in (416,640) or manifest['outputs']!=['damage','part'] or manifest.get('input_color')!='BGR':
                raise ValueError('Unsupported model signature')
            if not (ensemble or .25 <= manifest['threshold'] <= 1) or not 0 < manifest['nms_threshold'] < 1:
                raise ValueError('Invalid confidence/NMS threshold')
            checks=(('damage.onnx','damage_sha256'),('part.onnx','part_sha256')) if ensemble else (('model.onnx','model_sha256'),)
            for filename,key in (*checks,('classes.json','catalog_sha256')):
                if hashlib.sha256((bundle/filename).read_bytes()).hexdigest()!=manifest[key]:
                    raise ValueError('Model/catalog checksum mismatch')
            self._config_cache=(signature,bundle,manifest)
            return bundle,manifest
        except (OSError,ValueError,KeyError,TypeError) as exc:
            raise VisionUnavailable('Doğrulanmış hasar modeli hazır değil.') from exc

    def require_available(self):
        self._configuration()
        self._load()

    def status(self):
        try:
            self._configuration()
            return 'READY' if self._session is not None else 'NOT_LOADED'
        except VisionUnavailable:
            return 'UNAVAILABLE'

    def _load(self):
        if self._session is None:
            with self._lock:
                if self._session is None:
                    bundle,self.manifest=self._configuration()
                    catalog=json.loads((bundle/'classes.json').read_text(encoding='utf-8'))
                    expected=json.loads(Path(__file__).with_name('classes.json').read_text(encoding='utf-8'))
                    if catalog != expected:
                        raise VisionUnavailable('Model sınıf kataloğu uygulamayla uyuşmuyor.')
                    self.categories={t:sorted([c for c in catalog['categories'] if c['task']==t],key=lambda c:c['task_index']) for t in ('damage','part')}
                    if tuple(map(len,(self.categories['damage'],self.categories['part'])))!=(8,21):
                        raise VisionUnavailable('Model sınıf sözleşmesi geçersiz.')
                    if self.manifest.get('format')=='ensemble-v1':
                        from .ensemble import EnsembleBackend
                        try:
                            session=EnsembleBackend(bundle,self.manifest,self.categories)
                        except Exception as exc:
                            raise VisionUnavailable('Model ensemble imzası geçersiz.') from exc
                        self._session=session
                        self._loaded_signature=self._config_cache[0]
                        return session
                    import onnxruntime as ort
                    options=ort.SessionOptions()
                    options.intra_op_num_threads=2;options.inter_op_num_threads=1
                    session=ort.InferenceSession(str(bundle/'model.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
                    if [o.name for o in session.get_outputs()]!=['damage','part']:
                        raise VisionUnavailable('Model çıktı sözleşmesi geçersiz.')
                    inputs=session.get_inputs()
                    if len(inputs)!=1 or inputs[0].name!='images' or inputs[0].type!='tensor(float)' or inputs[0].shape!=[1,3,self.manifest['input_size'],self.manifest['input_size']]:
                        raise VisionUnavailable('Model giriş imzası geçersiz.')
                    if [o.shape[-1] for o in session.get_outputs()]!=[13,26]:
                        raise VisionUnavailable('Model head sınıf sayısı geçersiz.')
                    self._session=session
                    self._loaded_signature=self._config_cache[0]
        return self._session

    def validate(self,content):
        self.require_available()
        return quality(decode_image(content))

    def analyze(self,content,vehicle_region=None):
        self.require_available()
        image=decode_image(content)
        if not quality(image)['suitable']:
            raise ValueError('Daha net ve yeterli ışıkta bir fotoğraf kullanın.')
        with self._inference_lock:
            session=self._load()
            if self.manifest.get('format')=='ensemble-v1':
                damage,parts=session.detect(image)
            else:
                pixels,ratio=preprocess(image,self.manifest['input_size'])
                outputs=session.run(['damage','part'],{'images':pixels[None]})
                damage,parts=(postprocess(p,c,ratio,image.width,image.height,self.manifest['threshold'],self.manifest['nms_threshold'])
                              for p,c in zip(outputs,(self.categories['damage'],self.categories['part'])))
        recommendations=[]
        for detection in damage:
            matches=match_parts(detection,parts,vehicle_region)
            detection['affectedPart']=matches[0] if len(matches)==1 else 'UNKNOWN'
            recommendations.append({'damageType':detection['code'],'recommendedAction':'PROFESSIONAL_INSPECTION',
                'partReplacementRequired':None,'affectedParts':matches})
        # FRONT/REAR is contextual input only; it cannot rename a detected class.
        return {'schemaVersion':'hitl-v1','modelVersion':self.manifest['model_version'],
            'analysisOutcome':'DAMAGE_DETECTED' if damage else 'INCONCLUSIVE',
            'imageWidth':image.width,'imageHeight':image.height,
            'damageSeverity':'UNKNOWN','confidenceScore':max((d['confidence'] for d in damage),default=None),
            'damageTypes':list(dict.fromkeys(d['code'] for d in damage)),
            'affectedParts':list(dict.fromkeys(p for r in recommendations for p in r['affectedParts'])),
            'detections':damage,'partDetections':parts,'repairRecommendations':recommendations,
            'analysisMessage':('Görsel hasar bulguları saptandı. Derinlik, şiddet ve kesin onarım yöntemi fotoğraftan doğrulanamaz; fiziksel inceleme gerekir.'
                if damage else 'Güvenilir bir hasar bulgusu belirlenemedi. Bu sonuç hasarsızlık anlamına gelmez; farklı bir fotoğraf veya fiziksel inceleme gerekir.')}
