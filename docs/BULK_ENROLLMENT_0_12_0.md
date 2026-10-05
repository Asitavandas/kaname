# AuthWire toplu bilgisayar kaydı ve yenileme — 0.12.0-dev.1

Amaç: IT her bilgisayarda komut çalıştırmaz, CSR taşımaz, sertifika kopyalamaz. Bir kez merkezi AD/GPO kurulumu yapılır. GPO, domain bilgisayarında SYSTEM olarak çalışan kayıt/yenileme görevini kurar. Her bilgisayar kendi farklı, dışa aktarılamayan Windows CNG anahtarını oluşturur; AuthWire sertifikayı canlı AD kimliğine bağlar. İlk kapsam domain Windows bilgisayarıdır; insan kullanıcı kimliği veya kullanıcı+bilgisayar birleşik EAP iddiası değildir.

## Panel akışı

Sertifikalar → **Profiller → Dağıtım → Cihazlar**.

1. Bir AD güvenlik grubu ve sertifika süresi seçin. 90 gün / bitmeden 30 gün önce yenileme başlangıç örneğidir. 2–365 gün desteklenir; imzalayan CA son tarihi üst sınırdır. Yeni profiller kapalı başlar.
2. Dağıtım ekranında HTTPS, DNS adı, Kerberos SPN/keytab ve otomatik imzalayıcı durumunu kontrol edin. CA parolasını bir kez girerek otomatik imzalamayı açın.
3. Profilden GPO paketini indirin, merkezden imzalayıp pilot OU’ya dağıtın.
4. Cihazlar ekranında “Kurulum onayı bekliyor” ve “İstemci kurulumu doğrulandı” ayrımını izleyin. Henüz bağlanmayan bilgisayar listede görünmez; toplam sayı cihaz sertifikası sayısıdır ve yenileme geçmişini içerir. GPO uygulanma envanteriyle eşdeğer değildir.

## Merkezi AD/HTTPS hazırlığı — bilgisayar başına yapılmaz

AuthWire’ın mevcut HTTPS sertifikasındaki DNS adı kullanılmalıdır. Dağıtım ekranındaki `HTTP/<FQDN>` SPN bununla aynıdır. DNS kaydı Ubuntu IP’sine çözülmeli; domain bilgisayarlarının DC’ye, DNS’e, saate ve AuthWire HTTPS portuna erişimi olmalıdır. IP URL ile Kerberos dağıtımı yapılmaz. Marka değişikliği mevcut TLS/DNS kimliğini otomatik değiştirmez.

AD’de yalnız HTTP kabulü için **ayrı**, domain admin olmayan bir servis hesabı oluşturun. Mevcut AD bağlantı hesabını bu iş için yeniden kullanmayın: keytab üretimi hesabın parolasını değiştirebilir. Hesabın delegation yetkisine ihtiyacı yoktur; AES Kerberos etkin olmalıdır.

Yetkili AD yöneticisi, gerçek `<FQDN>`, `<NETBIOS>` ve servis hesabını kullanarak bir kez:

```powershell
Set-ADUser svc_authwire_http -KerberosEncryptionType AES128,AES256 -AccountNotDelegated $true
setspn -S HTTP/<FQDN> <NETBIOS>\svc_authwire_http
ktpass /out C:\Secure\AuthWire-http.keytab /princ HTTP/<FQDN>@VIZYONVERI.LOCAL /mapuser <NETBIOS>\svc_authwire_http /crypto AES256-SHA1 /ptype KRB5_NT_PRINCIPAL /pass *
```

Örnek realm kullanıcının mevcut `vizyonveri.local` domainidir; başka kurulumda kendi realm’i kullanılmalıdır. FQDN küçük harf, realm büyük harf; principal/keytab yazımı tam eşleşmelidir. `setspn -S` tekrar eden SPN’yi kontrol eder. Keytab sunucu sırrıdır: GPO’ya, kullanıcı paylaşımına veya sohbete konulmaz. Güvenli yöntemle Ubuntu’ya, root sahibi ve 0600 olarak aktarılır.

Toplu kayıt sürümü güncellendikten sonra Ubuntu üzerinde **bir kez**:

```bash
sudo /usr/bin/python3 -B /opt/kaname-lab/source/tools/linux_device_setup.py \
  --keytab /root/AuthWire-http.keytab
```

Bu ayrı komut `python3-gssapi` paketini kurar, keytab’ı mevcut servis hesabıyla doğrular ve `/var/lib/kaname-lab/device-http.keytab` içine 0600 olarak yerleştirir. Mevcut keytab üzerine yazmaz. AD’ye, RADIUS’a ve ağ cihazlarına değişiklik yapmaz. Kaynak güncelleyici apt kurulumunu gizlice yapmaz. Servis keytab’ı her yeni oturumda okur; restart gerekmez. Gerçek KDC’nin SPN’yi doğru hesaba yönlendirdiği ancak gerçek domain istemci pilotunda kanıtlanır.

## GPO paketi ve merkezden imzalama

