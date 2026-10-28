# AuthWire devam noktası — 28 Ekim 2026

## 🔴✓ Windows birleşik worker Prepare kabul edildi — Apply sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /ToolVersion1.3.0 /Mode Prepare /Stage prepared**
sonucunu paylaştı. Kaynak imzaları geçerli, **Error=null /ChangesMayBePartial=false**.
Beklenen current release **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**, yeni aday
**689649c0-61df-40aa-bbfb-b84fa1cc2ac0**, kaynak bileşeni **157b2d4bc705539f78f982a860331e537010cab1**.
**PackagePrepared=true; ExistingAccountPreserved/PairingPreserved/ChannelKeyPreserved=true**.
Signer snapshot ve eski kaynaklar korundu. **ServiceTransitioned=false**; çalışan Connector hâlâ eski sürümdedir.
GPO/AD, key ACL, trust store değişmedi; yeni anahtar/servis oluşturulmadı. **CanApplyGpo=false**.

Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-689649c061df40aabbfbb84fa1cc2ac0-3628c461f2914802999776d7114ac9c6**.
Journal: **C:\ProgramData\AuthWire-ConnectorUpgrade-4c23eebe071546d188eea2e96ad7ee46-689649c061df40aabbfbb84fa1cc2ac0\upgrade.json**.
Tam operatör JSON'u **docs/checkpoints/2026-10-28-customer-combined-worker-prepared.json** içinde kaydedildi.
Bu kabul operatör çıktısına dayanır; asistanın bağımsız Windows oturumu/servis okuması değildir.
ArchivePath planlanan geri alma konumudur; Prepare sırasında eski paket arşivlenmiş veya geri alma denenmiş sayılmaz.

**Sıradaki işlem:** aynı hash doğrulanmış r2 launcher ile **-Mode Apply**.
Bu işlem yalnız kalıcı Windows Connector'ı kontrollü stop/start ile yeni worker'a geçirir;
mevcut hesap/eşleştirme/anahtar/signer ve önceki paket korunur. Linux RADIUS değiştirilmez.
Yeni sürüm için taze HTTPS health ve birleşik capability kabul kapısıdır;
uygulama sonucu ve taze health görüldükten sonra panelden birleşik doğrulama görevi gönderilecek.
Henüz Apply yapılmadı, müşteri pozitif birleşik roundtrip veya GPO/endpoint dağıtımı yok.
Linux son kabul **dev.42**, genel **54/94 tamam,40 açık**; nihai kılavuz kapısı değişmedi.
Her işlemden sonra kayıt tercihi yerine getirildi; yeni tam yedek alınmadı.


## Windows Prepare teslimatı doğrulandı — 28 Ekim 2026

PR111 merge **01d323fab033bcc8e56d59cae0cec0328cb7f4e3**; test head **1fdeba003642f34e1bf13a1722b782722ba09d93**.
Genel ve bounded retry workflow'ları başarılı;1001 test/28 skipped, üç yerel delivery regresyon testi geçti.
Yalnız wrapper'ın kabul edilen efc5ee91 başlangıç sürümü girdisi düzeltildi;
21 dosyalık embedded archive ve bütün imza/ACL/channel/rollback korumaları değişmedi.
Linux'taki eski dosyayla byte karşılaştırması, tek farkın bu sürüm girdisi olduğunu doğruladı.

**Kullanılacak r2 dosyası:** /home/segmentiq/authwire-dc01-combined-worker-upgrade-r2-20261028.ps1
SHA256 **65bf7b7a1963c9c103764c6e1b6677cecb2b5a06d2cffc1bcb56372c9fc86cc3**,125642 byte.
Yeni release **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**; beklenen current release
**efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Komut ve beklenen sonuçlar **docs/checkpoints/2026-10-28-windows-combined-worker-prepare-handoff.md** içinde kayıtlı.
Windows'ta henüz Prepare/Apply çalıştırılmadı; sonraki işlem yalnız Prepare ve sonucunu incelemek.
Linux dev.42 kabul edildi; GPO/endpoint uygulaması ve gerçek birleşik pozitif roundtrip hâlâ açık.
Bu teslimat işlemi tam yedek, yeni anahtar/hesap/sertifika veya dağıtım görevi oluşturmadı.


