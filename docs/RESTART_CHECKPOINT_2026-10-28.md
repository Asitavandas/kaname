# AuthWire devam noktası — 28 Ekim 2026

## Raporlarda kalan süre ve kapasite ayrımı — 29 Ekim 2026

Kullanıcı talebi kalıcı çalışma kuralı olarak **docs/STATUS_REPORTING_RULES.md** içine kaydedildi:
**her güncel durum raporu güncellemesinde kalan süre yeniden değerlendirilecek**.
İş paketi, kalan işgünü aralığı, koşullu bitiş penceresi, aktif saha saati, gözlem/bekleme,
önceki tahminden fark ve gerekçesi gösterilecek. Sadece geçen gün sayısı düşülmeyecek.

**200 cihaz ürün/lisans kotası değildir; ilk ölçek kabul basamağıdır.**
Kaynak kontrolünde mevcut scope/combined-scope/staging-preview görevleri ve Windows scope doğrulayıcısında
**tek görev için512 hedef** sınırı görüldü.1000 bilgisayarlı grubu bugün tek bu görevde doğrulama desteklenmiyor.
Bu toplam RADIUS/NAC kapasitesi değildir.500 sayı sınırında olsa da performans/saha garantisi yoktur.
500/1000 için güvenli iş parçalama, tam kapsam/sonuç birleştirme, kısmi hata ve yük kabulü açık işe eklendi.
Sınır kodda artırılmadı; yeni yük testi veya müşteri ayar değişikliği yapılmadı.

Güncel kalan süre (düzenli beş gün/hafta ortak ilerleme, hazır test erişimi varsayımı):
| Hedef | Tahmin | Koşullu bitiş |
|---|---|---|
| İlk küçük otomatik merkezi pilot | **2–3 hafta** | **12–19 Kasım 2026** |
| 500/1000 teknik ölçek kapısı dahil temel ürün + tek hesap | **6–9 hafta** | **10–31 Aralık 2026** |
| Temel sürüm hedef seçilirse kılavuz dahil | **7–10 hafta** | **17 Aralık 2026–7 Ocak 2027** |
| Bütün kayıtlı geliştirmeler ve nihai kılavuz | **13–19 hafta** | **28 Ocak–11 Mart 2027** |

Önceki tahmine fark: kapasite/regresyon paketi2–4'ten **5–9 aktif işgününe** çıktı;
512 üstü güvenli görev parçalama/500–1000 testleri için yaklaşık **3–5 ek işgünü** payı ayrıldı.
İlk dar pilot değişmedi; temel kapanış5–8'den6–9, bütün kapsam12–18'den13–19 haftaya revize edildi.
Temel aktif saha eforu **20–30 saat /6–10 ayrı test günü**; tüm geliştirmelerle **30–45 saat**.
Ayrıca **7–14 takvim günü** gözlem geliştirmeyle örtüşebilir. Bu tarih/kapasite garantisi değildir;
API, dış yedek hedefi, restore VM ve gerçek ölçek uçları beklemeleri kapanışı uzatabilir.

Kabul kanıtı her zaman türü ve ölçülen kapsamıyla verilecek; sentetik1000 kayıt gerçek1000 uç kabulü değildir.
Bugün1000 fiziksel PC'nin hazır olması geliştirme ön koşulu yapılmadı.
Ayrıntılar **docs/CAPACITY_AND_ACCEPTANCE.md** ve güncellenmiş **docs/reports/2026-10-29-process-forecast.md**.
Genel **54/94 tamam,40 açık** ve kılavuz bayrakları false korundu.
Sonraki geliştirme aynı onaylı staging/rollback iş akışı; büyük kapsam desteği bu tasarımda ayrıca ele alınacak.

## Süreç tahmini kaydedildi — 29 Ekim 2026

Operatör mevcut tempoyla iş paketleri ve canlı test sürelerini istedi.
Koşullu mühendislik tahmini: ilk otomatik merkezi pilot **2–3 hafta (12–19 Kasım)**;
temel ürün + tek hesap **5–8 hafta (3–24 Aralık)**.
Temel sürüm hedef seçilirse kılavuz dahil **6–9 hafta**; tüm kayıtlı geliştirmeler ve nihai kılavuz
için **12–18 hafta (21 Ocak–4 Mart 2027)**. Bunlar taahhüt veya ölçülmüş hız modeli değildir.

Temel saha kabulü yaklaşık **15–25 aktif saat /5–8 ayrı test günü**;
tüm geliştirmelerle **25–40 saat** ve buna ek **7–14 takvim günü** gözlem.
Haftada beş gün düzenli ortak ilerleme, aynı gün kurulum çıktıları, test erişimi ve hazır altyapı varsayılır.
Tek gMSA için AD okuma ve Kerberos taşıması ayrıca **6–10 iş günü** tahmin edildi.
Kullanılabilir üretici API yetkisi, off-host yedek hedefi, restore VM'si veya ölçek uçları yoksa
ilgili tam kapanış için tarih verilemez. G02/G03 ilk üretici/sınırlı model kapsamıdır.

Ayrıntılı iş/süre/bağımlılık ve kabul tablosu **docs/reports/2026-10-29-process-forecast.md**.
Genel **54/94 tamam,40 açık** değişmedi. Yüksek test sayısı veya dar önceki saha kabulü bütün ürün tamamlandı sayılmadı.
Kılavuz bayrakları false; bu rapor kılavuz değildir. Panel/AD/GPO/servis/yedek/cihaz ayarı değiştirilmedi.
Sonraki geliştirme aynı: onaylı ve idempotent staging/rollback görevi, canlı scope adapter'ı ve kısmi işlem kurtarması.

## Sınırlı dosya yazma/geri alma çekirdeği kaynakta test edildi — canlı entegrasyon bekliyor — 29 Ekim 2026

**PR118** merge **8ae5a1a8f6b05caf7bb4a3a18b1a8f49329ccb50**; test edilen head **dc6c8d817638728777eba7e2e1df4bf97e200fa0**.
Yeni **StagingFilesystem.ps1** güvenilen çağıran için izole dosya işlem çekirdeğidir.
90 saniyelik tam önizleme, 20 dosyalık kaynak hash/boyut/ACL listesi ve beş öğeli boş GPO tabanını
yeniden doğrular; yalnız türetilen yeni sürüm klasörüne CreateNew ile yazar.
Yerel intent/complete kayıtları flush edilir; kaynak dosyalar ve yol dizinleri handle ile sabitlenir.
Reparse/ADS/hardlink ve mevcut hedef reddedilir. Geri alma öncesinde ayrıca rollback intent yazılır;
yalnız tamamlanmış sahiplik kaydındaki tam dosya kimliği/hash/ACL ağacı eşleşirse handle üzerinden silinir.
Recursive delete veya mevcut verinin üzerine yazma yoktur.

**Dört workflow başarılı.** Native WinPS5.1/gerçek geçici SMB testinde **81 kontrol**
(40 mevcut önizleme,41 dosya işlem/sahiplik kontrolü) geçti; gerçek 20 dosyalı yazma ve geri alma,
bayat/yanlış onay, korunan GPO, kaynak/taban/izin/ADS/hardlink/junction farkı, dosya değiştirme kimliği,
handle ile yazma/yeniden adlandırma yasağı, tekrar istek ve completion kayıt hatası sınandı.
Genel **1075 test /28 ortam atlaması**; Windows regresyon workflow'unun beş job'ı başarılı,
gerçek düşük yetkili imzalı SCM yaşam döngüsü **85 kontrol** ile altı kanal/kesinti/crash/otomatik ve açık rollback'i geçti.
Test edilen source head için run'lar **40846597760 /40846597638 /40846597682 /40846597807**.

**Bu kaynak bileşeni canlı Connector paketine, API/görev kanalına veya panel yazma butonuna eklenmedi.**
Müşteri Linux/DC01/AD/GPO/SYSVOL/endpoint veya anahtar/sertifika ayarı değiştirilmedi.
Canlı kabul edilen durum Linux **dev.44**, Windows **df28f70c**, son gerçek salt okunur önizleme **11:36:38**.
Hash argümanı kimlik doğrulama veya operatör yazma onayı değildir.
Kesinti/kısmi I/O hatasında intent ve varsa kısmi klasör incelemeye bırakılır; otomatik partial cleanup/resume yoktur.

**Sıradaki iş:** yetkili typed yazma/geri alma onayı ve idempotent görev akışını, güncel canlı AD/PDC/GPO/link/sürüm,
imza/izin kontrollerini ve sabit türetilmiş yolları kullanan bounded Connector adapter'ını hazırlamak.
Kısmi işlem/kesinti kurtarma kapısı ayrıca tamamlanmalı; ardından ayrı müşteri teslimatı ve gerçek gMSA staging/rollback kabulü.
GPO aktivasyonu/çoğaltma ve gerçek endpoint kabulü halen açık. Gelecek yazma için yeni taze önizleme gerekecek.
Genel **54/94 tamamlanan,40 açık** değişmedi; kılavuz bayrakları false. Yeni tam veri yedeği alınmadı.
Kod/test ayrıntısı **docs/STAGING_FILESYSTEM.md**; kanıt **docs/checkpoints/2026-10-29-staging-filesystem-source.json**.

## Gerçek hazırlık önizlemesi panelde doğrulandı — SYSVOL yazıcısı sonraki aşama — 29 Ekim 2026

Operatör **Paket dosyaları ve geri alma sınırı** bölümünü iki ekran görüntüsüyle paylaştı.
Kontrol zamanı **29.10.2026 11:36:38 Europe/Istanbul**. Mevcut birleşik aday için
**20 dosya /102464 bayt** ve hedef **Machine/AuthWire-524653f5135946f584a546355bb82aff-v1-124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b** görüntülendi.
20 satırın boyutları yeniden toplandı: **102464 bayt**.
Önizleme SHA256 **76b22e299cc4c45b6d76e8d803862588a712d26cf08f7e49c0a37c7bdac62a5d**.
Görüntülerdeki manifest/draft hashleri mevcut kabul edilen birleşik adayla eşleşiyor.

Bu kayıt, gerçek müşteri Connector önizleme sonucunun panelde görüntülenmesine ilişkin operatör kanıtıdır.
İncelenen UI bu ayrıntıları yalnız doğrulanmış preview sonucunda gösterir; worker mevcut gMSA hesabıyla çalışır.
Bu kontrol sırasında raw job/imzalı payload alınmadı ve 20 kaynak dosyanın hashleri bağımsız yeniden hesaplanmadı.
Ekran görüntüleri ve hashleri **docs/checkpoints/2026-10-29-customer-staging-preview-browser-accepted.json** içinde referanslandı.
90 saniyelik güncellik süresi kalıcı değildir; ileride yazma işlemi için yeni güncel önizleme gerekecek.

**Önizleme dosya yazmadı ve dağıtım yetkisi vermedi.** Yalnız yeni sürüm klasörünü kapsayan geri alma sınırı,
sahiplik kaydı ve tam dosya/izin eşleşmesi koşulları panelde görünüyor.
Linux **dev.44**, kabul edilen Windows **df28f70c**. Gerçek hazırlık önizlemesi/panel alt kabulü kaydedildi.
Genel ürün tamamlanması değildir: **54/94 tamamlanan,40 açık** sayımı değişmedi; kılavuz bayrakları false.

**Sıradaki iş:** güncel önizleme, açık yazma onayı, sahiplik journal'ı ve drift kontrolüyle sınırlı
SYSVOL staging/geri alma yazıcısını kaynakta hazırlamak, incelemek ve test etmek.
Bu yazıcı mevcut teslimatta yoktur; canlı SYSVOL'a kopyalama/silme komutu verilmedi.
GPO link/startup/sürüm/çoğaltma aktivasyonu ve gerçek endpoint kabulü sonraki açık kapılardır.
Yeni tam veri yedeği alınmadı; hesap sadeleştirme ve önceki ilk cf742 Apply iç hata incelemesi açık kalır.

## DC01 önizleme worker Apply başarılı — gerçek panel önizlemesi bekleniyor — 29 Ekim 2026

Operatör **ToolVersion1.5.0 /Mode=Apply /Stage=applied /Upgrade.Phase=applied** sonucunun tamamını paylaştı.
**Kabul edilen Windows Connector sürümü df28f70c-104e-4d6d-972c-e311d38adde6**,
kaynak **92b2af9b78347058802f4bb135b5fbb243abc813**. Önceki sürüm cf74295c arşiv yolu kayıtta korunur.
**SourceSignaturesValid=true /ServiceTransitioned=true /Error=null /ChangesMayBePartial=false**.
Mevcut hesap, pairing ve kanal anahtarı korundu; **SignerSnapshotPreserved=true**.
AD/GPO, key ACL ve trust store değişmedi; yeni servis veya kanal anahtarı oluşturulmadı.

