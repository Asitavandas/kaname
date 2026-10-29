# Windows yazma öncesi görev kaydı ve CLAIM hazırlığı

29 Ekim 2026. **Yalnız kaynak geliştirmesi.** Linux/DC01'e kurulmadı; kalıcı
worker veya paket listesine kaydedilmedi. Yeni HTTP peer rotaları ve create hâlâ
kapalıdır. Bu modül ağ isteği göndermez, grant kabul etmez, dosya yürütücüsünü
çağırmaz, GPO etkinleştirmez ve eski kayıtları silmez.

## Bu katmanda yapılanlar

- Ayrı POLL/CLAIM/RESULT proof amaçları, yolları ve1024/4096 bayt sınırları.
  Mevcut host/SID/non-exportable machine CNG key doğrulaması aynen kullanılır;
  dışarı çıkan anahtar bilgisi yalnız public key'dir. Müşteri imzalama anahtarı
  açılmaz/onarılmaz; yeni anahtar üretimi yalnız CI fixture'ına aittir.
- Server target/intent ve sıra bağımsız canonical JSON özeti ile mevcut20 dosyalı
  önizlemenin sıra tanımlı özeti doğrulanır. Yol/komut/ek alan, farklı binding veya
  release, kaynak/ACL/hash farkı, aşılmış süre ve yetki overclaim'i reddedilir.
  Eski filesystem guard'ına giden önizleme sabit alan sırasına normalize edilir;
  ağ/SQLite JSON alan sırası onayın anlamını değiştirmez. Ek alanlar atılarak
  gizlenmez; normalize etmeden önce kesin şema doğrulanır.
- Özel ACL'li yerel journal kökü çağıran tarafından sağlanmalıdır. Ağ teklifinden
  journal/source/SYSVOL yolu alınmaz. GPO kilidi ve job offer kaydı CreateNew ve
  Flush(true) ile yazılır; namespace sahiplenilmez veya mevcut ACL gevşetilmez.
  Başka binding nesli aynı GPO kilidini aşamaz. En fazla32 iş/64 üst giriş sınırı
  vardır. Kısa yerel oluşturma bölümü makine genelinde nonblocking mutex ile
  sıralanır; path alias'ları kapasite yarışını açmaz. Busy/ACL/IO hatası izin vermez.
- Sabit AllSigned child, en fazla30s çalışma bütçesi ve bounded stdout/stderr ile
  mevcut içerik/imza/hizmet kimliği ve canlı AD/GPO/SYSVOL okumasını kullanır.
  Helper yalnız seçili yerel job kaydını okur. PDC aynı okuma boyunca tutarlı
  olmalı; source kökü ProgramData + doğrulanmış connector/plan/draft sabitinden,
  SYSVOL kökü doğrulanmış domain/PDC/GPO'dan türetilir. Protected trust GPO reddedilir.
- Yeni okuma eski onayın checked_at/expires_at alanlarıyla karşılaştırılır;
  taze snapshot eski onayı sessizce değiştirmez veya süresini uzatmaz. Mevcut
  önizleme eski PDC adını taşımaz; bu modül eski PDC'nin değişmediğini iddia etmez.
  Yerel preflight güncel PDC/üretilmiş yolları kaydeder; gerçek yazma öncesi bunlar
  yeniden canlı kontrol edilmelidir. Cache tek başına yazma izni değildir.
- CLAIM hazırlığı için en fazla5s önce tamamlanan aynı-job/target canlı kayıt
  gerekir. claim-started.json proof üretilmeden önce flush edilir. Başarılı proof
  de dönmeden önce kaydedilir. İmza hatası, kayıp yanıt veya process reload ikinci
  CLAIM üretmez; kayıt/kilit inceleme için kalır. Ağ isteğini başka bir caller'ın
  gönderip göndermediği buradan bilinemez; claim-started muhafazakâr belirsizliktir.

## Sınırlar ve kalan entegrasyon

Bu ilk Windows katmanı **stage preclaim** içindir. Rollback hedef/proof şeması
okunabilir, ancak rollback offer'ın kaydı/canlı ön kontrolü açıkça reddedilir.
Tam rollback adapter'ı bitmiş değildir. Grant cevabının kesin doğrulanması ve
yerel kaydı, dosya motoruna bağlama, sonuç gönderimi, kayıp yanıtta journal
uzlaştırma, kısmi recovery ve bağımsız onayla kilit çözme hâlâ açıktır.
Hiçbir kayıt/timeout otomatik tekrar veya temizleme oluşturmaz. Her process/
yeniden eşleştirme aynı önceden hazırlanmış güvenilir journal kökünü kullanmalıdır;
yeni boş kök seçmek kurtarma yöntemi değildir. Power-loss/hardware kalıcılığı
Flush(true) çağrısından bağımsız ayrıca saha/restore testine tabidir.

512 hedef sözleşmesi korunur. strict backup projection, gerçek onay formu/peer
rotalarının açılması, imzalı teslim, gerçek gMSA ve AD/SMB kabulü teslimat kapılarıdır.
Create/peer kapıları bu kaynak eklendi diye açılmaz. Eski hizmet/hesap/pairing,
key ACL veya trust store değiştirilmedi; yeni tam yedek alınmadı.

## Test kanıtının anlamı

Native WinPS5.1 fixture yeni geçici non-exportable CNG key, özel yerel journal,
sentetik GPO envanteri ve simüle edilmiş AD/içerik observations kullanır.
Bağlantı nesli, tekrar/reload, imza hatası, bozuk dosya/ACL, hardlink/ADS/reparse,
korunan GPO, PDC hareketi ve yol türetme sınırları sınanır. Yerel test imzalayıcısı
ile sabit AllSigned helper'ın yanlış config'i AD'ye erişmeden reddettiği ve
timeout'lu child'ın sınırlandırıldığı kontrol edilir. Oluşturulan fixture sertifika
ve trust girdileri temizlenir. Gerçek müşteri gMSA/AD kabulü yapılmış sayılmaz.
Windows RSA proof/target çıktısı mevcut Python verifier'ı ile ayrı çapraz kontrolden
geçirilir. Nihai CI head/sonuçları kaynak checkpoint'ine ayrıca kaydedilir.
