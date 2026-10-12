# EksperSiz uygulama bilgi tabanı

Bu dizine yalnız EksperSiz'in ürün özellikleri, kullanım akışları ve AI değerlendirmesinin sınırları eklenir. Genel otomotiv bilgileri Google Search, kişisel kayıtlar ise yetkilendirilmiş backend araçları üzerinden alınır.

Yeni kaynaklar sources.json ile sınırlandırılmıştır. PDF desteklenir; düzenlenebilir Markdown belgeleri aynı metnin kanonik kaynağıdır. PDF ve Markdown kopyalarını aynı anda ingest etmeyin (çift embedding).

## Yeniden embedding

1. Belgeleri ve sources.json dosyasını gözden geçirin.
2. PostgreSQL DATABASE_URL ve model bağımlılıkları olan bir ortamda aşağıdaki komutu çalıştırın:

```bash
python scripts/ingest_assistant_knowledge.py --source-version app-only-v1
```

Başarılı ingest tamamlandığında manifest dışında kalan eski aktif belgeler SUPERSEDED olur; geçmiş sürümler denetim amacıyla saklanır. Bu komut geçmiş veritabanı satırlarını fiziksel olarak silmez. Üretim veritabanında yeniden embedding işlemi henüz otomatik çalıştırılmaz.

Sürüm değişmeden belge içeriğini değiştirmeyin; değişiklik için yeni source-version kullanın.
