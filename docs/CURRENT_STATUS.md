# AuthWire current work record

Updated: 28 October 2026, Europe/Istanbul. This record supplements the 9 October
`AuthWire_Durum_ve_Tamamlama_Raporu_2026-10-09.docx` / `.pdf`; those reports are a
dated baseline. Use this record when producing their next requested revision.
The operator requested ongoing tracking; on 15 October at16:52 requested a
pause checkpoint and an updated report with red check marks against 9 October.















## 🔴✓ Dev.43 canlı Linux kurulumu kabul edildi — Windows kapsam worker Prepare sırada — 28 Ekim 2026

Operatör **COMBINED_SCOPE_JOBS_FINISHED /verified=true**, sürüm **0.14.0-dev.43**,
release **c67adc15b731dbb7876cef1ed848ee1ce483b8bb** sonucunu paylaştı.
Korunan dosyalar, broker/RADIUS süreçleri, timer ve iş durumu kontrolleri geçti.
Önce/sonra bütün authenticated loopback okumaları200; birleşik kapsam görev kanalı eklendi,
ancak yeni kapsam görevi veya aday kaydı oluşturulmadı.
RADIUS **1243360** ve broker **1069437** korundu; RADIUS yeniden başlatılmadı.
Kanıt: **/var/lib/authwire-updates/combined-scope-jobs-dev43-20261028T124458Z-78543b4b**.

Asistan ayrıca salt okunur source sürümünü dev.43, panel active/PID **2058459**,
RADIUS/broker active ve aynı PID'leri, backup timer active durumunu doğruladı.
Kurulu/source backup worker SHA **e0623c6998db9c8fa45df2f9e5ff6d514e451567d711fece5ef5417330ada8b6**;
release.json eşleşiyor, restore checker **8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5** değişmedi.
DB okunmadı; HTTPS/session200 ve iş durumu korunumu operatörün sudo installer kanıtına dayanır.
**backup_workers_changed=true** beşinci sıranın poll uyumluluğu için beklenen güncellemedir;
tam yedek alınmadı ve backup timer korundu.

Politika, sertifika, plan, eşleştirme, AD/GPO, Windows paket/endpoint ve native modül değişmedi.
**combined_scope_worker_delivery_pending=true /gpo_apply_enabled=false** beklenen ara durumdur.
Windows son kabul edilen release hâlâ **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**;
birleşik pozitif content/browser kabulü korunuyor, yeni canlı kapsam kabulü henüz yok.

**Sıradaki operatör işlemi:** DC01'de yönetici64-bit Windows PowerShell ile
**authwire-dc01-combined-scope-worker-upgrade-20261028.ps1 -Mode Prepare**.
Dosya Linux home'da hazır; SHA **44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2**.
Asistan uzak dosya hash'ini ve wrapper'ın **689649c0** current-release pinini tekrar doğruladı.
Yeni aday release **e6d734b1-59c8-48e5-8a6e-c40b43be3114**,24 incelenmiş source.
Prepare mevcut servis/PID'yi değiştirmeden paket ve journal hazırlar; çıktı kabulünden sonra Apply yapılacak.
Henüz Windows Prepare/Apply veya birleşik kapsam işi yürütülmedi.
Ardından panelde birleşik satırın AD/GPO kontrolünü önizle/gönder/Yenile akışıyla gerçek kapsam sonucu alınacak.
Staging/rollback, gerçek endpoint ve bütün ürün kabulü açık; **54/94 tamam,40 açık**.
Nihai kılavuz kapısı değişmedi; sonuç ve sonraki işlem kaydedildi.

## Birleşik AD/GPO/SYSVOL kapsam kontrolü hazır — dev.43 ve Windows kurulumu bekliyor — 28 Ekim 2026

**PR112** merge **94c888bfa979e1c773bf0aee356692db69ed584e**, test head **b4eed841150059170658a9b004594b4638c66e9c**,
kaynak bileşeni **c67adc15b731dbb7876cef1ed848ee1ce483b8bb**.
Dokuz workflow başarılı: **1045 Python testi /28 skipped**, tarayıcı, gerçek RADIUS,
native birleşik paket, Linux kaynak hazırlama, yedek ve Windows kontrolleri.
Native scope hedef/hash/gerçek geçici dosya ağacında41 kontrol; imzalı kalıcı SCM fixture'ında90 kontrol geçti.
SCM fixture'ı typed birleşik scope görevinde gerçek imzalı negatif sonucu ve yeni kanal kesildiğinde
upgrade reddi/rollback davranışını sınadı. Hosted fixture müşteri AD/gMSA pozitif kabulü değildir.
Yerel49 RSA/SQLite/HTTPS/yedek,14 delivery/rollback ve üç exact Windows archive kontrolü geçti.
Bu sayılar ürünün bütünü veya müşteri kapsam testi tamamlanmış anlamına gelmez.

**Yeni davranış:** ayrı **combined.scope.verify.v1** capability/purpose/route ve
**windows_combined_scope_jobs** sırası. Hedef, birleşik adayın19 alanına; son kabul edilen birleşik
içerik kanıtının hash'ine; tüm güncel AD hedef SID setine; profile/network/draft/manifest pinlerine bağlı.
İçerik kanıtı veya bağımlılık değişirse eski lease/snapshot geçersiz olur. Sonuç yalnız90 saniye taze
okuma snapshot'ıdır. Eski ağ-only scope ve birleşik content kanalları kendi görevlerini korur.
Başarılı sonuç **connector_verified/can_apply** açmaz.

İmzalı, süre/çıktı bütçeli AllSigned child; birleşik ve ağ içeriğini okuma öncesi/sonrası yeniden doğrular.
AD nested/primary üyelikleri, etkin bilgisayarlar, managed GPO kimliği/marker/owner/izinler,
bağsız/ayarsız/zero-version durumunu ve SYSVOL root ACL'ini kontrol eder.
SYSVOL'de dört kök öğe, boş Machine/User dizinleri, dosya byte hash/ACL'leri,
GPT.INI tek Version=0 ve iki kararlı okuma zorunludur; gizli deployment dosyası/reparse/drift reddedilir.
Deployment artifact çalıştırılmaz; AD/GPO/endpoint ayarı yazılmaz.
Mevcut25 server fonksiyon gövdesi pinli; üç incelenmiş dispatch gövdesi genişletildi.

**Linux dev.43 teslimatı hazırlanıp sunucuda salt okunur doğrulandı; henüz uygulanmadı.**
Helper **/home/segmentiq/authwire-combined-scope-jobs-20261028.py**
SHA256 **19a33302b0b80dbf186a75e4e09aae91195ae82ce905e59dd2341d8c277d36d2**.
Stage **/home/segmentiq/authwire-stage-dev43-c67adc15b731**,182 dosya;
manifest **61a0310f43d5aea90e79554c39950c792b5bf8bd4e59f55a832c13e105995338**.
Yalnız yedi source dosyası (yeni combined_scope_jobs.py dahil), kurulu backup worker ve release hash pair'i güncellenir.
Yeni worker **e0623c6998db9c8fa45df2f9e5ff6d514e451567d711fece5ef5417330ada8b6**, restore checker değişmez.
Beşinci sıranın yalnız doğrulanmış poll metadata'sı kararlılık karşılaştırmasına eklenir;
tüm DB/poll/replay verisi ve durable işler/sonuçlar gerçek yedekte korunur.
Panel restart planlı; RADIUS/broker ve timer korunur. Idle/exclusive lock, source/worker exact rollback,
üçüncü taraf drift ve eşzamanlı iş değişikliğinde otomatik geri alma yapmama testleri geçti.

**Windows teslimatı hazır; henüz Windows'ta Prepare/Apply çalıştırılmadı.**
Helper **/home/segmentiq/authwire-dc01-combined-scope-worker-upgrade-20261028.ps1**
SHA256 **44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2**;24 incelenmiş source,
archive **f348716cddef27503c1d8b1e698963d1612193ee9a74bd7df06e58588cae0ddd**.
Yeni release **e6d734b1-59c8-48e5-8a6e-c40b43be3114**, beklenen current **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**.
Mevcut gMSA, eşleştirme, channel key, signer ve eski paket korunur.
Yeni release ancak taze **CombinedScopeChannelVerified** dahil beş kanal sağlıklıysa kabul edilir;
başarısız geçişte eski sürüme geri dönülür.
İlk dosya aktarım timeout'u parça aktarımıyla giderildi; byte hash ve tek kaynak manifesti tekrar doğrulandı.

**Canlı son kabul değişmedi:** Linux **dev.42**, Windows **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**;
birleşik content pozitif/browser kabulü tamam. Müşteride yeni scope okuması yapılmadı.
Devam: Linux pinned sudo helper → Windows Prepare → Apply → birleşik satırda
**AD/GPO kontrolünü önizle/gönder/Yenile** → gerçek kapsam sonucu.
Ardından kontrollü staging/rollback ve gerçek pilot endpoint kabulü açık.
Yeni tam yedek alınmadı; mevcut28 Ekim10:28 doğrulanmış yedek son kabul edilen arşivdir.
**54/94 tamam,40 açık; READY_FOR_FINAL_GUIDE=false, GUIDE_DELIVERED=false** korunur.
Tamamlanan kaynak/test/teslimat ve sonraki işlem kalıcı kayda işlendi.

## 🔴✓ Birleşik paket kalıcı Connector içerik doğrulaması panelde kabul edildi — 28 Ekim 2026

Operatör ekran görüntüsünde **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket**
satırı ve **“İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.”**
durumu görünüyor. Sertifika kurulumu+ağ profilleri birlikte doğrulanan birleşik kayıt açıkça seçilmiş.
Manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b** ve
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**
önceden kabul edilen imzalı adayla aynı.
Bu, dev.42 görev kanalı ve689649c0 kalıcı worker sonrası gerçek müşteri pozitif content sonucunun
**panel gösterimiyle kabulüdür**; eski ağ-only doğrulamasıyla karıştırılmadı.

Kanıt: **image(20261028-120334).png**,
SHA256 **3b730b6fbd659ab53437f94ec221e50f1ab954518c39e7de6b7afd44e1d57fe0**.
Kaynak operatör ekranıdır; asistanın bağımsız API/Windows/DB okuması değildir.
Görev kimliği ve ham imzalı result bu görüntüde bulunmuyor; bunlar uydurulmadı.
Kabul kaydı: **docs/checkpoints/2026-10-28-customer-combined-content-browser-accepted.json**.

**Tamamlanan alt adım:** birleşik imzalı aday hazırlığı → ayrı panel kaydı → dev.42 typed görev kanalı →
kalıcı Windows worker Prepare/Apply → pozitif birleşik içerik sonucu ve tarayıcı kabulü.
Linux son kabul **0.14.0-dev.42**; Windows son kabul **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**.
İçerik kabulü GPO/AD/SYSVOL tazeliği, gerçek staging/rollback veya endpoint kurulumu değildir.
Bu kayıt ürün/policy/AD/GPO/cihaz ayarlarını değiştirmez ve yeni tam yedek oluşturmaz.

**Sıradaki geliştirme/kontrol:** aynı birleşik adaya ve güncel içerik sonucuna bağlı,
güncel AD hedef üyeliklerini ve yönetilen GPO/SYSVOL durumunu salt okunur doğrulayacak kapsam adımı.
Mevcut ağ-only scope kanalı birleşik kanıt sayılmaz; birleşik hedef/paket pinleri korunarak
destek hazırlanmalı, önizleme/görev/worker sonucu ayrı kaydedilmelidir.
Sonra kontrollü staging/rollback ve gerçek pilot endpoint kabulü açık kalır.
Planın merkezi Windows dağıtımı maddesi devam ediyor; henüz GPO uygulaması başlatılmadı.
Genel **54/94 tamam,40 açık** sayımı ve **READY_FOR_FINAL_GUIDE=false /GUIDE_DELIVERED=false** değişmedi.
Her tamamlanan işlemi kaydetme tercihi bu kabul ve devam noktasıyla yerine getirildi.

## 🔴✓ Kalıcı Windows birleşik worker Apply kabul edildi — panel içerik görevi sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /Mode Apply /Stage applied /Error=null**
sonucunu paylaştı. **ServiceTransitioned=true**; kalıcı Connector
**efc5ee91-e39e-4cc4-9cc1-60b648e18cf9 → 689649c0-61df-40aa-bbfb-b84fa1cc2ac0** geçişi kabul edildi.
Kaynak bileşeni **157b2d4bc705539f78f982a860331e537010cab1**; SourceSignaturesValid=true,
ChangesMayBePartial=false. Mevcut hesap, eşleştirme, channel key, eski kaynaklar ve signer snapshot korundu.
**AD/GPO, signer key ACL ve trust store değişmedi; yeni anahtar/hesap/servis oluşturulmadı; CanApplyGpo=false.**
Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-689649c061df40aabbfbb84fa1cc2ac0-69466a1b270542f9832734e1055622f7**.
Tam çıktı **docs/checkpoints/2026-10-28-customer-combined-worker-applied.json** içinde kayıtlı.

İncelenen source'da Apply başarıdan önce yeni release/runtime kimliğine bağlı taze HTTPS health ile
Probe/Candidate/Scope/**CombinedChannelVerified** kapılarını zorunlu tutar.
Dolayısıyla applied sonucu bu kurulum kapısının geçtiğine dair operatör kanıtıdır;
asistanın bağımsız DC01 health/servis okuması veya pozitif birleşik aday doğrulaması değildir.
Önceki paket için ArchivePath kaydedildi; bu müşteride geri alma çalıştırılmış sayılmaz.

**Sıradaki adım:** paneli Ctrl+F5 ile yenile → **İmzalı dağıtım adayları** bölümünde
**AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırını seç →
**Doğrulamayı önizle → Doğrulamayı gönder** → yaklaşık30–60 saniye sonra **Yenile**.
Hedef manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b**,
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5** korunur.
Ağ profilleri satırındaki eski doğrulama birleşik paket kanıtı olarak kullanılmaz.
Beklenen birleşik satır mesajı: **“İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.”**
Görev queued/leased iken tekrar gönderilmez; önce Yenile ile aynı görevin sonucu izlenir.

Henüz birleşik görev gönderildiği veya gerçek pozitif content sonucu alındığı bildirilmedi.
Taze birleşik AD/GPO/SYSVOL, staging/rollback, gerçek endpoint kabulü ve ürünün bütünü açık.
Linux dev.42; Windows son kabul689649c0; **54/94 tamam,40 açık**; nihai kılavuz kapısı değişmedi.
Her işlemden sonra sonuç/kanıt/devam kaydı eklendi; bu adım yeni tam yedek veya GPO/cihaz dağıtımı değildir.

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

## 🔴✓ Birleşik paket panel kaydı ve tarayıcı görünümü kabul edildi — 28 Ekim 2026

Operatör ekran görüntüsünde **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırı ve
**“Operatör sonucu kaydedildi. Connector doğrulaması bekleniyor.”** durumu görünüyor.
Manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b** ve
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**
önceden kabul edilen birleşik imzalı hazırlıkla aynı. Panel sertifika kurulumu+ağ profillerini ayrı
birleşik kayıt olarak gösteriyor; kalıcı Connector doğrulamasının henüz kullanılabilir olmadığını açıkça belirtiyor.
Bu ekran adımın beklenen görünümüdür; hata mesajı veya gerçek GPO uygulama sonucu değildir.

Kanıt **image(20261028-095711).png**, SHA256
**6f6cdd126842ef816f6b814f2f99c26810a1c97043e0f4f09525960e869158fb**.
Kabul operatör ekranına dayanır; ayrı asistan canlı DB okuması değildir.
**Dev.41 kurulum + birleşik operatör kaydı + bu satırın tarayıcı görünümü tamamlandı.**
Kalıcı birleşik worker doğrulaması, taze AD/GPO/SYSVOL, staging/rollback ve cihaz kurulumu açık kalır.
Eski ağ-only kanıtı birleşik doğrulama sayılmaz; GPO/endpoint kabulü veya ürünün tamamlanması iddia edilmez.
Genel **54/94 /40 açık**, nihai kılavuz kapısı değişmedi.

**Sıradaki geliştirme:** birleşik adayın kendi hedef/manifest/draft bağımlılıklarını taşıyan typed
doğrulama görev kanalı ve kalıcı Windows Connector worker teslimatı. Mevcut imzalı paket ve
ağ-only kayıt korunacak; paket yeniden üretilmeyecek veya imzalanmayacak.
Kullanıcının her tamamlanan işlemi kaydetme ve her değişiklikte tam yedek almama tercihleri korunur.

## 🔴✓ Dev.41 Linux kurulumu kabul edildi — birleşik panel kaydı bekliyor — 28 Ekim 2026

Operatör **COMBINED_REGISTRATION_FINISHED /verified=true**, sürüm **0.14.0-dev.41**,
release **ae21bb729cf57215b13546fa3e4cb8d2202ca68f** sonucunu paylaştı.
Korunan dosyalar, broker/RADIUS süreçleri, timer ve iş durumu kontrolleri geçti.
RADIUS PID **1243360** ve broker PID **1069437** korundu; RADIUS yeniden başlatılmadı.
Önce/sonra bütün authenticated loopback panel okumaları **200**; aday/Connector/dağıtım API'leri erişilebilir.
Policy, plan, sertifika, Windows paket/cihaz, AD/GPO, native modül ve yedek worker değişmedi;
tam yedek alınmadı, yedek timer korundu. Yeni kayıt veya görev oluşturulmadı.

Kanıt: **/var/lib/authwire-updates/combined-registration-dev41-20261028T094925Z-b9c1e309**.
Asistan ayrıca salt okunur sürüm ve systemd kontrolünde dev.41, RADIUS/broker active ve aynı PID'leri,
panel active/PID **1991730** durumunu gördü. Bu okuma DB iş durumu kanıtını bağımsız tekrar üretmez;
iş durumu korunumu operatör installer çıktısına dayanır.

**Tarayıcı kabulü ve birleşik operatör kaydı henüz bekliyor.**
Önceden kabul edilmiş **WINDOWS_COMBINED_SIGNING_DELIVERY /Prepare /verified** çıktısının
yalnız operator_result bölümü tekrar aramayı gerektirmemek için
**docs/checkpoints/2026-10-28-combined-registration-panel-receipt.json** içine aynen ayrıldı.
Yeni Windows işi çalıştırılmadı veya paket yeniden imzalanmadı. Panelde
**İmzalı dağıtım adayları → Hazırlık sonucunu kaydet → Önizle → Kaydet** yolu kullanılacak.
Bu kayıt sonucundan sonra birleşik typed kalıcı Connector worker/job kanalı hazırlanacak.
**combined_worker_delivery_pending=true, GPO apply=false**, gerçek cihaz kabulü açık.
Genel **54/94 /40 açık**, nihai kılavuz kapısı değişmedi. Tamamlanan bu adım ve sonraki adım kaydedildi.

## Birleşik paket panel kaydı hazır — dev.41 canlı uygulama bekliyor — 28 Ekim 2026

**Kayıt tercihi:** Kullanıcı her tamamlanan işlemin ve doğrulama sonucunun kalıcı kayda alınmasını istedi.
Her mantıksal adım için kaynak/sonuç/kanıt/sonraki adım GitHub durum ve checkpoint kayıtlarına işlenecek.
Bu tercih her değişiklikte tam yedek istemek değildir; önceki tam-yedek-almama tercihi korunur.

**PR109** merge **749d84faa21058c6719df2ba4f635b8f80e87f1d**, test head **edebc092a5bcd253533a4ba53ee954034676830d**, ürün kaynak bileşeni
**ae21bb729cf57215b13546fa3e4cb8d2202ca68f**. Altı workflow başarılı: genel **960 test /28 skipped**,
tarayıcıda ayrı birleşik satır/yanlış görev engeli, gerçek native RADIUS/systemd, Linux kaynak hazırlama,
device enrollment ve bounded retry kontrolleri. Yerel source delivery/rollback için9 test ve
müşteri verisine erişmeden geçici Linux fixture ortamında7 RSA/SQLite kayıt testi geçti.
Önceki yedek poll düzeltmesinin ortaya çıkardığı tarihsel RADIUS test hazırlığı uyumsuzluğu,
pinli eski worker fixture'ıyla düzeltildi; ürün RADIUS/yedek korumaları değiştirilmedi.

Panel aynı planın güncel ağ-only kaydını korur; **WINDOWS_COMBINED_SIGNING_DELIVERY** Prepare/verified
sonucunu **combined_machine_v1** olarak ayrı draft/manifest/publisher/network-reference pinleriyle kaydeder.
Çıktıda host/GPO bulunmadığı için mevcut güncel plan/binding/dependency ile eşleşen tek ağ kaydına bağlanır;
bu ilişki canlı Windows/GPO doğrulaması değildir. Yollar saklanmaz/açılmaz/çalıştırılmaz.
Bozuk veya yetki/uygulama iddiası içeren kayıt reddedilir; mevcut çift yetki, HTTPS/session/CSRF ve
yazma sırasında güncel yetki kontrolleri korunur. Ağ kaydı değişmez; eski content/scope görevleri
birleşik kaydı doğrulayamaz. **content_verified=false, connector_verified=false, can_apply=false**.
Birleşik kayıt satırında kalıcı doğrulamanın henüz kullanılabilir olmadığı açıkça görünür.

Linux'a hazır stage **/home/segmentiq/authwire-stage-dev41-ae21bb729cf5**;180 dosya,
manifest **93cbe46e5af959a0778500e3d5020691164692182463077ceaef78ffa5546bb7**.
Sabit sudo helper **/home/segmentiq/authwire-combined-registration-20261028.py**,
SHA256 **408a2dcd5de9f5542bec00f7bcd86be9c3b3c415cb9adc90c108a9a075be151c**.
Uzak dosya/manifest ve kurulu kaynak guard'ı salt okunur doğrulandı.
Yalnız altı registry/UI/version dosyasına izin verir; bütün diğer kurulu kaynaklar ve28 server fonksiyonu korunur.
Plan: yalnız panel restart; RADIUS/broker PID, policy/certificates, Windows/GPO, yedek worker/timer korunur.
Kaynak geri alma ve eşzamanlı iş değişikliğinde otomatik geri alma yapmama kontrolleri test edildi.

**Henüz canlı dev.41 kurulmadı; operatör sonucu ve tarayıcı kabulü bekleniyor.**
Linux son kabul dev.40, Windows kalıcı Connector efc5ee91-e39e-4cc4-9cc1-60b648e18cf9.
Yeni aday/görev/kural/sertifika oluşturulmadı, GPO/staging uygulanmadı ve bu değişiklik için tam yedek alınmadı.
28 Ekim10:28 doğrulanmış Linux yedeği korunuyor. Genel **54/94 /40 açık**, nihai kılavuz kapısı değişmedi.
Sonraki sıra: dev.41 uygulama + birleşik operatör kaydı; birleşik typed kalıcı worker/job kanalı;
taze AD/GPO/tam SYSVOL kontrolleri; staging/rollback ve uç cihaz kabulü.

## 🔴✓ Linux yeni yedek ve poll düzeltmesi kabul edildi — 28 Ekim 2026 10:28 İstanbul

Operatör r2 helper sonucu **BACKUP_POLL_FIX_FINISHED**: worker iki konumda
**c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c**, üç görev kuyruğunda recognized=true.
Kaynak uygulaması ürün süreçlerini korudu; DB/unit/restore checker değişmedi, ürün servisleri yeniden başlatılmadı.
Kanıt dizini **/var/lib/authwire-updates/backup-poll-fix-r2-20261028-0ed27bd5aef54db4b6b20750da2a6b02**.

Yeni **BACKUP_SUCCESS**: **28 Ekim 2026 10:28:35 İstanbul** (07:28:35.438167 UTC),
**1687 dosya /4 DB**, arşiv okuma, dosya byte/metadata, SQLite bütünlük ve iş durumu kararlılığı doğrulandı.
Arşiv: **/var/backups/authwire/scheduled/authwire-scheduled-20261028T072835Z-004fe2d609b1.tar.gz**
SHA256: **3c4b00b745063980c962f712a426a4ce2e845d62abb096ec2346941a5062c002**
Helper arşivi yeniden hash ederek archive_sha256_verified=true bildirdi. Başarılı saklama politikası kapsamında
bir eski yönetilen yedek temizlendi; keep_successful=14. Servis süreçleri korundu, durdurulmadı.

Asistan ayrı salt okunur journal/systemd/kaynak kontrolüyle aynı başarı kaydını,
iki worker hash'ini, backup.service Result=success/inactive ve backup.timer active durumunu doğruladı.
Arşivin root-only içeriği asistan tarafından ayrıca açılmadı; byte/hash doğrulaması operatör helper sonucuna dayanır.
Bu yeni yedekte **data_restore_exercised=false /full_appliance_boot_restore_tested=false**;
CI fixture restore kabulü bu arşivde canlı restore yapılmış anlamına gelmez.
Off-host kopya ve Windows/DC01 CNG anahtar/servis durum yedeği ayrıca ele alınır.

**Yeniden başlatma öncesi Linux yedek adımı tamamlandı**; güç işlemi çalıştırılmadı, reboot sonrası sağlık kabulü bekler.
A04 birleşik kalıcı job/registry entegrasyonu ve staging/rollback işleri duraklatılan yerden devam edecek.
Genel durum **54/94 /40 açık**; CanStage/CanApplyGpo=false ve nihai kılavuz beklemesi değişmedi.
Önceki başarısızlık notları tarihseldir; güncel sonuç bu başarılı kayıttır.

## Yedek ilk hotfix sonrası hâlâ başarısız — probe biçimi düzeltmesi — 28 Ekim 2026

Operatör ilk hotfix'i uyguladı: iki worker SHA256 **fab31d283971b3d36d3cf4c4f480f36e32e16f7f5a627ebbd422ec9741d31288**,
ürün PID'leri korunmuş, DB/unit/restore checker değişmemiş. Yeni iş **10:11:56 İstanbul**
**BACKUP_FAILED /capture /ValueError**, önceki arşivler temizlenmemiş. Yeni başarılı yedek henüz yok.
Asistan salt okunur kaynak hash/PID ve journal kontrolü uygulamayı ve başarısızlığı doğruladı.

İlk düzeltme probe last_poll kaydına da release_id şartı koymuştu; gerçek ConnectorJobs yazıcısı
yalnız **scope/at** üretir. Candidate ve scope kuyrukları **scope/at/release_id** üretir.
Bu nedenle probe satırı ham korumada kalmış ve sürekli poll değişimi capture guard'ını tetiklemeye devam etmiştir.
İkinci düzeltme her kuyruk için yalnız gerçek kesin biçimi tanır. Bilinmeyen/ek alanlar ve kalıcı jobs/results
korunur; tam poll/replay verisi SQLite arşivinde kalır. Testler gerçek RSA/SQLite poll yazıcılarıyla genişletildi.
Sabit r2 helper yalnız kurulmuş ilk hotfix hash'inden geçiş yapar; yeni yedekten önce canlı üç kuyruğun
biçiminin tanındığını salt okunur kontrol eder. RADIUS/panel/broker restart veya DB/AD/GPO değişikliği yapmaz.
**PR108** merge **6e330534857ce668c1bbefaf3456034e671bb217**, test head **2f3647e44bc7005198bbaf94d53a4d145983aa7e**: üç workflow başarılı;
**941 test /28 skipped**, gerçek üç poll yazıcısı regresyonu ve yedek/restore/systemd fixture kontrolleri geçti.
Linux sabit r2 dosyası **/home/segmentiq/authwire-backup-poll-fix-r2-20261028.py**, SHA256
**70f8490113a4a8b7c1197253d5e14ab473fe9b8eca19ce7055783e89dd93837f**; uzak dosya özeti doğrulandı.
Yeni worker SHA256 **c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c**.
**İkinci hotfix uygulaması ve yeni BACKUP_SUCCESS bekleniyor.** Ürün 54/94 /40 açık; reboot ve A04 ilerlemesi beklemede.

## Yedek kararlılık hatası için dar düzeltme hazır — uygulama/yeni yedek bekleniyor — 28 Ekim 2026

Operatör salt okunur teşhisi: dört DB, schema değişimi yok; yalnız **kaname.sqlite3/runtime_settings**
ve **windows_candidate_verify_jobs /windows_connector_probe_jobs /windows_deployment_scope_jobs** satırları değişiyor.
Kaynak incelemesi bu kuyrukların sürekli poll/replay/last_poll metadata güncellediğini, eski guard'ın
bütün satırları karşılaştırdığını gösterdi. Snapshot'ın kararlılık kontrolü bu geçici trafikle çakışıyor.

**PR107** merge **cd9faa1b269f3964c7ba51afc8bb579dfe85813b**, test head **c0d3ece8c9198516d986d415544555577a785375**:
üç workflow başarılı; genel **939 test /28 skipped**, yedek arşiv/restore/systemd kabul kontrolleri başarılı.
Düzeltme yalnız bu üç bilinen v1 kuyruğun geçerli **polls/last_poll** alanlarını karşılaştırma projeksiyonundan ayırır.
**Jobs, targets, leases, results, diğer runtime kayıtları ve bilinmeyen/bozuk payload'lar korunur**.
SQLite arşivi ham polls/last_poll/replay kayıtları dahil tüm veriyi içerir; veri yedekten çıkarılmaz.
Gerçek iş/result değişikliği testte yayını hâlâ engeller.

Sabit hotfix **/home/segmentiq/authwire-backup-poll-fix-20261028.py**, SHA256
**8a5d4d3274e28c5902213f896a304f0e4723829fca219364133c468a57d3ab67**; Linux kopyası doğrulandı.
Operatör sudo ile iki worker kopyası ve backup release hash kaydını update lock altında,
eski küçük kaynak kopyalarını koruyarak günceller; sonra normal yedek servisini bir kez başlatır,
sonuç ve arşiv SHA256'sını kontrol eder. Kaynak uygulama hatasında değişen kaynaklar guard'lı geri alınır.
Uygulama servisleri, timer/unit'ler, restore checker, DB/AD/GPO/Windows değişmez.
**Canlı hotfix uygulaması ve yeni BACKUP_SUCCESS henüz kabul edilmedi**; eski26 Ekim yedeği güncel yedek sayılmaz.
Güvenli kapatma öncesinde yeni sonuç beklenir; restart checkpoint ilerleme kaydı ayrı olarak saklıdır.

## Yedekleme başarısızlığı inceleniyor — yeniden açılış öncesi öncelik — 28 Ekim 2026

Operatör **sudo systemctl start authwire-backup.service** çalıştırdı; iş exit1 ile başarısız.
Asistan salt okunur systemd/journal kontrolünde 28 Ekim09:47:20–09:50:23 İstanbul çalışmasının
**BACKUP_FAILED /ValueError** çıktısını gördü. 27 ve28 Ekim doğal gece işleri de aynı türde başarısız.
Journal'daki son başarılı kayıt **26 Ekim03:19:04 İstanbul**, arşiv **authwire-scheduled-20261026T001904Z-f6ad3585d4ef.tar.gz**,
SHA256 **3db0772ad74d8c6e047f930264e85946683e95ea1da7b131e528b643d338309f**.
Bu eski journal kaydıdır; dosya varlığı/digest veya restore şimdi yeniden doğrulanmadı.
Disk çıktısı43G toplam/18G kullanım/23G boş; hata mesajı tam neden bildirmiyor.

Canlı backup worker kaynak özeti **83de9cb66df58b5f0a12c18c6526731e9697023f268a12c7b566ba6efbda77b0**.
Kararlılık fingerprint'i runtime_settings içinde yalnız directory_health satırını dışlıyor.
Sürekli Connector poll/health kayıtlarının bu guard'ı değiştirmesi bir **hipotezdir**, henüz kesin neden değildir.
Yedekleme/servis/DB guard'ları gevşetilmedi, işler tekrar başlatılmadı ve eski yedekler silinmedi.

Sabit salt okunur teşhis **/home/segmentiq/authwire-backup-diagnostic-20261028.py**,
SHA256 **2b253ac5140b166c21bbefbf89ea9e8e990c28fc7d27677421a7d3edff05a1f7**. Operatör sudo ile36 saniyelik DB tablo/row özeti değişim
gözlemini ve last-run/last-success güvenli metadata'sını okuyacak; servis/DB yazısı veya yeni backup yok.
Değerler/sırlar dışarı verilmez. Yeni yedek başarılı kabul edilmez; önce teşhis ve düzeltme,
sonra gerçek başarılı yedek/özet kontrolü. Geliştirme ve reboot devam kaydı bu backup kabulünün yerine geçmez.

## Çalışma duraklatıldı — sunucu yeniden açılışı öncesi kalıcı devam kaydı — 28 Ekim 2026

Kullanıcı sunucuyu kapatıp açma ihtimaline karşı kayıt istedi. Son kabul, DC01 üzerinde
birleşik paketin **aw-deploy$** kimliğiyle başarılı salt okunur doğrulamasıdır.
Kalıcı devam belgesi **RESTART_CHECKPOINT_2026-10-28.md** içine kaynak/servis sürümleri,
kalıcı paket ve kanıt konumları, özetler, açık işler ve yeniden açılış kontrol sırası kaydedildi.
Bu çalışma güç işlemi veya tam sistem/veri yedeği oluşturmaz. PowerShell Temp/değişkenlerine bağımlı değildir.

**Yeniden açılışta önce salt okunur sağlık kontrolü:** Etkilenen host/VM, Linux RADIUS/control/panel,
DC01 AD/DNS ve kalıcı Connector'ın açılış sonrası taze başarısı. PID değişmesi normaldir;
eski PID eşitliği beklenmez. Başarılı kurulum/imzalama/probe işlemleri gereksiz tekrarlanmayacak.
Sonra **birleşik panel/Connector job-registry entegrasyonu**, taze kapsam guard'ları ve
controlled SYSVOL staging/rollback işine devam edilecek.
**CanStage/CanApplyGpo=false**, gerçek cihaz kabulü açık, **54/94 /40 açık** ve nihai kılavuz beklemesi korunur.

## 🔴✓ DC01 birleşik paketin gerçek gMSA kimliğiyle salt okunur kontrolü kabul edildi — 28 Ekim 2026

Operatör **WINDOWS_COMBINED_RUNTIME_DELIVERY /RunProbe /Stage=verified** sonucunu paylaştı.
DC01 **VIZYONVERI\\aw-deploy$**, runtime SID **S-1-5-21-34256453-3348971241-2809240126-1648**,
geçici runtime PID **9288**; **ServiceLogonVerified=true, ProbeVerified=true, CandidateVerified=true,
ContentVerified=true, ServiceIdentityVerified=true, SignaturesVerified=3**.
Plan **524653f5-1359-46f5-84a5-46355bb82aff v1**; manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b**,
özgün draft **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**.
Bu operatör çıktısı kabulüdür; ayrı asistan DC01 dosya/servis okuması değildir.
**9288 geçici probe PID'idir; kalıcı Connector PID'i olarak kullanılmaz.**

**TemporaryServiceRemoved/TemporaryBinaryRemoved/TemporaryVerifierRemoved/TemporaryResultDirectoryRemoved=true**,
Error=null ve CleanupErrors=[]; özgün ZIP korunmuş. Doğrulayıcı private key açmamış, deployment artifact çalıştırılmamış;
kalıcı Connector, AD/GPO ve logon rights değiştirilmemiş, secret export yok.
Kanıt yolu **C:\\ProgramData\\AuthWire-CandidateProbe-707b20123a304c599e8463068f0fdcd1\\summary.json**.

**Kabul sınırı/devam:** **GpoStateChecked=false, DirectoryFreshnessChecked=false, CanStage=false, CanApplyGpo=false**.
Bu standalone geçici SCM kanıtıdır; panelin birleşik job/registry yolu veya kalıcı worker güncellemesi kabulü değildir.
Sırada birleşik iş/kayıt entegrasyonu ve staging öncesi güncel AD/GPO/tam SYSVOL guard'ları;
ardından kontrollü staging/rollback, GPO/ağ uygulaması ve gerçek cihaz sertifika/Ethernet/Wi-Fi EAP-TLS/VLAN testleri vardır.
Başarılı aynı kontrol gereksiz tekrarlanmayacak.
Linux dev.40, Windows efc5ee91, **54/94 /40 açık** ve nihai ürün/kılavuz beklemesi korunur.
Kanıt **checkpoints/2026-10-28-customer-combined-gmsa-runtime-accepted.json**.

## Birleşik paket için salt okunur servis kimliği doğrulama aracı hazır — müşteri kontrolü bekleniyor — 28 Ekim 2026

**PR106** merge **60c39b36b594e3e1f9076a2a9e50ce87cdeda32b**, son test head **a69f9a6d2c1f6c2476a4ebb258e9299e6129cb14** üzerinde dört workflow başarılı.
Genel **932 test /28 skipped**, native Windows5.1 **28 kontrol**: private/signing işlevleri engelliyken
public doğrulama, yanlış pin/hesap reddi, gerçek yönetici olmayan SCM kimliğiyle imzalı paketi
okuma ve geçici servis/exe/helper/result temizliği geçti. Bu izole fixture kanıtıdır, DC01 kabulü değildir.

Sabit DC01 helper **/home/segmentiq/authwire-dc01-combined-runtime-20261028.ps1**,
SHA256 **3caf4882a6871f4936b6021d68c44f664f14556ffc5cd3bdd7ef0bd87e8eec78**, Linux kopyası doğrulandı.
Mevcut **aw-deploy$** ile geçici servis üzerinden exact manifest/draft/üç imza/ACL kontrolü yapar.
Kalıcı Connector PID/hesap/durum ve native signer snapshot korunumu kontrol edilir.
Müşteri **RunProbe sonucu henüz yok**; gMSA doğrulaması veya panel attestation başarılı diye işaretlenmez.
**CanStage=false/CanApplyGpo=false**; GPO/SYSVOL/ağ uygulaması ve deployment artifact execution yok.

**Devam:** Müşteri servis hesabı sonucu; ardından birleşik job/registry/worker entegrasyonu ve
güncel kapsam guard'larıyla controlled staging/rollback. Eski ağ-only aday aynı kalır.
GPO/ağ uygulaması ve gerçek endpoint sertifika/EAP-TLS/VLAN kabulü açık.
Linux dev.40, Windows efc5ee91, **54/94 /40 açık**, tam yedek alınmaması ve nihai kılavuz beklemesi korunur.
Ayrıntı **COMBINED_RUNTIME_VERIFICATION.md**, kanıt **checkpoints/2026-10-28-combined-runtime-delivery-prepared.json**.

## 🔴✓ DC01 birleşik yerel imzalı kopya kabul edildi — 28 Ekim 2026

Operatör **WINDOWS_COMBINED_SIGNING_DELIVERY /Prepare /Stage=verified** sonucunu paylaştı.
Plan **524653f5-1359-46f5-84a5-46355bb82aff v1**, özgün taslak SHA256 **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**.
İmzalı JSON manifest SHA256 **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b**,
publisher **FFC134BC305757457163F99C7479B4168E397129**. **SignaturesVerified=3, PreparedNow=true,
InstallerTemplateUpdated=true, SignerSnapshotPreserved=true, OriginalDraftPreserved=true**.
Bu operatör sonucunun dar kabulüdür; ayrı asistan DC01 dosya/sertifika okuması değildir.
Retry-trigger düzeltmesi yalnız yeni yerel installer kopyasında kabul edildi; Linux template'i ve uç cihazlar değiştirilmedi.

**Kabul sınırı/devam:** **CanStage=false, CanApplyGpo=false, ArtifactExecuted=false**.
AD/GPO/endpoint/servis/key ACL/trust değişikliği ve secret export yok; kalıcı Connector değiştirilmedi.
Birleşik formatın Connector doğrulama/kayıt yolu henüz kabul edilmedi; eski ağ-only panel adayı bu sonuçla yükseltilmez.
Sonraki geliştirme birleşik imzalı paketin servis kimliğiyle doğrulanması/kaydı ve controlled SYSVOL staging yoludur.
Gerçek staging öncesi güncel AD/GPO/tam envanter guard'ları yeniden kontrol edilmeli; henüz paket SYSVOL'a kopyalanmadı.
GPO/ağ uygulaması ve gerçek cihaz sertifika/Ethernet/Wi-Fi EAP-TLS/VLAN kabulü açık.
Linux dev.40, Windows efc5ee91, **54/94 /40 açık** ve nihai ürün/kılavuz beklemesi korunur.
Kanıt **checkpoints/2026-10-28-customer-combined-signed-preparation-accepted.json**.

## Birleşik taslağın DC01 aktarımı kabul edildi; yerel imzalama aracı hazır — 28 Ekim 2026

Operatör **COMBINED_DRAFT_TRANSFER_VERIFIED** sonucunda Windows geçici dizinindeki ZIP özetini
**5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5** olarak doğruladı.
Bu operatör aktarım/özet kabulüdür; ayrı asistan DC01 okuması veya imza kabulü değildir.

**PR105** merge **a97fc75b79348320edc062c09ce7bed9440752de**, son test head **fde15f7f3bc8acc88f9f24d77ff320137ac3fea0**.
Dört workflow başarılı; genel **929 test /28 skipped**, native Windows5.1 **21 kontrol**.
Yeni araç ayrı yerel kopyada istemci, incelenmiş main installer ve inert paket manifesti için üç Authenticode imzası üretir/doğrular.
Kalıcı signer binding/anahtar özellikleri/key ACL/CLR marker korunur; özgün ZIP değişmez; tekrar Prepare mevcut kopyayı doğrular.
Installer'ın retry zamanlama düzeltmesi yalnız yeni yerel kopyaya alınır; Linux ve uç cihaz dosyaları değiştirilmez.
Müşteri imzalama sonucu **henüz yok**. Sabit helper **/home/segmentiq/authwire-dc01-combined-candidate-20261028.ps1**, SHA256 **25667b231cffdfeec7cd73aadb85dd3054569efe61a677dadb0443824a92033f**.

**Sınır/devam:** **can_stage=false/can_apply=false**; GPO/SYSVOL/servis/AD/endpoint/key ACL/trust uygulaması yok.
Hazırlama elevated operatörle yapılır; müşteri gMSA runtime imzalama/dağıtımı kabulü sayılmaz.
Müşteri Prepare çıktısı, birleşik worker/registry/staging yolu, gerçek cihaz sertifika + Ethernet/Wi-Fi EAP-TLS/VLAN kabulü açıktır.
Linux dev.40, Windows efc5ee91, **54/94 /40 açık** ve nihai kılavuz beklemesi korunur.
Ayrıntı **COMBINED_SIGNED_PREPARATION.md**; checkpoint kayıtları **2026-10-28-customer-combined-transfer-accepted.json** ve **2026-10-28-combined-signing-delivery-prepared.json**.

## 🔴✓ Birleşik makine taslağı dışa aktarıldı ve arşiv doğrulandı — 28 Ekim 2026

Operatör **MACHINE_DEPLOYMENT_DRAFT_EXPORTED** sonucunu paylaştı: **18 dosya /29.086 bayt**, plan **524653f5-1359-46f5-84a5-46355bb82aff v1**, makine profili **e3597842-3499-4ace-aaf3-29890eabd908 v3**.
Çıktı **/home/segmentiq/authwire-pilot-combined-draft-20261028.zip**, SHA256 **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**.
Asistan Linux'ta ayrıca salt okunur doğruladı: ZIP özeti, tam dosya kümesi ve manifestteki bütün dosya özetleri eşleşiyor; dosya **0600 /segmentiq:segmentiq**.
Operatör sonucu **query_only_snapshot=true**, istemci korunmuş, özel anahtar okunmamış; servis/AD/GPO/endpoint değişmemiş. Bu iddialar operatör export çıktısından; arşiv doğrulaması DB işlemini yeniden çalıştırmaz.

**Kabul sınırı:** Public varlık taslağıdır; **requires_windows_signing=true, can_stage=false, can_apply=false**.
Eski Windows aday imzalayıcısı yalnız ağ paketi formatını destekler; birleşik taslağa doğrudan uygulanmayacak. DC01 aktarım/özet kabulü ve birleşik paket imzalama geliştirmesi sırada.
Main'deki retry trigger düzeltmesinin dağıtım öncesi alınması, kontrollü SYSVOL staging/ağ uygulama yolu, GPO uygulama ve gerçek cihaz sertifika/EAP-TLS/VLAN kabulü açık.
Linux dev.40, Windows efc5ee91, genel **54/94 /40 açık**, nihai ürün/kılavuz beklemesi korunur.
Kanıt **checkpoints/2026-10-28-customer-combined-machine-draft-accepted.json**.

## Birleşik makine paketi taslağı hazırlanıyor — operatör export'u bekleniyor — 28 Ekim 2026

A04 içindeki enrollment/installer + ağ profili birleştirme alt adımı PR104'tedir.
PR104 birleştirildi: **05b23412545fd7df0bf7c657cd49f13d1bff0c1e**. Son test head **648529d31ee073d33a0c3cb1c720d0ba19ae6d8d** üzerinde altı workflow başarılı; genel paket **927 test /28 skipped**. Kaynak bileşeni **e0edcd463a4da5f5f77695052bba580bd3829f28**. Teslimat helper'ı ve altı ek testi bu son head'de doğrulandı.
Sabit Linux helper'ının **--inspect-public** kontrolü uid1000 ile geçti; kaynak pinleri/özgün ağ ZIP'i doğrulandı, özel DB/TLS dosyası veya çıktı açılmadı.
**Gerçek müşteri birleşik ZIP'i henüz oluşturulmadı.** Operatör sudo export'u bekleniyor; yalnız yeni public varlık ZIP'i yazılır, DB salt okunur transaction ile okunur.
**requires_windows_signing=true, can_stage=false, can_apply=false**; SYSVOL/GPO/servis/endpoint/özel anahtar değişikliği yok.
Canlı kurulum betiği korunur; main'deki daha yeni retry trigger zamanlama düzeltmesi canlıda yoktur ve dağıtım öncesi ayrı takip edilecektir.
Windows imzalama, tam paket kabulü, controlled staging/ağ uygulama yolu ve gerçek cihaz EAP-TLS/VLAN testleri açıktır.
Linux dev.40, Windows efc5ee91, **54/94 /40 açık** ve nihai kılavuz beklemesi korunur.
Ayrıntı **MACHINE_DEPLOYMENT_BUNDLE.md**. Bu kayıt export veya ürünün tümü tamamlandı anlamına gelmez.

## 🔴✓ DC01 SYSVOL alt ağaç operatör envanteri kabul edildi — 27 Ekim 2026 23:57 İstanbul

Operatör **WINDOWS_SYSVOL_FULL_INVENTORY_READONLY v1** sonucunu paylaştı. DC01, GPO **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3**, hesap **VIZYONVERI\\administrator**, UTC **2026-10-27T20:57:49.6855695+00:00**. **InventoryStable=true, EmptyDeploymentTree=true, Blockers=[]**. Bu operatör JSON kabulüdür; ayrı asistan DC01 okuması veya gMSA runtime testi değildir.

🔴✓ Kök dahil **5 girdi /485 dosya baytı**: kök, boş Machine/User dizinleri, **GPO.cmt426 bayt / SHA256 91f1febf0b6a72ce00facb4952363b3efb1f915cdfe8834686dd137c1ecc07ca**, **GPT.INI59 bayt / SHA256 112721708676acace5886ff541684d5ff98607774380d53b07bf20546ac84349**. İki okumanın envanter özeti **b694d3170907045f688ddb7490933815f29eeff21b4e682b795487233ffebec6** aynı. Çıktı kök ve alt girdilerin standart owner/group/DACL SDDL verilerini içeriyor. Kök Domain Admins sahipliğinde, alt dosya/dizinler BUILTIN Administrators sahipliğinde; bunlar farklı girdilerin sahipleridir, tek kök owner varsayımı bütün alt ağaca uygulanmayacak. Ayrı etkili yazma yetkisi veya tüm ACL'lerin hedef yazıcı sözleşmesine uygunluğu kabul edilmedi.

**Sınır ve devam:** Envanter ana veri akışı/yollar ve standart ACL kapsamındadır; alternatif stream/SACL/hardlink taraması değildir. **GmsaRuntimeTested=false, EffectiveWriteAccessTested=false, PackageStaged=false, CanApplyGpo=false**. AD/GPO/servis/key ACL/trust değişmedi, artifact çalıştırılmadı. Başarılı aynı okuma gereksiz tekrarlanmayacak; gelecekte gerçek yazıcı uygulama anında güncel durumu yeniden kontrol etmeli. Sıradaki geliştirme eksiksiz enrollment/installer + ağ profili paketini SYSVOL dışında hazırlayıp doğrulamak, ardından ayrı controlled staging yazıcısıdır. Ağ XML adayı tek başına tam kurulum sayılmaz. Linux dev.40, Windows efc5ee91 ve **54/94,40 açık** korunur; nihai ürün/kılavuz kapanışı yok. Kanıt **checkpoints/2026-10-27-customer-sysvol-inventory-accepted.json**.

## 🔴✓ SYSVOL alt ağaç envanteri ve DC01 salt okunur kontrol dosyası hazır — müşteri okuması bekleniyor — 27 Ekim 2026

**PR103** birleştirildi. Test head **592a7aa8b4d59cfd354b0727ed0c6440c222904c**, merge **b45d9cb2332382a4723ce6553f472ea4be62e89e**. Önceki başarılı scope görevi yalnız kökü kontrol ediyordu. Yeni **SysvolInventory.ps1**, alt dizin yollarını, dosya ana veri akışı boyut/SHA256 ve standart owner/group/DACL SDDL verilerini de kaydeder. Kök dahil1024 girdi,16 derinlik, dosya16MiB/toplam32MiB sınırı; reparse takibi yok. Bilinmeyen alt dosya varsa boş dağıtım sınıflandırması false olur; hiçbir dosya silinmez veya sahiplenilmez. Bu transaction/SMB snapshot, alternatif NTFS stream/SACL/hardlink topolojisi taraması veya etkili yazma yetkisi kabulü değildir. Ayrıntı **SYSVOL_STAGING_PREPARATION.md**.

🔴✓ Son head üzerinde dört workflow başarılı. Native Windows **15 kontrol**: gerçek NTFS kararlı liste, alt dosya/içerik değişimi, junction reddi, dosya boyutu/derinlik sınırları, exact embedded source, GPO adı/marker/durum ve namespaced XML link/ayar/sürüm guard'ları. Mevcut genel kaynak, Connector/SCM/rollback/scope ve network probe kontrolleri geçti. CI verileri müşteri AD/SYSVOL kabulü sayılmaz.

🔴✓ Sabit DC01 operator wrapper **/home/segmentiq/authwire-dc01-sysvol-inventory-20261027.ps1**, SHA256 **fdd7adc70aa401740dd1595b644a688053b165054cd993883335da5377e912d8**, Linux kopya özeti doğrulandı. Owned GPO **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** için unlinked/empty/version0 guard, iki tam envanter özeti ve GPO modification-time karşılaştırması yapar. Çıktı **WINDOWS_SYSVOL_FULL_INVENTORY_READONLY**. **Müşteri çalıştırması ve gerçek alt ağaç sonucu henüz yok.** Operator okumasıdır, gMSA runtime veya panel attestation değildir. Kesin I/O süre sınırı gelecekte bounded child entegrasyonunda korunmalıdır; bu standalone operatör aracına30 saniyelik süre garantisi verilmez.

**Devam:** DC01 readonly sonucu al; sonra eksiksiz enrollment/installer paketini ve ayrı kontrollü staging yazıcısını geliştir. Mevcut aday yalnız ağ XML paketidir. Bu çalışma paket kopyalamaz, GPO link/startup/sürüm/ayarlarını, hesap/sertifika/anahtarları veya mevcut Connector paketini değiştirmez. Windows worker **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**, Linux dev.40 korunur. Tam yedek yok; **can_apply=false**, genel **54/94,40 açık** ve nihai kılavuz beklemesi sürer. Kanıt **checkpoints/2026-10-27-sysvol-inventory-prepared.json**.

## 🔴✓ İlk gerçek panel → Connector → AD/GPO okuma sonucu operatör görseliyle kabul edildi — 27 Ekim 2026

Operatör **image(20261027-204325).png** görselini paylaştı; SHA256 **ec16ac6412298ec77b5c8ef2904c17eb5e14c6f205bbdd2152f1dab8818bf8dc**. Mevcut **AuthWire Pilot - Merkezi Windows · v1** kaydı ve manifest **4f7a463d3404428703bb95424d8c8a7f275e85f6a3a42d7a270f6eaae5ba9a6d** altında **AD hedefleri ve GPO okuma kontrolü başarılı. Dağıtım henüz uygulanmadı.** mesajı görünüyor. Panel kontrol zamanı **27.10.2026 23:42:47**. Bu operatör UI kanıtıdır; ayrı asistan backend/SQL/raw signed result incelemesi değildir. Görsel job UUID, kayıt UUID veya runtime PID içermiyor; bunlar varsayılmaz. Görsel Library ID **libfile_c2c2f0bcb23c81918d5cd0db8114ed82**.

🔴✓ İncelenmiş dev.40 panel sözleşmesinde bu mesaj, güncel kapsam için authenticated Connector scope sonucu **scope_snapshot_verified** ve90 saniyelik tazelik koşulu sağlandığında gösterilir. Böylece önceki aday imza/içerik kabulüne ek olarak, yeni Windows scope worker'ın gerçek panel görevi üzerinden AD hedef kümesi ve owned GPO/root ACL okuma roundtrip'i dar kapsamda kabul edildi. Tazelik anlıktır; daha sonra yeniden kontrol gerektirebilir. Üstteki genel “GPO ve dağıtım kontrolü bekleniyor” satırı daha geniş dağıtım kapısını anlatır; alttaki ayrı okuma başarısını geçersiz kılmaz.

**Kabul sınırı:** Etkili yazma yetkisi, tam SYSVOL alt ağaç envanteri, paket staging, GPO bağlama/uygulama,200 cihaz saha/performans kabulü ve gerçek endpoint kurulumu tamamlandı sayılmaz. **can_apply=false** korunur. Başarılı Prepare/Apply veya aynı kontrol gereksiz tekrarlanmayacak. Yeni kaynak/servis/AD-GPO/uç/key-ACL işlemi yapılmadı. Sonraki çalışma tam SYSVOL/paket staging tasarımı ve ayrı kontrollü pilot uygulama kapısıdır; canlı GPO uygulaması bu görselden yetkilendirilmiş veya yapılmış sayılmaz. Ana durum **54/94,40 açık**, nihai kılavuz kapanışı yok.

## 🔴✓ DC01 scope worker etkinleştirmesi operatör çıktısıyla kabul edildi — 27 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY / ToolVersion1.2.0 / Mode=Apply / Stage=applied / Error=null / ChangesMayBePartial=false** sonucunu paylaştı. Kaynak **28578aa67244d0d8fdf24206dc0ce6f99cf8c73c**, yeni release **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**, önceki **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** beklenenle aynı. Bu operatör çıktısı kabulüdür; bağımsız DC01 servis sorgusu değildir ve yeni PID varsayılmaz.

🔴✓ **ServiceTransitioned=true, SourceSignaturesValid=true, SignerSnapshotPreserved=true**. İncelenmiş upgrader sözleşmesine göre applied aşaması yeni sürümün güncel health/probe/candidate/scope kanal kapılarından geçmiştir; bir aday için gerçek AD/GPO snapshot başarısı henüz kanıtlanmış değildir. Hesap/binding/kanal anahtarı/orijinal kaynaklar korunmuş. Yeni servis veya anahtar oluşturulmamış; AD/GPO, trust ve key ACL değişikliği ya da sır dışa aktarımı yok. Evidence **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-efc5ee91e39e4cc49cc160b648e18cf9-aaa158735b124499bdb98d8c03fd3b26**. Önceki paket scoped .previous-b5469eaa0ccf4558bd84c2f6a10ecb2f arşivinde; müşteri rollback testi yapılmadı.

**Sıradaki kabul:** Panelde mevcut **AuthWire Pilot - Merkezi Windows · v1** adayını Yenile; **AD/GPO kontrolünü önizle** üzerinden tek scope görevi gönder; worker döngüsü ardından Yenile ile sonucu incele. Yeni aday/plan/receipt oluşturulmayacak, başarılı Prepare/Apply tekrarlanmayacak. Gerçek gMSA hedef üyelik/GPO okuma ve panel sonucu hâlâ bekliyor. **CanApplyGpo=false**, Linux dev.40, **54/94,40 açık** korunur; nihai ürün/kılavuz kapanışı yok.

## 🔴✓ DC01 scope worker aday paket hazırlığı operatör çıktısıyla kabul edildi — 27 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY / ToolVersion1.2.0 / Mode=Prepare / Stage=prepared / Error=null / ChangesMayBePartial=false** çıktısını paylaştı. Kaynak **28578aa67244d0d8fdf24206dc0ce6f99cf8c73c**, önceki release **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f**, yeni release **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9** beklenenle aynı. Bu operatör JSON kabulüdür; bağımsız asistan DC01 sorgusu değildir.

🔴✓ SourceSignaturesValid, PackagePrepared, ExistingAccountPreserved, PairingPreserved, ChannelKeyPreserved, OriginalSourcesPreserved ve SignerSnapshotPreserved=true. **ServiceTransitioned=false**; eski hizmet henüz değiştirilmedi. AD/GPO, trust/key ACL, kanal anahtarı oluşturma ve sır dışa aktarma yok. Evidence **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-efc5ee91e39e4cc49cc160b648e18cf9-b23b9b7e259847f8956135e37b84f4b3**.

**Sıradaki adım:** Aynı SHA256 kontrollü teslimatı **Mode=Apply** ile etkinleştirmek; sonra mevcut pilot kaydından gerçek gMSA AD/GPO okuma görevi. Apply henüz çalıştırılmadı, müşteri scope sonucu kabul edilmedi. **CanApplyGpo=false**, Linux dev.40 ve genel **54/94,40 açık** durumu korunur; nihai ürün/kılavuz kapanışı yok.

## 🔴✓ Windows salt okunur AD/GPO scope worker ve yükseltme teslimatı hazır — DC01 Prepare/Apply bekliyor — 27 Ekim 2026

**PR102** birleştirildi. Kaynak bileşeni **28578aa67244d0d8fdf24206dc0ce6f99cf8c73c**, son test head **06a753949f06840f5b989a979f3f3371bf81f84e**, merge **f90cfb1e131acaef63c6372d2654dfeaf6c0b27d**. Windows yeni release **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**, son kabul edilen önceki release **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f**. Linux dev.40 kurulumu önceki operatör kabulüyle geçerli; yeniden kurulmayacak.

🔴✓ Yeni imzalı sabit okuyucu mevcut aday içeriğini, tam recursive/primaryGroupID bilgisayar SID kümesini ve enabled durumlarını, owned GPO kimlik/marker/owner/izin/link/ayar/sürüm alanlarını ve SYSVOL kök ACL/girdilerini iki kez okur. Ayrı scope kuyruğuna imzalı typed sonuç gönderir. Okuma en fazla30 saniye, stdout8192/stderr2048 karakter,128 grup/4096 üyelik kenarı/512 bilgisayarla sınırlıdır. İstekle komut/yol/LDAP filtre/URL alınmaz; AllSigned sabit alt süreç kullanılır. Yeni hizmet sürümünün kabulü health/probe/candidate/scope kanallarının hepsini gerektirir. Mevcut hesap/binding/kanal anahtarı korunur; eski üç paket ailesi dondurulmuş kaynak özetleriyle tanınır. Etkili yazma yetkisi, tam SYSVOL alt ağaç envanteri, staging, GPO uygulama veya gerçek uç kabulü değildir. Ayrıntı **WINDOWS_SCOPE_WORKER.md**.

🔴✓ Son head üzerinde dört workflow başarılı: tam kaynak **905 test /28 ortam atlaması**, native WinPS5 scope **33 kontrol**, gerçek düşük yetkili imzalı SCM/TLS hizmeti **82 kontrol**. Nested/primary-group sorgu şekli,200 bilgisayarlık sentetik kapsam, namespaced GPO XML/gerçek NTFS ACL nesnelerinden snapshot oluşturma, timeout/çıktı sınırı/AllSigned reddi, ayrı scope negatif sonuç roundtrip'i ve kanal hatasında otomatik/elle rollback geçti. AD/GPO verileri CI'da simüledir; müşteri gMSA scope kabulü sayılmaz. Eski immutable teslimat korunur. Native signer metadata/CLR marker ve ACL koruma kontrolü geçti. İlk fixture koşularındaki dosya listesi, asenkron yerel durum bekleme ve audit sayım hataları düzeltildi; yalnız son yeşil head kabul edildi.

🔴✓ **19 kaynaklı** DC01 wrapper Linux home'a kondu ve özeti doğrulandı: **/home/segmentiq/authwire-dc01-scope-worker-upgrade-20261027.ps1**, SHA256 **a8c3ef1692553f5ec65156d748372c6a9b84196b8da7a4e9e8ec70474209743e**. Bu yalnız teslimat dosyası hazırlığıdır. **DC01 Prepare/Apply çalıştırılmadı; Windows scope worker kurulmadı ve müşteri scope görevi oluşturulmadı.** Prepare ayrı imzalı aday oluşturur; çalışan hizmeti değiştirmez. Sonrasında ayrı Apply ve mevcut pilot kaydından AD/GPO kontrolü gerekir. Gerçek aw-deploy$ AD/GPO okuması ve panel sonucu bekleniyor; **can_apply=false** kalır.

Linux'ta uid1000 ile salt okunur systemctl kontrolünde RADIUS **1243360**, broker **1069437**, ikisi de active ve önceki PID'lerle aynı görüldü. Windows/AD/GPO/istemci/key/trust ayarı değiştirilmedi; tam yedek alınmadı. Durum **54/94 (~%57),40 açık**; nihai ürün/kılavuz kapanışı yok. Kanıt **checkpoints/2026-10-27-scope-worker-delivery-prepared.json**.

## 🔴✓ Dev.40 Linux kurulumu ve koruma kontrolleri operatör çıktısıyla kabul edildi — 27 Ekim 2026

Operatör **SCOPE_JOBS_FINISHED verified=true**, sürüm **0.14.0-dev.40**, release **4543e25b3675202a828047c4a0628570939d6fe0**, changed=true sonucunu paylaştı. Kanıt **/var/lib/authwire-updates/scope-jobs-dev40-20261027T195658Z-de05f1b5**. Bu operatör kurucu JSON kabulüdür; ayrı root DB/kanıt dizini incelemesi yapılmadı.

🔴✓ Protected files, broker/RADIUS süreçleri, timer ve business state kontrolleri true. RADIUS aktif, yeniden başlamadı; PID **1243360** öncesi/sonrası aynı, broker süreci korundu. Gösterilen önce/sonra panel okumalarının tamamı200; candidate status sonrası median17.4ms/max36.9ms. Plan/policy/sertifika/eşleştirme/AD-GPO/Windows uç ve paket/native module/backup worker değişmedi. Tam yedek alınmadı, günlük timer korundu. Public appliance kimliği/domain/FQDN ve TLS pini öncekiyle aynı; sır dışa aktarılmadı.

**Sınır:** Sunucu/panel scope kanalı artık kurulu. Scope/probe/candidate işi oluşturulmadı; **gpo_apply_enabled=false, windows_scope_worker_delivery_pending=true**. Gerçek gMSA canlı AD/GPO scope işi, yeni Windows worker ve tarayıcı/gerçek uç kabulü tamamlanmadı. Başarılı Linux kurucusu yeniden çalıştırılmayacak. Sıradaki çalışma mevcut **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** Windows paketinden süre/çıktı sınırları test edilmiş imzalı scope worker yükseltmesini hazırlamak; hesap, binding, kanal anahtarı, signer/ACL/CLR marker korunacak. Kanıt **checkpoints/2026-10-27-scope-jobs-linux-accepted.json**. Ana durum **54/94 (~%57),40 açık**, kılavuz kapanışı yok.

## 🔴✓ Ayrı AD/GPO okuma görev kanalı dev.40 hazır — Linux sudo ve Windows worker bekliyor — 27 Ekim 2026

**PR101** main'e birleştirildi. Kaynak bileşeni **4543e25b3675202a828047c4a0628570939d6fe0**, son test head **2547db71169da01b9a79399445255a0a516da28f**, merge **96cebc77ab777ca617ae19fe525608c68cac0893**. Önceki yönetici AD/GPO snapshot kabulü korunur; bu ayrı sunucu/panel geliştirmesi gerçek gMSA scope görevi kabulü değildir.

🔴✓ **deployment.scope.verify.v1** ayrı defter, peer yolları, imza amacı, capability ve preview/create ile hazır. Eski içerik/probe worker bu kuyruğa giremez. Önceden kabul edilmiş içerik ve güncel plan/profile/catalog/config/trust/binding gerekir. İlk20 ekran örneği yerine bütün recursive bilgisayar SID'leri özete bağlıdır. V1 sözleşme1–512 etkin aynı-domain bilgisayar; bu 200 cihaz performans/saha kabulü değildir. Kapalı/çözümlenemeyen veya farklı domain hedefler reddedilir. Sınırlı payload, replay/lease/deadline, tek aktif iş,32 kayıt sınırı ve idempotent sonuç korunur. Typed sonuç yedi sabit okuma kontrolü, zaman, neden ve snapshot özetiyle sınırlı; geçmiş başarılı snapshot ve90 saniyelik güncellik ayrı gösterilir. Sonraki ret eski başarıyı kaldırır. **connector_verified/can_apply=false**; etkili yazma yetkisi, tam SYSVOL alt ağaç doğrulaması, staging veya GPO uygulama yoktur. İki güncel yönetici yetkisi ve HTTPS/Host/Origin/CSRF/panel oturumu sınırı korunur. Sözleşme **DEPLOYMENT_SCOPE_JOB_CHANNEL.md**.

🔴✓ **64 hedefli yerel test**, buna dahil33 scope/gerçek HTTPS/kurucu testi; tam GitHub checkout'ta **903 test /28 ortam atlaması** ve yedi PR workflow başarılı. Tarayıcı capability kapısı, içerik/scope ayrımı, kayıp yanıtta tek oluşturma/GET uzlaştırma, snapshot süre/ret ve yetki reset'i geçti. Mevcut Windows/Kerberos ve gerçek RADIUS protokol kontrolleri geçti; yeni müşteri Windows scope worker çalışması sayılmaz. Kısmi yerel kopyada eski checkpoint/logo eksikliğinden54 missing-file hatası veren geniş koşu başarı sayılmadı; otoritatif tam kaynak CI geçti.

🔴✓ Linux home'da **180 dosyalı** ayrı stage, kurulu önceki kaynak baseline'ı, manifest, source_guard ve mevcut venv import'u doğrulandı. Kurucu **/home/segmentiq/authwire-scope-jobs-20261027.py**, SHA256 **b0bdd9dbc573f04d9cc69c671b82bbaa5549b661342cc1bc9e2122b77788e8c3**. Stage **/home/segmentiq/authwire-stage-dev40-4543e25b3675**, manifest **cbe06e8d9d93b5c6c967da4f7c62f00197eec96a1f42bbc916c7ea3c1d436aa4**. Yalnız altı uygulama/sürüm dosyası değişir ve panel yeniden başlar; authentication kaynakları, RADIUS/control PID, Windows istemcileri, policy/sertifika/plan/kayıtlar, görev/sonuçlar ve timer korunur. Heartbeat/replay cache dışında iş defteri değişiklikleri fingerprint'e dahildir. Tam yedek yok, küçük kod geri dönüş kanıtı var; aktif yedekte uygulama reddedilir, eşzamanlı business değişikliğinde veri geri sarılmaz.

**Canlı hâlâ dev.39; sudo çalıştırılmadı.** Son okuma RADIUS1243360/broker1069437 active/success; yeni Windows/gMSA, AD/GPO, uç, key/CLR marker/ACL veya root hizmet işlemi yapılmadı. Son tekrar SHA sorgusu uzak bağlantıda gecikti ve bekleyen orchestration durduruldu; read-only sorgu için değişiklik iddiası yok. Önceki başarılı doğrulamalar kayıtlı, operatör komutu özeti tekrar denetler.

**Devam:** pinned Linux kurucusundan **SCOPE_JOBS_FINISHED verified=true** al; sonra ayrı gözden geçirilmiş, süre/çıktı sınırları test edilmiş imzalı Windows scope worker yükseltmesi ve gerçek aw-deploy$ ile panel görevi. Mevcut Windows worker değişmedi; scope düğmesi yeni capability gelene kadar kapalı kalır. Protected trust GPO ve çalışan802.1X korundu. **54/94 (~%57),40 açık** değişmedi; nihai ürün/kılavuz kapanışı yok. Kanıt **checkpoints/2026-10-27-scope-jobs-delivery-prepared.json**; operatör komutu **checkpoints/2026-10-27-scope-jobs-linux-run.sh**.

## 🔴✓ Canlı AD hedefleri ve yönetilen GPO operatör okuması kabul edildi — 27 Ekim 2026 18:23 İstanbul

Operatör **Yapıştırılan metin(7).txt** içinde **WINDOWS_DEPLOYMENT_SCOPE_OPERATOR_READONLY v1.0.0** sonucunu paylaştı. DC01’de **VIZYONVERI\\administrator** ile 15:23:50–15:23:54Z arasında çalıştı; **OperationError=null, Blockers=[], ReadyForNextReview=true**. Ek dosya SHA256 **7678a18926c92e062d6a3ca1eb310da2c6a4458a6c4eba3b89d7a0404a703791**.

🔴✓ Sabit SHA256’li onaylı ağ adayındaki pilot hedef SID’leri canlı recursive AD grubuyla eşleşti. **2GL13ZU / SID …-1105 / GUID 8c150ec9-59ac-41fe-9f12-5a7023e1a999** ve **VV06 / SID …-1644 / GUID 69b0d5cd-db61-4627-9db7-fcc5230152a3** etkin; disabled ve diğer üye sayısı0. Bu okuma anına ait doğrulama; gelecekteki üyelik/güncellik garantisi değildir.

🔴✓ Ayrı **AuthWire-Managed-Deployment-4c23eebe / 8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** GPO adı, sahiplik işareti ve Domain Admins sahibi beklenenle eşleşti. GPMC izinleri kayıtlı dar kapsamla aynı: gMSA **GpoEdit**, pilot **GpoApply**, Authenticated Users **GpoRead**. Rapor link listesi boş, ayar uzantısı0, bilgisayar/kullanıcı AD ve SYSVOL sürümleri0. SYSVOL yolu eşleşti; kökte Machine/User, GPO.cmt426 bayt ve GPT.INI59 bayt görüldü. Root ACL’de gMSA write/read/delete-child izni var, doğrudan ChangePermissions/TakeOwnership kaydı yok; bu etkili gMSA runtime erişim testi değildir. Protected trust GPO kimliği/adı eşleşti; geçmiş tam durum karşılaştırması yapılmadı.

**Kabul sınırı:** Başarılı gerçek operatör salt okunur snapshot ve native script çalışmasıdır. SYSVOL alt ağacı sayılmadı, hizmet hesabının bu işi yürüttüğü veya bütün GPO durumunun sabit kaldığı iddia edilmez. **GmsaRuntimeTested/PanelAttestationUpdated/CanApplyGpo=false**. AD/GPO, servis, uç, trust ve key ACL değişikliği yok; tam yedek alınmadı. Aynı başarılı kontrol tekrarlanmayacak. Kanıt **checkpoints/2026-10-27-deployment-scope-readonly-accepted.json**.

**Sıradaki geliştirme:** Aynı kapsamın ayrı sınırlı typed Connector göreviyle güncel AD ve owned-GPO doğrulamasına taşınması; panelde eski/değişmiş hedef/izin/link/sürüm reddi. Ardından tam SYSVOL/paket hazırlığı ve ayrı pilot uygulama kapısı. İçerik doğrulaması bu yeni kapsamın yerine geçmez. Üst sayım **54/94 (~%57),40 açık** korunur; rapor dosyaları bu dar kabul için yeniden üretilmedi; nihai ürün/kılavuz kapanışı yok.

## 🔴✓ 27 Ekim durum raporu teslimatı ve sonraki salt okunur kontrol hazır

Operatörün isteğiyle güncel **9 sayfalık Word/PDF durum raporu** hazırlandı. Önceki raporun 25 Ekim revizyonu ve güncel main kabul kayıtları okundu. B01–B12 **44/59**, G01–G07 **10/35**, toplam **54/94 (~%57),40 açık (~%43)** sayımı korundu. 25–27 Ekim KDS/gMSA, gerçek imzalama, kalıcı Connector, aşamalı worker güncellemesi ve ilk müşteri içerik roundtrip kabulleri kırmızı tikle ayrıldı. Bunlar açık A03/A04 ana işine ikinci puan eklemez. Yarım işler, gerçek uç/AD/kurtarma/ölçek testleri, tek hesap geçişi ve nihai kılavuz ayrı açık. İptal edilmiş özellik güncel kapsam sayılmadı. Kaynak metin **reports/2026-10-27-status-report.md**, teslimat kaydı **checkpoints/2026-10-27-status-report.json**. Word ve iki biçimi birlikte taşıyan arşiv kaydedildi; PDF bağımsız transferi başarısız oldu, aynı doğrulanmış PDF arşiv içinde korunur.

**Devam çalışması:** Mevcut onaylı ağ ZIP SHA256'sine bağlı **operatör salt okunur AD/GPO anlık okuma** scripti hazırlandı ve Linux home'a kopyası özetle doğrulandı. Kaynak **checkpoints/2026-10-27-dc01-deployment-scope-readonly.ps1**, SHA256 **f2a149bef2726bfe0e2b2708388b3d29d2fbd5b3bc362ea17b529363bf02711c**. Pinned planın tam SID örnek listesiyle canlı recursive bilgisayar üyeliğini karşılaştırır; enabled/GUID, owned GPO marker/name/owner/permissions/link/settings/versions/SYSVOL root ve protected trust GPO kimliği raporlanır. Yetki veya GPO tanımı yazmaz, servis çalıştırmaz, özel anahtar açmaz, gpupdate yapmaz. Root ACL/dizin üst düzeyi okunur; bütün SYSVOL alt ağacını veya etkili gMSA yazma yetkisini doğruladığı iddia edilmez. Alan değerleri değişmiş veya okuma eksikse blocker üretir. **Native DC01 çalıştırması/sonucu henüz yok; canlı AD/GPO kontrolü kapanmadı.** Kayıt **checkpoints/2026-10-27-deployment-scope-readonly-prepared.json**. Bu operatör okuması, sonraki ayrı sınırlı Connector scope görevinin yerine geçmez; panel attestation ve can_apply=false korunur.

Rapor/teslimat ve yalnız home dosyası hazırlığı yapıldı. Canlı panel/RADIUS/Connector kodu, service state, business policy, AD/GPO, uç, PKI/key ACL ve yedek timer değiştirilmedi; tam yedek alınmadı.

## 🔴✓ İlk gerçek panel → Connector → imza/içerik doğrulama sonucu kabul edildi — 27 Ekim 2026

Operatör **image(20261027-140716).png** ekran görüntüsünü paylaştı. **AuthWire Pilot - Merkezi Windows · v1** kaydında **İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.** mesajı görünüyor. Manifest **4f7a463d3404428703bb95424d8c8a7f275e85f6a3a42d7a270f6eaae5ba9a6d**, daha önce kabul edilen DC01 adayıyla aynı. Görsel SHA256 **030fd471ee8ceca3cb1c8c3efbd896764b36e5623d3213d4d5e4dcf8ea88f68c**.

🔴✓ Mevcut panelden gönderilen ilk olumlu müşteri aday içerik görevi, operatörün UI kanıtıyla kabul edildi. İncelenmiş dev.39 UI'si bu mesajı yalnız güncel kayıt için authenticated worker sonucu **content_verified** olduğunda gösterir. Bu ayrı asistan backend GET/SQL veya raw signed result incelemesi değildir; job UUID, kayıt UUID veya runtime PID görüntüde yoktur ve varsayılmaz. Alt taraftaki “Doğrulama görevi kaydedildi...” bildirimi gönderim geri bildirimidir; üstteki başarı satırı sonuç durumudur. Statik operatör-bildirimi açıklaması orijinal receipt'in kaynağını anlatır, yeni sonucu iptal etmez.

Bu aşamanın kabulü **imza ve içerikle sınırlı**. Canlı AD hedef üyelikleri/güncelliği, owned GPO marker/izin/link kapsamı, SYSVOL staging, GPO uygulama ve endpoint kurulumu tamamlandı sayılmaz. **connector_verified=false / can_apply=false** kapıları tasarım gereği korunur; görüntüdeki “GPO ve dağıtım kontrolü bekleniyor” mesajı beklenen durumdur. Yeni source, servis, AD/GPO/endpoint veya key/ACL işlemi yapılmadı; başarılı görev/manuel probe tekrarlanmayacak.

Linux **dev.39** ve Windows release **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** önceki operatör kabul kayıtlarıyla geçerli. Sıradaki geliştirme canlı AD hedef kapsamı ve yönetilen GPO'nun güncel kimlik/izin/link kontrolünü salt okunur, sınırlı typed görev olarak eklemek; uygulama kapısı ayrıca kalacak. **54/94 (~%57),40 açık** işlevsel ana durum değişmedi; merkezi otomasyonun bir alt kabulü tamamlandı. Nihai ürün/kılavuz kapanışı iddia edilmez.

## 🔴✓ DC01 yeni aday worker etkinleştirmesi kabul edildi; panel görevi bekleniyor — 27 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY / Mode=Apply / Stage=applied / Error=null / ChangesMayBePartial=false** çıktısını paylaştı. Kaynak component **6d19a86846948aa126aef222671f6f80be64e9de** ve yeni release **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** beklenen paketle eşleşiyor. Önceki release **970d7039-3798-478b-a5f4-a57e245693a0**. Bu operatör çıktısı kabulüdür; bağımsız asistan DC01 servis sorgusu değildir, yeni PID varsayılmaz.

🔴✓ **ServiceTransitioned=true, SourceSignaturesValid=true, SignerSnapshotPreserved=true**. İncelenmiş upgrader sözleşmesine göre yeni paket için güncel health/probe/candidate kanalı guard'ları geçerek applied kaydına ulaşılmıştır; henüz bir adayın imza/içeriği bu kanaldan doğrulanmış sayılmaz. **ExistingAccountPreserved, PairingPreserved, ChannelKeyPreserved, OriginalSourcesPreserved=true**. Scoped eski kod arşivi **.previous-970d70393798478ba5f4a57e245693a0** olarak tutuluyor; müşteri rollback testi yapılmadı. Yeni işlem evidence **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-b5469eaa0ccf4558bd84c2f6a10ecb2f-047e8264d0d64e1a8d1f2c859aaf111f**.

Yeni servis oluşturma, kanal key oluşturma, signer key ACL/trust değişikliği, AD/GPO yazımı veya secrets export yok. Native signer before/after kabulü yalnız bu Apply işlemi içindir; eski başarısız wrapper geriye dönük kabul edilmez. Linux **dev.39** korunuyor; Linux kurulumu/Apply/manual probe tekrar edilmeyecek. **CanApplyGpo=false**.

Sıradaki kabul **Sertifikalar → Merkezi dağıtım → İmzalı dağıtım adayları** altındaki mevcut **AuthWire Pilot - Merkezi Windows · v1** kaydında **Yenile → Doğrulamayı önizle → Doğrulamayı gönder**. Bu yalnız mevcut adayı okur. Worker döngüsü sonrasında Yenile ile beklenen mesaj **İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.** Henüz bu gerçek panel görevi oluşturuldu veya tamamlandı iddia edilmez. Receipt yeniden yapıştırılmayacak; aday yeniden hazırlanmayacak.

Olumlu müşteri job roundtrip, canlı AD/GPO freshness/kapsam, SYSVOL staging ve endpoint kabulü hâlâ bekliyor. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ DC01 aday worker paketi hazırlığı kabul edildi; Apply bekleniyor — 27 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY / ToolVersion=1.1.0 / Mode=Prepare / Stage=prepared / Error=null / ChangesMayBePartial=false** çıktısını paylaştı. Kaynak component **6d19a86846948aa126aef222671f6f80be64e9de**, yeni release **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** beklenen teslimatla eşleşiyor. Bu operatör çıktısı kabulüdür; asistan DC01'de bağımsız sorgu veya çalıştırma yapmadı.

🔴✓ **SourcesPreparedNow=true, SourceSignaturesValid=true, PackagePrepared=true**. Exact signed kaynaklar ve ayrı candidate paket hazırlanmış; upgrade journal **C:\ProgramData\AuthWire-ConnectorUpgrade-4c23eebe071546d188eea2e96ad7ee46-b5469eaa0ccf4558bd84c2f6a10ecb2f\upgrade.json**. **SignerSnapshotPreserved=true** yeni hazırlama işlemindeki native binding/policy/marker/key ACL önce/sonra kontrolünü kabul eder. Evidence **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-b5469eaa0ccf4558bd84c2f6a10ecb2f-72ab8d07a428476f95271b51cbff6aba**. Bu, geçmişteki başarısız probe wrapper'ın eksik before snapshot'ını geriye dönük tamamlamaz.

**ServiceTransitioned=false, ServicesCreated=false**; mevcut release **970d7039-3798-478b-a5f4-a57e245693a0** üzerinde etkinleştirme henüz yapılmadı. Hesap, pairing, kanal anahtarı ve eski kaynaklar korunmuş. Signer key ACL, trust, AD/GPO değişikliği veya secrets export yok; GPO apply kapalı.

Sıradaki operatör adımı aynı hash-sabitli dosyada **-Mode Apply**. Yalnız Windows Connector kısa süreli durup yeni paketle başlayacak; health/probe/candidate kanalı güncel kabul edilmezse core eski paketi geri yükleyecek. Henüz Apply sonucu, yeni müşteri worker health'i veya panelden olumlu aday görevi kabulü yok. Linux dev.39 kurulumu tekrarlanmayacak; eski manuel probe tekrar edilmeyecek. **54/94 (~%57),40 açık** korunur.

## 🔴✓ Windows aday worker güncellemesi test edildi ve teslimata hazır — 27 Ekim 2026

**PR100**, son test edilen head **a7622b8ba58e46b6f82e85ffd92487f1dc17d7c6**, kaynak component **6d19a86846948aa126aef222671f6f80be64e9de**, merge **5da1c27f20bd5fd615379d7c4b0ce6ad45701b95**. Mevcut **970d7039-3798-478b-a5f4-a57e245693a0** release'inden **b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f** release'ine aynı servis/hesap/eşleme/kanal anahtarıyla staged yükseltme hazırlandı. Linux **dev.39** zaten operatör çıktısıyla kabul edilmiş durumda; tekrar Linux kurulumu gerekmiyor.

**Prepare** sabit 16 kaynak dosyasını doğrulayıp mevcut machine signer ile imzalar ve ayrı candidate klasöründe yeni paketi derler; mevcut servisi durdurmaz. Tekrar Prepare aynı paketi doğrular. Ayrı **Apply** health/probe yanında güncel **CandidateChannelVerified** ister; yeni görev kanalı başarısızsa eski paket otomatik geri yüklenir. Bu GPO veya endpoint uygulaması değildir.

Signer kontrolü CLR marker'ını persistence hükmü olarak kullanmaz: native container/unique keyfile/public-key eşleşmesi, RSA3072/machine/export0/usage2 ve exact key ACL birlikte doğrulanır. Önce/sonra marker, key identity ve ACL karşılaştırılır; yeni işlem için küçük admin-only before/after/result kayıtları tutulur. Marker, key/association/ACL değiştirilmez; yeni sertifika üretilmez. Inspect kaynak/servis/evidence oluşturmaz. Eski başarısız wrapper geriye dönük kabul edilmez ve başarılı manuel probe tekrarlanmaz.

🔴✓ Kaynak head'deki **7 farklı kontrol işinin tüm check-run kayıtları başarılı**; GitHub merge durumu clean olarak doğrulandı. Foundation **870 test /28 skip**, native SCM **76**, native signer **23** ve exact archive/current source **2** kontrolü geçti. Gerçek düşük yetkili SCM fixture'da candidate kanalı kapalıyken (health/probe çalışsa da) yükseltme geri alındı. Fixture'a ait nonexportable RSA3072 anahtar CLR marker **01** korunarak gerçek Authenticode imzası üretti; binding/export/marker/ACL aynı kaldı. Bunlar müşteri gMSA/DC01 kabulü değildir. Workflow roll-up ve tamamlanmış check-run ham durumları checkpoint'te ayrı saklandı.

**DC01 teslimatı henüz çalıştırılmadı.** Linux home **/home/segmentiq/authwire-dc01-candidate-worker-upgrade-20261027.ps1**, **91939 byte**, SHA256 **3abcfea6d4ba2a6bdc8bf59731d300cebbce6f1aa166947cc948f74452671bff** uzak okumayla doğrulandı; repo merge byte'larıyla aynı. Asistan yalnız home'a teslimat dosyası yazdı. Operatöre yalnız **-Mode Prepare** komutu verilecek; Apply henüz istenmedi. Eski servis/eşleme/anahtar/aday korunacak; tam veri yedeği alınmayacak. GPO apply kapalıdır.

Sırada DC01 yönetici Windows PowerShell **5.1** içinde bu hazırlama sonucu var; ardından Apply ve gerçek panel imza/içerik görevi ayrıca kabul edilecek. Canlı AD/GPO freshness/kapsam, SYSVOL staging ve endpoint kabulü bekliyor. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ Dev.39 Linux kurulumu operatör çıktısıyla kabul edildi — 27 Ekim 2026

Operatör **CANDIDATE_JOBS_FINISHED / verified=true / changed=true / 0.14.0-dev.39** çıktısını paylaştı. Release **cf0be7fbdd3df8b3dac7d535d353af8bdb9f149a** beklenen kaynak component ile eşleşiyor. Evidence **/var/lib/authwire-updates/candidate-jobs-dev39-20261027T132300Z-271fcb5a**. Bu kabul operatörün updater çıktısına dayanır; bağımsız asistan backend sorgusu değildir.

🔴✓ Korumalı dosyalar, broker/RADIUS süreçleri, timer'lar ve iş verisi kontrolleri başarılı. RADIUS PID **1243360** önce/sonra aynı; broker süreci korunmuş, RADIUS yeniden başlatılmamış. Önce/sonra gösterilen panel okuma sonuçları **200**, aday ve görev API'leri dahil. Tam veri yedeği alınmamış; günlük backup timer korunmuş. Policy, plan, pairing, sertifika, AD/GPO, Windows paket/endpoint, native modül ve backup worker değişikliği yok.

**candidate_jobs_created=false, gpo_apply_enabled=false, windows_candidate_worker_delivery_pending=true** beklenen durum. Yeni görev kanalı Linux tarafında kurulmuş; eski Windows worker yeni capability bildirmediği için imza/içerik görevi henüz gönderilmeyecek. Operatör browser kabulü ve müşteri worker roundtrip hâlâ bekliyor. Sırada mevcut release **970d7039-3798-478b-a5f4-a57e245693a0** korunarak yeni signed/staged Windows Connector paketinin hazırlanması var; yeni hesap, eşleme veya kanal anahtarı oluşturulmayacak.

Mevcut imzalı aday ve operatör receipt korunuyor; eski başarılı manuel probe tekrarlanmayacak. Signer CLR marker/anahtar/ACL onarımı veya sertifika yenilemesi gerekmiyor. Canlı AD/GPO kapsam/freshness, SYSVOL staging ve endpoint kabulü hâlâ bekliyor. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ Connector aday içerik görevi geliştirildi; dev.39 kurulumu bekleniyor — 27 Ekim 2026

**PR99**, test edilen head **406d3d5b46971874d450ff1a83ee311b1c302191**, merge **e93365d1e160f7a18780a98c09a550a2eee69fde**, uygulama kaynak component **cf0be7fbdd3df8b3dac7d535d353af8bdb9f149a**. Mevcut aday kaydından **Doğrulamayı önizle → Doğrulamayı gönder** akışı eklendi. Görev yalnız imza ve içerik kontrol eder; ayrı signed capability bildirmeyen eski Connector'a gönderilmez. Sonuç **content_verified / İmza ve içerik doğrulandı** olur; **connector_verified=false, can_apply=false** korunur. Canlı AD/GPO kontrolü ve dağıtım kabulü yerine geçmez.

Görev ve sonuç Connector binding, plan/sürüm, approval/manifest ve güncel plan/profile/katalog/trust/config özetlerine bağlıdır. Scope create/poll/result/durum aşamalarında tekrar okunur; değişen kapsam reddedilir. Süreli lease, replay reddi, aynı sonucun tekrarında idempotent kayıt ve iki güncel panel yetkisi/CSRF kontrolü vardır. Yol, komut, URL, script veya AD filtresi istekten alınmaz. Worker korumalı sabit yerel dizinde en fazla 32 kayıt içinden exact approval hash ile tek adayı seçer; publisher paket config'inden gelir. Başarılı eski receipt değiştirilmez. Yeni red sonucu önceki içerik başarı etiketini kaldırır.

🔴✓ Son head'de **8 workflow başarılı**. Foundation **868 test /28 skip**; gerçek SQLite/RSA ve HTTPS job/rol/lease/eskime/idempotency, **29 yerel job/HTTP/delivery testi**, tarayıcı önizleme/gönderme/yanıt kaybı/eskimiş önizleme iptali geçti. Windows aday **55**, non-admin verifier ve worker seçim kapsamı **30**, gerçek SCM paket/HTTPS/upgrade/rollback **53** kontrolü geçti. Kalıcı düşük yetkili test worker'ı eksik aday için authenticated **content_rejected** sonucunu gerçek kanaldan döndürdü; olumlu gerçek non-admin aday verifier testi ayrıca geçti. Bu, müşteri DC01'de olumlu tam worker roundtrip kabulü değildir. Gerçek RADIUS protokolü, enrollment, Linux source ve bounded retry workflow'ları da başarılı.

**Canlı Linux hâlâ dev.38; kurulum yapılmadı.** Yalnız home altında 179 dosyalı stage ve hash-sabitli updater hazırlandı. Uzak salt okunur source guard ve teslimat byte doğrulaması geçti. Updater **/home/segmentiq/authwire-candidate-jobs-20261027.py**, SHA256 **9ce550af4267e27f3d29d776b2a5590afc376a7b08a3bb2607834858afdb9f1d**; manifest **9045a1b093fa28b00869c5a5ecfe1d831daac9c6682cad668f0f884a5a004d0b**. Yalnız panel restart planlanıyor; tam veri yedeği/restore, RADIUS veya broker restart yok. Son okunan RADIUS **1243360**, broker **1069437** active. Yedi uygulama/versiyon dosyası değişebilir; auth, RADIUS, policy, client, sertifika ve iş verisi koruma kontrolleri sürer. Günlük backup timer korunacak.

**Sırada operatör Linux sudo komutu var.** Ardından mevcut hesap/eşleme/kanal anahtarı korunarak Windows Connector'ın staged güncelleme teslimatı hazırlanıp gerçek panel görevi kabul edilecek. Windows yeni worker bu adımda müşteriye teslim edilmedi/yükseltilmedi; henüz aday görevi oluşturulmadı. AD/GPO/endpoint, signer key/marker/ACL veya logo değiştirilmedi. Eski başarılı manuel probe tekrar edilmedi; tarihsel wrapper başarısızlığı geriye dönük kabul edilmedi. Canlı AD/GPO kapsamı, SYSVOL staging ve endpoint kabulü hâlâ bekliyor. **54/94 (~%57),40 açık** değişmedi; kılavuz kapanış koşulu oluşmadı.

## 🔴✓ DC01 kalıcı imza anahtarı native olarak doğrulandı; metadata incelemesi tamamlandı — 27 Ekim 2026

Operatör **WINDOWS_SIGNER_PERSISTED_METADATA_READONLY / Version=2** sonucunu paylaştı. **NamedKeyOpened=true, OpenError=null, NativeKeyNameMatchesBinding=true, PublicKeyMatchesCertificate=true**. Sertifika **FFC134BC305757457163F99C7479B4168E397129**, named container ve native unique keyfile eşleşiyor. **Microsoft Software Key Storage Provider / RSA3072 / machine KeyType32 / ExportPolicy0 / KeyUsage2** doğrulandı. Unique dosya **6d83645dd6648563b32f0fdecaf3d56e_1fed02ca-1f1d-4faf-839e-e8eb2f0eff4a** ve tam SDDL **25 Ekim'de kabul edilen kayıtla aynı**: SYSTEM ve Administrators full control; aw-deploy$ SID **…1648** Read; korumalı DACL. Bu operatör çıktısı kabulüdür, bağımsız asistan DC01 sorgusu değildir.

**CLR marker 01 olarak önce/sonra aynı kaldı.** Native named-key/public-key/file kanıtı bu işaretin anahtarın kaybolduğu veya yalnız bellekte bulunduğu şeklinde yorumlanamayacağını gösteriyor. Önceki wrapper bu managed işareti kalıcılık şartı saydığı için kontrolü geçemedi. İşareti hangi işlem veya bileşenin yazdığı ve sonraki GetRSAPrivateKey acquisition hatasının tüm mekanizması kanıtlanmış değil. Marker, association, anahtar, ACL ve servis değiştirilmedi; yeni sertifika, imza veya private export yapılmadı.

**Metadata tanısı kapatıldı; ilave tekrar probe gerekmiyor.** Daha önce gerçek aw-deploy$ runtime'ında başarılı aday doğrulaması ve cleanup kabulü korunuyor. Buna karşılık orijinal outer wrapper **preservation_after başarısızlığı geriye dönük başarılı sayılmaz**: kaydedilmemiş original before snapshot mevcut değil; bütün dosya/ACL/PID'nin o işlem boyunca aynı kaldığı iddia edilmez. Bu son okuma mevcut signer kimliği/policy/ACL ve tarihsel kayıt eşleşmesini doğrular; yeni signing veya zincir/iptal denemesi değildir.

Gelecek teslimat guard'ı yalnız IsEphemeral şartını silerek gevşetilmeyecek: reviewed native kalıcı ad/sertifika public eşleşmesi, machine provider, unique dosya/ACL ve RSA/boyut/export/usage şartlarıyla değiştirilecek. **Bu guard düzeltmesi henüz uygulanmadı.** Tarihsel teslimat dosyası/hash'i değiştirilmedi ve RunProbe yeniden çalıştırılmayacak. Sıradaki geliştirme **mevcut Connector üzerinden sınırlı typed aday doğrulama görevi ve authenticated sonuç dönüşü**; güncel plan/profile/dizin ve owned GPO kapsamı kontrolleri ayrıca kalır.

Panel **dev.38**, kayıt hâlâ **Connector doğrulaması bekleniyor**; attestation elle ilerletilmedi, GPO apply kapalı. Linux/panel, kalıcı Windows Connector, AD/GPO veya endpoint ayarı değiştirilmedi. İşlevsel durum **54/94 (~%57),40 açık** değişmedi. Ayrıntılı operatör çıktısı ve kabul sınırları **docs/checkpoints/2026-10-27-signer-native-metadata-accepted.json** içinde.

## Signer named-key açılışı ile CLR ephemeral bayrağı çelişiyor; native r2 tanısı hazır — 27 Ekim 2026

Operatör v1 salt okunur tanı sonucunda **NamedKeyOpened=true / Microsoft Software Key Storage Provider / IsMachineKey=true / export=0 / usage=2** paylaştı. Kayıtlı container **tq-AuthWireConnectorCodeSigning-4c23eebe-15cb8856-8d31-4e48-8c7b-ebe0c842cb2f**; provider flags **32**, type **0**, key spec **0**. Buna karşılık managed **IsEphemeral=true**, KeyName/UniqueName null ve tanı **NAMED_MACHINE_RSA_KEY_REQUIRED** ile public-key/file kontrollerinden önce durdu. Bu çıktı anahtarın kaybolduğunu veya doğru persisted key/file bağının doğrulandığını tek başına kanıtlamaz; bayrağın müşteri ortamındaki kök nedeni hâlâ bilinmiyor.

**PR98**, son test edilen head **db983de090cc1296ddc12f34f7b1411d54be8241**, merge **5cee48148883991fb17de87ba456880dba27df53**. V2 tanısı **NCryptOpenKey/GetProperty** üzerinden native Name/Unique Name/Key Type/Length/Export Policy/Key Usage ve ayrı CLR marker değerini okur; yalnız sabit **RSAPUBLICBLOB** ile sertifikanın public RSA DER değerini karşılaştırır, mevcut key ACL'yi okur. CLR marker değiştirilmez; key/association/ACL yazımı, private export, signing, yeni key veya guard gevşetme yok.

🔴✓ **4 workflow /16 native kontrol** geçti. Fixture kendine ait named key üzerinde CLR marker 1 durumunu oluşturup **managed IsEphemeral=true ve null isimleri** tekrarladı; native isim/public eşleşmesi, aynı unique keyfile, değişmeyen marker ve export/usage/boyut/ACL ayrı doğrulandı. Bu müşteri anahtarının native sonucunun kabulü değildir. Gerçek gMSA aday doğrulaması ve temizlik önceki summary ile zaten kabul edildi; RunProbe tekrar edilmeyecek. Orijinal outer wrapper preservation guard henüz kabul edilmedi veya değiştirilmedi.

Linux home **/home/segmentiq/authwire-signer-native-metadata-r2-20261027.ps1**, **12426 byte**, SHA256 **2332082ac59f9adec7ac47d2bd9e80e3ca6733f34ba75e256ac1abb33769d908** uzak okumayla doğrulandı; yeni müşteri çıktısı bekleniyor. Sırada yalnız bu native metadata/public-key/file ACL çıktısının incelenmesi var. Linux/panel **dev.38** ve kalıcı Connector değişmedi; panel attestation/GPO apply açılmadı. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ Gerçek aw-deploy$ aday doğrulaması ve temizlik kabul edildi; signer postcheck ayrı bekliyor — 27 Ekim 2026

Operatör kaydedilmiş **C:\ProgramData\AuthWire-CandidateProbe-33776769e3a64abbafcbe3cf926be79f\summary.json** içeriğini paylaştı. **ProbeVerified=true, CandidateVerified=true, ServiceLogonVerified=true, RuntimeSid=…1648**; doğru Connector/plan/GPO, approval ve manifest **4f7a463d…ba9a6d** eşleşiyor. **SignatureVerified=true, NetworkContentVerified=true**. Geçici servis **AuthWireLogonProbe-6c9b71e462be4906b23b364c25246ee7**, PID **8536**; servis/exe/verifier/output kaldırılmış ve cleanupErrors boş. Bu operatör çıktısıdır; bağımsız asistan DC01 sorgusu değildir.

🔴✓ Gerçek müşteri **VIZYONVERI\aw-deploy$** hesabıyla salt okunur aday doğrulaması tamamlandı. Kalıcı Connector listelemede **Running / aw-deploy$ / PID6444**. Verifier özel anahtar açmadı, adayı çalıştırmadı. Bu native fixture'dan ayrı gerçek gMSA kabulüdür. Önceki “runtime/cleanup sonucu bilinmiyor” notları bu summary kabulünden önceki durumdur.

**Tam wrapper koruma kontrolü hâlâ kabul edilmedi.** Doğrudan **GetRSAPrivateKey** tanısı CNG ephemeral-handle seçenek hatasıyla döndü; bu hata tek başına diskteki anahtarın ephemeral olduğunu, silindiğini veya değiştiğini kanıtlamaz. Yeni PowerShell sürecinin kullanıldığı ayrıca doğrulanmış değil. Anahtar, ACL, association veya servis değiştirilmeyecek; RunProbe tekrarına gerek yok. **GPO/dizin güncelliği, authenticated typed job ve panel attestation hâlâ bekliyor.**

**PR97** salt okunur named-key metadata tanısı ekledi; son kaynak **36896f7d3aa135c453745c062f82a6699cf690c0**, merge **4d86aa70735f365b7c295d6176414bc0e6c48c74**. Sertifikanın **CERT_KEY_PROV_INFO** kaydını okuyup mevcut named machine KSP anahtarını açar; public RSA eşleşmesini, machine/ephemeral/boyut/export/usage ve mevcut ACL'yi raporlar. Oluşturma, imzalama, private export veya özellik/association/ACL yazımı yok; ephemeral flag'i zorlayan fallback yok. **4 workflow /12 native kontrol** geçti. Cached-handle fixture farklı invalid-handle hatası üretti; müşteri hatasının birebir tekrarlandığı iddia edilmez. Named-key yöntemi bağımsızlık/yanlış-key/no-binding/ACL kontrollerinden geçti.

DC01 tanı dosyası Linux home **/home/segmentiq/authwire-signer-persisted-metadata-20261027.ps1**, **6779 byte /SHA256 a337c3e2cd0db356c30995527992a99288ff92e11069d45329c3a57dad6c4c2d** olarak uzak okumayla doğrulandı. Henüz müşteri tarafından çalıştırılmadı. Linux/panel **dev.38**, mevcut Windows Connector korunuyor; panel **Connector doğrulaması bekleniyor** durumunda kalır. **54/94 (~%57),40 açık** değişmedi.

## DC01 salt okunur aday probe sonrası koruma kontrolünde durdu — 27 Ekim 2026

Operatör **WINDOWS_CANDIDATE_READONLY_SERVICE_DELIVERY_FAILED / Mode=RunProbe / Stage=preservation_after / EXISTING_NONEXPORTABLE_SIGNER_REQUIRED** çıktısını paylaştı. **SourcesPreparedNow=true, ProbeStarted=true**; kaynaklar **C:\ProgramData\AuthWire-CandidateVerifySources-048dce54c72d0984** altında. Son snapshot anahtar türü/machine/ephemeral/boyut/export/usage koşullarından birini sağlayamadı; tek hata kodu hangi özelliğin uyuşmadığını göstermiyor.

**Müşteri probe başarı/temizlik/koruma kabulü yapılmadı.** İç probe sonucu dış hata çıktısında görünmüyor; kaydedilmiş owned-probe summary salt okunur alınacak. Önce/sonra tüm kapsamın korunduğu veya anahtarın değiştiği iddia edilmez; kök neden henüz bilinmiyor. İnceleme sırasında RunProbe yeniden çalıştırılmayacak, anahtar/ACL/trust/hesap/servis ayarları değiştirilmeyecek. Yeni Windows PowerShell sürecinden persisted signer metadata, mevcut Connector ve ilgili summary okunacak. **PanelAttestationUpdated=false, GpoApplyEnabled=false**; ana durum **54/94 (~%57),40 açık** korunur.

## 🔴✓ Servis hesabı için salt okunur imzalı aday doğrulayıcısı hazır — 27 Ekim 2026

**PR96**, son test edilen kaynak **de5d9ad859f7a0be40f7a87d9304e07f76fb801e**, merge **c1035780711b2b640b56fca0bd5963e54702dc45**. Mevcut aday Prepare/Verify aracı yönetici gerektirdiğinden, kalıcı non-admin worker'a doğrudan bağlanamaz. Ayrı **Test-AuthWireDeploymentCandidate.ps1**, exact non-admin runtime SID ve on sabit kapsam/hash piniyle aday yolunu türetir; korumalı ACL, original approval, sınırlı ZIP/JSON/XML, açık CA verisi, public TrustedPublisher zinciri, native Authenticode ve yalnız yorum içeren manifesti doğrular. Verifier özel anahtar açmaz, imzalamaz, adayı çalıştırmaz veya AD/GPO/endpoint değiştirmez.

🔴✓ Son kaynakta **4 workflow başarılı**. Gerçek non-admin virtual SCM hesabı, Windows PowerShell 5.1, AllSigned, machine CNG/Authenticode ve NTFS fixture **24 yeni kontrol**, mevcut native aday fixture **55 kontrol** geçti. Yanlış manifest hash'i, bozuk ZIP, ek dosya, farklı hesap ve komut alanı reddedildi; geçici servis/exe/verifier/output temizlendi. Exact DC01 wrapper parse/embedded ZIP/body pin/imza/ACL/erken host reddi kontrolünden geçti. Foundation **839 test /28 skip**; mevcut Windows bootstrap/service/channel ve bounded retry kontrolleri başarılı. Bunlar müşteri gMSA/AD kabulü değildir.

**DC01 teslimatı hazır, henüz çalıştırılmadı.** Linux home **/home/segmentiq/authwire-dc01-candidate-readonly-service-20261027.ps1**, **35628 byte**, SHA256 **63e647f0ef017709fe59c3f330f4ce9b0cd431e3dab14699d033463bd0c56518** uzak okumayla doğrulandı. Onaylanmış kaynak component **be785a13350ffc916a02b4e509953a8c1635433b**. Wrapper yalnız mevcut DC01/aw-deploy$/Connector release **970d7039…**/FFC134… signer ve kabul edilmiş aday bağlamını kullanır. İki reviewed helper için ayrı imzalı kaynak klasörü hazırlar; exact scope'a bağlı geçici signed SCM probe çalıştırır, kalıcı Connector PID/config/package/exe, aday byte/ACL ve signer key ACL'sini önce/sonra karşılaştırır. Mevcut hesabı, servisi, eşlemeyi veya adayı sıfırlamaz; aday yeniden üretilmez. Operatör adımı **2026-10-27-dc01-candidate-readonly-run.ps1** içinde hash sabitlidir.

**Canlı Linux/panel dev.38 olarak korunuyor; kalıcı Windows Connector yükseltilmedi.** Asistan yalnız Linux home'a teslimat dosyası yazdı; DC01 probe henüz çalıştırılmadı. **TypedWorkerJobDeliveryPending=true, PanelAttestationUpdated=false, CanApplyGpo=false**. Bu salt okunur runtime önkoşuludur; paneldeki “Connector doğrulaması bekleniyor” durumu elle değiştirilmez. Sonraki gerçek gMSA kabulünden sonra typed worker job/authenticated result roundtrip ve fresh owned GPO/plan kontrolü eklenecek. GPO/dizin güncelliği, linksiz staging, GPO uygulama ve endpoint kabulü hâlâ ayrı bekliyor. Nihai ürün için kalıcı manuel probe akışı hedeflenmiyor. Tam veri yedeği alınmadı; **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ İmzalı aday kaydı panelde kabul edildi — 27 Ekim 2026

Operatörün **image(20261027-084309).png** görüntüsü doğrudan incelendi. **İmzalı dağıtım adayları** altında **AuthWire Pilot - Merkezi Windows · v1**, manifest SHA256 **4f7a463d3404428703bb95424d8c8a7f275e85f6a3a42d7a270f6eaae5ba9a6d** ve **Operatör sonucu kaydedildi. Connector doğrulaması bekleniyor.** görünür. Bildirim de hazırlık sonucunun kaydedildiğini doğruluyor. Manifest, daha önce kabul edilen DC01 Prepare çıktısıyla eşleşiyor. Görsel SHA256 **c8b425e2488248d4dfba4c9b0cfc1a1f4768c344dcdf222c304f14afceba59ad**.

🔴✓ Dev.38'in ilk gerçek müşteri tarayıcı kayıt akışı operatör ekran kanıtıyla kabul edildi. Bu ayrı asistan backend GET/SQL kontrolü değildir; kayıt UUID'si görüntüde yoktur ve varsayılmaz. Önceki “gerçek aday kaydı/tarayıcı kabulü bekleniyor” kayıtları bu kabulden önceki durumdur.

**Connector doğrulaması, typed worker teslimatı ve GPO dağıtımı henüz tamamlanmadı.** Sıradaki geliştirme mevcut kayıt üzerinden sınırlı typed Connector doğrulama/hazırlama görevidir: işlem anında güncel plan/profile/AD hedefleri, native imza/içerik ve exact owned GPO marker/izin/link kapsamı doğrulanacak; linksiz staging ve GPO uygulama kapıları ayrı kalacak. Operatör aynı sonucu yeniden kaydetmeyecek; mevcut servis/eşleme/anahtar/imzalı aday sıfırlanmayacak. İşlevsel durum **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ Dev.38 Linux kurulumu operatör çıktısıyla kabul edildi — 27 Ekim 2026

Operatör **CANDIDATE_REGISTRY_FINISHED / verified=true / changed=true / 0.14.0-dev.38** çıktısını paylaştı. Release **957e590d879b65579e650519c65afed9571847d2** beklenen kaynakla eşleşiyor. Evidence **/var/lib/authwire-updates/candidate-registry-dev38-20261027T083529Z-ed24d2d0**. Bu kabul operatörün updater çıktısına dayanır; bağımsız canlı asistan sorgusu değildir.

🔴✓ Korumalı dosyalar, broker/RADIUS süreçleri, timer'lar ve iş verisi kontrolleri başarılı. RADIUS **1243360** ve broker **1069437** korunmuş; RADIUS yeniden başlatılmamış. Önce/sonra panel okuma kontrolleri **200**, yeni **/api/deployment/candidates** dahil. Policy, plan, AD/GPO, sertifika, Windows paket/endpoint, pairing ve backup worker değişikliği yok. Tam veri yedeği alınmadı; günlük backup timer korunmuş.

**candidate_records_created=false, gpo_apply_enabled=false, windows_candidate_worker_delivery_pending=true** beklenen kapsam. Sıradaki operatör adımı paneli yenileyerek **Sertifikalar → Merkezi dağıtım → Hazırlık sonucunu kaydet** altında daha önce kabul edilen DC01 **WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY / Prepare** JSON'unun tamamını önizleyip kaydetmektir. Beklenen durum **Connector doğrulaması bekleniyor**; bu kayıt gerçek worker doğrulaması veya dağıtım kabulü sayılmaz. DC01 Prepare yeniden çalıştırılmayacak; mevcut servis/eşleme/aday korunacak. Müşteri tarayıcı kabulü ve gerçek aday kaydı henüz bekliyor. **54/94 (~%57),40 açık** değişmedi.

## İmzalı aday sonucunun panelde kaydı hazır — 27 Ekim 2026

**PR95**, merge **65782a6e9367da671caed15833f46385a7d77378**, test edilen kaynak **957e590d879b65579e650519c65afed9571847d2**, sürüm **0.14.0-dev.38**. Sertifikalar → Merkezi dağıtım altında **İmzalı dağıtım adayları / Hazırlık sonucunu kaydet** eklendi. İlk DC01 Prepare JSON çıktısı önizlenip kaydedilebilir. Kaydın açık durumu **operator_reported / Connector doğrulaması bekleniyor**; **connector_verified=false, can_apply=false**. Bu, geçici bootstrap kayıt köprüsüdür; nihai otomatik dağıtımda rutin çıktı yapıştırma hedeflenmiyor.

Kayıt güncel plan, profil, gerçek dizin içeriği, trust ve Connector binding kapsamına bağlanır; değişiklikte **outdated** olur. Salt timestamp yenilenmesi tek başına eskime sayılmaz. HTTPS, interaktif oturum, CSRF ve iki güncel yönetici yetkisi gerekir. Duplicate/bozuk JSON, çakışan kayıt, eski önizleme ve cevap kaybında tekrar yazmama kontrolleri vardır. Receipt içindeki yollar kullanılmaz; dosya açılmaz/çalıştırılmaz. GPO uygulama veya genel komut endpoint'i eklenmedi.

**Linux canlı sürüm hâlâ dev.37; dev.38 kurulumu operatör sudo komutu bekliyor.** Sunucuda yalnız home altında stage ve hash-sabitli updater hazırlandı. Updater **/home/segmentiq/authwire-candidate-registry-20261027.py**, SHA256 **20216103bd6ba7f5f4c057716ff65212a7a1a11895cb0a62587c6eb6d8d3ca29**; stage manifest **480dc0621d1da1933535ecd9ffe908618d9a7d4bb2ba8f43e3c9f6edba78886f**, **178 dosya** yalnız okuma source guard kontrolünden geçti. Kaynak swap/rollback/backup-idle işlevleri önceki incelenmiş updater ile aynı; projection fixture olağan poll heartbeat/cache hariç tüm görev/lease/sonuçların korunduğunu doğruladı. Tam veri yedeği alınmadı; günlük timer korunacak. RADIUS/broker yeniden başlatma, Windows/AD/GPO/sertifika/trust/hesap değişikliği planlanmıyor.

🔴✓ Son kaynakta **7 workflow başarılı**: genel testler **839 test /28 skip**, tarayıcı kayıt/cevap-kaybı akışı, Windows bootstrap/servis, gerçek RADIUS, bounded retry, Linux source ve enrollment kontrolleri. Yerel 42 aday/HTTPS/mevcut iş testi ve 8 tarihsel delivery testi geçti. Bu fixture/CI kabulüdür; müşteri endpoint kabulü değildir.

Henüz gerçek aday kaydı yapılmadı ve müşteri tarayıcı kabulü yok. **Panelden typed worker aday doğrulama/hazırlama, tam istemci installer paketi, SYSVOL staging, GPO link/uygulama ve endpoint kabulü bekliyor.** Önce Linux güncellemesi ve mevcut DC01 Prepare sonucunun panel kaydı kabul edilecek. Mevcut servis/aday/eşleme sıfırlanmayacak. İşlevsel durum **54/94 (~%57),40 açık** değişmedi; ürün tamamlandı veya kılavuz hazır sayılmaz.

## 🔴✓ DC01 ilk gerçek imzalı ağ profili adayı oluşturuldu — 26 Ekim 2026

Operatör **WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY / Mode=Prepare / Stage=prepared** çıktısını paylaştı. **SourcesPreparedNow=true, SourceSignaturesValid=true**. Approval SHA256 **3b5587d5e6fcdc3cbdb753e097fe36d377e27e9e6bc549c289383baa345577ad**, kabul edilen pilot ZIP ve exact kaynak teslimatıyla eşleşiyor. Plan **524653f5-1359-46f5-84a5-46355bb82aff /v1**, owned deployment GPO **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** doğru. Aday **C:\ProgramData\AuthWire-DeploymentCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5135946f584a546355bb82aff-v1-ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7** altında; manifest SHA256 **4f7a463d3404428703bb95424d8c8a7f275e85f6a3a42d7a270f6eaae5ba9a6d**.

🔴✓ **PreparedNow=true, SignatureVerified=true**: gerçek müşteri DC01'de mevcut machine signer ile lokal aday oluşturma ve son imza/hash/ACL guard'ları geçti. Bu operatör çıktısı kabulüdür; bağımsız asistan DC01 sorgusu değildir. Prepare zaten yayımlanan adayı tekrar doğrulayarak döner; yalnız bu kabul için aynı testi yeniden çalıştırma gerekmiyor. Kaynaklar **C:\ProgramData\AuthWire-DeploymentCandidateSources-3b5587d5e6fcdc3c** altında imzalı olarak hazırlanmış.

**ArtifactExecuted=false, CanApplyGpo=false** beklenen kapsam. Operatör çıktısında **AD/GPO/endpoint/services/trust/key ACL değişikliği yok**, secret export yok; mevcut Connector değiştirilmedi. Bu yeni helper'ın installed gMSA worker üzerinden çalıştığı, tam istemci installer paketi bulunduğu, SYSVOL/GPO staging/link yapıldığı veya endpoint kabulü tamamlandığı iddia edilmez.

Sıradaki geliştirme **panel → sınırlı typed dağıtım hazırlama görevi → Connector** akışıdır. Mevcut account/binding/key korunacak; güncel plan/profile/AD hedefi ve exact owned GPO marker/link/izinleri işlem anında kontrol edilecek. Önce linksiz hazırlama, ardından ayrı scoped uygulama kapısı gelecek. Mevcut imzalı adayı silmek veya tekrar kurulum yapmak gerekmiyor. **54/94 (~%57),40 açık** değişmedi; bu kabul merkezi otomasyonun bir alt adımıdır.


## 🔴✓ İmzalı ağ profili aday hazırlığı geliştirildi ve test edildi — 26 Ekim 2026

**PR94**, final tested head **c41e853719f81cd32055f8dd0806b1c3c769225f**, merge **a097420d777c2c6d50bbfe78ffb7ffb55f6a0b68**. Yeni **New-AuthWireDeploymentCandidate.ps1** mevcut machine+Ethernet+Wi-Fi pilot ZIP'ini dışarıdan sabitlenen approval SHA256 ve ZIP özetiyle kontrol eder; exact plan/profile/grup/GPO/Connector kimliklerini comment-only, çalıştırılmayan bir manifestte Authenticode imzasıyla bağlar. Duplicate JSON/ZIP, fazla veya büyük dosya, farklı XML yapısı, kapalı sunucu doğrulama, yanlış ad/kök, farklı sürüm/kapsam, reparse point veya genişletilmiş ACL reddedilir. Aday yalnız original ZIP + approval.json + imzalı manifest içerir. Prepare atomik yayımlar; tekrar Prepare/Verify mevcut imzalı byte'ları korur, bozuk adayın üzerine yazmaz.

🔴✓ Final head'de **dört workflow başarılı**. Gerçek Windows PowerShell 5.1 / machine non-exportable CNG / Authenticode / fresh AllSigned / NTFS sınırları ve exact DC01 wrapper/source/approval kontrolü **55 test** (run40395613878). Foundation **828 test /28 skip** (run40395613883/job121827710289); mevcut service SCM/HTTPS/upgrade fixture **53 kontrol**, dört bootstrap job başarılı (run40395613885). Kaynak compiler/modül bağımlılığı temiz native PowerShell oturumunda doğrulandı; hosted pwsh ebeveyninin PSModulePath sızıntısı fixture'da ayrıldı. Müşteri AD/gMSA çalıştırması veya endpoint kabulü test edilmiş sayılmaz.

**DC01 teslimatı hazır, henüz çalıştırılmadı.** Linux **/home/segmentiq/authwire-dc01-deployment-candidate-20261026.ps1**, **24062 byte**, SHA256 **9a6fd20aa72fb5a157d17344f6c531dfef608b17399f540e9708412e26745264**; kabul edilen original ZIP de **/home/segmentiq/authwire-pilot-network-profiles-20261026.zip** altında **6110 byte /528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38** olarak hazır; iki dosyanın uzak özeti doğrulandı. Wrapper yalnız DC01, mevcut healthy release **970d7039…**, aynı servis hesabı/Connector/appliance ve mevcut **FFC134…** signer/trust bağlamını kabul eder. Değişmeyen tek reviewed helper'ı özel yeni kaynak klasörüne imzalar; approval'ı sabitler ve helper **Prepare** çalıştırır. İndirme/çalıştırma komutu **2026-10-26-dc01-deployment-candidate-run.ps1** dosyasında. Bu yerel hazırlık kullanıcı tarafından zaten yetkilendirilmiş kapsamdır; ayrı canlı GPO link/uygulama kapısı açılmaz.

**Canlı Linux uygulaması hâlâ dev.37; servis yükseltmesi yapılmadı.** Panelden typed deployment job, istemci installer paketi, SYSVOL kopyası, GPO ayar yazımı/link/uygulama ve endpoint kabulü henüz eklenmedi. Mevcut servis, pairing, hesap, key ACL, trust, Windows endpoint ve GPO değiştirilmedi; yalnız Linux home'a teslimat dosyaları yazıldı. Helper Inspect aday oluşturmaz/private key açmaz; wrapper ilk kaynak hazırlığında dosya yazıp mevcut anahtarla reviewed helper'ı imzalayabilir. CA path kontrolü offline'dır, CRL/RADIUS leaf kabulü değildir. Kaynak UI placeholder'ı bu adımda değiştirilmedi. **CanApplyGpo=false** ve **54/94 (~%57),40 açık** korunur. Sırada DC01 **Prepare** sonucu ile ilk gerçek local signed candidate kabulü var.


## 🔴✓ Merkezi dağıtım GPO'su güncel yalnız okuma ile doğrulandı — 26 Ekim 2026

Operatörün **Yapıştırılan metin(6).txt** çıktısı JSON ve içindeki GPMC XML olarak incelendi. SHA256 **12be6e876a52d18d7e6d271e6e833a0b025fc2cae031b5d781f35b52f580f0c7**; rapor okuma zamanı **2026-10-26T20:00:13.2678615Z**. Owned deployment **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3 / AuthWire-Managed-Deployment-4c23eebe** mevcut; description ownership marker'ı connector **4c23eebe…**, host **0fa4143f…**, service SID **…1648** ve scope SID **…1647** ile tam eşleşiyor. Owner **Domain Admins / …512**. Pilot grubunda **GpoApply**, aw-deploy$ hesabında **GpoEdit**, Authenticated Users'da **GpoRead** var; rapor SID eşleşmeleri doğrulandı.

**0 link, 0 ExtensionData**, Computer/User Directory ve SYSVOL sürümleri **0/0**. Böylece rapor bazında GPO hâlâ boş ve bağlı değil. Bu operatörün DC01 çıktısıdır; asistan canlı AD veya SYSVOL ACL incelemesi yapmış sayılmaz. Korumalı trust GPO bu komutta okunmadı/değiştirilmedi. Bu snapshot gelecekteki yazım sırasında yeniden kontrol edilmelidir.

İlk plan ve XML paketi kabulünden sonra hazırlık kontrolü tamamlandı. **GPO dağıtımı henüz uygulanmadı; CanApplyGpo=false.** Sonraki geliştirme, kaydedilmiş planı exact owned GPO'ya bağlayan sınırlı typed dağıtım hazırlama/uygulama akışı; doğrulanmış istemci/ağ asset imzaları, eski snapshot reddi, linksiz staging, endpoint publisher güveni ve sınırlı rollback kontrolleridir. Yeni GPO/hesap oluşturmak veya mevcut Connector'ı sıfırlamak gerekmiyor. **54/94 (~%57),40 açık** değişmedi.


## 🔴✓ İlk merkezi Windows ağ profili ZIP paketi doğrulandı — 26 Ekim 2026

Operatörün yüklediği **AuthWire-Network-Profiles.zip** bağımsız yerel incelemeden geçti. ZIP SHA256 **528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38**; tam **7 benzersiz dosya**, CRC doğru, manifestteki **6/6 SHA256** eşleşiyor. Plan **524653f5-1359-46f5-84a5-46355bb82aff /v1**, sertifika profili **e3597842-3499-4ace-aaf3-29890eabd908 /v3**, snapshot revision **84**, preview hash **ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7**. Cached AD üyeliğinde **2 etkin /2 toplam**, **0 unresolved**; örnekler **2GL13ZU$** ve **VV06**. Snapshot zamanı **2026-10-26T19:54:34.314927+00:00**.

Her iki XML'de **machine / EAP-TLS (13)**, sunucu **kaname.vizyonveri.local**, kök **C789A0595ADB95A6BE4534D01B1D205F6C37DE18**, server/name validation açık ve kullanıcıdan sunucu kabulü isteme kapalı. Wi-Fi **VV_802.1X / WPA2-AES**. Açık kökün kendi imzası, issuer'ın kök imzası, iki CA'nın güncelliği ve root SHA1/SHA256 eşleşmesi doğrulandı. Özel anahtar/çalıştırılabilir içerik yok. Manifest eşleşmesi iç bütünlüktür; paket Authenticode imzalı dağıtım sayılmaz. RADIUS leaf pakette yoktur, planın trust.ready/leaf SHA256 değeri ZIP'ten bağımsız leaf zincir kabulü sayılmaz. Windows native import, GPO uygulaması ve endpoint kabulü bu paketle henüz yapılmadı.

İndirme bu denemede başarılı; önceki donmanın kök nedeni belirlenmedi. İkinci operatör görüntüsündeki ek bağlantı testi **f4857612-8413-41c0-9ba2-4276ff6cd9e1** de Tamamlandı; yeni dağıtım planı/GPO uygulaması olarak yorumlanmaz. GPO/AD/endpoint değişmedi. Sonraki adım owned deployment GPO **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** üzerinde güncel yalnız okuma ile marker/izin/link/ayar durumunu yeniden toplamak; korumalı trust GPO'ya dokunulmayacak. **54/94 (~%57),40 açık** değişmedi.


## 🔴✓ İlk merkezi Windows pilot planı önizlendi — 26 Ekim 2026

Operatörün **image(20261026-193519).png** görüntüsü doğrudan incelendi: **AuthWire Pilot - Merkezi Windows · v1**, **2 etkin /2 toplam bilgisayar**, bilgisayar kimliği, **Ethernet + Wi-Fi / VV_802.1X**, **kaname.vizyonveri.local**, bilgisayar sertifika profili **AuthWire-Pilot-Computers · v3** ve kök **C789A0595ADB95A6BE4534D01B1D205F6C37DE18** görünüyor. AD okuma zamanı **2026-10-26T19:24:32.826510+00:00**. Görsel SHA256 **b718b9660e8738254dd87c1519bcbda4fe2bd1dd3980905bf89e6b8fa564faba**. Artifact blocker görünmüyor ve **Profil XML paketini indir** düğmesi kullanılabilir. Bu operatör önizleme kanıtıdır; bağımsız canlı API/SQL incelemesi değildir.

Planın görünen ayarları kabul edildi. Görüntü plan/profile UUID'lerini, preview hash'ini veya hedef bilgisayar adlarını göstermiyor; bunlar varsayılmayacak. Sonraki somut adım bu ekrandan XML ZIP paketini indirip inceleme için paylaşmak: manifest/plan kimlikleri, dosya özetleri ve Ethernet/Wi-Fi EAP-TLS sunucu adı/kök doğrulaması kontrol edilecek. Paket yalnız açık sertifikalar ve ağ profilleri içerir; özel anahtar veya çalıştırılabilir dağıtım değildir. İndirme/inceleme henüz yapılmadı.

Ekrandaki Windows bağlantısı bekleniyor metni önceki kaynak incelemesinde doğrulanan sabit placeholder'dır. Kabul edilen sağlıklı Connector/probe kanalı korunur; yeniden eşleme yapılmayacak. **GPO apply henüz uygulanmadı**, owned deployment GPO'nun fresh ownership/scope incelemesi ve imzalı dağıtım/publisher güveni sonraki ayrı kapıdır. Bu adımda asistan GPO/AD/endpoint değişikliği veya yeni Connector işi yapmadı. **54/94 (~%57),40 açık** değişmedi.


## Merkezi Windows dağıtımı: mevcut plan ekranıyla ilk pilot önizlemesi — 26 Ekim 2026

Kaynak incelemesi **Deployment.save/preview/package** ve sürümlü plan editörünün zaten var olduğunu doğruladı. Yeni/ikinci plan altyapısı yazılmayacak. İlk operatör adımı **Sertifikalar → Merkezi dağıtım → Yeni dağıtım** üzerinden **AuthWire Pilot - Merkezi Windows** planını hazırlamak: bilgisayar kimliği; **AuthWire-Pilot-Computers / …1647**; aynı gruba bağlı mevcut bilgisayar sertifika profili; Ethernet+Wi-Fi; **VV_802.1X**; RADIUS adı **kaname.vizyonveri.local**. Kullanıcı sertifika profili bu ilk machine planında kullanılmaz. Plan kaydetmek ve önizlemek AD/GPO/endpoint değiştirmez; kaynak tarafından desteklenen, ayrı bilgisayar/kullanıcı cached üyelik sayımı ve trust/profile blocker'ları doğrulanacak.

**Henüz plan oluşturulmadı; operatör önizleme sonucu bekleniyor.** Asistan canlı API/SQL kaydı, yeni iş veya GPO değişikliği yapmadı. Plan/profile kimlik ve sürümleri, enabled bilgisayar hedefi, unresolved üyeler, trust hazır durumu ve blocker'lar çıktıyla kaydedilecek. Gerçek hedef sayısı varsayılmayacak.

Önemli kaynak bulgusu: hazırlık ekranındaki **Windows yönetim bağlantısı henüz kurulmadı / kurulması bekleniyor** metinleri ve **WINDOWS_CONNECTOR_NOT_CONFIGURED** apply blocker'ı hâlâ eski sabit placeholder'dır. Kabul edilen dev.37 + DC01 probe roundtrip'ın başarısız olduğu anlamına gelmez; yalnız bu eski metne bakarak key/pairing/service sıfırlanmayacak. GPO apply endpoint gerçekten yoktur. Sonraki entegrasyonda bu durumlar gerçek Connector kapsamı ve kontrollü GPO executor hazırlığıyla doğru bağlanacak.

GPO yazımından önce owned deployment **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** için fresh ownership/scope/unlinked incelemesi ve imzalı paket/publisher güven zinciri gerekli. Korumalı trust GPO **e5a9ab39-3709-49cb-837a-0208d2eb3b12** korunacak. Şu aşamada kullanıcı/AD grubu/sertifika/network policy/VLAN/Windows task değiştirilmedi. **54/94 (~%57),40 açık** değişmedi.


## Son teslimata eklendi: tüm panelin ayrıntılı kullanım kılavuzu — 26 Ekim 2026

Operatör, çalışma tamamlanınca **paneldeki bütün sayfaların ve başlıkların nasıl çalıştığını, neyin nasıl yapılacağını anlatan detaylı kılavuz** istedi. Zorunlu kapanış teslimatı olarak **docs/USER_GUIDE_PLAN.md** kaydedildi. Kılavuz son kabul edilmiş panel sürümünün tüm menü, sekme, alan, buton ve durumlarını envanterle kapsayacak; sade Türkçe, gerçek ekran görüntüleri, adım adım işlemler, örnek senaryolar, başarı kontrolleri ve hata çözümleri içerecek. Word ve PDF teslim edilecek. Şu anda kılavuz üretilmedi; arayüz değişiklikleri yeniden açılmadı. İşlevsel **54/94** sayımı ayrı kaldı. Nihai işlevsel sürüm kabulünden sonra kılavuz hazır olmadan kapanış teslimatı tamamlandı sayılmayacak.


## 🔴✓ DC01 ilk gerçek salt okunur iş/sonuç döngüsü tamamlandı — 26 Ekim 2026

Operatörün yüklediği **image(20261026-185844).png** doğrudan görsel incelendi. Windows bağlantısı → **Bağlantı görevleri** ekranında **Salt okunur görev kanalı hazır** ve tek **Bağlantı testi / Tamamlandı** satırı var. Görev kimliği **4511c351-86a5-49a3-9993-2f4609a415f8**; **Oluşturulma=26.10.2026 21:57:51 Europe/Istanbul** (tamamlanma saati olarak yorumlanmaz). Sonuçtaki Connector paket sürümü **970d7039-3798-478b-a5f4-a57e245693a0**, uygulanmış yeni DC01 sürümüyle tam eşleşiyor. Görsel SHA256 **01c2e7d2f1fb7487298cb4be0a430361fffe4a090e3656d5ae68ba7ac5691b6e**.

🔴✓ Panelden açık onayla gönderilen **connector.probe** işinin gerçek müşteri Connector'ında alınması ve sonucu AuthWire'a kaydetme döngüsü, operatör panel kanıtıyla kabul edildi. Bu ayrı asistan backend GET/SQL sorgusu olarak sunulmaz. Önceki “müşteri probe işi bekliyor” kayıtları bu kabulden önceki durumdur.

Bu yalnız salt okunur ilk işin uçtan uca kabulüdür. **GPO uygulaması, genel komut yürütme, AD/dizin/Kerberos geçişi, müşteri rollback/boot/rotation/scale kabulü** tamamlandı sayılmaz; CanApplyGpo=false sınırı korunur. Sıradaki fonksiyonel adım merkezi Windows dağıtım planı/önizleme ve yalnız owned deployment GPO üzerinde kontrollü uygulama akışıdır; hedef kapsamı, imzalı paket/publisher güveni ve link/uygulama kapıları ayrı doğrulanacak. **54/94 (~%57),40 açık** ana madde sayımı değişmedi; alt kapı olan gerçek probe roundtrip tamamlandı.


## 🔴✓ DC01 gerçek Connector yükseltmesi uygulandı — 26 Ekim 2026

Operatör pinned **Apply** sonucunu paylaştı: **Stage/Phase=applied, SourceSignaturesValid=true, ServiceTransitioned=true, Error=null, ChangesMayBePartial=false**. Yeni runtime release **970d7039-3798-478b-a5f4-a57e245693a0**; önceki **7b7d7bbc-88c0-4d83-8274-0ab294db2236** paket release'e bağlı **.previous-7b7d7bbc88c04d8382740ab294db2236** arşivinde korunur. Kaynaklar yeniden imzalanmadı (**SourcesPreparedNow=false**). Mevcut hesap, pairing ve ayrı kanal key korundu; yeni servis veya anahtar oluşturulmadı. AD/GPO/trust/key ACL değişmedi, secret export yok; **CanApplyGpo=false** beklenen sınırdır.

Kaynağın Apply akışı başarılı dönüşten önce eşleşen yeni runtime kimliği, taze health ve probe readiness gerektirir; operatör çıktısı bu guard'ların geçtiği kabulüdür. Ayrı asistan DC01 sorgusu ya da müşteri rollback tatbikatı yapılmış sayılmaz. **Uçtan uca gerçek test işi henüz gönderilmedi.** Sırada panelde **Salt okunur görev kanalı hazır** durumunu okuyup bir kez **Test görevini önizle → Test görevini gönder**, ardından listede **Tamamlandı** ve aynı yeni ReleaseId sonucunu doğrulamak var. GPO uygulama ve diğer AD/dizin/Kerberos işleri ayrı açık kapıdır. **54/94 (~%57),40 açık** değişmedi.


## 🔴✓ DC01 imzalı yükseltme aday paketi hazır — 26 Ekim 2026

Operatör pinned wrapper **Prepare** sonucunu paylaştı: **SourceSignaturesValid=true, Stage/Phase=prepared, PackagePrepared=true, Error=null, ChangesMayBePartial=false**. Yeni release **970d7039-3798-478b-a5f4-a57e245693a0**, kaynak component **918bc02453a6f2d821f3f3272654e6e8dcacf6a0**. Aday aynı kanonik root'un **.candidate-970d70393798478ba5f4a57e245693a0** kardeş klasöründe; private journal **C:\ProgramData\AuthWire-ConnectorUpgrade-4c23eebe071546d188eea2e96ad7ee46-970d70393798478ba5f4a57e245693a0\upgrade.json**. Mevcut hesap, pairing ve ayrı kanal key korunmuş; orijinal imzalı kaynaklar korunmuş. AD/GPO/trust/key ACL değişmedi, secret export yok.

**ServiceTransitioned=false**: çalışan paket hâlâ eski **7b7d7bbc-88c0-4d83-8274-0ab294db2236**; gerçek müşteri upgrade/fresh probe kabulü tamamlanmadı. Sırada aynı hash-pinned wrapper'ın ayrı **Apply** modu var. Yalnız owned Connector stop/swap/start yapılır; fresh matching runtime health ve probe readiness gerektirir, başarısız geçiş doğrulanmış eski pakete rollback dener. **GPO apply=false**, panelden test işi henüz oluşturulmadı. **54/94 (~%57),40 açık** değişmedi. Bu kayıt operatör çıktısı kabulüdür; bağımsız DC01 sorgusu olarak sunulmaz.


## 🔴✓ dev.37 panel kabulü; imzalı Windows servis yükseltme/geri alma hazır — 26 Ekim 2026

Operatör **Test görevini önizle** düğmesinin göründüğünü ve **henüz görev göndermediğini** doğruladı. dev.37 panel görünüm kabulü tamam; gerçek Windows probe işi henüz tamamlanmadı.

**PR93 / kaynak 9ed6f6b722eb9504eb83d78b2c25ba4cebe9eec3 / merge 9b735bd38d9ad6e807bc9a3c9a47f7859617fdd7**. Ayrı imzalı yönetici aracı Inspect/Prepare/Apply/Rollback sağlar. Prepare çalışan servise dokunmadan ayrı, imzalı aday oluşturur. Apply önce exact kaynak/ACL, mevcut hesap SID'si, binding, non-exportable kanal key ve SCM recovery kontrollerini yapar; yalnız owned Connector hizmetini durdurur, eski klasörü korur, adayı aynı kanonik yola geçirir ve yalnız release description marker'ını değiştirir. Yeni runtime kimliği, taze HTTPS health ve probe readiness geçmezse doğrulanmış eski pakete geri döner. Belirsiz/yarım hazırlık ve drift otomatik benimsenmez; bounded rollback/journal incelemesi gerekir. Genel resume/garbage collection, hesap/anahtar/publisher rotation ve GPO apply bu araçta yok.

🔴✓ Son commit'te **üç workflow başarılı**, dört Windows job geçti. Foundation **828 test /28 ortam skip** (run40379938061/job121773122125). Gerçek signed SCM/verified HTTPS fixture'ı **53 kontrol** (run40379938416/job121773124654): bağımsız pinned eski kaynak checkout'undan gerçek health-only paket; prepare idempotence; aday/journal drift reddi; başarısız start'ta otomatik rollback; ayrı AllSigned süreçte Apply; bozuk arşivden rollback reddi; explicit rollback ve tekrar Apply; hesap, pairing, CNG key/ACL ve SCM security koruması. Exact müşteri wrapper'ı WinPS5.1'de parse edildi; içindeki 14 kaynaklık arşiv/signature/ACL ve overwrite/tamper reddi de geçti. Sabit DC01-only main, hosted ortamda çalıştırılmadı; müşteri gMSA kabulü açık. İki test-harness uyumsuzluğu (literal AST okuma ve extracted helper compression assembly yüklemesi) giderildi; ürün ve müşteri wrapper byte'ları değişmedi.

**Müşteri teslimatı hazır; DC01'de henüz çalıştırılmadı.** Linux dosyası **/home/segmentiq/authwire-dc01-service-upgrade-20261026.ps1**, **60454 byte**, SHA256 **d79960d55239b0ac63e12309b10cd15252bfc20c9afc5c5feebcb643b0d46595**, readback doğrulandı. İçindeki 14 dosya component source **918bc02453a6f2d821f3f3272654e6e8dcacf6a0** ile eşleşir. Aynı mevcut **FFC134BC305757457163F99C7479B4168E397129** machine publisher kullanılır. Eski release **7b7d7bbc-88c0-4d83-8274-0ab294db2236**, yeni release **970d7039-3798-478b-a5f4-a57e245693a0**. Eşleştirme generation=1, ayrı kanal key cbe3… ve **aw-deploy$** değişmez. Eski imzalı kaynak klasörü ve paket üstüne yazılmaz.

**Sıradaki operatör adımı: DC01 elevated WinPS'de pinned wrapper -Mode Prepare**. Bu yalnız kaynakları imzalayıp ayrı aday paketi hazırlar; mevcut servis PID/state değişirse reddeder. Başarılı **Stage/Phase=prepared** çıktısından sonra ayrı Apply ve taze gMSA/probe kabulü yapılacak. Şu ana kadar müşteri Windows servisine geçiş/AD/GPO/trust/key ACL/endpoint/policy değişikliği ve yeni probe işi yok; Linux dev.37 kalır. Tam veri yedeği alınmadı. **54/94 (~%57),40 açık** değişmedi.


## 🔴✓ dev.37 Linux kurulumu operatör çıktısıyla doğrulandı — 26 Ekim 2026

Operatör **CONNECTOR_PROBE_JOBS_FINISHED**, verified=true, **0.14.0-dev.37 / 280390e081818685969fb3327ace2c074e94e433** sonucunu paylaştı. Yeni **GET /api/deployment/connector/jobs** dahil tüm önce/sonra okumalar 200. Protected-files, broker-process, radius-process, timers ve business-state kontrolleri başarılı. RADIUS **1243360** korunmuş ve yeniden başlatılmamış; broker süreci korunmuş. Policy/GPO/sertifika/Windows paketleri/uç noktaları değişmedi; pairing veya probe işi oluşturulmadı. Tam veri yedeği alınmadı, günlük timer korundu. Kanıt: **/var/lib/authwire-updates/connector-probe-jobs-dev37-20261026T180928Z-bc5961d6**. Bu operatör kurulum çıktısı kabulüdür; bağımsız asistan API okuması olarak sunulmaz.

**Sırada panel kabulü:** Sistem → Windows bağlantısı, test görevi önizleme/gönderme ve görev listesi görünümü. Henüz görev göndermeyin; mevcut DC01 servisi health-only olduğundan görev desteğinin doğrulanmadığı mesajı beklenir. Ayrı imzalı Windows worker upgrade/rollback ve gerçek müşteri probe işi kabulü hâlâ açık. **GPO apply kapalı**, dizin/Kerberos ve tek hesap geçişi açık. **54/94 (~%57),40 açık** değişmedi. Aşağıdaki dev.37 “canlı kurulum bekliyor” notu bu çıktı öncesindeki hazırlık durumudur.


## 🔴✓ Sınırlı Connector test görevi ve sonuç kanalı hazır — 26 Ekim 2026

**PR92 / kaynak 280390e081818685969fb3327ace2c074e94e433 / merge 826580728ffdaa54bb90c3f7d03c3f64c0e7872d / dev.37**. Yalnız **connector.probe** salt okunur işine izin verilir. Panelde mevcut system.connectors yetkisi, HTTPS, CSRF/Origin/Host, güncel principal ve revision/önizleme kontrolü kullanılır. Kimlikler kalıcı saklanır; süreli lease, replay/expiry, eşleştirme/anahtar/kapsam yeniden kontrolü ve idempotent sonuç kaydı vardır. Kayıp create yanıtı yalnız GET ile uzlaştırılır. Bu genel komut/PowerShell/AD/GPO yürütücüsü veya exactly-once GPO iddiası değildir; **CanApply=false**.

🔴✓ Son kaynak commit'inde **yedi PR workflow başarılı**. Foundation **820 test /28 ortam skip** (run40373872742/job121751530861). İmzalı gerçek Windows SCM/normal doğrulanmış pinli HTTPS fixture'ında probe tamamlanması ve **28 kontrol**, altı bağımsız WinPS5.1/AllSigned public işlem, outage/crash/orphan toparlanması geçti (run40373872721/job121751532262). Browser, Linux-stage, gerçek RADIUS, native enrollment ve bounded-network başarılı. Bunlar disposable CI kabulüdür; müşteri gMSA görev kabulü değildir. Yeni sekiz yerel teslimat guard/rollback testi ayrıca geçti.

Native retry testinde kesirli deadline'ın saniyeye aşağı yuvarlanıp geçmiş trigger'a dönüşmesi bulundu: installer kaynak düzeltmesi yukarı yuvarlar ve en az beş saniye ileri rearm yapar. Gerçek SYSTEM iki otomatik deneme/kurtarma ve kesirli/geçmiş deadline regresyonu geçti. Eski dev12/dev13 deploy testleri yalnız kabul ettikleri **donmuş dev11 installer** kaynağına sabitlendi; tarihsel guard'lar gevşetilmedi. **Windows retry düzeltmesi source-only; SYSVOL/uç noktalara uygulanmadı.** Daha önce bir kez görülüp değişmeden tekrar çalıştırmada geçen expired-pending fixture aralıklı hatasının kök nedeni çözülmüş sayılmaz.

**Canlı kurulum bekliyor.** /home/segmentiq/authwire-stage-dev37-280390e08181 altında **174 dosya**, manifest **d6e5ca725c390c2d83eee3f582a3f9ec69bbf790ead0457ea357fe0f83995e00** doğrulandı. Appliance'ın gerçek venv import'u geçti. Yalnız altı runtime/version/UI dosyası değişecek; 168 eski dosya ve 21 korunan server fonksiyon AST'si aynı. Installer **faec4a…**, client **bf5008…**, RADIUS/broker/backup kaynakları korunur. Pinned launcher **/home/segmentiq/authwire-connector-probe-jobs-dev37-20261026.py**, SHA256 **563637ebf4f8c085265e54cd380ca9e896206b702cb2795567d468ae4390f3ef**. Yalnız panel restart; tam veri yedeği yok, günlük timer korunur; kod rollback'i veri restore etmez.

Mevcut Linux hâlâ **dev.36**, RADIUS **1243360**, broker **1069437**, hepsi active. DC01 kurulu paket **7b7d7bbc-88c0-4d83-8274-0ab294db2236** değişmedi ve health-only. Sonraki kapılar: Linux sudo kurulumu ve panel okuma kabulü; ardından ayrı imzalı Windows worker güncellemesi/rollback hazırlığı ve gerçek müşteri probe işi. Henüz iş/pairing/GPO/policy/sertifika yazılmadı. GPO uygulama, dizin/Kerberos işleri, tek hesap geçişi ve endpoint kabulü açık. **54/94 (~%57),40 açık** değişmedi.


## 🔴✓ Fresh WinPS hizmet kontrolü kaynak düzeltmesi ve CI kabulü tamam — 26 Ekim 2026

**PR91 / kaynak b6b4c343375e8f426903904c0bdcfa1d464d7300 / merge 1bda18c04740d6b9eff5b9bcd8657b825ae16ee8**. Kontrol yardımcısı **System.ServiceProcess** assembly'sini native helper cache dönüşünden önce açıkça yükler; controller tipleri tam adla kullanılır. İmzalı builder'ın yalnız ilgili control kaynak pini güncellendi. Eski immutable imzalı kaynak ZIP'i değiştirilmedi; arşiv testi bağımsız checkout ile kendi sabit tarihsel kaynak commit'ini karşılaştırır.

🔴✓ Dört PR workflow başarılı. Gerçek signed SCM/normal verified HTTPS fixture'ında **24 kontrol**, buna altı ayrı x64 **WinPS5.1 -NoProfile/AllSigned** public işlem (Inspect,Start,Start,Stop,Start,Remove), kesinti sonrası otomatik dönüş, crash toparlanması, orphan temizliği ve non-exportable key/ACL koruması geçti (run40339312268/job121629322389). Diğer üç Windows Connector job da başarılı. Foundation **789 test /28 ortam skip** (run40339312565/job121629323053). Historical source delivery (run40339312550) ve bounded-network (run40339312689) başarılı.

**Mevcut DC01 imzalı paketine yeni kod uygulanmadı**; source-only düzeltme sonraki imzalı teslimata dahil edilecek. DC01 kabulü mevcut gMSA ile ilk health + panel online + kontrollü Stop/Start sonrası dört fresh başarıdır. Müşteri boot/crash kabulü, staged signed upgrade/rollback/rotation ve GPO/dizin/Kerberos işleri açık. Bir sonraki fonksiyonel iş sınırlı Connector iş/sonuç kanalı ve kontrollü GPO uygulamasıdır; health tek başına bu yetkileri açmaz. **54/94 (~%57),40 açık** değişmedi. Aşağıdaki CI-bekliyor notları tarihsel hazırlık durumudur.

## 🔴✓ DC01 Connector kontrollü Stop/Start sonrası tekrar sağlıklı — 26 Ekim 2026 17:17 +03

Operatör Stop=Stopped ve Start=Running sonuçlarını paylaştı. Ardından salt okunur kontrolde **2026-10-26T14:17:24.2736685Z**, doğru RuntimeSid **S-1-5-21-34256453-3348971241-2809240126-1648**, **SuccessCount=4, ConsecutiveFailures=0, Healthy=true, FreshHealthAfterRestart=true** görüldü. Mevcut gMSA/kanal anahtarı korunarak kontrollü yeniden başlatma sonrası bağlantı dönüşü kabul edildi. Bu boot/crash recovery veya GPO uygulama kabulü değildir.

İlk fresh-session Start hatası için **System.ServiceProcess** assembly yüklemesi kontrol yardımcısına açıkça ekleniyor; cache dönüşünden önce çalışacak. İmzalı public kontrolün Inspect/Start/Start/Stop/Start/Remove işlemleri altı bağımsız WinPS5.1 -NoProfile/AllSigned sürecinde test edilecek. Builder'ın incelenmiş kaynak SHA256 pini güncellenir; imzalı geçmiş kaynak ZIP'i değiştirilmez ve testi kendi sabit tarihsel kaynak commit'ine karşı kalır. **Kaynak CI kabulü bekliyor; DC01 kurulu paketine yeni kod yazılmadı.** **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ DC01 Connector panel çevrimiçi kabulü doğrulandı — 26 Ekim 2026

Operatörün yüklediği `image(20261026-140923).png` doğrudan görsel incelendi. Sistem → Windows bağlantısı sayfasında **“Connector bağlantı kanalı çevrimiçi.”**, Windows sunucusu **dc01.vizyonveri.local**, beklenen tam **cbe3b5afdc40e5a141f55499ade4e32dbaf4792b0772dfcd025448c7633a9041** key ID ve **eşleştirme sürümü 1** görünüyor. Panel çevrimiçi kabulü geçti. Bu ayrı bir asistan-authenticated API GET olarak sunulmaz.

Sırada yalnız Connector hizmetini imzalı araçla Stop/Start yapmak ve yeniden başlatma zamanından daha yeni health kaydıyla bağlantı dönüşünü doğrulamak var. DC01/AD/RADIUS yeniden başlatılmayacak; paket/anahtar/policy değişmeyecek. Fresh-session System.ServiceProcess assembly kaynak düzeltmesi açık, yönetici oturumu preload geçici çözümü kullanılır. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ DC01 gerçek gMSA Connector ilk health kabulü başarılı — 26 Ekim 2026 17:06 +03

Operatör **Start** sonucunda hizmetin Running olduğunu paylaştı; Win32_Service StartName=`VIZYONVERI\aw-deploy$`, ProcessId=9608. ReleaseId **7b7d7bbc-88c0-4d83-8274-0ab294db2236**. İlk taze health kaydı **2026-10-26T14:06:04.0627530Z**, RuntimeSid **S-1-5-21-34256453-3348971241-2809240126-1648**, **Healthy=true, SuccessCount=1, ConsecutiveFailures=0**. Mevcut runtime bu sonucu ayrı non-exportable kanal anahtarıyla imzalı poll/challenge-health ve normal doğrulamalı/pinli HTTPS üzerinden verir. Gerçek gMSA ayrı kanal key-use ve ilk HTTPS health kabulü geçti; bu operatör çıktısıdır, bağımsız sunucu GET kanıtı değildir.

**CanApply=false, DirectorySyncReady=false, KerberosReady=false** beklenen health-only sınırıdır. GPO uygulama/dizin/Kerberos işleri, sürekli bağlantı/toparlanma/boot, upgrade/rotation ve eski hesapları kaldırma hâlâ açık; A03/A04 tamamen kapanmadı. **54/94 (~%57),40 açık** değişmedi. Sonraki kontrol panelde **“Connector bağlantı kanalı çevrimiçi.”** ve daha yeni health/success sayacıdır.

Start aracında fresh-session `System.ServiceProcess` assembly yükleme eksikliği görüldü. Yönetici oturumunda `Add-Type -AssemblyName System.ServiceProcess` sonrası aynı imzalı Start aracı başarılı oldu; kurulu paket/ACL değiştirilmedi. Kalıcı kaynak düzeltmesi ve preload içermeyen ayrı WinPS5.1 süreç regresyonu hâlâ bekler; bu başarı eksik kaynak düzeltmesini kapatmaz.

## 🔴✓ DC01 kalıcı Connector hizmeti kuruldu; başlatma ve health kabulü bekliyor — 26 Ekim 2026

Operatör önce **Inspect** ile aynı ReleaseId **7b7d7bbc-88c0-4d83-8274-0ab294db2236** paketini doğruladı: ServiceInstalled=false / Absent. Ardından **Install** sonucu ServiceCreated=true, ServiceInstalled=true, ServiceState=Stopped döndü. Hizmet: `AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46`. AD/GPO, logon rights ve key ACL değişmedi; gizli veri dışarı aktarılmadı. Install'ın owned-key/bootstrap/publisher kontrolleri geçti; bu gerçek runtime gMSA health kabulü sayılmaz.

Sırada imzalı kontrol aracının **Start** modu ve taze `state\status.json` içindeki RuntimeSid/Healthy/LastSuccessUtc/SuccessCount ile panel bağlantı kontrolü var. **CanApplyGpo=false** beklenir; bu sürüm health kanalıdır. GPO/dizin/Kerberos işi ve eski hesapları kaldırma hâlâ açık. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ DC01 kalıcı Connector hizmet paketi hazır — 26 Ekim 2026

Operatör `WINDOWS_CONNECTOR_SERVICE_PACKAGE_PREPARED` sonucunu paylaştı: RootPath `C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46`, ServiceName `AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46`, ReleaseId **7b7d7bbc-88c0-4d83-8274-0ab294db2236**, PackagePrepared=true. **ServiceCreated=false, ServiceStarted=false**; AD/GPO değişmedi, gizli veri dışarı aktarılmadı. Bu operatör sonucu paket hazırlığı kabulüdür; kalıcı hizmet/gerçek gMSA HTTPS kabulü değildir.

Sırada paket admin aracının varsayılan **Inspect** kontrolü, ardından mevcut aw-deploy$ ile Install ve ayrı Start kabulü var. Kanal anahtarı yeniden oluşturulmayacak, paket yeniden hazırlanmayacak. **54/94 (~%57),40 açık** değişmedi.

## 🔴✓ DC01 genel eşleştirme dosyası kabulü — 26 Ekim 2026

Operatörün yüklediği `AuthWire-Connector-Binding.json` (`AuthWireConnectorBindingPublicV1`) incelendi: dokuz binding alanı, BaseUrl ve domain beklenen DC01/appliance kaydıyla tam eşleşiyor; **generation=1**. Kanal key ID **cbe3b5afdc40e5a141f55499ade4e32dbaf4792b0772dfcd025448c7633a9041**. Bu kayıt operatörün panelden indirdiği genel metadata kabulüdür; bağımsız canlı GET veya gMSA health testi olarak sunulmaz.

Sırada kabul edilmiş imzalı Windows kaynaklarından paketin hazırlanması var. Mevcut ayrı kanal anahtarı ve kod imzalayıcı yeniden kullanılacak; yeni hesap/anahtar/AD/GPO/policy değişikliği yapılmayacak. Paket hazırlama hizmet kurmaz/başlatmaz. Gerçek gMSA kanal imzası/HTTPS, kalıcı hizmet ve uçtan uca GPO işleri hâlâ açıktır. **54/94 (~%57),40 açık** değişmedi. Önceki “pairing henüz yapılmadı” notları bu genel export tesliminden önceki durumu anlatır.

## 🔴✓ Connector dev.36 canlı uygulaması doğrulandı — 26 Ekim 2026

Operatörün paylaştığı `CONNECTOR_PAIRING_UI_FINISHED` çıktısı **0.14.0-dev.36 / 7531ee65f56ec8d237cb67e8f5a2e24e39293192** kurulumunu doğruladı. Bildirilen tüm önce/sonra okumalar 200. RADIUS PID **1243360** ve broker **1069437** korunmuş; protected-files, timers ve business-state kontrolleri başarılı. Politika, sertifika, GPO, Windows paketleri/uç noktaları değişmedi. Tam veri yedeği oluşturulmadı; günlük yedek timer korundu. Kanıt: `/var/lib/authwire-updates/connector-pairing-ui-dev36-20261026T134425Z-18b52d74`.

**Panel eşleştirmesi henüz yapılmadı**: connector_binding_written=false, pairing_actions_executed=false. Sonraki adım Sistem → Windows bağlantısı ekranında DC01 public adayını önizlemek, **cbe3b5afdc40e5a141f55499ade4e32dbaf4792b0772dfcd025448c7633a9041** key ID'sini tam karşılaştırıp onaylamak ve genel binding dosyasını indirmek. Gerçek gMSA kanal anahtarı kullanımı/HTTPS ve kalıcı hizmet kabulü bekliyor; GPO uygulama yeteneği tamamlandı sayılmaz. **54/94 (~%57), 40 açık** değişmedi. Aşağıdaki dev.36 “sudo bekliyor” kaydı tarihsel hazırlık kaydıdır; bu operatör sonucu onun yerine geçer.

## 🔴✓ Yetkili panel Connector eşleştirme ekranı hazır; dev.36 canlı uygulaması bekliyor — 26 Ekim 2026

**PR90 / kaynak ve runtime release 7531ee65f56ec8d237cb67e8f5a2e24e39293192 / merge 978ad05a6efd3f90cb7faa8a5ac4be469a256bbc**. Sistem → **Windows bağlantısı** sayfası mevcut `system.connectors` yetkisini kullanır; sertifika yönetimi yetkisinden ayrıdır. Backend/server/admin/registry/channel/RADIUS kaynakları aynı kaldı. Yeni ekran yalnız sekiz flat string alanlı genel JSON adayını kabul eder; duplicate/unknown/nested alanı reddeder. Önizleme kayıt yazmaz. DC01 **KeySha256** değerinin tamamı açıkça karşılaştırılıp girilmeden apply açılamaz; aday değişince önizleme/onay temizlenir. Mevcut cookie/CSRF/Origin/revision/principal-lease sınırı kullanılır; maintenance bearer/root doğrudan registry/SQL ile trust yazılmaz. Kayıp yanıt yalnız GET ile uzlaştırılır; POST tekrarlanmaz. Oturum/yetki değişiminde geç yanıtlar temiz ekranı dolduramaz. Eşleştirilmiş metadata'nın yalnız genel dokuz alanlı binding'i indirilebilir.

🔴✓ Altı workflow geçti: browser40330076956, foundation40330077140, RADIUS40330077169, device40330076977, Linux40330077106, bounded40330077360. Foundation **781 test /28 ortam skip**. Yeni gerçek HTTPS browser-fixture senaryosu + bütün mevcut UI testleri geçti; screenshot artifact12653158107 digest ile indirilip görsel incelendi. Yerel **26 registry/verified-HTTPS +8 delivery guard =34 test** başarılı. UI çiftleri fake/disposable sertifika ve DB kullanır; gerçek müşteri eşleştirmesi yapılmadı.

🔴✓ Canlı dev.35'in **173** kaynak dosyası önceki kabul edilmiş manifest ile byte düzeyinde aynı. Ayrı dev.36 adayında **173** dosya ve gerçek Linux venv import'u doğrulandı. Yalnız **6 UI/sürüm dosyası** değişebilir; panel stop/start, RADIUS/kontrol PID/timer/protected-file/business-state koruması, aktif backup guard, bytecode karantinası ve küçük source rollback vardır. Tam veri yedeği/restore yapılmaz; eşzamanlı iş verisi değişmişse rollback incelemeye bırakılır.

Teslim `/home/segmentiq/authwire-connector-pairing-ui-dev36-20261026.py`, SHA256 **5e594d12573daf7edef1e571482eb737622928b3853912837779fda4a39dcc92**. Stage `/home/segmentiq/authwire-stage-dev36-7531ee65f56e`, manifest **7f7a6231c2c4f5bba869b0ddd02aab3337de811c6cc534e8111377b664e65ebc**. **Operator sudo henüz bekliyor; kurulu kaynak/hizmetlere işlem yapılmadı.** Sonrasında normal interactive panel önizleme ve açık key-ID onayı, ardından gerçek gMSA key-use/HTTPS/servis kabulü vardır. UI Source delivery eşleştirme kaydı oluşturmaz. **54/94 (~%57), 40 açık** değişmedi.

## 🔴✓ DC01 imzalı kaynaklar ve ayrı kanal anahtarı kabulü tamam — 26 Ekim 2026 15:57 +03

Operatör `WINDOWS_CONNECTOR_CHANNEL_PREPARATION / Stage=key_prepared` sonucunu paylaştı. Kaynaklar hazırlandı ve tüm imzalar doğrulandı. Ayrı yeni kanal anahtarının policy ve read/use ACL kontrolleri geçti; mevcut code-signing anahtar ACL'i, orijinal bootstrap, AD/GPO/güven depoları korunmuş. Public PEM RSA3072 olarak okunup AuthWire'ın ortak **AuthWireConnectorKeyV1** modulus çerçevesiyle key ID yeniden hesaplandı: **cbe3b5afdc40e5a141f55499ade4e32dbaf4792b0772dfcd025448c7633a9041**, DC01 ile aynı. Bu ID standart DER SPKI digest'i değildir; eşleştirmede DC01 `KeySha256` alanı kullanılır.

Kaynak dizini `C:\ProgramData\AuthWire-ConnectorSources-606371a06ec14f95be2291d8b5220b77`; kanal receipt'i `C:\ProgramData\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46\channel-key.json`. Ayrıntılı genel kayıt `checkpoints/2026-10-26-dc01-channel-key-accepted.json` içindedir. **ServiceKeyAccessVerified=false** normaldir: gerçek gMSA key-use ve HTTPS-hizmet kabulü henüz yapılmadı. Server eşleştirmesi/hizmet kurulumu/GPO uygulaması yapılmış sayılmaz.

Sırada mevcut `system.connectors` yetkisi, interactive oturum ve CSRF sınırı üzerinden preview + açık key-ID onayı + apply var. Bu işlemi ürünün kurulum akışına ekleyen işlevsel panel kontrolü hazırlanıyor; maintenance bearer/root direct write kullanılmayacak. **54/94 (~%57), 40 açık** değişmedi.

## 🔴✓ İmzalı Windows kaynak teslimi ve ayrı kanal anahtarı aracı hazır — 26 Ekim 2026

**PR89 / kaynak 520064fca02640e1bf5f96fcc617c9c7e2866ace / merge c115b0432c749423c8e029723db8f25a9ac7b3ba**. Tek dosyalık teslim, kabul edilmiş kaynak **02c5cb2d04e1bb5f6d402623001e3c029ff96f90** içindeki 13 dosyayı sabit ZIP ve tek tek dosya SHA256'larıyla taşır. Varsayılan Inspect'tir; açık PrepareKey modu mevcut **FFC134BC305757457163F99C7479B4168E397129** machine imzalayıcının/publisher'ın normal enterprise zincirini kontrol eder. Yalnız incelenmiş 12 PS kaynağı imzalar; 1 C# kaynağını aynı digest ile taşır. Çıktı klasörü ve dosyalar yalnız SYSTEM/Administrators'a aittir. Orijinal bootstrap yerine içeriği aynı ayrı imzalı kopya kullanılır; eski dosya ve sahiplik marker'ları değişmez.

Kabul edilmiş kanal initializer'ı önce **owned-account Inspect** yapar, sonra mevcut gMSA **aw-deploy$ / SID ...1648** için ayrı, non-exportable RSA3072 machine Signing anahtarını hazırlar. Appliance UUID **6796fa84-fcff-41c1-b9c5-d725b95ba139** ile Windows Connector UUID **4c23eebe-0715-46d1-88ee-a2e96ad7ee46** ayrı kalır. Yeni anahtarın onaylı read/use ACL'i ayarlanır; kod imzalama anahtarının ACL'i, güven depoları, AD/GPO/hesaplar ve hizmetler değiştirilmez. Public pairing adayı döner; server pairing yazılmaz. Mevcut doğrulanmış kaynak/anahtar yeniden kullanılır; yabancı/kısmi/değişmiş çıktı otomatik ezilmez veya düzeltilmez.

🔴✓ **35 native Windows kontrolü** başarılı (run40325614659/job121581409312): gerçek 13 kaynak/12 imza, sabit repo hash karşılaştırması, değiştirilmiş içerik/digest/path traversal/case/duplicate/size/extra-member reddi, output öncesi imza girdisi kontrolü, protected ACL ve foreign publisher/tamper reddi, code-signing key ACL koruması ve fixture temizliği. Customer entry point/AD/kanal anahtarı CI'da çalıştırılmadı. Foundation **781 test /28 ortam skip**, bounded retry ve native source workflow'larının üçü de geçti.

Teslim `/home/segmentiq/authwire-dc01-channel-prepare-20261026.ps1` (**55033 byte**, SHA256 **1238a2006e81dd61ab820d84b9e304bdcd7a6639679b43ce56d1988532820566**) Linux kullanıcı dizininde tekrar okunup doğrulandı. **Gerçek DC01 PrepareKey henüz uygulanmadı.** Sonrasında interactive yetkili panel preview/key-confirm/apply ve gerçek gMSA key-use/HTTPS/kalıcı hizmet kabulü bekliyor. Linux runtime/UI güncellenmedi; kurulu sürüm dev.35. **54/94 (~%57), 40 açık** değişmedi.

## 🔴✓ DC01 yerel güven ve normal HTTPS kabulü tamam — 26 Ekim 2026 14:26 +03

Operatör `WINDOWS_CONNECTOR_TRUST_PREPARATION / Stage=prepared` sonucunu paylaştı. Tam SHA256 pinli web sertifikası ile mevcut **FFC134BC305757457163F99C7479B4168E397129** kod yayıncısının iki genel güven kaydı eklendi; önceki kayıtlar korundu. TLS **PolicyErrors=None**, normal doğrulama ve tam pin eşleşmesi başarılı; exception yok. Receipt: `C:\ProgramData\AuthWire-ConnectorTrust-baf6a2c1ad8a4928ba8126eb18891699\trust-preparation.json`.

AD/GPO, mevcut anahtar ACL'leri, hesaplar ve hizmetler değişmedi; sertifika üretilmedi/özel anahtar dışarı aktarılmadı. Bu kabul yönetici oturumuna aittir; **gMSA HTTPS, ayrı kanal anahtarı, yetkili panel eşleştirmesi ve kalıcı hizmet hâlâ bekliyor**. İmzalı kaynak teslimi hazırlanıyor. **54/94 (~%57), 40 açık** sayımı değişmedi; A03/A04 kapanmadı.

## 🔴✓ DC01 HTTPS kök nedeni belirlendi; sınırlı güven hazırlığı hazır — 26 Ekim 2026

DC01 operatör tanılaması (10:56:59 UTC / 13:56:59 +03) DNS **10.35.50.246**, TCP bağlantısı ve canlı dev.35 TLS SHA256 pin eşleşmesini doğruladı. Windows yalnız **UntrustedRoot** bildirdi: web sertifikası `CN=kaname.vizyonveri.local` kendinden imzalı, geçerli tarihli, **non-CA / serverAuth-only** bir uç sertifikası. SHA256 **a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d** ve SHA1 **06AC51AF9AB4F7EBAFD3EA89E55BDD191E289636**. Sorun için DNS/saat/policy veya TLS doğrulama kapatma uygulanmadı.

**PR88 / kaynak c19d04372924dbcbf1943c2f15c53402e87ce01b / merge ddd3e0285478c70c6441fdf495261c9360e277d8**: varsayılan Inspect; açık PrepareTrust modu yalnız tam eşleşen genel web sertifikasını DC01 LocalMachine Root'a ve mevcut **FFC134BC305757457163F99C7479B4168E397129** kod imzalayıcı sertifikasının genel kopyasını TrustedPublisher'a ekler. İmzalayıcı normal online machine zinciri mevcut enterprise root **4D6D3C94B878B75AE02B436C0A19D3A3104C68BB** ile doğrulanmadan yazmaz. Yeni CA üretmez; başka güven kaydı silmez/değiştirmez; AD/GPO/hesap/anahtar ACL/servis işlemi yok. Önce/sonra küçük receipt yalnız SYSTEM/Administrators erişimindedir. Kısmi başarısızlık inceleme gerektirir; normal zincir/ad/iptal kontrolü + tam leaf pin ile TLS son kontrolü şarttır.

🔴✓ **21 gerçek Windows kontrolü**: yanlış hash/amaç/depo reddi, non-CA kendinden imzalı uç sertifikasının açık güven sonrası machine zinciri, genel-kopya/özel-anahtar ayrımı, idempotence, mevcut kayıtları koruma, receipt ACL ve test temizliği geçti (run40312464000/job121536763662). C# TLS yardımcısı native WinPS5.1'de derlendi. Foundation **781 test /28 ortam skip** ve bounded-network workflow başarılı. Canlı public sertifikanın digest/imza/SAN/extensions kontrolü ayrıca yapıldı; CI müşteri sertifikasını güven deposuna eklemedi.

**DC01 PrepareTrust henüz çalıştırılmadı.** Teslim: `/home/segmentiq/authwire-dc01-connector-trust-20261026.ps1`, SHA256 **577b0b65839e85d5be0ef63e38288eb59364140c96cf79f296754105bf95b111**. Genel güvenin gerçek DC01 son kontrolü, ardından ayrı kanal anahtarı/panel eşleştirmesi/gerçek gMSA HTTPS-hizmet kabulü bekliyor. Canlı AuthWire sürümü dev.35 olarak kalır; Linux hizmetlerine işlem yapılmadı. **54/94 (~%57), 40 açık** değişmedi.

## DC01 Connector ön kontrolü: iki engel açık — 26 Ekim 2026 13:25 +03

Operatörün `WINDOWS_CONNECTOR_CHANNEL_READONLY_PREFLIGHT` çıktısında servis SID eşleşmesi, mevcut gMSA kullanılabilirliği ve LocalMachine imzalayıcı sertifikanın güncelliği/private-key varlığı doğrulandı. **MachinePublisherTrusted=false** ve normal HTTPS doğrulaması başarısız; ilk betik yalnız dış `MethodInvocationException` türünü bildirdiği için HTTPS kök nedeni henüz bilinmiyor. Root, ad veya revocation sorunu varsayılmadı. Kanal dizini, paket ve kalıcı hizmet yok; hiçbir AD/GPO/güven/anahtar ACL değişikliği yapılmadı. gMSA HTTPS ve eşleştirme hâlâ bekliyor. `VoidTaskResult` yardımcı çıktısı kabul sayılmaz.

Ayrıntılı TLS tanılama dosyası normal Windows zincir/ad/iptal kontrolünü ve canlı dev.35'ten alınan tam SHA256 leaf pinini birlikte şart koşar; doğrulama hatasında bağlantıyı reddeder. Yalnız TLS ve public sertifika hata bilgisi toplar, HTTP/auth payload göndermez; otomatik güven ekleme yok. Gerçek DC01 sonucu bekleniyor. Sayım **54/94** değişmedi.

## 🔴✓ Connector dev.35 canlı uygulaması doğrulandı — 26 Ekim 2026

Operatörün paylaştığı `CONNECTOR_CHANNEL_FINISHED` çıktısında **0.14.0-dev.35 / 2023ac92faf3ee1b9d25d3d0e2c09cfe3ba96c34** başarıyla uygulanmış; bildirilen tüm önce/sonra API okumaları 200. RADIUS PID **1243360** ve kontrol süreci **1069437** korunmuş; politika, sertifika, GPO ve Windows uç noktaları değişmemiş; günlük yedek timer korunmuş. Kanıt: `/var/lib/authwire-updates/connector-channel-dev35-20261026T101342Z-fc756ec9`.

Appliance UUID **6796fa84-fcff-41c1-b9c5-d725b95ba139**, Windows Connector UUID **4c23eebe-0715-46d1-88ee-a2e96ad7ee46** olarak ayrı tutulur. Public TLS SHA256 **a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d**. Henüz eşleştirme yazılmadı, sağlıklı Connector iddiası yok. DC01 için yalnız okuma yapan hesap/sertifika/yayıncı güveni ve normal zincir/ad/iptal kontrolü + TLS pin kontrol dosyası hazır; gerçek DC01 çalışması bekliyor. Dosya yönetici oturumunu sınar; gMSA HTTPS kabulü sayılmaz. Eksik güveni/izni otomatik eklemez, anahtar/hizmet oluşturmaz.

Sırada imzalı Windows paket teslimi, ayrı kanal anahtarı, yetkili panel eşleştirmesi ve gerçek gMSA hizmet kabulü var. **54/94 (~%57) tamam, 40 açık; A03/A04 devam ediyor.** Bu altyapı adımı tamamlanmamış uçtan uca otomasyon olarak işaretlenmedi. Tek gMSA hedefi korunur; eski hesaplar henüz kaldırılmaz. Önceki hazırlık notları tarihsel kanıttır; aşağıdaki eski “sudo bekliyor” durumu bu canlı sonuçla aşılmıştır.

## 🔴✓ Connector dev.35 güncelleme paketi hazır; sudo uygulaması bekliyor — 26 Ekim 2026

- **PR87 / kaynak 86b53429e7fb912466fed771da3520ec18d5e32a / runtime release 2023ac92faf3ee1b9d25d3d0e2c09cfe3ba96c34 / merge 9913e827782aae9c3d5e83c84028a13fedd8c41e**. Önceden test edilen eşleştirme/health backend'i dev.35 olarak sürümlendi. İki tarayıcı testi artık ekranda görünen sürümü kaynak VERSION ile karşılaştırır; panel tasarımı değiştirilmedi.
- 🔴✓ Canlı Linux makinesinde dev.34'e ait **167 kaynak dosyası** digest ile doğrulandı; ayrı dev.35 dizinindeki **173 dosya** manifest'e göre doğrulandı ve mevcut venv ile sunucu/registry import edildi. Canlı kaynak, veri ve hizmetlere yazma/servis komutu uygulanmadı. Root/TLS/DB gizli verilerine normal kullanıcıyla erişim denenince işletim sistemi engeli korundu; sudo parolası gerektirdi, izinler aşılmadı.
- 🔴✓ Pinned güncelleme yalnız panel servisini durdurup başlatabilir; RADIUS/kontrol süreçleri ve kaynakları, politika/sertifika/istemci paketleri, UI varlıkları ve günlük timer korunur. Aktif yedek işi varsa uygulama reddedilir; bytecode kaynak değişiminden önce karantinaya alınır. Sorunda yalnız kod geri alınır; eşzamanlı iş verisi değişmişse otomatik rollback incelemeye bırakılır. Tam veri yedeği alınmaz; küçük kaynak rollback kanıtı tutulur.
- 🔴✓ **57 hedefli test**, buna dahil7 yeni teslimat/public-metadata testi, **781 genel test /28 ortam atlaması** ve ilgili altı PR workflow başarılı. Gerçek RADIUS, browser ve Windows/Kerberos kontrolleri geçti. Değişmeyen Windows expired-pending fixture'ı bir kez fresh retry'da hata verdi; aynı runtime'ın önceki koşusu ve değişikliksiz tekrar koşusu başarılıydı. İlk hata saklandı, aralıklı kök neden kapatılmadı.
- Script sonunda salt okunur DB sorgusu ve doğrulanmış gerçek TLS peer eşleşmesiyle appliance PKI UUID/domain/FQDN/leaf pini raporlanacak. **Bu işlem Connector eşleştirme/anahtar/AD/GPO oluşturmaz.** Appliance UUID henüz alınmış sayılmaz; Windows bootstrap UUID'siyle karıştırılmaz.
- Operatör komutu: **/home/segmentiq/authwire-connector-channel-dev35-20261026.py**, SHA256 **69567b84261c5f5bc723644ed3de381705fcb6ad28b68d2270900707c95b20e7**. Aday dizin **/home/segmentiq/authwire-stage-dev35-2023ac92faf3**; manifest **58e00a22ab4a7f68c52559cfc5faf520fd09a0b890e2e0564e510d5145c05717**.
- **Canlı sürüm hâlâ dev.34; sudo uygulaması ve CONNECTOR_CHANNEL_FINISHED kabulü bekleniyor.** Sonra gerçek public metadata ile imzalı Windows teslimatı, mevcut aw-deploy$ ve kontrollü panel eşleştirmesi/DC01 hizmet kabulü yapılacak. A03/A04 açık; **54/94 (%57),40 açık** değişmedi; resmi rapor yeniden üretilmedi.
- Kanıt: **checkpoints/2026-10-26-connector-channel-delivery.json**. Uygulama kaynağı **checkpoints/2026-10-26-connector-channel-deploy.py**; yalnız kaynak hazırlığı kaydıdır, canlı uygulama sonucu değildir.


## 🔴✓ Kalıcı Windows Connector health hizmetinin kaynak hazırlığı tamamlandı — 26 Ekim 2026

- **PR86 / kaynak e743a8bc66b15f4dca5213fd35de8b02957d097d / main merge 62e9be9d4e58bd06ad38f6aeffaf3dbb32dcdc5a**.
- 🔴✓ Sabit amaçlı, imzalı **x64 Windows hizmeti**, korunan ve hash'e bağlı yerel yapılandırma, mevcut gMSA SID'si ve ayrı kanal anahtarıyla çalışma kaynağı hazır. Varsayılan yönetim komutu yalnız Inspect yapar. Install mevcut gMSA'yı NULL parola ile kullanır, hizmeti oluşturur ama başlatmaz; yeni hesap/hak/GPO/SPN/trust değişikliği yapmaz. Remove yalnız hizmet kaydını kaldırır, paket ve anahtarı korur.
- 🔴✓ Paket hazırlayıcı yalnız gözden geçirilmiş kaynak gövdelerini imzalar; kaynak dosyaları kontrol boyunca yazma/yeniden adlandırmaya karşı kilitlidir. Çalışma kodu/yapılandırma hizmete salt okunur, yönetim araçları yalnız SYSTEM/Administrators erişimindedir; ayrı durum dizini hizmete yazılabilir. Farklı mevcut hizmet, bozulmuş paket, değişmiş izinler veya başlangıç/toparlanma ayarı sessizce düzeltilmez.
- 🔴✓ Otomatik gecikmeli açılış ve iki adet60 saniyelik SCM yeniden başlatma tanımlandı; dış komut/reboot yok. Başarılı bağlantı30 saniyede yenilenir, hatada30/60/120 saniye beklenir. Özel kill-on-close Windows job nesnesi, parent PID/başlangıç zamanı ve duplicate-worker kontrolleri alt işlemleri host ömrüne bağlar. Durdurmada20 saniye kontrollü bekleme ardından job her koşulda kapatılır.
- 🔴✓ **23 yeni gerçek Windows kontrolü** geçti: public imzalı builder ve varsayılan Inspector, değiştirilmiş kaynak reddi, gMSA olmayan kurulumun yazmadan reddi, yönetim ACL ayrılığı, gerçek düşük yetkili SCM süreç SID'si ve HTTPS health, tekrarlı başlatma, kesinti/toparlanma, stop/crash alt işlem temizliği, SCM yeniden başlatması, bozuk kod/yazılabilir config reddi ve anahtarı koruyan kaldırma. Fixture hesabı/servisi/LSA hakkı/anahtar/sertifika/hosts değişiklikleri temizlenir; bu gerçek müşteri gMSA testi değildir.
- 🔴✓ Son kaynakta **774 genel test /28 ortam atlaması**, ilgili üç PR workflow ve dört Windows job başarılı. Önceki kanal19 /native CNG33 /anahtar8 /HTTPS16 kontrolleri de geçti. Bu PR Linux/RADIUS/Windows uç istemcisi kodunu değiştirmedi; önceki gerçek RADIUS kanıtı korunur, yeniden çalıştırılmış sayılmaz.
- **Canlı uygulama dev.34 kaldı; DC01'e hizmet kurulmadı.** Gerçek aw-deploy$ ile kurulum/bağlantı, gerçek reboot ve GPO yenilemesi kabulü, imzalı teslimat ve appliance güncellemesi açıktır. V1 mevcut paketin üstüne yazmayı reddeder; aşamalı upgrade/rollback, kanal/pin ve yayıncı rotasyonu ayrıca tamamlanacak. HTTPS timeout5 saniye yapılandırılır; DNS/OS sertifika işlemleri daha uzun sürebileceğinden mutlak beş saniye garantisi verilmez; hizmet kapatma bağımsız job temizliğiyle korunur.
- Health AD/Kerberos/GPO yetkisi değildir: **can_apply/directory_sync_ready/kerberos_ready=false**. Sonra sınırlı iş/sonuç ve dizin/canlı AD/Kerberos tek gMSA geçişi, pilot/ölçek kabulü ve eski hesapların kontrollü kaldırılması gelir. **A03/A04 açık;54/94 (%57),40 açık** değişmedi. Tam yedek ve resmi rapor yeniden üretilmedi; canlı hizmet/hesap/sertifika/paket işlemi yapılmadı.
- Ayrıntı: **WINDOWS_CONNECTOR_HEALTH_SERVICE.md**. Kanıt: **checkpoints/2026-10-26-connector-permanent-service.json**.


## 🔴✓ Ayrı Windows kanal anahtarı ve gerçek doğrulanmış HTTPS durum bağlantısı — 26 Ekim 2026

- **PR85 / kaynak 8fc2859ccccbfb72a46b586cd4a8ec8507a44dfe / main merge 6ac3a0f86395b7b13ad74e8cdfaf37e202fb9dff**.
- 🔴✓ Mevcut gMSA için ayrı **RSA3072, dışa aktarılamayan, yalnız imzalama amaçlı makine kanal anahtarı** hazırlama kaynağı eklendi. Kod imzalama anahtarı yeniden kullanılmaz; yeni AD hesabı açılmaz. Varsayılan Inspect, imzalı mevcut bootstrap/hesap kapsamını doğrular. Hazırlanan anahtar ve public kapsam korunan atomik kayıtla izlenir; doğrulanmış anahtar tekrar kullanılır. Yarım kayıt, farklı kapsam, reparse, sahiplik/izin farkı ikinci anahtar veya sessiz onarım yerine inceleme gerektirir.
- 🔴✓ AuthWire ile sabit iki HTTPS uç noktasında imzalı poll ve bağımsız sunucu nonce'u üzerinden health doğrulaması hazır. Normal TLS zinciri/sunucu adı/iptal kontrolü + kayıtlı leaf SHA256 pini zorunlu. HTTP, yönlendirme, proxy, varsayılan Windows credential'ı, cookie ve global TLS bypass yok. Her istek için tam yanıt süresi5 saniye, gövde4096bayt, header16KiB ile sınırlı; yavaş gövde de süreye dahildir. İmza/kapsam/süre/replay, IP hız ve eşzamanlılık sınırları uygulanır.
- 🔴✓ **19 Python kanal testi + 33 mevcut gerçek Windows CNG kontrolü + 8 yeni anahtar/kayıt/ACL kontrolü + 16 gerçek HTTPS istemci kontrolü** geçti. Beş gerçek HTTPS handler testi ve diğer regresyonlarla **774 test /28 ortam atlaması** başarılı; yedi PR workflow (native Windows, Kerberos/enrollment, browser ve gerçek RADIUS dahil) geçti. Hosted fixture anahtarı, geçici public trust ve hosts girdileri temizlenir; müşteri DC01 üzerinde çalıştırılmış sayılmaz. Hazırlama wrapper'ının gerçek signed-bootstrap/gMSA uç kabulü ayrıca açıktır.
- Bu sadece kaynak hazırlığıdır: **kalıcı Connector hizmeti kurulmadı, canlı uygulama dev.34'te kaldı**. Gerçek müşteri gMSA'sı ile bu yeni anahtar/HTTPS çalışması henüz doğrulanmadı. transport_active yalnız son90s içindeki health kanıtını ifade eder; SCM kurulum/AD/Kerberos/GPO kanıtı değildir. **can_apply/directory_sync_ready/kerberos_ready=false**.
- Mevcut hesaplar/SPN'ler, GPO, CA/sertifika ve imzalama anahtarları, uç paketleri, çalışan hizmetler ve günlük yedekleme değiştirilmedi; her değişiklik için tam veri yedeği alınmadı. Önceki aralıklı Windows retry zamanlama kök nedeni açık; bu son koşuda gerçek SYSTEM otomatik yeniden deneme başarılı, eski hata gizlenmedi.
- Sıradaki iş: kalıcı imzalı Windows hizmeti, güvenilen yerel çalışma yapılandırması ve kurulum/güncelleme/toparlanma; gerçek gMSA kanal kabulü. Ardından sınırlı iş/sonuç, dizin/canlı AD ve Kerberos'un tek gMSA'ya geçişi, pilot/ölçek kabulü ve eski hesapların kontrollü kaldırılması. **A03/A04 açık;54/94 (%57),40 açık** değişmedi.
- Kaynak/CI/koruma kanıtı: **checkpoints/2026-10-26-connector-dedicated-key-https.json**. Ayrıntılı sözleşme **CONNECTOR_SINGLE_ACCOUNT_CHANNEL.md** güncellendi; resmi durum raporu yeniden üretilmedi.


## 🔴✓ Kalıcı Connector eşleştirmesi ve HTTPS yönetim sınırı hazır — 25 Ekim 2026

- **PR84 / kaynak 8ba3519bd796807325ce1fbdf478440ebb599b20 / main merge f15035a47b527294ad5f6600b8217d3759fc0039**: tek public Connector kaydı mevcut korunan SQLite runtime_settings içine eklendi. Eşleştirme/anahtar değiştirme/iptal, global sürüm ve audit aynı transaction içinde kaydedilir. Yeni hesap/credential veritabanı veya özel anahtar saklanmaz.
- 🔴✓ Önizleme mevcut kayıt, revizyon, appliance PKI/domain/TLS kapsamı ve public anahtara bağlıdır. Ayrı **system.connectors** yetkisi; HTTPS, panel oturumu, Host/Origin/CSRF ve kayıt öncesi güncel principal kontrolü zorunlu. Directory/certificate write veya bakım bearer tokenı trust yazma hakkı kazanmaz. Parmak izi açıkça doğrulanır; kayıp yanıt GET ile uzlaştırılır, ikinci yazma yapılmaz.
- 🔴✓ Eşleştirme ve iptal tombstone/sürümü yeniden başlatmada korunur; eski nonce/online durumu korunmaz. Anahtar değiştirme/iptal başka gerçek süreçte de önceden bekleyen kanıtı geçersiz kılar. Başarısız audit/transaction değişikliği atomik geri alır; eski geçerli kanıtı gereksiz yere tüketmez. TLS/domain/PKI drift'i kanıtları engeller, iptal yapılabilir kalır.
- 🔴✓ **17 SQLite/public-PKI + 9 gerçek doğrulanmış HTTPS testi** eklendi; önceki13 kanal testiyle hedefli39 test geçti. Genel **763 test /28 ortam atlaması**, altı PR workflow başarılı. Windows machine/user/Kerberos/SYSTEM retry, browser ve native RADIUS kontrolleri ilk koşularında başarılı; önceki aralıklı retry kök neden maddesi kapanmadı.
- 🔴✓ Public binding SQLite yedeğinde korunur, mevcut yedek kararlılık fingerprint'i rotasyonu izler; worker kodu değiştirilmedi. Eski yedeğe geri dönüşte trust yeniden onayı ve tam appliance restore/boot kabulü ayrı açık kapıdır; geri alınmaya dayanıklı iptal garantisi verilmez.
- **Kimlik ayrımı:** Binding.instance_id appliance PKI kurulum UUID'sidir; Binding.connector_id mevcut Windows bootstrap InstanceId'sidir. Pilot Windows kimliği **4c23eebe-0715-46d1-88ee-a2e96ad7ee46** aynı gMSA/GPO sahiplik marker'larında korunur. Bir UUID diğerinin yerine yazılmaz; hesap/GPO yeniden oluşturulmaz. Appliance gerçek UUID'si bu çalışmada alınamadı (sudo -n public-only sorgusunda parola gerekti); değer uydurulmadı.
- Bu yalnız kaynak hazırlığıdır: yönetici API'si fixture HTTPS ile test edildi, canlı dev.34'e uygulanmadı. Peer health endpoint'i, çalışan Connector hizmeti/transport veya AD/GPO işi açılmadı; **transport_active/can_apply/directory_sync_ready/kerberos_ready=false**. Mevcut hesaplar, GPO, CA/sertifikalar, Windows paketleri ve çalışan 802.1X için değişiklik yapılmadı; tam yedek üretilmedi.
- Sonraki somut iş: ayrı non-exportable Windows kanal anahtarının hazırlanması/yalnız mevcut gMSA erişimi ve gerçek outbound HTTPS Connector bağlantısı. Sonra iş/sonuç, canlı AD/Kerberos geçişi ve eski hesapların kontrollü kaldırılması. A03/A04 açık, **54/94 (%57),40 açık** değişmedi; resmi rapor yeniden üretilmedi.
- Kanıt: **checkpoints/2026-10-25-connector-durable-pairing.json**; sözleşme: **CONNECTOR_SINGLE_ACCOUNT_CHANNEL.md**.

## 🔴✓ Tek hesaplı Connector için kanal mesajı doğrulama temeli — 25 Ekim 2026

- **A04 alt parçası:** Python sunucu doğrulayıcısı ve Windows PowerShell5.1 istemci yardımcısı, ayrı dışa aktarılamayan makine kanal anahtarıyla sınırlı health kanıtı üretip doğrular. Kanal anahtarı yeni AD hesabı değildir; mevcut kod imzalama anahtarından ayrıdır.
- Kurulum/connector/host GUID'leri, gerçek Windows süreç SID'si, binding sürümü, appliance FQDN/TLS pini, anahtar kimliği, işlem/yol ve süreli nonce imzaya bağlıdır. Sunucu yalnız yerelde önceden güvenilmiş public anahtarı kullanır; kendi anahtarını sunan peer eşleştirilemez. Eşzamanlı replay, değişmiş/yanlış anahtar, bozuk/duplicate/non-UTF8 JSON ve doğrulama sırasında dolan süre reddedilir.
- **13 Python sınır testi + 33 gerçek Windows CNG/PowerShell5.1 kontrolü başarılı.** Windows imzası bağımsız Python doğrulamasından geçti; fixture anahtarı temizlendi, key ACL korundu, özel anahtar dışa aktarılmadı. Bu hosted fixture kanıtıdır, DC01 üzerinde canlı Connector kabulü değildir.
- **Genel regresyon:** 737 test (28 ortam atlaması); yedi PR workflow başarılı. Mevcut Windows retry zamanlama fixture'ı ilk koşuda deadline_rearmed/sonraki çalışma eksikliğiyle hata verdi; yalnız başarısız işler tekrarlandığında geçti. Retry kodu/testi gevşetilmedi; aralıklı hata ve kök neden işi açık kaldı.
- Kaynak **PR83 / 44d59280fe5b693f515571a4195068cf97a52fd4**, main merge **fd4de99fc090409f6019c60add4fc9ac79e47770**.
- Bu kaynak parçası **HTTP route açmaz, servis kurmaz, AD/GPO işi çalıştırmaz**. Health kanıtı AD üyeliği/kullanıcı kimliği, Kerberos oturumu veya GPO uygulanma kanıtı sayılmaz; can_apply/directory_sync_ready/kerberos_ready false kalır.
- Sonraki somut iş: yetkili yönetici eşleştirmesinin kalıcı, sürümlü ve audit'li kaydı; yalnız owned kanal anahtarının hazırlığı/ACL'si ve gerçek doğrulanmış HTTPS bağlantısı. Sonra sınırlı iş/sonuç akışı, canlı AD/katalog ve Kerberos geçişi. Mevcut bootstrap'ın boş SPN gereksinimi ancak gözden geçirilmiş sahipli SPN geçişiyle değiştirilebilir; HTTP SPN iki hesapta bulunmaz.
- Mevcut LDAP/HTTP/gMSA hesapları, çalışan Linux/RADIUS/panel, GPO, sertifikalar, uç paketleri ve günlük yedekler değiştirilmedi. Yeni anahtar/GPO/hesap/customer komutu gerekmedi; canlı sürüm **dev.34** kaldı. A03/A04 ve tek hesap geçişi açık, üst checklist **54/94 (%57),40 açık** değişmedi; resmi rapor üretilmedi.
- Ayrıntılı sözleşme: **CONNECTOR_SINGLE_ACCOUNT_CHANNEL.md**. Kaynak ve CI kanıtları **checkpoints/2026-10-25-connector-channel-health-foundation.json** içinde tutulur.

## Tek yönetilen hizmet hesabı hedefi — 25 Ekim 2026, plan kararı; uygulama bekliyor

Operatör mevcut üç hesabın müşteri kurulumlarında yönetim yükünü kabul etmedi; standart tek-domain kurulumunda tek yönetilen hizmet hesabı hedefini onaylayıp zamanlamayı bize bıraktı. Karar: **mimari şimdi netleştirilecek, uygulama kalıcı Windows Connector geliştirmesine dahil edilecek; üç hesaba bağımlı kalıcı connector tamamlandıktan sonraya ertelenmeyecek.**

- [ ] **A04 öncelikli tasarım/uygulama alt işi:** tek kurulum sihirbazı ve bir gMSA ile AD katalog eşitlemesi, canlı hesap/üyelik kontrolleri, Kerberos kayıt kabulü, owned GPO dağıtımı ve Windows tarafında imzalama. Bu bir ürün hedefidir; mevcut sürüm bunu henüz sağlamaz. İlk destek sınırı tek AD domainidir; çoklu domain/forest için tek hesap garantisi verilmez.
- [ ] Linux üzerinde saklanan LDAP bağlantı parolası ve ayrı HTTP keytab bağımlılığını kaldırabilecek Windows taraflı doğrulama/okuma yolu tasarlanır. gMSA parolası, keytab veya özel imzalama anahtarı Linux'a dışa aktarılıp hesap sayısı azaltılmış gibi gösterilmez. Mevcut LDAP hesabına GPO yazma yetkisi eklenmez; HTTP SPN aynı anda iki hesaba kaydedilmez.
- [ ] Connector kanalında kurulum/host/işlem kimliğine bağlı karşılıklı kimlik doğrulama, replay ve süre denetimi; kullanıcı ve bilgisayar kayıtlarının ayrılığı, istek/CSR bağlama ve mevcut Kerberos güvenlik şartları korunur. Linux sertifika otoritesi ve RADIUS karar sınırları ayrıca değerlendirilir; sıradan bir connector beyanı kimlik doğrulama kanıtı kabul edilmez.
- [ ] Dizin okuması ve GPO/imzalama işlemleri tek AD kimliği altında olsa da API/işlem yetkileri ayrı ve sınırlı tutulur. Domain Admin/orman geneli yazma yetkisi verilmez; owned GPO ve açıkça seçilmiş imzalama anahtarı sınırları korunur. Mevcut aw-deploy$ hazırlıkları yeniden kullanılır; gereksiz yeni hesap açılmaz.
- [ ] Connector erişilemezliği ve AD erişilemezliğinde katalog güncelliği, canlı yetkilendirme, RADIUS zaman aşımı ve kayıt/yenileme davranışı açıkça tanımlanır; eski katalog canlı AD kontrolü yerine sessizce geçirilmez. Gecikme/yük ve toparlama testleri yapılır.
- [ ] **Geçiş kabulü:** AD eşitlemesi + canlı AD retleri + kullanıcı/bilgisayar Kerberos kaydı + sertifika yenileme + wired/wireless RADIUS + owned GPO/paket imzalama + kesinti/geri alma birlikte doğrulanır. Pilot ardından ölçek kabulü yapılır. Uç kabulü gerçek test bilgisayarı erişimine bağlıdır.
- [ ] Ancak yeni yol kabul edilip eski bağlantı bağımlılıkları tek tek envanterlendikten sonra eski LDAP/HTTP hesaplarının yetkileri ve SPN/keytab kullanımı kontrollü kaldırılır. Önce geri alınabilir geçiş ve devre dışı bırakma, sonra bağımlılık kalmadığı doğrulanarak silme planlanır. Mevcut çalışan hesaplar şimdi değiştirilmez/silinmez.
- [ ] Müşteri deneyimi: yönetici bir kez bootstrap'ı yetkilendirir, günlük parola yönetimi gMSA ile otomatik olur, devamı AuthWire panelinden yürür. Yönetici hesabı kalıcı servis kimliği/credential olarak saklanmaz. Pilot grubunun ve GPO'nun hesap olmadığı kurulumda açıklanır.

Bu karar yalnız yol haritasını günceller; yeni kod, AD/GPO/SPN, hesap, keytab, servis, sertifika veya canlı paket değişikliği yapılmadı. Önceki başarılı gMSA/GPO/imzalama kanıtları korunur. Canlı AuthWire dev.34; A03/A04 açık, üst checklist **54/94 (%57), 40 açık** değişmedi; yeni üst madde eklemek yerine A04 kabul şartı genişletildi.

## 🔴✓ GPO yenilemesi sonrası gerçek hizmet oturumu ve Authenticode imzalama kabulü tamamlandı — 25 Ekim 2026

- Operatör yenileme sonrasında **WINDOWS_CONNECTOR_SERVICE_AUTHENTICODE_PROBE1.0.0** sonucunu paylaştı. Yeni SCM hizmeti **AuthWireLogonProbe-8d6389074d234875baf386c18ab25969**, gerçek PID **4892**, beklenen gMSA SID **...-1648**.
- 🔴✓ **ServiceLogonVerified / SignatureVerified / RuntimeSigningTested / ServiceKeyAccessVerified / AuthenticodePackageSigningVerified / AuthenticodeSignatureVerified / ProbeVerified=true**. Geçici hizmet, binary ve yazılabilir sonuç dizini temizlendi; Error/NativeErrorCode null, CleanupErrors boş.
- 🔴✓ **KeyAclPreserved=true / KeyAclChanged=false**; AD/GPO/logon-right değişikliği ve secret export yok. İmzalanan deneme dosyası çalıştırılmadı. Korunan kanıt **C:\\ProgramData\\AuthWire-ServiceProbe-a66ee6441fbf404994a5d846bc7d2335\\summary.json**, public imzalı örnek aynı klasörde **verified-authenticode-test.ps1**.
- Önceki başarılı Computer GPUpdate ve hakların yeniden eklenmeden korunması çıktısıyla birlikte **mevcut policy yenilemesi sonrası gerçek çalışma alt kabulü kapandı**. Aracın genel **GpoPersistenceVerified=false** alanı bu ayrı sonuçları otomatik birleştirmez; ham değer değiştirilmeden saklandı. Reboot ve gelecekteki policy değişiklikleri doğrulanmış sayılmaz.
- **CertificateChainValidationPerformed=false** bu araç içinde ayrı certutil zincir/CRL kontrolünün tekrarlanmadığını belirtir; önceki ayrı başarılı zincir/iptal kontrolü korunur. Bu dosya imzalama yeteneği kanıtıdır; gerçek uç paketlerinin dağıtımı değildir.
- Sıradaki çalışma: kalıcı Windows connector ve kimliği doğrulanan AuthWire iş/durum iletişimi; ardından yalnız owned yönetim GPO'su için kapsamlı dağıtım ve yeni yayıncı güveni. Mevcut pilot trust GPO, paketler ve endpointler kendiliğinden değiştirilmez. **ConnectorInstalled / CanApplyGpo=false**; A03/A04 ve uç kabulü açık.
- Kayıt: **checkpoints/2026-10-25-windows-connector-service-authenticode-after-gpupdate-live-result.json**. Canlı uygulama dev.34; toplam **54/94 (%57),40 açık** değişmedi. Resmi rapor yeniden üretilmedi.

## 🔴✓ DC01 bilgisayar GPO yenilemesinde hizmet oturumu hakkı ve mevcut atamalar korundu — 25 Ekim 2026

- Operatör **Computer Policy update has completed successfully / GpupdateExitCode0** ve **WINDOWS_CONNECTOR_SERVICE_RIGHT_AFTER_GPUPDATE** çıktısını paylaştı.
- 🔴✓ **DirectServiceRightStillAssigned=true / BeforeAllowEntriesPreserved=true**, DenyAssignedSids ve RemovedAllowSids boş. Allow listesi SID1616, ownedgMSA1648, NT SERVICE all80-0 ve mevcut82-300670...9415 olarak korunmuş. **InspectionAddedRights=false**; kontrol eksik hakkı geri ekleyerek sonucu maskelemedi.
- **GpoDefinitionsChangedByThisCommand=false**; var olan DC01 Computer policies yeniden uygulandı, GPO tanımı düzenlenmedi. Bu sonuç mevcut yenilemede hakkın korunmasıdır; reboot veya gelecekteki başka müşteri policy değişikliklerine garanti olarak sunulmaz.
- Sonraki somut kabul: aynı signed **AuthWire-Service-Authenticode-Probe-v1.ps1 RunProbe** bir kez daha **refresh sonrasında** çalıştırılır. Sadece mevcut Right atamasını görmek yerine gerçek managed-account SCM startup + raw signature + Authenticode + independent verification + cleanup + keyACL korunmasını tekrar doğrular. Yeni değişiklik sonrası bu tekrar gerekli kabul testidir; gereksiz tekrar değildir.
- Yeni download/sertifika/anahtar/ACL/AD/GPO değişikliği gerekmez. Gerekli before/after policy kontrol kanıtları önceki protected receipt klasöründe; proof aracı kendi ayrı owned evidence GUID klasörünü oluşturur.
- Henüz post-refresh runtime çıktısı yok. Probe içindeki eski **GpoPersistenceVerified=false** genel alanı bu after-refresh aggregate kanıtını otomatik değerlendirmez; gerçek sonuçlar birlikte kaydedilecek. Üst A04/full connector rollout/reboot kapıları açık kalır.
- Kanıt checkpoints/2026-10-25-windows-connector-service-right-gpupdate-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-service-authenticode-after-gpupdate.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ DC01 gerçek gMSA Authenticode dosya imzalama ve bağımsız doğrulama tamamlandı — 25 Ekim 2026

- Operatör **WINDOWS_CONNECTOR_SERVICE_AUTHENTICODE_PROBE1.0.0 / DC01 / VIZYONVERI\\aw-deploy$** sonucu verdi. **AuthenticodePackageSigningVerified/AuthenticodeSignatureVerified/ServiceKeyAccessVerified/RuntimeSigningTested/SignatureVerified/ServiceLogonVerified/ProbeVerified=true**.
- 🔴✓ Gerçek runtimeSID **...-1648**, PID **348**, signer **FFC134BC305757457163F99C7479B4168E397129**. Hizmet yeni nonexportable machine CNG key ile disposable ps1'i imzaladı; controller Windows Valid/exact signer/hash kontrolü yaptı. **ArtifactExecuted=false**, mevcut SYSVOL/endpoint paketleri yeniden imzalanmadı veya dağıtılmadı.
- 🔴✓ Temporary service **AuthWireLogonProbe-2f3a3f842f7347c28a8fcca5beb7e4ac** / binary / writable result directory kaldırıldı. **Error/NativeErrorCode=null, CleanupErrors boş; KeyAclPreserved=true, KeyAclChanged=false; AD/GPO/logon-right değişikliği=false, SecretsExported=false**.
- Protected summary **C:\\ProgramData\\AuthWire-ServiceProbe-2db1f10d137b437ca5db372ca4db0ddb\\summary.json**, public signed audit artifact **verified-authenticode-test.ps1**. Verified key-access receipt hash44A7AAD8... öncekiyle aynı.
- **CertificateChainValidationPerformed=false** bu probe'ın standalone certutil testini tekrar etmediğini belirtir; önceki machine-context CA/base-deltaCRL/code-signing-policy kontrolü zaten ayrı kanıtta başarılı. **GpoPersistenceVerified/ConnectorInstalled/CanApplyGpo=false** beklenen açık kapılardır; full connector otomasyonu tamamlandı denmez.
- Sonraki kontrollü operatör adımı mevcut **DC01 bilgisayar ilkelerini gpupdate /target:computer /force ile yeniden uygulayıp** signed ServiceRightPrepare1.0.0 **Inspect** çıktısını öncesi/sonrası saklamak. Bu **salt okunur işlem olarak sunulmaz**: mevcut Computer policy ayarları tekrar uygulanır, GPO tanımları düzenlenmez. /boot veya /logoff verilmez. ModeInspect yeni hak eklemez; kayıp hak varsa otomatik geri ekleme yok.
- GPUpdate konsolunun gerçek tamamlanma çıktısı + exitcode + direct service right + previous Allow entries + Deny list incelenecek. Tek snapshot gelecekte tüm policy değişikliklerine/reboot'a karşı kalıcılık garantisi değildir. Refresh sonrası gerçek runtime startup/signature ve gerekirse mevcut hakları koruyan scoped policy tasarımı ayrı kapı.
- Kanıt checkpoints/2026-10-25-windows-connector-service-authenticode-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-service-right-gpupdate-check.ps1. GPUpdate kaynağı: https://learn.microsoft.com/windows-server/administration/windows-commands/gpupdate .
- A04 signer önkoşulu gerçek uçta tamamlandı; üst A04 connector/managedGPO/publisher-trust/endpoint dağıtımı/ölçek kapıları açık olduğu için **54/94 (%57),40 açık** sayımı korunur. AuthWire app dev.34, formal rapor yenilenmedi.

## 🔴✓ Hizmet bağlamında gerçek Authenticode test aracı Windows'ta geçti; DC01 sonucu açık — 25 Ekim 2026

- **Test-AuthWireServiceAuthenticode1.0.0**, PR82 merge **c3fab6d5493b571805a83fde560ec427e3e77e52**. **33 native Windows PowerShell5.1 kontrolü başarılı**: gerçek signed SCM/LocalService worker key Read yokken başarısız, signer trust yokken başarısız; Read+fixture-root trust ile disposable UTF16 ps1 imzalama ve native Valid doğrulaması başarılı. Üç temporary hizmet de temizlendi.
- 🔴✓ Controller signed artifact için exact signer/thumb/full-file hash ve Windows Authenticode Valid durumunu bağımsız kontrol etti; wrong signer/hash ve **tampered signed body (güncel dosya hash'i verilse bile)** reddedildi. Korunan public signed audit copy de Valid. **Artifact hiçbir aşamada çalıştırılmadı; fixture private key export yok.**
- SDK host **InitialSessionState.NoLanguage** + sabit **Set/Get-AuthenticodeSignature AddCommand** çağrıları kullanır; AddScript/script evaluation/PowerShell execution-policy override yok. Compiler PowerShell SDK referansı PSHOME varsayımı yerine **[PSObject].Assembly.Location** ile gerçek GAC konumundan alınır; ilk native testteki pre-service duruş canlıya taşınmadan düzeltildi. Worker hata ayrıntıları korumalı summary'ye aktarılır.
- Araç mevcut owned SCM/null-password/runtimeSID-PID-host-nonce/cleanup/keyACL-before-after guard'larını korur. Disposable comment-only artifact, gMSA writable result dizininde imzalanır, controller doğrulanmış public copy'yi admin/SYSTEM evidence root'a alır; worker/service/result/binary kaldırılır. EvidenceArtifactPath altında public imzalı örnek korunur.
- **AuthenticodePackageSigningVerified** bu araçta disposable dosyayla imzalama yeteneğinin doğrulanmasıdır; mevcut SYSVOL/endpoint paketlerinin imzalandığı/yayıldığı anlamına gelmez. **CertificateChainValidationPerformed=false** standalone certutil probe'ın bu araçta tekrar yapılmadığını belirtir; önceki DC01 machine-context chain/base-deltaCRL başarısı ayrı kanıtta kabul edilmiştir.
- Diğer SCM35/GPO66/keyACL25/raw-signing23/bootstrap/foundation/bounded-network kontrolleri başarılı. Gerçek müşteri gMSA ve key bu CI'da kullanılmadı. **DC01 Authenticode canlı sonucu hâlâ bekleniyor.**
- Staged **authwire-service-authenticode-probe-v1-20261025.ps1**, SHA256 **41cb745fa25afa9e020b6a616836e805b81fa220b748254561da56465031c1a9**, remote digest doğrulandı. Operatör komutu checkpoints/2026-10-25-windows-connector-service-authenticode-probe-run.ps1; native kanıt checkpoints/2026-10-25-windows-connector-service-authenticode-prepared.json.
- DC01 gerçek sonuçtan sonra yeni publisher public trust/managed GPO/endpoint execution ve merkezi connector-daemon kapıları açık. **GPO/trust/keyACL/endpoint package değişikliği yok**. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Makine signer güven zinciri ve CRL iptal kontrolü başarılı — 25 Ekim 2026

- Operatör exact signer **FFC134BC305757457163F99C7479B4168E397129** için **certutil -verify -urlfetch / HCCE_LOCAL_MACHINE / CERT_CHAIN_POLICY_BASE** çıktısını paylaştı. Leaf ve issuer **dwErrorStatus=0**, **Leaf certificate revocation check passed**, exitcode0.
- 🔴✓ CodeSigning application-policy **1.3.6.1.5.5.7.3.3** doğrulandı. Doğrulanmış self-signed issuer/root **CN=vizyonveri-DC01-CA, DC=vizyonveri, DC=local**, thumbprint **4D6D3C94B878B75AE02B436C0A19D3A3104C68BB**, NotAfter22May2029. Bu thumbprint sonraki issuer seçimleri için kayıtlı baseline'dır; AD enrollment object cACertificate byte karşılaştırması bağımsız olarak yapılmış sayılmaz.
- 🔴✓ LDAP AIA certificate ve CDP **baseCRL0349** / **deltaCRL034A** doğrulandı. Base nextUpdate **1Kas2026 06:19+03**, delta nextUpdate **27Eki2026 06:20+03**. Revocation chain exclude-root; bu anlık başarı CRL yayımlama/erişim sağlığının gelecekte sürekli başarılı kalacağını kanıtlamaz. OCSP URL yok; CRL yolu başarılı olduğundan bu tek başına hata değildir.
- **KeyAclChanged/TrustStoreChanged=false**. Kanıtlı log **machine-signing-v2-chain-verify.log**; mevcut CA, key ve endpoint paketlerine müdahale edilmedi.
- Sonraki araç **Test-AuthWireServiceAuthenticode** PR82 hazırlanıyor: aynı owned SCM/gMSA worker, comment-only UTF16 disposable ps1 üzerinde Windows PowerShell SDK fixed Set/Get-AuthenticodeSignature cmdletleri. **AddScript / script execution / execution-policy override yok**; artifact çalıştırılmaz. Worker ve controller exact signer/status/hash doğrular, protected public signed audit copy tutar, temporary worker/result dizini kaldırılır. Native CI ve gerçek DC01 sonucu henüz açık.
- Raw service RSA signing önceki kapıda başarılı; gerçek **AuthenticodePackageSigningVerified** bu kayıttan çıkarılmaz. Yeni publisher TrustedPublisher/endpoint execution/managed GPO scope/connector-daemon kapıları açık.
- Kanıt checkpoints/2026-10-25-windows-connector-signer-chain-live-result.json. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ DC01 gerçek gMSA machine-key imzalama testi başarıyla tamamlandı — 25 Ekim 2026

- Operatör **WINDOWS_CONNECTOR_SERVICE_SIGNING_PROBE1.0.0 / DC01 / VIZYONVERI\\aw-deploy$** gerçek sonucunu paylaştı. **ServiceLogonVerified/SignatureVerified/RuntimeSigningTested/ServiceKeyAccessVerified/ProbeVerified=true**. Runtime SID **S-1-5-21-34256453-3348971241-2809240126-1648**, gerçek PID **7412**.
- 🔴✓ Owned machine signer **FFC134BC305757457163F99C7479B4168E397129** hizmet bağlamında identity-bound RSA3072/SHA256/PKCS1 challenge imzaladı; public doğrulama geçti. Sadece ACL veya Administrator imzasından çıkarılmış bir başarı değildir; önceki helper'ın actual SCM runtime SID/PID/service/host/nonce bağları da geçti.
- 🔴✓ Temporary service **AuthWireLogonProbe-d88cb9eaccd748f29b53db7c03ece553**, binary ve writable result directory kaldırıldı. Error/NativeErrorCode=null, CleanupErrors boş. **KeyAclPreserved=true / KeyAclChanged=false / AD-GPO-logon rights değişikliği=false / SecretsExported=false**.
- Protected evidence **C:\\ProgramData\\AuthWire-ServiceProbe-1683d449a22f40379d494af2747a2dd5\\summary.json**. Probe'ın kullandığı yeni verified key-access receipt SHA256 **44A7AAD8823C1034AFB32B01EB0F223E72D5D9F83210CCDC197BAFC7C0C6475E** (original failure receipt hash86E10... ile karıştırılmaz).
- **AuthenticodePackageSigningVerified=false / CertificateChainValidationPerformed=false** beklenen açık kapılar; raw challenge signing bu sonuçlara dönüştürülmez. **GpoPersistenceVerified/ConnectorInstalled/CanApplyGpo=false**; merkezi otomasyon bütünü henüz tamam değil.
- Sonraki readonly operatör adımı exact thumbprint public response üzerinde **certutil -verify -urlfetch**; chain/AIA/CDP/revocation detayları ve exitcode protected loga alınır. Bu komut CA cert dağıtımı/import/key ACL/GPO değişikliği yapmaz; Windows retrieval cache güncellenebilir. Sadece exitcode ile pinned issuer/chain/trust başarısı varsayılmaz; gerçek çıktı incelenecek. Kaynak: https://learn.microsoft.com/windows-server/administration/windows-commands/certutil .
- Ardından gerçek hizmet bağlamında bir disposable dosyanın **Authenticode** imzalanması/doğrulanması, pinned CA-chain/new publisher trust ve scoped Windows deployment kapıları var. Endpoint paketleri henüz yeni publisher'a geçirilmedi.
- Kanıt checkpoints/2026-10-25-windows-connector-service-signing-live-result.json; sonraki readonly komut checkpoints/2026-10-25-windows-connector-signer-chain-check.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Gerçek CNG/SCM imzalama test aracı Windows'ta doğrulandı; DC01 gMSA sonucu açık — 25 Ekim 2026

- **Test-AuthWireServiceSigning1.0.0** PR81 merge **a7c775a0ceca64663058cc361aeeb5f044537aa0**. **23 native Windows PowerShell5.1 kontrolü başarılı**: signed SCM worker LocalService bağlamında machine/nonexport/RSA3072/signing-only CNG key ile Read yokken başarısız, exact Read verildiğinde başarılı; public RSA/SHA256/PKCS1 doğrulaması geçti. Her iki temporary service ve dosyalar temizlendi; fixture key/cert/trust materyali kaldırıldı.
- Nonce/serviceName/host/SID/PID/SignerThumbprint/Signature/policy boolean değişiklikleri ve başka sertifika public-key doğrulaması reddedildi. Private key export yok. Eski SCM35/GPO66/keyACL25/bootstrap, foundation ve bounded-network kontrolleri de başarılı.
- Araç mevcut null-password gMSA SCM helper lifecycle'ını kullanır. Varsayılan **Inspect**; operatöre **RunProbe** somut komutu verilir. Signed bootstrap/right helpers owned gMSA/readiness ve SeServiceLogonRight'ı kontrol eder; exact LocalMachine/My cert ve verified key-ACL receipt/current-ACL scope guard'ı yapılır. Key ACL probe sonrasında da karşılaştırılır.
- Worker yalnız bound owned signer ile identity-bound challenge imzalar. **AD/GPO/logon rights/CA/key ACL/trust/client package değişikliği yapmaz**; geçici signed executable mevcut Administrator publisher ile doğrulanır, test imzası yeni makine signer'ı ile hizmet bağlamında atılır. Mevcut publisher özel anahtarı gMSA'ya verilmez/taşınmaz.
- **Raw challenge signing** sonucu ile **AuthenticodePackageSigningVerified/CertificateChainValidationPerformed** karıştırılmaz; bu ikisi false, ilgili kapılar açık. ProbeVerified ancak actual SID/PID/nonce binding + public signature verification + service/binary/result cleanup + keyACL korunması birlikte geçerse true.
- Staged **/home/segmentiq/authwire-service-signing-probe-v1-20261025.ps1**, SHA256 **85a21def1fcbcd542d599c7d7d71acb74ab3f2cc6f2704dbcd3e4c027b2d0152**, remote digest doğrulandı. DC01 operatör komutu checkpoints/2026-10-25-windows-connector-service-signing-probe-run.ps1. Önceki signed Bootstrap1.0.3 / ServiceRightPrepare1.0.0 helper'ları TEMP altında kullanılır.
- **Gerçek DC01/aw-deploy SID1648 signing sonucu henüz gelmedi**. Sonuç pending: ServiceKeyAccessVerified=false burada hazırlık kaydıdır; yeni probe çıktısından başarı türetilir. Kanıt checkpoints/2026-10-25-windows-connector-service-signing-probe-prepared.json.
- AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ DC01 signer key izin doğrulama kaydı tamamlandı; gerçek hizmet signing probe hazırlanıyor — 25 Ekim 2026

- Operatör **WINDOWS_CONNECTOR_SIGNER_KEY_ACL_VERIFIED / ComparisonVersion1.0.1**, thumbFFC134... / serviceSID1648 için **ReadPermissionVerified=true / ExistingRightsPreserved=true / AutoInheritedMetadataOnly=true / ChangedControlFlagsCode1024** sonucunu paylaştı.
- 🔴✓ Orijinal receipt **phasepostcheck** geçmiş hata kanıtı olarak korunmuş; SHA256 **86E10BC742147BD1A25B9E53907723DC75B34B106235B69BE4648A6F32F23851** yeni verified JSON'a bağlanmış. Current SDDL protected **D:PAI**, SYSTEM/BA FA ve yalnız serviceSID FR. **KeyAclChangedByThisCheck=false**; ACL yeniden uygulanmadı.
- **ServiceKeyAccessVerified/RuntimeSigningTested=false** doğru: bu kapı yalnız izin doğrulaması. Gerçek hizmet anahtar kullanımı henüz kabul edilmez.
- Sonraki araç **Test-AuthWireServiceSigning1.0.0** PR81'de hazırlanıyor: mevcut signed owned-SCM yaşam döngüsü, null gMSA password, runtime SID/PID/host/nonce bağları ve cleanup tekrar kullanılır. Worker yalnız exact LocalMachine/My signer üzerinde CNG/machine/nonexport/RSA3072/signing-only özellikleriyle identity-bound challenge imzalar; controller public RSA doğrular. Inspect varsayılanı korunur; RunProbe ayrı çağrıdır.
- Bu raw challenge signing kapısıdır; **AuthenticodePackageSigningVerified/CertificateChainValidationPerformed=false** açıkça raporlanacak. Gerçek hizmet context Authenticode package signing, pinned CA-chain/trust ve Windows deployment halen sonraki kapılardır; paket/policy/GPO/logon right/key ACL değiştirme yok.
- Native Windows fixture gerçek düşük yetkili LocalService ile önce Read olmadan başarısızlık, sonra exact file Read ile başarı/signature tamper reddi/cleanup deneyecek. **CI ve gerçek DC01 sonucu bu kayıtta henüz bekleniyor**; PR hazırlanması canlı başarı değildir.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-key-acl-verified-live-result.json. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Key Read grant doğru; false-negative postcheck yalnız AI metadata farkından düzeltildi — 25 Ekim 2026

- Operatör readonly postcheck sonucunda **Expected D:P → Actual/Current D:PAI** gösterdi. Tek control farkı **SE_DACL_AUTO_INHERITED bit1024**; **P/protection=true** korunuyor. Bütün ACE'ler explicit/inheritanceNone/propagationNone.
- 🔴✓ Exact key için **SYSTEM ve BA FullControl2032127**, yalnız **aw-deploy service SID1648 Read+Synchronize1179785** var. Owner BA544, group DomainUsers513 değişmedi. Bu gerçek çıktı üzerinden **izin hazırlığı ve mevcut hakların korunması kabul edildi**. İzin yeniden yazılmaz/geri alınmaz; ilk postcheck bir false-negative idi.
- İlk kontrolüm tüm SDDL'yi strict metin olarak karşılaştırdığı için Windows metadata bayrağını hak değişikliği saydı. Yeni **Compare-AuthWireSigningKeyAcl** yalnız DACL_AUTO_INHERITED bitini bellek içi RawSecurityDescriptor kopyasında karşılaştırmadan çıkarır; owner/group, diğer bütün control flags (özellikle protected), ordered ACE/right/SID/type/inheritance/propagation ve SACL aynı kalmalıdır. Null DACL reddedilir; broad replace/metadata wildcard yok.
- 🔴✓ **25 native Windows PowerShell5.1 testi geçti**: gerçek NTFS Set-Acl roundtrip, Read+Synchronize, protected/owner/group korunması; fazla hak/yazma/deny/başka SID/extra ACE/eksik SYSTEM-BA/korumasız/inheritance/SACL/null-empty DACL reddi. Comparator dosyaya ACL yazmaz. Eski SCM35/GPO66 ve WindowsBootstrap/foundation/bounded-network kontrolleri başarılı. PR80, merge **31f1d86b7ab113f08c54b6a766c71fe00304a998**.
- Eski staging grant dosyası tekrar çalıştırılmaz; zaten existing receipt guard'ı var. Repo operatör grant checkpoint'i aynı sınırlı comparator'ı kullanacak şekilde düzeltildi. Canlı izni değiştirmeyen r2 verifier staged: **authwire-signer-key-access-verify-v1-r2-20261025.ps1**, SHA256 **8559a9920dff23483a301e7f26dc9fd7c7e93ea087ed806891f1ab6aec47a99b**.
- r2 verifier original receipt/expected baseline/exact key mapping/current ACL scope kontrolü yapıp **machine-signing-v2-key-access-verified.json** oluşturur. Orijinal failure receipt phasepostcheck geçmiş kanıt olarak korunur; yeni verified evidence onun SHA256'sını bağlar. Bu lokal evidence sonucu henüz gelmedi.
- **ServiceKeyAccessVerified/RuntimeSigningTested=false** beklenen kapılar. İzin verilmesi gerçek gMSA anahtar kullanım testi yerine geçmez. Sonraki çalışma aynı gMSA altında geçici signed SCM worker ile sahipli key üzerinde challenge imzalama ve public doğrulama; cleanup ve runtime SID/PID/nonce kanıtı. Henüz bu yeni signing probe çalışmadı/hazırlandı denmez. Pinned CA-chain/public publisher trust/endpoint dağıtımı ve connector kapıları açık.
- Kaynak: https://learn.microsoft.com/windows/win32/secauthz/security-descriptor-string-format . Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-key-access-metadata-review.json; r2 kaynak checkpoints/2026-10-25-windows-connector-machine-signer-key-access-verify.ps1.
- AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## Owned signer key Read grant sonrası SDDL postcheck eşleşmedi; gerçek izinler yeniden okunacak — 25 Ekim 2026

- Operatör staged **authwire-signer-key-access-prepare-v1-20261025.ps1** aktarımından sonra **Izin sonrasi kontrol eslesmedi** hatası bildirdi. Hata, Set-Acl ve ActualAfterSddl receipt yazımından **sonraki** strict string karşılaştırmasında. İzin yazma komutu döndü; **başarı/koruma doğrulaması kabul edilmez**.
- İlk baseline SYSTEM/Administrators FullControl ve protected DACL olarak kabul edilmişti. Beklenen değişiklik yalnız service SID1648 Allow Read+Synchronize. Gerçek fark henüz görülmediğinden sıra/SDDL gösterim farkı veya gerçek hak/owner/group değişikliği olarak teşhis konmadı.
- **machine-signing-v2-key-access.json korunur**, mevcut receipt nedeniyle eski script zaten yeniden uygulamayı engeller. Otomatik tekrar/ACL reset/owner değiştirme/rollback yok. Gerçek gMSA signing probe başlatılmadı; **ServiceKeyAccessVerified=false**.
- Sonraki salt okunur kontrol existing receipt **BeforeSddl/ExpectedAfterSddl/ActualAfterSddl/Phase** ve exact key dosyasının **CurrentSddl/OwnerSid/GroupSid/Protected + her ACE numeric rights/inheritance/propagation** değerlerini verecek. Yalnız diagnostic evidence machine-signing-v2-key-access-postcheck.json yazılır; key ACL değişmez. Çıktı gelmeden grant başarıya çevrilmez veya onarım komutu verilmez.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-key-access-postcheck-failure.json; readonly komut checkpoints/2026-10-25-windows-connector-machine-signer-key-access-postcheck-readonly.ps1.
- Önceki signer certificate/template/CNG metadata kabulü korunur. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Owned CNG key dosyasının izin başlangıcı kabul edildi; sınırlı service Read hazırlığı — 25 Ekim 2026

- Operatör **WINDOWS_CONNECTOR_SIGNER_KEY_ACL_READONLY** sonucu: exact thumbFFC134... keyfile **C:\\ProgramData\\Microsoft\\Crypto\\Keys\\6d83645dd6648563b32f0fdecaf3d56e_1fed02ca-1f1d-4faf-839e-e8eb2f0eff4a**.
- 🔴✓ Owner **BUILTIN Administrators SID32-544**, group **DomainUsers SID513**, protected DACL; SDDL **O:BAG:DUD:P(A;;FA;;;SY)(A;;FA;;;BA)**. Yalnız SYSTEM/Administrators explicit FullControl2032127; inherited ACE yok. **DirectServiceEntryPresent=false / KeyAclChanged=false / ServiceKeyAccessVerified=false**.
- Sonraki operatör komutu gMSA SID1648/class/instance-host description, exact cert-thumb→CNG.UniqueName mapping, KSP/machine/permanent/nonexport/signing3072 ve normal dosya guard'larından sonra **yalnız bu dosyaya service SID1648 Allow Read** ekler. Klasörlere veya başka anahtarlara izin verilmez; owner/group/protected flag ve mevcut SYSTEM/BA hakları korunur.
- Windows FileSystemAccessRule Allow Read içine **Synchronize** bitini otomatik ekler; beklenen Read+Synchronize sayısal haklar1179785, FullControl değildir. Kaynak: https://learn.microsoft.com/dotnet/api/system.security.accesscontrol.filesystemrights ve https://learn.microsoft.com/dotnet/api/system.security.accesscontrol.filesystemsecurity.addaccessrule .
- **machine-signing-v2-key-access.json** CreateNew ile Set-Acl'den önce BeforeSddl/ExpectedAfterSddl tutar. Taze baseline SDDL farklıysa write yapılmaz. Sonrasında ActualAfterSddl expected ile birebir karşılaştırılır; eski hakların korunması bu karşılaştırmaya dayanır. Mismatch/yarım receipt halinde kör tekrar/auto-reset yok.
- Bu standart yerel admin ACL işlemi henüz canlı uygulanmadı; native runtime signing probe veya gMSA key-use acceptance olarak sunulmaz. Prepare sonucu gelse dahi **ServiceKeyAccessVerified=false**, gerçek SCM/gMSA imzalama testi sonraki kapı. Chain/pinned CA/public publisher trust/endpoint package ve connector kapıları açık kalır.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-key-acl-before-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-machine-signer-key-access-prepare.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Gerçek makine signer template/key özellikleri doğrulandı — 25 Ekim 2026

- Operatör **WINDOWS_CONNECTOR_MACHINE_SIGNER_KEY_READONLY**, exact thumbprint **FFC134BC305757457163F99C7479B4168E397129**, **TemplateOidMatches=true** sonucunu paylaştı. Certificate extension doğru owned template OID'ye bağlı.
- 🔴✓ Gerçek key: **Microsoft Software Key Storage Provider / RSA3072 / IsMachineKey=true / IsEphemeral=false / ExportPolicy=None(0) / KeyUsage=Signing(2)**. Key admin bağlamında property okumak için açıldı; private key export veya signing yapılmadı. Non-exportability policy metadata kabulü, export denemesi olarak raporlanmaz.
- **InspectedAs=VIZYONVERI\\administrator, KeyAclChanged=false, ServiceKeyAccessVerified=false**. gMSA erişimi henüz yok/kabul edilmedi; bu sonuç Administrator bağlamındaki okumadır.
- Sonraki readonly operatör kapısı **aw-deploy SID1648** AD kimliği + exact owned KSP key UniqueName üzerinden yalnız ilgili normal makine key dosyasının owner/group/SDDL/rules/protection başlangıcını okumak. KeyFile reparse/directory/invalid basename durumunda durur. Certificate Thumb/metadata guard'ları tekrarlanır; private key içeriği okunmaz veya izin değişmez.
- **machine-signing-v2-key-acl-before.json** protected receipt klasörüne kaydedilecek. Mevcut haklar görüldükten sonra yalnız service SID1648'e owned key erişimi ve actual signed SCM probe yapılacak; chain/pinned issuer/public publisher trust/endpoint deployment kapıları açık.
- Kaynak: https://learn.microsoft.com/dotnet/api/system.security.cryptography.cngkey.uniquename ve https://learn.microsoft.com/windows/win32/seccng/key-storage-and-retrieval . Key path Microsoft Software KSP machine/shared key kapsamına özeldir; başka sağlayıcıya genellenmez.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-key-live-result.json; readonly komut checkpoints/2026-10-25-windows-connector-machine-signer-key-acl-readonly.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ CA RequestId6 sertifikası LocalMachine/My deposuna yüklendi ve private key eşleşti — 25 Ekim 2026

- Operatör **Installed Certificate / WINDOWS_CONNECTOR_MACHINE_SIGNER_INSTALLED**, RequestId6, **LocalMachine/My / HasPrivateKey=true** sonucunu paylaştı. Thumbprint **FFC134BC305757457163F99C7479B4168E397129**, serial **6A000000067A2B82B44DD3676E000000000006**.
- Subject **CN=dc01.vizyonveri.local**, issuer **CN=vizyonveri-DC01-CA, DC=vizyonveri, DC=local**; NotAfter **2027-10-25T16:37:01+03:00**. Önceki Accept komutundaki public subject/issuerCN/validity/code-signing-only EKU/RSA3072 guard'ları geçti. Bu issuerCN guard'ı kriptografik chain/signature doğrulaması yerine geçmez.
- **ServiceKeyAccessVerified=false** beklenen durum. Sertifika kurulu/HasPrivateKey olması gMSA imza yetkisinin veya tam otomasyonun tamamlandığı anlamına gelmez. Yeni Request/Submit yapılmaz.
- Sonraki readonly kapı, yalnız exact thumbprint için **IX509ExtensionTemplate.InitializeDecode** ile certificate template OID kontrolü ve **GetRSAPrivateKey/RSACng** ile provider/machine/ephemeral/exportPolicy/keyUsage/keySize özelliklerini okumak. Private key admin bağlamında açılır; **sign/export/ACL değişikliği yapılmaz**. Anahtar byte'ları/loga private key çıkışı yok. ExportPolicy0/None ve IsMachineKeytrue beklenir; gerçek çıktı henüz gelmedi.
- Sonuç machine-signing-v2-key-check.json olarak mevcut protected receipt klasöründe saklanacak. TemplateOID/CNG metadata sonucundan sonra chain/pinned issuer ve owned key ACL/gMSA runtime signing probe ayrı kapılar olarak kalır. Public signer trust/endpoint paket geçişi henüz yapılmadı.
- Kaynaklar: https://learn.microsoft.com/windows/win32/api/certenroll/nf-certenroll-ix509extensiontemplate-initializedecode ; https://learn.microsoft.com/dotnet/api/system.security.cryptography.cngkey.exportpolicy ; https://learn.microsoft.com/dotnet/api/system.security.cryptography.cngkey.ismachinekey
- Kanıt checkpoints/2026-10-25-windows-connector-machine-signer-installed-live-result.json; readonly komut checkpoints/2026-10-25-windows-connector-machine-signer-key-readonly.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ CA makine imzalama sertifikasını üretti; RequestId6 — 25 Ekim 2026

- Operatör **RequestId:6 / Certificate retrieved(Issued) Issued**, **ExitCode=0 / CertificateFileExists=true** sonucunu paylaştı. Aynı SHA-pinned CSR için issuance kabul edildi; yeni istek veya anahtar üretimi yapılmayacak.
- Public response **machine-signing-v2.cer**, gönderim receipt **machine-signing-v2-submit.json**, log **machine-signing-v2-submit.log**, mevcut protected **AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37** klasöründe. CSR SHA256 D07E3800345AFD62E8423B5E720047BDA3670CBDB1644153BDBD90BDEC689BDE.
- Sonraki operatör kapısı public response subjectCN/DC01 + issuerCN/vizyonveri-DC01-CA + validity + code-signing-only EKU + RSA3072 kontrolünden sonra **certreq -accept -machine -q**. Aynı thumbprint LocalMachine/My/HasPrivateKey ise tekrar Accept yapılmaz; yeni certificate request gönderilmez. Sonuç machine-signing-v2-install.json içine kaydedilecek.
- Basit CN karşılaştırması issuer imza/zincir doğrulaması yerine geçmez; certificate template extension, CA chain/signature, gerçek key provider/machine scope/export policy, owned-key gMSA ACL ve gerçek service signing probe halen sonraki kapılardır. Bu komut service key ACL/TrustedPublisher/GPO/client package değişikliği yapmaz.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-certificate-issued-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-machine-certificate-accept.ps1. **Live installation sonucu henüz gelmedi.** AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ DC01 makine CSR oluşturma tamamlandı; aynı istek CA'ya gönderilecek — 25 Ekim 2026

- Operatör **CertReq: Request Created / WINDOWS_CONNECTOR_MACHINE_CSR_PREPARED** çıktısını paylaştı. LDAP AD enrollment policy **EC3C46B2-ED74-4BF2-BB4C-5A8E7D9BB33C** görüldü. **SubmittedToCa=false**.
- Public CSR **C:\\ProgramData\\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37\\machine-signing-v2.req**, SHA256 **D07E3800345AFD62E8423B5E720047BDA3670CBDB1644153BDBD90BDEC689BDE**. CSR success kabulü; gerçek certificate template/issuer/key provider/machine scope/export policy/gMSA usage henüz doğrulanmadı.
- Sonraki operatör adımı aynı hash-pinned CSR ile **certreq -submit -AdminForceMachine -q -config explicitCA req cer**; yerel Submit yardımında seçenekler doğrulandı. -machine Submit'e eklenmez; makine anahtar bağlamı önceki New/INF'te, gönderim kimliği AdminForceMachine ile sağlanır.
- **machine-signing-v2-submit.json** FileMode.CreateNew ile gönderimden önce oluşturulur; önceki state/cer/log varsa yeni gönderim yapılmaz. Public stdout/RequestId **machine-signing-v2-submit.log** içinde; exit code/cer varlığı receipt'te. CLI başarı/cer varlığı ayrıca incelenecek; pending/error/connection kesintisinde yeni CSR/Submit yapılmaz, mevcut request ID ile sürdürülür. Bu adım otomatik Accept/key ACL/trust/package değişikliği yapmaz.
- Kanıt checkpoints/2026-10-25-windows-connector-machine-csr-prepared-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-machine-csr-submit.ps1. Eski hatalı enroll receipt korunur. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ DC01 verb seçenekleri ve önceki denemenin sıfır yeni sertifika sonucu doğrulandı — 25 Ekim 2026

- Operatör **Yapıştırılan metin(5).txt** ekinde yerel certreq yardımlarını ve store farkını gönderdi. Scratch kopyası okundu; kaynak ek değiştirilmedi.
- 🔴✓ **-New** machine/INF/CNG/key/security-descriptor seçeneklerini; **-Submit** explicit **-AdminForceMachine/-config/-q**; **-Accept** **-machine/-q** seçeneklerini destekliyor. AdminForceMachine yanlışlıkla -Enroll ile birleştirilmişti; doğru verb **Submit** olarak yerel sürümle doğrulandı.
- 🔴✓ Korunan eski işlem kaydı **Phase=enroll_returned, ExitCode=-2147024809**, **NewMachineCertificateCount=0**. Bu yalnız LocalMachine/My installed certificate farkıdır; tüm makine key/request deposunun envanteri olduğu iddia edilmez. Eski receipt silinmez veya retry için temizlenmez.
- Sonraki kontrollü adım ayrı **machine-signing-v2.inf/.req**: **certreq -new -machine -q**, RSA3072/SHA256/Microsoft Software Key Storage Provider/digitalSignature/code-signing-only/Exportable=false/ExportableEncrypted=false/PrivateKeyArchive=false/KeyProtection0/Admin+SYSTEM key DACL. Anahtar adı sistem tarafından üretilecek; mevcut key re-use veya özel anahtar export yok.
- INF FileMode.CreateNew ile yazılır; daha önce hazırlık dosyası varsa işlem durur. Ayrı public before snapshot ve CSR hash saklanır. Bu aşama CA'ya istek göndermez; başarılı CSR çıktısından sonra **-Submit -AdminForceMachine -config exactCA** ve sonra **-Accept -machine** ayrı kapılardır. Henüz CSR/key metadata doğrulaması veya sertifika issuance başarısı yok.
- Kanıt checkpoints/2026-10-25-windows-connector-certreq-capabilities-live-result.json; operatör komutu checkpoints/2026-10-25-windows-connector-machine-csr-prepare.ps1. Template/publication kabulü korunur; app dev.34, **54/94 (%57),40 açık**, A03/A04 açık. Formal rapor yenilenmedi.

## Makine sertifikası isteği CLI parametre kontrolünde durdu; yeni istek gönderilmeden sürüm kontrolü — 25 Ekim 2026

- Operatör yerel **certreq -Enroll** yardımında yalnız **PolicyServer/user/machine/pin** seçeneklerini ve **Unexpected argument: -AdminForceMachine / 0x80070057 (WIN32 87)** bildirdi. Verilen enroll çağrısı bu sürümün kabul ettiği seçeneklerle uyumlu değildi; genel certreq dokümanındaki seçenekler verb bazında doğrulanmadan birlikte kullanılmıştı.
- Bu çıktı **CA tarafından sertifika reddi** veya geçerli enrollment sonucu değildir. Parametre ayrıştırma aşamasında duruş gözlendi; yeni certificate/key state kesinliği için before snapshot'a karşı readonly store farkı istenir. Başarı/sertifika oluştu kabulü yapılmaz.
- Önceki **machine-enrollment-attempt.json korunur**; otomatik silme/retry ve daha geniş template enrollment yetkisi verilmez. Kaynak kayıttaki enroll komutu retired/fail-fast yapıldı; hatalı komut yeniden kullanılmaz.
- Sonraki readonly operatör adımı **certreq -new -? / -submit -? / -accept -?**, mevcut attempt phase/exit code ve LocalMachine/My thumbprint farkı. Kullanılacak yeni verb/context yalnız bu makinenin çıktısı görüldükten sonra kesinleştirilecek. Yardım komutları istek oluşturmaz/göndermez.
- Template oluşturma ve publication kabulü korunur. **Gerçek machine signer sertifikası, provider/machine/export policy incelemesi, gMSA private-key usage ve gerçek imza testi halen açık.** Mevcut Administrator publisher, CA/policy/GPO/client paketleri değiştirilmedi.
- Kanıt checkpoints/2026-10-25-windows-connector-enrollment-cli-failure.json; readonly komut checkpoints/2026-10-25-windows-connector-certreq-cli-readonly.ps1. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Yeni imzalama şablonu CA'da yayımlandı — 25 Ekim 2026

- Operatör certutil **Adding / command completed successfully** ve **WINDOWS_CONNECTOR_TEMPLATE_PUBLICATION** sonucunu paylaştı: **AuthWireConnectorCodeSigning-4c23eebe / PublishedNow=true / TemplatePublished=true / ExistingTemplatesPreserved=true**. Mevcut CA template listesi korunarak yalnız yeni template eklendi.
- **EnrollmentRequested/CertificatesChanged=false**. Template oluşturma ve publication kabulü tamam; henüz makine sertifikası/key-scope/non-exportability/service signing/publisher trust/connector dağıtımı kabulü yok.
- Sonraki adım: DC01'de yerleşik **certreq -enroll -machine -AdminForceMachine -q -config explicitCA exactTemplate** ile tek istek. Microsoft Learn AdminForceMachine'ın Local System bağlamından isteği gönderdiğini belgeliyor; mevcut kullanıcı kişisel imzalayıcısı taşınmaz veya kullanılmaz. Kaynak: https://learn.microsoft.com/windows-server/administration/windows-commands/certreq_1
- Korunan mevcut template receipt klasöründe **machine-enrollment-attempt.json**, isteğin öncesinde FileMode.CreateNew ile kaydedilir; tekrar varsa yeni istek gönderilmez. BeforeThumbprints/UTC/context/exit code/candidate thumbprint saklanır; key/password export yok. Başarılı CLI sonucu ve tek yeni LocalMachine/My/HasPrivateKey certificate yalnız **aday kurulum** kabulüdür; template extension/issuer/key provider/machine scope/export policy ayrıca incelenecek.
- Operatör komutu checkpoints/2026-10-25-windows-connector-machine-signing-enroll.ps1; bu yerleşik araçla kontrollü canlı işlem kapısıdır, henüz gerçek enrollment sonucu veya gerçek service signing testi olarak raporlanmaz. GPO/key ACL/TrustedPublisher/paket değişikliği ve servis yeniden başlatma içermez.
- Kanıt checkpoints/2026-10-25-windows-connector-template-publication-live-result.json. AuthWire app dev.34, **54/94 (%57),40 açık**, A03/A04 açık; formal rapor yenilenmedi.

## 🔴✓ Yeni makine tipi imzalama şablonu oluşturuldu ve doğrulandı — 25 Ekim 2026

- Operatör **SigningTemplatePreparation1.0.0 PrepareTemplate** gerçek sonucunu paylaştı. **TemplateCreated=true, AdChanged=true**, schema3/RSA3072/SHA256/CNG/machine/code-signing-only/no-export/no-supplied-subject planı için iki yeni OID/template objesinin readback kontrolü başarılı.
- Şablon **AuthWireConnectorCodeSigning-4c23eebe**, machine enrollment **DC01 SID1000**; gMSA1648'e template enrollment/admin yetkisi verilmedi. Protected ACL ve kritik attribute karşılaştırması araçta tamamlandı. Mevcut template ve CA publication yapılandırması **SourceTemplatePreserved/CaConfigurationPreserved=true**.
- Protected receipt **C:\\ProgramData\\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37\\template-preparation.json**; yeni objectGUID'ler bu receipt içindedir. Kullanıcı çıktısında GUID'ler olmadığından dokümana tahminle eklenmedi.
- **TemplatePublished=false, CaChanged/GpoChanged/CertificatesChanged/KeyAclChanged/TrustStoreChanged/EnrollmentRequested=false**. **ServiceKeyAccessVerified/ConnectorInstalled/CanApplyGpo=false**; şablon hazırlığı uçtan uca otomasyon tamamlandı anlamına gelmez.
- Sonraki adım açık: yalnız bu owned template'i explicit **dc01.vizyonveri.local\\vizyonveri-DC01-CA** üzerinde **certutil -SetCATemplates +<name>** ile yayımlama. Receipt phase/templateGUID/OID/CA GUID/host guard'ları, mevcut template listesi korunması kontrolü; sertifika talep edilmez. Microsoft Learn certutil belgesi ekleme işaretini doğruluyor: https://learn.microsoft.com/windows-server/administration/windows-commands/certutil#setcatemplates
- Kanıt: checkpoints/2026-10-25-windows-connector-signing-template-created-live-result.json. Operatör komutu: checkpoints/2026-10-25-windows-connector-signing-template-publish.ps1. **Canlı publication sonucu henüz gelmedi.**
- AuthWire app dev.34, **54/94 (%57),40 açık**; A03/A04 açık. Formal rapor yeniden üretilmedi.

## 🔴✓ Makine imzalama şablonu canlı önizlemesi kabul edildi — 25 Ekim 2026

- Operatör **SigningTemplatePreparation1.0.0 Inspect** sonucunu paylaştı: DC01/vizyonveri.local/instance4c23eebe/serviceSID1648; **ReadyForPrepare=true**.
- 🔴✓ Doğrulanmış enrollment makinesi **DC01 SID1000**; önerilen protected ACL Domain Admins SID512/SYSTEM yönetim, Authenticated Users yalnız read, DC01 SID1000 yalnız explicit Enroll. gMSA SID1648'e template enrollment/admin izni önerilmiyor. Bu kayıt plan/metadata kabulüdür; henüz gerçek template/sertifika/key kullanım testi değildir.
- Önerilen yeni template **AuthWireConnectorCodeSigning-4c23eebe**, schema3/machine, RSA3072/SHA256/Microsoft Software Key Storage Provider/code-signing-only/no-export/no-supplied-subject. Forest-specific OID ve exact DN kontrolü gerçek çıktıda başarılı. CA **dc01.vizyonveri.local\\vizyonveri-DC01-CA**.
- **TemplateCreated/TemplatePublished/AdChanged/CaChanged/GpoChanged/CertificatesChanged/KeyAclChanged/TrustStoreChanged/EnrollmentRequested=false**. SourceTemplatePreserved/CaConfigurationPreserved=true; ReceiptPath=null. ServiceKeyAccessVerified/ConnectorInstalled/CanApplyGpo=false.
- Sonraki operatör adımı aynı doğrulanmış araçla **PrepareTemplate**: iki yeni template/OID nesnesi ve protected receipt, readback. İlk create sonrası hata olursa kör tekrar/auto-delete yapılmaz; receipt incelenir. CA publication/certificate request/key ACL/publisher trust ve gerçek service signing sonraki ayrı kapılardır.
- Kanıt: checkpoints/2026-10-25-windows-connector-signing-template-inspect-live-result.json. AuthWire app dev.34, **54/94 (%57),40 açık**; A03/A04 açık. Formal rapor yenilenmedi.

## 🔴✓ Ayrı makine imzalama şablonu hazırlık aracı hazır; canlı Inspect/oluşturma açık — 25 Ekim 2026

- Yeni `windows/connector/Initialize-AuthWireSigningTemplate.ps1` **1.0.0**, varsayılan **Inspect** ile yalnız envanter/plan okur. **PrepareTemplate** iki yeni owned AD objesi oluşturabilir: **AuthWireConnectorCodeSigning-4c23eebe** template ve forest OID kökü altında instance/host/service bağlı OID kaydı. Mevcut AuthWireGPOCodeSigning template'i ve CA publication listesi değiştirilmez.
- Plan: schema3/machine, **RSA3072/SHA256**, Microsoft Software Key Storage Provider, yalnız code-signing EKU/application-policy, non-exportable/no-archive/no-interactive/no-supplied-subject/no-autoenrollment. Subject DC01 DNS adına dayanır; validity365gün/overlap30gün. Template ilk oluşturulduğunda **yayımlanmaz**, sertifika talep edilmez.
- Protected DACL ile Domain Admins/SYSTEM yönetim, Authenticated Users yalnız okuma; yalnız doğrulanmış **DC01 computer SID** explicit Enroll. **aw-deploy$** template enrollment/admin izni almaz; owned machine key kullanım yetkisi ileride ayrıca verilip gerçek service signing probe ile doğrulanacak.
- Yeni LDAP nesneleri nTSecurityDescriptor dahil tek AddRequest ile, sabit DC/Kerberos/signing/sealing/no-referral bağlantısında oluşturulur. Korumalı receipt source/CA hash ve yeni objectGUID'leri tutar. İsim/OID çakışması veya yarım oluşturma otomatik benimsenmez/silinmez/yeniden denenmez; receipt ile yeniden inceleme gerekir.
- **31 native template kontrolü başarılı**; önceki Windows kontrolleri ve foundation/bounded-network kontrolleri başarılı. Native test sonucu ve kaynak SHA checkpoints/2026-10-25-windows-connector-signing-template-preparation.json içinde. Testler gerçek AD property/security tiplerini ve gerçek LDAP AddRequest yapısını kullanır; directory writes simulated. **Gerçek forest/CA oluşturma testi yapılmış değildir.**
- DC01 operatör adımı önce **Inspect**: aktarım SHA256 + mevcut kurumsal publisher ile imza kontrolü. Komut checkpoints/2026-10-25-windows-connector-signing-template-inspect.ps1. Gerçek ReadyForPrepare/templateOID/ACL çıktısı gelmeden template/CA/cert/trust/key-ACL başarı kabulü yapılmaz.
- Canlı AuthWire **dev.34**; bu adım app/runtime/RADIUS/policy/GPO/sertifika/uç paket değişikliği yapmadı. **54/94 (%57),40 açık** ve A03/A04 açık kalır; formal rapor yeniden üretilmedi.

## 🔴✓ Gerçek imzalama envanteri kabul edildi; ayrı makine imzalayıcısı hazırlığı açık — 25 Ekim 2026

- Operatör **Yapıştırılan metin(4).txt** ekinde **SigningReadiness1.0.1 Inspect**, DC01/vizyonveri.local/instance4c23eebe/SID1648 sonucunu paylaştı. **InspectionSucceeded=true**, null-template hatası çözüldü; **ShapeCompatibleTemplateCount=0** geçerli envanter sonucudur.
- 🔴✓ Mevcut publisher **6E74B513F766E01730719684A41B2664380CA68A**, CurrentUser/My, subjectAdministrator, issuer vizyonveri-DC01-CA, currently valid/code-signing-only/HasPrivateKeyMetadata=true. Native metadata **MachineKeySet=false, Cng=false, CSP Microsoft Enhanced Cryptographic Provider v1.0 / ProviderType1 / KeySpec2**: anahtar kullanıcı bağlamındadır. ServiceKeyAccessVerified/PrivateKeyUseTested=false; kullanım/taşıma/ACL değişikliği yapılmadı.
- **DC01'in** CurrentUser/TrustedPublisher ve LocalMachine/TrustedPublisher depolarında mevcut publisher görünmüyor; bu kontrol VV06 veya diğer uçların güven durumunu ölçmez. Marker'lı LocalMachine signer certificate listesi boş. Yeni hizmet publisher'ı için public güven dağıtımı halen açık.
- 🔴✓ AD'de enterprise CA kaydı **dc01.vizyonveri.local\\vizyonveri-DC01-CA** ve yayında **AuthWireGPOCodeSigning** template'i görüldü. Bu template schema2, CodeSigningOnly=true, non-exportable/no-archive/no-interactive/no-supplied-subject/min2048; ancak **MachineType=false**, legacy CSP listesi ve raw Enroll ACE'de Administrator SID500 var. Grup bazlı etkin enrollment hakları değerlendirilmedi.
- Yerleşik **CodeSigning** schema1 de user tipidir; bu CA'da yayımlanmamış. İki template de ShapeCompatible=false veAutomaticallyApproved=false. Mevcut template'ler makine tipi olarak değiştirilmez; mevcut paket/publisher korunur.
- **Sıradaki somut hazırlık:** ayrı önerilen **AuthWireConnectorCodeSigning** makine tipi, code-signing-only, non-exportable/CNG signer yolu; isim/sahiplik/issuer/enrollment kapsam guard'larıyla hazırlanmalı. Sonra yalnız owned machine key için hizmet kullanım izni ve gerçek gMSA signing probe, ardından yeni public publisher trust kontrolü. Bu kayıtta template/sertifika/key-ACL/trust oluşturulmadı; CA issuance backend seçimi ve gerçek isteği sonraki kapıdır.
- Tüm gerçek mutation bayrakları **AdChanged/GpoChanged/CertificatesChanged/KeyAclChanged/TrustStoreChanged/EnrollmentRequested=false**. ReadyForAutomatedSigning/ServiceKeyAccessVerified/ConnectorInstalled/CanApplyGpo=false beklenen açık kapılardır.
- Kanıt: checkpoints/2026-10-25-windows-connector-signing-readonly-live-result.json (operator attachment normalized; kaynak ek değiştirilmedi). Ürün dev.34, **54/94 (%57),40 açık** sayımı korunur; formal rapor yeniden üretilmedi.

## 🔴✓ İmzalama readiness null-template hatası düzeltildi; gerçek tekrar bekleniyor — 25 Ekim 2026

- Operatör **SigningReadiness1.0.0** sonunda Where-Object ShapeCompatible için **InputObjectIsNull** bildirdi. Sorgu readonly'dir; AD/GPO/cert/key-ACL/trust değişikliği yapılmadı. Çıktı tamamlanmadığından CA/template/key-scope envanteri kabul edilmez.
- Kaynak neden: kod imzalama dışındaki şablonların analiz fonksiyonu **return $null** ile null pipeline kaydı üretmiş; ilk fixture yalnız code-signing template içeriyordu. **1.0.1** ilgisiz şablonda hiç kayıt üretmez, null discovery/shape kayıtlarını açıkça filtreler ve compatible sayımını null-safe yapar.
- **Boş CodeSigningTemplates=[] ve count0 geçerli envanterdir**, hazırlık/onay değildir. Malformed ilgili signing metadata guard'ı korunur; hiçbir sertifika isteği veya anahtar/CA/template/GPO/trust mutation eklenmedi.
- 🔴✓ PR78 source **a7d3ef57bc5448eddb0ea3317952e7593b64b53e**, merge **f3122f6406d5c4a9989ce51f049d57f5102e6720**. Native Windows5.1 **50 signing-readiness kontrolü** geçti: mixed, all-unrelated, empty, all-null discovery, JSON'da gerçek/null'sız array, malformed ilgili şablonu reddetme; önceki native CNG/CSP metadata ve readonly entry korumaları. AD/CA fixture'dır; gerçek müşteri inventory sonucu değildir. Önceki147/16/39/108/35/66, foundation724/28skip ve bounded retry probe başarılı.
- Teslim /home/segmentiq/authwire-signing-readiness-v1-r2-20261025.ps1; SHA256 **6558d8fd4f4280ea5932b4b5d6a8f86131054a19e2792a5dffe72c463bed5b5a**, yerel/uzak eşleşti. **ToolVersion1.0.1 Inspect gerçek çıktı bekleniyor.** Service signing key, template/issuer seçimi, actual gMSA signing, publisher public trust ve connector/dağıtım kapıları açık kalır.
- Kanıt/komut: checkpoints/2026-10-25-windows-connector-signing-null-fix-ci.json, checkpoints/2026-10-25-windows-connector-signing-inspect-r2.ps1. Ürün dev.34;54/94 (%57),40 açık değişmedi. Tam yedek/ürün servis restart/Windows endpoint veya package değişikliği yok.

## 🔴✓ Hizmet imzalama altyapısı için salt okunur kontrol aracı hazır — 25 Ekim 2026

- **Get-AuthWireSigningReadiness.ps1 1.0.0**, yalnız Inspect modu ile hazırlandı. Aynı imzalı bootstrap/host/domain/kurulum/SID doğrulanır. Mevcut kurumsal publisher ve marker'lı LocalMachine adayları, native **CertGetCertificateContextProperty** provider metadata'sı ile okunur: CNG/CSP, machine/user keyset, provider ve container identifier SHA256. Private key acquisition/use/export API'si yoktur; HasPrivateKey metadata'sı hizmet erişimi sayılmaz.
- Forest configuration partition'dan enterprise enrollment-service CA'ları, yayımlanan template listeleri ve kod imzalama template EKU/application policy/machine/export/archive/UI/subject/min-key flag'leri ile raw enrollment ACE'leri okunur. ShapeCompatible yalnız biçim adayıdır; **TemplateSelected/AutomaticallyApproved/EffectiveEnrollmentRightsEvaluated/ServiceKeyAccessVerified=false**. Sertifika talebi veya otomatik seçim yapılmaz.
- Tasarım yönü: **AuthWire'a özel, non-exportable makine anahtarı ve yalnız code-signing purpose**; mevcut Administrator CurrentUser publisher/anahtarı ve imzalı paketler korunur. Yeni publisher'ın yalnız public güven dağıtımı, endpoint paket değişiminden önce ayrıca hazırlanmalıdır; mevcut protected trust GPO admin yönetiminde kalır. Hizmet anahtar ACL'si bu adımda açılmaz.
- AD CS bu incelemeyle ürün kurulum önkoşulu ilan edilmez. Mevcut kurumsal CA bu ortam için bir issuance seçeneğidir; nihai onaylı şablon/issuer yolu gerçek sonuçtan sonra belirlenecek. Müşteri ortamına CA/template kurma/değiştirme, key taşıma, PFX çıkarma veya trust/GPO mutation yapılmadı.
- 🔴✓ PR77 source **38526181e7414eb280bb30247df4c6057447df79**, merge **313aa3d09143b94be28c352e4228ad4d1f96f153**. Native Windows5.1 **36 yeni kontrol**: gerçek disposable user/machine CNG ve legacy CSP provider metadata; public-only cert; genuine AD collection/ACL, bitfield/mixed-purpose/scope guard'ları ve tam readonly entry akışı (AD/CA mocked). Önceki147/16/39/108/35/66 kontrolleri, foundation724/28skip ve bounded retry probe başarılı. CNG tespiti resmi CRYPT_KEY_PROV_INFO kuralıyla ProviderType==0'dan yapılır; KeySpec legacy hint olarak raporlanır.
- Teslim: /home/segmentiq/authwire-signing-readiness-v1-20261025.ps1; SHA256 **00d2399c2c527bf176384f43917be4b7226624204ab2c82bdbaf73ea0a1f782d**, yerel/uzak hash aynı. **DC01 gerçek Inspect sonucu bekleniyor**; signing sertifikası hazırlanmış veya hizmetle imza atılmış sayılmaz. Yeni tam yedek, canlı AuthWire servis restart veya Windows endpoint/package değişikliği yok.
- Kanıt/komut: checkpoints/2026-10-25-windows-connector-signing-readiness-ci.json, checkpoints/2026-10-25-windows-connector-signing-inspect.ps1. Service signer hazırlığı/actual sign/issuer-public-trust, connector kurulumu/güvenli iletişimi ve GPO/uç/kalıcılık kabulü açık; ürün dev.34,54/94 (%57),40 açık değişmedi.

## 🔴✓ Gerçek gMSA AD/SYSVOL yazma, okuma, temizlik ve koruma testi tamamlandı — 25 Ekim 2026

- Operatör DC01/vizyonveri.local üzerinde **GPO write probe1.0.1** sonucunu paylaştı. **ProbeVerified=true, ServiceWriteAccessVerified=true, TargetStatePreserved=true, ProtectedTrustPreserved=true**; Error/NativeErrorCode/OperationError=null, CleanupErrors/OperationCleanupErrors=[].
- 🔴✓ Gerçek runtime hesabı **VIZYONVERI\\aw-deploy$ / SID1648**, SCM PID**9656**; hizmet **AuthWireLogonProbe-9be0d534201b41a1911e7fd36fa6585d**. Hedef yalnız **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3 / AuthWire-Managed-Deployment-4c23eebe**. **AdWriteReadVerified/AdProbeRemoved/SysvolWriteReadVerified/SysvolProbeRemoved=true**.
- 🔴✓ Geçici hizmet, EXE ve sonuç klasörü kaldırıldı. **BusinessStateIdentical=true, ChangedComponents=[]**: bu yeni denemenin baseline'ına göre hedef comment/ayar/version/link/delegasyon/dosya içeriği/dosya-dizin-root ACL karşılaştırmaları aynı. **ChangedRootMetadata=[ReadTime,ModifiedTime], MetadataOnlyDifference=true**: beklenen tarih farkları ayrı kanıtlandı. Önceki1.0.0 denemenin bellek içi baseline'ı geçmişe dönük yeniden oluşturulmuş sayılmaz; tam kabul yeni1.0.1 denemesine dayanır.
- **AdChanged/GpoChanged=true** yalnız geçici test yazımlarını belirtir; değerler/dosya temizlenmiştir. LogonRightsChanged/SecretsExported=false. GPO link veya istemci dağıtımı yapılmamıştır; önceki verified_unlinked hazırlık geçerlidir.
- Yerel kanıtlar: **C:\ProgramData\AuthWire-GpoWriteProbe-e9218814a6f848c797c04e70822a37c3\summary.json** ve **gpo-comparison.json**; korumalı gpo-before.json baseline'ı aynı evidence klasöründe test öncesi yazıldı. Operatör JSON kanıtı: checkpoints/2026-10-25-windows-connector-gpo-write-live-accepted.json.
- **GpoPersistenceVerified/ConnectorInstalled/CanApplyGpo=false** halen beklenen açık kapılardır. Sıradaki iş, servis hesabının dağıtım betiklerini imzalayabilmesi için imzalama hazırlığı/uygun anahtar erişiminin doğrulanması; sonra connector kurulumu/güvenli panel iletişimi ve kontrollü GPO dağıtımı/kalıcılık/uç kabulüdür. Bu sonuç service signing-key erişimini veya merkezi otomasyonun tamamını kanıtlamaz.
- Tamamlanan bir alt kabul kapısıdır; A03/A04 üst maddeleri açık kalır. Ürün dev.34 ve **54/94 (%57),40 açık** sayımı korunur. Formal rapor yeniden üretilmedi; çalışma kaydı güncellendi.

## 🔴✓ GPO write-probe tarih karşılaştırması düzeltildi; bileşen kanıtı hazır — 25 Ekim 2026

- **Test-AuthWireGpoWrite1.0.1**: GPMC XML'de doğru root alanı **ModifiedTime** kullanıldı. Yalnız doğrudan root ReadTime/ModifiedTime karşılaştırma dışında tutulur; RawReport ve tarihler ayrıca kaydedilir. CreationTime ve nested ModifiedTime dahil ayar/version/link/delegation/owner farkları korunur.
- Before/after bileşenler artık ayrı kanıttır: GPO GUID/comment, normalized rapor, sıralı izinler, SYSVOL root ACL, her dosya/dizin ACL ve dosya byte hash'i. **gpo-before.json hizmet oluşturulmadan önce** admin/SYSTEM-only yazılır; **gpo-comparison.json** raw before/after ve ChangedComponents/ChangedRootMetadata içerir. Kanıt yazılamazsa kabul başarısızdır.
- 🔴✓ PR76 source **756c3d5ddeee3ec93d976b1d176f5168bc00dc06**, merge **ef7a1c02b8af35deb0cc77958e9bd8eaab314a1c**. Native Windows5.1 **66 write-probe kontrolü** geçti: gerçek XML timestamp adları, metadata-only eşitlik, nested/creation/enabled/version/link/comment/permission/file/file-ACL/root-ACL/yeni dosya farklarını reddetme, servis öncesi baseline kaydı ve iki gerçek fixture SCM helper çalışması. Önceki bootstrap147/LSA16/right39/GPO108/SCM35, foundation724/28skip ve bounded retry probe de başarılı.
- İlk gerçek çalışmanın AD/SYSVOL yazma/okuma ve own-cleanup alt kanıtı korunur; **ilk hedefin bütün eski durumunun korunduğu geçmişe dönük ilan edilmez**, çünkü1.0.0 yalnız bellek içi hash tuttu. İlk farkın yalnız tarihten ibaret olduğu kesinlenmemiştir. **Düzeltilmiş sürümle yeni baseline üzerinden kontrollü tekrar beklenir.**
- Teslim /home/segmentiq/authwire-gpo-write-probe-v1-r2-20261025.ps1, SHA256 **9f2b599b97b9a137905f45effb1223d76043c67380da32f1d6a735755e653d2d**; yerel/uzak hash eşleşti. Kaynak/araç Linux'ta hazırlandı; müşteri GPO'su bu düzeltme sırasında değiştirilmedi, test tekrar çalıştırılmadı, AuthWire servisi/CA/policy/Windows paketi değiştirilmedi. Yeni tam yedek yok.
- Kanıt/komut: checkpoints/2026-10-25-windows-connector-gpo-postcheck-fix-ci.json, checkpoints/2026-10-25-windows-connector-gpo-write-probe-r2-run.ps1. **ServiceWriteAccessVerified/TargetStatePreserved/ProbeVerified canlı tekrar sonucu bekleniyor.** Ürün dev.34,54/94 (%57),40 açık korunur.
- Kaynak: https://devblogs.microsoft.com/scripting/use-powershell-to-generate-and-parse-a-group-policy-object-report/ (Microsoft root ModifiedTime/ReadTime örneği).

## Gerçek yazma/okuma ve temizlik doğrulandı; hedef postcheck incelemede — 25 Ekim 2026

- Operatör **GPO write probe1.0.0** sonucunu paylaştı: gerçek **VIZYONVERI\\aw-deploy$ / SID1648**, SCM PID1388, Stage=runtime_write_verified. **AdWriteReadVerified/AdProbeRemoved/SysvolWriteReadVerified/SysvolProbeRemoved=true**; OperationError=null, OperationCleanupErrors=[].
- 🔴✓ Geçici hizmet73580e757e9d40ddbc87088b1629318e, EXE ve result directory kaldırılmış; ProtectedTrustPreserved=true. Bu alt kanıt gerçek hizmet hesabı AD/SYSVOL yazma, okuma ve test verisi temizliğini doğrular.
- **ProbeVerified=false, ServiceWriteAccessVerified=false, TargetStatePreserved=false**, CleanupErrors=[GPO_POSTCHECK_REQUIRES_REVIEW]. Tam kabul veya hedefin bütün eski durumunun korunduğu ilan edilmez. Kaynak/yerel GPO ayarı geri alınmadı ve izin guard'ı atlanmadı.
- İncelemede somut normalizasyon hatası bulundu: Get-GPOReport XML kökü **ModifiedTime** taşır;1.0.0 karşılaştırması yanlış **ModificationTime** adını dışarıda tutmuştu. Microsoft resmi XML örneği bunu doğrular. Bu beklenen tarih farkı sonucu açıklayabilir; eski çalışmada bileşen baseline'ı kalıcı yazılmadığı için ilk farkın kesin alanları geçmişe dönük kanıtlanamaz.
- **1.0.1** düzeltmesi PR76'da hazırlanıyor: yalnız root ReadTime/ModifiedTime normalizasyonu; before/after raw rapor ve ayrı bileşenler, dosya/dizin ACL ve içerik karşılaştırmaları; servis oluşturmadan önce baseline kaydı. CreationTime/nested ayar/versiyon/link/izin farkları korunur. Native testlerden sonra kontrollü tekrar gerekir.
- Kanıt: checkpoints/2026-10-25-windows-connector-gpo-write-live-postcheck-review.json. Mevcut yerel özet: C:\ProgramData\AuthWire-GpoWriteProbe-9ff03235ed39411ab210616a5d43cd19\summary.json. Ürün dev.34;54/94 (%57),40 açık değişmedi.

## 🔴✓ Gerçek hizmet hesabı GPO yazma/okuma test aracı hazır — 25 Ekim 2026

- **Test-AuthWireGpoWrite.ps1 1.0.0**, varsayılan Inspect. Dört mevcut kurumsal imzalı yardımcı, hesap/hizmet hakkı ve **verified_unlinked** receipt ile aynı **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** boş/bağlantısız GPO doğrulanır. RunProbe yalnız bu GPO'da geçici test yapar; GPO link/ayar/izin, hesap hakkı, grup veya imzalama anahtarı ACL'si değiştirmez.
- Kısa ömürlü imzalı SCM hizmeti **aw-deploy$** olarak NULL managed password ile çalışır. Hizmet, sabit DC/GPC üzerinde Kerberos LDAP signing/sealing kullanır; boş LDAP description alanına nonce-bound tek değer ekler/okur ve yalnız o değeri siler. GPMC Description/ownership marker değiştirilmez. GPC modification timestamp ilerleyebilir; ayar/version/permission korunur. Eşzamanlı yabancı değerler silinmez ve preservation başarısız sayılır.
- SYSVOL testi sabit DC UNC yolunda CreateNew + DeleteOnClose ile yalnız benzersiz dosya oluşturur/yazar/flush/okur; mevcut dosyaya yazmaz. Actual service SID/SCM PID/host/nonce ve typed operation proof, test temizliği, hedef business/file/ACL fingerprint ve korunan trust fingerprint birlikte doğrulanmadan **ServiceWriteAccessVerified=true** verilmez.
- Hizmet, EXE, config ve geçici sonuç klasörü temizlenir; admin/SYSTEM korumalı manifest/proof/summary kalır. Bilinmeyen LDAP sonucu açık gösterilir; manifest kesin nonce/GPO/DC/own-value/own-file bağlarını taşır. Yönetici adına arbitrary değer/dosya silme veya otomatik onarım yoktur. Signing-key service access, connector kurulum, GPO kalıcılık ve uç kabulü bu testin kapsamı değildir.
- 🔴✓ PR75 finalsource **f83b25925d7c20571ecdc47e34deb06b35b1f3e9**, merge **baac2ed3f9781288e1f6723090d88c4b3c816b3c**. Native Windows PowerShell5.1: **yeni write-probe51 kontrol**, gerçek local file I/O ve iki signed SCM helper çalışması (başarı/temizlik başarısızlığı) geçti. AD adapter ve UNC testte simüle/localdir olarak derlendi; üretimde fixture switch yoktur. Müşteri AD/SMB/gMSA yazma kabulü değildir. Önceki bootstrap147/LSA16/right39/GPO108/SCM35 kontrolleri, foundation724/28skip ve bounded retry probe geçti.
- Doğrulanmış teslim: /home/segmentiq/authwire-gpo-write-probe-v1-20261025.ps1, SHA256 **665032a52539a939bdceebe96249d050f5dc866a0c8efb295a2b2afd42deb2fe**; yerel ve uzak dosya hash'leri eşleşti. DC01 RunProbe komutu hash kontrolü ve mevcut publisher ile imza içerir. **Gerçek müşteri sonucu henüz bekleniyor**; komut teslimi kabul sayılmaz.
- Ürün dev.34;54/94 (%57),40 açık sayımı korunur. Yeni tam yedek veya ürün servisi restart yapılmadı. Kanıt/komut: checkpoints/2026-10-25-windows-connector-gpo-write-probe-ci.json, checkpoints/2026-10-25-windows-connector-gpo-write-probe-run.ps1.

## 🔴✓ Ayrı dağıtım GPO'sunun gerçek izin hazırlığı tamamlandı — 25 Ekim 2026

- Operatör DC01/vizyonveri.local üzerinde **Initialize-AuthWireDeploymentGpo1.0.1 ResumeGpo** sonucunu paylaştı. **GpoResumed=true, GpoCreated=false, MetadataComplete=true, Blockers=[]**. Aynı **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3** GPO'su kullanıldı; ikinci nesne oluşturulmadı.
- 🔴✓ AuthWire-Pilot-Computers/SID1647=**GpoApply**, VIZYONVERI\\aw-deploy$/SID1648=**GpoEdit**, Authenticated Users=**GpoRead**. Domain Admins512/Enterprise Admins519/SYSTEM18 idari rolleri; Enterprise Domain Controllers9 read korundu. OwnerDomainAdmins512; hizmete GPO güvenliğini değiştirme/silme rolü verilmedi.
- 🔴✓ SYSVOL metadata'sında hizmet yazma izni var (**SysvolServiceWriteMetadata=true**); hizmet ChangePermissions/TakeOwnership metadata'sı ve deny yok. **ProtectedTrustPreserved=true**: mevcut AuthWire-Pilot-Trust fingerprint'i korunmuş. Bu gerçek müşteri GPO delegasyon/readback kabulüdür.
- **Linked=false, ContainsSettings=false, GpoLinked=false, SettingsApplied=false**: dağıtım GPO'su hâlâ boş/bağlantısızdır, uçlara ayar dağıtılmamıştır. AdChanged/GpoChanged=true yalnız bu yeni yönetilen GPO'da beklenen izin hazırlığını ifade eder.
- **ServiceWriteAccessVerified/SigningKeyAccessVerified/ConnectorInstalled/CanApplyGpo=false** beklenen açık kapılardır; ACL metadata'sı gerçek hizmet hesabı AD/SYSVOL yazma testi yerine geçmez. Sonraki adım yalnız bu boş GPO'ya sınırlandırılmış, geçici test verisini temizleyen gerçek hizmet hesabı yazma/okuma kabulüdür; imzalama anahtarı erişimi ve connector kurulumu sonra gelir.
- Receipt: C:\ProgramData\AuthWire-GpoPreparation-6394ceadf50a4dc29f13787be5822806\gpo-preparation.json. Kanıt: checkpoints/2026-10-25-windows-connector-deployment-gpo-live-prepared.json. Formal rapor yeniden üretilmedi; ürün dev.34 ve **54/94 (%57),40 açık** sayımı korunur; A03/A04 merkezi dağıtım üst maddeleri henüz bitmedi.

## 🔴✓ GPO sahiplik okuma hatası düzeltildi; aynı GPO için kontrollü devam hazır — 25 Ekim 2026

- Gerçek salt okunur sonuç: GPO **8c6808fd-a382-4bf2-9c9c-d9e1d46082a3**, AuthWire-Managed-Deployment-4c23eebe, owner VIZYONVERI\\Domain Admins, ObjectClass=groupPolicyContainer; receipt evresi created_unlinked. **GPMC GpoDescription beklenen marker ile birebir aynı, LDAP AdDescription boş.** Önceki betiğin LDAP description ile GPO yorumunu eşitlemesi hatalıydı. Oluşmuş GPO silinmedi/yeniden oluşturulmadı; bu sorgu GPO değiştirmedi.
- 🔴✓ Initialize-AuthWireDeploymentGpo **1.0.1**, fresh GUID-bound Get-GPO.Description kullanır. GPC türü, owner, SYSVOL yolu, boş/bağlantısız durum ve trust fingerprint kontrolleri korunur. Varsayılan Inspect/PrepareGpo yarım nesneyi otomatik sahiplenmez.
- 🔴✓ Açık ResumeGpo modu, hem orijinal admin/SYSTEM korumalı receipt yolu hem bağımsız beklenen GUID ister. Kurulum/host/marker/scope/protected baseline eşleşmesi ve initial default delegation şarttır; reparse, başka yazabilen trustee, farklı marker/owner/link/settings veya ara izin evresi reddedilir. Aynı GUID üzerinde yalnız Authenticated Users read, pilot apply, gMSA GpoEdit tamamlanır. Yeni GPO oluşturma/silme/link/settings API'si recovery'de kullanılmaz. Verified matching repeat no-op.
- 🔴✓ PR74 kaynak3122ddc849d331b7954247cbbf40b977a3e12df8, mergeecf91fd9534e66149fc8416c294baf200525d193. Windows PowerShell5.1: **GPO108**, bootstrap147, LSAread16, additive-right39, native SCM35 (iki LocalService probe) kontrolleri geçti. AD/GPMC çağrıları fixture'dır; gerçek müşteri GPO recovery kabulü değildir. Foundation724 test/28skip, bounded retry probe başarılı.
- İndirme dosyası Linux /home/segmentiq/authwire-deployment-gpo-bootstrap-v1-r2-20261025.ps1; SHA256 **25794286c163f4fecf83ae8736b80cdbb25ba5c6d1bd5eefa236a7859c5b67d5**,26878byte; test edilmiş kaynak ile eşleşme yerel/uzak hash ile doğrulandı. DC01 komutu hash kontrolü, mevcut kurumsal publisher ile imza ve ResumeGpo içerir. Komut teslimi gerçek izin yazımı veya başarı değildir; operatör çıktısı beklenir.
- Ürün dev.34, **54/94 (%57)** korunur. Gerçek GPO recovery/delegasyon, gMSA ile AD/SYSVOL yazma, servis imzalama anahtarı erişimi, connector kurulumu/protokolü, GPO link/kalıcılık ve uç testleri açık. Bu adımda AuthWire ürün servisi/Windows paketi değiştirilmedi, yeni tam yedek alınmadı.
- Kanıt/teslim: checkpoints/2026-10-25-windows-connector-gpo-description-live-result.json, checkpoints/2026-10-25-windows-connector-gpo-recovery-ci.json, checkpoints/2026-10-25-windows-connector-gpo-resume.ps1.

## Ayrı dağıtım GPO hazırlığı sahiplik readback kontrolünde durdu — 25 Ekim 2026

- Operatör PrepareGpo çalıştırmasında GPO_OWNERSHIP_MARKER_MISMATCH bildirdi. Receipt: C:\ProgramData\AuthWire-GpoPreparation-6394ceadf50a4dc29f13787be5822806\gpo-preparation.json. Yeni boş GPO oluşmuş olabilir; gerçek GUID/evre/delegasyon durumu henüz okunmadı. Bu deneme için AD/GPO değişmedi veya hazırlık tamamlandı denmez.
- Aynı guard hem groupPolicyContainer nesne türünü hem LDAP description sayısını/metnini kontrol eder; yalnız hata metni kesin neden sağlamaz. New-GPO -Comment için GPMC Description ile LDAP description eşitliği canlı kanıtla karşılaştırılacak; varsayım doğrulanmadan guard gevşetilmez.
- Yeniden PrepareGpo, sil-yeniden oluştur veya otomatik sahiplenme yapılmaz. Receipt GUID'sine sabitlenmiş salt okunur metadata/izin sorgusu hazırlanmıştır. GPO adı ve korunan trust GUID'si denetlenir; ayar/izin/üyelik/anahtar değişikliği yoktur. Sonuç operatörden beklenir.
- Önceden doğrulanan KDS, yerel gMSA, eklemeli hizmet hakkı ve gerçek SCM logon kabulü korunur. Yeni GPO oluşturma/doğrulama/delegasyon açık; uygulama dev.34 ve54/94 (%57) değişmedi.
- Kanıt: checkpoints/2026-10-25-windows-connector-gpo-marker-failure.json; salt okunur komut: checkpoints/2026-10-25-windows-connector-gpo-marker-readonly.ps1.

## 🔴✓ Ayrı dağıtım GPO'sunun gerçek önizlemesi kabul edildi — 25 Ekim 2026

- Operatör DC01/vizyonveri.local üzerinde Initialize-AuthWireDeploymentGpo1.0.0 **Inspect** sonucunu paylaştı: **Blockers=[], ReadyForPrepare=true, ProtectedTrustPreserved=true, GpoExists/GpoCreated=false**. Yeni AuthWire-Managed-Deployment-4c23eebe adı için çakışma yok; AD/GPO değiştirilmedi.
- 🔴✓ Gerçek Win32 SID çözümlemesinde VIZYONVERI\\aw-deploy$ / SID1648 **ServiceTargetType=User** olarak geldi; GPMC rolü native sonuçtan seçildi. Aynı-domain AuthWire-Pilot-Computers güvenlik grubu/SID1647 doğrulandı. Sahiplik marker'ı kurulum4c23eebe-0715-46d1-88ee-a2e96ad7ee46, host0fa4143f-aae3-4bc3-9cd3-db8a1de24acd ve iki SID'ye bağlıdır.
- ScopeGroupApplyOnly=true bu önizlemede **planlanan kapsamı** gösterir; GPO henüz yoktur ve uygulama izni atanmış sayılmaz. GpoLinked/SettingsApplied/ServiceWriteAccessVerified/SigningKeyAccessVerified/ConnectorInstalled/CanApplyGpo=false.
- Sonraki teslim aynı doğrulanmış imzalı dosyada **PrepareGpo**: tekrar preflight sonrası yalnız yeni boş/bağlantısız GPO oluşturulur; yeni nesnede Authenticated Users read, pilot grup apply, hizmet GpoEdit olarak sınırlanır. Trust GPO delegasyonu/ayarları ve mevcut GPO'lar korunur. Komut teslimi gerçek oluşturma sonucu değildir; New-GPO/Set-GPPermission çıktısı beklenir.
- Kullanılacak kaynak önceki PR73/test edilmiş sürümle aynı; yeni ürün kodu, Windows paketi, servis veya müşteri GPO değişikliği yapılmadı. Yeni tam yedek alınmadı. Gerçek oluşturma/delegasyon/readback, hizmetle gerçek AD/SYSVOL yazması, imzalama, GPO bağlama/kalıcılık ve merkezi dağıtım/uç kabulü açık kalır. AuthWiredev.34 ve54/94 (%57) korunur.
- Kanıt: checkpoints/2026-10-25-windows-connector-deployment-gpo-live-inspect.json; sonraki komut: checkpoints/2026-10-25-windows-connector-deployment-gpo-prepare.ps1.

## 🔴✓ Pilot GPO/SYSVOL kapsam incelemesi tamamlandı; ayrı dağıtım GPO hazırlığı hazır — 25 Ekim 2026

- Operatörün Yapıştırılan metin(3).txt çıktısı okundu/kaydedildi. AuthWire-Pilot-Trust / e5a9ab39-3709-49cb-837a-0208d2eb3b12, owner VIZYONVERI\\Domain Admins, AllSettingsEnabled; ComputerSections=Scripts/Public Key/Registry, UserSections=[], domain köküne bağlı. Pilot grupta GpoApply, Authenticated Users/Enterprise DC'lerde GpoRead; mevcut admin/SYSTEM yetkileri korunur.
- SYSVOL root ve Machine/Scripts/Startup mevcut. Root inheritance protected, Startup inherited; Authenticated Users ve pilot SID1647 read/execute; admin/SYSTEM full-control ve standart CREATOR OWNER inherit-only kayıtları bulunur. aw-deploy$ SID1648 için doğrudan GPO veya SYSVOL edit kaydı yoktur. Bu, gruplar üzerinden etkin erişimin tam testi değildir. AD/GPO/izinler incelemede değişmedi.
- **Karar:** trust anchor/Public Key ayarlarını içeren mevcut GPO'ya hizmet edit yetkisi verilmez. Ayrı, başlangıçta boş ve bağlantısız **AuthWire-Managed-Deployment-4c23eebe** hazırlanır. Hizmete yalnız yeni GPO için GpoEdit, seçili pilot gruba GpoApply, Authenticated Users'a read; mevcut güven GPO'su admin yönetiminde korunur.
- 🔴✓ Initialize-AuthWireDeploymentGpo.ps11.0.0, varsayılan Inspect ile hazırlandı. İmzalı bootstrap1.0.3, domain/host/kurulum/SID, aynı-domain security scope group ve native SID_NAME_USE türü doğrulanır. PrepareGpo yalnız yeni boş/bağlantısız GPO oluşturur, kurulum/host/service/scope marker'ı ve admin owner şartını kullanır, üç hedefli delegasyon uygular. GPO link/settings, grup üyeliği, servis veya imzalama anahtarı ACL'si değiştirilmez.
- İsim çakışması, yabancı marker/owner, mevcut link/ayar, belirsiz/yarım kurulum otomatik sahiplenme/onarım veya sil-yeniden oluşturma yapmaz. Eksiksiz eşleşen tekrar no-op. Korunan trust GPO'nun ReadTime hariç report/delegation/root-ACL fingerprint'i karşılaştırılır; oluşturma/delegasyon evreleri korunan küçük receipt'e yazılır. SYSVOL yazma metadata'sı gerçek gMSA AD/SMB yazma/okuma testi yerine geçmez.
- 🔴✓ PR#73 kaynak5f85b4bac5cdbfda7b2d42ea00c940475f04fad4, mergee3282c18bc303595ef1bd708db43576de34badb2. Windows PowerShell5.1'de native SID lookup ve AD/GPMC simülasyonlu tam hazırlık yolu için **39 kontrol** geçti; user/computer trustee türü, read-only preview, tek create/üç sınırlı permission, idempotence, marker/owner/scope/link/settings drift'i, yarış ve kısmi hata kapsandı. Gerçek müşteri GPO'su oluşturulmuş veya hizmet yazması doğrulanmış sayılmaz.
- CI tümü başarılı: Windows40176218389/bootstrapjob121117354683 (147+16+39+GPO39), SCMjob121117354845 (35), foundation40176218431/job121117354787 (724test/28skip), bounded retry40176218395.
- Public dosya /home/segmentiq/authwire-deployment-gpo-bootstrap-v1-20261025.ps1; SHA256=48170996a41fef8bb50dc656d56e46b500541b46ad1184d1659252d2de0f827e, uzak kopya özeti doğrulandı. Şimdiki operatör teslimi **yalnız Inspect**: önizleme/kimlik/scope doğrulaması; New-GPO/Set-GPPermission henüz DC01'de çalıştırılmadı. ProtectedTrustPreserved/Blockers/ReadyForPrepare sonucu beklenir.
- Açık: gerçek önizleme, ardından yeni GPO oluşturma/delegasyon metadata kabulü; hizmet kimliğiyle gerçek AD/SYSVOL erişimi; kod imzalama anahtarı hizmet erişimi; GPO bağlama/kalıcılık, connector/merkezi dağıtım ve uç/geri alma/ölçek kabulü. AuthWiredev.34 ve54/94 (%57) değişmedi; tam yedek oluşturulmadı.
- Kanıt: checkpoints/2026-10-25-windows-connector-gpo-scope-live-result.json; teslim: checkpoints/2026-10-25-windows-connector-deployment-gpo-delivery.json ve checkpoints/2026-10-25-windows-connector-deployment-gpo-inspect.ps1.

## 🔴✓ Gerçek DC01 gMSA hizmet oturumu ve temizlik kabulü tamamlandı — 25 Ekim 2026

- Operatör WINDOWS_CONNECTOR_SERVICE_LOGON_PROBE1.0.0 sonucunu paylaştı: **ServiceLogonVerified=true, ProbeVerified=true**, hesap VIZYONVERI\\aw-deploy$, ExpectedSid/RuntimeSid aynı S-1-5-21-34256453-3348971241-2809240126-1648, runtime processID5708. İmzalı gerçek SCM hizmeti bu domain hesabıyla çalıştı; bu artık yalnız Test-ADServiceAccount veya CI LocalService kanıtı değildir.
- 🔴✓ Geçici AuthWireLogonProbe-e214ab3a31c443dcac1f7394ce567041 hizmeti oluşturuldu ve **TemporaryServiceRemoved/TemporaryBinaryRemoved/TemporaryResultDirectoryRemoved=true**. Stage=runtime_verified, Error/NativeErrorCode=null, CleanupErrors=[]. İşlem kanıtı C:\\ProgramData\\AuthWire-ServiceProbe-055f7344ae51483ab65dad11b5d2da1a\\summary.json olarak bildirildi.
- KDS/hesap sahipliği/readback, yerel kullanım, yalnız hedef SID'ye hizmet oturumu hakkı ve gerçek hizmet oturumu alt adımları tamamlandı. Test AD/GPO/hakları değiştirmedi, sır dışa aktarmadı. **GpoPersistenceVerified/ConnectorInstalled/CanApplyGpo=false**: bu başarı GPO edit/link/SYSVOL, hizmet kimliğiyle kod imzalama veya merkezi dağıtımın tamamlandığı anlamına gelmez.
- Sonraki salt okunur komut, mevcut AuthWire-Pilot-Trust GPO'sunun GUID'sini ve adını sabitler; Get-GPOReport'tan yalnız bölüm adları/bağlı yollar, GPO delegasyonu ve seçili SYSVOL root/startup klasörlerinin SID tabanlı ACL'lerini okur. Tam GPO XML'i veya script/konfigürasyon içerikleri dışa verilmez; politika/yetki değiştirilmez. Mevcut trust GPO'suna otomatik edit hakkı verilmez veya mevcut müşteri GPO'su sahiplenilmez; yönetilecek dağıtım kapsamı/ayrı AuthWire GPO ihtiyacı bu envanterle netleştirilir.
- Açık kapılar: GPO/SYSVOL için sınırlı sahiplik/delegasyon, kurumsal anahtarın hizmet erişimi, yönetim bağlantısı/connector kurulumu, GPO kalıcılığı/uygulaması, gerçek uç ve geri alma/ölçek kabulü. AuthWiredev.34 ve54/94 (%57) hesabı korunur; ana A04 tamamlanmış sayılmaz.
- Kanıt: checkpoints/2026-10-25-windows-connector-service-logon-live-result.json. Sonraki komut: checkpoints/2026-10-25-windows-connector-gpo-scope-readonly.ps1. Bu kayıt sırasında yeni canlı servis, kaynak veya GPO değişikliği yapılmadı.

## 🔴✓ DC01 hedefli hizmet oturumu hakkı eklendi; gerçek hizmet testi teslim edildi — 25 Ekim 2026

- Operatör PrepareServiceRight1.0.0 sonucunu paylaştı: aw-deploy$ / SID S-1-5-21-34256453-3348971241-2809240126-1648 için **AddedNow=true, DirectServiceRightAssigned=true, ExistingAssignmentsPreserved=true**. Üç eski allow kaydı korunarak yalnız hedef SID eklendi; deny listesi boş. LocalPolicyChanged=true, AD/GPO değişmedi. İşlem kaydı: C:\ProgramData\AuthWire-ServiceRight-802cad0a04f444aba5c8db948d5b7e92\service-right.json.
- 🔴✓ Yerel SeServiceLogonRight ekleme/readback kapısı gerçek DC01'de tamamlandı. **ServiceLogonVerified/GpoPersistenceVerified/ConnectorInstalled/CanApplyGpo=false**: gerçek hizmet oturumu ve GPO yenilemesi sonrası kalıcılık ayrıca doğrulanacaktır.
- 🔴✓ Test-AuthWireServiceLogon.ps11.0.0 eklendi. RunProbe, imzalı bootstrap/hak hazırlık araçlarını Inspect ile ve Test-ADServiceAccount ile tekrar doğrular; hedef SID'yi gerçek hesap adına çevirir. Korunan benzersiz ProgramData klasöründe minimal ServiceBase EXE derlenir ve mevcut kurumsal yayıncıyla imzalanır. EXE'ye yalnız Admin/SYSTEM yazabilir; hesap yalnız EXE read/execute ve ayrı sonuç klasöründe modify alır.
- Yerel SCM'de yalnız GUID isimli, demand-start own-process geçici hizmet oluşturulur; managed-account parolası NULL'dır. Kabul, çalışan SCM hizmetinin processID'si ile helper'ın SID/makine/hizmet/nonce/processID/authenticated/service-group verilerinin birlikte eşleşmesini gerektirir. Helper45s watchdog ile kendini durdurur. Normal finally yalnız oluşturulan hizmet handle'ını durdurur/siler ve gerçek yokluğunu doğrular; EXE/sonuç klasörü kaldırılır, admin-only manifest/kanıt/özet saklanır. Sert kesilmede watchdog durdurur; manifest, kalmış stopped demand-start kaydı için inceleme kanıtıdır; kesilme sonrası temizlik garanti edilmiş sayılmaz.
- 🔴✓ PR#72 kaynak659a1c6d66ecbaa8fc30d95783b19cb969b573c3, merge421f416f143d9219d2731b8453aa114ec0ce7c81. Ayrı Windows SCM job'unda kurumsal olmayan geçici fixture cert ile imzalı helper **LocalService altında iki kez** gerçek başlatıldı; SID/process/nonce bağları, bozuk proof reddi, ACL, çakışmada mevcut hizmete dokunmama ve temizlik dahil35 kontrol geçti. Bu müşteri gMSA'sı veya gerçek AD testi değildir. CI'deki etkileşimli CurrentUser root güven adımı, yalnız disposable runner'ın LocalMachine root/publisher alanına taşındı; test sonunda fixture güven girdileri temizlenir. Üretim aracı hiçbir root/publisher sertifikası eklemez.
- Son CI tümü başarılı: Windows40173858818 / SCMjob121110257926 (35), bootstrapjob121110257773 (147+16+39), foundation40173858806/job121110257642 (724test/28skip), bounded retry40173858835. İlk test ortamı denemelerindeki güven adımı beklemesi müşteri DC01'de yaşanmadı.
- Public kaynak /home/segmentiq/authwire-service-logon-probe-v1-20261025.ps1; SHA256=ac34825ef7263f920563b7980c1afbc701b77df5516b95599e3538c781bbeac0, uzak kopya özeti doğrulandı. Operatöre **RunProbe** komutu teslim edildi; gerçek DC01 gMSA hizmet oturumu hâlâ sonuç bekliyor. Linux/AuthWiredev.34/RADIUS/broker, müşteri GPO/SYSVOL, mevcut hizmetler, kullanıcı/bilgisayar sertifikaları ve imzalama anahtarı ACL'leri değiştirilmedi. Tam yedek alınmadı; yalnız hedefli işlem/test metadata kanıtları tutulur.
- Kanıt: checkpoints/2026-10-25-windows-connector-service-right-live-result.json; teslim: checkpoints/2026-10-25-windows-connector-service-logon-probe-delivery.json ve checkpoints/2026-10-25-windows-connector-service-logon-probe.ps1. Gerçek hizmet/kalıcılık, en az yetkili GPO/imzalama erişimi, connector/merkezi dağıtım ve uç/geri alma kapıları açık;54/94 (%57) değişmedi.

## 🔴✓ Gerçek LSA okuması kabul edildi; sınırlı hizmet oturumu hakkı hazırlığı hazır — 25 Ekim 2026

- Operatör DC01 LSA çıktısını paylaştı: ReadSucceeded=true; üç mevcut allow SID'si, deny listesi boş; aw-deploy$ SID S-1-5-21-34256453-3348971241-2809240126-1648 için **DirectAllowAssigned=false/DirectDenyAssigned=false**. Bu, doğrudan atama yokluğunu kanıtlar; grup üzerinden etkin izin veya gerçek hizmet oturumu iddiası yapılmaz. Önceki secedit boş listesi gerçek LSA atamalarının yokluğu değildi.
- 🔴✓ Initialize-AuthWireServiceLogon.ps11.0.0 eklendi. Varsayılan Inspect; PrepareServiceRight, aynı kurumsal imzalı bootstrap1.0.3 üzerinden domain/host/kurulum GUID'si/hesap/SID ve KDS/sahiplik/ayarları yeniden doğrular. Yalnız **SeServiceLogonRight** eklenebilir. LsaAddAccountRights mevcut haklara ekleme yapar; hiçbir allow/deny listesi bütünüyle değiştirilmez, üretim betiğinde hak silme API'si yoktur. LSA account-entry oluşturma, AD hesabı oluşturma değildir.
- Herhangi bir deny-service ataması varsa hazırlık grup incelemesi için durur. İşlem öncesi yalnız SYSTEM/Administrators erişimli benzersiz ProgramData klasörüne küçük işlem kaydı yazılır; drift tekrar kontrol edilir; hedef ekleme ve mevcut kayıtların korunması işlem sonunda doğrulanır. Kesilme/sonuç belirsizliğinde receipt ve Inspect kullanılır; otomatik geri alma veya hesabı yeniden oluşturma yapılmaz. Mevcut doğrudan atama varsa tekrar çalışma değişiklik yapmaz.
- 🔴✓ PR#71 kaynak1c12d3717ac40c4a6a16a0784301b916a29ca850, merge76071767a044d7484c27a8ae1316087d4f033627. Native Windows PowerShell5.1'de benzersiz kullanılmayan fixture SID'sine gerçek LSA ekleme, korunacak ayrı batch hakkı, koruma reddi, idempotence, receipt ACL'si ve yalnız test haklarının temizlenmesi dahil **39 kontrol geçti**; tam PrepareServiceRight yolu test edildi. Bootstrap147 + LSA read16 + genel724 test (28skip) ve bounded retry probe başarılı. Müşteri AD'si veya gerçek gMSA hizmet oturumu test edilmedi.
- CI Windows40171868961/job121104205842; foundation40171868914/job121104205644; probe40171868950.
- İmzalanacak public araç /home/segmentiq/authwire-service-right-prepare-v1-20261025.ps1; SHA256=b795a3a153af632a8cd2cfd821c3d2172633b0925da9aa4c2bb22031be4204f4, uzak kopya özeti doğrulandı. **DC01'de bu hak henüz eklenmiş sayılmaz:** operator PrepareServiceRight çıktısı beklenir. Canlı işlem sıfır; RADIUS/broker, AuthWiredev.34, GPO/SYSVOL/imzalama ACL'leri ve Windows paketleri değişmedi. Tam yedek alınmadı; hedefli değişiklikte yalnız küçük receipt oluşturulur.
- Açık kapılar: gerçek hak ekleme/readback, gerçek hizmet oturumu, GPO yenilemesi sonrası kalıcılık, sınırlı GPO/imzalama erişimi, connector/merkezi dağıtım ve uç/geri alma kabulü. ServiceLogonVerified/ConnectorInstalled/CanApplyGpo=false,54/94 (%57) değişmedi.
- Kanıt: checkpoints/2026-10-25-windows-connector-lsa-rights-live-result.json; teslim: checkpoints/2026-10-25-windows-connector-service-right-prepare-delivery.json ve checkpoints/2026-10-25-windows-connector-service-right-prepare.ps1.

## Hizmet oturumu atamaları: boş secedit sonucu kaydedildi; doğrudan LSA okuması hazır — 25 Ekim 2026

- Operatör DC01/aw-deploy$ için WINDOWS_CONNECTOR_SERVICE_RIGHTS_READONLY çıktısını paylaştı: **ExportedAssignments=[]**, PolicyChanged=false, ServiceLogonVerified=false. Bu yalnız dışa aktarılan INF'de iki atama satırının bulunmadığını kanıtlar; etkin izin yokluğu veya yasak yokluğu kabul edilmez. Yerel gMSA kullanım kabulü olumlu kalır.
- 🔴✓ Bağımsız Get-AuthWireServiceRights.ps11.0.0 eklendi. Yerel LsaOpenPolicy yalnız VIEW_LOCAL_INFORMATION|LOOKUP_NAMES (0x801) erişimi alır; LsaEnumerateAccountsWithUserRight ile SeServiceLogonRight/SeDenyServiceLogonRight SID listeleri okunur. NO_MORE_ENTRIES boş başarıdır; diğer hatalar Win32 koduyla başarısız olur. Buffer, metin ve policy handle finally ile bırakılır. İzin ekleme/silme, GPO/AD yazma, managed parola okuma, hizmet oluşturma veya oturum açma API'si yoktur.
- Çıktı doğrudan hesap SID'si eşleşmesini ayrıca gösterir; grup üzerinden etkin izin değerlendirmesi ve ServiceLogonVerified hâlâ false. Boş liste ile erişim hatası karıştırılmaz. Yerel bilgisayar ve SID biçimi doğrulanır; başka sisteme policy sorgusu yapılmaz.
- 🔴✓ PR#70 kaynak6f6b3632671943f601ac01c02b828e118e322ed8, merge823c064eff44d4c09c1c69269908ff7dfcf464fb. Native Windows PowerShell5.1 gerçek yerel LSA okuma/hata/kimlik korumaları için16 kontrol, mevcut bootstrap147 kontrol, genel724 test (28skip) ve bounded retry probe başarılı. Testte müşteri AD'si veya gerçek gMSA hizmet oturumu kullanılmadı; policy yazılmadı.
- CI Windows40170958115/job121101503511; foundation40170958141/job121101503622; probe40170958190.
- İmzalanacak public betik /home/segmentiq/authwire-service-rights-readonly-v1-20261025.ps1 olarak hazırlandı; SHA256=8084e949dd954833464d26224606e8a4ee41989ac17ed79f918c165ac9a2ef07, uzak kopya özeti doğrulandı. Yerel çıktı beklenir; hiçbir mevcut izin listesi üzerine yazılmadı. AuthWiredev.34, bootstrap1.0.3, RADIUS/broker ve müşteri GPO'su değiştirilmedi; tam yedek oluşturulmadı.
- Kanıt: checkpoints/2026-10-25-windows-connector-service-rights-export-result.json; teslim: checkpoints/2026-10-25-windows-connector-lsa-rights-delivery.json ve checkpoints/2026-10-25-windows-connector-lsa-rights-inspect.ps1. Gerçek hizmet oturumu, sınırlı GPO/imzalama erişimi ve merkezi dağıtım kabulü açık;54/94 (%57) değişmedi.

## 🔴✓ DC01 yerel gMSA kullanım kontrolü tamamlandı — 25 Ekim 2026

- Operatör WINDOWS_CONNECTOR_LOCAL_ACCOUNT_CHECK sonucunu paylaştı: DC01/aw-deploy$, SID S-1-5-21-34256453-3348971241-2809240126-1648, **LocalInstallationVerified=true, AccountReadyForUse=true**.
- **InstalledNow=false:** ilk Test-ADServiceAccount zaten olumlu olduğu için Install-ADServiceAccount çağrısı atlandı. Yeni yerel kurulum/hesap oluşturma veya hesap yeniden oluşturma yapılmadı. Sabit SID ve imzalı bootstrap1.0.3 Inspect kapısı üzerinden gerçek Windows kullanım kontrolü tamamlandı.
- 🔴✓ KDS, hesap/sahiplik/readback ve yerel kullanım alt adımları tamamlandı. **ServiceLogonVerified=false, ConnectorInstalled=false, CanApplyGpo=false** aynen kalır: Test-ADServiceAccount başarısı, gerçek Windows hizmetinin bu kimlikle çalıştığının kanıtı değildir.
- Sıradaki salt okunur ön kontrol, DC01 birleşik yerel/domain güvenlik veritabanında yalnız SeServiceLogonRight ve SeDenyServiceLogonRight atamalarını okur. secedit /export /mergedpolicy /areas USER_RIGHTS kullanılır; /configure veya /import çağrısı yoktur. Benzersiz geçici INF/log dosyaları işlem sonunda kaldırılır. Atamalar tek başına grup üzerinden gelen etkin hakkı veya gerçek hizmet oturumunu kanıtlamaz.
- Gerçek hizmet oturumu, gerekiyorsa yalnız hedef SID'ye sınırlı hak hazırlığı, GPO/SYSVOL izinleri, imzalama anahtarına hizmet erişimi, yönetim bağlantısı ve GPO/uç/geri alma kabulü açık kalır. Hiçbir oturum açma hakkı bu teslimde değiştirilmedi; mevcut müşteri GPO'su veya domain-controller hak listesi üzerine yazılmaz. A03/A04, AuthWiredev.34 ve54/94 (%57) korunur.
- Kanıt: checkpoints/2026-10-25-windows-connector-local-account-live-result.json; sonraki salt okunur komut: checkpoints/2026-10-25-windows-connector-service-rights-readonly.ps1.

## 🔴✓ Windows hesabının gerçek readback kabulü tamamlandı — 25 Ekim 2026

- Operatör imzalı bootstrap1.0.3 Inspect sonucunu paylaştı: **Blockers=[], ReadyForAccountPreparation=true, Kds.Ready=true/ConfigurationValid=true**. aw-deploy$ Exists=true/Created=false; SID S-1-5-21-34256453-3348971241-2809240126-1648. Sahiplik, AES, delegasyon, grup/SPN ve tek DC01 parola okuyucusu gereklilikleri gerçek AD'de birlikte doğrulandı. Hesap yeniden oluşturulmadı.
- 🔴✓ Önceki ADPropertyValueCollection ve null-SPN kaynaklı yanlış engellerin gerçek DC01 kabulü kapandı. KDS ve hesap hazırlığı/readback alt adımları tamamlandı; **yerel gMSA kurulumu veya hizmet oturumu tamamlanmış sayılmaz**.
- Pilot GPO AllSettingsEnabled/mevcut izinlerle; kurumsal yayıncı CodeSigningEku/HasPrivateKey/CurrentlyValid olumlu, hizmet anahtarı erişimi doğrulanmamış. Inspect AD/GPO/sertifika/yerel policy değiştirmedi, sır dışa aktarmadı. GmsaReadinessVerified/LocalInstallationVerified/ServiceLogonVerified/ConnectorInstalled/CanApplyGpo=false.
- Sıradaki teslim yalnız **DC01 yerel gMSA kullanımı**: aynı imzalı bootstrap Inspect kapısı ve sabit SID doğrulanır; Test-ADServiceAccount zaten olumluysa yerel kurulum atlanır, olumsuzsa Install-ADServiceAccount ile yalnız yerel hazırlık yapılıp tekrar test edilir. Yerel kurulum komutu henüz operatör tarafından çalıştırılmış/kabul edilmiş değildir. Hesap/okuyucu/GPO/imzalama ACL'si veya oturum açma hakları değiştirilmez; connector hizmeti kurulmaz.
- Gerçek hizmet kimliği/oturumu, en az yetkili GPO/SYSVOL erişimi, imzalama anahtarı erişimi, yönetim bağlantısı, gerçek GPO/uç dağıtımı ve geri alma kabulü açık kalır. Genel A03/A04 ve54/94 (%57) değişmedi; AuthWiredev.34 ve çalışan servisler için işlem yapılmadı.
- Kanıt: checkpoints/2026-10-25-windows-connector-bootstrap-r4-live-accepted.json. Sonraki kapı teslimi: checkpoints/2026-10-25-windows-connector-local-account-check.ps1.

## 🔴✓ Boş SPN alanının yanlış sayılması düzeltildi — 25 Ekim 2026

- Operatör gerçek DC01 metadata çıktısını paylaştı: aw-deploy$ / msDS-GroupManagedServiceAccount, SID S-1-5-21-34256453-3348971241-2809240126-1648. Description kurulum/host GUID'siyle tam eşleşir; DNS aw-deploy.vizyonveri.local, Enabled/AccountNotDelegated=true, TrustedForDelegation/TrustedToAuthForDelegation=false, AES128/AES256 ve ham msDS-SupportedEncryptionTypes24, primaryGroupID515, tek okuyucu DC01 DN'sidir.
- **Yanlış engelin nedeni kesinleşti:** ServicePrincipalNames=null iken @($null).Count=1; MemberOf gerçek boş ADPropertyValueCollection ve Count0. Bootstrap1.0.2 bu boş SPN alanını dolu sayarak ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH üretiyordu. Paylaşılan ayarlar için hesap değişikliği gerekmez.
- 🔴✓ Bootstrap1.0.3 null veya gerçekten boş SPN/grup koleksiyonunu kabul eder; her gerçek giriş, boş dize, dizide null öğesi veya iç içe boş dizi dahil, engellenir. Hesap oluşturma parametreleri, sahiplik, AES24, delegasyon, primary-group ve tek okuyucu gereklilikleri korunur. KDS işlevi değişmedi.
- 🔴✓ PR#69, kaynakb1f65459ffa63b8230c63f8f61d13c530ce9e51f, merge696468127fb28a611da252c4e1c34c17ddd23c5b. Gerçek AD koleksiyon/ADKerberosEncryptionType türleriyle ve gözlenen null-SPN biçimiyle native PowerShell5.1 testinde **147 kontrol geçti**. Genel724 test geçti (28skip), bounded retry probe başarılı. AD/KDS/GPMC çağrıları testte taklittir; canlı gMSA hizmet oturumu henüz doğrulanmadı.
- CI: Windows40170087137/job121098982998; foundation40170087117/job121098982968; probe40170087162.
- Public betik /home/segmentiq/authwire-windows-bootstrap-v1-r4-20261025.ps1 olarak hazırlandı; SHA256=458243b75970470005ea6a2c4bf2337887653812af74dd041a10f760e7c5ac79, uzak kopya özeti doğrulandı. AuthWiredev.34, GPO, çalışan RADIUS/broker, CA/sertifikalar, Windows paketleri için değişiklik/restart yapılmadı; tam yedek oluşturulmadı.
- **Bekleyen:** kurumsal imzalı1.0.3 Inspect'in DC01'de gerçek kabulü. Hesap metadata/sahiplik değerleri olumlu; son bootstrap kabulü, yerel gMSA kurulumu/oturumu, sınırlı GPO/imzalama erişimi ve merkezi dağıtım kapıları ayrı kalır. CanApplyGpo=false; A03/A04 ve54/94 (%57) değişmedi.
- Kanıt/teslim: checkpoints/2026-10-25-windows-connector-account-settings-result.json; checkpoints/2026-10-25-windows-connector-bootstrap-r4-delivery.json; checkpoints/2026-10-25-windows-connector-bootstrap-r4-inspect.ps1.

## Windows hesabı mevcut; ayar uyumsuzluğu için salt okunur inceleme açık — 25 Ekim 2026

- Operatör DC01'de kurumsal imzalı bootstrap1.0.2 Inspect çalıştırdı. **aw-deploy$ Exists=true, Created=false**; hesap varlığı doğrulandı, önceki oluşturma sonucunun belirsizliği varlık açısından giderildi. Hesabın bu kurulumla tam eşleşmesi henüz doğrulanmadı.
- KDS Count1/Ready=true/ConfigurationValid=true. ADPropertyValueCollection→Int32 hatası tekrarlanmadı; yeni engel **ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH**, ReadyForAccountPreparation=false. Uyumsuz alan henüz bilinmiyor; sahiplik veya ayar olduğu kanıtlanmadan hesap ya da koruma kontrolü değiştirilmez.
- Inspect Sid=null çıktısı hesabın SID'si olmadığı anlamına gelmez: bootstrap bir engel varken SID'yi yayımlamaz. Genel hesap doğrulaması başarısız kaldı. GmsaReadinessVerified/ConnectorInstalled/CanApplyGpo/LocalInstallationVerified/ServiceLogonVerified=false.
- GPO AllSettingsEnabled ve mevcut izinlerle, yayıncı CodeSigningEku/EkuReadState/HasPrivateKey/CurrentlyValid olumlu. AD/GPO/sertifika/yerel policy değişmedi; sır dışa aktarılmadı. Yeni hesap oluşturma/silme/onarım veya servis yeniden başlatma yapılmadı.
- Sonraki işlem, açıkça seçilmiş hesap metadata alanlarının gerçek değer ve türlerini, ham msDS-SupportedEncryptionTypes dahil, DC01'den salt okunur almaktır. Yönetilen parola veya anahtar materyali istenmez. Hesap ayarları ve sahiplik kabul edilmeden PrepareAccount tekrar çalıştırılmaz.
- Kanıt: checkpoints/2026-10-25-windows-connector-r3-live-mismatch.json; komut: checkpoints/2026-10-25-windows-connector-account-settings-readonly.ps1. A03/A04, dev.34 ve54/94 (%57) tamamlanma hesabı değişmedi.

## Windows hazırlığı 1.0.2: AD koleksiyonu okuma hatası düzeltildi — 25 Ekim 2026

- Operatörün bootstrap1.0.1 PrepareAccount denemesi ADPropertyValueCollection → Int32 dönüşümünde kesildi. **Hesap oluşturma sonucu belirsizdir:** önceki Inspect'teki Exists=false artık güncel durum kanıtı değildir; aw-deploy$ oluşturulmuş, ardından readback doğrulaması hata vermiş olabilir. Hesap yok/başarıyla kuruldu varsayılmadı; silme/yeniden oluşturma veya mevcut hesabı değiştirme yapılmadı.
- 🔴✓ Bootstrap1.0.2 sayısal ve Boolean alanları tam bir tek değer olarak okur. Gerçek ADPropertyValueCollection desteklenir; boş/çoklu/iç içe/yanlış tür/kesirli/taşan değerler engellenir. AES24, primary-group513/515, delegasyon, sahiplik ve tek parola okuyucusu kontrolleri korunur. Hesap oluşturma parametreleri ve KDS işlevi önceki sürümle birebir aynı.
- 🔴✓ PR#68 / kaynak46d02973e63b495ab52992c0f89fc31145a87d1c, merge47b7c16d3fbe303f92786950a9cc036cb2a4944a. Native Windows PowerShell5.1 testinde gerçek AD modülü koleksiyon türüyle eski hata yeniden üretildi; mevcut hesabın salt okunur kontrolü, create sonrası readback ve ikinci create yapılmaması dahil **117 kontrol geçti**. AD/KDS/GPMC çağrıları testte taklittir; gerçek müşteri gMSA oturumu test edilmiş sayılmaz.
- Genel724 test geçti (28skip); bounded retry probe başarılı. Windows CI run40169478310/job121097226642, foundation40169478328/job121097226591, probe40169478286.
- Linux'ta yalnız public bootstrap dosyası hazırlandı: /home/segmentiq/authwire-windows-bootstrap-v1-r3-20261025.ps1; SHA256=696733d09ee6c4f5bea29df1b1d4fb60da47cac0e9b7d81d40f0f002c3a90361. Uzak kopyanın özeti doğrulandı. AuthWire uygulama sürümü/dev.34, çalışan servisler, GPO/policy/CA/sertifika/Windows paketleri için değişiklik veya restart işlemi yapılmadı.
- **Sıradaki tek işlem Inspect:** DC01'de kurumsal imzalama, aynı instance4c23eebe-0715-46d1-88ee-a2e96ad7ee46 ile salt okunur hesap/SID/sahiplik/yetki doğrulaması. Gerçek çıktı gelmeden PrepareAccount tekrar teslim edilmez. KDS gerçek kontrolü tamamlanmış kalır; hesap readback, yerel gMSA oturumu, sınırlı GPO/imzalama erişimi ve merkezi dağıtım kabul kapıları açıktır. A03/A04 ve54/94 (%57) değişmedi.
- Kanıt/teslim: checkpoints/2026-10-25-windows-connector-account-readback-failure.json; checkpoints/2026-10-25-windows-connector-bootstrap-r3-delivery.json; checkpoints/2026-10-25-windows-connector-bootstrap-r3-inspect.ps1.

## 🔴✓ KDS beklemesi ve gerçek yapılandırma kontrolü tamamlandı — 25 Ekim 2026

- Operatör DC01/vizyonveri.local üzerinde imzalı bootstrap1.0.1 **Inspect** sonucunu paylaştı: tek kök, **Kds.Ready=true**, State=configuration_valid, **ConfigurationValid=true**, Blockers=[] ve ReadyForAccountPreparation=true. Bekleme sonrası native KDS kontrol kapısı kapandı; anahtar yeniden oluşturulmadı.
- aw-deploy$ hâlâ yok: Exists=false, Created=false, Sid=null. Mevcut pilot GPO AllSettingsEnabled; CodeSigningEku/EkuReadState/HasPrivateKey/CurrentlyValid yayıncı kontrolleri olumlu. Bu salt okunur kontrolde AD/GPO/sertifika/yerel policy değişmedi ve sır dışa aktarılmadı.
- **Hesap kurulumu tamamlandı sayılmaz:** GmsaReadinessVerified/LocalInstallationVerified/ServiceLogonVerified/ServiceKeyAccessVerified/CanApplyGpo/ConnectorInstalled=false. KDS başarısı hizmetin çalışabildiği veya GPO yazma yetkisi verildiği anlamına gelmez.
- Sıradaki somut işlem, aynı imzalı betikte **PrepareAccount**: sabit kurulum GUID'si `4c23eebe-0715-46d1-88ee-a2e96ad7ee46`, hedef DC01, hesap aw-deploy. Yalnız DC01 parola okuyucusu, AES128/256 ve delegasyon koruması; mevcut müşteri hesabını sahiplenme/onarım, yönetici grubu üyeliği, GPO, CA, imzalama ACL'si veya hizmet kurulumu yok. Komut teslimi henüz canlı hesap oluşturma sonucu değildir.
- Sonraki kapılar: hesap readback/SID, yerel gMSA kurulum ve gerçek oturum, sınırlı GPO/imzalama erişimi, yönetim bağlantısı, gerçek GPO/uç ve geri alma kabulü. AuthWiredev.34 ve çalışan 802.1X değişmedi. A03/A04 ve54/94 (%57) hesabı korunur; yeni Word/PDF raporu bu alt sonuç için yeniden üretilmedi.
- Kanıt: `checkpoints/2026-10-25-windows-connector-kds-ready-result.json`; teslim: `checkpoints/2026-10-25-windows-connector-account-prepare.ps1`, `checkpoints/2026-10-25-windows-connector-account-prepare-delivery.json`.

## 🔴✓ Windows hazırlık 1.0.1 gerçek DC01 kontrolü ve EKU düzeltmesi kabul edildi — 24 Ekim 2026

- Operatör tam WINDOWS_CONNECTOR_BOOTSTRAP JSON sonucunu paylaştı: bootstrap1.0.1, Inspect, DC01/vizyonveri.local. Hazırlık envanterinin gerçek Windows okuması hatasız tamamlandı. Önceki ObjectId.Value hatası bu çalıştırmada tekrarlanmadı.
- 🔴✓ Kurumsal yayıncı `6E74B513F766E01730719684A41B2664380CA68A`, CurrentUser/My: CodeSigningEku=true, EkuReadState=valid, HasPrivateKey=true, CurrentlyValid=true. **Hizmet kimliği anahtar erişimi doğrulanmadı** (ServiceKeyAccessVerified=false); bu sonuç yalnız mevcut yönetici deposunu doğrular.
- 🔴✓ Hedef bilgisayar DC01 GUID `0fa4143f-aae3-4bc3-9cd3-db8a1de24acd`, sabit kurulum GUID `4c23eebe-0715-46d1-88ee-a2e96ad7ee46` doğrulandı. Önerilen aw-deploy$ hesabı mevcut değil ve oluşturulmadı. AuthWire-Pilot-Trust aynı GUID/AllSettingsEnabled ve mevcut izinlerle okundu; sahiplenilmedi, yeni yazma yetkisi verilmedi.
- Tek hazırlık engeli **KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED**:1kök, propagation_wait, Kds.Ready=false. En erken kontrol **25 Ekim07:18:13Türkiye (+03:00)** /04:18:13UTC. Bu durumda **ConfigurationValid=false başarısız kriptografik test değildir; süre nedeniyle Test-KdsRootKey henüz çağrılmadı.**
- Operatör çıktısında AdChanged/GpoChanged/CertificatesChanged/LocalPolicyChanged/SecretsExported=false. Bu kayıt sırasında yeni canlı ürün/servis işlemi yapılmadı; AuthWiredev.34 korunur. Inspect tamamlandı; KDS kabulü, gerçek gMSA oluşturma/kurulum/oturum, GPO delegasyonu ve imzalama anahtar ACL'si, yönetim TLS/protokolü ve uç kabulü açık. A03/A04 ve54/94 (%57) hesabı değişmedi.
- Sonraki kapı: bekleme dolunca aynı imzalı betikte Inspect'i yeniden çalıştırıp KDS yapılandırma sonucunu doğrulamak; bundan sonra ayrı PrepareAccount adımına geçmek. Anahtar yeniden oluşturulmayacak.
- Kanıt: `checkpoints/2026-10-24-windows-connector-bootstrap-r2-live-result.json`.

## 🔴✓ Windows hazırlık EKU okuma düzeltmesi test edildi; DC01 tekrar kontrolü açık — 24 Ekim 2026

- İlk gerçek Inspect çalıştırması yayıncı envanterinde durdu: `PropertyNotFoundStrict`, EnhancedKeyUsageList.ObjectId.Value. DC01'de ObjectId görüntüleme nesnesinin Value özelliği olmadığı bildirildi. İlk48kontrol boş yayıncı deposu kullandığından bu yol kapsanmamıştı. **İlk canlı Inspect başarılı sayılmaz.** Inspect uygulaması AD/GPO/sertifika deposu yazması yapmaz; hesap oluşturma istenmedi.
- 🔴✓ Bootstrap **1.0.1** EKU'yu Cert: görüntüleme nesnesinden değil gerçek X.509 DER uzantısından X509EnhancedKeyUsageExtension ile okur. Eksik/bozuk EKU absent/invalid ve CodeSigningEku=false olarak açık raporlanır. Bozuk DER'in native decoder tarafından boş OID listesine çevrilmesi de geçerli sayılmaz.
- 🔴✓ Native Windows PowerShell **5.1.26100.33648** üzerinde **56 kontrol** geçti (run40121882136/job120955038224). Gerçek geçici bellekteki X.509 sertifikalarıyla code-signing, server-auth, eksik ve bozuk EKU; string ve Oid ObjectId görüntüleme biçimleri doğrulandı. Sertifika deposuna yazılmadı. AD/KDS/GPMC hâlâ simüledir; gerçek gMSA/KDS çoğaltma/servis kabulü değildir. Kaynak `51308432fb6a7db1126df317f8200220f5225a9b`, PR67; merge `1313d6f4929bbfa99ffcbeb2542d74ac24480cdb`. Foundation724test/28ortam atlaması, syntax ve bounded-network-probe kontrolleri de başarılı.
- Yeni dosya `/home/segmentiq/authwire-windows-bootstrap-v1-r2-20261024.ps1`:13310bayt, SHA256 `1a416a475ee4e56b7b35f2f9b928e698f15dca9f3847499c7c6fb7f446d0700b` Linux'ta doğrulandı; eski sahne dosyası korundu. Canlı AuthWiredev.34 ürün dosyası, RADIUS/broker, policy/CA/Windows paketleri veya GPO değiştirilmedi; yeni tam yedek alınmadı.
- **Açık:** güncel dosyayı hash doğrulaması ve aynı kurumsal imza sonrası DC01'de **Inspect** ile yeniden çalıştırma. Aynı kurulum GUID'si `4c23eebe-0715-46d1-88ee-a2e96ad7ee46` korunur. KDS en erken25Ekim07:18:13Türkiye kontrol kapısı, gerçek hesap oluşturma/kurulum, sınırlı GPO/imzalama yetkisi ve connector/uç kabulü açık. A03/A04 ve54/94 (%57) hesabı değişmedi.
- Kanıt: `checkpoints/2026-10-24-windows-connector-bootstrap-inspect-failed.json`, `checkpoints/2026-10-24-windows-connector-bootstrap-r2-delivery.json`; güncel blok `checkpoints/2026-10-24-windows-connector-bootstrap-r2-inspect.ps1`.

## 🔴✓ Standart Windows AD hazırlık betiği geliştirildi ve test edildi — 24 Ekim 2026

- Her müşteride ayrı komut dizileri yerine kullanılacak domain/hedef bilgisayar/kurulum GUID parametreli `windows/connector/Initialize-AuthWireWindows.ps1` v1 eklendi. Varsayılan **Inspect**: AD/GPO/sertifika/yerel policy, hizmet ve görevlere yazmaz. Domain, yazılabilir DC, hedef bilgisayar, KDS metadata/süre/yapılandırma, hesap adı/kimliği çakışmaları; isteğe bağlı mevcut GPO izinleri ve public yayıncı sertifika durumu kontrol edilir.
- **PrepareAccount** modu, KDS oluşturma+10 saat ve kayıtlı etkinlik zamanının geçmesini ve yerel Test-KdsRootKey=true sonucunu şart koşar. Yalnız seçilen bilgisayarın parola alabileceği, AES128/256 ve Kerberos delegasyonu kapalı gMSA oluşturur. KDS anahtarı oluşturmaz/değiştirmez; var olan müşteri hesabını sahiplenmez/onarmaz/silmez. Kurulum ve bilgisayar GUID'leriyle eşleşen hesap aynı ayarlarda ise yazmadan kullanılır; drift, yarış veya kayıp oluşturma teyidi otomatik ikinci yazmaya dönüşmez.
- 🔴✓ Native Windows PowerShell **5.1.26100.33648** üzerinde **48 kontrol** geçti (run40121100889/job120952593225). AD/KDS/GPMC/sertifika çağrıları test doubles ile yürütüldü; gerçek AD/KDS çoğaltması, gMSA kurulumu veya hizmet oturumu kabulü sayılmadı. Foundation **724 test/28 ortam atlaması**, syntax ve bounded-network-probe kontrolleri de başarılı. Kaynak `91e18f979fe63136fc180617c69f87c0c3bdaa1a`, PR66; merge `1778aeca16b3ac9c3a0d9e5ed4881e877a89987d`.
- Dosya `/home/segmentiq/authwire-windows-bootstrap-v1-20261024.ps1` konumuna sahnelendi; 12008 bayt ve SHA256 `75b8e21e21796dcf2a3023f45dd8d87c9cc6c2f7d8176bf7096fe4b2afe1dfc1` Linux'ta doğrulandı. Canlı ürün kaynak/servis/unit/policy/CA/istemci/GPO değiştirilmedi; sürüm dev.34. Yeni tam yedek alınmadı.
- Pilot kurulum kimliği `4c23eebe-0715-46d1-88ee-a2e96ad7ee46`, domain vizyonveri.local, hedef DC01, önerilen gMSA aw-deploy$. Şimdiki operatör adımı dosya hash'ini doğrulayıp mevcut kurumsal yayıncıyla Windows'ta imzalamak ve **yalnız Inspect** çalıştırmak. ExecutionPolicy düşürülmez; GPO paketleri AllSigned kalır. Bu betik henüz DC01'de çalıştırılmadı; hesap oluşturulmadı.
- **Açık:** 25 Ekim 07:18:13 Türkiye saati sonrası KDS kabulü, gerçek gMSA oluşturma/yerel kurulum/oturum, sınırlı GPO delegasyonu ve imzalama anahtar ACL'si, yönetim TLS/protokolü, gerçek GPO/uç dağıtımı ve geri alma. CanApplyGpo/ConnectorInstalled/GmsaReadinessVerified=false kalır. A03/A04 açık;54/94 (%57) değişmedi.
- Kanıt ve çalıştırma bloğu: `checkpoints/2026-10-24-windows-connector-bootstrap-delivery.json`, `checkpoints/2026-10-24-windows-connector-bootstrap-inspect.ps1`.

## 🔴✓ KDS kök anahtarı oluşturuldu; yayılım beklemesi sürüyor — 24 Ekim 2026

- Operatör DC01'de WINDOWS_CONNECTOR_KDS_PREPARED sonucunu paylaştı: **Created=true, RootKeyObjectsVisible=1**. Anahtar oluşturma ve ardından metadata sayımı doğrulandı. Önceki salt okunur kontrolde görünür anahtar sayısı 0 idi; ilk betiğin ham1 sayımı bu yeni oluşturma kanıtıyla karıştırılmaz.
- **AD'de bir defalık KDS önkoşulu oluşturuldu. GPO ve sertifikalar değiştirilmedi.** Bu adım, mevcut 802.1X policy/CA/Windows paketi değişikliği veya connector kurulumu değildir.
- Normal bekleme sonrası en erken kontrol: **25 Ekim 2026 Pazar 07:18:13, Türkiye saati (+03:00)**; UTC 04:18:13. GmsaReadinessVerified=false; yalnız zamanın dolması gMSA çalışabilirliğinin test edildiği anlamına gelmez. Anahtar yeniden oluşturulmayacak veya geri tarihlenmeyecek.
- Sonraki açık adımlar: KDS kullanılabilirlik doğrulaması, sınırlı Windows hizmet hesabı/gMSA hazırlığı, sınırlı GPO delegasyonu, hizmet kimliğiyle imzalama anahtarına erişim ve connector uygulaması. Uç cihaz kabul testleri 26 Ekim Pazartesi için açık. Canlı ürün dev.34 ve A03/A04 açık; ana kontrol listesi 54/94 (%57), alt hazırlık tamamlandı diye oran artırılmadı.
- Kanıt: `checkpoints/2026-10-24-windows-connector-kds-prepared-result.json`.

## 🔴✓ KDS metadata kontrolü tamamlandı; anahtar oluşturma bekliyor — 24 Ekim 2026

- Operatörün doğrudan DC01 configuration partition sorgusunda, VIZYONVERI\\administrator hesabıyla **RootKeyObjectsVisible=0**, RootKeys=[] doğrulandı. Mevcut domain sorgusu tek yazılabilir DC (DC01, Windows Server 2019) bildirdi; tüm forest için tek DC olduğu varsayılmadı.
- İlk kontrolün ham `1` sayımı tarihçe olarak korunur, anahtar varlığı kanıtı olarak kullanılmaz. Boş koleksiyonun dış wrapper ile sayılmış olması olası açıklamadır; cmdlet nesne şekli ayrıca kanıtlanmadı. Anahtarın silindiğine dair kanıt yok.
- KDS sorgusu salt okunurdu: AD/GPO değişmedi, anahtar malzemesi istenmedi. Mevcut GPO AllSettingsEnabled ve mevcut izinler korunuyor.
- Sıradaki bir defalık AD önkoşulu için DC01/domain korumalı betik hazırlandı: anahtar hâlâ yoksa `Add-KdsRootKey -EffectiveImmediately`, ardından metadata doğrulaması ve oluşturma zamanından 10 saat sonrası için kontrol zamanı. Var olan anahtarı silmez/yenilemez, geri tarih kullanmaz; GPO, CA/sertifika, policy ve Windows istemci dosyalarına yazmaz. **Betik henüz çalıştırılmadı; KDS oluşturuldu veya gMSA hazır denemez.**
- gMSA oluşturma/kurulum, sınırlı GPO yetkisi, hizmet kimliğiyle imzalama anahtarına erişim ve gerçek uç kabulü açık. Canlı AuthWire dev.34; bu kayıt ürün kodu veya çalışan servisleri değiştirmez. A03/A04 ve pazartesi uç testleri açık; 54/94 (%57) hesabı değişmedi.
- Kanıt: `checkpoints/2026-10-24-windows-connector-kds-metadata-result.json`. Hazırlanan işlem: `checkpoints/2026-10-24-windows-connector-kds-prepare.ps1`.

## 🔴✓ Windows GPO/izin isimleri doğrulandı; KDS hazırlığı açık — 24 Ekim 2026

- Operatör WINDOWS_CONNECTOR_READONLY_NAMES sonucunu paylaştı. AuthWire-Pilot-Trust durumunun **AllSettingsEnabled** olduğu doğrudan DC01 enum adından doğrulandı. Pilot grupGpoApply; Domain Admins/Enterprise Admins/SYSTEM GpoEditDeleteModifySecurity; Authenticated Users/ENTERPRISE DOMAIN CONTROLLERS GpoRead olarak okundu. Yeni hizmet hesabı veya delegasyon oluşturulmadı.
- 🔴✓ ExecutionPolicy isimleri doğrulandı: LocalMachine RemoteSigned, diğer dört scope Undefined. Herhangi bir execution-policy veya GPO durumu değiştirilmedi; paketlerde AllSigned gereği korunur.
- **KDS belirsizliği:** sonraki çıktı KdsTimes=[] döndü. İlk betikteki `@(Get-KdsRootKey).Count=1` gerçek anahtar varlığı için yeterli kanıt sayılmıyor. Microsoft cmdlet çıktısı generic root-key listesi; boş liste/koleksiyon sayımı olasılığı çıkarımdır, henüz yerel nesne şekliyle kanıtlanmadı. “Anahtar silindi” veya “kesinlikle anahtar yok” sonucu çıkarılmadı. İlk kaydın ham1değeri tarihçe olarak korunup doğrulanmışlık kaldırıldı.
- Doğrudan DC01'in configuration partition'ında msKds-ProvRootKey nesnelerini ve yalnız oluşturma/başlangıç zamanı metadata'sını okuyacak kısa betik hazırlandı. msKds-RootKeyData istenmez/yazdırılmaz; DC listesi okunur. Sonuç gelmeden KDS/gMSA oluşturma, anahtar silme veya bekleme süresini geri tarihleme yapılmadı.
- Gelecekteki v2 önkontrolde dış array-wrapper sayımı yerine dönen koleksiyonun kendi Count özelliği kullanılacak. İlk çalıştırılan v1 hash'i `7be8f5097422a6fe6a539716e91c05a1e6bb72cf53faccd63dd100e8b0c08fe9` ve kaynak dosyası aynen korunur.
- İmzalama anahtarı hâlâ Administrator CurrentUser/My deposunda; hizmet kimliği erişimi ayrıca kurulacak/doğrulanacak. AuthWiredev.34, RADIUS, policy/sertifika, Windows paketleri ve AD/GPO bu kayıt sırasında değişmedi. A04 ve gerçek uç/pazartesi testleri açık;54/94 (%57) hesabı korunur.
- Kanıt: `checkpoints/2026-10-24-windows-connector-readonly-names-result.json`. Açık kontrol: `checkpoints/2026-10-24-windows-connector-kds-metadata-readonly.ps1`.

## 🔴✓ Windows yönetim bileşeni DC01 salt okunur hazırlık kontrolü tamam — 24 Ekim 2026

- Operatör WINDOWS_CONNECTOR_READONLY_PREFLIGHT sonucunu paylaştı; Errors=[] ve AD/GPO/trust değişikliği yok. DC01, Windows Server2019Standard build17763, PowerShell5.1.17763.592; ActiveDirectory1.0.1.0, GroupPolicy1.0.0.0 ve Kds1.0.0.0 modülleri var.
- DomainModeWindows2016Domain, schema88, KDS root key count1. Bunlar gMSA yaklaşımı için temel ortam verileridir; anahtarın etkinlik/çoğaltma zamanı, kurulacak hizmet hesabının parola alabilmesi ve gerçek görev/servis oturumu henüz doğrulanmadı. Yeni KDS anahtarı veya hizmet hesabı bu kontrolde oluşturulmadı.
- Mevcut AuthWire-Pilot-Trust GPO'su aynı GUID ile bulundu. JSON GpoStatus3 ve izin65536/65792/65794değerleri ham olarak saklandı; isim karşılığı tahmin edilmedi ve GPO'nun etkin/devre dışı olduğu ilan edilmedi. Sonraki kısa salt okunur kontrolde yerel enum isimleri ve KDS zamanları alınacak.
- Kod imzalama sertifikası `6E74B513F766E01730719684A41B2664380CA68A`, Administrator kullanıcısının CurrentUser/My deposunda ve HasPrivateKey=true. Bitiş2027-10-06T09:48:11UTC. Bu bayrak kurulacak servis/gMSA hesabının anahtarı kullanabileceğini kanıtlamaz; PrivateKeyAccessTested=false olarak korundu. Özel anahtar dışa aktarılmadı veya imzalama erişimi verilmedi.
- 🔴✓ İlk ortam okuması tamam; ayrı hesap/delegasyon/imzalama/bağlantı kurulumu açık. A04 bütünü, gerçek GPO ve uç kabulü tamamlanmadı.54/94 (%57) hesabı değişmedi. Çalışan AuthWiredev.34, RADIUS/policy/sertifika/Windows paketlerine bu kayıt sırasında işlem yapılmadı.
- İlk çalıştırılan betik eski hash/commit ile aynen korunur. Sonraki kullanımlar için enum isimlerini açık string'e çeviren v2 hazırlandı; kısa isim/KDS kontrolü henüz çalıştırılmadı. Kanıt: `checkpoints/2026-10-24-windows-connector-readonly-preflight-result.json`.

## 🔴✓ dev.34 merkezi dağıtım hazırlık ekranı operatör kabulü tamam — 24 Ekim 2026

- Operatör “Kontrol ettim. sorun görünmüyor” diyerek Sertifikalar → Dağıtım / Windows dağıtım planları / Yeni dağıtım penceresi kontrolünü onayladı. Canlı ekran görünümü kabulü tamamlandı.
- Bu onay dağıtım planı oluşturulduğu, profil XML'inin uç cihaza uygulandığı veya GPO yazıldığı anlamına gelmez. Kısıtlı Windows yönetim bileşeninin bir defalık yetkilendirmesi ve imzalı GPO yolu sıradaki açık adımdır.
- Gerçek kullanıcı/bilgisayar AD-GPO, Ethernet/Wi-Fi, geçiş ve ölçek kabulü pazartesi için açık kalır. A04 bütünü ve54/94 (%57) tamamlanma hesabı değişmedi. Bu kayıt sırasında canlı kaynak, servis, policy, sertifika ve AD/GPO değişikliği yapılmadı.
- Kanıt: checkpoints/2026-10-24-windows-preparation-live-result.json içindeki operator_browser_acceptance.

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

## 🔴✓ dev.32 kullanıcı sekmeleri operatör kabulü tamam — 24 Ekim 2026

- Operatör Sertifikalar → Kullanıcı profilleri ve Kullanıcı kayıtları sekmelerinin ikisinin de hatasız açıldığını doğruladı. Canlı kurulum sonrasındaki sekme görünürlüğü/tarayıcı kabulü tamamlandı olarak işaretlendi.
- Bu onay profil oluşturma, gerçek kullanıcı sertifikası dağıtımı veya kullanıcı 802.1X/VLAN kabulü değildir. Gerçek kullanıcı/cihaz AD-GPO ve kablolu/Wi-Fi testleri pazartesiye bırakılmıştır; A03/A04 bütünü açık kalır.
- Bu kayıt güncellemesinde canlı sisteme, profile, policy'ye, sertifikalara veya AD/GPO'ya ek işlem yapılmadı. Kanıt: checkpoints/2026-10-24-user-profile-panel-live-result.json içindeki operator_acceptance.

## 🔴✓ dev.32 canlı kullanıcı profili panel kurulumu tamam — 24 Ekim 2026

- 🔴✓ Operatör USER_PANEL_FINISHED / verified=true çıktısıyla dev.32 (kaynak 422ab022c0fe2e54848772934575e035b45610ac) kurulumunu doğruladı. Yerel sudo/kurulum beklemesi kapandı. Hazırlık kaydındaki dev.29 canlı sürüm bilgisi bu sonuçla güncellendi.
- 🔴✓ Korunan dosyalar, RADIUS/broker PID'leri, timer ve önceden var olan iş verisi kontrolleri başarılı. RADIUS aktif ve yeniden başlatılmadı; önceki PID 1136462 korundu. Broker süreci korundu. Policy, mevcut sertifikalar/anahtarlar, bilgisayar istemcisi, Windows uçları ve AD/GPO değişmedi.
- 🔴✓ Yedek worker uyumu güncellendi; kullanıcı kayıt altyapısı için boş şema eklendi. Kullanıcı kayıt profili oluşturulmadı veya kayıt izni kendiliğinden açılmadı. Yeni tam veri yedeği alınmadı; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Önce altı, sonra kullanıcı status API ve yeni JS dahil on sekiz yol üçer kez HTTP200 döndü. Son kontrolde kullanıcı status medyan 7,0ms/en uzun 10,9ms; tüm yolların en uzunu 159,4ms (bilgisayar kayıt status). Bu kısa yerel ölçüm uzun süre/yük veya tarayıcı/uç kabulü değildir.
- Açık kalan panel kabulü: operatör dev.32 sürümünü, Sertifikalar → Kullanıcı profilleri / Kullanıcı kayıtları sekmelerini ve hata olmadan açılmalarını görsel olarak kontrol edecek. Gerçek kullanıcı AD/GPO/kablolu-Wi-Fi/VLAN/geçiş/negatif testleri operatörün isteğiyle pazartesiye bırakıldı; A03/A04 bütünü kapatılmadı.
- İlk94 alt iş sayımı 54/94 (%57), kalan40/94 (%43) korunur; bu kayıt canlı kurulum alt adımını kapatır. Kanıt: checkpoints/2026-10-24-user-profile-panel-live-result.json ve /var/lib/authwire-updates/user-panel-dev32-20261024T121809Z-08fe3866.

## 🔴✓ Kullanıcı kayıt profilleri panel yönetimi — teknik kabul tamam, 24 Ekim 2026

- 🔴✓ Sertifikalar bölümüne ayrı Kullanıcı profilleri ve Kullanıcı kayıtları sekmeleri eklendi. Profil oluşturma/düzenleme penceresi; açık AD güvenlik grubu seçimi, grup arama/sayfalama, geçerlilik ve yenileme aralığı ile kayıt iznini yönetiyor. Yeni profilde kayıt varsayılan olarak kapalı; sayfa açılınca profil veya AD grubu oluşturulmaz.
- 🔴✓ Kullanıcı paketi indirme, kullanıcı sertifikasının oluşturulması/kurulum teyidi/yenileme/süre dolması/iptal durumunu görme ve açık yenileme talebi işaretleme hazır. Yenileme talebi istemcinin sonraki kontrolünü bekler; mevcut ağ bağlantısı hemen değişmiş sayılmaz. Kayıt iznini kapatmak mevcut sertifikayı iptal etmez. VLAN kararı mevcut Erişim kuralları bölümünde kalır.
- 🔴✓ Salt okunur sertifika hesabında kayıt/paket/yenileme yazma işlemi yok. Başka yönetici profili değiştirirse sürüm kontrolü taslağı korur. Yanıtı kaybolan kaydetme otomatik tekrar edilmez; kayıtlı sonuç okunup eşleşen profil doğrulanır. Kaydetme başarılı, liste okuması başarısız durumları ayrılır. Oturum kapandıktan sonraki yanıtlar listeyi yeniden dolduramaz. Hiçbir parola/özel anahtar veya kalıcı tarayıcı depolaması eklenmedi.
- 🔴✓ AD grup adı yalnız mevcut katalogdan gösterilir; yetkilendirme SID'si değiştirilmez. Aramada kaybolan mevcut seçim korunur; seçilmemiş grup kendiliğinden ilk sonuca atanmaz. HTML görünümlü katalog adları metin olarak çizilir. Masaüstü ve 390px mobil ekranlar, profil penceresi ve taşma kontrolü gerçek tarayıcı görüntüleriyle incelendi.
- 🔴✓ Kaydetmeden önce başlayan gecikmiş okuma, yazma sonrası doğrulamanın yerine geçemez; eski yanıtlar ve hatalar dikkate alınmaz. Bu yarış yeni tarayıcı testinde gerçek POST/taze GET ile geçti.
- 🔴✓ Genel CI'da mevcut servis testinin busy bayrağını kilitsiz okuyup son dosya yazımından önce klasörü silebildiği görüldü. Test bekleyişi mevcut controller kilidiyle eşleştirildi. Ürün broker/servis kodu değişmedi; hata gizlenmedi veya koruma kaldırılmadı. Hedefli 18 servis testi geçti.
- 🔴✓ 690 Python testi (28 ortama bağlı atlama), 13 tarayıcı akışı, 107 zorunlu native Kerberos/backend/HTTP testi, mevcut Windows kullanıcı/bilgisayar istemcileri ve retry kontrolleri başarılı. Yeni tarayıcı akışı gerçek geçici HTTPS/CA/profil/paket/yenileme API'lerini kullanır; AD/kullanıcı ilk kayıt verisi fixture'dır. Gerçek müşteri AD/GPO veya kullanıcı 802.1X saha kabulü değildir.
- 🔴✓ PR63 kaynak 422ab022c0fe2e54848772934575e035b45610ac, main merge 7e9844718d0b8f8a772a4b135dc568ec484137ef. Altı CI workflow başarılı; normal/debug RADIUS ve systemd aktivasyon/rollback dahil. 161 dosyalı dev.32 paketinin manifest SHA256 değeri d7ad429bc3d7d0a8fea3dc948a75eff5356de8e2b4b0bf11802f6c4f099cdb80. Son UI kaynakları Git ile karşılaştırıldı; kesin kanıt checkpoints/2026-10-24-user-profile-panel.json dosyasında. Değişen 15 proje dosyası kaynak karşılaştırmasına alındı. RADIUS çekirdeği/adapter, policy motoru, iki bilgisayar scripti, iki kullanıcı scripti ve kilitli logo önceki kaynakla byte olarak aynıdır. Mevcut bilgisayar profilleri/erişim kuralları testte korundu; ayrı AuthWire grubu özelliği geri eklenmedi.
- 🔴✓ Operatör uzak bağlantıyı düzeltti. Yeni salt okunur kontrolde dev.29; panel 1136447, RADIUS 1136462 ve broker 1069437 aktif, günlük yedek ve CRL timer aktif/enabled. Canlı kaynak hâlâ değiştirilmedi. Gerçek kurulu updater hash'i/owner kontrolleri ve 161 dosyalı staging manifest/kapsam doğrulaması geçti. Kurucunun yedi izolasyon testi aynı Linux venv'inde de başarılı. Özel DB/koruma ve uygulama evresi yerel sudo parolası gerektiriyor; parolasız sudo yok. Canlı kurulum/operatör kabulü tamamlandı sayılmaz.
- 🔴✓ Dev.29→dev.32 kurucusu hazır: yalnız 31 değişen/yeni kaynak dosyası, iki yedek worker uyumu ve dört boş kullanıcı tablosu/indeks eklemesi planlandı. Tam veri yedeği yok; küçük kod geri alma kaydı var. Yalnız panelin kısa stop/start geçişi planlanır; RADIUS/broker PID ve unit/native modül, mevcut policy/sertifika/anahtar/Windows/AD-GPO/timer korunur. Beklenmeyen kaynak, worker veya kısmi şema reddedilir. Eski iş verisi hash ile korunur; yeni tablolarda operatör verisi görülürse silinmez. Canlı sonuç henüz alınmadı.
- Operatörün isteğiyle gerçek test bilgisayarı/GPO/kullanıcı kablolu-Wi-Fi/VLAN/geçiş/negatif kabulü pazartesiye bırakıldı. Kullanıcı/AD grubu policy kimlik kapsamı, imzalı merkezi SYSVOL/GPO dağıtımı ve tam GPO otomasyonu açık. A03/A04 bütünü kapatılmadı.
- İlk 94 alt iş sayımı 54/94 (%57), kalan 40/94 (%43) olarak korunur. Kullanıcı profili panelinin teknik alt adımı tamamlandı; canlı kurulum, operatör panel kabulü ve saha testi açık tutulur.
- Ayrıntı: USER_PROFILE_PANEL.md. Önceki kullanıcı istemcisi/paket kanıtı USER_WINDOWS_CLIENT.md ve 2026-10-24-user-windows-client.json kayıtlarında korunur.

## 🔴✓ A03/A04 kullanıcı Windows istemcisi ve dağıtım paketi — teknik kabul tamam, 24 Ekim 2026

- 🔴✓ Kullanıcıya ait ayrı Windows istemcisi geliştirildi. Sertifika ve dışa aktarılamayan CNG özel anahtarı CurrentUser kapsamındadır; state, pending, retry ve kurulum dizini kullanıcı SID'si/profil UUID'siyle ayrılır. Mevcut bilgisayar istemcisi ve SYSTEM görevi değiştirilmedi.
- 🔴✓ İlk kayıt, yeni anahtarla yenileme, kurulum teyidi, bağlantı kesilince kalıcı yeniden deneme, yanıtı kaybolan isteğin aynı anahtar/CSR ile tamamlanması, süresi dolan yarım isteğin arşivlenip yeni anahtarla toparlanması ve anahtar oluştururken kesinti sonrası mevcut anahtarla devam etme Windows testlerinden geçti. Eski yaprak/anahtar temizliği bağ kontrolü ve 24 saat yerel bekleme süresiyle sınırlandı; çalışan anahtar korunuyor.
- 🔴✓ İmzalı kullanıcı logon kurucusu ve SID/profil başına Limited/InteractiveToken görev hazır. Beş dakikalık kontroller kalıcı 10 dakika–12 saat retry süresine uyar; sağlıklı sertifika kontrolü altı saatte bir yapılır. Parola tutulmaz. Kullanıcı oturumu kapalıyken kullanıcı işi çalıştırılacağı ilan edilmez.
- 🔴✓ Yönetici sertifika-yazma yetkisi ve HTTPS isteyen kullanıcı paket indirme API'si hazır. İki PowerShell imzası config ve açık CA/TLS dosyalarının hash'lerini bağlar. Kod imzalayan yayıncı ile CA/HTTPS kök güveni onaylı GPO ile önceden dağıtılır. Kurucu kök depolarını salt okunur doğrular, kök güveni onayı istemez; yalnız ara CA'yı CurrentUser'a ekler. certreq işlemleri 60 saniyeyle sınırlıdır.
- 🔴✓ Standart yerel kullanıcı kendi dışa aktarılamayan kullanıcı anahtarını ve sınırlı görevini oluşturdu; diğer kullanıcının CNG anahtarını açamadı. Asıl kullanıcı istemcisinin CNG/certreq/kurulum/yenileme/state akışı Windows üzerinde, yalnız Kerberos/HTTP taşıması ve AD dizini sentetik olan kontrollü testle çalıştı. Gerçek sunucu Kerberos/HTTPS sınırı ayrı native testlerle doğrulandı; bu birleşim gerçek Windows AD/GPO uçtan uca kabulü değildir.
- 🔴✓ PR62 kaynak 0b5bf7fc33a723a8cb1093378e5956afb5774cfc, main merge e40f8ba0aae5835370b426d7148603cd3b147a97. Altı CI workflow başarılı: 688 Python testi (28 ortama bağlı atlama), zorunlu Kerberos/backend/HTTP 107 test, tarayıcı akışları, normal/debug gerçek RADIUS ve systemd aktivasyon/rollback, mevcut bilgisayar Windows CNG/startup/expiry/retry ve yeni kullanıcı Windows testi. Sentetik 1000 bilgisayar kontrolü 1000 ayrı sertifikayla 10,62 saniyede geçti; müşteri AD/GPO veya 200 kullanıcı kabulü değildir.
- 🔴✓ 159 dosyalı dev.31 aday kaynak hazır; manifest SHA256 620232c3ac97ac7e96f597f15c68d55a835c42b53f26749c7d1ebc083a2e8654. Değişen 16 dosya GitHub kaynağıyla birebir doğrulandı. RADIUS çekirdeği/adapter, policy motoru, mevcut iki bilgisayar PowerShell dosyası, HTML ve logo byte olarak aynı. İptal edilen ayrı grup özelliği geri eklenmedi.
- Canlı kurulum yapılmadı. Son doğrulanmış canlı sürüm dev.29'dur; bu adımda canlı kaynak, servis, policy, sertifika, Windows veya AD/GPO değişmedi. Yeni tam yedek alınmadı. Son salt okunur canlı durum sorgusu zamanında yanıt vermedi; önceki PID/servis bulguları yeni kontrol gibi sunulmaz. Günlük timer üzerinde işlem yapılmadı.
- A03/A04 bütünü açık: kullanıcı kayıt profillerini panelden yönetme, kullanıcı grubu policy kimlik kapsamının doğrulanması, kontrollü imzalama/SYSVOL/GPO dağıtımı, gerçek AD kullanıcısının kablolu/Wi-Fi/VLAN ve kullanıcı/bilgisayar geçiş/negatif testleri, merkezi GPO tam otomasyonu ve ölçek kabulü bekliyor. Kaynak status windows_client_available=true/enterprise_signing_required=true döndürür; endpoint_acceptance_pending=true kalır. Bu, dev.29 canlı status veya müşteriye dağıtım yapıldığı anlamına gelmez.
- Sıradaki teknik iş: kullanıcı sertifika kayıt profillerini panelden yönetme. İlk 94 alt iş sayımı 54/94 (%57), kalan 40/94 (%43) olarak korunur; yalnız bu teknik alt adım tamamlandı. Bağımsız tarihsel Windows retry aralıklılığı, test bu koşuda geçmiş olsa da kök nedeni çözüldü sayılmaz.
- Kanıt: USER_WINDOWS_CLIENT.md ve checkpoints/2026-10-24-user-windows-client.json.

## 🔴✓ A03 kullanıcı kayıt sunucu altyapısı teknik olarak tamam — 24 Ekim 2026

- 🔴✓ Parolasız kullanıcı Kerberos kayıt oturumu, bilgisayar oturumundan ayrı kabul ve session store ile geliştirildi. Kullanıcıya özgü kayıt profilleri açık yönetici seçimi gerektirir; otomatik kullanıcı profili/grup oluşturulmaz. İptal edilen ayrı AuthWire grupları özelliği geri eklenmedi.
- 🔴✓ Güncel AD SAM→GUID/SID/hesap durumu/tokenGroups kontrolü, imzalı CSR ve anahtar kanıtı; tekrar/eşzamanlı isteklerde aynı sertifikayı döndürme; kurulum teyidi, yeni anahtarla yenileme ve eski yaprağın kurulumdan sonra emekliliği teknik testlerden geçti. AD sorgusu sırasında sertifika sona ererse teyit reddedilir; çalışan eski yaprak devreden çıkarılmaz.
- 🔴✓ Kullanıcı/bilgisayar oturumları birbirine çevrilemiyor; başka realm/SPN, değiştirilmiş path/JSON, replay, kullanıcı silip yeniden oluşturma, grup çekilmesi/hesap devre dışı ve profil sürüm değişimi retleri test edildi. Sunucu kullanıcı parolası veya istemciden GUID/SID kabul etmez. İlk desteklenen ad biçimi ASCII SAM@configured-domain, SAM en çok20karakterdir; alternatif UPN/forest desteği ilan edilmez.
- 🔴✓ PR61, kaynak e97e66cf16178ace2ca6ded5025e1786d8e2e63f, main merge bd5f4b6864c4bb771fc77020aca07ca60ed39e05. Son kaynakta8CI workflow başarılı: 665 Python testi (28 ortama bağlı skip), zorunlu native Kerberos/backend/HTTP107test, gerçek kullanıcı Kerberos+HTTPS+sertifika/teyit akışı; 12 tarayıcı akışı; normal/debug native RADIUS, systemd aktivasyon/rollback, Windows CNG/startup/expired/retry, yedek ve opsiyonel kullanıcı şeması restore kontrolleri.
- 🔴✓ 1000 bilgisayarlı sentetik kayıt/teyit yükü1000ayrısertifika ile14,386s duvar süresinde geçti; gerçek AD/GPO veya200müşteri cihaz kabulü değildir. Önceden izlenen Windows retry aralıklılığı başarılı bu koşuyla kök neden çözülmüş sayılmaz.
- 🔴✓ Yeni profil/issuance tabloları iş verisi, kısa ömürlü challenge/rate satırları volatile olarak yedek tutarlılığına bağlandı. Tam kullanıcı şeması okunabilir, kısmi şema reddedilir. Tarihsel yedek worker geçişinde bulunan hash uyumsuzluğu iki sabit, gözden geçirilmiş byte değişimi ve bilinen eski SHA sınırlarıyla düzeltildi; koruma gevşetilmedi.
- 🔴✓ 153dosyalı dev.30 aday paket hazır; manifest SHA256 6ec493376e5c8c0e45703b3a18f07f78fea7c6c508730f13da1b27a4db7d2fc7. RADIUS çekirdek adapter/policy, mevcut Windows istemci/installer, HTML ve logo kaynakları dev.29 ile birebir aynı. Panelin bilgisayar endpoint/profilleri korunur; ortak signer, sınırlı worker bütçesi ve SQLite writer lock yeniden kullanılır.
- Bu aşama yalnız kaynak/teknik kabuldür. Canlı kurulum yapılmadı: son salt okunur kontrolde dev.29, panel1136447/RADIUS1136462/broker1069437 aktif, günlük yedek ve CRL timer aktif. Kaynak/servis/policy/sertifika/Windows/AD-GPO değiştirilmedi; canlı tam veri yedeği/restore veya kullanıcı profili oluşturma yapılmadı.
- A03 bütünü açık kalır: imzalı CurrentUser Windows CNG istemcisi, kullanıcıya ait korumalı state/retry/yenileme/anahtar temizliği, kullanıcı kayıt profili panel yönetimi ve kullanıcı gruplarında kural kimlik kapsamı, gerçek kullanıcı kablolu/Wi-Fi/VLAN ve kullanıcı/bilgisayar geçiş/negatif kabulü bekliyor. API status windows_client_available=false ve endpoint_acceptance_pending=true döndürüyor.
- A04 merkezi Windows/GPO otomasyonu açık. Sonraki iş kullanıcı istemcisi ve dağıtım paketidir; canlı güncelleme bundan önce uygulanmaz. Sonraki kuruluma yeni schema/uyumlu yedek worker koruma kontrolleri eklenmeli. İlk94alt iş puanı54/94 (%57), kalan40/94 (%43) değişmedi; henüz bütün bir kabul maddesi kapanmadı.
- Kanıt: USER_ENROLLMENT_BACKEND.md ve docs/checkpoints/2026-10-24-user-enrollment-backend.json.

## 🔴✓ dev.29 canlı kaldırma tamam — 24 Ekim 2026

- 🔴✓ Operatör LOCAL_GROUP_REMOVAL_FINISHED/verified=true çıktısıyla dev.29 ve source3b522160d34a0ebaf952f707c611490ccf1a9b5f canlı uygulamasını doğruladı. Önceki yerel sudo/kurulum beklemesi kapandı.
- 🔴✓ İptal edilen ayrı grup özelliğinin menüsü, API/static kaynağı ve kural seçicisi kaldırıldı; tek yerel gruba üyelik kısıtı da kaldırıldı. İlgili iki veri satırı (bir grup ve bir üyelik) atomik temizlendi, kayıt revizyonu ilerledi. Diğer iş verisi korundu. A01/A02 aktif plan ve rapora tekrar eklenmez.
- 🔴✓ RADIUS planlı yeniden başlatmayla1095612→1136462 geçti ve aktif. radius_process_preserved=false bu kontrollü geçiştir. Broker süreci, dosyalar, timer ve iş verisi kontrolleri başarılı. Policy, sertifika, Windows ve AD üyelikleri değişmedi. Yeni tam veri yedeği/izole restore yapılmadı; günlük yedek timer korundu.
- 🔴✓ On altı mevcut API yolu üçer kez HTTP200; iptal edilen /api/access-groups ve /access-groups.js HTTP404. En uzun yanıt145,2ms (device-admin/status); bu kısa loopback kontrolü uzun süreli/yük veya uç cihaz kabulü değildir.
- Sadece tarayıcıdaki menü/seçici yokluğu ve doğrudan kullanıcı/bilgisayar/AD grubu seçimlerinin operatör kontrolü bekliyor. Gerçek uç 802.1X regresyon kabulü henüz yapılmadı; cihaz erişimi bekler. Bu kayıt canlı policy/sertifika üzerinde ek işlem yapmadı.
- Sonraki ana çalışma A03 kullanıcı EAP-TLS ve G01/A04 merkezi Windows/GPO dağıtımı teknik hazırlığıdır. Bağımsız aralıklı Windows retry takibi açıktır.
- Kanıt: docs/checkpoints/2026-10-24-local-groups-removal-live-result.json ve /var/lib/authwire-updates/remove-groups-dev29-20261024T082604Z-33f27fa0.

## 🔴✓ İptal edilen özellik kaynak ve rapordan çıkarıldı — 24 Ekim 2026

- Operatörün son talebiyle AuthWire içinde ayrı erişim grubu oluşturma/üyelik yönetimi, yerel grup seçicisi ve tek yerel gruba üyelik kısıtı iptal edildi. A01/A02 aktif iş planından ve güncel Word/PDF raporundan çıkarıldı; bekleyen iş olarak taşınmadı. Tarihsel audit/Git kanıtları silinmedi.
- 🔴✓ PR60 kaynak değişikliği 3b522160d34a0ebaf952f707c611490ccf1a9b5f; main merge 611f5fad874e7bec12a2c062bef2e7d84520733d. dev.29 hazırlanmış durumda; mevcut doğrudan kullanıcı/bilgisayar ve AD grubu seçimi ile POLICY_CONFLICT koruması sürüyor. Desteklenmeyen local_group_ids seçicisi genel izne çevrilmez, açıkça reddedilir.
- 🔴✓ 603 Python testi (25 ortama bağlı atlama), sunucuda müşteri verisi kullanmadan 10 hedefli test, 12 tarayıcı akışı, altı CI workflow ve normal/debug gerçek protokol testleri geçti. Windows retry testi ilk koşuda kesirli deadline/deadline_rearmed/boş NextRunTime bulgusunu tekrarladı; aynı kaynak tekrarı geçti. Bu, kök neden çözümü değildir; B04 takibi açık.
- 🔴✓ Güncelleme/silinen kaynak dosyalarının geri alınması, hata halinde servis toparlanması ve idempotence testleri geçti. Yalnız iptal edilen özelliğin runtime_settings kayıtlarını temizleyen transaction; revizyon/audit dahil atomik hata geri dönüşü, stale-state ve kullanılan selector ön kontrolleriyle denetlendi. Diğer iş verisi ve policy değişmez.
- 🔴✓ 149 dosyalı paket kurulu güncelleyicinin gerçek manifest, kaynak ağacı ve kapsam kontrollerinden geçti. Helper sunucuda /home/segmentiq/authwire-remove-groups-20261024.py; SHA256 12697cfd3fa0673cd40f7d4e4fb4ba71bda2d8de239f05e01606b3b5f84a2c76.
- Canlı sürüm hâlâ dev.28; son salt okunur kontrolde panel1095597, RADIUS1095612 ve broker1069437 aktif, yedek/CRL timer aktif. Canlı root uygulaması yerel sudo parolası gerektiriyor. Bu turda müşteri grup kayıtları root yetkisiyle okunamadı; varsa policy bağlantısı kurulum başında değişiklikten önce durdurulur. Hiçbir mevcut policy kendiliğinden silinmez/dönüştürülmez.
- Planlı dev.29 uygulaması panel/RADIUS stop/start gerektirir. Broker, unit/native modül, Windows/GPO, CA/sertifikalar/anahtarlar, logo ve günlük timer korunur. Kullanıcının isteğiyle yeni tam veri yedeği/izole restore yapılmadı. Canlı kurulum ve tarayıcı kabulü henüz tamamlandı sayılmıyor.
- 🔴✓ Mevcut 24 Ekim tarihli PDF ve Word aynı dosya kimlikleriyle sürüm1 olarak güncellendi, dokuz sayfa kontrol edildi. İptal edilen başlıklar/kabul testleri raporda yok. Sayım ilk94alt işte 54/94 (%57), kalan40/94 (%43) olarak korunur; iptal edilen ek kapsam bu sayımın parçası değildi.
- Açık kapsam: A03 kullanıcı EAP-TLS ve G01/A04 merkezi Windows/GPO tam otomasyonu. Test bilgisayarı gerektirmeyen teknik hazırlıkla devam edilecek. DNS dağıtım mimarisi ve misafir tekrar testi kapsam dışı; NTP uzun gözlem beklemede.
- Kanıt: docs/checkpoints/2026-10-24-local-groups-removal-prepared.json. Güncel plan: USER_AUTH_AND_CENTRAL_DEPLOYMENT.md.

## 🔴✓ dev.27 canlı kurulum ve koruma kontrolleri tamam — 24 Ekim 2026

- 🔴✓ Operatör DEVICE_STORAGE_FINISHED/verified=true ile 0.14.0-dev.27, source e6b899b2dccbd74e07b7feaac3d5a22e6b7d93ce kurulumunu doğruladı. Önceki staging manifest ad hatası sonrası gerçek kurulum tamamlandı; yerel sudo/kurulum çıktısı beklemesi kapandı.
- 🔴✓ Dosya, PID, timer ve iş verisi kontrolleri başarılı. RADIUS1069559/broker1069437 süreçleri korundu; RADIUS yeniden başlatılmadı. Policy, sertifika ve Windows dosyaları değişmedi. Günlük yedek zamanlayıcısı korundu; yeni tam veri yedeği/izole veri restore yapılmadı.
- 🔴✓ Önce altı, sonra on altı API yolu üçer kez HTTP200. Sonrasında device-admin/status medyan3,7ms/en uzun157,5ms, state7,3/8,1ms; diğer son API'ler en çok65,1ms. Bu üçer okuma bir uzun süre/yük veya gerçek uç cihaz kabulü değildir.
- Teknik ve canlı kurulum alt adımı tamamlandı. B04'ün diğer yük/negatif kayıt senaryoları, gerçek uç kabulü ve bağımsız Windows retry aralıklılığı açık; bu çıktı bunları topluca kapatmaz. Sonraki çalışma kullanıcı EAP-TLS teknik hazırlığı ve merkezi Windows/GPO dağıtımıdır; gerçek saha kabulü cihaz erişimi bekler.
- Kanıt: /var/lib/authwire-updates/device-storage-dev27-20261024T052453Z-3eee794d; makine okunur sonuç docs/checkpoints/2026-10-24-device-storage-live-result.json. Bu kayıt turunda yeni canlı kaynak/servis/AD işlemi yapılmadı.

## 🔴✓ dev.27 staging manifest adı düzeltildi; gerçek kurucu ön kontrolü geçti — 24 Ekim 2026

- Operatör DEVICE_STORAGE_FAILED/phase=preflight_helpers/ValueError/evidence=null bildirdi. Canlı dev.26 ve panel1069472/RADIUS1069559/broker1069437 aktif/sabit; source swap veya servis restart olmadı.
- Neden asistanın staging hazırlama hatasıydı: manifest SOURCE_MANIFEST.json adıyla konmuştu, kurulu hash-sabit tools/linux_update.py verified_files fonksiyonu LINUX_SOURCE_MANIFEST.json bekliyordu. Önceki özel hash/AST kontrolleri bu arayüz farkını yakalamadı. Salt okunur gerçek validator çalışması installed_tree=True, stage_manifest=False/Invalid manifest ile nedeni doğruladı.
- 🔴✓ Yalnız kullanıcı staging dizinindeki manifest beklenen LINUX_SOURCE_MANIFEST.json adına taşındı, 0600 yapıldı; içerik SHA f9dd9ad2a1e44d76043cf487b763ad930af2bbbb8c37cd0cc479f4ca1a81fa23 korundu. Kurulum helper'ı ve incelenen ürün kodu değişmedi; helper SHA45695d2030290abb924d5c7e8b5d922912344a801662542d6b02d748582f4910 aynıdır.
- 🔴✓ Bu kez helper'ın kendi load_pinned → kurulu safe_tree(owner=0) → kurulu verified_files(STAGE,EXPECTED) → source_check zinciri salt okunur çalıştırıldı. 148 dosya, installed source güvenliği, kapsam ve drift koruması başarılı; RADIUS1069559/broker1069437 PID korundu. PRIVATE root DB/preservation/apply evreleri çalıştırılmadı; canlı kurulum hâlâ yerel sudo ve DEVICE_STORAGE_FINISHED çıktısı bekliyor.
- Aynı sudo komutu tekrar kullanılabilir. Bu onarım stage dosya adı/içerik doğrulamasıyla sınırlı olduğu için ürün/Windows/RADIUS CI'ı yeniden çalıştırılmadı; önceki başarılı kaynak testleri korunur. Teslim JSON'una doğru manifest adı ve gerçek ön kontrol kanıtı eklendi. B04 düzeltmesinin canlı kurulum kabulü kapanmadı.

## 🔴✓ dev.27 sertifika kayıt okumaları/yazmaları için kilit düzeltmesi — teknik kabul tamam, canlı kurulum bekliyor (24 Ekim 2026)

- Operatör 24–25 Ekim test bilgisayarına erişemiyor; AD ve AuthWire'a uzaktan erişebiliyor. Onaylanan sırayla önce B04 yük altında SQLite kilitlenmesi incelendi. Panel görsel düzenlemesi yapılmadı.
- 🔴✓ Tarihsel job119851757698 hata izi doğrulandı: dört işçili 1.000 sentetik cihaz kaydında DeviceEnrollment._authorize → Operations.directory/_public SELECT sırasında database is locked. Değişmeyen kaynakla üç ortam kombinasyonunda toplam 30 tekrar geçti; bu başarılı tekrarlar eski hatanın giderildiği diye sunulmadı. Aynı tarihsel koşunun kesin zamanlaması/yazıcı sahibi yeniden üretilmiş sayılmaz.
- 🔴✓ Kontrollü, kısa fixture-only SQLite timeout'lu exclusive writer/reader çakışması eski dev.26 kodunda database is locked ile başarısız; aynı kabul yeni kodda başarılı. DeviceEnrollment'ın kısa profil/durum/challenge/yetkilendirme-ayar okumaları ve yazmaları aynı servis-instance sırasına alındı. AD/Kerberos ağ sorgusu bu kilidin dışında kalır. Üç saniyelik admission sınırı ve yalnız SQLITE_BUSY/LOCKED için mevcut DEVICE_BUSY/429 yolu var; diğer veritabanı hataları gizlenmez, başarısız transaction geri alınır. Ortak Store/SQLite timeout, DELETE journal, dört worker gate, kimlik/izin kuralları ve sertifika kanıtı değişmedi.
- 🔴✓ Altı yeni regresyon: eski okuyucu yarışı, dış SQLite kilidinde güvenli geçici ret/veri koruma, sınırlı sıra bekleme, diğer hata türünü maskelememe, rollback/lock bırakma ve AD sorgusunun kilit tutmaması. Yerel tam koşu 601 test/25 ortam atlaması başarılı; syntax geçti. SQLite3.45.1/cryptography46.0.0 ile 200 cihaz 3,110s; üç ayrı 1.000 cihaz turu 14,958/15,487/15,908s. Her tur dört worker, benzersiz cert/installed receipt, binding/key/audit sayıları, integrity/foreign-key ve DELETE journal kontrolü başarılı.
- 🔴✓ Gerçek Linux üzerinde ayrı geçici state ile düşük öncelikli 200 sentetik cihaz testi 8,530s/cpu3,205s geçti. Canlı DB kullanılmadı. Panel1069472/RADIUS1069559/broker1069437 PID'leri ön/son korundu. Bu, gerçek 200 Windows/GPO/AD veya ağ kabulü değildir; önceki 23 Ekim PID'leri güncel diye kullanılmadı.
- 🔴✓ Son adayda altı CI workflow başarılı: foundation40065410053, browser40065410109, device/Windows/nativeKerberos40065410072, Linux40065410059, bounded probe40065410150, gerçek normal+debug EAP-TLS40065410048. Native load 1.000 cihaz/dört worker 13,843s; registry/audit/integrity başarılı. İlk browser turunda yalnız iki fixture'ın eski dev.26 sürüm beklentisi başarısızdı; eşikler gevşetilmeden dev.27 kesin beklentisiyle düzeltildi. Bağımsız Windows retry aralıklılığı bu başarılı koşuyla kapatılmadı.
- 🔴✓ PR58 birleştirildi: source e6b899b2dccbd74e07b7feaac3d5a22e6b7d93ce, merge8b445732b04b98b6f0c97b021574855478142326. 148 paket dosyasında yalnız device_enrollment.py, iki sürüm dosyası, ilgili test ve load aracı değişir. Depoda ayrıca teknik belge ve iki browser sürüm beklentisi güncellendi. RADIUS karar kaynağı/native modül, UI tasarımı/logo, Windows/GPO istemci/kurucu, policy, CA/sertifika verisi değişmedi.
- 🔴✓ Güncelleme paketi root olmayan staging'de doğrulandı; helper SHA45695d2030290abb924d5c7e8b5d922912344a801662542d6b02d748582f4910, manifestf9dd9ad2a1e44d76043cf487b763ad930af2bbbb8c37cd0cc479f4ca1a81fa23. Başarısız yazma/başlatma/HTTPS durumunda kaynak geri alma, tekrar çalıştırma/no-op, yalnız panel servisine müdahale ve kaynak drift/scope reddi izole probunda başarılı. RADIUS/broker yeniden başlatılmayacak; kurulum ön/son iş verisi, korunan dosya/PID/timer ve API/device-admin status kontrolleri var. Yeni tam veri yedeği/izole veri restore yapılmadı; günlük yedek/CRL korunur.
- **Bekliyor:** operatörün yerel sudo kurulumu ve DEVICE_STORAGE_FINISHED koruma çıktısı. Canlı kaynak bu kayıtta hâlâ dev.26; servis/AD/GPO/policy/cert değişikliği uygulanmadı. B04'ün bu sınırlı contention düzeltmesinin kaynak/teknik kapısı tamam, tüm B04/gerçek ölçek veya bütün yük sorununun kapanışı değil. Sonraki yerel grup/çakışma özellikleri henüz uygulanmadı; kullanıcı EAP-TLS ve uç cihaz kabulleri açık.
- Ayrı retry incelemesinde eski Windows job119941861158 tanılaması okundu: retry16:15:50Z tam saniye çalışması, JSON deadline19:15:50.8534911+03:00 ve deadline_rearmed sonrası NextRun boş; kesirli deadline'ın trigger zamanına dönüşümü/aynı çalışan tek-seferlik görevin yeniden kaydı şüphe olarak izlenecek. Kesin kök neden veya düzeltme henüz yok; Windows kaynağı değiştirilmedi.
- Teknik açıklama [DEVICE_STORAGE_ADMISSION.md](DEVICE_STORAGE_ADMISSION.md); teslim/kanıt/manifest/kurulum ve geri dönüş probu docs/checkpoints/2026-10-24-device-storage-* dosyalarında. Kullanıcıdan yeni tam durum raporu istenmedi; yalnız çalışma kaydı güncellendi.

## 🔴✓ Yerel grup ve merkezi Windows otomasyon kapsamı kaydedildi — 24 Ekim 2026

- 🔴✓ Operatörün düzeltmesi: örnekteki VLAN50-Kullanicilari **AuthWire içinde oluşturulacak yerel erişim grubu**; yeni AD grubu değildir. On kullanıcı farklı AD güvenlik gruplarında kalabilir. Yerel grup ve üyelik yönetimi yeni açık geliştirme maddesidir; mevcut tekil hesap/AD grubu seçimiyle tamamlandı sayılmaz.
- 🔴✓ Tekillik kararı kaydedildi: bir kullanıcı/bilgisayar aynı anda yalnız bir AuthWire yerel VLAN erişim grubuna üye olabilir. İkinci gruba eklemeden önce eskisinden çıkarılmalı; mevcut grup adıyla uyarı ve sunucu tarafı kayıt engeli gerekir. AD'nin olağan çoklu güvenlik grupları silinmez/değişmez. AD/doğrudan/genel kural çakışması ayrıca kontrol edilir; örtülü öncelik yok, çalışma anında POLICY_CONFLICT reddi korunur.
- 🔴✓ Kullanıcı EAP-TLS ve kullanıcı/bilgisayar geçişleri mevcut açık yol haritası olarak teyit edildi. Kullanıcı sertifikası yaşam döngüsü ve gerçek kullanıcı VLAN kabulü henüz tamamlanmadı; makine doğrulaması kullanıcıyı doğrulamış sayılmaz.
- 🔴✓ Merkezi Windows dağıtımı ve tam GPO otomasyonu açık kapsama eklendi/pekiştirildi: bir defalık sınırlı AD/Windows yetki kurulumu, panelden hedef seçimi, imzalı istemci/güven/kablolu-WLAN profili, AuthWire'a ait GPO oluşturma/güncelleme/bağlama, izleme ve geri alma, ardından 200 cihaz ölçek kabulü. Günlük LDAP okuma ve yetkili GPO yazma ayrıdır; AllSigned ve Windows'ta kalan imza anahtarı korunur. Ayrıntılar: [onaylı kapsam](USER_AUTH_AND_CENTRAL_DEPLOYMENT.md). **Kayıt tamamlandı; özelliklerin uygulanması açık.**
- Panel öncesi son kabul 21 Ekim: yanlış sunucu adı/kök ile kablosuz ret ve doğru profile dönüş; güncel cert/policy ile VLAN140 DHCP; policy disabled NO_MATCHING_POLICY reddi ve yeniden izin/VLAN140 bağlantısı; Ret/boş VLAN incelemesi operatörün eski elle deny kaydı açıklamasıyla kapandı. Doğru Wi-Fi profili geri yüklendi. Saf allow140→disable→enable turu tüm ayrıntılarıyla ayrıca kanıtlanmış sayılmaz; B08/B10 bütünü kapanmadı.
- Devam için yeni ana başlık **kullanıcı EAP-TLS pilotu**; önce geçerli makine pilotu ve hedef kullanıcı/sertifika kaydı salt okunur tespit edilecek. Önceki diğer AD/kapasite, SQLite/Windows fixture aralıklılığı, gerçek expiry/ayrı cihaz, accounting/oturum takibi, off-host ve tam appliance kurtarma işleri açık kalır. Yeni kapsam eklendiği için eski yüzde yeni payda olmadan tekrar kullanılmayacak.
- Operatör panel tasarımını şimdilik durdurdu. Bu tur yalnız belge/iş planı güncellemesidir; canlı sunucuya erişim, servis veya AD/GPO/policy/sertifika/Windows değişikliği yapılmadı. Dev.26 görünüm kabulü önceki bağımsız bekleme kaydı olarak kalır. DHCP/DNS mimarisi kapsam dışı, NTP uzun süre/reboot izlemi duraklatılmıştır.

## 🔴✓ dev.26 giriş/menü/grafik canlı kurulumu tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün LOGIN_CHART_FINISHED çıktısı sürüm 0.14.0-dev.26, kaynak cf4b34926b206aa4e3c1e52e7d08b264782e643c kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrollerinin tamamı başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on beş API yolu üçer kez HTTP 200 döndürdü. Dashboard 7 gün medyan/en uzun 4,8/4,8 ms; 1 saat 4,1/4,3 ms; 6 ay 8,1/8,7 ms; 1 yıl 6,3/9,6 ms. Kaynak API'si 1,6/2,2 ms. Son kontrollerin en uzun yanıtı 35,5 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu. Operatör tercihiyle yeni tam veri yedeği/izole veri restore yapılmadı.
- Bu kayıt turunda ek kaynak/servis eylemi uygulanmadı. Canlı kurulum bekleme maddesi kapanmıştır. Bekliyor: gerçek tarayıcıda çerçevesiz giriş ekranı, her girişte açık menü, yalnız Düzenle modundaki × düğmeleri ve yeni çift sütun trafik grafiği için operatör görünüm kabulü. Önceki bağımsız fonksiyonel açık işler bu kurulum çıktısıyla kapanmaz.
- Kanıt: /var/lib/authwire-ui-updates/login-chart-dev26-20261023T204113Z-cf2f2590. Makine okunur kayıt: docs/checkpoints/2026-10-23-login-chart-live-result.json.

## 🔴✓ dev.26 giriş ekranı, düzenleme denetimleri ve yeni trafik grafiği — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün ekranına göre dashboard kartlarının × kaldırma düğmesi yalnız Düzenle modunda görünür ve çalışır. Normal görünümde hover, klavye odağı ve dokunmatik ekran bu düğmeyi açmaz; düzenleme dışındaki kaldırma çağrısı da engellenir. Kaydet/Vazgeç, boş düzen, katalogdan geri ekleme, taşıma ve boyutlandırma korunur.
- 🔴✓ İlk HTML boyamasından itibaren giriş, oturum kontrolü ve bağlantı kurtarma ekranlarında sol menü, Kontrol merkezi başlığı ve menü aç/kapat düğmesi gizlidir. Giriş kartı çalışma alanı sütunundan bağımsız ortalanır. Doğrulanmış panel açılana kadar çalışma alanı çerçevesi görünmez; kullanıcıdan tekrar parola istemeden kurtarma davranışı korunur.
- 🔴✓ Her yeni panel girişinde ve geçerli oturumla F5 dönüşünde menü açık başlar; önceki tarayıcıdaki gizleme tercihi yeni girişi kapalı başlatmaz. Kullanıcı sonrasında kapatabilir/açabilir. Arka plan yenilemesi kullanıcının aynı oturumdaki kapatma seçimini bozmaz. Mobilde de girişte menü açılır; perde/menü düğmesiyle kapatılabilir, sayfa seçimi mobil perdeyi kapatır. Masaüstüne dönüşte aynı sayfa içindeki seçim korunur.
- 🔴✓ Kimlik doğrulama trafiği alan/çizgi grafiği yerine mavi/pembe geçişli ikili dikey sütunlara dönüştü. Sütunların açılış hareketi, hover/klavye odağında vurgusu, değerleri ve zaman aralığı ipuçları var; hareket azaltma tercihi desteklenir. Uzun dönemler en fazla 36 ardışık zaman grubuna toplanır; kabul/ret toplamları aynen korunur, veri atlama veya sahte trafik yoktur. Altı dönem, filtreye geçiş/watermark, grafik dışındaki kartlar ve gerçek kaynak ölçümleri korunur.
- 🔴✓ Son kaynakta 12 tarayıcı akışı, 595 temel/HTTP sınır testi (25 ortam atlaması), Linux hazırlık/systemd, Windows istemci/retry/native Kerberos ve sınırlı ağ probu başarılı. Tarayıcı denemeleri giriş/yükleme/kurtarma/çıkışta çerçevesiz ekranı, eski gizleme tercihiyle yeniden girişi, F5'i, arka plan yenilemesinde kapalı kalmayı, mobil açılışı, yalnız düzenlemede kaldırmayı, tam sütun toplamlarını ve responsive yerleşimi doğrular. Giriş, masaüstü dashboard ekranları incelendi.
- 🔴✓ 148 paket dosyasında yalnız altı frontend/sürüm dosyası değişir. Tüm backend ve RADIUS karar kaynakları, kurallar, sertifikalar, Windows/GPO, native modül ve onaylı logo baytları aynıdır. Yalnız panel servisine müdahale, yazma/başlatma/HTTPS hatasında eski kaynağa dönüş ve tekrarlı çalıştırma sınırı izole kurulum probunda başarılı.
- 🔴✓ Linux üzerinde staging ve kurulu dev.25 tabanı karşılaştırması doğrulandı. Canlı kaynak veya servis bu turda değiştirilmedi; RADIUS PID 832810 ve broker PID 887154 aktif. Yeni tam veri yedeği/izole veri restore yapılmadı; günlük yedek ve CRL düzeni korunur. Kurulumda yalnız kaname-lab.service yenilenecek.
- Bekliyor: hash sabitlenmiş sudo kurulumu, LOGIN_CHART_FINISHED koruma çıktısı ve gerçek panelde giriş/menü/düzenleme/grafik görünüm kabulü. Bu frontend turu önceki fonksiyonel açık işleri veya bağımsız fixture takibini kapatmaz. Gerçek normal/debug EAP-TLS workflow'u kayıt anında çalışıyor ve başarılı diye gösterilmedi.
- Kaynak cf4b34926b206aa4e3c1e52e7d08b264782e643c; PR #57 birleştirildi (42049a612b8207197834402db5807499e17b6848). Manifest d9debe0e4dc78e190645c1c7c2210c9cf9c663bb1e6818bf8d30e182232f1887. Yardımcı /home/segmentiq/authwire-login-chart-20261023.py; SHA256 6cba72c84e818bcaf12dcd789a0e7f578447bbc61e88ff113bbed8d4a5565f65. Tarayıcı run40020516718/job120643570520/artifact12530022887; ZIP SHA256 0b0cb4405ad0561324077cdc2a9931941e28603f1ac83bf981121de4ccdd366a. Teslim kaydı docs/checkpoints/2026-10-23-login-chart-delivery.json.

## 🔴✓ dev.25 dashboard düzenlemeleri canlı kurulum tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün DASHBOARD_POLISH_FINISHED çıktısı sürüm 0.14.0-dev.25, kaynak 3baa25868bccf69b930b69404c37d69cc3746090 kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrollerinin tamamı başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on beş API yolu üçer kez HTTP 200 döndürdü. Son 1 saat medyan 4,9 ms / en uzun 5,3 ms; 6 ay 5,6 / 6,1 ms; 1 yıl 6,8 / 7,0 ms. Dashboard 7 gün 7,0 / 10,5 ms; kaynak API'si 4,9 / 5,0 ms. Son kontrollerin en uzun yanıtı 38,9 ms.
- 🔴✓ RADIUS aktif, yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu. Operatör tercihiyle yeni tam yedek/izole veri restore yapılmadı.
- Bu kayıt turunda ek kaynak veya servis eylemi uygulanmadı. Canlı kurulum beklemesi kapanmıştır. Bekliyor: Ctrl+F5 sonrası dört lacivert özet kartı, pembe üst çizgilerin kaldırılması, pembe yoğunluk ölçeği, altı dönem ve dar üst başlığın operatör görünüm kabulü. Önceki bağımsız fonksiyonel açık işler bu kurulum çıktısıyla kapanmaz.
- Kanıt: /var/lib/authwire-ui-updates/dashboard-polish-dev25-20261023T202446Z-6cf487dc. Makine okunur kayıt: docs/checkpoints/2026-10-23-dashboard-polish-live-result.json.

## 🔴✓ dev.25 dashboard renkleri, başlık ve dönemler — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Üç operatör ekranı incelendi. İlk ekrandaki dört özet kartı aynı #1D4D73 lacivert zemin, beyaz başlık/sayı/açıklama ve aynı kenarlıkla eşitlendi. Sertifika, CPU/RAM/disk ve bağımsız durum kartlarındaki pembe üst çizgiler kaldırıldı; tüm kartları laciverte çevirmek yerine ekrandaki dört özet kartı esas alındı.
- 🔴✓ Trafik grafiğinin #B5346B pembe ret rengi korundu. Haftanın erişim ritmi ve Düşük→Yüksek ölçeği aynı dört basamaklı pembe yoğunluk paletine alındı; hücre sayıları, eşikleri ve etkileşimleri değiştirilmedi.
- 🔴✓ Dönem listesi: Son 1 saat, Son 24 saat, Son 7 gün, Son 1 ay, Son 6 ay, Son 1 yıl. Önceki 30 günlük seçenek Son 1 ay adıyla korunur; 6 ay/1 yıl takvim aylarına göre hesaplanır ve ay sonu/artık yıl günleri güvenle kısaltılır. 1 saat son 60 dakikadır ve dakikalık; 24 saat saatlik; uzun dönemler günlük seriler kullanır. Başlangıç dahil/bitiş hariç aralık, İstanbul tarihi, tam tutulan yanıt toplamları, watermark, sorgu zaman sınırı ve aralarda yazıcıya fırsat veren kısa okuma partileri korunur. Tarihsel olmayan sayaçlar ve canlı kaynak ölçümleri seçilen geçmiş dönem diye etiketlenmez.
- 🔴✓ Üst ana başlık yaklaşık 62 px, mobilde 60 px yüksekliğe alındı. Kontrol merkezi ve admin aynı satırda; ayırıcı çizgi hesap düğmesinin hemen altında. Hesap/açılır sistem menüleri ile diğer sayfaların pencereleri korunur. İlk tarayıcı denemesinde eski hesap düğmesi min-height kuralının boşluk bıraktığı görüldü; gerçek CSS hizası düzeltildi, ölçüm beklentisi gevşetilmedi.
- 🔴✓ Yerel 19 dashboard/kaynak testi geçti. Son 1 saat sınırı, kısmi dakika, ay sonu/artık yıl, uzun dönem tam toplamları ve altı dönemin HTTP kabulü doğrulandı. Kaynak değişikliği yalnız yedi paket dosyası; RADIUS, sunucu GET/yetki katmanı, kaynak örnekleyici, policy, sertifika, Windows/GPO, native modül ve onaylı logo baytları değişmedi.
- 🔴✓ Sunucuda 148 dosyalı staging ve gerçek dev.24 kaynağına karşı koruma doğrulandı. Yazma/başlatma/HTTPS hatasında eski kaynak baytlarına dönüş, tekrarlı çalışma ve yalnız panel servisi sınırı izole kurulum probunda başarılı. Tam veri yedeği/izole veri restore yok; günlük zamanlayıcı korunur.
- 🔴✓ Son kaynakta 12 tarayıcı akışı, 595 temel/HTTP sınır testi (25 ortam atlaması), Linux hazırlık/systemd, Windows istemci/retry/native Kerberos ve sınırlı ağ probu başarılı. Masaüstü ve yerleşim akışının mobil ekranları incelendi. Altı dönem, tam toplamlar, dakika etiketleri, dört kartın eş renkleri, pembe üst çizgi yokluğu, pembe yoğunluk ölçeği ve admin altındaki çizgi mesafesi tarayıcıda ölçüldü.
- Canlı panel hâlâ dev.24; bu tur canlı kaynak veya servis değişikliği uygulanmadı. RADIUS PID 832810 ve broker PID 887154 aktif. Kurulumda yalnız panel servisi yenilenecek. Bekliyor: hash sabitlenmiş sudo kurulumu, DASHBOARD_POLISH_FINISHED koruma çıktısı ve Ctrl+F5 sonrası gerçek panel görünüm kabulü. Önceki fonksiyonel açık işler ve bağımsız fixture takibi kapanmaz; gerçek normal/debug EAP-TLS workflow'u kayıt anında çalışıyor.
- Kaynak 3baa25868bccf69b930b69404c37d69cc3746090; PR #56 birleştirildi (5176bc8ab20a276fa66ec46b4b10aedd437ab5c2). Manifest 6675255c6f19bd9febfbb55f90c381c46e985f1d4c9cdc7167187c1f4cc1b1ee. Yardımcı /home/segmentiq/authwire-dashboard-polish-20261023.py; SHA256 eca458dd011fa54e83d5a2a06745a39decb2beded8914541744aa8906f0d5545. Tarayıcı run40018273240/job120635888920/artifact12529870903; ZIP SHA256 64b1cd997e7600737ec76b3b47db9af2a9cf34b8ba32df3e702f859a6b7a1e1d. Teslim kaydı docs/checkpoints/2026-10-23-dashboard-polish-delivery.json.

## 🔴✓ dev.24 widget ve menü canlı kurulumu tamam — operatör görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün WIDGETS_FINISHED çıktısı 0.14.0-dev.24, kaynak 3a3f1e4e68bb0d832ee3b715dc69195df0a562cd kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrollerinin tamamı başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on iki API yolu üçer kez HTTP 200 döndürdü. Yeni /api/system/resources medyan 1,5 ms / en uzun 2,1 ms; dashboard medyan 3,9 ms / en uzun 4,7 ms. Son kontrollerde en uzun yanıt 34,7 ms.
- 🔴✓ RADIUS aktif, yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows değişmedi; günlük yedek zamanlayıcısı korundu. Yeni tam yedek/izole veri restore yapılmadı.
- Bu kayıt turunda ek kaynak değişikliği veya servis eylemi uygulanmadı. Canlı kurulum bekleme maddesi kapanmıştır. Bekliyor: Ctrl+F5 sonrası Widget Ekle/kaldırma, düzen ve yeni dikey menünün gerçek tarayıcı görünüm kabulü. Önceki bağımsız fonksiyonel açık işler bu sonuçla kapatılmaz.
- Kanıt: /var/lib/authwire-ui-updates/widgets-dev24-20261023T195448Z-6d4ad4fe. Makine okunur kayıt: docs/checkpoints/2026-10-23-widgets-live-result.json.

## 🔴✓ dev.24 widget kataloğu, kaynak kartları ve dikey menü — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Operatör dev.23 metalik siyah logoyu “logo oldu” diyerek kabul etti. Onaylı PNG ve çizgi geometrisi bu turda değişmedi; SHA256 677e49220d7ca57376735a9792b8067e8aaca223ee73806d91ff3dc1eb8d728e. Önceki logo görünüm kabulü bekleme maddesi kapanmıştır.
- 🔴✓ Yenile ve Düzenle yanına Widget Ekle; aramalı ve kategorili 16 kartlık katalog eklendi. Mevcut erişim/sertifika/grafik/sağlık kartlarının yanında CPU, RAM, AuthWire veri diski, sunucu çalışma süresi, son yedek ve CRL güncelliği seçilebilir. Kart üzerindeki × kaldırır; katalogdan geri eklenir ve tekrar ekleme engellenir. Tamamen boş dashboard kaydedilebilir ve katalogdan geri doldurulabilir.
- 🔴✓ Taşıma/boyutlandırma korunur. Düzen, görünür kartlar ve boyutlar hesaba özel tarayıcı kaydında saklanır; sunucular/tarayıcılar arasında eşitleme yoktur. Düzenleme sırasında Kaydet/Vazgeç çalışır; düzenleme dışında ekleme/kaldırma kaydedilir. Eski 10 kartlık kayıt sırası ve boyutlarıyla taşınır; yeni varsayılanda CPU/RAM/disk dahil 13 kart vardır. Önceden kaydedilmiş düzenler yeni kartları zorla almaz; Widget Ekle kullanılabilir.
- 🔴✓ Kaynaklar Linux konuğundan salt okunur ölçülür: CPU örnek farkı, kullanılabilir belleğe göre RAM, AuthWire veri dizininin bulunduğu dosya sistemi ve uptime. ESXi toplam kaynakları veya bütün disklerin toplamı diye gösterilmez. İlk CPU ölçümü yüzde uydurmaz; sonraki örneği bekler. İlgili kartlar görünürken yaklaşık 10 saniyede yenilenir; gizli sayfa/oturum/kartlarda kaynak sorgusu durur. API system.services görüntüleme yetkisi ister; hatalı/eksik tek ölçüm diğer kartları veya panel oturumunu bozmaz.
- 🔴✓ Altı ana başlık aynı kaldı; yuvarlak dizilim yerine ikonlu, yuvarlatılmış dikdörtgen satırlar ve başlık altında açılan alt menüler var. Sola kayan gizleme/açma, mobil perde, Escape, klavye ve yetkiler korundu. Koyu pembe #B5346B grafiklerde, kaynak göstergelerinde ve küçük vurgularda kullanıldı; lacivert/açık mavi yüzeyler korunur.
- 🔴✓ Son kaynakta 12 tarayıcı akışı, 593 temel/HTTP sınır testi (25 ortam atlaması), Linux hazırlık/systemd kontrolleri, Windows istemci/retry/native Kerberos ve sınırlı retry ağ probu başarılı. Yerel hedefli kaynak/dashboard 17 testi başarılı. Widget ekleme/kaldırma/boş düzen/yeniden yükleme/eski kayıt aktarımı, depolama hatası, ayrı hesap, kaynak 503 hatası, responsive ve hareket azaltma doğrulandı. Masaüstü, açık alt menü ve mobil ekranlar incelendi. Ret kartının gradient altında açık zemin rengi kontrast kontrolü için düzeltildi; test eşiği gevşetilmedi.
- 🔴✓ 148 kaynak dosyasında dokuz değişiklik var; sunucu değişikliği yeni salt okunur GET ve yetki izdüşümüyle sınırlı. RADIUS karar kaynağı, policy, sertifika ve Windows/GPO kaynakları aynıdır. Yeni iki dosyanın eklenmesi ve başarısız yazma/başlatma/HTTPS halinde kaldırılarak eski kaynağa dönülmesi, tekrarlı çalıştırma ve yalnız panel servisine müdahale sınırı izole kurulum probunda doğrulandı.
- 🔴✓ 10.35.50.246/segmentiq üzerinde 148 dosyalı staging ve kurulu dev.23 tabanına karşı kaynak koruması doğrulandı. RADIUS PID 832810 ve broker PID 887154 aktif; canlı kaynak/servisler bu turda değiştirilmedi. Yeni tam yedek/izole veri restore yapılmadı; günlük yedek ve CRL zamanlayıcıları korunacak. Sadece kaname-lab.service kurulumda yenilenecek.
- Bekliyor: hash sabitlenmiş sudo kurulumu, WIDGETS_FINISHED koruma çıktısı ve Ctrl+F5 sonrası operatör widget/menü görünüm kabulü. Canlı panel bu kayıt anında dev.23'tür. Bu tur bağımsız eski Windows retry fixture aralıklı hatasını veya B04/önceki fonksiyonel açık işleri kapatmaz; gerçek normal/debug EAP-TLS workflow'u kayıt anında çalışıyor ve başarılı diye gösterilmedi.
- Kaynak 3a3f1e4e68bb0d832ee3b715dc69195df0a562cd; PR #55 birleştirildi (3ea9186bc22f02ac2b3840ae4318bf31dce8bd39). Manifest b865b6e6a082e3575d93bee70560fbdac15f679ba90545e3fa9905c265a7d081. Yardımcı /home/segmentiq/authwire-widgets-20261023.py; SHA256 ebc80f64d4190745673f564bb4a49fcec6651002341d1a69b6152fad46d5e232. Tarayıcı run40014375608/job120622544924/artifact12528260823; ZIP SHA256 43cc339e90bcd1a2d65e53b5b4ed3444af3bb58650001a405cf778f36380b8c7. Teslim ve yeniden üretim kayıtları docs/checkpoints/2026-10-23-widgets-* altında.

## 🔴✓ dev.23 siyah logo canlı kurulumu tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün BLACK_LOGO_FINISHED çıktısı 0.14.0-dev.23, kaynak d4cc83e80eeff69c50732c11fecdd4eb3cae5b9f kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrolleri başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on bir API yolu üçer kez HTTP 200 döndürdü. Dashboard medyan 4,0 ms / en uzun 4,8 ms; son kontrollerin en uzun yanıtı 34,9 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Tam veri yedeği/izole restore yapılmadı; operatör tercihi korundu. Bu kayıt turunda ek servis müdahalesi uygulanmadı.
- Onaylı logonun şeklini operatör istemedikçe değiştirmeme talimatı docs/BRANDING.md içinde geçerli. Bekliyor: Ctrl+F5 sonrası gerçek panel görünüm kabulü. Kurulum sonucu bağımsız Windows retry fixture hatasını veya önceki fonksiyonel açık işleri kapatmaz.
- Kanıt: /var/lib/authwire-ui-updates/black-logo-dev23-20261023T191949Z-ae61e346. Makine okunur kayıt: docs/checkpoints/2026-10-23-black-logo-live-result.json.

## 🔴✓ dev.23 onaylı metalik siyah logo — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Operatör metalik siyah önizlemeyi onaylayıp uygula talimatı verdi. Beş çizginin tamamı aynı siyah metal yüzeyde; onaylı PNG dosyası yeniden üretilmeden, kırpılmadan veya yeniden örneklenmeden birebir depoya alındı. SHA256 677e49220d7ca57376735a9792b8067e8aaca223ee73806d91ff3dc1eb8d728e, 1254 × 1254. Git blob cfc942223bf90b477cb34d2437818f8731d5b888 yerel dosyanın Git özetiyle eşleşir.
- 🔴✓ Sol üst amblem, dairesel menü merkezi, giriş ekranı ve mevcut favicon aynı görseli kullanır. CSS çerçevesi yalnız çevredeki beyaz boşluğu görünüm alanında gizler; çizgilerin oranı, açısı, konumu ve aralıkları değiştirilmez. Mevcut yazı logosu ve panel davranışı korunur.
- 🔴✓ Sen istemedikçe şekli değiştirmeme talimatı docs/BRANDING.md içine kalıcı olarak kaydedildi. Yeni görsel üretimi/yeniden çizim/geometri değişikliği için yeni açık talimat gerekir.
- 🔴✓ Son kaynakta 12 tarayıcı akışı, temel/HTTP sınır testleri, Linux hazırlık ve sınırlı ağ probu başarılı; branding kontrolü HTTP üzerinden gelen PNG'nin tam SHA256 eşitliğini doğrular. Masaüstü/giriş ekranı görüntüleri incelendi. Windows istemci ve native Kerberos işleri geçti; bağımsız Windows retry fixture'ı deadline_rearmed durumunda süre sınırına takıldı (run40009749999/job120606771408). Tarihsel aralıklı fixture sorunu kapatılmadı; bu UI turunda Windows kaynakları değiştirilmedi ve bu iş başarılı diye gösterilmedi. Gerçek normal/debug EAP-TLS workflow'u bu kayıt anında çalışıyor.
- 🔴✓ 146 kaynak dosyasında değişen kapsam yalnız sürüm bilgileri, PNG, index.html ve styles.css. Sunucuda korunan dev.22 kaynakları ile salt okunur kontrol başarılı. PNG için atomik ikili yazma, PNG değiştirme/yazma/başlatma/HTTPS hatasında eski baytlara geri dönüş, tekrarlı çalışma ve yalnız panel servis sınırı izole kontrolde doğrulandı.
- Canlı sürüm hâlâ dev.22. RADIUS PID 832810 ve broker PID 887154 aktif, bu turda servis müdahalesi yapılmadı. Tam veri yedeği veya izole veri restore yapılmadı; günlük yedek/CRL düzeni korunur. Yalnız panel servisi kurulurken yenilenecek.
- Bekliyor: hash sabitlenmiş sudo kurulumu, BLACK_LOGO_FINISHED koruma çıktısı ve Ctrl+F5 sonrası gerçek panel görünüm kabulü.
- Kaynak d4cc83e80eeff69c50732c11fecdd4eb3cae5b9f; PR #54 birleştirildi (e90602d320030671eb184061c0b18581a5baef23). Manifest b4eb90e5b92082fee42db7bd8cbb97a7b315298353b7aab958f741b44b818a13. Yardımcı /home/segmentiq/authwire-black-logo-20261023.py; SHA256 65ee734e477f8d91c22f657c513b0d5248db33d2f739e69038982a67a7ba4e63. Tarayıcı run40009749994/job120606771139/artifact12525687825, arşiv SHA256 5e0b443c090de6ed076e4141e38254c0d0f010ee70459b898b49dfd7fe8c3983.

## 🔴✓ dev.22 canlı kurulum ve koruma kontrolleri tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün CLEAN_UI_FINISHED çıktısı 0.14.0-dev.22, kaynak e128a8a2426c0aa3e9a62f6544eef9dbeed388b4 kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrollerinin tümü başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on bir API yolu üçer kez HTTP 200 döndürdü. Dashboard medyan 4,0 ms / en uzun 5,0 ms; son kontrollerin en uzun yanıtı 38,5 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Operatör tercihi doğrultusunda tam veri yedeği veya izole restore yapılmadı. Bu kayıt turunda ek kurulum veya servis müdahalesi uygulanmadı.
- Bekliyor: Ctrl+F5 sonrası işaretli açıklama/arama alanlarının kaldırılması ve Düzenle düğmesinin Yenile sağındaki yerleşimi için operatör görünüm kabulü. Kurulum çıktısı yeni uç cihaz EAP-TLS kabulü sayılmaz; önceki açık işler ayrıca korunur.
- Kanıt: /var/lib/authwire-ui-updates/clean-ui-dev22-20261023T134813Z-dea4c1fb. Makine okunur kayıt: docs/checkpoints/2026-10-23-clean-ui-live-result.json.

## 🔴✓ dev.22 dashboard başlıklarını sadeleştirme — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün kırmızı işaretli ekranına göre üst başlık açıklaması, bölüm arama/Git alanı, Ağınızın erişim özeti başlığı ve açıklaması, ayrı düzenleme şeridi ve başarılı okumadaki dönem/saat dilimi metni kaldırıldı. Boş alan bırakılmadı; kaldırılan arama elemanlarının olay bağları ve kısayolu da temizlendi.
- 🔴✓ Düzeni düzenle → Düzenle olarak değişti; Yenile düğmesinin hemen sağına, aynı yükseklik/hizaya taşındı. Kaydet/Vazgeç/Varsayılan düzen aynı kontrol grubunda; mobilde gerektiğinde sarılır. Kart taşıma/boyutlandırma ve hesaba özel tarayıcı kaydı korundu. Veri/yetki hatalarının görünür geri bildirimi korundu.
- 🔴✓ Son kaynakta 12 tarayıcı akışı, temel/HTTP sınır testleri, Linux paket hazırlık, Windows istemci/retry/native Kerberos ve sınırlı ağ probu başarılı. Yeni yerleşim kontrolü işaretli elemanların kaldırıldığını, normal metin satırının boşluğuyla birlikte gizlendiğini ve Düzenle/Yenile sırasını aynı satırda doğrular. İlk turda düğme yükseklik farkı düzeltildi; iki eski sürüm beklentisi güncellendi. Gerçek normal/debug EAP-TLS CI workflow'u bu kayıt anında çalışıyor; başarılı diye işaretlenmedi ve açık fonksiyonel işler kapatılmadı.
- 🔴✓ 146 dosyalı kaynak paketinde yalnız altı UI/sürüm dosyası değişti. Kurulu dev.21 ile korunan kaynakların gerçek sunucuda salt okunur karşılaştırması başarılı. Kaynak yamasının yazma/başlatma/HTTPS hata geri dönüşü ve tekrarlı çalışma sınırı doğrulandı. Yalnız panel servisi yenilenecek.
- Canlı sürüm hâlâ dev.21; bu turda servis eylemi yapılmadı. RADIUS PID 832810, broker PID 887154 aktif ve korundu. Yeni tam veri yedeği/izole restore yok; günlük yedek düzeni korunuyor.
- Bekliyor: sudo kurulumu, CLEAN_UI_FINISHED koruma çıktısı ve Ctrl+F5 sonrası operatör görünüm kabulü.
- Kaynak e128a8a2426c0aa3e9a62f6544eef9dbeed388b4; PR #53 birleştirildi (77d33d867ee7f9586ecdbb82551c8a8e371f7661). Manifest 235829410e4bba7567add7f23652ef84d683dd8e80a74cff244a8a78a56f0aa7. Yardımcı /home/segmentiq/authwire-clean-ui-20261023.py; SHA256 0297dc87e8afec7a9beb50e414589e631e21790e754fb558ad54fcdf0b22c6b7. Tarayıcı run39950737870/job120404272748/artifact12500855407; arşiv SHA256 3b7dd05115f4c4b059ed73f9473332433233effd3cf322045938fe557018aef2.

## 🔴✓ dev.21 canlı kurulum ve koruma kontrolleri tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün MOTION_UI_FINISHED çıktısı sürüm 0.14.0-dev.21, kaynak ad21a77d99d5cf1cbf0d6a71cf933af2586092a6 kurulumunu doğruladı. Dosya, süreç, zamanlayıcı ve iş verisi kontrolleri başarılı.
- 🔴✓ Kurulum öncesi beş, sonrası on bir API yolu üçer kez HTTP 200 döndürdü. Dashboard medyan 5,3 ms / en uzun 7,0 ms; son kontrollerin en uzun yanıtı 37,4 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Operatör tercihi doğrultusunda tam veri yedeği veya izole restore yapılmadı. Bu kayıt turunda ek kurulum veya servis müdahalesi uygulanmadı.
- Bekliyor: Ctrl+F5 sonrasında küçük/büyüyen dairesel başlıklar, tıklanan başlık yanında açılan menü, tüm dashboard kartlarında hareket ve Düzeni düzenle / taşıma / boyutlandırma / kaydetme için operatör görünüm kabulü. Kurulum çıktısı yeni bir uç cihaz EAP-TLS testi sayılmaz; önceki açık işler ayrıca korunur.
- Kanıt: /var/lib/authwire-ui-updates/motion-ui-dev21-20261023T114222Z-26a7ac0d. Makine okunur kayıt: docs/checkpoints/2026-10-23-motion-ui-live-result.json.

## 🔴✓ dev.21 küçük dairesel menü ve hareketli, düzenlenebilir dashboard — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Ekteki iki gerçek ekran incelendi. Merkezden boşta uzanan fazladan yatay çizgi kaldırıldı; altı başlık 74 px dairelere alındı, okunaklı etiketler korundu. İmleç/klavye odağında hafif büyür. Alt menü, tıklanan başlığın gerçek ekran konumuna göre yanında; dar alanda altında ve ekran sınırlarında açılır. Kısa ekranlarda yukarı sabitleyen eski kural geçersiz kılındı.
- 🔴✓ Dashboard’un 10 bilgi kartı tek düzenlenebilir alanda: fareyle veya klavyeyle taşıma, sağ alt köşe/oklarla genişlik ve yükseklik ayarı, Kaydet, Vazgeç ve Varsayılan düzen. Yalnız konum/boyut hesabın ID’sine özel tarayıcı depolamasında saklanır; cihazlar/tarayıcılar arasında sunucu eşitlemesi yoktur. Bozuk kayıt reddedilir; depolama hatası görünür ve taslak korunur. Dar ekranda tek sütun; hesap çıkışında ekrandaki düzen sıfırlanır.
- 🔴✓ Gerçek verilerle SVG alan/çizgi grafiği, odaklanabilir veri noktaları ve ipuçları, dilim/legend etkileşimli halka grafiği; tüm kartlarda imleci takip eden ışık/derinlik, yükselme, bar/yoğunluk/sağlık/satır tepkileri. Halka dilimlerinin merkez hizası ve grafik/legend boşluğu görsel kontrolde düzeltildi; açılış animasyonu tamamlandıktan sonra geometrik sınır kontrolü eklendi. Hareket azaltma tercihi desteklenir. Sayaçlar rastgele veya sahte canlı oturum verisine çevrilmedi.
- 🔴✓ Son kaynakta 12 tarayıcı akışı başarılı; yeni akış on kartın hover/klavye/fare taşıma-boyutlandırma, kayıt/reload, ayrı hesap, vazgeç/varsayılan, bozuk/engelli depolama, mobil menü ve 390/768/1366/1920 genişliklerini doğrular; sunucu mutasyonu sıfır. Foundation: 586 test, 25 ortam atlaması. Yerel hedefli 113 test, 7 ortam atlaması. Linux paket hazırlık, Windows istemci/retry, native Kerberos ve sınırlı ağ probu kontrolleri başarılı. Bağımsız normal/debug gerçek EAP-TLS workflow'u bu kayıt anında çalışıyor; başarılı diye işaretlenmedi. Önceki B04/fixture kayıtları kapatılmadı.
- 🔴✓ 146 üretim dosyasında yalnız altı UI/sürüm dosyası değişti. Sunucuda gerçek kurulu dev.20 tabanı ve korunan kaynaklarla salt okunur karşılaştırma başarılı. Kurulum yaması yazma, başlatma ve HTTPS hatalarında önceki kaynak baytlarına döner; tekrarlı çalıştırma servis eylemi yapmaz. Sadece kaname-lab.service yenilenir. RADIUS/broker, kurallar, sertifikalar, Windows/GPO, native modül ve yedek/CRL zamanlayıcıları değişmez.
- Canlı kurulum henüz yapılmadı: panel dev.20, PID 950471; RADIUS PID 832810, broker PID 887154 korundu. Yeni tam veri yedeği/izole restore alınmadı; operatör tercihi ve günlük yedek düzeni korundu.
- Bekliyor: hash sabitlenmiş sudo kurulumu, MOTION_UI_FINISHED koruma çıktısı, Ctrl+F5 sonrası operatör görünüm ve düzenleme kabulü. Bu UI çalışması önceki fonksiyonel yol haritası veya gerçek uç cihaz kabulü yerine geçmez.
- Kaynak ad21a77d99d5cf1cbf0d6a71cf933af2586092a6, PR #51 ve son grafik boşluk düzeltmesi PR #52 birleştirildi (son merge cf383759cf1a82ce11027f792bc74adefdc7ba53). Manifest 7b9582ee11402e4d8e7f1bee0130cdee714f9c53c2eb76f448782fc0e37df669. Yardımcı /home/segmentiq/authwire-motion-ui-20261023.py, SHA256 a31e0595193bbda1df4fa37c540d91913fe9b4d20d1753116fcb1dcfb4ce68f2. Son tarayıcı run39947507985/job120393657515/artifact12499570131, arşiv SHA256 0bcc2cf1a0f48cd3e0ea4bd55a6fa09a21a481c14cd3edf834f720b3973df5b3. Teslim kaydı docs/checkpoints/2026-10-23-motion-ui-delivery.json.


## 🔴✓ dev.20 canlı kurulumu ve koruma kontrolleri tamam — görünüm kabulü bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün gerçek CENTRAL_UI_FINISHED çıktısı dev.20 kurulumunu doğruladı. Kaynak adf0c0c6333d8930bc48af3f892371d7cd2526be; dosya, süreç, zamanlayıcı ve iş verisi kontrollerinin tümü başarılı.
- 🔴✓ Kurulum öncesinde beş, sonrasında on bir API yolu üçer kez HTTP 200 döndürdü. Son kontrollerde en uzun yanıt 38,4 ms; dashboard medyanı 5,7 ms, en uzun yanıtı 6,5 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; PID 832810 korundu. Broker PID 887154 korundu. Kurallar, sertifikalar ve Windows kaynakları değişmedi; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Operatör tercihi doğrultusunda yeni tam veri yedeği veya izole restore yapılmadı. Bu kayıt turunda sunucuya ek kurulum veya servis müdahalesi uygulanmadı.
- Bekliyor: Ctrl+F5 sonrası yeni dairesel menü, gizleme/açma, kimlik tabloları ve gölgeli bölümlerin operatör görünüm kabulü. Kurulum doğrulaması yeni bir gerçek uç cihaz testi değildir; önceki fonksiyonel yol haritası, açık hatalar ve henüz sonuçlanmamış bağımsız testler bu sonuçla kapatılmadı.
- Kanıt: /var/lib/authwire-ui-updates/central-ui-dev20-20261023T101912Z-89975f7c. Makine okunur kayıt: docs/checkpoints/2026-10-23-central-ui-live-result.json.


## 🔴✓ dev.20 sade mavi panel ve dairesel menü — kaynak/test tamam; canlı kurulum bekliyor (23 Ekim 2026)

- 🔴✓ Operatörün Aruba Central referansına göre açık gri zemin, beyaz gölgeli bölümler, açık mavi #DDEAF0 seçim yüzeyleri ve lacivert #1D4D73 vurgular hazırlandı. Onaylı altın/antrasit Λ/W logosu korundu; üçüncü taraf ürün kodu veya görsel varlığı kopyalanmadı.
- 🔴✓ Altı dairesel ana başlık: Genel bakış, Erişim, Sertifikalar, RADIUS, Kayıtlar ve Sistem. Alt seçenekler tıklanınca açılır. Sol menü sola kayarak gizlenir, çalışma alanı genişler; masaüstü gizleme tercihi hatırlanır. Mobilde perde, Escape ve klavye odak davranışları bulunur. Mevcut görünürlük/yazma yetkileri korunur.
- 🔴✓ Kullanıcılar, gruplar ve bilgisayarlar sekmelerinde hizalı tablolar, sınırlı genişlikte arama, sayaçlar ve 100 kayıtlık sayfalama var. Alanlar mevcut AD kataloğundan gelir: ad, hesap adı, hesap durumu/grup türü, SID ve üyelik/kuralda kullan işlemi. AD hesap durumu canlı ağ oturumu olarak sunulmaz; bilinmeyen MAC/IP/son oturum verisi uydurulmaz.
- 🔴✓ Ayrı tarayıcı kontrolünde menüyü gizleme ve tercihi hatırlama, alt menü klavyesi, liste başlıkları, arama/sayfalama, üyelik penceresi, XSS metin güvenliği ve 390/768/1366/1920 genişlikleri doğrulandı; bu akışta değişiklik yapan API isteği sıfır. Son kaynak üzerinde 11 tarayıcı akışının tamamı başarılı: ana panel/roller, dashboard, policy modalı ve tablo işlemleri, kurulum, işlem geçmişi, erişim kayıtları, oturum, cihaz dağıtımı, envanter ve servisler. Kural satırındaki Escape işleminin menüye odak kaçırması da düzeltilip bu turda doğrulandı.
- 🔴✓ Yerel hedefli 113 Python testi tamamlandı (7 ortam atlaması). Tam yerel koşuda eksik tarihsel test fixture dosyası beş kurulum koruma testini engelledi; dosya depodan alındı ve bu beş test tekrar başarılı oldu. Kaynak üretim hatası sayılmadı. CI tam foundation kontrolü başarılı: 586 test, 25 ortam atlaması. Linux hazırlık, Windows/native Kerberos istemci ve sınırlı retry ağ probu kontrolleri de başarılı. Bu UI turu tarihsel B04 veya Windows fixture flakiness kayıtlarını kapatmaz.
- 🔴✓ Küçük kurulum yaması yazma, panel başlatma ve HTTPS kontrol hatalarında önceki kaynak baytlarına döner; tekrarlı çalışma servis eylemi yapmaz. Yalnız panel servisini durdurup başlatabilir. RADIUS/broker yeniden başlatma veya host güç eylemi içermez.
- 🔴✓ 146 paket dosyasında değişen üretim kapsamı yalnız sürüm bilgileri ve üç panel dosyasıdır: kaname/__init__.py, pyproject.toml, index.html, app.js, styles.css. Sunucuda salt okunur kaynak kontrolü başarılı; kurulu dev.19 ile korunan kaynaklar aynı. Kurallar, sertifikalar, Windows/GPO istemcisi, yerel modül ve broker kodu değişmedi.
- Bekliyor: sudo ile canlı dev.20 kurulumu ve operatör görünüm kabulü. Canlı panel bu hazırlık sırasında dev.19'da; RADIUS PID 832810, broker PID 887154 korundu. Yeni tam yedek/izole restore yapılmadı; günlük yedek zamanlayıcısı değiştirilmedi. Önceki fonksiyonel yol haritası ve açık hata kayıtları korunur.

- Kaynak adf0c0c6333d8930bc48af3f892371d7cd2526be; PR #50 birleştirildi (40e244918e195fdce54e9c1f5c10a91f89953698). Manifest 7b50fadd7d66881a88bb360ef004343b8d4e9f6e8a0641ac448454baa08c1db2. Root yardımcı /home/segmentiq/authwire-central-ui-20261023.py, SHA256 799b7fac3af3f4e6ef08162aa3c5d4e29b1e4dbc349bc9180578982240e37b98. Son tarayıcı run39937607414/job120360887973/artifact12494138788, arşiv SHA256 f8442ba148cce4111ad967c5c5d3b6efbe850644bd3e59d7f52705f3c019f8ac. Normal/debug gerçek EAP-TLS protokol workflow'u bu kayıt anında hâlâ çalışıyor; sonucu başarılı diye işaretlenmedi. Çalışan sunucuda gerçek uç cihaz veya hizmet güç eylemi yapılmadı.


## 🔴✓ dev.19 dashboard canlı kurulumu doğrulandı — görünüm kabulü bekliyor (22 Ekim 2026)

- 🔴✓ Operatörün paylaştığı gerçek DASHBOARD_FINISHED çıktısına göre dev.19 aktif. Dosya, çalışan RADIUS süreci, zamanlayıcılar, iş verisi ve planlanan broker geçişi kontrolleri başarılı.
- 🔴✓ Güncelleme öncesinde beş, sonrasında on bir API yolu üçer kez HTTP 200 döndürdü. Yeni /api/dashboard?period=7d yanıtları 4,9 ms medyan / 5,1 ms en uzun süreyle başarılı; tüm son kontrollerde en uzun yanıt 36,9 ms.
- 🔴✓ RADIUS aktif ve yeniden başlatılmadı; çalışan süreç korundu. Broker planlandığı gibi 858994 → 887154 geçti. Kurallar, sertifikalar, Windows kaynakları ve yerel RADIUS modülü değişmedi; servis kontrol veya güç eylemi uygulanmadı.
- 🔴✓ Tam veri yedeği alınmadı; günlük yedek zamanlayıcısı korundu. Bu kayıt turunda yeniden kurulum veya servis müdahalesi yapılmadı.
- Bekliyor: Ctrl+F5 sonrası operatörün dashboard görünümünü, dönem seçimlerini ve kartlardan detaylara geçişi kabul etmesi. Gerçek uç cihaz kabulü ayrıca bekliyor; API başarısı yeni bir VV06 EAP-TLS bağlantısı sayılmaz. Önceden açık hata ve yol haritası maddeleri bu kurulum sonucuyla kapatılmadı.
- Kaynak: operatörün canlı kurulum çıktısı; kanıt dizini `/var/lib/authwire-ui-updates/dashboard-dev19-20261022T185325Z-c7455f87`. Makine okunur kayıt: `docs/checkpoints/2026-10-22-dashboard-live-result.json`.

## 🔴✓ dev.19 erişim dashboard’u geliştirildi, test edildi ve sunucuda hazırlandı — canlı kurulum bekliyor (22 Ekim 2026)

- 🔴✓ Operatörün onayladığı Velzon yerleşim yaklaşımı, AuthWire'ın mevcut krem/lacivert/gökyüzü/kiremit renkleri ve Λ/W logosuyla yeniden uygulandı. Şablonun ticari kodları veya varlıkları kopyalanmadı; yerel HTML/CSS/JS ve SVG kullanıldı.
- 🔴✓ Ana ekranda kabul/ret sayaçları, geçerli ve 30 gün içinde dolacak cihaz sertifikaları, zaman grafiği, mevcut NAS tanımından kablolu/kablosuz/bilinmeyen dağılımı, ilk altı switch/AP, gün-saat yoğunluğu, son sekiz sunucu yanıtı ve sistem sağlığı bulunuyor. 24 saat / 7 gün / 30 gün seçimi var. Doğrulama yanıtı, bağlı cihaz ve canlı oturum sayısı olarak sunulmuyor.
- 🔴✓ Kabul/ret kartları ve NAS satırları erişim kayıtlarını kesin zaman aralığı ve aynı kayıt watermark'ı ile açıyor. Sertifika kartları sertifika listesine gider; liste sayfalıdır. Kimlik ve kaynak eksikse tahmin üretilmez; veri yok / yetki yok / alınamadı durumları ayrıdır.
- 🔴✓ Yeni GET /api/dashboard bölümleri mevcut audit.events ve certificates.authority yetkileriyle süzülür; NAS adları/sınıflaması için network.radius gerekir. Sorgular salt okunurdur. Değiştirilemeyen olay ID sınırıyla kısa okuma parçaları kullanılır; uzun bir okuma transaction'ı tutulmaz. RADIUS karar yolu bu modülü çağırmaz.
- 🔴✓ Mevcut servis durumuna, sabit root sahipli yedek durum dosyalarından yalnız doğrulanmış durum alanlarını döndüren okuma özeti eklendi. Arşiv içeriği, yollar, anahtarlar veya komut girdisi döndürülmez. Bu gösterge arşivin şimdi yeniden doğrulandığı, sunucu dışı kopya veya tam açılış geri yükleme testi yapıldığı anlamına gelmez. CRL güncelliği/imzası çalışan dosyadan okunur.
- 🔴✓ Son kaynak için 586 foundation testi tamamlandı (25 ortam atlaması); bunun içinde 10 dashboard testi var. On tarayıcı akışı, mobil/masaüstü taşma, filtreli geçiş, oturum çıkışında bekleyen yanıtın atılması ve veri hatasında oturumun korunması başarılı. Gerçek normal/debug EAP-TLS/VLAN, Windows istemcisi, yerel Kerberos, yeniden deneme ve sınırlı ağ probu kontrolleri de başarılı.
- 🔴✓ Ayrı geçici 100.000 kayıt / 38,12 MB testinde özet 0,517 saniyede hesaplandı; eşzamanlı 21 yazma başarılı, yazma hatası yok. Bu bir test ortamı ölçümüdür, canlı yük garantisi değildir.
- 🔴✓ Kurulum yardımcısının iptal/geri dönüş, tekrarlı çalışma, eski broker dosya modu, yeni API'yi yalnız kurulumdan sonra kontrol etme ve korunan kaynak değişimini reddetme kontrolleri geçti. 146 kaynak dosyası son Git commit'iyle birebir karşılaştırıldı. Sunucuda salt okunur gerçek kaynak ön kontrolü başarılı.
- Son test turundaki Windows deadline_rearmed aralıklı fixture hatası bir tekrar çalışmasında geçti; eski açık hata kaydı kapatılmadı. Tarayıcının ilk çalışması uygulama testine ulaşmadan Ubuntu paket aynasının yavaşlığıyla zaman aşımına uğradı; tek tekrar çalışması başarılı. B04 ve diğer önceden açık işler ayrıca korunur.
- Canlı durum: hâlâ dev.18; panel PID 859017, RADIUS PID 832810 ve broker PID 858994 değişmedi. Bu turda root kurulumu, servis veya güç eylemi uygulanmadı. Tam veri yedeği/izole geri yükleme yapılmadı; günlük zamanlayıcı değişmedi.
- Bekliyor: operatörün sudo komutunu çalıştırması, DASHBOARD_FINISHED canlı koruma çıktısı ve Ctrl+F5 sonrası görünüm kabulü. Çalışan RADIUS sürecinin korunması zorunlu; kurulum yalnız panel ve brokerı kısa süreli yeniden başlatacak. Mevcut kurallar, sertifikalar, Windows istemcisi, GPO ve yerel RADIUS modülü değişmeyecek.
- Kaynak `ae79998d7ff1afd6777e81cc05bca5a5e389ce2e`; PR #49 birleştirildi. Manifest `ccc2104a9d52422e0dd2670cea92d8de7158bb8ca457dd8b60123863b59842ec`. Kurulum dosyası `/home/segmentiq/authwire-dashboard-20261022.py`, SHA256 `7f64e7ef2ac9c82124a807d0ddfc1ca917359832b37262e8ebc8a167eb4aef2e`. Kalıcı teslim kaydı: `docs/checkpoints/2026-10-22-dashboard-delivery.json`.

## 🔴✓ dev.18 canlı kurulum ve koruma kontrolleri tamam — görünüm kabulü bekliyor (22 Ekim 2026)

- 🔴✓ Operatörün paylaştığı gerçek ACCOUNT_MENU_FINISHED çıktısı dev.18 kurulumunu doğruladı; kaynak sürümü `21ea9b2e994b95fae9f38e0099ec29f8bf18f644`. Dosya, çalışan RADIUS süreci, zamanlayıcılar, iş verisi ve planlanan broker geçişi kontrolleri başarılı.
- 🔴✓ RADIUS aktif; PID 832810 korundu ve yeniden başlatılmadı. Servis kontrol brokerı planlandığı gibi 149955 → 858994 geçti.
- 🔴✓ Kurallar, sertifikalar, Windows kaynakları ve yerel RADIUS modülü değişmedi. Güç veya servis kontrol eylemi uygulanmadı. Tam veri yedeği alınmadı; günlük yedek zamanlayıcısı korundu.
- 🔴✓ Güncelleme öncesi beş, sonrası on API yolu üçer kez HTTP 200 döndürdü; yeni /api/system/power dahil, bildirilen en uzun yanıt 34,7 ms.
- Bekliyor: Sil butonunun, sağ üst hesap menüsünün ve Sistem alt menüsünün operatör tarayıcı kabulü. Gerçek sunucu yeniden başlatma/kapatma yürütme kabulü ayrıca bekler; durum sorgusu bu eylemlerin testi sayılmaz.
- Bu kayıt operatörün canlı kurulum çıktısına dayanır. Bu kayıt turunda sunucuda yeni kurulum, servis yeniden başlatma veya güç eylemi yapılmadı. Önceki uç cihaz kabulü, kullanıcı kimlik doğrulaması yol haritası ve açık hata kayıtları bu sonuçla tamamlanmış sayılmaz.
- Kanıt: `/var/lib/authwire-ui-updates/account-menu-dev18-20261022T173757Z-ee699f1c`; makine okunur sonuç: `docs/checkpoints/2026-10-22-account-menu-live-result.json`.

## 🔴✓ dev.18 Sil / hesap ve Sistem menüsü kaynak-test-hazırlık tamam — canlı kurulum bekliyor (22 Ekim 2026)

- 🔴✓ Operatör dev.17 için “Görünüyor şu an için sorun yok” diyerek önceki tablo/modal/kayan kimlik panelinin görünümünü kabul etti. dev.17 operator_browser_acceptance_pending artık false olarak takip edilir. Bu kabul yeni gerçek VV06 bağlantısı veya kullanıcı kimlik doğrulaması testi sayılmaz; gerçek uç kabulü ayrı bekler.
- 🔴✓ Erişim kuralı satırında Düzenle → Etkinleştir/Devre dışı bırak → Sil sırası. Sil adı gösteren onay penceresiyle açılır; onay anında kullanıcıya gösterilen policy listesinin revizyonu sabitlenir. İptal yazmaz, eşzamanlı yeni kaydı ezmez; yalnız seçilen kayıt filtrelenir.
- 🔴✓ Kullanıcı adı/ok sağ üst başlığa taşındı; dağınık alt hesap çubuğu kaldırıldı. Menünün sırası ürün/sürüm, Sistem, Parolamı değiştir, Çıkış yap. Sistem alt menüsü masaüstünde sola açılır, hover/click ve klavye destekler; dar ekranda menünün içinde açılır. Escape/dış tıklama/çıkış temizliği var. Bildirim konumu hesap menüsünü kapatmayacak şekilde alta alındı.
- 🔴✓ Ayrı system.power kaynağı eklendi. Mevcut Custom servis yetkisi güç yetkisine dönüşmez; varsayılan none. SuperAdmin tam, ReadOnly salt okuma. POST yalnız gerçek oturum, write izni, Origin/CSRF, açık onay ve audit intent ile ilerler; bakım bearer token'ı host eylemi yapamaz.
- 🔴✓ Root broker yalnız reboot/poweroff enum'larını kabul eder; UUID türetilmiş geçici systemd timer üzerinden sabit komut planlar. İstemci komut/yol/unit/argüman/deadline seçemez. Aynı talep yeniden çalıştırılmaz; belirsiz talep otomatik tekrarlanmaz. Planlama kabulü gerçek reboot/shutdown başarısı sayılmaz. Yeni boot kimliği gözlendiğinde yalnız boot-observed kaydı tutulur.
- 🔴✓ PR48 birleştirildi: 675c1645510f02c791b86cd49ce3f14577f534ca. Test edilen kaynak21ea9b2e994b95fae9f38e0099ec29f8bf18f644, sürüm0.14.0-dev.18;143paket dosyası Git blob SHA'larıyla karşılaştırıldı, fark yok. RADIUS/policy motoru, CA/sertifika, Windows client/installer ve native modül kaynakları değişmedi.
- 🔴✓ Tüm ilgili CI kontrolleri başarılı: foundation576 test/25ortam atlaması (14yeni host power broker/HTTP testi),9tarayıcı akışı, Linux LDAP58test/systemd, nativeKerberos, Windowsclient/retry ve gerçek normal+debugEAP-TLS. Bu tur Windows retry fixture'ının geçmesi tarihsel flakiness'in kök nedeninin giderildiği anlamına gelmez; önceden açık B04ve fixture bulguları ayrı kalır.
- 🔴✓ Gerçek hardened broker sandbox'ından systemd-run geçici timer oluşturma yolu disposableCI'da doğrulandı; **güç komutu sabit fixture marker/touch komutuyla değiştirilmişti**. host_power_timer_sandbox_verified=true, host_reboot_or_poweroff_executed=false, customer_units_used=false. Canlı sunucu veya CI host'u test için kapatılmadı/yeniden başlatılmadı.
- 🔴✓ Tarayıcı ekranları incelendi: hesap menüsü ve sola açılan Sistem alt menüsü, tablo Sil sırası. Artefakt12444887571/run39822663927 SHA256921e4cf8bf3997627930ed7c640db5aa068a00526bafedc41191a09d346d52f9. Sil iptal/kayıt/eşzamanlı değişiklik reddi, menü klavye, güç onayı/iptali/readonly/hata tekPOST kontrolü geçer.
- 🔴✓ Küçük root yaması disposable testte kaynak yazma, broker start, HTTPS health hatalarında önceki kaynak+broker'ı geri yükler; broker mode korunur, idempotans geçer. Güncelleme öncesi yeni power rotası çağrılmaz; sonrası200zorunlu. Bu testler RADIUS veya host power komutu çalıştırmaz.
- Sunucu salt okunur kontrolde dev.17kaynağıyla birebir aynı, RADIUS PID832810/panel832806/broker149955aktif; systemd-run mevcut. Hazırlık dosyaları /home/segmentiq/authwire-stage-dev18-21ea9b2e994b,143dosya manifest SHA2560ea4273dc028458b415bd2ff97cb6e10da3db4dc175a2a16736525fce0df6593 ile doğrulandı. Root dosya /home/segmentiq/authwire-account-menu-20261022.py SHA25686781cb73c2c936d01b808a5176d013b9e25be4d93a323a1a25bd77f69d7866a.
- **Bekliyor:** tek sudo komutuyla canlı dev.18 kurulumu; ACCOUNT_MENU_FINISHED koruma sonucu; operatör görünüm ve gerekirse kontrollü host power saha kabulü. Kurulum yalnız panel ve broker'ı yeniden başlatır; RADIUS PID/units/native modül, kurallar, sertifikalar, Windows ve timer'lar korunacak. Gerçek reboot/poweroff çalıştırılması bu teslimat/kurulumun parçası değil.
- Operatörün tam yedek almama tercihi sürüyor: bu UI değişikliğinde full data backup/izole restore yok; günlük backup timer korunacak. Hata geri alma yalnız küçük incelenmiş kaynak+broker dosyalarını bellekteki önceki baytlardan yapar. Kalıcı geri alma kaynak referansıe2ad6634c853ae39750822123dca87d259276ca1/dev17stage. Kalan asıl yol haritası ve DNS kapsam dışı kararı değişmedi.

## 🔴✓ dev.17 kural modalı canlı kurulum ve koruma kontrolleri tamam — 22 Ekim 2026; görünüm/VV06 kabulü bekliyor

- Operatör düzeltmiş kurulum dosyasını güncel d74b2f887db66f6ba6535e1f7d0c8037e1bb8b478ba6817a597f245f8c811580 hash'iyle çalıştırdı ve POLICY_MODAL_FINISHED / verified=true çıktısını iletti. Son doğrulanmış canlı sürüm **0.14.0-dev.17**, kaynak8f2a3971d00c849fc8fdee168250d7da1e763a41. Kanıt dizini /var/lib/authwire-ui-updates/policy-modal-dev17-20261022T163108Z-d08a37ff. Kabul operatörün gerçek çıktısına dayanır; bu kayıt turunda ek canlı işlem yapılmadı.
- 🔴✓ Önkontrol mevcut5rotada200; sonkontrol yeni /api/policies/labels dahil9rotanın her birinde üç kez200. İlk denemeyi durduran yanlış kontrol sırası düzeltilmiş haliyle canlıda geçti. Sonkontrolde en yüksek gözlenen yanıt35.5ms.
- 🔴✓ files, broker_process, radius_listener, timers, business_state ve planned_radius_transition tümütrue. RADIUS planlandığı gibi bir kez yeniden başladı (PID679309→832810) ve aktif. Broker süreci korundu; native modül, mevcut policy/VLAN, sertifikalar ve Windows kaynakları değişmedi.
- 🔴✓ Operatör tercihi korundu: full_data_backup_created=false; bu güncelleme için tam veri yedeği alınmadı. Düzenli yedek timer'ı korundu. İzole restore veya yeni tam yedek tamamlandı iddiası yok.
- **Bekliyor:** Ctrl+F5 sonrası Durum sütunu, Yeni Kural/Düzenle modalı ve sağdan kayan bilgisayar/kullanıcı/grup çoklu seçim panelinin operatör kabulü; VV06 ile yeni bir gerçek802.1Xbağlantı denemesi. RADIUS'un aktif olması gerçek cihaz kabulünün yerine sayılmadı. Mevcut kurallar bu kontrol için kendiliğinden değiştirilmedi.
- Kullanıcı kimlik doğrulaması/yol haritası ile daha önce açık Windows retry fixture ve B04 bulguları bu canlı UI kurulumu nedeniyle tamamlandı sayılmıyor. Önceki dev16ve başarısız ilk dev17deneme kayıtları aşağıda tarihsel kanıt olarak korunuyor.

## 🔴✓ dev.17 kurulum önkontrol düzeltmesi test edildi ve hazırlandı — canlı kurulum hâlâ bekliyor (22 Ekim 2026)

- Operatörün ilk denemesi /var/lib/authwire-ui-updates/policy-modal-dev17-20261022T162458Z-f2803231 dizininde PANEL_READ_CHECK/before sırasında durdu. Kurulum dosyası dev.17 ile eklenecek /api/policies/labels adresini dev.16 üzerinde çağırmıştı; 404 doğru yanıt, hatalı olan kurulum kontrol sırasıydı. Bu deneme başarılı veya geri alınmış güncelleme sayılmaz: kaynak yazma/servis durdurma aşamasına ulaşmadı.
- 🔴✓ Sonraki salt okunur kontrolde kurulu sürüm0.14.0-dev.16, önceki manifestteki141 kaynak dosyası birebir aynı, farklı dosya yok. RADIUS PID679309, brokerPID149955 ve panelPID802958aktif; CRL ve yedek timer'ları aktif. İnceleme servis eylemi çalıştırmadı.
- 🔴✓ Düzeltme yalnız kurulum dosyasında: before mevcut5 adresi kontrol eder; after yeni /api/policies/labels adresini de zorunlu200 olarak kontrol eder. Eksik yeni adresin404yanıtı güncelleme sonrasında hâlâ hatadır. Hata fazları panel_health_before / panel_health_after olarak ayrıldı. Ürün kaynağı, sürüm,142dosyalık aday manifest ve kural motoru değişmedi.
- 🔴✓ Üç disposable regresyon testi geçti: dev16önkontrol yeni adrese gitmez; dev17sonkontrol yeni adresi üç kez çağırır; sonkontrolde404güncellemeyi doğrulanmış saydırmaz. Önceki yazma/start/HTTPS hata geri alma ve idempotans testleri de yeniden geçti.
- Hazır dosya /home/segmentiq/authwire-policy-modal-20261022.py; **güncel SHA256 d74b2f887db66f6ba6535e1f7d0c8037e1bb8b478ba6817a597f245f8c811580**. Önceki6dca927d3705453dce89028c4561be83ee5bc1ed0bde24e4e58786596806f9f7değeri bu dosya için artık kullanılmamalı. Sunucuda dosya SHA'sı ve aday142dosya tekrar doğrulandı.
- **Bekliyor:** yeni hash'li sudo komutu, POLICY_MODAL_FINISHED koruma sonucu, panel görünüm kabulü ve VV06bağlantı kabulü. Bir planlı RADIUSrestart yalnız başarılı önkontrol sonrası uygulanacak. Tam veri yedeği veya restore eklenmedi.

## 🔴✓ dev.17 kural modalı, sağ kimlik paneli ve Durum sütunu — kaynak/test tamam; canlı kurulum bekliyor (22 Ekim 2026)

- 🔴✓ Karar sağında Durum sütunu; etkinlik rozeti Kural Adı hücresinden kaldırıldı. Altı başlık ve satır hücreleri hizalı.
- 🔴✓ Yeni Kural ve Düzenle altı alanlı modal açar: Kural Adı, Erişim Türü, Kullanıcı/Grup, VLAN, Karar, Etkin/Devre Dışı. Ortadaki TAMAM yalnız başarılı kayıt sonrasında kapatır; tek POST, revizyon/CSRF/RBAC korunur. Hata formu ve seçimleri korur.
- 🔴✓ Sağdan kayan, ana modalın bir kısmını görünür bırakan kimlik paneli: bilgisayar/kullanıcı/grup listesi, arama, 100 kayıtlık sayfalar, çoklu seçim, aramada seçimleri koruma. İç TAMAM forma aktarır; ×/Escape panelin kaydedilmeyen seçimlerini iptal eder. Dış ×/Escape kuralı kaydetmez.
- 🔴✓ Gelişmiş taslak arayüzü kaldırıldı. Kaydedilmiş eski taslaklar ve API'leri silinmedi; envanter arayüzü korunuyor.
- 🔴✓ Seçilen doğrudan hesap SID'si yalnız sertifika kaydıyla eşleşen ve canlı AD'den tekrar okunan account.sid ile değerlendirilir. Mevcut grup eşleşmesi, iptal/kapalı hesap/AD erişimi ve NAS/EAP sınırları korunur. Simülasyon endpoint'i account_sid kabul etmez. **Kullanıcı kimlik doğrulaması ve kullanıcı+bilgisayar yol haritası tamamlandı sayılmaz**; makine EAP-TLS oturumu oturum açan kullanıcıya ait kanıt değildir. Yeni kullanıcı kapsamlı kurallar kullanıcı kimlik doğrulaması gerektirir; mevcut kural kısıtları düzenlemede korunur.
- 🔴✓ PR47 birleştirildi: a6864a11e4aabdf3db505d4e655fa58f42397d5e. Test edilen kaynak8f2a3971d00c849fc8fdee168250d7da1e763a41; 142 paket dosyası Git blob'larıyla karşılaştırıldı, fark yok. Sürüm0.14.0-dev.17.
- 🔴✓ Foundation562 test/25 ortam atlaması; 9 tarayıcı akışı; Linux LDAP/systemd58 test ve gerçek kurulum kontrolleri; native Kerberos/Windows istemci; normal+debug gerçek EAP-TLS ve35 runtime testi geçti. Tarayıcı artefaktı12439733775, run39811987895, SHA256 20896cb2c54ca21f29b6a70a3c84e8ef5834c08717c95c495a45e65e8f756d96. Masaüstü tablo, modal ve kayan panel görsel olarak incelendi.
- **Açık test bulgusu:** Windows retry fixture'ındaki önceden takip edilen deadline_rearmed / automatic recovery did not finish hatası bu turda da tekrarlandı (job119940410459 ve119941861158). Windows istemci/installer/GPO kaynakları değişmedi. Hata bu UI çalışmasında çözülmüş veya Windows retry kabulü yeniden tamamlanmış sayılmıyor. B04 kilitlenme bulgusu da ayrı açık kalır.
- 🔴✓ Küçük root güncellemesinde yazma, servis start ve HTTPS sağlık hatalarından kaynak geri alma ile idempotans disposable ortamda doğrulandı. Tam veri yedeği/izole restore çalıştırılmıyor; mevcut günlük yedek timer'ı korunacak. Bu tur yedek veya restore tamamlandı iddiası yok.
- Sunucuda hazırlanan kaynak /home/segmentiq/authwire-stage-dev17-8f2a3971d00c; manifest SHA256 5ca12d3077b7303da00f49039837a9e16d3e8697e5548d9461bc14e0957c344b. Root dosya /home/segmentiq/authwire-policy-modal-20261022.py; SHA256 6dca927d3705453dce89028c4561be83ee5bc1ed0bde24e4e58786596806f9f7.
- **Bekliyor:** operatörün tek sudo komutuyla canlı kurulumu; öncesi/sonrası koruma çıktısı; panelde modal/kayan panel kabulü; VV06 yeniden bağlantı kabulü. Doğrudan principal desteği için kurulum **bir kontrollü RADIUS yeniden başlatması** yapar; RADIUS PID korunacak denmiyor. Broker, unit/native modül, Windows kaynakları, mevcut policy/VLAN ve sertifikalar korunacak. Bu kayıtta canlı servis henüz durdurulmadı/yeniden başlatılmadı; son doğrulanmış canlı sürümdev.16.
- Kaynak geri alma referansı9f537bd50c358cc2c5f88235d141920c95d7a0e4 ve önceki dev16 hazırlık dizini korunuyor. Çalışma yüzdesi bu UI isteğiyle yeniden hesaplanmadı; kapsam dışı DNS ve bekleyen ana roadmap işleri aynen duruyor.

## 🔴✓ dev.16 erişim kuralları tablosu canlı kurulum ve koruma kabulü tamam — 22 Ekim 2026; operatör görünüm kabulü bekliyor

- Operatör POLICY_TABLE_UI_FINISHED/verified=true/version0.14.0-dev.16 çıktısını iletti. Küçük UI kaynak yaması canlı sunucuda başarıyla uygulandı. Kanıt dizini `/var/lib/authwire-ui-updates/policy-table-dev16-20261022T151018Z-1d8c260e`; kabul operatörün gerçek çıktısına dayanır. Bu kayıt turunda ek canlı işlem yapılmadı.
- 🔴✓ Dosya/PID/timer/business_state karşılaştırmaları tümütrue. RADIUS aktif, PID679309 ve brokerPID149955korundu; radius_restarted=false. Policy/VLAN, sertifikalar ve Windows kaynakları değişmedi. Düzenli yedek timer'ı korundu.
- 🔴✓ Operatörün yeni tercihi uygulandı: bu UI güncellemesinde **tam veri yedeği alınmadı ve izole restore çalıştırılmadı**. Kaynak geri alma referansı `d90947e265257ea83f2bd56ba3397198098e3f65` kayıtta tutulur; geri alma gerekirse yalnız kaynak değişikliği ele alınır, mevcut policy/veri geçmişe döndürülmez.
- 🔴✓ Önce5/sonra8 kimlikli yerel HTTPS API uç noktası üçer okuma, tümü200; kurulum sonrası en yüksek süre58.4ms. Panel teknik sağlık kontrolü başarılı.
- **Bekliyor:** operatör Ctrl+F5 ile dev.16ve Erişim kuralları sayfasındaki Yeni Kural/kısa arama, beş hizalı sütun ve satıra tıklayınca açılan iki işlem menüsünü gerçek tarayıcıda kontrol edecek. operator_browser_acceptance_pending=true; kurulum çıktısı tek başına görsel kabul değildir.
- Kalan işlevsel plan beklemede; bu UI işi94iş hesabına yeni işlevsel puan eklemez. Önceki açık bulgular ve kapsam dışı DNS mimarisi aynen korunur.
- [Canlı kurulum kanıt özeti](checkpoints/2026-10-22-policy-table-live-result.json).


## 🔴✓ Erişim kuralları tablo düzeni geliştirme ve teknik kabul tamam — 22 Ekim 2026; küçük canlı kaynak yaması bekliyor

- Operatörün iki referans görüntüsüne göre üstte **Yeni Kural**, hemen sağında kısa arama alanı; altında sırasıyla **Kural Adı / Erişim Türü / Kullanıcı/Grup / VLAN / Karar** başlıklı hizalı tablo hazırlandı. Kurala tıklanınca yalnız o satırın altında **Düzenle**, ardından etkinleştirme/devre dışı bırakma düğmesi açılır. Klavyeyle seçim desteklenir; arama yalnız görünür listeyi süzer, kural kaydetmez. Sütun değerleri mevcut policy alanlarından gelir. Genel panel paleti ve onaylı42°ΛuthWire logosu korunur.
- 🔴✓ PR46main'e `9dc908e1301bc6336038bbc880ab238b86aff04d` olarak birleştirildi. Ürün kaynağı `b3ae5cc655522faf43b642622af6f1f2cb0ddd62`; son test başı `e2de117598fe0b54ad60f16a2327953218056219` yalnız genel tarayıcı fixture'ında yeni kural adının açıkça girilmesini düzeltir. Beş ürün dosyası (üç arayüz, iki sürüm metaverisi) değişir; server/RADIUS/CA/Windows/GPO ve gerçek policy verisi değişmez. Sürüm0.14.0-dev.16.
- 🔴✓ Altı CI iş akışının tümü başarılı. Chromium dokuz akışı; beş sütun hizası,320pxkısa arama/Yeni Kural aynı sıra, aramada sıfır policyPOST, tek açık satır, klavye, iki işlem sırası, yeni form açılışı, mevcut VLAN/koşul/karar koruması, disabled değerlendirmesi, tek POST, başarısız kayıt/eskimiş revision/çakışma/RBAC/CSRF kontrolleri geçti.390/1366/1920genişliklerde sayfa taşması yok. Masaüstü `policy-table-desktop.png` doğrudan incelendi. UI run39799462916, artifact12435870660; ZIP SHA256 `c8176c633b239e8cf1f646e1ae16416b86f6d96233754b008f71d2f888f74a0a` doğrulandı.
- **Yeni açık operatör tercihi:**22Ekimde her görsel değişiklikte uzun tam veri yedeği/izole restore yapılmaması; istenmeyen son düzenlemenin sürüm kaydından geri alınması istendi. Bu tercih sonraki görsel işler için geçerlidir. Düzenli günlük yedek timer'ı değiştirilmez. Bu paket kabul edilmiş genel tam-yedek updater'ını çağırmaz; yalnız beş izinli kaynak dosyasını kısa panel duruşuyla değiştirir. RADIUS/broker korunur. Kurulum hatasında önceki kaynak byte'ları bellekte tutularak otomatik geri konur; veri/policy geri yüklenmez.
- 🔴✓ Yeni küçük kaynak yamasının gerçek geçici dosya testleri: geçerli yama/tam aday tekrarı, yazma ortası hatasında ve HTTPS sağlık hatasında önceki byte'lara geri dönüş, yalnız panel servis komutları geçti. RADIUS authorizer, Windows istemci/installer ve güncelleme aracı değişikliği reddedilir.141/141paket hash'i sunucuda doğrulandı. Stage `/home/segmentiq/authwire-stage-dev16-b3ae5cc65552`; manifestSHA256 `e93d89e835d8f722efd5c8cdda8cf84149903077cc650409df7cb66a6d055eec`. Yerel-sudo dosyası `/home/segmentiq/authwire-policy-table-ui-20261022.py`; SHA256 `5bb7a5958cf9718001fa09a08ce98d43e2c5012607eb11696eb2703a95fbb0bc`. Önceki kaynak d90947e265257ea83f2bd56ba3397198098e3f65 ve zaten mevcutdev.15paketi geri alma referansıdır.
- **Açık:** operatör Linux'ta hash ile sabitlenmiş yerel-sudo komutunu çalıştıracak; beklenen sonuç POLICY_TABLE_UI_FINISHED/verified=true/version0.14.0-dev.16. Ardından Ctrl+F5 ile gerçek tablo/satır altı menü kabulü yapılacak. Bu turda canlı kaynak değişikliği, servis restart, policy/sertifika eylemi, yeni tam veri yedeği veya restore yapılmadı. Mevcut işlevsel plan beklemede; bu görsel alt iş94iş hesabına yeni işlevsel puan eklemez.
- [Teslim ve test kanıtı](checkpoints/2026-10-22-policy-table-delivery.json), [incelenen küçük UI kurulum kaynağı](checkpoints/2026-10-22-policy-table-ui-patch.py).


## 🔴✓ dev.15 ΛuthWire logo canlı kurulumu, veri koruma ve izole geri yükleme kabulü tamam — 22 Ekim 2026; operatör görünüm kontrolü bekliyor

- Operatörün BRANDING_UPDATE_FINISHED çıktısı verified=true/version0.14.0-dev.15. Logo/marka paketi canlı Linux sunucusuna kuruldu. Kanıt dizini `/var/backups/authwire/scheduled/branding-dev15-20261022T135527Z-c18fb2e1`; orijinal başlangıç snapshot'ı kalıcıdır. Bu kabul operatörün gerçek kurulum çıktısına dayanır; bu kayıt turunda ek servis eylemi veya yeni saha testi yapılmadı.
- 🔴✓ RADIUS aktif; PID679309 ve brokerPID149955korundu, radius_restarted=false. Dosya/PID/timer/business_state karşılaştırmaları tümütrue. Windows istemcisi/GPO, policy/VLAN, CA/sertifikalar, native modül ve planlı yedek timer'ı korundu. Canlı policy eylemi yapılmadı.
- 🔴✓ Kurulum öncesi ve sonrası yeni veri yedeklerinin arşiv ve SQLite kontrolleri geçti. Son yedek `/var/backups/authwire/scheduled/authwire-scheduled-20261022T135850Z-f04757325236.tar.gz`, SHA256 `dd20d1b6a56f07d15dfff7d9c0b2da5d73a59e927091ec7b83e2de2826d9a78d`. Bu arşivden162dosyanın izole veri geri yüklemesi; byte/sahiplik/mod, veritabanı, CA/CRL, korumalı sırlar, anahtar eşleşmesi/imzalama, kayıt ve erişim geçmişi kontrolleri başarılı. İzole kopya kaldırıldı; tam appliance boot restore tamamlanmış sayılmaz.
- 🔴✓ Önce5/sonra8 kimlikli yerel HTTPS API uç noktası üçer kez okundu, tüm yanıtlar200. Kurulum sonrası en yüksek süre46.0ms. Panelin teknik sağlık kontrolü başarılı.
- **Açık kalan dar adım:** operatör Ctrl+F5 ile yenileyip dev.15, altın–antrasit amblem ve çizgisiz Lambda ile **ΛuthWire** yazımını giriş/menü/kontrol merkezinde kontrol edecek. branding_browser_acceptance_pending=true; canlı kurulum sonucu tek başına gerçek tarayıcı görünümü kabulü değildir.
- Kalan işlevsel işler ve önceki açık B04/Windows retry aralıklılığı bulguları beklemede kalır; DNS mimarisi kapsam dışıdır. Görsel güncelleme94iş hesabında yeni işlevsel puan oluşturmaz.
- [Canlı kurulum kanıt özeti](checkpoints/2026-10-22-panel-branding-live-result.json).


## 🔴✓ Onaylı 42° altın–antrasit ΛuthWire logo geliştirme ve teknik/görsel kontrol tamam — 22 Ekim 2026; canlı kurulum bekliyor

- Operatör matematiksel vektör çizimini “bence oldu bunu kullanalım” diyerek onayladı. Baş harf çizgisiz Yunanca büyük Lambda: **ΛuthWire**. Altın `#C6A15B` / antrasit `#25272B` ve onaylı geçişler kullanılır. Beş ayrı parça, dört komşu eksen açısı42°, dört yatay uç aralığı28birim, dik parça kalınlığı36birim korunur. Panelin krem/lacivert/açık mavi/kiremit renk rolleri aynı kaldı.
- 🔴✓ Onaylı masterSVG byte olarak aynen kaynakta saklandı; SHA256 `90639e21a88e2cfe065574121019369aeb27d49b8b6a14908b173287be1f402d`. Panel PNG'si aynı beş polygon/gradientten yalnız dış boşluk kırpılarak1200×742şeffaf üretildi. Menü sözcük logosu masterdaki fonttan bağımsız glyph path'lerini kullanır; giriş/sekme/yardım metinleri ΛuthWire gösterir. Görüntü oranı CSS contain ile korunur. Teknik AuthWire dosya/indirme adları, API product kimliği, servis adları değişmedi.
- 🔴✓ PR45, ürün kaynağı `1e062bf896e492a4ae50a344dd67ad849d994422`; ek belge ve tarayıcı test başı `750ee012939e3bf07bb115987cf197e4114acd63`; main merge `1a5fe3cef053b56e287dd147e97aa5fa1d9444c5`. JavaScript farkı yalnız görünen marka metinleridir; ağ çağrısı, kontrol akışı ve kimlik doğrulama davranışı aynı. Linux141dosyasında8görsel/metaveri dosyası değişir; Windows istemci/installer, server/authorization/CA/policy ve diğer araçlar byte olarak aynıdır.
- 🔴✓553temel test (25ortam atlaması), Linux native hazırlık, bounded network probe, Windows istemci ve gerçek Kerberos testleri geçti. Gerçek EAP-TLS normal/debug policy/VLAN yanıtları ve runtime kontrolleri ürün kaynağı üzerinde başarılı. Chromium dokuz akışı geçti;390/1366/1920genişliklerde taşma, sidebar'a sığma ve amblem oranı denetlendi. `login-branding.png`, `overview-empty.png`, `branding-mobile-menu.png` doğrudan incelendi. Bunlar izole fixture görüntüleridir; canlı panelin operatör kabulü değildir. UI run39788662719, artifact12430067022; indirilen ZIP SHA256 `e5d0f500ca6a84c5a6e66b33463675ebb6d21eae2709dfa53588f6f01ba9a27f` doğrulandı.
- **Önceden açık bulgular korunur:**1000cihaz/4worker izole enrollment ilk denemesinde Operations._public okumasında SQLite `database is locked` görüldü (job119851757698); aynı kodla ayrı tekrarda1000benzersiz/kurulmuş sertifika18.742sn geçti (119853804871). Windows deadline retry fixture ilk denemede deadline_rearmed/retry_pending ile180sn sınırını aştı (119853865843); ayrı aynı-kod tekrarı119854782823geçti. Bunlar düzeltilmiş sayılmaz; B04 ve retry test aralıklılığı açık kalır. Kimlik kodu, timeout/thread/test eşiği değiştirilmedi. İlk UI denemesi Ubuntu paket indirmesinde süre aşımına uğradı; ürün testleri başlamamıştı. Yeni doküman başında tarayıcı akışlarının tümü başarılı.
- 🔴✓ Yerel kurulum korumaları accepted dev.14→aday ve tam aday tekrarını kabul; RADIUS adapter/Windows istemci/installer değişikliği ve kurulu kaynak sapmasını reddetme kontrollerini geçti. Sunucuda `/home/segmentiq/authwire-stage-dev15-1e062bf896e4` hazırlanıp141/141hash tekrar doğrulandı. ManifestSHA256 `cdd7e02efb77fead5db9de1b8c95ed9fd400944beb6d4f037392d7269ac30565`. `/home/segmentiq/authwire-branding-update-20261022.py` SHA256 `ea3cb87ef9f940c5ea05b960cb47558e14cacd6c0f9f098a7263a71833eeee3e`; incelenen dosya checkpointte aynen saklanır.
- **Canlı kurulum henüz yapılmadı:** yerel sudo terminal parolası gerekir. Son salt okunur kontrolde canlı sürümdev.14, panelPID716005/RADIUSPID679309/brokerPID149955aktif. Bu turda servis stop/restart veya canlı policy/sertifika/GPO değişikliği yapılmadı. Yeni canlı veri yedeği/restore ve tam dosya/PID/timer/business_state karşılaştırması henüz yapılmış gibi sayılmaz; kurulum komutu bunları zorunlu doğrular. Beklenen son olay BRANDING_UPDATE_FINISHED/version0.14.0-dev.15; ardından operatör Ctrl+F5/giriş-menü-logo görüntüsünü kontrol edecek.
- Kalan işlevsel işler beklemede; DNS mimarisi kapsam dışı ve NTP işi duraklatılmıştır. Bu görsel alt iş94iş hesabında yeni işlevsel tamamlanma puanı oluşturmaz. Önceki tüm açık kapılar aynen korunur.
- [Onaylı vektör ve ölçüler](branding/README.md), [teslim/CI/koruma kanıt özeti](checkpoints/2026-10-22-panel-branding-delivery.json), [hash ile sabitlenmiş kurulum kaynağı](checkpoints/2026-10-22-panel-branding-update.py).


## 🔴✓ dev.14 renk teması gerçek panel görüntüsüyle doğrulandı — 22 Ekim 2026

- Operatörün image(20261022-093936).png ekran görüntüsü doğrudan açılıp incelendi. Canlı Kontrol merkezi altlığında Ubuntu · 0.14.0-dev.14; krem zemin ve sol menü, açık mavi seçili menü/Git butonu/AD grup kartı, lacivert kullanıcı ve policy kartları, kiremit marka yazısı ve CTA, koyu metinler görünür. Başlıklar, butonlar ve sayaçlar okunuyor; referans renk paletinin gerçek tarayıcıya geldiği dar görsel kontrol tamamlandı.
- 🔴✓ Önceki canlı kurulum/koruma/yedek/izole veri geri yükleme kabulüne ek olarak, bu istek için beklenen gerçek panel renk görünümü de doğrulandı. Bu, operatörün tasarımı beğendiğini sözlü onayladığı veya tüm ekranlarda yeni saha testi yapıldığı anlamına gelmez; kanıt paylaşılan Kontrol merkezi ekranıyla sınırlıdır. Diğer ekranların masaüstü/mobil teknik tarayıcı kontrolleri önceki teslimde geçti.
- Bu mesajda ürün, policy, sertifika, Windows/GPO veya servis değişikliği yapılmadı. Sonraki panel düzenlemesi operatörün seçimiyle devam edecek; kalan işlevsel işler beklemede. Mevcut94alt iş yüzdesine yeni puan eklenmedi.

## 🔴✓ dev.14 panel renk paleti canlı kurulum ve veri koruma kabulü tamam — 22 Ekim 2026; tarayıcı görünümü bekliyor

- Operatör PALETTE_UPDATE_FINISHED çıktısını verified=true/version0.14.0-dev.14 olarak iletti. Canlı Linux kurulum tamamlandı. Orijinal preflight snapshot/kanıt dizini `/var/backups/authwire/scheduled/palette-dev14-20261022T093320Z-1d994551` kalıcıdır. Bu kayıt operatörün gerçek çıktısına dayanır; bu turda yeni canlı sistem veya saha testi yapılmadı.
- 🔴✓ RADIUS aktif, PID679309 ve brokerPID149955 korundu; radius_restarted=false. Dosya/PID/timer/business_state kontrolleri tümütrue; policy, sertifika/CA, native modül, Windows istemci ve GPO kaynakları değişmedi. Canlı policy işlemi yapılmadı; planlı yedek zamanlayıcısı korundu.
- 🔴✓ Önce/sonra gerçek yedeklerin arşiv ve SQLite kontrolleri geçti. Son arşiv `/var/backups/authwire/scheduled/authwire-scheduled-20261022T093520Z-58209c3065c4.tar.gz`, SHA256 `a011c5ef004f8b84e4b7b6e713fc23b2e28c181d528208ce8c5aae0e763ee8e7`. Bu arşivden162dosya izole veri geri yükleme; byte/owner/mode, DB/CA/CRL/korumalı sırlar/anahtar eşleşmesi/imzalama ve erişim kayıtları kontrolleri geçti. İzole kopya kaldırıldı. Tam appliance boot restore tamamlanmış sayılmaz.
- 🔴✓ Önce5/sonra8 kimliği doğrulanmış yerel HTTPS API uç noktası, her biri3okuma, tümü200; son kontrollerde en yüksek süre35.9ms. Panel teknik sağlık kontrolü başarılı.
- **Açık kalan dar adım:** operatör gerçek paneli F5 ile yenileyip dev.14, krem zemin/menü, açık mavi aktif sekme, lacivert kartlar ve kiremit buton görünümünü kontrol edecek. palette_browser_acceptance_pending=true; bu çıktı tek başına gerçek tarayıcı görünümü kabulü değildir.
- Kalan işlevsel işler beklemede; DHCP/DNS mimarisi kapsam dışı ve NTP çalışması duraklatılmıştır. Mevcut policy/VLAN değerleri değiştirilmedi. Yeni tema için94alt iş hesabına ek puan verilmez.
- [Canlı kurulum kanıt özeti](checkpoints/2026-10-22-panel-palette-live-result.json).

## 🔴✓ Panel renk paleti geliştirme ve teknik kabulü tamam — 22 Ekim 2026; canlı kurulum bekliyor

- Operatör kalan işlevsel işleri bekletti; bugün yalnız mevcut panelin renk düzeni üzerinde çalışılacak. Referans görsel ve palet açıldı: lacivert #1D4D73, açık mavi #68A9CF, kiremit #D96B52, krem #F3EAD8, koyu füme #2C2C2C. Ana zemin/menü krem; aktif menü ve sekmeler açık mavi; ana sayaç kartları lacivert; CTA ve marka yazısı kiremit. Krem ara yüzey tonları kart/formları ayırır. Küçük CTA yazısı kontrast için #171717; lacivert kartta krem, açık mavide koyu metin kullanıldı. Başarı/uyarı/hata anlam renkleri korundu.
- 🔴✓ dev.14 kaynak geliştirme tamam: ürün tarafında yalnız styles.css ile sürüm metadata dosyaları değişti. Kimlik doğrulama, JavaScript davranışı, policy, Windows/GPO ve RADIUS kaynakları aynı. PR44, incelenen b180d5c2cccf2f145f4c49d7ad85ba71c5b6ca88 kaynağı; merge f16de7ae5f0deb111184dcbc76f4ae87138fc141.
- 🔴✓ 9 mevcut tarayıcı akışı, gerçek render metin/zemin kontrastı ve mobil/masaüstü kontrolleri geçti; overview, mobil, policy, servis, sertifika/drawer, LDAP ve erişim kayıt ekranları görsel incelendi. Foundation 553 test /25skip, Linux hazırlama, native RADIUS, network probe, Windows istemci ve Kerberos grupları başarılı. İlk Windows retry job119743546546 deadline_rearmed zaman aşımıyla başarısızdı; değişmeyen kod tek yeniden çalıştırmada job119745471485 ile geçti. Önceki aralıklı zamanlama bulgusu çözülmüş sayılmaz, saklandı.
- 🔴✓ Yalnız sunucu kullanıcı dizininde kurulum paketi hazırlandı; 141 dosya/manifest ve kurulum dosyası SHA256/sözdizimi doğrulandı. Salt okunur canlı kontrol Linux segmentiq/IP10.35.50.246, dev.13; panel679209, RADIUS679309, broker149955 aktif. Kurulu141 dosyanın tümü kabul edilmiş dev.13 ile aynı. Yerel deploy koruması base→aday/tekrar kabulü, yetkisiz RADIUS/JS/Windows değişikliği ve drift reddi, dosya/PID/timer/policy koruma senaryolarını geçti.
- **Canlı kurulum henüz yapılmadı:** parolasız sudo yok; operatör Linux terminalinden yerel sudo çalıştıracak. Stage `/home/segmentiq/authwire-stage-dev14-b180d5c2cccf`, manifestSHA256 `5dc6f6d432630c92f3c276654163f6ad3ffefcb0270552ab0bd30883f6c7106c`. Deployer `/home/segmentiq/authwire-palette-update-20261022.py`, SHA256 `1b21178d80907dede058d45a40f882b9374e8851e34bb93e9b82ff0efeb6a6df`. Beklenen son olay PALETTE_UPDATE_FINISHED; ardından gerçek panel F5/görsel kabulü açık. Kod yedeği, canlı veri yedeği, korunma ve izole veri restore kontrolleri kurulum sırasında yapılacak; bugün bunlar yeni canlı kabul yapılmış gibi sayılmaz.
- Yeni saha testi/servis restart/policy veya sertifika değişikliği yapılmadı. İşlevsel kalanlar ve NTP duraklatıldı; DHCP/DNS mimarisi kapsam dışı. Renk düzenlemesi mevcut panel maddesini günceller; 94 alt iş sayımına yeni iş/puan eklemez.
- [Teslim ve kanıt özeti](checkpoints/2026-10-22-panel-palette-delivery.md), [incelenen yerel-sudo kurulum dosyası](checkpoints/2026-10-22-panel-palette-update.py).

## 🔴✓ VV06 doğrulanmış Wi-Fi profilinin geri yüklenmesi / test temizliği tamam — 21 Ekim 2026

- Operatör, C:\Users\administrator\AuthWire-WiFi-Verified-20261021-190808\Wi-Fi-VV_802.1X.xml doğrulanmış yedeğini `netsh wlan add profile ... interface=Wi-Fi user=all` ile geri yükleme komutuna `Profile VV_802.1X is added on interface Wi-Fi` başarı yanıtı verdi. Aynı çıktı iki kez iletildi; iki ayrı işlem/test gibi sayılmaz.
- 🔴✓ Geçici PMKCacheMode=no değişikliğinin özgün profil yedeğiyle geri alınması, profil import başarı ölçütüne göre tamamlandı. Yedek daha önce machine/EAP-TLS, doğru KANAME root/server-name ve sunucu doğrulama ayarlarıyla doğrulanmıştı. Bu son yanıt yalnız profil yükleme kabulüdür; yeni export veya import sonrası yeni 802.1X/DHCP ölçümü yapılmış gibi sunulmaz.
- dev13butonun geliştirme/teknik/canlı teslim/görünüm kabulleri, Windows-RADIUS disabled ret/güncel allow140 kabul kayıtları ve önceden elle kaydedilen deny/null açıklamasıyla kapatılan inceleme korunur. Geçici profil geri dönüşü artık bekleyen iş değildir. İlk döngü deny başlangıcı/action-vlan değişikliği içerdiğinden safallow140→disabled→enabled turu ayrıca uygulanmış sayılmaz; bütün B08/B10 tamamlandı denmez.
- Diğer kullanıcıEAP-TLS, gerçekexpiry/ayrıcihaz, off-host/tamappliance kurtarma ve yol haritasındaki kalan senaryolar açık; NTPişleri duraklatılmış ve DHCP/DNS mimarisi kapsam dışıdır. Bu kayıt ürün/policy/sertifika/servis değişikliği içermez.

## 🔴✓ Operatör açıklamasıyla Ret/boş VLAN incelemesi kapatıldı — 21 Ekim 2026

- Operatör, daha önce policy'yi elle İzin ver'den Reddet'e çekip kaydettiğini, sonra bunu unuttuğunu ve devre dışı bırak butonu eklenince kayıtlı kararı değiştirmediğini açıkça doğruladı. Bu açıklama revision56/SHAdoğrulanmış yedekteki enabled/deny/null ve yeniden etkinleşme sonrası POLICY_DENY kaydıyla örtüşür. **Ret/boşVLAN bildirimi önceki kayıtlı ayardan kaynaklanmıştır; ürün/form hatası incelemesi bu açıklamayla kapatıldı.** Yeni kod/servis/policy düzeltmesi yapılmadı, gerekmedi.
- 🔴✓ dev13butonun geliştirme/teknik test/canlı kurulum/operatör görünümü kabulü; 🔴✓disablediken NO_MATCHING_POLICY ret ve güncel allow/VLAN140 durumunda POLICY_ALLOW/Windows12012-8001/10.10.140.2geri dönüşü kabul edildi. Etkinlik bayrağı ile İzin/Retkararı ayrı; mevcut kayıt kablosuz enabled/allow140, wiredallow110.
- **Kanıt sınırı korunur:** ilk döngü denybaşlangıcı ve sonrasında action/vlan değişikliği içerdiği için yalnızallow140başlangıçlı saf kapat/aç turu ayrıca uygulanmış gibi kaydedilmez. Bu tur artık bildirilen hata için zorunlu yeniden üretim adımı değildir; operatör sebebi açıkladı. B08/B10bütün açık maddeleri tamamlanmış sayılmaz.
- Son temizlik açık: VV06'da PMKCacheMode=no geçici değişikliğini, bugün önceden doğrulanmış C:\\Users\\administrator\\AuthWire-WiFi-Verified-20261021-190808\\Wi-Fi-VV_802.1X.xml profiliyle özgün haline döndürmek. Bu adım sertifika/policy/GPO değişikliği gerektirmez; operatör netsh profil geri yükleme başarısı ve bağlantı/IP kontrolü henüz beklenir. NTPişleri duraklatılmış, DNSmimarisi kapsam dışı, kullanıcıEAP-TLSvegerçekexpiry ayrı açık maddelerdir.

## Policy tanılaması: ilk yedek zaten Reddet/boş VLAN; mevcut kayıt İzin/VLAN140 — 21 Ekim 2026

- Operatörün Yapıştırılan metin(2).txt salt okunur tanılaması18:33:17UTC/21:33:17+03'te geldi; dosyaSHA256fa9127c2af1a039e61dedd250b2f73c23f9d4133b2bfb231002a06f5d58f0635. Canlı revision60; wiredenabled/allow/VLAN110 değişmemiş, wirelessenabled/allow/VLAN140, başka kablosuzpolicy yok. Revizyon kontrol boyunca sabit, servisPIDkorumasıtrue, policywrite/restart/diskrestorefalse.
- **Önceki başlangıç varsayımı düzeltildi:** SHA doğrulanmış21:14yedekte (revision56) wireless zatenenabled=true/action=deny/vlan=null; bu revizyon audit20:38:00.784+03'te, dev13kurulumundan önce kaydedilmiş. Asistanın dev13kurulum/testbaşlangıcında policy'nin kesinallow140olduğu varsayımı doğru değildi. Etkinleştir butonu policy'nin mevcut İzin/Ret kararını dönüştürmez; deny policy'nin tekrar etkinleşmesi POLICY_DENY/boşVLAN üretir. Karşılaştırmadaki settings_except_enabled_preserved=false, bu yedekteki deny/null ile şimdiki allow/140 farkını bildirir; tek başına butonun alanları bozduğunu kanıtlamaz.
- 🔴✓ Olumsuz saha sunucu teyidi: kayıt26(21:20:12.167+03) ve27(21:21:18.436),Access-Reject/NO_MATCHING_POLICY, policy/vlannull, TLSverified1, doğruVV06MAC/GUID/güncel26e...seri ve APNAS10.35.50.52. İlk kayıt Windows21:20:12/12013-8002 ile aynı saniyede eşleşir; disabled skip davranışının dar uç/sunucu kabulü tamam.
- Kayıt28(21:23:32.300) farklı bir ret: Access-Reject/POLICY_DENY, wirelesspolicyID, TLSverified1, VLANnull. Bu, eşleşen etkin policy'nin açık Ret kararını uygulamasıdır; NO_MATCHING_POLICY ile aynı senaryo değildir. Ara revision57/58/59/60(21:19:58/21:22:34/21:23:04/21:24:24)audit yalnızpolicies_saved tutar; her ara policy payload'ı veya hangi UI işleminin hangi alanı yazdığı bu logdan kesin çıkarılamaz.
- 🔴✓ Pozitif sunucu ve uç eşleşmesi: kayıt29(21:25:02.135),30(21:25:39.511),31(21:30:15.819)Access-Accept/POLICY_ALLOW/wirelesspolicy/VLAN140/TLSverified1/aynıVV06cert-MAC-GUID/APNAS. Kayıt30Windows21:25:39/12012-8001 ve10.10.140.2/24Preferred ile aynı saniyede dar korelasyon kabulünü tamamlar. Bu, kalıcıNTPsağlığı/TLSresumption/accounting/B11bütünü tamamlandı anlamına gelmez.
- **Açık dar kontrol:** Şimdi doğrulanmış allow140 başlangıcında, kaydet/düzenleme yapmadan yalnız Devre dışı bırak→Etkinleştir, ardından Düzenle alanlarının İzin/140 kaldığını kontrol et. İlk test başlangıcı deny olduğundan temizallow-roundtrip/ayar koruması saha kabulünü bitmiş saymayacağız. Operatörün formgösterimi bildirimi henüz doğrudan yeniden üretilemedi; butonun kalıcıveriyi bozduğu veya UIhatasının giderildiği iddia edilmeyecek. Mevcutallow140/wired110 korunur; ürün değişikliği yapılmadı. Geçici PMKCacheMode=no özgün profile geri dönüşü hâlâ açık.
- [Tam tanılama verisi](checkpoints/2026-10-21-policy-editor-readonly-result.json). Yedekle canlı kayıt karşılaştırması, script alanlarının tekil amacı ve varsayım düzeltmesi kanıtıyla saklandı.

## 🔴✓ VV06 yeniden etkinleştirme sonrası Wi-Fi/VLAN140 döndü; policy Düzenle alanlarında Ret/boş VLAN bildirimi açık — 21 Ekim 2026

- Operatör yeniden Etkinleştir adımı sonrası VV06'da aynıSSID/AP/MAC/computerGUID ile connected,21:25:39 WLAN12012/8001 ve10.10.140.2/24Preferred bildirdi. **🔴✓ Windows yeniden bağlantı ve VLAN140 geri dönüşü tamamlandı.** Önceki21:20:12Windowsreddiyle birlikte dar uç davranışı görüldü; RADIUS ret/kabul kaydı ve kesin neden/policy eşleştirmesi henüz paylaşılmadı.
- Operatör ayrıca toggle sonrası kararın Reddet, VLAN'ın boş göründüğünü belirtti; hedefli soruya **Erişim kuralları / Düzenle** yanıtını verdi. Bu bildirim ret geçmişi olarak yorumlanamaz; **policy editörü/veri koruması hatası incelemesi açık**. Mevcut bağlantı başarısı tek başına policy'nin depodaki action/vlan alanlarının doğru olduğunu kanıtlamaz. B08/B10tamamlandı sayılmaz.
- Salt okunur RDC kontrolünde sunucudaki141kurulu dosyanın tamamı incelenen dev13manifestiyle eşleşti; panelPID645600/RADIUS326873aktif. Kurulu setPolicyEnabled yalnızenabledalanını değiştiriyor; bu kod gözlemi operatör hatasını geçersiz saymaz. UI state/edit yarışları, form gösterimi ve gerçek kayıt ayrı incelenecek; henüz ürün düzeltmesi veya canlı policy değişikliği yapılmadı.
- Hazır tanılama [2026-10-21-policy-editor-readonly.py](checkpoints/2026-10-21-policy-editor-readonly.py), sunucu/home/segmentiq/authwire-policy-editor-readonly-20261021.py, SHA2563495396d3d743a84414067de94f68e5097cf9504d8da409a8bfc321d8a25a08c. Yalnız sqlite mode=ro/query_only ile pilot policy ve sonAPNAS kayıtları; bilinen a51a4575...yedek arşivini SHA doğruladıktan sonra SQLite'ı yalnızbelleğe deserialize edip action/vlan/conditions farkını karşılaştırır. Diskextract/restore, secret/token/CA/key çıktısı, servisrestart veya policywrite yok. Yerel fixture'da yazma reddi/dosyaözeti korunması/bellekrestore/yalnızenabled ve action-vlanfarkı tespiti/yanlışdigestret kontrolleri geçti. Sunucuda dosyaözeti ve sözdizimi doğrulandı; özelDB için operatör sudo çalıştırması beklenir.
- Geçici PMKCacheMode=no ayarı ve sonradan özgün profil geri dönüşü açık kalır; bozuk görünümü kaydetmeden kayıtlıveri ve form gösterimi ayırt edilecek. KullanıcıEAP-TLS/gerçekexpiry ve diğer açık senaryolar korunur; DNSmimarisi kapsam dışı, NTPçalışması duraklatılmıştır.

## 🔴✓ VV06 policy kapalı senaryosunda Windows Wi-Fi reddi doğrulandı — 21 Ekim 2026, sunucu nedeni ve geri dönüş bekliyor

- Operatör, yalnız kablosuz policy devre dışı adımı sonrası PMKCacheMode=no profil güncellemesi ve yeni bağlantı çıktısını iletti. VV06 Wi-Fi disconnected, donanım/yazılım radyosu açık;21:20:12 olay12013 ve8002; EAP0x80420105 sunucudan genel ret. MAC10:B1:DF:69:95:33, APF0:61:C0:CC:73:54, kimlikhost/AuthWire computer69b0d5cd-db61-4627-9db7-fcc5230152a3. Connection request completed metni başarılı kimlik doğrulama sayılmadı.
- 🔴✓ Yalnız Windows tarafında yeni bağlantının reddedilmesi tamamlandı. **AuthWire yeni Access-Reject kaydı/nedeni henüz paylaşılmadı**; NO_MATCHING_POLICY ve ret nedeninin policy disabled olması henüz doğrulanmış değildir. Windows genel0x80420105 tek başına sertifika bozuk/iptal veya policy nedeni ayırmaz. Tam B08/B10 senaryosu açık.
- Sıradaki adım aynıauthwire-pilot-wireless'i Etkinleştir/VLAN140 korumasını kontrol et, PMKcache kapalı kalırken yeni Wi-Fi bağlantısı/12012-8001/DHCP140 ve yeni Access-AcceptPOLICY_ALLOW kaydını birlikte doğrula. Önceki ret kaydı da bu sırada incelenebilir; Ethernet yönetim korunur. Sonunda geçici Wi-Fi profil parametresi doğrulanmış özgün yedekten geri alınacak.

## 🔴✓ dev.13 policy butonu operatör ekran kabulü tamam — 21 Ekim 2026

- Operatör F5 sonrası policy satırının Etkin olduğunu ve Devre dışı bırak butonunu gördüğünü doğruladı. Geliştirme/CI ve canlı kurulumun ardından bu dar ekran görünümü kabulü de tamamlandı.
- Sıradaki saha adımı yalnız `authwire-pilot-wireless` enabled=false→true: VV06 Wi-Fi yeni doğrulamada ret; ardından aynı policy yeniden etkin, VLAN140 DHCP geri dönüşü. Mevcut bağlantının otomatik düşmesi beklenmez; PMK cache kapalı taze bağlantı ile güncel RADIUS kaydı ve Windows WLAN olayları birlikte incelenecek. Başka etkin policy eşleşirse karar önceden varsayılmayacak. Ethernet yönetim ve wired policy korunacak.
- Henüz butona basıldığına veya olumsuz/geri dönüş saha testinin tamamlandığına dair çıktı yok. B08/B10 saha kabulü açık; bu kayıt yalnız operatörün durum rozeti/buton görünümü kabulünü tamamlar.

## 🔴✓ dev.13 policy butonu canlı kurulum, koruma ve yedek/restore kabulü tamam — 21 Ekim 2026

- Operatör `POLICY_TOGGLE_UPDATE_FINISHED` çıktısı verified=true/version0.14.0-dev.13; Linux canlı kurulum tamamlandı. Orijinal preflight snapshot ve kanıt dizini `/var/backups/authwire/scheduled/policy-toggle-dev13-20261021T181206Z-277d351a` kalıcıdır.
- RADIUS aktif, PID326873 ve broker PID149955 korundu; radius_restarted=false. Dosya/PID/timer/business_state kontrolleri tümütrue; policy, CA/sertifika, native modül, Windows ve GPO kaynak değişikliği yok. Kurulum herhangi bir canlı policy toggle işlemi yapmadı.
- 🔴✓ Önce/sonra gerçek özel yedekler okuma/SQLite kontrolünü geçti. Son arşiv `/var/backups/authwire/scheduled/authwire-scheduled-20261021T181414Z-77a4a68ad8c4.tar.gz`, SHA256 `a51a4575c98b8199ddcc61c600c10db6d2f65e04b9362d14d8db69f0d766cde7`. 🔴✓ Bu arşivden162dosya izole veri restore provası, byte/owner/mode, DB/CA/CRL/şifreli sırlar/imzalama/anahtarlar/kayıt tutarlılığı ve erişim kayıtları kontrolleri geçti; kopya kaldırıldı. Tam appliance boot restore hâlâ test edilmiş sayılmaz.
- 🔴✓ Önce/sonra kimliği doğrulanmış yerel HTTPS API ölçümleri tümü200; son8endpoint max34.5ms. Bu teknik canlı kabul, operatörün gerçek tarayıcı görünümü kabulünün yerine geçmez.
- **Açık kalan dar adım:** F5 sonrası dev.13, Etkin/Devre dışı rozeti ve butonun görünmesi; kablosuz policy'nin halen allow/VLAN140 olması. Ardından yalnızpilotwireless enabled=false→true ile yeni bağlantıda ret/kabul/VLAN140 saha testi. B08/B10 bütünü tamamlanmış sayılmaz. NTP çalışması duraklatılmıştır; DHCP/DNS mimarisi kapsam dışıdır.
- [Yapılandırılmış canlı teslim kanıt özeti](checkpoints/2026-10-21-policy-toggle-live-result.json); yeniden sunucu kontrolü yapılmış gibi sunulmadan operatör çıktısından kaydedildi.

## 🔴✓ Policy etkinleştirme/devre dışı bırakma geliştirme ve teknik testleri tamam — 21 Ekim 2026; canlı kurulum bekliyor

- Operatör, Reddet senaryosuna geçmek yerine panelde gerçek **Devre dışı bırak / Etkinleştir** butonu istedi. Bu istek önceki Reddet→İzin ver yönergesinin yerini alır. Sonraki saha testi yeniden `authwire-pilot-wireless.enabled=false→true`; başka eşleşen allow yoksa olumsuz karar `NO_MATCHING_POLICY` beklenir. Açık deny kararı `POLICY_DENY` ayrı senaryodur.
- dev.13 adayında satırda Etkin/Devre dışı rozeti ve yalnız `policies.rules` yazma yetkisine açık buton eklendi. Var olan CSRF/RBAC/revision/çakışma denetimli `/api/policies` kaydı kullanılır; yalnız ilgili `enabled` değişir, VLAN140/karar/grup/NAS/erişim türü/constraints ve diğer politikalar korunur. Disabled policy düzenleme ile açılmaz; çakışan etkinleştirme kaydedilmez. Düzenleyici açıkken ve kayıt sürerken toggle kilitlenir; POST otomatik tekrar edilmez.
- 🔴✓ Mevcut policy/yönetim/admin sınırları için yerel90 test geçti (1skip); panel-only teslim korumaları için5 test geçti. 🔴✓ Gerçek HTTP/tarayıcı fixture'ı CI'da geçti: kalıcılık, disabled değerlendirmesi, VLAN/grup/NAS koruması, disabled düzenleme, çift/başarısız yazım, revision çakışması, çakışan reactivation, RBAC/CSRF ve390/1366/1920px taşmama; ekran görüntüsü incelendi. Mevcut diğer tarayıcı akışları, foundation, enrollment, retry probe ve Linux hazırlama da geçti. Yerel Chromium indirilemedi; tarayıcı sonucu CI'dan alınmıştır.
- İlk native RADIUS CI turunda test observer shim'i için ModuleNotFoundError görüldü. İncelemede authorizer config python_path'inde geçici shim varken observer'ın kendi yolunda yoktu; diğer modülün önce yüklenmesine bağımlıydı. Yalnız tools/radius_lab.py fixture'ında observer'a açık shim yolu eklendi; iki modülün ayrı izole Python süreçlerinde bağımsız import regresyon testi geçti. Ürün RADIUS/karar/observer kaynakları değişmedi; 🔴✓ Düzeltme sonrası normal ve debug native EAP-TLS/policy/VLAN/erişim kayıt testleri ve35 runtime sınır testi geçti. Aynı9629483795df63f139eed25bc3bfb8cc1649aac6head'de bütün ilgili workflow grupları başarılı: foundation553test/25skip, tarayıcı, Linux hazırlama/native adapter, Windows client/SYSTEM retry, native Kerberos, bounded network probe ve native RADIUS. İlk modül yolu başarısızlığı sessiz tekrar ile örtülmedi; fixture düzeltmesi ve bağımsız import regresyonu kaydedildi. Panelde statik kalmış dev.11 sürüm altlığı da /api/state sürümünden güncellenecek hale getirildi.
- Sunucu salt okunur kontrolünde dev.12, panel/RADIUS/broker etkin; RADIUS326873 ve broker149955 PID korunuyor, CRL/backup timer etkin/enabled. Canlı policy toggle, RADIUS restart, CA/cert/Windows/GPO/DNS değişikliği **yapılmadı**. 🔴✓ PR43 birleştirildi (merge96be7f50c67e030d31f42fcab1cd34ae6b3086af), incelenen kaynakhead9629483795df63f139eed25bc3bfb8cc1649aac6.141dosyalık paket tüm Git blob ve SHA256 kayıtlarıyla doğrulandı; sunucudaki ordinary-user stage hazır. LauncherSHA2560ef95ca8fa91a62760ee28dd0246bb353d50ef3ea9a690b3378b29fc676983d6 okuma ile doğrulandı, çalıştırılmadı. [Teslim checkpoint](checkpoints/2026-10-21-policy-toggle-delivery.md). **dev.13 sudo kurulum ve operatör buton/gerçek Wi-Fi ret→kabul kabulü henüz bekliyor**; bütün B08/B10 tamam sayılmaz.

## Test yönergesi düzeltildi: UI'de devre dışı anahtarı yok; açık Reddet→İzin ver senaryosu uygulanacak — 21 Ekim 2026

- Operatör panelde“devre dışı”değil“Reddet”seçeneği olduğunu belirtti. **Asistanın önceki disable/enableUIyönergesihatalıydı.** Canlıstatic/index.htmlpolicy-actionseçenekleriallow/İzinvervedeny/Reddet;static/app.jsrenderPoliciesyalnızDüzenle/Silbutonlarısunuyor,enabledalanıgörseldüzenlenemiyor(legacyarchivedgösterimi). Paneldeolmayananahtarıvarsaymayacağız;yenibuttonözelliğibuturnkapsamınagirilmedi.
- Değerlendirmedışıbırakmak(enabledfalse)ileeşleşenpolicy'ninreddetmesi(actiondeny)aynıdeğildir. Sıradakitest**yalnızauthwire-pilot-wirelessactionallow→deny→allow**olarakdüzeltildi. BeklenenolumsuznedenPOLICY_DENY'dır;NO_MATCHING_POLICY/disabledpolicykabulu sayılmaz.
- **Kaynakdoğrulamalıgeridönüşayrıntısı:**UIkaydetmedeenabled:old.enabled,mevcutaccess_types/nas_ips/constraints korunur;denyactionvlan:nullolarakkaydedilir. Bu nedenleİzinver'egeridönüşte**VLAN140yenidenseçilecektir**. Grupkoşuluseçimikorunmalı,policykopyalama/silme/wiredpolicyeveAD'yeişlemyok.
- ÖncekiVV06PMKcachegeçicikapat/negativeconnect,sonrapositiveconnectveözgünprofilrestorekomutlarıtestiçingeçerlidir;yalnızpaneladımlarıvebeklenenretkararıdeğişmiştir. Etkiaynıpilotwirelesspolicy'ye bağlıcihazlarıyenidendoğrulamadaetkileyebilir. Şimdilikpolicydeğişikliğiuygulanmış/testtamamlanmışsayılmaz.

## 🔴✓ VV06–DC01 anlık saat hizalaması ve özgün eşik geri dönüşü; operatör isteğiyle 802.1X'e dönüldü — 21 Ekim 2026

- Operatörhelperçıktısı:W32Timebackup C:\ProgramData\AuthWire-Time-Align-20261021-203036;geçiciMaxAllowedPhaseOffset1adımısonrası“no time data”resyncmetni görüldü;finally“Özgün eşik geri yüklendi:300”,runtimeMaxAllowedPhaseOffset300(Local)/TypeNT5DS(Local)doğrulandı.
- **🔴✓ Anlık duvarsaatihizalama:**20:30:23/25/27/29/31stripchartDCminusVV06+0.0009195/+0.0001621/+0.0000133/-0.0001196/-0.0002258s.5örnekte|offset|<1ms;önceki124sfarkbukısapenceredekapandı. Buölçümve300/NT5DSgeri dönüş dar kabulü tamamlandı.
- **Açıkizlem,başarıgibisunulmaz:**aynısonstatusLeap3,stratum0,StateUnset,LastSyncError1,PhaseOffset-20.2919052s,rootdispersion28.0747172s,lastsync20:30:40. Komutresyncsonucuileduvarsaat ölçümüayrıkaydedilir;NTPhizmetinin kararlı normalstatüdeolduğu veya rebootkalıcılığı kanıtlanmadı. Kullanıcı“Düzeldi bence,artık gerçek konumuza dönelim”dedi;bu nedenle NTPçalışmasınadevamedilmeyecek,izlemmaddesiaçıkduracak. Nativeexitcodekontrolütekbaşınabuoperatörresyncmetniningeçerliliğinikabuleyetmez;manuelstatus/offsetkabulükorunur.
- **Sıradaki 802.1X B08/B10 dar senaryo:**geçerliVV06certveaynıdoğruWi-Fiprofiliyleyalnızauthwire-pilot-wirelesspolicygeçicidisabledikenret,bukablosuzpolicyyenidenenabledikenaccept/VLAN140DHCPgeridönüş. Ethernetmanagementvewiredpolicykorunur;ADgroup/device/cert/CA/sharedsecret/RADIUSservisayarınadokunulmaz. Aynıpilotwirelesspolicy'ye bağlıdiğercihazlaryenidendoğrulamadageçiciretgörebilir;operatörpaneladımındabuetkibelirtilecek. Başkailzinpolicy'sieşleşirsegerçekkararincelenecek,sonuçöncedenvarsayılmayacak.
- Henüzpolicytoggle/olumsuztestyapılmadı;hazırlıkolarakkaydedildi. Guesttekrarıistenmedi,DNSmimarisikapsamdışı,gerçekexpiryayrıcihazbekliyor,kullanıcıEAP-TLSayrıaçıkmaddekalır.

## VV06 phase ayarları doğrulandı; yedekli tek seferlik anlık hizalama adımı hazır — 21 Ekim 2026

- Operatörverbose:PhaseOffset123.9658728s/ClockRate0.0156250s/StateHold/TimeSourceFlags8(SignatureAuthenticated)/LastSyncError0/soniyiörnek234sönce. NT5DS(Local),MinPoll10/MaxPoll15,MaxAllowedPhaseOffset300(Local),PhaseCorrectRate1,UpdateInterval30000,SpikeWatchPeriod900;maxpos/neg0xFFFFFFFFmevcutdeğerleridir,asistantarafındangenişletilmedi.
- Sonölçüm20:23:41/43/45+03:DCminusVV06+123.9566876/+123.9568428/+123.9565635s. Kaynakkabulüvar,farkhenuz~124s. Microsoftbelgelerineeşikaltıoffsetinkademelidüzeltilmesidavranışıylauyumlu;Holdveuzunpollayarlarıtamyakınsamabeklentisindeayrıcagörünür.
- Hazır operatörhelper **docs/checkpoints/2026-10-21-vv06-time-align-once.ps1**:yalnızVV06guard,orijinal300/NT5DSkontrolü,GPOphaseoverridevarsaabort,W32Timeregistryexportbaşarısızsaabort;tryiçindeMaxAllowedPhaseOffsetgeçici1s,W32Timerestart/resync;finallyherdurumdaorijinal300registrygeri+configupdateveokumadoğrulaması;ardındanruntimeconfiguration/statusverbose/5örnekstripchart. Saatbirkezgünceldomainkaynağınahizalanır;DC01/LinuxveAuthWirekonfigürasyonunadokunulmaz. Parametre,MaxPos/NegveyaSpikeWatchPeriodgibikabuledilebilirörnek sınırlarınıgenişletmez.
- **Henüz uygulanmadı:**backup/temporaryphase/resync/restore/offsetkabullerioperatörçıktısıbekliyor.HelperüzerindeWindowsçalıştırmatestiyapılmışgibisunumyok;belgelitemelmekanizmavegerçekVV06baselinedeğerleriylehazırlandı. B11yakınsamavekorelasyon açık.

## 🔴✓ VV06 Windows Time domain kaynağını kabul etti; yaklaşık124saatfarkı henüz kapanmadı — 21 Ekim 2026

- **🔴✓ Operatör yalnızVV06W32Timerestartsonrası/resync/rediscover başarılı**,sourcedc01.vizyonveri.local/10.35.50.70,Leap0,stratum4,lastsync20:19:47+03,rootdispersion131.7487307s.20:19:43/45/47Time-Service37:“valid time data”;20:19:47olay35:“now synchronizing”veUDP0.0.0.0:123→10.35.50.70:123. Bu,buölçümdegerçekW32Timeverikabulünügösterir;kalıcıUDPengeliartıkkanıtlanmışnedendeğildir.
- **Saatyakınsaması açık:**20:19:47/49/51/53/55stripchartoffsetleriDCminusVV06+123.9661099/+123.9656704/+123.9655307/+123.9655892/+123.9653209s. Değişim8s'de~0.789ms;başarılıresynckomutuveLeap0,duvarsaatininyakınsadığıanlamınagelmez.
- Olay158,VMICTimeProvidernon-HyperVortamıdesteklemiyorvebeklenenşekildedurduğunu açıkça belirtiyor;AuthWire/sertifikaarızasınedeniolarakyorumlanmadı.
- MicrosoftW32Timebelgelerikabul edilmişoffsetiMaxAllowedPhaseOffsetaltındakademelihızayarıyladüzeltebileceğinibelirtiyor. VV06güncelType/phase/poll/MaxAllowedPhaseOffsetveverbosePhaseOffset/ClockRateparametrelerihenüzokunmadı;kesinmekanizmaparametreçıktısındanönceiddiaedilmez. SıradakisaltokunurVV06statusverbosevefiltrelenmişconfiguration;orijinaldeğerlerbilinmedenphase/spike/GPOgüvenayarlarıdeğiştirilmedi.
- **Tamamlanmadı:**VV06–DCoffsetyakınsamasıveB11tazeWindows/RADIUSolaykorelasyonu. DC01/LinuxkaynakdüzeltmesiveöncekikablosuzVLAN/kimliktestlerininkabullerikorunur;AuthWirepolicy/cert/CA/RADIUSveprofilayarlarıdeğişmedi.

## VV06 W32Time yeniden eşzamanlaması açık; DC01 güncel NTP sağlığı tekrar doğrulandı — 21 Ekim 2026

- VV06operatör /resync/rediscover sonucu “no time data was available”;sourcedc01.vizyonveri.local,Leap3/stratum0,lastsync20:08:01/rootdispersion133.4957884s.20:09:04–20:09:12stripchart DC01'eyanıtveriyor,offset+123.9729094/+123.9712788/+123.9713576/+123.9706198/+123.9715100s. **VV06eşzamanlamasıtamamlanmadı.** Stripchart ephemeralUDP ile gerçekW32TimeUDP123/MS-SNTPeşzamanlaması aynıbaşarıkanıtıdeğildir.
- Linux→DC01takip17:12:30.423697Z:fark+0.003578s,leap0,stratum3,rootdispersion0.262680s,reference185.125.190.57. AynıpenceredeupstreamminusLinux-0.000288s.
- **🔴✓ Devam sonrası17:20:36.737614ZgüncelDCNTPölçümü:**DCminusLinux+0.002652s,RTT0.295ms,stratum3/leap0,rootdispersion0.023315s,reference185.125.190.57. DCkaynağı kısaizlemdeyakınsamışkaldı;VV06'dekiöncekiyüksekdispersionyanıtınıgüncelDCdurumuolarakgenelleştirmeyiz.
- İstemcihatasınınkesinnedeni henüzbilinmiyor (öncekikaynakgeçişi/ölçümreddi,domainadvertising,UDP123yolu veyaistemciyereldurum ihtimalleriayrıştırılmadı). GPO/NTPSNTPgüvenayarlarınıgevşetme veyaWindowsTimeunregister/register yapılmadı.
- **Sıradaki dar işlem:**yalnızVV06W32Timeservicerestart,3sbekleme,resync/rediscover,source/status,5örnekDCstripchartveTime-ServiceSystemsonolayları; henüzoperatörceuygulanmışdeğil. DC01konfigürasyonuveAuthWireRADIUS/CA/cert/policyleredeğişiklikyok;B11kesinWindows-RADIUSkorelasyonuaçık.

## 🔴✓ DC01 yedekli NTP kaynak düzeltmesi ve Linux ile milisaniye düzeyinde yakınsama — 21 Ekim 2026

- **🔴✓ Operatör uygulaması:** W32Timeregistryexport/configbackup başarılı,C:\ProgramData\AuthWire-Time-Backup-20261021-200423;manualpeerntp.ubuntu.com,0x8/config/update ve/resync/rediscover başarılı. DCsource ntp.ubuntu.com,0x8/185.125.190.57,stratum3,leap0,lastsync20:04:23. İlkoperatörstatus RootDispersion130.8929471s; bu tekçıktıyakınsamışsaatkanıtısayılmadı.
- **Geçici sapma saklandı:**17:07:40.330994–17:07:40.931942Z Linux→DCüçdoğrulanmışSNTPyanıtındaDCminusLinux+624.093807/+624.093811/+624.093781s,RTT~0.3msölçüldü. Sonrakiyenidenölçüm17:08:18.625627Zfark+0.004291s,DCreference185.125.190.57/stratum3/leap0/rootdispersion7.761459s. İlkbüyüksapmanınkesinnedeni belirlenmedi;kaynakdeğişimiylesıradakiyakınsamaölçümleriarasındaoluşanbulguolarakkorundu,permanentarızaolaraksunulmadı.
- **🔴✓ Bağımsızüstkaynak karşılaştırması:**17:08:18.688686Z,185.125.190.57minusLinux+0.000303s,RTT62.921ms,stratum2/leap0;Linuxsystemd-timesyncdsonoffset+2.031ms/rootdistance4.363ms.
- **🔴✓ Tekrar DC–Linux ölçümleri:**17:08:52.547798/17:08:53.548232/17:08:54.548724Zfark+0.004189/+0.004160/+0.004176s,RTT0.279–0.313ms,DCstratum3/leap0. Bu kısa pencerede aynıNTPkaynağıüzerindenyakınsama doğrulandı;uzunsüre/rebootkalıcılığıveVV06clientyenidenkabulühenüzölçülmedi.
- **🔴✓ AuthWire saltokunur servis koruması:**panel573680/RADIUS326873/broker149955active+enabled,PIDlerkorundu;authwire-radius-crl-sync.timervegerçekyedekunitiauthwire-backup.timerloaded/active/enabled,sonbackuptrigger21Ekim03:16:33,next22Ekim03:17:11İstanbul. İlkgenelstatussorgusundayanlıştahminedilenauthwire-scheduled-backup.timerinactiveçıktısıgerçekyedekarıza bulgusu değildir.
- **Bekliyor:**VV06yalnızdomainhiyerarşisindenresyncveDC'yestripchart/status;sonrasıtazeWindows/RADIUSortakolaykorelasyonu. B11tamamısayılmaz. NTPdüzeltmesioperatörünDC01W32Timeayarınaaittir;asistanLinuxsaatini,NTP'sini,AuthWirepolicy/CA/cert/nativeRADIUSve802.1Xprofillerinideğiştirmedi.

## DC01 zaman yapılandırması: yerel NT5DS, etkin upstream yok; yedekli NTP düzeltmesi hazırlanıyor — 21 Ekim 2026

- Operatör configuration/peers: NtpClientEnabled1/InputProvider1/TypeNT5DS(Local);NtpServerEnabled1;AnnounceFlags10(Local);VMICTimeProviderEnabled1(Local).Paylaşılan ayarlardaGPO/Policyişareti yok.1peeradıboş/Pending,mode0,stratum0,poll0;bu etkin birNTPupstream değildir.
- ÖncekiADçıktıları forest/domainvizyonveri.local/PDCdc01hiyerarşisini gösteriyor;rootPDC'ninNT5DShiyerarşisinden upstream beklemesi Free-runningSystemClock davranışıyla uyumludur.MicrosoftrootPDCiçin manuelüstzamanreferansı önerir.
- Hazırlanan operatör adımı: labdaLinux'unhalihazırkullandığıntp.ubuntu.com'a DC01w32tmstripchart5saltokunurörnek;başarılıyanıtsonrasıyerelW32Timeregistry/configbackup,manualpeerntp.ubuntu.com,0x8/syncfromflagsmanual/update,resync/rediscover,source/statuskontrol. MevcutAnnounceFlags10veVMIC/NtpServerayarlarına özeldeğişiklik yok. Stripchart ephemeralUDPportkullandığıiçinW32TimesourceUDP123erişiminikesinolarakkanıtlamaz;resynckabulüayrıdoğrulanacak.
- Bu kayıt **hazırlanmış, henüz operatörce uygulanmamış** adımı anlatır. Geri dönüşkopyası,sourceerişimi,configuygulaması,resyncveoffsetyakınsamasıkabulleriaçık;backupoluştu/saatişişlediyedenmez. AuthWirepolicy/CA/cert/RADIUS/Windows802.1Xetkilenmemesi korunacak;mevcutNTPveADC'tümünündüzeldiğikabulüverilmedi.

## 🔴✓ Zaman farkı teşhisinde DC01 PDC ve yerel serbest saat kaynağı doğrulandı — 21 Ekim 2026

- **🔴✓ DC01 operatör saltokunur çıktısı:** DNSRootvizyonveri.local,PDCEmulatordc01.vizyonveri.local;W32Time/query/source ve/query/status **Free-running System Clock**,RefIDLOCL(0x4C4F434C),stratum1,rootdelay0,rootdispersion10s,lastsync16:35:12+03. Stratum1/genel“radio clock”etiketi bu kaynakta gerçek dış/hardware UTC referansı kanıtı değildir.
- VV06DC01'i,AuthWireLinuxntp.ubuntu.com'u izliyor;Linux→DC01SNTPölçümündekiDCminusLinux-123.123sile birlikte ayrışmışaktifzamanreferansları saptandı. DC01'in harici/iç onaylı upstream'e aktif eşzamanlanmaması doğrulandı; bunun eksikpeer,erişim,GPO,servis veya sanallaştırma nedeniyle olup olmadığı henüz belirlenmedi.
- **Sonraki gerekli saltokunur kontrol:** DC01w32tm/query/configuration ve/query/peers;Local/Policykaynağı ve yapılandırılmışpeer durumunu ayırt et. Kaynak seçimi/erişim ve mevcutyapılandırmayedeği incelenmeden etki alanının saati değiştirilmedi;AuthWireCA/cert/policy/RADIUS/802.1XveDNSayarları korundu. B11kesinpacket/timekorelasyonu veNTPdüzeltmekabulü açık kalır.

## 🔴✓ VV06 doğru Wi-Fi ağına bağlandıktan sonra policy VLAN140 DHCP uç kabulü tamamlandı — 21 Ekim 2026

- Operatör önceki169.254çıktısının **Wi-Fi ağına bağlı değilken** alındığını açıkladı; doğru Wi-Fi ağına bağlanıp yeniden ölçtü. Önceki “VLAN140DHCPyolu/scope arızası” şüphesi bu veriye dayanarak doğrulanmış arıza sayılmaz; gereksizAP/switch/DHCPdeğişikliği yapılmadı. Tarihsel ham APIPA gözlemi korunur, arıza çıkarımı bu notla düzeltilir.
- **🔴✓ Yeni uç ölçümü:** VV06Wi-Fi10.10.140.2/24,PrefixOriginDhcp,AddressStatePreferred. Operatörün VLAN140policydeğişikliği + CSV ID20/21kablosuzpolicy/currentcert/TLStrue/140Access-Accept + doğru Wi-Fiağına bağlandıktan sonra140DHCPadresinin alınması birlikte bu dar dinamikVLANuçkabulünü tamamlar. SonIPçıktısındaSSID/BSSID/12012yeniden basılmadı; bağlantıbağlamı operatörbildirimine dayanır,kesinpaketkorelasyonu iddia edilmez.
- Yeni VV06zaman okuması19:53:14.3358545+03/16:53:14.3358545Z;W32TimeDC01kaynağı/stratum2/lastsync19:45:06aynı. Bu çıktı geçmiş123saniyelikDC–Linuxfarkının düzeldiğini kanıtlamaz.
- **Açık sıradaki adım:** DC01'dehostname,W32Timesource/status vePDCrolü saltokunurkontrol. Saat/NTP/DNS/GPO/policy/certayarları asistan tarafından değiştirilmedi. Daha geniş B10kimlikvaryantları veB11kesinzamankorelasyonu açık kalır.

## VLAN140 uç DHCP kabulü başarısız; DC01–Linux zaman farkı salt okunur ölçüldü — 21 Ekim 2026

- **VLAN140 sonrası VV06 Wi-Fi:**169.254.206.66/16,PrefixOriginWellKnown,AddressStateTentative. Bu geçerli140DHCPkirası kanıtı değildir; uçIP/DHCPkabulü tamamlanmadı. CSV'de140Access-Acceptgönderimi ve doğru sertifika/policy kabulü korunur; mevcut arayüz802.1Xdurumu bu yeni IPçıktısında ayrıca bulunmuyor. DHCPscope,140ağyolu/APuplinktagging veya başka nedenler henüz belirlenmedi.
- **🔴✓ Windows zaman kaynağı okundu:** VV06yerel19:50:22.6486991+03/UTC16:50:22.6486991Z;W32Timesource dc01.vizyonveri.local/10.35.50.70,stratum2,leap0,lastsync19:45:06. Sunucu adı veUTCyereldönüşümü tutarlı; tek başına mutlak saatin doğruluğunu kanıtlamaz.
- **🔴✓ Linux→DC01 saltokunur SNTP karşılaştırması:** Linuxyerelsaatine göre16:53:19.072151ZölçümündeDCminusLinux=-123.123390s,RTT0.000973s,DCstratum1/leap0. Yanıt kaynağı10.35.50.70,mode4veoriginatetimestamp eşleşmesi doğrulandı. Bu, önceki olasıWindows/RADIUSolaylarındaki123–124sfarkıyla uyumlu güncel relatif farktır; geçmiş ortakpaket korelasyonunun kesin kanıtı değildir.
- LinuxNTPkaynağıntp.ubuntu.com/185.125.190.57,FallbackNTPServersntp.ubuntu.com,VMwareToolszamaneşitlemesiDisabled; öncekiNTP=yes/NTPSynchronized=yesgözlemi. DC01upstreamkaynağı veya mutlakUTCdoğruluğu henüz sorgulanmadı. “LinuxNTPeşzamanlı” durumu DC01ileeşit saat anlamına gelmez.
- **Açık takip:** Wi-Fi802.1Xgünceldurum + yalnızWi-FiDHCPrenew; kullanıcı tarafından140DHCPscopeveAP/switch/uplinkVLANyolu kontrolü. Sonra müşteriADzamanotoritesi kaynağı/korelasyon incelemesi; hiçbir saat/NTP/DNS/GPO/policy/cert/serverayarına asistan müdahalesi yok. Saat düzeltmesiyle geçerlilik koşulları yapay olarak değiştirilmez.

## 🔴✓ Kablosuz policy VLAN140 değişikliği operatör tarafından doğrulandı — 21 Ekim 2026

- Operatör açıkça **VLAN140'ı kendisi değiştirdiğini** bildirdi. CSV ID20/21'de19:33:34.238/19:33:50.953+03 policy authwire-pilot-wireless/POLICY_ALLOW/TLStrue/güncel VV06sertifikası ile140gönderilmesi bu bilinçli değişiklikle uyumludur; yanlış VLAN olayı veya otomatik policy düzeltme gereği olarak değerlendirilmez.
- **🔴✓ Policy değişikliğinin RADIUS yanıtına140olarak yansıması** dar kontrolü tamamlandı;140sonrasında VV06Wi-FiDHCPadresi henüz paylaşılmadı, bu uçkabul açık. Bilinen110IP'si140sonrası ölçüm yerine kullanılmaz.
- B11 yaklaşık124saniye Windows/RADIUS olası zaman farkı açık. Sıradaki saltokunur adım Wi-FiIP,Windowsyerel/UTCzamanı veW32Timekaynağını okumaktır; saat/NTP/Windowsprofil/policy üzerinde asistan değişikliği uygulanmadı. Linux öncekiNTP=yes/NTPSynchronized=yes gözlemi korunur; geçmişteki olayların kesin eşleşmesi bundan türetilmez.

## 🔴✓ VV06 kablosuz CSV'de güncel sertifika/kimlik/policy eşleşmesi; VLAN140 ve zaman korelasyonu takipte — 21 Ekim 2026

- **🔴✓ Operatör CSV'si salt okunur incelendi:** AuthWire-erisim-kayitlari-2026-10-21.csv, SHA256 723d8a54bfb26b3e62d45fa85a60d8b995665b01572f0452469a2d0b3b04ad0d,16sütun/8geçerli satır,ID14–21;8ayrı event_id ve8ayrı request_id (bu örnekte aynı korelasyon anahtarlı mükerrer satır yok).6Access-Accept/2Access-Reject.
- **🔴✓ Tüm6kabul:** AP/NAS10.35.50.52,station10:b1:df:69:95:33,policy authwire-pilot-wireless,reasonPOLICY_ALLOW,sourcepolicy,TLStrue,identitycomputer,GUID69b0d5cd-db61-4627-9db7-fcc5230152a3 ve güncel seri26e43008251ac23612b2e654a6f6a259ee234f6e. Güncel VV06 sertifikasının bu kablosuz RADIUS kabullerinde seçildiği kayıttan doğrulandı; native sonuç endpoint/DHCP teslim kanıtıyla karıştırılmaz.
- **VLAN farkı açık:** ID14/15/17/19 yanıtında110,sonID20/21 yanıtında140. Son iki sunucu zamanı19:33:34.238 ve19:33:50.953+03;110yanıtı son19:29:18.275+03. Operatörün bilerek policyVLAN değiştirip değiştirmediği,aktif policykonfigürasyonu ve140sonrası endpointIP bu CSV'den belirlenemez; otomatik110'a çevirme yok.
- ID16/NATIVE_ACCESS_REJECT,native_generic,19:16:47.280+03;ID18/TLS_CERTIFICATE_UNTRUSTED,native_category,19:28:10.930+03. İkisindeTLSfalse/serial-GUID-policy-VLANboş; doğrulanmamış kimlikyetkilendirmesi yapılmamasıyla tutarlı. Client-side yanlış sunucu/kök testleriyle kesin birebir paket eşleşmesi iddia edilmedi.
- **B11 zaman farkı açık:** Windows19:10:07/19:14:44/19:26:07 ile olası sunucuID15/16/18eşleşmeleri+123.953/+123.280/+123.930saniye fark gösteriyor. Bu güçlü bir yaklaşık2dakika4saniye sapma işaretidir; saat kaynağı ve kesin eşleşme doğrulanmadı. Linuxsaltokunur16:48:26.712719ZkontrolündeEurope/Istanbul,NTP=yes,NTPSynchronized=yes. Hiçbir sistem saati veya NTPkonfigürasyonu değiştirilmedi.
- CSVanalizi ve kablosuz sertifika/policy/kimlik alt kabulü **tamamlandı**; B10/B11tümü, kesin zaman korelasyonu ve140DHCPkabulü açık kalır. Sunucu/Windows/policy/cert/CA/RADIUSprosesleri değiştirilmedi.

## 🔴✓ B10 VV06 yanlış kök seçimi reddi ve doğru profile/VLAN110'a geri dönüş saha kabulü — 21 Ekim 2026, 19:26 İstanbul

- **🔴✓ Test önkoşulu:** KANAME rootC789A0595ADB95A6BE4534D01B1D205F6C37DE18 hemLocalMachine\\Root hemCurrentUser\\Root'ta aynı cert olarak bulundu; önceki profildeki0FF97F30... bu iki depoda bulunmadı. Sertifika silinmedi/yüklenmedi. Alternatif geçerli self-issued yerel kök AAA Certificate Services, Comodo CA Limited, thumbD1EB23A46D17D68FD92564C2F1F1601764D8E349,NotAfter1Ocak2029 seçildi.
- **🔴✓ Yanlış kök export doğrulaması:** C:\Users\administrator\AuthWire-WrongRoot-20261021-192604\Wi-Fi-VV_802.1X.xml; komut XML'de yalnızAAA hash'ini doğruladı;PMKCacheMode=no/ConnectionMode=manual başarılı. Diğer doğru server-name/machine/validation/prompt ayarları korunması talimatı verildi; bu test exportunda bu alanlar ayrıca basılmadı.
- **🔴✓ 19:26:07+03 EAPtype13/12011 ardından12013 ve11006:**0x800B0109 (CERT_E_UNTRUSTEDROOT),EAP0x80420301; Windows kök neden metni ağ için kök sertifikası doğrulamasının başarısız olduğunu belirtiyor.19:26:08+03 olay8002 ve arayüzdisconnected. Bu, AAA sertifikasının genel Windows deposunda bozuk/geçersiz olduğu anlamına gelmez; server zincirinin test profilinde seçilmiş köke güvenemediğini gösterir.
- **🔴✓ Geri dönüş:**19:08 doğru KANAME root/server-name exportu başarıyla yüklendi, VV_802.1X/aynıAPBSSIDf0:61:c0:cc:73:54/MAC10:B1:DF:69:95:33/WPA2-Enterprise(FT)/CCMPconnected ve Wi-Fi10.10.110.2/24Preferred yeniden ölçüldü. Geri dönüş12012 veya seçilen leafseriali yeniden toplanmadı; profile fields sonradan yeniden export edilmedi.
- Dar B10 yanlış kök reddi/geri dönüş senaryosu **tamamlandı**; tüm B10 paketi veya kullanıcı kimlik doğrulaması tamamlandı sayılmaz. Sunucu/RADIUS/policy/CA/native module/sharedsecret değişmedi; gerçek expiry saha testi ayrı cihaz bekliyor.

## 🔴✓ B10 VV06 yanlış RADIUS sunucu adı reddi ve doğru profile geri dönüş saha kabulü — 21 Ekim 2026

- **🔴✓ Pozitif → olumsuz → geri dönüş:**19:10:07+03 doğru kaname.vizyonveri.local/KANAME root/machine EAP-TLS ile12012/8001 ve10.10.110.2/24; operatörün yanlış yanlis-radius.vizyonveri.local adıyla kontrollü denemesinde19:14:43+03 EAPtype13başlangıcı,19:14:44+03 olay12013/11006/8002,0x800B0114 ve0x80420101; arayüzdisconnected.
- 0x800B0114=Microsoft CERT_E_INVALID_NAME (isim izin verilen listede değil veya dışlanmış). Tek başına genel Windows “kullanıcı sertifikası geçersiz” metni istemci leaf'inin bozulduğunu kanıtlamaz. Önce/sonra kontrollü sonuçlar sunucu adı kısıtının beklendiği gibi reddettiği dar saha kabulünü destekler; paket/chain düzeyi trace alınmadı.
- **🔴✓ Geri dönüş:** operatör C:\Users\administrator\AuthWire-WiFi-Verified-20261021-190808\Wi-Fi-VV_802.1X.xml doğru yedeğini netsh add profile ile başarıyla yükledi; sonraki çıktı VV_802.1X/aynı APBSSID/MAC, WPA2-Enterprise(FT)/CCMP veconnected. Geri dönüş çıktısında IP veya12012 yeniden gösterilmedi; önceki10.10.110.2 yeni ölçüm gibi sunulmaz.
- Testte PMKCacheMode=no/ConnectionMode=manual komutu başarılı; doğru exportun geri yüklenmesi özgün ayarlara dönüş işlemidir (sonrasında alan bazında ayrı export karşılaştırması yapılmadı). Ethernet yönetimi korunması talimatı verildi; sunucu/RADIUS/policy/CA/native module/sharedsecret değiştirilmedi.
- **Yalnız bu B10 alt senaryosu tamamlandı.** Diğer kablosuz negatif güven/kimlik, kullanıcı EAP-TLS ve geniş B10 kabulü açık; gerçek expiry saha testi ayrı cihaz bekliyor.

## 🔴✓ VV06 doğru sunucu güven profiliyle kablosuz yeniden bağlantı kabulü — 21 Ekim 2026, 19:10 İstanbul

- **🔴✓ 19:10:07+03 WLAN zinciri:**8000 bağlantı başlangıcı,11000/11001 ilişkilendirme,12011 EAPtype13 başlangıcı,12012 802.1Xsuccess (host/AuthWire computer69b0d5cd-db61-4627-9db7-fcc5230152a3),11005 güvenliksuccess,8001 bağlandı. Son arayüz VV_802.1X/APBSSIDf0:61:c0:cc:73:54, WPA2-Enterprise(FT)/CCMP; Wi-Fi10.10.110.2/24Preferred.
- Bu, 19:08 exportunda doğrulanan doğru KANAME root/server-name/prompt ayarlarından sonraki pozitif istemci bağlantı kabulüdür. Hangi leaf serialinin seçildiği ve TLS full/resumption ayrımı bu çıktıda ölçülmedi.
- **B10 yanlış sunucu adı olumsuz saha testi ve doğru profile geri dönüş halen bekliyor.** Yalnız VV06 Wi-Fi üzerinde test; doğru export C:\Users\administrator\AuthWire-WiFi-Verified-20261021-190808\Wi-Fi-VV_802.1X.xml geri dönüş noktası. Testte PMK caching geçici kapatılıp doğru export geri yüklenerek özgün ayarlar korunacak; henüz uygulanmış sayılmaz.
- Sunucu/RADIUS/policy/CA/shared secret/Ethernet değişmedi; daha geniş B10 paketi tamamlanmadı.

## 🔴✓ VV06 Wi-Fi profilinin sunucu güven ayarları düzeltildi ve export ile doğrulandı — 21 Ekim 2026, 19:08 İstanbul

- **🔴✓ Operatörün elle kaydettiği güncel profil exportu:** C:\Users\administrator\AuthWire-WiFi-Verified-20261021-190808\Wi-Fi-VV_802.1X.xml.
- authMode=machine; ServerNames=kaname.vizyonveri.local; TrustedRootCA=C789A0595ADB95A6BE4534D01B1D205F6C37DE18; PerformServerValidation=true; AcceptServerName=true; DisableUserPromptForServerValidation=true. İstemci profili doğru sunucu adı ve KANAME köküyle sınırlanmıştır; kullanıcı onayıyla doğrulama hatasını geçme kapalıdır.
- Bu kabul **yalnız profil yapılandırması ve yedeği** içindir. Kaydetme sonrası yeniden bağlantı, taze tam EAP/leaf seçimi ve yanlış server-name reddi → doğru profile dönüş henüz doğrulanmadı; B10 saha olumsuz kabulü açık kalır. Önceki FT oturum başarısı yeni ayarların el sıkışması kanıtı sayılmaz.
- Sunucu/policy/CA/native RADIUS/shared secret/Ethernet değiştirilmedi. Gerçek expiry saha testi ayrı cihaz bekliyor.

## VV06 Wi-Fi pozitif bağlantı görüldü; istemci sunucu güveni düzeltmesi bekliyor — 21 Ekim 2026

- **🔴✓ Dar pozitif gözlem:** VV06, RTL8852BE/MAC10:b1:df:69:95:33 ile VV_802.1X/APBSSIDf0:61:c0:cc:73:54 bağlantısı; WPA2-Enterprise(FT)/CCMP, EAP-TLS, machine credential ve Wi-Fi10.10.110.2/24Preferred operatör çıktısında görüldü. Bu gözlem seçilmiş leaf serialini veya taze tam EAP el sıkışmasını kanıtlamaz.
- **🔴✓ Değişiklik öncesi profil yedeği:** C:\Users\administrator\AuthWire-WiFi-Backup-20261021-185927\Wi-Fi-VV_802.1X.xml, netsh export başarılı.
- Yedek XML: authMode=machine, PerformServerValidation=true; ServerNames boş, AcceptServerName=false, DisableUserPromptForServerValidation=false. TrustedRootCA=0FF97F30A22CC23776A994B72CF6279C3A365281; beklenen KANAME Root6796fa84/C789A0595ADB95A6BE4534D01B1D205F6C37DE18 ile eşleşmiyor. Farklı hash'in hangi CA olduğu ve mevcut oturumun neden kabul edildiği henüz belirlenmedi; FT/cache veya prompt olasılıkları kanıtlanmış neden değildir.
- **Bekliyor:** yalnız VV06 Wi-Fi profilinde doğru server-name/root ve promptsuz reddetme ayarını elle düzeltme, yeni export ile doğrulama, taze bağlantı kabulü; sonrasında B10 yanlış server-name reddi ve doğrulanmış doğru profile dönüş. B10 tamamlandı sayılmaz. Sunucu/policy/CA/native RADIUS/shared secret veya Ethernet ayarına müdahale yoktur.

## Sonraki saha adımı: VV06 kablosuz server-name olumsuz güven testi; gerçek expiry ayrı cihaz bekliyor — 21 Ekim2026

- Operatör seçimi: **şu an yalnızVV06 var.** Enrollment profile mevcut kuralı en az2gün geçerlilik ve en az1gün renew-before ister. Gerçek expired-pending saha testi bugün tamamlandı sayılmaz; **ayrı test cihazı bekliyor** olarak açık tutulur. Geçerli VV06 cert/key veya sistem saati değiştirilmez.
- Sıradaki dar kabul **B10 kablosuz yanlış RADIUS server-name reddi → özgün doğru profile geri dönüş**. SSIDVV_802.1X, AP10.35.50.52, beklenen server-namekaname.vizyonveri.local. İlk adım VV06'da yalnız Wi-Fi profil/arayüz bilgisi okumaktır; henüz profil/server/policy/CA/shared-secret değişikliği yoktur.
- Ethernet yönetim bağlantısı başlangıçta korunur. Herhangi bir profile edit öncesi özgün kablosuz profile yedeği alınacak; server certificate validation açık kalacak. Bu senaryo başlamadı/tamamlanmadı diye ayrılır; gerçek expiry bekleyen maddesi veya eski pozitif kablosuz kabulü bununla karıştırılmaz. DHCP/DNS mimarisi kapsam dışı kalır.

## 🔴✓ VV06 doğrulanmış dev.12 signed kopyadan sonra taze normal görev kabulü tamamlandı — 21 Ekim2026,18:29 İstanbul

- **🔴✓ Operatör manuel task start sonrası:**AuthWire Certificate EnrollmentLastRun21Ekim18:29:17+03,Ready/LastTaskResult0; statusinstalled, error/stage/server_error raporlanmadı; retry.jsonfalse. Bu çalışma, exact hash/publisher ile doğrulanmış yeni signed istemci kopyasından sonradır.
- **🔴✓ Mevcut sertifika serisi korundu:**26e43008251ac23612b2e654a6f6a259ee234f6e aynı. Güncel thumbprintF5596CFE0AA4FD4F9378EB0699DF4FB4FC275119 kaydedildi; aynı leaf için önceki thumbprint karşılaştırması yapılmış gibi sunulmadı. Önceki boot çıktısında privatekeytrue/pendingfalse/EthernetAuthSuccess/10.10.110.4/24 doğrulanmıştı; bu yeni çıktı pending/EAP/IP'yi ayrıca yeniden ölçmez.
- **🔴✓ dev.12 teslim ve normal çalışma kabul zinciri kapandı:** Linux kaynak/koruma/backup/izole restore → DC01 same-publisher signed client/SYSVOL/ACL koruması → VV06 exact signed copy/boot/cert-key/Ethernet/IP koruması → yeni kopyadan sonra fresh taskReady0/installed/seri aynı/retryfalse. Sadece bu dar teslim/günlük çalışma zinciri tamamlandı; tüm B06 veya projenin tamamı bitmiş sayılmaz.
- **Açık:** actual expired-pending uç cihaz saha kurtarması, diğer kalan yaşam döngüsü varyantları ve önceki aralıklı test kararlılığı bulguları. Bu adım için geçerli cert/key/saat/policy değişikliği veya zorla yenileme uygulanmadı. Kesin RADIUS-selected-leaf/zaman eşleştirmesi ayrı kapsamdır; DHCP/DNS mimarisi kapsam dışı kalır.

## 🔴✓ VV06 dev.12 signed client kopyası ve boot sonrası görev/cert/kablolu ağ kabulü tamamlandı — 21 Ekim2026

- **🔴✓ Gerçek GPO/endpoint teslimi:** VV06ClientUpdatedtrue; signed full-fileSHA59C86CF55E5110E23DF16388928580FE8D2050B59C999A0E09CA2599286790B3 ile eşleşiyor. SignatureValid ve mevcut publisher6E74B513F766E01730719684A41B2664380CA68A doğru.
- **🔴✓ Boot/task:**boot18:14:12+03; taskLastRun18:14:24+03; RanAfterBoottrue, Ready veLastTaskResult0. Bu12s task başlangıcı farkıdır, tamamlanma süresi ölçümü değildir.
- **🔴✓ Mevcut kimlik ve ağ korunması:**installed serial26e43008251ac23612b2e654a6f6a259ee234f6e aynı;HasPrivateKeytrue,pendingfalse,retryfalse. Gerçek Ethernet38-CA-84-DB-FF-E6 Authentication succeeded; IP10.10.110.4/24Preferred mevcut VLAN110 ağıyla uyumlu. Bu çıktı bu boot'ta RADIUS'un seçtiği leaf serisinin ayrı server kanıtı değildir.
- Bu dar copy/boot/sağlıklı kablolu ağ kabulü tamamdır. GPO dosya kopyası ile ilk task process launch sırası ölçülmediğinden, doğrulanmış yeni kopya sonrasında bir taze normal görev çalışması exact updated-source execution kabulünü tamamlayabilir. **Gerçek expired-pending saha kurtarması ayrı açık kalır**; geçerli mevcut sertifika/anahtar/sistem saati bu adımda değiştirilmedi. Önceki test kararlılığı bulguları ve DHCP/DNS kapsam dışı kararı korunur.

## 🔴✓ DC01 aynı publisher ile dev.12 istemciyi SYSVOL'e teslim etti — 21 Ekim2026,18:02 İstanbul

- **🔴✓ Operatör çıktısı SYSVOL_CLIENT_UPDATED/verifiedtrue/updatedtrue:** mevcut publisher`6E74B513F766E01730719684A41B2664380CA68A` ile yeni AuthWire-Client.ps1 imzalandı. BodySHA`bf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60`; signed full-fileSHA`59C86CF55E5110E23DF16388928580FE8D2050B59C999A0E09CA2599286790B3`.
- **🔴✓ Koruma/yedek:**`C:\ProgramData\AuthWire-Admin-Backup-20261021-180253-88c863b5c1bc46cb99b6b9fb6b74b8ca`. Installer ve signed assets korundu; tek AllSigned Startup girişi ve paket izinleri korundu. GPO ayarları ve Windows görevleri bu DC teslim adımında değişmedi.
- **Henüz açık:** VV06'nın bu yeni signed dosyayı gerçekten aldığı/çalıştırdığı bu çıktıdan anlaşılmaz. Sıradaki dar kabul doğal bilgisayar GPO/boot dağıtımı, exact signed file hash/publisher, boot/task sonucu, mevcut cert/key, Ethernet802.1X ve VLAN110 korumasıdır. Yeni istemci aldıktan sonraki temel kabul, gerçek expired saha kabulünden ayrı tutulur. Dev12 Linux canlı kaynağı daha önce kabul edilmişti; aralıklı CI/yerel test kararlılığı bulguları ve DHCP/DNS kapsam dışı kararı korunur.

## 🔴✓ dev.12 Linux canlı güncellemesi, koruma ve gerçek yedekte izole restore tamamlandı — 21 Ekim2026

- **🔴✓ Operatör sudo çıktısıyla canlı kaynak güncellemesi kabul edildi:**0.14.0-dev.12, HTTPS doğrulandı; Windows istemci sourceSHA`bf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60`. Sonrasında salt okunur remote kontrol de aynı sürüm/hash'i doğruladı. Evidence`/var/backups/authwire/scheduled/expired-recovery-dev12-20261021T145726Z-ec221763`; özgün before snapshot kalıcı.
- **🔴✓ Koruma:**files/pids/timers/business_state tümütrue. RADIUS PID326873 ve broker149955 aynı/active; RADIUS yeniden başlatılmadı. Panel kaynak güncellemesi sonrası PID573680active. Config, admin kullanıcı/profil, CA/cert/key, policy, native modül ve backup timer korundu. Önce/sonra bütün API ölçümleri200.
- **🔴✓ Yeni before/after yedekler ve izole veri restore:**before`authwire-scheduled-20261021T145825Z-b81963bb89a2.tar.gz` SHA83c02df6be9f54cf89c1bf0a653e5e025441cd3f9372791fd980139a17da7abe; after`authwire-scheduled-20261021T145925Z-258c41968bd4.tar.gz` SHA4cb6670c7135942e6b416a09fb5e27b14e694ee3c92293ca76afd56f711c5c39. Gerçek after yedeğinde160dosya byte/owner/mode, DB/config/policy/admin, private secrets, CA/signer/key eşleşmesi/probe imzası, web/RADIUS cert-key, CRL ve access-history bütünlüğü doğrulandı; kopya kaldırıldı. Restore kodu/servisleri çalıştırılmadı ve ağ çağrısı yapılmadı. Tam appliance boot restore kabulü hâlâayrı açık.
- **Sıradaki açık kapı DC01 signed SYSVOL client teslimidir.** Bu adımda Linux'taki Windows istemci şablonu değişti; VV06/Windows endpoint ve mevcut signed SYSVOL paketi değişmedi. Generic updater'ın`windows_changed:true` alanı source-template farkını ifade eder;`windows_endpoints_changed:false` ve final`windows_changed:false` bu sınırı doğrular. İmzalı client teslimi, VV06 boot/cert/key/EAP/VLAN koruması ve gerçek expired saha kabulü henüz tamamlanmış sayılmaz.
- DC helper`/home/segmentiq/authwire-sysvol-client-update-20261021.ps1` SHA`a1bc6a0dac570409b4e07b62d0aa4b6065950f281065f7f0e70636dba8186965` yeniden doğrulandı; Linux SSH hizmeti active, ED25519 fingerprint`SHA256:2WcdB102dnmUsOGSnSL9ptqJ0NimJ7Gve6WhFmwmpxY`. Operatöre GitHub oturumu/dosya indirme bağımlılığı olmadan DC01'den SCP + hash kontrollü çalıştırma adımı verilecek. Önceki aralıklı CI/yerel test kararlılığı bulguları ayrı açık kalır; DHCP/DNS mimarisi kapsam dışıdır.

## 🔴✓ dev.12 teknik kabulü ve korumalı teslim hazırlığı tamamlandı; canlı uygulama bekliyor — 21 Ekim2026

- **🔴✓ Yedi CI kontrol grubu başarılı:** candidate39676196d72d5a7e467857b981fe141c786ce672 için foundation39617785888, enrollment39617785953, native RADIUS39617785931, GPO/restore39617785904, browser39617785900, Linux preparation39617785929 ve bounded network retry39617785891. Temel tur547test/25skip/hata0; gerçek SYSTEM expired-pending/yeni CNG key/leaf kurulumu, ayrı native KDC ve normal/debug RADIUS kontrolleri geçti. PR42, expected-head kontrolüyle **b3b0936ed4c8acdf3a0d7f0524ceb1305413d70c** olarak birleştirildi; bu işlem canlı kurulum değildir.
- **🔴✓ Korumalı teslim testleri:** Linux kaynak koruma ve embedded payload için7odak testi başarılı. DC01 helper'ı yalnız mevcut publisher ile client dosyasını imzalar/değiştirir; kurucu/assets/Startup/ACL korunur. Windowsjob119283136477 gerçek imza, atomic swap, idempotence, asset/publisher retleri ve post-replace hata sonrası birebir rollback'i geçti. Tarihsel installer-only fixture'ları kendi accepted dev11 client'ında tutuldu; yeni readonly audit yeni client pinini tanır.
- **🔴✓ Aynı son head için doğal SYSTEM retry kontrolü iki tur başarılı:**119283136099 ve119284494311. Önceki180s süre aşımlarının kesin nedeni **belirlenmedi**; prod launcher değiştirilmedi ve bulgu silinmedi. Yeni tanılama yalnız UUID test görevlerini ve sınırlı zaman/sonuç alanlarını kaydeder. İlk tanılama denemesindeki null NextRunTime hatası düzeltildi.
- **Ayrı yerel test kararlılığı kaydı:** ek geniş yerel tur547test/25skip/3hata verdi: admin loopback login timeout, concurrent access-history STORAGE_BUSY ve broker temporary-directory cleanup race. Bu üç test tek başına2.736s içinde geçti; ilgili kaynak ve test byte'ları kabul edilmiş dev11 ile aynı. CI tam turunun başarılı olması yerel hata kanıtını silmez; kök neden/yük altında tekrar üretim ayrı açık takipte. Bu sürümde bu ilgisiz server/broker kodları değiştirilmedi.
- **🔴✓ Kurulum paketi sunucuda hazır:**139kaynak dosyasının Git blob kimlikleri mergecommit ile birebir karşılaştırıldı; remote manifest ve her dosya hash'i doğrulandı. Stage`/home/segmentiq/authwire-stage-dev12-b3b0936ed4c8`, manifestSHA`b53c4df2c52ede56719c13cac4fb84053045120cfeb0f8ccd687c6298ed0d386`. Operator helper`/home/segmentiq/authwire-expired-recovery-update-20261021.py`, SHA`80167d1329cc09fc06ca38f25509f73e19a0b936929c8a9dfb95a235856ad0c9`; test edilmiş template'ten yalnız stage/digest/release sabitleri farklı. Venv cryptography46.0.0 doğrulandı. Signed SYSVOL helper da`/home/segmentiq/authwire-sysvol-client-update-20261021.ps1` konumunda hazır; henüz çalıştırılmadı.
- **Canlı hâlâdev11:** panel428758/RADIUS326873/broker149955active; installed clientSHA86081... korunuyor. Bu hazırlıkta yeni backup alınmadı, canlı kaynak/SYSVOL/Windows/cert/policy değişmedi ve servis yeniden başlatılmadı. Sıradaki zorunlu operator adımı sudo ile pinned helper: fresh backup, before/after durum koruma, RADIUS/broker PID koruması, API ve izole restore kontrolleri; ardından DC01 aynı publisher ile signed client teslimi ve VV06 kabulü. Gerçek expired saha kabulü ve tanılama için saklanan eski expired request/key'in otomatik temizliği açık kalır. DHCP/DNS mimarisi müşteri kararıyla kapsam dışıdır.

## 🔴✓ Native Windows expired-pending kurtarma ve gerçek RADIUS teknik testleri geçti — 21 Ekim2026

- **🔴✓ Tamamlandı: izole, imzalı SYSTEM Windows teknik kabulü.** Candidatea89869cdde2b22688df66433a6a9ac8f5ca20f66/device run39613894826/windows-client job119269650239 başarılı. Production main AST, gerçek CNG/CSR proof/chain/certreq/receipt ile expired pending reddi, birebir arşiv, yeni nonexportable anahtar/CSR ve yeni leaf kurulumu doğrulandı; ilgisiz mevcut kimlik korundu. Kerberos taşıması bu fixture'da sentetiktir; saat/müşteri durumu değiştirilmedi, gerçek retry deadline beklenmedi. Ayrı native MIT KDC job119269650421 ve1000sentetik cihaz yük kontrolü de geçti. Önceki aralıklı4-worker SQLite bulgusu bu sonuçla kapanmış sayılmaz.
- **🔴✓ Gerçek native RADIUS:** run39613895299/job119269652889 başarılı; normal mod29 ve debug mod27 senaryo, expired/revoked/wrong-purpose/CA/server-name retleri, gerçek authenticated VLAN yanıtları ve normal modda300s native CRL cache reload/süreç koruması geçti. Production runtime parse/ilişkili35test de başarılı. Başlangıç engeli yalnız izole lab çağrısında explicit dictionary dizini ve stdout log hedefiyle giderildi; capability veya canlı servis ayarı gevşetilmedi. Görünen ptrace uyarısı kesin kök neden ilan edilmedi.
- **🔴✓ Actions başlatma engeli kalktı:** taze test adımları gerçekten çalışıyor; ödeme/bütçe ayarı değiştirilmedi. Aynı head için foundation39613895446, browser39613896020, Linux source preparation39613894982 ve bounded retry39613895022 başarılı.
- Windows fixture'ın ilk yeni denemesinde parent kullanıcıya ait CurrentUser DPAPI sırrı SYSTEM içinde açılmaya çalışılıyordu. Yalnız test fixture'ı, issuer'ı kendi kullanıcı sürecinde tutan özel/UUID korelasyonlu dosya IPC ile düzeltildi; production Vault/DPAPI kapsamı gevşetilmedi.
- **Açık kapı:** Aynı son head'deki ayrı windows-retry job119269650741, otomatik failure/rearm/recovery180s kontrolünde timeout verdi. Bu ayrı kontrol önceki7574head/device run39612729264 içinde başarılıydı; aralıklı sonuç kayıttan silinmedi ve yeni expired fixture başarısıyla örtülmedi. Job yeniden yürütme ve failed-jobs yeniden yürütme istekleri GitHub tarafından403/already-running ile reddedildi: bütün listelenen işler terminal görünmesine rağmen run39613894826 hâlâin_progress raporluyor. Yeniden deneme ve gerekirse dar task-state tanısı açık; bütün native gate'ler yeşil sayılmaz.
- **Canlı salt okunur doğrulama:** segmentiq panel428758/RADIUS326873/broker149955active; kurulu0.14.0-dev.11 ve clientSHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15 değişmedi. **PR42 taslak; merge, canlı kaynak güncellemesi, signed SYSVOL teslimi ve VV06 gerçek expired saha kabulü yapılmadı.** Candidate clientSHAbf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60. Eski expired-pending request/key tanılama için saklanır; yeni otomatik temizleme kapsam dışıdır. DHCP/DNS müşteri kararı kapsam dışı kalır.

## Actions yeniden kontrolü: taze denemede de test adımı başlamadı — 20 Ekim2026, 19:48 İstanbul

- Operatör “bir daha kontrol et” talebi üzerine PR42 güncelhead8b714c475590c5a0ae512c5533961064b0b6131d ve deviceworkflowrun105/39458971058 kontrol edildi; yeniden yürütme isteği kabul edildi.
- Attempt2 başlangıç16:47:57Z, bitiş/güncelleme16:48:02Z;5s içinde failure. Güncel Windowsjob118758738683 için steps=[] doğrulandı; nativeWindows test çalışmadı. Bu, yalnız eski failure ekranının okunması değildir; yeni bir deneme yapıldı.
- Önceki ödeme/harcama limiti annotation'ı operatör görseliyle doğrulanmıştı. Yeni attempt'in annotation ayrıntısı bağlantıda görülemediğinden aynı mesajın tekrar okunduğu iddia edilmez; başlangıç engelinin kalktığı henüz doğrulanamadı.
- PR42draft ve teslim/native kabul kapıları açık kalıyor. Bu kontrolde canlı kaynak, SYSVOL, Windows veya sertifika değişikliği yapılmadı.

## GitHub native test engeli ödeme/harcama limiti olarak doğrulandı — 20 Ekim2026, 19:39 İstanbul

- Operatörün image(20261020-163906).png ekran görüntüsü bizzat okundu. Actionsrun104/39458558838 Annotations, job'ın hesap ödemesi başarısızlığı **veya** harcama limitinin artırılması gerektiği için başlatılmadığını açıkça söylüyor; Billing&plans kontrolü isteniyor. İki olasılıktan hangisinin hesapta geçerli olduğu henüz bilinmiyor; yalnız kota doldu/yalnız kart reddi diye daraltılmadı.
- Bu provider engeli nedeniyle test adımları çalışmamış; candidate Windows/RADIUS testleri başarılı sayılmaz. Yerel514geçen/25skip sonucu ve PR42taslak korunuyor. Aday0.14.0-dev.12 merge/teslim edilmedi; canlı0.14.0-dev.11 ve çalışan802.1X değişmedi.
- Ödeme veya ücretli Actions bütçesi hesap sahibi tarafından yönetilecek; asistan ödeme yöntemi/bütçe ayarı değiştirmedi ve harcama yetkisi varsaymadı. Engel kalkınca güncel candidate head için native testler yeniden yürütülecek.
- Kanıt Librarylibfile_8695c571f9a081918c8bc889c0541e90, SHAe81d95866e76621102da5c47d5892ac81d26e905e2fbcf5ddbb7c5e095a6e4ac. Expired saha kabulü açık, DNS/DHCP kapsam dışı kalır.

## Expired-pending kurtarma açığı doğrulandı; düzeltme taslağı native test engelinde — 20 Ekim2026

- **🔴✓ Tamamlandı: izole kaynak/uygulama hata tekrar üretimi.** Aynı expired pending CSR iki kez DEVICE_CERTIFICATE_EXPIRED ile reddediliyor; yeni anahtar/CSR mevcut sunucuda taze yetkilendirmeyle toparlanıyor. Eski Windows istemcisinde pending.json bırakıldığı için aynı expired istek döngüye girebiliyor. Bu bulgu VV06'nın şu anki geçerli26e... sertifikasının arızalı olduğu anlamına gelmez.
- Taslak düzeltme **PR42** https://github.com/Asitavandas/kaname/pull/42, aday0.14.0-dev.12, sourceheadf6ddf71629f251cd40feb936cf5f24fe4f38d489; yalnız issue aşamasında açık expired yanıtı ve değişmemiş pending kimliği varsa eski istek özel expired-pending klasörüne taşınır. Sonraki normal retry yeni nonexportable CNG key/CSR üretir. Diğer hata kodları aynı pending isteği korur; arşiv hatası durum alanına yazılır. Eski request/key referansı tanılama için saklanır; sertifika/anahtar silme veya yeni otomatik arşiv/key temizliği bu taslakta yoktur.
- **🔴✓ Yerel teknik kontrol:**539test/25skip/hatasız (514geçti); odak26testgeçti; ilişkili55test/1skip/hatasız. Bunlar Windows SYSTEM/CNG veya yeni gerçek TLS testleri geçti demek değildir.
- **Açık/engelli:** GitHub Actions device run39458558838/windowsjob118751695669 ve RADIUSrun39458558740 test adımları başlamadan failure oldu. Windows steps=[] ve logBlobNotFound. Provider annotation bağlantının desteklediği read uçlarından alınamadı; kesin neden veya billing/kota tanısı uydurulmadı. Native Windows fixture ve güncel native TLS expired ret henüz çalıştırılamadı. PRdraft, merge/deploy yapılmadı.
- Canlı salt okunur kontrol: version0.14.0-dev.11, clientSHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15; panel428758/RADIUS326873/broker149955active. Üretim kaynak/SYSVOL/Windows, CA/policy ve saat ayarı değişmedi. Aday clientSHAbf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60.
- Normal profil en az2gün geçerli sertifika üretir. Canlı VV06 sertifikasının gerçek expiry saha kabulü, izole/native teknik testlerden ayrı kalır; Windows veya Linux saatini ileri alma uygulanmadı. Sonraki kapı Actions sağlayıcı hata metnini okuyup native doğrulamayı açmak, kontrollerden sonra korumalı kaynak ve signed SYSVOL teslimidir. DHCP/DNS kapsam dışı kararı korunur.

## 🔴✓ VV06 yarım kurulum → doğal retry → yeni seriyle taze kablolu EAP senaryosu tamamlandı — 20 Ekim2026

- **🔴✓ Tamamlandı: yeni sertifika ile taze802.1X kabulü.** Operatör dot3svc yeniden başlatma adımından sonra VV06 EthernetAuthentication succeeded ve20 Ekim19:15:52 yerel15505/Reason0/Error0 olayını paylaştı. Fiziksel MAC38:ca:84:db:ff:e6 ve cihaz GUID69b0d5cd-db61-4627-9db7-fcc5230152a3.
- AuthWire Linux ekran görüntüsü bizzat okundu: checked_at16:18:14.066703Z, en yeni kayıt16:17:55.541Z, response_code2/POLICY_ALLOW, **certificate_serial26e43008251ac23612b2e654a6f6a259ee234f6e**, policy_idauthwire-pilot-wired, VLAN110, tls_verified1 ve aynı MAC. Diğer iki satır daha önceki14:13:45Z/14:00:49Z olayları ve eski5899... serisidir; yeni testin çoğaltılmış kayıtları olarak sayılmaz.
- Önceden kabul edilen zincir: issue/result1/pendingtrue → doğal18:59:21 retry → ana18:59:25/Ready0 → aynı pendingcontainer ile yeni leaf/privatekey → pending/retryfalse → sunucuda aynı CSR tek issuance/final receipt ve önceki6eb... serisine receipt+24h retirement planı. Şimdi yeni26e... serisinin gerçek RADIUS/EAP kullanım kanıtı da var.
- **Bu dar kontrollü yarım kurulum senaryosu tamamlandı.** Expired, diğer kesilme noktaları/ilk kurulum varyantları, diğer negatif güven senaryoları ve kullanıcı EAP-TLS pilotu ayrıca açık kalır. Henüz gelecekteki6eb... retirement yürütmesi veya bu yeni çiftin12h yerel temizliği test edilmiş sayılmaz.
- Zaman korelasyonu sınırı: Windows15505 yerel19:15:52 ve sunucuaccept yerel19:17:55.541 arasında123.541s fark var. Ortak anda iki saat ofseti ölçülmedi; tekil tetik ile olayın saniye bazında birebir eşleşmesi/clock drift nedeni iddia edilmez. MAC/yeni seri/TLS ve operatör akışı yeni serinin taze kabulünü destekler; kesin çapraz kaynak zaman korelasyonu B11'de ayrı açık nottur. Saat/DNS/DHCP ayarı değiştirilmedi.
- Kaynak görselimage(20261020-161942).png Librarylibfile_948cb01ddfec819189f8249bfc69f8b9, SHA1605652bc6935c386f9145ef8cf98b5c65d22b257a3b415d0abb2457203aa3a5. Güncel rapor üretiminde bu alt adımlar kırmızı tik ile gösterilecek;19 Ekim PDF tarihli snapshot olarak kalır.

## VV06 yarım kurulum: tek issuance ve final receipt sunucuda doğrulandı — 20 Ekim2026

- **🔴✓ Tamamlandı: sunucuda aynı CSR için tek issuance ve kurulum onayı.** Seri26e43008251ac23612b2e654a6f6a259ee234f6e, CSRsha256fbad25474f7faff5fc29b85958cf5cbb138e0f05898e0882f677d11ac310440f; same_csr_issuance_count=1, tek issued ve installed audit kaydı paylaşıldı. installed_at/last_seen2026-10-20T16:02:33Z.
- **🔴✓ Tamamlandı: önceki6eb... sertifikasının emeklilik planı final receipt'ten24h sonra.** retire_at2026-10-21T16:02:33Z; bu henüz gelecekteki iptalin gerçekleştiği anlamına gelmez.
- Audit ilk üretim2026-10-20T15:41:24.427Z, kurulum16:02:33.879Z. İlk issue audit'i raporlanan18:39:28 yerel hata gözleminden sonradır; kesin hata-tetik/audit zaman eşleştirmesi ayrıca kanıtlanmış sayılmaz. Dar tek-issuance/receipt ve aynı pending anahtar istemci kanıtları korunur. Salt okunur canlı Linux tarih kontrolü16:15:29Z, araç16:15:27.352–16:15:29.671Z aralığında; NTP durumu çıktıda görülmedi, saat değiştirilmedi.
- **Son açık saha kapısı:** yeni26e... serisinin taze802.1X/EAP seçimi. Mevcut oturum Authentication succeeded/VLAN110 sonucu bunun yerine geçmez. Diğer expired/yarım kurulum çeşitleri ve kullanıcı EAP-TLS ayrı izlenir; DHCP/DNS kapsam dışı.

## VV06 yarım kurulumdan doğal toparlanma — istemci saha kabulü, 20 Ekim2026, 19:03 İstanbul

- **🔴✓ Tamamlandı: kontrollü issue aşaması yarım kalmasından doğal retry ile istemci toparlanması.** Retry18:59:21/result0 ana task18:59:25/Ready/result0; duruminstalled. Dört saniye retry ile ana task başlangıcı arasındaki farktır, toplam tamamlanma süresi değildir.
- **🔴✓ Tamamlandı: aynı bekleyen anahtar ile kurulum ve yerel durum temizliği.** installedserial26e43008251ac23612b2e654a6f6a259ee234f6e, CertificateChanged=true, SamePendingKey=true (AuthWire-2ee74dcc-e141-44b9-b546-cc3f360622f5), privatekeytrue, pending.json=false ve retry.json=false. Toparlanma öncesi installedserial6eb64486d4123a060ba8deb8bb6ea9054fab5b4f idi.
- **🔴✓ Tamamlandı: gözlem anında erişim koruması.** EthernetAuthentication succeeded,10.10.110.4/24Preferred. Bu yeni seriyle taze EAP kimlik doğrulaması yapıldığını tek başına kanıtlamaz; mevcut oturumun erişimi korunmuştur.
- **Açık son kanıtlar:** sunucuda aynı CSR için tek issuance/ilk üretim zamanı, final receipt/installed_at ve önceki sertifika retirement kaydı; ardından yeni serinin taze EAP seçimi. Bütün yarım kurulum çeşitleri veya expired kurtarma bu tek senaryoyla kapanmaz. DHCP/DNS kapsam dışı kararı korunur.

## VV06 yarım kurulum için doğal retry saati eşleşti — 20 Ekim2026, 18:50 İstanbul

- Operatör18:50:39: retry attempts1/stageissue/next_attempt18:59:21+03 ve retry taskNextRun18:59:21 birebir eşleşiyor. Bekleyen anahtar containerAuthWire-2ee74dcc-e141-44b9-b546-cc3f360622f5 olarak kaydedildi. Verilen yakalama komutu kalan handle'ı Dispose eder; ayrıca retry dosyası veya görev zamanı değiştirilmez.
- Mevcut installedserial6eb64486d4123a060ba8deb8bb6ea9054fab5b4f, özel anahtartrue ve EthernetAuthentication succeeded. Bu seri ilk18:26 baseline5899... serisinden farklıdır; arada başarılı çalışma vardır ancak değişimin kesin issuance/audit nedeni henüz okunmadı. Yenileme hiç başlamadı diye varsayılmaz. Toparlanma öncesi güncel karşılaştırma6eb... ve bu pendingcontainer üzerinden yapılacak.
- **🔴✓ Tamamlanan dar alt kontrol:** issue hatası sonrası gerçek retry deadline/görev eşleşmesi ve erişimin o anda sürmesi. **Açık:** doğal18:59:21 çalışması sonrası Ready0/statusinstalled, aynı pendingcontainer, yeni leaf/privatekey, pending/retry temizliği; sunucuda aynı CSR için tek issuance ve receipt doğrulaması.
- Sıradaki operatör kontrolü20 Ekim19:03 civarı; görev elle başlatılmayacak. Doğal çalışma ve süreli jitter tamamlanmadan başarı ilan edilmez; bu kayıt tüm yarım kurulum kabulünü kapatmaz.

## VV06 hedeflenen yarım kurulum kesintisi görüldü — 20 Ekim2026, 18:39 İstanbul

- Operatör önceki uygulamayı yanlış yaptığını bildirdi ve aynı kontrollü adımları tekrarladı.18:37:53 ana task,18:39:28 kontrolde Ready/result1, statusretry_pending, stageissue, ServerError boş ve pending.json=true.
- **🔴✓ Tamamlandı: hedeflenen issue aşamasında başarısız çalışma ve pending isteğin korunması alt adımı.** Bu çıktı hata/toparlanma testinin beklenen kesintisidir; normal ürün arızası olarak veya tüm yarım kurulum kabulünün tamamlanması olarak işaretlenmez.
- **Açık:** dosya kilidinin bırakıldığının ve eski sertifika/erişimin korunduğunun doğrulanması; pending CSR/anahtar kimliği ve gerçek next_attempt/taskNextRun zamanının yakalanması; doğal retry sonucunda aynı istekle kurulum, tek issuance/receipt ve temiz durum. Görev elle tekrar başlatılmayacak, pending/retry dosyaları silinmeyecek.
- Önceki18:36 sonuçsuz deneme tarihsel kayıtta korunur; güncel kesinti kanıtı bu ikinci çıktıdır. DHCP/DNS yapılandırması kapsam dışı kalır.

## VV06 yarım kurulum denemesi hedef kesintiyi doğrulamadı — 20 Ekim2026, 18:36 İstanbul

- Operatör:18:36:00 ana task,18:36:17 kontrolde Ready/result0, statusinstalled, Stage/ServerError boş, pending.json=false; dosya kilidi kaldırıldı. Bu çıktı hedeflenen issue aşaması/result1/pending kesintisi değildir; yarım kurulum ve toparlanma kabulü tamamlandı sayılmaz.
- İşlemin normal kontrol mü yoksa tamamlanan yenileme mi olduğu henüz bilinmiyor: deneme sonrası seri ve sunucuda yenileme talebi/issuance kaydı görülmedi. WriteBlocked=True kanıtı ayrıca paylaşılmadı; LockActive=True önceki handle açılışına aittir. Operatör hatası veya ürün hatası varsayılmaz.
- Canlı salt okunur kontrol: panelactive/PID428758 ve RADIUSactive/PID326873 korunuyor; Windows client sourceSHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15 beklenenle aynı. Korunan veritabanı remote kullanıcıya kapalı; izinler değiştirilmedi.
- Sonraki adım yalnız VV06 GUID için salt okunur SQLite issuance/renewal audit sorgusu; mevcut pending/sertifika bilinmeden aynı kesinti veya renew-now tekrar edilmez.

## VV06 yarım kurulum testi başlangıç durumu — 20 Ekim 2026, 18:26 İstanbul

- Operatör çıktısı: Ready/result0, son çalışma17:52:32; mevcut seri5899e122009871b0d5536890bee81e4f0499e605 ve özel anahtar mevcut, bitiş13 Ocak2027 16:26:42. pending.json=false ve retry.json=false. Ethernet Authentication succeeded.
- Hazırlık: istemci kaynak yolunda sunucu issue yanıtından sonra issued.pem yazısı, Windows cert-store kurulumundan ve final receipt'ten öncedir. Mevcut dosyaya salt okunur FileShare.Read handle ile geçici yazma kesintisi planlandı; yazma engelinin gerçekten sharing violation olduğu önce doğrulanacak. Sertifika/anahtar silinmez, signed istemci veya ACL değiştirilmez.
- Yerel iki ilgili unittest geçti: aynı CSR/yeniden denemede idempotent issuance ve yeni kurulum makbuzuna kadar eski sertifikanın korunması. Bunlar saha kesintisi kabulü değildir.
- **Açık:** kilit kurulması, panelden yalnız VV06 için normal yenileme isteği, gerçek yarım kurulum çıktısı ve aynı pending CSR/anahtarla toparlanma. Henüz kilit/yenileme uygulanmadı; bu test tamamlandı sayılmaz. DHCP/DNS yapılandırması kapsam dışı kalır.

## DHCP/DNS yapılandırması kapsam dışı — müşteri kararı, 20 Ekim 2026, 18:07 İstanbul

- **Kapsam dışı / müşteri kararı:** DHCP/DNS'in hangi cihazdan dağıtılacağı, firewall veya AD DNS mimarisi ve istemciye dağıtılan DNS listesi müşterinin sorumluluğundadır. AuthWire çalışması kapsamında bu ayarlar değiştirilmeyecek; bu konu bekleyen iş veya tamamlanmış teknik iş olarak sayılmayacak.
- Önceki18:00 DNS kaynak incelemesi ve DNS düzenleme önerisi bu kararla kapatıldı. DHCPServer keşfi dahil yeni DNS yapılandırma çalışması yapılmayacak. Eski tarihli rapor/checkpoint kayıtları geçmiş gözlemdir; güncel kapsam için bu karar esas alınır.
- Mevcut gözlem: VV06 Ethernet DNS listesi DHCP'den10.35.50.70 ve1.1.1.1 geliyor. Hiçbir DNS/DHCP ayarı değiştirilmedi. Önceki session hatasının kesin nedeninin DNS olduğu kanıtlanmadı.
- AuthWire için yalnız gerekli domain ve AuthWire adlarının çözümlenebilmesi ve gerekli bağlantıların çalışması işlevsel ön koşuldur; bu hizmetin hangi cihazda sağlandığına ilişkin mimari değişiklik istenmez.
- **🔴✓ Korunan tamamlanmış kabul:** gerçek otomatik retry, installed durumuna dönüş, 802.1X ve VLAN110 erişimi. Sonraki AuthWire kabul işleri kesilen/yarım kurulum, expired/yanlış issuer ve diğer ayrı AD/kablosuz senaryolarıdır; kullanıcı EAP-TLS pilotu ayrıca izlenir.

## VV06 gerçek otomatik retry ve toparlanma kabulü tamamlandı — 20 Ekim 2026, 17:56 İstanbul

- **🔴✓ Tamamlandı: gerçek başarısız deneme → deadline görevi → kendiliğinden başarı saha zinciri.** Kontrollü ESXi vNIC kesintisinde ana task17:37:00/session/result1; retry.json attempts1/next_attempt14:52:30.4497593Z; tek seferlik task Türkiye17:52:30'a kuruldu. Operatör17:49'da VV06 TCP8765=True sonucunu teyit etti.
- Operatör17:54:02 kontrolünde retry LastRun17:52:30/result0, ana LastRun17:52:32/Ready/result0 gördü. Görev başarısızlıktan sonra elle yeniden başlatılmadan doğal deadline beklendi. **İki saniye tetikleyici ile ana görev başlangıcı arasındaki farktır; tamamlanma süresi değildir.**
- **🔴✓ Tamamlandı: retry ve eski hata durumu temizliği.** retry.json=false, status.state=installed. Bu gerçek ağ hata/toparlanma kabulüdür; yalnız fixture veya manuel retry değildir.
- **🔴✓ Tamamlandı: toparlanma sonrası mevcut erişim koruması.** Realtek Ethernet Authentication succeeded;10.10.110.4/24Preferred. CA/policy veya Windows saatinde test değişikliği yapılmadı. Hazırlanan nft probe kullanılmadı. Önceki Linux kontrolünde RADIUS PID326873/broker149955 korunuyordu; son Windows çıktısı sunucu PID okuması değildir.
- **Sonraki açık AuthWire işleri:** kalan expired/yanlış issuer, kesilen/yarım kurulum ve diğer AD/kablosuz kabul kapıları. Kullanıcı EAP-TLS pilotu ayrı ve unutulmadan izlenir. DHCP/DNS yapılandırması20 Ekim18:07 müşteri kararıyla kapsam dışıdır.
- B06'nın doğal boot, ağsız boot/kablo dönüşü ve gerçek hata sonrası otomatik retry alt işleri tamamlandı; bütün yaşam döngüsü/expired ve yarım kurulum kapsamı kapanmış sayılmaz. 19 Ekim raporu tarihli snapshot olarak korunur; bu sonuç güncel kayda eklendi.

## VV06 gerçek session hatası sonrası deadline görevi kuruldu — 20 Ekim 2026, 17:42 İstanbul

- Operatör daha kolay olduğu için ESXi'de AuthWire Linux VM vNIC bağlantısını geçici kesme yöntemini seçti. Yeni/yeniden802.1X doğrulamalarının bu arada etkilenebileceği açıklandı; VM kapatılmadan iki dakika sonra bağlantının geri açılması ve VV06 Ethernet'in korunması istendi. Hazırlanan dar nft probe kullanılmadı/çalıştırılmadı; iki yöntem birlikte uygulanmadı.
- **🔴✓ Tamamlandı: gerçek başarısız enrollment ve gerçek retry deadline kurulumu.** VV06 ana task17:37:00 çalıştı ve1 ile bitti. retry.json attempts1/stage=session/next_attempt2026-10-20T14:52:30.4497593+00:00. Türkiye saati17:52:30 ile retry task NextRunTime17:52:30 eşleşiyor (saniye gösteriminde alt saniye farkı).
- Yeni retry task LastTaskResult267011=0x00041303 SCHED_S_TASK_HAS_NOT_RUN; henüz çalışmamış görev durumudur. LastRunTime30.11.1999 gerçek test çalışması değildir. Windows saatiyle oynanmaz veya task elle yeniden başlatılmaz.
- Salt okunur Linux kontrolü14:42:54Z: ens33UP10.35.50.246/24, panel/RADIUS/brokeractive; RADIUS PID326873 ve broker149955 korunuyor. Bu kontrol VV06'dan TCP erişiminin yerine geçmez; istemciden HTTPS yolu da kontrol edilecek.
- **Açık son kabul:**17:52:30 sonrasında retry task kendi kendine ana task'ı başlatmalı; ana task yeniLastRun/Ready0, retry.json yok ve statusinstalled görülmeli. Eski manuel Start başarısı otomatik tekrar kabulü sayılmaz. Kontrol17:54 civarı salt okunur yapılacak; kernel probe için hazır dosya kullanılmayacak.

## VV06 kontrollü retry kesintisi hazırlandı; canlı engel uygulanmadı — 20 Ekim 2026

- VV06 Domain/Private/Public firewall profilleri False; yerel kurallar izinli görünse de kapalı profilde engel etkili varsayılmadı. Birleştirilmiş tabloda MpsSvc adı göründü, Status görünmedi; servis durumu uydurulmadı. Windows firewall açılmadı.
- **🔴✓ Tamamlandı: sınırlı sunucu probe kodu ve gerçek izole kernel testi.** PR41 candidate1afbcb314856, native job118685231691 başarı; dört scope/overlap/deletion guard testi ve foundation kontrolleri de geçti. Private network namespace içinde yalnız10.10.110.4→10.35.50.246TCP8765 reset ile reddedildi; farklı istemci, loopback, TCP22 ve UDP1812 açık kaldı; mevcut farklı chain'in drop'u geçersiz kılınmadı. Kernel set timeout4s testinde cleanup süreci çalıştırmadan erişim döndü, başka tablonun JSON'u korundu ve probe tablosu kaldırıldı. Bu transport fixture gerçek RADIUS oturum kabulü değildir.
- Live probe sabit180 saniye, yalnız IPv4 istemci/hedef/TCPport, paket yolunda timeout uzatması yok. UUID adlı ayrı inet table, mevcut tabloya flush/yazma yok; normal finally yalnız kendi tablosunu kaldırır. Terminal/SIGKILL halinde engel kernel element timeout ile son bulur (boş test tablosu ayrıca temizlenebilir). Kaynak/sertifika/service state yazılmaz; panel/RADIUS/broker PID ve korunan dosyalar ön/son karşılaştırılır.
- PR41 merge0e635a83bf170a0bff2f2fc3d1d8174776ecc9cd. Operatör dosyası /home/segmentiq/authwire-retry-network-probe-20261020.py SHA8152fb58f5a00e87c57995242eb2f9d40838b3e5b09e3eeea3020f582c396614 olarak hazırlandı. **Probe çalıştırılmadı; canlı nft kuralı kurulmadı.** Ürün source update/restart yapılmadı, canlıdev.11 kalır.
- Sonraki operatör akışı: Linux sudo probe READY ardından beklemeden VV06'dan hedefTCP8765'in kapandığı kontrol edilir; True ise task başlatılmaz. False ise hazır ana task bir kez kontrollü başlatılır; retry.json ve tek seferlik task deadline kanıtı alınır. İlk hata sonrası sonraki task elle başlatılmaz;3dk engel kalkışı/paket sayısı/koruma çıktısı ve doğal10–25dk retry Ready/0/retryfalse sonucu beklenir. CA/sertifika/policy ve Windows saati değiştirilmez. NAT nedeniyle eşleşme olmazsa paket sayısı0 olarak teşhis edilir; kapsam genişletilmez.

## VV06 dev.11 ağsız boot ve doğal kablo geri dönüşü kabulü — 20 Ekim 2026, 17:18 İstanbul

- **🔴✓ Tamamlandı: gerçek ağsız açılış sonrası ağ geri gelince kendiliğinden görev/erişim toparlanması.** Operatör Wi-Fi kapalı, Ethernet çıkarılmış reboot ve sonra kablo takma prosedürü ardından çıktı verdi: boot17:08:48; ana task başlangıcı17:11:44; kontrol17:15:30; RanAfterBoot=true, Ready, LastTaskResult0.
- **🔴✓ Tamamlandı: aynı senaryoda kablolu EAP/VLAN koruması.** Realtek Ethernet Authentication succeeded,10.10.110.4/24Preferred. Görev elle başlatılması istenmedi; operatör test prosedürü doğal çalışmayı hedefledi.
- retry.json=false; RetryTaskFound=false. İlk deneme hata vermeden geçtiğinden tek seferlik retry görevi oluşmaması beklenen davranıştır. **Bu sonuç hata sonrası deadline retry'nin çalıştığını kanıtlamaz.** Gerçek başarısız deneme, next_attempt eşleşmesi, kendi kendine sonraki ana görev ve Ready/0/retryfalse kabulü ayrı açık tutulur.
- Sonraki kontrollü hata testi için önce yalnız VV06 Windows firewall etkin profil/yerel kural durumu salt okunur sorgulanacak. Önceki firewall kapalı bilgisiyle kuralın etkili olacağı varsayılmayacak. Amaç yalnız VV06→10.35.50.246 TCP8765'e geçici test kısıtı; CA/sertifika/policy/RADIUS ayarı değişikliği planlanmaz. Uygulama ve geri alma somutlaştırılmadan blok uygulanmaz.

## VV06 dev.11 gerçek açılış kabulü — 20 Ekim 2026, 17:03 İstanbul

- **🔴✓ Tamamlandı: dev.11 yeni launcher gerçek GPO/açılış kabulü.** VV06 boot16:58:33, task başlangıcı16:58:44 (11 saniye fark), RanAfterBoot=true, Ready, LastTaskResult0. UsesNewLauncher=true, InstallerSignature=Valid, InstallerUpdated=true.
- **🔴✓ Tamamlandı: mevcut kimlik ve erişim koruması.** CertificateFound/HasPrivateKey=true; retry.json yok. Realtek Ethernet Authentication succeeded,10.10.110.4/24Preferred.
- **Sonraki ayrı kabul:** Wi-Fi kapalı/Ethernet çıkarılmış reboot, kablo geri gelince doğal task/EAP/VLAN; elle task başlatılmayacak. İlk deneme0 ise ağsız boot toparlanması kabul edilir fakat hata sonrası otomatik retry kanıtlanmış sayılmaz. Hata oluşursa retry.json deadline ve tek seferlik task zamanı ile doğal sonraki Ready/0/retryfalse izlenecek. Expired/diğer olumsuzlar ve kullanıcı EAP-TLS ayrı açık.

## Dev.11 signed SYSVOL güncellemesi canlı kabulü — 19 Ekim 2026, 21:20 İstanbul

- **🔴✓ Tamamlandı: DC01 mevcut publisher ile retry kurucusu güncellendi.** Operatör SYSVOL_INSTALLER_UPDATED verified=true/updated=true bildirdi. Publisher6E74B513F766E01730719684A41B2664380CA68A; bodySHAfaec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609; signedSHA C8B7696224161D144D92E3B0F87F4BBAD70FCAA24DC262EA573EE3850A6BEFD9.
- Özel geri dönüş yedeği C:\ProgramData\AuthWire-Admin-Backup-20261019-211826-e11b109147f1438388e7ce1a0c44aa13. Client/config/trust asset ve paket ACL korundu; tek AllSigned Startup girişi1, GPO settings_changed=false. Bu adım VV06 yerel görevini doğrudan değiştirmedi.
- Dosya açılamadığı için aynı test edilmiş helper, iki gömülü metin yeniden kurularak aynıSHA0a698cd597a70dc1e5b5016acfbbbcef4eb7256fcaba9e73591cf0e56a718484 doğrulaması sonrası doğrudan PowerShell içinden çalıştırıldı; indirme/GitHub girişine ihtiyaç olmadı. Başarılı operatör çıktısı aktarım ve helper yürütmesini doğruladı.
- **Sonraki kabul:** VV06 bilgisayar GPO yenileme ve ağ hazırken yeniden açılış; yerel signed installer/hash, ana task -RunClient action, SYSTEM, doğal LastRun/0 ve mevcut cert/EAP/VLAN korunması. Bundan sonra ayrı gerçek otomatik retry testi. Bu iki VV06 kapısı henüz kapanmadı.

## Dev.11 Linux canlı güncellemesi kabul edildi — 19 Ekim 2026, 21:02 İstanbul

- **🔴✓ Tamamlandı: korumalı dev.11 Linux kaynak dağıtımı ve gerçek yedek/restore kabulü.** Operatör RETRY_UPDATE_FINISHED verified=true paylaştı. Ön/son API okumaları200; dosya/PID/timer/iş verisi koruma kontrolleri true. Artık canlı sürüm0.14.0-dev.11.
- RADIUS PID326873 ve broker149955 korundu; radius_restarted=false. Policy, sertifikalar, native modül ve Windows istemcisi değişmedi. AuthWire-Client.ps1 SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15.
- Ön yedek180040Z-fb65dde9d307 SHA8763116cd17c57a7b24b0bb3a7c09fc632eebbeafb8b6a961515468b95ce607b; son yedek180142Z-c33f59ef8175 SHAa0dc0f592250d6616bb12d8ed456c3e89de88aee6299ab67f883f15046844f28. Son gerçek arşivden151 dosya izole veri restore, byte/owner/mode, DB/CA/signer/secret/sertifika ve erişim kayıt DB kontrolleri geçti. Full appliance boot restore değildir.
- Kalıcı ön kontrol/sonuç dizini /var/backups/authwire/scheduled/retry-update-dev11-20261019T175941Z-76e52fc1. Main mergee2b835def667 için tüm altı iş akışı da artık success; candidate ve merge source130 dosya/manifest eşleşmesi korunuyor.
- **Sonraki adım:** DC01 mevcut publisher ile aynı paket içindeki kurucuyu yeniden imzalama/değiştirme. Test edilmiş helper2026-10-19-retry-installer-update.ps1 SHA0a698cd597a70dc1e5b5016acfbbbcef4eb7256fcaba9e73591cf0e56a718484; Linux /home/segmentiq altında hazır. GPO scope/tek AllSigned Startup, client/config/trust/ACL korunacak. Bu Windows/DC adımı henüz uygulanmadı.
- **Açık:** signed_sysvol_update_pending=true ve vv06_automatic_retry_acceptance_pending=true. Linux güncellemesi gerçek Windows otomatik retry kabulü sayılmadı. 19 Ekim raporu tarihli snapshot; güncel devam kaydı bu bölüm.

## Retry native Windows kontrolleri geçti ve dağıtım hazırlandı — 19 Ekim 2026

- **🔴✓ Tamamlandı: aday8585f3a8de5b için altı CI iş akışının tamamı başarılı.** Native Windows job118151986906 gerçek signed SYSTEM/time-trigger ile erken rearm, yalnız SYSTEM/Admin task ACL, iki otomatik retry sonrası recovery ve kimlik koruması, Running ana görevin çoğaltılmamasını doğruladı. Fixture müşteri ağı/AD kesintisi değildir.
- **🔴✓ Tamamlandı: imzalı GPO güncelleme/geri alma ve mevcut CNG/boot regresyonları.** Job118151986358 same publisher, asset/ACL koruması, tamper/publisher retleri ve rollback; job118151986984 gerçek Windows CNG ilk kayıt/yenileme ve startup fixture başarılı. Diğer LDAP/Kerberos, EAP, browser, restore ve kaynak kontrolleri de başarılı.
- PR40 hazır duruma alınıp e2b835def66769b61ec0b02c804b7dabafb1edc0 olarak birleşti. Tam130 kaynak Git blob'u merge tree ile eşleşti; manifest35d8f4956827b8f2a3e356cbbbf1f3ecfeb555d28c88adcfd91f7afd92becfcf.
- **🔴✓ Tamamlandı: pinlenmiş korumalı Linux checkpoint hazırlığı.** /home/segmentiq/authwire-retry-update-dev11-20261019.py SHA0d14759ceff077cd165faba4b70a281f186898b77f98af769d5dbd05c851ae12. Kabul edilmiş125 dosyalı dev10 tabanı ve130 dosyalı aday için guard geçti;10 guard testi başarılı. Root çalışması öncesi stage/manifest ve canlı korunma tekrar denetlenir, ön/son yedek ve izole veri restore alınır; RADIUS restart planlanmaz.
- **Canlı kurulum hâlâdev.10:** salt okunur kontrolde RADIUS PID326873, broker149955; panel ve iki timer active/enabled. AuthWire-Client.ps1 SHA86081 değişmedi. /opt/kaname-lab/venv/bin/python cryptography46.0.0 doğrulandı.
- **Açık:** Linux root güncellemesi operatör parolasını gerektiriyor; signed DC01 SYSVOL güncellemesi ve VV06 gerçek doğal otomatik retry kabulü sonraki adımlar. Manuel recovery veya izole Windows fixture gerçek müşteri otomatik kabulü sayılmadı. 19 Ekim raporundaki %55 liste sayımı bu geliştirme/test alt kazanımıyla değiştirilmedi.

## Güncel durum raporu ve tamamlanma sayımı — 19 Ekim 2026

- **🔴✓ Tamamlandı: 9 Ekim temel raporu ve 15 Ekim ara raporunun 19 Ekim güncellemesi.** B01–B12, G01–G07, P01–P10 kimlikleri korundu; tamamlanan dar alt işler kırmızı tikle, kısmi/açık işler ayrı gösterildi.
- Sabit ilk rapor listesi üzerinden muhafazakâr sayım: B paketleri42/59 (%71); G paketleri10/35 (%29); toplam52/94 (%55). Tamam1, kısmi/açık0; eşit alt iş sayımıdır, emek/süre veya üretime hazır olma yüzdesi değildir. B tamamları4,3,3,4,5,3,4,5,3,3,2,3. G tamamları2,2,1,1,2,1,1. İlk raporda temel26/59 idi. Yeni servis/yedek kazanımları ilgili kapsamın kanıtıdır, ayrıca puan eklenmedi.
- B05 ilk dar pilot listesi5/5; güncel signed SYSVOL, tek AllSigned Startup ve VV06 dev.10 doğal boot kabulü tamam. Genel domain yayılımı/G01 ayrı açık.
- B12 gerçek yedekten izole veri restore alt işi tamam; tam appliance boot restore/rollback ve off-host hedef hâlâ açık. Bu nedenle3/6.
- B06 eski/yeni seri seçimi ve yerel/server retirement kanıtları tamam; birleşik yaşam döngüsü satırındaki expired kurtarma açık. Canlı otomatik retry eksikliği kapanmadı.
- **Devam noktası:** canlıdev.10; PR40dev.11 aday8585f3a8de5b, Windows CI son kontroldequeued. Merge/dağıtım/SYSVOL etkinleştirme ve VV06 gerçek otomatik toparlanma açık. ManuelReady/0/retryfalse, otomatik kabul değildir. Kullanıcı EAP-TLS pilotu, DNS düzenlemesi, eşzamanlı SQLite kilidi, accounting, tam kurtarma ve yedi geliştirme paketi raporda açık korundu.
- Rapor hazırlanırken ürün/AD/NAS/PKI/802.1X ayarı veya servis değiştirilmedi. Sonraki çalışma kullanıcı devamından sonra CI/kalan retry kabulünden sürer.

## Retry düzeltmesi hazır; native Windows CI kuyruğu bekleniyor — 19 Ekim 2026

- **🔴✓ Tamamlandı: aday dev.11 imzalı installer/launcher geliştirmesi ve yerel regresyonlar.**
  PR40 draft; son aday8585f3a8de5b03e08afd7abf6ae85386d08f2ebc.
  Yerel tam suite534 test/25 ortam atlaması,87.025s geçti.
  Ek enrollment + historical/current source guard turu25 test geçti.
  AuthWire-Client.ps1 SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15
  değişmedi. Aday installer SHAfaec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609.
- **🔴✓ Tamamlandı: kaynak kapsamı ve yerel tam paket koruma kontrolü.**
  Kabul edilmiş dev.10 snapshot'ının125 dosyalı baseline'ı ve adayın tam
  tekrar uygulanması source_check ile doğrulandı. Aday130 dosya,
  manifest35d8f4956827b8f2a3e356cbbbf1f3ecfeb555d28c88adcfd91f7afd92becfcf.
  Tam130 Git blob'u aday tree ile birebir eşleşti. kaname/ içinde yalnız
  installer ve iki sürüm metaverisi değişti; RADIUS/AD/PKI/policy kaynakları aynı.
  Bu, canlı sunucuda yeni bir deploy veya preservation çalıştırması değildir.
- **Hazır, ancak canlıya uygulanmadı:** korumalı Linux/source ve DC01 aynı-publisher
  installer update checkpoint'leri PR40'ta. Linux release/manifest pinlemesi
  henüz tamamlanmadı; RELEASE_NOT_PINNED guard değişiklikten önce reddeder.
  DC01 updater ayrıca gerçek Authenticode/ACL/asset/rollback fixture'ına eklendi.
  Yeni retry görevi periyodik polling yapmaz; deadline'da ana görevi başlatır.
- **Engel / açık doğrulama:** GitHub işleri queued, runner atanmış değil.
  Native Windows görev/Authenticode/otomatik retry fixture'ı, mevcut Windows
  CNG/startup, native Kerberos/LDAP/EAP ve browser/restore CI henüz bu aday için
  sonuç üretmedi. Son run'lar39279891613(device),39279891501(GPO/restore),
  39279891326(core),39279891396(Linux),39279891566(EAP),39279891474(browser).
  Queue nedeni bilinmiyor; geçirilmiş test veya genel platform outage iddiası yok.
  Native testler geçmeden PR birleştirilmez veya canlıya uygulanmaz.
- Canlı hâlâ0.14.0-dev.10. Windows/SYSVOL/RADIUS/policy/CA/sertifikalar bu
  hazırlıkla değiştirilmedi. Gerçek otomatik recovery, signed SYSVOL/reapply,
  kaynak/paket pinleme, korumalı yedek/restore ve DNS DHCP düzenlemesi açık.
  Kullanıcının18:17:11 manuel0/retry yok kabulü korunur.
  Ayrıntılar PR40 docs/checkpoints/2026-10-19-enrollment-retry.md ve
  docs/checkpoints/2026-10-19-retry-validation.json içinde saklandı.

## VV06 kontrollü manuel recovery başarılı; retry düzeltmesi hazırlanıyor — 19 Ekim 2026, 18:21 İstanbul

- **🔴✓ Tamamlandı: hazır ağda kontrollü manuel enrollment yeniden denemesi.**
  Operatör LastRun18:17:11, TaskStateReady, LastTaskResult0,
  RetryFileExists=false çıktısını paylaştı. Bu,17:40:59 session hatası sonrası
  hazır ortamda istemcinin yeniden başarıyla çalışabildiğini doğrular.
  Tamamlanma süresi veya ilk hatanın kesin SSPI/HTTPS alt nedeni çıkarılmadı.
  Bu manuel başarı otomatik recovery kabulü yerine geçmez.
- Doğrulanmış düzeltme kapsamı: imzalı installer'ın özel dizine kopyası asıl
  görevi mevcut imzalı istemciye aktarır; istemci hatasında retry.json UTC
  deadline'ına gerçek tek seferlik SYSTEM görevi kaydeder. Retry görevi asıl
  görevi başlatır; böylece ana task'ın LastRun/LastResult bilgisi güncellenir.
  Erken çağrı deadline'a yeniden kurulur; Running/Queued ana görev başlatılmaz;
  launcher mutex ve istemcinin mevcut mutex'i korunur. Periyodik polling yoktur.
- Başarılı receipt kontrolü sonrasında retry yoksa ve mevcut geçerli özel
  anahtarlı sertifika mevcutsa eski retry_pending durumu güncellenir.
  last_verified kontrol zamanıdır; yeni sertifika verilme tarihi uydurulmaz.
  Orijinal AuthWire-Client.ps1 body SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15
  ve SSPI/TLS/PKI/protokol kodu değişmedi.
- Aday0.14.0-dev.11, PR40 https://github.com/Asitavandas/kaname/pull/40.
  Yerel20 enrollment/historical preservation testi geçti. Gerçek imzalı
  SYSTEM/tek seferlik zaman trigger'ı, rearm, çift süreç engeli ve durum
  toparlama Windows fixture'ı CI'ya gönderildi; sonucu henüz alınmadı.
  **Canlı sürüm hâlâdev.10**; Linux kaynak, SYSVOL, VV06 görev veya sertifikası,
  CA/policy/RADIUS değiştirilmedi. Canlıya geçiş ve otomatik recovery açık.
  DNS listesindeki1.1.1.1 düzenlemesi uygulanmış sayılmadı.

## Canlı retry tetikleyici boşluğu doğrulandı — 19 Ekim 2026, 18:12 İstanbul

- **🔴✓ Tamamlandı: güncel DC discovery/Kerberos TCP erişimi tanısı.**
  nltest /dsgetdc:vizyonveri.local /force başarılı; DCdc01.vizyonveri.local,
  IP10.35.50.70, KDC/LDAP/DNS_DOMAIN/DNS_FOREST gibi flag'ler var.
  TCP10.35.50.70:88 true. Ayrı SRV sorgu çıktısı paylaşılmadı; SRV kaydı
  sonucu bu çıktıdan bağımsız başarılı diye kaydedilmedi.
  Bu,17:41:02 hata anındaki SYSTEM SSPI başarısını kanıtlamaz.
- **Doğrulanmış açık ürün hatası: otomatik retry tetikleyicisi yok.**
  LastRun17:40:59/LastResult1 korunuyor; NextRunTime21:00:00,
  RestartCount0/RestartIntervalboş. retry.json.next_attempt17:54:02 geçmiş;
  görevi o saatte başlatmamış. Bu hem kaynak hem canlı task ayarlarıyla
  doğrulandı; ağ geri dönüşü enrollment kabulü açık kalır.
- Sıradaki tanı: mevcut ağı/DNS ayarını değiştirmeden, next_attempt geçtikten
  sonra tek kontrollü manuel ana görev çalıştırması. Amaç session hatasının
  hazır ortamda sürüp sürmediğini ayırmaktır; manuel başarı otomatik recovery
  yerine geçmez. retry.json silinmeyecek/clock değiştirilmeyecek.
  Başarı değerlendirmesinde LastRun güncelliği, LastResult0 ve retry.json'ın
  kalkması birlikte incelenecek. Eski status.json state'i tek başına yeterli
  değildir: mevcut istemci renewal_check başarı yolunda retry'ı kaldırıp
  dönüyor, eski hata status'unu yenilemiyor. Bu gözlenebilirlik açığı da
  retry düzeltmesinde ele alınacak.
- **Planlanan dar düzeltme, henüz yazılmış/dağıtılmış değil:** retry deadline
  için gerçek, sınırlı ve kalıcı Task Scheduler tetiklemesi; mevcut imzalı
  SYSTEM istemci/private state ve IgnoreNew/mutex korumasıyla tekil çalışma;
  geçerli receipt başarısında güncel durum kaydı; yalnız kontrollü yerel
  hata kategorisi/HRESULT ile credential/ticket içermeyen tanı.
  Ayrı retry task, yeniden kayıt esnasında çalışan instance ve ağsız missed
  one-time trigger davranışları izole Windows testleriyle doğrulanmadan
  canlıya taşınmayacak. Signed SYSVOL update gerçek publisher ile yapılacak.
  Task'a yalnız RestartOnFailure eklemek erken return0 nedeniyle yeterli
  çözüm olarak kabul edilmedi.
- Kanıt docs/checkpoints/2026-10-19-vv06-live-retry-gap.json.
  DNS1.1.1.1 düzeltme önerisi hâlâ açık; uygulanmış varsayılmadı.
  CA/policy/sertifika/RADIUS/802.1X veya Windows görev ayarı değiştirilmedi.

## VV06 session hatası ve retry zamanlaması bulgusu — 19 Ekim 2026, 17:59 İstanbul

- Operatör status.json: retry_pending, ENROLLMENT_OR_INSTALL_FAILED,
  stage=session, server_error boş; checked_at2026-10-19T14:41:02.2419780Z
  (İstanbul17:41:02). Bu, kablo sonrası17:40:59 çalışmasıyla zaman olarak uyumlu.
  retry.json attempts1, stage=session,
  next_attempt2026-10-19T14:54:02.2032214Z (İstanbul17:54:02).
- **🔴✓ Tamamlandı: hata aşaması ve güncel ağ erişimi ayrıştırması.**
  Son kontrol TCP8765 true, Remote10.35.50.246, Source10.10.110.4;
  Ethernet DNS listesi10.35.50.70 ve1.1.1.1.
  Şimdiki TCP başarısı, hata anında HTTPS/Kerberos/DC yolunun sağlıklı
  olduğunu kanıtlamaz. server_error boşluğu da isteğin sunucuya hiç
  ulaşmadığını tek başına kanıtlamaz.
- session aşaması Kerberos SSPI credential/token üretimi, HTTPS session
  çağrısı ve karşılıklı doğrulamayı kapsar. Hangi alt adımın hata verdiği
  henüz bilinmiyor; public DNS kullanımı tek kesin kök neden diye atanmadı.
  Domain istemcisinde yalnız AD namespace'ini çözen iç DNS sunucularının
  kullanılması gerekir; pilotta yalnız10.35.50.70 ile tanı ve DC SRV/discovery
  kontrolü sıradadır. Kalıcı DHCP DNS düzenlemesi ayrıca takip edilir.
  DNS override henüz uygulanmış sayılmaz.
- **Doğrulanmış ürün sınırı:** next_attempt yalnız istemci başındaki erken
  çalışma gate'idir. retry.json yazımı bir Windows task trigger'ı oluşturmaz.
  Mevcut installer boot/09:00/21:00 trigger'ları ve IgnoreNew kullanır;
  RestartOnFailure/ayrı retry timer tanımlamaz. 17:54 retry kaydı otomatik
  17:54 task çalışması vaadi değildir. Canlı RestartCount/RestartInterval ve
  NextRunTime salt okunur alınacak; retry tetikleme düzeltmesi henüz yoktur.
  Yalnız RestartOnFailure eklemek de yeterli sayılmaz: retry tarihi gelmeden
  mevcut istemci return0 verir; bu durumda scheduler hata zinciri kesilebilir.
- Kanıt docs/checkpoints/2026-10-19-vv06-session-retry-evidence.json.
  Önceki çevrimiçi reboot ve EAP/VLAN geri dönüşü kabulü korunur;
  enrollment ağ geri dönüşü kapısı açık. CA/policy/cert/802.1X ayarı değişmedi.

## VV06 ağsız açılış: EAP geri döndü, enrollment hata verdi — 19 Ekim 2026, 17:48 İstanbul

- **🔴✓ Tamamlandı: ağsız açılış sonrasında Ethernet 802.1X ve VLAN110 geri dönüşü.**
  Boot17:27:45. Kablo öncesi17:39:04: Ethernet/Wi-Fi Disconnected;
  taskReady, LastRun17:15:50 (önceki boot), LastResult0.
  Bu0 yeni ağsız boot'un başarılı enrollment sonucu diye yorumlanmadı.
- Kablo sonrası17:41:34: EthernetUp/Wi-FiDisconnected; LastRun17:40:59,
  taskReady, **LastTaskResult1**. Elle Start istenmedi; ağ geldikten sonra
  görev çalışması gözlendi, tam tetikleyici/installer yolu ayrıca ayrıştırılmadı.
  Windows Ethernet Authentication succeeded;
  GUID415933d5-5010-4a7a-b8bf-0e537e0bc7f2/MAC38:CA:84:DB:FF:E6;
  IPv4 10.10.110.4/24 Preferred.
- **Açık hata:** enrollment ağ geri dönüşü kabulü başarısız.
  Sertifikanın iptal/geçersiz olduğu veya RADIUS policy hatası olduğu bu
  sonuçtan çıkarılmadı. status.json/retry.json içindeki aşama, kontrollü hata
  kodu ve UTC zamanları; güncel DNS sunucuları ve HTTPS TCP erişimi
  salt okunur isteniyor. Henüz kök neden veya düzeltme kanıtı yok.
- Kaynak incelemesi: istemci session açma sonrası receipt/renewal kontrolü
  yapar; catch içinde retry_pending + stage + next_attempt yazar, exit1 verir.
  next_attempt erken yeniden çalışmayı engelleyen kayıttır; dosya yazımı
  tek başına yeni Task Scheduler tetikleyicisi kurmaz. Görünen kurucu
  boot/09:00/21:00 tetikleyicileri kullanır. Bu retry zamanlaması sınırı
  incelenecek; kullanıcının hata aşaması alınmadan nedeni diye atanmadı.
- Kanıt docs/checkpoints/2026-10-19-vv06-offline-reconnect-result.json.
  Bu tanı sırasında görev elle başlatılmadı veya ayarı değiştirilmedi;
  CA/policy/sertifika/clock/802.1X ayarlarına müdahale edilmedi.
  Çevrimiçi dev.10 boot kabulü geçerli kalır; B04/B06 ağ geri dönüşü hâlâ açık.

## VV06 ağsız açılış testi başlangıç kaydı — 19 Ekim 2026, 17:26 İstanbul

- **🔴✓ Tamamlandı: çevrimiçi DNS/TCP baseline.**
  Operatör Resolve-DnsName çıktısı kaname.vizyonveri.local ->10.35.50.246;
  ayrı Format-List TCP8765 kontrolü için true bildirdi.
  Hemen önce VV06 Ethernet10.10.110.4/24 Preferred ve başarılı EAP/boot kabulü vardı.
  TCP kontrolünün SourceAddress alanı ayrıca paylaşılmadı.
- **Devam ediyor:** geçerli mevcut sertifikayla tüm fiziksel ağlar kesikken
  gerçek restart; kablo takılmadan LastBoot/TaskState/LastRun/LastResult ve
  fiziksel NIC durumunun salt okunur kaydı; ardından kabloyu takıp doğal
  enrollment ve 802.1X/VLAN/DNS/TCP geri dönüşünün gözlenmesi.
  Elle görev başlatılmayacak; CA/policy/cert/clock/task ayarı değiştirilmeyecek.
- Henüz ağsız açılış veya ağ geri dönüşü kabul çıktısı yoktur.
  Bu senaryo ağ koşulunu test eder; sertifika expired/offline renewal testi
  yerine geçmez. B04/B06 ilgili kapıları sonuç gelmeden kapatılmadı.

## VV06 dev.10 gerçek açılış kabulü — 19 Ekim 2026, 17:21 İstanbul

- **🔴✓ Tamamlandı: DC01 imzalı kurucu güncellemesi sonrasında VV06 gerçek
  restart ile doğal enrollment görevi açılış kabulü.**
  LastBootUpTime19.10.2026 17:15:28, LastRunTime17:15:50;
  RanAfterBoot=true, TaskState=Ready, LastTaskResult0.
  Görev açılıştan22 saniye sonra başlamıştır; tamamlanmanın22 saniyede
  olduğu iddia edilmez. Kontrol çıktısı sırasında başarıyla tamamlanmıştır.
- **🔴✓ Tamamlandı: bu açılışta istemci imzası ve mevcut kimlik malzemesi koruması.**
  ClientSignatureValid; pinli mevcut thumbprint
  4CFD8321AE08D6074B99AF5C194151AD5F99F454 için
  CertificateFound=true/HasPrivateKey=true; RetryFileExists=false.
  Bu kontrol private key byte'larını export etmez.
- **🔴✓ Tamamlandı: aynı reboot sonrası kablolu 802.1X ve VLAN110 adres kabulü.**
  Ethernet Authentication succeeded,
  GUID415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC38:CA:84:DB:FF:E6;
  IPv4 10.10.110.4/24, AddressStatePreferred.
  Yalnız bu çıktı ağ geçidi/uygulama erişimi veya tam DHCP trafiğini yeniden
  test etmez; VLAN110 adresi ve başarılı EAP gözlemi kaydedilir.
- Kanıt docs/checkpoints/2026-10-19-vv06-dev10-boot-acceptance.json.
  Gerçek boot sonucu kabul edilmiştir; bu çıktı StartForBoot fallback
  dalının mı yoksa yerleşik AtStartup tetikleyicisinin mi çalıştığını tek
  başına ayırmaz. Eksik boot-run kurtarma dalı ayrı SYSTEM fixture'ında testlidir.
- Önceki aşağıdaki VV06 boot acceptance pending kayıtları tarihsel aşamadır.
  B05 bu pilot açılış alt adımı tamamlandı; daha geniş yayılım açıktır.
  B06 ağ yokken/expired yolları, B04 yük altında SQLite bulgusu ve diğer
  yol haritası kapıları topluca tamamlandı sayılmaz.
  Sıradaki saha kapsamı: geçerli mevcut sertifikayla ağsız açılış ve ağ geri
  geldiğinde enrollment/802.1X toparlanması; önce çevrimiçi DNS/TCP baseline alınır.

## DC01 imzalı SYSVOL kurucusu canlı kabulü — 19 Ekim 2026, 17:14 İstanbul

- **🔴✓ Tamamlandı: DC01 pilot SYSVOL kurucusunun mevcut yayıncıyla güncellenmesi.**
  Operatör SYSVOL_INSTALLER_UPDATED, verified=true, updated=true çıktısını paylaştı.
  Publisher6E74B513F766E01730719684A41B2664380CA68A;
  installer body SHA2564c1b14a1c088b0ac28f63337ff681824da560d6bf9143bf79132720850f2067d.
  Yeni tam imzalı dosya SHA256:
  35cf0487ffe84cbbc763cd10d0427e33ebae76c5e7b87447482dc16738fa8238.
- Yedek C:\ProgramData\AuthWire-Admin-Backup-20261019-171142-08ad3aebefaf4a478fefcd96a0f81875.
  client_and_assets_preserved=true, package_permissions_preserved=true,
  startup_entries=1, all_signed=true. GPO ayarları ve Windows görevi bu
  DC01 güncellemesiyle değiştirilmedi (iki changed alanı false).
  Kanıt docs/checkpoints/2026-10-19-dc01-sysvol-acceptance.json içinde saklandı.
- İndirme/GitHub erişim güçlüğü sonrası Raw clipboard metni LF/BOM normalize
  edilip sabit helper SHA4eba2563... ile doğrulandı; helper mevcut publisher
  ile imzalanarak çalıştırıldı. Hash veya Authenticode kontrolü bypass edilmedi.
  Alternatif dosya aktarımı için açılmış kendi geçici Linux aktarım süreci
  kapatıldı; ürün servisleri değiştirilmedi.
- **Açık:** VV06 üzerinde güncel GPO ile gerçek restart sonrası doğal task
  çalışması. vv06_boot_acceptance_pending=true; RanAfterBoot, Ready/LastResult0,
  geçerli istemci imzası, mevcut sertifika/private key ve 802.1X/VLAN erişimi
  birlikte doğrulanmadan B05 boot alt kabulü kapatılmayacak.
  Önceki aşağıdaki DC01/SYSVOL bekliyor kayıtları tarihsel aşamadır.

## DC01 imzalı SYSVOL kurucu güncellemesi hazır — 19 Ekim 2026

- **🔴✓ Tamamlandı: dar kapsamlı protected updater ve izole Windows kabulü.**
  PR39 https://github.com/Asitavandas/kaname/pull/39 birleştirildi;
  merge0413143263c9fc4c34d81dff91c9e50226afcafb.
  Aday03eea0623f1923e49b7a547f7906e18692d4b80d için529 test/25 ortam
  atlaması ve restore fixture'ları geçti. Windows işi118088248063,
  gerçek Authenticode ile aynı publisher/old-new body pinlerini, imzalı
  asset/istemci/ACL korumasını, idempotence'ı, bozuk asset ve yanlış publisher
  reddini, post-replace hata sonrası eski dosya/izin geri almayı doğruladı.
- Checkpoint docs/checkpoints/2026-10-19-sysvol-installer-update.ps1,
  SHA2564eba25638ad6f8a6d697c91005266524df1b4c124d690059c4feb1b4dd384bb6.
  Kılavuz aynı adlı.md dosyasıdır. İçerdiği yeni installer template SHA4c1b14a1...
  ve audit kaynakları mevcut main ile eşleşir; updater installer'ı yürütmez.
  DC01/domain/pilot GUID/tek apply grubu/mevcut publisher pinlidir.
  Eski imzalı kurucu ve hash/SDDL manifest'i private ProgramData yedeğine alınır;
  yalnız kurucu mevcut publisher private key'i export edilmeden yeniden imzalanır.
  Atomik byte değişimi ardından eski security descriptor uygulanıp doğrulanır;
  istemci/config/CA asset/INI byte ve ACL değişikliği reddedilir.
  Windows PowerShell5.1 gerçek null-string ve izin davranışı fixture ile doğrulandı.
- **Açık:** dosyanın operatör tarafından DC01'de mevcut yayıncıyla imzalanıp
  çalıştırılması, başarılı SYSVOL_INSTALLER_UPDATED çıktısı, ardından gerçek
  VV06 gpupdate/reboot kabulü. Bu henüz canlı GPO/task değişikliği kanıtı değildir.
  AllSigned korunur; bypass/trust-store değişikliği veya signing key export yoktur.
  Sunucu RADIUS/CA/policy/sertifikalarına bu hazırlık adımıyla müdahale edilmedi.

## Dev.10 canlı kaynak kabulü ve doğal gece yedeği — 19 Ekim 2026

- **🔴✓ Tamamlandı: canlı Linux kaynak güncellemesi0.14.0-dev.10.**
  Operatör STARTUP_UPDATE_FINISHED verified=true çıktısını paylaştı.
  RADIUS326873 ve broker149955 süreçleri korundu; RADIUS restart yapılmadı.
  Kritik dosyalar, timer'lar, iş durumu, policy, CA/sertifikalar ve native modül
  korundu. Windows istemcisine veya SYSVOL'a bu Linux adımıyla yazılmadı.
- **🔴✓ Tamamlandı: ilk doğal takvim yedeğinin arşiv/digest kanıtı.**
  Timer19.10.2026 03:17:01 İstanbul'da doğal tetiklendi; servis Result=success,
  ExecMainStatus0, bitiş03:18:19. Arşiv:
  /var/backups/authwire/scheduled/authwire-scheduled-20261019T001819Z-2bc7629f0d67.tar.gz
  SHA25602bd20dc78a9d7884c2bb23a1400a3d202186a8a9f07c379fc0f34271019c91a.
  PREVIOUS_BACKUP_EVIDENCE digest_verified=true; created_utc00:18:19.240355.
  Bu doğal arşive ayrıca restore uygulanmış sayılmaz.
- **🔴✓ Tamamlandı: dev.10 güncellemesinin öncesi/sonrası yedek, koruma ve izole veri restore kabulü.**
  Kanıt dizini /var/backups/authwire/scheduled/startup-update-dev10-20261019T131838Z-4448a4a4.
  Ön yedek authwire-scheduled-20261019T131938Z-96f29a5081a6.tar.gz,
  SHA256c1ff1adff6f4c65040a4e6dbfccf982e775167e04b8d5083b88086c3efa3b271.
  Son yedek authwire-scheduled-20261019T132039Z-a55dda3d72ab.tar.gz,
  SHA2560c3bb4aca61ee45206d213144074d96faa4db73d6cf302a176c68a355cc70793.
  Arşiv/SQLite bütünlüğü doğrulandı;146 dosya izole restore edildi,
  byte/owner/mode ve PKI/secret/registry/history DB kontrolleri geçti.
  Restore kopyasında kod/servis çalıştırılmadı veya ağ çağrısı yapılmadı;
  tam appliance boot restore ayrı açık kapıdır.
- Son8 API yolu üçer kez200 döndü; en yüksek36.4ms.
  İstemci body SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15
  değişmedi; yeni installer template4c1b14a1... Linux kaynakta etkin.
- **Açık:** DC01 mevcut yayıncıyla yalnız SYSVOL installer'ın yeniden imzalı
  güncellemesi ve VV06 gerçek reboot sonrası RanAfterBoot/LastResult/802.1X kabulü.
  signed_sysvol_update_pending=true, vv06_boot_acceptance_pending=true.
  Önceki aşağıdaki “canlıdev.9 / sudo bekliyor” kayıtları tarihsel aşamadır.

## VV06 açılış enrollment düzeltmesi hazırlandı — 19 Ekim 2026

- Operatörün15:56:16 salt okunur çıktısı: task Ready/SYSTEM,
  LastBoot15:51:34, LastRun09:00:01, RanAfterBoot=false, LastResult0.
  Üç trigger enabled; RunOnlyIfNetworkAvailable/StartWhenAvailable ve iki pil
  kısıtı true. Ethernet DomainAuthenticated/Internet. TaskScheduler event140,
  15:52:01, VIZYONVERI\\VV06$ mevcut görevi güncellemiş.
  Bu gözlem kuyrukta bekleyen göreve indirgenmedi; yeni boot çalışması yoktur.
- Kaynakta mevcut task varlığını açılışta çalıştığının kanıtı sayan
  if(!$existingTask) koşulu saptandı. **🔴✓ Tamamlandı: bu koşulun kaldırılması
  ve dar kapsamlı boot-run kurtarma geliştirmesi.**
  Register sonrasında gerçek LastBootUpTime/LastRunTime/State okunur;
  Running/Queued veya bu boot'ta zaten çalışmış task yeniden istenmez.
  Eksik boot çalışmasına tek Start isteği verilir; IgnoreNew korunur.
  GPO reapply bilinen varsayılan pil kısıtını geri getirmesin diye iki pil
  izni açıkça eklenir. Ağ koşulu,09:00/21:00/AtStartup kapsamı ve gerçek
  enrollment/receipt/renewal kodu değiştirilmedi.
- **🔴✓ Tamamlandı: son teknik testler ve PR38 birleştirmesi.**
  https://github.com/Asitavandas/kaname/pull/38,
  aday7a1bef08976ffa012d3a74a7dc6cdbae20666a45,
  merge0202ded59188fd82bce8e887a7669e2aed53244c.
  524 test/25 ortam atlaması; Windows CNG ilk kayıt/yenileme; gerçek SYSTEM
  Task Scheduler iki action ile ilk başlangıç, Running/current-boot duplicate
  engelleme ve yeniden Register edilmiş görevin kurtarılması geçti.
  Boot sınırı fixture'da simüledir; gerçek CI reboot iddiası yok.
  Queued guard mock ile testlidir. GPO imza/varlık/ACL, browser/session,
  native LDAP/Kerberos, EAP-TLS normal/debug ve production parse testleri geçti.
  Ek5 sudo kaynak/preservation guard testi yerelde geçti; ana CI'ya eklendi.
- İstemci body SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15
  değişmedi. Yeni Install-AuthWire.ps1 template SHA:
  4c1b14a1c088b0ac28f63337ff681824da560d6bf9143bf79132720850f2067d.
  Audit aracı yeni template hash'ini bekler. Yeni kurucu mevcut enterprise
  yayıncıyla yeniden imzalanmadan SYSVOL'a konmayacak; AllSigned korunur.
- Aday sürüm0.14.0-dev.10; canlı hâlâdev.9, RADIUS326873/broker149955.
  Paket125 dosya; manifest
  c027714db78fdabedb400f019723dbce6958e4db49f9d98d5226b892de301423
  tüm Git blob'larıyla ve live dev.9'un124 dosyalı baseline guard'ıyla doğrulandı.
  Stage /home/kaname-runner/kaname-stage-0202ded59188.
- Sudo checkpoint docs/checkpoints/2026-10-19-startup-update.py:
  SHA4ada81793864d9b29dda7f2dd95a1d501b2c1009da136422b8e6a8fc5aa004fb.
  Kaynak değişimi için tek istisna imzalanacak installer template ve sürüm
  metaverisidir; authorizer/PKI/CA/policy/Windows client body değişikliği reddedilir.
  RADIUS restart yok; her PID/timer/iş durumu ve kritik dosya korunacak.
  Önce/sonra managed yedek ve izole veri/history restore doğrulanacak.
  Önceki last-success yedek digest/timer kanıtı overwrite öncesi ayrıca kaydedilecek.
- **🔴✓ Tamamlandı: sunucuda paket hazırlama ve son guard CI.**
  Self-hosted142 test/4 ortam atlaması geçti;125 dosyalı manifest yukarıdaki
  c027714d... değeriyle birebir eşleşti. Ek5 guard dahil529 test/25 ortam
  atlaması CI'da geçti. Sudo launcher segmentiq üzerinde syntax/hash doğrulandı,
  yürütülmedi; canlı kaynak hâlâdev.9 ve GPO reboot kabulü açıktır.
- **Açık:** canlı sudo kaynak güncellemesi, DC01 mevcut yayıncıyla imzalı
  pilot SYSVOL kurucu güncellemesi ve gerçek VV06 yeniden açılış kabulü.
  B05 bütünü ve offline/expired/network-recovery/capacity açıkları kapatılmadı.
  Bu aşamada canlı kaynak, task, CA, policy veya sertifika değiştirilmedi.

## VV06 GPO yeniden uygulama: açılış görevi kabulü açık — 19 Ekim 2026, 15:55 İstanbul

- **🔴✓ Tamamlandı: VV06 bilgisayar RSOP'unda güncel GPO'nun uygulanmış görünmesi ve bağlantının korunması.**
  LastBootUpTime19.10.2026 15:51:34; gpresult oluşturulma15:53:11,
  son bilgisayar GPO uygulaması15:51:53, kaynakdc01.vizyonveri.local.
  Applied GPO: Default Domain Policy ve AuthWire-Pilot-Trust;
  VV06$, AuthWire-Pilot-Computers ve Domain Computers üyelikleri görünüyor.
  Bu, Startup installer'ın bütün eylemlerinin bu boot'ta yürüdüğünü tek başına kanıtlamaz.
- İstemci imzasıValid; seri5899e122009871b0d5536890bee81e4f0499e605 ve
  thumbprint4CFD8321AE08D6074B99AF5C194151AD5F99F454 korunmuş;
  retry.json yok; Ethernet Authentication succeeded.
- **Açık bulgu:** LastRunTime09:00:01 boot15:51:34'ten önce; RanAfterBoot=false.
  LastTaskResult0 önceki çalışmaya aittir; bu boot için başarılı görev kabulü yapılmadı.
  İlk çıktı boot'tan yaklaşık97s sonra üretilmiştir; gecikmeli/queued başlangıç,
  tetikleyici ve runtime koşulları yeni salt okunur gözlemle ayrılacak.
- İncelenen kurucu AtStartup/09:00/21:00 ile SYSTEM görevi kaydeder,
  RunOnlyIfNetworkAvailable/StartWhenAvailable kullanır; varsayılan pil
  kısıtlarını açıkça kaldırmaz. Her GPO kurulumunda task yeniden Register edilir,
  mevcut task varsa ayrıca Start çağırmaz. Bunlar incelenecek olası etkiler;
  mevcut bulgunun kesin kök nedeni diye atanmadı.
  Tanı için güncel State/Trigger/Settings, ağ/pil ve yalnız bu görevin boot
  sonrası TaskScheduler olayları istenecek. Elle Start veya ayar değişikliği
  yapılmadan doğal durum incelenecek; mevcut RADIUS/policy/CA korunur.

## VV06 eski CNG anahtarı SYSTEM kabulü — 19 Ekim 2026, 15:49 İstanbul

- **🔴✓ Tamamlandı: yenileme sonrası eski yerel sertifika ve CNG private key temizliğinin doğrudan doğrulanması.**
  Operatörün SYSTEM kontrol çıktısı:
  Checked=true, RunAsSystem=true, OldCertificatePresent=false,
  OldKeyPresent=false, CurrentKeyPresent=true.
  Böylece yalnız sertifikanın My deposundan kalkması değil, istemcinin
  takip ettiği eski container'ın MachineKey/Software KSP içinde bulunmaması
  ve yeni container'ın mevcut kalması da doğrulandı.
- Kontrol, VV06 mevcut installed thumbprint'i ve tek takip edilen eski
  thumbprint için pinliydi. Yeni key positive control başarılıdır; hata
  veya erişim yetersizliği absent diye yorumlanmadı.
  Eski thumbprint68B32BBD470847950BAE5629B853739F819150B5;
  korunmuş güncel thumbprint4CFD8321AE08D6074B99AF5C194151AD5F99F454.
- Kontrollü yenileme alt adımında yeni anahtar/sertifika, gerçek EAP-TLS
  yolunda yeni seri, sunucu24h superseded/CRL ve yerel12h cleanup artık ayrı
  kanıtlarıyla tamamlanmış kalemlerdir. B06 offline/expired senaryoları ve
  tüm sertifika yaşam döngüsü paketi topluca tamamlandı sayılmadı.
- Sırada son tek-AllSigned Startup GPO halinin VV06'ya yeniden uygulanması,
  açılış sonrası görev/istemci imzası/sertifika korunması ve bağlantı kontrolü var.
  Bu kabul kaydı çalışan sunucu, CA/policy veya enrollment görevi değiştirmedi.

## VV06 yerel sertifika temizliği kabulü — 19 Ekim 2026, 15:43 İstanbul

- **🔴✓ Tamamlandı: yenileme sonrası eski sertifikanın yerel makine deposundan kaldırılması.**
  installed.json seri5899e122009871b0d5536890bee81e4f0499e605,
  thumbprint4CFD8321AE08D6074B99AF5C194151AD5F99F454,
  renew_at2026-12-14T13:26:42+00:00. Aynı cihaz subject filtresiyle My deposunda
  yalnız bu yeni sertifika listelendi; HasPrivateKey=true,
  NotAfter13.01.2027 16:26:42.
- Takip edilen eski thumbprint68B32BBD470847950BAE5629B853739F819150B5,
  remove_at2026-10-16T01:24:42.2682885+00:00 (İstanbul04:24:42).
  Süre geçmiş; previous metadata kaydının durması eski cert'in mevcut olduğu
  anlamına gelmez. İstemci kodu previous kaydını silmeden cleanup'ı idempotent tekrarlar.
- **🔴✓ Tamamlandı: bu kontrol turunda son enrollment görevi sonucu gözlemi.**
  LastRunTime19.10.2026 09:00:01, LastTaskResult0. Bu, GPO'nun son halinin
  istemciye yeniden uygulandığı veya private key'in silindiği tek başına kanıt değildir.
- **Açık: eski CNG private key'in kaldırılmasının doğrudan doğrulanması.**
  Salt okunur SYSTEM varlık kontrolü için ayrı UUID adlı demand-only geçici
  task hazırlanır. CngKey.Exists, MicrosoftSoftwareKeyStorageProvider/MachineKey
  ve yeni anahtar için positive control kullanılır; key byte'ları okunmaz/export edilmez.
  Check başarısız/unknown olursa absent diye raporlanmaz; mevcut enrollment görevi,
  policy veya sertifika değiştirilmez. Yalnız kendi geçici task/result kaldırılır.
  Script docs/checkpoints/2026-10-19-vv06-key-readonly.ps1 içinde kaydedildi;
  henüz VV06 üzerinde çalıştırılmış/kabul edilmiş sayılmaz.

## Dev.9 CSV teknik kabulü ve farklı paket kimlikleri — 19 Ekim 2026, 15:38 İstanbul

- **🔴✓ Tamamlandı: canlı erişim kayıtları CSV indirme ve dosya yapısı doğrulaması.**
  Operatör AuthWire-erisim-kayitlari-2026-10-19.csv dosyasını paylaştı.
  SHA2564a96015a211da190009cb6f9b6400ee7a1df14cb21b28aa2eb371770529af9ae.
  UTF-8 BOM, CRLF,16 başlık ve her veri satırında16 alan doğrulandı.
  Tam2 veri satırı var; Türkçe başlıklar doğru decode edildi. Dosya değiştirilmedi.
  Bu teknik sütun kabulüdür; operatörün Excel uygulamasındaki görünümü ayrıca bildirilmedi.
- **🔴✓ Tamamlandı: iki kayıt için paket/olay anahtarı karşılaştırması.**
  ID1: UTC12:28:02.224 / İstanbul15:28:02.224,
  request fd65123ccd2457633c67ae72f6f02c7745917047e41672374803a2e7c36ca592,
  event e87cf43e4ee980a558cf66df80945adcb3bdc763a40ac40c9da34fbc0e7ff8cc.
  ID2: UTC12:30:56.411 / İstanbul15:30:56.411,
  request b0caff3edead51b668542290aaa20660f9a4e74b6d2f419334e9a78ea9328f47,
  event 0e8a437e3cc586b53e22e9c02bfd5295875561917b3ee701e08094d6c5d51cdc.
  Aralık174.187s. Paket anahtarları ve olay anahtarları farklı; ikisinde de
  sha256(request_id+'|2') olay anahtarı kuralı bağımsız kontrolle doğrulandı.
  capture_run aynı:1ecb2d1a4da245f793c643499eacb35c.
  Aynı DB satırının UI'de/CSV'de iki kez görünmesi veya aynı paket anahtarının
  iki satır olarak saklanması bulgusu yok. Loglama kapsamı final paket yanıtıdır;
  farklı anahtarlar tek başına iki ayrı kullanıcı oturumunu veya NAS'ın
  yeniden deneme tetikleyicisini kanıtlamaz.
- Her iki satır code2/POLICY_ALLOW, NAS10.35.50.253,
  authwire-pilot-wired, VLAN110, TLS verified=true; VV06 GUID/MAC eşleşiyor.
  **🔴✓ Tamamlandı: yeni sertifika serisinin gerçek VV06 TLS/policy yolunda gözlenmesi.**
  Seri5899e122009871b0d5536890bee81e4f0499e605 iki satırda da aynı.
  Yerel eski sertifika ve private key temizliği ayrı açık kabul kapısıdır.
- İkinci isteğin kablo/dot3svc restart/periyodik yeniden doğrulama gibi tam
  tetikleyicisi bu CSV'de yoktur. Kaynak port/authenticator'ın hangisinin
  değiştiği özetten geri çıkarılamaz. Windows15:28:54 olayıyla tek tek
  zaman eşleştirmesi de bu dosyayla kesinleştirilmedi.
- Bu bulgu için çalışan RADIUS/policy/CA/istemci değiştirilmedi.
  Sıradaki işlem VV06'dan installed.previous, makine sertifika deposu ve
  görev son çalışmasını salt okunur inceleyerek12h yerel cleanup'ı doğrulamak.

## VV06 pozitif kablolu bağlantı ve iki erişim kaydı incelemesi — 19 Ekim 2026, 15:34 İstanbul

- **🔴✓ Tamamlandı: dev.9 sonrasında VV06 kablolu pozitif Windows gözlemi.**
  Ethernet Connected.Authentication succeeded; event15505 19.10.2026 15:28:54,
  reason/error0. GUID415933d5-5010-4a7a-b8bf-0e537e0bc7f2,
  MAC38:ca:84:db:ff:e6; host/AuthWire computer
  69b0d5cd-db61-4627-9db7-fcc5230152a3.
- Erişim kayıtları görüntüsü image(20261019-123308).png okundu.
  İki ayrı satır zamanı15:28:02 ve15:30:56; her ikisi Access-Accept/POLICY_ALLOW,
  NAS10.35.50.253, policy authwire-pilot-wired, yanıttaki VLAN110,
  kayıtlı GUID69b0d5cd-db61-4627-9db7-fcc5230152a3, bildirilen MAC38:ca:84:db:ff:e6.
  Her iki satırda yenilenmiş TLS seri5899e122009871b0d5536890bee81e4f0499e605
  görünüyor. Bu, eski seri yerine yeni serinin sunucudaki TLS/policy yoluna
  ulaştığına ilişkin saha kanıtıdır; yerel eski sertifika/anahtar temizliğini
  veya DHCP lease yenilenmesini tek başına kanıtlamaz.
- Görüntü süreç326873 için yazılan2, tekrar0, yazılamayan0 gösteriyor.
  Bu sayaçlar süreç gözlemidir; tek bağlantı oturumu sayacı veya kayıpsızlık kanıtı değildir.
- **İnceleme açık:** operatör iki satırın nedenini sordu. Farklı zamanlar
  yeni deneme/yeniden doğrulama ile uyumludur; bunu kablo takılması/dot3svc
  restart'ı/periodic reauth gibi belirli bir tetikleyiciye bağlayan kesin
  kanıt henüz yok. Windows event zamanı15:28:54 iki satırla birebir aynı
  değildir; saat farkı/gecikme varsayılıp kesin eşleştirme yapılmadı.
  CSV'deki Kayıt ID/Paket korelasyon ID/Olay ID karşılaştırması istenecek.
  Aynı final paketin çift yazıldığı veya UI'nin aynı satırı çift çizdiği
  peşinen kabul edilmedi; farklı request ID de tek başına NAS'ın yeniden
  gönderme nedenini açıklamaz. Sütunlu CSV kabulü hâlâ açık.
- Sunucuya salt okunur erişimde RADIUS active/PID326873 görüldü.
  segmentiq hesabının private erişim DB'sini doğrudan okumasına izin yok;
  izinler değiştirilmedi. Dar zaman aralığındaki normal servis journal'ında
  giriş bulunmadı; bu durum paket gelmediği anlamına yorumlanmadı.
  Bu incelemede servis, policy, sertifika, kaynak veya Windows değiştirilmedi.

## Dev.9 operatör ekran kabulü — 19 Ekim 2026, 15:22 İstanbul

- **🔴✓ Tamamlandı: Erişim kayıtları ekranının hatasız açılması.**
  Operatör herhangi bir hata görmediğini ve kayıt bulunmadığını bildirdi.
  Bu bildirim filtrelerin gerçek satırlarda sonuç doğruluğunu veya logger'ın
  gerçek NAS yanıtı kaydettiğini tek başına kanıtlamaz.
- **Açık: dev.9 canlı CSV sütun kabulü.** Listede kayıt olmadığı için indirme
  ve sütun kontrolü yapılmadı; başarılı sayılmadı. Dev.8 yönetim geçmişi CSV
  kabulü ayrı tamamlanmış iştir, dev.9'a aktarılmaz.
- Sıradaki saha adımı: VV06'da yeni EAP-TLS denemesi, Windows sonucu ile
  sunucunun final RADIUS kaydındaki NAS/kimlik/karar/VLAN eşleştirmesi.
  İlk gerçek kayıtla dev.9 CSV indirme/sütun kontrolü de yapılacak.
- Bu bildirim üzerine kaynak, servis, policy, sertifika veya Windows
  ayarı değiştirilmedi. Diğer açık kabul kapıları korunur.

## Dev.9 canlı erişim kayıtları teknik kurulumu kabul edildi — 18 Ekim 2026, 23:30 İstanbul

- **🔴✓ Tamamlandı: canlı dev.9 kaynak güncellemesi ve final RADIUS kayıt modülünün etkinleştirilmesi.**
  Operatörün paylaştığı ACCESS_HISTORY_DEPLOY_FINISHED verified=true çıktısı kabul edildi.
  Kaynak değişimi sırasında RADIUS PID1274 korundu; ayrı ve beklenen kontrollü
  etkinleştirme restart'ı sonrasında PID326873 ile aktif listener doğrulandı.
  Broker PID149955 korundu. Base unit ve native modül değiştirilmedi.
- **🔴✓ Tamamlandı: kritik durum koruması.** files/pids/timers/business_state
  kontrollerinin tümü true; policy, sertifika ve Windows değişikliği false.
  Kalıcı başlangıç kanıtı:
  /var/backups/authwire/scheduled/access-update-dev9-20261018T202740Z-eaabef14.
  Etkinleştirme kanıtı:
  /var/backups/authwire/access-history-20261018T202841Z-699eab01.
- **🔴✓ Tamamlandı: kurulum öncesi/sonrası yeni managed yedekler ve son yedekte izole veri restore kabulü.**
  Önceki arşiv authwire-scheduled-20261018T202839Z-2c79decf715e.tar.gz,
  SHA256769f5d1d9cf973ef9e2cc9edb087538c7de45028481e2ebea1999da6302191e4.
  Son arşiv /var/backups/authwire/scheduled/authwire-scheduled-20261018T202941Z-3f8a76246977.tar.gz,
  SHA2565b7532962f8692eaab8471c268510e9862b8e3b415f9f9e6b5b786ddf0da64dd.
  145 dosyada byte/sahip/mod kontrolü, DB/PKI/secret/key kontrolleri ve yeni
  access_history_database_integrity_ok/access_history_columns_readable geçti.
  İzole kopya kaldırıldı; restore edilmiş kod/servis çalıştırılmadı, network çağrısı yok.
  Bu kanıt tam appliance boot restore kabulü değildir.
- **🔴✓ Tamamlandı: canlı sunucu-local API teknik kontrolü.** Sekiz endpoint,
  üçer istek, tümü200; yeni /api/radius/events medyan3.0ms/maksimum12.0ms.
  Tüm ölçümlerde en yüksek süre41.6ms. Bunlar loopback ölçümüdür; operatör
  tarayıcısının davranışı ve uç cihaz kimlik doğrulaması için ayrı kanıt gerekir.
- **Açık:** operatörün dev.9 Erişim kayıtları ekran/filtre ve koşullu CSV kabulü;
  gerçek VV06/NAS final yanıt kaydı eşleştirmesi19 Ekim saha adımında.
  Test cihazı uzaktayken boş liste tek başına hata değildir; geçmiş denemeler
  geriye dönük üretilmez, yeni etkinleştirmeden sonraki final yanıtlar tutulur.
  B11 accounting/korelasyon/arşiv/saklama/temizlik ve önceki açıklar korunur.
  İlk doğal backup takvimi, off-host hedef, tam boot/rollback, VV06 leaf/yerel
  cleanup/son GPO ve kullanıcı EAP-TLS tamamlandı işaretlenmedi.

## B11 final RADIUS yanıt kaydı geliştirmesi — 18 Ekim 2026

- Dev.8 yönetim geçmişi/CSV alt işi tamamlandı. Operatör devam talebi üzerine
  ayrı final RADIUS yanıt kaydı alt işi PR37'de başlatıldı:
  https://github.com/Asitavandas/kaname/pull/37. Aday0.14.0-dev.9; canlı
  sunucu hâlâdev.8, RADIUS1274/broker149955 ve iki timer korunuyor.
- **🔴✓ Tamamlandı: kapsam ve native son yanıt noktası incelemesi.**
  Certificate-check callback allow'u final kabul sayılmıyor. Opt-in outer
  post-auth Accept/Reject hook'u, pre-callback TLS/CRL retleri dahil son seçilen
  sunucu yanıtını alıyor. Accounting veya uç cihaz başarısı diye gösterilmiyor.
- Geliştirme: ayrı private append-only access.sqlite3,200.000 satır/64MB'den
  önce dolan sınır,128MB boş disk altı koruması,25ms SQLite busy bekleme.
  Başarılı satır FULL sync commit; kayıt hatası reply/Auth-Type değiştirmez.
  Tanınan native hata yalnız sabit kategoriye çevrilir; ham hata/key/outer
  identity yazılmaz. Native TLS callback'i yoksa seri/GUID/tür bilinmiyor kalır.
  MAC yalnız NAS bildirimi, kaynak IP gerçek packet source'tur.
- Policy kararı, kayıtlı GUID/tür ve TLS seri ek bilgisi orijinal yetki
  sağlayıcısından ayrıro/query_only bağlantıyla okunur; ek Store başlangıcı,
  AD sorgusu veya PKI/policy yazma yoktur. Bilgi alınamazsa bilinen karar/TLS
  seri korunur, bilinmeyen GUID uydurulmaz. Asıl radius_adapter/policy/registry/
  PKI/enrollment/Windows kaynakları değiştirilmedi.
- **🔴✓ Tamamlandı: ilk normal/debug gerçek loopback protokol kabulü ve
  genişletilmiş tekrar/kilit/recovery testleri.** İlk26/24, sonra29/27
  senaryolu turda gerçek EAP-TLS ve imzalı/authenticator doğrulanmış yanıtlar:
  policy izin/ret, grup/hesap/AD retleri; revoked/expired/untrusted/purpose,
  CRL hot reload; cache tekrarında tek kayıt; logging DB EXCLUSIVE kilitliyken
  kabul/VLAN'ın korunması ve kayıt uyarısı, kilit kalkınca yeni kayıt; silent
  drop'a sahte final olay yazılmaması. Bunlar sentetik AD/izoleCA'dır, VV06
  saha kabulü değildir. Son read-only metadata sürümü de aynı 29/27
  senaryolu son turu geçti; doğal CRL bekleme/yenileme kontrolü korundu.
- **🔴✓ Tamamlandı: Erişim kayıtları arayüzünün ilk gerçek Chromium kabulü.**
  Sonuç/NAS/neden/tarih/metin filtreleri,100'lük sayfalama, yalnız sayfa CSV,
  formül koruması, yetki403, hatada oturum/liste korunması, logout sonrası eski
  yanıtın atılması;390/1366/1920 taşmasız görünüm. Servis eylemi0.
- Yedek worker'da yalnız yeni log tablosu iş durumu istikrar karşılaştırması
  dışında; tüm satırlar SQLite backup ile arşivde. Gerçek SQLite/arşiv fixture
  testi eşzamanlı log yazımıyla geçti. Mevcut offline checker128MB dosya sınırı
  korunur; log64MB ile uyumludur. Tarihsel ilk backup checkpoint'i korunur;
  güncel worker için ayrı fresh-install checkpoint'i vardır.
- Kontrollü etkinleştirme aracı base unit/native modülü/CA/policy'ye dokunmaz.
  Gerçek servis hesabıyla generator ve radiusd-XC ön kontrolü; yalnız generator
  bayrağı ekleyen drop-in; RADIUS restart ve listener doğrulaması; hata halinde
  araçça değiştirilen worker/release/drop-in geri alınıp eski listener beklenir.
  Dört izole dosya/lock/fault testi geçti.
- **🔴✓ Tamamlandı: gerçek hardened systemd etkinleştirme ve geri dönüş testi.**
  Son CI turunda gerçek native restart, tek final Reject satırı, korunan
  ProtectSystem/NoNewPrivileges/User ve panel PID doğrulandı. Başarılı -XC
  kontrolünden sonra bilerek bozulan ExecStartPre gerçekten başarısız oldu;
  eski worker/release/drop-in ve orijinal authorizer/listener geri geldi.
  İlk fixture turlarındaki UDP readiness ve root dosya güven denetimi
  hataları test kurulumunda düzeltildi; ürün güven denetimleri gevşetilmedi.
  Önceki başarısız turlar başarılı kabul diye sayılmadı.
- Launcher dev.8'in115 kaynak hash'ini pinler; beklenmedik kaynak/istemci
  değişikliğini ve kapsamın yetkilendirme dosyalarına genişlemesini reddeder.
  Kaynak güncellemesinde RADIUS PID korunur; gözlemci için ayrı kontrollü
  restart açıkça raporlanır. Önce/sonra managed yedek, kalıcı koruma kanıtı,
  son arşivde izole restore + erişim DB bütünlük/sütun okuması hazırdır;
  bu yeni launcher henüz canlıda yürütülmedi.
  cryptography 46.0.0 içeren mevcut venv kullanılacak; sistem Python41
  gözlendiği için launcher yanlış yorumlayıcıyla başlamayı reddeder.
- **🔴✓ Tamamlandı: dev.9 geliştirme ve son teknik kabul.** PR37 ana kaynakla
  204f63088550209a912e4c81659974cdf1048d5a commit'inde birleştirildi.
  Son aday c4c1ec3:524 test/25 ortam atlaması, Chromium, gerçek hardened
  systemd etkinleştirme/failed-start rollback, native EAP-TLS29/27 ve35
  production parse/runtime kontrolü geçti. Windows/native LDAP/Kerberos
  sınırları da başarılıdır. Önceki B04 aralıklı yük testi bulgusu bu başarılı
  tekrarla kapatılmaz. Test edilen124 dosyanın Git blob'ları doğrulandı;
  Linux manifest SHA256:
  0157e4825a6acc7bbfa8b032bfa0dd96e55105b6538af267ce3163b2c19a3769.
  Somut sudo launcher docs/checkpoints/2026-10-18-access-history.py içinde
  pinlidir. **🔴✓ Tamamlandı: sunucuda paket hazırlama ve eşleşme kontrolü.**
  Ana kaynak staging işi142 test/4 ortam atlamasıyla geçti; segmentiq üzerinde
  hazırlanan124 dosyalı manifest test edilen paketle birebir aynıdır.
  Stage: /home/kaname-runner/kaname-stage-204f63088550.
  Operatör launcher'ı /home/segmentiq/authwire-access-history-dev9-20261018.py
  üzerinde syntax/hash doğrulandı, yürütülmedi. SHA256:
  52043765498de430c423eb292bbc53dc569cef8472e2457d25eb84e4b9fd56c2.
  Canlı sudo kurulumu ve gerçek bağlantı kabulü hâlâ açıktır.
- **Açık:** canlı sudo
  kurulumu, panel operatör ekran/CSV kabulü ve19 Ekim gerçek VV06/NAS olay
  eşleştirmesi. Henüz canlı log etkinleştirilmedi; bu alt iş saha tamamlandı
  değildir. B11 accounting/tam korelasyon/arşiv/retention/temizlik, B04 aralıklı
  enrollment kilitlenmesi, doğal backup takvimi, off-host hedef, full boot/
  rollback ve VV06 leaf/yerel cleanup/son GPO/kullanıcı EAP-TLS açıkları korunur.
  Yeni resmi rapor üretilmedi.

## Dev.8 yönetim geçmişi operatör kabulü tamamlandı — 18 Ekim 2026, 22:28 İstanbul

- **🔴✓ Tamamlandı: yönetim işlem geçmişi alt işinin operatör ekran/CSV kabulü.**
  Operatör son kontrol için “sütun doğru açıldı” bildirdi. Önceki dev.8
  sürüm/ekran/filtre ve indirme bildirimiyle birlikte CSV sütun kabulü kapandı.
  İlk görüntüde Türkçe başlıklar okunuyordu; virgül ayırıcısıyla açma sonrası
  sütunlar düzeldi. Bu düzeltme için ürün kodu veya Windows genel bölge
  ayarı değiştirilmedi; yeniden dağıtım gerekmedi.
- İlk B11 yönetim geçmişi alt işi geliştirme, izole testler, canlı teknik
  koruma/API ve operatör kabulüyle tamamlandı. Mevcut yönetim kayıtlarını
  salt okunur filtreleme, sayfalama ve görünen sayfayı CSV indirme kapsamıdır.
  Canlı daha-eski-kayıt testi, kayıt mevcutsa koşulluydu; ayrı canlı kanıt
  iddiası yoktur. Otomatik sayfalama test kanıtı önceki kayıtta korunur.
- **B11 bütünü açık:** final native RADIUS karar günlüğü, accounting ve
  korelasyon, arşiv/saklama/temizlik henüz tamamlanmadı. B04 aralıklı
  eşzamanlı SQLite kilitlenmesi, doğal yedek takvimi, off-host hedef,
  tam boot/rollback, uzun panel gözlemi ve VV06 leaf/yerel cleanup/son GPO
  kabulü korunur. Kullanıcı EAP-TLS pilotu yol haritasında kalır.
- Bu kabul kaydında çalışan servis, policy, sertifika, Windows istemcisi
  veya ürün kaynağı değiştirilmedi. Yeni resmi rapor üretilmedi.

## Dev.8 operatör ekranı ve CSV gözlemi — 18 Ekim 2026, 22:18 İstanbul

- **🔴✓ Tamamlandı: operatör dev.8 sürüm ve CSV indirme doğrulaması.**
  Operatör önceki ekran/filtre adımlarını yaptığını, sürümü0.14.0-dev.8
  gördüğünü ve CSV indirdiğini bildirdi. Daha eski kayıt sayfalaması yalnız
  kayıt varsa istenmişti; bu görüntü ayrı bir canlı sayfalama kanıtı değildir.
- image(20261018-191708).png görüntüsünde CSV başlığı ve iki config_saved
  satırı okunuyor; Türkçe başlıklar bozuk görünmüyor. Ancak başlık ve her kayıt
  tek A hücresinde: Excel virgülle ayrılmış alanları sütunlara ayırmamış.
  Görüntüden ham dosyanın bütün byte/kaçış doğruluğu ayrıca kanıtlanamaz.
- **Açık: Excel'de sütunlu CSV okuma kabulü.** Veri → Metin/CSV'den içe
  aktarımda UTF-8 ve Virgül ayırıcısı seçilecek; önizlemede Kaynak, Kayıt ID,
  Zaman UTC, Olay vb. ayrı sütunlar görülecek. Mevcut A sütunu için
  Veri → Metni Sütunlara Dönüştür → Sınırlandırılmış → yalnız Virgül,
  metin niteleyicisi çift tırnak alternatifi vardır.
  Bu gözlem tek başına sunucu veri kaybı veya export bozulması kanıtı değildir.
- Bu aşamada kaynak, servis, Windows, policy veya sertifika değişikliği
  yapılmadı. B11 yönetim geçmişi alt işinin son CSV sütun kabulü açık;
  final RADIUS olayları/accounting/retention ve diğer mevcut açıklar korunur.
  Tam B11 tamamlandı işaretlenmedi; yeni resmi rapor üretilmedi.

## Dev.8 canlı yönetim geçmişi kurulumu kabul edildi — 18 Ekim 2026, 22:07 İstanbul

- **🔴✓ Tamamlandı: dev.8 canlı güncelleme ve teknik koruma/API kabulü.**
  Operatör PANEL_DEPLOY_FINISHED verified=true, version=0.14.0-dev.8 paylaştı.
  Güncelleme/HTTPS başarılı; configuration/administrators ve Windows client
  source hash86081b... korundu. Bu sonuç geliştirilen ilk B11 yönetim geçmişi
  alt işinin canlı teknik kabulüdür; B11 bütünü veya ekran/CSV kabulü değildir.
- **🔴✓ Tamamlandı: kurulum öncesi yeni managed yedek ve kalıcı karşılaştırma.**
  /var/backups/authwire/scheduled/authwire-scheduled-20261018T190641Z-48ea2fe48b0c.tar.gz
  SHA25654794ff40afd243f43bf73878e2d8218e061c2e98ef9372f7c68909709f32ca6.
  Arşiv ve SQLite bütünlüğü, süreç koruması doğrulandı. Bu yeni arşivde
  data_restore_exercised=false; önceki ayrı restore kanıtı bunun için yeni
  restore kabulü sayılmaz. Başlangıç/sonra kanıtı:
  /var/backups/authwire/scheduled/panel-update-dev8-20261018T190526Z-9a522334.
- PANEL_PRESERVATION: files/pids/timers/business_state hepsi true.
  RADIUS PID1274 ve broker PID149955 aynı; backup timer korundu.
  Windows/policy/sertifikalar değişmedi. RADIUS başlatılmadı; unit'i güncellenmedi.
  Yalnız panel source güncellemesi yapıldı; legacy audit uç noktası korunur.
- Kimlikli loopback önce beş, sonra yedi API'de üçer okuma: toplam36 yanıt200.
  Yeni /api/audit/history medyan2.5ms, max2.7ms; administrators kaynağı2.2ms.
  Sonra bütün okumalarda medyan1.7–7.4ms, max40.4ms. Bu sunucu içi okumalardır;
  gerçek tarayıcı görüntüsü, filtre doğruluğu veya indirilen CSV kabulü değildir.
- **Bekliyor: operatör tarayıcı/CSV kabulü.** Ctrl+F5 sonrasıdev.8, İzleme →
  İşlem geçmişi listesi; config_saved olay filtresi, filtre temizleme,
  mevcutsa Daha eski kayıtlar, bu sayfa CSV indirme ve Türkçe karakterler
  kontrol edilecek. Ayar/sertifika değişikliği, kayıt silme veya servis
  stop/restart yapılmayacak. Eksik actor alanı Kaydedilmemiş olabilir.
- Açıklar korunur: final RADIUS karar günlüğü/accounting/korelasyon,
  archive/retention/temizlik;4-worker enrollment fixture'daki aralıklı SQLite
  kilitlenmesi araştırması. Uzun panel gözlemi, off-host hedef/altyapı, doğal
  yedek takvim çalışması, full boot/rollback ve19 Ekim VV06 leaf/cleanup/son GPO
  saha kabulü açık. Kullanıcı EAP-TLS pilotu unutulmadı. Yeni resmi rapor yok.

## B11 yönetim geçmişi paketi hazır; canlı kurulum bekliyor — 18 Ekim 2026, 22:03 İstanbul

- **🔴✓ Tamamlandı: ilk B11 yönetim geçmişi geliştirme, test ve dağıtım hazırlığı.**
  PR36, main'e551b1a96e69cacca490229c02e7e0216da4b932a olarak birleştirildi.
  Test edilen son branch3f665a33230bad8467475d79a0cc0281f47ad8d2; bütün
  ilgili kapılar başarılı. Native Kerberos/load kapısı tek tekrar sonrasında
  başarılı; önceki SQLite kilitlenmesi aşağıdaki açık bulguda korunur.
- Sunucu self-hosted hazırlık141 testi geçti.115 dosyalık paket:
  /home/kaname-runner/kaname-stage-551b1a96e69c.
  Manifest SHA256862824644e3aaac399d7f28e1b3ff81081afb4016beeb7dce8068a7504011852;
  bağımsız Git blob karşılaştırması115/115 aynı, self-hosted çıktı aynı digest.
- /home/segmentiq/authwire-panel-update-dev8-20261018.py
  SHA256bca8e76fc1d89286d5c0a47a2b797b5ea33113219afb8af2dd10a43d6c67e935.
  Aynı kaynak docs/checkpoints/2026-10-18-panel-dev8.py içinde saklanır.
  Sunucuda hash/derleme doğrulandı, çalıştırılmadı; kurulu sürümdev.7 kalır.
- Launcher yeni managed yedek, kalıcı hash-only başlangıç/sonra kanıtı,
  korunan dosya/mod/sahip, DB iş durumu, RADIUS/broker PID ve timer karşılaştırması
  ister. Mevcut dev.7 server hash'i pinlidir; başka panel kaynağı veya beklenmeyen
  audit modülü varsa reddeder. İmzalı Windows istemcisi ve kimlik kodu aynı kalır.
  Yalnız gözden geçirilmiş panel route/audit okuyucu/statikler/sürüm değişebilir.
- Dört source guard testi pinned dev.7 ve aynı adayın tekrarını kabul, bilinmeyen
  server/modül ve değişmiş istemci reddini geçti. Ayrı API-probe fixture yeni
  history uçlarının yalnız update sonrası sorgulandığını doğruladı; ağ çağrısı
  yapmadı. Uygulama hesabına ait özel key sahipliği kontrolü dev.7 düzeltmesini
  korur; herhangi bir chown/chmod veya yeni şema migration eklenmedi.
- **Bekliyor:** sudo ile canlı update/koruma/API sonucu ve operatör filtre/CSV
  kabulü. Bunlar olmadan bu alt işin canlı kabulü veya tüm B11 tamamlandı değildir.
  RADIUS karar günlüğü, accounting/korelasyon, archive/retention/temizlik;
  B04 eşzamanlı kilitlenme araştırması ve diğer saha/kurtarma kapıları açıktır.
  Tamamlanan/açık işler güncel yol haritasına işlendi; yeni resmi rapor yok.

## B11 mevcut kayıt envanteri ve yönetim geçmişi alt işi — 18 Ekim 2026

- **🔴✓ Tamamlandı: kayıt kapsamı salt okunur kaynak/sunucu incelemesi.**
  Önceki panel /api/audit yalnız son100 yapılandırma/sertifika kaydını gösterir.
  admin_audit ayrı DB'de panel hesap işlemleri tutar. Servis talepleri ana
  audit içinde, tamamlanma sonucu ayrı broker geçmişindedir. Şema/trigger
  ve kayıt yazarları incelendi; ham müşteri olayları veya sırlar basılmadı.
- **Açık bulgu:** radius_adapter kararları kalıcı erişim tablosuna yazmıyor;
  runtime auth=no, auth_badpass=no, auth_goodpass=no; accounting kapalı.
  Sertifika callback allow sonucu final EAP başarısı sayılmaz; native TLS/CRL
  retleri callback'e ulaşmayabilir. Dolayısıyla mevcut yönetim kayıtlarından
  cihaz/policy/VLAN/ret nedeni içeren eksiksiz erişim geçmişi üretilemez.
  Okunabilir son24saat journal0satır gözlemi, trafik veya hata yok kanıtı değildir.
  Başarısız panel girişinin ayrıntılı kalıcı audit olayı da bu alt işle eklenmedi.
- **Geliştirilen ilk alt iş:** yeni /api/audit/history salt okunur/parametreli,
  tarih/olay/metin filtresi,100'lük ID sayfalama ve ilk sayfa üst sınırı;
  yeni kayıt gelmesi eski sayfayı kaydırmaz. Kaynak toplam sayısı ve bütün DB
  boyutu görünür. İki saniye query bütçesi, ro/query_only bağlantı vardır.
  API/şema/append-only trigger'lar ve mevcut kayıt yazarları değiştirilmedi.
- Panel hesap kaynağı için audit.events + system.administrators gerekir.
  Eksik eski actor bilgisi doldurulmaz; admin ID'leri tarihsel ad sayılmaz.
  Servis satırı yalnız talep diye etiketlenir. Açık alan projeksiyonu yapılır,
  ham JSON/private key/session/parola döndürülmez. Eski /api/audit uyumludur.
- CSV yalnız görünen100'e kadar kayıttır; UTF-8 BOM/standart kaçış ve formül
  başlatan hücrelerde apostrof koruması var. CSV, sunucu arşivi veya silme
  değildir. Filtre değişince indirme kapanır; oturum değişiminde eski veri temizlenir.
  API her istekte kaynak yetkisini kontrol eder.
  Kayıtlar silinmez; otomatik retention veya şema/index migration eklenmedi.
- PR36 https://github.com/Asitavandas/kaname/pull/36; aday dev.8.
  Yerel39 audit/HTTP/store testi geçti. **🔴✓ Tamamlandı: geliştirme ve izole teknik/tarayıcı kabulü.** Son kaynak
  3f665a33230bad8467475d79a0cc0281f47ad8d2 için genel502test (25 ortam atlaması),
  Chromium akışı, native LDAP/installer/systemd, Windows ve normal/debug
  gerçek EAP-TLS policy/VLAN +34 runtime test kapıları başarılı. Tarayıcı
  yeni kayıt sırasında sayfalama, İstanbul gün sınırı, gerçek CSV/formül
  koruması, kaynak yetkisi403, geçersiz filtre, okuma hatasında oturumun
  korunması ve çıkış sonrası eski yanıtın atılmasını doğruladı.390/1366/1920
  genişliklerde viewport taşması yok; screenshot incelendi. Servis eylemi0.
  Henüz canlı dağıtım veya B11 bütünü tamamlandı değildir.
  Kullanılan/eksik kapsam işletim belgesi AUDIT_HISTORY.md içinde.
- Ayrı100.000 satırlı izole ölçüm: son sayfa1.9ms, bulunmayan metin11.4ms,
  tarih filtresi1.1ms, reserved writer varken okuma0.9ms; DB byte hash'i aynı.
  Bunlar yerel fixture ölçümleridir, müşteri kapasite garantisi değildir.
- **Açık B04 kapasite bulgusu:** ayrı1000 cihaz/4worker enrollment job'ı
  bir kez değişmemiş Store.snapshot/device_enrollment yolunda SQLite
  database-is-locked ile kaldı (job117760170263). Yeni history modülü bu
  load scriptinde import/çağrı almıyor. Aynı job tek ayrı tekrarda geçti:
  1000 benzersiz/kurulmuş sertifika,24.394sn; önceki kaynak da1000/19.879sn
  geçmişti. Bu, aralıklı kilitlenmenin düzeltildiğini kanıtlamaz. Kayıt kodu,
  timeout, thread sayısı veya test ölçütü değiştirilmedi; B04 geniş yayılım/
  eşzamanlı kayıt kabulünde ayrıca araştırılacak. Başarısız gözlem gizlenmedi.
- Canlı salt okunur doğrulama: dev.7 server hash'i beklenen d1b60e...,
  yeni audit okuyucusu henüz yok. Panel275154/RADIUS1274/broker149955 ve backup
  timer aktif. Native kimlik doğrulama/PKI/policy/Windows kaynakları aynı.
  Yeni root launcher mevcut dev.7 server hash'ini, yeni modül yokluğunu veya
  tam aday eşleşmesini kontrol edecek; ilk ve sonraki API probe'ları ayrıdır.
- **Açık işler:** bu alt işin canlı kurulum/operatör CSV kabulü; final
  RADIUS olay toplama ve accounting, arşiv/retention/temizlik tasarımı;
  uzun panel gözlemi, off-host hedef, doğal yedek takvim kabulü ve full boot/
  rollback.19 Ekim VV06 leaf/yerel cleanup/son GPO ve kullanıcı EAP-TLS pilotu
  korunur. Yeni resmi rapor üretilmedi.

## Dev.7 gerçek tarayıcı kabulü tamamlandı — 18 Ekim 2026, 16:43 İstanbul

- **🔴✓ Tamamlandı: dev.7 operatör ekran kabulü.** Operatör istenen dört
  kontrol için “tüm sonuçlar belirttiğin gibi” bildirdi: Ctrl+F5 sonrası
  sürüm0.14.0-dev.7; Kontrol merkezi RADIUS durumu ve son kontrol zamanı;
  Temel ayarlar → Gözden geçir ekranında değişiklik yok ve pasif kaydet;
  RADIUS istemcilerinde mevcut switch/AP kayıtlarının yerinde olması.
- Bu kontroller ayar değiştirmeden yapıldı. Dev.7 B01 review/revision/tek kayıt
  ve gerçek RADIUS özeti alt işi geliştirme, otomatik test, canlı koruma/API
  ve gerçek tarayıcı kabulüyle kapandı. Canlı ortamda değişmiş FQDN/domain
  kaydedilmesi veya RADIUS restart işlemi yapılmış sayılmaz; bu mutasyonlar
  izole testlerde sınandı. B01'in tüm wizard/OS apply kapsamı kapanmaz.
- **Açık işler korunuyor:** panel aralıklı hata/uzun süreli gözlemi, B01 kalan
  kurulum/apply, B11 accounting/korelasyon/saklama, off-host hedef/altyapı,
  ilk doğal yedek takvim çalışması ve tam OS/runtime boot/rollback.
  VV06 seçilen yenilenmiş EAP leaf, yerel12h eski sertifika/anahtar cleanup
  ve son GPO halinin uygulanması19 Ekim Pazartesi saha planında.
  Kullanıcı EAP-TLS pilotu ve G01–G07 sırası korunur. Yeni resmi rapor yok.

## Dev.7 canlı panel güncellemesi kabul edildi — 18 Ekim 2026, 16:39 İstanbul

- **🔴✓ Tamamlandı: 0.14.0-dev.7 canlı güncelleme ve teknik koruma/API kabulü.**
  Operatör düzeltilmiş launcher çıktısında PANEL_DEPLOY_FINISHED verified=true,
  version=0.14.0-dev.7 paylaştı. Source update ve HTTPS doğrulaması başarılı;
  configuration/administrators ve Windows client source hash'i korundu.
  Ön kontrol sahiplik düzeltmesi gerçek sunucuda da geçmiştir.
- **🔴✓ Tamamlandı: bu güncelleme öncesi yeni managed yedek ve kalıcı baseline.**
  /var/backups/authwire/scheduled/authwire-scheduled-20261018T133845Z-a54aaeddfb04.tar.gz
  SHA256e9c440b5b294e2d776cb6dbc9e219569931e70a4e694b02869367dcbc94aecb7.
  Arşiv ve SQLite bütünlüğü, süreç koruması başarılı. Bu yeni arşiv için
  data_restore_exercised=false; önceki ayrı izole restore kabulü geçerlidir,
  bu arşivde yeniden restore yapılmış sayılmaz.
  Başlangıç/sonra kanıt dizini:
  /var/backups/authwire/scheduled/panel-update-dev7-20261018T133746Z-dcf546f4.
  original_preflight_snapshot_persisted=true; başlangıç snapshot'ı saklandı.
- PANEL_PRESERVATION: files/pids/timers/business_state hepsi true.
  RADIUS PID1274 ve broker PID149955 korundu. Policy, sertifikalar ve
  Windows değişmedi; backup timer korundu. RADIUS başlatılmadı ve unit'i
  değiştirilmedi. Panel source güncellemesinin yeniden başlatması ayrı kapsamdır.
- Kimlikli loopback önce/sonra beş API'de üçer okuma, toplam30 yanıt200.
  Güncelleme sonrası medyan1.8–7.5ms, en yüksek35.2ms. Bunlar sunucu içi
  okumadır; kullanıcının gerçek tarayıcı ekran kabulünün yerine geçmez.
- **Bekliyor: dev.7 operatör tarayıcı kabulü.** Ctrl+F5 sonrası0.14.0-dev.7,
  ana sayfa RADIUS özeti ve kontrol zamanı, Temel ayarlar → Gözden geçir
  ekranında değişiklik yok özeti/kayıt düğmesinin kapalı olması ve RADIUS
  istemcilerinin korunması, hiçbir ayarı kaydetmeden kontrol edilecek.
  Bu dar kabul tamamlanmadan bütün B01 veya OS apply akışı kapatılmaz.
- Önceki açıklar korunur: uzun süreli panel gözlemi, off-host hedef/altyapı,
  doğal yedek takvim tetiklemesi, tam boot/rollback,19 Ekim VV06 yenilenmiş
  EAP leaf/yerel12h cleanup/son GPO uygulaması ve kullanıcı kimliği pilotu.
  Kullanıcı yeni resmi rapor istemedi; çalışma kaydı güncellendi.

## Dev.7 ön kontrolündeki sahiplik hatası ve düzeltilmiş launcher — 18 Ekim 2026

- Operatör PANEL_DEPLOY_FAILED phase=preflight, category=ValueError,
  evidence=null paylaştı. Bu akışta source update, yeni yedek ve servis
  yeniden başlatma adımına ulaşılmadı; canlı dev.7 kabulü açık kalır.
- **Tespit edilen launcher kusuru:** snapshot bütün korunan dosyalara kod/unit
  için yazılmış root sahipliği kontrolünü uyguluyordu. Vault._key tasarımı
  secret-store.key sahibinin çalışan kaname-lab hesabı olmasını zorunlu kılar.
  Bu sunucuda state dizini/uygulama hesabı UID999 ve private0700 olarak
  doğrulandı. Uygulama anahtarında root şartı bu sözleşmeyle çelişir.
  Orijinal hata kaydı alt kontrolü adlandırmadığından root-only dosyaların
  gerçek metadata'sı henüz yeni launcher çıktısıyla ayrıca doğrulanacaktır.
- **🔴✓ Tamamlandı: launcher koruma kontrolünün düzeltmesi ve altı izole test.**
  Kod/unit/native dosyalar root-owned ve başka kullanıcıca yazılamaz kalır.
  Yalnız üç sabit uygulama veri yolunda özel kontrol vardır: kasa anahtarı
  uygulama hesabına ait olmalı; RADIUS materyali root veya aynı hesaba ait
  olabilir; hepsi gerçek özel dosya, grup/diğer erişimi olmayan modda olmalı.
  Symlink, yabancı sahip ve grup erişimi reddedilir. Önce/sonra hash, uid/gid ve
  mod karşılaştırması korunur. Sahiplik/izin değiştiren komut eklenmedi.
- Altı test özel geçici dosyalar ve simüle UID metadata'sıyla çalıştı; uygulama
  anahtarı kabulü, root/yabancı kasa sahibi reddi, grup okuma reddi, symlink
  reddi, RADIUS owner sınırı ve root-only kod sınırını doğruladı.
  Yerel ortamda gerçek farklı UID chown desteklenmediği için bu bölüm gerçek
  OS hesap/UID kabulü olarak gösterilmez. Müşteri dosyalarına test yapılmadı.
- Daha ayrıntılı preflight_helpers/manifest/sources/preservation/evidence
  evreleri ve sabit guard_code eklendi; sır veya istisna gövdesi basılmaz.
  Yeni /home/segmentiq/authwire-panel-update-dev7-fix-20261018.py
  SHA2569e343d5806a51fba4dfe89366797d5c6a71329ae7a5fba82af876dfe5dcfb8d7.
  Aynı kaynak docs/checkpoints/2026-10-18-panel-dev7-fix.py içinde.
  Sunucuda hash ve derleme doğrulandı, henüz çalıştırılmadı. Önceki
  8ba63e... launcher yerine bu komut kullanılacak; eski dosya tarihsel kanıttır.
- Salt okunur karşılaştırma: korunan29 kaname kaynağı aynı, ek/çıkarılacak
  korunan dosya yok; updater/backup helper hash'leri aynı. Panel PID174745,
  RADIUS1274, broker149955; iki timer active/enabled. Kaynak release397fa3...
  için main üzerindeki bütün CI kapıları da artık başarılı. Paket112 dosya
  ve manifest değişmedi; uygulama kodu veya Windows istemcisi değiştirilmedi.
- **Bekliyor:** düzeltilmiş sudo launcher çıktısı, gerçek koruma/API kontrolü
  ve operatör ekran kabulü. Off-host hedef/altyapı, doğal yedek takvim kabulü,
  tam boot/rollback, VV06 leaf/cleanup/son GPO saha kabulü ve kullanıcı
  EAP-TLS pilotu dahil önceki açık işler korunuyor.

## B01 ayar kaydı ve gerçek RADIUS özeti — 18 Ekim 2026

- **🔴✓ Tamamlandı: panel düzeltmesi ve izole tarayıcı/API doğrulaması.**
  PR35 https://github.com/Asitavandas/kaname/pull/35, aday sürüm0.14.0-dev.7.
  Eski sabit “802.1X/RADIUS erişimi henüz uygulanmıyor” bildirimi kaldırıldı;
  ana sayfa mevcut Servisler API'sinden zaman bilgili RADIUS durumunu okur.
  Servis yetkisi olmayan hesap sorgulamaz; broker kesintisi paneli kilitlemez.
- Temel ayarlar mevcut AuthWire yapılandırmasına kaydeder; OS IP/DNS,
  switch/AP veya Windows ayarı uygulamaz. Taslak ifadeleri düzeltildi.
  Kayıt öncesi eski/yeni alan karşılaştırması ve mevcut ayara etki onayı var.
  Yalnız değişen alanlar, formun yüklendiği revision ile gönderilir.
  Arka plan okuması kirli formun revision'ını ilerletmez; çakışmada form korunur.
  Çift tıklama tek POST; kayıt sonrası okuma hatası veya bilinmeyen POST sonucu
  otomatik tekrar yazma üretmez, önce yeniden okuma gerekir.
- Mevcut RADIUS istemcileri bu formda salt okunur; düzenleme ayrı RADIUS
  istemcileri ekranındadır. Kablolu/kablosuz tür ve sealed secret korunur.
  Backend, AD/PKI/enrollment/policy/native RADIUS ve Windows istemcisi değişmedi.
- Gerçek Chromium fixture sekiz senaryosu geçti; servis eylemi0 ve korunan
  RADIUS secret hash'leri aynı. Genel490 test (25 ortam atlaması), yerel40
  admin/HTTP, native58 LDAP/installer/systemd ve41 Kerberos testleri başarılı.
  Windows görevi de başarılı. Normal/debug gerçek native EAP-TLS, policy/VLAN yanıtı ve runtime parse kapıları da geçti.
- **🔴✓ Tamamlandı: dağıtım paketi ve korumalı komut hazırlığı.**
  PR35, main'e397fa3d390e20e04bb33dd1803a795fb3ba402bd olarak alındı.
  Self-hosted141 test geçti;112 dosyanın manifesti, doğrudan Git blob'larıyla
  doğrulanan kaynakla aynı: d1aba96d059717843d6c3a7e0881047f2a37918cf533eb84386e05d99244bbae.
  Paket /home/kaname-runner/kaname-stage-397fa3d390e2.
  Korumalı launcher /home/segmentiq/authwire-panel-update-dev7-20261018.py;
  SHA2568ba63e511252750d221ca354db1cbcfb34735f1882c9e1489ad04e62c2ca1aa5.
  Aynı dosya docs/checkpoints/2026-10-18-panel-dev7.py içinde kayıtlı.
  Üç izole launcher sınır testi değişmiş server kodu/silme/sürüm, pinli helper
  ve eski/doğrulanmamış yedek reddini geçti. Launcher sunucuda hash/derleme
  doğrulandı; henüz çalıştırılmadı. Sudo parolası operatörce girilecek.
- Launcher kurulum öncesi yeni managed yedek ister; hash-only başlangıç
  snapshot'ını kalıcı özel dizine yazar. Sonra kritik unit/dosya/izinler,
  kararlı iş DB hash'leri, RADIUS/broker PID ve iki timer karşılaştırılır.
  Meşru directory_health/session/audit hareketleri iş durumu korumasına
  dahil edilmez; yedeklerinde saklanır. Yalnız panel yeniden başlar.
- **Bekliyor: canlı güncelleme ve operatör ekran kabulü.**
  Kurulu sürüm henüzdev.6; aday test başarısı canlı kurulum sayılmaz.
  B01'in kalan wizard/OS apply/tekrarlanabilir kurulum kapsamı açık kalır.
- **Yarım kalanlar korunuyor:** off-host kopya hedef/altyapı bekliyor;
  ilk doğal yedek takvim çalışması19 Ekim sonrası doğrulanacak; tam OS/runtime
  boot ve rollback kabulü açık. VV06 seçilen yenilenmiş EAP leaf, yerel12h
  eski sertifika/anahtar cleanup ve son GPO halinin uygulanması19 Ekim saha
  planında. Uzun süreli panel gözlemi ve kullanıcı EAP-TLS pilotu unutulmadı.
  G01–G07 ve B11 accounting/korelasyon/saklama ayrı açık işlerdir.

## Off-host hedefi yok; yerel yedek aktif, B01 ön incelemesi — 18 Ekim 2026, 15:59 İstanbul

- Operatör şu anda NAS, Windows paylaşımı veya ikinci Linux yedek hedefi
  olmadığını bildirdi. **Off-host ikinci kopya: hedef/altyapı bekliyor.**
  Hedef adresi varsayılmadı; yeni makine/paylaşım veya dış servis kurulmadı.
  Bu alt iş tamamlandı sayılmaz. Yerel günlük backup timer ve14 başarılı
  managed kopya saklama ayarı korunur; doğal ilk takvim çalışması hâlâ bekliyor.
- Diğer bağımsız uzaktan iş B01 kurulum/ayar uygulama akışıdır. Salt okunur
  kaynak ön incelemesinde mevcut panel üst bildiriminde “Ağda 802.1X / RADIUS
  erişimi henüz uygulanmıyor” metni sabit bulundu. Bu eski ifade çalışan
  RADIUS ve başarılı kablolu/kablosuz saha kanıtıyla güncel değildir.
  Overview/kurulum ekranındaki hazırlık/taslak ifadelerinin gerçek kayıt ve
  uygulama kapsamıyla birlikte incelenmesi gerekir. Henüz UI/kod değişikliği
  veya canlı dağıtım yapılmadı; B01 tamamlandı sayılmadı.
- Mevcut policy/VLAN, sertifikalar, RADIUS, görevler ve yedek zamanlayıcısına
  bu adımda müdahale edilmedi. G01–G07 sırası ve19 Ekim VV06 saha planı korunur.

## Planlı yedekleme canlı kurulum ve ilk müşteri restore kabulü — 18 Ekim 2026, 15:54 İstanbul

- **🔴✓ Tamamlandı: planlı özel yedekleme canlı kurulum/enable ve ilk yedek
  + izole veri restore kabulü.** Operatör BACKUP_TIMER_INSTALLED verified=true
  paylaştı. Timer enabled/active; Europe/Istanbul03:15, en fazla300sn jitter,
  keep_successful=14. Manuel yedekler değiştirilmedi; ilk temizlik0 arşiv.
- İlk managed arşiv:
  /var/backups/authwire/scheduled/authwire-scheduled-20261018T125415Z-f274d0e4a6f0.tar.gz
  SHA2564213808660eb6888f5f531915f4065716e2b71b5541c163c5e8028ec6d111c0d.
  1609 dosya,3 SQLite DB; arşiv byte/hash/metadata, SQLite bütünlüğü ve kararlı
  iş durumu doğrulandı. Servis durdurulmadı; süreçler korundu.
- Aynı SHA'ya bağlı initial_data_restore.data_restore_exercised=true:
  123 veri/ayar/kaynak/unit dosyası özel geçici dizine geri getirildi; sahip/
  izinler, iki kritik DB/FK ve iş kayıtları, CA/Issuer, üç korumalı sır, Issuer
  anahtar eşleşmesi/imza denemesi, web/RADIUS anahtarları, güncel CRL ve
  sertifika/enrollment kayıtları doğrulandı. Geçici kopyalar silindi; restored
  kod çalıştırılmadı, servis başlatılmadı, restore denetiminden ağ çağrısı yok.
  Günlük arşiv manifestindeki data_restore_exercised=false, ayrı ilk restore
  kanıtıyla çelişmez; full_appliance_boot_restore_tested=false kalır.
- Doğrudan salt okunur systemd doğrulaması: authwire-backup.timer
  active/waiting/enabled, Result=success. Oneshot authwire-backup.service
  inactive/dead/static, Result=success, ExecMainStatus=0; iş bitince normaldir.
  Panel PID174745, RADIUS PID1274 ve broker PID149955 active/running/enabled
  olarak korunmuş. Korunan iş durumu/dosyalar ve manuel yedekler aynı.
- **Bekliyor: ilk doğal takvim tetiklemesi.** systemd'nin gözlenen sonraki
  planı19 Ekim2026 03:18:54 +03; bu ileriye dönük plan, gerçekleşmiş yedek
  kanıtı değildir. Doğal çalışma sonrası son kayıt/sonuç ayrıca kontrol edilir.
- **Bekliyor: off-host şifreli ikinci kopya.** off_host_copy_configured=false.
  Ayrı NAS/Windows paylaşımı/Linux hedefi ve erişim bilgileri henüz seçilmedi.
  Hedef belirlenmeden aktarım kurulmuş veya tam B12 tamamlandı sayılmaz.
  Full boot/rollback ve VV06 leaf/cleanup/GPO saha kapıları açık; kullanıcı
  kimliği pilotu korunuyor. Yeni resmi rapor üretilmedi.

## Planlı özel yedekleme geliştirildi; canlı kurulum bekliyor — 18 Ekim 2026

- **🔴✓ Tamamlandı: B12 planlı yedekleme kodu, güvenlik sınırları ve izole
  kabul hazırlığı.** PR34 https://github.com/Asitavandas/kaname/pull/34.
  scheduled_backup.py + backup_install.py; ayrı /opt/authwire-backup prefix,
  authwire-backup.service ve authwire-backup.timer. Ürün dev.6 kalır;
  kaname/**, Windows imzalı istemcisi ve native RADIUS değiştirilmedi.
- Varsayılan günlük03:15 Europe/Istanbul, en fazla300sn jitter,30sn doğruluk,
  Persistent=yes. Son14 başarılı managed çalışma tutulur; bu14 takvim günü
  garantisi değildir. Manuel authwire-pause ve upgrade yedekleri korunur.
  Yeni root0700 /var/backups/authwire/scheduled; arşiv/manifest/durum/lock0600.
- SQLite online backup + integrity/FK; bütün arşiv byte/hash/type/uid/gid/mode
  kontrolü, önce/kopya/sonra iş durumu kararlılığı ve üç deneme. Session/audit/
  rate/challenge/cache/health kararlılık guard'ından dışlanır fakat yedeğe alınır.
  Diğer iş tabloları korunur; çoklu DB için tek global transaction iddiası yoktur.
  Güncelleme shared lock ve ayrı job lock, disk alanı ön koşulu vardır.
- Eski managed arşivler yalnız yeni doğrulanmış yedekten sonra ve kendi
  producer/manifest/isim/hash denetimleriyle temizlenir. Hata durumunda son
  başarılı kayıt korunur; last-run ve journal hata kategorisi/evresini taşır.
  Bilinmeyen/orphan dosyalar silinmez. Günlük arşiv bütünlüğü ile veri restore
  farklıdır; her günlük kayıtta data_restore_exercised=false olması normaldir.
- Yeni kurulum timer'ı açmadan önce gerçek ilk arşiv ve izole PKI/vault/veri
  restore provası, korunan dosya/iş durumu ve panel/RADIUS/broker PID kontrolü
  gerektirir. Hash-only install-before ve install-preservation özel kanıtları
  tutulur. Farklı mevcut kurulum üzerine yazılmaz; hata halinde yalnız bu
  yeni feature unit/kodları geri alınır, ürün servislerine restart/stop yok.
- İzole testler:20 worker/installer sınır testi +10 veri restore testi.
  Gerçek hosted systemd fixture; kısıtlı root worker, başka uid'ye ait özel
  verinin okunması, fixture PKI/vault restore, gerçek timer tetiklemesi,
  committed WAL satırının arşivde doğrulanması, hata kaydı ve ürün fixture
  PID koruması geçti. Son kaynak5f7307bf47a2b3acc3a1437b554d897c581fb72c için
  genel490 test başarılı (25 ortam atlaması); gerçek systemd ve Windows test
  discovery kapıları da başarılı (Windows'ta20 Linux testi doğru şekilde atlandı).
  PR34 main'e1e53860cc48a8e83195e6cdf96c42c44b287cc9b olarak birleştirildi.
- Canlı salt okunur preflight: /opt ve unit parent root755; broker boot-time
  lock tanımı beklenen içerikte, ortak lock root600; çakışan backup prefix/unit
  yok. Kaynak paket dosyaları özel kullanıcı staging dizinine hazırlandı.
  **Canlı kurulum, ilk müşteri arşiv/restore ve doğal takvim çalışması henüz
  tamamlandı değildir.** Root-only dosyalar ve unit kurulumu operatör sudo
  parolası gerektirir. Kurulum çıktısı alınmadan installed/aktif iddiası yok.
- Hazır paket /home/segmentiq/authwire-backup-package-20261018;
  manifest SHA2569c84b47a709af791963e25e057a80f6f08feb0094391cdfd5f26bd5afe8f62ec.
  Installer SHA256ed18f5c0c3e65aa6d2a6fe8311ddd1fa604b128c724e5854214e986118faf347.
  /home/segmentiq/authwire-backup-deploy-20261018.py
  SHA256ffe0ba6488aa4e16febd0095ee075ace2503e226a7cabd54f7365e630ec07fbb;
  aynı kaynak docs/checkpoints/2026-10-18-scheduled-backup.py içinde.
- İşletim belgesi SCHEDULED_BACKUPS.md. Off-host kopya/şifreli hedef bu yerel
  zamanlayıcıyla kurulmuş olmaz; hedef seçimi, doğal takvim kabulü, full boot/
  rollback, VV06 leaf/cleanup ve kullanıcı kimliği pilotu açık kalır.

## Uzaktan kalan işler ve yedek zamanlama envanteri — 18 Ekim 2026, 15:24 İstanbul

- Önceki “uzaktan kontrol turu tamamlandı” ifadesi18 Ekim kontrol listesini
  kapsar; bütün uzaktan geliştirilebilecek B01/B11/B12 işleri bitmiş değildir.
- **🔴✓ Tamamlandı: yedek zamanlama için salt okunur ön envanter.** Linux
  segmentiq üzerinde /var/backups/authwire root-owned0700. /etc/systemd/system
  ürün unit adları ve odaklı list-timers çıktısında yalnız CRL sync timer var;
  ürün adlarıyla eşleşen backup cron/timer tanımı incelenen yerlerde bulunmadı.
  /usr/lib/systemd/system içindeki dpkg-db-backup OS paket DB görevidir,
  AuthWire uygulama/CA/vault yedeği kabul edilmez.
- Bu sınırlı tarama harici backup ürününü, root kullanıcı crontab'ını veya başka
  isimli görevleri dışlamaz; otomatik/off-host yedek tamamlandı sayılmadı.
  İlk genel list-unit-files sorgusu15sn timeout oldu; odaklı ürün timer okuması
  başarılı. Servis değişikliği veya restart yapılmadı.
- Uzaktan devam edebilecek işler: planlı yedek ve saklama/güvenli aktarım
  akışının geliştirme/testi (ikinci hedef seçimi gerekir); tekrarlanabilir
  kurulum/kurtarma kabul hazırlığı (gerçek tam boot için izole VM gerekir);
  B01 eksik wizard/apply akışları; B11 kayıt saklama/dışa aktarım ve accounting
  hazırlığı. Sahadaki değişiklikler mevcut kimlik ayarları korunarak ayrı doğrulanır.
- Öncelik önerisi B12 düzenli yedekleme; ardından B01 kalan akışlar ve B11
  kayıt düzeni. G01–G07 kapsamı temel kabul kapılarından sonra kalır. VV06
  seçilen leaf/yerel cleanup ve yeni GPO istemci kabulü19 Ekim'e ayrılmıştır.
  Yeni otomatik yedek görevi kurulmadı, yedek silinmedi/aktarılmadı; yeni formal rapor yok.

## Panel gerçek tarayıcı kabulü tamamlandı — 18 Ekim 2026, 15:21 İstanbul

- **🔴✓ Tamamlandı: operatörün gerçek tarayıcı F5/giriş ve sayfa geçişi kabulü.**
  Ctrl+F5, yüklenmeyi bekleyerek beş F5, Sertifikalar/Ağlar-VLAN/Servisler
  geçişleri ve çıkış/yeniden giriş kontrolü istendi. Operatör “hiç bir hata
  almadım, tek giriş denemesiyle açıldı” sonucunu paylaştı. Bu testte hata veya
  tekrar parola denemesi bildirilmedi; kısa süreli saha kabulü kapanmıştır.
- Bu kısa gözlem geçmişteki bütün aralıklı kilitlenmelerin kalıcı bittiğini
  veya2saat idle/12saat absolute sürelerinin gerçek zamanlı uçtan uca
  tamamlandığını kanıtlamaz. Uzun süreli kullanıcı gözlemi açık kalır.
- **🔴✓ Tamamlandı: bu turdaki uzaktan kontrol listesi.** Sunucu günlük/API
  incelemesi + gerçek tarayıcı kısa kabulü; gerçek yedekte izole veri restore;
  VV06 sunucu24saat retirement/CRL; DC01 paket/ACL/güven/Startup kontrolü ve
  çift kayıt düzeltmesi; güncel işletim/kurtarma rehberleri kaydedildi.
  B01/B05/B06/B12 paketlerinin tamamının kapandığı iddia edilmez.
- Sıradaki planlı saha adımı19 Ekim Pazartesi VV06 üzerinde yenilenmiş leaf'in
  EAP'de seçildiğini, eski yerel sertifika/anahtar cleanup'ını ve düzeltilmiş
  GPO/Startup halinin yeniden uygulanmasını doğrulamaktır. Yeni kullanıcı
  kimliği pilotu daha sonra devam edecek. Zaman ileri alınmaz, eski anahtarlar
  elle silinmez. Bu kayıt bir hatırlatma/otomasyon kurulumu değildir.
- Bu kabul kaydında canlı servis, policy/VLAN, GPO veya sertifika değişikliği
  yapılmadı. Güncel durum ve yol haritası kaydedildi; yeni resmi rapor yok.

## DC01 çift Startup düzeltmesi ve tekrar denetimi kabul edildi — 18 Ekim 2026, 15:17 İstanbul

- **🔴✓ Tamamlandı: gereksiz AuthWire Startup kaydının kaldırılması ve gerçek
  DC01/SYSVOL tekrar denetimi.** Operatörün GPO_READONLY_AUDIT sonucunda
  InstallEntryCount=1, DuplicateInstallEntries=false, ExplicitAllSigned=true,
  BypassReferenced=false. Önceki iki çağrı bulgusu kapanmıştır.
- PackageChecksPassed=true;14 paket kontrolü tekrar başarılı. İki scriptin
  imzası Valid, CodeSigning EKU/yayıncı eşleşiyor; kaynak gövdeleri ve dört
  asset doğru. URL/domain/SPN/TLS pini, Root/Issuer zinciri ve ACL korunmuş.
  İmzalı script hash'leri önceki denetimle aynı:
  Install-AuthWire d1ae2163fa086184f73d3e053bf30a605a9098cedcdd7c0a02528c920b4780b9;
  AuthWire-Client 784c3234e05f0fe300fd5ed8bac12a23ee90b5a98d392f01159cf08dd3c323e2.
- GPO AllSettingsEnabled, ApplyTrustees yalnız AuthWire-Pilot-Computers.
  GpoChanged=false, WindowsClientChanged=false ve TrustStoreChanged=false
  denetim aracının müdahale etmediğini gösterir; önceki manuel Startup
  düzeltmesinin hiç yapılmadığı anlamına gelmez.
- ClientApplicationAccepted=false: yeni GPO halinin istemci yeniden başlatma/
  uygulama kabulü henüz bu sonuçla kanıtlanmadı. Mevcut imzalı paket ve sertifika/
  RADIUS ayarları değiştirilmedi; tüm B05 dağıtım/rollout kapsamı kapanmaz.
  Backup-GPO komutu daha önce verildi; yedek ID/yolu çıktısı paylaşılmadığından
  bu denetim ayrıca bir GPO yedek kanıtı olarak kullanılmaz.
- Uzak çalışma sırasındaki sunucu/API kontrolü, gerçek yedekte izole veri
  restore alt işi ve DC/SYSVOL paket/Startup denetimi tamamlandı. Rehberler
  kaydedilmiş durumda. Gerçek tarayıcı F5/giriş gözlemi, VV06 yeni leaf/yerel
  cleanup saha kabulü ve tam OS/runtime boot/rollback kapıları açıktır.
  Kullanıcı kimliği pilotu sonraki plan içinde korunuyor. Yeni resmi rapor yok.

## Çift Startup kaydı doğrulandı; GPMC düzeltmesi hazır — 18 Ekim 2026, 15:06 İstanbul

- Operatör INI bölüm çıktısında iki kayıt da aynı UNC Install-AuthWire.ps1
  kurucusunu -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File ile çağırıyor.
  scripts.ini/Startup/0CmdLine=powershell.exe doğru klasik Scripts çağrısıdır.
  psscripts.ini/Startup/0CmdLine=C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe;
  PowerShell Scripts sekmesinde betik yerine yürütülebilir dosya kaydedilmiş.
- Somut düzeltme: önce Backup-GPO ile AuthWire-Pilot-Trust yedeği, sonra GPMC
  Computer Configuration/Policies/Windows Settings/Scripts/Startup içindeki
  yalnız PowerShell Scripts kaydını kaldırma; klasik Scripts kaydı korunacak.
  INI/GPT/AD sürümü elle düzenlenmez; GPMC kaydı ve sürümü birlikte yönetir.
- Düzeltme ve tekrar denetim henüz operatör çıktısını bekliyor. Beklenen
  InstallEntryCount=1, DuplicateInstallEntries=false, ExplicitAllSigned=true,
  BypassReferenced=false; paket kontrolleri başarılı kalmalı. GPO yedeği veya
  düzeltme uygulanmış sayılmadı. Mevcut paket/sertifika/RADIUS değişikliği yok.

## DC01 gerçek SYSVOL paket denetimi; çift Startup bulgusu — 18 Ekim 2026, 15:04 İstanbul

- **🔴✓ Tamamlandı: gerçek DC01/SYSVOL paket imza, kaynak, asset, güven ve ACL
  denetimi.** GPO AuthWire-Pilot-Trust, GUID e5a9ab39-3709-49cb-837a-0208d2eb3b12,
  AllSettingsEnabled; ApplyTrustees yalnız AuthWire-Pilot-Computers.
  PackageChecksPassed=true;14 paket kontrolünün tamamı başarılı.
- İki script gerçek Authenticode Valid, CodeSigning EKU ve aynı yayıncı;
  yayıncı thumbprint6E74B513F766E01730719684A41B2664380CA68A.
  İmzalı Install-AuthWire SHA256d1ae2163fa086184f73d3e053bf30a605a9098cedcdd7c0a02528c920b4780b9;
  AuthWire-Client SHA256784c3234e05f0fe300fd5ed8bac12a23ee90b5a98d392f01159cf08dd3c323e2.
  Normalize edilmiş gövdeler güncel kaynakla, dört asset imzalı kurucuyla eşleşiyor.
  URL/domain/SPN/TLS pini, Root/Issuer zinciri ve geniş yazma izni kontrolleri geçti.
- **Açık bulgu: Startup InstallEntryCount=2, DuplicateInstallEntries=true.**
  Her kayıtta açık AllSigned var, Bypass yok. Tam CmdLine/Parameters ve hangi
  INI/indekste oldukları görülmeden kayıt silinmeyecek. Gerçek çift çağrı
  doğrulanırsa GPO yedeğiyle yalnız gereksiz kayıt uzlaştırılacak; paket veya
  mevcut sertifikalar değiştirilmez. B05 genel GPO/Startup kabulü henüz kapanmaz.
- Denetimde WindowsClientChanged/GpoChanged/TrustStoreChanged=false.
  ClientApplicationAccepted=false; bu sonuç yeni istemci saha çalıştırma kanıtı değildir.

## DC01 paket denetimi ön kontrolü — 18 Ekim 2026, 14:56 İstanbul

- **🔴✓ Tamamlandı: DC01 denetim ön kontrolü.** GPO AllSettingsEnabled,
  mevcut Install-AuthWire imzası Valid; aynı yayıncı için yerel private key
  erişilebilir. Etkin yürütme politikası RemoteSigned. Trust/GPO/SYSVOL
  değişikliği yok. Asıl paket hash/asset/ACL/Startup denetimi henüz bekliyor.
- Denetim aracı kaydedilmiş repo kaynağıyla aynı;
  SHA256920efeb421c845b90a2aa278c1d1d67f0c33c54bf0c1e9d3a65f08b7561a2e9b.
  Yalnız ayrı indirilen tanılama kopyası mevcut paket yayıncısıyla imzalanacak.

## Gerçek yedek veri restore ve VV06 sunucu retirement kabulü — 18 Ekim 2026, 14:48 İstanbul

- **🔴✓ Tamamlandı: canlı kimlikli panel API okuma kabulü.** Operatörün
  LIVE_PANEL_READ_CHECK çıktısında session/state/certificates/network/services
  uçlarında toplam15 okuma200 döndü. Medyanlar1.6–8.5ms; en yüksek20.9ms.
  Bu ölçüm loopback sunucu okumalarıdır; uzaktan tarayıcı/F5 kabulü değildir.
- **🔴✓ Tamamlandı: VV06 önceki sertifikasının sunucu tarafı planlı retirement'ı.**
  Önceki6fc12360e627e5b92b0d60ab103def6cb40fe624 seri superseded ile iptal;
  yeni5899e122009871b0d5536890bee81e4f0499e605 iptal edilmemiş.
  Planlı süre86400sn, son tarih16 Ekim13:26:43UTC, gerçek iptal13:27:11UTC:
  süre dolduktan28sn sonra. Önceki seri imzalı/geçerli runtime CRL'de,
  yeni seri CRL dışında; DB ve runtime CRL aynı. Bu B06 sunucu alt işini kapatır.
  Windows yerel12saat cleanup ve EAP'nin seçtiği yeni leaf hâlâ açık.
- **🔴✓ Tamamlandı: yeni gerçek sunucu yedeğinde izole veri geri yükleme provası.**
  /var/backups/authwire/authwire-pause-20261018T114709Z.tar.gz,
  SHA256ae720fe219803a917344a283460a4bbd2179f26dc1ae37df463039e7765552eb.
  Arşiv okuma, SQLite bütünlüğü ve kararlı canlı capture doğrulandı.
  Ayrı özel dizine123 dosya geri getirildi; byte/hash ve sahip/izinler geçti.
  İki DB/FK, config/policy, yöneticiler, CA/Issuer, üç korumalı sırın çözülmesi,
  Issuer anahtar eşleşmesi ve sertifika/CRL olmayan imza denemesi, web/RADIUS
  anahtar eşleşmeleri, güncel CRL ve enrollment/sertifika kayıtları doğrulandı.
- İzole kopyalar silindi; geri gelen kod çalıştırılmadı, servis başlatılmadı,
  restore denetiminden ağ çağrısı yapılmadı. Dört runtime linki açılmadı.
  On iki korunan dosya, üç canlı servis PID'si ve altı kontrol hash'i aynı.
  Canlı policy/VLAN/sertifika/Windows istemcisi değiştirilmedi.
- Kanıt dosyası aynı yedeğin .restore-check.json uzantılı özel yan kaydıdır.
  B12'nin yalnız **sunucu verisi geri yükleme** alt işi tamamlandı. Yedek
  çıktısındaki restore_tested=false ile full_appliance_boot_restore_tested=false,
  tam OS/runtime boot/rollback testinin yapılmadığını belirtir; ayrı
  data_restore_exercised=true ile çelişmez. B12'nin tamamı kapanmaz.
- Sıradaki uzaktan iş gerçek DC/SYSVOL paketinin salt okunur denetimidir;
  araç/fixture hazır, gerçek DC sonucu bekleniyor. Tarayıcı gözlemi, tam boot/
  rollback/temiz appliance ve19 Ekim VV06 saha kapıları açık kalır.
  Kullanıcı kimliği pilotu yol haritasında tutuluyor. Yeni resmi rapor üretilmedi.

## Uzaktan çalışma hazırlıkları ve sunucu gözlemi — 18 Ekim 2026

- **🔴✓ Tamamlandı: canlı sunucu günlükleri, süreçler ve kurulu kaynak kontrolü.**
  18 Ekim11:13UTC gözleminde panel dev.6/HTTPS200; panel PID174745,
  RADIUS PID1274 ve broker PID149955 çalışıyor. CRL timer etkin/bekliyor;
  oneshot son sonucu başarılı. TLS pini ve Windows istemci kaynağı korunmuş.
  Bu çalışma canlı servis restart, policy/VLAN veya sertifika değişikliği yapmadı.
- 15 Ekim20:05:31UTC sonrası günlüklerde tek PANEL_DATABASE_ERROR bulundu:
  15 Ekim20:08:12.882569UTC, area=session, method=GET, sqlite_code=5,
  transient=true. Sonraki gözlem aralığında aynı kayıt tekrarlamadı. Bu bulgu
  kullanıcı tarayıcısında hatanın görünmediğini veya geçmiş bütün kitlenmelerin
  nedeninin kanıtlandığını göstermez. F5/login kullanıcı gözlemi açık kalır.
- **🔴✓ Tamamlandı: izole veri geri yükleme doğrulayıcısının geliştirilmesi ve
  regresyon testleri.** Şifreli gerçek fixture verisinde DB/FK, CA/Issuer/vault,
  TLS/RADIUS anahtar eşleşmeleri, CRL ve sahip/izin/hash denetimleri geçti.
  Hatalı arşiv pini, anahtar, yol/link ve güvensiz çalışma alanı reddedildi.
  Ubuntu genel test paketi470 testte başarılı (25 ortam atlaması); restore
  odaklı10 test başarılı. Canlı dizine geri yükleme veya restored code execution yok.
- **🔴✓ Tamamlandı: salt okunur DC/SYSVOL paket denetim aracı ve Windows
  fixture kabulü.** Gerçek Authenticode, aynı yayıncı/EKU, imzalı içerik/asset
  pinleri, TLS/Root/Issuer zinciri, ACL ve Startup kayıtları test edildi.
  Değiştirilmiş paket, geniş yazma ve çift/Bypass kayıtları yakalandı.
  Gerçek DC paketi henüz çalıştırılmadı; GPO/istemci saha kabulü kapanmaz.
- **🔴✓ Tamamlandı: dev.6 yönetim/işletim/kurtarma rehberleri ve güncel yol
  haritası.** ADMINISTRATION.md, OPERATIONS_0_14_0.md ve ROADMAP.md güncellendi.
  BULK_ENROLLMENT belgesindeki network-event trigger iddiası düzeltildi;
  gerçek görev Startup+09:00+21:00 ve ağ/AC koşulları kullanıyor.
- Kaynak değişiklikleri PR33: https://github.com/Asitavandas/kaname/pull/33.
  Bunlar araç/test/belge değişiklikleridir; uygulama sürümü dev.6 kalır.
  kaname/**, imzalı Windows istemcisi, native modül ve canlı kimlik ayarları değişmedi.
- **Bekliyor: gerçek sunucu yedeğiyle veri geri yükleme provası ve canlı
  kimlikli API okumaları.** Root-only dosyalar nedeniyle operatör sudo çıktısı
  gerekiyor. Hazır çalıştırıcı yeni özel yedek alır, yalnız izole geçici kopyada
  doğrular, özel hash baseline/sonuç kaydı bırakır ve canlı PID/korunan durumu
  karşılaştırır. Yalnız hazırlık/test tamamlandı; gerçek prova yapılmış sayılmaz.
  Tam OS/runtime boot, temiz appliance import/rollback ve off-host yedek ayrı açıktır.
- Sunucu çalıştırıcısı:
  /home/segmentiq/authwire-remote-check-20261018.py,
  SHA256b467c1227d071993f6be7cc92c6c20f97862746bd0ac552f44a897fe8deee683.
  Sabitlenen veri doğrulayıcısı:
  /home/segmentiq/authwire-offline-restore-check-20261018.py,
  SHA256c9a1cba667eee28e5e6a3579ced0b457b17e1e7193f254b74e6638a87e48f610.
  Kaynak checkpoint docs/checkpoints/2026-10-18-remote-readiness.py içinde.
- VV06 predecessor için sunucu retirement/registry/imzalı runtime CRL kanıtı
  aynı salt okunur kontrolde ayrıca alınacak. Windows yerel12saat cleanup ve
  EAP'nin seçtiği yeni leaf bundan çıkarılmaz; 19 Ekim saha kabulü açık.
  Kullanıcı kimliği pilotu yol haritasında korunuyor. Yeni resmi rapor istenmedi.

## Panel dev6 preservation reconciled and technical deployment accepted — 15 October2026, 23:05 Istanbul

- **Completed: dev6 deployment and technical preservation/API acceptance.**
  Operator's read-only verifier emitted PANEL_VERIFICATION_FINISHED verified=true.
  All104 installed source files match the tested release manifest.
- Against the pinned full checkpoint immediately before source update, all12
  critical files match (primary/broker units, native module, web/RADIUS keys/
  certificates, secret-store key and both signed Windows scripts); all12 state
  comparison categories pass (config/policy, protected secrets, CA material,
  certificate registry, signer/profiles/bindings/key registry, administrators/
  profiles and runtime configuration/health shape).
- RADIUS PID1274 and broker PID149955 preserved. Verification restarted no
  service and changed no configuration or certificate. Backup integrity and
  all four SQLite quick checks pass.
- The sole reported runtime difference is directory_health.checked_at and
  last_success; timestamps_only=true. These are normal scheduler observations,
  not policy/AD connection or authentication changes. This reconciles the
  overly broad outer protection alarm against the pinned pre-update backup.
  Original outer before dictionary was not persisted; its exact earlier hash
  is not claimed to have been reconstructed.
- All15 post-update authenticated loopback API reads returned200. Maxima:
  session4.3ms, state10.2ms, certificates8.3ms, network5.2ms, services38.4ms.
  These timings cover local server reads, not a claim about remote VPN/browser
  performance or long-term disappearance of the historical storage error.
- Panel changes installed: initial credential form hidden until cookie check,
  limited transient-busy GET recovery with no write replay, throttled session
  writes, fixed-label storage diagnostics. New logins use idle2h and absolute
 12h; existing absolute deadlines retained. Secure cookie, CSRF and account/
  permission revocation remain enforced.
- **Pending: operator F5/login observation and monitoring for recurrence of
  historical STORE_UNAVAILABLE.** Its exact historical SQLite cause is still
  not retroactively proved. Do not label this long-term observation complete
  from server-local API checks alone.
- VV06 selected-renewed-leaf and delayed cleanup field checks remain deferred
  until Monday morning19 October2026; user authentication stays on roadmap.
  No new formal report requested.

## Panel dev6 installed; outer preservation difference needs read-only verification — 15 October2026, 22:57 Istanbul

- Operator ran the prepared dev6 updater. Both SQLite quick checks pass;
  journal modes remain delete. All18 pre-update loopback authenticated reads
  succeeded (session/state/certificates/device status/network/services).
- Fresh private checkpoint:
  /var/backups/authwire/authwire-pause-20261015T195441Z.tar.gz,
  SHA256e40a7739e650f1dd7c4cfac001a6b903931fc58b415d2a3e53a7ea042db7bb47.
  Archive, DB integrity, stable live capture and RADIUS PID preservation pass.
- Installed updater reported version0.14.0-dev.6, HTTPS verified, configuration/
  administrators/Windows client preserved, RADIUS process preserved, no RADIUS
  start or unit migration. Outer launcher then failed at preservation_after
  with ValueError; it did not identify the compared field. Do not mark the
  full deployment verified or simply rerun the update.
- Direct post-failure check: dev6 health200 with the same pinned public TLS
  certificate and signed client hash; panel active PID174745, RADIUS PID1274,
  broker PID149955, CRL timer active/waiting. No service restart by assistant.
- Control digest includes all runtime_settings, including directory_health
  fields automatically updated by the AD scheduler. These operational records
  can differ over the backup/update window. This is a plausible false-positive
  mechanism, not yet the confirmed field cause. The original before dictionary
  was not persisted and cannot be retroactively reconstructed exactly.
- Prepared a strictly read-only reconciliation against the exact pinned full
  checkpoint immediately before source replacement. It verifies archive hash,
  critical file hashes/PIDs, required config/policy/admin/CA/key/certificate/
  profile/binding tables, separate health field differences, all104 tested
  source files, SQLite integrity and authenticated panel reads. No source,
  certificate, config, session or service mutation; only private temporary
  snapshot copies are created/deleted.
- Seven isolated tests pass: stable snapshot acceptance; metadata timestamps
  separated; policy/network/admin/CA changes rejected; missing table rejected;
  checkpoint symlink rejected.
- Verifier: /home/segmentiq/authwire-panel-dev6-verify-20261015.py,
  SHA25626b8a72fe79325cc550cc8003b00c83fb6b888c81644d14d7e7703000b7b1cfe.
  Await operator sudo output before closing preservation acceptance. VV06
  tests remain deferred to Monday morning19 October; no new report requested.

## Panel reload/session follow-up — 15 October 2026, evening

- Operator postpones VV06 computer-certificate field tests until Monday
  morning19 October2026; selected renewed leaf and delayed cleanup remain
  pending. The user-authentication pilot is retained.
- Opened both screenshots: image(20261015-193101).png shows Certificates with
  STORE_UNAVAILABLE; image(20261015-193338).png shows credentials during F5.
  Current source displays the credential form before async cookie validation.
  It also writes admin_sessions.last_seen on every authenticated request.
- Existing error handling discards SQLite error codes and messages. A read-only
  journal signal scan found no database-specific diagnostic; the exact
  historical storage error cannot be established from this screenshot.
  TLS certificate-unknown records exist but do not explain a JSON storage
  response from an already loaded panel. No TLS trust settings changed.
- PR32 https://github.com/Asitavandas/kaname/pull/32, tested source head
  e21e08ec4b54b3647e600899c665bc4aed4bb1da, version0.14.0-dev.6:
  hide credentials in initial HTML until cookie validation finishes; show
  neutral loading/recovery, actual401 still requires login.
- New logins: absolute12h and idle2h; preserve existing absolute expiry fields.
  Validate account enabled/version/permissions and session expiry every time,
  persist activity at most once per minute. Background panel reads count as
  activity as before; idle cutoff has up to60s touch granularity.
- SQLite busy/locked responses now distinct STORE_BUSY; fixed area/method/
  numeric-code-only diagnostics exclude SQL, query values, exception text and
  secrets. Only GET503/STORE_BUSY receives at most two retries (200/600ms)
  within the original deadline. No password/POST/write/service-action replay,
  no retry of general storage/network failures. No journal-mode migration.
- Local and hosted foundation:460 tests,25 environment skips. Administrator/
  Services focused suite43 pass, including an actual reserved SQLite writer
  during an active session read. Browser11 session fault cases pass, including
  delayed F5, bounded busy GETs and exactly one busy POST; full Services UI
  regression also passes. Windows enrollment, Kerberos and hardened installer
  gates pass. Native normal/debug EAP-TLS/VLAN/CRL and runtime parsing gates\n  also passed before merge.
- Application changes limited to panel admin.py/server.py, static loading/
  API behavior and version metadata. Signed Windows client, PKI, enrollment,
  live AD authorization, policy/VLAN and native RADIUS code unchanged.
- Current production remains dev.5 until operator executes the prepared guarded
  update. Require fresh private backup including broker/history/unit, read-only
  DB integrity/API checks and exact protected files/state + RADIUS/broker PID
  preservation. Do not mark deployment or live user acceptance completed yet.

- PR32 merged as40d69fff4c849d207d368e42bea64401dd552156.
  Linux source104 files exactly match the tested Git tree; expected manifest
  0679cb615cfc05179363a28807c208f0235efdb14d08b616d0517e2b862accee,
  stage /home/kaname-runner/kaname-stage-40d69fff4c84.
  Guarded launcher /home/segmentiq/authwire-panel-update-dev6-20261015.py,
  SHA25627ebd35feadd8d8b0522819d7f12889d734c06b5d0eb91f70034b18c5b450e45.
  Prepared checkpoint is retained alongside this record. Launcher additionally
  backs up service broker code/history/unit using the pinned backup helper.
- Direct pre-installation service read: panel PID149888, RADIUS PID1274,
  broker PID149955, all active. Installation and post-update operator reload/
  intermittent-error observation remain pending.

## Services screen and controlled CRL action accepted — 15 October 2026, 18:48 Istanbul

- **Completed: first-phase Services feature implementation, deployment and
  operator field acceptance.** Uploaded image(20261015-154802).png was opened
  and visually inspected; screen last check18:44:39.
- Screen shows RADIUS and AuthWire panel Running, boot enabled; CRL timer
  Running/boot enabled. CRL sync shows waiting with last execution successful,
  which is normal for this oneshot.
- Operation history explicitly shows: CRL synchronization / Sync now /
  Successful / admin / 15.10.2026 18:42:21. This closes the requested controlled
  UI action/history verification. It does not claim a customer RADIUS restart
  test or every privileged-action/error path has been exercised on customer
  equipment; those were covered on disposable CI fixtures.
- RADIUS uptime24h44m versus panel9m is consistent with prior PID preservation
  evidence. No new RADIUS stop/restart requested for this acceptance.
- Return to the existing roadmap: VV06 B06 proof of the selected renewed leaf
  and later normal predecessor cleanup. Keep valid overlapping certificate/
  key material until normal cleanup eligibility; do not delete manually or
  advance time. User-authentication pilot remains explicitly scheduled after
  computer-certificate lifecycle acceptance. Existing work evidence preserved.
- No new formal report generated; the ongoing work record is updated.

## Services installed and live status verified — 15 October 2026, 18:36 Istanbul

- **Completed: deployment of Services version0.14.0-dev.5.** Operator's corrected
  guarded launcher emitted SERVICES_SOURCE_UPDATED, SERVICES_CONTROL_INSTALLED
  and SERVICES_DEPLOY_FINISHED verified=true.
- Fresh private backup:
  /var/backups/authwire/authwire-pause-20261015T153357Z.tar.gz,
  SHA256 8a665495f55b63742c3d5f6abdf73424e05141597f00289067f6951b54243284.
  Archive read, SQLite integrity and stable live state verified. Restore untested.
- Protected authentication source, primary service units, native module, keys/
  certificates and signed Windows client preserved; configuration and
  administrator preservation passed. RADIUS process remains PID1274.
- Broker installed/enabled/active; query as actual kaname-lab identity succeeded
  for all four controlled/observed units. Broker source SHA256
  dd84bd794a6a9ce8bdfd348868c9bb6b91573d643831ae26bf2522c3936c65f4.
  Deployment performed no RADIUS control action.
- Direct read confirms panel active/enabled PID149888, RADIUS active/enabled
  PID1274, CRL timer active/enabled/waiting, broker active/enabled PID149955.
  CRL sync oneshot inactive/dead with Result=success is expected idle state.
- **Pending: operator Services screen acceptance and a controlled CRL sync
  action through the panel, with audit history/result verified.** Do not mark
  that UI/control field test passed from installation output alone. Panel
  itself is read-only in this first service-control phase. No RADIUS restart
  field acceptance has been performed or is required merely to inspect status.
- After Services acceptance, resume B06 selected renewed VV06 leaf and delayed
  cleanup checks, then the planned user-authentication pilot. Preserve all
  existing wired/wireless, EAP-TLS, VLAN and CRL acceptance evidence.

## Services deployment backup completed; permission boundary repaired — 15 October 2026, 18:29–18:40 Istanbul

- Operator executed the guarded deployment. Full private checkpoint was created:
  /var/backups/authwire/authwire-pause-20261015T152747Z.tar.gz,
  SHA256 549c1227d4f6abcb76d5ad10fb6e9e5665ad0a786b6436726ca403cc4fcf4a50.
  Archive read, SQLite integrity, stable live state and RADIUS PID preservation
  were verified. Restore has not been tested.
- Source update then raised CalledProcessError; original launcher suppressed
  subprocess detail. Direct post-failure check: installed source remains dev.4,
  panel active/enabled PID1238; RADIUS active/enabled PID1274; CRL timer active/
  enabled. Broker absent/inactive. No successful production installation claimed.
- Launcher defect found: backup main sets process umask0077 and returns without
  restoring it. The in-process updater's mkdir(mode0755) therefore produces
  package directories0700, blocking its kaname-lab dependency-import check.
  The permission mechanism was reproduced using temporary fixture directories;
  exact remote subprocess traceback was not captured.
- Corrected launcher isolates backup0077 and update/install0022 in finally-
  restoring context managers. No application or authentication source change,
  staged source/manifest unchanged. Four focused regression tests passed for
  private backup0600, public source0755 despite restrictive caller, error-path
  restoration, and actual launcher call-site coverage. These tests do not claim
  a real low-privilege subprocess import on the restricted local test host.
- Corrected launcher prepared at
  /home/segmentiq/authwire-services-deploy-fix-20261015.py,
  SHA256 02a048d49c1ed95f6540f5a30a7ceec3b508658447346ba00e157dd0fe90a056.
  It takes a fresh backup again, preserves existing pilot RADIUS, and includes
  safe phase/program/exit-code metadata if another subprocess fails.
- Installation and operator Services UI acceptance remain pending. Return after
  acceptance to VV06 B06 selected-new-leaf/delayed cleanup, then the separately
  planned user-authentication pilot. No new formal report requested.

## Services feature merged and installation prepared — 15 October 2026

- PR31 https://github.com/Asitavandas/kaname/pull/31 merged as
  3eaa628ae5ea348ee2c1f41ac4cfeb3e4230b454; tested PR head
  47bb8faa2474feab7182fbf553846239b1ee25b5. Source version0.14.0-dev.5.
  All required PR gates passed: 456 foundation tests (25 environment skips),
  browser including Services and panel-session regressions, real hardened
  broker/systemd start-stop-restart/UDP verification, Windows enrollment,
  Kerberos, and native normal/debug EAP-TLS/VLAN/CRL checks.
- Root broker remains fixed to four local AuthWire units; panel is read-only,
  RADIUS has start/stop/restart, CRL has sync and timer start/stop. Separate
  system.services read/write permission, Origin/CSRF/session/confirmation,
  durable bounded operation history, recent-UUID deduplication and upgrade
  locks are implemented. No arbitrary unit, shell or panel self-stop.
- Main Linux preparation38758704460 succeeded. Self-hosted stage ran141
  filesystem tests (four skips), then prepared104 source files with digest
  dcf0957a545bf526c999cf849033868e9e32271a080d5e00004261d9b32ce3c4.
  Local exact PR tree and manifest match. Actual private runner location:
  /home/kaname-runner/kaname-stage-3eaa628ae5ea.
- Prepared guarded deployment launcher:
  /home/segmentiq/authwire-services-deploy-20261015.py,
  SHA256 5531aca52ff42c60b5f04898a6414b6d1030c29c57810e97f6026f2b3cb91c47.
  It verifies staged source and unchanged authentication code, takes the
  separately pinned current-data backup before updating, invokes the trusted
  existing updater, installs the guarded broker, and compares protected files
  and the RADIUS PID. No customer service action is automatically tested.
- **Installation and field acceptance are pending operator sudo execution.**
  Desktop Commander still runs as segmentiq and cannot supply the sudo
  password. No customer source/service change was performed by the assistant.
  Last direct customer check: panel PID1238, RADIUS PID1274, timer active/enabled;
  signed Windows client hash remains86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15.
  The protected runner stage cannot be read by segmentiq; CI verified its
  manifest and the root launcher re-verifies every file before applying it.
- Expect PAUSE_BACKUP_CREATED, SERVICES_SOURCE_UPDATED,
  SERVICES_CONTROL_INSTALLED and SERVICES_DEPLOY_FINISHED verified=true.
  Only then mark current-data backup/deployment done. Existing report copies
  remain the dated pre-feature revision; no replacement report requested.
- After installation: inspect System > Services with one Ctrl+F5, confirm four
  live rows and privileges, then capture the controlled RADIUS action/reconnect
  acceptance separately. B07 feature source is complete; installation/field
  acceptance remain open. B11 accounting is unchanged.
- Return immediately afterward to the prior B06 checkpoint: selected renewed
  VV06 certificate and natural delayed12h local/24h server cleanup. Preserve
  overlap; do not delete/revoke the valid old certificate to force success.
  User EAP-TLS pilot remains the next explicit roadmap item.

## Services screen work started — 15 October 2026, 17:37

- Operator authorized implementation today and remote continuation; afterward
  return to VV06 certificate lifecycle and the existing user-authentication plan.
- Scope: B07 core service operations, related B01 access/UI, B11 operation audit
  and B12 installation. Separate Unix broker preserves web hardening and fixed
  RADIUS/CRL controls; panel is read-only in this stage.
- Isolated source under development at 0.14.0-dev.5. Initial foundation run:
  455 tests, 25 environment skips; service-specific boundary tests passed.
  Real disposable systemd/browser and installation acceptance still pending.
- Customer remains on 0.14.0-dev.4; no deployment/service mutation performed.
  Windows signed client hash remains
  86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15.
  New pause backup still has no operator success output.

## Current dated report revision — 15 October 2026

- Operator-requested updated report delivered as a separate dated revision;
  9 October baseline retained. All B01-B12, G01-G07 and P01-P10 identifiers
  preserved; changed rows marked with red checks; partial/open boundaries
  retained. Nineteen pages rendered and visually checked.
- DOCX: AuthWire_Durum_ve_Tamamlama_Raporu_2026-10-15.docx,
  Library identity libfile_251ed9e8b320819197e8a2bdd0342806.
- PDF: AuthWire_Durum_ve_Tamamlama_Raporu_2026-10-15.pdf,
  Library identity libfile_cb8de0841d488191a14f95e3fda1bbc5.
- Both report saves and local identity metadata succeeded. The document records
  checkpoint63d784ccc762 and includes the guarded sudo backup command.
  New server data backup remains pending operator password/execution; no
  PAUSE_BACKUP_CREATED output has been received. Do not mark B12 closed.

## Pause checkpoint and report revision — 15 October 2026, 16:52

- Operator requested a pause, saved final state and a current report marking
  changes since 9 October with red check marks. No new field test is required
  before this pause.
- Direct Linux read at16:53 confirms installed VERSION=0.14.0-dev.4,
  kaname-lab.service active/enabled PID1238 Result=success,
  authwire-radius.service active/enabled PID1274 Result=success, and
  authwire-radius-crl-sync.timer active/enabled. os.sync completed successfully.
  No service stop/restart, configuration, certificate, CA or policy mutation.
- Current completed checkpoint includes controlled normal VV06 renewal/new key,
  confirmed installed state, post-renewal wired Authentication succeeded,
  10.10.110.4/24 gateway10.10.110.1 and TCP8765 reachability to10.35.50.246.
  Preserve old/new overlap. Exact EAP-selected renewed leaf, local12h cleanup
  and separate server retirement (up to24h) remain open.
- Source/work record are in Git and previous guarded upgrade backups remain
  the previously confirmed backups. Disk sync is not a new full backup.
  The connected segmentiq user cannot read root-protected state/config; sudo
  requires an interactive password. A new current data backup has NOT been
  executed or verified.
- Prepared /home/segmentiq/authwire-pause-backup-20261015.py,
  SHA256 f3defafe3faed08d5cae48b982f74217c8a24a15107c25ced267a26a84958f43.
  It uses read-only SQLite online backup/integrity checks, private root-only
  output under /var/backups/authwire, verifies unchanged live state during
  capture and archive readability; includes configuration/state, deployed
  source/venv/native RADIUS and effective local units/drop-ins. It stops no
  services and prints no protected payloads. Syntax and isolated SQLite/
  inventory smoke checks passed; operator sudo execution is still needed.
  It is a local checkpoint, not an independently tested restore or off-host
  disaster-recovery copy; B12 restore acceptance remains open.
- Next session: read current services/CRL and selected installed metadata;
  observe normal task execution after cleanup eligibility, verify intended old
  certificate/key cleanup and successful access with the renewed leaf. Do not
  repeat completed reboot/renewal tests or manually delete/revoke the valid old
  certificate merely to force a result.
- User authentication remains explicitly planned: machine EAP-TLS is the
  accepted pilot. User EAP-TLS deployment, live user/group authorization and
  pre/post-login behavior require their own scoped pilot; TEAP chaining has
  no implementation acceptance. Panel browser feedback, wireless negatives,
  daily/offline lifecycle, accounting and restore/rollback remain separate.

## Completed field results

- **Completed: VV06 controlled normal renewal and key rotation.** Supported
  per-device panel renewal completed via the existing SYSTEM client with a
  distinct certificate/public key, private key available and installation state
  confirmed. Post-renewal wired authentication, VLAN 110 DHCP and AuthWire HTTPS
  reachability also passed. Exact EAP-selected leaf and timed cleanup remain open.
- **Completed: VV06 automatic startup authentication and certificate-task check.**
  On 15 October boot16:05:50, existing task started16:06:02 without manual launch,
  completed Ready/0, RanAfterBoot=True and retry.json absent; wired authentication
  succeeded. Corrected-network endpoint reboot acceptance is closed.
- **Completed: VV06 controlled post-revocation certificate recovery, wired access
  and existing-certificate task recovery.** New certificate/private key verified;
  wired EAP-TLS/VLAN 110 restored. Operator corrected missing VLAN carriage on
  the connected switch port; FQDN TCP/DC discovery then passed and normal task
  completed Ready/0 with retry.json removed. Automatic post-fix reboot/task
  acceptance subsequently passed at16:15 (see dedicated record).
- **Completed: wired positive EAP-TLS pilot and dynamic policy VLAN assignment.**
  Windows computer 2GL13ZU, Realtek Ethernet, HPE Instant On 1930 VV-SW,
  source 10.35.50.253, port 6. Windows reported Authentication succeeded.
  Changing the AuthWire policy VLAN resulted in an address from the new VLAN;
  the operator also confirmed a VLAN 70 assignment test.
- **Completed: wireless positive EAP-TLS pilot and dynamic policy VLAN assignment.**
  HPE Instant On AP22 OFIS-AP, source 10.35.50.52, SSID VV_802.1X.
  Windows was configured manually with machine EAP-TLS, pinned server name and
  AuthWire Root CA. WPA2-Enterprise connected; initial address 10.10.110.3/24.
  With the SSID default network unchanged, changing only the AuthWire wireless
  policy VLAN gave an address from the new VLAN (operator confirmation 17:13).
- **Existing configuration accepted, new test omitted by operator:** separate
  guest SSID / VLAN 70. The operator already uses this arrangement and explicitly
  declined another guest test. Do not label it as a newly executed test.
- **Completed: normal-mode native RADIUS authorization correction.** PR 27
  backports upstream Python attribute parsing correction without dropping secret
  redaction. Native module update was applied with backup; real normal-service
  Accept and authenticated VLAN attributes were observed. Debug-only success is
  no longer the deployment evidence.
- **Completed: wireless pilot registration and scoped rule.** Existing OFIS-AP
  RADIUS client was changed from wired to wireless, preserving its shared secret.
  Rule `authwire-pilot-wireless` retains the pilot AD security group, EAP-TLS and
  domain computer constraint, and NAS 10.35.50.52. Existing wired rule was retained.
- The operator subsequently chose to share the existing cloud RADIUS profile and
  shared secret between switch and AP. Keep their distinct trusted source IPs and
  wired/wireless classifications; do not combine them into a subnet-wide client.

## Mapping to the baseline report

| ID | Latest change | Work still open |
| --- | --- | --- |
| B01 | Panel session recovery fix deployed; server API and protected-state verification completed. | Operator browser acceptance; complete setup/apply/recovery UX. |
| B02 | Live AD identity/pilot group accepted on wired/wireless; VV06 pilot-group removal and disabled-computer-account rejection/recovery completed. | Deleted account, unavailable AD and capacity tests. |
| B03 | Server name/CA validation completed on wired/wireless; VV06 wired revoked-certificate rejection and signed/current runtime CRL membership verified. | Expired/wrong issuer, CA/issuer rotation and remaining signing maintenance acceptance. |
| B04 | Enrollment task, successful last result, installation record, valid certificate/private key and confirmed receipt observed for the pilot. | Interrupted/duplicate requests and negative enrollment scenarios. |
| B05 | Pilot task and installed client confirmed. Client source hash remained unchanged through server updates. | Fresh SYSVOL package/signature/hash comparison where not yet recorded. |
| B06 | VV06 controlled post-revocation fresh enrollment, wired access, manual task recovery, automatic corrected-network reboot/task acceptance, controlled renewal/key rotation and post-renewal wired/VLAN/AuthWire reachability completed. | Exact EAP-selected renewed leaf, natural calendar renewal, daily-trigger reliability, offline/expired recovery and delayed predecessor cleanup. |
| B07 | Normal service, actual switch/AP EAP-TLS/VLAN, VV06 group/disabled-account recovery and corrected-network reboot wired/task acceptance completed. | Remaining lifecycle acceptance, other failure scenarios and accounting. |
| B08 | Real permit and dynamic VLAN/DHCP completed on switch/AP; pilot-group and disabled-account rejection/recovery completed on VV06. | Other explicit deny conditions and negative state transitions. |
| B09 | Wired positives, VV06 missing-cert/group/disabled/revoked negatives, controlled fresh-certificate recovery and automatic post-fix reboot wired/task acceptance completed. | Remaining lifecycle/negative scenarios; this does not close ordinary renewal or all offline recovery. |
| B10 | AP/SSID/source/secret, manual Windows machine EAP-TLS profile, positive connection and dynamic VLAN completed (3 of original 4 rows). | Intentional negative trust/identity tests remain open; reconnect was exercised during VLAN testing. |
| B11 | No accounting expansion in this session. | Accounting, session correlation and retention. |
| B12 | Updates retained configuration, administrators and certificates with backups. | Full restore/rollback and clean appliance import/boot acceptance. |

Do not close all of B03/B06/B09/B10 solely because a positive connection worked.
The operator's completed milestone is positive wired/wireless authentication and
policy VLAN behavior; negative and lifecycle rows remain separately visible.
G01-G07 remain at the baseline state unless a later implementation has evidence.

## Panel stability investigation

- Operator request at 17:38: intermittent F5/repeated credentials/slow responses;
  diagnose, report findings and fix without disturbing tested 802.1X behavior.
- Current production resources: no CPU/RAM/disk pressure, no service crash/restart
  loop. HTTPS public reads measured 2-3 ms; 24 reads at concurrency 8 had zero
  failures, median 11 ms and maximum 23 ms (server-local, not a client LAN benchmark).
- Journal contained repeated `SSLV3_ALERT_CERTIFICATE_UNKNOWN` from 10.35.50.54.
  Current HTTPS certificate is self-signed for kaname.vizyonveri.local and
  10.35.50.246, valid through October 2027. This is distinct from RADIUS CA trust;
  neither CA nor RADIUS server certificate should be reset to address it. The
  operator subsequently confirmed 10.35.50.54 is unrelated to panel use; exclude
  these messages from the diagnosis and do not change client certificate trust.
- Frontend defects corrected in PR 28 / source merge
  `11b4950cb475dce20054606a2839499c05cc7566` (0.14.0-dev.3): transient startup
  state/list errors no longer demand another password; fetch has bounded wait;
  login and polling are single flight; generic errors no longer trigger extra
  refresh requests; obsolete session responses cannot close a newer session.
- Completed validation: all nine browser fault-injection scenarios passed,
  existing panel/device/planning browser flows passed, and foundation CI ran
  409 Python tests successfully with 25 environment-dependent skips. Native
  RADIUS protocol and Windows enrollment/renewal fixture gates also passed.
  Main staging passed 112 filesystem-local checks (four skips); source manifest
  `2323abf4fde7a2169313f19ed766ffa425b03a47b2040bccdb33fc1c3af76392`.
- Panel fix status: **0.14.0-dev.3 deployed; final acceptance pending**. The
  operator ran the guarded update at approximately 18:14. Update and trusted HTTPS
  checks passed, and configuration, administrators and Windows client source
  preservation passed. Before update, all 15 authenticated API reads returned
  HTTP 200; endpoint medians were 2.4-8.0 ms, maximum 8.3 ms (server-local).
- Deployment incident: the post-update guard correctly detected RADIUS was no
  longer running. Its unit had `Requires=kaname-lab.service`; stopping the panel
  propagated a clean stop to RADIUS. The panel updater did not account for that
  effective systemd dependency. Panel and native module are healthy/unchanged,
  and RADIUS service restoration was subsequently confirmed by the guarded unit
  repair at 18:31. The initial RADIUS PID was not preserved; a new process was
  started. Authentication configuration and protected state were preserved.
- **Completed: permanent service dependency repair and server verification.**
  PR 29 merged as
  `b7e46991e17d3602d6424c1e59a179fda8b07f14`. Foundation CI ran 421 tests
  successfully (25 environment-dependent skips); native RADIUS proof and real
  disposable systemd lifecycle checks passed. The operator applied the guarded repair at 18:31: unit backup created,
  stop dependency removed, RADIUS started successfully, and UDP
  10.35.50.246:1812 confirmed. All 17 protected-state/file comparisons matched
  backup `upgrade-c2af2627005f44268e12dfebc9b120a8`, including policies, CA,
  certificates, enrollment signer/profiles/bindings, sealed secrets, administrators,
  web/RADIUS keys and certificates, Windows client, native module and remaining
  service commands/hardening. All 15 authenticated API reads returned HTTP 200;
  endpoint medians 2.6-25.1 ms, maximum 60.0 ms (server-local). Final output:
  `REPAIR_FINISHED verified=true radius_active=true protected_state_preserved=true
  panel_api_healthy=true`. Browser behavior after one Ctrl+F5 reload remains
  pending operator feedback; do not claim the intermittent client symptom is
  conclusively resolved until that acceptance.
  Retain `After` and a `Wants` startup
  dependency, remove panel stop propagation, refuse future panel upgrades while
  an active RADIUS service has a stopping dependency, and verify its PID after
  an upgrade. Migration preserves the remaining unit and authentication settings.
  The passing disposable systemd regression fixture reproduced old behavior and checked
  RADIUS PID survival across panel stop/restart. Never retest this by stopping
  the customer's live panel without independent authorization and need.

## VV06 field session — 13–15 October 2026

- Operator will bring a domain-joined Windows computer with no AuthWire client
  certificate installed. Operator identified the new computer as **VV06** at 11:14 on 13 October,
  reporting domain membership and no installed certificate. Read-only baseline confirmed at 11:22: domain vizyonveri.local,
  PartOfDomain=true, one personal machine certificate (Subject/Issuer CN=VV06),
  zero AuthWire machine certificates, AuthWire Root CA not trusted, no AuthWire
  enrollment task, and dot3svc stopped. Certificate purpose of the self-issued
  VV06 certificate was not established. Server-trust and supplicant preparation
  are required before the no-client-certificate rejection test can be accepted. No AD, policy or GPO changes were made in advance.
- **Completed VV06 preparation at 16:52:** operator imported the pinned public
  Root CA into LocalMachine Root after file thumbprint verification.
  RootTrusted=true; Subject CN=KANAME Root 6796fa84; SHA1
  C789A0595ADB95A6BE4534D01B1D205F6C37DE18. dot3svc is Running.
  This trust-only action did not issue an AuthWire client certificate; last
  measured AuthWire machine certificate count was zero. Correct machine EAP-TLS
  wired profile preparation was followed by the actual missing-certificate
  negative test at 19:15; results are recorded below.
- Server connection at session start was unavailable; Desktop Commander
  segmentiq reconnected at approximately 17:08. Production service and CRL
  readiness were subsequently verified; remote connectivity alone was not used
  as evidence of RADIUS health.
- **Blocking readiness issue found at 17:06, resolved at 18:02 on 13 October:** operator read the
  running RADIUS CRL: lastUpdate 12 October 06:02:58 UTC, nextUpdate 13 October
  06:02:58 UTC (09:02:58 Istanbul), already expired. Do not accept a failed
  connection as the missing-client-certificate test while this is unresolved.
  Desktop Commander reconnected; RADIUS was directly confirmed active, PID
  1100697. The subsequent read-only guarded diagnostic compared database and
  runtime CRL dates, numbers and signatures. Existing CA, keys, certificates,
  policies and VLANs have not been changed to address this issue.
- CRL diagnostic at 17:13 confirmed current, correctly signed database CRL #18
  (13 October 06:03:23 UTC through 14 October 06:03:23 UTC, two revoked entries)
  versus expired runtime #16 (12 October 06:02:58 UTC through 13 October
  06:02:58 UTC, two entries). Signer enabled and authority currently valid.
  Root cause: the database auto-refresh was not published to the active runtime;
  native X509 cache refresh was not configured. Immediate restart instruction
  given but not yet confirmed; observed PID still 1100697 at 17:31.
- **Completed: permanent CRL correction deployed (0.14.0-dev.4).** signed, pinned, monotonic
  atomic publication as the existing service user; minute timer respecting a
  deliberately stopped RADIUS; native X509 refresh at the supported 300-second
  interval. No CA/endpoint certificate reissue, policy reset or relaxed validation.
  PR 30 merged as `477a57d265a4dbfb9f6fb43f522648fdf277dca9` after all source
  gates passed: 438 foundation tests (25 environment skips), native EAP-TLS CRL
  cache proof (same process, real 300-second interval, native reject before policy),
  non-root systemd timer sandbox and stopped-service boundary, browser and Windows
  enrollment/renewal fixtures. Main staging ran 141 filesystem checks (four skips)
  and produced 98-file manifest
  `359722b02776194d1622d620366c36896108d860e86d68068367fb9f42328718`.
  Operator applied the guarded deployment at 18:02. Source upgrade verified
  HTTPS and preserved the active RADIUS process during the panel upgrade.
  Timer installation then performed the required initial RADIUS restart to
  activate the 300-second native X509 refresh; no periodic restart is configured.
  Database and runtime CRL were identical, signature-valid and current: #18,
  lastUpdate 13 October 06:03:23 UTC, nextUpdate 14 October 06:03:23 UTC,
  two revoked entries. All 17 protected file/state comparisons passed.
  Configuration, policies, CA material, certificates, secrets, administrators,
  primary RADIUS unit/native module and Windows source were preserved.
  Direct read-only follow-up at 18:06 confirmed the minute timer actually
  triggered, its oneshot completed with Result=success, and RADIUS remained
  active with PID 1142921. The successful oneshot being inactive afterward is
  expected. CRL publication/cache readiness blocker is closed; the VV06
  missing-client-certificate field test itself remains open.
- **Completed: VV06 wired missing-client-certificate negative test at 19:15:44
  on 13 October.** WiredService=Running, AuthWireMachineCertificateCount=0.
  Physical Realtek Ethernet MAC 38-CA-84-DB-FF-E6, interface
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, switch peer 64E881346361.
  Windows reported Connected / Authentication failed; fresh event 15514:
  identity NULL, 0x80420014, "A certificate could not be found that can be used
  with this Extensible Authentication Protocol." Event 15506 then applied a
  600-second suppression period. This establishes supplicant-side failure due
  to unavailable usable client certificate; it is not evidence of a RADIUS
  Access-Reject or an evaluated policy deny. Root trust/domain membership did
  not provide an EAP-TLS client credential. Guest access was not retested.
- Operator requested a brief Linux shutdown at 18:12. Pre-shutdown disk sync
  completed; panel/RADIUS/minute timer were enabled and active. Actual shutdown
  and subsequent boot are not yet confirmed. At 19:19 Desktop Commander was
  offline; this alone did not indicate server/RADIUS failure.
  **Completed: post-boot service/CRL readiness at 19:23.** Operator reported
  kaname-lab.service, authwire-radius.service and authwire-radius-crl-sync.timer
  all active/enabled. Runtime CRL #18 (0x12) lastUpdate 13 October 06:03:23 UTC,
  nextUpdate 14 October 06:03:23 UTC, still current. This verifies readiness
  after the planned shutdown; full boot/lifecycle and endpoint reconnect
  acceptance remain separate from these service-state observations.
- Enrollment scope check at 19:29: VV06 is
  CN=VV06,CN=Computers,DC=vizyonveri,DC=local; direct MemberOf list is empty.
  Existing GPO e5a9ab39-3709-49cb-837a-0208d2eb3b12 is
  AuthWire-Pilot-Trust, AllSettingsEnabled. AuthWire-Pilot-Computers has
  GpoApply; Authenticated Users has GpoRead only. Computer pilot group addition
  is the next scoped action; not yet confirmed. Link location and actual
  enrollment Startup script registration need verification before reboot.
  Do not infer installer deployment from the GPO name or copied SYSVOL files.
- GPMC screenshots at 19:33 confirm AuthWire-Pilot-Trust is linked to the
  vizyonveri.local domain root, Link Enabled=Yes, Enforced=No, WMI filter none.
  Security filtering remains AuthWire-Pilot-Computers only. Computer Startup
  has two entries invoking the same signed Install-AuthWire.ps1 in the existing
  GPO SYSVOL path: bare powershell.exe and the full System32 WindowsPowerShell
  v1.0 path, both with AllSigned. Operator instructed to remove the redundant
  bare-path entry and retain the full-path entry/parameters. Cleanup, VV06 pilot
  membership, new machine-token reboot and automatic enrollment are not yet
  confirmed. Do not mark the GPO distribution/second-device enrollment passed.
- **Completed: VV06 automatic enrollment/task and machine certificate installation
  observed at 19:45.** LastRunTime 13 October 19:39:42; initial LastTaskResult
  267009 (0x41301, task running), later 0. Certificate count increased from 0
  to 1; Subject CN=AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  Issuer CN=KANAME Issuer 6796fa84, HasPrivateKey=true, expiry 11 January 2027
  19:43:27 Europe/Istanbul. This is a distinct identity from pilot 2GL13ZU.
  Ethernet disconnected when the final read was captured does not invalidate
  stored task result/certificate evidence. Certificate serial and server receipt
  row were not independently read in this step. Positive switch port 6 access
  and policy VLAN/DHCP on VV06 remain pending; do not close full lifecycle,
  SYSVOL hash/signature inventory or user-authentication acceptance.
- **Completed: VV06 wired positive EAP-TLS field test at 19:48:36.**
  Windows physical Realtek Ethernet reported Connected / Authentication
  succeeded. Fresh event 15502 confirms EAP-TLS and machine credentials.
  Fresh event 15505 confirms host/AuthWire computer
  69b0d5cd-db61-4627-9db7-fcc5230152a3, peer 64E881346361, reason/error 0x0.
  After DHCP renewal, Ethernet had 10.10.110.4/24, gateway 10.10.110.1,
  matching the previously established VLAN 110 subnet. Wi-Fi was disconnected.
  This completes the VV06 certificate-free failure → automatic certificate
  installation → successful wired access sequence. A separate VLAN change on
  VV06 was not performed; dynamic policy VLAN changes remain evidenced by
  the earlier 2GL13ZU wired/wireless pilot tests. Wrong-group, disabled account,
  revoked certificate and lifecycle acceptance remain open.
- **Wrong-group negative phase observed at 19:55:51, reported at 20:01.**
  After the instructed VV06-only pilot group removal and a fresh wired attempt,
  Windows reported Connected / Authentication failed. Fresh event 15514 has
  host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3, switch peer
  64E881346361, reason 0x50005 and error 0x80420105 (server rejected the
  credential). Unlike the earlier missing-certificate failure, a certificate
  identity was selected. This is the expected client-side result of the
  controlled group-out test. Exact backend decision reason was not read;
  do not equate the generic Windows text with certificate revocation or expiry.
  Operator reported no errors/output from DC commands; membership restoration
  and positive recovery must be verified before closing the full wrong-group
  acceptance case. Only VV06 membership was instructed to change.

- **Completed: controlled VV06 wrong-group rejection and recovery at 20:05.**
  After the instructed pilot membership restoration and a fresh physical wired
  reconnect/service reset, Ethernet MAC 38-CA-84-DB-FF-E6 again reported
  Connected / Authentication succeeded. The group-out phase at 19:55:51
  failed and the restored phase succeeded using the same machine certificate.
  This closes the scoped wired field acceptance case; exact backend decision
  reason and an independent AD membership listing were not captured. No policy,
  certificate, VLAN or working 2GL13ZU change was instructed.
  Next controlled case is temporarily disabling only the VV06 AD computer
  account, checking fresh rejection, then re-enabling and verifying recovery.
  The disabled-account case was subsequently completed on 14 October, as
  recorded below.

- **Completed: VV06 disabled AD computer account rejection and recovery on
  14 October.** Operator labeled the first screenshot as account disabled:
  Ethernet MAC 38-CA-84-DB-FF-E6 / GUID 415933d5-5010-4a7a-b8bf-0e537e0bc7f2
  reported Connected / Authentication failed. Fresh event 15514 at 15:56:34
  identifies host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  peer 64E881346361, reason 0x50005, error 0x80420105. The second screenshot,
  after account re-enabling and dot3svc reset, shows the same physical Ethernet
  Connected / Authentication succeeded. This closes the controlled wired
  account-disabled rejection/recovery field case using operator-described AD
  states. Exact backend decision reason and Enabled=false/true AD command
  output were not captured; generic Windows error alone is not a revocation
  or expiry diagnosis. Evidence: image(20261014-130352).png and
  image(20261014-130403).png, inspected directly.
- **Completed: revocation-test preflight at 16:13 on 14 October.**
  Operator screenshots identify the VV06 LocalMachine machine certificate:
  Subject CN=AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3;
  Windows SerialNumber 0D9C3EE3C0B676CB323C1EC8314B62EE3E20A1D9;
  canonical AuthWire serial d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9;
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453;
  HasPrivateKey=true, expiry 11 January 2027 19:43:27 Europe/Istanbul.
  Current physical Ethernet still reports Authentication succeeded.
  Runtime CRL advanced to #20 (0x14), lastUpdate 14 October 06:03:32 UTC,
  nextUpdate 15 October 06:03:32 UTC (09:03:32 Istanbul), currently valid.
  This is next-day runtime publication evidence; no fresh signature/DB-equality
  or process-preservation comparison was captured in these screenshots.
  PKI revoke API expects canonical hex without leading zero; identify the
  exact certificate before the irreversible leaf revocation. Target is only
  VV06, with cessation_of_operation reason for the controlled test. Keep the
  certificate installed until the negative attempt so missing-cert failure
  cannot substitute for revocation rejection. Actual revocation/rejection and
  controlled fresh enrollment are still pending.
- Next: revoked-certificate test on VV06 only, then controlled fresh enrollment.
  First identify the actual current client certificate serial/thumbprint and
  verify current CRL readiness. No certificate has yet been revoked for this
  case; do not mark it completed. Desktop Commander was offline at the 16:06
  follow-up, so no fresh server/CRL inspection could be performed remotely.
  Keep working pilot 2GL13ZU unchanged and preserve policy/client/CA settings.
- **User EAP-TLS remains an explicit open item.** User certificate issuance,
  AD binding and live authorization exist in source, but automated user
  distribution/renewal and real wired/wireless user authentication have not been
  accepted. Include them in the next report; do not close them with computer
  pilot evidence. Windows machineOrUser switching also needs separate acceptance.
- Simultaneous machine-and-user authentication (for example TEAP chaining) is not
  implemented and is not silently added to the current EAP-TLS release scope.
- Operator will observe panel behavior and send grouped notes if symptoms recur;
  browser acceptance remains open. No reminder or unattended live test is scheduled.

## Completed: VV06 post-renewal wired access — 15 October 2026, 16:43

- Operator supplied image(20261015-134337).png after the requested ordinary
  wired reconnection test: physical Realtek Ethernet GUID
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC 38-CA-84-DB-FF-E6,
  Connected. Authentication succeeded. Fortinet virtual adapters disconnected.
- image(20261015-134347).png shows renewed DHCP address 10.10.110.4/24,
  gateway 10.10.110.1, AddressState Preferred; Wi-Fi disconnected.
  Test-NetConnection kaname.vizyonveri.local -Port 8765 resolves to
  10.35.50.246, uses SourceAddress 10.10.110.4 and returns
  TcpTestSucceeded=True.
- **Completed: post-renewal wired authentication, policy VLAN 110 DHCP and
  AuthWire HTTPS transport reachability.** This follows the confirmed new leaf,
  private key, public-key rotation and installed receipt state. TCP success
  establishes transport reachability, not a new application login test.
- Both old and renewed valid certificates remain in the intended overlap;
  these screenshots do not establish which exact leaf Windows selected for
  EAP-TLS. Selected-renewed-leaf evidence and scheduled predecessor cleanup
  remain separate open acceptance items. No manual old-leaf/key deletion,
  revocation, policy/CA modification or RADIUS restart was performed.
- Next lifecycle follow-up is normal subsequent task execution after local
  predecessor cleanup becomes eligible (12h), and server retirement after its
  separate deadline (up to 24h, capped by expiry). Do not accelerate clocks or
  remove the predecessor to relabel this overlap test as selected-leaf proof.

## Completed: VV06 renewed certificate and key rotation — 15 October 2026, 16:33

- Operator supplied installed-selected current machine certificate:
  Subject CN=AuthWire computer69b0d5cd-db61-4627-9db7-fcc5230152a3;
  canonical serial5899e122009871b0d5536890bee81e4f0499e605;
  thumb4CFD8321AE08D6074B99AF5C194151AD5F99F454;
  HasPrivateKey=True; CertificateChanged=True; PublicKeyChanged=True;
  OldCertificatePresent=True; NotAfter13 January2027 16:26:42 local.
- **Completed: supported per-device due-time request -> normal SYSTEM client
  renewal -> new leaf and new key -> installed receipt state.** Prior same-run
  task Ready/0, no pending/retry and fresh installed status support completion.
  This is controlled renewal via "Şimdi yenile", not elapsed natural lifetime.
- Old valid predecessor6fc12360e627e5b92b0d60ab103def6cb40fe624 /
  thumb68B32BBD470847950BAE5629B853739F819150B5 remains as intended overlap.
  Fresh source receipt/maintenance review additionally confirms server-side
  predecessor retirement deadline up to24h (capped by expiry), independently
  of the client's12h local certificate/key cleanup eligibility.
  Do not revoke/remove the old leaf or manipulate time for this normal test.
- No normal production RADIUS authorization logging currently prints the leaf
  serial; changing it/restarting live RADIUS is not warranted solely to obtain
  selection proof. Passive handshake parsing may be unable to reveal client
  certificate under TLS1.3; no parser/capture script was deployed.
- Next immediate field check: ordinary wired reauthentication, DHCP/VLAN and
  AuthWire reachability after renewal while preserving normal overlap.
  A successful reconnect with both old/new still eligible proves post-renewal
  access, not by itself which serial Windows selected. Keep selected-new-leaf
  and delayed retirement/cleanup acceptance explicitly separate.
- No key export, temporary certificate-store move, old-leaf removal, CA/policy
  change or server service restart was performed for this verification.

## VV06 renewal task completed; new leaf verification pending — 15 October 2026, 16:31

- Operator endpoint diagnostic CheckedAt=15 October16:28:28:
  task Ready, LastRunTime16:23:16, LastTaskResult0;
  status.json state=installed, last_success=2026-10-15T13:24:42.3282833Z
  (16:24:42 local); no stage/server_error; PendingRequest=False;
  RetryFileExists=False.
- This is a new successful installation-state write during the renewal run,
  stronger evidence than a healthy existing-certificate early-return.
  Actual new installed serial/thumbprint and key change are still missing.
  The earlier installed-selected old-leaf query was captured during Running;
  do not reuse its cached metadata to identify the final installed leaf.
- Next read current installed.json afresh, retrieve exactly its selected machine
  certificate and compare with baseline thumb68B32BBD470847950BAE5629B853739F819150B5,
  serial6fc12360e627e5b92b0d60ab103def6cb40fe624. Compare public key strings
  in memory only, output a boolean; do not export or print private key/container
  or receipt proof data. Old valid predecessor is expected to remain during
  the normal overlap period; do not delete/revoke it for this read.
- Certificate renewal is not yet finally accepted solely from task/state:
  confirm distinct leaf/private key and public key rotation, then validate
  access cutover with selected-serial evidence or explicitly scoped retirement
  consistent with the intended lifecycle. No new reconnect has been performed.

## VV06 renewal run in progress — 15 October 2026, 16:28

- Operator baseline installed record remains canonical serial
  6fc12360e627e5b92b0d60ab103def6cb40fe624,
  thumb68B32BBD470847950BAE5629B853739F819150B5,
  renew_at=2026-12-14T10:07:32Z (client-local schedule before server-side request).
- Current task Running, LastRunTime=15 October16:23:16,
  LastTaskResult=267009 (running). Installed-selected certificate still the
  same baseline leaf, HasPrivateKey=True, expiry13Jan2027 13:07:32 local.
  retry.json absent. No new serial/key or completed renewal is established.
  Operator has not separately supplied the panel renewal-request confirmation.
- Direct server13:28:16Z: panel active PID1238 Result=success and RADIUS active
  PID1274 Result=success. Request logging is intentionally disabled by
  Handler.log_message, so absence of API URLs in journal is not proof of no
  client request. Server is threaded with deferred TLS handshake and bounded
  per-connection read timeout; no immediate server-threading change indicated.
- Sanitized13:22-13:29Z journal count550,22 certificate_unknown TLS traces all
  associated with unrelated10.35.50.54; exclude them per operator instruction.
  No target-VV06 application error was established by this journal read.
- Next fresh endpoint read without a second task start: current timestamp,
  task state/run/result, whitelisted status timestamps/stage/server_error,
  pending.json existence and retry metadata if present. Old status entries
  may predate this running request; correlate timestamps before diagnosis.
  Do not stop task/RADIUS, clear state or revoke/remove the current certificate.

## Controlled normal renewal test prepared — 15 October 2026, 16:20

- After completed reboot acceptance, operator authorized continuing to normal
  certificate renewal. Fresh main-source review confirms supported panel action
  Certificates -> Devices -> installed VV06 -> "Şimdi yenile", endpoint
  POST /api/device-admin/renew-now. request_renewal validates installed/current/
  unrevoked leaf, updates only that issuance renew_at and records actor audit.
  It does not revoke/delete the old certificate, change profile/global lifetime
  or restart RADIUS.
- Existing target baseline: VV06 identity69b0d5cd-db61-4627-9db7-fcc5230152a3,
  installed canonical serial6fc12360e627e5b92b0d60ab103def6cb40fe624,
  thumb68B32BBD470847950BAE5629B853739F819150B5, expiry13Jan2027 13:07:32 local.
  Other pilot2GL13ZU and revoked predecessor d9c3... are outside scope.
- Verified client behavior: initial healthy receipt reports renew_now, then
  client establishes a fresh Kerberos session before new CSR/challenge/issue,
  installs/verifies the new leaf/private key and final receipt, and preserves
  the predecessor for a12-hour local overlap before normal cleanup.
- Test uses an explicitly advanced due time through the supported admin action,
  not proof that a natural90-day calendar boundary elapsed. Capture baseline
  serial/thumb, request renewal only once for installed VV06, launch the existing
  SYSTEM task normally, wait for actual completion, then read installed-selected
  new certificate plus task result and retry presence. No metadata reset,
  date manipulation, private-key export or server deployment is indicated.
- Renewal has NOT yet been requested/executed in field. After installation,
  verify changed serial/thumb and public key, active new registry/receipt and
  wired access with actual selected-certificate evidence where available.
  Do not equate installing a new certificate while old remains valid with
  independent proof that a reconnect selected the new leaf.
- No formal report requested/delivered. Continue updating this work record.

## Completed: VV06 automatic reboot acceptance — 15 October 2026, 16:15

- Operator supplied actual endpoint correlation:
  LastBootUpTime=15 October16:05:50;
  LastRunTime=15 October16:06:02;
  RanAfterBoot=True; LastTaskResult=0; RetryFileExists=False.
  Prior current-state submission shows task Ready and physical Realtek Ethernet
  Connected / Authentication succeeded, GUID415933d5-5010-4a7a-b8bf-0e537e0bc7f2.
- Existing SYSTEM task started12 seconds after boot and subsequently completed
  successfully; this is a start offset, not a12-second total execution duration.
  Operator was explicitly instructed not to manually launch the task.
  Retry eligibility16:01:03 had already passed before boot.
- **Completed: corrected-network automatic endpoint boot -> wired EAP-TLS
  access -> existing certificate task/session check without manual dispatch.**
  Preserve working switch/network restrictions correction, guest separation,
  endpoint profile/certificates and unchanged RADIUS/CA/policies.
- This does not prove a new renewal certificate or key rotation: the existing
  certificate health-check path was exercised. Ordinary renewal, daily09/21
  triggers/extended scheduling, offline/expired recovery and key retirement
  remain separate roadmap items; broader historical queue-cause diagnosis is
  not retrospectively established by one successful startup.
- No new source deployment, certificate issuance/reset, task-condition change,
  server restart or formal report delivery was performed for this acceptance.

## Corrected-network reboot follow-up — 15 October 2026, 16:13

- Before instructed reboot, endpoint retry eligibility time was
  15 October 16:01:03.7029914 Europe/Istanbul (13:01:03.7029914Z).
  Operator submitted it at16:06:47; earliest-retry time had passed, so continuation
  was authorized without deleting retry.json or forcing task constraints.
- Latest endpoint output after reboot instruction: physical Realtek Ethernet
  GUID415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC38-CA-84-DB-FF-E6,
  Connected / Authentication succeeded; enrollment task Ready,
  LastRunTime=15 October16:06:02, LastTaskResult=0.
- LastBootUpTime and retry.json existence were omitted from this submission.
  Do not close full unattended post-boot task acceptance yet: compare the
  actual endpoint boot timestamp with LastRunTime and check retry removal.
  Task time is before the16:06:47 continuation-message timestamp; this alone
  does not prove a stale result or clock fault. Endpoint boot/run comparison,
  rather than assumptions about cross-device clocks, is the appropriate check.
- Next single read-only object: actual LastBootUpTime, current LastRunTime,
  RanAfterBoot boolean, LastTaskResult and RetryFileExists. Do not restart,
  manually launch the task, clear metadata or change current working network
  settings for this check. Current wired positive and task exit0 observations
  are retained as successful observations with this final evidence boundary.

## Instant On access correction confirmed by operator — 15 October 2026, 16:03

- Operator explicitly confirms the preceding network access-control action
  definitely resolved the problem and requests continuing acceptance.
  Record this as operator-confirmed recovery following Instant On destination-
  restriction investigation. Exact final Access Control field values and scope
  were not supplied; do not invent a specific whitelist/global toggle or say
  guest isolation was removed.
- Retain the important distinction between static VLAN tag membership and
  network destination ACLs: adding multiple tagged networks can bypass the
  restriction per the prior UI warning, so earlier success after adding VLANs
  does not by itself prove missing VLAN carriage was the sole root cause.
- Scoped corrected-network automatic reboot acceptance remains the next test:
  before reboot inspect any existing retry.json next_attempt. If the deadline
  is in the future, wait until eligible rather than deleting retry metadata or
  accepting an exit0 early-return as successful session work.
- Reboot only VV06, Ethernet on corrected port6 and Wi-Fi off; no manual task
  launch or RunEx. After startup read actual LastBootUpTime, wired auth/IP,
  task state/LastRunTime/result, RunAfterBoot comparison and retry-file presence.
  Preserve certificates, task conditions/action and all server/RADIUS settings.
- Completed prior evidence stays separate: controlled fresh cert + wired
  recovery, restored TCP/DC discovery and manually requested Ready/0 with
  retry removal. Final corrected-network unattended reboot acceptance is pending.

## Internal-only reachability failure with Internet working — 15 October 2026, 15:57

- After the proposed port changes, operator reports a VLAN110-subnet address,
  Internet access working, but gateway 10.10.110.1 and AuthWire10.35.50.246
  inaccessible again. Fresh wired authentication state, actual cloud client
  network and network-level access-control screen were not yet supplied.
- Important previously underweighted screenshot warning on port6:
  "Network destination restrictions do not apply when multiple networks are included."
  Earlier all-tagged configuration may have bypassed network destination ACLs;
  clearing tagged memberships may have made existing restrictions applicable.
  This is a hypothesis supported by the UI warning and changed behavior, not
  a verified ACL match or proven final root cause.
- Own the diagnostic omission: the port review focused on static VLAN tag conflict
  but did not account for this warning's effect on destination restrictions.
  Do not restore an all-VLAN PC trunk merely to bypass ACLs or claim Windows
  authentication settings defective based on ICMP failure.
- Primary Instant On documentation confirms wired network Restricted access
  can allow Internet while blocking internal resources; web UI path is Networks
  -> selected network -> Access Control -> Network Access / Network Destinations,
  with Allowed Destinations Internet and Specific IP Address exceptions.
- Next read-only GUI evidence: TEST110/VLAN110 Access Control and current port6
  VV06 client network (VLAN110 versus Guest70), plus current netsh state if absent.
  Preserve guest70 isolation; do not globally unrestrict guest or all networks.
  If TEST110 restricts to Internet, review narrow required internal destinations
  (AuthWire10.35.50.246, AD/DNS10.35.50.70, gateway10.10.110.1 for diagnostic
  ICMP) instead of opening the entire internal address space.
- Previous successful TCP/DC/manual-task tests remain valid for their prior
  configuration. Current network correction and automatic reboot acceptance
  are open again; exact reason for earlier operator-described VLAN fix may need
  refinement once actual restriction settings are read.

## VV06 reboot failure and switch port review — 15 October 2026, 15:46

- Corrected-network automatic reboot acceptance is NOT complete. Operator's
  15:41 submission shows physical Ethernet Connected / Authentication failed;
  enrollment task Running, LastRunTime=15:38:01, LastTaskResult=267009.
  Boot timestamp, fresh Wired-AutoConfig error and final task result were not
  supplied. Preserve earlier manual Ready/0 recovery as a separate passed case.
- Direct server check at 12:42:45Z: panel active/running PID1238 Result=success,
  RADIUS active/running PID1274 Result=success, minute CRL timer active/waiting,
  CRL sync oneshot inactive after Result=success (normal). No restart performed.
- Directly inspected operator port 6 screenshots image(20261015-124409).png
  and image(20261015-124444).png. Actual settings:
  Enabled, no port profile, Client-based 802.1X;
  MAC authentication off; Unauthenticated User Guest Access ON;
  Port isolation off; untrusted network protections enabled;
  Untagged Default Network shows Select;
  Untagged Guest Network VLAN70;
  Selected Wired Networks with All networks checked and static tagged
  VLAN1,110,120,130,140,200; VLAN70 guest disabled in tagged selection.
  Connected VV06 MAC38:ca:84:db:ff:e6 currently displays VLAN70 Guest.
- Primary-source review: current Instant On cloud guide documents guest fallback
  on failed 802.1X and per-client authentication. 1930 hardware management guide
  states static tagged/untagged membership conflicting with the RADIUS-indicated
  tag status can cause authentication failure; a non-member port can join the
  returned VLAN dynamically. Hardware behavior is a strong hypothesis here,
  not a captured server/switch failure reason.
- Scoped correction proposed for ordinary untagged VV06 endpoint: retain
  Client-based authentication and intended VLAN70 guest fallback; clear all
  static tagged networks from port6 only, explicitly set its Untagged Default
  Network to VLAN110 TEST110 for the current test. Do not make the PC port an
  all-VLAN trunk or change NIC VLAN tagging. Keep existing uplink VLAN carriage,
  other ports, RADIUS policy/CA/certificates and protections unchanged.
- Guest fallback being enabled is not itself proof of a defect; observed
  VLAN70 can be the consequence of failed authentication. If Windows keeps a
  previous VLAN110 lease while actually in guest70, IP reachability may fail.
- Next after operator saves scoped port correction: fresh wired reconnect,
  current auth state first, then DHCP/IP and FQDN TCP if auth succeeds.
  If authentication still fails, capture fresh physical-interface 15514/15506
  before further changes. Automatic reboot/task acceptance remains open.

## VV06 existing-certificate task recovered — 15 October 2026, 15:38

- **Completed: normal existing SYSTEM-task run after VLAN carriage correction.**
  Operator reports AuthWire Certificate Enrollment Ready,
  LastRunTime=15 October 2026 15:27:27, LastTaskResult=0 and retry.json absent
  (False). Before this same run retry.json existed; intermediate state was
  Running/267009. Thus the result is completion, not merely an accepted start.
- Combined with restored FQDN TCP 8765/DC discovery, the task result and
  retry-file removal match successful existing-certificate session/receipt
  handling in the unchanged signed client. No fresh certificate serial,
  renewal issuance or private-key rotation was observed or claimed.
  An old status.json retry_pending entry can remain in this healthy-check
  branch; do not demand its removal or reset enrollment state.
- Root cause recorded from operator: required VLAN not carried on the
  computer-connected switch port; adding it restored access.
  No Windows EAP-TLS profile correction was required.
- This run was manually requested through ordinary Start-ScheduledTask and
  retained SYSTEM principal, signed action and persistent conditions/triggers.
  It does not close the corrected-network automatic reboot execution test
  or establish permanent resolution of every earlier queued-task condition.
- Next: reboot only VV06 with Ethernet on corrected test port and Wi-Fi off,
  do not manually launch the task, then read wired auth/IP and Ready/result0
  with LastRunTime after the actual boot and no retry.json.
  Preserve server/RADIUS, policy/VLAN/certificates and the working pilot 2GL13ZU.

## VLAN carriage corrected and network retest passed — 15 October 2026, 15:33

- Operator identified actual correction: the required VLAN was not carried
  on VV06's connected switch port; adding the VLAN restored access. Exact
  cloud setting/port membership delta was not supplied. Do not attribute the
  fault to Windows EAP-TLS mode or a specific FortiGate/UFW deny.
- **Completed: VV06 post-correction FQDN/TCP and DC discovery checks.**
  Directly inspected image(20261015-123051).png: AuthWire FQDN resolves to
  10.35.50.246; TCP 8765 succeeds from 10.10.110.4. Forced nltest succeeds,
  identifying dc01.vizyonveri.local at 10.35.50.70 with KDC/LDAP/DC flags.
  Existing Ethernet/default route via 10.10.110.1 remains.
- Before normal task start, retry.json existed (True). Existing task was
  started using ordinary Start-ScheduledTask. Directly inspected second image
  image(20261015-123132).png: State=Running, LastRunTime=15:27:27,
  LastTaskResult=267009 (0x41301, running); retry.json still True.
- Task completion/receipt recovery is NOT accepted yet. Running code is not a
  final failure or success. Request a fresh state/result/retry-presence read
  without starting a second instance or clearing state. If still running,
  inspect actual elapsed time/process stage before any restart/reset.
- Earlier missing network access is resolved at endpoint TCP/DC-discovery
  level. Persistent task scheduling, final task result and clean reboot with
  the corrected VLAN configuration remain separate acceptance items.

## Operator network correction, retest pending — 15 October 2026, 15:27

- Operator reports finding and correcting the network problem and requests
  resuming the intended acceptance test. Exact cause/configuration change
  has not been supplied; do not label it a specific firewall/switch/endpoint
  defect or claim independent resolution.
- Next acceptance: restored FQDN TCP 8765 and domain-controller discovery from
  VV06, then ordinary Start-ScheduledTask on the existing SYSTEM task after
  checking retry eligibility. Preserve signed client, certificate/metadata,
  task settings and server/RADIUS policies. No fresh enrollment/reset or
  RunEx constraint bypass is indicated for this retest.
- Read actual LastRunTime/result and current task state after completion.
  Client source returns successfully after a healthy existing-certificate
  receipt and removes retry.json without updating status.json in that branch;
  an old retry_pending status alone is not proof the latest run failed.
  Capture retry-file presence before/after as well as task result to distinguish
  a real receipt recovery from a retry-deadline early return.
- Do not close post-boot task/receipt or network reachability until results
  are supplied. Ask operator to identify the actual correction for the record.

## Gateway/interface and endpoint route matched — 15 October 2026, 15:21

- Directly inspected image(20261015-122053).png from FortiGate VIZYONVERI-FW:
  10.10.110.1/24 is assigned to TEST110, interface index 46.
  VRF 0 route 10.10.110.0/24 is directly connected through TEST110.
  FortiGate ARP maps 10.10.110.4 to 38:ca:84:db:ff:e6 on TEST110,
  matching VV06's actual physical MAC.
- Windows Find-NetRoute to 10.35.50.246 selects Ethernet, source 10.10.110.4,
  destination 0.0.0.0/0, next hop 10.10.110.1. The inspected route does not
  select one of the unplugged VPN virtual adapters.
- Basic gateway/interface and reciprocal neighbor data align. These observations
  do not explain the earlier empty capture or prove successful IP forwarding.
  Preserve EAP-TLS/profile and avoid changing gateway/VLAN based on speculation.
- Next: FortiGate route lookup to AuthWire, read-only policy lookup for tuple
  10.10.110.4:55000 -> 10.35.50.246:8765 TCP with actual ingress TEST110,
  plus FortiGate server-neighbor entry. Policy lookup is configuration evaluation,
  not independent proof a real packet arrived/was allowed.
- Compare server neighbor MAC to actual Linux ens33 MAC. Endpoint gateway ping
  remains a distinct local-in check; verify TEST110 PING setting if needed,
  rather than assuming the transit ACCEPT/ALL policy grants local-in traffic.

## FortiGate capture empty — 15 October 2026, 15:16

- Operator reports FortiGate capture stopped with Ctrl+C:
  0 packets received by filter, 0 packets dropped by kernel.
  No matching ingress/egress headers were supplied for the instructed
  combined client ICMP/server TCP filter.
- This is not proof of a specific deny rule or a bad Windows EAP-TLS profile.
  Capture timing, actual gateway device, VDOM/HA context, endpoint selected
  route, alternate path and capture visibility remain to be established.
  Do not disable hardware offload or reset switch/authentication based only
  on an empty trace.
- Next read-only cross-check in the VLAN 110 FortiGate VDOM:
  interface IP ownership for 10.10.110.1, route lookup to 10.10.110.4,
  ARP entry for VV06 (expected 38:ca:84:db:ff:e6 if directly connected).
  Separately inspect Windows Find-NetRoute toward 10.35.50.246 with explicit
  Format-List so mixed table formatting does not hide route fields.
- Existing gateway neighbor on VV06 is 90-6C-AC-A7-D2-D1 Reachable.
  Its ownership has not yet been independently matched to the FortiGate.
  No configuration/security changes have been performed.

## VV06 gateway ARP resolved — 15 October 2026, 15:12

- Current physical Ethernet authentication succeeds. IPv4 10.10.110.4/24 is
  Preferred with PrefixOrigin=Dhcp; three probes to 10.10.110.1 timed out.
  The supplied earlier default-route table was not legible enough to establish
  additional route fields independently.
- Standalone neighbor read: InterfaceAlias=Ethernet, IPAddress=10.10.110.1,
  LinkLayerAddress=90-6C-AC-A7-D2-D1, State=Reachable. This establishes a resolved
  gateway neighbor/basic ARP exchange. It does not prove intended VLAN tagging,
  absence of proxy ARP/IP conflict, correct FortiGate ownership of that MAC,
  or permitted IP/ICMP/forwarding traffic.
- Keep machine EAP-TLS/certificate/policy intact. No evidence currently calls
  for changing authentication mode or disabling validation.
- Next: actual FortiGate ingress/egress header capture during VV06 gateway ping
  and TCP 8765 test; filter includes client ICMP plus server TCP to retain
  visibility across possible SNAT. Confirm the gateway VLAN/interface and
  actual matched policy from capture/log evidence rather than the configured
  ACCEPT/ALL row alone. Local-in ICMP and forwarded TCP are distinct decisions.
- Pending: Forward Traffic/matched-policy or sniffer output, restored AuthWire
  HTTPS connectivity and successful post-boot enrollment receipt/task execution.

## VV06 gateway reachability branch — 15 October 2026, 15:08

- Operator reports VV06 cannot ping its own gateway in the affected network,
  despite ping being allowed, while access works when moved to another network.
  Operator disabled Windows Firewall for diagnosis with no change in outcome.
  Neither a paired FortiGate sniffer trace nor new Windows interface/ARP output
  has been supplied. Do not attribute a firewall change to the assistant.
- Expand diagnosis to actual VLAN, addressing, route and gateway ARP/L2 path.
  Previous EAP-TLS success proves the earlier authenticated state, not the
  current effective VLAN or gateway connectivity. Gateway ICMP failure alone
  does not distinguish failed ARP from disabled local-in ICMP or filtering.
- Next read-only VV06 checks while on affected VLAN 110/port 6 with Wi-Fi off:
  current wired authentication, IPv4 prefix/address origin, default route,
  three gateway probes, and gateway neighbor state/MAC. Established expected
  gateway is 10.10.110.1; check actual current route rather than assuming it.
- If ARP remains Incomplete/Unreachable, investigate authenticated port VLAN,
  switch/AP uplink membership and gateway VLAN interface before modifying TLS
  or broad firewall rules. Existing neighbor mapping is not by itself proof
  of fresh end-to-end reachability.
- Restore the endpoint firewall to its pre-test state. No certificate, task,
  EAP method, server validation, RADIUS policy/VLAN or switch reset is indicated
  by current evidence; preserve these until the actual fault is established.

## VV06 Linux capture observation — 15 October 2026, 14:52

- Operator supplied bounded Linux ens33 TCP 8765 SYN/RST capture output:
  0 packets captured, 1 packet received by filter, 0 dropped by kernel.
  No packet header was delivered in the submitted output. Do not silently
  replace the filter count with zero or treat this as conclusive proof that
  no packet reached Linux.
- A concurrent VV06 TCP test was instructed; no paired Windows output/timestamp
  was supplied in this submission. Confirm effective traffic path with an
  observation on FortiGate during a fresh VV06 test.
- Next: FortiGate CLI header-only sniffer on any interface for server
  10.35.50.246 TCP 8765, verbosity 4 to show interfaces, count 0, local timestamps;
  operator stops with Ctrl+C after the test/about 30 seconds. This changes no
  policy or offload setting. Filter avoids original-source requirement to
  preserve visibility if SNAT is present.
- Packet capture/actual matched-policy evidence remains pending. Do not infer
  exact FortiGate deny, wrong route, wrong VLAN or host rejection without it.

## VV06 TCP failure with UFW inactive — 15 October 2026, 14:47

- Operator reports intended FortiGate rule is ACCEPT with service ALL.
  VV06 retest still fails from 10.10.110.4 to 10.35.50.246 TCP 8765.
  A matching configuration row alone does not establish which policy actually
  handled the connection, its interfaces/order, NAT or return-path behavior.
- Operator root read sudo ufw status numbered returns Status: inactive.
  Correct the earlier inference: systemctl reporting ufw.service active only
  described its service unit and did not establish active UFW filtering.
  No assistant firewall disable/enable or rule mutation occurred.
- Direct Linux recheck still shows panel active/running Result=success,
  listener 10.35.50.246:8765 and route to VV06 via 10.35.50.254 on ens33.
  tcpdump and timeout are installed at /usr/bin/tcpdump and /usr/bin/timeout.
- Next: operator-run bounded 30-second Linux packet-header observation on ens33
  for server TCP 8765 SYN/RST while running one VV06 TCP test. Match the server
  address/port rather than requiring the original client source, so a possible
  FortiGate SNAT does not conceal arrivals. Do not print payloads or change
  certificate/task/RADIUS/firewall settings. Arrival/response evidence is still pending.

## VV06 DNS restored, HTTPS still blocked — 15 October 2026, 14:37

- Attached image(20261015-113624).png was directly inspected. Explicit VV06 DNS
  queries against 10.35.50.70 now succeed: kaname.vizyonveri.local A ->
  10.35.50.246; domain-controller SRV -> dc01.vizyonveri.local:389,
  with additional A -> 10.35.50.70. Scoped explicit DNS-query restoration is
  completed; default-resolver behavior and actual DC discovery are not yet retested.
- Direct-IP TCP test still fails: source 10.10.110.4 -> 10.35.50.246:8765,
  TcpTestSucceeded=False. Ping timeout is ancillary and not service proof.
  Do not mark HTTPS enrollment connectivity or the failed task recovered.
- Direct read-only Linux checks: listener present on 10.35.50.246:8765;
  route to 10.10.110.4 via 10.35.50.254, ens33, source 10.35.50.246.
  This proves a configured return route, not successful end-to-end delivery.
  ufw.service is active; firewalld.service and nftables.service inactive.
  No privileged firewall ruleset has been read; UFW as the blocker is only
  a hypothesis alongside the inter-VLAN firewall policy.
- Next root-only read is operator-run sudo ufw status numbered. Inspect existing
  source/service allowances before any scoped rule change; do not disable UFW,
  broadly open management access or restart RADIUS for this diagnosis.
  Preserve machine cert, client state, task conditions, policy/VLAN and CA.

## VV06 VLAN 110 firewall prerequisite — 15 October 2026, 14:12

- Explicit endpoint queries to internal DNS 10.35.50.70 timed out for both
  kaname.vizyonveri.local A and domain-controller SRV records.
  Direct-IP TCP 10.35.50.246:8765 also failed with source 10.10.110.4.
  Ping timed out as well; ICMP alone is not used as service-health evidence.
- Operator confirmed no firewall access rule exists from 10.10.110.0 network
  to 10.35.50.0 network and will configure access then repeat the same tests.
  Current evidence strongly supports missing inter-VLAN access as the DNS/
  HTTPS bootstrap prerequisite failure. Exact rule effect awaits retest.
- Working machine-certificate EAP-TLS/VLAN authorization does not establish
  endpoint HTTPS enrollment or domain-controller reachability: the RADIUS
  conversation is between switch and server, whereas task requests originate
  from VV06 in its assigned VLAN.
- Recommend scoped destinations/services for this pilot: internal DNS
  10.35.50.70 UDP/TCP 53, AuthWire 10.35.50.246 TCP 8765, and required AD
  connectivity to the actual DC according to the existing domain firewall policy.
  Do not request unrestricted access between both entire networks.
- Firewall/DHCP configuration is performed by the operator. No RADIUS,
  certificate, task, policy/VLAN or server configuration has been changed.
  Post-change DNS/HTTPS/DC discovery and an actual successful existing task
  run remain pending; no second enrollment/reset is needed for this test.

## VV06 VLAN 110 DNS/DC discovery failure — 15 October 2026, 14:05

- Endpoint Ethernet DNS servers are 10.35.50.70 and public resolver 1.1.1.1.
  Test-NetConnection by FQDN warned that kaname.vizyonveri.local name
  resolution failed; nltest forced DC discovery returned 1355 / ERROR_NO_SUCH_DOMAIN.
  No endpoint TCP result was supplied. DNS/DC discovery is currently unhealthy;
  failed discovery alone does not mean VV06 lost domain membership.
- Direct read-only DNS queries from AuthWire Linux to 10.35.50.70 succeeded:
  authoritative NOERROR A kaname.vizyonveri.local -> 10.35.50.246;
  authoritative NOERROR SRV _ldap._tcp.dc._msdcs.vizyonveri.local ->
  dc01.vizyonveri.local, port 389. Thus these records exist and the DNS server
  answers from the Linux management-network vantage. This does not prove
  VLAN 110 DNS reachability or identify a specific firewall rule.
- Session-stage enrollment failure is consistent with endpoint DNS/DC failure,
  but exact original SSPI/HTTPS exception remains unobserved.
- Next: explicit endpoint queries against 10.35.50.70 for both records, plus
  direct-IP TCP 8765 reachability to 10.35.50.246. Check VLAN 110 DNS routing/
  ACL and DHCP resolver configuration against results. Domain clients should
  receive internal AD DNS servers; public recursive forwarding belongs on the
  internal DNS service, not as an alternate domain-client resolver.
- Do not alter EAP-TLS validation, certificates, task, RADIUS policies or broadly
  open VLAN routing. No configuration mutation has been performed.

## VV06 session-stage diagnosis — 15 October 2026, 14:01

- Endpoint status: state=retry_pending, error=ENROLLMENT_OR_INSTALL_FAILED,
  stage=session, no server_error, checked_at=2026-10-15T10:50:08.6893421Z.
  Retry attempts=1, next_attempt=2026-10-15T11:05:08.6366804Z
  (14:05:08 Europe/Istanbul). This is an earliest retry eligibility deadline,
  not a guaranteed task trigger at that time.
- Client source shows session includes machine Kerberos credential acquisition,
  initial SSPI token, pinned/validated HTTPS POST /api/device/session, response
  parsing and mutual-authentication completion. No specific failure within
  these operations is established by the coarse stage. Blank server_error
  does not prove no server contact.
- Read-only Linux verification at 13:58:44 showed panel and RADIUS active/running
  with Result=success and CRL timer active/waiting. A service-journal query for
  13:47-13:52 local returned zero records; it supplies no independent request
  or TLS/Kerberos failure evidence and cannot establish that no request arrived.
- Next endpoint read-only diagnosis: Ethernet IPv4 DNS configuration, current
  FQDN TCP 8765 reachability/source and forced domain-controller discovery on
  VLAN 110. Preserve client state, pinned TLS/mutual Kerberos, task conditions,
  certificate, RADIUS and policy configuration pending evidence.

## VV06 post-boot task failure — 15 October 2026, 13:58

- After the elevated read, operator reported existing enrollment task Ready,
  LastRunTime=15 October 2026 13:48:24 and LastTaskResult=1. This confirms a
  post-boot execution attempt ended with a nonzero result; post-boot task
  success is not accepted. Existing certificate-backed wired authentication
  and VLAN 110 access remain successful, as separately observed.
- Client source inspection confirms status.json records sanitized
  state/error/stage/checked_at/server_error for enrollment failures and
  retry.json records attempts/next_attempt/stage/server_error. Read only these
  whitelisted fields before diagnosing or rerunning. Exit code 1 alone does
  not identify networking, Kerberos, receipt, renewal or signing as the cause.
- Do not clear retry or installation state, replace certificates, weaken
  validation or force-dispatch the task for this initial diagnosis.
  Earlier queued scheduling and this nonzero boot run are distinct observations.

## VV06 Windows reboot acceptance — 15 October 2026, 13:54

- **Completed: restored wired access after the instructed VV06 Windows reboot.**
  Operator supplied physical Realtek Ethernet GUID
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC 38-CA-84-DB-FF-E6,
  Connected / Authentication succeeded, and IPv4 10.10.110.4/24 Preferred.
  This closes the scoped endpoint reboot/authentication/VLAN-access test.
  Boot timestamp and pre-logon timing were not independently measured.
- Get-ScheduledTaskInfo for AuthWire Certificate Enrollment returned
  PermissionDenied / HRESULT 0x80070005. No LastRunTime or LastTaskResult
  was read. This is a query access failure, not evidence that enrollment
  failed or that the existing scheduled task ran successfully after boot.
- Next: repeat only task-information and administrator-token read in an elevated
  PowerShell on VV06. If denial persists with an elevated token, investigate
  task access read-only; do not weaken the SYSTEM task ACL or change its
  principal, action, triggers, power/network conditions or signing requirements.
- Task execution after reboot, ordinary scheduling reliability, unattended
  renewal, offline recovery and key lifecycle acceptance remain open.
  No server/RADIUS, policy/VLAN, certificate or task change was made for this step.

## VV06 post-revocation recovery accepted — 15 October 2026, 13:47

- **Completed: controlled revocation -> fresh enrollment -> restored wired
  authentication and VLAN 110 access.** Operator supplied current netsh output
  for physical Realtek Ethernet, GUID 415933d5-5010-4a7a-b8bf-0e537e0bc7f2,
  MAC 38-CA-84-DB-FF-E6: Connected / Authentication succeeded.
  The immediately preceding endpoint result showed 10.10.110.4/24,
  gateway 10.10.110.1, with Wi-Fi disconnected.
- Together with the verified distinct new certificate/private key and
  state=installed (13:35 entry), this completes the controlled field recovery
  case. It does not prove the exact EAP-TLS selected serial from a handshake
  trace; the current netsh result reports authentication state only.
- The old server certificate remains revoked. Its guarded local removal was
  instructed but cleanup output was not supplied; do not claim old leaf/key
  lifecycle cleanup independently verified.
- Ordinary scheduler queue cause/reliability, unattended renewal, automatic
  recovery UX and full Windows reboot lifecycle remain separate open items.
  Next scoped acceptance: reboot only VV06 with physical port 6 connected and
  Wi-Fi disconnected, then observe wired authentication/IP and the existing
  SYSTEM task without forced dispatch or task-condition changes.
- Existing working pilot 2GL13ZU and Linux RADIUS, CA, policy/VLAN and secrets
  were not changed for this acceptance step.

## VV06 recovery network observation — 15 October 2026, 13:45

- **Completed: post-recovery IPv4 address observation.** Operator supplied
  Ethernet 10.10.110.4/24, gateway 10.10.110.1, AddressState=Preferred,
  with Wi-Fi disconnected. This matches the established VLAN 110 subnet.
- New certificate installation is already verified separately. This submission
  contains no current netsh authentication state or fresh 15505 success event;
  an IP address alone does not establish successful EAP-TLS or which certificate
  was selected. Keep fresh wired authentication acceptance pending.
- Guarded removal of the old revoked leaf was instructed, but no cleanup output
  was supplied. Do not record removal or private-key cleanup as confirmed.
- Next: read current physical Ethernet authentication state and latest matching
  Wired-AutoConfig success/failure events. Do not reset certificate metadata,
  task settings, RADIUS service, policies, VLANs or CA material for this read.

## VV06 fresh certificate verified — 15 October 2026, 13:35

- **Completed: controlled fresh enrollment after revocation, endpoint evidence.**
  Operator reports TaskState=Ready, LastTaskResult=0; current installed record
  resolves to Subject CN=AuthWire computer
  69b0d5cd-db61-4627-9db7-fcc5230152a3, serial
  6fc12360e627e5b92b0d60ab103def6cb40fe624, thumbprint
  68B32BBD470847950BAE5629B853739F819150B5, HasPrivateKey=true, expiry
  13 January 2027 13:07:32 Europe/Istanbul.
  status.json state=installed, serial matches the new leaf, reported
  last_success=2026-10-15T10:05:31.9905999+00:00.
- These recorded times do not establish that the 13:12:58 RunEx dispatch
  created this leaf: last_success precedes that task start. Preserve the raw
  observations; do not infer an exact issuance/dispatch chronology or permanent
  scheduler fix from them. The distinct new certificate/private-key and
  installed receipt state establish the recovery milestone.
- Next: guarded removal of only the old revoked Windows certificate with
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453, after checking new
  leaf identity/private-key. Keep the server old serial revoked. No CNG key
  container deletion or CA/trust/policy changes are part of this step.
  Fresh wired port 6 EAP-TLS/DHCP using the new leaf remains pending.

## VV06 controlled dispatch result — 15 October 2026, 13:15

- Operator executed the existing-task RunEx dispatch and reported TaskState=
  Running, LastRunTime=13:12:58, LastTaskResult=267009 (running),
  PendingRequest=false, InstalledRecord=true. This is actual task execution
  and a recreated installed.json, not merely an accepted launch request.
- Inspect the certificate referenced by current installed.json thumbprint and
  current status/finished task result before accepting fresh enrollment or
  removing the old revoked leaf. New serial/thumbprint have not yet been read.
- Persistent scheduled-task settings were not changed by the supplied RunEx
  method. Ordinary condition-based scheduling reliability/precise queue cause
  remains open; do not label one-run dispatch as a permanent scheduler repair.

## VV06 scheduler follow-up — 15 October 2026, 13:07

- Current bootstrap reachability is confirmed: Wi-Fi source 10.35.50.69,
  AuthWire TCP 8765 reachable, network vizyonveri.local is DomainAuthenticated
  with Internet IPv4 connectivity. Task network profile Name/Id are empty;
  RunOnlyIfNetworkAvailable=true, DisallowStartIfOnBatteries=true,
  StopIfGoingOnBatteries=true, RunOnlyIfIdle=false, StartWhenAvailable=true,
  MultipleInstances=IgnoreNew. Win32_Battery Primary BatteryStatus=2.
  Microsoft documents that battery status 2 indicates access to AC power.
- Thus lack of current HTTPS TCP reachability or reported battery discharge
  is not established as the queue cause. Exact Windows scheduler queue cause
  remains unresolved. Avoid changing broad power/network conditions without
  evidence or claiming the installer is permanently fixed.
- Next controlled attempt: invoke the existing enabled SYSTEM task via
  Task Scheduler RunEx with only TASK_RUN_IGNORE_CONSTRAINTS (2), after checking
  its principal/enabled/AllowDemandStart and current state. Preserve persistent
  task settings/action, signed client, config/trust and all server settings.
  No task stop, state reset or additional certificate removal is part of this
  attempt. Report actual post-request task state, not a success-start message.
  This one-run dispatch is not yet performed/verified; new certificate and
  normal periodic scheduling acceptance are still open.

## VV06 queued enrollment — 15 October 2026, 12:55

- Operator read-only diagnostic: Computer=VV06, TaskState=Queued,
  TaskUser=SYSTEM, LastRunTime=12:41:05, LastTaskResult=0,
  ActionCallsClient=true, ValidateOnly=false, PendingRequest=false.
  Current status.json, retry.json and installed.json are all absent.
  Only AuthWire Certificate Enrollment was listed, also Queued.
- This confirms the current task is awaiting scheduler execution and no new
  client-state result has been saved. Earlier current-retry/ValidateOnly
  hypotheses are not supported by this snapshot. Exit 0 is not acceptance
  evidence for fresh issuance. Exact queue constraint is not yet established.
- Check AuthWire TCP reachability from the bootstrap network, task network
  profile/availability, idle/power settings and current network profile before
  changing any scheduler condition. Source installer enables
  RunOnlyIfNetworkAvailable; default Windows battery restrictions may also
  apply. Do not assume either is the cause before collecting actual settings.
- No repeat state reset or old certificate deletion is authorized by this
  diagnostic step; preserve existing Recovery-20261015-124104 backup.

## VV06 recovery attempt — 15 October 2026, 12:46

- Operator screenshots image(20261015-094606).png and
  image(20261015-094614).png were directly inspected. Recovery block printed
  backup C:\ProgramData\AuthWire\Recovery-20261015-124104 and task-start message.
  Task LastRunTime=15 October 12:41:05, LastTaskResult=0.
- **Recovery is not yet verified.** The supplied certificate result contains
  only the original revoked serial 0D9C3EE3C0B676CB323C1EC8314B62EE3E20A1D9,
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453, private key present,
  expiry 11 January 2027 19:43:27. No new leaf was shown by the fixed-subject
  query. Do not delete the old leaf or mark fresh enrollment successful solely
  from task exit 0 or the task-start message.
- Inspect current task state/action and selected status/retry/installed metadata
  without printing receipt_payload, config contents or pending CSR/key material.
  Source has intentional successful early returns for ValidateOnly, held global
  mutex and future retry deadline; actual cause is not established. An updated
  installed record would also require reading the certificate by its recorded
  thumbprint rather than assuming the original subject filter finds it.
- No second reset, additional key/CSR or certificate deletion has been executed.
  Future mutating recovery commands should be invoked as one script block so
  a guard exception aborts the whole operation in an interactive shell.

## VV06 revocation acceptance — 14 October 2026, 19:06

- **Completed: VV06 wired revoked-certificate rejection.** Operator ran the
  targeted read-only CRL check: crl_number=21, currently_valid=true,
  signature_valid=true, vv06_in_crl=true for canonical serial
  d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9. The runtime Issuer public key and
  issuer name were used to verify the signature.
- Fresh Windows screenshot image(20261014-160552).png shows event 15514
  at 19:02:55, physical Realtek Ethernet GUID
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC 38CA84DBFFE6, peer
  64E881346361, host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  reason 0x50005, error 0x40420110, generic account-related failure text.
  Do not relabel that text as independent proof that the AD account is disabled.
  Controlled revocation, exact signed/runtime CRL membership and fresh matching
  endpoint rejection jointly close the field negative case. Actual rejection
  layer (native CRL versus registry callback) was not independently instrumented.
- **Open: controlled fresh enrollment after revocation.** VV06 must use the
  ordinary domain/bootstrap network. Keep the account enabled/in the pilot
  group. Prepare an elevated, VV06-only guarded state reset: refuse running
  enrollment/pending request or mismatched installed serial/thumbprint; verify
  client Authenticode signature; temporarily disable the existing task, back up
  only installed/retry/status metadata under the protected ProgramData AuthWire
  folder, then enable/start the same SYSTEM task for a fresh key/CSR. Preserve
  config/trust, GPO, server settings and the old installed leaf until the new
  certificate/receipt is verified. This is explicit administrative recovery,
  not automatic revival of the revoked certificate or a production recovery UX
  acceptance. No recovery state mutation has been confirmed yet.

## VV06 revocation observation — 14 October 2026, 18:57

- Operator reports VV06 Authentication failed following the instructed
  certificate-revocation sequence. Runtime CRL is #21 (0x15), lastUpdate
  14 October 15:45:14 UTC (18:45:14 Istanbul), nextUpdate 15 October
  15:45:14 UTC (18:45:14 Istanbul), currently valid. This is the expected
  rejection/new-CRL observation; exact target entry/signature and a fresh
  Windows certificate-identity event are not yet captured, so final acceptance
  remains pending those checks.
- Desktop Commander reconnected after the requested server restart.
  Direct read at 18:58 confirms normal RADIUS active, PID 1274, Result=success;
  minute CRL timer active, last trigger 18:58:03, and sync oneshot Result=success
  (inactive after completion is normal). No assistant restart was performed.
- Source inspection for recovery: existing Windows client reports receipt for
  its installed certificate before deciding renewal. A revoked installed leaf
  receipt is rejected and handled as retry_pending; ordinary task reruns do not
  automatically create a fresh CSR in this case. Server issuance accepts a new
  key/CSR after a previously revoked leaf using fresh Kerberos/live AD/profile
  checks. Recovery will require a scoped administrative client-state reset,
  with guarded local backup and a new SYSTEM-task enrollment on an allowed
  bootstrap network. Do not clear config/trust, reuse the old CSR/key, un-revoke
  the old certificate or change working pilot 2GL13ZU.

## Pause checkpoint — 14 October 2026, 16:19 Europe/Istanbul

- Operator requested a Linux shutdown/start before executing the VV06
  certificate-revocation test. No revocation has yet been reported.
- Completed and retained: wired/wireless positive EAP-TLS/VLAN pilots, CRL
  synchronization fix, VV06 missing-certificate negative, GPO task/client
  certificate installation, positive wired/DHCP, pilot-group-out and disabled
  computer-account rejection with successful restoration.
- Exact next revocation target remains canonical serial
  d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9, VV06 GUID
  69b0d5cd-db61-4627-9db7-fcc5230152a3. Keep this certificate installed for
  the negative test; subsequent recovery uses fresh controlled enrollment.
- Last runtime CRL evidence is #20, valid until 15 October 09:03:32 Istanbul.
  Recheck active services/current CRL after boot before the panel revocation.
- Remote Desktop Commander reconnected for this checkpoint. Direct Linux
  os.sync completed successfully; kaname-lab.service, authwire-radius.service
  and authwire-radius-crl-sync.timer were each active/enabled. No service stop,
  certificate/policy mutation or shutdown was performed by the assistant.
- Work record and source are persisted in Git. This sync is not a newly
  created full data backup. Existing update backup remains the prior backup.

## Preservation requirements

Keep RADIUS process/unit/native module, policy conditions/VLANs, RADIUS client
secrets, AD connection, existing CA/certificates, Windows client and enrollment
package untouched by panel-only changes. Check actual process and file/state
preservation during deployment. Never record passwords, cookies, shared secrets,
private keys or keytabs in this record or test output.
