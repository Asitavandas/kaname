# KANAME — kapsam ve kabul şartları

Tarih: 2026-10-02. Bu belge önceki ürün adlarının ve kapsam varsayımlarının yerini alır.

## Sabit ürün kararları

1. Ürün adı şimdilik **KANAME**. Başka bir ürünle entegrasyonu veya ona bağımlılığı bulunmaz. İsim tescili/uygunluğu bu geliştirme tesliminin kapsamı değildir.
2. Kurulum hedefi bağımsız x86_64 sanal appliance; teslim biçimi OVF descriptor, VMDK disk ve SHA256 manifest.
3. Dış kimlik kaynağı Active Directory Domain Services. Kullanıcı, bilgisayar ve grup bilgisi AD'den gelir. Ayrı CA sunucusu, NPS sunucusu, bulut API veya lisans sunucusu zorunlu olmayacak.
4. Switch/AP yönetimi ve entegrasyon testleri ilk kapsamdan çıkarıldı. Operatör bunları manuel yapılandırır. KANAME içinde RADIUS istemcisinin kaynak IP ve shared secret tanımı tutulur; bu cihaz yönetimi değildir.
5. Kablolu ve kablosuz gerçek 802.1X kabul testleri devam eder. Manuel hazırlanmış switch/AP üzerinden test edilir; API/SSH/SNMP yönetim testi yapılmaz.
6. İlk kurulum ve sonraki yönetim tek panel üzerinden yürür. Başlangıç sürümünün paneli taslaktır; nihai wizard gerçek servisleri kontrollü olarak uygulayacak.
7. Günlük panel girişi kullanıcı adı/parola ile olur; ilk kurulum hesabı admin/Kaname. System altında ayrı Administrators ve Admin Profiles sekmelerinden tüm hesap/profiller düzenlenebilir ve silinebilir. SuperAdmin bütün kaynaklarda Read/Write, Admin_ReadOnly Read, Custom menü/sekme başına seçilen erişimle çalışır.
8. Politika formunda kullanıcı SID yazmaz; AD grup adını seçer. SID eşleşme kimliği olarak içeride tutulur. Grup koşulu isteğe bağlıdır.
9. Menüler akordiyon biçiminde açılır/kapanır. User&Authentication → Active Directory bağlantı ekranıdır; Users/User Groups aynı ekranda iki ayrı liste ve karşılıklı üyelik detayları sunar.
10. Her sürüm tamamlandığında operatöre soruları veya istediği değişiklikler sorulur; yanıt alınmadan sonraki sürüme geçilmez.

## Nihai wizard akışı

| Adım | İşlem | Başarı kanıtı |
|---|---|---|
| 1. Appliance | Ağ, DNS, saat, ürün FQDN, ilk yönetici, HTTPS erişimi | IP/DNS/saat doğrulaması; her kurulumda farklı kimlik |
| 2. AD | Yetkili kullanıcıyla bağlantı kontrolü, domain join veya yetki devri, güvenli dizin bağlantısı | Gerçek AD sorgusu; parola logda/veritabanında düz metin yok |
| 3. Dizin | OU kapsamı, kullanıcı/bilgisayar, iç içe gruplar ve SID eşlemesi | Sayfalı okuma, silinmiş/devre dışı hesap davranışı |
| 4. Sertifikalar | Dahili CA, RADIUS sunucu sertifikası, istemci kayıt yöntemi ve güven dağıtımı | Ayrı CA olmadan gerçek EAP-TLS; endpoint sunucu adını doğrular |
| 5. Erişim | Kablolu/kablosuz profiller, RADIUS istemcileri, secret üretimi, grup/VLAN politikaları | Onaylanan yapılandırmanın doğrulanıp atomik etkinleştirilmesi |
| 6. İstemciler | Windows GPO/profil çıktıları, CA güveni ve EAP-TLS kayıt akışı | Yeniden başlatma öncesi/sonrası cihaz ve kullanıcı akışı |
| 7. Kontrol | Gerçek kimlik doğrulama, teşhis, yapılandırma sürümü ve geri dönüş | İzin/ret gerekçesi, test bağlantısı, eski çalışan sürüme dönüş |

Wizard switch/AP için yalnız manuel ayar rehberi verir. Yönetim adresi, cihaz admin parolası veya SSH anahtarı toplamaz. GPO/profil dağıtımının AD üzerinde değişiklik yapan kısmı, yetkili operatörün başlattığı açık işlem olmalıdır; günlük dizin okuması Domain Admin ile çalışmaz.

## İlk çalışan ürün kapsamı

EAP-TLS, AD grupları ve bilgisayar hesapları, sıralı erişim politikaları, RADIUS Access-Accept/Reject/Challenge, gerekli VLAN öznitelikleri, accounting, dahili sertifika yaşam döngüsü, Windows kablolu/kablosuz profil dağıtımı, olay/teşhis ekranı, yedek/geri yükleme ve OVF ilk açılışı.

PEAP-TLS ve PEAP-MSCHAPv2 için uyumluluk ayrı laboratuvar kapısıdır. LDAP parola kontrolü MSCHAPv2 challenge/response doğrulamasının yerine geçmez. PEAP-MSCHAPv2 varsayılan erişim yöntemi olarak açılmaz; Samba/AD ve Windows güvenlik ayarlarıyla kanıtlanmadan destekleniyor sayılmaz.

## İlk kapsam dışında

Switch/AP API, SSH, SNMP, otomatik VLAN veya SSID oluşturma, firmware, vendor adaptörleri, roaming/host-mode testleri; CoA; captive portal, posture agent, MAB ve cihaz keşfi; multi-tenant yönetim, bulut kontrolü ve başka ürün entegrasyonu. Switch portu/SSID üzerinde hangi VLAN'ın kullanılabildiğini operatör hazırlar. KANAME'nin Access-Accept özniteliği tek başına switchte VLAN oluşturmaz.

## Nihai teslim koşulları

Çalışan OVF temiz imajdan üretilmiş olmalı; iki bağımsız importta kimlik/anahtarlar farklı olmalı. Gerçek AD ve manuel hazırlanmış switch/AP ile kablolu ve kablosuz EAP-TLS başarılı olmalı. Yanlış sertifika, iptal, kapalı hesap, yanlış grup, domain dışı cihaz ve AD kesintisi için güvenli ret kanıtlanmalı. Harici CA ve internet olmadan çalışma, yedekten geri yükleme, güncellemeden geri dönüş ve kaynak tüketimi ölçülmeli.

Bu başlangıç paketi bu nihai kabul koşullarını karşıladığını iddia etmez.