## 🔴✓ Dev.42 canlı Linux kurulumu kabul edildi — Windows birleşik worker hazırlığı sırada — 28 Ekim 2026

Operatör **COMBINED_JOBS_FINISHED /verified=true**, sürüm **0.14.0-dev.42**,
release **375677c9bd733cae0f25fd6fc59c0ea826b25f78** sonucunu paylaştı.
Korunan dosyalar, broker/RADIUS süreçleri, timer ve iş durumu kontrolleri geçti.
Önce/sonra bütün authenticated loopback okumaları200 döndü; combined job kanalı eklendi,
ancak birleşik görev oluşturulmadı. RADIUS PID **1243360** ve broker PID **1069437** korundu.
Kanıt: **/var/lib/authwire-updates/combined-jobs-dev42-20261028T114518Z-941ed9a1**.

Asistan ayrıca salt okunur source sürümünü dev.42, panel active/PID **2035660**,
RADIUS/broker active ve aynı PID'leri, backup timer active durumunu doğruladı.
Kurulu ve source backup worker hash'leri **4f489caa2113c86bda5d0d294878920e218769751e0edbb9385aa40135a924b6**;
release.json aynı worker hash'ini gösteriyor; restore checker hash'i değişmedi.
Asistan unprivileged olarak private web.crt okuyamadığından HTTPS kontrolünü bağımsız tekrarlamadı;
HTTP200/iş durumu korunumu operatörün sudo installer kanıtına dayanır. DB veya gizli değer okunmadı.

**backup_workers_changed=true beklenen uyumluluk güncellemesidir:** birleşik görev kanalının
poll/last_poll hareketleri yedek kararlılık kontrolüne eklendi; tam yedek alınmadı.
Politika, sertifika, plan, eşleştirme, AD/GPO, Windows paket/cihaz ve native modül değişmedi.
Son kabul edilen tam yedek28 Ekim10:28 arşividir; bu güncelleme yeni backup/restore provası sayılmaz.

Windows teslimatını vermeden önce wrapper'ın b546 başlangıç sürümü pininin artık eski olduğu bulundu.
Mevcut son kabul edilen scope worker **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9** olduğundan
yalnız ExpectedCurrentRelease girdisi düzeltildi;21 dosyalık imzalanacak kaynak arşivi değişmedi.
**PR111** bu düzeltmeyi ve regresyon kontrolünü kaydeder; son CI/teslimat hash'i aşağıdaki takip kaydına işlenecek.
Eski staged Windows helper henüz operatöre çalıştırılmak üzere verilmedi ve Windows'ta uygulanmadı.

**Sıradaki operatör adımı:** düzeltilmiş Windows helper ile **Prepare**;
çalışan servis/PID'yi değiştirmeden aday paket ve geri alma kaydı hazırlanır.
Başarılı sonucu takiben **Apply**, taze health/capability ve birleşik panel doğrulama görevi.
Windows son canlı release hâlâ **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Birleşik gerçek pozitif roundtrip, browser kabulü, taze AD/GPO/SYSVOL, staging/rollback ve endpoint kabulü açık.
**GPO apply=false;54/94 tamam,40 açık; nihai kılavuz kapısı değişmedi.**


## Birleşik kalıcı doğrulama hazır — dev.42 ve Windows uygulaması bekliyor — 28 Ekim 2026

