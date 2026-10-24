# AuthWire kullanıcı kimliği ve merkezi Windows dağıtımı

Tarih: 24 Ekim 2026, Europe/Istanbul.
Durum: A03/A04 kapsamı açık. Güncel ilerleme kaydı: CURRENT_STATUS.md.
Bu belge mevcut kullanıcı kimliği ve merkezi dağıtım yol haritasını açıklar.

## 🔴✓ dev.34 merkezi Windows hazırlık ekranı canlı kurulum tamam — 24 Ekim 2026

- 🔴✓ Operatör WINDOWS_PREPARATION_FINISHED / verified=true / version0.14.0-dev.34 sonucunu paylaştı. Kaynak `8bcc043b1d763f79e1c071241d755ec1c6a8ead4` canlıya uygulandı; yerel sudo/kurulum beklemesi kapandı. Kanıt: `/var/lib/authwire-updates/windows-preparation-dev34-20261024T173830Z-e0334c8c`.
- 🔴✓ RADIUS yeniden başlamadı; PID1243360aynı kaldı ve aktif. Broker süreci, korunan dosyalar, timer ve iş verisi karşılaştırmaları başarılı. Policy, CA/sertifika, Windows istemci/installer, native modül, backup worker ve AD/GPO değişmedi. Dağıtım planı otomatik oluşturulmadı; Windows yönetim bileşeni yapılandırılmadı.
- 🔴✓ Öncesinde6, sonrasında20panel/API yolu üçer kez HTTP200 döndü. Yeni deployment status medyan3.8ms/max4.2ms; deployment.js medyan1.5ms/max1.8ms. En yüksek sonrası ölçüm173.7ms (device status). Sonuç operatörün root kurulum çıktısına dayanır; bu kayıt güncellemesinde ek canlı işlem yapılmadı.
- 🔴✓ Tam veri yedeği tekrar alınmadı; günlük yedek timer ve worker korundu. Başarılı kurulumda kod geri alma çalıştırılmadı.
- **Açık:** Ctrl+F5 → Sertifikalar → Dağıtım altında Windows dağıtım planları ve Yeni dağıtım penceresinin operatör görünüm kabulü. Sonraki bölüm kısıtlı Windows yönetim bileşeninin bir defalık yetkilendirmesi/iletişimi ve imzalı GPO uygulama yoludur. AD/GPO create/link/apply, OU hedefleme, gerçek uç teyitleri, rollback ve200cihaz kabulü tamamlanmış değildir.
- Gerçek kullanıcı/bilgisayar ve Ethernet/Wi-Fi testleri pazartesi için açık kalır. A04 bütünü ve54/94 (%57) tamamlanma hesabı değişmedi. Kanıt: `checkpoints/2026-10-24-windows-preparation-live-result.json`.

## 🔴✓ A04 merkezi Windows dağıtımı hazırlık geliştirmesi — dev.34, 24 Ekim 2026