İncelenen yükseltme kaynağında applied sonucu yalnız Running servis, doğru runtime SID/yeni sürüm,
taze sağlıklı worker ve **altı kanalın** (yeni StagingPreviewChannelVerified dahil) doğrulanmasından sonra yazılır.
Bu sonuç bu yükseltme kapısının geçtiğini gösterir; bağımsız sonraki anlık status okuması veya gerçek görev başarısı değildir.
Kanıt **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-df28f70c104e4d6d972ce311d38adde6-78280346890f47cc98c11fa37eb7b57a**.
Tam kullanıcı sonucu **docs/checkpoints/2026-10-29-customer-staging-preview-worker-apply.json** içinde kayıtlı.

**Sıradaki operatör adımı:** panelde mevcut **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket**
kaydını Yenile ile aç; **Paket hazırlığını önizle → Hazırlık önizlemesini gönder** akışını bir kez çalıştır.
Görevi yeniden oluşturmadan bekle/Yenile; sonuç ve **Paket dosyaları ve geri alma sınırı** bölümünü kaydet.
Beklenen başarı **Paket hazırlığı önizlemesi hazır. SYSVOL dosyası yazılmadı.**; 20 dosya/boyut/hash,
önerilen klasör, önizleme SHA256 ve kontrol zamanı ayrı değerlendirilir.
90 saniyelik güncellik dolunca eski sonuç kayıtlı kalır; bu dağıtım veya yazma yetkisi değildir.
Yeni plan/aday oluşturulmayacak. Gerçek müşteri gMSA hazırlık önizlemesi ve operatör tarayıcı kabulü henüz bekleniyor.

Linux dev.44 kabulü geçerli; bu Windows Apply sonucu Linux/RADIUS için yeni anlık gözlem sayılmadı.
CanApplyGpo=false; gerçek SYSVOL staging/geri alma, GPO aktivasyonu ve endpoint kabulü halen açık.
Önceki ilk cf742 Apply gizli iç hata incelemesi ve hesap sadeleştirme açık kalır.
Genel **54/94 tamamlanan,40 açık**; kılavuz bayrakları false. Yeni tam veri yedeği alınmadı.

## DC01 önizleme worker Prepare başarılı — Apply bekleniyor — 29 Ekim 2026

Operatör **ToolVersion1.5.0 /Mode=Prepare /Stage=prepared** sonucunun tamamını paylaştı.
Kaynak **92b2af9b78347058802f4bb135b5fbb243abc813**, hedef sürüm **df28f70c-104e-4d6d-972c-e311d38adde6**.
Kaynaklar hazırlandı ve **SourceSignaturesValid=true /PackagePrepared=true**.
Mevcut hesap, eşleştirme ve kanal anahtarı korundu; **SignerSnapshotPreserved=true**.
**Error=null /ChangesMayBePartial=false /ServiceTransitioned=false**.
AD/GPO, key ACL ve trust store değişmedi; yeni servis veya kanal anahtarı oluşturulmadı.

Aday **C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46.candidate-df28f70c104e4d6d972ce311d38adde6**.
Kanıt **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-df28f70c104e4d6d972ce311d38adde6-c04e8ef41d274e5096e46a615002f0c8**.
Journal **C:\ProgramData\AuthWire-ConnectorUpgrade-4c23eebe071546d188eea2e96ad7ee46-df28f70c104e4d6d972ce311d38adde6\upgrade.json**.
Tam kullanıcı sonucu **docs/checkpoints/2026-10-29-customer-staging-preview-worker-prepare.json** içinde kayıtlı.

**Canlı kabul edilen Windows sürümü hâlâ cf74295c; Apply henüz çalıştırılmadı.**
Sıradaki adım aynı hash kontrollü araçla DC01 yönetici WinPS5.1 **Apply**; bu işlem Connector servisini
kontrollü durdurup yeni sürümle başlatır ve yeni sürümün altı kanal sağlığını kontrol eder.
Tam Apply sonucu alınmadan yükseltme başarılı sayılmaz. Sonra gerçek gMSA hazırlık önizlemesi ve panel kabulü beklenir.
CanApplyGpo=false; gerçek SYSVOL staging/geri alma, GPO aktivasyonu ve endpoint dağıtımı halen açık.
Linux dev.44 kabulü geçerli; bu Windows Prepare sonucundan Linux/RADIUS yeni sağlık durumu çıkarılmadı.
Genel **54/94 tamamlanan,40 açık** değişmedi; kılavuz bayrakları false. Yeni tam veri yedeği alınmadı.

```powershell
$ErrorActionPreference = 'Stop'
$awTool = Join-Path $env:TEMP 'AuthWire-Staging-Preview-Worker-Upgrade-20261028.ps1'
if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ne '2C8FBE776A240BC98BBB387C529A90AB4FBFC3FA2467096799D3A9E159EA33CF') {
    throw 'Dosya ozeti uyusmuyor'
}
& $awTool -Mode Apply
```

## Windows önizleme worker teslimatı test edildi — DC01 Prepare bekleniyor — 29 Ekim 2026

**PR117** merge **22b704f5e42dbb1ac0125ddb0d3ddd0a3c1f754c**; test edilen head **82bb633214d1fdaf3314af47679db2c91d474d96**.
Üç workflow başarılı: foundation **40746579732** (**1075 test,28 ortam atlaması**),
native Windows teslimat **40746579556** (**64 kontrol,28 kaynak**) ve bounded retry **40746579055**.
WinPS5.1 test ortamında gerçek önceki tam paket tanındı, yeni aday aynı test kanal anahtarıyla hazırlandı;
imza/native signer özellikleri korundu, bozuk/fazladan kaynak ve yanlış host reddedildi.
Testler müşteri DC01 Prepare/Apply veya gerçek AD/gMSA kabulü sayılmadı; testte servis/AD hesabı oluşturulmadı.

Hazır araç **ToolVersion1.5.0**; kaynak **92b2af9b78347058802f4bb135b5fbb243abc813**.
Beklenen mevcut Windows sürümü **cf74295c-ec97-4edf-a15a-877b155d1740**;
hedef **df28f70c-104e-4d6d-972c-e311d38adde6**.
Aktarım dosyası **/home/segmentiq/authwire-dc01-staging-preview-worker-upgrade-20261028.ps1**;
29 Ekim salt okunur SHA256 kontrolü **2c8fbe776a240bc98bbb387c529a90ab4fbfc3fa2467096799d3a9e159ea33cf** ile eşleşti.
Kabul edilen1.4.1 wrapper'ın host/account/pairing/anahtar/ACL/CLR-marker ve koruma yardımcıları değişmedi.
Yeni hesap veya anahtar gerekmiyor. Yeni Apply altı kanalın sağlığını ister.

**Müşteri Windows Prepare ve Apply henüz çalıştırılmadı.** Canlı kabul edilen durum Linux **dev.44**,
Windows **cf74295c**. Sıradaki operatör adımı **DC01'de yönetici Windows PowerShell5.1 ile yalnız Prepare**;
tam sonucu kaydettikten sonra ayrı Apply, ardından gerçek gMSA önizlemesi ve panel kabulü.
Prepare mevcut kalıcı servisi değiştirmeden imzalı aday paket hazırlar.
Gerçek SYSVOL staging/geri alma, GPO aktivasyonu ve endpoint dağıtımı bu araçla açılmaz.
Önceki ilk Apply'ın gizli iç hata kaydı incelemesi, hesap sadeleştirme, gerçek endpoint kabulü halen açık.
Genel **54/94 tamamlanan,40 açık**; kılavuz bayrakları false. Yeni tam veri yedeği veya kapatma yok.
Ayrıntı **docs/checkpoints/2026-10-28-dc01-staging-preview-worker-prepared.json**.

```powershell
$ErrorActionPreference = 'Stop'
$awTool = Join-Path $env:TEMP 'AuthWire-Staging-Preview-Worker-Upgrade-20261028.ps1'
scp segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-staging-preview-worker-upgrade-20261028.ps1 $awTool
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ne '2C8FBE776A240BC98BBB387C529A90AB4FBFC3FA2467096799D3A9E159EA33CF') { throw 'Dosya ozeti uyusmuyor' }
& $awTool -Mode Prepare
```

## Linux dev.44 kuruldu ve koruma kontrolleri geçti — Windows önizleme worker teslimatı sırada — 28 Ekim 2026

Operatör **STAGING_PREVIEW_JOBS_FINISHED /verified=true /version=0.14.0-dev.44** sonucunu paylaştı.
Kaynak bileşen **21003f27bdedd0cb61c3dcfc9fffaaaf943552c7**.
Kanıt **/var/lib/authwire-updates/staging-preview-jobs-dev44-20261028T182406Z-86efc09b**
(zaman damgası **21:24:06 Europe/Istanbul**). Önce/sonra panel okuma kontrollerinin tamamı HTTP200;
korunan dosya, broker, RADIUS, timer ve iş verisi kontrolleri true.
RADIUS yeniden başlatılmadı, PID **1243360**; broker PID **1069437** korundu.

Ek salt okunur host kontrolü kurulu **dev.44** sürümünü ve üç aktif servisi doğruladı.
Panel PID **2163240**, yeni backup worker **bf11bef7b45083a28781817e579eaab906d8bf3a581d80a84d98d1a7889f4662**;
restore checker **8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5** değişmedi.
**Backup worker güncellendi; yeni tam veri yedeği alınmadı.** Önceki yeni backup/kapatma iptali geçerlidir.

Linux preview görev kanalı eklendi. Yeni görev/adayı oluşturulmadı; pairing, sertifika,
Windows paketi/endpoint ve AD/GPO değişmedi. **Canlı Windows hâlâ cf74295c**;
yeni altıncı kanal ve gerçek müşteri gMSA önizlemesi henüz doğrulanmadı.
HTTP200 kontrolü operatör tarayıcı veya gerçek endpoint kabulü sayılmadı.
GPO apply=false; gerçek SYSVOL staging/rollback/aktivasyon yapılmadı.

Sıradaki adım aynı mevcut hesap/pairing/anahtarları koruyan Windows preview worker teslimatını
hazırlayıp doğrulamak; operatörden önce **Prepare**, sonucu kaydettikten sonra **Apply** kanıtı almak.
Ardından gerçek gMSA önizlemesi ve panel kabulü. Genel **54/94 tamamlanan,40 açık** değişmedi;
kılavuz bayrakları false. Ayrıntı: **docs/checkpoints/2026-10-28-customer-staging-preview-dev44-installed.json**.

## Linux dev.44 önizleme kanalı teslimatı hazır — sudo sonucu bekleniyor — 28 Ekim 2026

**PR116** merge **3bf268b296bce3fa31b578af1a299ae613477705**, test edilen head **efe6f74eff0449a561baf0c5ec4b7600be0a0761**.
Altı ilgili workflow başarılı; **1070 genel test (28 ortam atlaması)** ve sekiz yeni teslimat koruma testi geçti.
Ürün entegrasyonu PR115'in dokuz başarılı workflow/native Windows kanıtı önceki kayıtta korunur.

**Hedef sürüm 0.14.0-dev.44 kaynakta hazırdır; canlı Linux hâlâ dev.43, Windows cf74295c'dir.**
Sunucuda yönetici yetkisi kullanılmadan 183 aday dosya/182 kurulu baseline kontrol edildi;
korunan RADIUS kaynağı, fazladan kaynak ve yanlış sürüm girdileri reddedildi.
Eski/yeni backup worker ve değişmeyen restore-checker pinleri doğrulandı.
RADIUS PID **1243360**, broker PID **1069437** bu hazırlıkta korundu.
**Kurulum helper'ı root olarak çalıştırılmadı; panel/servis/veritabanı/AD/GPO/endpoint değişmedi.**

Hazır dosya **/home/segmentiq/authwire-staging-preview-jobs-20261028.py**.
SHA256 **2c76cf30db43e4b1fb4da9f4ba9b637d9c2f2ab61af0a342091218778cc3098c**.
Aday **/home/segmentiq/authwire-stage-dev44-staging-preview-92b2af9b7834**, manifest **65a5ef1c7a9f8dfc86b657f7abe610b4ed618bca4de0014750f55911aad29afb**.
Bileşen **21003f27bdedd0cb61c3dcfc9fffaaaf943552c7**; yalnız sekiz sabit version/runtime/UI/backup dosyası değişebilir.
Komut paneli kontrollü stop/start ile günceller ve backup worker'ı yeni readonly kuyruğa uyumlar.
RADIUS/broker PID, timer, korunan kaynak, iş verisi ve HTTPS kontrolleri vardır.
Yeni tam yedek, GPO uygulaması veya Windows paket değişikliği başlatmaz.

