# AuthWire yerel erişim grupları ve merkezi Windows dağıtımı

Tarih: 24 Ekim 2026, Europe/Istanbul.
Durum: Operatör tarafından onaylanmış geliştirme kapsamı; henüz uygulanmadı.
Bu belge eski tarihli kapsam belgelerine aşağıdaki konularda ek/güncellemedir.
Güncel ilerleme kaydı: CURRENT_STATUS.md.

## A01 — AuthWire içinde yerel VLAN erişim grupları (açık)

- AD'den alınan kullanıcı veya bilgisayarlar AuthWire içinde oluşturulan isimli
  yerel erişim grubuna seçilerek eklenebilir. Örnek: VLAN50-Kullanicilari,
  farklı AD güvenlik gruplarında bulunan on kullanıcıyı içerir.
- Bu işlem AD güvenlik grubu oluşturmaz, AD üyeliklerini yazmaz ve mevcut AD
  gruplarından kullanıcı çıkarmaz. Yerel erişim grubu üyeliği AuthWire'da tutulur;
  kalıcı domain/GUID/SID kimliğiyle bağlanır. Aynı adlı yeni AD hesabı eski
  hesabın yetkisini devralmaz. Silinmiş/devre dışı hesaplar erişim kazanmaz.
- VLAN yerel grubun adına bakılarak tahmin edilmez; grubu kullanan izin
  politikasındaki VLAN değeri RADIUS yanıtına aktarılır. Switch/AP VLAN yolu ve
  DHCP müşteri tarafından hazırlanır.
- Kullanıcı grubu, doğrulanmış kullanıcı kimliğiyle; bilgisayar grubu,
  doğrulanmış bilgisayar kimliğiyle değerlendirilir. Makine EAP-TLS oturumundan
  oturum açan kullanıcıya yetki çıkarılmaz.
- Şu an doğrudan hesap SID'si veya AD güvenlik grubu seçimi bulunması,
  isimli yerel grup CRUD/üyelik yaşam döngüsünün hazır olduğu anlamına gelmez.

Kabul: Farklı AD güvenlik gruplarındaki on kullanıcının yerel gruba seçilmesi,
kalıcı saklama/okuma ve gerçek kullanıcı EAP-TLS ile VLAN50 DHCP; AD üyelikleri
değişmeden kalmalı. Bilgisayar kimliği için ayrı eşdeğer kabul yapılmalı.

## A02 — Tek yerel erişim grubu ve kural çakışmasını engelleme (açık)

- Bir kullanıcı veya bilgisayar aynı anda yalnız bir AuthWire yerel VLAN
  erişim grubunda bulunabilir. Başka gruba eklemek için önce eski üyelikten
  açıkça çıkarılmalıdır; sessiz taşıma veya otomatik eski üyelik silme yoktur.
  Bu kısıt AD'deki olağan çoklu güvenlik grubu üyeliğini yasaklamaz.
- İkinci üyelik eklenirken mevcut grup adı gösterilir; işlem kaydedilmez.
  Kullanıcı/bilgisayar ekleme, toplu ekleme ve kural oluşturma/düzenleme/
  etkinleştirme yollarında çakışma kontrolü yapılır.
- Koruma yalnız tarayıcıda kalmaz: sunucu tarafında atomik kayıt,
  eşzamanlı istekler ve revizyon değişimi karşısında da uygulanır.
- Yerel grup tekilliği tüm kural çakışmalarını tek başına çözmez. Doğrudan
  hesap, AD grubu, iç içe üyelik ve genel kurallardan aynı doğrulamada farklı
  karar/VLAN çıkması da denetlenir. Yöneticiye ilgili gruplar ve kurallar
  gösterilir, çakışan kuralın kaydı/etkinleştirilmesi engellenir.
- Güncel AD bilgisi alınamadığında çakışma yokmuş gibi etkinleştirme yapılmaz.
  Sonradan AD üyeliği değişirse yeni çakışma uyarılır ve çalışma anında mevcut
  güvenli POLICY_CONFLICT reddi korunur. İlk/son/yeni kuralın sessiz kazanması
  veya örtülü öncelik eklenmesi kapsamda değildir.
- Çakışma kontrolü mevcut çalışan kuralları bu plan kaydı sırasında değiştirmez.

Kabul: Aynı hesaba iki grup, toplu eklemede kısmi/atomik davranışın açık olması,
eşzamanlı kayıt, AD/doğrudan/genel kural çakışmaları, devre dışı/yeniden etkin
kural ve sonradan AD değişimi testleri. Uyarı açık, kayıt engeli sunucuda olmalı.

## A03 — Kullanıcı kimlik doğrulaması (mevcut açık yol haritasının devamı)

- Kullanıcı EAP-TLS sertifikası üretim/kurulum/yenileme/iptal ve kullanıcı
  deposu/özel anahtar izinleri için gerçek Windows kabulü.
