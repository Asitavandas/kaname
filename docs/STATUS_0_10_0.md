# KANAME 0.10.0-dev.1 — kullanıcı sertifikası kayıt akışı

Bu kaynak Ubuntu üzerinde kontrollü laboratuvar kullanıcı enrollment'ını ekler. Güncelleme uygulanmadan çalışan panel 0.8 olarak kalır. RADIUS dinleyicisi/accounting açılmaz, Windows kurulumu değiştirilmez. Müşterinin gerçek kullanıcı enrollment'ı, makine enrollment'ı ve fiziksel switch/AP kabulü henüz yapılmadı.

## Kimlik ve sertifika sınırı

Panelde certificates.authority Write yetkisi, gerçek HTTPS, geçerli Origin ve CSRF gerekir. Yerel maintenance token bile TLS kontrolünü atlayamaz. Read yetkisi liste ve public sertifika/CRL indirme içindir; bu okumalar CA oluşturmaz veya enrollment tablolarını yaratmaz.

İstemci kendi anahtarını oluşturur. Panel yalnız imzalı PEM PKCS#10 CSR alır; anahtar üretilmez/yüklenmez, PFX veya private key indirme endpoint'i yoktur. RSA 2048–4096/e=65537 veya EC P-256/P-384 ve SHA256/384/512 kabul edilir. CSR uzantıları, SAN, EKU ve CA talepleri reddedilir. İmzalı CSR tek başına AD kimliği kanıtı değildir.

Kullanıcının kendi parolası tek Kerberos denemesinde kullanılır. İlk lab akışı yalnız ASCII samAccountName@configured-domain (1–20 karakter, harf/rakam/alt çizgiyle başlar) kabul eder; machine $, enterprise UPN alias ve SPN kabul edilmez. kinit canonicalization açılmaz; klist aynı kısa ömürlü private FILE cache içindeki principal'ı doğrular. LDAP SASL signing/sealing, DC IP ve RootDSE kimliği mevcut 0.8 sınırlarını kullanır.

Aynı LDAP oturumunda Who Am I yanıtı zorunludur: SID doğrudan resolved account SID'iyle eşleşir. NetBIOS\\sam yanıtında configured domain'in configuration crossRef nCName/nETBIOSName bilgisi ve account sam değeri karşılaştırılır. Anonymous, AD LDS dn:, foreign NetBIOS ve SID uyuşmazlığı reddedilir; desteklenmeyen Who Am I için isim fallback'i yoktur. Hesap GUID ile tekrar bulunur, canlı tokenGroups/disabled/lockout/accountExpires doğrulanır. Kayıtlı connector hesabıyla ikinci canlı kontrol hesabın hâlâ aynı GUID/SID/türde ve enabled olduğunu doğrular. UI kataloğu kullanılmaz.

Sertifika CLIENT_AUTH EKU ve digitalSignature taşır; CA değildir. Subject sunucu tarafından GUID ile hazırlanır, dış EAP adı/CN/SAN izin kaynağı olmaz. Sertifika, issuer/serial + AD domain/GUID/SID/user bağı ve CSR/public-key fingerprint kaydı aynı SQLite transaction'ında yazılır. Audit hatası bütün issuance'ı geri alır. Kayıt öncesi/config değişiklikleri fail closed; CSR veya public key tekrar kullanılamaz. Kalıcı global 30 saniye aralığı, tek paralel işlem ve otomatik tekrar olmaması AD parolası denemelerini sınırlar. Kullanıcı AD parolası ve CA parolası kaydedilmez/geri gönderilmez.

Kullanıcı sertifikası bir domain bilgisayarının kanıtı değildir. require_domain_device=true kuralları bunu reddeder; varsayılan panel politikaları gevşetilmedi. Bilgisayarın kendi kimlik kanıtı ayrı geliştirmedir. Hesap/grup değişiklikleri yetkilendirme sırasında yine canlı sorgulanır.

## Panel ve lab kullanım sırası

