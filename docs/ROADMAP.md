# KANAME — çalışma planı

Güncelleme: 2026-10-04. Aşamalar bağımlılık sırasıyla ilerler; süreler tek geliştirici için önceki kaba mühendislik tahminleridir, teslim tarihi taahhüdü değildir. İlk gerçek kanıt için yaklaşık 3–4 hafta, panel üzerinden MVP için 9–13 hafta, ilk kapsamın sertleştirilmiş appliance teslimi için toplam 13–20 hafta referans alınır. Laboratuvar/AD erişimi ve sertifika kayıt protokolünün sonuçları bu tahminleri değiştirebilir.

| Aşama | Çıktı | Kabul kapısı | Durum |
|---|---|---|---|
| 0. Başlangıç | Bağımsız repo yapısı, taslak panel, politika motoru, SQLite, OVF sözleşmesi/araçları | Otomatik testler; API simülasyonu gerçek auth olarak kullanılamaz | 0.1 temeli korundu |
| 1. Protokol kanıtı | Gerçek FreeRADIUS + AD adaptörü + dahili PKI enrollment denemesi | Manuel hazırlanmış switch/AP üzerinden gerçek kablolu ve kablosuz EAP-TLS | CA/server CSR/CRL, Windows AD katalog ve 0.6 native loopback EAP-TLS/policy/VLAN temeli var; Ubuntu HTTPS/gerçek AD katalog eşitlemesi kabul edildi; canlı yetki sorgusu, enrollment ve fiziksel 802.1X kabulü bekliyor |
| 2. Kimlik yaşam döngüsü | AD grup/hesap sorgusu, cihaz/kullanıcı sertifika eşlemesi, yenileme/iptal | Yanlış grup, kapalı hesap, iptal/expired sertifika, AD kesintisi ret testleri | Planlandı |
| 3. Gerçek wizard | DNS/saat/AD testleri, CA/trust, RADIUS secret, GPO/profil çıktıları, kontrollü apply | Başlangıçtan ilk erişime kadar panelden uygulanabilir akış; rollback | Planlandı |
| 4. Günlük yönetim | Kullanıcı/grup seçimi, policy edit, accounting, arama/teşhis, RBAC, audit | Kim yaptı/neyi değiştirdi; oturum ve hata korelasyonu | 0.5 yerel oturum/RBAC, akordiyon menüler, ayrılmış System/AD ekranları ve kullanıcı/grup üyelik inceleme tamamlandı; accounting/üretim audit/apply bekliyor |
| 5. Appliance | OS hardening, ilk açılış, offline runtime, yedekleme, imzalı güncelleme, OVF | Gerçek import, boot, iki bağımsız kimlik, restore ve upgrade rollback | Planlandı |
| 6. NPS uyumluluğu | PEAP yöntemleri, ilave koşullar/VSA, proxy ve failover | Özellik bazlı NPS karşılaştırma matrisi | İlk MVP sonrası |

## Sıradaki somut geliştirme

0.2 dahili CA/server CSR/CRL temelini ekledi. 0.3.2 Windows Kerberos LDAP ve domain kapsamlı sayfalı okuma düzeltmelerini tamamladı; operatör gerçek AD ekranında başarılı 55 sonuç bildirdi. Bu sayı tek başına bütün kategorilerin toplamı veya canlı üyelik doğrulaması değildir. 0.4 kullanıcı/parola girişi, System kullanıcı/profil yönetimi, menü/sekme düzeyinde RBAC ve SID yazmadan grup adı seçimi ekledi. 0.5 akordiyon menüleri, ayrı Admin Profiles ve AD bağlantı sayfalarını, aynı ekranda Users/User Groups listelerini ve doğrudan/primary/iç içe üyelik detaylarını ekler. Bu ilişkiler henüz ağ kimlik doğrulamasına bağlanmaz. Yerel oturum/RBAC üretim HTTPS/appliance aşamasının tamamlandığı anlamına gelmez.

Her sürümün testleri ve güncellemesi tamamlandıktan sonra **Soruların veya değiştirmek/düzenlemek istediğin yerler var mı?** sorulur. Operatör yanıtlamadan aşağıdaki yeni geliştirmeye geçilmez.

Operatör 0.5 menü/üyelik teslimini kabul etti ve sonraki aşamayı onayladı. 0.6, sabit FreeRADIUS 3.2.10 native loopback protokol laboratuvarını ve sertifikaya bağlı iç yetkilendirme sınırını ekler. Gerçek paketler fixture AD/enrollment bağlarıyla denenir; production service, canlı domain kimlik doğrulaması veya Windows fiziksel EAPOL kabulü ilan edilmez. Sonraki ihtiyaç temiz Ubuntu VM ve live Kerberos AD sağlayıcısıdır. Ayrıntılar [RADIUS protokol kanıtı](RADIUS_PROTOCOL.md).