- Kullanıcı veya kullanıcı grubu politikasından kablolu/kablosuz VLAN kararı.
- Bilgisayar doğrulaması ile kullanıcı doğrulaması ve desteklenen
  kullanıcı/bilgisayar geçiş davranışı ayrı ayrı kanıtlanır. Windows'taki
  kullanıcı veya bilgisayar modu eşzamanlı iki kimlik kanıtı diye sunulmaz.
  TEAP ile eşzamanlı kimlik zincirleme bu onayla kendiliğinden eklenmez.
- Çalışan makine EAP-TLS pilotları ve bilgisayar sertifika yaşam döngüsü korunur.

## A04 — Merkezi Windows dağıtımı ve GPO tam otomasyonu (açık)

Hedef: Bir defalık yetkilendirilmiş müşteri kurulumundan sonra günlük dağıtım
ve yönetim AuthWire panelinden yürüsün; her bilgisayarın Ethernet/Wi-Fi
özellikleri elle açılıp düzenlenmesin.

- Panelden hedef OU/bilgisayar grubu, kayıt profili, kablolu ve kablosuz
  kimlik doğrulama yöntemi, SSID, sunucu adı ve güvenilen CA seçimi.
- CA güveni, sertifika kayıt/yenileme istemcisi ve görevleri, kablolu 802.1X
  profili ve WLAN EAP-TLS profili için sürümlü merkezi paket.
- Kullanıcı sertifikası dağıtımı için kullanıcı kapsamı; makine sertifikası
  ve ağ profilleri için uygun bilgisayar kapsamı ayrı tasarlanır. Seçilen
  kullanıcı listesinden kullandığı bilgisayarlar kendiliğinden varsayılmaz.
- Sınırlı yetkili Windows yönetim bileşeni üzerinden AuthWire'a ait GPO'nun
  oluşturulması/güncellenmesi/uygun kapsamına bağlanması. İlk yetki devri
  ve bileşen kurulumu müşteri yöneticisi tarafından bir kez yapılır.
- Günlük salt okunur AD eşitlemesi GPO yazma yetkisine dönüştürülmez.
  Mevcut LDAP hesabına sessiz Domain Admin yetkisi verilmez.
- İmzalı paket ve AllSigned korunur; kurumsal kod imzalama özel anahtarı
  AuthWire'a taşınmaz. Yetkili Windows imzalama/dağıtım yolu tasarlanır.
- GPO değişikliğinden önce hedef ve fark önizlemesi, kapsamlı hata raporu,
  kontrollü pilot yayılım, sürüm/geri alma ve işlemi yapan yönetici kaydı.
  İlgisiz müşteri GPO'ları/üyelikleri değiştirilmez.
- Panelden dağıtım, son uygulama/sertifika durumu ve hata/yeniden deneme
  takibi. GPO güncellemesi veya yeniden açılış gerektiren zamanlamalar
  görünür olur; anında uygulanmış gibi gösterilmez.
- İlk pilot sonrasında 200 kullanıcı/bilgisayar ölçeğinde kayıt, yenileme,
  politika/üyelik, GPO güncellemesi ve hata toparlama kabulü.

Mevcut durum: GPO ile pilot bilgisayar sertifika istemcisi ve SYSTEM görevleri
dağıtıldı/test edildi. GPO/SYSVOL hazırlığı merkezi fakat yetkili operatör
tarafından yapıldı. Ethernet/Wi-Fi profilleri pilotta elle ayarlandı.
Panelden GPO oluşturma/bağlama ve uçtan uca profil dağıtımı henüz yoktur.
Bu plan, bunların bugün hazır olduğunu veya 200 cihaz kabulünün geçtiğini
iddia etmez.

## Devam sırası ve koruma

1. Panel görsel işleri operatör isteğiyle beklemede.
2. Önce mevcut fonksiyonel kabul listesinin kaldığı yer doğrulanır:
   kullanıcı EAP-TLS yeni ana çalışma başlığıdır; önceki B02/B04/B06/B08/B10/
   B11/B12 açık alt işleri kendi kanıt sınırlarıyla korunur.
3. A03 kullanıcı pilotu, A01/A02 yerel grup ve çakışma geliştirmesi,
   A04 merkezi dağıtım/GPO tasarım ve uygulaması, ardından kontrollü ölçek
   kabulü için ayrı tamamlanma kapıları açılır; bu sıra planlamadır,
   bu kayıt uygulama veya canlı değişiklik değildir.
4. Gerçek expiry testi ayrı cihaz bekliyor. Off-host yedek ve tam appliance
   restore/boot kabulü açık. NTP uzun süre/reboot izlemi duraklatılmıştır.
   DHCP/DNS dağıtım mimarisi operatör kararıyla kapsam dışı kalır.
5. Canlı dev.26, çalışan RADIUS/broker, kurallar, CA/sertifikalar, Windows/GPO,
   logo, mevcut hizmet ve günlük yedek/CRL zamanlayıcıları bu kayıtta değişmez.
