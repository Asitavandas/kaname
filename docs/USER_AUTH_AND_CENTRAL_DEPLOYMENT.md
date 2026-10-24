# AuthWire kullanıcı kimliği ve merkezi Windows dağıtımı

Tarih: 24 Ekim 2026, Europe/Istanbul.
Durum: A03/A04 kapsamı açık. Güncel ilerleme kaydı: CURRENT_STATUS.md.
Bu belge mevcut kullanıcı kimliği ve merkezi dağıtım yol haritasını açıklar.

## 🔴✓ Kullanıcı sekmelerinin tarayıcı kabulü tamam — 24 Ekim 2026

Operatör iki yeni sekmenin hatasız açıldığını doğruladı. Dev.32 canlı kurulum
ve sekme görünürlüğü kabulü tamam; kullanıcı sertifika dağıtımı, AD/GPO ve
gerçek kullanıcı 802.1X/VLAN testleri pazartesiye bırakılmış olarak açıktır.

## 🔴✓ dev.32 canlı kurulum doğrulandı — 24 Ekim 2026

Operatörün verified=true çıktısıyla dev.32 canlı uygulaması tamamlandı.
RADIUS yeniden başlamadı; RADIUS/broker süreçleri, korunan dosyalar, timer ve
önceden var olan iş verisi korundu. Kullanıcı profili oluşturulmadı. Policy,
sertifikalar, Windows/AD-GPO değişmedi; tam veri yedeği alınmadı.
Kullanıcı status API'si ve yeni JS dahil on sekiz yol üçer kez HTTP200 döndü.
Operatörün yeni sekmeleri tarayıcıda görme kabulü açık; gerçek kullanıcı
AD/GPO/802.1X saha testi pazartesiye bırakıldı. A03/A04 bütünü hâlâ açık.
Kanıt: checkpoints/2026-10-24-user-profile-panel-live-result.json.

## 🔴✓ A03 sunucu altyapısı teknik kabulü — 24 Ekim 2026

Ayrı kullanıcı Kerberos/MIC oturumu, kullanıcı AD kayıt profili, güncel GUID/SID
ve üyelik kontrolü, anahtar kanıtlı kayıt/teyit/yenileme, emeklilik/CRL ve yedek
şema desteği dev.30 kaynağında geliştirildi; 8 CI workflow, 665 Python testi
(28 ortama bağlı atlama), gerçek Kerberos/HTTPS kullanıcı kayıt akışı ve
mevcut bilgisayar/Windows/RADIUS regresyon kontrolleri geçti.

Bu kaynak kilometre taşı canlıya kurulmadı. Windows CurrentUser istemcisi,
kullanıcı profili panel yönetimi, kullanıcı grubu policy kimlik kapsamı ve
gerçek kullanıcı kablolu/Wi-Fi/VLAN/geçiş kabulü açıktır. A03 veya A04 bütünü
tamamlandı sayılmaz. Ayrıntılar: USER_ENROLLMENT_BACKEND.md ve
checkpoints/2026-10-24-user-enrollment-backend.json.

## 🔴✓ Kullanıcı Windows istemcisi/paketi teknik kabulü — 24 Ekim 2026

Ayrı CurrentUser CNG istemcisi, imzalanabilir kullanıcı logon paketi, kullanıcı
SID/profiline ait state/retry, yeni anahtarla yenileme ve güvenli eski anahtar
temizliği dev.31 kaynağında hazır. Standart kullanıcı anahtar/görev izolasyonu,
gerçek Windows certreq/kurulum/yenileme, kesinti ve expired-pending toparlanma
testleri geçti. Altı CI workflow, 688 Python testi (28 atlama), zorunlu native
Kerberos/backend/HTTP 107 test ve mevcut Windows/RADIUS/tarayıcı kontrolleri
başarılı. PR62 main'e birleştirildi; canlı sürüm son doğrulamada dev.29 kalır.