**PR110** merge **bbeeb482099302dea45ed1f03cdd6cca6165cff0**, test head **f924535281b63c48e1facfe24964e73f50c5a9fd**.
Dokuz workflow başarılı: **1000 Python testi /28 skipped**, tarayıcı, native birleşik paket,
gerçek RADIUS, Linux kaynak hazırlama, yedek ve Windows kontrolleri.
Gerçek imzalı kalıcı SCM fixture'ında86 kontrol geçti: ayrı birleşik capability, typed negatif
görev sonucu, kanal kesintisinde upgrade reddi/rollback ve eski sürümden kontrollü yükseltme.
Linux delivery/rollback için14, geçici Linux lifecycle/registry ortamında19 test geçti.
İlk native denemede C# HTTPS allowlist'ine iki yeni exact yolun eklenmediği bulundu; düzeltildi.
Ayrı ve değişmeyen expired endpoint fixture'ı ilk çalıştırmada takıldı; retry ve son test head geçti.
Bu kayıt gerçek müşteri pozitif uçtan uca sonucu veya ürünün bütünü için kabul değildir.

**Yeni davranış:** combined.verify.v1 ayrı sıra/purpose/route ile birleşik operatör kaydına,
taslak/manifest/profile sürümüne, orijinal ağ kaydına ve geçerli Connector bağımlılıklarına bağlanır.
Kalıcı worker eski ağ adayını ve birleşik üç imzayı, profile/domain/group/CA/config/TLS ilişkilerini
yalnız genel anahtarlarla doğrular; signer private key açmaz, deployment artifact çalıştırmaz.
Eski ağ-only kanalı birleşik kaydı kabul etmez. Başarılı sonuç content_verified alanını ilerletir;
AD/GPO tazeliği, connector_verified ve can_apply ayrı ve henüz false kalır.
Panelde kendi worker yeteneği görüldükten sonra birleşik satırın “Doğrulamayı önizle” akışı kullanılabilir.

**Linux teslimatı salt okunur doğrulandı; HENÜZ UYGULANMADI.**
Son kabul edilen canlı Linux **0.14.0-dev.41**, Windows **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Sudo helper: **/home/segmentiq/authwire-combined-jobs-20261028.py**
SHA256 **d0e64bfa44824de69e89f187949383a9201951ac77e47f0e403e1d2cd5d8d9e9**.
Stage: **/home/segmentiq/authwire-stage-dev42-375677c9bd73**,181 dosya,
manifest **361af5e19eeabcc1fc526d4f444d23b25966d8df4dced19f9715dec00ffbbdf2**,
Linux kaynak bileşeni **375677c9bd733cae0f25fd6fc59c0ea826b25f78**.
Yalnız yedi source dosyası değişir; yeni combined_jobs.py dahil. Server'ın25 değişmeyen fonksiyon gövdesi pinlidir;
yalnız üç incelenmiş dispatch gövdesi genişler, mevcut HTTPS/session/CSRF/çift güncel yetki ve peer korumaları korunur.
Panel restart planlı; RADIUS/broker PID, politikalar, sertifikalar, Windows, AD/GPO ve timer korunur.

**Yedek uyumluluğu:** dördüncü sıranın yalnız doğrulanmış polls/last_poll alanları mevcut karşılaştırma
projeksiyonuna eklenir; tüm gerçek DB içeriği ve durable jobs/results yedekte kalır.
Hem source hem kurulu backup worker yeni SHA **4f489caa2113c86bda5d0d294878920e218769751e0edbb9385aa40135a924b6**
olacak; kurulu release.json aynı hash'e atomik güncellenir, restore checker değişmez.
Eski/new pair pinleri, metadata, idle+exclusive update lock ve exact source/worker rollback kontrolü test edildi.
Her değişiklikte tam yedek alınmaması tercihi korunur;28 Ekim10:28 başarılı yedek hâlâ son kabul edilen arşivdir.

**Windows teslimatı Linux home'a aktarıldı, HENÜZ WINDOWS'TA ÇALIŞTIRILMADI.**
/home/segmentiq/authwire-dc01-combined-worker-upgrade-20261028.ps1
SHA256 **d8251cd89870519a7fa520c568713bd88949c6a3bd72924470dd47ec5a5ffba9**.
21 kaynak dosyası; bileşen **157b2d4bc705539f78f982a860331e537010cab1**,
yeni release **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**,
arşiv **dffba96918da2e4295bf018f126de4297335ee4100cd5912370e97fb3b8b7509**.
Mevcut gMSA, eşleştirme, channel key ve signer/ACL korunur. Eski birleşik paket yeniden üretilmez/imzalanmaz.

