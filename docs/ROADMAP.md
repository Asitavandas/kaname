# KANAME — çalışma planı

Güncelleme: 2026-10-03. Aşamalar bağımlılık sırasıyla ilerler; süreler tek geliştirici için önceki kaba mühendislik tahminleridir, teslim tarihi taahhüdü değildir. İlk gerçek kanıt için yaklaşık 3–4 hafta, panel üzerinden MVP için 9–13 hafta, ilk kapsamın sertleştirilmiş appliance teslimi için toplam 13–20 hafta referans alınır. Laboratuvar/AD erişimi ve sertifika kayıt protokolünün sonuçları bu tahminleri değiştirebilir.

| Aşama | Çıktı | Kabul kapısı | Durum |
|---|---|---|---|
| 0. Başlangıç | Bağımsız repo yapısı, taslak panel, politika motoru, SQLite, OVF sözleşmesi/araçları | Otomatik testler; API simülasyonu gerçek auth olarak kullanılamaz | 0.1 temeli korundu |
| 1. Protokol kanıtı | Gerçek FreeRADIUS + AD adaptörü + dahili PKI enrollment denemesi | Manuel hazırlanmış switch/AP üzerinden gerçek kablolu ve kablosuz EAP-TLS | CA/server CSR/CRL alt adımı tamamlandı; AD/EAP sıradaki |
| 2. Kimlik yaşam döngüsü | AD grup/hesap sorgusu, cihaz/kullanıcı sertifika eşlemesi, yenileme/iptal | Yanlış grup, kapalı hesap, iptal/expired sertifika, AD kesintisi ret testleri | Planlandı |
| 3. Gerçek wizard | DNS/saat/AD testleri, CA/trust, RADIUS secret, GPO/profil çıktıları, kontrollü apply | Başlangıçtan ilk erişime kadar panelden uygulanabilir akış; rollback | Planlandı |
| 4. Günlük yönetim | Kullanıcı/grup seçimi, policy edit, accounting, arama/teşhis, RBAC, audit | Kim yaptı/neyi değiştirdi; oturum ve hata korelasyonu | Planlandı |
| 5. Appliance | OS hardening, ilk açılış, offline runtime, yedekleme, imzalı güncelleme, OVF | Gerçek import, boot, iki bağımsız kimlik, restore ve upgrade rollback | Planlandı |
| 6. NPS uyumluluğu | PEAP yöntemleri, ilave koşullar/VSA, proxy ve failover | Özellik bazlı NPS karşılaştırma matrisi | İlk MVP sonrası |

## Sıradaki somut geliştirme

0.2.0-dev.1 dahili root/issuer CA, RADIUS sunucu sertifikası ve iptal/CRL altyapısını ekledi. Gerçek yerel TLS ve OpenSSL zincir/DNS/iptal doğrulaması yapıldı. Bunun EAP-TLS ya da AD enrollment kanıtı olmadığı korunuyor. Kullanıcının Windows lab runner'ı bağlandı: mevcut kurulum korundu, 131 Windows testi geçti (OpenSSL CLI olmadığı için 1 ek test atlandı), 132 Linux testi geçti. Kayıtlı config/policy/CA ve üç politika simülasyonu doğrulandı. Ayrıntılar WINDOWS_STATUS_2026-10-03.md belgesinde.

1. Tek domainli Windows AD laboratuvarını, Windows endpoint'i ve temiz Ubuntu appliance VM'ini hazırlamak. Switch/AP ve port/SSID ayarları operatörün manuel sorumluluğundadır.
2. Mevcut iç CA/server CSR altyapısını gerçek endpoint trust ve EAP oturumuna bağlamak. İstemci enrollment kimliğini AD nesnesiyle doğrulamadan istemci sertifikası üretimini açmamak.
3. FreeRADIUS'u test EAP-TLS oturumlarına bağlamak. EAP başarısını tek başına erişim izni saymadan AD hesabı/grubunu doğrulamak ve politika motorunu güvenilir iç adaptörle çağırmak.
4. İlk kez gerçek Access-Accept/Reject ve VLAN özniteliklerini uçtan uca görmek. Başarılı olduğu kadar reddedilen durumları da kaydetmek.
5. Kanıtlandıktan sonra panel API'sini servis uygulayıcı, secret kasası ve AD grup seçiciyle birleştirmek. Geliştirme HTTP sunucusunu üretim TLS/oturum altyapısıyla değiştirmek.

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

Bu kodun üretildiği ortamda AD domain, switch/AP, FreeRADIUS runtime, hypervisor, Packer, QEMU veya VMware OVF Tool yoktu. 3 Ekim'de kullanıcının Windows geliştirme makinesine GitHub self-hosted runner ile bağlanıldı ve mevcut kurulum/testler doğrulandı. Henüz gerçek AD/RADIUS kimlik doğrulaması, temiz Linux appliance diski, import ve boot doğrulanmadı. Bunlar kaynak testiyle değiştirilemez ve appliance release kapısı olarak kalır.
