# KANAME — mimari

## NPS'in yaptığı iş

802.1X istemci/supplicant, switch veya AP'nin authenticator rolü ve RADIUS sunucusu birlikte çalışır. İstemci EAP'i EAPOL üzerinden cihazla konuşur; cihaz EAP mesajlarını RADIUS içinde sunucuya taşır. RADIUS sunucusu cihazı shared secret ve mesaj bütünlüğüyle doğrular, EAP yöntemini yürütür, kimliği doğrular, erişim politikasını değerlendirir ve Access-Challenge/Accept/Reject üretir. İzin yanıtındaki VLAN gibi öznitelikleri cihaz uygular. Accounting mesajları oturum kullanımını raporlar.

NPS'in connection request policy katmanı isteğin yerelde işleneceğini veya uzak RADIUS'a proxy edileceğini seçer. Network policy katmanı sıralı koşul/kısıt/izin kararını verir. Koşul eşleşmezse sıradaki politika denenir; eşleşen politikanın kısıtı sağlanmazsa istek reddedilir. KANAME'nin ilk politika motoru bu sırayı kullanır. AD erişilemediğinde ret kararı daha katı bir başlangıç ürün tercihidir; NPS'in bütün önbellek davranışlarının kopyası değildir.

## Hedef bileşenler ve mevcut durum

| Bileşen | Hedef | 0.6.0-dev.1 |
|---|---|---|
| Yönetim paneli/API | HTTPS, wizard, RBAC, yönetici oturumları, teşhis | Loopback geliştirme paneli, oturum/RBAC ve kullanıcı/profil yönetimi; gerçek servis apply yok |
| Politika motoru | SID ile grup, erişim türü, NAS, EAP, cihaz şartı, VLAN | Çalışıyor; girdiler gerçek adaptör kanıtı değil |
| RADIUS/EAP | Appliance içinde FreeRADIUS; TLS/EAP/RADIUS protokolünü yeniden yazmama | Native loopback EAP-TLS/policy/VLAN protokol kanıtı; production servis bağlı değil |
| AD adaptörü | Güvenli LDAP/Kerberos, grup ve hesap durumu, computer kimliği | Windows Kerberos katalog ve üyelik okuması; live Linux erişim karar sağlayıcısı yok |
| Dahili PKI | CA, enrollment, yenileme, iptal, CRL ve kimliğe bağlama | Root/issuer CA, şifreli anahtar, server CSR, iptal ve CRL var; istemci enrollment/AD eşlemesi yok |
| Kalıcılık | Yapılandırma sürümü, secret kasası, audit, kontrollü apply | SQLite sürümleme ve atomik audit; secret kasası yok |
| Servis uygulayıcı | Doğrula → staged config → etkinleştir → health check → rollback | Henüz yok |
| Appliance | Temiz imaj, ilk açılış, offline servisler, OVF | Sözleşme ve denetim araçları; disk imajı yok |

Python mevcut kontrol katmanının dilidir. Üretim HTTP/oturum sunucusu, şema migrasyonları ve servis işleticisi ayrıca geliştirilecek. FreeRADIUS sürümü, işletim sistemi paketleri ve güvenlik güncellemeleri ilk gerçek imajda sabitlenip lock/SBOM ile kayıt altına alınacak. FreeRADIUS'un lisans ve dağıtım yükümlülükleri imaj tesliminde karşılanacak.

Yerel PKI mevcut SQLite veritabanına ilave tablolar ekler; eski ayar/politika satırlarını veya erişim anahtarını yeniden oluşturmaz. PKI yazımı ve audit aynı transaction içindedir; yapılandırma taslağının revision değeri değişmez. Root CA en fazla bir issuer katmanına, issuer yalnız leaf sertifikalara izin verir. Bu sürümde root ve issuer anahtarları aynı parola ile şifreli aynı veritabanında tutulur; offline root/HSM mimarisi uygulanmış sayılmaz. Ağ üzerinden CA yönetimi yoktur; panel yalnız public metadata okur.

## Güven sınırları

Tarayıcıda girilen `authenticated`, grup SID veya `domain_device` bir doğrulama kanıtı değildir. `/api/simulate` yalnız örnek karar üretir. Üretimde bu alanlar sadece doğrulanmış EAP oturumu ile AD/sertifika eşlemesini birleştiren iç adaptörden gelebilir. Yönetim API'si RADIUS Access-Accept gönderemez.