**Devam sırası:** operatör Linux pinned sudo helper sonucunu paylaşır → Windows Prepare → Apply →
taze health/capability → panel birleşik satırında önizle/gönder/yenile ile gerçek pozitif content sonucu.
Ardından birleşik paket için taze AD/GPO/SYSVOL kapsamı, staging/rollback ve gerçek cihaz testleri açık kalır.
Bu hazırlık sırasında source/service/DB/GPO/endpoint canlı değişmedi; görev/yeni kayıt/tam yedek oluşturulmadı.
Genel **54/94 tamam,40 açık**; nihai kılavuz **READY_FOR_FINAL_GUIDE=false, GUIDE_DELIVERED=false**.
Her tamamlanan işlemi kaydetme tercihi bu test/teslimat/devam kaydıyla yerine getirildi.


Kullanıcı çalıştığı sunucuyu kapatıp açmadan önce ilerlemenin kalıcı kaydını istedi.
Hangi fiziksel/VM sunucusunun yeniden başlatılacağı belirtilmedi.
Bu kayıt güç işlemi, tam sistem/veri yedeği veya kurtarma testi gerçekleştirmez.
Kaynak taban commit: e7b1e2c4fc0161667f7dce60c9f6872fe043f247.
Yeni geliştirme bu devam noktasında duraklatıldı.

## Yeniden başlatma öncesi Linux yedeği — tamamlandı

28 Ekim 2026 10:28:35 İstanbul tarihinde yeni BACKUP_SUCCESS kabul edildi.
Arşiv: /var/backups/authwire/scheduled/authwire-scheduled-20261028T072835Z-004fe2d609b1.tar.gz
SHA256: 3c4b00b745063980c962f712a426a4ce2e845d62abb096ec2346941a5062c002
1687 dosya /4 DB; arşiv, byte/metadata, SQLite bütünlüğü, kararlı iş durumu ve ürün süreçleri doğrulandı.
Operatör helper bağımsız arşiv hash kontrolünü tamamladı; asistan journal/systemd/worker hash'lerini ayrıca okudu.
r2 worker SHA256: c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c.
Timer etkin; ürün servisleri durdurulmadı/yeniden başlatılmadı.
Bu arşivde veri restore veya tam OS boot restore provası yapılmadı; off-host kopya ve Windows/DC01 yedeği ayrı.
Henüz reboot yapılmış veya açılış sonrası sağlık doğrulanmış sayılmaz.

## Güncel devam noktası — dev.41 ve birleşik panel kaydı kabul edildi

Operatör ekranı birleşik satırı, beklenen pending durumunu ve doğru manifest/draft hash'lerini gösterdi.
Dev.41 canlı kurulum ve birleşik operatör kayıt/browser adımı tamamlandı.
Kanıt: docs/checkpoints/2026-10-28-customer-combined-registration-browser-accepted.json
Sıradaki iş: typed birleşik aday doğrulama görevi ve kalıcı Windows Connector worker entegrasyonu.
Mevcut paket yeniden oluşturulmayacak/imzalanmayacak; ağ-only kanıtı birleşik kabul sayılmayacak.
GPO staging/apply ve gerçek endpoint kabulü açık;54/94,40 açık; final guide ready=false.
Aşağıdaki kayıt-bekliyor notları tarihsel hazırlık/kurulum kayıtlarıdır.

## Son güncelleme — dev.41 kuruldu; birleşik panel kaydı bekliyor

Dev.41 kurulum sonucu doğrulandı. RADIUS1243360/broker1069437 korundu; panel active1991730.
Kanıt: /var/lib/authwire-updates/combined-registration-dev41-20261028T094925Z-b9c1e309
Yeni kayıt/görev/GPO uygulaması yok. Tarayıcı kabulü bekler.
Sıradaki işlem: mevcut başarılı birleşik Prepare çıktısının operator_result bölümünü
İmzalı dağıtım adayları/Hazırlık sonucunu kaydet alanında önizleyip kaydetmek.
Hazır JSON: docs/checkpoints/2026-10-28-combined-registration-panel-receipt.json.
Ardından typed birleşik kalıcı worker/job entegrasyonu.54/94,40 açık; final guide ready=false.
Aşağıdaki dev.41 uygulama-bekliyor notu tarihsel hazırlık kaydıdır; kurulum artık tamamlandı.

