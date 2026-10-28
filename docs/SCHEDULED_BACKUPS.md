# AuthWire planlı özel yedekleme

Bu bileşen panel/RADIUS kodunu veya çalışan kimlik ayarlarını değiştirmeden,
ayrı bir root oneshot ve systemd timer kurar. Ürün sürümü dev.6 kalır.
Gerçek saha kurulum kabulü [CURRENT_STATUS.md](CURRENT_STATUS.md) içinde tutulur.

## Varsayılan çalışma

- Her gece03:15 Europe/Istanbul; en fazla300sn rastgele gecikme ve30sn doğruluk.
  Persistent=yes ile kapalıyken kaçırılan çalışma açılışta telafi edilebilir.
- Son14 başarılı **planlı çalışmanın** arşivi tutulur. Elle aynı servisi
  başlatmak da bu sayıya dahildir; bu garanti14 takvim günü anlamına gelmez.
- Yeni hedef /var/backups/authwire/scheduled, root0700; arşiv/JSON/lock0600.
  Önceki authwire-pause ve upgrade yedekleri saklama temizliğine dahil değildir.
- Root-owned kod /opt/authwire-backup; mevcut Python venv kullanılır.
  authwire-backup.service ağ erişimini AF_UNIX ile sınırlar, bütün dosya
  sistemini salt okunur açar ve yalnız yedek hedefinde yazmaya izin verir.
  CAP_DAC_READ_SEARCH başka uid'ye ait özel uygulama verisini okumak içindir.
  Çalışma düşük CPU/IO önceliklidir; servis durdurma/restart komutu içermez.

## Kapsam ve bütünlük

Panel ayarları, bütün durum DB'leri, CA/Issuer/vault/keytab, web/RADIUS anahtarları,
sertifikalar, kaynak, venv/native runtime, broker kod/geçmişi, servis unit/drop-in'leri,
yedek aracı ve boot-time shared lock tanımı arşive alınır. İstemci CNG özel
anahtarları sunucuda olmadığından bu yedeğe girmez. Runtime linkleri link olarak
saklanır; bu, bağımlı OS paketlerinin veya tam boot kurtarmasının kabulü değildir.

SQLite backup API ile her DB ayrı, tutarlı bir snapshot olarak alınır;
integrity_check ve foreign_key_check uygulanır. Bütün arşiv üyelerinin byte/hash,
uid/gid/izinleri ve dosya türleri, arşiv EOF okunarak doğrulanır. Canlı iş verisinin
before/copy/after fingerprint'i ve dosya envanteri eşleşmezse en çok3 deneme
yapılır; tutarlı arşiv yayınlanmadan eski yedek temizlenmez. Disk alanı ön koşulu
iki kat tahmini veri boyutu +512MiB'dir; hiçbir canlı DB'ye yazılmaz.

Normal oturum/audit/rate-limit/challenge/directory-cache tabloları ve
directory_health satırı kararlılık karşılaştırmasının dışında kalır. Ayrıca tam adı bilinen\nwindows_connector_probe_jobs, windows_candidate_verify_jobs ve windows_deployment_scope_jobs\nv1 runtime kayıtlarında yalnız geçerli polls/last_poll transport metadata'sı karşılaştırmada\nnormalize edilir; jobs/target/lease/result ve diğer bütün kayıtlar korunur. Bilinmeyen format,\nek alan, bozuk/duplicate-key JSON veya hatalı metadata ham haliyle guard içinde kalır; **yine
de snapshot içine kopyalanırlar**. Policy, yönetici/profil, CA/sertifika/iptal,
enrollment ve diğer kalıcı iş tabloları karşılaştırılır. Bu model servisleri
durdurmadan iş durumunun kararlılığını denetler; bütün DB'lerin tek global
transaction anında çekildiği iddiası değildir. İlk kurulum ayrıca gerçek yeni
arşivde izole PKI/vault/veri geri yükleme provası yapmadan timer'ı açmaz.

Shared update lock yükseltme/broker müdahalesiyle çakışmayı, ayrı job lock çift
yedeklemeyi engeller. Boot-time lock mevcut, doğrulanmış broker tmpfiles
tanımından gelir. Eksik/değiştirilmiş kurulum üzerine yazılmaz.

Saklama yalnız bu araç üreticisine ait geçerli manifest/arşiv adlarını kapsar;
bilinmeyen/orphan dosyalar korunur. Silinecek eski arşivlerin bütün SHA'ları
silmeden önce doğrulanır. Kayıp/bozuk dosya durumunda kör temizlik yapılmaz.

## Durum ve işletim

```bash
systemctl list-timers --all authwire-backup.timer
systemctl status authwire-backup.timer authwire-backup.service --no-pager
sudo cat /var/backups/authwire/scheduled/last-run.json
sudo cat /var/backups/authwire/scheduled/last-success.json
sudo journalctl -u authwire-backup.service -n 20 --no-pager
```

Oneshot servis iş bitince inactive/dead ve Result=success olabilir; timer etkin
kalır. last-run son sonucu, last-success son başarılı arşivi gösterir. Kayıtlar
sır veya SQL değerleri içermez. Yedek verilerinin kendisi özel anahtar ve parolaya
eşdeğer malzeme taşır; arşivler sohbet eki değildir. Disk tamamen dolarsa özel
durum dosyası da yazılamayabilir; systemd sonucu ve journal ayrıca kontrol edilir.
Bildirim/e-posta veya panelde yeni yedek menüsü bu ilk kurulumun kapsamı değildir.

Gerekirse normal bir planlı işi şimdi çalıştırmak için:

```bash
sudo systemctl start authwire-backup.service
```

Yalnız sonraki otomatik çalışmaları kapatmak için:

```bash
sudo systemctl disable --now authwire-backup.timer
```

İlk kurulum kaynak/manifest pinlerini doğrular; ilk yedek+izole veri restore ve
korunan dosya/iş durumu/PID karşılaştırması başarılı olunca timer açılır.
Hata halinde yalnız bu kurulumun eklediği feature unit/kodları geri alınır;
oluşmuş yedekler tanılama için korunur. Mevcut farklı unit/kod üzerine yazılmaz.

## Açık kalan kabul kapıları

Bu yerel arşiv kendi başına sunucu/disk kaybına karşı ikinci kopya değildir.
Şifreli off-host aktarım için ayrı hedef, erişim ve saklama düzeni belirlenecek.
İlk canlı kurulum sonucu ve ertesi doğal takvim çalışması ayrıca kaydedilir.
Tam OS/runtime boot, rollback ve bağımsız appliance import kabulü bu alt işten
ayrıdır. Gerçek felaket kurtarması [OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md)
içindeki güncel iptal durumuyla uzlaştırma kapılarına tabidir.
