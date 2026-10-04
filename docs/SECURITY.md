# KANAME — güvenlik sınırları

## Başlangıç sürümü

Loopback HTTP sunucusu yerel geliştirme içindir. İnternete/LAN'a bind etme seçeneği yoktur; üretim appliance yönetimi HTTPS ve üretim servis altyapısına geçirilecek. Yerel kullanıcı oturumu ve RBAC bu sürümde uygulanmıştır. Reverse proxy ile bu geliştirme sunucusunu uzaktan erişime açmak desteklenen dağıtım değildir.

Panel kullanıcı adı/parolasıyla giriş yapar. Parolalar rastgele salt ile PBKDF2-HMAC-SHA256, 600.000 iterasyon kullanılarak hash olarak tutulur. İlk kurulum admin/Kaname hesabı yalnız bir kez oluşturulur; silinen hesap veya profil yeniden başlatmada oluşturulmaz. Yeni/değiştirilen parolalar en az 8 karakterdir. Oturum kimliği 256 bit rastgeledir; SQLite'da yalnız hash'i tutulur. HttpOnly, SameSite=Strict cookie; ayrı CSRF nonce, zorunlu Origin/Host doğrulaması, 8 saat mutlak ve 30 dakika boşta süre sınırı uygulanır. HTTP loopback sürümünde Secure cookie kullanılmaz; HTTPS appliance geçişinde zorunlu olacaktır. Giriş denemeleri yerel veritabanında 60 saniyede 30 istekle sınırlıdır. Tarayıcı token/oturum kimliğini localStorage'a yazmaz.

Her yönetim endpoint'i sunucu tarafında Read/Write denetimi yapar. Custom profillerde Kurulum sekmeleri ayrı ayrı kontrol edilir; durum API'si izin verilmeyen alanları çıkarır. Profil izinleri her istekte yeniden okunur; kullanıcı/parola değişikliği, kapatma ve silme mevcut oturumları iptal eder. Profil yöneticisi kendi yetkilerini aşan profil veya hesap ataması/değişikliği yapamaz. Gizlenmiş menüler tek başına güvenlik kontrolü sayılmaz. Eski 256 bit access-token yalnız yerel CLI/güncelleme/tanılama için tam yetkili bakım erişimi olarak korunur; tarayıcıya verilmez. Bu dosyaya erişebilen yerel operatör normal profil sınırlarını aşabilir.

JSON sınırı, katı alan/tip doğrulaması, dış kaynakları engelleyen CSP ve statik dosya allowlist uygulanır. Kullanıcı alanları textContent ile gösterilir. AD okuma için directory.connection Write gerekir; katalog ve üyelik detayları directory.catalog Read ister. Eski Custom profillerin directory.catalog bağlantı hakkı ayrı matris ayarı verilene kadar korunur. Grup ilişki referansları, primary group tutarlılığı, katalog kapsamı ve ranged üye yanıtları denetlenir; eksik okumada eski katalog korunur. Distribution grupları erişim politikası seçicisinden çıkarılır. AD bağlantı parolası ayrı protected_secrets tablosunda şifreli saklanır. Windows DPAPI user scope (UI forbidden), Linux geliştirme/test yolunda 0600 yerel anahtar ile AES-GCM kullanılır; amacı bağlayan entropy/AAD yanlış alana taşınan ciphertexti reddeder. Parola normal GET/state/audit yanıtlarına verilmez. Windows Kerberos okuyucusuna yalnız stdin üzerinden aktarılır. RADIUS secret üretme/gösterme network.radius Write ve CSRF ister; gösterme audit edilir, normal network GET sadece kayıt bayrağı verir. Kullanıcı Domain Admin hesabı kaydedebilir ancak AD salt okunur kalır; asgari okuma hesabı tercih edilir. Runtime kimlik yazma yetkisi kazanmaz. Diğer config/policy şemaları secret kabul etmez. Windows dosya ACL sertleştirmesi uygulanmış sayılmaz; bu sürüm yerel operatör hesabıyla çalışır. POSIX'te state klasörü 0700, token/veritabanları 0600'dür.

SQLite yapılandırma audit'i değişikliklerle aynı transaction içinde oluşturulur. Ayrı yönetici veritabanı hesap/profil/parola değişikliklerini aktör ve hedef kimliğiyle append-only admin_audit tablosuna kaydeder. Bu tablo henüz paneldeki İşlem geçmişi ekranına birleştirilmez; o ekran yapılandırma audit'ini gösterir. Update/delete trigger'ları root/DB sahibi veya dosya değiştirmeye karşı kriptografik kanıt değildir. Bu audit RADIUS kimlik doğrulama olay günlüğü değildir.

