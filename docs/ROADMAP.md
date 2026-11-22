# AuthWire — güncel çalışma planı

## 22 Kasım 2026 — G01 süre koruması kalıcı teslim edildi

60/94 tamam,34 açık; G01 2/5,G05 5/5. Parent/child/engine artık özgün grant ve gerçek15000ms work penceresinin küçüğüne bağlı. Engine girişinde2s kalmazsa dosya/journal oluşturmadan ret; sonuç için1s ayrılır. Private input'lar önce native handle ile sabitlenir, sonra tam yetki zinciri doğrulanır; modül import'u intent/gate/PID denetiminden sonradır.

Yeni24 süre hesabı ve92 AllSigned/CNG/SMB kontrolü geçti:7s kontrollü context gecikmesiyle20 dosya12,95s'de hazırlandı; geç context14,06s'de hard timeout/hedef/engine journal olmadan reddedildi. AD/namespace ve grant bu CI'de test verisidir. Son kaynakda8ff7c0;9 değişen Git blob'u yerelle aynı. Son snapshot18/21 genel CI başarılı, üç koşu sürüyor.

İmzalıe3573903 release DC01'e Prepare/Apply ile kuruldu; Connector healthy ve writer dinlemede. Mevcut18765 dahil config yalnız release dışında aynı; B9 arşivi ve eski kapanış kanıtları korunur. Yeni saha stage/rollback job yok; c292 kurtarması,24/92 testleri veya önceki18 ölçümleri tekrarlanmayacak. Önceki0a55/B24/0455/5991 adaylar hiç uygulanmadı ve yeni kabulde kullanılmayacak.

Sırada kalan CI sonuçlarını okumak; uygun koşulda yeni taze önizleme/yetkiyle gerçek AD20 dosyalı stage ve ayrı rollback. Üç uç etkin GPO teslimi ve harici eşleşen restore açık. G01 5–9 aktif iş günü yeniden değerlendirildi, korundu; diğer bantlar aynı. [Kanıt](checkpoints/2026-11-22-g01-stage-work-budget.json).


## 22 Kasım 2026 — G01 hazırlık okuması iyileştirildi; tam yürütme kabulü açık

60/94 tamam,34 açık; G01 2/5,G05 5/5. Yeni gerçek salt okunur gözlem7876→6745ms; iki uçtaki bütün güvenlik gözlemleri korunarak üçüncü fazladan içerik turu kaldırıldı.18 yeni non-admin sözleşme kontrolü ve5 tarihsel kaynak kontrolü geçti. PR167 son76b87e3b, ürün kodu453d1585; son genel CI sürüyor. İmzalı0a55f57c aday Prepare geçti; tüm bağlantı/eşleştirme/anahtar ayarları aynı. Apply işçiyi otomatik başlattığından mevcut B9 ve durmuş yazıcı korunur. Yanlış port taşıyan0455 aday hiç uygulanmadı.

Sırada bütün çocuk başlangıç/özgün yetki/engine/postcheck bütçesinin kapanması; son CI'yi okumak ve sonra doğru aday Apply + ayrı taze yetkiyle tam20 dosyalı stage/ayrı rollback. İki süre ölçümü,18 kontrol, c292 kurtarması veya G05/EAP/CRL testleri tekrarlanmayacak. Üç uç etkin teslim ve harici eşleşen restore açık. G01 5–9 aktif iş günü yeniden değerlendirildi, daraltılmadı; diğer bantlar aynı. [Kanıt](checkpoints/2026-11-22-g01-cold-read-optimization.json).


## 22 Kasım 2026, 19:03 — Boş kısmi hedef ve kilit kurtarması tamam

c292e179 işi AllSigned gMSA bakımıyla kapandı:18:58:33 yalnız boş hedef kaldırıldı, tam başlangıç envanteri geri geldi; engine intent/grant/belirsiz sonuç korundu.18:59:48 ayrı CNG kapanışı Linux rev145'te kabul edildi; ilgili kilit yok. Kalıcı B9 Connector ve izole Linux f5b98a5e kuruldu.51 Linux defter testi,17 Linux CI ve79 native kontrol geçti; tüm Windows CI ilan edilmez. Yazıcı soğuk çocuk bütçesi çözülene kadar duraklatıldı; yeni iş/boş çevrim veya eski saha testi tekrarlanmadı. **Sırada süre sorununun ölçümü ve çözümü var; c292 kurtarması tekrar edilmeyecek.** Sonra tam20 dosyalı stage/rollback, üç uç etkin teslimi ve harici eşleşen kurtarma.60/94,34 açık,G012/5,G055/5 ve5–9 aktif iş günü korundu. [Kanıt](checkpoints/2026-11-22-g01-empty-stage-field-recovery.json).

## 22 Kasım 2026, 17:20 — Yeni gerçek stage süre aşımı: kısmi boş hedef korunuyor