**Beklenen sonraki kullanıcı adımı — Linux terminalinde:**

```bash
sudo /opt/kaname-lab/venv/bin/python -I -B -c 'import hashlib,pathlib; p=pathlib.Path("/home/segmentiq/authwire-staging-preview-jobs-20261028.py"); b=p.read_bytes(); assert hashlib.sha256(b).hexdigest()=="2c76cf30db43e4b1fb4da9f4ba9b637d9c2f2ab61af0a342091218778cc3098c", "Dosya degismis"; exec(compile(b,str(p),"exec"))'
```

Çıktının tamamı alınmadan Linux kurulumu başarılı sayılmayacak.
Beklenen başarı olayı **STAGING_PREVIEW_JOBS_FINISHED /verified=true /version=0.14.0-dev.44**;
tam koruma kontrolleri ve kanıt dizini ayrıca değerlendirilir. Hata sonucu yeniden çalıştırılmış sayılmaz.
Sonra mevcut cf74295c'den Windows preview worker teslimatı hazırlanacak; yeni Linux kanalı
ve Windows altıncı kanal sağlığı sonrası gerçek DC01 gMSA önizlemesi/panel kabulü alınacak.
SYSVOL yazma/staging/rollback, GPO aktivasyonu ve gerçek endpoint kabulü halen açık.

Operatörün yeni backup/kapatma iptali geçerlidir. Son veri yedeği 10:28:35'tir ve sonraki değişiklikleri
içeriyor sayılmaz. Genel **54/94 tamamlanan,40 açık**; kılavuz bayrakları false kalır.
Ayrıntı: **docs/checkpoints/2026-10-28-staging-preview-jobs-dev44-prepared.json**.

## Paket hazırlığı önizlemesi Connector/panel kaynağına bağlandı — müşteri teslimatı bekliyor — 28 Ekim 2026

**PR115**: ayrı **combined.staging.preview.v1** görevi, sabit bounded AllSigned WinPS child,
panelde **Paket hazırlığını önizle → Hazırlık önizlemesini gönder** akışı eklendi.
Görev aynı birleşik içerik kabulüne, güncel dizin hedefine ve mevcut pairing nesline bağlıdır.
Mevcut iki yönetici yetkisi, oturum/Origin/CSRF, revizyon, idempotency/replay ve TLS/isim/iptal/pin kontrolleri korundu.

Sonuç **20 dosyanın** boyut/hash/ACL bağını, sabit göreli sürüm klasörünü, 90 saniyelik güncelliği ve
sahiplik/tam dosya ağacı/drift gerektiren geri alma sınırını gösterir. **SYSVOL yazıcısı, silme,
GPO aktivasyonu veya endpoint dağıtımı yoktur**; can_stage/can_apply_gpo/writer_available=false.
Yeni sonuç yoluna ayrı 32768 bayt zarf/16384 bayt payload sınırı verildi; eski yolların sınırları korunur.
Yeni kuyruğun yalnız doğrulanmış poll metadata'sı backup kararlılık karşılaştırmasından çıkarılır;
tam görev/sonuç yedekte ve business karşılaştırmasında korunur. Büyük kuyruk senaryosu test edildi.

Yeni paket dört sabit preview bağımlılığı içerir. Yeni Apply altıncı preview kanalını da doğrular;
eski sürüme rollback eski sağlık koşullarını kullanır. Tarihsel teslimat arşivleri değiştirilmedi.
Başlangıçtaki tarayıcı rol geçişi, fixture kaynak kopya listesi ve tarihsel-current kaynak eşitliği
hataları düzeltildi; hash/ACL/yetki veya sağlık kapıları gevşetilmedi.
Ek gerçek servis ret sonucu kontrolünün özet listesinde result araması da fixture'a özgüydü;
kontrol asıl ledger'dan yapılır, parent abort halinde fixture beklemesi cleanup'a geçer.

Doğrulama: test edilen head **92b2af9b78347058802f4bb135b5fbb243abc813**, merge **a6a1aeeb80a530474baaba06351c1467b0affb56**.
Dokuz ilgili workflow başarılı. **1062 genel test (28 ortam atlaması)**, **14 yeni Python testi**,
**40 native staging/gerçek geçici SMB kontrolü**, WinPS→Python canonical SHA ve
**49 scope/child-bound kontrolü** geçti. Düzeltilen gerçek imzalı SCM fixture'ında **85 kontrol**;
typed preview ret sonucunun HTTPS üzerinden kaydı, yeni kanal yokken yükseltme reddi ve
otomatik/explicit geri dönüş doğrulandı. Tarihsel arşivin tüm bağımsız/per-file hash pinleri korunur;
yalnız daha sonra değişmiş kaynakların eski arşivle güncel-kaynak eşitliği kıyası yapılmaz.

**Canlı müşteri ortamı değişmedi:** Linux **0.14.0-dev.43**, Windows **cf74295c-ec97-4edf-a15a-877b155d1740**.
Bu oturumda salt okunur Linux kontrolünde RADIUS PID **1243360**, broker PID **1069437** korundu;
kurulu backup worker **e0623c6998db9c8fa45df2f9e5ff6d514e451567d711fece5ef5417330ada8b6**.
Yeni kaynak testleri canlıya yükleme veya gerçek DC01 gMSA preview kabulü değildir.
Yeni backup/kapatma iptal kaldı; hiçbiri başlatılmadı.

Sıradaki kapı **kontrollü Linux + Windows teslimatı, gerçek gMSA önizlemesi ve panel kabulü**.
Sonrasında ayrı typed write approval, sahipli staging/journal/kısmi hata temizliği/rollback,
GPO link/startup/sürüm/çoğaltma ve gerçek pilot endpoint kabulü açık kalır.
İlk müşteri Apply iç exception görünürlüğü, tek hesap standardı ve dış backup/restore takibi sürer.
Genel **54/94 tamamlanan,40 açık**; **READY_FOR_FINAL_GUIDE=false, GUIDE_DELIVERED=false**.
Ayrıntı: **docs/checkpoints/2026-10-28-staging-preview-jobs-source.json**.

## Staging önizleme kaynağı tamamlandı ve test edildi — canlı entegrasyon bekliyor — 28 Ekim 2026

**PR114** merge **fdc26414245e3412d3f293733098bebcc50feeb2**, test edilen head
**1f32a94e56c59456662fa29d7065c95ba57cf638**. Dört ilgili workflow başarılı.
**1048 genel test /28 skipped**, yeni native WinPS5.1 staging önizlemesinde **40 kontrol**,
mevcut scope için **47**, gerçek imzalı kalıcı SCM yaşam döngüsünde **90 kontrol** geçti.
Bu hosted fixture'lar müşteri AD/gMSA veya gerçek staging kabulü değildir.

**CombinedStagingPreview.ps1** sabit **20 dosyanın** byte/hash/ACL listesini,
güncel scope hedefini/gözlem özetini ve boş SYSVOL tam envanterini tek 90 saniyelik önizlemeye bağlar.
Önerilen tek sürüm klasörü **Machine/AuthWire-<plan GUID N>-v<sürüm>-<manifest SHA256>**.
Kaynak/hedef yolu veya komut istekten alınmaz. Mevcut imza/içerik, service SID, GPO marker/link/sürüm/izin,
iki tam envanter ve iki kaynak ledger'ı yeniden doğrulanır. Geri alma yalnız yeni sahipli klasör için
journal/tam hash/ACL/drift şartı olarak tanımlandı; **gerçek yazma veya silme kodu yoktur**.
**read_only=true /can_stage=false /can_apply_gpo=false /writer_available=false** korunur.

İlk fixture StrictMode bildirimini writer sandı. Sonraki fixture varsayılan TEMP kökünün inherited ACE
işaretinin SMB'de farklı raporlanması nedeniyle durdu; teşhis yalnız kök ID işaretini farklı buldu.
Fixture gerçek managed-GPO ön koşulundaki korumalı DACL ile kuruldu; ham ACL karşılaştırması gevşetilmedi.
Gerçek geçici SMB paylaşımı, kaynağa müdahale/yol/boyut reddi ve hedef ağaca yazılmaması doğrulandı.
Bu fixture nedeni müşteri ilk Apply hatasının nedeni olarak yorumlanmadı.

**Canlı Linux dev.43 ve Windows cf74295c değişmedi.** Yeni source modülü mevcut worker/panele yüklenmedi.
Sıradaki iş **bounded AllSigned child + typed Connector/panel preview görevi ve müşteri teslimatı**;
ardından ayrı write approval, staging/rollback ve gerçek endpoint kabulü. Henüz SYSVOL'a paket yazılmadı.
Operatörün yeni backup/kapatma talebi iptal kaldı; yeni yedek/kapama çalıştırılmadı.
Güncel özet rapor **docs/STATUS_2026-10-28.md**, kaynak açıklaması **docs/COMBINED_STAGING_PREVIEW.md**,
kanıt **docs/checkpoints/2026-10-28-combined-staging-preview-source.json**.
Genel **54/94 tamamlanan,40 açık**, nihai kılavuz bayrakları false kalır.


## Güncel rapor yenilendi; yeni yedek/kapatma iptal edildi — 28 Ekim 2026

Operatör yeni yedek alma ve Linux'u kapatma niyetinden vazgeçti. **Yeni yedek veya kapatma komutu yürütülmedi.**
Güncel tamamlanan, yarım kalan ve saha testi bekleyen işler **docs/STATUS_2026-10-28.md** içinde toplandı.
Linux **dev.43**, Windows Connector **cf74295c**, gerçek birleşik AD/GPO–SYSVOL okuma kabulü **17:04:16**.
Yeni aşama: aynı birleşik aday için typed **SYSVOL staging önizlemesi ve geri alma sınırı**.
Henüz SYSVOL yazıcı/aktivasyon/endpoint dağıtımı yok. Mevcut yedek **10:28:35** tarihlidir;
sonraki değişiklikleri içeriyor veya dış disk yedeği var sayılmaz.
Genel **54 tamamlanan/40 açık**, kılavuz kapısı false kalır.


## Müşteri birleşik AD/GPO/SYSVOL okuma kontrolü başarılı — READ_FAILED bu kontrolde kapandı — 28 Ekim 2026

Operatör panel ekranını paylaştı: **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket**.
**“AD hedefleri ve GPO okuma kontrolü başarılı. Dağıtım henüz uygulanmadı.”**
Kontrol zamanı **28.10.2026 17:04:16 Europe/Istanbul** (**14:04:16Z** olarak yorumlandı).
Manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b**,
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5** beklenen birleşik adayla eşleşiyor.
İmza/içerik Connector tarafından doğrulanmış görünümü korunuyor.
Ekran SHA256 **fbb76a21487778cbba71381614b6ebf4bf5faeeefb2af657a285935d29f18078**.
Kanıt operatör ekranıdır; raw job-result/check list ayrıca alınmadı.

Önceki kabul edilen **cf74295c-ec97-4edf-a15a-877b155d1740** Windows Apply /native signer preservation
sonrası müşteri pozitif kapsam kontrolü artık doğrulandı. Önceki **READ_FAILED bu yeni kontrolde giderildi**.
Bu snapshot zamana bağlıdır; sonraki değişiklikten önce bağımlılık ve kapsam tazeliği yeniden değerlendirilmeli.
Üst satırdaki **GPO ve dağıtım kontrolü bekleniyor** ifadesi ürünün gerçek uygulamasının tamamlandığı anlamına gelmez.
**Henüz SYSVOL staging, GPO link/ayar uygulaması veya endpoint dağıtımı yapılmadı.**

Sonraki aşama aynı birleşik aday için kontrollü **SYSVOL staging /rollback** akışını hazırlamak ve incelemektir;
gerçek pilot endpoint sertifika/ağ kabulü ve ürünün bütünü açık kalır.
Linux **0.14.0-dev.43**, Windows **cf74295c**, mevcut yedek korunur; yeni tam yedek başlatılmadı.
İlk Apply'ın örtülen iç exception'ı ve kanal hata görünürlüğü takip işi açık kalır; başarılı retry bunu açıklamaz.
Bu alt adımın kapanışı genel matrix sayımını otomatik değiştirmez: **54/94 tamamlanan,40 açık**.
**READY_FOR_FINAL_GUIDE=false /GUIDE_DELIVERED=false**; nihai kılavuz/ürün tamamlandı bildirimi yapılmadı.
Ayrıntı: `docs/checkpoints/2026-10-28-combined-scope-customer-panel-accepted.json`.


