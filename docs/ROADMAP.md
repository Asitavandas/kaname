# AuthWire — güncel çalışma planı

18 Ekim2026. Kurulu pilot sürümü0.14.0-dev.6'dır. Ayrıntılı kanıtlar ve tarihli
sonuçlar [CURRENT_STATUS.md](CURRENT_STATUS.md), işletim/kurtarma adımları
[OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md) içindedir. Eski sürüm notları tarihsel
kapsamdır; burada tamamlanan saha işleri yeniden “bekliyor” sayılmaz.

## Temel ürün

| İş paketi | Tamamlanan kapsam | Açık kabul kapısı |
|---|---|---|
| B01 Panel | Oturum kurtarma, yükleniyor durumu,2h/12h sınırları, RBAC/CSRF, dev.6 teknik kabul ve gerçek F5/giriş kısa saha kabulü | Aralıklı hataların uzun süreli takibi ve kalan wizard/apply akışı |
| B02 Canlı AD | Gerçek kimlik/grup, grup dışı ve kapalı hesap ret/geri dönüş | Silinmiş hesap/erişilemez AD ve gerçek kapasite sınırları |
| B03 Güven ve PKI | Gerçek CA/server-name kontrolü, iptal ve imzalı runtime CRL | Expired/yanlış issuer saha testi, CA/Issuer rollover ve bakım |
| B04 Enrollment | SYSTEM/GPO ile gerçek farklı cihaz anahtarı ve makbuz | Kesilmiş/tekrarlı kayıtların kalan saha senaryoları |
| B05 Merkezi dağıtım | Paket ve gerçek GPO görevi/istemci kabulü; güncel DC01 paket/ACL kontrolü, çift Startup düzeltmesi ve tek AllSigned çağrı | Son GPO halinin istemcide yeniden uygulanması ve daha geniş yayılım kabulü |
| B06 Yenileme | VV06 kontrollü yenileme, yeni anahtar/sertifika, erişim ve sunucu24h retirement/CRL kanıtı | Seçilen EAP leaf, yerel12h cleanup, offline/expired yolları |
| B07 Servis işletimi | Normal RADIUS, ayrı Servisler ekranı ve canlı CRL sync kabulü | Kalan hata/yaşam döngüsü ve işletim senaryoları |
| B08 Policy/VLAN | Dar pilot grubunda/NAS'ta kablolu/kablosuz gerçek policy VLAN ve DHCP | Diğer deny koşulları ve gelişmiş seçiciler |
| B09 Kablolu | Pozitif; sertifikasız/grup dışı/kapalı/iptal ret; reboot/recovery | Kalan uç cihaz negatifleri ve doğal yaşam döngüsü |
| B10 Kablosuz | AP22/SSID, EAP-TLS ve gerçek dinamik VLAN | Ayrılmış negatif güven/kimlik senaryoları; guest tekrarı istenmedi |
| B11 Kayıt/korelasyon | Servis işlem geçmişi ve temel audit | Accounting, canlı oturum korelasyonu ve saklama politikası |
| B12 Kurtarma/dağıtım | Durum koruyan kurulum/güncelleme, doğrulanmış özel yedekler ve gerçek yedekte izole veri restore | Tam boot/rollback, temiz appliance ve bağımsız kimlik |

18 Ekim uzaktan kontrol turu tamamlandı: panel günlük/API ve gerçek tarayıcı
kısa kabulü; güncel gerçek yedeğin izole veri restore provası; DC/SYSVOL paket
ve tek AllSigned Startup kontrolü; güncel rehberler. Yalnız fixture başarısı
müşteri restore kabulü sayılmaz; bu turda gerçek yedek kanıtı da alınmıştır.
Uzun süreli panel gözlemi ve tam boot/rollback ayrı açık kapılardır.
VV06 testleri19 Ekim Pazartesi sabahına ayrıldı. Uzaktan sunucu retirement/CRL kaydı18 Ekim'de
doğrulandı; bu, Windows cert-store cleanup veya seçilen EAP leaf'i kanıtlamaz.
Kullanıcı EAP-TLS pilotu unutulmadı; bilgisayar yaşam döngüsü kabulünden ayrı
izlenir. Kullanıcı+bilgisayar menüsü eşzamanlı iki kimlik/TEAP kanıtı değildir.

## Yedi geliştirme paketi

| ID | Konu | Bağımlılık / sınır |
|---|---|---|
| G01 | Otomatik GPO/sertifika dağıtımı | Mevcut imzalı istemci temel; panelden AD/GPO yazma ve kademeli yayılım açık |
| G02 | Manual, Read Only, Managed, Import | Envanter kayıtları var; gerçek cihaz bağlantı/uygulama adaptörleri açık |
| G03 | Cloud yönetilen cihazlar | Kullanıcının HPE cloud panelini elle kullanması AuthWire vendor API kabulü değildir |
| G04 | VLAN/port keşfi | Elle VLAN/policy var; kaynak/zaman bilgili cihaz keşfi G02/G03'e bağlı |
| G05 | Gelişmiş User/Computer/Group/OU/Everyone seçicileri | Taslaklar gerçek yetkilendirme hattı ve ayrı deny testleriyle kabul edilecek |
| G06 | Canlı port/kullanıcı topolojisi | Accounting, güvenilir cihaz/port bilgisi ve korelasyon gerekir |
| G07 | Network intelligence | Güvenilir oturum/topoloji verisi sonrasında açıklanabilir öneriler |

Önce temel ürünün açık kabul kapıları; ardından G01/G05 kullanım kolaylığı ve
kapsam, ihtiyaç duyulan cihaz için G02/G03 salt okuma, bunlara bağlı G04 ve
son olarak B11/G06/G07. PEAP/NPS kapsam genişlemesi, proxy/failover ve tam
appliance teslimi bu dar EAP-TLS pilotunun tamamlanmasıyla eşit değildir.

## Değişiklik koruması

Panel/rehber/test işleri mevcut CA'yı, signed Windows istemcisini, policy/NAS/
VLAN koşullarını veya native RADIUS'u değiştirmez. Servis müdahalesi gerektiren
kabul ayrı ve kontrollü yapılır. Veri/hata gözlemi ile gerçek kullanıcı kabulü
ayrı işaretlenir; kısmi satırın tamamı tamamlandı sayılmaz.
