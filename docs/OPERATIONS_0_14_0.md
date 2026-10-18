# AuthWire işletim ve kurtarma rehberi — dev.6

Bu rehber mevcut Ubuntu24.04 pilotunu işletmek ve doğrulamak içindir. Temiz
OVF/appliance import veya bütün kurum için yayılım kabulü değildir. Güncel saha
kanıtı ve tamamlanan alt işler [CURRENT_STATUS.md](CURRENT_STATUS.md) içindedir.

## Mevcut bileşenler

| Bileşen | Kalıcı kaynak / görev |
|---|---|
| Panel | kaname-lab.service, HTTPS8765; normal panel kullanıcıları ve CSRF |
| RADIUS | authwire-radius.service, UDP1812; ayrı native süreç |
| Servis kontrolü | authwire-service-control.service; sabit kapsamlı yerel socket |
| CRL | authwire-radius-crl-sync.timer; dakikalık aktarım, native önbellek300sn |
| Kaynak/runtime | /opt/kaname-lab/source, /opt/kaname-lab/venv, /opt/authwire-radius |
| İş verisi | /var/lib/kaname-lab; DB, CA/Issuer, keytab, kasa anahtarı, makbuzlar |
| HTTPS ayarları | /etc/kaname-lab; web.crt/web.key |
| Servis geçmişi | /var/lib/authwire-service-control; işlem kaydı ve son istek kimlikleri |

Pilot panel adresi kaname.vizyonveri.local /10.35.50.246:8765'tir. Switch
VV-SW10.35.50.253 ve AP OFIS-AP10.35.50.52 ayrı RADIUS istemcileridir; aynı
cloud profili/shared secret kullanılsa da kaynak IP ve erişim türü ayrı kalır.
Pilot VLAN110, karantina70'tir. Bunlar ürünün başka kurulumlarına varsayılan
adres veya VLAN olarak uygulanmaz.

## Günlük panel kontrolü

Mevcut Secure/HttpOnly/SameSite cookie doğrulanırken yükleniyor durumu görünür.
Gerçek401 giriş ister; geçici veri/bağlantı hatası tek başına yeniden parola
istememelidir. Yeni girişler toplam12saat, hareketsizlik2saat ile sınırlıdır;
arka plan panel istekleri de etkinlik sayılır. Önceki oturumların mutlak son
tarihleri güncellemede ileri alınmaz. İlk güncelleme sonrası bir Ctrl+F5 yeterlidir.

SQLite BUSY/LOCKED, STORE_BUSY olarak ayrılır. Yalnız bu503 salt okuma isteği
200/600ms aralıkla en fazla iki kez yinelenir; toplam bekleme ilk zaman aşımı
sınırı içindedir. Parola, POST, policy, sertifika ve servis işlemleri tekrarlanmaz.
PANEL_DATABASE_ERROR kaydı yalnız alan, yöntem, sayısal SQLite kodu ve geçici
olup olmadığını içerir. URL/SQL/parola/keytab/anahtar/makbuz içeriği kayda konmaz.
Tek hata kaydı, son kullanıcıya hatanın yansıdığını veya veritabanı bozulmasını
tek başına kanıtlamaz. F5 kabulü ayrıca gerçek kullanıcı tarayıcısında yapılır.

## Servisler

Yönetim → Servisler bölümünde RADIUS start/stop/restart, CRL senkronizasyonu ve
zamanlayıcı start/stop vardır. Panel kendi kendini bu ekrandan durdurmaz.
CRL oneshot'ın “Bekliyor · Son çalışma başarılı” görünmesi normaldir. Ayrı
system.services hakkı gerekir; salt okunur profil işlem başlatamaz. Başlat/durdur
boot-enable tercihini değiştirmez. RADIUS restart sırasında yeni kimlik doğrulama
istekleri etkilenebilir; çalışan RADIUS'u durum okumak için yeniden başlatmayın.
Bu ekran canlı switch portu/kullanıcı oturum envanteri veya accounting değildir.

## Yedek kapsamı

Yedek DB, CA/Issuer şifreli asılları, korumalı secret'lar, bunların kasa anahtarı,
web/RADIUS sertifika ve anahtarları, HTTP keytab, yönetici hesapları, profiller ve
kimlik bağlarını birlikte içermelidir. Kaynak/runtime ve unit'ler de saklanır.
Servis yardımcısı kodu, işlem geçmişi ve unit'i kapsamda olmalıdır. İstemciye ait
nonexportable CNG özel anahtarları sunucu yedeğinin içinde değildir.

SQLite online backup ve integrity_check kullanılır; canlı DB/WAL dosyalarını
rastgele kopyalamak tutarlı yedek kabul edilmez. Root-only tar ve SHA256/manifest
lokal koruma sağlar; dışarıda ikinci kopya veya şifreli off-host yedek kabulü
ayrıdır. Arşiv CA/servis sırları içerir; genel paylaşım veya sohbet eki değildir.

## İzole veri geri yükleme provası

[offline_restore_check.py](../tools/offline_restore_check.py), doğrulanmış arşivden
sunucu verisi/ayar/kaynak/unit'leri yalnız yeni bir özel çalışma dizinine açar.
Mutlak/kaçış/çift yolları, özel dosyaları ve restore veri ağacındaki linkleri
reddeder; venv/native runtime linklerini materialize etmez. Dosya hash'leri ile
UID/GID/izinler kontrol edilir. Canlı uygulama yolları çalışma alanı olamaz.

