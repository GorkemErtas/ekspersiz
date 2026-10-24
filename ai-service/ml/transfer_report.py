"""Readable report from measured comparison artifacts; no inference or fabricated values."""
from pathlib import Path


def write_markdown(report, output):
    selected = report['decision']['selected']
    candidates = report['candidates']
    chosen = candidates[selected]
    baseline = report['baseline']
    rt_stage = ('Ek RT-DETR R18 adayı çok ölçekli CNN, 640 giriş ve framework-native eğitim '
                'ayarları kullanır. Bu aşama RF-DETR test sonuçlarından sonra, ayrı protokolle '
                'eklenmiştir; checkpoint ve aday seçimi yalnızca validation üzerinden yapılır.'
                if 'rtdetr-r18' in candidates else '')
    ablation_note = ('Bu çalışmadaki INT8 ve parça kanıtına göre hasar eleme deneyleri validation '
                     'doğruluğunu düşürdüğü için seçilmedi. RT-DETR NMS taramasında da önceden '
                     'yazılan precision kazancı / recall kaybı koşulları sağlanmadı; native decoder '
                     'korundu (`TRANSFER_RTDETR_VALIDATION_DIAGNOSTICS.json`). '
                     if report.get('final_review') else '')
    entries = [('YOLOX-Tiny 416', baseline['test']['damage'], baseline['cpu'])]
    entries += [(name, row['onnx_test']['damage'], row['cpu']) for name, row in candidates.items()]
    lines = [
        '# Gerçek transfer öğrenme sonuçları', '',
        f'Validation ve yerel CPU koşullarıyla seçilen aday: **{selected}**. '
        '**Üretim için yeterli değil; aktivasyon ve deploy yapılmadı.**', '',
        '## Aynı tarihsel test üzerindeki hasar tespiti', '',
        '| Model | mAP50:95 | mAP50 | Precision | Recall | FP | CPU medyan | Tepe RAM |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]
    for name, metric, cpu in entries:
        medium = cpu['medium']
        lines.append(f'| {name} | {metric["mAP50_95"]:.2%} | {metric["mAP50"]:.2%} | '
                     f'{metric["precision"]:.2%} | {metric["recall"]:.2%} | {metric["false_positive"]} | '
                     f'{medium["photo_pipeline_ms_median"]:.1f} ms | {medium["peak_process_mib"]:.1f} MiB |')
    observed_best=max(candidates,key=lambda name:candidates[name]['onnx_test']['damage']['mAP50_95'])
    if observed_best!=selected:
        lines += ['', f'**Validation ön seçimi testte en yüksek mAP’yi korumadı.** '
                  f'Tarihsel testte en yüksek bbox mAP50:95 `{observed_best}` adayında ölçüldü. '
                  'Bu gözlem, test kullanılarak yeni bir üretim seçimi yapılmış gibi sunulmaz. '
                  'Hiçbir aday üretim için seçilmedi.']
    lines += [
        '', '81 hasar etiketli görüntü, 936 gerçek hasar kutusu. AP: COCO bbox IoU '
        '0.50:0.95, skor tabanı 0.001; P/R/FP: skor 0.25, IoU 0.5, sınıf uyumlu eşleştirme. '
        'Test görüntüleri veya etiketleriyle model/eşik seçilmedi. Bu daha önce görülmüş '
        'tarihsel karşılaştırma setidir; yeni ve kör bir üretim kabul seti değildir.', '',
        'Baseline kendi validation sonucuna göre 416 girişle tutuldu: validation hasar '
        'mAP50:95 416 için 0.02267, 640 için 0.01888. Eski farklı sınıfları birlikte '
        'eşleştiren P/R hatası ortak evaluator ile düzeltildi; bu düzeltme COCO mAP’yi '
        'değiştirmez. Tablodaki iç test sonuçları baseline dahil gerçek ONNX CPU '
        'çıktılarındandır. Tarihsel Torch çıktıları JSON’da ayrı tutulur; export sayısal '
        'farkları metrik düzeltmesi veya model kazanımı sayılmaz.', '',
        '## Validation ile seçilen çalışma noktası', '',
        '| Model | Eşik | Validation precision koşulu | Test precision | Test recall | TP | FP |',
        '| --- | ---: | --- | ---: | ---: | ---: | ---: |',
    ]
    for name, row in candidates.items():
        calibration = row['calibration']
        metric = row['onnx_test']['api_quality_gated_operating_point']
        lines.append(f'| {name} | {calibration["selected"]["threshold"]:.3f} | '
                     f'{"sağlandı" if calibration["constraint_satisfied"] else "sağlanamadı"} | '
                     f'{metric["precision"]:.2%} | {metric["recall"]:.2%} | '
                     f'{metric["true_positive"]} | {metric["false_positive"]} |')
    lines += [
        '', 'Precision koşulu tek başına yeterli değildir. Nano 512’nin yüksek eşikteki '
        'precision değeri çok az tahmine dayanır; recall çok düşüktür. Üstteki eşit '
        '0.25 eşik karşılaştırması bu çalışma noktasıyla karıştırılmamalıdır. '
        'Hiçbir aday gerekli precision ve recall’u birlikte sağlamaz.', '',
        '## CPU ve RAM', '',
        '| Model | Fotoğraf | Medyan | p95 | Tepe RAM |',
        '| --- | --- | ---: | ---: | ---: |',
    ]
    for name, _, cpu in entries:
        for label, metric in cpu.items():
            lines.append(f'| {name} | {label} | {metric["photo_pipeline_ms_median"]:.1f} ms | '
                         f'{metric["photo_pipeline_ms_p95"]:.1f} ms | {metric["peak_process_mib"]:.1f} MiB |')
    lines += [
        '', 'Ayrı Torch içermeyen süreçler, iki ONNX inference thread’i, fotoğraf başına '
        'iki ısınma ve 20 ölçüm; her modelin validation ile seçilen bundle eşiği kullanılır. '
        'Decode, kalite kontrolü, ön işleme, iki görevin forward '
        'işlemleri, kutu çözümü/NMS ve parça eşleştirmesi dahildir. `medium`: 637×419 HITL '
        'PNG; `camera`: 8 MP SYNDCAR fotoğrafından JPEG; `large`: 4032×3024 türetilmiş '
        '12 MP JPEG. Son ikisi eşit kaynak tüketimi için kullanılır; bağımsız hasar vakası '
        'sayılmaz. JVM, E5/RAG, ağ ve Gemini dahil değildir. Gerçek Railway kotası veya '
        'yük testi yapılmadı.', '',
        '## Validation adayının sınıf sonuçları', '',
        '| Sınıf | Test desteği | mAP50:95 | Precision | Recall | FP | FN |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]
    for name, metric in chosen['onnx_test']['damage']['per_class'].items():
        lines.append(f'| {name} | {metric["annotations"]} | {metric["mAP50_95"]:.2%} | '
                     f'{metric["precision"]:.2%} | {metric["recall"]:.2%} | '
                     f'{metric["false_positive"]} | {metric["false_negative"]} |')
    lines += ['', '## Detection ve segmentation', '']
    for name, row in candidates.items():
        segmentation = row['test'].get('segmentation')
        if segmentation:
            lines.append(f'`{name}` gerçek maske eğitimi/testi: mask mAP50:95 '
                         f'**{segmentation["mAP50_95"]:.2%}**, mask mAP50 '
                         f'**{segmentation["mAP50"]:.2%}**. Aynı bbox API’sine aktarımda '
                         'mask head dışarıda bırakıldı; maskeler API’ye yeni alan olarak eklenmedi.')
    lines += [
        '', 'Nano 384/512, öğrenme oranı ve çözünürlük bakımından; Seg Nano ayrıca '
        'mimari ve bbox/mask uyumlu crop bakımından farklıdır. Sonuçlar tek bir '
        'değişkenin nedensel etkisi veya bütün modeller arasında optimum diye sunulmaz. '
        + rt_stage, '',
        '## Ayrı kaynak: SYNDCAR v1', '',
        '| Model | İki sınıf mAP50:95 | mAP50 | Precision | Recall | FP |',
        '| --- | ---: | ---: | ---: | ---: | ---: |',
    ]
    external = [('YOLOX-Tiny 416', baseline['external_shared_classes'])]
    external += [(name, row['external_shared_classes']['damage']) for name, row in candidates.items()]
    for name, metric in external:
        lines.append(f'| {name} | {metric["mAP50_95"]:.2%} | {metric["mAP50"]:.2%} | '
                     f'{metric["precision"]:.2%} | {metric["recall"]:.2%} | {metric["false_positive"]} |')
    lines += [
        '', 'CC BY 4.0 kaynak; eğitimde kullanılmayan 245 görüntü ve 673 ortak '
        '`Cracked`/`Scratch` kutusu. Diğer kaynak sınıfları ve bunlara ilişkin tahminler '
        'ortak sınıf skoruna girmez. Aynı küçük araç/sentetik hasarın çok sayıda yakın '
        'görünümü vardır; 245 bağımsız gerçek olay veya temiz negatif seti değildir. '
        'Alan farkındaki düşük sonuçlar üretim genellemesi iddiasını desteklemez.', '',
        '## Uyumluluk ve yayın kararı', '',
    ]
    parity = all(row['onnx_test']['accuracy_parity_passed'] for row in candidates.values())
    lines.append(f'Tüm adayların aynı testte ONNX/PyTorch metrik farkı kontrolü: '
                 f'**{"geçti" if parity else "başarısız aday var"}**. '
                 'mAP50, mAP50:95, precision ve recall için mutlak tolerans 0.0001. '
                 '512 modelinin 12 MP kontrolünde düşük skorlu proposal satırları ham tensor '
                 'allclose kontrolünü geçmedi; API tespit kümesi eşleşti. Bu sınır '
                 '`TRANSFER_EXPORT_DIAGNOSTICS.json` içinde açıkça kaydedildi.')
    if report.get('part_compatibility_review'):
        lines += ['', 'Parça modeli, katalog, 416 ön işleme, confidence 0.25 ve baseline NMS '
                  '0.45 korundu. İlk export’taki NMS 0.50 farkı incelemede düzeltildi; yeni '
                  'bundle dizinleri oluşturularak üç tam test parity kontrolü ve tüm CPU '
                  'ölçümleri tekrarlandı. Parça P/R ve mAP farkı baseline’a karşı 0.0001 '
                  'sınırının altında doğrulandı. Hasar ağırlığı, seçimi ve postprocess’i değişmedi.']
    lines += [
        '', ablation_note+'Validation eşik aramasında istenen precision 0.70 '
        'koşulu sağlanamadığında başarısızlık açıkça kaydedildi. Doğrulanmış temiz negatif '
        'veri olmadığı için gerçek hasarsız fotoğraf yanlış alarm oranı ölçülemedi.', '',
        'Üretim için eksikler: yeterli nadir sınıf örneği, uzman semantik etiket incelemesi, '
        'izinli temiz/araç dışı negatifler, yeni araç/çekim oturumu ayrılmış kör saha holdout’u, '
        'hasar-parça ilişki doğruluğu ve gerçek Railway kaynak/yük ölçümü. Mevcut P/R/mAP '
        'değerleri önceden yazılan yayın koşullarını birlikte sağlamaz. Analiz bayrakları ve '
        'bütün model onayları kapalıdır; geçmiş, rapor, asistan/RAG ve kredi sözleşmeleri korunur.', '',
        'Ayrıntılar: [ölçümler](TRANSFER_RESULTS.json), '
        '[gerçek eğitim kayıtları ve başarısız denemeler](TRANSFER_TRAINING_RUNS.json), '
        '[yöntem ve tekrarlama](TRANSFER_LEARNING.md), '
        '[veri incelemesi](TRANSFER_DATA_AUDIT.json), [ayrımlar arası görsel benzerlik](TRANSFER_SPLIT_SIMILARITY.json), '
        '[ayrı veri/framework/ağırlık lisansları](COMMERCIAL_LICENSE_REVIEW.md), '
        '[test doğrulaması](TRANSFER_VALIDATION.json).', '',
    ]
    Path(output).write_text('\n'.join(lines), encoding='utf-8')
