# Değişiklikler

## 0.3.0-dev.1 — AD dizin okuma

- Mevcut GitHub kayıtları ve Windows paneli doğrulandı; kaynak/state yeniden oluşturulmadı.
- Windows .NET LDAP okuyucusu Kerberos, signing ve sealing zorunluluğuyla eklendi; Basic/NTLM/plaintext fallback yok.
- Parola yalnız istek/işlem belleğinde kullanılır; argv/env/config/audit/katalog içine yazılmaz.
- Sayfalı kullanıcı, bilgisayar ve güvenlik grubu listeleri; SID/GUID doğrulaması ve kapalı hesap durumu eklendi.
- Katalog ve audit atomik kaydedilir; config/policy revision veya CA değiştirilmez. Hatalı okuma eski listeyi korur.
- Panele AD bağlantısı, sayfalı arama ve yeni politikaya grup seçimi eklendi.
- Gerçek AD credential testi kullanıcı laboratuvarı kabul kapısıdır. İç içe/primary grup doğrulaması, düzenli eşitleme, Linux Kerberos adaptörü, EAP ve OVF henüz tamamlanmadı.

## 0.2.0-dev.1 — bağlantı sonrası devam

- 0.1 kaynak/paket bütünlüğü ve 70 test doğrulandı; mevcut temel yeniden oluşturulmadı.
- Benzersiz root/issuer CA, şifreli PKCS#8 anahtarlar ve yerel yönetim CLI'ı eklendi.
- Kayıtlı appliance FQDN için katı CSR denetimi ve server-only sertifika imzalama eklendi.
- Sertifika iptali, idempotent tekrar, imzalı/numaralı CRL ve refresh eklendi.
- PKI kayıtları ile audit atomik; eski yapılandırma/politika korunur. CA yeniden init ile değiştirilemez.
- Panele private key içermeyen CA kimlik/parmak izi/süre ekranı eklendi.
- Gerçek yerel TLS ve OpenSSL zincir/DNS/revocation testleri eklendi.
- AD/enrollment/RADIUS/OVF bağlantıları ve tarayıcı görsel doğrulaması hâlâ tamamlanmadı.

## 0.1.0-dev.1 — 2026-10-02

- KANAME için bağımsız kaynak yapısı ve ürün kapsamı oluşturuldu.
- Dört adımlı taslak kurulum, politika sıralama ve yerel karar testi paneli eklendi.
- Sıralı koşul/kısıt değerlendirmesi, varsayılan ret ve VLAN öznitelik modeli uygulandı.
- Katı nonsecret JSON şeması, optimistic revision ve atomik SQLite audit eklendi.
- Loopback geliştirme API'si token/Host/Origin kontrolleriyle sınırlandı.
- OVF appliance sözleşmesi, hazırlanmış temiz VMX export sarmalayıcısı ve manifest/struktur denetleyicisi eklendi.
- 70 otomatik test, CI tarifi ve tarayıcı akış test betiği eklendi.
- AD, PKI, RADIUS runtime ve gerçek OVF henüz teslim edilmedi; hazır olma endpoint'i 503 döner.