## SYSVOL UNC düzeltmesi DC01'e başarıyla uygulandı — pozitif AD/GPO kapsam tekrarı bekliyor — 28 Ekim 2026

Operatörün kontrollü ikinci **Apply** çıktısı kabul edildi: **ToolVersion 1.4.1**, kaynak
**a5030a3a8f6c47e5009800a65b7209a348adb2f7**, yeni aktif Windows release
**cf74295c-ec97-4edf-a15a-877b155d1740** (önceki **e6d734b1-59c8-48e5-8a6e-c40b43be3114**).
**Stage=applied /Phase=applied /Error=null /ChangesMayBePartial=false /ServiceTransitioned=true**.
Kaynak imzaları geçerli; değişmeyen updater'ın beş kanalı aynı taze health kaydında zorunlu tutan
kontrolü geçilerek applied'a ulaşıldı. Ayrı bir post-Apply sağlık örneği henüz paylaşılmadı.

**SignerSnapshotPreserved=true**: native before/after karşılaştırması tamamlandı; önceki başarısız
denemede bekleyen signer son karşılaştırması kapandı. Hesap, eşleştirme ve channel key korundu.
AD/GPO, key ACL ve trust store değişmedi; yeni hesap/servis/channel key oluşturulmadı; sırlar dışa aktarılmadı.
Evidence: `C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-cf74295cec974edfa15a877b155d1740-d5ff82bd4a2541018674854efa61a308`.
Önceki sürüm archive: `C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46.previous-e6d734b159c848e58a6ec40b43be3114`.
Linux **0.14.0-dev.43** kalır; bu işlemde yeni tam yedek alınmadı, backup timer değişmedi.

**Sıradaki operatör adımı:** panelde **İmzalı dağıtım adayları** içindeki
**AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırında
**AD/GPO kontrolünü önizle → AD/GPO kontrolünü gönder**, ardından **Yenile**.
Bu yeni görev salt okunur AD/GPO ve SYSVOL kontrolüdür, dağıtım/endpoint uygulaması değildir.
Beklenen pozitif metin **AD hedefleri ve GPO okuma kontrolü başarılı. Dağıtım henüz uygulanmadı.**
ve yeni kontrol zamanı. Görev henüz gönderilmedi; **READ_FAILED giderildi kabulü pozitif müşteri
kapsam sonucu gelmeden yapılmayacak**.

İlk başarısız Apply'ın kesin iç exception'ı hâlâ bilinmiyor; partial kanal bayrakları daha sonra toparlandı.
Takip işi: original upgrade exception ve sınırlı kanal hata kodlarının korunması; hiçbir gate gevşetilmedi.
Genel durum **54/94 tamamlanan,40 açık**; nihai kılavuz bayrakları false kalır.


## Eski Windows sürümünde beş kanal tekrar doğrulandı — kontrollü Apply tekrarı bekliyor — 28 Ekim 2026

Operatörün üç örneği **e6d734b1-59c8-48e5-8a6e-c40b43be3114** üzerinde Healthy=true,
ConsecutiveFailures=0 ve **probe/candidate/scope/combined/combined-scope=true** gösteriyor.
**İki benzersiz CheckedUtc** var: **13:56:25.3813701Z**, **13:57:03.4885640Z**;
üçüncü örnek ikinci kaydın tekrarıdır, üçüncü bağımsız başarı sayılmaz.
Önceki kanal hataları bu iki taze örnekte sürmüyor. Kesintili hata ile uyumludur;
ilk transport/validation istisnası hâlâ bilinmiyor.

Updater kodu **rolled_back** journal'dan aynı Prepare edilmiş candidate ile Apply tekrarını destekliyor:
eski/yeni release, hesap, imza, package/tree hash, kanal anahtarı ve servis marker kontrolleri yeniden yapılır.
Yeni sürümün **beş kanalının aynı taze sağlık kaydında doğrulanması**, mevcut timeout ve otomatik
rollback koşulları korunacak. Kontrolleri gevşetmeden **aynı hash-pinned helper ile bir kontrollü Apply tekrarı** önerildi.
Hedef **cf74295c-ec97-4edf-a15a-877b155d1740**, helper SHA256
**7f84588eeda9301d541a25d3e89bc2aeacc7e0e2ffa1fc36a5e57e563bc56498**.
**Tekrar henüz yürütülmedi.** İkinci hata olursa kör tekrar yapılmayacak; hata ayrıntısı görünürlüğü geliştirilecek.
Pozitif müşteri SYSVOL kapsam görevi ve signer son karşılaştırması bekliyor.
Linux dev.43 kalır; bu okumada ayar değişmedi/yeni tam yedek alınmadı.
Genel durum **54 tamamlanan/40 açık**, kılavuz hazır/teslim false.


## Linux beş görev kuyruğu salt okunur doğrulandı — 28 Ekim 2026

Operatör pinned diagnostic çıktısı **checked_utc_epoch=1793195507**:
beş queue **schema_valid=true**, tümü 100000-character sınırının altında (1798–2734 karakter).
Probe 2 tamamlanan, diğer dört queue 1'er tamamlanan iş içeriyor; hiçbirinde queued/leased iş yok.
Her queue'da 2 replay poll kaydı; last_poll yaşları **31/29/28/28/28 saniye**.
Bu sonuç mevcut queue şeması bozukluğunu ve boyut aşımını elemektedir;
sunucunun yakın zamanda beş kanalda sorgu kabul ettiğini gösterir.
İstemcinin HTTP yanıtını aldığı veya tüm alanları kabul ettiği bundan çıkarılamaz.
Runtime hataları yuttuğundan gerçek istisna hâlâ gözlenmedi; ilk upgrade hatası catch'te örtülmüştü.

Tanı **database_writes=false**, jobs_created/poll_requests_sent/services_changed/key_material_read/
secret_values_exported false. Üretim ayarı değiştirilmedi.
Sıradaki adım canlı eski Windows sürümünün sağlık kaydını 20 saniye arayla 3 defa salt okunur izlemek;
aynı kaydın tekrarını CheckedUtc ile ayırmak ve hatanın geçici mi kalıcı mı olduğunu belirlemek.
Upgrade gate gevşetilmedi; Apply tekrarlanmadı. READ_FAILED ve signer postcomparison kapanmadı.
Genel durum **54/94 tamamlanan,40 açık**; kılavuz bayrakları false; yeni tam yedek yok.


## Eski sürüm sağlığı doğrulandı; yeni paket beş kanal eşiğini geçememiş — 28 Ekim 2026

Operatör doğru paket yollarından kayıtları paylaştı. Canlı **e6d734b1-59c8-48e5-8a6e-c40b43be3114**,
worker **9804**, beklenen gMSA SID ile **Healthy=true /ConsecutiveFailures=0**,
CheckedUtc **2026-10-28T13:42:16.3559014Z**. Probe/candidate/scope/combined false, combined-scope true.
Candidate **cf74295c-ec97-4edf-a15a-877b155d1740** tarihsel sağlık kaydı
**2026-10-28T13:34:03.0678245Z**, worker **6416**, doğru SID ile Healthy=true/0 failure;
probe/candidate/combined false, scope/combined-scope true.
service.json yalnız konfigürasyon olduğundan seçilen sağlık alanlarının null olması beklenir.

Runtime bayrakları her döngüde sıfırlayıp ilgili poll/reply doğrulamasıyla doldurur;
Healthy yalnız temel health exchange'i ölçer. Updater yeni sürüm için beş kanalın tümünü aynı
taze sağlık kaydında zorunlu tutar; paylaşılan candidate kaydı bu koşulu sağlamıyor.
İlk iç hata mevcut catch tarafından geri dönüş mesajıyla örtüldüğünden kesin ilk throw görülmedi.
Kanal false durumları eski sürümde de var; **SYSVOL fix'in bunları yarattığı iddia edilmez**.
Kök neden (queue schema/transport/reply) henüz belirlenmedi. Kontroller gevşetilmeyecek; Apply tekrarlanmadı.

Linux journal yararlı çıktı vermedi; HTTP log_message kapalı. Unprivileged DB okuması erişim reddi aldı,
yetki aşılmadı. Beş queue'nun mevcut _read validatörlerini **mode=ro /query_only /SELECT** ile çağıran
sabit salt okunur helper hazırlandı; beş empty ve beş invalid-schema fixture kontrolü geçti.
Helper **/home/segmentiq/authwire-connector-queues-readonly-20261028.py**,
SHA256 **62dc12667fb94a53358cc49dd0ce268547fb93989737d5541d7fe6ba301b585b**.
Üretimde henüz çalıştırılmadı; operatör pinned sudo komutuyla yalnız kuyruk sayısı/şema/hata kodunu paylaşacak.
Anahtarlar, sırlar, payload/job kimlikleri yazdırılmaz; servis/DB/business state değiştirilmez.
Signer's son karşılaştırması ve müşteri pozitif kapsam kontrolü bekliyor. Genel takip **54 tamamlanan/40 açık**.


## UNC düzeltmesi geri dönüş kontrolü — servis çalışıyor, sağlık yolu kontrolü düzeltilecek — 28 Ekim 2026

Operatör çıktısı: **AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46 Running**,
hesap **VIZYONVERI\\aw-deploy$**, PID **556**. Journal **Phase=rolled_back**,
old release **e6d734b1-59c8-48e5-8a6e-c40b43be3114**, new release **cf74295c-ec97-4edf-a15a-877b155d1740**.
Önceki asistan tanı komutunda paket klasörü yanlışlıkla **AuthWireConnector-…** yazıldı;
doğru klasör **AuthWire-Connector-…**. Bu nedenle iki **STATUS_FILE_ABSENT** çıktısı
gerçek sağlık dosyalarının bulunmadığına kanıt değildir. Servis SCM durumu ve journal çıktısı geçerlidir.
Yeni adım doğru literal paket yollarında salt okunur service.json/status.json kontrolüdür.
Canlı sürümün güncel sağlık kaydı ve başarısız candidate kanalları henüz görülmedi;
Apply tekrar edilmedi, READ_FAILED çözülmüş kabul edilmedi. Signer son karşılaştırması da bekliyor.
Linux dev.43 kalır; bu kontrolde ayar değişmedi ve yeni tam yedek alınmadı. Genel takip 54 tamamlanan/40 açık.


## DC01 SYSVOL UNC Apply başarısız — otomatik geri dönüş bildirildi, inceleme bekliyor — 28 Ekim 2026

Operatör **ToolVersion 1.4.1 / Mode Apply** çıktısını paylaştı:
**Stage=package_apply_requires_review**, **Upgrade=null**, **ChangesMayBePartial=true**.
Hata: **CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED**.
Hedef release **cf74295c-ec97-4edf-a15a-877b155d1740** canlıya kabul edilmedi.
Araç önceki **e6d734b1-59c8-48e5-8a6e-c40b43be3114** sürümün geri yüklendiğini bildiriyor;
güncel servis/sağlık durumu operatörün salt okunur çıktısıyla ayrıca doğrulanacak.
**SignerSnapshotPreserved=false**: wrapper iç updater hatası üzerine son signer karşılaştırmasına
ulaşamadan catch'e girdiğinden bu alan varsayılan false kalır; tek başına anahtar değişikliği kanıtı değildir.
**ExistingSigningKeyAclChanged=false**, AD/GPO/trust değişmedi, sırlar dışa aktarılmadı.
Evidence: `C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-cf74295cec974edfa15a877b155d1740-4756876a2d9844a3a7326c229df405f5`.
Sıradaki işlem journal phase, canlı ve candidate state/status.json dosyaları ve sınırlı SCM olaylarının salt okunur kontrolü.
Apply tekrar edilmeyecek; yeni panel kapsam görevi henüz başlatılmayacak.
**READ_FAILED çözülmüş kabul edilmedi**; Linux **dev.43**, genel durum **54 tamamlanan/40 açık**.
Yeni tam yedek alınmadı; kılavuz hazır/teslim bayrakları false kalır.


## SYSVOL UNC düzeltmesi: DC01 Prepare başarılı, Apply bekliyor — 28 Ekim 2026

