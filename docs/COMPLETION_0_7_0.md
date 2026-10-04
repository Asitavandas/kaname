# KANAME 0.7.0-dev.1 — tamamlanma kaydı

## Davranış

Network → VLANs: ID 1–4094, ad, açıklama ve düzenleme/silme. Politikadaki VLAN silinemez. Eski politikaların VLAN ID değerleri kaybolmaz; varsayılan adla listelenir. Cihazlarda VLAN oluşturulmaz.

Network → RADIUS Clients: gerçek paket kaynak IP'si, cihaz adı, shared secret üretme, korumalı saklama, yetkili kullanıcı için açıkça gösterme ve yenileme. Authentication/Accounting UDP portları bağımsız ayarlanır, varsayılan 1812/1813; aynı port olamaz. Timeout/retry ve cihaz yönetimi yok. Üretim dinleyicisi henüz yok; bu ekran ayarları hazırlar.

Politikalar: sıra bağımsızdır, aç/kapat/yukarı/aşağı yok, düzenle/sil var. Çakışan karar, VLAN veya kısıt aynı koşulda kaydedilemez; sağ alt uyarı isimleri ve düzeltme gereğini açıklar. Grup koşulları aynı, ortak veya katalogdaki doğrudan/primary/iç içe kullanıcı üyeliğiyle örtüşen politikalar kontrol edilir. Ayrı grupların gelecekte ortak üyesi olabilir: her başarılı katalog güncellemesinde uyarı yeniden hesaplanır ve gerçek karar motoru farklı sonuçlarda POLICY_CONFLICT ile reddeder. Aynı sonucu veren eşleşmeler birleşir. Önceki kapalı politikalar kendiliğinden açılmaz; arşivlenmiş olarak görünür.

AD yalnız okunur. Bağlantı ekranındaki kullanıcı ve parola saklanır; parola GET yanıtlarına geri verilmez. Windows'ta DPAPI kullanıcı kapsamı, Linux geliştirme/test ortamında 0600 yerel anahtar ile AES-GCM kullanılır. Linux appliance secret lifecycle henüz üretim kabulü almamıştır. Windows'ta panel aynı Windows hesabıyla çalışmalıdır.

CN/OU/DC boşsa tüm authenticated domain okunur. Konum girilirse o konumdaki gruplar, aynı domaindeki doğrudan üyeler, nested gruplar ve primary üyeler alınır. Üyeler başka OU'da olabilir; yabancı domain üyeleri çözülmez ve eksik kapsam gösterilir. Konum bir LDAP filtresi değildir; DC eki yapılandırılmış domainle eşleşmelidir. Değiştirilmiş filtre/bağlantı okunurken revizyon değişirse eski sorgu sonucu kaydedilmez.

Manuel eşitleme kayıtlı bağlantıyı kullanır. Otomatik eşitleme seçilebilir; varsayılan 15 dakika, bağımsız bağlantı kontrolü 5 dakika, her ikisi 1–1440 dakika ayarlanır. Bağlantı kontrolü Kerberos bind ve RootDSE domain doğrulamasını yapar; tüm kataloğu tekrar okumaz. Periyodik işlemler panel süreci çalışırken yürür. Windows boot servisi/Ubuntu systemd kurulum kabulü sonraki appliance aşamasındadır.

Başarılı tam sorgu kullanıcı ekleme/silmeyi ve üyelik değişikliklerini yansıtır. Ulaşılmaz AD, reddedilen kimlik bilgisi, timeout veya eksik sorgu eski kataloğu silmez. Son durum ve son başarılı kontrol panelde gösterilir. Hata nedeni kesin parola değişikliği olarak sunulmaz. Mail ve AD grup üyeliği yazma bu sürüme dahil değildir. Karar testi AD grup adlarından seçim yapar.

## Doğrulama

