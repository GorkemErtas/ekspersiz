"""Make the reviewer report from measured artifacts; never supplies substitute metrics."""
import json
from pathlib import Path


def main():
    root=Path(__file__).resolve().parents[2]
    directory=root/'docs/ml'
    path=directory/'HITL_RESULTS.json'
    result=json.loads(path.read_text(encoding='utf-8'))
    log=root/'ai-service/training-runs/hitl-tiny-416/training.jsonl'
    training=[json.loads(line) for line in log.read_text().splitlines()]
    result['training'].update({'completed_epochs':max(r['epoch'] for r in training)+1,
        'logged_epoch_seconds':sum(r['seconds'] for r in training),
        'peak_cuda_mib':max(r['cuda_peak_mib'] for r in training),
        'gpu':'NVIDIA GeForce RTX 4050 Laptop GPU',
        'interruption_note':'After epoch 0, evaluation rejected exp-overflow output. Identical train/inference extent bounds were added and training resumed from the last valid checkpoint. No invalid checkpoint was promoted.'})
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    r=result;lines=['# HITL / YOLOX-Tiny gerçek sonuçlar — 24 Ekim 2026','',
        '**Karar: Üretim için onaylanmadı; hasar analizi kapalı kalır.** Parça tespiti öğrenilmiş olsa da hasar recall değeri yetersizdir. Düşük maliyetli çıkarım, doğruluk eksiğini gidermez.','',
        '## Veri ve eğitim','',
        'Ham veri 1.812 görüntü / 24.851 poligondur. Bir geçersiz görüntü bütünüyle dışlandı; 441 piksel eşinin tamamlayıcı etiketleri birleştirildi. Kullanılabilir 1.370 görüntü / 24.819 poligon; split 1.095 / 137 / 138. Ham dosyalar değişmedi. [Sınıf başına sayılar](HITL_CLASS_COUNTS.md), [tam veri denetimi](HITL_DATASET_AUDIT.json).','',
        f"Tek Tiny omurga + 8/21 sınıflı iki head, **{r['training']['parameters']:,} parametre**. Hazır ağırlık kullanılmadı. 50 epoch tamamlandı; validation ortalama iki görev mAP50:95 ölçütüyle **{r['training']['selected_epoch']+1}. epoch** checkpoint'i seçildi. Test kümesi seçimden sonra bir kez değerlendirildi; ONNX doğrulaması aynı dondurulmuş testin yeniden çalıştırılmasıdır.", '',
        f"Donanım: RTX 4050 Laptop GPU. Loglanan başarılı epoch süreleri toplamı {r['training']['logged_epoch_seconds']/60:.1f} dakika; tepe CUDA tahsisi {r['training']['peak_cuda_mib']:.1f} MiB. İlk değerlendirmedeki sayısal taşma fail-closed davranışıyla durdu; eğitim/çıkarım boyut sınırı düzeltilip son geçerli checkpoint'ten devam edildi. İlk küçük alt küme smoke'u doğruluk kanıtı sayılmadı.", '',
        '## Bağımsız test — seçilen 416 girişi','',
        '| Görev | mAP50 | mAP50:95 | Precision | Recall | F1 |',
        '| --- | ---: | ---: | ---: | ---: | ---: |']
    for task in ('damage','part'):
        m=r['independent_test']['tasks'][task]
        lines.append('| '+task+' | '+' | '.join(f'{m[k]*100:.2f}%' for k in ('mAP50','mAP50_95','precision','recall','f1'))+' |')
    lines+=['','Precision/recall/F1 çalışma noktası confidence 0.25, IoU 0.5’tir. Sınıf AP, FP/FN ve confusion matrix [JSON sonuçlarında](HITL_RESULTS.json) bulunur. Etiketsiz görevler negatif sayılmaz. Hasar→parça ilişki doğruluğu için insan etiketli ilişki verisi yoktur; ölçülmüş başarı iddia edilmez.','',
        '## Çözünürlük karşılaştırması — validation','',
        '| Giriş | Hasar mAP50:95 | Parça mAP50:95 |','| --- | ---: | ---: |']
    for size in ('416','640'):
        tasks=r['validation'][size]['tasks']
        lines.append(f"| {size} | {tasks['damage']['mAP50_95']*100:.2f}% | {tasks['part']['mAP50_95']*100:.2f}% |")
    lines+=['','İki giriş aynı 416’da eğitilmiş checkpoint ile karşılaştırıldı; ayrı 640 eğitimi yapılmadı. 416 validation ile seçildi. 640’ın bu koşuda daha kötü olması, yeniden eğitilmiş yüksek çözünürlüğün yararsız olduğu anlamına gelmez.','',
        '## Ayrı CPU ONNX süreci — iki thread','',
        '| Giriş | Session yükleme | Tek fotoğraf medyanı | p95 | Süreç tepe RAM |','| --- | ---: | ---: | ---: | ---: |']
    for size in ('416','640'):
        m=r['onnx'][size]['runtime']
        lines.append(f"| {size} | {m['session_load_ms']:.1f} ms | {m['photo_pipeline_ms_median']:.1f} ms | {m['photo_pipeline_ms_p95']:.1f} ms | {m['peak_process_mib']:.1f} MiB |")
    m=r['large_photo_cpu']
    lines+=['',f"4032×3024 türetilmiş fotoğraf, 416 giriş: medyan {m['photo_pipeline_ms_median']:.1f} ms, p95 {m['photo_pipeline_ms_p95']:.1f} ms, tepe süreç belleği {m['peak_process_mib']:.1f} MiB.", '',
        'Süreler decode, ışık/netlik, letterbox, iki head forward, NMS ve parça eşleştirmesini içerir. Fotoğraf yükleme, ağ, JVM, Gemini ve E5/RAG belleği kapsam dışıdır. Bunlar yerel CPU ölçümleridir; Railway ölçümü veya fatura tasarrufu iddiası değildir. İzole vision sürecine PyTorch import edilmedi. PyTorch, asistan için üretim imajında korunur.','',
        'Her iki çözünürlükte iki head’in tüm çıktıları ONNX/PyTorch karşılaştırmasından geçti. Dondurulmuş test kümesinin ONNX metrik farkları [ayrı parity raporunda](HITL_ONNX_ACCURACY.json); mAP mutlak farkı her iki görevde 0.0001 altında kaldı. Bu sonuç temel modelin düşük hasar başarısını düzeltmez.','',
        '## Full-stack ve regresyon','',
        '- Python: sürümlü şema, tek fotoğraf, ONNX lazy yükleme, hash/imza kapısı, sınırlı eşzamanlılık, gerçek confidence ve INCONCLUSIVE davranışı.','- Java: eklemeli enum ve V17; ham kanıt/model sürümü saklama; null değişim kararı; mevcut ve yeni kayıt uyumluluğu; eşleştirme/çıktı doğrulaması.','- Flutter/PDF: 29 gerçek sınıfın Türkçe etiketleri, eski değerlerin gösterimi, belirsiz şiddet/değişim ve fiziksel inceleme fiyat başlığı.','- Gemini/asistan: kaynak sınıfları ve belirsizlik aktarılır; kesin olmayan onarım/değişim veya hasarsızlık uydurulmaz. Mevcut fiyat/web ve yetki akışı korunur.','',
        'Test sayıları ve yürütme sınırları `HITL_VALIDATION.json` kaydında tutulur. Docker daemon kapalı olduğu için build/run doğrulaması yapılamadı. Canlı ödeme, Gemini/Places, gerçek pgvector/RAG sorgusu ve fiziksel cihaz uçtan uca akışı çalıştırılmadı.','',
        '## Üretimden önce','',
        'Hasar performansı iyileştirilmeden ve bağımsız olarak doğrulanmadan aktivasyon yapılmamalıdır. Sonraki deneyler için doğrulanmış lisanslı transfer kaynağı veya daha uzun/hedefli sıfırdan eğitim, bağımsız yüksek çözünürlüklü eğitim, küçük nesne ve sınıf dengesinin incelenmesi, temiz/araç olmayan negatifler, görevler arası ilişki etiketleri ve eşik kalibrasyonu gereklidir. Mevcut test seti bu sonraki deneyleri seçmek için kullanılmamalıdır; yeni nihai doğrulama kümesi gerekir.','',
        'Model bundle’ları `production_approved: false`; Java, Python ve Flutter varsayılan kapalıdır. Canlı deploy, aktivasyon, branch, commit veya push yapılmadı.','']
    (directory/'HITL_RESULTS.md').write_text('\n'.join(lines),encoding='utf-8')


if __name__=='__main__':
    main()
