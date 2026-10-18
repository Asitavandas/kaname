# AuthWire panel yönetimi — 0.14.0-dev.7

Panel, sunucu HTTPS adresinden yerel panel hesabıyla açılır; AD hesabı otomatik
panel yöneticisi olmaz. Temiz kurulumdaki başlangıç hesabı `admin`, parolası
`Kaname` olur; günlük kullanım öncesinde parola değiştirilir. Güncelleme var olan
yönetici/parolayı sıfırlamaz. Menü adları çalışan Türkçe arayüzü esas alır.

## Giriş ve oturum

Sayfa açılışında/F5'te mevcut HttpOnly cookie kontrol edilir. Doğrulama sırasında
kullanıcı adı/parola formu gizlidir; geçerli oturumda panel açılır, gerçek401
halinde giriş gerekir. Bağlantı/veri yükleme hatası parola POST'unu tekrar etmez.
Yeni girişlerde mutlak süre12saat, hareketsizlik2saattir. Arka plan istekleri de
etkinlik sayılır; eski oturumların mutlak bitişi güncellemeyle uzatılmaz.
Parolamı değiştir, hesap kapatma/silme ve sürüm değişiklikleri ilgili oturumları
geçersiz kılar; yetki profili değişiklikleri bir sonraki istekte uygulanır.

## Panel yöneticileri ve yetki profilleri

| Profil | Yetki |
|---|---|
| SuperAdmin | Bütün kaynaklarda okuma/yazma |
| Admin_ReadOnly | Okuma; kayıt ve servis işlemi başlatamaz |
| Custom | Kaynak başına none/read/write; sahip olduğu yetkiden fazlasını devredemez |

Yönetim → Panel yöneticileri / Yetki profilleri bu hesap ve profilleri yönetir.
Menünün gizlenmesi tek koruma değildir; API de kaynak yetkisini doğrular.
Kullanılan profil silinmeden hesaplar başka profile taşınır. Son yöneticinin
silinmesinde panel uyarır; silinen varsayılan hesap restart ile yeniden oluşmaz.
Kasa/bakım anahtarı normal panel kullanıcılarıyla paylaşılmaz.

## Güncel menüler

Erişim: kullanıcılar/gruplar, erişim kuralları, ağ cihazları, ağlar/VLAN.
Sertifikalar: otorite bilgisi, profiller, dağıtım ve cihaz kayıtları.
RADIUS: kaynak-IP bazlı istemci ve korunan shared secret kayıtları.
İzleme: karar testi ve işlem geçmişi.
Yönetim: temel ayarlar, LDAP sunucuları, panel yöneticileri, servisler ve yetki profilleri.

AD grup isimleri seçim içindir; politika SID ile saklanır. Aynı isimle yeniden
oluşturulan grup eski SID'nin yerine otomatik geçmez. Domain cihaz şartı,
EAP yöntemi, NAS kaynağı, grup ve diğer koşullar birlikte değerlendirilir.
Katalog görüntüsü canlı yetki kontrolü yerine geçmez. Karar testi simülasyondur.

## Temel ayarlar ve kayıt öncesi inceleme

Temel ayarlar AuthWire'ın saklanan FQDN, dizin ve erişim modu ayarlarını yönetir.
Bu kayıt OS IP/DNS, switch/AP veya Windows ayarı uygulamaz. Kayıt adımı eski ve
yeni değerleri gösterir; mevcut ayar değişiyorsa etki onayı gerekir. Yalnız değişen
alanlar gönderilir. Başka bir işlem form yüklendikten sonra kaydı değiştirdiyse
yeniden okuyup farkları kontrol edin; eski formun üzerine sessiz kayıt yapılmaz.

“Kayıt tamamlandı; ekran yenilenemedi” durumunda aynı işlemi tekrar göndermeyin.
“Güncel ayarları yükle” ile yalnız okuma yapılır. Bağlantı kesilmesinde kayıt
sonucu bilinmiyorsa da önce güncel ayarlar okunur. Kaydedilmemiş değişikliklerin
atılması onay ister; arka plan durumu güncellemesi formu silmez.

İlk kurulumdan sonra RADIUS istemcileri temel ayarlarda salt okunur. NAS IP,
kablolu/kablosuz erişim türü ve shared secret için RADIUS → RADIUS istemcileri
kullanılır; temel FQDN/dizin kaydı var olan istemci türü veya sırrını yeniden yazmaz.

Ana sayfadaki RADIUS özeti Servisler API'sinden salt okunur durum ve kontrol
zamanını gösterir. “UDP1812 doğrulandı” yalnız listener kontrolü olumluysa görünür.
Özet, uçtan uca EAP/DHCP testi değildir. Broker okunamazsa durum bilinmiyor olur;
sonuç otomatik stop/start/restart başlatmaz. system.services okuma yetkisi gerekir.

## İşlem geçmişi (dev.8 aday)

Tarih, olay kodu ve içerik filtresiyle mevcut kayıtlar100'lük sayfalar halinde
incelenir. “Daha eski kayıtlar” aynı kayıt üst sınırını korur; “En yeni kayıtlar”
yeni okuma başlatır. CSV yalnız ekranda gösterilen sayfayı indirir ve kayıt silmez.
Panel hesap işlemleri ayrıca system.administrators okuma hakkı gerektirir.
Eski kayıtta actor yoksa kullanıcı atanmaz; kimlik alanı mevcut ID olabilir.

Saklama bilgisi kaynak toplam satırını ve bütün DB boyutunu gösterir. Otomatik
temizlik tanımlı değildir; mevcut append-only koruması sürer. RADIUS kabul/ret
kararları/accounting bu listede toplanmaz; servis talebi sonuç kanıtı değildir.
Ayrıntılar ve açık B11 işleri [AUDIT_HISTORY.md](AUDIT_HISTORY.md) içindedir.

## Servisler ve tanılama

Ayrı system.services hakkı, RADIUS ve CRL servis kontrollerini yönetir. Panel
kendini bu ekrandan durdurmaz. Son işlemler kullanıcı/zaman/sonuç gösterir;
bu, RADIUS accounting veya canlı switch oturum listesi değildir.
PANEL_DATABASE_ERROR tanılaması SQL/sır yazmadan geçici busy/locked hatasını ayırır.
Yalnız bu geçici hatadaki GET sınırlı tekrar edilir; POST otomatik tekrarlanmaz.

İşletim, yedek ve kurtarma adımları [OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md),
güncel saha kabulü [CURRENT_STATUS.md](CURRENT_STATUS.md) içindedir.
