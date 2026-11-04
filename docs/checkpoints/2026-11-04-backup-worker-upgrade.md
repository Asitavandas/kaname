# Ayrı yedek işçisi yükseltmesi — kaynak kabul kaydı

Durum: **KAYNAK_TEST_ASAMASINDA**. Canlı Linux/DC01'e dosya aktarılmadı veya
servis işlemi uygulanmadı. Linux sürümü ve teslim manifesti henüz atanmadı.

## Neden ayrı bir yol gerekiyor?

Panel kaynak güncelleyicisi `/opt/authwire-backup` kurulumunu değiştirmez.
Tarihsel `tools/backup_install.py` aynı byte'lar için idempotenttir; farklı
işçi sürümünü reddeder. Eski kurucu ve onun mevcut güven/hash kayıtları korunur.
Yeni `tools/backup_upgrade.py` yalnız bu ayrı bileşenin kaynak yükseltmesidir.

## Uygulanan kontroller

- Operatörün dışarıdan doğruladığı aday manifest SHA256'sı ve taze ölçülmüş
  kurulu `release.json` SHA256'sı zorunludur. İki scriptin hash'i, kök sahipliği,
  izinleri, dosya türleri ve tam üye kümesi doğrulanır. Link/ek dosya reddedilir.
- `inspect` aday kodunu çalıştırmadan, dosya/servis değişikliği yapmadan raporlar.
  Gerçek işlem aynı ölçümleri kilitler altında yeniden kontrol eder.
- Mevcut işçi sırasıyla `.job.lock` ve ortak güncelleme kilidini kullanır.
  Yükseltici de aynı sırayı, özel ve mevcut kilitlerle izler. Meşgul işçi veya
  aktif/transitional backup service varken işlemi reddeder; lock silmez.
- Yalnız bilinen tam unit byte'ları, etkin fragment yolu ve drop-in olmayan
  kurulum kabul edilir. Özel/değişmiş veya masked unit operatör incelemesi
  gerektirir; yükseltici unit yazmaz, daemon-reload/enable/disable yapmaz.
- Başlangıçta aktif timer kısa süre durdurulur; başlangıçta kapalı timer
  başlatılmaz. Timer ancak kilitler bırakıldıktan sonra eski durumuna alınır.
  Böylece normal catch-up yedeği kilide çarpmaz. Ürün servisleri yönetilmez;
  kapalı RADIUS PID=0 dahil önceki PID'ler karşılaştırılır.
- Aynı dosya sisteminde Linux `renameat2(RENAME_EXCHANGE)` ile iki dizin
  atomik değiştirilir. Kurulu yol hiçbir anda kaybolmaz. Dosya/dizin izinleri
  operatörün umask değerinden bağımsız korunur. Değişim sonrası fsync hatası
  olsa bile mevcut inode/hash kimliği tekrar ölçülerek geri dönüş belirlenir.
- Yeni işçi özel işlem dizinine gerçek arşiv üretir; aday offline checker
  bu arşivden izole veri geri yükleme ve PKI/vault doğrulaması yapar. Normal
  scheduled worker/run/retention çağrılmaz. Mevcut planlı arşivler ve
  last-run/last-success kayıtlarının değişmediği ölçülür.
- Ürün dosya hash'leri, yönetici/iş verisi DB parmak izleri ve PID'ler korunur.
  Yeni veri değişikliği varsa DB geri yüklenmez. Bilinen eski/yeni kaynaklar
  güvenle eşleşiyorsa yalnız kod geri alınır; yabancı/belirsiz kaynak üstüne
  yazılmaz. Timer/finalization belirsizliği başarı sayılmaz.
- Eski kaynak, aday kaynak, bakım arşivi, ön ölçümler ve sonuçlar root'a özel
  `/opt/authwire-backup-upgrades/<operation>` altında tutulur. Otomatik prune,
  reset veya crash-resume yoktur. Eksik terminal kaydı sonraki yükseltmeyi
  engeller; en fazla 64 işlem kaydında ayrıca inceleme gerekir.

## Kabul ve sınırlar

Yerel root testleri gerçek dosyalar, flock ve atomik dizin değişimi üzerinde
hata enjeksiyonu yapar; systemctl ve fixture bakım kontrolü bu testlerde
taklittir. Ayrı GitHub-hosted Ubuntu 24.04 kabulü gerçek systemd, şifreli fixture
PKI, aktif/kapalı timer ve kapalı RADIUS ile yükseltmeyi çalıştırır. Ardından
yeni işçiyi gerçek kısıtlı backup.service üzerinden de çalıştırır. CI sonucu
geldikten sonra kesin kaynak SHA'sıyla bu kayıt güncellenecektir.

Bakım arşivinden izole veri geri yüklemesi tam makine boot restore'u, harici
yedek kabulü veya canlı müşteri ortamı kabulü değildir. Tutulan bakım arşivi
gizli veriler içerebilir; içerikleri stdout/rapor çıktısına basılmaz.

## Operatör akışı (henüz canlıya uygulanmayacak)

1. Kesin kaynak/araç SHA256'sını ve iki scriptlik paket manifestini doğrula.
   Aday stage root'a ait, üst dizinleri korunan bir konumda olmalıdır; world
   writable `/tmp` stage'i bu yükseltici için kabul edilmez.
2. Kurulu release hash'i, servis/timer durumu ve son kullanılabilir yedeği taze
   ölç. `inspect --source-dir <stage> --manifest-sha256 <aday-hash>
   --installed-release-sha256 <kurulu-hash>` ile salt okunur kontrolü tamamla.
3. Bakım sırasında aynı parametrelerle `upgrade` ve
   `--acknowledgment upgrade_observed_backup_worker_preserve_archives_and_service_state`
   kullan. Pinned araç mevcut güvenilir AuthWire Python'u ile `-I -B` çalıştırılır.
4. Çıkış kodu 0 başarı/zaten güncel; 2 doğrulanmış kod geri dönüşü; 1 ret veya
   inceleme gerektiren durumdur. JSON `requires_review` alanını kontrol et.
   Eksik/belirsiz kayıtları otomatik silme veya kilitleri kaldırma.

Bu adım Linux teslim kapısının bir alt işidir. 54/94 makro toplamı değişmez;
panel sürüm/paket oluşturma, canlı ön kontrol ve kontrollü kurulum ayrı kalır.
