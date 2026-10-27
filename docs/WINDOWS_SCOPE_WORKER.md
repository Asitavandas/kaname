# Windows Connector: salt okunur AD/GPO kontrolü

Bu bileşen, dev.40 kapsam görevi kanalını Windows hizmetine ekler. Kalıcı hizmet
mevcut hesabı, eşleştirmeyi ve kanal anahtarını kullanır. `can_apply=false` kalır.

## Kontrolün kapsamı

1. Panele kayıtlı adayın sabit dizinindeki onay, imzalı manifest ve profil ZIP'i
   mevcut salt okunur aday doğrulayıcıyla yeniden doğrulanır.
2. AD etki alanı SID'i ve Connector bilgisayarının GUID/DNS kimliği doğrulanır.
   Seçilen güvenlik grubunun iç içe grupları ve primaryGroupID üyelikleri okunur.
   Tüm bilgisayarların SID kümesi, panelin tam hedef kümesi özetiyle karşılaştırılır;
   ilk 20 satırlık önizleme kullanılmaz. Devre dışı, çözülemeyen, yabancı veya
   değişen bilgisayar hedefi kabul edilmez.
3. Yönetilen GPO'nun kimliği, sahiplik işareti, sahibi, yedi izin kaydı, linksiz
   olması, ayar uzantısı bulunmaması ve dört sürüm sayacının sıfır olması kontrol edilir.
4. SYSVOL kökünün sahibi, korumalı DACL'i, sekiz izin kaydı ve dört kök girdisi
   kontrol edilir. Reparse point kabul edilmez.
5. Aynı okuma ikinci kez yapılır; normalleştirilmiş özet değişirse sonuç reddedilir.
   Son olarak aday içerik tekrar kontrol edilir.

Bu kontrol alt dizinlerdeki bütün dosyaların envanteri, etkili yazma yetkisi testi,
GPO staging/bağlama/uygulama veya gerçek istemci kabulü değildir. GPO boşluk kontrolü
rapordaki ayar/sürüm alanları ve kök görünümüyle sınırlıdır. Gerçek DC01 üzerinde
Connector hesabıyla başarılı okuma, Windows güncellemesi sonrasında ayrıca beklenir.

## Sınırlar ve hata sonucu

İş yalnız kimlik ve SHA256 alanları alır; istekle komut, dosya yolu, LDAP filtresi,
URL veya betik verilemez. Sabit imzalı okuyucu temiz Windows PowerShell 5.1
alt sürecinde `AllSigned` ile çalışır. Ebeveyn hizmetin Windows Job nesnesi
alt süreçleri hizmet kapanışında sonlandırır.

Okuma bütçesi en fazla 30 saniyedir ve kalan görev süresinden kısadır. Süre aşımında
alt süreç öldürülür; çıkış/akış toplama ayrıca sınırlıdır. Stdout 8192, stderr 2048
karakterle sınırlıdır; uzun tek satır da sınırsız biriktirilmez. AD kapsamı 128
ziyaret edilen grup, 4096 üyelik kenarı, 512 bilgisayarla sınırlıdır. AD cmdlet
çağrısı takılırsa toplam alt süreç süresi bu çağrıyı da sınırlar.

Başarıda yalnız kontrollerin adları, okuma zamanı ve normalleştirilmiş gözlem özeti
panele gönderilir. Hatalar `CONTENT_REJECTED`, `DIRECTORY_SCOPE_CHANGED`,
`GPO_SCOPE_CHANGED`, `READ_TIMEOUT` veya `READ_FAILED` olarak bildirilir. Ham AD
çıktısı ve hata metinleri ağa gönderilmez. Panelin başarı tazeliği 90 saniyedir.

## Güncelleme ve doğrulama

DC01 teslimatı önce ayrı bir imzalı aday paket hazırlar (`Prepare`). Çalışan hizmet
bu aşamada değiştirilmez. `Apply` mevcut hizmeti kontrollü geçirir; kabul için yeni
sürümün sağlık, test, içerik ve kapsam kanallarının hepsi çalışmalıdır. Başarısız
geçişte doğrulanmış önceki paket geri getirilir. Aday içeriği doğrulayan b5469eaa
sürümü ve önceki iki sürüm ailesi yalnız dondurulmuş kaynak özetleriyle tanınır.

CI'da gerçek WinPS 5.1 ayrıştırma, saf 200 bilgisayar doğrulaması, grup sorgusu
şekli, süre/çıktı sınırları, AllSigned reddi, gerçek düşük yetkili SCM hizmeti ve
TLS/imzalı sonuç gidiş dönüşü test edilir. AD ormanı olmayan CI'daki grup/GPO
verileri simüledir; müşteri ortamı kabulü olarak sayılmaz. Negatif kapsam görevi
fixture'ı, yalnız öncül içerik bağımlılığını simüle ederek eksik adayın gerçek imzalı
okuyucu tarafından reddedildiğini sınar. Anahtar ACL'si ve CLR metadata işareti
okunarak korunur; anahtar tamiri, yeniden üretimi veya dışa aktarımı yapılmaz.
