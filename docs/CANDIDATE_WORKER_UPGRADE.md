# Mevcut Windows Connector'a aday doğrulama desteği

Linux dev.39 operatör çıktısıyla kabul edildi. Windows'ta mevcut hesap, eşleme,
kanal anahtarı ve imzalı aday korunarak aynı servis yükseltilecek.

1. **Prepare:** sabit 16 kaynak doğrulanır ve mevcut machine publisher ile
   imzalanır. Ayrı candidate klasöründe yeni paket derlenir; çalışan servis
   durdurulmaz. Tekrar Prepare aynı paketi doğrular, üzerine yazmaz.
2. **Apply:** doğrulanmış paket etkinleştirilir. Eski statik kod rollback
   klasöründe korunur. Yeni runtime'ın güncel health, probe ve candidate görev
   kanalları birlikte doğrulanır. Candidate kanalı çalışmıyorsa eski paket
   otomatik geri yüklenir. Bu işlem GPO uygulamasını etkinleştirmez.
3. Sonraki panel görevi yalnız mevcut adayın imza/içeriğini okuyacak. Canlı AD/GPO
   freshness ve kapsam denetimi, SYSVOL staging ve endpoint kabulü ayrı bekliyor.

DC01 aracı yalnız beklenen domain/host, mevcut release, exact pairing, account,
kanal key adı/pin ve machine publisher bağlamını kabul eder. Metadata tanısında
kanıtlanan native persisted ad, unique keyfile, public-cert eşleşmesi, RSA3072,
machine/nonexportable/signing-only ve tam key ACL kontrol edilir. CLR marker
kalıcılık hükmü olarak kullanılmaz ve değiştirilmez. Marker/binding/ACL önce ve
sonra karşılaştırılır. Yeni işlem için küçük admin-only evidence dizininde
before/after/result kayıtları tutulur; eski başarısız wrapper geriye dönük başarılı
sayılmaz. Inspect kaynak/servis/evidence oluşturmaz.

Yeni hesap/sertifika/anahtar oluşturma, private export, signer key ACL onarımı,
AD/GPO/endpoint değişikliği ve eski başarılı manuel probe tekrarı yok. Prepare
mevcut anahtarla yalnız sabit incelenmiş kaynakları ve yeni servis paketini
imzalar; adayı çalıştırmaz. Windows teslimatı ve gerçek müşteri kabulü, kaynak
ve CI kabulünden ayrıdır. Tam veri yedeği alınmaz; kod rollback arşivi ve küçük
işlem journal/evidence kayıtları saklanır.
