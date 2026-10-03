# Windows lab panel güncellemesi

`.github/workflows/windows-update.yml` yalnız özel KANAME deposunun main dalında release manifesti değiştiğinde veya manuel çalıştırıldığında devreye girer. Önce Windows testleri tamamlanır; hata varsa mevcut panel değiştirilmez.

Güncelleyici yalnız kullanıcının bildirdiği C:\Users\Administrator\KANAME kaynak dosyalarını yönetir. Bilinen eski/yeni kaynak hash'lerinden farklı yerel değişiklik varsa durur. Symlink/junction, kaynak dışı yol ve state path'leri manifestte kabul edilmez. 8765 portunu dinleyen işlemin aynı Windows hesabına ait, KANAME venv Python'u ile `-m kaname` çalıştıran süreç olduğu ve panel token/state eşleşmesi doğrulanır; başka süreç durdurulmaz.

Kaynak yedeği ve yerel SQLite backup, `.kaname-upgrades/<zaman>` altında tutulur. Token ve mevcut administrators.sqlite3 veritabanı da yerel yedeğe alınır. Bu klasör GitHub'a yüklenmez ve kaynak paketine girmez. Yedek hassas veri içerir; kendi bilgisayarınızda tutun. Mevcut token, config/policy, CA, AD kataloğu ve yönetici hesap/profil kayıtları saklanır. DB geri yüklenmez; böylece rollback sırasında kullanıcının daha yeni kayıtları ezilmez. İlk hesap geçişinde admin/Kaname ile yerel HTTP girişi, tüm yetkilerin okunması ve oturumdan çıkış ayrıca doğrulanır; cookie/CSRF değeri rapora yazılmaz. Mevcut hesapların olduğu sonraki güncellemelerde varsayılan parola denenmez. Yeni panel health/state/giriş kontrolünü geçmezse yalnız kaynak dosyaları geri alınır ve eski panel yeniden başlatılır.

Yeni lab paneli aynı Windows kullanıcısının arka plan sürecidir; GitHub job cleanup'tan bağımsız yaşar. GitHub/ACTIONS erişim anahtarları ve kullanıcı tanımlı secret ortam değişkenleri bu sürece aktarılmaz. Windows servisi, scheduled task, firewall veya AD değişikliği yapılmaz. Makine yeniden başlatılınca paneli standart `\.venv\Scripts\python.exe -m kaname` komutuyla açabilirsiniz. PID `kaname-state/panel.pid`, yerel loglar `panel.stdout.log` ve `panel.stderr.log` içindedir; bunları GitHub'a yüklemeyin.

Bu güncelleme mekanizması Windows laboratuvarı içindir. Üretim appliance update/rollback, imzalı paket ve Linux servis yönetimi ayrı kabul kapısıdır.