- 🔴✓ Sertifikalar → Dağıtım bölümüne Windows dağıtım planları eklendi. Bilgisayar hedef AD grubu, ayrı kullanıcı sertifika profili/hedefi, makine sertifika profili, Ethernet/Wi-Fi, SSID, RADIUS sunucu adı ve machine/user/machineOrUser seçilir. Kullanıcı seçimi bilgisayar hedefi varsaymaz; ayrı AuthWire yerel grup yönetimi eklenmedi.
- 🔴✓ Açıkça kaydedilen planlar existing runtime_settings içinde tutulur; yeni DB şeması veya varsayılan plan oluşturulmaz. Global revision + plan version eski yazmayı engeller; son5eski tanım saklanır. Audit kaydı sunucunun doğruladığı yönetici kimliği ve sürümünü içerir. Yanıt kaybında yazma tekrarlanmaz; sabit UUID ile kayıt okunarak uzlaştırılır.
- 🔴✓ Salt okunur önizleme, ayrı etkin/toplam kullanıcı ve bilgisayar sayıları, AD okuma zamanı, ağ/SSID/kimlik seçimi ve sertifika profillerinin gerçek sürümlerini gösterir. Sayılar önbellek AD üyeliğidir; uç kurulumu veya GPO başarısı değildir. Eksik/boş/çözümlenmeyen hedef veya kapalı/değişen profil paket üretimini engeller.
- 🔴✓ Deterministik XML paketi gerçek CA/issuer ve mevcut RADIUS leaf zinciri, süre, ServerAuth EKU, exact SAN ve iptal durumuyla doğrulanır. EAP-TLS13, açık sunucu adı/kök pin'i, server validation ve certificate-error prompt reddi LAN/WLAN XML'ine yazılır. Plan/profil sürümü/AD katalog/config/sertifika özeti değişirse eski önizleme ile indirme reddedilir. Paket yalnız public trust/XML/JSON/hash manifestidir; özel anahtar, parola, PFX veya executable installer içermez.
- Teknik testler:724Python testi (28ortam atlaması), yeni13backend/HTTP sınırı;14tarayıcı akışı, gerçek HTTPS kayıt/önizleme/arşiv, kayıp yanıtın tekrarsız uzlaştırılması, stale editor, read-role/CSRF ve logout koruması. Masaüstü/dar ekran görüntüleri incelendi. Native Windows kullanıcı/bilgisayar CNG/SYSTEM/retry ve107Kerberos testi başarılı. Altı CI workflow başarılı; native RADIUS normal33/debug31, gerçek300sn CRL cache yenilemesi ve35production runtime testi geçti. Bunlar izole fixture kanıtıdır; müşteri AD/GPO veya gerçek uç kabulü yapılmış sayılmaz.
- Kaynak PR65 başı `8bcc043b1d763f79e1c071241d755ec1c6a8ead4`, main merge `3e74805d4eea1890d65297712c3130b459e7c008`.
-167dosyalı aday sunucuda `/home/segmentiq/authwire-stage-dev34-8bcc043b1d76` yolunda hazır ve dosya hashleri doğrulandı. Dev.33 kurulu163dosya kaynak koruması geçti.10paket dosyası değişir; RADIUS/policy/models/store, Windows istemci/installer, logo ve backup worker kaynakları aynıdır. ManifestSHA256 `5f7e033e431e775b07cf60b911f1cbfdc2d79922c77a114be4d482d44d6eb106`.
- 🔴✓ Panel-only teslim/geri alma5izole test geçti. Helper `/home/segmentiq/authwire-windows-preparation-20261024.py`, SHA256 `9a4a3707be854fb880ad4110b5fcbd54801fba2bed35995a55a4d50117957d04`. Kaynak kaydı/iş verisi çakışırsa veri geri yüklenmez. Yerel sudo kurulumunda yalnız panel yeniden başlayacak; RADIUS ve broker PID'leri, unit/native, CA/sertifika/policy/Windows ve timer korunması zorunlu karşılaştırılacak. Tam veri yedeği tekrar alınmayacak.
- **Canlı kurulum ve operatör görünümü bekliyor.** Son canlı salt okunur durumda dev.33, panelPID1243356/RADIUSPID1243360/brokerPID1069437aktif. Hazırlık sırasında canlı kaynak veya AD/GPO/uç ayarı değiştirilmedi; aday dosyalar aktarıldı. Bir staging isteği bağlantı zaman aşımı verdi; önce salt okunur envanterle hedefin oluşmadığı görüldü, ardından aktarım tamamlanıp167hash/kurulu kaynak guard tekrar doğrulandı.
- **A04 bütünü açık:** kısıtlı Windows yönetim bileşeninin bir defalık yetkilendirmesi/iletişimi, kurumsal Windows imzalama yolu, canlı GPO create/link/apply ve hedef/izin farkı, OU hedefleme, uç uygulama teyitleri, gerçek Ethernet/Wi-Fi/user-machine geçişi, rollback ve200cihaz ölçek kabulü sonraki kapılardır. dev.34 GPO uygulama endpoint'i içermez; can_apply=false ve bağlantı bekleniyor bilgisi açıkça gösterilir. XML'in gerçek Windows kartına/GPO'ya uygulanması pazartesi için açıktır.
-94iş hesabı54tamam (%57),40kalan (%43) korunur; A04 alt hazırlığıyla ana madde tamamlanmış sayılmadı. DNS/DHCP mimarisi kapsam dışı, off-host yedek ve full appliance boot/restore açık kalır. Tasarım ve açık kapılar: `WINDOWS_DEPLOYMENT_CONNECTOR.md`.

## 🔴✓ dev.33 Doğrulama Kapsamı alanının tarayıcı kabulü tamam — 24 Ekim 2026

