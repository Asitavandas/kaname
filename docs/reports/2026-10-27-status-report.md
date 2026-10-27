# AuthWire güncel durum raporu

27 Ekim 2026 | Tamamlanan işler ve devam planı

Bilgisayar sertifikasıyla kablolu ve kablosuz 802.1X erişimi ve VLAN ataması gerçek cihazlarda çalıştı. Bugün ulaştığımız nokta, panelden gönderilen dağıtım adayının Connector tarafından imza ve içerik bakımından doğrulanmasıdır. Merkezi GPO uygulaması ve kullanıcı sertifikalı erişimin saha kabulü hâlâ açık.

### Ne kadar bitti ne kadar kaldı

| Kapsam | Tamamlanan | Kalan |
| --- | --- | --- |
| Temel ürün B01 ile B12 | 44 / 59 · %75 | 15 / 59 · %25 |
| Yedi geliştirme G01 ile G07 | 10 / 35 · %29 | 25 / 35 · %71 |
| İlk kayıtlı listenin toplamı | 54 / 94 · %57 | 40 / 94 · %43 |

Sayım, önceki raporla aynı 94 alt işi temel alır. Bir alt iş tüm kabul şartlarıyla kapanınca 1; kısmi veya açıkken 0 sayılır. Bu oran çalışma süresi veya üretime hazır olma oranı değildir. 9 Ekim başlangıcındaki 36/94 sonucuna göre 18 ilave alt iş kapanmıştır.

Son günlerde tamamlanan Connector ve imzalama adımları açık merkezi dağıtım paketinin parçalarıdır. Bunlar ayrıca anlatıldı; aynı işe ikinci puan verilmedi. Bu nedenle önemli ilerleme olmasına rağmen ana oran %57 olarak korunuyor.

### Son doğrulanan sürümler

Linux panel ve RADIUS kaynağı 0.14.0-dev.39. DC01 Connector sürüm kimliği b5469eaa-0ccf-4558-bd84-c2f6a10ecb2f. Son kurulum kabulünde RADIUS aktifti; Linux güncellemesinde RADIUS ve kontrol hizmeti süreçleri korundu. Bu bilgiler son kabul kayıtlarıdır; anlık yeni sağlık ölçümü değildir.

İşaretler: Kırmızı ✓ tamamlanan dar adımı gösterir. Kısmi, bazı parçaların çalıştığı ancak bütün kabulün kapanmadığı anlamına gelir. Test bekliyor, geliştirilmiş parçanın gerçek ortam doğrulamasının eksik olduğunu belirtir.

## Tamamlanan ve korunan işler

✓ Kablolu bilgisayar erişimi ve VLAN. HPE Instant On 1930 üzerinden makine sertifikalı bağlantı ve VLAN sonucu kabul edildi. VV06 için önceki doğrulanmış Ethernet adresi 10.10.110.4/24.

✓ Kablosuz bilgisayar erişimi ve VLAN. AP22 ve VV_802.1X ağı üzerinden bağlantı, kural değişikliğinin DHCP sonucuna yansıması ve VLAN 140 kabul edildi. Önceki saha adresi 10.10.140.2/24.

✓ Sertifika dağıtımı ve yenileme. İmzalı pilot GPO paketi, SYSTEM görevi, cihazın kendi özel anahtarıyla kayıt olması, yenileme ve belirli eski sertifika temizliği senaryoları doğrulandı.

✓ Olumsuz güven testleri. Yanlış Wi-Fi sunucu adı ve yanlış kök ayrı ayrı reddedildi. Doğru güven profiline dönüşte erişim geri geldi. Bunlar tüm olumsuz testlerin bittiği anlamına gelmez.

✓ Belirli kesinti ve kurtarma testleri. Yarım kurulumdan aynı bekleyen anahtarla devam, bazı ağ geri dönüşü ve gerçek açılış senaryoları geçti. Aralıklı yeniden deneme bulgusu ayrıca açık tutuluyor.

✓ Policy yönetimi ve kayıtlar. İzin ve ret, VLAN, etkinleştirme ve devre dışı bırakma, düzenleme ve silme işlemleri geliştirildi. Kullanıcı veya bilgisayar doğrulama kapsamı panelde görüldü.

✓ Yedek ve CRL işletimi. Günlük yerel yedek, gerçek arşivden izole veri geri yükleme ve CRL eşitleme doğrulandı. Tam appliance açılışı ve sunucu dışı kopya ayrı açık.

