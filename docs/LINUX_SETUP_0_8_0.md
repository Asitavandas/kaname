# KANAME 0.8 — Ubuntu laboratuvar kurulumu

Bu aşama Linux Kerberos/GSSAPI AD katalog okuyucusu ve HTTPS yönetim panelini
systemd servisine bağlar. RADIUS üretim dinleyicisi, accounting, güvenilir istemci
enrollment ve açılabilir OVF henüz bu teslimin kabulü değildir.
Windows'taki kurulu 0.7 paneli ve state değiştirilmez. Windows update işi yalnız
manuel tetiklenir ve 0.7 yayın commit'ini kullanır; Linux dosyaları Windows'a uygulanmaz.

## Ön hazırlık

linux-stage workflow'u disposable Ubuntu CI'de native python-ldap ile loopback
LDAP sayfalama, critical domain-scope, binary SID/GUID, referral reddi, member-range,
seçilmiş OU sınırlarını ve birden fazla OU birleşimini doğrular; kapsam dışındaki üyeler içeri alınmaz (0.12.1 güncel davranışı). Bu fixture anonim
loopback bind kullanır; gerçek GSSAPI/AD kimlik doğrulaması olarak sunulmaz.
Runtime okuyucusu yalnız kinit + GSSAPI bind kullanır ve SASL SSF >= 56 ister.
Simple Bind, NTLM, referral chasing ve domain join yolu bulunmaz.

Runner'daki ikinci iş geçici venv'de tüm regression testlerini çalıştırır ve
generic kaynakları kullanıcı home'unda kaname-stage-COMMIT dizinine kopyalar.
Root/paket/DNS/service değişikliği veya müşteri AD çağrısı yapmaz.
Test sonucu source_digest, manifestin SHA256 değeridir. Gerçek domain/IP/kullanıcı
bilgileri kaynaklara, workflow'a veya test verisine yazılmaz.

## Bir kez yerel yönetici ile kurulum

Operatör Ubuntu terminalinde stage dizinindeki tools/linux_install.py aracını
sudo ile çalıştırır. --source-digest, --domain, --dc-ip ve --listen-ip gerekir.
İsteğe bağlı --dc-fqdn ile doğrulanmış DC adı kullanılabilir; aksi halde verilen
DC'nin DNS hizmetinden domain SRV/A kayıtları okunarak bulunur. Parola alınmaz.

Araç Ubuntu 24.04 tabanını, kaynak hash'lerini, yerel listen IP/portunu ve mevcut
kurulum çakışmasını denetler. İlk kurulum içindir; mevcut state/servis/hesabı
silmez veya üzerine kurmaz. Başarısız kısmi kurulum manuel tanılama gerektirir;
OS paket işlemlerinin transaction/rollback olduğu iddia edilmez.

Kurulan OS paketleri: python3-venv, python3-ldap, krb5-user,
libsasl2-modules-gssapi-mit, bind9-dnsutils, ca-certificates.
Cryptography 46.0.0 yalnız /opt/kaname-lab/venv içine wheel olarak kurulur.
Build/kurulum interneti kullanabilir; sonraki çalışan uygulama PyPI/GitHub çağırmaz.
Nihai offline appliance build/güncelleme lifecycle'ı ayrı kabul işidir.

AD DNS adı/IP eşleşmesi bulunur; DC TCP 88/389 erişimi test edilir. Mevcut
/etc/hosts içeriği korunarak yalnız DC adının verilen IP'ye eşlemesi eklenir;
farklı mevcut DC eşlemesi varsa işlem reddedilir. Önceki hosts kopyası local
/etc/kaname-lab/hosts.before içinde tutulur. Netplan, genel DNS sunucuları,
hostname ve firewall kuralları değiştirilmez. Saat/Kerberos gerçek kabulü parola
girildikten sonraki authenticated bind sonucuna bağlıdır.

## Yerel dizinler ve servis

