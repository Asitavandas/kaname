# Birleşik paket için kalıcı salt okunur doğrulama

Ayrı combined.verify.v1 işlemi, windows_combined_verify_jobs kuyruğu ve AUTHWIRE-COMBINED-JOB frame amacı kullanılır. Eski ağ profili kaydı ve kuyrukları korunur. Hedef; mevcut plan, bağlantı, bağımlılık, ağ kaydı/manifesti, birleşik draft/manifesti, yayıncı, bilgisayar profili/sürümü, domain/grup ve kök güvenini bağlar. Eski/yabancı/çakışan sonuç kabul edilmez; tek lease, kalıcı replay koruması, idempotent sonuç, güncel iki yönetici yetkisi ve HTTPS panel oturumu gerekir.

Kalıcı Windows child aynı non-admin servis kimliğiyle eski ağ adayını ve birleşik üç imzayı doğrular. Birleşik dosyanın içindeki ağ ZIP'i mevcut doğrulanmış ağ adayının ZIP hash'iyle eşleşir. Sertifika kurulum ayarları profil/domain ve gerçek appliance URL/TLS pinine, CA içerikleri ağ paketine bağlanır. Public-only okuyucu kullanılır; imzalı artifact çalıştırılmaz, signer özel anahtarı açılmaz, AD/GPO/cihaz/trust/ACL değiştirilmez. Channel proof için mevcut ayrı channel anahtarı kullanılır.

Sonuç yalnız content_verified anlamındadır; connector_verified/can_apply false kalır, taze AD/GPO ve staging yetkisi vermez. Güncelleme taze CombinedChannelVerified olmadan başarılı sayılmaz ve mevcut paket/key/pairing korunarak eski release'e geri alınır. Poll trafiği dördüncü kesin biçimiyle backup kararlılık karşılaştırmasına eklenir; jobs/results/leases ve tüm gerçek DB verisi korunur. Yeni yedek tam veri içerir.

Canlı kabul sırayla Linux dev.42 + güncel backup worker, Windows paket Prepare/Apply + taze sağlık, panelde birleşik görevin önizlenmesi/gönderilmesi ve gerçek imza/içerik roundtrip sonucudur. Bu hazırlık kendi başına canlı kabul veya GPO uygulaması değildir.
