# AuthWire kapasite hedefleri ve ölçek kabulü

29 Ekim 2026. Kullanıcının 200 cihazın ürün sınırı olup olmadığı sorusuna ilişkin kaynak kontrolü.
İncelenen kaynak sabiti: fffa56643101343a9bc9be05f7889dab85367696.

## 200 ne demek?

WINDOWS_DEPLOYMENT_CONNECTOR ve CONNECTOR_SINGLE_ACCOUNT_CHANNEL belgeleri 200 kullanıcı/bilgisayarı
kademeli ölçek kabulü olarak tanımlar. Bu ifade üründe 201'inci cihazın yasaklanması veya lisans kotası değildir.
İlk ölçek basamağını toplam destek kapasitesi gibi sunmamak gerekir.

Toplam kayıtlı uç, aynı anda bağlı uç/oturum, aynı anda başlayan EAP-TLS doğrulaması, kayıt/yenileme
hızı ve günlük audit hacmi farklı yüklerdir. Örneğin 1000 cihazın gün içine yayılmış bağlantısı ile
kesinti sonrasında aynı dakikada yeniden bağlanması aynı yük değildir.
Başarı donanım/DB/AD gecikmesi, TLS iş yükü, yenileme/CRL, Accounting ve kuyruk davranışıyla ölçülür.

## Bugünkü gerçek teknik sınır

- kaname/scope_jobs.py: target_count ve çözümlenen bilgisayar listesi en fazla512.
- kaname/combined_scope_jobs.py: aynı 512 üst sınırı.
- kaname/staging_preview_jobs.py: aynı 512 üst sınırı.
- windows/connector/DeploymentScope.ps1: target_count/bilgisayar listesi en fazla512;
  Get-ADComputer -ResultSetSize513 ile taşma algılanır.
- windows/connector/CombinedDeploymentScope.ps1: target_count en fazla512.
- docs/DEPLOYMENT_SCOPE_JOB_CHANNEL.md bunu açıkça1–512 etkin bilgisayarlık sözleşme olarak belirtir.

Dolayısıyla **bugün 1000 bilgisayarlı hedef grubu tek scope/preview görevinde kabul edilmez**.
Bu, 1000 uçlu ortamda RADIUS'un mutlaka duracağı anlamına gelmez; dağıtım işinin kapsam sınırıdır.
500 sözleşmedeki sayı sınırının içindedir; bu, 500 cihaz için süre/kapasite veya saha garantisi değildir.
DeploymentScope içindeki ResultPageSize200 ise AD sorgu sayfa boyutudur; toplam cihaz kotası değildir.

tools/device_load_smoke.py varsayılan1000 ve1–2000 fixture aralığı içerir.
Bu aracın bulunması veya fixture sayısı, bugün1000 cihaz testinin geçtiğini kanıtlamaz.
Araç gerçek AD, GPO veya fiziksel EAP-TLS saha kabulü değildir. Bu incelemede yeni yük testi çalıştırılmadı.

## Açık iş ve doğrulama sırası

1. Küçük temsilî gerçek pilot; sonra200,500,1000 hedefli teknik ölçek basamakları.
2. 512 üstü dağıtım için tek onaya bağlı kapsam snapshot'ı, bounded parçalara ayırma, tam kapsama/tekrar
   kontrolü, pairing/plan/önizleme bağı, sonuç birleştirme, idempotency ve kısmi hata/kurtarma.
   Bu mekanizma henüz mevcut değildir; burada çalışıyormuş gibi gösterilmez.
3. Her basamakta normal yük, toplu açılış/yeniden bağlanma, kayıt/yenileme ve bileşen kesintisi.
4. Başarı oranı, timeout/retry, p95/p99 süreler, iş/saniye, CPU/RAM, DB kilidi ve kuyruk gecikmesi.
   Kabul eşikleri testten önce iş yükü ve donanım profiliyle tanımlanır; ölçülmemiş sayı uydurulmaz.
5. Gerçekte kaç fiziksel/sanal uç, kaç tam protokol istemcisi ve kaç sentetik kayıt kullanıldığı ayrı yazılır.
   Gerçek200 uç yoksa200 cihaz saha kabulü kapatılmaz. Temsilî saha + kontrollü yük, iki ayrı kanıt olarak raporlanır;
   bugün1000 fiziksel PC'nin hazır olması bir geliştirme ön koşulu değildir.

Hedef, 200'de durmak veya500/1000'e keyfi ürün kotası koymak değildir.
Destek kapasitesi doğrulanan donanım/iş yükü ve yazılım sürümüyle ilan edilecek; daha büyük
ölçekler için yeniden ölçüm/iyileştirme gerekir. Bu rapor üretim kapasitesi garantisi değildir.

## Tahmine etkisi

500/1000 ölçek doğrulaması ile 512 üstü görevlerin güvenli parçalanması açık ölçek paketine eklendi.
Önceki2–4 aktif işgünlük kapasite/regresyon tahmini **5–9 aktif işgününe** çıktı
(yaklaşık3–5 ek işgünü). Bu tamamlanmış geliştirme değildir.

İlk küçük otomatik pilot için2–3 hafta korunur; büyük kapsam bunun ön koşulu yapılmadı.
500/1000 teknik ölçek kapısını içeren temel kapanış için **6–9 hafta**,
temel sürüm kılavuzu dahil **7–10 hafta**, tüm kayıtlı geliştirmeler/nihai kılavuz için **13–19 hafta**
koşullu planlama aralığı kullanılır. Test altyapısı ve API erişimi beklemeleri bu aralığa garanti olarak girmez.
