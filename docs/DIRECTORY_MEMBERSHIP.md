# AD üyelikleri — 0.5.0-dev.1

## Kullanım

Sol menüde **User&Authentication → Active Directory** bağlantı ekranıdır. DNS/domain/DC ayarları Kurulum'da korunur; DC DNS adı ve geçici AD kimlik bilgileriyle dizin buradan okunur. Parola kaydedilmez.

**User&Authentication → Users/User Groups** iki listeyi aynı ekranda gösterir. Users kullanıcı hesaplarıdır; User Groups AD gruplarıdır. Her listenin bağımsız araması ve sayfalaması vardır. İsme tıklayınca detay penceresi açılır:

- Kullanıcıda **Member of**: üye olduğu gruplar.
- Grupta **Members**: üye olan kullanıcılar.
- **Doğrudan**, **Primary group** ve **İç içe grup üzerinden** etiketleri ilişki türünü gösterir.
- Bir detay satırındaki karşı nesneye tıklayarak diğer detay açılır. Arama ve Önceki/Sonraki düğmeleri detay içinde de bulunur.

Detaylar kayıtlı katalogdan okunur; her tıklamada AD parolası istenmez. Eski katalog üyelik bilgisi içermiyorsa boş üyelik varsayılmaz; AD ekranından bir kez yeniden okuma gerektiği açıkça yazılır. Başarısız yenilemede eski katalog korunur.

## Kapsam

Tek domainin son başarılı okuması gösterilir. Kullanıcı/bilgisayar/grup nesneleri SID/GUID ile eşlenir. Kullanıcının primaryGroupID RID'si hesap domain SID'siyle birleştirilir; normal member listesinde bulunmasa da ilişki eklenir. Grup member bağlantılarından döngülere dayanıklı gezintiyle iç içe üyelikler hesaplanır. Primary üyelik ve doğrudan üyelik, aynı grup için dolaylı yoldan bulunan eşleşmeden önceliklidir.

Security ve distribution grupları türleriyle listelenir; distribution grubu üzerinden oluşan yapısal iç içe ilişki de gösterilir. Politika seçicisi yalnız security gruplarını sunar. Bu görüntü Windows access token/tokenGroups veya gerçek EAP kimlik doğrulama kanıtı değildir; erişim değerlendirmesine bağlama sonraki aşamadır.

Grup detayında kullanıcılar listelenir. İlişkili bilgisayarlar ayrı sayıyla, katalogda çözülemeyen yabancı-domain/contact/diğer nesne referansları kapsam dışı sayıyla belirtilir; bunlar kullanıcıymış gibi gösterilmez. Diğer domainlerin bütün üyelikleri bu tek domain okumasıyla tamamlanmış sayılmaz. Primary grup bulunamazsa kullanıcı detayında ayrıca bildirilir.

## Okuma ve yetki sınırları

Kerberos signing/sealing, tek domain scope ve referral reddi korunur. LDAP nesne sayfalaması yanında member;range başlangıç/bitiş/son-sayfa doğrulaması yapılır. Devam sorguları Base kapsamıyla aynı gruba gider; istenen devam parçası en fazla 1000 değer. Eksik/tekrarlanan aralık, duplicate üye, yönlendirme veya limit aşımı tüm importu reddeder.

Kategori başına en fazla 10.000 nesne, grup başına 10.000 üye referansı, toplam 100.000 üye referansı ve 100.000 ilişki, 24 MB helper yanıtı ve 60 saniye toplam okuma sınırı geçerlidir. Büyük kataloglarda bu sınırlar açık başarısızlıkla eski veriyi korur; sessiz kesme yoktur. Liste/detay yanıtları 100 sonuçluk sayfalardır.

Custom profilde **User&Authentication / Active Directory** bağlantıya, **Users/User Groups** katalog ve detaylara yetki verir. Bağlantı için Write, liste/detay için Read gerekir. Eski directory.catalog hakkı ayrı connection ayarı yoksa eski bağlantı hakkını korur; matriste ayrı değer kaydedildiğinde bağımsız olur. Kullanıcı ve grup detay endpoint'i de sunucu tarafında yetki denetimine tabidir.

Microsoft kaynakları:

- [Primary group normal member/memberOf listesinde bulunmaz](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-ada3/e12954a4-6865-4432-94e6-00c310ca87c0)
- [LDAP öznitelik aralığı okuma](https://learn.microsoft.com/en-us/windows/win32/adsi/attribute-range-retrieval)
- [Security/distribution groupType bayrakları](https://learn.microsoft.com/en-us/windows/win32/adschema/a-grouptype)
