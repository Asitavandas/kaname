# AuthWire kullanıcı kimliği ve merkezi Windows dağıtımı

Tarih: 26 Ekim 2026, Europe/Istanbul.
Durum: A03/A04 kapsamı açık. Güncel ilerleme kaydı: CURRENT_STATUS.md.
Bu belge mevcut kullanıcı kimliği ve merkezi dağıtım yol haritasını açıklar.

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