✓ Panel ve logo. Dashboard, widget ekleme ve çıkarma, taşıma ve boyutlandırma, kaynak göstergeleri ve gizlenebilir menü teslim edildi. Metalik siyah logo kullanıcı tarafından kabul edildi; şekli korunuyor.

✓ Kullanıcı altyapısı. Kullanıcı sertifikası sunucusu, ayrı Windows istemcisi ve kullanıcı profilleri ile kayıtları sekmeleri hazır. Sekmelerin açılması kabul edildi. Gerçek kullanıcıyla ağ erişimi henüz kabul edilmedi.

## 25 ile 27 Ekim arasında kapanan adımlar

✓ KDS ve yönetilen hizmet hesabı. KDS hazır duruma geldi. Mevcut aw-deploy$ hesabı kuruldu ve gerçek hizmet sürecinde beklenen SID ile oturum açabildi. Yeni müşteri kurulumunda her seferinde elle sorgu dizisi yerine standart hazırlık yolu hedefleniyor.

✓ Sınırlı GPO yetkisi. AuthWire için ayrı yönetilen GPO hazırlandı. Hizmet hesabının AD ve SYSVOL üzerinde sınırlandırılmış yazma ve okuma denemesi başarılı oldu; deneme kalıntıları temizlendi. Bu, dağıtımın uygulandığı anlamına gelmez.

✓ Kod imzalama ve anahtar erişimi. Dışa aktarılamayan RSA 3072 makine anahtarıyla kod imzalama sertifikası hazırlandı. Gerçek hizmet hesabı imzaladı; Authenticode doğrulandı. Mevcut anahtar ve izinler korundu.

✓ HTTPS ve eşleştirme. DC01 tarafında normal TLS doğrulaması ve sabitlenmiş sunucu parmak izi başarılı oldu. Ayrı kanal anahtarı ve panel eşleştirmesi hazırlandı; özel anahtar Linux tarafına taşınmadı.

✓ Kalıcı Connector hizmeti. DC01 hizmeti aw-deploy$ ile çalıştı. Kontrollü durdurma ve başlatmadan sonra yeni sağlık sonucu alındı. Panelden gönderilen sınırlı test görevinin sonucu döndü.

✓ Dağıtım planı ve imzalı aday. Pilot plan ve ağ profilleri paketi hazırlandı. Aday manifesti imzalandı; operatör sonucu panele kaydedildi. Paket henüz tam istemci kurulum ve GPO uygulama paketi değildir.

✓ Güvenli Connector güncellemesi. Yeni aday doğrulama bileşeni aşamalı hazırlandı ve etkinleştirildi. Hesap, eşleştirme, kanal anahtarı ve kod imzalama anahtarı korundu. Müşteri ortamında geri alma testi yapılmadı.

✓ İlk gerçek içerik doğrulama dönüşü. 27 Ekim ekranında “İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.” sonucu görüldü. Bu, operatör ekran kanıtıyla kabul edildi; ayrı ham sonuç veya veritabanı incelemesi yapılmadı.

Bu başarılar merkezi dağıtımın hazırlık ve iletişim katmanını ilerletti. Canlı AD hedefleri, güncel GPO kapsamı, SYSVOL hazırlığı, gerçek uygulama ve uç cihaz kabulü kapanmadan tam otomasyon tamamlandı sayılmayacak.

## Temel ürünün ilk altı başlığı

### B01 Panel ve yönetici erişimi 4 / 5 tamam

HTTPS, yönetici erişimi ve panel altyapısı çalışıyor. Açık: temiz kurulumdan ilk erişime kadar işletim sistemine uygulanan kurulum akışı ve hata halinde geri dönüş; kalan görünüm ve uzun süre kullanım kabulleri.

### B02 AD ve yetkilendirme 3 / 5 tamam

Kullanıcı, grup ve bilgisayar kataloğu; OU kapsamı ve canlı kimlik kontrolü var. Açık: silinmiş hesap ve AD erişilemezliği saha kabulü; AD gecikmesi, eşzamanlı kapasite ve tek hizmet hesabına geçiş.

### B03 CA güveni ve sertifikalar 3 / 5 tamam

Kök ve imzalayan CA, güven paketi, CRL ve gerçek sunucu güveni var. Açık: gerçek süresi dolmuş sertifika, yanlış imzalayan CA, CA geçişi ve kod imzalama sertifikası yenileme kabulü.

### B04 Bilgisayar kayıt hizmeti 4 / 5 tamam

Kayıt ve yenileme API, Kerberos kimliği, Windows anahtarı ve gerçek SYSTEM kaydı çalışıyor. SQLite erişim kilidi düzeltmesi kuruldu. Açık: kalan kesilmiş yanıt ve tekrar çeşitleri, tüm yük kabulü ve aralıklı yeniden deneme araştırması.

