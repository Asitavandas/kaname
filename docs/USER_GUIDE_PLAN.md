# AuthWire son sürüm kullanım kılavuzu — teslimat planı

READY_FOR_FINAL_GUIDE=false
GUIDE_DELIVERED=false

Durum: Planlandı; ürünün hedef sürümü ve işlevsel kabul testleri tamamlandıktan sonra hazırlanacak. Bu belge kullanım kılavuzunun kendisi değildir. 26 Ekim 2026 operatör talebiyle zorunlu kapanış teslimatına eklendi. İşlevsel 94 maddelik test sayımı ayrı kalır; bu teslimat unutularak proje kapanışı yapılmaz.

## Hedef ve biçim

AuthWire panelini ilk kez kullanan bir BT yöneticisinin işlemleri kendi başına yapabileceği, sade ve anlaşılır Türkçe bir kılavuz. Nihai panel sürümü esas alınır. Düzenlenebilir Word ve aranabilir/içindekiler bağlantılı PDF teslim edilir; sürüm numarası ve hazırlanma tarihi açıkça belirtilir.

## Eksiksiz ekran kapsamı

Nihai sürümdeki bütün ana/alt menüler, sayfalar, sekmeler, başlıklar, formlar, alanlar, butonlar, açılır menüler, seçim panelleri, durum mesajları ve widget kontrolleri envantere alınır. Yetkiye bağlı görünüm/işlem farkları açıklanır. Envanter-kılavuz karşılaştırmasıyla açıklanmamış öğe bırakılmadığı kontrol edilir; yalnız henüz uygulanmamış fikirler mevcut özellik gibi anlatılmaz.

Her öğe için:
- Ne işe yarar, ne zaman kullanılır ve ön koşulları nelerdir?
- Hangi bilgi girilir/seçilir; biçimi, geçerli değerleri, varsayılanı ve zorunluluğu nedir?
- Butona basınca ne değişir; yalnız kayıt/önizleme mi, yoksa gerçek uygulama mı yapılır?
- Adım adım nasıl yapılır; başarı nasıl doğrulanır?
- Sık hata/durum mesajı ne demektir ve nasıl giderilir?
- Güncelleme, devre dışı bırakma, silme ve varsa geri alma nasıl yapılır?

## İş akışları

Son sürümde bulunmaları durumunda kurulum/ilk erişim, AD bağlantısı ve senkronizasyon, kullanıcı/grup/bilgisayar listeleri, kimlik doğrulama kapsamları, erişim kuralları ve VLAN, sertifika üretimi/dağıtımı/yenileme/iptal/kurtarma, Windows Connector, merkezi Windows/GPO dağıtımı, kablolu/kablosuz 802.1X, RADIUS istemcileri, olay/denetim kayıtları, yetkiler, dashboard/widget düzeni, sistem kaynakları, yedekleme/geri yükleme ve sürüm güncelleme anlatılır. İptal edilmiş yerel AuthWire grupları güncel özellik olarak geri getirilmez. Müşterinin DNS mimarisini değiştirmek bir gereklilik olarak eklenmez.

Uçtan uca örnekler: yeni ortamı hazırlamak; pilot kullanıcı/bilgisayar seçmek; imzalı dağıtımı önizleyip kontrollü uygulamak; sertifika ile wired/Wi-Fi bağlantısı kurmak; VLAN kuralı yazmak; yenileme/iptal ve bekleyen görev/hata durumunu çözmek. Gerçek son sürüm ekran görüntüleri ve açıklamalar kullanılır; gizli anahtar, parola ve RADIUS secret gösterilmez. Kısa terimler sözlüğü ve hızlı başlangıç bölümü eklenir.

## Kabul ve kapanış

Önce nihai UI/kontrol envanteri çıkarılır, sonra örnekler uygulanmış davranış ve kabul kanıtlarıyla karşılaştırılır. Gerçek GPO uygulaması, yalnız hazırlık, plan kaydı, görev gönderimi ve tamamlanma birbirinden doğru biçimde açıklanır. Kullanıcı panel/işlevsel hedef sürümün tamamlandığını kabul ettiğinde READY_FOR_FINAL_GUIDE=true yapılır. Word/PDF teslim edilip bağlantıları kaydedildikten sonra GUIDE_DELIVERED=true yapılır ve ilgili koşullu hatırlatma durdurulur.

## Koşullu takip

Otomasyon kimliği: 6adfa509447081919aee1bcf3095f0ae. Europe/Istanbul saat diliminde günlük durum kontrolü yapar; yalnız READY_FOR_FINAL_GUIDE=true ve GUIDE_DELIVERED=false ise hatırlatır. Kendiliğinden hazırlanmış kılavuz veya teslim edilmiş dosya iddiası oluşturmaz. Word/PDF teslimatından sonra GUIDE_DELIVERED=true kaydıyla birlikte bu otomasyon durdurulur.