Kod imzalayan yayıncı ve CA/HTTPS kök güveni onaylı GPO ile önceden dağıtılır.
Kullanıcı kurucusu kök depoya yazmaz; mevcut güveni kontrol eder. İmzalı iki
script açık config/CA varlıklarını bağlar. Özel anahtar veya kullanıcı parolası
pakete konmaz. Kullanıcı policy kimlik kapsamı, gerçek AD/GPO/kullanıcı
802.1X/VLAN kabulü ve tam merkezi otomasyon hâlâ açıktır. Teknik Windows
testinde Kerberos/HTTP taşıması ve AD sentetiktir; gerçek sunucu Kerberos/HTTPS
ayrı test edildi. Ayrıntı: USER_WINDOWS_CLIENT.md ve
checkpoints/2026-10-24-user-windows-client.json.

## 🔴✓ Kullanıcı profili panel yönetimi teknik kabulü — 24 Ekim 2026

Dev.32 kaynağında Sertifikalar → Kullanıcı profilleri / Kullanıcı kayıtları hazır.
Açık AD güvenlik grubu seçimi, süre/yenileme/kayıt izni, profil sürüm kontrolü,
kullanıcı paketi indirme ve kurulum teyidi/yenileme durumu yönetilir. Yeni profil
varsayılan kapalıdır. Kayıt iznini kapatmak sertifikayı iptal etmez; VLAN/ağ erişim
kararı bu profilde belirlenmez. Ayrı erişim grubu özelliği geri eklenmedi.

690 Python testi (28 atlama), yeni akış dahil 13 tarayıcı akışı ve mevcut
Windows/kullanıcı/backend/RADIUS kontrolleri geçti; altı CI workflow başarılı.
Operatör uzak bağlantıyı düzeltti. Dev.29 servisleri/timer aktif; kurulu kaynak,
updater ve staging ön kontrolleriyle yedi izole kurucu testi Linux'ta geçti.
Dev.32 kurucusu hazır, fakat özel DB/uygulama evresi yerel sudo parolası bekler.
Henüz canlı kurulum veya operatör panel kabulü yapılmadı. Gerçek test bilgisayarı kabulü operatör
isteğiyle pazartesiye bırakıldı. A03/A04 tamamlandı sayılmaz.
Ayrıntı: USER_PROFILE_PANEL.md ve checkpoints/2026-10-24-user-profile-panel.json.

## A03 — Kullanıcı kimlik doğrulaması (mevcut açık yol haritasının devamı)

- Kullanıcı EAP-TLS sertifikası üretim/kurulum/yenileme/iptal ve kullanıcı
  deposu/özel anahtar izinleri için gerçek Windows kabulü.
- Kullanıcı veya kullanıcı grubu politikasından kablolu/kablosuz VLAN kararı.
- Bilgisayar doğrulaması ile kullanıcı doğrulaması ve desteklenen
  kullanıcı/bilgisayar geçiş davranışı ayrı ayrı kanıtlanır. Windows'taki
  kullanıcı veya bilgisayar modu eşzamanlı iki kimlik kanıtı diye sunulmaz.
  TEAP ile eşzamanlı kimlik zincirleme bu onayla kendiliğinden eklenmez.
- Çalışan makine EAP-TLS pilotları ve bilgisayar sertifika yaşam döngüsü korunur.

## A04 — Merkezi Windows dağıtımı ve GPO tam otomasyonu (açık)

Hedef: Bir defalık yetkilendirilmiş müşteri kurulumundan sonra günlük dağıtım
ve yönetim AuthWire panelinden yürüsün; her bilgisayarın Ethernet/Wi-Fi
özellikleri elle açılıp düzenlenmesin.

- Panelden hedef OU/bilgisayar grubu, kayıt profili, kablolu ve kablosuz
  kimlik doğrulama yöntemi, SSID, sunucu adı ve güvenilen CA seçimi.
- CA güveni, sertifika kayıt/yenileme istemcisi ve görevleri, kablolu 802.1X
  profili ve WLAN EAP-TLS profili için sürümlü merkezi paket.