### B05 Dar pilot GPO paketi 5 / 5 tamam

İmzalı SYSVOL paketi, pilot grup, cihazın ayrı anahtarı ve AllSigned başlangıç kaydı kabul edildi. Dar paket tamam. Panelden 200 bilgisayara otomatik GPO oluşturma, bağlama, uygulama ve geri alma G01 ve A04 altında açık.

### B06 Yenileme ve kurtarma 4 / 5 tamam

Geçerli eski kimliğin korunması, yeni seriyle erişim ve belirli ağ veya açılış toparlanmaları kabul edildi. Açık: gerçekten süresi bitmiş sertifikadan kurtarma ve kalan seçim ile temizlik çeşitleri.

Bu bölümde “çalışıyor” ifadesi belirtilen pilot ve kabul kapsamını anlatır. Sonraki işletim ve ölçek kabulü gereken başlıklar açık tutuldu.

## Temel ürünün kalan altı başlığı

### B07 RADIUS ve servis işletimi 4 / 5 tamam

Kalıcı RADIUS servisi ve fiziksel switch ile AP kabulü var. Son Linux güncellemelerinde RADIUS süreci korundu. Açık: bütün servis hata ve yaşam döngüsü çeşitleri, panelden kontrol işlemleri ve gerçek host güç işlemi kabulü.

### B08 Policy ve VLAN sonucu 5 / 5 tamam

İzin ve ret, bilgisayar veya AD grubu, NAS ve erişim türü, RADIUS VLAN yanıtı ve gerçek DHCP kabulü var. Dar paket tamam. Kullanıcı kimliğiyle VLAN ve bütün seçiciler A03 ve G05 altında açık.

### B09 Gerçek kablolu kabul 3 / 4 tamam

Pilot port ve bilgisayar, makine sertifikası, güven profili ve VLAN 110 çalıştı. Açık: kalan olumsuz ve tekrar çeşitleri; özellikle gerçek expiry ve yanlış imzalayan CA.

### B10 Gerçek kablosuz kabul 4 / 4 tamam

AP22 ve SSID, makine EAP-TLS, dinamik VLAN ve dar olumsuz güven testleri tamam. Kullanıcı sertifikalı Wi-Fi ve gelişmiş roaming bu dar listenin dışında açık.

### B11 Kayıtlar ve teşhis 2 / 5 tamam

Yönetici geçmişi, CSV, sertifika ve kurulum durumları ile erişim denemeleri var. Açık: RADIUS Accounting Start, Stop ve Interim; tam oturum ilişkisi, saklama, arşivleme ve temizlik.

### B12 Yedek ve dağıtılabilir ürün 3 / 6 tamam

Durumu koruyan güncelleme, OVF araç temeli ve gerçek yedekten izole veri geri yükleme var. Açık: tam sürüm ve veri geri alma, temiz appliance import ve boot, bağımsız kurulum kimlikleri, destek matrisi ve nihai kılavuz.

Sunucu dışı yedek hedefi henüz belirlenmedi. İzole verinin açılıp kontrol edilmesi, bütün sanal makinenin yedekten çalıştırıldığı anlamına gelmez.

## Yedi geliştirme paketinde kalan işler

| Paket | Biten | Açık kapsam |
| --- | --- | --- |
| G01 Otomatik GPO ve sertifika dağıtımı | 2 / 5 | Plan, imzalı aday ve çalışan Connector var. Güncel hedef ve GPO denetimi, tam paket, kontrollü uygulama, geri alma ve yayılım açık. |
| G02 Cihaz yönetim modları | 2 / 5 | Manual, Read Only, Managed ve Import temeli var. Gerçek cihaz okuması, yapılandırma uygulama ve geri alma kabulü açık. |
| G03 Cloud cihaz entegrasyonları | 1 / 5 | Envanter hazırlığı var. İlk üretici API bağlantısı, korumalı bilgiler ve gerçek veri kabulü açık. |
| G04 VLAN ve port keşfi | 1 / 5 | Elle VLAN tanımı ve kural sonucu var. Otomatik VLAN ve port okuması, tazelik, eşleme ve kullanılabilirlik uyarısı açık. |
| G05 Gelişmiş kimlik seçicileri | 2 / 5 | Doğrudan hesap ve AD grubu ile kullanıcı veya bilgisayar kapsamı var. Tüm OU ve Everyone seçicileri ve her seçicinin saha kabulü açık. |
| G06 Canlı port ve kullanıcı topolojisi | 1 / 5 | Envanter temeli var. Canlı port ve oturum modeli, accounting eşlemesi, topoloji ve port veya SSID değişimi doğruluğu açık. |
| G07 Network intelligence ve öneriler | 1 / 5 | Kimlik, policy ve audit temeli var. Veri kalitesi ve saklama, korelasyon, açıklanabilir öneri ve yanlış alarm kabulü açık. |

