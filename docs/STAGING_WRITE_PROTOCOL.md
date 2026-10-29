# Yazma/geri alma görevlerinin onay ve yetkilendirme çekirdeği

29 Ekim 2026. `kaname/staging_write_jobs.py` yalnız kaynak/test bileşenidir.
server.py içine, canlı API'ye, panele veya Windows paketine kaydedilmedi.
StagingFilesystem.ps1 çağrısı veya gerçek dosya yazması yapmaz. Bu ilk protokol
katmanının geçmesi, uçtan uca yazma/geri alma iş akışının tamamlanması değildir.

## Güven sınırları

Sınıf mevcut Connector binding ve RSA çerçeve doğrulamasını kullanır; ayrı
POLL/CLAIM/RESULT amaçları ve yolları vardır. Eski okuma kanalı çerçeveleri
yazmayı yetkilendiremez. İmzalı payload1024, zarf4096 baytla sınırlıdır.
POLL cevabı onaylanan20 dosyalı önizlemeyi de taşır; Windows adapter'ında
cevap boyutu ve kesin şema denetimi ayrıca uygulanmalıdır.

Bu sınıfın yönetici çağıranı güvenilir iç servistir: actor UUID ve ack metni
kimlik doğrulama değildir. Gelecek HTTP adapter'ı certificates.authority ve
system.connectors yazma yetkilerini, güncel oturumu, Origin/CSRF ve revizyonu
zorunlu uygulamalıdır. Bu adapter ve testleri henüz yoktur.

## Sıra

1. Ayrı yazma/geri alma incelemesi: güncel aday ve kabul edilmiş içerik,
   binding nesli, scope/SID özeti, worker sürümü, taze90 saniyelik dosya/hash/ACL
   önizlemesi ve yönetici kimliği inceleme SHA256'sına bağlanır. Yazma ve silme
   farklı ack metni ister. İstekte yol veya komut kabul edilmez.
2. Create aynı SQLite transaction'ında tekrar doğrular, tek job UUID'sini ve
   aktörü audit'e kaydeder. Aynı istek tekrarında yalnız kayıt durumu döner;
   yetki anahtarı veya ikinci yürütme verilmez. ID başka aktör/istekle kullanılamaz.
3. POLL işi yalnız bir kez lease eder. Cevap write_authorized=false'dur.
   Kaybolan offer veya biten lease otomatik yeniden teslim/yürütme oluşturmaz.
4. Gelecek Windows adapter'ı yerel durable job kaydını ve canlı AD/GPO/imza/
   kaynak kontrollerini yaptıktan sonra ayrı RSA CLAIM gönderir. Protokol
   hedef ve bağımlılıkları tekrar doğrular. Tek transaction'da en fazla30 saniye
   geçerli bir yetkilendirme üretir; GPO activation izni daima false kalır.
5. Aynı CLAIM'in tekrarı, yeni nonce'lu tekrarı ve iki eşzamanlı CLAIM'den
   ikincisi yetki alamaz. CLAIM cevabı kaybolursa worker dosyaya dokunmaz;
   sunucudaki durum sonucu belirsiz olarak inceleme bekler.
6. İmzalı sonuç; asıl job/lease/intent/target/sürüm/yetkilendirme kimliğine
   bağlıdır. Yetkilendirme süresi içinde gözlenen sonuç en çok300 saniyelik
   transport gecikmesiyle kaydedilebilir. Bu yeni yürütme izni değildir.
   Plan sonradan değişse bile eski işin sonuç kanıtı kaybedilmez. Kesinti/kısmi
   hata daha geç gözlenebilir: deadline+300 saniyeye kadar gözlenen belirsizlik
   kanıtı ayrıca kaydedilebilir, ancak kilidi açmaz veya yeni izin vermez.

## Sahiplik ve belirsiz durum

Durumlar queued, leased, authorized, completed ve requires_review'dür.
authorized fiziksel yazma gerçekleştiğini değil, iznin verildiğini gösterir.
Zaman aşımı veya binding iptali/yeniden eşleştirme yetkilendirilmiş işi sessizce
expired/obsolete yapıp unutmaz. Aynı GPO'da yeni işler inceleme bitene kadar
engellenir. Yetki verilmiş bir iş, basit bir "yazmadım" boole'uyla kilidi açamaz.

Geri alma için ayrı operatör onayı ve aynı binding altında tamamlanan stage
işinin journal ve staged-tree SHA256'sı gerekir. Eski önizleme zamanı geçmiş
olabilir; bu, rollback öncesi canlı AD/GPO/sahiplik kontrolünü kaldırmaz.
Yanlış stage, farklı ağaç veya tekrar geri alma reddedilir. Tamamlanan stage,
geri alma sonucu kaydedilmeden aynı GPO'da yeni stage'i engeller.

Sonuç sadece doğrulanan Connector'ın bildirimidir; diskin uzaktan attestation'ı,
GPO etkinleştirmesi veya müşteri kabulü olarak sunulmaz. Kısmi/IO/journal hatası
requires_review bırakır. Manuel reconciliation, kesilmiş transaction temizliği
ve güvenli resume/unblock henüz uygulanmadı; bunlar teslimat öncesi kapılardır.

## Kalıcılık ve kaynak sınırları

Yeni runtime ledger'ı1MiB,32 kalıcı iş ve128 canlı transport nonce ile sınırlı.
İş ID'leri kendiliğinden budanmaz; dolunca kapalı hata verir. Audit ile state
aynı SQLite transaction'ındadır. Poll metadata'sı kendi TTL'siyle temizlenir.
Mevcut512 hedef sözleşmesi korunur;1000 hedef parçalama desteği bu değişiklikte yoktur.

Kurulu backup worker yeni ledger'ı henüz tanımaz; hiçbir alanı kararlılık
karşılaştırmasından sessizce çıkarılmaz. Dağıtımdan önce yalnız doğrulanmış
transport metadata'sı için kesin projection eklenmeli; bütün onay, hedef,
authorization ve sonuçlar yedekte/iş verisi karşılaştırmasında korunmalıdır.

## Teslimat öncesi açık işler

- Yetkili HTTP/panel inceleme ve onay akışı; rol/oturum/Origin/CSRF testleri.
- Sınırlandırılmış Windows proof/claim ve canlı scope adapter'ı; yerel durable
  iş kaydı, kayıp CLAIM yanıtında durma, filesystem core'a güvenilen yol türetme.
- Stage/rollback ve journal kayıtlarıyla sonuç uzlaştırma; partial cleanup/resume
  ve yanlışlıkla ikinci yürütmeyi önleyen kurtarma testleri.
- Yeni ledger'ın backup poll projection'ı, source teslimi ve gerçek gMSA/SMB kabulü.
- Ayrı GPO aktivasyon/çoğaltma ve endpoint kabul kapıları.

36 yeni yerel RSA/SQLite testi ve mevcut ilgili okuma/proof testleriyle toplam90
kontrol geçti. Tam repo CI ve test edilen kaynak head'i checkpoint'te ayrıca
kaydedilir. Müşteri AD/GPO/servis/sertifika veya diskine değişiklik yapılmadı.
