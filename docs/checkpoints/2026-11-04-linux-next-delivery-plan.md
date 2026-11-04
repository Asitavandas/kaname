# Sonraki Linux teslimatı — hazırlık kaydı

Durum: **LINUX_DEV45_KURULDU_KABUL_EDILDI**. Doğrulanmış paketler canlı Linux'a uygulanıp kurulum sonrası
kaynak/HTTPS/ayar/yönetici, RADIUS PID ve taze yedek/veri restore kabulü tamamlandı. Kullanıcı sırası: son kaynak doğrulaması → sürüm/paket hazırlığı →
yedek/geri dönüş → kontrollü Linux güncellemesi ve kabul.

## Kaynak ve kapsam

- Ayrı yedek işçisi yükseltmesi PR135 ile kaynakta doğrulandı: `2cbd3771d8af81d12ed4230096bf33ba95d50206`.
  Üç ilgili PR workflow'u başarılı; merge `5d4a4c3710594caadc81e33a3d4fbca384ed8aaa`.
  Kanıt: `docs/checkpoints/2026-11-04-backup-worker-upgrade-source.json`.

- PR134 son test kaynağı: `53d35ab2867e684e6400d94f6b7eee5c6b88bfea`.
- PR134, aynı son kaynakta 12 workflow başarılı olduktan sonra
  `77612e798361187bbdd6e554bb488364f197da45` ile merge edildi.
  Önceki SHA'nın yeşil koşusu son SHA'nın yerine kullanılmadı.
- Linux teslim adayı **0.14.0-dev.45** PR136 ile hazırlandı. Test edilen kaynak
  `c5241e55c7728da239070bbe8f9c841043f54cde`, merge `965ac305d1a67e992f56246adecfdcedfde4d089`.
  Yedi ilgili workflow başarılı; 296 kaynak dosyası içeren panel paketi ve
  ayrı yedek işçisi paketi iki bağımsız üretimde byte bazında aynı çıktı.
  Paket ve manifest SHA256'ları `docs/checkpoints/2026-11-04-linux-dev45-delivery.json`
  kaydındadır. İndirme: https://github.com/Asitavandas/kaname/actions/runs/41895297932/artifacts/13354438976
  (2027-02-02 tarihine kadar). Yeni Linux sürümü kontrollü olarak canlıya uygulandı; kabul kaydı
  `docs/checkpoints/2026-11-04-linux-dev45-live-acceptance.json` içindedir.
- Güncel canlı Linux sürümü 0.14.0-dev.45'tir. Önceki dev.44 geri dönüş kodu ve
  durum/ayar kopyaları korundu; taze canlı servis/HTTPS/yedek kabulü yapıldı.
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

PR133'ün yedek karşılaştırma düzeltmesini bu bileşene taşımak için ayrı
`tools/backup_upgrade.py` yolu PR135 ile hazırlandı ve kaynakta doğrulandı.
Kurulu release ve aday manifest hash'leri, iş/güncelleme kilitleri, atomik
kaynak değişimi, izole veri restore'u ve yalnız bilinen koda geri dönüş kabul
edildi. Mevcut arşiv/koşu kayıtları, timer durumu ve kapalı RADIUS dahil ürün
PID'leri gerçek disposable systemd ortamında korundu. Aynı yedek işçisi yolu canlıda da
başarıyla uygulandı; yeni sürümün gerçek hardened yedek hizmeti ve izole veri
restore kabulü tamamlandı.

## Canlı kabul kaydı

Teslimden önce gerçek kaynak sürümü, kurulum sahipliği, servis/HTTPS durumu ve
son kullanılabilir yedek ölçülür. Gizli anahtarlar, AD/RADIUS parolaları ve
tam ayar/veri içerikleri rapor çıktısına alınmaz.

Teslim sonrası sürüm/hash/HTTPS, ayar-yönetici-PKI korunması, RADIUS'un önceki
çalışma durumu ve varsa ayrı yedek işçisi sürümü doğrulanır. Windows gMSA/AD/
domain-SYSVOL/endpoint, gerçek reboot ve dış restore kabulü ayrıca izlenir.

## Tamamlanan işlem — canlı ön kontrol ve kontrollü Linux kurulumu

Gerçek sürüm/Ubuntu-Python, HTTPS, mevcut yedek hash/tazelik, paket hash'leri ve
boş alan taze doğrulandı. Yedek işçisi önce, panel sonra güncellendi; RADIUS ve
service-control PID'leri korundu. Manifestteki 296 kaynak dosyası aynı; yeni
sürümün taze yedeği ve 18 izole veri restore kontrolü başarılı. Ayrıntı yukarıdaki
canlı kabul kaydındadır. Tam OS boot restore ve harici yedekten kabul ayrı kalır.

## Sıradaki işlem — kablolu pilot ve Windows teslim kapıları

Gerçek Windows istemcisinin kablolu EAP-TLS sonucunu yeniden doğrula. Yeni
Windows SDK'sı panel güncellemesiyle aktif worker'a kaydedilmiş sayılmaz;
gMSA/AD/SYSVOL/endpoint ve imzalı Windows teslimi kendi kapılarında izlenir.
Kablolu başarıdan önce kablosuz pilota geçilmez.