0.6 iç `TLSAuthorization` sınırı native FreeRADIUS certificate-check sanal sunucusu için hazırlanır. Pinned issuer+serial kayıt bağı domain/objectGUID/SID/tür ile güncel dizin hesabına eşlenir. Dizin sağlayıcısı her karar için çağrılır; eksik sağlayıcı ret verir. Kullanıcı sertifikası domain bilgisayar kanıtı değildir. Mevcut üyelik ekranının distribution grupları dahil yapısal grafiği Windows access token/security grup yetkisi yerine kullanılamaz. İzole protokol laboratuvarı gerçek EAP/RADIUS'u, sentetik AD sağlayıcısını kullanır; production enrollment veya provider etkinleştirmez. [Kanıtın kapsamı](RADIUS_PROTOCOL.md).

EAP-TLS sertifikasının CA imzası tek başına domain üyeliğini kanıtlamaz. Kayıt sırasında doğrulanmış bilgisayar/kullanıcı kimliği, SID veya değişmez AD nesne kimliğiyle bağlanır; yetkisiz SAN/UPN talebi kabul edilmez. Kararda sertifika zinciri, amaç, süre, iptal durumu ve eşleşen AD hesabının enabled durumu kontrol edilir. Kullanıcı sertifikası ile bilgisayar sertifikası ayrı profil/amaç ve politikaya sahiptir. Aynı oturumda hem kullanıcı hem cihaz kanıtı gerektiren senaryolar ayrıca tasarlanır; temel EAP-TLS'in bunu kendiliğinden verdiği varsayılmaz.

## AD ve harici CA gerektirmeyen tasarım

Yetkili kullanıcı ilk domain join/GPO yetki devri için kullanılabilir; Domain Admin parolası kalıcı runtime hesabı olarak saklanmaz. Günlük okuma, devredilmiş hesabın veya makine hesabının Kerberos kimliğiyle yapılır. LDAP için doğrulanmış LDAPS/StartTLS veya Kerberos ile imzalı ve şifreli SASL kullanılır. Düz LDAP simple bind üzerinden parola gönderilmez. Domain ortamında LDAPS sertifikası bulunmadığında Kerberos sealing seçeneği laboratuvarda doğrulanır; wizard ayrı AD CS kurulumunu zorunlu tutamaz.

Nested grup, primary group, OU sınırı, referral, sayfalama, ad değişikliği, SID ve grup silinmesi açık test konularıdır. Kullanıcı adıyla login doğrulaması ile dizin nesnesini okuma birbirine karıştırılmaz. DNS ve Kerberos saat uyumu preflight kontrolüdür. İlk sürüm tek AD domain hedefler; forest/trust desteği ayrı uyumluluk aşamasıdır.

KANAME'nin içindeki CA ayrı sunucu istemeden RADIUS ve istemci sertifikalarını üretir. CA güveninin endpoint'e dağıtılması yine gerekir. Domain Windows için GPO + kayıt aracı/profil çıktısı planlanır; AD CS auto-enrollment'in başka bir CA için otomatik çalışacağı varsayılmaz. İlk HTTPS erişiminde kurulumun ürettiği sertifika parmak izi konsoldan doğrulanır; kurumsal istemci güveni sonraki adımda dağıtılır. CA özel anahtarı imajla dağıtılmaz, ilk kurulumda üretilir ve korumalı yedeğe dahil edilir. CA kaybı/migrasyonu ve root rollover ayrı kabul testidir.

## NPS özelliklerinin teslim sırası

| NPS işlevi | KANAME yaklaşımı | Aşama |
|---|---|---|
| RADIUS client | Kaynak IP, benzersiz secret ve mesaj bütünlüğü | İlk gerçek RADIUS |
| Local request processing | İlk sürümde yalnız yerel auth | İlk gerçek RADIUS |
| Network policy | Sıralı koşul/kısıt, deny default, group SID | Çekirdek hazır; runtime bağlantısı sonra |
| EAP-TLS | Dahili PKI ile cihaz/kullanıcı profili | Öncelikli laboratuvar |
| PEAP-TLS/MSCHAPv2 | Ayrı protokol/AD/Windows doğrulaması | Uyumluluk genişlemesi |
| RADIUS VLAN/VSA | Standart VLAN; seçilmiş vendor öznitelikleri | VLAN ilk; VSA sonra |
| Accounting | Start/Interim/Stop ve korelasyon | MVP |
| Proxy/remote server groups | Ayrı routing ve timeout/failover tasarımı | MVP sonrası |
| Dial-in account davranışı | AD erişim özellikleri ve policy precedence araştırması | NPS uyumluluk genişlemesi |
| Time/session/IP koşulları | Açık model ve sınır testleri | NPS uyumluluk genişlemesi |
| NAP/eski Windows rolleri | Birebir işletim sistemi rolü klonu hedeflenmez | İlk kapsam dışı |

İlk MVP tam NPS özellik eşitliği değildir. Nihai uyumluluk, özellik matrisi ve gerçek test sonuçlarıyla ilan edilir.