Operatörün paylaştığı **ToolVersion 1.4.1 / Mode Prepare** çıktısı kabul edildi.
Kaynak **a5030a3a8f6c47e5009800a65b7209a348adb2f7**, yeni release **cf74295c-ec97-4edf-a15a-877b155d1740**.
**Stage=prepared**, **SourceSignaturesValid=true**, **PackagePrepared=true**, **Error=null**.
**ServiceTransitioned=false**: çalışan sürüm hâlâ **e6d734b1-59c8-48e5-8a6e-c40b43be3114**.
Mevcut hesap, eşleştirme, channel key ve signer snapshot korundu; AD/GPO, trust ve key ACL değişmedi.
Evidence: `C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-cf74295cec974edfa15a877b155d1740-6a4e5a860cdf483693433e0ae66e96a9`.
Sonraki adım aynı hash-pinned helper ile kontrollü **Apply**, ardından yeni salt okunur birleşik AD/GPO kapsam görevi.
Müşteri ortamındaki **READ_FAILED henüz çözülmüş kabul edilmedi**. Linux **dev.43** kalır.
Bu adımda yeni tam yedek alınmadı. Genel takip **54/94 tamamlanan,40 açık**; nihai kılavuz hazır/teslim edildi işaretlenmedi.
Ayrıntı: `docs/checkpoints/2026-10-28-sysvol-unc-fix-customer-prepare.json`.


## SYSVOL UNC okuyucu düzeltmesi test edildi — Windows hazırlığı bekliyor — 28 Ekim 2026

**PR113** merge **836d0a6b5601114ea6ed949f02bf54aba6082732**, test head **043c83391965d476cb65e54ccb2da5a60541aecc**,
kaynak bileşeni **a5030a3a8f6c47e5009800a65b7209a348adb2f7**.
Tetiklenen dört workflow başarılı: **1048 Python testi /28 skipped**, native Windows connector,
imzalı birleşik paket ve bounded retry kontrolleri.
Native scope fixture'ında47 kontrol, gerçek geçici **SMB/UNC paylaşımı** üzerinde pozitif okuma
ve mevcut yerel aday guard'ının aynı dosyayı **DEPLOYMENT_PATH_REJECTED** ile reddetmesi dahil geçti.
Altı yerel delivery/archive testi ve gerçek imzalı kalıcı SCM yaşam döngüsü/rollback için90 kontrol başarılı.
Hosted test müşteri AD/gMSA pozitif kapsam kabulü değildir.

Önceki full-tree fixture yalnız yerel temp dizinini kullandığından UNC uyumsuzluğunu kaçırmıştı.
**Read-AuthWireCombinedSysvolFile** yalnız **gpo.cmt /gpt.ini** dosyalarını, doğrulanmış domain/PDC/GPO root'undan
salt okunur stream ile ve4096-byte sınırıyla okur. Reparse/device yolları, boş/oversized/değişen
dosyalar reddedilir; stream kapatılır. Yerel aday okuyucusunun UNC yasağı gevşetilmedi.
Linux/API/RADIUS, AD/GPO, trust, key/credential veya dağıtım yetkisi değişmedi.
Müşteride ham exception görülmediği için başka bir okuma sorununun da bulunmadığı iddia edilmez;
gerçek pozitif kapsam sonucu düzeltme uygulamasından sonra tekrar sınanacak.

**Windows-only teslimat sunucuya aktarıldı ve hash'i salt okunur doğrulandı; henüz uygulanmadı.**
Helper **/home/segmentiq/authwire-dc01-sysvol-unc-fix-20261028.ps1**,
SHA256 **7f84588eeda9301d541a25d3e89bc2aeacc7e0e2ffa1fc36a5e57e563bc56498**,135205 byte,24 source.
Archive **96e6b14015e7cb94b3adb4ff5becd70748eb001fb0fab1a86e343fce1474728c**.
Beklenen current **e6d734b1-59c8-48e5-8a6e-c40b43be3114**, yeni release **cf74295c-ec97-4edf-a15a-877b155d1740**,
ToolVersion **1.4.1**. Mevcut hesap/eşleştirme/channel key/signer ve eski paket korunur.
**Linux dev.43'te kalır; yeni Linux kurulumu gerekmiyor.**

Devam: DC01 yönetici64-bit PowerShell'de hash doğrulamalı **Prepare** → çıktı kabulünden sonra **Apply** →
birleşik satırda tek yeni AD/GPO kontrol görevi → Yenile ve gerçek sonuç.
Komut **docs/checkpoints/2026-10-28-sysvol-unc-fix-handoff.md** içinde kayıtlı.
Eski READ_FAILED kaydı bir başarıya çevrilmedi veya silinmedi; hiçbir görev yeniden kuyruğa konmadı.
Canlı Windows hâlâ e6d734b1; müşteri kapsam kabulü açık. Yeni tam yedek alınmadı.
Genel **54/94 tamam,40 açık** ve nihai kılavuz kapısı değişmedi.
Kaynak, hata kanıtı, testler, teslimat ve sonraki işlem kaydedildi.


## Birleşik kapsam canlı kontrolü READ_FAILED — inceleme/düzeltme açık — 28 Ekim 2026

Operatör **image(20261028-125714).png** ekranında birleşik paketin content doğrulaması başarılı,
ancak **“AD/GPO kontrolü tamamlanamadı: READ_FAILED”** sonucunu paylaştı.
Manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b** ve
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5** aynı kaldı.
Görüntü SHA256 **3eb23134c2dbcedcf71e3461c55ee9f11c822c0e7318fcae7e8677bc2b6b4497**.
Bu sonuç başarılı kapsam kabulü değildir; GPO/endpoint dağıtımı yapılmadı.

Kaynak incelemesinde somut uyumsuzluk bulundu:
**CombinedDeploymentScope.ps1 /Read-AuthWireCombinedSysvolTree**, UNC SYSVOL dosyalarında
**Read-AuthWireCandidateBytes** çağırıyor. Bu yerel aday okuyucusunun
**Assert-AuthWireCandidatePath** koruması UNC yollarını açıkça **DEPLOYMENT_PATH_REJECTED** ile reddediyor.
Child exception'ı dışarı vermediği için panel READ_FAILED gösteriyor.
Bu uyumsuzluğun kaynakta varlığı doğrulandı; müşterideki ham exception görülmediğinden
başka bir okuma sorununun da bulunmadığı iddia edilmiyor.

Yerel aday yolu koruması korunacak; yalnız doğrulanmış SYSVOL root'unda iki sabit dosyayı,
reparse/boyut/okuma bütçesi ve salt okunur stream ile okuyacak ayrı helper eklenecek.
Regresyon gerçek geçici Windows SMB/UNC paylaşımıyla test edilecek;
yerel aday okuyucusunun UNC reddi de ayrıca korunacak.
Henüz kaynak/servis/policy/AD/GPO/endpoint canlı değişikliği veya yeni görev/yedek yok.
Yeni Apply veya aynı görev tekrar çalıştırılmadı.
Son canlı Linux dev.43 /Windows e6d734b1; birleşik içerik kabulü korunuyor.
**54/94 tamam,40 açık**; kapsam, staging/rollback ve gerçek endpoint kabulü açık.


## 🔴✓ Windows birleşik kapsam worker Apply kabul edildi — gerçek kapsam görevi sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /ToolVersion1.4.0 /Mode Apply /Stage applied**,
**Error=null /ChangesMayBePartial=false** sonucunu paylaştı. **ServiceTransitioned=true**.
Kalıcı Windows Connector **689649c0-61df-40aa-bbfb-b84fa1cc2ac0 → e6d734b1-59c8-48e5-8a6e-c40b43be3114**
geçişi kabul edildi; source bileşeni **c67adc15b731dbb7876cef1ed848ee1ce483b8bb**.
SourceSignaturesValid=true; mevcut hesap, eşleştirme, channel key, önceki kaynaklar ve signer snapshot korundu.
AD/GPO, key ACL ve trust store değişmedi; yeni anahtar veya servis oluşturulmadı.
**CanApplyGpo=false**; bu Connector güncellemesi GPO/endpoint dağıtımı değildir.

Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-e6d734b159c848e58a6ec40b43be3114-1ac6276ee60744ef865f2d3989508a6c**.
Tam normalize edilmiş operatör sonucu **docs/checkpoints/2026-10-28-customer-combined-scope-worker-applied.json**.
Kabul operatör çıktısına dayanır; asistanın bağımsız DC01/servis/DB okuması değildir.
İncelenen source'da applied öncesinde yeni release/runtime kimliği ve taze HTTPS health ile
Probe/Candidate/Scope/Combined/**CombinedScopeChannelVerified** kapıları zorunludur.
Bu gate'in geçmesi gerçek birleşik AD/GPO/SYSVOL görevi veya pozitif kapsam sonucu sayılmaz.
Önceki paket ArchivePath'i kaydedildi; müşteride rollback provası yapıldığı iddia edilmez.

**Son kabul:** Linux **dev.43**, Windows **e6d734b1**; birleşik content pozitif/browser kabulü korunuyor.
**Sıradaki operatör adımı:** paneli Ctrl+F5 ile yenile → İmzalı dağıtım adaylarında
**AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırı →
**AD/GPO kontrolünü önizle → AD/GPO kontrolünü gönder** → yaklaşık30–60 saniye sonra **Yenile**.
Doğrulamayı önizle içerik işini tekrar çalıştırır; bu aşamada AD/GPO kontrolü seçilir.
Beklenen mesaj: **“AD hedefleri ve GPO okuma kontrolü başarılı. Dağıtım henüz uygulanmadı.”**
Bu yeni birleşik görev kabul edilen content hash'ine ve tam hedef setine bağlıdır; SYSVOL dosya ağacını da okur.
Ağ profilleri satırının önceki sonucu birleşik kapsam kabulü değildir.
queued/leased durumunda yeni görev oluşturulmadan Yenile ile aynı sonuç izlenir.
Kapsam tazeliği90 saniyedir; stale mesajı dağıtım hatası veya GPO değişikliği sayılmaz.

Henüz birleşik kapsam görevinin gönderildiği veya pozitif sonuç alındığı bildirilmedi.
Kontrollü staging/rollback ve gerçek pilot endpoint kabulü açık; **54/94 tamam,40 açık**.
Nihai kılavuz kapısı değişmedi. Yeni tam yedek alınmadı; sonuç ve devam noktası kaydedildi.


## 🔴✓ Windows birleşik kapsam worker Prepare kabul edildi — Apply sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /ToolVersion1.4.0 /Mode Prepare /Stage prepared**
sonucunu paylaştı. **SourceSignaturesValid=true /Error=null /ChangesMayBePartial=false**.
Mevcut sürüm **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**, hazırlanan yeni aday
**e6d734b1-59c8-48e5-8a6e-c40b43be3114**, source bileşeni **c67adc15b731dbb7876cef1ed848ee1ce483b8bb**.
**PackagePrepared=true; ServiceTransitioned=false**.
Mevcut hesap, eşleştirme, channel key, eski kaynaklar ve signer snapshot korunmuş.
AD/GPO, signer key ACL ve trust store değişmemiş; yeni anahtar veya servis oluşturulmamış.
**CanApplyGpo=false**; hazırlık canlı GPO/cihaz dağıtımı değildir.

Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-e6d734b159c848e58a6ec40b43be3114-ab20f0a5e5a64fe5bcabc0c86552745c**.
Tam operatör sonucu: **docs/checkpoints/2026-10-28-customer-combined-scope-worker-prepared.json**.
Kabul operatör çıktısına dayanır; asistanın bağımsız Windows/servis okuması değildir.
ArchivePath planlanan önceki-paket konumudur; bu çıktı arşiv oluşturma veya müşteride rollback provası sayılmaz.

**Son canlı kabul:** Linux **dev.43**; Windows hâlâ **689649c0** (Prepare servis geçişi yapmadı).
**Sıradaki işlem:** aynı hash doğrulanmış launcher ile **-Mode Apply**.
Bu işlem Windows Connector'ı kontrollü stop/start ile yeni kapsam worker'ına geçirir;
mevcut kimlik/eşleştirme/anahtar/signer korunur, eski paket geri alma için saklanır.
Başarı yeni release/runtime kimliği, taze HTTPS health ve **CombinedScopeChannelVerified** dahil beş kanal gerektirir.
Linux RADIUS veya GPO/endpoint ayarı değiştirilmez.
Apply sonucu kabulünden sonra birleşik paket satırında AD/GPO kontrolünü önizle/gönder/Yenile ile gerçek kapsam işi yürütülecek.

Henüz Apply veya müşteri pozitif birleşik kapsam sonucu yok; staging/rollback ve gerçek endpoint kabulü açık.
**54/94 tamam,40 açık**; nihai kılavuz kapısı değişmedi. Yeni tam yedek alınmadı.
Her tamamlanan işlemden sonra sonuç, kanıt ve sonraki adım kaydedildi.


## 🔴✓ Dev.43 canlı Linux kurulumu kabul edildi — Windows kapsam worker Prepare sırada — 28 Ekim 2026

Operatör **COMBINED_SCOPE_JOBS_FINISHED /verified=true**, sürüm **0.14.0-dev.43**,
release **c67adc15b731dbb7876cef1ed848ee1ce483b8bb** sonucunu paylaştı.
Korunan dosyalar, broker/RADIUS süreçleri, timer ve iş durumu kontrolleri geçti.
Önce/sonra bütün authenticated loopback okumaları200; birleşik kapsam görev kanalı eklendi,
ancak yeni kapsam görevi veya aday kaydı oluşturulmadı.
RADIUS **1243360** ve broker **1069437** korundu; RADIUS yeniden başlatılmadı.
Kanıt: **/var/lib/authwire-updates/combined-scope-jobs-dev43-20261028T124458Z-78543b4b**.

