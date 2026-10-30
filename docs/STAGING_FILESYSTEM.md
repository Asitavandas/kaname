# Sınırlı dosya yazma/geri alma çekirdeği

29 Ekim 2026. `StagingFilesystem.ps1` yalnız kaynak/test bileşenidir. Mevcut
Connector paketinin dosya listesine, çalışma döngüsüne veya panel/API görevlerine
eklenmez. Müşteri ortamında çalıştırılacak komut veya yeni yetki sunmaz.

Çekirdek, mevcut 20 dosyalı önizlemeyi yeniden üretip onaylanan SHA256 ile
eşleştirir. 90 saniyelik süre, kaynak boyut/hash/ACL listesi, tam kaynak ağacı,
beş öğeli boş GPO tabanı ve korunan GPO ayrımı yazmadan önce denetlenir.
Kaynak/hedef/journal yolları yalnız güvenilen çağıran bileşen girdileridir;
gelecekte ağ isteğinden bu parametrelere yol veya komut geçirilemez.

## Yazma ve kayıt

Yerel journal kökü önceden yalnız servis kimliği/SYSTEM/Administrators erişimiyle
ve korumalı DACL ile hazırlanmış olmalıdır; modül mevcut izinleri gevşetmez.
İşlem GUID klasörü ve `intent.json` yeni oluşturulur. Intent flush edilmeden
GPO ağacına dokunulmaz. Yalnız önizlemeden türeyen yeni
`Machine/AuthWire-<plan>-v<sürüm>-<manifest>` klasörü ve onun 20 dosyası oluşturulur.
Mevcut klasör veya dosya üzerine yazılmaz; tekrar yürütme yeni yazma yapmaz.

Win32 handle'ları kaynak dosyaların yazılmasını/yeniden adlandırılmasını engeller,
yol üstündeki dizinleri sabitler. Reparse point, ek NTFS veri akışı, hardlink,
eksik/fazla dosya, kaynak veya taban farkı reddedilir. Sonuçta gerçek hedef
dosyaların hash/ACL/volume-file kimlikleri ve değişmeyen dış GPO tabanı
`complete.json` kaydına flush edilir. Hedef ACL'leri SYSVOL'dan miras alınır;
yerel kaynak ACL'leri hedefe kopyalanmaz, ayrıca sahiplik kaydına bağlanır.

## Geri alma

Çağıran, tamamlanmış journal'ın beklenen SHA256'sını ayrıca sağlamalıdır.
Tam hedef ağaç, dosya kimlikleri, hashler, boyutlar ve ACL'ler eşleşmeden hiçbir
silme başlamaz. Silme yalnız sabitlenmiş sahip olunan handle'lar üzerinden
yapılır; recursive/pathname delete kullanılmaz. Başka dosya, stream veya izin
farkında işlem durur. Kayıtlar geri alındıktan sonra da saklanır.

### Geri alma süre kapısı — 30 Ekim 2026

Geri alma çekirdeği her çağrıda pozitif `NotAfter` ister. Eksik/sıfır/geçmiş veya
çağrı başlangıcından 30 saniyeden uzak sınır silme başlatmadan reddedilir. Bu değer
yeni bir izin üretmez: gelecekteki kimliği doğrulanmış adapter özgün CLAIM bitişini
aynen sağlamalıdır. Kaynakta bu adapter henüz yoktur; bu alt adım onu tamamlamaz.

Hem UTC hem aynı süreçteki monoton sayaç denetlenir. Kontroller, hazırlık sonrası,
`rollback-started.json` flush öncesi/sonrası, her tekil native handle silmesinden
önce/sonra, taban envanteri ve sonuç flush çevresinde yapılır. Monoton süreyi
yeniden başlatmak veya duvar saatini geri almak bütçeyi uzatamaz. Eski sınırsız
`DeleteOwnedTree()` girişi kaldırıldı; native silme de son tarihi zorunlu tutar.
V2 başlangıç kaydı özgün complete hash'ini, başlangıç ve bitiş zamanını saklar.

Başlangıç kaydı yazılmışsa süre dolması, kısmi silme, postcheck veya tamamlanma
flush hatası otomatik tekrar edilemez. Yeni bir son tarih de bu kaydı aşamaz.
Yazılan journal ve kalan dosyalar inceleme için saklanır. Dosyalar silinmiş fakat
sonuç doğrulanamamış olabilir; hata, sıfır etki veya başarı olarak yorumlanamaz.
Bu bir SMB atomik işlem ya da kesin I/O iptal garantisi değildir: başlamış tekil
uzak çağrı son tarihten sonra tamamlanabilir. Sınırlı child süreci, parent gözlemi,
ayrı rollback onayı/tüketimi/RESULT ve yeniden başlatma uzlaştırması hâlâ gerekir.

Windows testi özgün native gövdeyi ve gerçek geçici SMB/NTFS'yi kullanır. Dört
ayrı kesinti (marker öncesi, marker flush sonrası, postcheck, completion flush),
eksik/geçersiz süre, monoton/UTC sapması, read-only lease ve taze süreyle replay
reddi sınanır. Native gövdenin yalnız test namespace'ine kopyasında ilk gerçek
silmeden sonra gecikme eklenir; süre dolunca sonraki dosyalara dokunulmadığı
gösterilir. Ürün koduna test gecikmesi/saat override'ı eklenmez. Bağımsız vakalar
arasında yalnız fixture'ın oluşturduğu alan temizlenir; ürün cleanup API'si yoktur.

## Açık sınırlar

- Hash parametresi kimlik doğrulama/operatör onayı değildir. Yetkili panel
  oturumu, typed yazma onayı, pairing nesli, idempotency ve yeniden oynatma
  koruması bu çekirdeğin üstündeki gelecek adapter'da zorunludur.
- Canlı AD/PDC/GPO/link/sürüm, imza ve bağımlılık kontrolü güvenilen adapter
  tarafından yazmadan hemen önce yeniden yapılmalıdır. Çekirdek bunların
  gerçekleştiğini tek başına iddia etmez.
- Kesinti/kısmi I/O hatası veya tamamlanma kaydı yazılamaması intent'i ve varsa
  kısmi klasörü inceleme için bırakır. Otomatik resume veya kısmi ağaç temizliği
  uygulanmaz; tamamlanmamış işlemde sahiplik tahmin edilerek silme yapılmaz.
- Ayrıcalıklı eşzamanlı yönetici müdahalesine karşı SMB transaction/atomik GPO
  snapshot garantisi yoktur. Silme sırasında yeni yabancı çocuk oluşursa dizin
  silme hata verir; yabancı çocuk silinmez, kısmi durum incelenir.
- GPO link/startup kaydı/sürüm güncellemesi/çoğaltma ve endpoint yürütmesi yoktur.
  Yeni modül servis paketine eklenmeden önce bu açık kapılar ayrı değerlendirilir.

## Doğrulama

`staging_filesystem_windows_check.ps1` mevcut 40 önizleme kontrolünü korur ve
yalnız kendi oluşturduğu geçici NTFS/SMB alanında gerçek yazma, sahiplik kaydı,
geri alma, bayat/yanlış onay, korunan GPO, kaynak/taban/hash/ACL/ADS farkı,
tekrar istek ve tamamlanma kaydı hatası senaryolarını sınar.
Müşteri AD'si, kalıcı servis, sertifika veya cihaz ayarı kullanılmaz/değiştirilmez.
CI sonucu test edilen commit ile ayrıca kaydedilir; kaynak/test başarısı canlı
müşteri staging veya ürünün tamamlanması olarak yorumlanmaz.
