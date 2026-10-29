# AuthWire tahmini süreç ve canlı test raporu

## PR124 sonrası süre değerlendirmesi — 30 Ekim 2026

Test edilen kaynak **628bd7cd18d1ff7abebde5c4fb4f1b8f51962914**: özgün grant/consumption/intent, tek başlatma ve gerçek
dosya motoru günlüğüne bağlandı. Sabit AllSigned child, exact PID/start-time, private auto-reset gate
ve kill-on-close Windows Job Object ile sınırlandı. Kaynak parent/child gövdeleri korunarak gerçek
geçici SMB alanında 20 dosya yazımı ve **127 native kontrol** geçti; mevcut **81 SMB/rollback**
ve **297 preclaim +18 RSA** kontrolleri de başarılı. Tam CI kapanışı kaynak checkpoint'ine kaydedilir.
Grant'lar seed edilir; pozitif AD/içerik ve SYSVOL namespace ortamı açıkça simüledir.
Müşteri Linux/DC01 kurulumu, gerçek gMSA/domain SYSVOL veya cihaz kabulü değildir.

Önceki PR123 tahmini **4–7 aktif iş günü** idi. Bounded stage child ve gerçek journal/completion
bağlama alt kapısı artık geçici gerçek SMB ile doğrulandığı için kalan yazma/kurtarma paketi
**3–6 aktif iş günü** olarak yeniden planlandı. Bu, geçen saat/gün veya test sayısını doğrusal
düşürmek değildir. POLL/result orkestrasyonu, ayrı rollback/onay, kayıp sonuç/partial recovery,
strict backup projection ve imzalı müşteri teslim/kabulü hâlâ açıktır.

İlk pilot ve genel kapanış bantları korunur: diğer kritik paketlerde ve gerçek saha/erişim
kapanışlarında yeni kanıt yoktur. 30 Ekim başlangıçlı koşullu pencereler değişmedi.

| Hedef | Kalan tahmin | Koşullu pencere |
|---|---|---|
| Yazma entegrasyonu ve kurtarma | **3–6 aktif iş günü** | Orkestrasyon/rollback/recovery/teslim çevrimlerine bağlı |
| İlk küçük otomatik pilot | **2–3 hafta** | **13–20 Kasım 2026** |
| 500/1000 teknik ölçek + tek hesap dahil temel ürün | **6–9 hafta** | **11 Aralık 2026–1 Ocak 2027** |
| Yalnız temel sürüm seçilirse kılavuz dahil | **7–10 hafta** | **18 Aralık 2026–8 Ocak 2027** |
| Tüm kayıtlı geliştirmeler ve nihai kılavuz | **13–19 hafta** | **29 Ocak–12 Mart 2027** |

Temel aktif saha **20–30 saat**, tüm kapsam **30–45 saat**; ek **7–14 takvim günü** gözlem ayrı.
Düzenli 5 gün/hafta ortak ilerleme ve hazır erişim varsayılır. Dış yedek hedefi, restore VM,
üretici API ve ölçek uçlarına erişim beklemelerinin son tarihi bilinmiyor. CI'da ölçülen saniyeler
müşteri performans/kapsam kabulü değildir. Tek görev 512 sınırı ve 200→500→1000 teknik kabul planı
korundu; 200 toplam cihaz kotası değildir. Makro 54/94 ve 40 açık; kılavuz bayrakları false.


## PR123 kapanışı ve süre değerlendirmesi — 30 Ekim 2026

Önceki karşılaştırma PR122/29 Ekim kaydıdır. Test edilen kaynak **f0d83009fdc64d2b169ffe45ea96dc149561354f**, merge **67daabaf4e6c48636eac98e77fb2b146f5143cc6**.
29 Ekim testlerinin son servis sonucu yeniden doğrulandı; kaynak kapanışı 30 Ekim kaydedildi.
**297 native Windows kontrolü +18 Python/RSA kontrolü**, **1123 testlik genel koşu (28 ortam atlaması)**
ve **85 kalıcı servis kontrolü** başarılı; dört CI workflow geçti.