Asistan ayrıca salt okunur source sürümünü dev.43, panel active/PID **2058459**,
RADIUS/broker active ve aynı PID'leri, backup timer active durumunu doğruladı.
Kurulu/source backup worker SHA **e0623c6998db9c8fa45df2f9e5ff6d514e451567d711fece5ef5417330ada8b6**;
release.json eşleşiyor, restore checker **8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5** değişmedi.
DB okunmadı; HTTPS/session200 ve iş durumu korunumu operatörün sudo installer kanıtına dayanır.
**backup_workers_changed=true** beşinci sıranın poll uyumluluğu için beklenen güncellemedir;
tam yedek alınmadı ve backup timer korundu.

Politika, sertifika, plan, eşleştirme, AD/GPO, Windows paket/endpoint ve native modül değişmedi.
**combined_scope_worker_delivery_pending=true /gpo_apply_enabled=false** beklenen ara durumdur.
Windows son kabul edilen release hâlâ **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**;
birleşik pozitif content/browser kabulü korunuyor, yeni canlı kapsam kabulü henüz yok.

**Sıradaki operatör işlemi:** DC01'de yönetici64-bit Windows PowerShell ile
**authwire-dc01-combined-scope-worker-upgrade-20261028.ps1 -Mode Prepare**.
Dosya Linux home'da hazır; SHA **44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2**.
Asistan uzak dosya hash'ini ve wrapper'ın **689649c0** current-release pinini tekrar doğruladı.
Yeni aday release **e6d734b1-59c8-48e5-8a6e-c40b43be3114**,24 incelenmiş source.
Prepare mevcut servis/PID'yi değiştirmeden paket ve journal hazırlar; çıktı kabulünden sonra Apply yapılacak.
Henüz Windows Prepare/Apply veya birleşik kapsam işi yürütülmedi.
Ardından panelde birleşik satırın AD/GPO kontrolünü önizle/gönder/Yenile akışıyla gerçek kapsam sonucu alınacak.
Staging/rollback, gerçek endpoint ve bütün ürün kabulü açık; **54/94 tamam,40 açık**.
Nihai kılavuz kapısı değişmedi; sonuç ve sonraki işlem kaydedildi.


## Birleşik AD/GPO/SYSVOL kapsam kontrolü hazır — dev.43 ve Windows kurulumu bekliyor — 28 Ekim 2026

**PR112** merge **94c888bfa979e1c773bf0aee356692db69ed584e**, test head **b4eed841150059170658a9b004594b4638c66e9c**,
kaynak bileşeni **c67adc15b731dbb7876cef1ed848ee1ce483b8bb**.
Dokuz workflow başarılı: **1045 Python testi /28 skipped**, tarayıcı, gerçek RADIUS,
native birleşik paket, Linux kaynak hazırlama, yedek ve Windows kontrolleri.
Native scope hedef/hash/gerçek geçici dosya ağacında41 kontrol; imzalı kalıcı SCM fixture'ında90 kontrol geçti.
SCM fixture'ı typed birleşik scope görevinde gerçek imzalı negatif sonucu ve yeni kanal kesildiğinde
upgrade reddi/rollback davranışını sınadı. Hosted fixture müşteri AD/gMSA pozitif kabulü değildir.
Yerel49 RSA/SQLite/HTTPS/yedek,14 delivery/rollback ve üç exact Windows archive kontrolü geçti.
Bu sayılar ürünün bütünü veya müşteri kapsam testi tamamlanmış anlamına gelmez.

**Yeni davranış:** ayrı **combined.scope.verify.v1** capability/purpose/route ve
**windows_combined_scope_jobs** sırası. Hedef, birleşik adayın19 alanına; son kabul edilen birleşik
içerik kanıtının hash'ine; tüm güncel AD hedef SID setine; profile/network/draft/manifest pinlerine bağlı.
İçerik kanıtı veya bağımlılık değişirse eski lease/snapshot geçersiz olur. Sonuç yalnız90 saniye taze
okuma snapshot'ıdır. Eski ağ-only scope ve birleşik content kanalları kendi görevlerini korur.
Başarılı sonuç **connector_verified/can_apply** açmaz.

İmzalı, süre/çıktı bütçeli AllSigned child; birleşik ve ağ içeriğini okuma öncesi/sonrası yeniden doğrular.
AD nested/primary üyelikleri, etkin bilgisayarlar, managed GPO kimliği/marker/owner/izinler,
bağsız/ayarsız/zero-version durumunu ve SYSVOL root ACL'ini kontrol eder.
SYSVOL'de dört kök öğe, boş Machine/User dizinleri, dosya byte hash/ACL'leri,
GPT.INI tek Version=0 ve iki kararlı okuma zorunludur; gizli deployment dosyası/reparse/drift reddedilir.
Deployment artifact çalıştırılmaz; AD/GPO/endpoint ayarı yazılmaz.
Mevcut25 server fonksiyon gövdesi pinli; üç incelenmiş dispatch gövdesi genişletildi.

**Linux dev.43 teslimatı hazırlanıp sunucuda salt okunur doğrulandı; henüz uygulanmadı.**
Helper **/home/segmentiq/authwire-combined-scope-jobs-20261028.py**
SHA256 **19a33302b0b80dbf186a75e4e09aae91195ae82ce905e59dd2341d8c277d36d2**.
Stage **/home/segmentiq/authwire-stage-dev43-c67adc15b731**,182 dosya;
manifest **61a0310f43d5aea90e79554c39950c792b5bf8bd4e59f55a832c13e105995338**.
Yalnız yedi source dosyası (yeni combined_scope_jobs.py dahil), kurulu backup worker ve release hash pair'i güncellenir.
Yeni worker **e0623c6998db9c8fa45df2f9e5ff6d514e451567d711fece5ef5417330ada8b6**, restore checker değişmez.
Beşinci sıranın yalnız doğrulanmış poll metadata'sı kararlılık karşılaştırmasına eklenir;
tüm DB/poll/replay verisi ve durable işler/sonuçlar gerçek yedekte korunur.
Panel restart planlı; RADIUS/broker ve timer korunur. Idle/exclusive lock, source/worker exact rollback,
üçüncü taraf drift ve eşzamanlı iş değişikliğinde otomatik geri alma yapmama testleri geçti.

**Windows teslimatı hazır; henüz Windows'ta Prepare/Apply çalıştırılmadı.**
Helper **/home/segmentiq/authwire-dc01-combined-scope-worker-upgrade-20261028.ps1**
SHA256 **44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2**;24 incelenmiş source,
archive **f348716cddef27503c1d8b1e698963d1612193ee9a74bd7df06e58588cae0ddd**.
Yeni release **e6d734b1-59c8-48e5-8a6e-c40b43be3114**, beklenen current **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**.
Mevcut gMSA, eşleştirme, channel key, signer ve eski paket korunur.
Yeni release ancak taze **CombinedScopeChannelVerified** dahil beş kanal sağlıklıysa kabul edilir;
başarısız geçişte eski sürüme geri dönülür.
İlk dosya aktarım timeout'u parça aktarımıyla giderildi; byte hash ve tek kaynak manifesti tekrar doğrulandı.

**Canlı son kabul değişmedi:** Linux **dev.42**, Windows **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**;
birleşik content pozitif/browser kabulü tamam. Müşteride yeni scope okuması yapılmadı.
Devam: Linux pinned sudo helper → Windows Prepare → Apply → birleşik satırda
**AD/GPO kontrolünü önizle/gönder/Yenile** → gerçek kapsam sonucu.
Ardından kontrollü staging/rollback ve gerçek pilot endpoint kabulü açık.
Yeni tam yedek alınmadı; mevcut28 Ekim10:28 doğrulanmış yedek son kabul edilen arşivdir.
**54/94 tamam,40 açık; READY_FOR_FINAL_GUIDE=false, GUIDE_DELIVERED=false** korunur.
Tamamlanan kaynak/test/teslimat ve sonraki işlem kalıcı kayda işlendi.


## 🔴✓ Birleşik paket kalıcı Connector içerik doğrulaması panelde kabul edildi — 28 Ekim 2026

Operatör ekran görüntüsünde **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket**
satırı ve **“İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.”**
durumu görünüyor. Sertifika kurulumu+ağ profilleri birlikte doğrulanan birleşik kayıt açıkça seçilmiş.
Manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b** ve
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5**
önceden kabul edilen imzalı adayla aynı.
Bu, dev.42 görev kanalı ve689649c0 kalıcı worker sonrası gerçek müşteri pozitif content sonucunun
**panel gösterimiyle kabulüdür**; eski ağ-only doğrulamasıyla karıştırılmadı.

Kanıt: **image(20261028-120334).png**,
SHA256 **3b730b6fbd659ab53437f94ec221e50f1ab954518c39e7de6b7afd44e1d57fe0**.
Kaynak operatör ekranıdır; asistanın bağımsız API/Windows/DB okuması değildir.
Görev kimliği ve ham imzalı result bu görüntüde bulunmuyor; bunlar uydurulmadı.
Kabul kaydı: **docs/checkpoints/2026-10-28-customer-combined-content-browser-accepted.json**.

**Tamamlanan alt adım:** birleşik imzalı aday hazırlığı → ayrı panel kaydı → dev.42 typed görev kanalı →
kalıcı Windows worker Prepare/Apply → pozitif birleşik içerik sonucu ve tarayıcı kabulü.
Linux son kabul **0.14.0-dev.42**; Windows son kabul **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**.
İçerik kabulü GPO/AD/SYSVOL tazeliği, gerçek staging/rollback veya endpoint kurulumu değildir.
Bu kayıt ürün/policy/AD/GPO/cihaz ayarlarını değiştirmez ve yeni tam yedek oluşturmaz.

**Sıradaki geliştirme/kontrol:** aynı birleşik adaya ve güncel içerik sonucuna bağlı,
güncel AD hedef üyeliklerini ve yönetilen GPO/SYSVOL durumunu salt okunur doğrulayacak kapsam adımı.
Mevcut ağ-only scope kanalı birleşik kanıt sayılmaz; birleşik hedef/paket pinleri korunarak
destek hazırlanmalı, önizleme/görev/worker sonucu ayrı kaydedilmelidir.
Sonra kontrollü staging/rollback ve gerçek pilot endpoint kabulü açık kalır.
Planın merkezi Windows dağıtımı maddesi devam ediyor; henüz GPO uygulaması başlatılmadı.
Genel **54/94 tamam,40 açık** sayımı ve **READY_FOR_FINAL_GUIDE=false /GUIDE_DELIVERED=false** değişmedi.
Her tamamlanan işlemi kaydetme tercihi bu kabul ve devam noktasıyla yerine getirildi.


## 🔴✓ Kalıcı Windows birleşik worker Apply kabul edildi — panel içerik görevi sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /Mode Apply /Stage applied /Error=null**
sonucunu paylaştı. **ServiceTransitioned=true**; kalıcı Connector
**efc5ee91-e39e-4cc4-9cc1-60b648e18cf9 → 689649c0-61df-40aa-bbfb-b84fa1cc2ac0** geçişi kabul edildi.
Kaynak bileşeni **157b2d4bc705539f78f982a860331e537010cab1**; SourceSignaturesValid=true,
ChangesMayBePartial=false. Mevcut hesap, eşleştirme, channel key, eski kaynaklar ve signer snapshot korundu.
**AD/GPO, signer key ACL ve trust store değişmedi; yeni anahtar/hesap/servis oluşturulmadı; CanApplyGpo=false.**
Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-689649c061df40aabbfbb84fa1cc2ac0-69466a1b270542f9832734e1055622f7**.
Tam çıktı **docs/checkpoints/2026-10-28-customer-combined-worker-applied.json** içinde kayıtlı.

