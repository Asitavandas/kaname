# Connector aday içerik doğrulama görevi — dev.39

Mevcut operatör kaydından **Doğrulamayı önizle → Doğrulamayı gönder** ile
salt okunur, süreli bir görev oluşturulur. Yeni worker ayrı imzalı capability
poll göndermedikçe görev kaydedilemez; eski probe-only worker etkilenmez.

Endpointler `/api/connector/v1/candidates/poll` ve `/result` mevcut HTTPS
adı/zinciri/iptal kontrolü/TLS pin ve Connector RSA anahtarını kullanır.
Proof purpose, path, method, binding generation, nonce, zaman ve payload hash
bağlıdır. Lease/sonuç SQLite işleminde kayıtlıdır; aynı sonuç tekrar yazılmaz.
Panel yazıları iki güncel yetki + interaktif oturum + CSRF ister.

Görev yalnız candidate UUID, plan UUID/sürüm, GPO UUID, approval/manifest ve
bağımlılık özetlerini taşır. URL, yol, komut, script veya AD filtresi alamaz.
Worker en fazla 32 kayıt içeren korumalı sabit yerel dizinde exact plan/sürüm
ve approval hash ile tek adayı bulur. Paket publisher kimliği ayrıca sabittir.
Mevcut non-admin verifier imza, XML/ZIP/CA ve byte/ACL sınırlarını kontrol eder;
private signer key açılmaz, aday çalıştırılmaz, AD/GPO/endpoint yazılmaz.

Plan/profile/katalog içeriği/trust/config/binding create, poll, result ve durum
gösteriminde yeniden kontrol edilir. Sadece catalog synced_at değişikliği
eskime değildir. Bu cache kontrolü canlı AD freshness veya GPO kontrolü değildir.

Başarı **content_verified / İmza ve içerik doğrulandı** olarak ayrı gösterilir.
`connector_verified=false`, `can_apply=false` korunur. Bu noktasal okuma
gelecekteki dağıtım öncesi fresh AD/GPO/dosya kontrollerinin yerine geçmez.
Sonraki yeniden doğrulama reddedilirse önceki içerik başarı etiketi kaldırılır.
Operatör receipt ve tarihi başarısız wrapper kayıtları değiştirilmez.

Linux güncellemesi ve signed/staged Windows Connector paketi ayrı kabul
edilecek. Kaynak/CI başarısı müşteri roundtrip veya endpoint kabulü değildir.
GPO uygulama, SYSVOL staging, installer, cihaz sertifikası/ağ ayarı ve canlı
AD/GPO kapsam doğrulaması beklemededir. Mevcut servis/eşleme/kanal anahtarı
sıfırlanmaz. Eski başarılı manuel probe tekrarlanmaz; CLR signer marker veya
key ACL değiştirilmez. Tarihsel delivery dosyası yeniden üretilmez.