Yeni önizleme geçti; tek yeni c292e179 işi14s çocuk bütçesini aştı. Engine intent ve yalnız boş sahip olunan sürüm dizini var;0 dosya. Dizinin dışındaki GPO envanteri başlangıçla aynı. İmzalı requires_review sonucu Linux rev142'de; worker dikkat gerektiği için durdu. Kilit/hedef/kanıtlar korundu, geri alma işi oluşmadı.733 no-engine kapanışı bu kısmi yazıma uygulanamaz. **Sırada yeni deneme değil, mevcut kısmi işin ayrı denetimli kurtarması ve yürütme bütçesi çözümü var.**18 mevcut kaynak CI koşusu başarılı; yeniden başlatılmadı. Geçici operatör/görev/parola dosyaları temizlendi. Sayım60/94,34 açık,G012/5,G055/5; G01 süre5–9 aktif iş günü korundu. [Kanıt](checkpoints/2026-11-22-g01-stage-timeout-review.json), [durum](CURRENT_STATUS.md).

## 22 Kasım 2026 — Intent kurtarması ve kalıcı paket teslimi kapandı

733fc751 işi16:59:03'te CNG kapanışı ve Linux rev137 ile denetimli kapandı. Özgün grant/intent/belirsiz sonuç korundu; yeni000072 no_job ile devam doğrulandı. Windows kalıcı released3b84b6a, kaynak4b7b71b7; izole Linux kaynağıa93f3fbe. Gerçek yeni stage/rollback, üç uç etkin GPO teslimi ve harici eşleşen günlük kurtarma açık; **60/94 tamam,34 açık;G012/5,G055/5** korunur. [Kapanış](checkpoints/2026-11-22-g01-intent-field-closure.json), [süre](reports/2026-10-29-process-forecast.md). Bitmiş kurtarma ve junction testleri tekrar edilmeyecek.

## 22 Kasım 2026 — Junction kaynak ve salt okunur saha kabulü geçti

PR167 kaynak1d6c4757: yerel PDC'nin standart SYSVOL junction'ı ve fiziksel hedef kimliği sabitleniyor; FILE_LIST_DIRECTORY ile yeniden adlandırma engeli doğrulandı. Ayrı alanda17 native kontrol ve gerçek gMSA ile CNG imzalı salt okunur gözlem geçti. Kalıcı paket21d54b36 ve 733 işinin inceleme kilidi korunuyor; intent uzlaştırması, CI/paket ve gerçek stage/rollback açık. Sayım60/94,34 açık,G012/5; G055/5. [Kanıt](checkpoints/2026-11-22-g01-sysvol-junction-validation.json), [süre](reports/2026-10-29-process-forecast.md). Başarılı junction/alan gözlemi tekrar edilmeyecek.

## 22 Kasım 2026 — G01 arşivi tamam, yeni junction/intent inceleme kapısı

64 gerçek çevrim arşivi ve 65. no_job kabulü tamamlandı. 4da20206 intent öncesi tüketim kurtarması kapandı; sonraki 733fc751 işi standart SYSVOL junction reddiyle filesystem-intent sonrası incelemede, kilidi korunuyor. Kaynak c729289e PR167'de, release21d54b36 DC01'de. Geri alma CI başarısız olduğundan bütün stage/rollback kabulü açık; sırada doğrulanmış junction desteği ve denetimli intent uzlaştırması var. **G01 2/5; toplam60/94,34 açık**. [Kanıt](checkpoints/2026-11-22-g01-history-and-stage-review.json), [durum](CURRENT_STATUS.md), [yeniden değerlendirilen süre](reports/2026-10-29-process-forecast.md).

## 22 Kasım 2026, 12:44 — G01 kurtarma saha adımı tamamlandı

Eski d918bc0d işi/kilidi kapandı; imzalı Windows kapanışı ile Linux revizyon121 eşleşti, Connector yeni no_job çevrimine devam etti. **G01 2/5 ve toplam 60/94, 34 açık** korunur: gerçek GPO hazırlama/geri alma, üç uç teslimi ve harici Windows günlük kurtarma kabulü açıktır. [Kapanış kaydı](checkpoints/2026-11-22-g01-consumed-stage-closure.json), [güncel durum](CURRENT_STATUS.md), [yeniden değerlendirilen süre](reports/2026-10-29-process-forecast.md).

## 22 Kasım 2026 — güncel kabul durumu

**60/94 tamam, 34 açık; G05 5/5 kapandı.** Saha kanıtları 21 Kasım'a aittir; kapanışta tamamlanmış testler tekrarlanmadı. [Güncel kayıt](CURRENT_STATUS.md), [beş seçici kabul matrisi](checkpoints/2026-11-21-g05-acceptance.json) ve [yeniden değerlendirilen süreler](reports/2026-10-29-process-forecast.md). G01/A04 üç uç/GPO teslimi, B02 hesap silinmesi/AD kesintisi, A03 kullanıcı Wi-Fi, B11 NAS ve B12 dış kurtarma kapıları açıktır. Aşağıdaki tarihli eski bölümler geçmiş kayıttır.

