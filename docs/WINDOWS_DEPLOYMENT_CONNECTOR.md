# Merkezi Windows dağıtımı — sınırlar ve sonraki uygulama

24 Ekim 2026. A04 bütünü açıktır. Bu belge bir Windows bileşeninin
kurulduğu veya GPO yazıldığı anlamına gelmez.

## Standart AD hazırlık giriş noktası — bootstrap v1

`windows/connector/Initialize-AuthWireWindows.ps1` ve yanındaki README, tekrar
kullanılabilir DC hazırlık giriş noktasıdır. Inspect varsayılanı salt okunurdur;
PrepareAccount ayrı açık moddur ve KDS beklemesi/yapılandırması, kurulum sahipliği,
tek hedef bilgisayar ve ad/izin çakışması kontrollerini geçmeden gMSA oluşturmaz.
Var olan KDS kökü, GPO, istemci ve sertifikalar korunur; uygun hesap tekrarında
onarım/yazma yoktur. Bu giriş noktası çalışan connector, GPO uygulama veya servis
kurulumu değildir. Önce gerçek Inspect, sonra KDS kullanılabilirliği ve hesap
hazırlığı kabul edilecektir. GPO delegasyonu, yerel hizmet oturumu, imzalama anahtarı
erişimi, yönetim TLS/protokolü ve uç kabulü sonraki ayrı kapılardır.

Müşteride bir defalık yetkili kurulum sonrası kontrollerin standart akışta
yürütülmesi hedefi korunur; günlük dağıtım AuthWire üzerinden olacaktır.
Mevcut v1 elle başlatılan hazırlıktır; panelden tam otomasyon olarak sunulmaz.

## dev.34 hazırlık teslimi

Sertifikalar → Dağıtım ekranı sürümlü plan, bilgisayar AD grubu, ayrı kullanıcı
sertifika profili/hedefi, makine sertifika profili, Ethernet/Wi-Fi, SSID ve
EAP-TLS kimlik türünü tutar. Kayıt global revision + plan version ile korunur.
Son beş eski tanım sunucuda saklanır; bu geçmişin tutulması çalışan GPO'yu
geri alma kabulünün tamamlandığı anlamına gelmez.

Önizleme AD eşitleme zamanını ve ayrı kullanıcı/bilgisayar sayılarını gösterir.
Sayılar önbellek üyeliğidir; GPO uygulanması, sertifika kurulması veya gerçek
802.1X başarısı olarak gösterilmez. Etkin profil/hedef, üyelik çözümü ve RADIUS
sertifika zinciri/SAN/EKU/süre/iptal durumu doğrulanmadan XML paketi üretilmez.
Önizleme özeti planı, profil sürümlerini, katalog içeriğini, yapılandırmayı ve
sertifikaları bağlar. Veri değişirse eski özetle paket alınamaz.

XML paketi yalnız public CA/issuer, LAN/WLAN EAP-TLS profilleri, plan/önizleme
ve SHA256 dosya manifestini içerir. Özel anahtar, parola, PFX, çalıştırılabilir
istemci veya GPO uygulama betiği içermez. Paket tek başına Authenticode imzalı
bir dağıtım komutu değildir. JSON içindeki örnek hedefler sınırlı tanıtım
bilgisidir; gerçek GPO güvenlik filtresinin yerine geçmez.

Mevcut sertifika kayıt istemcileri ve elle yönetilen GPO paketleri aynen
korunur. Kullanıcı planı, kullanıcının hangi bilgisayarda oturum açacağını
varsaymaz. İlk hedefleme AD gruplarıyla sınırlıdır; OU hedefleme henüz yoktur.

## Sonraki kapı: bir defalık Windows yetkilendirmesi

- Müşteri yöneticisi, domain'e bağlı uygun Windows yönetim makinesinde
  sınırlı bileşeni kurar; hangi OU ve AuthWire'a ait hangi GPO'ların yönetileceği
  açıkça belirlenir. Mevcut LDAP okuma hesabına GPO yazma yetkisi verilmez.
- Servis kimliğinin türü mevcut AD/Windows/KDS kabiliyetleriyle doğrulanır.
  Destek varsa gMSA değerlendirilir; bulunduğu varsayılmaz. Kullanıcı parolası
  Linux'a/panele/JSON'a taşınmaz. Kimlik ve imzalama erişimi Windows'un korumalı
  mekanizmalarıyla sınırlandırılır.
- Kurumsal kod imzalama özel anahtarı Windows'ta kalır. Mevcut CurrentUser
  yönetici sertifikasının bir servis hesabınca kullanılabileceği varsayılmaz;
  sertifika deposu, CNG/CSP anahtar ACL'si ve güvenilen yayıncı ayrı doğrulanır.
- Bileşen yalnız sabit AuthWire işlem türlerini kabul eder. Keyfi PowerShell,
  komut, registry yolu, SYSVOL yolu, etki alanı, GPO veya OU çalıştırılamaz.
  Kimlik doğrulanmış olmak tek başına GPO yönetme yetkisi değildir.
- Bileşen/panel iletişimi yerel HTTPS üzerinden, karşılıklı doğrulanmış ayrı
  yönetim kimliğiyle bağlanır. Normal NAC kullanıcı/bilgisayar sertifikasının
  yönetim bileşeni yetkisi kazandırmasına izin verilmez. Yönetim hesabı/GUID/SID,
  makine ve izinli işlemler kayıtlı olmalıdır. Protokol, nonce/son kullanma,
  iş kimliği, sonuç idempotensi ve yeniden oynatma kontrolleri kabul edilmeden
  panelden yürütme açılmaz. Bulut servisi gerekmez.

