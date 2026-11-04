# AuthWire Linux teslim paketleri

Bu akış sürüm ve kaynak doğrulaması yaparak **teslim adayı** üretir. Paket
oluşturulması veya CI kabulü Linux'a kurulum uygulamaz. Canlı ön ölçüm, mevcut
yedek doğrulaması, kontrollü kurulum ve sonrasındaki kabul ayrıca yürütülür.

## Sürüm ve kaynak

Yeni teslim sürümü **0.14.0-dev.45**. Son bilinen canlı dev.44 sürümü bu belgeyle
güncellenmiş sayılmaz. Ürün VERSION ve pyproject sürümü aynı olmalıdır.
Paketleyici exact Git commit'i zorunlu tutar, temiz checkout ve seçilmiş her
dosyanın özgün Git blob hash'ini doğrular. Kod ağacı eksik/kirli, symlink veya
gizli durum dosyası içeriyorsa çıktı üretmez. Paketleme sürüm modülünü çalıştırmaz.

Tam checkout üzerinde örnek üretim (kurulum yapmaz):

```bash
python -B -m tools.package_linux_delivery --source . --expected-commit <40-karakter-commit> --destination <yeni-cikti-dizini>
```

`.github/workflows/linux_delivery.yml` PR head'ini açıkça checkout eder; PR'ın
merge ref'i ile kaynak commit'ini karıştırmaz. Aynı kaynaktan iki bağımsız üretim
yapılır ve bütün çıktı byte'ları karşılaştırılır. Başarılı adaylar workflow'un
`authwire-linux-<commit>` artifact'ında 90 gün tutulur. Süre dolarsa aynı kesin
kaynak yeniden üretilebilir; yeni kaynak eski hash'lerin yerine kullanılamaz.

## Çıktılar

| Dosya | İçerik ve doğrulama |
|---|---|
| `AuthWire-0.14.0-dev.45-linux-source.zip` | `linux-source/` altında commit'teki kaname, tools, tests ve pyproject kaynakları. `LINUX_SOURCE_MANIFEST.json`, mevcut Linux güncelleyicisinin kabul ettiği tam şema ve dosya hash'lerini taşır. |
| `AuthWire-0.14.0-dev.45-backup-worker.zip` | `backup-worker/` altında yalnız iki işçi scripti ve manifest; `backup-upgrade/` altında ayrı yükseltici. Panel kurulumu bu bileşeni kendiliğinden güncellemez. |
| `DELIVERY.json` | Kaynak commit'i, sürüm, iki ZIP'in hash'i, iç manifest pinleri, yükseltici hash'i ve Windows istemci kaynak hash'leri. |
| `SHA256SUMS` | İki ZIP ve DELIVERY.json için SHA256. |

ZIP zaman damgaları ve üye sırası sabittir; zlib sürüm farklarından kaçınmak için
ZIP üyeleri sıkıştırılmadan saklanır. Her üyenin geri okunan byte'ı ve CRC'si
doğrulanır. Kaynak/dosya hash'i bütünlük sağlar; SHA256SUMS dosyasının kendisini
güvenilir kaynaktan almak gerekir. Bu paketler imzalı müşteri appliance teslimi
veya Windows Connector'ın yeni SDK'sını aktif servise kaydetme kabulü değildir.
Windows istemci scriptleri bu sürüm hazırlığında değiştirilmez.

## Kurulumdan önce ayrı kapılar

1. Teslim adayının **aynı commit'inde** genel ürün, paketleme ve ilgili kabul
   testleri başarılı olmalıdır. Paket üretimi tek başına kurulum izni değildir.
2. Canlı Linux sürümü, dosya sahipliği, mevcut servis/PID/timer durumu, HTTPS ve
   son kullanılabilir yedek taze ölçülür. Kapalı RADIUS başlatılmaz.
3. Panel kaynak paketi dış manifest piniyle mevcut `tools/linux_update.py`
   üzerinden kontrollü uygulanır. Eski kod ve durum yedeği korunur; başarısız
   sağlık kontrolünde kod geri dönüşü vardır, DB sessizce eskiye alınmaz.
4. Ayrı yedek işçisi gerekirse `tools/backup_upgrade.py` ile kendi manifest ve
   kurulu release pinleri kullanılarak yükseltilir. Stage, root'a ait korunan
   yeni bir dizinde olmalı; indirilmiş ZIP'i açmak dosya sahipliğini kendiliğinden
   doğrulamış sayılmaz. Önce salt okunur `inspect` yapılır. Kapsam ve ret/geri
   dönüş kuralları `checkpoints/2026-11-04-backup-worker-upgrade.md` içindedir.
5. Kurulum sonrası sürüm/hash/HTTPS, ayar-yönetici-PKI, önceki RADIUS durumu ve
   yedek işçisi/timer kabulü kaydedilir. Gerçek AD/GPO/SYSVOL/endpoint, reboot
   ve harici yedekten tam makine restore kabulü ayrı kalır.

Paketleyici servis, AD, RADIUS, ağ veya canlı dosya yollarında işlem yapmaz.
