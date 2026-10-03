# Windows kurulum kontrolü — 3 Ekim 2026

Depo: Asitavandas/kaname. Kullanıcının mevcut kurulum klasörü: C:\Users\Administrator\KANAME.

İlk tanılama: https://github.com/Asitavandas/kaname/actions/runs/37131544564

| Önceki adım | Mevcut kanıt |
|---|---|
| Paketi açma | 0.2.0-dev.1 paketindeki 41 kaynak dosyası eksiksiz ve SHA256'ları aynı |
| Python | 3.12 yönergesinden farklı olarak 3.14.8 kullanılıyor |
| venv/bağımlılık | venv kullanılıyor; cryptography 46.0.0 mevcut |
| Panel | 127.0.0.1:8765 healthz 200; sürüm kaynakla aynı |
| Token | Dosya mevcut, format geçerli, panel tarafından kabul edildi; değer dışarı çıkarılmadı |
| Kurulum ayarları | Geçerli config kaydedilmiş; revision 7 |
| Politikalar | 1 politika kayıtlı ve etkin |
| Dahili CA | Database'de CA kaydı mevcut; anahtarlar açılmadı veya yeniden oluşturulmadı |

Tarayıcıdaki önceki girişin ve Set-Clipboard kullanımının geçmişi bu kontrolden belirlenemez. Get-Content ... | Set-Clipboard başarılı olduğunda normal olarak çıktı üretmez.

Windows Python uyumluluğu: https://github.com/Asitavandas/kaname/actions/runs/37131663936

132 test çalıştı; 131 geçti, Windows'ta OpenSSL CLI bulunmadığı için 1 bağımsız CLI doğrulama testi atlandı. Gerçek yerel TLS handshake testi geçti. Önceki Linux geliştirme ve GitHub Linux koşularında tüm 132 test geçti. Bu sonuçlar Windows'taki mevcut Python sürümünü değiştirmeyi gerektiren bir hata göstermiyor.

Bu aşamada 503 readyz beklenir; AD ve RADIUS bağlanmadı ve çalışan OVF imajı oluşturulmadı. Simülasyon sonuçları gerçek kullanıcı/makine kimlik doğrulaması veya 802.1X enforcement kanıtı değildir.

Sonraki geliştirme: AD bağlantı/test sihirbazı; ardından gerçek kullanıcı/grup eşitleme, AD ile kanıtlanmış sertifika enrollment, FreeRADIUS/EAP-TLS, trust dağıtımı ve appliance export/boot. AD parolaları GitHub'a veya sohbet kayıtlarına girilmeyecek. Switch/AP yönetimi eklenmeyecek; gerçek 802.1X testleri kullanıcının manuel yapılandırdığı cihazlarla yapılacak.