Yeni alt katman saklanan izni özgün gönderim/alım zamanında doğrular, kullanımda hâlâ geçerli olmasını
ister; sabit özel journal kökünde önce tek kullanımlık tüketim, sonra bounded readonly kontrol ve
yetkiye bağlı dosya işlem niyetini kalıcı kaydeder. Dokuz gerçek HTTPS/SQLite grant ve beş tüketim
senaryosu sınandı; pozitif AD/içerik/pairing gözlemleri simüledir. Filesystem motoru çağrılmadı.
Müşteri Linux/DC01 kurulumu veya gerçek gMSA/AD/SMB kabulü bu kaynak testleri değildir.

**4–7 aktif iş günü** yazma/kurtarma bandı yeniden değerlendirildi ve korundu. Tüketim/intent alt
katmanı kapandı; bounded stage child, gerçek journal/result, POLL/result worker, rollback, kesinti/
kısmi kurtarma, backup projection ve imzalı müşteri teslim/kabulü açık. İlk uçtan uca yazma/kurtarma
çevrimi henüz ölçülmedi; diğer paketlerde yeni saha/erişim kanıtı yoktur. Aşağıdaki tüm işgünü ve
bağımlılık aralıkları bu nedenle korunur; takvim günü veya test sayısı kalan işten düşülmedi.

Önceki koşullu tarihlerin başlangıcı 29 Ekim idi. Aynı kalan hafta aralıkları 30 Ekim başlangıcına
açıkça yeniden hesaplandığından aşağıdaki pencereler **bir takvim günü ileri** gösterilir.
Bu yeni geliştirme kapsamı, ölçülmüş gecikme veya çalışılmayan arada arka plan çalışma iddiası değildir.

| Hedef | Kalan tahmin | 30 Ekim başlangıçlı koşullu pencere |
|---|---|---|
| Yazma entegrasyonu ve kurtarma | **4–7 aktif iş günü** | Stage child/result/recovery/teslim çevrimlerine bağlı |
| İlk küçük otomatik pilot | **2–3 hafta** | **13–20 Kasım 2026** |
| 500/1000 teknik ölçek + tek hesap dahil temel ürün | **6–9 hafta** | **11 Aralık 2026–1 Ocak 2027** |
| Yalnız temel sürüm seçilirse kılavuz dahil | **7–10 hafta** | **18 Aralık 2026–8 Ocak 2027** |
| Tüm kayıtlı geliştirmeler ve nihai kılavuz | **13–19 hafta** | **29 Ocak–12 Mart 2027** |

Temel aktif saha **20–30 saat**, tüm kapsam **30–45 saat**; ek **7–14 takvim günü** gözlem ayrıdır.
Düzenli 5 gün/hafta ortak ilerleme, aynı gün operatör çıktısı ve hazır test erişimi varsayılır.
Dış yedek hedefi/restore VM/üretici API/ölçek uçlarına erişim beklemelerinin son tarihi bilinmiyor.
Pencereler mühendislik tahminidir; tatil/erişim/oturum beklemelerine karşı teslim taahhüdü değildir.
200 ürün kotası değildir; tek görev 512 hedef sınırı korunur, 500/1000 teknik kabulü açıktır.
Makro **54/94 tamam,40 açık**; alt katman tam dağıtım kabulü sayılmadı. Kılavuz bayrakları false.


## PR122 sonrası süre değerlendirmesi — 29 Ekim 2026

Test edilen kaynak **95b4776b1efe91cecc9cdec7d7314c49eb515609**: Windows SDK'sına bounded pinned HTTPS CLAIM taşıması ve
tek kullanımlık yanıtın kalıcı kaydı eklendi. **168 native WinPS5.1 kontrolü +18 Python/RSA çapraz
kontrolü** geçti. Geçici HTTPS sunucusunda gerçek SQLite çekirdeği 4 izin üretti; her biri replay'i
reddetti ve istemci SDK reload sonrasında ikinci HTTP gönderimi yapmadı. Kayıp/hatalı yanıt ile
receipt disk hatası belirsizliği/kilidi korudu. Binding/AD/candidate context testte simüledir.
Kaynak müşteri Linux/DC01'e kurulmadı; create/peer ve dosya yürütme kapalıdır.