## 29 Ekim 2026 — raporlama ve ölçek açıklaması

Her durum raporunda kalan süre yeniden hesaplanır: [raporlama kuralı](STATUS_REPORTING_RULES.md).
200 bir ilk ölçek kabul basamağıdır; ürün kotası değildir. Mevcut scope görevi512 hedefle sınırlı;
500/1000 teknik ölçek ve güvenli parçalama desteği açık iş olarak planlandı.
[Kapasite/kabul ayrımı](CAPACITY_AND_ACCEPTANCE.md) ve [güncel süre tahmini](reports/2026-10-29-process-forecast.md).

21 Ekim2026. Kurulu pilot sürümü0.14.0-dev.13'tür; policy butonunun geliştirme, teknik test ve canlı kurulum/yedek/restore/API kabulü tamam; 🔴✓operatör Etkin durum ve Devre dışı bırak butonu görünümünü doğruladı; gerçek policy toggle saha kabulü bekler. Ayrıntılı kanıtlar ve tarihli
sonuçlar [CURRENT_STATUS.md](CURRENT_STATUS.md), işletim/kurtarma adımları
[OPERATIONS_0_14_0.md](OPERATIONS_0_14_0.md) içindedir. Eski sürüm notları tarihsel
kapsamdır; burada tamamlanan saha işleri yeniden “bekliyor” sayılmaz.

## 🔴✓ Connector dev.35 canlı uygulaması doğrulandı — 26 Ekim 2026

Operatörün paylaştığı `CONNECTOR_CHANNEL_FINISHED` çıktısında **0.14.0-dev.35 / 2023ac92faf3ee1b9d25d3d0e2c09cfe3ba96c34** başarıyla uygulanmış; bildirilen tüm önce/sonra API okumaları 200. RADIUS PID **1243360** ve kontrol süreci **1069437** korunmuş; politika, sertifika, GPO ve Windows uç noktaları değişmemiş; günlük yedek timer korunmuş. Kanıt: `/var/lib/authwire-updates/connector-channel-dev35-20261026T101342Z-fc756ec9`.

Appliance UUID **6796fa84-fcff-41c1-b9c5-d725b95ba139**, Windows Connector UUID **4c23eebe-0715-46d1-88ee-a2e96ad7ee46** olarak ayrı tutulur. Public TLS SHA256 **a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d**. Henüz eşleştirme yazılmadı, sağlıklı Connector iddiası yok. DC01 için yalnız okuma yapan hesap/sertifika/yayıncı güveni ve normal zincir/ad/iptal kontrolü + TLS pin kontrol dosyası hazır; gerçek DC01 çalışması bekliyor. Dosya yönetici oturumunu sınar; gMSA HTTPS kabulü sayılmaz. Eksik güveni/izni otomatik eklemez, anahtar/hizmet oluşturmaz.

