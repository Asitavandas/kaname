# AuthWire kullanıcı kimliği ve merkezi Windows dağıtımı

Tarih: 24 Ekim 2026, Europe/Istanbul.
Durum: A03/A04 kapsamı açık. Güncel ilerleme kaydı: CURRENT_STATUS.md.
Bu belge mevcut kullanıcı kimliği ve merkezi dağıtım yol haritasını açıklar.

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
