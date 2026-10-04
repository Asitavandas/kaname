# KANAME

Bağımsız Active Directory tabanlı kablolu/kablosuz 802.1X erişim yönetimi.

**Kaynak geliştirme sürümü: 0.11.0-dev.1 — kompakt bakır/krem panel.**

Arayüz yenilendi: #F5EFEB arka plan, #2B2B2B sol menü ve #C88565 menü yazıları/ikonları. Türkçe gezinme, genel bakış, menü araması, sertifika sekmeleri ve kapatıldığında parolaları/CSR alanını temizleyen sağ form paneli bulunur. API ve AD/politika/CA davranışı korunur. Yalnız PEM CSR dosyası forma alınır; özel anahtar dosyası reddedilir. [Tema kapsamı ve doğrulama](docs/PANEL_0_11_0.md).
Ubuntu geliştirme hedefidir. Mevcut politika, VLAN, RADIUS istemci ve AD eşitleme ayarları korunur. Privileged HTTPS kayıt akışı, imzalı endpoint CSR'sini kullanıcının kendi Kerberos kimliği, güvenli LDAP Who Am I ve canlı GUID/tokenGroups sorgusuyla doğrular; sertifika ve değişmez AD bağı aynı transaction'da kaydedilir. Panelden CA oluşturma, kullanıcı sertifikası üretme/indirme, açık trust/CRL indirme ve iptal mümkündür. Endpoint anahtarı panele gönderilmez. Kullanıcı sertifikası domain bilgisayarı kanıtı değildir; mevcut require_domain_device kuralları kullanıcı sertifikasını reddeder.

Çalışan Ubuntu paneli yerel doğrulanmış güncelleme uygulanana kadar 0.8 olarak kalır; Windows kurulumu korunur ve otomatik Windows sunucu testleri kapalıdır. Müşteri ağında RADIUS/accounting, bilgisayar enrollment, otomatik trust/GPO dağıtımı ve açılabilir OVF henüz etkin değildir. [0.10 kullanım ve kabul sınırları](docs/STATUS_0_10_0.md).

## Başlatma

Python 3.12 veya üzeri gerekir. Panel ve politika çekirdeği ek Python paketi olmadan çalışır; Linux geliştirme ortamında korumalı bağlantı kaydı için cryptography gerekir. Windows kayıtları DPAPI kullanır. Dahili PKI ve tam test seti için `cryptography==46.0.0` gerekir; bu sürüm geliştirme ortamında doğrulanan sürümdür. Nihai appliance bu bağımlılıkları içinde taşıyacak. ZIP'i açın, terminali bu README'nin bulunduğu `kaname` klasöründe açın:

```bash
python3 -m kaname
```

Windows'ta:

```powershell
py -3.12 -m kaname
```

Tarayıcıda `http://127.0.0.1:8765/` adresini açın. İlk kurulumda kullanıcı adı **admin**, parola **Kaname** ile giriş yapın; harflerin büyüklüğü parolada önemlidir. Günlük panel girişi için PowerShell veya token gerekmez. Panel giriş hesabı AD hesabından bağımsızdır. Üstteki **Parolamı değiştir** düğmesiyle kendi parolanızı değiştirebilirsiniz. Durdurmak için terminalde Ctrl+C kullanın.

**System → Administrators** altında kullanıcı ekleme/düzenleme/silme ve profil atama; ayrı **System → Admin Profiles** sekmesinde SuperAdmin, Admin_ReadOnly ve menü/sekme başına Custom yetkiler bulunur. Ayrıntılar [yönetici kullanım kılavuzunda](docs/ADMINISTRATION.md).

Hesaplar, oturumlar ve ayarlar `kaname-state/` içinde yerelde oluşur; kaynak paketine eklenmez. Panel yalnız aynı bilgisayarın loopback adresinde dinler. Yerel bakım araçlarının mevcut access-token dosyası korunur; tarayıcı girişinde kullanılmaz.

Farklı yerel port veya veri klasörü:

```bash
python3 -m kaname --port 8876 --state-dir ./kaname-state
```

## Bu sürümde yapılabilenler

| Alan | Mevcut davranış |
|---|---|
| Kurulum | Ürün DNS adı, AD domain/DC bilgileri, RADIUS istemci ad/IP bilgileri ve kablolu/kablosuz seçimleri dört adımda taslak olarak kaydedilir. |
| Politikalar | AD grup adını listeden seçme (SID içeride saklanır), erişim türü, NAS IP, EAP yöntemi, domain cihazı şartı, izin/ret ve VLAN modeli; panelde ekleme/düzenleme/silme; sıra bağımsız karar ve çakışan kayıtları engelleme. |
| System | Yerel kullanıcı/parola girişi, düzenlenebilir/silinebilir yönetici hesapları ve SuperAdmin/Admin_ReadOnly/Custom profiller; menü ve sekme düzeyinde sunucu tarafında yetki denetimi. |
| Karar testi | Örnek kimliklerle politika değerlendirmesi ve VLAN özniteliklerinin gösterimi. Gerçek doğrulama kanıtı üretmez. |
| Kayıt | SQLite kalıcılığı, çakışan sürüm kaydını engelleme ve yapılandırmayla aynı transaction içinde audit. |
| Dahili PKI | Yerel konsoldan benzersiz root/issuer CA, şifreli anahtarlar, kayıtlı FQDN için server-only sertifika, iptal ve imzalı CRL. Panel yalnız açık CA bilgilerini gösterir. |
| Active Directory | User&Authentication → Active Directory altında bağlantı; Users/User Groups altında aynı ekranda iki ayrı liste ve tıklanabilir üyelik detayları. Kerberos korumalı LDAP, nesne/üye sayfalama, primary ve iç içe üyelik; politikaya yalnız security grubu seçimi. Kayıtlı bağlantı parolası korumalı saklanır; OU/CN/DC konumu, manuel/periyodik eşitleme ve bağlantı uyarıları vardır. AD değişikliği yapılmaz. |
| Network | Ad/ID/açıklamalı VLAN tanımları; RADIUS cihaz kaynak IP ve korumalı shared secret; Authentication/Accounting UDP portları varsayılan 1812/1813. Cihaz ayarları manuel uygulanır. |
| RADIUS protokol laboratuvarı | İzole loopback ortamında native EAP-TLS, sertifika-kimlik eşlemesi, politika motoru ve bütünlüğü doğrulanan gerçek Accept/Reject/VLAN yanıtları. Dizin verisi fixture'dır; production service veya enrollment açılmaz. |
| OVF araçları | Hazırlanmış temiz VMware VMX'inin dışa aktarımı için sarmalayıcı ve yerel OVF/VMDK/SHA256 manifest denetleyicisi. |