Kaynak hazırlama testinde Windows: 258 test, 256 başarılı/2 atlandı; Linux: 258 test, 250 başarılı/8 Windows özel testi atlandı. Native FreeRADIUS/EAP-TLS: 24 senaryo başarılı (iki farklı sırada allow/deny çakışma reddi dahil). Tarayıcıda geciken AD ayar yanıtının DC alanını boşaltma yarışı görüldü; form yüklenirken yazma bekletilerek düzeltildi. Son yayın kontrolleri ve Windows kurulum sonucu aşağıya eklenecek. Gerçek müşteri AD bilgileri CI'ye alınmaz. Ubuntu müşteri VM'i ve fiziksel switch/AP kabulü henüz yapılmadı.

## Kullanıcı kabulü

Ctrl+F5 ile paneli yenileyin. Önce VLAN adlarını kontrol edin. AD bağlantısını bir kez kaydedin; istenirse CN/OU/DC konumu ve otomatik eşitlemeyi seçin, Şimdi eşitle'ye basın. RADIUS cihazına secret üretip kaydedin ve aynı değeri cihazınıza manuel girin. Bu aşamada gerçek cihaz erişimi beklemeyin.

Sürüm tamamlanınca sorular veya değiştirmek/düzenlemek istenen yerler sorulur; yanıt gelmeden sonraki sürüme geçilmez.

## Yayına hazır kaynak kontrolleri

- Kaynak: 20f73500309ba8b7b8ecccf4fbd1bde53dda3a7b.
- [Windows](https://github.com/Asitavandas/kaname/actions/runs/37198767411): 258 test, 256 başarılı/2 atlandı; DPAPI round-trip/tamper/purpose ve gerçek .NET scoped loopback LDAP dahil.
- [Linux](https://github.com/Asitavandas/kaname/actions/runs/37198767377): 258 test, 250 başarılı/8 Windows özel testi atlandı.
- [Chromium](https://github.com/Asitavandas/kaname/actions/runs/37198767432): yeni yönetim akışları, şifreli kayıt, çakışma kaydının engellenmesi ve düzeltilmesi, read-only reveal reddi, eski oturum gecikmesi başarılı.
- [Native RADIUS](https://github.com/Asitavandas/kaname/actions/runs/37198767439): 24 başarılı senaryo; rapor [RADIUS_PROOF_0_7_0.json](RADIUS_PROOF_0_7_0.json).

## Windows kurulum kabulü

Yayın commit'i: 25477b024d60e8fa940f84828d19acf9ff4b7789.
[Windows update](https://github.com/Asitavandas/kaname/actions/runs/37198982588) başarılıdır. Ön kontrolde 258 test, 256 başarılı/2 atlandı.

C:\Users\Administrator\KANAME kurulumu 0.7.0-dev.1 olarak güncellendi; kaynak ve SQLite yedeği alındı. Configuration, policies, CA, token, directory_catalog ve panel_accounts korundu. Mevcut hesaplar tekrar oluşturulmadı, parola sıfırlanmadı ve varsayılan ilk giriş tekrar denenmedi.

Tanılama kaynak/HTTP sürüm eşleşmesini, revision 16 ve 86 dosyalık kaynak manifestinde missing_files=[]/changed_files=[] sonucunu doğruladı. Gerçek AD kimlik bilgileri kullanılmadı; gerçek AD bağlantısı/eşitleme kullanıcı kabulünü bekler. RADIUS üretim dinleyicisi, accounting ve açılabilir OVF bekliyor.

Operatör mevcut panel hesabıyla Ctrl+F5 sonrası giriş yapar. Network → VLANs ile mevcut VLAN adları kontrol edilir; Active Directory altında bağlantı bir kez korumalı kaydedilip Şimdi eşitle denenir. İstenirse otomatik eşitleme açılır. Shared secret yalnız yetkili RADIUS ekranından oluşturulur/gösterilir ve aynı değer cihazda manuel tanımlanır.

Sürüm tamamlandı. Operatörün soruları/değişiklik isteği sorulacak; yanıt gelmeden sonraki sürüme başlanmayacak.

