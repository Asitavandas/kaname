# Değişiklikler

## 0.8.0-dev.1 — Ubuntu AD/HTTPS laboratuvarı

- Linux kinit/GSSAPI okuyucusu, zorunlu SASL sealing, private kısa ömürlü ticket, sayfalı/OU kapsamlı katalog ve primary/nested üyelikler eklendi. Domain join veya AD yazma yok.
- TLS olmayan LAN paneli reddedilir; HTTPS origin/host/CSRF, Secure cookie ve loopback bakım sınırı eklendi. Yerel HTTP geliştirme davranışı korunur.
- Generic kaynaklar root kullanmadan runner üzerinde test/stage edilir; yerel sudo ilk kurulum aracı non-root systemd servisi ve bağımsız Ubuntu state hazırlayabilir. Gerçek domain/IP kaynak veya CI parametresine yazılmaz.
- Hatalı AD kimlik bilgisinde otomatik denemeler durur; tekrar kaydetme/başarılı manuel okuma beklenir.
- Windows 0.7 update yalnız manuel ve sabit yayın kaynağıyla çalışır; mevcut Windows state ve parolalar değiştirilmez.
- Gerçek AD, sudo ilk kurulum, production RADIUS/accounting/enrollment ve açılabilir OVF henüz kabul edilmedi.

## 0.6.0-dev.1 — gerçek EAP-TLS/RADIUS protokol laboratuvarı

- Native FreeRADIUS 3.2.10 ve eapol_test ile geçici loopback protokol testi eklendi; panelin simülasyon endpoint'i kullanılmaz.
- Sertifika pinned issuer/serial ile kayıt bağına, domain/objectGUID/SID/tür ile güncel dizin sağlayıcısı sonucuna eşlenir. Missing/offline/mismatch/disabled/group removal varsayılan ret verir; display katalog fallback değildir.
- Kullanıcı sertifikası bilgisayar kimliği üretmez. Policy sıra/koşul/kısıt ve VLAN motoru native sertifika-check sanal sunucusunda kullanılır; bozuk/ret sonuç Accept veya VLAN üretemez.
- Gerçek TLS zincir/EKU/süre/CRL retleri, sunucu adı/güven reddi, Access-Challenge, Reply Authenticator/Message-Authenticator ve standart VLAN öznitelikleri denetlenir.
- Native kaynak commit'i sabitlenir; yalnız loopback geçici CA, shared secret, dosyalar ve süreçler kullanılır. Müşteri CA'sı/verisi ve Windows ağ/servis ayarı değiştirilmez.
- Dizin ve enrollment bağları yalnız fixture'dır. Production RADIUS, live Linux AD, Windows/switch/AP uçtan uca test ve bootable OVF sonraki kabul kapılarıdır.

## 0.5.0-dev.1 — menüler ve AD üyelik detayları

- Sol menü başlıkları tek başlığı açık tutabilen, klavyeyle kullanılabilen akordiyon yapısına geçti.
- System altında Administrators ve Admin Profiles ayrı sayfalar oldu.
- User&Authentication altında Active Directory bağlantı sayfası ve Users/User Groups listeleri ayrıldı; iki liste aynı ekranda ayrı arama/sayfalama sunar.
- Kullanıcı veya grup adına tıklanınca karşılıklı doğrudan, primary ve iç içe üyelik detayları açılır. Detayda arama, sayfalama ve karşı nesneye geçiş vardır.
- LDAP member range devam sayfaları, primary group RID/SID eşlemesi ve security/distribution ayrımı eklendi. Distribution grupları katalogda görünür, erişim politikasına seçilemez.
- Eski katalog/veriler değiştirilmez; üyelik şeması yoksa yeniden okuma açıklaması gösterilir. AD bağlantısı ve katalog yetkileri ayrılabilir; eski Custom yetkileri korunur.
- Yükleme sırasında eski satır düzenleme düğmeleri de kapatılır. Reddedilen bounded POST gövdesi okunarak Windows TCP reset yerine hata yanıtının ulaşması sağlanır; yetki/CSRF şartları değişmez.