PR121 sonrası **4–7 aktif iş günü** yazma entegrasyonu/kurtarma bandı yeniden değerlendirildi ve
korundu. CLAIM transport/grant alt katmanı ilerledi; POLL/result worker orkestrasyonu, grant
tüketimi, yeniden canlı kontrol sonrası bounded dosya yürütme, rollback, kesinti uzlaştırması,
strict backup projection, imzalı teslim ve müşteri kabulü henüz kapanmadı. Bu geniş paketten
takvim günü veya test sayısı otomatik düşülmedi. Diğer iş paketlerinde yeni saha/erişim ölçümü
yok; aşağıdaki işgünü ve bağımlılık tablosu korunur.

| Hedef | Kalan tahmin | Koşullu pencere |
|---|---|---|
| İlk küçük otomatik pilot | **2–3 hafta** | **12–19 Kasım 2026** |
| 500/1000 teknik ölçek + tek hesap dahil temel ürün | **6–9 hafta** | **10–31 Aralık 2026** |
| Temel sürüm seçeneği, kılavuz dahil | **7–10 hafta** | **17 Aralık 2026–7 Ocak 2027** |
| Tüm kayıtlı geliştirmeler ve nihai kılavuz | **13–19 hafta** | **28 Ocak–11 Mart 2027** |

Aktif saha temel kapsamda **20–30**, tüm kapsamda **30–45 saat**; ek **7–14 takvim günü** gözlem
ayrı tutulur. Düzenli 5 gün/hafta ortak çalışma ve hazır test erişimi varsayılır. Dış yedek hedefi,
restore VM, üretici API ve ölçek uçlarına erişim beklemelerinin son tarihi bilinmiyor.
200 ürün kotası değildir; tek görev512 hedef sınırı korunur. 500/1000 teknik kabulü,
tek hesap geçişi ve nihai operatör kabulü açıktır. Makro 54/94 ve 40 açık; guide bayrakları false.


## PR121 sonrası süre değerlendirmesi — 29 Ekim 2026

Kaynak **50dcb7cc87de1e64bba720c99ed47fa42ed27083**: Windows stage-preclaim doğrulaması, canlı gözlemlerden yerel yol
türetme, bounded AllSigned reader ve kalıcı yerel GPO/job/claim-started kayıtları eklendi.
**82 native Windows kontrolü +18 Python/RSA çapraz kontrolü** geçti; tam CI sonuçları kaynak
checkpoint'ine ayrıca kaydedilir. JSON alan sırası normalize edilir; strict şema ve hash korunur.
Kalıcı worker/paket, yeni peer transport ve Linux/DC01 kurulumu bu adımda değiştirilmedi.

PR120 sonrası **4–7 aktif iş günü** yazma entegrasyonu/kurtarma bandı korunur. Bir source-only
alt katman kapandı; grant yanıtı/transport, gerçek dosya yürütme, rollback adapter, sonuç/journal
uzlaştırma, partial recovery, strict backup projection ve müşteri teslim/kabulü henüz kapanmadı.
Bu nedenlerle geçen takvim zamanı veya kontrol sayısı süreyi kendiliğinden azaltmadı.
Diğer iş paketlerinde yeni saha/erişim ölçümü yok; aşağıdaki süre/bağımlılıkları korunur.

| Hedef | Kalan tahmin | Koşullu pencere |
|---|---|---|
| İlk küçük otomatik pilot | **2–3 hafta** | **12–19 Kasım 2026** |
| 500/1000 teknik ölçek + tek hesap dahil temel ürün | **6–9 hafta** | **10–31 Aralık 2026** |
| Temel sürüm seçeneği, kılavuz dahil | **7–10 hafta** | **17 Aralık 2026–7 Ocak 2027** |
| Tüm kayıtlı geliştirmeler ve nihai kılavuz | **13–19 hafta** | **28 Ocak–11 Mart 2027** |

