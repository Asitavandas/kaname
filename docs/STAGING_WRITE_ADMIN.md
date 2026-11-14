# Yazma ve geri alma yönetici incelemesi

14 Kasım 2026. İzole HTTPS pilotu kaynak ve test kapsamındadır. Windows dosya sistemi ve canlı GPO üzerinde işlem yapmaz.

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
  Varsayılan hizmette `review_only=true`. İnceleme ledger, audit veya revision yazmaz.
- `POST /api/deployment/staging-write/create`: aynı güvenlik kapılarından sonra
  varsayılan hizmette `409 STAGING_WRITE_EXECUTION_UNAVAILABLE` döndürür. Canlı
  komut satırı, environment ve HTTP isteği pilot modunu etkinleştiremez.
- Varsayılan hizmette `staging-write/poll` kapalıdır. Yalıtılmış kabul için
  loopback HTTPS sunucusu bu ucu açıkça etkinleştirebilir. İmzalı yoklama
  yalnızca boş yanıt alır. Kuyruktaki işler ve yazıcı hazırlık kaydı korunur.
  Bu probe modunda `claim`, `result` ve apply/execute uçları kayıtlı değildir.

## İzole tek GPO pilotu

Yalnız loopback TLS sunucusu `DevelopmentServer` oluşturulurken kanonik
`staging_write_pilot_gpo_id` ile pilot kapsamı tanımlanabilir. Boş yanıt veren probe
modu aynı anda açılamaz. İzole pilotta yönetici incelemesi ve iş oluşturma ile
Connector'ın imzalı `poll`, `claim` ve `result` çağrıları aynı GPO sınırını kullanır.
Stage ve rollback ayrı inceleme, güncel revizyon, onay ve inceleme özeti ister.
Connector işlemleri kayıtlı peer anahtarını kullanır. Panel oturumu ve CSRF, görev
oluşturma için yeniden doğrulanır. `can_apply_gpo=false` ve apply/execute rotaları
kapalı kalır. Testteki peer sonuçları sentetiktir. Fiilî dosya etkisi ve Windows
Connector kabulü ayrı saha adımlarıdır.

## Uzlaştırma kararı

`POST /api/deployment/staging-write/reconciliation/review` aynı yönetici
oturumu ve iki yazma yetkisiyle `expected_revision`, Windows incelemesinden
alınan `evidence` ve `decision` alanlarını kabul eder. `keep_under_review`
eksik veya çelişkili kayıtlar için kullanılabilir. `acknowledge_saved_result`
yalnız sunucudaki `completed` kaydının sonuç özeti kanıtla birebir eşleşirse
kullanılabilir. Bu karar, Windows tarafında ACK eksikken de sunucuda saklanan
sonucun görüldüğünü kaydeder. İletilen Windows kanıtı operatör girdisidir.

`POST /api/deployment/staging-write/reconciliation/record` aynı alanlara
`review_hash` ve `acknowledge: record_reconciliation_decision` eklenmesini
ister. Sunucu revizyonu ve görev kaydını karar işleminde yeniden denetler.
İnceleme özeti oturumdan alınan operatör kimliğine, karara ve iki taraftaki
kayıtlara bağlıdır. Aynı isteğin tekrarı ilk denetim kaydının makbuzunu döndürür.
Karar yalnız denetim geçmişine eklenir. Görev durumu, Windows günlüğü,
kilitler ve dosya işlemleri bu iki çağrının kapsamı dışındadır.

`approve_refused_stage_lock_release` ayrı bir denetim kararıdır. Yalnız
yetki verilmeden reddedilmiş stage görevi, güncel Connector kapsamı, eşleşen
sonuç özeti ve Windows'ta doğrulandığı bildirilen ACK ile incelenebilir.
`reconciliation_receipt` önceki `acknowledge_saved_result` kararının
`revision` ve `review_hash` alanlarını içerir. Sunucu aynı operatör ve aynı
kanıt için önceki kararı denetim kaydından doğrular. İstek ayrıca Windows
incelemesinin `StageLockReleaseEvidence` nesnesini `stage_lock_evidence`
alanında ister. Sunucu iş, GPO, Connector kapsamı, niyet, sonuç ve beklenen
kilit özetini eşler. Yerel ACK ve tamamlanma özetlerini aynı onaya bağlar.
İnceleme ve kaydetme `stage_lock_evidence_sha256` döndürür. Kaydetme isteği
`acknowledge: record_stage_lock_release_approval` gerektirir. Onay denetim
kaydına eklenir. Yerel kayıtların tekrar doğrulanması, günlük geri yükleme
ve fiilî kilit açma ayrı kabul adımlarıdır.

`POST /api/deployment/staging-write/reconciliation/verify-lock-release`
aynı iki yetki, geçerli operatör oturumu ve CSRF ile kaydedilen onay isteğini
`approval`, makbuz revizyonunu `approval_revision` alanında kabul eder.
Sunucu onayı denetim geçmişinde aynı operatör ve aynı içerikle bulur, güncel
Connector kapsamını, kayıtlı ret sonucunu ve GPO üzerindeki diğer işleri
tek SQLite okuma işleminde yeniden denetler. Başarılı yanıt `approval_verified`
ve kanıt özetini içerir. Doğrulama yalnızca okuma yapar.

Varsayılan hizmette durum ve inceleme sonuçlarında `approval_enabled`,
`write_authorization_enabled`, `execution_adapter_available` ve `can_apply_gpo`
false'tur. İzole pilotta ilk üç bayrak HTTP yazma akışının ulaşılabilirliğini gösterir. Review hash'i kullanıcı
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
gerçek yönetici onay formu, imzalı teslim ve gerçek gMSA/SMB kabulü vardır. GPO aktivasyonu ayrıca açık kapıdır.
512 hedef sözleşmesi korunur. Bu değişiklik kurulu sürümü/ayarları veya gerçek
kapasite/saha kabulünü değiştirmez; tam veri yedeği almaz.