1. Test/stage tamamlandıktan sonra yerel sudo ile `tools/linux_update.py --source-digest <CI-manifest-hash>` uygulanır. Aracı sadece doğrulanmış stage'den çalıştırın. Var olan servis çalışır durumda olmalıdır.
2. Aynı HTTPS panelinde Sertifikalar ekranını açın. Read/Write yetkinizle dahili CA oluşturun; güçlü, en az 16 UTF-8 byte CA anahtar parolasını iki kez girin ve saklayın. CA varsa yeniden oluşturulmaz; unutulmuş parola reset edilmez.
3. **Endpoint üzerinde**, cryptography==46.0.0 bulunan kaynak ortamında `python -m tools.client_request --directory <yeni-klasor>` çalıştırın. İstemci anahtar parolası terminalde sorulur; aynı klasör/anahtar üzerine yazılmaz. Şifreli client-key.pem endpoint üzerinde kalır; yalnız client-request.pem içeriğini panel CSR alanına taşıyın.
4. CSR'nin sahibinin kendi samAccountName@domain hesabı ve AD parolasını girin. Connector/admin hesabı farklıysa onun parolasını burada kullanmayın. CA parolasını girin; gün (1–90, varsayılan 30) seçip doğrulayın. Üretilen açık istemci sertifikasını indirin. Kaybolursa sertifika listesinden tekrar indirilebilir; özel anahtar panelde bulunmaz.
5. Root/issuer/CRL public dosyalarını panelden indirin. Fingerprint doğrulaması ve endpoint trust/profil dağıtımı henüz manuel lab adımıdır; bu sürüm otomatik Windows store/GPO dağıtımı yapmaz. CSR aracının encrypted PEM anahtarı Windows certificate store/PFX provisioning tamamlandı anlamına gelmez.
6. Listeden sertifikayı iptal için seçin, nedeni ve CA parolasını girip iptal edin. İptal geri alınamaz. Signed CRL ve registry revocation birlikte değişir; yeniden enrollment yeni endpoint anahtarı gerektirir. Otomatik yenileme henüz yoktur. CRL 24 saatliktir; yenile/indir işlemi paneldedir, native servis apply/scheduler sonraki aşamadır.

## Güncelleme ve test sınırı

Updater Ubuntu 24.04/kaname-lab mevcut layout'uyla sınırlıdır. Manifest doğrulanır ve root-owned snapshot kopyalanır; dependency import önce non-root servis kimliğiyle kontrol edilir. Çalışan servis durdurulur; private state/settings ve eski source root-only backup altına alınır. Kod değiştirilir, aynı sertifika ile doğrulanan HTTPS health ve config/admin/profile/CA keys/secret-store key digest koruması kontrol edilir. Başarısız health durumunda eski source yeniden başlatılır. Eski DB üzerine restore yaparak yeni kullanıcı/AD değişiklikleri silinmez; additive schema eski kodla uyumludur. Backup müşteri secrets içerir ve root-only korunmalıdır.

Native kurulum testi root-owned fakat 777 izinli eski __pycache__ dizinlerini ortaya çıkardı. Kaynak .py dosyalarının güvenlik şartı gevşetilmez: old bytecode root-only backup/bytecode altına, içeriği çalıştırılmadan/symlink'leri takip edilmeden taşınır. Rollback source bu güvenilmeyen cache'i yeniden yükleyemez. Yeni bootstrap komutları -B ile bytecode yazmaz; unit'teki mevcut PYTHONDONTWRITEBYTECODE korunur. Root update launcher yalnız stdlib kullanır, mutable runner helper modülünü root olarak import etmez. Eşzamanlı upgrade root-only dosya kilidiyle reddedilir.

Native LDAP tests gerçek OpenLDAP BER/Who Am I/BASE tokenGroups parser'ını loopback anonymous fixture'da test eder; bu müşteri Kerberos'u değildir. Unit/TLS tests injection sadece disposable fixtures kullanır. Gerçek AD self-auth/Who Am I kabulü kullanıcı tarafından yapılana kadar pending'dir. Loopback RADIUS fixture'i önceki gerçek sertifika/TLS/policy testlerini korur; customer user enrollment veya production network service kabulü ilan edilmez.

## Referanslar

- [RFC 7030 — enrollment kimliği ve CSR proof of possession ayrımı](https://www.rfc-editor.org/rfc/rfc7030.html). Bu lab API bir EST uyumluluk iddiası değildir.
- [MIT kinit](https://web.mit.edu/kerberos/www/krb5-latest/doc/user/user_commands/kinit.html) ve [klist](https://web.mit.edu/kerberos/www/krb5-latest/doc/user/user_commands/klist.html).
- [Microsoft MS-ADTS Who Am I](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/faf0b8c6-8c59-439f-ac62-dc4c078ed715).
- [python-ldap LDAPObject.whoami_s](https://www.python-ldap.org/en/latest/reference/ldap.html).

Yeni sürümün teslim/kullanıcı kontrolü ardından sorular/değişiklikler alınır; sonraki sürüm operatör yanıtından sonra başlar.