Aktif operatör saati temel kapsamda **20–30**, tüm kapsamda **30–45**; ek **7–14 takvim günü**
gözlem ayrı. Düzenli5 gün/hafta ortak ilerleme ve hazır erişim varsayımı; dış yedek alanı/restore
VM/API/ölçek uçları beklemelerinin son tarihi bilinmiyor. 54/94 ve40 açık, guide bayrakları false.


## PR120 sonrası süre değerlendirmesi — 29 Ekim 2026

Kaynak **92e478c064b32ee2a94d9070d5519df0c03b706a**: yönetici HTTPS durum/inceleme ve panel durum alanı eklendi.
İki yetki ve güncel session gövde sonrası tekrar doğrulanır. Yavaş ek durum sorgusu aday listesini
bekletmez; eski oturum/yenileme yanıtları atılır. Gerçek onay/create ve peer rotaları kapalıdır.
Windows yürütücüsü, protected yerel kayıt, kesinti/journal uzlaştırma, partial recovery ve strict
backup projection hâlâ açıktır. CI ve kalıcılık kanıtı ilgili kaynak checkpoint'ine kaydedilir.

PR119 sonrası tahmine göre **4–7 aktif iş günü**, ilk pilot **2–3 hafta (12–19 Kasım 2026)**,
ölçek kapılı temel kapanış **6–9 hafta (10–31 Aralık 2026)** ve tüm kapsam **13–19 hafta
(28 Ocak–11 Mart 2027)** bandı korunur. Bu adım dar HTTP inceleme alt katmanını kapattı;
uçtan uca yürütme/kurtarma veya müşteri teslim kabulü kapanmadığı için geçen takvim günü otomatik
düşülmedi. Diğer iş paketlerinde yeni saha/erişim ölçümü yok; aşağıdaki süre ve bağımlılıkları korunur.
Temel sürüm seçeneğinin kılavuzu dahil bandı **7–10 hafta (17 Aralık 2026–7 Ocak 2027)**.
Aktif saha **20–30 saat**, tüm geliştirmelerle **30–45 saat**; ek **7–14 takvim günü** gözlem
ayrı tutulur. Dış yedek/restore VM/cihaz API/ölçek erişimi beklemelerinin son tarihi bilinmiyor.
Tam sürüm/operatör kabulü veya nihai kılavuz teslimi kaydedilmedi; **54/94 ve40 açık** korunur.


## PR119 sonrası süre değerlendirmesi — 29 Ekim 2026

Yazma/geri alma protokolünün kaynak katmanı36 yeni test ve altı CI workflow ile doğrulandı;
[ayrıntılı kayıt](../checkpoints/2026-10-29-staging-write-protocol-source.json).
Yetkili HTTP/panel, canlı Windows scope/CLAIM, yerel durable kayıt, belirsiz sonuç uzlaştırma,
kısmi kurtarma ve backup projection henüz açık olduğundan yazma entegrasyonu bandı **4–7 iş günü**
olarak korunur. Alt katman ilerlemesi tam müşteri kabulü sayılmadı; geçen saat/gün otomatik düşülmedi.
İlk küçük pilot **2–3 hafta**, ölçek kapılı temel ürün **6–9 hafta**, tüm kapsam **13–19 hafta**.
Aktif saha **20–30 /30–45 saat**, gözlem **7–14 takvim günü**; önceki koşullu tarihler değişmedi.


## Aynı gün revizyonu — kapasite ve raporlama talebi

Her durum raporunda kalan süre yeniden hesaplanacak; [raporlama kuralları](../STATUS_REPORTING_RULES.md).
200 ürün kotası değildir. Mevcut tek scope/preview görevi512 hedefle sınırlıdır;1000 hedef için güvenli
parçalama ve sonuç birleştirme henüz yoktur. [Kaynak incelemesi ve ölçek planı](../CAPACITY_AND_ACCEPTANCE.md).