## 0.4.0-dev.1 — yönetici hesapları ve yetki profilleri

- PowerShell/token panel girişi yerine kullanıcı/parola formu, ilk kurulum admin/Kaname, cookie oturumu ve kendi parolasını değiştirme eklendi.
- System → Administrators ve Admin Profiles altında hesap/profil ekleme, düzenleme, silme; SuperAdmin, Admin_ReadOnly ve menü/sekme bazında Custom yetkiler eklendi.
- Yetkiler API'de denetlenir; izin verilmeyen veriler durum yanıtından çıkarılır. Yetki devri yapan hesap kendi haklarını aşamaz.
- Salt'lı parola hash'i, CSRF nonce, oturum sonlandırma/süre sınırları ve giriş deneme sınırı uygulandı. Silinen varsayılan hesap/profiller otomatik yeniden oluşturulmaz.
- Politika formunda SID yazmak yerine AD grup adıyla arama/çoklu seçim ve açık grup kısıtı yok seçeneği eklendi; kalıcı kimlik olarak SID korunur.
- Windows güncellemesi AD kataloğunu ve mevcut yönetici hesap/profillerini de yedekler/doğrular; ilk geçişte gerçek yerel panel girişini kontrol eder.
- Her sürüm tamamlandığında operatörün soruları/değişiklikleri alınmadan sonraki sürüme geçilmez.

## 0.3.2-dev.1 — domain kapsamlı LDAP sorgusu

- Her kullanıcı/grup/bilgisayar sorgusuna kritik LDAP_SERVER_DOMAIN_SCOPE_OID eklendi; AD DNS/alt-domain yönlendirmeleri arama kapsamına girmez.
- Referral chasing kapalı ve beklenmeyen referral reddi korunur; artık REFERRAL_RETURNED nedeni gösterilir.
- Windows .NET sorgu, iki sayfalı kullanıcı okuma, GUID/SID dönüşümü, eksik/tekrarlanan sayfa ve referral reddi gerçek LDAP protokolünü konuşan yerel fixture ile test edilir.
- Fixture yalnız test CLI seçeneğiyle 127.0.0.1 üzerinde çalışır, gerçek kimlik bilgisi veya dış ağ kullanmaz; üretim Kerberos/signing/sealing koşulları değişmez.
- Önceki 0.3.1 yayınından ayar/politika/CA/token korunarak güncelleme desteklenir.

## 0.3.1-dev.1 — AD ikili öznitelik okuma düzeltmesi

- SID/GUID öznitelikleri GetValues(byte[]) ile okunur; LDAP indexer UTF-8 dönüşümünden etkilenmez.
- Windows .NET self-test yerleşik grup SID ve GUID nesne dönüşümünü de doğrular.
- AD hataları yalnız sabit aşama/neden kodlarıyla ayrılır; ham exception, DN veya kimlik bilgisi gösterilmez.
- Kullanıcı adı biçimi/parola kontrolü ve bağlantı düğmesi yanında durum açıklaması eklendi.
- Önceki yayın manifestiyle 0.3.0 kurulumu güvenli biçimde güncellenebilir; kullanıcı kaynak değişiklikleri hâlâ reddedilir.
- Gerçek AD başarılı katalog okuması yeniden operatör denemesi gerektirir.

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

## 0.7.0-dev.1

- Named manual VLAN inventory and VLAN selectors, preserving existing assignments.
- Order-independent policy engine, conflict rejection before save with named bottom-right warnings; edit/delete controls, no ordering or enable toggles. Existing disabled rules remain archived.
- Read-only AD OU/CN/DC scope, protected saved connection credentials, manual and periodic sync, independent authenticated health probes and panel alerts. Failed/partial reads preserve the last catalog; successful reads replace added/deleted users and memberships.
- Named security groups in decision simulation. No AD membership writes, SMTP, switch/AP management, timeout or retry fields.
- RADIUS client source IPs, generated/revealable encrypted per-client shared secrets; configurable server authentication/accounting UDP ports, defaults 1812/1813. Production listener/accounting and OVF remain pending.