- Kullanıcı sertifikası dağıtımı için kullanıcı kapsamı; makine sertifikası
  ve ağ profilleri için uygun bilgisayar kapsamı ayrı tasarlanır. Seçilen
  kullanıcı listesinden kullandığı bilgisayarlar kendiliğinden varsayılmaz.
- Sınırlı yetkili Windows yönetim bileşeni üzerinden AuthWire'a ait GPO'nun
  oluşturulması/güncellenmesi/uygun kapsamına bağlanması. İlk yetki devri
  ve bileşen kurulumu müşteri yöneticisi tarafından bir kez yapılır.
- Günlük salt okunur AD eşitlemesi GPO yazma yetkisine dönüştürülmez.
  Mevcut LDAP hesabına sessiz Domain Admin yetkisi verilmez.
- İmzalı paket ve AllSigned korunur; kurumsal kod imzalama özel anahtarı
  AuthWire'a taşınmaz. Yetkili Windows imzalama/dağıtım yolu tasarlanır.
- GPO değişikliğinden önce hedef ve fark önizlemesi, kapsamlı hata raporu,
  kontrollü pilot yayılım, sürüm/geri alma ve işlemi yapan yönetici kaydı.
  İlgisiz müşteri GPO'ları/üyelikleri değiştirilmez.
- Panelden dağıtım, son uygulama/sertifika durumu ve hata/yeniden deneme
  takibi. GPO güncellemesi veya yeniden açılış gerektiren zamanlamalar
  görünür olur; anında uygulanmış gibi gösterilmez.
- İlk pilot sonrasında 200 kullanıcı/bilgisayar ölçeğinde kayıt, yenileme,
  politika/üyelik, GPO güncellemesi ve hata toparlama kabulü.

Mevcut durum: GPO ile pilot bilgisayar sertifika istemcisi ve SYSTEM görevleri
dağıtıldı/test edildi. GPO/SYSVOL hazırlığı merkezi fakat yetkili operatör
tarafından yapıldı. Ethernet/Wi-Fi profilleri pilotta elle ayarlandı.
Panelden GPO oluşturma/bağlama ve uçtan uca profil dağıtımı henüz yoktur.
Bu plan, bunların bugün hazır olduğunu veya 200 cihaz kabulünün geçtiğini
iddia etmez.

## Devam sırası ve koruma

1. Panel görsel işleri operatör isteğiyle beklemede.
2. Önce mevcut fonksiyonel kabul listesinin kaldığı yer doğrulanır:
   kullanıcı EAP-TLS yeni ana çalışma başlığıdır; önceki B02/B04/B06/B08/B10/
   B11/B12 açık alt işleri kendi kanıt sınırlarıyla korunur.
3. A03 kullanıcı/AD grubu policy kimlik kapsamı ve saha pilotu ile A04 merkezi dağıtım/GPO tasarım ve uygulaması,
   ardından kontrollü ölçek kabulü için ayrı tamamlanma kapıları açılır.
   Bu kayıt uygulama veya canlı değişiklik değildir.
4. Gerçek expiry testi ayrı cihaz bekliyor. Off-host yedek ve tam appliance
   restore/boot kabulü açık. NTP uzun süre/reboot izlemi duraklatılmıştır.
   DHCP/DNS dağıtım mimarisi operatör kararıyla kapsam dışı kalır.
5. Canlı sürüm dev.29'dur. Operatör kaldırma paketinin verified=true
   sonucunu doğruladı. Ayrı grup yönetimi aktif kapsamdan çıkarılmıştır.
   Doğrudan kullanıcı/bilgisayar ve AD grubu policy seçimi korunur.
   RADIUS planlı yeniden başladı ve aktif; broker, policy, CA/sertifika,
   Windows/GPO, AD üyelikleri, logo ve günlük yedek/CRL timer korundu.
   Son menü/seçici tarayıcı kontrolü ve gerçek uç regresyon kabulü bekliyor.