Ölçek paketine3–5 ek işgünü payı kondu: önceki2–4 gün yerine5–9 aktif işgünü.
Bu nedenle ilk küçük pilot2–3 hafta korunurken ölçek kanıtlı temel kapanış5–8'den6–9 haftaya,
tüm hedef kapsam12–18'den13–19 haftaya revize edildi. Bu ilerleme veya kapasite garantisi değildir.
Temel saha eforu20–30 saat, tüm geliştirmelerle30–45 saat olarak yeniden planlandı.
Sayı sınırları kodda yükseltilmedi; bu güncelleme yalnız plan/rapor kaydıdır.


29 Ekim 2026 · Europe/Istanbul · planlama tahmini, teslim tarihi taahhüdü değildir.

## Yönetici özeti

Mevcut düzenli çalışma temposu korunursa panelden ilk otomatik merkezi pilot dağıtımı ve dar uç kabulü için **2–3 hafta**;
temel ürünün açık kabul kapıları ve tek hesap hedefi için **6–9 hafta**;
nihai temel sürüm kılavuzu dahil teslimat için **7–10 hafta** planlıyorum.
Kayıtlı yedi geliştirme paketi de kapsandığında toplam işlevsel kapsam için **13–19 hafta** daha gerçekçi bir aralıktır.

29 Ekim başlangıçlı koşullu takvim:
- İlk otomatik merkezi pilot: **12–19 Kasım 2026**.
- Temel ürünün işlevsel kabulü + tek hesap: **10–31 Aralık 2026**.
- Bu temel sürümün kılavuzu dahil teslimi: **17 Aralık 2026–7 Ocak 2027**.
- Bütün kayıtlı geliştirmeler ve nihai kılavuz: **28 Ocak–11 Mart 2027**.

Kullanıcının nihai hedefi tüm geliştirmeleri içerirse, temel sürüm kılavuzu tarihi yalnız ara sürüm seçeneğidir.
Tek nihai kılavuz, gerçek hedef kapsam tamamlanıp operatör kabulü alındıktan sonra hazırlanır.
Bu rapor kılavuz oluşturma/teslim etme veya ürün tamamlandı kaydı değildir.

## Dayanak ve belirsizlik

Kaynak sabiti **e5aea433146e9452867159544ef38b49d1e2cf9a**. Güncel CURRENT_STATUS üst kaydı, PR118 sonucu,
27 Ekim ayrıntılı durum raporu, ROADMAP, CONNECTOR_SINGLE_ACCOUNT_CHANNEL ve USER_GUIDE_PLAN incelendi.
ROADMAP'ın eski sürüm notları yerine kurulu sürüm için güncel üst kabul kaydı esas alındı.

Son resmi makro sayım **54/94 tamam,40 açık**:
temel ürün **44/59**, geliştirmeler **10/35**. A03/A04 örtüşen ek kapsamdır, tekrar sayılmadı.
Bu oran zamanın %57'sinin tüketildiğini göstermez; kalan işler farklı büyüklükte ve bağımlılıktadır.
1075 genel testin veya 81 çekirdek kontrolünün geçmesi, kalan 40 işin kapandığı anlamına gelmez.

Bu hesap geçmiş işlerin ölçülmüş saatlerinden çıkarılmış istatistiksel bir tahmin değildir.
Kayıtlı son 25–29 Ekim ilerlemesindeki teslim/test/düzeltme çevrimleri ve kalan teknik kapsamdan yapılan
mühendislik değerlendirmesidir. İlk uçtan uca pilot ve tek hesap geçişinden sonra yeniden tahmin edilmelidir.

Varsayımlar:
- Haftada beş gün düzenli ortak çalışma; gerekli yönetici komutlarının ve sonuçlarının aynı gün ilerlemesi.
- Bu süreler aktif çalışma oturumlarına bağlıdır; sohbet kapalıyken kesintisiz arka plan geliştirme varsayımı yoktur.
- Mevcut domain, CA, Linux, Connector ve kabul edilmiş imzalama/güven yolu yeniden kurulmaz.
- Test PC, switch/AP yönetimi ve gerekli kullanıcı erişimleri planlanan saha oturumunda hazırdır.
- Ciddi yeni güvenlik/kimlik/geri alma mimarisi hatası çıkmaz. Aralıklar olağan test-düzeltme tekrarları içerir;
  büyük bir bulgu ilgili aşamaya ayrıca yaklaşık 2–5 iş günü veya mimari yeniden planlama ekleyebilir.