- Operatör erişim kuralı modalındaki Doğrulama Kapsamı alanının göründüğünü doğruladı. Yeni alanın canlı panel görünürlüğü kabulü tamamlandı.
- Bu onay herhangi bir kuralın değiştirildiği veya gerçek kullanıcı/bilgisayar EAP-TLS/VLAN testinin yapıldığı anlamına gelmez. Kullanıcı/cihaz AD-GPO ve kablolu/Wi-Fi/VLAN saha kabulü pazartesi için açık kalır. A03/A04 bütünü ve54/94 (%57) tamamlanma hesabı değişmedi.
- Bu kayıt güncellemesinde canlı policy/sertifika, Windows/AD-GPO veya servislere işlem yapılmadı. Kanıt: checkpoints/2026-10-24-policy-identity-live-result.json içindeki operator_browser_acceptance.

## 🔴✓ dev.33 canlı kullanıcı/bilgisayar policy kapsamı kurulumu tamam — 24 Ekim 2026

- 🔴✓ Operatör POLICY_IDENTITY_FINISHED / verified=true / version0.14.0-dev.33 çıktısını paylaştı. Kaynak `3dbf32d5ea903e94ae017bc0ed1ff66e23daa4fa` canlıya uygulandı; yerel sudo/kurulum beklemesi kapandı. Kanıt dizini: `/var/lib/authwire-updates/policy-identity-dev33-20261024T165150Z-570a7ccb`.
- 🔴✓ Planlı RADIUS geçişi tamam: PID1136462 →1243360, servis aktif. Broker süreci korundu. Korunan dosya, timer ve iş verisi karşılaştırmaları başarılı; native modül, Windows kullanıcı/bilgisayar paketleri, AD/GPO, sertifikalar ve mevcut policy verisi değişmedi. Eski kurallara kapsam alanı otomatik eklenmedi.
- 🔴✓ Kurulum öncesi6, sonrası18panel/API yolu üçer kez HTTP200 döndü. Sonrasında kullanıcı status/JS, simülasyon dışındaki durum sayfaları, dashboard süreleri, services/system/policy labels ve audit/RADIUS geçmişi sağlıklı. En yüksek ölçüm161.3ms (cihaz status), medyan9.1ms; kullanıcı status medyan5.3ms/max10.3ms. Bu sonuçlar operatörün root kurulum çıktısına dayanır; bu kayıtta ek canlı yazma yapılmadı.
- 🔴✓ Tam veri yedeği tekrar alınmadı; backup worker ve günlük yedek timer korundu. Yeni kaynak ve hata halinde yalnız kodu geri alma yolu önceki teknik kabulde doğrulandı; bu başarılı kurulumda geri alma çalıştırılmadı.
- **Açık:** Ctrl+F5 sonrasında erişim kuralı modalında Doğrulama Kapsamı alanının operatör tarayıcı kabulü. Kullanıcı/cihaz sertifikası, AD-GPO ve gerçek kablolu/Wi-Fi/VLAN uç kabulü pazartesiye bırakılmıştır. Canlı kurulum başarısı bu saha testlerini tamamlamaz.
- A03/A04 bütünü açık;94iş hesabı54tamam (%57),40kalan (%43) olarak korundu. AuthWire ayrı grup yönetimi geri eklenmedi. Kanıt: `checkpoints/2026-10-24-policy-identity-live-result.json`.

## 🔴✓ Kullanıcı/bilgisayar policy kapsamı teknik kabulü tamam — dev.33, 24 Ekim 2026

