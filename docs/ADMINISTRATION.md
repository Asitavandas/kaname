# AuthWire panel yönetimi — 0.14.0-dev.6

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

## Servisler ve tanılama

Ayrı system.services hakkı, RADIUS ve CRL servis kontrollerini yönetir. Panel
kendini bu ekrandan durdurmaz. Son işlemler kullanıcı/zaman/sonuç gösterir;
bu, RADIUS accounting veya canlı switch oturum listesi değildir.
PANEL_DATABASE_ERROR tanılaması SQL/sır yazmadan geçici busy/locked hatasını ayırır.
Yalnız bu geçici hatadaki GET sınırlı tekrar edilir; POST otomatik tekrarlanmaz.

İşletim, yedek ve kurtarma adımları [OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md),
güncel saha kabulü [CURRENT_STATUS.md](CURRENT_STATUS.md) içindedir.