Bu liste 10/35 tamam, 25/35 açık durumundadır. Cihazın üretici bulut panelinde elle ayarlanması API entegrasyonu; dashboard grafikleri de tek başına canlı topoloji veya öneri motoru sayılmaz.

### Ek kapsamın takibi

A03 kullanıcı kimlik doğrulaması ve A04 merkezi Windows dağıtımı ayrıca izleniyor. Bunlara keyfi bir yüzde verilmedi; biten alt adımlar ile kalan kabul koşulları aşağıdaki sayfalarda ayrıldı. Aynı iş B ve G sayımına ikinci kez eklenmez.

## Yarım kalan merkezi Windows işleri

### A03 Kullanıcı kimlik doğrulaması

Sunucu, kullanıcı Windows istemcisi ve panel hazır; kullanıcı profilleri ve kayıtları sekmeleri açılıyor. Eksik olan gerçek AD kullanıcısına kontrollü dağıtım, kullanıcı deposunda sertifika kurulumu, kablolu ve Wi-Fi erişimi ve kullanıcıya göre VLAN kabulü. Yenileme, iptal ve kullanıcı ile bilgisayar kimliği geçişi de sahada sınanacak.

### A04 Merkezi dağıtım ve tek hizmet hesabı

Hedef, bir defalık yetkili kurulumdan sonra günlük işlemlerin AuthWire panelinden yürütülmesi. aw-deploy$ ile çalışan Connector ve sınırlı imzalama hazır. Ancak mevcut AD katalog ve Kerberos yollarının bu hesaba taşınması tamamlanmadı; eski LDAP ve HTTP hesapları henüz kaldırılmadı. Standart tek domain kurulumunda tek gMSA hedefi korunuyor.

| Adım | Durum | Kapanış için gereken |
| --- | --- | --- |
| Hesap, imzalama ve HTTPS kanalı | Tamam | Mevcut başarılı kanıtlar korunacak; yeniden oluşturulmayacak. |
| Plan ve aday imza ile içerik kontrolü | Tamam | İlk gerçek panel görevi sonucu 27 Ekim ekranıyla kabul edildi. |
| Canlı AD hedefleri ve yönetilen GPO | Bekliyor | Üyelik ve etkinlik, GPO kimliği, izin, bağlantı ve sürüm güncelliği. |
| Tam istemci ve güven paketi | Kısmi | Mevcut XML adayının ötesinde onaylı kurulum, görev ve yayıncı güveni. |
| GPO hazırlama ve uygulama | Bekliyor | Önce bağlamadan hazırlama, sonra kapsamlı önizleme ve pilot uygulama. |
| Geri alma ve ölçek | Bekliyor | Gerçek uç, hata toparlama ve kademeli 200 kullanıcı veya bilgisayar kabulü. |

Şu an “içerik doğrulandı” durumu geçerli. GPO uygulama izni açılmadı. Yalnız bir kullanıcı seçilince o kullanıcının hangi bilgisayarları kullandığı kendiliğinden varsayılmayacak; kullanıcı ve bilgisayar kapsamları ayrı tutulacak.

## Test bekleyen işler ve açık bulgular

| Test grubu | Nerede | Beklenen kabul |
| --- | --- | --- |
| Kullanıcı EAP-TLS ve VLAN | Test PC ve AD | Kullanıcı sertifikası, Ethernet ve Wi-Fi, doğru kullanıcı kuralı ve kimlik geçişi. |
| AD retleri ve geri dönüş | AD ve pilot uç | Silinmiş hesap, AD kesintisi, üyelik değişikliği ve geri dönüşte doğru karar. |
| Sertifika olumsuz çeşitleri | Ayrı test profili veya uç | Gerçek süresi dolmuş sertifika ve yanlış imzalayan CA ile ret ve güvenli kurtarma. |
| Kayıt ve yeniden deneme | Windows ve sunucu | Kesilmiş yanıt, yarım işlem, kalan retry çeşitleri ve tekrarlı dayanıklılık. |
| Dağıtım ve geri alma | DC01 ve pilot uç | GPO hazırlığı, uygulama, sürüm değişimi, güven ve geri alma; sonra kademeli ölçek. |
| Tam ürün kurtarma | Ayrı sanal ortam | Sürüm ile veri rollback, appliance import ve boot, bağımsız kimlikler. |
| İşletim ve kapasite | Sunucu ve kontrollü pilot | Accounting, kayıt saklama, yük, servis ve güç işlemleri, uzun süre gözlem. |