## Güncel devam adımı — birleşik kayıt dev.41 hazır, canlı uygulama bekliyor

Kullanıcı her tamamlanan işlemi GitHub'a kayıt etme tercihini yineledi; tam yedek her işlemde alınmayacak.
PR109 merge 749d84faa21058c6719df2ba4f635b8f80e87f1d; test head edebc092a5bcd253533a4ba53ee954034676830d.
960 test/28 skipped ve altı workflow geçti. A04 registry alt adımı hazır; live dev.41 ve browser kabulü bekler.
Linux helper: /home/segmentiq/authwire-combined-registration-20261028.py
SHA256: 408a2dcd5de9f5542bec00f7bcd86be9c3b3c415cb9adc90c108a9a075be151c
Stage: /home/segmentiq/authwire-stage-dev41-ae21bb729cf5
Manifest: 93cbe46e5af959a0778500e3d5020691164692182463077ceaef78ffa5546bb7
Yalnız panel restart planlı; RADIUS/broker/yedek/GPO/Windows değişmez.
Operatör uygulama sonucundan sonra mevcut birleşik imzalama çıktısı ayrı hazırlık kaydı olarak alınacak.
Ardından typed birleşik kalıcı Connector worker/job kanalı hazırlanacak.
Önceki ağ-only doğrulaması birleşik paket doğrulaması diye kabul edilmeyecek.

## Son kabul edilen durum
- Linux AuthWire: son operatör kabulü 0.14.0-dev.40.
- Windows kalıcı Connector: son kabul edilen release efc5ee91-e39e-4cc4-9cc1-60b648e18cf9.
- Birleşik imzalı paket DC01 üzerinde oluşturuldu; üç imza doğrulandı.
- aw-deploy$ hesabıyla gerçek geçici SCM kontrolü başarılı: exact runtime SID ...1648,
  ContentVerified/ServiceIdentityVerified/ProbeVerified true; SignaturesVerified=3.
- Geçici servis/exe/verifier/result dizini kaldırıldı, Error=null/CleanupErrors=[].
- Son PID9288 geçici probe PID'idir; tekrar var olması beklenmez.
- Kalıcı Connector değiştirilmedi; deployment artifact çalıştırılmadı.
- GpoStateChecked=false, DirectoryFreshnessChecked=false, CanStage=false, CanApplyGpo=false.
- Genel durum 54/94 tamam,40 açık; ürünün tamamı kabul edilmiş sayılmaz.
- READY_FOR_FINAL_GUIDE=false; nihai sade Türkçe ayrıntılı Word/PDF kılavuz teslimatı bekler.

## Kalıcı konumlar ve özetler
Linux kaynak: /opt/kaname-lab/source
Linux DB: /var/lib/kaname-lab/kaname.sqlite3
Linux özgün birleşik ZIP: /home/segmentiq/authwire-pilot-combined-draft-20261028.zip
ZIP SHA256: 5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5
Linux son kontrol helper'ı: /home/segmentiq/authwire-dc01-combined-runtime-20261028.ps1
Helper SHA256: 3caf4882a6871f4936b6021d68c44f664f14556ffc5cd3bdd7ef0bd87e8eec78

DC01 imzalı aday:
C:\ProgramData\AuthWire-CombinedCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5-1359-46f5-84a5-46355bb82aff-v1-5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5-ab1a11c683810061
İmzalı manifest SHA256: 124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b
Publisher: FFC134BC305757457163F99C7479B4168E397129
DC01 runtime kaynakları: C:\ProgramData\AuthWire-CombinedRuntimeSources-4bd3a5483f44fd62
DC01 kontrol özeti: C:\ProgramData\AuthWire-CandidateProbe-707b20123a304c599e8463068f0fdcd1\summary.json
Windows Temp altındaki aktarım kopyası veya açık PowerShell değişkenlerine devam için güvenilmez.
Gerekirse özgün ZIP Linux home konumundan tekrar aktarılabilir; paketi yeniden üretmek/imzalamak gerekmez.

