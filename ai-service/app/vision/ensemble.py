"""Bounded ONNX-only inference for independently trained damage and part models."""
from .processing import preprocess, postprocess
from .rfdetr_processing import preprocess_rfdetr, postprocess_rfdetr
from .rtdetr_processing import preprocess_rtdetr


class EnsembleBackend:
    def __init__(self, bundle, manifest, categories):
        self.family = manifest.get('damage_family','rfdetr')
        if self.family not in ('rfdetr','rtdetr'):
            raise ValueError('Unsupported damage architecture')
        import onnxruntime as ort
        options = ort.SessionOptions()
        options.intra_op_num_threads = 2
        options.inter_op_num_threads = 1
        self.damage = ort.InferenceSession(str(bundle/'damage.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
        self.part = ort.InferenceSession(str(bundle/'part.onnx'), sess_options=options, providers=['CPUExecutionProvider'])
        for session, task in ((self.damage, 'damage'), (self.part, 'part')):
            inputs = session.get_inputs()
            if len(inputs) != 1 or inputs[0].name != 'images' or inputs[0].type != 'tensor(float)' or inputs[0].shape != [1, 3, manifest['input_sizes'][task], manifest['input_sizes'][task]]:
                raise ValueError('Ensemble input signature mismatch')
        damage_outputs = self.damage.get_outputs()
        queries = manifest['num_queries']
        classes = 8 if self.family == 'rtdetr' else 9
        if [o.name for o in damage_outputs] != ['boxes', 'logits'] or damage_outputs[0].shape != [1, queries, 4] or damage_outputs[1].shape != [1, queries, classes]:
            raise ValueError('DETR output signature mismatch')
        outputs = self.part.get_outputs()
        if len(outputs) != 1 or outputs[0].name != 'part' or outputs[0].shape[-1] != 26:
            raise ValueError('Part output signature mismatch')
        self.manifest, self.categories = manifest, categories

    def detect(self, image, threshold=None, part_threshold=None):
        manifest = self.manifest
        damage_input = (preprocess_rtdetr(image,manifest['input_sizes']['damage']) if self.family == 'rtdetr' else
                        preprocess_rfdetr(image, manifest['input_sizes']['damage'],
                                          manifest['damage_preprocessing'] == 'RGB-square-PIL-bilinear-ImageNet-v1'))
        boxes, logits = self.damage.run(['boxes', 'logits'], {'images': damage_input[None]})
        damage = postprocess_rfdetr(boxes, logits, self.categories['damage'], image.width, image.height,
                                   manifest['threshold'] if threshold is None else threshold, manifest['num_select'],
                                   background_class=self.family != 'rtdetr')
        for detection in damage:
            detection.pop('_query')
        # Sequential forwards keep peak CPU workspaces bounded.
        part_input, ratio = preprocess(image, manifest['input_sizes']['part'])
        raw = self.part.run(['part'], {'images': part_input[None]})[0]
        parts = postprocess(raw, self.categories['part'], ratio, image.width, image.height,
                            manifest['part_threshold'] if part_threshold is None else part_threshold, manifest['nms_threshold'])
        return damage, parts