İncelenen source'da Apply başarıdan önce yeni release/runtime kimliğine bağlı taze HTTPS health ile
Probe/Candidate/Scope/**CombinedChannelVerified** kapılarını zorunlu tutar.
Dolayısıyla applied sonucu bu kurulum kapısının geçtiğine dair operatör kanıtıdır;
asistanın bağımsız DC01 health/servis okuması veya pozitif birleşik aday doğrulaması değildir.
Önceki paket için ArchivePath kaydedildi; bu müşteride geri alma çalıştırılmış sayılmaz.

**Sıradaki adım:** paneli Ctrl+F5 ile yenile → **İmzalı dağıtım adayları** bölümünde
**AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırını seç →
**Doğrulamayı önizle → Doğrulamayı gönder** → yaklaşık30–60 saniye sonra **Yenile**.
Hedef manifest **124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b**,
taslak **5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5** korunur.
Ağ profilleri satırındaki eski doğrulama birleşik paket kanıtı olarak kullanılmaz.
Beklenen birleşik satır mesajı: **“İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.”**
Görev queued/leased iken tekrar gönderilmez; önce Yenile ile aynı görevin sonucu izlenir.

Henüz birleşik görev gönderildiği veya gerçek pozitif content sonucu alındığı bildirilmedi.
Taze birleşik AD/GPO/SYSVOL, staging/rollback, gerçek endpoint kabulü ve ürünün bütünü açık.
Linux dev.42; Windows son kabul689649c0; **54/94 tamam,40 açık**; nihai kılavuz kapısı değişmedi.
Her işlemden sonra sonuç/kanıt/devam kaydı eklendi; bu adım yeni tam yedek veya GPO/cihaz dağıtımı değildir.


## 🔴✓ Windows birleşik worker Prepare kabul edildi — Apply sırada — 28 Ekim 2026

Operatör **WINDOWS_CONNECTOR_UPGRADE_DELIVERY /ToolVersion1.3.0 /Mode Prepare /Stage prepared**
sonucunu paylaştı. Kaynak imzaları geçerli, **Error=null /ChangesMayBePartial=false**.
Beklenen current release **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**, yeni aday
**689649c0-61df-40aa-bbfb-b84fa1cc2ac0**, kaynak bileşeni **157b2d4bc705539f78f982a860331e537010cab1**.
**PackagePrepared=true; ExistingAccountPreserved/PairingPreserved/ChannelKeyPreserved=true**.
Signer snapshot ve eski kaynaklar korundu. **ServiceTransitioned=false**; çalışan Connector hâlâ eski sürümdedir.
GPO/AD, key ACL, trust store değişmedi; yeni anahtar/servis oluşturulmadı. **CanApplyGpo=false**.

Kanıt: **C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-689649c061df40aabbfbb84fa1cc2ac0-3628c461f2914802999776d7114ac9c6**.
Journal: **C:\ProgramData\AuthWire-ConnectorUpgrade-4c23eebe071546d188eea2e96ad7ee46-689649c061df40aabbfbb84fa1cc2ac0\upgrade.json**.
Tam operatör JSON'u **docs/checkpoints/2026-10-28-customer-combined-worker-prepared.json** içinde kaydedildi.
Bu kabul operatör çıktısına dayanır; asistanın bağımsız Windows oturumu/servis okuması değildir.
ArchivePath planlanan geri alma konumudur; Prepare sırasında eski paket arşivlenmiş veya geri alma denenmiş sayılmaz.

**Sıradaki işlem:** aynı hash doğrulanmış r2 launcher ile **-Mode Apply**.
Bu işlem yalnız kalıcı Windows Connector'ı kontrollü stop/start ile yeni worker'a geçirir;
mevcut hesap/eşleştirme/anahtar/signer ve önceki paket korunur. Linux RADIUS değiştirilmez.
Yeni sürüm için taze HTTPS health ve birleşik capability kabul kapısıdır;
uygulama sonucu ve taze health görüldükten sonra panelden birleşik doğrulama görevi gönderilecek.
Henüz Apply yapılmadı, müşteri pozitif birleşik roundtrip veya GPO/endpoint dağıtımı yok.
Linux son kabul **dev.42**, genel **54/94 tamam,40 açık**; nihai kılavuz kapısı değişmedi.
Her işlemden sonra kayıt tercihi yerine getirildi; yeni tam yedek alınmadı.


## Windows Prepare teslimatı doğrulandı — 28 Ekim 2026

PR111 merge **01d323fab033bcc8e56d59cae0cec0328cb7f4e3**; test head **1fdeba003642f34e1bf13a1722b782722ba09d93**.
Genel ve bounded retry workflow'ları başarılı;1001 test/28 skipped, üç yerel delivery regresyon testi geçti.
Yalnız wrapper'ın kabul edilen efc5ee91 başlangıç sürümü girdisi düzeltildi;
21 dosyalık embedded archive ve bütün imza/ACL/channel/rollback korumaları değişmedi.
Linux'taki eski dosyayla byte karşılaştırması, tek farkın bu sürüm girdisi olduğunu doğruladı.

**Kullanılacak r2 dosyası:** /home/segmentiq/authwire-dc01-combined-worker-upgrade-r2-20261028.ps1
SHA256 **65bf7b7a1963c9c103764c6e1b6677cecb2b5a06d2cffc1bcb56372c9fc86cc3**,125642 byte.
Yeni release **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**; beklenen current release
**efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Komut ve beklenen sonuçlar **docs/checkpoints/2026-10-28-windows-combined-worker-prepare-handoff.md** içinde kayıtlı.
Windows'ta henüz Prepare/Apply çalıştırılmadı; sonraki işlem yalnız Prepare ve sonucunu incelemek.
Linux dev.42 kabul edildi; GPO/endpoint uygulaması ve gerçek birleşik pozitif roundtrip hâlâ açık.
Bu teslimat işlemi tam yedek, yeni anahtar/hesap/sertifika veya dağıtım görevi oluşturmadı.


## 🔴✓ Dev.42 canlı Linux kurulumu kabul edildi — Windows birleşik worker hazırlığı sırada — 28 Ekim 2026

Operatör **COMBINED_JOBS_FINISHED /verified=true**, sürüm **0.14.0-dev.42**,
release **375677c9bd733cae0f25fd6fc59c0ea826b25f78** sonucunu paylaştı.
Korunan dosyalar, broker/RADIUS süreçleri, timer ve iş durumu kontrolleri geçti.
Önce/sonra bütün authenticated loopback okumaları200 döndü; combined job kanalı eklendi,
ancak birleşik görev oluşturulmadı. RADIUS PID **1243360** ve broker PID **1069437** korundu.
Kanıt: **/var/lib/authwire-updates/combined-jobs-dev42-20261028T114518Z-941ed9a1**.

Asistan ayrıca salt okunur source sürümünü dev.42, panel active/PID **2035660**,
RADIUS/broker active ve aynı PID'leri, backup timer active durumunu doğruladı.
Kurulu ve source backup worker hash'leri **4f489caa2113c86bda5d0d294878920e218769751e0edbb9385aa40135a924b6**;
release.json aynı worker hash'ini gösteriyor; restore checker hash'i değişmedi.
Asistan unprivileged olarak private web.crt okuyamadığından HTTPS kontrolünü bağımsız tekrarlamadı;
HTTP200/iş durumu korunumu operatörün sudo installer kanıtına dayanır. DB veya gizli değer okunmadı.

**backup_workers_changed=true beklenen uyumluluk güncellemesidir:** birleşik görev kanalının
poll/last_poll hareketleri yedek kararlılık kontrolüne eklendi; tam yedek alınmadı.
Politika, sertifika, plan, eşleştirme, AD/GPO, Windows paket/cihaz ve native modül değişmedi.
Son kabul edilen tam yedek28 Ekim10:28 arşividir; bu güncelleme yeni backup/restore provası sayılmaz.

Windows teslimatını vermeden önce wrapper'ın b546 başlangıç sürümü pininin artık eski olduğu bulundu.
Mevcut son kabul edilen scope worker **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9** olduğundan
yalnız ExpectedCurrentRelease girdisi düzeltildi;21 dosyalık imzalanacak kaynak arşivi değişmedi.
**PR111** bu düzeltmeyi ve regresyon kontrolünü kaydeder; son CI/teslimat hash'i aşağıdaki takip kaydına işlenecek.
Eski staged Windows helper henüz operatöre çalıştırılmak üzere verilmedi ve Windows'ta uygulanmadı.

**Sıradaki operatör adımı:** düzeltilmiş Windows helper ile **Prepare**;
çalışan servis/PID'yi değiştirmeden aday paket ve geri alma kaydı hazırlanır.
Başarılı sonucu takiben **Apply**, taze health/capability ve birleşik panel doğrulama görevi.
Windows son canlı release hâlâ **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Birleşik gerçek pozitif roundtrip, browser kabulü, taze AD/GPO/SYSVOL, staging/rollback ve endpoint kabulü açık.
**GPO apply=false;54/94 tamam,40 açık; nihai kılavuz kapısı değişmedi.**


## Birleşik kalıcı doğrulama hazır — dev.42 ve Windows uygulaması bekliyor — 28 Ekim 2026

**PR110** merge **bbeeb482099302dea45ed1f03cdd6cca6165cff0**, test head **f924535281b63c48e1facfe24964e73f50c5a9fd**.
Dokuz workflow başarılı: **1000 Python testi /28 skipped**, tarayıcı, native birleşik paket,
gerçek RADIUS, Linux kaynak hazırlama, yedek ve Windows kontrolleri.
Gerçek imzalı kalıcı SCM fixture'ında86 kontrol geçti: ayrı birleşik capability, typed negatif
görev sonucu, kanal kesintisinde upgrade reddi/rollback ve eski sürümden kontrollü yükseltme.
Linux delivery/rollback için14, geçici Linux lifecycle/registry ortamında19 test geçti.
İlk native denemede C# HTTPS allowlist'ine iki yeni exact yolun eklenmediği bulundu; düzeltildi.
Ayrı ve değişmeyen expired endpoint fixture'ı ilk çalıştırmada takıldı; retry ve son test head geçti.
Bu kayıt gerçek müşteri pozitif uçtan uca sonucu veya ürünün bütünü için kabul değildir.

**Yeni davranış:** combined.verify.v1 ayrı sıra/purpose/route ile birleşik operatör kaydına,
taslak/manifest/profile sürümüne, orijinal ağ kaydına ve geçerli Connector bağımlılıklarına bağlanır.
Kalıcı worker eski ağ adayını ve birleşik üç imzayı, profile/domain/group/CA/config/TLS ilişkilerini
yalnız genel anahtarlarla doğrular; signer private key açmaz, deployment artifact çalıştırmaz.
Eski ağ-only kanalı birleşik kaydı kabul etmez. Başarılı sonuç content_verified alanını ilerletir;
AD/GPO tazeliği, connector_verified ve can_apply ayrı ve henüz false kalır.
Panelde kendi worker yeteneği görüldükten sonra birleşik satırın “Doğrulamayı önizle” akışı kullanılabilir.

**Linux teslimatı salt okunur doğrulandı; HENÜZ UYGULANMADI.**
Son kabul edilen canlı Linux **0.14.0-dev.41**, Windows **efc5ee91-e39e-4cc4-9cc1-60b648e18cf9**.
Sudo helper: **/home/segmentiq/authwire-combined-jobs-20261028.py**
SHA256 **d0e64bfa44824de69e89f187949383a9201951ac77e47f0e403e1d2cd5d8d9e9**.
Stage: **/home/segmentiq/authwire-stage-dev42-375677c9bd73**,181 dosya,
manifest **361af5e19eeabcc1fc526d4f444d23b25966d8df4dced19f9715dec00ffbbdf2**,
Linux kaynak bileşeni **375677c9bd733cae0f25fd6fc59c0ea826b25f78**.
Yalnız yedi source dosyası değişir; yeni combined_jobs.py dahil. Server'ın25 değişmeyen fonksiyon gövdesi pinlidir;
yalnız üç incelenmiş dispatch gövdesi genişler, mevcut HTTPS/session/CSRF/çift güncel yetki ve peer korumaları korunur.
Panel restart planlı; RADIUS/broker PID, politikalar, sertifikalar, Windows, AD/GPO ve timer korunur.

**Yedek uyumluluğu:** dördüncü sıranın yalnız doğrulanmış polls/last_poll alanları mevcut karşılaştırma
projeksiyonuna eklenir; tüm gerçek DB içeriği ve durable jobs/results yedekte kalır.
Hem source hem kurulu backup worker yeni SHA **4f489caa2113c86bda5d0d294878920e218769751e0edbb9385aa40135a924b6**
olacak; kurulu release.json aynı hash'e atomik güncellenir, restore checker değişmez.
Eski/new pair pinleri, metadata, idle+exclusive update lock ve exact source/worker rollback kontrolü test edildi.
Her değişiklikte tam yedek alınmaması tercihi korunur;28 Ekim10:28 başarılı yedek hâlâ son kabul edilen arşivdir.

