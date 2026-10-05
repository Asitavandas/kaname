# AD okuma laboratuvarı — 0.7.0-dev.1

Bu sürüm Windows'taki yerel geliştirme panelinden gerçek AD dizin okumayı denemek içindir. Linux appliance okuyucusu sonraki uygulama adımıdır; OVF hazır sayılmaz.

1. Kurulum ekranında gerçek AD DNS domain adını ve DC IP adreslerini kaydedin.
2. User&Authentication → Active Directory ekranını açın. DC'nin tam DNS adını ve `kullanici@domain` biçiminde kullanıcıyı girin. İlk sürümde UPN suffix'i kayıtlı domain ile aynı olmalı.
3. AD parolasını yalnız yerel panelde girin. LDAP Servers ekranında Name ve LDAP Server alanlarını, Distinguished Name içindeki OU kapsamını, eşitleme ve kontrol aralığını ayarlayıp Bağlantıyı kaydet düğmesine basın. Parola korumalı saklanır; alan temizlenir ve GET yanıtında geri verilmez. Şimdi eşitle kayıtlı bağlantıyı kullanır.
4. Son başarılı okumanın zamanı ve sayılar görüntülenir. User&Authentication → Users/User Groups ekranında Users ve User Groups listeleri birlikte gösterilir. Her liste ayrı aranır ve sayfalanır. Adına tıklayınca üyelik detayları açılır.
5. Güvenlik grubunun Politikada kullan düğmesi yeni politika formunda grup adını seçer. Politika formundan da grup adı aranabilir ve birden fazla grup seçilebilir; SID değerleri içeride saklanır. Kaydetmeden politika oluşturulmaz.

Domain Admin hesabı okunabilir ancak dizin okuması için bu yetki zorunlu değildir. AD'de yazma, domain join, GPO değişikliği veya hesap oluşturma yapılmaz. Parola boş bırakılarak mevcut kayıt korunabilir; kullanıcı/DC değişirse parola tekrar girilir. Windows DPAPI kullanıcı kapsamını kullanır; panel aynı Windows hesabıyla çalışmalıdır. Periyodik işler panel süreci çalışırken yürür. Kapsam boşsa veya domain DN’si girilirse tüm domain okunur. Bir OU adı veya tam/relative DN girildiğinde yalnız o konumun altındaki kullanıcı, grup ve bilgisayarlar okunur. Birden fazla konum için her satıra ayrı bir OU adı veya DN girin (en fazla 16). OU adı tekil olmalıdır; bulunamazsa veya aynı adda birden fazla OU varsa okuma açık hatayla durur. Nested ve primary üyelikler yalnız seçilen konumlar içindeki nesneler arasında çözülür; dış üyeler unresolved olarak gösterilir. Konumlar virgülle değil satır sonuyla ayrılır; DN içindeki virgüller hiyerarşiyi belirtir.

## Bağlantı koruması

Windows System.DirectoryServices.Protocols, AuthType.Kerberos, ProtocolVersion 3, Signing=true ve Sealing=true kullanılır. LDAP 389 üzerinde SASL koruması vardır; LDAP Basic veya NTLM'e düşüş yoktur. Bu yol ayrı CA/AD CS/LDAPS sertifikası gerektirmez. DNS ve saat uyumu, LDAP/Kerberos ağ erişimi ve uygun AD kullanıcı yetkisi gerekir. DC DNS adı kayıtlı domain altında olmalı ve çözümlenen bütün adresler kaydedilmiş DC IP'leriyle eşleşmelidir. Sorgular LDAP_SERVER_DOMAIN_SCOPE_OID (1.2.840.113556.1.4.1339) kritik kontrolüyle tek domain naming context içinde tutulur. Referral chasing kapalıdır; RootDSE domain eşleşmesi kontrol edilir.

