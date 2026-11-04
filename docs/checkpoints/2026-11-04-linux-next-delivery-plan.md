# Sonraki Linux teslimatı — hazırlık kaydı

Durum: **KAYNAK_DOGRULANDI_PAKET_HAZIRLANMADI**. Linux'a kurulum, dosya aktarımı veya servis işlemi
başlatılmadı. Kullanıcı sırası: son kaynak doğrulaması → sürüm/paket hazırlığı →
yedek/geri dönüş → kontrollü Linux güncellemesi ve kabul.

## Kaynak ve kapsam

- PR134 son test kaynağı: `53d35ab2867e684e6400d94f6b7eee5c6b88bfea`.
- PR134, aynı son kaynakta 12 workflow başarılı olduktan sonra
  `77612e798361187bbdd6e554bb488364f197da45` ile merge edildi.
  Önceki SHA'nın yeşil koşusu son SHA'nın yerine kullanılmadı.
- Kurulacak Linux sürüm numarası, kesin merge kaynağı ve manifest SHA256'sı
  paket hazırlığında atanır; henüz Linux teslim paketi oluşturulmadı.
- Son bilinen canlı Linux sürümü 0.14.0-dev.44'tür. Bu kayıtta canlı sürüm,
  servis durumu, yedek tazeliği veya erişim yeniden ölçülmedi.
- Windows Connector'ın yeni history/rollback SDK'sı panel güncellemesiyle
  etkinleşmiş sayılmaz. Aktif worker, imzalı teslim ve gerçek kabul ayrı kapıdır.

## Panel güncelleyicisinin mevcut kontrolleri

`tools/linux_update.py`, beklenen `LINUX_SOURCE_MANIFEST.json` hash'ini ve her
dosyanın hash'ini doğrular. Ubuntu 24.04, root'a ait değiştirilemez kurulum
ağacı, özel durum/ayar dizinleri ve güvenilen mevcut servis şarttır.
Aday bağımlılık importu servis durdurulmadan mevcut venv'de sınanır.

Panel durdurulduktan sonra durum/ayar/servis ve eski kaynak yedeklenir.
Yeni kaynak HTTPS sağlık kontrolünde sürüm ve Windows istemci kaynak hash'iyle
doğrulanır. Yönetici/ayar/vault/PKI koruma özeti karşılaştırılır. Hata olursa
önceki kod geri alınır; yeni operatör verisini silmek için eski DB sessizce
geri yüklenmez. Bu mekanizma tam OS veya harici yedekten boot restore kabulü
yerine geçmez.

RADIUS'un panel duruşundan etkilenip etkilenmeyeceği bağımlılık kontrolüyle
belirlenir. Aktif RADIUS PID'si korunmalıdır; durmuş RADIUS başlatılmaz.
Eski dictionary yolu için servis göçü gerekiyorsa mevcut updater yalnız
devre dışı/durmuş legacy unit üzerinde bunu kabul eder. Canlı durum varsayılmaz.

## Ayrı yedek işçisi teslim kapısı

Planlı yedek işçisi `/opt/authwire-backup` altında ayrı kurulur. Panel kaynak
güncellemesi bu çalışan bileşeni değiştirmez. Mevcut `tools/backup_install.py`
yalnız tam aynı dosya/unit içeriğinde idempotenttir; kurulu işçi byte'ları yeni
paketten farklıysa reddeder.

Bu nedenle PR133'ün yedek karşılaştırma düzeltmesini bu bileşene taşımak için
ayrı, doğrulanmış sürüm yükseltme yolu hazırlanmalıdır. Mevcut arşivler,
başarılı/başarısız koşu kayıtları, timer durumu ve çalışan ürün süreçleri
korunmalıdır. Bu yükseltme yolu henüz hazırlanmış veya uygulanmış sayılmaz.

## Canlı kabul kaydı

Teslimden önce gerçek kaynak sürümü, kurulum sahipliği, servis/HTTPS durumu ve
son kullanılabilir yedek ölçülür. Gizli anahtarlar, AD/RADIUS parolaları ve
tam ayar/veri içerikleri rapor çıktısına alınmaz.

Teslim sonrası sürüm/hash/HTTPS, ayar-yönetici-PKI korunması, RADIUS'un önceki
çalışma durumu ve varsa ayrı yedek işçisi sürümü doğrulanır. Windows gMSA/AD/
domain-SYSVOL/endpoint, gerçek reboot ve dış restore kabulü ayrıca izlenir.
