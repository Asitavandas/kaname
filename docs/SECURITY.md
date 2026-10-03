# KANAME — güvenlik sınırları

## Başlangıç sürümü

Loopback HTTP sunucusu yerel geliştirme içindir. İnternete/LAN'a bind etme seçeneği yoktur; üretim appliance yönetimi HTTPS + gerçek oturum/RBAC altyapısına geçirilecek. Reverse proxy ile bu geliştirme sunucusunu uzaktan erişime açmak desteklenen dağıtım değildir.

API 256 bit yerel access-token ister; token tarayıcının yalnız belleğinde tutulur. Host/Origin allowlist, JSON sınırı, katı alan/tip doğrulaması, dış kaynakları engelleyen CSP ve statik dosya allowlist uygulanır. UI'da kullanıcı alanları `textContent` ile gösterilir. AD okuma uç noktası, doğrulanmış yerel token ve same-origin istek içinde geçici AD kullanıcı/parolası alır. Parola kaydedilmez; yalnız Windows Kerberos okuyucusuna stdin üzerinden verilir. Domain Admin parolası runtime hesabı olarak tutulmaz. Diğer API şemaları secret kabul etmez. Belirlenmemiş JSON alanları reddedilir. Windows dosya ACL sertleştirmesi uygulanmış sayılmaz; bu sürüm yerel geliştirici hesabıyla çalıştırılır. POSIX'te state klasörü 0700, token/veritabanı 0600'dür.

SQLite audit kayıtları yapılandırmayla aynı transaction içinde oluşturulur ve update/delete trigger'larıyla uygulama seviyesinde korunur. Bu mekanizma root/DB sahibi veya dosya değiştirmeye karşı kriptografik kanıt değildir. Yönetici kimliği ve değişiklik özeti, üretim oturum/audit aşamasında eklenecek. Buradaki audit kimlik doğrulama olay günlüğü değildir.

`VerifiedIdentity` tipi girdi biçimini denetler; isim/ad veya tip bir kriptografik doğrulama sayılmaz. Mevcut HTTP simülasyonu sahte örnek alanları kabul eder, yalnız gösterim üretir. Üretim RADIUS adaptörü bu girdiyi istemci/panel beyanından alamaz.

## Yerel PKI sınırı

Root ve issuer RSA-3072/SHA256 ile oluşturulur. Anahtarlar PKCS#8 BestAvailableEncryption ile şifreli SQLite BLOB olarak saklanır; parola CLI'da getpass ile alınır ve argüman/log/API'ye yazılmaz. Parola uzunluk kontrolü güçlü parola veya HSM güvencesi değildir. Python süreç belleğinin sıfırlanması garanti edilmez. Root ve issuer aynı parola/veritabanındadır; bu bir offline root tasarımı değildir. Üretim key vault, yetki ayrımı ve root lifecycle sonraki aşamadır.

CSR imzası/algoritması ve anahtar boyutu denetlenir; SAN tam olarak kaydedilmiş appliance FQDN olmalıdır. Ek SAN/UPN, CA veya istemci EKU isteği reddedilir. İstenen subject yetki kanıtı olarak kullanılmaz. Üretilen leaf yalnız serverAuth içindir. CA/server işlemleri sadece yerel operatör CLI'ında bulunur; HTTP API'de imzalama veya istemci enrollment endpoint'i yoktur. Aynı state klasöründe eski yapılandırma ve policy korunur.

İptal ve CRL numarası/üretimi audit ile birlikte atomiktir. CSR imzalama/iptal öncesi issuer zinciri, anahtar eşleşmesi, süre ve saklanan CRL imzası/numarası doğrulanır. CRL'nin HTTP/CDP yayını ve otomatik yenileme zamanlayıcısı henüz yoktur; OpenSSL'de açıkça verilen CRL ile doğrulama yapılmıştır. Gerçek RADIUS ve endpoint revocation denetimi ayrıca bağlanmalıdır.

## Üretim için zorunlu işler

HTTPS ve sertifika güveni, yönetici oturumu/CSRF/RBAC, login rate limit, secret kasası ve anahtar koruması; process/user ayrımı, minimum ayrıcalık, RADIUS kaynak IP/secret/message integrity, TLS sürüm/algoritma ayarları, enrollment kimlik kanıtı ve CSR doğrulaması, sertifika revocation/CRL, AD offline ret, kaynak sınırları, immutable uygulama imajı, audit redaction/rotation, şifreli yedek, imzalı güncelleme/rollback.

RADIUS güvenlik düzeltmeleri ve Message-Authenticator gereksinimleri seçilen sürüm ve cihazlarla gerçek testten geçecek. Gerekli protokol güvenliğini kaldıran “uyumluluk” seçeneği varsayılan olarak eklenmez. CA anahtarı ve AD credentials tanılama/yedek dışa aktarımında düz metin görünmez.

## Veri yönetimi

Bu paketi örnek/nonsecret ayarlarla kullanın. `kaname-state/` klasörü ZIP'e eklenmez. Yapılandırmayı kaybetmek istemiyorsanız programı durdurup kendi veri klasörünüzün yedeğini alın. Nihai ürünün online tutarlı, şifreli yedekleme özelliği henüz yoktur. Kaynak teslimi kendi halinde müşteri kimliği veya üretim secret içermez.