`VerifiedIdentity` tipi girdi biçimini denetler; isim/ad veya tip bir kriptografik doğrulama sayılmaz. Mevcut HTTP simülasyonu sahte örnek alanları kabul eder, yalnız gösterim üretir. Üretim RADIUS adaptörü bu girdiyi istemci/panel beyanından alamaz.

0.6 native FreeRADIUS protokol laboratuvarı yalnız geçici loopback süreçtir. Pinned issuer+serial → registry → canlı dizin sağlayıcısı sınırı eksik/kapalı/yanlış kimliği reddeder; default production registry/provider bulunmaz. Fixture sağlayıcı display katalogdan veya müşteri verisinden okunmaz. Kendi geçici CA'sı ve test sertifikaları kullanılır, müşteri PKI'sına istemci imzalama açılmaz. TLS session cache kapalıdır; her yeni oturumda dizin kontrolü tekrar çalışır. Native Message-Authenticator ve kaynak IP denetimi ile TLS zincir/EKU/süre/CRL sınırları gerçek paket testiyle kontrol edilir. Bu kanıt service hardening, gerçek AD enrollment, CRL yayını/zamanlayıcı, production timeout/rate-limit veya ağ kabulü değildir.

## Yerel PKI sınırı

Root ve issuer RSA-3072/SHA256 ile oluşturulur. Anahtarlar PKCS#8 BestAvailableEncryption ile şifreli SQLite BLOB olarak saklanır; parola CLI'da getpass ile alınır ve argüman/log/API'ye yazılmaz. Parola uzunluk kontrolü güçlü parola veya HSM güvencesi değildir. Python süreç belleğinin sıfırlanması garanti edilmez. Root ve issuer aynı parola/veritabanındadır; bu bir offline root tasarımı değildir. Üretim key vault, yetki ayrımı ve root lifecycle sonraki aşamadır.

CSR imzası/algoritması ve anahtar boyutu denetlenir; SAN tam olarak kaydedilmiş appliance FQDN olmalıdır. Ek SAN/UPN, CA veya istemci EKU isteği reddedilir. İstenen subject yetki kanıtı olarak kullanılmaz. Üretilen leaf yalnız serverAuth içindir. CA/server işlemleri sadece yerel operatör CLI'ında bulunur; HTTP API'de imzalama veya istemci enrollment endpoint'i yoktur. Aynı state klasöründe eski yapılandırma ve policy korunur.

İptal ve CRL numarası/üretimi audit ile birlikte atomiktir. CSR imzalama/iptal öncesi issuer zinciri, anahtar eşleşmesi, süre ve saklanan CRL imzası/numarası doğrulanır. CRL'nin HTTP/CDP yayını ve otomatik yenileme zamanlayıcısı henüz yoktur; OpenSSL'de açıkça verilen CRL ile doğrulama yapılmıştır. Gerçek RADIUS ve endpoint revocation denetimi ayrıca bağlanmalıdır.

## Üretim için zorunlu işler

HTTPS ve sertifika güveni, üretim oturum dağıtımı ve Windows/Linux dosya erişim sınırları, secret kasası ve anahtar koruması; process/user ayrımı, minimum ayrıcalık, RADIUS kaynak IP/secret/message integrity, TLS sürüm/algoritma ayarları, enrollment kimlik kanıtı ve CSR doğrulaması, sertifika revocation/CRL, AD offline ret, kaynak sınırları, immutable uygulama imajı, audit redaction/rotation, şifreli yedek, imzalı güncelleme/rollback.

RADIUS güvenlik düzeltmeleri ve Message-Authenticator gereksinimleri seçilen sürüm ve cihazlarla gerçek testten geçecek. Gerekli protokol güvenliğini kaldıran “uyumluluk” seçeneği varsayılan olarak eklenmez. CA anahtarı ve AD credentials tanılama/yedek dışa aktarımında düz metin görünmez.

## Veri yönetimi

Bu paketi örnek/nonsecret ayarlarla kullanın. `kaname-state/` klasörü ZIP'e eklenmez. Yapılandırmayı kaybetmek istemiyorsanız programı durdurup kendi veri klasörünüzün yedeğini alın. Nihai ürünün online tutarlı, şifreli yedekleme özelliği henüz yoktur. Kaynak teslimi kendi halinde müşteri kimliği veya üretim secret içermez.

0.7: politika sırası erişim kararını etkilemez. Çakışan kayıt transaction içinde reddedilir; yeni AD üyeliği ile oluşan çelişkiler runtime ret ve panel uyarısı üretir. Görüntü kataloğu canlı kimlik kanıtı değildir. E-posta, AD üyelik yazma ve cihaz yönetimi kapsam dışında.
