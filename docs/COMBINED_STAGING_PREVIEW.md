# Birleşik paket staging önizlemesi

İlk kaynak kaydı 28 Ekim 2026. Güncelleme 29 Ekim: Linux dev.44 ve Windows df28f70c teslim edildi;
operatör 11:36:38 Europe/Istanbul zamanlı 20 dosya/102464 bayt hazırlık önizlemesini panelde görüntüledi.
Kanıt: checkpoints/2026-10-29-customer-staging-preview-browser-accepted.json.
Bu kabul yalnız salt okunur önizlemeyi kapsar; yazıcı/staging/geri alma ve GPO/endpoint uygulaması henüz yoktur.
Bu modülde SYSVOL yazıcısı, dosya silme, GPO aktivasyonu veya yürütme token'ı yoktur.

## Tek işlem ve sabit kapsam

CombinedStagingPreview.ps1 aynı birleşik aday için 20 dosyanın tam listesini
çıkarır. Yerel yol CommonApplicationData + Connector/plan/draft/template kimliklerinden
üretilir. İstek kaynak veya hedef yolu/komut belirleyemez. Manifest/draft pinleri,
tam dosya seti, byte sayıları, SHA256 ve mevcut kaynak ACL'leri önizlemeye bağlanır.
Dosya başına 1MiB/toplam 4MiB üst sınırı vardır; boş/ilave/eksik/tekrarlı/alternatif
case/path/ADS girdileri reddedilir. İmzalar ve gövdeler mevcut birleşik içerik
doğrulayıcısıyla önce/sonra yeniden doğrulanır; PS1 dosyaları çalıştırılmaz.
İmzalama veya channel özel anahtarı açılmaz.

Hedef yalnız yönetilen GPO'nun **Machine/AuthWire-<plan GUID N>-v<sürüm>-<manifest SHA256>**
altındadır. Mevcut dosyaya üzerine yazma ve keyfi konum kabulü yoktur.
Geri alma önerisi yalnız o yeni klasörle sınırlıdır; ownership journal, tam
staged-tree hash/ACL eşleşmesi ve drift halinde inceleme gerektirir. Bu tanım
gerçek bir geri alma uygulandığı anlamına gelmez.

## Canlı okuma adapter'ı

Get-AuthWireCombinedStagingPreview yalnız doğrulanmış, admin olmayan servis SID'si
ile çalışır. Mevcut combined scope hedef/approval, imza/bağımlılık, AD hedefleri,
GPO marker/izin/link/sürüm ve boş SYSVOL kontrollerini yeniden kullanır.
PDC/domain doğrulanmış AD kaydından türetilir. İki kapsam, iki tam dosya/ACL
envanteri ve iki kaynak ledger'ı eşleşmelidir; PDC ve içerik sonunda tekrar
kontrol edilir. Envanterde tek bir yabancı alt dosya bile varsa öneri reddedilir.
Önizleme checked_at/expires_at ile 90 saniyeye bağlıdır; SHA256 hedefi, kaynak
dosyaları, kapsam gözlemlerini, envanteri, hedefi ve rollback koşullarını kapsar.

Bu çift okuma SMB transaction/snapshot veya eşzamanlı ayrıcalıklı değişikliklere
karşı atomiklik garantisi değildir. Yeni worker kaynağı çağrıyı sabit dosyalı,
AllSigned, en fazla 30 saniyelik ayrı WinPS sürecinde çalıştırır. Üretim
teslimatı ve gerçek müşteri gMSA kabulü ayrıca izlenir.

## Yetki ayrımı

Pure New-AuthWireCombinedStagingPlanCore yalnız veri projeksiyonudur; elle
verilmiş girdilerle yazma yetkisi kazanılamaz. Çıktıda daima read_only=true,
can_stage=false, can_apply_gpo=false, writer_available=false ve
requires_new_write_approval=true bulunur. Yetkili typed write-preview/iş akışı,
freshness/idempotency/journal, kısmi hata temizliği, gerçek staging/rollback,
GPO link/startup/sürüm/çoğaltma ve endpoint kabulü sonraki kapılardır.

## Test sınırı

Native WinPS5.1 fixture sentetik yerel aday ve gerçek geçici NTFS/SMB paylaşımını
kullanır. Hash/ACL drift, tam dosya seti, boyutlar, yol reddi, mevcut UNC yasağı,
boş GPO ağacının korunması ve önerinin yazma izni vermemesi sınanır. Fixture
dosyaları imzalı müşteri paketi veya gerçek AD değildir. Canlı adapter'ın gerçek
müşteri gMSA kabulü, paketin yazılması veya geri alınması bu testten çıkarılmaz.

## Panel ve görev protokolü

Ayrı combined.staging.preview.v1 işlemi yalnız doğrulanmış birleşik içeriği
ve güncel dizin hedeflerini kabul eder. Görev hem certificates.authority hem
system.connectors yetkisi, güncel oturum, Origin/CSRF ve revizyon kontrolü
gerektirir. İş kimliği/idempotency, pairing nesli, RSA kanıtı, tekrar oynatma,
300 saniyelik görev/90 saniyelik lease ve güncel hedef kontrolleri korunur.
Kullanıcı kaynak/hedef yol veya komut gönderemez.

Panelde Paket hazırlığını önizle → Hazırlık önizlemesini gönder akışı bulunur.
Sonuç sabit göreli klasörü, 20 dosyanın boyut/hash listesini, öneri SHA256'sını,
90 saniyelik güncellik durumunu ve geri alma sınırlarını gösterir. Eski öneri
kayıtlı kalır; yeni yazma yetkisi veya uygulanmış dağıtım olarak gösterilmez.
Bağlantı yanıtı kaybolduğunda aynı istek otomatik tekrar gönderilmez; görev
listesi salt okunur yenilenerek kayıt uzlaştırılır. Salt okunur rol sonuçları
görebilir, yeni görev oluşturamaz.

Yeni /api/connector/v1/staging-preview/result yolu tek başına 32768 bayt
zarf/16384 bayt imzalı payload kabul eder. Poll ve eski tüm yolların
4096 bayt zarf/1024 bayt payload sınırı değişmez. Child stdout sınırı yalnız
yeni önizlemede 16384 karakterdir; eski scope 8192 ve stderr 2048 kalır.
En fazla 20 bilinen dosya, 1MiB/dosya, 4MiB toplam, tam ACL/hash ledger'ı
ve WinPS sıralı JSON SHA256'sı Linux'ta tekrar doğrulanır.

windows_staging_preview_jobs kaydı en fazla 1MiB/32 görevdir. Yedekleme
kararlılık karşılaştırması yalnız doğrulanmış polls/last_poll alanlarını
yok sayar; tüm görev ve sonuç içeriği yedekte ve karşılaştırmada korunur.
Eski kuyrukların 100000 karakter sınırı değişmez. Kaynak worker güncellemesi
kurulu backup worker'ın güncellendiği veya yeni yedek alındığı anlamına gelmez.

Yeni paket dört sabit önizleme dosyasını ekler. Yeni Apply bu altıncı kanalın
sağlığını da ister; eski pakete geri dönüş eski kanal koşullarını korur.
Önceki imzalı sürümler kendi sabit gövde hash listeleriyle tanınır. Tarihsel
teslimat arşivleri yeniden üretilmez veya yeni kaynakmış gibi yorumlanmaz.