## Kimlik ve hedefler
Domain: vizyonveri.local; DC01: dc01.vizyonveri.local
Appliance: https://kaname.vizyonveri.local:8765/ ; Linux IP son bilinen10.35.50.246
Connector ID: 4c23eebe-0715-46d1-88ee-a2e96ad7ee46
Servis: AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46
Hesap: VIZYONVERI\aw-deploy$
SID: S-1-5-21-34256453-3348971241-2809240126-1648
Plan: 524653f5-1359-46f5-84a5-46355bb82aff v1
Makine profili: e3597842-3499-4ace-aaf3-29890eabd908 v3
Owned deployment GPO: 8c6808fd-a382-4bf2-9c9c-d9e1d46082a3
Korunan trust GPO: e5a9ab39-3709-49cb-837a-0208d2eb3b12
TLS DER SHA256: a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d

## Yeniden açılışta devam sırası
1. Kullanıcının hangi host/VM'leri yeniden başlattığını öğren; etkilenenleri salt okunur kontrol et.
2. Linux erişimi, authwire-radius.service ve authwire-service-control.service aktifliği,
   panel HTTPS/session ve backup timer durumunu doğrula.
3. DC01 AD/DNS erişimi; kalıcı Connector servis hesabı, running durumu ve açılıştan sonra
   üretilmiş taze authenticated health/başarı zamanını kontrol et.
   Yeniden açılışta PID değişmesi normaldir; eski PID eşitliğini şart koşma.
4. Gerekliyse kalıcı aday dosyaları/manifest ve özgün ZIP'in özetlerini kontrol et.
   Önceki başarıyı her açılışta aynı uzun probe'ları tekrar çalıştırma gerekçesi sayma;
   sadece başarısız/taze doğrulama gerektiren sınır için hedefli kontrol yap.
5. Kaynak/iş verisi değişikliği veya başarısız başlangıç yoksa aşağıdaki geliştirmeye devam et.
   Sorun çıkarsa önce teşhis et; installer/Prepare/Apply komutlarını körlemesine tekrarlama.
   Yeni hesap/anahtar/sertifika/GPO oluşturma veya anahtar association/ACL onarma varsayımı yapma.

## Sıradaki geliştirme ve açık kabul kapıları
1. Birleşik paket için panel/Connector job + registry entegrasyonu.
   Mevcut ağ-only aday formatını birleşik paket diye yükseltme.
2. Kontrollü staging öncesinde taze AD hedef/GPO/tam SYSVOL kapsamı kontrolleri.
3. Controlled SYSVOL staging yazıcısı, koruma/rollback ve operatör kabulü.
4. GPO/ağ uygulama yolu; pilot cihazda sertifika edinimi, Ethernet/Wi-Fi EAP-TLS ve VLAN.
5. Kullanıcı doğrulaması/diğer A03 ve mevcut rapordaki açık saha/ölçek testleri kapanmış sayılmaz.
6. Tek hesap/standart kurulum sadeleştirmesi ve ayrıntılı final kullanım kılavuzu açık kalır.

## Kabul kanıtı
docs/checkpoints/2026-10-28-customer-combined-gmsa-runtime-accepted.json
docs/COMBINED_RUNTIME_VERIFICATION.md
Son araç PR106: merge60c39b36b594e3e1f9076a2a9e50ce87cdeda32b,
test head a69f9a6d2c1f6c2476a4ebb258e9299e6129cb14;
932 test/28 skipped, native Windows28 kontrol; dört workflow başarılı.
Başarı geçmişi yeniden açılış sonrası taze servis sağlığının yerine geçmez.

Devam cümlesi: “Sunucuyu açtım, 28 Ekim devam kaydından devam edelim.”