Policy API daha geniş modeli destekler; yeni politika formu EAP-TLS + domain cihazı şartı kullanır. **AD grup kısıtı yok** seçilirse yalnız grup üyeliği koşulu kaldırılır; diğer politika koşulları geçerlidir. Grup seçmek kullanıcı/cihazın o grupta olduğunu veya EAP oturumunu doğrulamaz. Ayrıntılar [AD laboratuvar akışında](docs/AD.md).

## Testler

PKI bağımlılığı geliştirme ortamında yoksa önce yükleyin (internetsiz ortamda önceden temin edilmiş, doğrulanmış wheel paketleri kullanılmalıdır):

```bash
python3 -m pip install cryptography==46.0.0
```

```bash
python3 -m unittest discover -s tests -t . -v
python3 -m compileall -q kaname tools tests
```

Tarayıcı akış testi için Node.js ve Playwright/Chromium bulunan geliştirme ortamında:

```bash
node tools/ui_smoke.cjs
```

Bu test geçici veri klasörü ve rastgele port kullanır; müşteri ayarı içermez. Bağımlılıklar appliance çalışma zamanı için zorunlu değildir.

Native RADIUS protokol kontrolü `.github/workflows/radius.yml` içinde sabit FreeRADIUS 3.2.10 kaynak commit'i ve eapol_test ile çalışır. Kimlik bağlama sınırları normal unittest'e dahildir; gerçek paket testi ayrı Linux işidir. Ayrıntılar ve sonraki domain laboratuvarı [RADIUS protokol kanıtında](docs/RADIUS_PROTOCOL.md).

## Dağıtım hedefi

Son ürünün teslimi `.ovf + .vmdk + .mf` paketi olacaktır. İlk doğrulama hedefi VMware vSphere/ESXi'dir. Her kurulum kendi yönetici erişimini, makine kimliğini ve anahtarlarını üretmelidir. Başka ürüne, bulut servisine veya ayrı CA sunucusuna çalışma bağımlılığı olmayacaktır. AD, DNS ve doğru saat erişimi kurumsal ağdan sağlanır.

OVF bütün hypervisor'larda aynı şekilde içe aktarılmaz. Diğer hedefler için gerçek içe aktarma ve açılış kanıtı gerekir. Ayrıntılar [appliance planında](docs/APPLIANCE.md).

## Geliştirme belgeleri

- [Kapsam ve kabul şartları](docs/REQUIREMENTS.md)
- [Mimari ve NPS eşlemesi](docs/ARCHITECTURE.md)
- [Aşamalı çalışma planı](docs/ROADMAP.md)
- [Dahili CA ve sunucu sertifikası denemesi](docs/PKI.md)
- [Bağlantı sonrası devam kaydı](docs/RESUME.md)
- [OVF üretim ve dağıtım sözleşmesi](docs/APPLIANCE.md)
- [AD kullanıcı/grup üyelikleri](docs/DIRECTORY_MEMBERSHIP.md)
- [Gerçek RADIUS/EAP-TLS protokol kanıtı](docs/RADIUS_PROTOCOL.md)
- [Yönetici hesapları ve profiller](docs/ADMINISTRATION.md)
- [Güvenlik sınırları](docs/SECURITY.md)
- [Doğrulama raporu](docs/TEST_REPORT.md)
- [Teknik kaynaklar](docs/SOURCES.md)

`kaname/` ürün çekirdeği ve paneldir; `tools/` paketleme/denetleme araçları; `appliance/` hedef sözleşmesi; `tests/` otomatik testlerdir. Geliştirme HTTP sunucusu üretim sunucusu olarak kullanılmayacaktır.

Kaynak paketini yeniden üretmek için: `python3 -m tools.package_source /absolute/output/KANAME-source.zip`. ZIP içindeki `SOURCE_MANIFEST.json` bütün kaynak dosyalarının SHA256 değerlerini içerir.

0.7 kullanım ve doğrulama kapsamı: [STATUS_0_7_0](docs/STATUS_0_7_0.md). Periyodik AD işleri panel süreci çalışırken yürür. Üretim boot servisi ve açılabilir OVF sonraki aşamadır.

Ubuntu 0.8 laboratuvar kurulumu ve kabul sınırı: [LINUX_SETUP_0_8_0](docs/LINUX_SETUP_0_8_0.md). Bu ilk kurulum aracıdır; mevcut kurulumları silmez/resetlemez. Üretim RADIUS ve OVF kabulü ayrı aşamadır.

0.9 kaynak ve gerçek AD yetki sorgusu kontrolü: [STATUS_0_9_0](docs/STATUS_0_9_0.md). Çalışan Ubuntu 0.8 paneli güncellenmez; tanılama mevcut bağlantıyı kullanır ve özet sonuç dışında kimlik bilgisi yazdırmaz.