- Yeni arayüz tasarımı veya yeni ürün özelliği kapsamı bu tahmine eklenmemiştir.
- Sunucu dışı yedek alanı, ayrı restore VM'si ve üretici API yetkisi beklemelerinin son tarihi bilinmiyor;
  bu ön koşullar hazır değilse ilgili kapanış tarihi verilemez.

## Bugünkü durum

Linux için kabul edilen sürüm **0.14.0-dev.44**, Windows Connector **df28f70c**.
Gerçek müşteri ortamında birleşik paket önizlemesi **20 dosya /102464 bayt** ile panelde görüldü.
Dosya yazma/geri alma çekirdeği PR118'de geçici gerçek SMB alanında test edilip ana dala alındı.
Canlı yazma işi, yetkili görev/onay akışı, kesinti sonrası kısmi işlem kurtarması ve GPO aktivasyonu henüz teslim edilmedi.

Bilgisayar sertifikalı Ethernet/Wi-Fi ve VLAN daha önce gerçek cihazda kabul edildi.
Yeni otomatik dağıtım yolu için bunlara regresyon kabulü yapılacak; sıfırdan geliştirme varsayılmadı.
Kullanıcı sertifikalı erişim ve tek gMSA altında AD/Kerberos geçişi ayrıca açık.

## İş paketleri ve süreler

İşgünü bir planlama birimidir; tek bir komutun çalışma süresi değildir.
Geliştirme, teknik doğrulama, düzeltme ve kontrollü teslim çevrimini kapsar.
Saha sütunu operatörün aktif oturum zamanını gösterir; günlük çalışma süresine ikinci kez eklenmez.

