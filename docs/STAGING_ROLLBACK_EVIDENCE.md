# Geri alma ön kontrolü ve özgün stage kanıtı — yalnız kaynak

30 Ekim 2026. `StagingRollbackEvidence.ps1`, rollback teklifinin tam olarak hangi
başarılı stage işlemine bağlı olduğunu okur. Aktif pakete/worker'a eklenmez;
üretim rotaları açılmaz. İzin göndermez/tüketmez, dosya silmez, journal yazmaz,
GPO kilidi kaldırmaz. Bu alt kapı ayrı onaylı rollback adapter'ının tamamı değildir.

`Read-AuthWireRollbackOrigin`, strict typed rollback offer/intent hash'ini ve
ayrı iş GUID'sini denetler. Özgün stage kayıtlarını yalnız sabit özel ProgramData
yazma kökünden türetir. Caller veya teklif bir journal/destination yolu veremez.
Özgün GPO kilidi korunur; önceki stage/outcome mutex'i ve canlı gate/PID kontrolü
kullanılır. Binding nesli, kanal anahtarı ve kapsam eski kaydı doğrulamalıdır.
Eski stage release'i yalnız eski kanıtı okumak için kullanılır; scope/key nesli
kendiliğinden taşınmaz. Yeni rollback release'i teklifin kendi release'iyle eşleşir.

Tek bir complete dosyası, hash veya operatör bildirimi yeterli değildir. Özgün
CLAIM kanıtı/receipt, tüketim, filesystem intent, launch/child/preflight, gerçek
23 satırlı engine ownership kaydı, child sonucu, parent gözlemi, değiştirilemez
staged outbox ve kaydedilmiş tam ACK bağlantısı birlikte eşleşmelidir. Tarihsel
observed-body okuması, stage outbox üretimindeki kontrolleri aynen kullanır; yeni
outbox yazmaz ve eski checked_at/preview/grant sürelerini yenilemez.
Eksik/bozuk/inceleme gerektiren sonuç, farklı stage/plan/manifest/dependency,
kayıp ACK veya önceki rollback başlangıcı/tamamlanması inceleme gerektirir.

`Get-AuthWireRollbackPreflight`, kaynağı doğrulanan stage kanıtının yanında:

- Servis SID'si, authenticated/non-admin kimlik ve mevcut imzalı içerik/AD/GPO
  kapsam kontrollerini çalıştırır. AD/PDC, hedefler, GPO owner/marker/ACL/link/
  settings/versiyon gözlemleri özgün scope hash'iyle iki defa eşleşmelidir.
- Geçerli PDC/SYSVOL yolunu yerel doğrulamadan türetir; PDC/yol değişimini otomatik
  DFSR kimlik taşıması saymaz. Korunan trust GPO ayrı kalır.
- Gerçek staged ağacı read-only native handle'larla sabitler; 20 dosya/3 dizinin
  byte/hash/ACL/volume-file kimlikleri tam ownership kaydıyla eşleşir. ADS,
  hardlink/reparse ve ek dosya reddedilir; dış GPO tabanı değişmemelidir.
- Sonra özgün sonuç zincirini yeniden kontrol eder. Kanıt değişirse durur.

Dönen beş saniyelik yeni gözlem bir **izin değildir**: read_only=true,
write_authorized=false, can_delete=false, can_apply_gpo=false ve
requires_separate_claim=true. Eski preview/grant son tarihi değiştirilmez.
Yerel monoton/UTC kontrolü 15 saniyeden geç dönen gözlemi reddeder; bu henüz
kesin bir AD/SMB I/O iptal sınırı değildir. Sabit AllSigned child ile parent'ın
süreç bütçesi sonraki entegrasyon kapısıdır. Bu gözlem doğrudan düşük seviyeli
rollback motoruna yetki olarak verilemez; her gerçek silme öncesi canlı kontrol
ayrı özgün rollback CLAIM/tek kullanımlık tüketimle bağlanmalıdır.

## Doğrulama ve sınırları

Yeni hosted Windows akışı, mevcut 13 senaryolu gerçek CNG/pinned TLS/SQLite/
imzalı child/SMB fixture'ını çalıştırır. Gerçek hazırlanmış/parent tarafından
gözlenmiş ve RESULT/ACK alınmış iki stage (normal ve kayıp-ACK sonrası) üzerinde
okuma guard'ı test edilir. Rollback offer'ları sentetiktir; AD/içerik/servis
kimliği dizin gözlemleri açıkça shim'dir. Rollback onayı/CLAIM verilmesi,
tüketilmesi veya dosya silme bu fixture'ın kapsamı değildir.

Yanlış origin/complete/tree/preview bağı, binding nesli, expired teklif, stage'i
rollback sayma, eksik/değişmiş observation/outbox/ACK, review sonucu, önceki
rollback marker'ı, canlı stage gate'i, staged byte/ACL/ADS/ek dosya, dış taban ve
PDC sapmaları reddedilir. Özgün proof/result kayıtları ve GPO kilidi byte-byte,
SYSVOL hash/ACL tabanı ve eski preview zamanları korunur. Yalnız testin oluşturduğu
geçici kayıtlar negatif vakalar arasında restore edilir; ürün recovery API'si yoktur.

Açık: sabit sınırlı AllSigned rollback reader, ayrı rollback CLAIM taşıma ve receipt,
tek kullanımlık tüketim, sınırlı child/parent gözlemi, immutable rollback RESULT,
kalıcı worker/kurtarma/retention, ayrı unlock, backup/restore ve gerçek müşteri
least-privilege gMSA/AD/domain-SYSVOL/endpoint kabulü. Müşteri kurulumu yapılmadı.