Kimlik bilgileri Python subprocess stdin üzerinden JSON ile taşınır; komut satırına, ortam değişkenine veya geçici dosyaya yazılmaz. Ham subprocess stderr/AD hata açıklamaları API'ye ya da GitHub'a aktarılmaz. Windows işlemleri kapatılır. Bellek sıfırlama garantisi verilmez; Python/.NET stringleri immutable olabilir. Yönetim sunucusu yalnız loopback'te dinler ve kullanıcı oturumu, Write yetkisi ve CSRF/Host/Origin kontrollerini kullanır. Üretim HTTPS dağıtımı ayrı aşamadır.

## Katalog sınırları

Her kategori en fazla 10.000 nesne, 250 nesnelik LDAP sayfaları ve toplam 60 saniye işlem sınırı vardır. Eksik/tekrarlanan sayfa, limit, yanlış domain, bilinmeyen alan veya bozuk SID/GUID tüm okumayı reddeder; kısmi liste kaydedilmez. GUID/SID kalıcı kimliklerdir. Disabled kullanıcı/bilgisayar bilgisi userAccountControl ACCOUNTDISABLE bitinden gelir. Security ve distribution grupları katalogda ayrı etiketlenir. Politika seçicisinde yalnız security grupları gösterilir. Grup member özniteliğinin ranged yanıtları son sayfaya kadar okunur; eksik, tekrarlanan veya çakışan aralık reddedilir. Primary group RID'si hesap domain SID'siyle birleştirilir. Doğrudan, primary ve iç içe ilişkiler katalogdan hesaplanır.

Katalog kaydı ve audit aynı SQLite transaction içindedir. Yapılandırma okuma sırasında değişirse import reddedilir. Domain değişince eski katalog gizlenir. Son katalog önbellektir; canlı grup üyeliği veya kimlik doğrulama kanıtı değildir. Gösterilen üyelikler, hesap silinmesi/yeniden oluşturulması ve sertifika nesnesi eşlemesi RADIUS adaptörüne bağlanmadan ağ kararı üretmez. Üyelik ayrıntıları [üyelik kapsamı belgesinde](DIRECTORY_MEMBERSHIP.md).

Microsoft kaynakları:
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.authtype
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.ldapsessionoptions.signing
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.ldapsessionoptions.sealing
- https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.pageresultrequestcontrol

## Kabul

Fixture API/tarayıcı testleri credential, kalıcılık, CSRF/Origin, XSS ve başarısız okuma davranışını doğrular; gerçek AD testi yerine geçmez. Windows .NET self-test ağ çağrısı yapmadan sınıf/koruma seçeneklerini doğrular. Gerçek kullanıcı/grup okunması, geçersiz kullanıcı bilgisi, yanlış DNS/DC, uygun olmayan yetki ve AD kesintisi operatör laboratuvarında doğrulanmalıdır. GitHub raporlarına AD parolası/katalog içeriği yüklenmez.

Domain-scope kaynakları:
- https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ldap/ldap-server-domain-scope-oid
- https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/ldap-paged-queries-subordinate-referrals-not-chased

## LDAP Servers bağlantı testleri

Test connectivity yalnız DNS ve izin verilen DC IP’lerinde TCP 389 erişimini kontrol eder; parola kullanmaz. Test user credentials Kerberos korumalı bağlantıyı ve formda verilen OU kapsamının varlığını doğrular; kayıtlı kataloğu değiştirmez. Boş parola yalnız aynı kayıtlı sunucu ve kullanıcı için saklanan parolayı kullanır. Her iki işlem directory.connection Write yetkisi ve normal panel CSRF doğrulaması gerektirir. Şimdi eşitle kayıtlı kapsamı kullanır; form değişikliği önce kaydedilmelidir.

0.12.1 LDAP Servers ve çoklu OU düzenlemesi Linux paneli içindir. Mevcut Windows panel okuyucusu ve kurulumu korunur; otomatik Windows işleri duraklatılmıştır.