1. Tek domainli Windows AD laboratuvarını, Windows endpoint'i ve temiz Ubuntu appliance VM'ini hazırlamak. Switch/AP ve port/SSID ayarları operatörün manuel sorumluluğundadır.
2. Mevcut iç CA/server CSR altyapısını gerçek endpoint trust ve EAP oturumuna bağlamak. İstemci enrollment kimliğini AD nesnesiyle doğrulamadan istemci sertifikası üretimini açmamak.
3. FreeRADIUS'u test EAP-TLS oturumlarına bağlamak. EAP başarısını tek başına erişim izni saymadan AD hesabı/grubunu doğrulamak ve politika motorunu güvenilir iç adaptörle çağırmak.
4. İlk kez gerçek Access-Accept/Reject ve VLAN özniteliklerini uçtan uca görmek. Başarılı olduğu kadar reddedilen durumları da kaydetmek.
5. Kanıtlandıktan sonra panel API'sini servis uygulayıcı, secret kasası ve mevcut AD grup seçici ve yetki profilleriyle birleştirmek. Geliştirme HTTP sunucusunu üretim HTTPS/servis altyapısıyla değiştirmek.

Samba/PEAP-MSCHAPv2, proxy veya cihaz yönetimi bu ilk kanıtı geciktirmeyecek. EAP-TLS'ın önceliği dış CA ihtiyacını kaldıran güvenli ürün yolunu erken doğrulamaktır.

## Test planı

| Katman | Test |
|---|---|
| Çekirdek | Policy sıra/koşul/kısıt, varsayılan ret, tip sınırları, VLAN, revision conflict, atomic audit |
| AD | İç içe/primary grup, sayfalama, devre dışı/silinmiş hesap, SID sabitliği, OU, Kerberos/DNS/saat, güvenli bağlantı |
| PKI | Yetkisiz enrollment, CSR/SAN sahteciliği, güven zinciri/EKU/süre, yenileme, iptal/CRL, CA yedek/root rollover |
| RADIUS | Geçerli/geçersiz secret, NAS allowlist, EAP parçalama, TLS, mesaj bütünlüğü/Message-Authenticator, retransmit, replay, rate limit |
| Erişim | Operatörün manuel hazırladığı port ve SSID'de Windows cihaz/kullanıcı EAP-TLS; yanlış grup/sertifika/hesap ve AD kesintisi |
| Panel | Yetkilendirme, oturum/CSRF, secrets redaction, apply/rollback, çift kayıt, arama ve teşhis |
| Appliance | OVF/VMDK/manifest, import, boot, yeniden başlatma, clone uniqueness, offline çalışma, kaynak ölçümü, backup/restore, update rollback |

Switch/AP yönetim API, SSH, SNMP, firmware, roaming, host-mode ve vendor yönetim adaptörleri test planında bulunmaz. Gerçek 802.1X testlerinin başarısı, manuel cihaz yapılandırmasının hazır olmasına bağlıdır.

## Geliştirme ortamının mevcut sınırı

Bu kodun üretildiği ortamda AD domain, switch/AP, FreeRADIUS runtime, hypervisor, Packer, QEMU veya VMware OVF Tool yoktu. 3 Ekim'de kullanıcının Windows geliştirme makinesine GitHub self-hosted runner ile bağlanıldı ve mevcut kurulum/testler doğrulandı. Windows gerçek AD katalog okuması operatörce başarılı bulundu; henüz RADIUS üzerinden gerçek AD kimlik doğrulaması, temiz Linux appliance diski, import ve boot doğrulanmadı. Bunlar kaynak testiyle değiştirilemez ve appliance release kapısı olarak kalır.

## 0.8 kabulü ve 0.9 bağımlılığı

Ubuntu 0.8 lab kurulumu, gerçek AD eşitlemesi ve güncellenmiş kullanıcı/grup üyelikleri operatörce kabul edildi. Panel görsel değişikliği ertelendi. 0.9 kaynak aşaması görüntüleme kataloğundan bağımsız canlı GUID/tokenGroups yetki sorgusu ve kalıcı sertifika bağ okuyucusudur. Gerçek AD tokenGroups tanılaması, doğrulanmış geçici kodu servis hesabıyla çalıştırır; kurulu paneli yükseltmez. Sonraki bağımlılık AD kimliğiyle doğrulanmış endpoint enrollment ve güven dağıtımı; ardından kontrollü FreeRADIUS servis apply ve manuel switch/AP üzerinden fiziksel EAP-TLS/VLAN kabulüdür.

0.9 gerçek AD tokenGroups sorgusu operatörce başarılı doğrulandı. Günlük server/panel geliştirmesi ve otomatik işletim sistemi testleri Ubuntu odaklı yürür; Windows server validation/diagnostics otomatik tetikleyicileri kapatıldı. Windows istemcinin gerçek kablolu/kablosuz 802.1X davranışı, istemci sertifika/trust dağıtımı ve VLAN kabulü test planında kalır.

## 0.10 kapsamı

Operatör Ubuntu üzerinden devam etmeyi onayladı. Bu sürüm kullanıcı kimliğinin kendi Kerberos parolasıyla kanıtlandığı endpoint CSR akışını, atomik clientAuth sertifikası/AD bağ kaydını, panelden CA/liste/indirme/iptal işlemlerini ve durum koruyan lab updater'ı tamamlar. Kullanıcı sertifikası makine kimlik kanıtı olarak kullanılmaz; require_domain_device politikaları aynı kalır. Bilgisayar enrollment için makinenin kendi Kerberos kimlik kanıtı, güven/profil dağıtımı ve kontrollü FreeRADIUS apply bir sonraki bağımlılıktır. 0.9 gerçek tokenGroups kabulü kullanıcı enrollment kabulü yerine geçmez.