- /opt/kaname-lab/source ve venv: root-owned kod/runtime.
- /var/lib/kaname-lab: kaname-lab servis hesabı, 0700; yerel veritabanı ve kasa anahtarı.
- /etc/kaname-lab: root-owned 0750; local bootstrap, hosts yedeği ve HTTPS sertifikası.
- web.key: root:kaname-lab 0640; web.crt public sertifika.
- kaname-lab.service: non-root, NoNewPrivileges, ProtectSystem=strict,
  ProtectHome, PrivateTmp ve sınırlı yazılabilir state/runtime dizinleri.

Servis yalnız açıkça seçilmiş IPv4'te HTTPS/8765 dinler. 0.0.0.0 ve şifresiz LAN
HTTP reddedilir; Host/Origin/CSRF kontrolleri kalır, cookie Secure/HttpOnly/Strict
olur. Bearer bakım erişimi loopback ile sınırlıdır. Web sunucusu hâlâ Python
development HTTP stack'idir; üretim web hardening/DoS kabulü ilan edilmez.

Web sertifikası kurulum başına yeni self-signed ECDSA, IP/FQDN SAN ve server EKU
ile üretilir. Dış CA gerekmez. Tarayıcı önceden güvenmediğinden ilk bağlantıda
sertifika uyarısı beklenir. Kurulum SHA256 fingerprint'i local terminalde gösterir;
operatör tarayıcıdaki certificate fingerprint ile karşılaştırır ve yalnız eşleşirse
bu lab sertifikasına güven verir. Bu sertifika EAP istemci enrollment CA'sı değildir.

Servis başlatıldıktan sonra aynı cert'e güvenen HTTPS health check zorunludur.
Başarısızsa yeni lab servisi durdurulur, state tanılama için korunur.

## Operatör kabulü

HTTPS panelde ilk kullanıcı admin, ilk parola Kaname (kullanıcının istediği lab
başlangıcı). Sonraki init hesapları veya değiştirilmiş parolayı resetlemez.
Ubuntu ayrı state kullanır; Windows DPAPI kasası Linux'a kopyalanmaz.

User&Authentication → Active Directory: kurulumun gösterdiği DC FQDN,
kullanici@domain ve AD parolası panelde girilir, kaydedilir, Şimdi eşitle denenir.
OU/CN/DC scope, Users/User Groups ve periyodik kontroller mevcut ekranlardan kullanılır.
Hatalı kimlik bilgisi saptanırsa otomatik denemeler AD hesabını kilitlememek için
kalıcı health durumu üzerinden durur; bağlantı yeniden kaydedilince veya başarılı
manuel okumayla devam eder. Network hataları tam aralık sonunda tekrar denenir.

Parola sadece stdin'den helper'a ve kinit'e verilir; argv/env veya password dosyası
yoktur. Geçici ticket/krb5.conf 0700 klasörde tutulur; parent timeout process group'u
kapatır ve cache'i siler. TGT lifetime 5 dakika, forwardable false. Crash/stop
temizliği systemd runtime directory/cgroup lifecycle'ıyla sınırlıdır; RAM sıfırlama
garantisi verilmez. Yerel AES-GCM state anahtarı/disk yedeği yaşam döngüsü hâlâ lab sınırıdır.

Gerçek AD başarılı/yanlış-parola/scope/kesinti/yeniden başlatma ve tarayıcı trust
testleri operatör kabulünü bekler. Switch/AP ayarları operatörün manuel işidir.

Kaynaklar:
- https://www.python-ldap.org/en/latest/reference/ldap.html
- https://www.python-ldap.org/en/latest/reference/ldap-sasl.html
- https://www.python-ldap.org/en/latest/reference/ldap-controls.html
- https://www.openldap.org/doc/admin26/security.html
- https://web.mit.edu/kerberos/krb5-latest/doc/user/user_commands/kinit.html

Her sürümün kabulü sonrasında operatöre soruları/değişiklik istekleri sorulur;
yanıt gelmeden sonraki sürüme geçilmez.