## GPO hazırlama ve uygulama

1. Yetkili bileşen AD'yi güncel olarak okuyup domain/GUID/SID, grup üyeliği,
   hedef OU kapsamı, GPO delegasyonu ve paylaşım ACL'lerini doğrular. Önbellek
   önizlemesiyle önemli hedef farkı yeni önizleme gerektirir.
2. Ürün sahipliği kayıtlı, benzersiz GUID'li GPO kullanılır. Aynı ada sahip
   müşteri GPO'su sahiplenilmez; AuthWire dışı GPO değiştirilmez.
3. İmzalı istemci ve güven varlıkları için sürümlü paket hazırlanır.
   İmzadan sonra varlık değiştirilirse reddedilir. AllSigned ve aynı kurumsal
   yayıncı korunur. Publisher/CA güveni önceden uygun bilgisayar/kullanıcı
   kapsamına dağıtılır; Bypass, ortak PFX veya sertifika hatası kabulü eklenmez.
4. SYSVOL yayını desteklenen GPMC/GroupPolicy mekanizmalarıyla yapılır.
   Eski scripts.ini/psscripts.ini çift giriş problemi tekrarlanmaz; AD ve GPT
   sürümleri/uzantıları/DC çoğaltması birlikte doğrulanır. Paylaşım ve dosya
   yolları sabit domain ve GPO kapsamına bağlıdır; reparse/UNC yönlendirme ve
   geniş yazma hakkı reddedilir.
5. İlk aşama istemci ve sertifika güveninin dağıtımıdır. Başlangıç/logon,
   SYSTEM bilgisayar ve Limited InteractiveToken kullanıcı sınırları korunur.
   Sonraki aşamada gerekli sertifika/özel anahtar kurulum teyidi gelmiş pilot
   cihazlarda ağ profilleri uygulanır. Sertifikasız hedeflerde 802.1X profilini
   erken değiştirip yönetim erişimi kesilmez; bootstrap erişimi doğrulanır.
6. OU bağlantısı ve güvenlik filtreleri farklı kullanıcı/bilgisayar kapsamını
   korur. Grup listesi OU kapsamını aşma yetkisi vermez. Kural VLAN'ını policy
   motoru belirlemeye devam eder; dağıtım planı VLAN yetkisi oluşturmaz.

## Durum, hata ve geri alma

Panel ayrı durumları gösterecek: taslak, önizlendi, imzalandı, GPO hazır,
uygulanması bekleniyor, istemci ulaştı, sertifika teyit edildi, ağ profili
uygulandı, gerçek 802.1X doğrulandı, başarısız veya geri alındı. GPO yazımı
sertifika kurulumu; sertifika receipt'i de RADIUS başarısı sayılmaz.

Her iş sürüm/hedef/işlemi yapan yönetici ile denetlenir. Yanıt kaybolduğunda
iş kimliği üzerinden sonuç okunur; yeni kimlikle aynı değişiklik tekrarlanmaz.
Başka yönetici/GPO sürümü değişmişse otomatik üzerine yazılmaz. Kısmi yayında
önceki AuthWire paket/GPO sürümüyle sınırlı geri alma yapılır; yeni sertifikalar
veya müşteri verisi topluca silinmez/iptal edilmez. Yetki iptalinde yeni iş
alınmaz; zamanlanmış işin devamına yetki varsayılmaz.

## Açık kabul sırası

1. Windows delegasyon/imzalama/iletişim bileşeni ve izole yerel testler.
2. Yetkili müşteri AD'sinde salt okunur kapsam/izin farkı önizlemesi.
3. 5–10 bilgisayarlık pilotta GPO/receipt, kullanıcı logon'u ve cihaz
   başlangıcı; Ethernet/Wi-Fi, user/machine geçişi, yanlış hedef reddi,
   kesinti ve geri alma. Gerçek cihaz çalışması pazartesiye bırakıldı.
4. Kademeli ölçek kabulü: 200 ilk basamak,500/1000 teknik doğrulama hedefleri. Gerçek saha ve yük fixture kanıtı ayrı kaydedilir. Mevcut tek scope görevi512 hedefle sınırlı; güvenli parçalama/bütünlük/sonuç birleştirme henüz uygulanmadı. Ayrıntı: CAPACITY_AND_ACCEPTANCE.md.

dev.34'te bu dört kapıdan hiçbiri tamamlanmış sayılmaz. Güncel durum
CURRENT_STATUS.md dosyasındadır.

## Profil biçimi için birincil kaynaklar

- https://learn.microsoft.com/en-us/windows/win32/nativewifi/machine-certificate-profile-sample
- https://learn.microsoft.com/en-us/windows/win32/nativewifi/lan-profileschema-elements
- https://learn.microsoft.com/en-us/windows/win32/nativewifi/onexschema-elements
- https://learn.microsoft.com/en-us/windows/win32/eaphost/eap-tls-connection-properties
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpwl/5885c241-4052-4573-944f-7f41290f92a8

XML üretim ve parse testleri gerçek Windows kartına profil uygulama veya GPO
protokol kabulünün yerine geçmez. Sunucu adı ve kök pin'i açıktır; kimlik türü
OneX authMode olarak belirtilir. machineOrUser iki kimliği aynı anda doğrulayan
bir protokol olarak sunulmaz; oturum geçişi ayrı saha kabulüdür.
