# AD okuma laboratuvarı — 0.3.0-dev.1

Bu sürüm Windows'taki yerel geliştirme panelinden gerçek AD dizin okumayı denemek içindir. Linux appliance okuyucusu sonraki uygulama adımıdır; OVF hazır sayılmaz.

1. Kurulum ekranında gerçek AD DNS domain adını ve DC IP adreslerini kaydedin.
2. Active Directory ekranını açın. DC'nin tam DNS adını ve `kullanici@domain` biçiminde kullanıcıyı girin. İlk sürümde UPN suffix'i kayıtlı domain ile aynı olmalı.
3. AD parolasını yalnız yerel panelde girin. Bağlan ve bilgileri getir düğmesine basın. Parola alanı hemen temizlenir; sunucu parolayı kaydetmez.
4. Son başarılı okumanın zamanı ve sayılar görüntülenir. Kullanıcı/grup/bilgisayar listelerinde arama ve sayfalama yapabilirsiniz.
5. Güvenlik grubunun Politikada kullan düğmesi yeni politika formuna SID taşır. Kaydetmeden politika oluşturulmaz.

Domain Admin hesabı okunabilir ancak dizin okuması için bu yetki zorunlu değildir. AD'de yazma, domain join, GPO değişikliği veya hesap oluşturma yapılmaz. Her yenilemede parola yeniden girilir; otomatik runtime hesabı/secret kasası bu sürümde yoktur.

## Bağlantı koruması

Windows System.DirectoryServices.Protocols, AuthType.Kerberos, ProtocolVersion 3, Signing=true ve Sealing=true kullanılır. LDAP 389 üzerinde SASL koruması vardır; LDAP Basic veya NTLM'e düşüş yoktur. Bu yol ayrı CA/AD CS/LDAPS sertifikası gerektirmez. DNS ve saat uyumu, LDAP/Kerberos ağ erişimi ve uygun AD kullanıcı yetkisi gerekir. DC DNS adı kayıtlı domain altında olmalı ve çözümlenen bütün adresler kaydedilmiş DC IP'leriyle eşleşmelidir. Referral chasing kapalıdır; RootDSE domain eşleşmesi kontrol edilir.

Kimlik bilgileri Python subprocess stdin üzerinden JSON ile taşınır; komut satırına, ortam değişkenine veya geçici dosyaya yazılmaz. Ham subprocess stderr/AD hata açıklamaları API'ye ya da GitHub'a aktarılmaz. Windows işlemleri kapatılır. Bellek sıfırlama garantisi verilmez; Python/.NET stringleri immutable olabilir. Yönetim sunucusu yalnız loopback'te dinler ve mevcut token/Host/Origin kontrollerini kullanır. LAN'a reverse proxy ile açmayın; üretim HTTPS/RBAC ayrı aşamadır.

## Katalog sınırları

Her kategori en fazla 10.000 nesne, 250 nesnelik LDAP sayfaları ve toplam 60 saniye işlem sınırı vardır. Eksik/tekrarlanan sayfa, limit, yanlış domain, bilinmeyen alan veya bozuk SID/GUID tüm okumayı reddeder; kısmi liste kaydedilmez. GUID/SID kalıcı kimliklerdir. Disabled kullanıcı/bilgisayar bilgisi userAccountControl ACCOUNTDISABLE bitinden gelir. Yalnız güvenlik grupları okunur; distribution grupları erişim grubu olarak gösterilmez.

Katalog kaydı ve audit aynı SQLite transaction içindedir. Yapılandırma okuma sırasında değişirse import reddedilir. Domain değişince eski katalog gizlenir. Son katalog önbellektir; canlı grup üyeliği veya kimlik doğrulama kanıtı değildir. Nested/primary grup, hesap silinmesi/yeniden oluşturulması ve sertifika nesnesi eşlemesi RADIUS adaptörüne bağlanmadan ağ kararı üretmez.

Microsoft kaynakları:
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.authtype
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.ldapsessionoptions.signing
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.ldapsessionoptions.sealing
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.pageresultrequestcontrol

## Kabul

Fixture API/tarayıcı testleri credential, kalıcılık, CSRF/Origin, XSS ve başarısız okuma davranışını doğrular; gerçek AD testi yerine geçmez. Windows .NET self-test ağ çağrısı yapmadan sınıf/koruma seçeneklerini doğrular. Gerçek kullanıcı/grup okunması, geçersiz kullanıcı bilgisi, yanlış DNS/DC, uygun olmayan yetki ve AD kesintisi operatör laboratuvarında doğrulanmalıdır. GitHub raporlarına AD parolası/katalog içeriği yüklenmez.