Kontroller: iki SQLite integrity/FK denetimi; ayar/policy/yönetici kayıtları;
CA zinciri ve şifreli anahtar varlığı; kasa sırlarının çözülebilmesi; geri gelen
Issuer anahtarının doğru public key'e bağlılığı ve sertifika/CRL olmayan bir
metni imzalayabilmesi; web/RADIUS anahtar eşleşmesi; imzalı güncel CRL;
sertifika seri/imza ve enrollment tabloları. Deşifre edilen değerler yazılmaz.
Geri yüklenen program çalıştırılmaz, servis/LDAP/KDC bağlantısı başlatılmaz.
Geçici kopya silinir; sonucu arşiv SHA'sına bağlı ayrı özel JSON kanıtı taşır.

Bu sonuç **sunucu verisi geri yükleme alt işi** için kanıttır. Runtime bağımlılıkları,
OS kurulumu, gerçek servis boot'u, temiz hypervisor import, rollback ve clone
kimlik ayrımı bununla tamamlandı sayılmaz. Orijinal backup manifestindeki genel
restore_tested=false, ayrı data_restore_exercised=true kanıtıyla aynı kapsam değildir.

## Gerçek bir kurtarmada kalan kapılar

1. Mevcut üretimi durdurma/değiştirme ayrı ve planlı bir kurtarma işlemidir; bu
   doğrulayıcı otomatik olarak canlı dizinlere geri yükleme yapmaz.
2. Geri dönecek noktanın tarihini ve yedekten sonraki sertifika/iptal/policy
   değişikliklerini uzlaştırın. Eski bir DB'ye dönmek sonradan iptal edilmiş bir
   kimliği tekrar geçerli gösterebilir. Bu kayıtlar belirlenmeden RADIUS açılmaz.
3. DB, secret-store.key, CA, keytab ve sertifikaları aynı doğrulanmış noktadan
   doğru sahip/izinlerle geri getirin. Uyumlu runtime ve unit kurulumunu doğrulayın.
4. DNS/SPN/keytab/TLS adı, saat ve Issuer geçerliliğini kontrol edin. Eski yedeğin
   CRL'si süresi dolmuş olabilir; güncel iptal durumunu koruyarak imzalama/CRL
   üretimini doğrulayın. Sadece eski CRL'yi kopyalamak kurtarma kabulü değildir.
5. Dış ağdan izole kopyada boot/HTTPS/DB/kimlik kontrollerinden sonra planlı ağ
   geçişi ve gerçek Accept/Reject testi gerekir. Aynı sunucu kimliğine sahip iki
   kopyayı üretime paralel bağlamayın. İki bağımsız yeni kurulum ayrı kimlik üretir.

## GPO paketinin salt okunur denetimi

[AuthWire-GPO-Audit.ps1](../tools/AuthWire-GPO-Audit.ps1), DC üzerinde paket imzaları,
aynı Code Signing yayıncısı/EKU, güncel script gövdeleri, imzalı kurucuya gömülü
config/trust hash'leri, URL/domain/SPN/TLS pini/Root, Issuer zinciri ve geniş yazma haklarını inceler.
İmza eklendiğinde script raw hash'i değişir; bu nedenle body hash ve gerçek
Authenticode doğrulaması birlikte kullanılır. İmzayı atlayan bir kontrol değildir.

Denetim betiği de kurumun normal script yürütme politikasına uyar. AllSigned
gerekiyorsa mevcut güvenilir kod imzalama sertifikasıyla yalnız denetim kopyası
imzalanır; private key dışarı verilmez ve yürütme politikası gevşetilmez.

GPO adı AuthWire-Pilot-Trust, pilot paket yolu gerçek GPO GUID'sinden türetilir.
Startup scripts.ini/psscripts.ini içinde Install-AuthWire çağrıları, açık AllSigned,
Bypass ve çift kayıtlar raporlanır. Şüpheli durumları raporlar; kendisi GPO, ACL,
sertifika deposu, görev veya Windows istemcisi değiştirmez ve kurucuyu çalıştırmaz.

Görev gerçekte Startup+09:00+21:00 tetikler; ayrı network-event tetikleyicisi yoktur.
NetworkAvailable/StartWhenAvailable çalışma koşullarıdır. DC paket denetimi,
VV06'nın GPO'yu tekrar aldığını veya SYSTEM görevinin istemcide çalıştığını
kanıtlamaz. Bu kabul cihazın sonraki saha testine aittir.

## İş planında açık kalanlar

VV06'da EAP'nin seçtiği yeni leaf ve yerel12saat temizlik; gerçek kullanıcı
kimliği pilotu; accounting/oturum korelasyonu; full restore/boot/rollback ve temiz
appliance kapıları açıktır. Sunucudaki24saat predecessor retirement, registry ve
imzalı runtime CRL ile uzaktan ayrıca doğrulanabilir; Windows cleanup ile karıştırılmaz.


Planlı yerel yedekleme kurulumu, saklama ve tanılama için
[SCHEDULED_BACKUPS.md](SCHEDULED_BACKUPS.md) belgesini kullanın. Bu bileşenin canlı
kabul durumu CURRENT_STATUS.md içindedir; off-host kopya ayrı bir kapıdır.
