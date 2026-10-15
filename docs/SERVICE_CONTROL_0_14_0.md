# Servis yönetimi 0.14.0 dev.5

## Kapsam

Sistem altındaki Servisler ekranı RADIUS, panel, CRL senkron görevi ve CRL
zamanlayıcısını gösterir. RADIUS start/stop/restart, CRL görevi için şimdi
senkronize et, zamanlayıcı için start/stop vardır. Panel yalnız izlenir.
Panelin kendisini yeniden başlatma sonraki aşamadır. Bu ekran accounting,
policy/VLAN uygulaması veya sertifika değişikliği yapmaz.

`system.services` ayrı read/write yetkisidir. SuperAdmin write, Admin_ReadOnly
read alır; mevcut Custom profiller bu hak açıkça verilmedikçe erişemez.
Mutasyon insan panel oturumu, doğru Origin, CSRF, onay ve UUID gerektirir.
Yerel maintenance bearer token servis mutasyonu yapamaz.

## Ayrıcalık sınırı

Web servisi mevcut kaname-lab kullanıcısı ve NoNewPrivileges korumasıyla kalır.
Root broker yalnız sabit dört unit adını bilir; istemciden yol, unit adı,
shell, argüman veya komut kabul etmez. Ağ portu açmaz. AF_UNIX soketi
root:kaname-lab 0660, üst dizini 0750; SO_PEERCRED hem istemci hem sunucu
tarafında doğrulanır. Yalnız panel UID'si ve root broker'a bağlanabilir.

Broker /opt/authwire-service-control/broker.py olarak root sahipliğinde
kurulur. systemd sandbox AF_UNIX/AF_NETLINK ile sınırlıdır; web birimi veya
RADIUS birimi değiştirilmez. CAP_SYS_PTRACE verilmez. Dinleyici kontrolü,
symlink izlemeyen sınırlı bir okumayla üretilmiş public listen stanza'sının
IP/port bilgisini ss çıktısıyla karşılaştırır. Bu transport hazırlığıdır;
başarılı bir EAP-TLS oturumu veya belirli bir PID'nin socket sahipliği kanıtı
olarak sunulmaz. RADIUS aktif olmalı ve beklenen UDP endpoint bulunmalıdır.

## İşlemler ve geçmiş

Başlat/durdur enable/disable çağırmaz; açılış ayarı korunur. Aynı anda tek
mutasyon çalışır. Son 100 UUID/işlem root'a özel kalıcı dosyada saklanır;
aynı UUID ve aynı istek tekrar komut çalıştırmaz, çelişen tekrar reddedilir.
Bu, sınırsız süreli idempotency deposu değildir. UI en son 20 işlemi gösterir.
Root'a özel kayıt başarısızsa işlem başlatılmaz. Panel audit tablosuna
istek/aktör kaydı önce yazılır; tamamlanma sonucu ayrı servis geçmişindedir.
Raw stdout/stderr, shared secret, token veya private key gösterilmez.

İşlemler asenkron kabul edilir; UI son durumu sorgular. İletişim zaman aşımı
mutasyonun otomatik tekrarını tetiklemez. Broker yeniden başlarsa yarım
işlem sonucu bilinmiyor olarak işaretlenir; işlem tekrar oynatılmaz.
Başlat/restart sonrası active durumu ve UDP endpoint; stop sonrası inactive;
CRL sync sonrası success/0 doğrulanır. CRL oneshot başarıyla bitip inactive
olduğunda bu hata değildir. Durdurulmuş RADIUS için sync başlatılmaz.

Panel/RADIUS yükseltmesiyle yarışmamak için mevcut root'a özel update lock
paylaşılır; servis işlemi shared lock, yükseltici exclusive lock alır.
Tmpfiles kaydı boot'ta /run içindeki lock'u tekrar oluşturur. Timer'ı
durdurmak periyodik CRL yayınına ara verir ve onay ekranı bunu belirtir.

## Kurulum ve geri dönüş

Test edilmiş kaynak mevcut korumalı linux_update yöntemiyle güncellenir;
ardından root sahipliğindeki `tools/service_control_install.py` çalıştırılır.
Kurucu eski broker kodunu/birimini root'a özel upgrade backup dizinine alır.
Yeni broker ve tmpfiles kaydını kurar; gerçek panel kullanıcısıyla socket
durum okumasını doğrular. Mevcut policy/CA/secret/yönetici durumu, Windows
istemcisi, native RADIUS modülü, panel/RADIUS unit dosyaları ve RADIUS PID
karşılaştırılır. Kurulum RADIUS start/stop/restart testini kendiliğinden yapmaz.

Kurucu hatasında önceki broker dosyası ve enabled/active tercihi geri yüklenir;
yeni kurulumsa helper ve eklenen unit/tmpfiles kaydı kaldırılır. History
arşivi ve ürün kimliği silinmez. Kaynak güncellemesinin geri dönüşü kendi
updater sözleşmesine tabidir. Root işlemler operatörün sudo parolasını gerektirir.

## Kabul sınırı ve iş planı

Ana takip B07, ilişkili B01/B11/B12. B11 accounting kapanmış sayılmaz.
Kaynak/yetki/HTTP testleri, gerçek disposable systemd ve tarayıcı fixture
kabulü tamamlandıktan sonra kurulum yapılır. Son saha read-only kontrolü ve
operatörün kontrollü RADIUS restart/reconnect kabulü ayrı kaydedilir.
İş bitince VV06 eski/yeni sertifika seçimi, 12 saat yerel temizlik ve ayrı
24 saate kadar sunucu emekliliği; sonra kullanıcı EAP-TLS pilotuna dönülür.
Mevcut geçerli eski sertifika elle silinmez veya iptal edilmez.
