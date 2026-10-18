# AuthWire current work record

Updated: 18 October 2026, Europe/Istanbul. This record supplements the 9 October
`AuthWire_Durum_ve_Tamamlama_Raporu_2026-10-09.docx` / `.pdf`; those reports are a
dated baseline. Use this record when producing their next requested revision.
The operator requested ongoing tracking; on 15 October at16:52 requested a
pause checkpoint and an updated report with red check marks against 9 October.

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