### Kök nedeni açık bırakılan bulgular

Windows yeniden deneme zamanlaması bazı teknik koşularda kesirli saniye erken tetiklenip sonraki çalışma zamanını boş bırakabildi. Aynı kaynakla sonraki testlerin geçmesi ilk hatayı kapatmadı. Gerçek istemciye gereksiz yeniden kurulum yapılmayacak.

SQLite için dar kilit düzeltmesi kuruldu ve kontrollü yük testleri geçti. Tarihsel aralıklı hatanın tek kesin nedeni ve gerçek ortam kapasitesi açık. CRL test hizmeti başlangıcı ile süresi geçmiş bekleyen istek toparlanmasındaki aralıklı test bulguları da izleniyor.

Kod imzalama anahtarında kalıcı CLR IsEphemeral metadata işareti gözlendi. Native okuma ve imzalama yolu mevcut anahtarı koruyarak test edildi. İşareti kimin yazdığı açıklanmadı; anahtar silinmedi, yeniden üretilmedi ve işaret temizlenmedi.

Connector güncellemesinin geri alma yolları teknik ortamda test edildi. Müşteri DC01 üzerinde gerçek geri alma ve reboot kabulü ayrıca bekliyor. Başarılı Stop/Start, reboot kabulü yerine geçmez.

## Kaldığımız yer ve çalışma sırası

### Şimdi devam edeceğimiz iş

Mevcut imzalı pilot adayını ve çalışan Connector’ı koruyarak canlı AD hedeflerini ve ayrı yönetilen GPO’nun güncel kapsamını salt okunur kontrol edeceğiz. Önce bilgisayarların üyeliği ve etkinliği; GPO adı ve sahiplik işareti; izinleri, bağlantıları, sürümleri ve SYSVOL durumu görülecek. Bu kontrol GPO uygulamaz.

### Ardından izlenecek sıra

1. Güncel AD ve GPO okumasını kayıtlı planla karşılaştır. Eski veya farklı kapsam varsa uygulamayı durdur ve farkı göster.

2. Aynı kontrolü sınırlı Connector göreviyle panelden izlenebilir hale getir. Yönetici tarafından yapılan bir okuma, hizmet hesabının yetkisiymiş gibi sunulmayacak.

3. Tam dağıtım paketini güven ve istemci varlıklarıyla hazırla. GPO’yu bağlamadan önce dosya ve sürüm farklarını doğrula.

4. Seçilmiş pilotta kontrollü GPO uygulama ve geri alma yap. Sonra kullanıcı sertifikalı erişim ve kademeli ölçek kabulüne geç.

### Bekletilen ve kapsamdan çıkarılan işler

Yeni panel tasarım talepleri beklemede; onaylı logo korunuyor. NTP için uzun süre ve reboot gözlemi ertelendi. DHCP ve DNS dağıtım mimarisi müşteri kararıdır. Misafir erişimini yeniden test etme işi kullanıcının isteğiyle eklenmedi. İptal edilen ayrı yerel grup özelliği güncel kapsamda ve tamamlanma sayımında yer almıyor.

### Nihai teslimat

Hedef işlevsel sürüm tamamlanıp operatör kabulü alındığında bütün nihai sayfa, menü, alan, buton ve durumları kapsayan sade Türkçe Word ve PDF kullanım kılavuzu hazırlanacak. Gerçek ekran görüntüleri, adım adım örnekler, başarı kontrolleri ve hata çözümleri bulunacak. Kılavuz henüz hazır veya teslim edilmiş değildir.

### Raporun dayandığı kayıtlar

Önceki durum raporunun 25 Ekim revizyonu; docs/CURRENT_STATUS.md güncel üst kaydı; 27 Ekim Linux dev.39, Windows worker etkinleştirme ve içerik doğrulama kabul kayıtları. Kaynak sabiti: 17503f88438d04820788c71760e7f6db63ee8b53. Teknik testler saha kabulünden ayrı değerlendirildi; yüksek test sayısı ürünün bütünü için tamamlanma kanıtı sayılmadı.

Bu raporun hazırlanması panel, AD, GPO veya cihaz ayarlarını değiştirmez. Sonraki çalışmanın sonuçları yeni kabul kayıtlarıyla ayrıca izlenecek.
