# RADIUS erişim kayıtları — dev.9

İzleme → Erişim kayıtları, açıkça etkinleştirildiği andan itibaren native
FreeRADIUS'un post-auth aşamasında seçtiği son Access-Accept/Access-Reject
yanıtlarını saklar. EAP parçaları/Access-Challenge satır üretmez. Mevcut
İşlem geçmişi yönetim değişiklikleri içindir; bu iki kayıt kaynağı ayrıdır.

## Kaydın anlamı

- Kabul, sunucunun seçtiği yanıtı gösterir. NAS'ın teslim aldığı, Windows'un
  kimlik doğrulamasını bitirdiği, DHCP veya uçtan uca ağ erişimi kanıtı değildir.
- Policy callback allow sonucu tek başına kayıt oluşturmaz. Son yanıt ret ise
  kabul kaydı yazılmaz; policy izninden sonra ret ayrı neden kodudur.
- İptal/expired/issuer/purpose gibi callback öncesi native TLS retleri de
  son yanıt aşamasından alınır. Yalnız tanınan native tanı mesajları sabit bir
  kategoriye dönüştürülür; ayrıntı belirlenemiyorsa NATIVE_ACCESS_REJECT olur.
  Native mesajdaki zincir hatası tek başına hangi tarafın sertifikayı
  reddettiğini her durumda kanıtlamaz. Ham hata mesajı kalıcı kayda konmaz.
- TLS callback'i çalışmadığında seri/GUID/kimlik türü boş kalır. Outer
  User-Name, sertifika subject'i veya istemcinin NAS-IP-Address iddiası
  güvenilir cihaz/kullanıcı kimliği olarak kullanılmaz.
- NAS IP gerçek paket kaynağıdır. MAC varsa yalnız biçimi kontrol edilmiş
  Calling-Station-Id'dir; NAS bildirimi diye etiketlenir, sertifika kimliği değildir.
  Hostname tahmini yapılmaz. Policy ID ve kayıtlı object GUID tarihsel satırda
  tutulur; sonradan başka ad/grup bilgisi bu kayda tarihsel gerçek diye eklenmez.
- VLAN yalnız final kabul yanıtındaki geçerli Tunnel-Type/Medium/Group
  üçlüsünden alınır. Ret satırında VLAN yoktur.
- Geçersiz/eksik Message-Authenticator, tanımsız NAS veya yarım kalmış EAP
  gibi yanıt üretilmeden düşürülen girişimler bu tabloda yoktur.
  Accounting Start/Interim/Stop ve tam oturum korelasyonu bu adımla eklenmedi.

## Tekrarlar ve dayanıklılık

Sunucunun oluşturduğu kaynak IP/port + request authenticator özeti paket
korelasyon ID'sidir; ham authenticator saklanmaz. Paket özeti + final yanıt
kodu olayın benzersiz anahtarıdır. Aynı yanıtın tekrarı/restart sonrası tekrar
tek satırdır; aynı pakete farklı final kod seçilirse ayrı olay kalabilir.
Yeni kimlik doğrulama yeni authenticator ile ayrı kayıttır. Bu anahtar EAP
oturumu veya accounting session ID değildir.

Kayıtlar /var/lib/kaname-lab/radius-events/access.sqlite3 içinde uygulama
hesabına ait0700 dizin/0600 dosyada, ayrı SQLite bağlantısıyla tutulur.
Başarılı yazma FULL synchronization ile commit edilir. Update/delete
trigger'ları yerindedir; otomatik silme veya trigger kaldırma yoktur.

200.000 kayıt **veya64MB**, önce dolan sınır geçerlidir.128MB boş disk altına
düşülünce yeni kayıt yazılmaz. Bu sınır mevcut offline restore aracının128MB
dosya sınırının içindedir. SQLite kilit bekleme25ms'dir; dosya sistemi/fsync
gecikmesi için kesin gerçek zaman garantisi yoktur. Kayıt yazımı PKI/policy/
enrollment DB'lerine yazmaz. Auth-Type ve reply attributes logger'dan dönmez.

