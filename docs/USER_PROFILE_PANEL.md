# Kullanıcı sertifika profilleri — A03/A04 teknik hazırlık

Sertifikalar bölümündeki Kullanıcı profilleri ve Kullanıcı kayıtları, mevcut
bilgisayar profilleri/SYSTEM istemcisinden ayrı kullanıcı kayıt API'sini kullanır.
Yeni profil varsayılan olarak kapalıdır. Yönetici bir AD güvenlik grubunu açıkça
seçer; profil adı, 2–365 günlük geçerlilik ve geçerlilikten kısa yenileme aralığı
girer. Profil düzenlemesi sunucudaki sürümle kontrol edilir. Eski sürüm mevcut
kaydı ezmez; tarayıcıdaki taslak korunur.

Kayıt izni sertifika üretim/yenileme kapsamıdır. VLAN ve ağ erişim kararı erişim
kurallarıyla belirlenir. Kayıt iznini kapatmak mevcut sertifikayı iptal etmez.
Kullanıcının etkinliği, değişmez AD GUID/SID ve grup üyeliği kayıt/yenilemede
sunucuda doğrulanır. Katalogdaki grup adı yalnız gösterimdir; SID'nin yerine geçmez.
Ayrı AuthWire erişim grubu veya AD üyeliği değiştiren işlem eklenmez.

Kullanıcı paketi indirmek GPO oluşturmaz, imzalama yapmaz veya bilgisayarın
Ethernet/Wi-Fi ayarını değiştirmez. İki script kurumun güvenilir yayıncısıyla
imzalanıp USER Configuration logon kapsamına dağıtılır. CA/HTTPS kök güveni ve
kod imzalayan yayıncı GPO ön koşuludur. Bilgisayar başlangıcında SYSTEM olarak
çalıştırılmaz. Ortak imzalayıcı mevcut Dağıtım sekmesinden yönetilir; kullanıcı
sekmesi açılınca signer etkinleştirme/durdurma işlemi yapılmaz.

Kullanıcı kayıtları oluşturulma, kurulum teyidi, yenileme beklemesi, süre dolması
ve iptal durumlarını ayrı gösterir. Şimdi yenile yalnız sunucuda talep işaretler;
istemcinin sonraki kontrolü beklenir ve mevcut bağlantı anında değişmiş sayılmaz.
Yetkiler certificates.authority read/write kapsamındadır. Salt okunur hesap
profilleri/kayıtları görebilir; paket indirme, kaydetme veya yenileme yapamaz.

Kaydetme tek istektir. Belirsiz ağ/zaman aşımı sonucunda otomatik yazma tekrarı
yoktur; taslak kilitlenir ve önce kayıtlı sonuç okunur. Kaydetme başarılı, sonraki
liste okuması başarısızsa başarı ile liste hatası ayrı gösterilir. Diğer yönetici
profil sürümünü değiştirmişse taslak korunur. Oturum kapanınca bekleyen yanıtlar
profil/kayıt verisini tekrar ekrana getiremez. Hiçbir özel anahtar/parola veya
kalıcı tarayıcı deposu kullanılmaz.

Tarayıcı teknik testleri geçici HTTPS/CA ve gerçek profil/paket/yenileme API'lerini
kullanır; AD kayıtları ve ilk kullanıcı sertifikası sentetik fixture ile hazırlanır.
Bu test, gerçek AD kullanıcısı/GPO dağıtımı veya 802.1X saha kabulü değildir.
Kullanıcının isteğiyle gerçek test bilgisayarı kabulü pazartesiye bırakılmıştır.
A03/A04 bütünü, merkezi GPO otomasyonu ve kullanıcı/bilgisayar geçiş kabulü açık kalır.