| İş | Şu anki durum / kalan kapsam | Tahmini çalışma | Aktif saha oturumu | Ön koşul / kapanış |
|---|---|---:|---:|---|
| 1. Onaylı staging/geri alma görevi | Bounded AllSigned stage adapter ve gerçek journal/result bağlama kaynakta gerçek geçici SMB ile test edildi; canlı kapılar kapalı. POLL/result worker, ayrı rollback, kayıp sonuç/kısmi kurtarma, backup ve müşteri teslim/kabulü açık | 3–6 iş günü | 1–2 saat | Aynı gMSA ile gerçek yazma, tekrar/kesinti ve güvenli geri alma kanıtı |
| 2. GPO etkinleştirme | Startup/uzantı/sürüm/link/çoğaltma ve kapsam koruması açık | 2–4 iş günü | 2–3 saat | İş1; ilk seçilmiş pilot PC'de doğal kurulum ve beklenen sertifika/ağ sonucu |
| 3. Kullanıcı EAP-TLS | Sunucu/istemci/panel hazır. Gerçek kullanıcı deposu, Ethernet/Wi-Fi, kullanıcı VLAN ve kimlik geçişi kabulü açık | 2–4 iş günü | 2–4 saat | Kontrollü kullanıcı dağıtımı, en az iki farklı kullanıcıyla ret/izin ve yaşam döngüsü |
| 4. Tek hesap standardı | gMSA Connector çalışıyor. AD katalog/canlı okuma ve Windows Kerberos acceptor taşınacak; eski bağımlılıklar kaldırılacak | 6–10 iş günü | 2–3 saat | Kimlik bütünlüğü, MIC/path/body/CSR bağı, replay/ret/kesinti testleri; eski hesapları ancak bağımlılık kanıtından sonra kaldırma |
| 5. Sertifika/AD olumsuz ve kurtarma | Expiry, yanlış issuer, rollover, silinmiş/kapalı hesap, AD kesintisi ve kalan retry çeşitleri | 3–5 iş günü | 3–4 saat | Ayrı test profili/uç; mevcut erişimi koruyan ret ve güvenli toparlanma |
| 6. Accounting ve işletim kayıtları | Start/Stop/Interim, oturum ilişkisi, saklama/temizlik ve hata görünürlüğü | 3–5 iş günü | 1–2 saat | NAS desteği ve gerçek oturum verisi; kaynak-zaman ilişkisi ayrıca doğrulanır |
| 7. Yedek/restore ve temiz appliance | Yerel yedek var; sunucu dışı kopya, gerçek boot restore, temiz import/bağımsız kimlik ve güncelleme geri dönüşü açık | 3–5 iş günü | 2–4 saat | Dış hedef ve ayrı VM; altyapı bekleme süresi hariç |
| 8. Temel regresyon/kapasite | 200/500/1000 teknik basamakları, 512 üstü güvenli görev parçalama/sonuç birleştirme, kademeli yayılım ve gözlem | 5–9 aktif iş günü + 7–14 takvim günü gözlem | 4–8 saat | İşlem sınırı toplam cihaz kotası değildir; gerçek saha ve sentetik/protokol yük kanıtları ayrı |
| 9. G02/G03 ilk cihaz ailesi | Mod temelleri var. Gerçek cihaz okuma/uygulama/geri alma ve ilk üretici bulut bağlantısı açık | 6–12 iş günü | 3–5 saat | Kullanılabilir desteklenen resmi API ve erişim. İlk üretici/sınırlı model içindir; ek üreticiler yeniden tahmin edilir |
| 10. G04 VLAN/port keşfi | Otomatik kaynak, tazelik, doğru port/SSID/cihaz eşleme | 3–5 iş günü | 1–2 saat | İş9 veya güvenilir cihaz okuma yolu |
| 11. G05 tüm kimlik seçicileri | OU/Everyone ve tüm seçicilerin gerçek yetkilendirme/ret kapsamı | 2–4 iş günü | 1–2 saat | Gerçek AD ve kullanıcı/bilgisayar kimliği; kullanıcıdan bilgisayar hedefi tahmin edilmez |
| 12. G06 canlı topoloji | Port/oturum modeli, Accounting eşleşmesi, port/SSID değişimi ve UI doğruluğu | 4–7 iş günü | 2–3 saat | İş6+9+10; güvenilir canlı veri |
| 13. G07 açıklanabilir öneriler | Veri kalitesi, korelasyon, açıklama ve yanlış alarm ölçümü | 4–7 iş günü + veri gözlemi | 1–2 saat | İş6+10+12 ve temsil edici trafik; veri birikimi takvimi uzatabilir |
| 14. Nihai Türkçe Word/PDF kılavuzu | Tüm nihai ekran/başlık/alan/buton/durum, gerçek görüntüler, adımlar, başarı ve hata çözümleri | 3–5 iş günü | 1–2 saat son inceleme | Hedef işlevsel sürüm ve operatör kabulünden sonra |

Tablodaki üst süreleri toplamak tek bir teslim tarihi vermez: bazı gözlemler, rapor kontrolleri ve bağımsız
işler çakışabilir; kritik bağımlılıklar ardışık ilerler. A03/A04 ile B/G kapsamındaki örtüşmeler tekrar sayılmadı.
Tek hesap taşınması ve cihaz API'si belirsizliği en yüksek paketlerdir. Temel tarih aralığının güveni orta,
yedi geliştirmenin tamamı için güven daha düşüktür.

## Canlı testler ne kadar sürer?

- İlk otomatik pilot turu: hazırlıklar hazır olduğunda **2–4 saat aktif oturum**; genellikle 1–2 güne bölünür.
- Temel ürünün kalan saha kabulleri: yaklaşık **20–30 saat aktif operatör katılımı**;
  sonuç ve düzeltmelere göre **6–10 ayrı test gününe** dağılabilir; bu günlerde toplam yaklaşık 2–4 saat ayrılması varsayılır.
