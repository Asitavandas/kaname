# AuthWire — güncel çalışma planı

21 Ekim2026. Kurulu pilot sürümü0.14.0-dev.12'dir. Ayrıntılı kanıtlar ve tarihli
sonuçlar [CURRENT_STATUS.md](CURRENT_STATUS.md), işletim/kurtarma adımları
[OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md) içindedir. Eski sürüm notları tarihsel
kapsamdır; burada tamamlanan saha işleri yeniden “bekliyor” sayılmaz.

## Kapsam sınırı — 20 Ekim müşteri kararı

DHCP/DNS'in hangi cihazdan dağıtılacağı, firewall/AD DNS mimarisi ve DNS listesi
değişiklikleri müşteri sorumluluğundadır; AuthWire çalışma kapsamından çıkarıldı.
Bu konu bekleyen eksik veya tamamlanan teknik iş olarak sayılmaz. Mevcut mimaride
gerekli domain/AuthWire ad çözümlemesi ve bağlantılar işlevsel ön koşuldur.
Eski tarihli raporlardaki DNS düzenleme maddeleri için bu karar geçerlidir.

## Temel ürün

| İş paketi | Tamamlanan kapsam | Açık kabul kapısı |
|---|---|---|
| B01 Panel | Oturum kurtarma, yükleniyor durumu,2h/12h sınırları, RBAC/CSRF, dev.6 gerçek F5/giriş kısa saha kabulü; dev.7 ayar review/revision/tek kayıt, gerçek RADIUS özeti, canlı teknik ve operatör ekran kabulü | Uzun gözlem ve kalan wizard/OS apply açık |
| B02 Canlı AD | Gerçek kimlik/grup, grup dışı ve kapalı hesap ret/geri dönüş | Silinmiş hesap/erişilemez AD ve gerçek kapasite sınırları |
| B03 Güven ve PKI | Gerçek CA/server-name kontrolü, iptal ve imzalı runtime CRL | Expired/yanlış issuer saha testi, CA/Issuer rollover ve bakım |
| B04 Enrollment | SYSTEM/GPO ile gerçek farklı cihaz anahtarı ve makbuz ; 🔴✓20 Ekim kontrollü issuance sonrası yarım kurulumdan aynı pending anahtarla retry, tek CSR issuance ve final receipt saha kabulü | Diğer kesilmiş/tekrarlı kayıt varyantları; 4-worker load fixture'da gözlenen aralıklı SQLite kilitlenmesi |
| B05 Merkezi dağıtım | Paket ve gerçek GPO görevi/istemci kabulü; DC01 paket/ACL kontrolü, çift Startup düzeltmesi ve tek AllSigned çağrı; 🔴✓ VV06 RSOP/imza/sertifika/802.1X korunması; 🔴✓ dev.10 boot-run kurtarma/SYSTEM testleri, canlı kaynak/restore ve signed updater Windows/rollback testleri; 🔴✓ DC01 mevcut publisher ile yeni imzalı SYSVOL kurucusu ve asset/ACL koruması canlı kabulü; 🔴✓ VV06 gerçek boot sonrası doğal task çalışması0, imza/cert/key ve 802.1X/VLAN110 korunması | Daha geniş yayılım; dev.11 doğal boot ve ağ hata/toparlanma kabulü B06'da tamamlandı |
| B06 Yenileme ve toparlanma | VV06 gerçek yeni anahtar/sertifika yenilemesi, yeni seri EAP seçimi, sunucu24h retirement/CRL ve yerel12h eski cert/CNG key temizliği; 🔴✓ dev.11 signed SYSVOL, yeni launcher doğal boot Ready/0 ve cert/key/802.1X/VLAN110 koruması; 🔴✓20 Ekim ağsız boot/kablo dönüşü; 🔴✓ gerçek ESXi kesintisi session/result1 sonrası retry17:52:30 → ana task17:52:32/Ready0, retry dosyası yok, statusinstalled ve EAP/VLAN110 korundu ; 🔴✓20 Ekim issue aşaması yarım kalmasından doğal retry ile aynı pending anahtarla yeni sertifika/privatekey kurulumu, pending/retry temizliği ve mevcut VLAN110 erişiminin korunması ; 🔴✓ sunucuda aynı CSR tek issuance, final receipt ve önceki seri için24h retirement planı ; 🔴✓ yeni26e... seri/TLS doğrulanmış RADIUS POLICY_ALLOW/VLAN110 ve taze Windows15505 ile bu kontrollü yarım kurulum senaryosu tamam; 🔴✓21 Ekim izole imzalı SYSTEM Windows expired-pending arşiv/yeni CNG anahtar/CSR/chain/certreq/receipt ve native RADIUS expired ret teknik kabulü; 🔴✓21 Ekim dev12 Linux kaynak güncellemesi, gerçek before/after backup ve izole restore/API kabulü; RADIUS/broker PID, CA/policy/native modül korundu; 🔴✓21 Ekim DC01 aynı enterprise publisher ile dev12 signed client SYSVOL teslimi, installer/assets/tek AllSigned Startup/ACL ve private backup koruması; 🔴✓VV06 dev12 exact signed copy/Valid publisher, doğal boot Ready0, mevcut26e... cert/key, pending/retry temizliği, EthernetAuthSuccess ve10.10.110.4/24 koruması; 🔴✓doğrulanmış yeni signed kopyadan sonra18:29:17 fresh normal taskReady0/installed/26e...seri aynı/retryfalse ile dev12 teslim ve normal çalışma zinciri tamam | Diğer kesilen/yarım kurulum varyantları ve expired kurtarma yolları; kesin çapraz kaynak zaman korelasyonu B11'de ayrı izlenir ; PR42 birleştirildi; 🔴✓7 CI grubu, aynı head'de iki SYSTEM retry turu ve signed SYSVOL client update/rollback teknik kabulü; 🔴✓sunucuda139dosyalık pinned kurulum paketi hazır. Linux sudo ve DC01 signed SYSVOL client teslimleri tamam; VV06 signed copy/boot/Ethernet/IP ve yeni kopyadan sonra taze normal task kabulü tamam; gerçek expired saha kabulü ayrı test cihazı bekliyor (21 Ekim yalnızVV06var); diğer kalan yaşam döngüsü varyantları açık; önceki aralıklı CI retry timeout ve yerel login/storage/cleanup test kararlılığı bulguları ayrı takipte |
| B07 Servis işletimi | Normal RADIUS, ayrı Servisler ekranı ve canlı CRL sync kabulü | Kalan hata/yaşam döngüsü ve işletim senaryoları |
| B08 Policy/VLAN | Dar pilot grubunda/NAS'ta kablolu/kablosuz gerçek policy VLAN ve DHCP | Diğer deny koşulları ve gelişmiş seçiciler; sıradaki21Ekimyalnızpilotwirelesspolicydisabled→ret/enabled→accept/VLAN140geri dönüş hazırlığı (henüzuygulanmadı) |
| B09 Kablolu | Pozitif; sertifikasız/grup dışı/kapalı/iptal ret; reboot/recovery; 🔴✓19 Ekim ağsız boot sonrası kablo takılınca EAP/VLAN110 geri dönüşü ; 🔴✓20 Ekim yarım kurulumdan toparlanan yeni26e... sertifika ile taze kablolu POLICY_ALLOW/VLAN110/TLS ve Windows15505 | Kalan olumsuz kimlik/güven, expired ve diğer yarım kurulum senaryoları |
| B10 Kablosuz | AP22/SSID, EAP-TLS ve gerçek dinamik VLAN; 🔴✓21 Ekim VV06 doğru KANAME root/server-name/machine profil exportu, taze WLAN12012/8001 ve10.10.110.2/24; 🔴✓yanlış sunucu adıyla12013/0x800B0114/disconnected, doğru export yüklenince aynı SSID/AP'de connected: dar olumsuz güven ve geri dönüş saha kabulü tamam; 🔴✓yalnız AAA kökü seçildiği exportta doğrulandı,19:26:07 olay12013/0x800B0109 ile ret; doğru KANAME exportu yüklenince connected ve10.10.110.2/24Preferred geri geldi; 🔴✓21 Ekim8satır/16sütun gerçek Wi-Fi CSV'sinde6kabulün güncel26e...seri/computerGUID/kablosuzpolicy/TLS eşleşmesi; 🔴✓operatörün policy140değişikliği,CSV140Access-Accept ve doğruWi-Fibağlantısından sonra10.10.140.2/24DhcpPreferred uçkabulü tamam | Diğer negatif güven/kimlik ve kullanıcı EAP-TLS senaryoları; TLS full-resumption ve kesin kaynak-zaman korelasyonu ayrıca doğrulanmadı; önceki APIPA ölçümü kablosuzbağlantı yokken alınmış, DHCP/VLAN arızası doğrulanmadı; guest tekrarı istenmedi |
| B11 Kayıt/korelasyon | Servis işlem geçmişi ve temel audit; 🔴✓ dev.8 yönetim geçmişi filtre/sayfalama/CSV operatör kabulü; 🔴✓ dev.9 final RADIUS kaydı geliştirme/izole native-systemd/UI ve canlı etkinleştirme, koruma/API/yedek/izole restore teknik kabulü; 🔴✓ dev.9 operatör ekranının hatasız açılması; 🔴✓ VV06 gerçek kabul kayıtları ve16 sütunlu canlı CSV teknik kabulü; 🔴✓21 Ekim kablosuz CSV8kayıt/16sütun,6kabul/2ret,ayrıevent/requestID ve sertifika-cihaz-policy eşleşmesi | Excel görünümünün operatör bildirimi ve kesin Windows/RADIUS zaman-tetik eşleştirmesi (olası eşleşmelerde yaklaşık124saniye sapma; VV06DC01kaynağı doğrulandı,DC-Linux-123.123sölçüldü;🔴✓DC01NTPkaynağıyedekle ntp.ubuntu.com'aalındı,resyncbaşarılı,3tekrarDC-Linux~4ms;🔴✓VV06duvarsaat5örnekte<1msveorijinal300/NT5DSgeridönüş;sonLeap3/Unset/LastSyncError1kalıcıW32Timesağlığıaçıkizlem,operatöristeğiyleNTPçalışmasıdurdu;ortakpaketteyidi bekliyor); accounting/korelasyon ve arşiv/saklama/temizlik |
| B12 Kurtarma/dağıtım | Durum koruyan kurulum/güncelleme, doğrulanmış özel yedekler, gerçek yedekte izole veri restore, planlı yedek canlı kurulum ve ilk arşiv/restore kabulü; 🔴✓19 Ekim doğal timer tetiklenmesi/başarılı arşiv/digest | hedef/altyapı bekleyen off-host kopya, tam boot/rollback, temiz appliance ve bağımsız kimlik |

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
