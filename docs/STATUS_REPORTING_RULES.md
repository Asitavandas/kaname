# Güncel durum raporlama kuralları

29 Ekim 2026 kullanıcı talebi. Bundan sonraki HER güncel durum raporu güncellemesinde süre tahmini de yeniden değerlendirilecek.

Her raporda:
1. Rapor tarihi ve karşılaştırılan önceki rapor/kaynak.
2. Her açık iş paketi için mevcut durum, kalan tahmini işgünü aralığı ve bağımlılıklar.
3. İlk pilot, temel işlevsel kapanış ve tüm hedef kapsam için kalan süre ve koşullu bitiş penceresi.
4. Operatörün aktif test saatleri ile takvimde gözlem/bekleme süresi ayrı.
5. Önceki tahmine göre değişiklik ve somut nedeni. Değişmediyse neden değişmediği.
6. Altyapı/cihaz/API/test erişimi beklemeleri ve tarih verilemeyen dış bağımlılıklar.
7. Teknik test, müşteri kurulumu, gerçek uç/saha ve kapasite kabulü ayrı.

Geçen takvim günü otomatik olarak kalan süreden düşülmez. Tamamlanan iş, yeni bulgu, gerçek çevrim süresi,
açık risk ve erişim beklemeleriyle yeniden hesaplanır. Test sayısından veya 54/94 gibi iş sayımından
doğrusal bir teslim tarihi türetilmez. Süre taahhüt değildir; çalışılmayan gün arka plan çalışma sayılmaz.
Yeni tarih penceresi değişen koşullarla hesaplanır; eski tarih sessizce ileri taşınmaz.

## Kapasite dili

200 bir ilk ölçek kabul basamağıdır; lisans/ürün/kurulumun toplam cihaz kotası değildir.
500/1000 de otomatik destek garantisi olarak yazılmaz. Kayıtlı cihaz, aktif oturum,
eşzamanlı tam EAP-TLS doğrulaması ve saniyelik istek yükü ayrı ölçülür.
Tek görev sınırı ile toplam hizmet kapasitesi ayrı gösterilir.
Mevcut scope/combined-scope/staging-preview sözleşmesi görev başına 1–512 etkin bilgisayar kabul eder.
Bu sınır yalnız sayı büyütülerek gevşetilmeyecek; büyük kapsam için güvenli parçalama/bütünlük/sonuç
birleştirme ve kısmi hata davranışı ayrıca geliştirilecek ve test edilecek.
Kanıtın gerçek fiziksel/sanal uç, gerçek protokol yükü veya sentetik AD fixture'ı olduğu açık yazılacak.

İlgili güncel tahmin: reports/2026-10-29-process-forecast.md.
Kapasite ve kabul ayrıntısı: CAPACITY_AND_ACCEPTANCE.md.
Bu kural planlı yeni bir bildirim/otomasyon oluşturmaz; durum raporu hazırlanırken uygulanır.
