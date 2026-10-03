# KANAME AD ekranı ve Windows güncelleme raporu — 3 Ekim 2026

Bu rapor önceki `WINDOWS_STATUS_2026-10-03.md` raporundan sonraki çalışmayı kaydeder. Kullanıcının mevcut `C:\Users\Administrator\KANAME` kurulumu silinmeden 0.2.0-dev.1 sürümünden **0.3.0-dev.1** sürümüne geçirildi. Kaynak commit: `f309d3ca57e745624f3709592149aab421d39863`.

## Tamamlananlar

- Yerel panelde Active Directory bağlantı ekranı, kullanıcı/güvenlik grubu/bilgisayar kataloğu, arama, sayfalama ve seçilen grup SID'sini yeni politika formuna taşıma.
- Windows .NET üzerinden açık Kerberos kimlik doğrulaması ve LDAP signing/sealing ile dizin okuma. Ayrı AD CS/LDAPS CA kurulumu bu okuma yolu için gerekli değil. Linux okuyucu henüz uygulanmadı.
- Parolanın yalnız yerel panelde alınması, işlem stdin'i ile taşınması ve kalıcı olarak saklanmaması. GitHub'a gerçek kullanıcı/grup kataloğu, parola, token veya özel anahtar aktarılmadı.
- Başarılı katalog kaydının audit ile atomik yazılması; başarısız/eksik okumanın önceki kataloğu koruması; yapılandırma değiştiğinde eski okumanın reddedilmesi.
- Kaynak hash kontrolü, yerel kaynak/veritabanı yedeği ve başarısız başlangıçta kaynak geri dönüşü olan, mevcut uygulama sürecini doğrulayarak değiştiren Windows güncelleyici.

## Mevcut Windows kurulumu

| Kontrol | Doğrulanan sonuç |
|---|---|
| Panel | 127.0.0.1:8765 üzerinden HTTP 200; 0.3.0-dev.1 |
| Kaynak | Yayın manifestine göre eksik/değişmiş dosya yok |
| Python | Mevcut venv ve Python 3.14.8 kullanılıyor |
| Ayarlar | Güncelleme öncesindeki revision 9 korundu |
| Politika | Mevcut 1 etkin politika korundu |
| CA | Mevcut CA durumu korundu; yeniden oluşturulmadı |
| Erişim tokenı | Korundu; panel tarafından kabul edildi; değeri dışarı çıkarılmadı |
| Yedek | Kurulum altında `.kaname-upgrades` içinde oluşturuldu; GitHub'a yüklenmedi |
| Tekrar kontrol | Actions güncelleme işi bittikten sonra panel hâlâ çalışıyordu; ikinci çalıştırma `already_current: true` verdi |
| Simülasyon | POLICY_ALLOW, DOMAIN_DEVICE_REQUIRED ve ACCOUNT_DISABLED beklenen sonuçları verdi |

İlk güncelleme girişimi Windows venv başlatıcısının süreçte temel Python executable olarak görünmesi nedeniyle güvenli biçimde durdu; eski panel durdurulmadı. Aynı kullanıcı, `-m kaname`, yerel durum ve Python executable doğrulamaları korunarak venv temel executable desteği eklendi. Sonraki güncelleme ve tekrar kontrol başarılı oldu. Windows servis kurulumu/otomatik açılış bu adımın kapsamında değil.

## Test kanıtları

| Koşu | Sonuç |
|---|---|
| [Linux Python 3.12](https://github.com/Asitavandas/kaname/actions/runs/37138906596) | 165 test: 164 geçti, Windows'a özel .NET self-test atlandı |
| [Kullanıcının Windows Python 3.14.8 ortamı](https://github.com/Asitavandas/kaname/actions/runs/37138906630) | 165 test: 163 geçti; Linux'a özel platform testi ve bulunmayan OpenSSL CLI testi atlandı |
| [Chromium panel akışları](https://github.com/Asitavandas/kaname/actions/runs/37137633739) | Giriş, kurulum, politika, simülasyon, audit, kalıcılık ve AD fixture kataloğu akışları geçti |
| [Windows güncelleme ve tekrar kontrol](https://github.com/Asitavandas/kaname/actions/runs/37138906565) | Yedek, güncelleme, ayar/token/CA koruması ve HTTP kontrolleri başarılı |

Windows .NET self-test LDAP sınıflarını ve koruma seçeneklerini ağ bağlantısı yapmadan doğrular. Tarayıcı/HTTP AD testleri fixture kullanır. **Gerçek AD kimlik bilgisi ile başarılı bind ve katalog okuma henüz doğrulanmadı.** Simülasyonlar gerçek RADIUS veya 802.1X kimlik doğrulaması değildir. `readyz` için geliştirme durumunda 503 beklenir.

## Kullanıcının yapacağı gerçek AD denemesi

1. Windows bilgisayarda `http://127.0.0.1:8765` adresini açıp Ctrl+F5 ile yenileyin. Giriş isterse mevcut `kaname-state\access-token` değerini kullanın.
2. Kurulum ekranında gerçek AD DNS domain adı ve DC IP adresleri kayıtlı olmalı. AD ekranındaki DC FQDN bu domain altında olmalı ve çözümlenen tüm adresleri kayıtlı DC IP'leri arasında bulunmalı.
3. Active Directory ekranında DC FQDN, `kullanici@domain` ve parolayı girip **Bağlan ve bilgileri getir** düğmesine basın. Bu sürümde UPN suffix'i kayıtlı domain ile aynı olmalı. Parolayı yalnız yerel panelde girin.
4. Başarılıysa kullanıcı/grup/bilgisayar sayılarını; başarısızsa ekrandaki hata kodunu bildirin. Parola veya erişim tokenı göndermeyin.

## Sıradaki çalışma kapıları

1. Gerçek AD laboratuvarı: başarılı okuma, yanlış parola, yanlış DNS/DC ve DC kesintisi; önceki katalog/ayarların korunması. Gerekirse yalnız sonuç kodlarına göre okuyucu düzeltmesi.
2. Linux appliance için Kerberos ile korumalı AD okuyucu, en az yetkili servis kimliği yaşam döngüsü ve nested/primary grup üyeliğinin doğru hesaplanması.
3. AD kimliği ile kanıtlanmış cihaz/kullanıcı sertifika enrollment, dahili CA güven dağıtımı, yenileme/iptal ve istemci yapılandırma sihirbazı.
4. Gerçek RADIUS/EAP-TLS ve accounting, politika motoru bağlantısı; kullanıcının elle ayarladığı switch/AP ile kablolu/kablosuz 802.1X kabul/red testleri. Switch/AP yönetimi entegrasyonu eklenmeyecek.
5. Üretim yönetim HTTPS/RBAC, secret kasası, yedek/geri yükleme ve işletim kontrolleri; boot edilebilir Linux appliance, OVF export/import ve hedef hypervisor kabul testleri.

OVF şablonu/araçları mevcut olsa da boot edilebilir, NPS işlevlerini karşılayan bir OVF appliance henüz teslim edilmiş değildir. AD kataloğu erişim yetkisi veya canlı kimlik doğrulama kanıtı olarak kullanılmaz.
