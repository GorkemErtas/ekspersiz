"""Artifacts for the frozen paired experiment; no threshold/model selection."""
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from experiments.damage_comparison import COMMON, NAMES, common_objects


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write(path, obj):
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False, allow_nan=False), encoding='utf-8')


def percentage(x):
    return 'N/A' if x is None else f'{100*x:.2f}'


def paired_intervals(metrics, ids):
    # Paired image bootstrap, not vehicle-cluster bootstrap (IDs unavailable).
    if not ids:
        return {}
    rng = np.random.default_rng(42)
    arrays = {}
    for model in ('cardd','roboflow'):
        values = np.zeros((len(ids),3,3),dtype=int)
        positions = {v:i for i,v in enumerate(ids)}
        for event in metrics[model]['pooled']['matches']:
            obj = event.get('prediction',event.get('gt'))
            values[positions[event['image']],obj['cls'],('TP','FP','FN').index(event['status'])] += 1
        arrays[model] = values
    deltas = []
    for _ in range(2000):
        index = rng.integers(0,len(ids),len(ids))
        f1s=[]
        for model in ('cardd','roboflow'):
            counts=arrays[model][index].sum(axis=0)
            denom=2*counts[:,0]+counts[:,1]+counts[:,2]
            f1s.append(np.divide(2*counts[:,0],denom,out=np.full(3,np.nan),where=denom>0))
        deltas.append(f1s[1]-f1s[0])
    intervals={}
    for c,name in enumerate(COMMON):
        values=np.array(deltas)[:,c]
        finite=values[np.isfinite(values)]
        intervals[name]=dict(delta_f1_95_interval=[float(x) for x in np.percentile(finite,[2.5,97.5])] if len(finite) else [None,None],
            valid_resamples=len(finite), method='2000 paired image bootstrap resamples; seed42; no vehicle IDs; not proof of independent generalization')
    return intervals


def draw_examples(output, audit, predictions, metrics):
    records=audit['records']
    # Deterministic, explicitly diagnostic selection: largest FN/FP differences,
    # first example per class/source, then high confidence errors.
    scores=Counter()
    for model in ('cardd','roboflow'):
        for event in metrics[model]['pooled']['matches']:
            if event['status']!='TP': scores[event['image']]+=1
    indices=audit['common_indices']
    chosen=[]
    for source in ('cardd','roboflow'):
        for name in COMMON:
            found=next((i for i in indices if records[i]['source']==source and
                        any(NAMES[source][o['cls']]==name for o in records[i]['gt'])),None)
            if found is not None and found not in chosen: chosen.append(found)
    for i in sorted(indices,key=lambda i:(-scores[records[i]['id']],records[i]['id'])):
        if i not in chosen: chosen.append(i)
        if len(chosen)>=12: break
    directory=output/'examples'
    directory.mkdir(exist_ok=True)
    manifest=[]
    for number,i in enumerate(chosen):
        record=records[i]
        canvas=Image.new('RGB',(1440,600),'#ffffff')
        draw=ImageDraw.Draw(canvas)
        for column,model in enumerate(('cardd','roboflow')):
            with Image.open(record['image']) as original: image=original.convert('RGB')
            image.thumbnail((710,510))
            x,y=column*720,65
            canvas.paste(image,(x,y))
            draw.text((x+4,4),f'{model} | conf >= 0.25 | green GT; red common; orange other head',fill='black')
            draw.text((x+4,23),record['id'][:95],fill='black')
            objects=[(o,'#00cc44','GT '+NAMES[record['source']][o['cls']]) for o in record['gt']]
            objects += [(p,'#ff2525' if NAMES[model][p['cls']] in COMMON else '#ff9900',
                         NAMES[model][p['cls']]+f" {p['conf']:.2f}")
                        for p in predictions[model][str(i)] if p['conf']>=.25]
            for obj,color,label in objects:
                b=obj['box']; coords=(x+b[0]*image.width,y+b[1]*image.height,x+b[2]*image.width,y+b[3]*image.height)
                draw.rectangle(coords,outline=color,width=2)
                draw.text((coords[0]+2,coords[1]+2),label,fill=color,stroke_width=1,stroke_fill='black')
        path=directory/f'{number:02}.jpg'
        canvas.save(path,quality=90)
        manifest.append(dict(file=path.relative_to(output).as_posix(),image=record['id']))
    write(directory/'manifest.json',dict(selection='First per source/class then most FP+FN; diagnostic, not representative sampling',images=manifest))


