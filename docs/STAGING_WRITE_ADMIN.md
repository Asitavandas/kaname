# Yazma/geri alma yönetici incelemesi — yürütme kapalı

29 Ekim 2026. Bu değişiklik kaynak/test entegrasyonudur; müşteri Linux veya Windows
paketine teslim edilmiş değildir. StagingFilesystem çağrısı ve canlı dosya yazması yoktur.

## HTTP sözleşmesi

- `GET /api/deployment/staging-write`: mevcut kayıtların dar durum görünümü.
  İki read yetkisi (`certificates.authority`, `system.connectors`), HTTPS ve panel
  oturumu ister. Maintenance bearer bu yeni uçta kabul edilmez.
- `POST /api/deployment/staging-write/review`: iki write yetkisi, geçerli panel
  oturumu, izinli Host/Origin ve CSRF ister. Gövde okunduktan sonra ayrı admin read
  transaction'ında iki yetki, hesabın enabled/version durumu ve asıl session'ın
  digest/user/version/expiry/idle/CSRF kaydı yeniden doğrulanır.
  İnceleme actor UUID'sini oturumdan alır; istemci actor/path/command veremez.
  Mevcut revision, ayrı stage/rollback ack, aday/içerik/binding/kapsam ve taze
  90 saniyelik önizleme kapıları protokol çekirdeğinde aynen korunur.
  `review_only=true`; ledger, audit veya revision yazılmaz.
- `POST /api/deployment/staging-write/create`: aynı güvenlik kapılarından sonra
  koşulsuz `409 STAGING_WRITE_EXECUTION_UNAVAILABLE`. Geçerli review hash'i veya
  tekrar istek dahi job oluşturmaz. Bunu açan environment/config/istek anahtarı yoktur.
- Peer `staging-write/poll`, `claim`, `result` ve apply/execute uçları **kayıtlı değildir**.
  İç protokol testleri bu sınıfı doğrudan çağırabilir; HTTP üzerinden yetki verilemez.

Yeni durum/review sonuçlarında `approval_enabled`, `write_authorization_enabled`,
`execution_adapter_available`, `can_apply_gpo` daima false'tur. Review hash'i kullanıcı
kimlik doğrulaması veya yürütme izni değildir. Core'un `read_only=false` alanı gelecekte
incelenecek stage/rollback işleminin etkisini tarif eder; HTTP çağrısının etkisi
`review_only=true` ile ayrılır. Mevcut kurulu Windows worker write capability
göndermez ve yeni poll ucu bulunmaz; üretimde başarılı write review beklenmez.
Başarılı review testi yalnız kontrollü fixture'daki dahili RSA poll kaydını kullanır.

## Panel

Birleşik aday listesinde ayrı bir "Dosya yazma ve geri alma durumu" alanı vardır.
Yazma/geri alma gönderme butonu yoktur. Mevcut okuma/önizleme akışı devam eder;
ek durum sorgusu gecikse bile aday listesi bu sorguyu beklemez.
Durum sorgusu başarısızsa bunu "işlem yok" veya "başarılı" diye göstermez.
Queued/leased henüz izin değildir; authorized dosya sonucunu kanıtlamaz;
requires_review tekrar başlatılmaması gereken belirsizliktir; completed ise yalnız
Connector bildirimi, bağımsız dosya/saha kabulü değildir. ID/metinler textContent ile
gösterilir. Oturum nesli veya yenileme sırası değiştiğinde eski async yanıt atılır.
Sunucudan yanlışlıkla true dönen yetki bayrağı UI'da bir gönderme yolu açmaz.

## Doğrulama ve açık kapılar

Gerçek doğrulanan HTTPS fixture'ları: başarılı actor bağlı inceleme, read/read ve
iki write rol sınırları, Origin/Host/CSRF/TLS, bakım anahtarı reddi, gövde okunurken
rol/kullanıcı/session değişimi, revizyon/ack/path/command/scope reddi, preview expiry,
bozuk/busy store, duplicate JSON/body/content-type sınırları, gizli grant'ın dar durum
görünümünde çıkmaması ve create tekrarlarının etkisizliği.
Tarayıcı fixture'ı: belirsizlik/peer sonucu ayrımı, XSS metni, durum servisi hatası,
beklenmedik true yetki bayrağı, oturum değişimiyle eski yanıtın atılması ve önceki
doğrulama/önizleme davranışları. CI sonuçları checkpoint'e ayrıca kaydedilir.

Sırada bounded Windows CLAIM/live-scope adapter'ı ve protected yerel durable kayıt,
kayıp yanıt/kesinti/journal uzlaştırma ve partial recovery, strict backup projection,
gerçek yönetici onay formu/create ve peer rotalarının bu kapılardan sonra açılması,
imzalı teslim ve gerçek gMSA/SMB kabulü vardır. GPO aktivasyonu ayrıca açık kapıdır.
512 hedef sözleşmesi korunur. Bu değişiklik kurulu sürümü/ayarları veya gerçek
kapasite/saha kabulünü değiştirmez; tam veri yedeği almaz.
