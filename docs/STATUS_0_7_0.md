# KANAME 0.7.0-dev.1 — onaylanan yönetim değişiklikleri

## Davranış

Network → VLANs: ID 1–4094, ad, açıklama ve düzenleme/silme. Politikadaki VLAN silinemez. Eski politikaların VLAN ID değerleri kaybolmaz; varsayılan adla listelenir. Cihazlarda VLAN oluşturulmaz.

Network → RADIUS Clients: gerçek paket kaynak IP'si, cihaz adı, shared secret üretme, korumalı saklama, yetkili kullanıcı için açıkça gösterme ve yenileme. Authentication/Accounting UDP portları bağımsız ayarlanır, varsayılan 1812/1813; aynı port olamaz. Timeout/retry ve cihaz yönetimi yok. Üretim dinleyicisi henüz yok; bu ekran ayarları hazırlar.

Politikalar: sıra bağımsızdır, aç/kapat/yukarı/aşağı yok, düzenle/sil var. Çakışan karar, VLAN veya kısıt aynı koşulda kaydedilemez; sağ alt uyarı isimleri ve düzeltme gereğini açıklar. Grup koşulları aynı, ortak veya katalogdaki doğrudan/primary/iç içe kullanıcı üyeliğiyle örtüşen politikalar kontrol edilir. Ayrı grupların gelecekte ortak üyesi olabilir: her başarılı katalog güncellemesinde uyarı yeniden hesaplanır ve gerçek karar motoru farklı sonuçlarda POLICY_CONFLICT ile reddeder. Aynı sonucu veren eşleşmeler birleşir. Önceki kapalı politikalar kendiliğinden açılmaz; arşivlenmiş olarak görünür.

AD yalnız okunur. Bağlantı ekranındaki kullanıcı ve parola saklanır; parola GET yanıtlarına geri verilmez. Windows'ta DPAPI kullanıcı kapsamı, Linux geliştirme/test ortamında 0600 yerel anahtar ile AES-GCM kullanılır. Linux appliance secret lifecycle henüz üretim kabulü almamıştır. Windows'ta panel aynı Windows hesabıyla çalışmalıdır.

CN/OU/DC boşsa tüm authenticated domain okunur. Konum girilirse o konumdaki gruplar, aynı domaindeki doğrudan üyeler, nested gruplar ve primary üyeler alınır. Üyeler başka OU'da olabilir; yabancı domain üyeleri çözülmez ve eksik kapsam gösterilir. Konum bir LDAP filtresi değildir; DC eki yapılandırılmış domainle eşleşmelidir. Değiştirilmiş filtre/bağlantı okunurken revizyon değişirse eski sorgu sonucu kaydedilmez.

Manuel eşitleme kayıtlı bağlantıyı kullanır. Otomatik eşitleme seçilebilir; varsayılan 15 dakika, bağımsız bağlantı kontrolü 5 dakika, her ikisi 1–1440 dakika ayarlanır. Bağlantı kontrolü Kerberos bind ve RootDSE domain doğrulamasını yapar; tüm kataloğu tekrar okumaz. Periyodik işlemler panel süreci çalışırken yürür. Windows boot servisi/Ubuntu systemd kurulum kabulü sonraki appliance aşamasındadır.

Başarılı tam sorgu kullanıcı ekleme/silmeyi ve üyelik değişikliklerini yansıtır. Ulaşılmaz AD, reddedilen kimlik bilgisi, timeout veya eksik sorgu eski kataloğu silmez. Son durum ve son başarılı kontrol panelde gösterilir. Hata nedeni kesin parola değişikliği olarak sunulmaz. Mail ve AD grup üyeliği yazma bu sürüme dahil değildir. Karar testi AD grup adlarından seçim yapar.

## Doğrulama

Test sonuçları yayın kontrolünden sonra bu belgeye eklenecek. Gerçek müşteri AD bilgileri CI'ye alınmaz. Ubuntu müşteri VM'i ve fiziksel switch/AP kabulü henüz yapılmadı.

## Kullanıcı kabulü

Ctrl+F5 ile paneli yenileyin. Önce VLAN adlarını kontrol edin. AD bağlantısını bir kez kaydedin; istenirse CN/OU/DC konumu ve otomatik eşitlemeyi seçin, Şimdi eşitle'ye basın. RADIUS cihazına secret üretip kaydedin ve aynı değeri cihazınıza manuel girin. Bu aşamada gerçek cihaz erişimi beklemeyin.

Sürüm tamamlanınca sorular veya değiştirmek/düzenlemek istenen yerler sorulur; yanıt gelmeden sonraki sürüme geçilmez.