def build_report(output):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    audit=read(output/'cohort.json')
    data=read(output/'metrics.json')
    predictions=read(output/'predictions.json')
    metrics=data['common']
    benchmarks={p.stem.removeprefix('benchmark_'):read(p) for p in output.glob('benchmark_*.json')}
    hardware=read(output/'hardware.json') if (output/'hardware.json').exists() else {}
    ids=[audit['records'][i]['id'] for i in audit['common_indices']]
    intervals=paired_intervals(metrics,ids)
    conclusions={}
    for name in COMMON:
        a,b=[metrics[m]['pooled']['per_class'][name] for m in ('cardd','roboflow')]
        delta=None if a['ap50_95'] is None else b['ap50_95']-a['ap50_95']
        conclusions[name]=dict(observed_ap50_95_leader=('not_measurable' if delta is None else
            'tie' if abs(delta)<1e-12 else 'roboflow' if delta>0 else 'cardd'),
            delta_ap50_95_rf_minus_cardd=delta, reliable_winner='NOT_ESTABLISHED',
            **intervals.get(name,{}))
    negative_indices=[i for i,r in enumerate(audit['records']) if r['split']=='test' and not r['gt']]
    negative=dict(verified_independent_clean_images=0, false_alerts_per_image=None,
        status='NOT_MEASURABLE: no independently adjudicated, leakage-free clean test set',
        candidates=[dict(id=audit['records'][i]['id'],leakage_excluded=audit['records'][i]['leakage_excluded'],
                        raw_alert_counts={m:sum(p['conf']>=.25 for p in predictions[m].get(str(i),[]))
                                          if str(i) in predictions[m] else None for m in predictions}) for i in negative_indices])
    result=dict(status='completed_exploratory_not_independent_superiority_evidence',
        report_generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        recommendation='KEEP_CURRENT_CARDD', comparison=data, audit_summary=audit['summary'],
        audit_details='audit.json', cohort_details='cohort.json', predictions='predictions.json', benchmarks=benchmarks,
        hardware=hardware,
        semantic_contract=dict(common=list(COMMON),
            cardd_broken_part='lamp broken only; native ID 3',
            roboflow_broken_part='general broken part; native ID 0; unsupported by CarDD',
            roboflow_broken_lamp='separate lamp class; native ID 6',
            lamp_common_evaluation='NOT_VALIDATED; native diagnostic cohorts only',
            glass_mapping='NONE; BROKEN_GLASS and CRACKED_GLASS are not equated'),
        class_conclusions=conclusions, clean_negative_evaluation=negative,
        reliability_limitations=audit['limitations']+[
            'Native lamp/general broken-part metrics use different own-source cohorts; not a common-class comparison.',
            'Filtered common-only images do not represent full product mix; test thresholds fixed, not tuned.',
            'Local laptop CPU/GPU benchmarks are not Railway production latency.'],
        matching_protocol=dict(ap='101-point interpolated precision envelope; confidence-first greedy per class; IoU .50:.05:.95',
            operating='Fixed .25; P/R/F1 class-aware IoU .50. Also .001 diagnostics, no max-F1 selection.',
            confusion='Prediction rows, GT columns; class-agnostic confidence-first geometry at IoU .50; background row/column.',
            max_det='300 per image across native head after class-aware NMS; common projection only afterwards.',
            area='All sizes; no crowd/ignore annotations; entire noncommon GT images excluded.',
            other_heads='Other-class detections reported separately, never silently renamed into common classes.',
            warning='Defined shared bbox protocol, not claimed numerically identical to Ultralytics val or official COCO API.'))
    write(output/'comparison.json',result)
    fields=['cohort','model','class','instances','tp','fp','fn','precision','recall','f1','ap50','ap50_95']
    with (output/'per_class_comparison.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.DictWriter(stream,fieldnames=fields)
        writer.writeheader()
        for model in metrics:
            cohorts={'pooled':metrics[model]['pooled'],**metrics[model]['by_source']}
            for cohort,values in cohorts.items():
                for name,values in values['per_class'].items():
                    writer.writerow(dict(cohort=cohort,model=model,**{'class':name},
                                         **{k:values[k] for k in fields[3:]}))
    figure,axes=plt.subplots(1,3,figsize=(14,4))
    for ax,metric in zip(axes,('ap50_95','recall','f1')):
        for j,model in enumerate(metrics):
            ax.bar(np.arange(3)+(j-.5)*.36,[metrics[model]['pooled']['per_class'][c][metric] or 0 for c in COMMON],
                   .36,label=model)
        ax.set_xticks(range(3),COMMON);ax.set_ylim(0,1);ax.set_title(metric);ax.legend()
    figure.suptitle('Exploratory filtered test: independence not established; P/R/F1 at conf=.25')
    figure.tight_layout();figure.savefig(output/'class_comparison.png',dpi=150);plt.close(figure)
    figure,axes=plt.subplots(1,2,figsize=(12,5))
    for ax,model in zip(axes,metrics):
        matrix=np.array(metrics[model]['pooled']['confusion_matrix']['values'])
        ax.imshow(matrix,cmap='Blues')
        ax.set_xticks(range(4),list(COMMON)+['background'],rotation=30)
        ax.set_yticks(range(4),list(COMMON)+['background'])
        ax.set_xlabel('Ground truth');ax.set_ylabel('Prediction');ax.set_title(model+' @ .25 / IoU .50')
        for (r,c),v in np.ndenumerate(matrix): ax.text(c,r,str(v),ha='center',va='center',color='red')
    figure.tight_layout();figure.savefig(output/'confusion_matrices.png',dpi=150);plt.close(figure)
    if benchmarks:
        figure,ax=plt.subplots(figsize=(9,4))
        keys=list(benchmarks)
        ax.bar(np.arange(len(keys))-.18,[benchmarks[k]['wall_ms']['p50'] for k in keys],.36,label='p50')
        ax.bar(np.arange(len(keys))+.18,[benchmarks[k]['wall_ms']['p95'] for k in keys],.36,label='p95')
        ax.set_xticks(range(len(keys)),keys);ax.set_ylabel('ms / image');ax.legend()
        ax.set_title('Local laptop only; NOT Railway production latency')
        figure.tight_layout();figure.savefig(output/'local_latency.png',dpi=150);plt.close(figure)
    draw_examples(output,audit,predictions,metrics)
    summary=audit['summary']
    lines=['# CarDD / Roboflow V3 Nano karşılaştırması','',
        '**Karar: mevcut CarDD modelini koru.** Bu çalışma güvenilir, bağımsız bir üstünlük iddiası kurmuyor. '
        'Aşağıdaki liderler yalnızca sızıntı şüphelileri çıkarılmış mevcut görüntülerdeki gözlemsel sonuçlardır.', '',
        '## Veri kapsamı ve sızıntı', '',
        f"{summary['total_images']} görüntü incelendi. Split sayıları: `{summary['splits']}`.",
        f"İki kaynaktan {summary['candidate_test_images']} test adayı vardı; {summary['leakage_excluded']} görüntü "
        'iki modelden en az birinin train/validation verisine bağlı olduğu için dışlandı.',
        f"Şüpheli eşleşme türleri (çift sayısı): `{summary['edge_counts']}`.",
        f"Etiket filtresinden kalan {summary['before_visual_review_common_images']} adayın görsel incelemesinde "
        f"{summary['visual_review_excluded']} görüntü daha dışlandı; gerekçeler `cohort_review.json` içinde.",
        f"Ortak deney: **{summary['common_test_images']} görüntü**, kaynaklar `{summary['common_sources']}`, "
        f"instance desteği `{summary['common_instances']}`.", '',
        'Dosya SHA-256, çözümlenmiş RGB SHA-256 ve 63 bit pHash (Hamming ≤10, boy oranı filtresiz) '
        'test adaylarının tüm envantere karşı taranmasında kullanıldı. Aynı kaynak dosya adı ailesi de şüpheli sayıldı. '
        'Top-12 pHash, top-12 gri görüntü benzerliği ve yakın CarDD numaralarından adaylar SIFT/RANSAC ile tarandı '
        '(≥14 inlier, ≥%50 inlier oranı, iki görüntüde ≥%4 alan). Bunlar aynı sahne şüphesidir; kesin araç kimliği değildir. '
        'Train/val ile bağlı bileşenin tüm test üyeleri dışlandı; kalan test bileşenleri tek temsilciye indirildi.', '',
        'Exact byte/RGB eşleşmesi 0 idi; buna rağmen yeniden boyutlanmış/sıkıştırılmış kopyalar dosya kökeni '
        've algısal taramayla bulundu. Örneğin RF test 000001/000020/000029 dosyaları CarDD train karşılıklarıyla '
        'görsel olarak aynı fotoğraflardır. Yerel özellik taramasında bazı yanlış benzerlikler de görüldü; '
        'şüpheliler konservatif olarak dışarıda tutuldu. Görsel incelemede aynı hasarlı beyaz kapı sahnesine '
        'benzeyen CarDD 002294/002707 örnekleri ayrıca dışlandı. İnceleme kararları model tahminleri görülmeden verildi.', '',
        'Araç/çekim oturumu kimlikleri bulunmuyor. Farklı açı ve büyük crop kaçabilir. CarDD checkpoint’i mevcut '
        'V2 yolunu gösteriyor fakat eğitim tarihindeki dosya üyeliğini doğrulayan manifest bulunmuyor. RF eğitim '
        'raporu/checkpoint/review hash’leri ve güncel dataset manifest’i doğrulandı. Bu nedenlerle kalan küme '
        '**bağımsızlığı kanıtlanmış test kümesi değildir**. Cross-source anotasyon kapsamı ve kutu çizim '
        'politikası da tüm görüntülerde yeniden uzman anotasyonuyla doğrulanmadı.', '',
        'CarDD BROKEN_PART = lamp broken (ID 3); RF BROKEN_PART = genel kırık parça (ID 0), '
        'BROKEN_LAMP = ID 6. Bunlar eşitlenmedi. BROKEN_GLASS / CRACKED_GLASS da eşitlenmedi. '
        'Ortak olmayan GT bulunan fotoğraf tümüyle çıkarıldı. Ham CarDD etiketlerinde patlak lastik '
        'bulunan fotoğraflar, aktarılmış etikette görünmese bile çıkarıldı. Boş etiket otomatik olarak hasarsız kabul edilmedi.', '',
        '## Ortak protokol', '',
        '`imgsz=640`, kare letterbox (`rect=False`), batch=1, FP32, NMS IoU=0.60, '
        'AP tabanı conf=0.001, native head üzerinde max_det=300, augmentation yok. '
        'Her iki model aynı görüntülerde ve aynı evaluator ile çalıştırıldı. '
        'ID eşleştirmesi: CarDD 0/1/2 → SCRATCH/DENT/CRACK; RF 5/2/1 → SCRATCH/DENT/CRACK.', '',
        'AP: confidence sıralı, sınıf duyarlı, bire bir greedy GT eşleştirme; IoU 0.50:0.05:0.95; '
        '101 recall noktasında interpolasyonlu precision ortalaması. P/R/F1 sabit conf=0.25 ve IoU=0.50 içindir; '
        'testten max-F1 eşiği seçilmedi. .001 çalışma noktası ayrıca JSON içinde bulunur. '
        'Confusion matrix sınıftan bağımsız geometrik eşleştirme kullanır; satır tahmin, sütun GT ve background dahildir. '
        'Bu nedenle yanlış sınıf eşleşmesi matriste tek hücre, sınıf metriklerinde bir FP ve bir FN olur.', '',
        '## Sınıf sonuçları', '',
        'Yüzde değerler. P/R/F1 @0.25; AP @0.001. Boş destek N/A; sıfır AP ile karıştırılmaz.', '',
        '| Sınıf | Model | GT | P | R | F1 | AP50 | AP50-95 | TP / FP / FN |',
        '|---|---|---:|---:|---:|---:|---:|---:|---|']
    for name in COMMON:
        for model in metrics:
            c=metrics[model]['pooled']['per_class'][name]
            lines.append(f"| {name} | {model} | {c['instances']} | "+' | '.join(percentage(c[k]) for k in ('precision','recall','f1','ap50','ap50_95'))+f" | {c['tp']} / {c['fp']} / {c['fn']} |")
    lines+=['','| Sınıf | Gözlemsel AP50-95 lideri | RF − CarDD (yüzde puan) | F1 farkı %95 bootstrap aralığı (puan) | Güvenilir kazanan |',
        '|---|---|---:|---|---|']
    for name,c in conclusions.items():
        ci=c.get('delta_f1_95_interval',[])
        lines.append(f"| {name} | {c['observed_ap50_95_leader']} | {percentage(c['delta_ap50_95_rf_minus_cardd'])} | "+' / '.join(percentage(v) for v in ci)+' | Belirlenemedi |')
    lines+=['', 'Bootstrap 2.000 eşlenik görüntü örneklemesi, seed=42. Araç kümeleri bilinmediği için '
        'bu aralık sahne bağımsızlığını veya dağılım dışı başarıyı kanıtlamaz. AP lideri tek başına ürün tercihi değildir.', '',
        '### Kaynağa göre AP50-95', '', '| Kaynak | Sınıf | GT | CarDD | Roboflow |','|---|---|---:|---:|---:|']
    for source in ('cardd','roboflow'):
        for name in COMMON:
            a,b=[metrics[m]['by_source'][source]['per_class'][name] for m in ('cardd','roboflow')]
            lines.append(f"| {source} | {name} | {a['instances']} | {percentage(a['ap50_95'])} | {percentage(b['ap50_95'])} |")
    lines+=['', 'Ortak kohortun 132/176 görüntüsü CarDD kaynağından geliyor; pooled skor CarDD dağılımına ağırlık verir. '
        'RF kaynağında DENT ve CRACK AP50-95 liderliği Nano’ya dönüyor, SCRATCH’te CarDD önde kalıyor. '
        'Ancak RF tarafında yalnızca 19 DENT ve 2 CRACK GT var. Toplam 18 CRACK da güvenilir sınıf üstünlüğü '
        'için zayıf destektir. Fotoğraf dışlamaları dağılımı daha hafif ve daha açık tanımlı hasarlara kaydırır; '
        'bu kohort ağır kaza veya bütün ürün trafiğinin temsilcisi değildir.', '',
        '## Gerçek kullanım eşiği ve kapsam dışı başlıklar', '']
    for model in metrics:
        m=metrics[model]['pooled']
        lines.append(f"- {model}: ortak sınıflarda {m['totals']['fn']} kaçırılan GT, {m['totals']['fp']} yanlış alarm kutusu; "
            f"confidence ≥0.80 olan {len(m['high_confidence_fp'])} FP. Diğer native sınıflardan {len(m['other_head_alerts'])} ek alarm var; "
            'bunlar ortak sınıf AP’sine eklenmedi ve otomatik yanlış alarm sayılmadı.')
    lines+=['', 'FP, referans anotasyona göre sınıf/kutu eşleştirme hatasıdır; yerelleştirme, sınıf karışması '
        've yinelenen kutular buna dahildir. Her FP, görüntüde gerçekte hasar olmadığı anlamına gelmez.', '',
        '**Gerçekten hasarsız fotoğraflarda FP/görüntü: ölçülemedi (null).** '
        f"{len(negative_indices)} boş etiketli test adayı bulundu; bunun gerçekten hasarsız, tüm hasar türleri açısından "
        'eksiksiz ve iki eğitim kaynağından bağımsız olduğu doğrulanmadı. Bu aday ayrıca train/val sızıntı filtresine takıldı. Tek aday zaten üretim yanlış alarm oranını '
        'tahmin etmeye yetmez. Negatif aday durumu ve varsa ham alarm sayıları comparison.json içindedir.', '',
        '### Lamba ve genel kırık parça: yalnızca native kaynak teşhisi', '',
        'Bu tablo aynı fotoğraflarda karşılaştırma değildir. Anotasyon anlamları ortak kategori olarak '
        'doğrulanmadığından lamba için cross-source kazanan çıkarılmaz. Genel kırık parça CarDD başlığında yoktur.', '',
        '| Model / kendi kaynağı | Anlam | Görüntü | GT | P@.25 | R@.25 | F1@.25 | AP50 | AP50-95 |',
        '|---|---|---:|---:|---:|---:|---:|---:|---:|']
    for model,name,meaning in [('cardd','BROKEN_PART','Lamba kırığı'),('roboflow','BROKEN_PART','Genel kırık parça'),('roboflow','BROKEN_LAMP','Lamba')]:
        native=data['native_diagnostics'][model];c=native['per_class'][name]
        lines.append(f"| {model} | {meaning} | {native['images']} | {c['instances']} | "+' | '.join(percentage(c[k]) for k in ('precision','recall','f1','ap50','ap50_95'))+' |')
    lines+=['', '## Kaynak tüketimi', '',
        'Aynı yerel Windows bilgisayar; her model/cihaz ayrı Python process. Sabit ilk 24 ortak görüntü '
        'önceden decode edildi; 10 warmup, 120 ölçüm, batch=1, 640, FP32, conf=.25, NMS=.60, max_det=300, '
        '4 Torch CPU thread. GPU ölçümünde CUDA senkronizasyonu kullanıldı. Wall süre preprocessing + forward + '
        'NMS + Python API içerir; dosya okuma, ağ ve backend içermez. Forward süreler ayrıca JSON içinde.', '',
        '| Model | Dosya MiB | CPU p50 / p95 ms | GPU p50 / p95 ms | CPU peak RAM MiB |',
        '|---|---:|---|---|---:|']
    for model in metrics:
        cpu=benchmarks.get(model+'_cpu');gpu=benchmarks.get(model+'_0')
        duration=lambda b: f"{b['wall_ms']['p50']:.2f} / {b['wall_ms']['p95']:.2f}" if b else 'Ölçülemedi'
        peak=max(cpu['sampled_peak_rss_bytes'],cpu['os_peak_working_set_bytes'] or 0)/2**20 if cpu else None
        lines.append(f"| {model} | {data['provenance']['checkpoints'][model]['bytes']/2**20:.3f} | {duration(cpu)} | {duration(gpu)} | {peak:.1f} |" if peak else f'| {model} | Ölçülemedi | | | |')
    lines+=['', f"GPU: {data['provenance']['gpu']}. CPU: {hardware.get('cpu_name',data['provenance']['cpu'])}.",
        'RAM model tensör belleği değildir; Python, CUDA özellikli PyTorch kurulumu ve runtime dahil toplam '
        'process working set’tir. 5 ms örneklemeli RSS ve Windows lifetime peak birlikte kaydedildi. '
        '**Bu sonuçlar Railway CPU production performansı değildir.** Gerçek container CPU limiti, Linux runtime, '
        'concurrency ve uçtan uca servis ölçümü yapılmadı. Ardışık yerel ölçümler güç/ısı durumundan etkilenebilir.', '',
        '## Ekspersiz için tercih', '',
        'Mevcut CarDD’yi koru. RF Nano’nun daha geniş sınıf başlığı tek başına daha iyi ortak hasar tespiti '
        'anlamına gelmez; sınıf bazındaki gözlemsel farklar yukarıdadır. Değişim için iki eğitim kaynağından bağımsız '
        'araç/oturum gruplarıyla toplanmış, ortak tanımlarla eksiksiz anotasyonlanmış, yeterli hasarsız negatif ve '
        'her sınıfı içeren yeni bir dış test kohortu gerekir. Threshold seçimi ayrı validation üzerinde yapılmalıdır. '
        'Bu çalışmada eşik ayarı, eğitim, production ağırlık değişikliği, merge veya deployment yoktur.', '',
        '## Tekrarlanabilirlik ve çıktılar', '',
        '`audit.json`: tüm görüntü/etiket hash’leri, eşleşme çiftleri, dışlama nedenleri ve veri üyeliği. '
        '`predictions.json`: korunan test görüntülerinde iki modelin native ID’li ham kutuları. '
        '`comparison.json` / `metrics.json`: tüm eşleşmeler, hatalar, .001 ve .25 metrikleri, native teşhisler, '
        'sürümler ve checkpoint hash’leri. `per_class_comparison.csv`: pooled ve kaynak bazlı sonuçlar. '
        '`examples/manifest.json`: yan yana örneklerin seçilme kuralı ve görüntü adları. '
        'Örnekler hata incelemesi için seçildi; rastgele veya temsilî başarı örneklemesi değildir.', '',
        '```powershell', 'cd ai-service',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py audit',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py review-sheets',
        '# Görsel inceleme kararlarını audit hash ile cohort_review.json içine kaydet.',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py evaluate --device 0',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py benchmark',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py report',
        '.\\venv\\Scripts\\python.exe scripts/compare_cardd_roboflow_nano.py verify',
        '.\\venv\\Scripts\\python.exe -m unittest discover -s tests', '```', '',
        'Mevcut audit dosyası ezilmez; baştan tekrar için yeni `--output` dizini verilir. '
        'Bütün değerlendirme çıktıları yereldir ve mevcut .gitignore gereği Git dışında kalır.']
    (output/'comparison_report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