ZIP: `Install-AuthWire.ps1`, `AuthWire-Client.ps1`, `config.json`, Root/Issuer açık sertifikaları, mevcut self-signed HTTPS sertifikası için açık güven dosyası ve SHA256 listesi. CA/cihaz özel anahtarı, AD parolası, keytab veya ortak istemci PFX içermez. Profil ID bir yetkilendirme sırrı değildir.

Kurumunuzun Code Signing EKU’lu, istemcilerce güvenilen Authenticode sertifikasını kullanın. İmzalayanın Root zinciri ve yayıncı sertifikasını GPO ile güvenilir Root/Trusted Publishers depolarına yerleştirin. Merkezde, paketteki iki betik için:

```powershell
$signer = Get-Item Cert:\CurrentUser\My\<CODE_SIGNING_THUMBPRINT>
Set-AuthenticodeSignature -FilePath .\Install-AuthWire.ps1 -Certificate $signer
Set-AuthenticodeSignature -FilePath .\AuthWire-Client.ps1 -Certificate $signer
```

İmza betiği değiştirir; ZIP’in ilk hash listesi imza öncesi kaynak içindir. İmzadan sonra dağıtım hash listesini merkezde yeniden üretin. Kurumunuz kullanıyorsa kendi timestamp servisini ekleyin. İki betik aynı güvenilir yayıncıyla imzalanır. Kurucuya paket üretiminde config/açık güven dosyalarının hash’leri gömülür; Authenticode imzası bu sabit hash’leri de kapsar. Config/Root/Issuer/HTTPS güven dosyası imzadan sonra değiştirilirse kurucu reddeder. İmzalar geçerli değilse kurucu çalışmayı reddeder. `Bypass` veya imzasız paket dağıtımı yoktur. Mevcut kurum kod imzalama sertifikasının özel anahtarı AuthWire’a yüklenmez.

GPO Computer Configuration → Windows Settings → Scripts → Startup üzerinden `Install-AuthWire.ps1` dağıtılır. İlgili pilot OU ve bilgisayar grubuyla scope/security filtering seçilir. Paket, yalnız yetkili yöneticilerin yazabildiği SYSVOL/paylaşımda tutulur. Başlangıç komutu AllSigned politikasıyla çalışır; profile ait paket tüm gerekli açık dosyalarıyla aynı dizinde olmalıdır. Group Policy Management, görev/Trust kurulumunu merkezden yapar; IT her istemciye gitmez.

Kurucu ProgramData\AuthWire dizinini SYSTEM/Administrators erişimiyle korur, güven sertifikalarını makine depolarına kurar ve SYSTEM görevini kaydeder. Görev açılışta, 09:00/21:00’da ve ağ bağlantısı olayında çalışır; ağ yokken bekler. Başlangıçta 0–120 saniye jitter, hatada en fazla 12 saat + jitter olacak yerel backoff vardır. Yeniden deneme bir sonraki görev tetiklemesinde yapılır; kesintisiz polling yoktur. WDAC/AppLocker/Constrained Language uyumu kurumun gerçek pilotunda doğrulanmalıdır.

## Kayıt ve yenileme davranışı

- Kerberos SSPI `Kerberos` paketiyle, SYSTEM’in bilgisayar hesabı kullanılır. Ubuntu GSSAPI yalnız Kerberos kabul eder; NTLM, `X-Remote-User`, admin cookie veya caller GUID/SID kimlik kanıtı olmaz. Karşılıklı doğrulama ve her uygulama mesajına MIC, istek yolunu ve tam gövdeyi bağlar; AP-REQ relay’i farklı CSR ile değiştirilemez. Bu uygulama özel TLS exporter/CBT desteği iddiasında bulunmaz; HTTPS normal zincir/ad doğrulaması ve sertifika fingerprint pin’i ayrıca zorunludur.
- AuthWire canlı LDAP’ta bilgisayar SAM’ini GUID’ye çözer, nesne türü/etkinlik/SID/transitive güvenlik grup üyeliğini tekrar okur. UI kataloğu veya önceki pozitif karar yetkilendirme kaynağı olmaz. AD erişilemezse yeni sertifika verilmez.
- Sunucu challenge’ı kimlik, profil sürümü ve CSR hash’ine bağlar. CSR anahtarının imza kanıtı gerekir. Kimliği cert subject’inden çıkarmaz. Sertifika, SID/GUID bağı, CSR/anahtar fingerprint’i ve audit tek transaction’da yazılır.
- Cevap kesilirse aynı kimlik/CSR yeni challenge ile aynı geçerli sertifikayı alır. İptal, yabancı kimlik/yeniden oluşturulmuş AD hesabı ve farklı anahtar bunu geçemez. Açık, süresi dolmamış kurulum isteği ikinci sertifikayla çoğaltılmaz; kaybolan pending istemci durumu operatörün eski sertifikayı iptal etmesini gerektirir.
- İstemci yeni leaf’in kendi anahtarıyla eşleşmesini ve beklenen Root/Issuer/client-auth zincirini doğrular, LocalMachine\My’a kurar, yüklenen özel anahtarla kurulum makbuzu imzalar. “Kuruldu” sunucunun OS deposunu uzaktan ölçmesi değil, doğrulanmış istemcinin anahtar kanıtıyla bildirdiği kurulumdur. TPM attestation uygulanmamıştır.
- Yenilemede yeni CNG anahtarı kullanılır. Eski geçerli cert, yeni kurulum onaylanana kadar tutulur. Onaydan sonra eski cert en geç 24 saat/eski son geçerlilik tarihinde registry’de reddedilir ve CRL’ye eklenir. İstemci normal görev tetiklemesinde 12 saatten sonra kendi önceki cert/anahtarını temizler. Windows’un geçiş sırasında doğru cert’i seçmesi gerçek pilot kabul maddesidir.
- CRL, devredeki imzalayıcıyla son tarihinden önce otomatik yenilenir. Operatör otomatik imzalayıcıyı kapatırsa yeni kayıt/yenileme ve otomatik CRL imzalama durur; geçmiş iptal/registry deadline’ları geri alınmaz.
- Süresi dolan cert’e güvenilerek recovery yapılmaz. Fresh Kerberos + canlı AD yeniden kaydı gerekir. AuthWire/DC erişimi için önceden kontrollü kayıt ağı bulunmalıdır; bu paket bootstrap VLAN kurmaz ve üretim ağında fail-open açmaz.