**Windows teslimatı Linux home'a aktarıldı, HENÜZ WINDOWS'TA ÇALIŞTIRILMADI.**
/home/segmentiq/authwire-dc01-combined-worker-upgrade-20261028.ps1
SHA256 **d8251cd89870519a7fa520c568713bd88949c6a3bd72924470dd47ec5a5ffba9**.
21 kaynak dosyası; bileşen **157b2d4bc705539f78f982a860331e537010cab1**,
yeni release **689649c0-61df-40aa-bbfb-b84fa1cc2ac0**,
arşiv **dffba96918da2e4295bf018f126de4297335ee4100cd5912370e97fb3b8b7509**.
Mevcut gMSA, eşleştirme, channel key ve signer/ACL korunur. Eski birleşik paket yeniden üretilmez/imzalanmaz.

**Devam sırası:** operatör Linux pinned sudo helper sonucunu paylaşır → Windows Prepare → Apply →
taze health/capability → panel birleşik satırında önizle/gönder/yenile ile gerçek pozitif content sonucu.
Ardından birleşik paket için taze AD/GPO/SYSVOL kapsamı, staging/rollback ve gerçek cihaz testleri açık kalır.
Bu hazırlık sırasında source/service/DB/GPO/endpoint canlı değişmedi; görev/yeni kayıt/tam yedek oluşturulmadı.
Genel **54/94 tamam,40 açık**; nihai kılavuz **READY_FOR_FINAL_GUIDE=false, GUIDE_DELIVERED=false**.
Her tamamlanan işlemi kaydetme tercihi bu test/teslimat/devam kaydıyla yerine getirildi.


Kullanıcı çalıştığı sunucuyu kapatıp açmadan önce ilerlemenin kalıcı kaydını istedi.
Hangi fiziksel/VM sunucusunun yeniden başlatılacağı belirtilmedi.
Bu kayıt güç işlemi, tam sistem/veri yedeği veya kurtarma testi gerçekleştirmez.
Kaynak taban commit: e7b1e2c4fc0161667f7dce60c9f6872fe043f247.
Yeni geliştirme bu devam noktasında duraklatıldı.

## Yeniden başlatma öncesi Linux yedeği — tamamlandı

28 Ekim 2026 10:28:35 İstanbul tarihinde yeni BACKUP_SUCCESS kabul edildi.
Arşiv: /var/backups/authwire/scheduled/authwire-scheduled-20261028T072835Z-004fe2d609b1.tar.gz
SHA256: 3c4b00b745063980c962f712a426a4ce2e845d62abb096ec2346941a5062c002
1687 dosya /4 DB; arşiv, byte/metadata, SQLite bütünlüğü, kararlı iş durumu ve ürün süreçleri doğrulandı.
Operatör helper bağımsız arşiv hash kontrolünü tamamladı; asistan journal/systemd/worker hash'lerini ayrıca okudu.
r2 worker SHA256: c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c.
Timer etkin; ürün servisleri durdurulmadı/yeniden başlatılmadı.
Bu arşivde veri restore veya tam OS boot restore provası yapılmadı; off-host kopya ve Windows/DC01 yedeği ayrı.
Henüz reboot yapılmış veya açılış sonrası sağlık doğrulanmış sayılmaz.

## Güncel devam noktası — dev.41 ve birleşik panel kaydı kabul edildi

Operatör ekranı birleşik satırı, beklenen pending durumunu ve doğru manifest/draft hash'lerini gösterdi.
Dev.41 canlı kurulum ve birleşik operatör kayıt/browser adımı tamamlandı.
Kanıt: docs/checkpoints/2026-10-28-customer-combined-registration-browser-accepted.json
Sıradaki iş: typed birleşik aday doğrulama görevi ve kalıcı Windows Connector worker entegrasyonu.
Mevcut paket yeniden oluşturulmayacak/imzalanmayacak; ağ-only kanıtı birleşik kabul sayılmayacak.
GPO staging/apply ve gerçek endpoint kabulü açık;54/94,40 açık; final guide ready=false.
Aşağıdaki kayıt-bekliyor notları tarihsel hazırlık/kurulum kayıtlarıdır.

## Son güncelleme — dev.41 kuruldu; birleşik panel kaydı bekliyor

Dev.41 kurulum sonucu doğrulandı. RADIUS1243360/broker1069437 korundu; panel active1991730.
Kanıt: /var/lib/authwire-updates/combined-registration-dev41-20261028T094925Z-b9c1e309
Yeni kayıt/görev/GPO uygulaması yok. Tarayıcı kabulü bekler.
Sıradaki işlem: mevcut başarılı birleşik Prepare çıktısının operator_result bölümünü
İmzalı dağıtım adayları/Hazırlık sonucunu kaydet alanında önizleyip kaydetmek.
Hazır JSON: docs/checkpoints/2026-10-28-combined-registration-panel-receipt.json.
Ardından typed birleşik kalıcı worker/job entegrasyonu.54/94,40 açık; final guide ready=false.
Aşağıdaki dev.41 uygulama-bekliyor notu tarihsel hazırlık kaydıdır; kurulum artık tamamlandı.

## Güncel devam adımı — birleşik kayıt dev.41 hazır, canlı uygulama bekliyor

Kullanıcı her tamamlanan işlemi GitHub'a kayıt etme tercihini yineledi; tam yedek her işlemde alınmayacak.
PR109 merge 749d84faa21058c6719df2ba4f635b8f80e87f1d; test head edebc092a5bcd253533a4ba53ee954034676830d.
960 test/28 skipped ve altı workflow geçti. A04 registry alt adımı hazır; live dev.41 ve browser kabulü bekler.
Linux helper: /home/segmentiq/authwire-combined-registration-20261028.py
SHA256: 408a2dcd5de9f5542bec00f7bcd86be9c3b3c415cb9adc90c108a9a075be151c
Stage: /home/segmentiq/authwire-stage-dev41-ae21bb729cf5
Manifest: 93cbe46e5af959a0778500e3d5020691164692182463077ceaef78ffa5546bb7
Yalnız panel restart planlı; RADIUS/broker/yedek/GPO/Windows değişmez.
Operatör uygulama sonucundan sonra mevcut birleşik imzalama çıktısı ayrı hazırlık kaydı olarak alınacak.
Ardından typed birleşik kalıcı Connector worker/job kanalı hazırlanacak.
Önceki ağ-only doğrulaması birleşik paket doğrulaması diye kabul edilmeyecek.

## Son kabul edilen durum
- Linux AuthWire: son operatör kabulü 0.14.0-dev.40.
- Windows kalıcı Connector: son kabul edilen release efc5ee91-e39e-4cc4-9cc1-60b648e18cf9.
- Birleşik imzalı paket DC01 üzerinde oluşturuldu; üç imza doğrulandı.
- aw-deploy$ hesabıyla gerçek geçici SCM kontrolü başarılı: exact runtime SID ...1648,
  ContentVerified/ServiceIdentityVerified/ProbeVerified true; SignaturesVerified=3.
- Geçici servis/exe/verifier/result dizini kaldırıldı, Error=null/CleanupErrors=[].
- Son PID9288 geçici probe PID'idir; tekrar var olması beklenmez.
- Kalıcı Connector değiştirilmedi; deployment artifact çalıştırılmadı.
- GpoStateChecked=false, DirectoryFreshnessChecked=false, CanStage=false, CanApplyGpo=false.
- Genel durum 54/94 tamam,40 açık; ürünün tamamı kabul edilmiş sayılmaz.
- READY_FOR_FINAL_GUIDE=false; nihai sade Türkçe ayrıntılı Word/PDF kılavuz teslimatı bekler.

## Kalıcı konumlar ve özetler
Linux kaynak: /opt/kaname-lab/source
Linux DB: /var/lib/kaname-lab/kaname.sqlite3
Linux özgün birleşik ZIP: /home/segmentiq/authwire-pilot-combined-draft-20261028.zip
ZIP SHA256: 5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5
Linux son kontrol helper'ı: /home/segmentiq/authwire-dc01-combined-runtime-20261028.ps1
Helper SHA256: 3caf4882a6871f4936b6021d68c44f664f14556ffc5cd3bdd7ef0bd87e8eec78

DC01 imzalı aday:
C:\ProgramData\AuthWire-CombinedCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5-1359-46f5-84a5-46355bb82aff-v1-5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5-ab1a11c683810061
İmzalı manifest SHA256: 124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b
Publisher: FFC134BC305757457163F99C7479B4168E397129
DC01 runtime kaynakları: C:\ProgramData\AuthWire-CombinedRuntimeSources-4bd3a5483f44fd62
DC01 kontrol özeti: C:\ProgramData\AuthWire-CandidateProbe-707b20123a304c599e8463068f0fdcd1\summary.json
Windows Temp altındaki aktarım kopyası veya açık PowerShell değişkenlerine devam için güvenilmez.
Gerekirse özgün ZIP Linux home konumundan tekrar aktarılabilir; paketi yeniden üretmek/imzalamak gerekmez.

## Kimlik ve hedefler
Domain: vizyonveri.local; DC01: dc01.vizyonveri.local
Appliance: https://kaname.vizyonveri.local:8765/ ; Linux IP son bilinen10.35.50.246
Connector ID: 4c23eebe-0715-46d1-88ee-a2e96ad7ee46
Servis: AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46
Hesap: VIZYONVERI\aw-deploy$
SID: S-1-5-21-34256453-3348971241-2809240126-1648
Plan: 524653f5-1359-46f5-84a5-46355bb82aff v1
Makine profili: e3597842-3499-4ace-aaf3-29890eabd908 v3
Owned deployment GPO: 8c6808fd-a382-4bf2-9c9c-d9e1d46082a3
Korunan trust GPO: e5a9ab39-3709-49cb-837a-0208d2eb3b12
TLS DER SHA256: a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d

## Yeniden açılışta devam sırası
1. Kullanıcının hangi host/VM'leri yeniden başlattığını öğren; etkilenenleri salt okunur kontrol et.
2. Linux erişimi, authwire-radius.service ve authwire-service-control.service aktifliği,
   panel HTTPS/session ve backup timer durumunu doğrula.
3. DC01 AD/DNS erişimi; kalıcı Connector servis hesabı, running durumu ve açılıştan sonra
   üretilmiş taze authenticated health/başarı zamanını kontrol et.
   Yeniden açılışta PID değişmesi normaldir; eski PID eşitliğini şart koşma.
4. Gerekliyse kalıcı aday dosyaları/manifest ve özgün ZIP'in özetlerini kontrol et.
   Önceki başarıyı her açılışta aynı uzun probe'ları tekrar çalıştırma gerekçesi sayma;
   sadece başarısız/taze doğrulama gerektiren sınır için hedefli kontrol yap.
5. Kaynak/iş verisi değişikliği veya başarısız başlangıç yoksa aşağıdaki geliştirmeye devam et.
   Sorun çıkarsa önce teşhis et; installer/Prepare/Apply komutlarını körlemesine tekrarlama.
   Yeni hesap/anahtar/sertifika/GPO oluşturma veya anahtar association/ACL onarma varsayımı yapma.

## Sıradaki geliştirme ve açık kabul kapıları
1. Birleşik paket için panel/Connector job + registry entegrasyonu.
   Mevcut ağ-only aday formatını birleşik paket diye yükseltme.
2. Kontrollü staging öncesinde taze AD hedef/GPO/tam SYSVOL kapsamı kontrolleri.
3. Controlled SYSVOL staging yazıcısı, koruma/rollback ve operatör kabulü.
4. GPO/ağ uygulama yolu; pilot cihazda sertifika edinimi, Ethernet/Wi-Fi EAP-TLS ve VLAN.
5. Kullanıcı doğrulaması/diğer A03 ve mevcut rapordaki açık saha/ölçek testleri kapanmış sayılmaz.
6. Tek hesap/standart kurulum sadeleştirmesi ve ayrıntılı final kullanım kılavuzu açık kalır.

## Kabul kanıtı
docs/checkpoints/2026-10-28-customer-combined-gmsa-runtime-accepted.json
docs/COMBINED_RUNTIME_VERIFICATION.md
Son araç PR106: merge60c39b36b594e3e1f9076a2a9e50ce87cdeda32b,
test head a69f9a6d2c1f6c2476a4ebb258e9299e6129cb14;
932 test/28 skipped, native Windows28 kontrol; dört workflow başarılı.
Başarı geçmişi yeniden açılış sonrası taze servis sağlığının yerine geçmez.

Devam cümlesi: “Sunucuyu açtım, 28 Ekim devam kaydından devam edelim.”
