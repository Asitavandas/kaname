# KANAME

Bağımsız Active Directory tabanlı kablolu/kablosuz 802.1X erişim yönetimi.

**Teslim edilen sürüm: 0.2.0-dev.1 — mevcut temelin üzerine dahili PKI geliştirmesi.**
Yerel konsoldan root/issuer CA, RADIUS sunucu sertifikası ve imzalı CRL üretilebilir. Çalışan RADIUS hizmeti, AD bağlantısı, istemci enrollment veya açılabilir OVF bu pakette yoktur. Paneldeki ağ/politika kayıtları yalnızca taslaktır; ağda izin/ret kararı uygulanmaz.

## Başlatma

Python 3.12 veya üzeri gerekir. Panel ve politika çekirdeği ek Python paketi olmadan çalışır. Dahili PKI ve tam test seti için `cryptography==46.0.0` gerekir; bu sürüm geliştirme ortamında doğrulanan sürümdür. Nihai appliance bu bağımlılıkları içinde taşıyacak. ZIP'i açın, terminali bu README'nin bulunduğu `kaname` klasöründe açın:

```bash
python3 -m kaname
```

Windows'ta:

```powershell
py -3.12 -m kaname
```

Tarayıcıda `http://127.0.0.1:8765` adresini açın. Programın gösterdiği `kaname-state/access-token` dosyasının içeriğini giriş alanına yapıştırın. Bu yerel geliştirme anahtarıdır; domain parolanızı girmeyin. Durdurmak için terminalde Ctrl+C kullanın.

Dosyayı okumak için Linux/macOS: `cat kaname-state/access-token`; PowerShell: `Get-Content kaname-state/access-token`. Anahtar ve SQLite veritabanı yerelde oluşur; dağıtım paketinde bulunmaz. Bu veri klasörünü paylaşmayın. Panel yalnızca aynı bilgisayarın loopback adresinde dinler.

Farklı yerel port veya veri klasörü:

```bash
python3 -m kaname --port 8876 --state-dir ./kaname-state
```

## Bu sürümde yapılabilenler

| Alan | Mevcut davranış |
|---|---|
| Kurulum | Ürün DNS adı, AD domain/DC bilgileri, RADIUS istemci ad/IP bilgileri ve kablolu/kablosuz seçimleri dört adımda taslak olarak kaydedilir. |
| Politikalar | AD grup SID, erişim türü, NAS IP, EAP yöntemi, domain cihazı şartı, izin/ret ve VLAN modeli; panelde ekleme, sıralama, etkinleştirme, silme. |
| Karar testi | Örnek kimliklerle politika değerlendirmesi ve VLAN özniteliklerinin gösterimi. Gerçek doğrulama kanıtı üretmez. |
| Kayıt | SQLite kalıcılığı, çakışan sürüm kaydını engelleme ve yapılandırmayla aynı transaction içinde audit. |
| Dahili PKI | Yerel konsoldan benzersiz root/issuer CA, şifreli anahtarlar, kayıtlı FQDN için server-only sertifika, iptal ve imzalı CRL. Panel yalnız açık CA bilgilerini gösterir. |
| OVF araçları | Hazırlanmış temiz VMware VMX'inin dışa aktarımı için sarmalayıcı ve yerel OVF/VMDK/SHA256 manifest denetleyicisi. |

Policy API daha geniş modeli destekler; başlangıç panelindeki yeni politika formu EAP-TLS + domain cihazı şartı kullanır. Gerçek AD grup seçici sonraki aşamadadır.

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
- [Güvenlik sınırları](docs/SECURITY.md)
- [Doğrulama raporu](docs/TEST_REPORT.md)
- [Teknik kaynaklar](docs/SOURCES.md)

`kaname/` ürün çekirdeği ve paneldir; `tools/` paketleme/denetleme araçları; `appliance/` hedef sözleşmesi; `tests/` otomatik testlerdir. Geliştirme HTTP sunucusu üretim sunucusu olarak kullanılmayacaktır.

Kaynak paketini yeniden üretmek için: `python3 -m tools.package_source /absolute/output/KANAME-source.zip`. ZIP içindeki `SOURCE_MANIFEST.json` bütün kaynak dosyalarının SHA256 değerlerini içerir.