## Anahtar ve çalışma kapsamı

Root yeniden oluşturulmaz ve otomatik hizmet tarafından açılmaz. Operatörün CA parolası saklanmaz; yalnız mevcut Issuer özel anahtarının kopyası OS-private vault ile mühürlenir. Şifreli Root/Issuer asılları, yöneticiler ve AD ayarları korunur. İmzalayıcı anahtar doğrulandıktan sonra bellekte tutulur; vault/CA değişiminde cache geçersizleşir. Geliştirme appliance’ında panel ve imzalayıcı aynı servis hesabındadır; HSM veya ayrı imzalayıcı servis izolasyonu tamamlanmış değildir. Üretim sertifikasyonu iddiası yoktur.

Profil/grup değişikliği gelecek kayıt/yenileme yetkisini ve yeni cert süresini etkiler; mevcut cert’leri otomatik topluca iptal etmez. Cihaz compromise’ında ayrıca iptal ve/veya AD kapsam dışına alma gerekir. TLS sertifikası/pin’i, Issuer veya kod imzalama zinciri değişirse merkezi paketi yeniden dağıtmak gerekir; CA/trust rollover ayrı operatör işidir.

## Doğrulama ve pilot kabulü

Yerel 1.000 cihaz / 4 worker sentetik AD testi: 1.000 farklı sertifika ve kurulum makbuzu, 10.848 saniye duvar, 14.352 saniye process CPU. Bu gerçek AD, Windows GPO veya ağ gecikmesi kapasite sonucu değildir. İlk denemede bulunan SQLite beklemesi, her istekte pahalı RSA private-key doğrulamasını tekrar etmeden, değişim kontrollü anahtar cache’iyle giderildi; anahtar doğrulaması atlanmaz.

CI ayrı olarak gerçek MIT KDC/GSSAPI karşılıklı doğrulama/MIC/replay/NTLM ret testlerini; Windows yerel CNG nonexportable CSR/key-proof/makine deposu kurulumunu; HTTPS profil/GPO/signer/mobil/logout akışlarını çalıştırır. Sentetik hesaplar gerçek AD pilotunun yerine geçmez.

İlk 5–10 Windows 11 domain bilgisayarında kabul:

1. GPO’yu aldıktan sonra son kullanıcı parola/CSR/komut görmeden kayıt.
2. İki cihazda farklı nonexportable anahtar; panelde iki gerçek GUID/SID.
3. Disabled, grup dışı ve domain dışı ret; AD/DNS/saat kesintisinde yanlış sertifika çıkmaması.
4. Yenileme, kesilmiş cevap, reboot/offline dönüş; kurulum onayı ve eski/yeni Windows certificate selection.
5. İptal, CRL, süre sonu ve kontrollü yeniden kayıt ağı.

Bu kabul tamamlanana kadar geniş GPO kapsamı açılmaz. **RADIUS/802.1X/switch değişikliği bu sürümün kurulumunun parçası değildir.**

## Birincil teknik kaynaklar

- [Microsoft Kerberos SSPI InitializeSecurityContext](https://learn.microsoft.com/en-us/windows/win32/secauthn/initializesecuritycontext--kerberos)
- [Microsoft ktpass](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ktpass)
- [Python GSSAPI high-level API](https://pythongssapi.github.io/python-gssapi/stable/gssapi.html)
- [Microsoft GPO sertifika dağıtımı](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/distribute-certificates-group-policy)

Microsoft AD CS yerel auto-enrollment API’si mevcut AuthWire HTTP API’sini kendiliğinden kullanmaz; bu sürüm GPO ile dağıtılan AuthWire istemcisini kullanır. AD CS entegrasyonu ayrı bir sonraki seçenektir.
