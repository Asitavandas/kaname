# Birleşik paket staging önizlemesi

28 Ekim 2026. Kaynak bileşenidir; canlı worker'a/panele henüz yüklenmedi.
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
karşı atomiklik garantisi değildir. Kalıcı worker entegrasyonundan önce çağrı
mevcut bounded AllSigned child içine alınmalıdır. Şu an canlı iş/protokol
route'u ve üretim teslimatı yoktur; doğrudan servis üzerinde çalıştırılmamalıdır.

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