Sırada imzalı Windows paket teslimi, ayrı kanal anahtarı, yetkili panel eşleştirmesi ve gerçek gMSA hizmet kabulü var. **54/94 (~%57) tamam, 40 açık; A03/A04 devam ediyor.** Bu altyapı adımı tamamlanmamış uçtan uca otomasyon olarak işaretlenmedi. Tek gMSA hedefi korunur; eski hesaplar henüz kaldırılmaz. Önceki hazırlık notları tarihsel kanıttır; aşağıdaki eski “sudo bekliyor” durumu bu canlı sonuçla aşılmıştır.

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
| B08 Policy/VLAN | Dar pilot grubunda/NAS'ta kablolu/kablosuz gerçek policy VLAN ve DHCP; 🔴✓21 Ekim dev.13 Etkin/Devre dışı rozeti ve Devre dışı bırak/Etkinleştir butonu, yalnız enabled değişimi/ayarların korunması, gerçek HTTP/tarayıcı ve temel/native/Windows kontrolleri; PR43 merge ve Git/SHA doğrulanmış paket; 🔴✓21 Ekim canlı dev.13 kurulum, koruma/yedek/162dosya izole restore ve API200 kabulü, RADIUS/broker PID koruması; 🔴✓operatör Etkin/buton görünümü kabulü | Diğer deny koşulları ve gelişmiş seçiciler; 🔴✓yalnız pilot wireless disabled adımı sonrası VV06 yeni bağlantı21:20:12/12013-8002/disconnected ile Windows reddi; 🔴✓21:25:39 yeniden enabled sonrası Windows12012/8001/connected ve10.10.140.2/24Preferred döndü; 🔴✓kayıt26/27NO_MATCHING_POLICY ve30POLICY_ALLOW/VLAN140/TLS ile Windowsaynısaniye eşleşmeleri doğrulandı; ilk kurulum yedeği zaten Ret/boşVLAN, şimdiki kayıt İzin/140. 🔴✓operatör önce İzin'i elle Reddet'e çekip kaydettiğini ve unuttuğunu açıkladı; Ret/boşVLAN incelemesi önceki kayıtlı ayar olarak kapatıldı, ürün düzeltmesi gerekmedi. Safallow140→disabled→enabled turu ayrıca uygulanmış sayılmaz; 🔴✓operatör doğrulanmış özgün Wi-Fi profil yedeğinin netsh ile başarıyla yüklendiğini bildirdi, geçici profil test temizliği tamam |
| B09 Kablolu | Pozitif; sertifikasız/grup dışı/kapalı/iptal ret; reboot/recovery; 🔴✓19 Ekim ağsız boot sonrası kablo takılınca EAP/VLAN110 geri dönüşü ; 🔴✓20 Ekim yarım kurulumdan toparlanan yeni26e... sertifika ile taze kablolu POLICY_ALLOW/VLAN110/TLS ve Windows15505 | Kalan olumsuz kimlik/güven, expired ve diğer yarım kurulum senaryoları |
| B10 Kablosuz | AP22/SSID, EAP-TLS ve gerçek dinamik VLAN; 🔴✓21 Ekim VV06 doğru KANAME root/server-name/machine profil exportu, taze WLAN12012/8001 ve10.10.110.2/24; 🔴✓yanlış sunucu adıyla12013/0x800B0114/disconnected, doğru export yüklenince aynı SSID/AP'de connected: dar olumsuz güven ve geri dönüş saha kabulü tamam; 🔴✓yalnız AAA kökü seçildiği exportta doğrulandı,19:26:07 olay12013/0x800B0109 ile ret; doğru KANAME exportu yüklenince connected ve10.10.110.2/24Preferred geri geldi; 🔴✓21 Ekim8satır/16sütun gerçek Wi-Fi CSV'sinde6kabulün güncel26e...seri/computerGUID/kablosuzpolicy/TLS eşleşmesi; 🔴✓operatörün policy140değişikliği,CSV140Access-Accept ve doğruWi-Fibağlantısından sonra10.10.140.2/24DhcpPreferred uçkabulü tamam | Diğer negatif güven/kimlik ve kullanıcı EAP-TLS senaryoları; TLS full-resumption ve kesin kaynak-zaman korelasyonu ayrıca doğrulanmadı; önceki APIPA ölçümü kablosuzbağlantı yokken alınmış, DHCP/VLAN arızası doğrulanmadı; guest tekrarı istenmedi |
| B11 Kayıt/korelasyon | Servis işlem geçmişi ve temel audit; 🔴✓ dev.8 yönetim geçmişi filtre/sayfalama/CSV operatör kabulü; 🔴✓ dev.9 final RADIUS kaydı geliştirme/izole native-systemd/UI ve canlı etkinleştirme, koruma/API/yedek/izole restore teknik kabulü; 🔴✓ dev.9 operatör ekranının hatasız açılması; 🔴✓ VV06 gerçek kabul kayıtları ve16 sütunlu canlı CSV teknik kabulü; 🔴✓21 Ekim kablosuz CSV8kayıt/16sütun,6kabul/2ret,ayrıevent/requestID ve sertifika-cihaz-policy eşleşmesi | 🔴✓21 Ekim policy testi ret26/21:20:12 ve kabul30/21:25:39 olaylarında Windows/RADIUS aynıMAC-GUID-seri/NAS/aynısaniye dar korelasyon; Excel görünümünün operatör bildirimi ve diğer senaryolarda Windows/RADIUS zaman-tetik eşleştirmesi (olası eşleşmelerde yaklaşık124saniye sapma; VV06DC01kaynağı doğrulandı,DC-Linux-123.123sölçüldü;🔴✓DC01NTPkaynağıyedekle ntp.ubuntu.com'aalındı,resyncbaşarılı,3tekrarDC-Linux~4ms;🔴✓VV06duvarsaat5örnekte<1msveorijinal300/NT5DSgeridönüş;sonLeap3/Unset/LastSyncError1kalıcıW32Timesağlığıaçıkizlem,operatöristeğiyleNTPçalışmasıdurdu;ortakpaketteyidi bekliyor); accounting/korelasyon ve arşiv/saklama/temizlik |
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
| G05 | Gelişmiş User/Computer/Group/OU/Everyone seçicileri | **5/5 tamam (22 Kasım)**: gerçek karar hattı, fiziksel EAP ve ayrı ret kanıtları; katman ayrımı kabul matrisinde |
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