- 🔴✓ Yeni kurala **Doğrulama Kapsamı: Kullanıcı / Bilgisayar / İkisi birlikte** seçimi eklendi. AD grubu her iki hesap türünü içerebilir. Gerçek RADIUS türü yalnız sertifikanın değişmez hesap bağı ve güncel AD nesnesinden gelir; dış EAP adı veya panel talebi kimlik kanıtı değildir. Mevcut sertifika/AD kontrolleri ve ikinci registry doğrulaması korundu.
- 🔴✓ Eski kuralların kapsam alanı yoksa eski anlamı aynen korunur; otomatik veri göçü veya scope ekleme yoktur. Aynı AD grubuna ait açıkça ayrı kullanıcı/bilgisayar kuralları farklı VLAN alabilir. Kesişen kararlar kayıt ve çalışma anında reddedilir; ilk eşleşen kural/öncelik eklenmedi. Yanlış türde doğrudan hesap seçimi atomik reddedilir.
- 🔴✓ Modalda yeni-kural kimlik önerisi ve mevcut kuralı kapsam/koşul değiştirmeden kaydetme kontrol edildi. Simülasyon kullanıcı/bilgisayar türünü alır; hesap SID'sini panelden kabul etmeme sınırı korundu. Simülasyon ağ kimlik kanıtı veya RADIUS yanıtı değildir.
- 🔴✓ PR64 kaynak başı `3dbf32d5ea903e94ae017bc0ed1ff66e23daa4fa`, main merge `fd129424b01f674a64503214cb969b68fb0d7533`. Altı CI workflow başarılı. 711 Python testi (28 ortam atlaması), 107 zorunlu native Kerberos/kayıt/HTTP testi, 13 tarayıcı akışı, Windows kullanıcı ve bilgisayar CNG/SYSTEM/retry kontrolleri geçti. Yeni21model/store/adapter/HTTP testi bu711sayısına dahildir.
- 🔴✓ Gerçek native EAP-TLS normal33/debug31senaryo geçti: aynı AD grubu için kullanıcıVLAN50, bilgisayarVLAN110; yanlış kapsam reddi ve sahte dış EAP adına rağmen sertifika/AD türünün korunması doğrulandı. Gerçek300sn CRL cache yenilemesi, native systemd aktivasyon/geri alma ve35runtime testi başarılı. Bunlar izole fixture sonuçlarıdır; müşteri AD'si ve gerçek kablolu/Wi-Fi uç kabulü değildir.
- 🔴✓ Tarayıcıda masaüstü/dar modal görsel kontrolü yapıldı. Artifact12560966377, ZIP SHA256 `3c8a98a3f14c8e2e421d1707685682a2e7a2f453406e40b3a99198192d12507a`. İlk tarayıcı denemesindeki fixture VLAN envanteri eksikliği giderildi; ürün davranışı değiştirilmedi. Tam testte simülasyona SID gönderiminin reddedilme sınırı geri korunarak test geçti; hata saklanmadı veya test devre dışı bırakılmadı.
- 🔴✓163dosyalı paket Linux'ta `/home/segmentiq/authwire-stage-dev33-3dbf32d5ea90` yolunda hazırlandı ve tek tek hash doğrulandı. ManifestSHA256 `77cf3d87cd3469f91ea12dd749f7b568936e187b6cbb28f4e08e1d291cc2d577`; mevcut161dosyalı dev.32 kaynak koruması geçti.13incelenmiş kaynak/test dosyası değişir; iki yeni test dosyası vardır. Logo, Windows kullanıcı/bilgisayar paketleri, enrollment, RADIUS adapter/directory/registry, native modül/servis kontrolü ve backup worker kaynakları korunur.
- 🔴✓ Yerel teslim/geri alma için5izole test geçti: kaynak sapması/inceleme sınırı, planlı panel+RADIUS geçişi, idempotent tekrar, kısmi yazma/sağlık hatasında kod geri alma, eşzamanlı yeni iş verisi varsa eski motora/veriye otomatik dönmeme. Canlı veri/DB geri yüklemesi yapılmaz. Helper `/home/segmentiq/authwire-policy-identity-20261024.py`, SHA256 `cd15ea86cf7b96b9052a723470a4fd92a6996ef9bfb931302e804a862b21ab9c`.
- **Canlı kurulum bekliyor:** yerel sudo gerekir. Bu adım policy motorunu değiştirdiğinden bir **planlı panel ve RADIUS yeniden başlatma** içerir. Broker/native modül/ünite, CA/sertifika, mevcut policy verisi, Windows paketleri ve timer'lar koruma karşılaştırmasıyla denetlenir. Tam veri yedeği tekrar alınmaz; kod geri alma noktası tutulur. Henüz POLICY_IDENTITY_FINISHED veya dev.33 canlı kabulü alınmış sayılmaz; çalışan kaynak son doğrulamada dev.32'dir.
- **Açık:** yeni alanın gerçek panel kabulü ve pazartesi kullanıcı/cihaz AD-GPO, kablolu/Wi-Fi/VLAN saha kabulü. A03/A04 bütünü açık.94iş üzerinden54tamam (%57),40kalan (%43) hesabı bu alt teknik işle artırılmadı. Ayrı AuthWire grup yönetimi geri eklenmedi; DNS/DHCP mimarisi kapsam dışı, off-host yedek ve tam appliance boot/restore açık kalır.
- Kanıt: `checkpoints/2026-10-24-policy-identity-delivery.json`; incelenmiş kurulum/geri alma kaynağı ve testleri aynı checkpoint dizininde saklıdır.

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