- Yedi geliştirme ve cihaz/topoloji/öneri kabulleri de dahil: toplam yaklaşık **30–45 saat aktif saha çalışması**.
- Buna ek olarak **7–14 takvim günü gözlem** planlanır; bu süre boyunca bilgisayar başında beklemek gerekmez.
  Yenileme, ağ geri dönüşü, otomatik görevler, audit ve veri kalitesi izlenir; geliştirme ile örtüşebilir.
- Gözlemde hata çıkarsa ilgili test grubu düzeltmeden sonra tekrarlanır. Altyapı/cihaz erişimi beklemeleri
  aktif test saatlerine dahil değildir.

Her gün test PC başında bulunman gerekmiyor. Hazır kabul paketlerini test günlerinde bir veya iki adet 60–120 dakikalık oturumda
birleştirmek, ekran/komut/kanıt turlarını planlı yapmak ve sonuçları aynı oturumda kaydetmek uygun olur.
İlk dar kabulde tek PC yeterli olabilir; kullanıcı ayrımı için birden fazla AD kullanıcı kimliği,
bazı expiry/olumsuz senaryolar için ayrı test profili veya ikinci uç, restore için ayrı VM gerekir.
200 uç ölçek kabulü fiziksel/gerçek kapsam olmadan tamamlandı yazılmaz.

## Kritik sıra ve tahmini kapanışlar

1. İlk hafta: onaylı staging/rollback görev akışı, canlı scope adapter'ı, kesinti kurtarma ve teknik testler.
2. İkinci/üçüncü hafta: müşteri teslimatı, GPO aktivasyonu, ilk otomatik pilot ve uç regresyonu.
3. Üçüncü–altıncı hafta: kullanıcı EAP-TLS, tek hesap AD/Kerberos taşınması, yaşam döngüsü ve işletim açıkları.
4. Altıncı–dokuzuncu hafta: temel sürümün restore/kapasite/regresyon ve uzun gözlem kabullerini kapatma.
5. Hedef yalnız temel sürümse: kabul sonrası 3–5 iş günü kılavuz ve son teslim.
6. Hedef bütün geliştirmelerse: cihaz entegrasyonları → keşif → topoloji → öneri; toplam 13–19 hafta,
   nihai kılavuz gerçek kapsam kabulünden sonra.

Tamamlanma yalnız kaynağın yazılmasıyla verilmez: teknik test, müşteri kurulumu, gerçek uç kabulü,
hata/geri dönüş ve kayıt zinciri gereken başlıkta birlikte kapanmalıdır.

## Tahmini en çok değiştirecek konular

- Tek gMSA'ya AD ve Kerberos taşınmasında beklenmeyen kimlik/uyumluluk bulgusu.
- GPO/DFSR/yerel politika farkları veya gerçek uçlarda ayrı Windows/NIC davranışı.
- Gerçek kullanıcı EAP-TLS geçişi ve yaşam döngüsünde yeni hata.
- Dış yedek hedefi, ayrı restore VM'si ve gerçek ölçek uçlarının bulunmaması.
- Cihaz entegrasyonları için desteklenen API veya gerekli yetkinin sağlanamaması.
- Tekrarlanan bağlantı kayıpları, kurulum çıktılarının günler sonra gelmesi veya kapsam değişikliği.

Bu durumlarda güvenlik/doğrulama kapıları gevşetilmez; ilgili paketin takvimi güncellenir.
Tekrarlı genel testler rastgele çoğaltılmaz; anlamlı değişiklik/hata/çözülmemiş risk olduğunda çalıştırılır.

## Sonraki adım

Mevcut geliştirme sırası değişmedi: yetkili, idempotent staging/geri alma görev protokolü;
güncel AD/PDC/GPO ve imza kontrollerini kullanan bounded Connector adapter'ı ve kısmi işlem kurtarması.
Bu rapor hazırlanırken panel, AD/GPO, cihaz, servis, yedek veya hesap ayarı değiştirilmedi.
READY_FOR_FINAL_GUIDE=false ve GUIDE_DELIVERED=false korunur.
