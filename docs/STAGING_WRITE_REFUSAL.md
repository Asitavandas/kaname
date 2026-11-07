# Yetki öncesi ret bildirimi

G01/A04 kaynak alt adımı, 6 Kasım 2026. Gerçek expired-pending saha testi
8 Kasım doğal süre dolumunu beklerken bağımsız geliştirme olarak seçildi.
Geçmiş yenileme/boot/retry/retention kabulleri tekrar açılmadı.

## Davranış

Kalıcı stage/rollback lifecycle, POLL yanıtı ve yerel offer başarıyla kaydedilip
preflight başarısız olduğunda, aynı iş için hiçbir CLAIM başlangıcı veya başka
belirsiz kayıt bulunmuyorsa `refused_before_authorization / PREFLIGHT_FAILED`
sonucunu sabitler. `authorization_id`, journal/tree özetleri boştur;
`filesystem_effects=none` yalnız bu işin Connector bildirimidir. Diskin bağımsız
doğrulanması veya önceki stage dosyalarının yokluğu anlamına gelmez.

Bu sürüm child stderr/exception metninden kapsam veya imza nedeni tahmin etmez;
preflight ayrıntıyı kaybettiyse dürüstçe genel kontrol hatası bildirir. Sunucunun
mevcut beş sabit ret kodu panelde Türkçe açıklanabilir. Ham hata, yol, proof,
lease ve anahtar bilgisi panel durum yanıtına eklenmez.

Kayıt orijinal imzalı POLL/yanıt, binding/release, dispatch ve başarısızlık
kanıtlarına bağlıdır. Özgün lease içinde ve hatadan en çok beş saniye sonra
CreateNew/Flush(true) ile dondurulur. Aynı işin CLAIM üretimi/taşıması ile ortak
nonblocking karar mutex'i vardır. Kısmi outbox dosyası da CLAIM'i engeller.
CLAIM başlangıcı, kayıp grant/receipt, yetkilendirme, tüketim, yürütme veya
bilinmeyen kayıt varken "etki yok" bildirimi üretilemez. Bozuk ACL, reparse,
hardlink/ADS ve şema farkı native pin'lerle reddedilir.

## Teslim ve yeniden başlatma

Her çağrı en çok bir mevcut RESULT POST'u gönderir; iş başına en çok üç kalıcı
deneme vardır. Deneme imzalamadan/ağdan önce saklanır. Her yeni proof aynı
dondurulmuş gövdeyi taşır; özgün zaman ve ret nedeni değişmez. HTTPS ad/zincir/
revocation ve eşleştirilmiş pin, beş saniye ve mevcut byte sınırları korunur.
ACK yalnız aynı request/job için kabul edilir. Kayıp ACK'de aynı gövdenin
sunucuya tekrar bildirimi idempotenttir; yeni audit geçişi oluşmaz.

Yeniden başlatma yalnız mevcut outbox'u gönderir veya kabul kaydını doğrular.
Eksik/yarım outbox için geç tarihli ret yaratmaz; preflight/CLAIM/yazma/silme
tekrarlamaz. İlk bildirim lease bittikten sonra sunucu tarafından kabul edilmez;
bu sınır değiştirilmedi. Kayıp kabul yanıtının eş gövdeli tekrarına mevcut core
kuralı uygulanır. Üç deneme, disk/şema hatası veya belirsizlik inceleme gerektirir.

Kabul edilmiş ret de yeni POLL'u durduran kalıcı sınırdır. GPO kilidi ve rollback
reservation tutulur; otomatik unlock, retry, yeni iş veya arşivleme yoktur.
Kontrollü uzlaştırma ve ayrı onaylı kilit açma sonraki bağımsız iştir.

## Kabul sınırı

HTTP durum yanıtı yalnız doğrulanmış sonuçtan sabit reason/effect/time alanlarını
verir. Panel başarılı dağıtımla yetki öncesi reddi ayırır; belirsiz sonuç için
dosya etkisinin kesinleşmediğini söyler. Tutarsız/unknown sonuç güvenli ret olarak
gösterilmez. Mevcut çift rol/session kontrolleri ve kapalı create/peer kapıları korunur.

Yeni native test disposable GitHub Windows ortamında gerçek CNG/proof/HTTPS ve
SQLite çekirdeği kullanır. Preflight hatası ve olumlu AD/content/service kimliği
gözlemleri açık fixture yerine koymalarıdır. Ayrı rollback ret vakası önce gerçek
test SMB stage'ini kullanır. Bu; müşteri AD/gMSA, aktif worker, gerçek reboot,
Linux/DC01 kurulumu veya uç saha kabulü değildir. Önceki genel testlerin tekrar
koşması kaynak regresyonudur; geçmiş pilot kabulünün tekrar yapılması değildir.

Kaynak worker/paket/peer'e kaydedilmez. Canlı sürüm, sertifika, Ethernet1,
AD/GPO/SYSVOL ve bekleyen doğal süre dolumu görevi bu geliştirmede değiştirilmez.
Yerel geçmiş saklama tamamlanmış önceki iştir. Windows journal yedek/restore,
belirsiz kayıt uzlaştırması, ayrı onaylı unlock, aktif scheduler/SCM ve kontrollü
müşteri teslimi açık kalır. Bütün G01/A04 veya ürün kabulü kapanmaz.