Kayıt hatası yetkilendirme sonucunu değiştirmez. Dolayısıyla kayıtlar için
kayıpsız teslim garantisi verilmez. Sabit AUTHWIRE_ACCESS_EVENT_DROPPED
uyarısı, hata kodu ve süreç sayacı rate-limit ile servis günlüğüne yazılır;
ham istek/parola/MPPE key/sertifika PEM veya hata payload'ı yazılmaz.
Paneldeki süreç sayaçları /run/authwire-radius/observer-status.json üzerinden
son gözlemdir: süreç yeniden başladığında sıfırlanır, her yazıma kalıcı sağlık
günlüğü değildir. Durum dosyası da yazılamıyorsa gösterge bulunmayabilir.
Son gözlem zamanı incelenmeli; sıfır düşen kayıt, eksiksiz geçmiş kanıtı sayılmaz.

## Panel/API ve CSV

GET /api/radius/events audit.events okuma hakkı gerektirir. Kaynak henüz
hazırlanmamışsa boş/uninitialized döner; okuma bir DB/dizin oluşturmaz.
Filtreler result=accept/reject, nas (gerçek kaynak IPv4), reason (sabit kod),
q (seri/GUID/policy/MAC), timezone içeren from/to, before ve watermark'tır.
100 satır, azalan ID, ilk okuma üst sınırı ve iki saniye sorgu bütçesi vardır.
Metin eşleşmesi literal/ASCII lower'dır; tam Türkçe Unicode casefold vaadi yoktur.

CSV yalnız görünen sayfayı içerir; virgül ayırıcısı, UTF-8 BOM, CRLF/çift
tırnak kaçışı ve formül başlangıcı koruması kullanır. Excel'de tek sütun
açılırsa Veri → Metin/CSV'den → UTF-8 / Virgül seçin. İndirme kayıtları silmez
veya sunucu arşivi oluşturmaz. Liste hatası panel oturumunu kapatmaz;
çıkış/yetki kaybında eski liste/indirme kullanılamaz.

## Etkinleştirme ve geri alma

Varsayılan runtime üretimi gözlemciyi etkinleştirmez. Yalnız --access-events
bayrağı kullanılır. Başlangıçta kayıt DB'si hazırlanamıyorsa orijinal
yetkilendirme modülüyle EAP-TLS devam eder ve ACCESS_HISTORY_UNAVAILABLE
durumu üretilir. Etkinleştirme aracı bunu başarı kabul etmez.

tools/radius_events_install.py, sudo ile ve doğrulanmış kaynak güncellemesi
sonrasında çalıştırılır. Base unit'i/native modülü değiştirmez; yalnız
30-access-history.conf drop-in'i generator'a bayrağı ekler. Önce gerçek servis
hesabıyla ayrı private runtime oluşturup radiusd -XC kontrolü yapar. Ardından
RADIUS kontrollü yeniden başlatılır; aktif PID, UDP listener ve etkin gözlemci
durumu doğrulanır. Broker/panel restart edilmez. Başlangıç başarısızsa eklenen
drop-in ve bu araçça değiştirilen backup worker/release geri alınır, önceki
generator ile RADIUS yeniden başlatılıp listener kontrol edilir. Kayıt DB'si
ve kullanıcı verileri geri alma sırasında silinmez. Bilinmeyen kaynak/override
ve dışarıdan değişmiş dosyalar üzerine körlemesine yazılmaz.

Yedek worker'da yalnız access_events tablosu iş durumu istikrar karşılaştırması
dışına eklenir; satırlar SQLite backup ile arşive tamamen kopyalanır. Servis/
timer/saklama saati değişmez. Yeni paket için ayrı scheduled-backup-access-history
checkpoint'i vardır; önceki kurulum checkpoint'i tarihsel haliyle korunur.
Etkinleştirme launcher'ı önce/sonra yeni managed yedek alır, kritik dosya/mod/
sahip/PID/timer/iş durumu kanıtını tutar ve son arşivde izole PKI/veri restore
kontrolünü erişim DB bütünlük/sütun okumasıyla genişletir. Restore edilmiş kod
ve servisler çalıştırılmaz. İleride de aktif logger varken kod güncellemesinden
önce doğrulanmış SQLite managed yedeği alınmalıdır; updater'ın ham durum dizini
kopyası tek başına erişim geçmişi restore kabulü sayılmaz.

Canlı operatör ekran/CSV ve gerçek VV06/AP/switch olay eşleştirmesi ayrı kabul
kapılarıdır. Bunlar olmadan bu alt işin saha kabulü tamamlandı denmez. B11
accounting, tam korelasyon, dış arşiv/saklama/temizlik kapsamı açık kalır.
