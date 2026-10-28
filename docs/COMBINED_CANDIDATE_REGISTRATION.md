# Birleşik adayın panel kaydı

Bu aşama, DC01 üzerinde önceden hazırlanmış **WINDOWS_COMBINED_SIGNING_DELIVERY**
Prepare/verified çıktısını mevcut hazırlık sonucu penceresine kabul eder. Ağ profili
kaydı korunur; birleşik sertifika kurulum/ağ paketi ayrı kayıt ve manifest/draft
pinleriyle görünür. Windows paketi yeniden imzalanmaz veya üretilmez.

Birleşik çıktı host/GPO kimliği bildirmediğinden, sunucu aynı plan/sürüm/bağlantı/bağımlılık
kapsamında tam bir güncel ağ profili kaydı gerektirir. GPO/approval referansı o değişmez
kayıttan alınır. Bu ilişki mevcut Windows GPO'sunun okunduğu veya paketin o hostta
bulunduğu iddiası değildir. Gerçek dosya, domain/profile/CA/network, imza, servis kimliği ve
taze AD/GPO kapsamı ileriki birleşik worker görevinde ayrıca doğrulanmalıdır.

Tam çıktı, duplicate-key reddeden mevcut sınırlı JSON okuyucusundan geçirilir.
Yalnız bilinen başarılı envelope, üç imza, korunmuş signer/draft, false uygulama/
değişiklik bayrakları kabul edilir. Dosya yolları çalıştırılmaz, açılmaz, saklanmaz.
Plan/profil/katalog/config/trust değişirse eski kayıt güncel sayılmaz.
Kayıt hem sertifika hem Connector yazma yetkisi, HTTPS panel oturumu, CSRF/origin ve
aynı işlemde güncel yönetici yetkisi kontrolüne tabidir. Kayıp yanıt mevcut idempotent
kayıt/GET uzlaştırma yolunu kullanır; otomatik yeniden gönderme yoktur.

Eski **candidate.verify.v1** ve **deployment.scope.verify.v1** bu formatı reddeder.
Panel birleşik kayıt için bu düğmeleri göstermeyip kalıcı doğrulamanın henüz
kullanılabilir olmadığını açıklar. Operatör çıktısındaki imza/probe başarısı kalıcı
Connector attestation'ı değildir. **content_verified=false, connector_verified=false,
can_apply=false** kalır. Ayrı runtime probe kabulü bu kayıtla otomatik birleşmez.

Bu sınırlı kayıt adımı A04'ü tamamlamaz. Sıradaki adım birleşik hedefi taşıyan typed
kalıcı Connector görev kanalı ve Windows worker teslimatıdır. Sonrasında taze
AD/GPO/tam SYSVOL kontrolleri, staging/rollback ve uç cihaz kabulü gerekir.
Yerel AuthWire grupları geri getirilmez; panel logosu/tasarımı ve RADIUS doğrulaması değişmez.
