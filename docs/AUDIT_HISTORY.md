# İşlem geçmişi — dev.8 aday işletim notu

İzleme → İşlem geçmişi mevcut yönetim kayıtlarını salt okunur inceler. Bu
özellik RADIUS erişim kararı veya accounting kaydı toplamaz. Mevcut RADIUS
adapter sonucu kalıcı erişim tablosuna yazılmıyor; auth log kapalı ve accounting
etkin değil. Okunabilen son24saat journal çıktısının boş olması, hiç kimlik
doğrulaması yapılmadığını veya hata olmadığını kanıtlamaz.

## Kaynaklar ve yetkiler

- Yapılandırma/sertifika geçmişi: audit.events okuma izni. Eski /api/audit
  uç noktası uyumluluk için son100 kaydı döndürmeye devam eder.
- Panel hesap işlemleri: audit.events ve system.administrators okuma izni
  birlikte gerekir. Yalnız admin profili okuma hakkı bu kaynağı açmaz.
- Kayıtta işlem yapan yoksa Kaydedilmemiş gösterilir. Eski kayda bugünün
  kullanıcısı veya bir cihaz adı atanmaz. Panel hesap kaydındaki actor/target
  kimlikleri, kaynakta tutulan ID'lerdir; tarihsel kullanıcı adı iddiası yoktur.
- service_action_requested bir talep kanıtıdır. İşlemin tamamlanma sonucu
  Servisler ekranındadır; bu kayıt Access-Accept veya başarılı restart sayılmaz.

## Filtreleme ve sayfalama

Kaynak, tarih, tam olay kodu ve olay/seri/talep içeriğinde metin aranabilir.
Olay kodu, iki nokta ile devam eden referans/actor eklerini de kapsar. Metin
araması SQL jokerlerini yorumlamaz; SQLite lower ile ASCII harf duyarsızdır,
Türkçe harfler için tam Unicode casefold garantisi yoktur. Cihaz hostname'i,
VLAN veya gerçek RADIUS ret nedeni mevcut satırda yoksa bunlara göre sonuç
üretilmez. Başlangıç/bitiş günleri tarayıcının yerel saatinde yorumlanır;
API zamanları timezone içeren ISO biçimindedir; from dahil, to hariçtir.

En fazla100 kayıt, azalan kayıt ID'siyle gelir. Daha eski kayıtlar son ID ve ilk
sayfanın üst sınırıyla okunur; bu sırada yeni eklenen kayıtlar sayfaları
kaydırmaz. Uygula / En yeni kayıtlar yeni bir okuma başlatır. Kaynak/filtre
değişince eski sayfanın indirmesi kapanır. İki saniye sorgu bütçesi aşılırsa
filtre daraltılır; otomatik tekrar yazma veya sınırsız sorgu yapılmaz.

## CSV ve saklama

Bu sayfayı CSV indir yalnız görünen en fazla100 satırı indirir. UTF-8 BOM ve
standart çift tırnak kaçışı vardır; formül başlatabilecek hücrelere apostrof
eklenir. İndirme sunucudaki kayıtları silmez, taşımaz veya arşivlemez. ID,
UTC zaman, kaynak, olay, mevcut actor/target/reference, sürüm ve servis talep
alanları dışında key/session/parola veya ham JSON payload dışa aktarılmaz.

Saklama bilgisi kaynak toplam satır sayısı, ilk/son kayıt zamanı ve bütün
SQLite dosyasının boyutunu gösterir. Bu sayı filtrelenmiş sonuç toplamı
veya sadece audit verisinin kapladığı alan değildir. Önceden var olan append-only
trigger'lar korunur; yeni şema, indeks, silme komutu veya retention timer yoktur.
Günlük doğrulanmış AuthWire yedekleri DB'leri kapsar; off-host hedef hâlâ açık.

### Excel'de sütunlara ayırma

CSV virgül ayırıcılıdır. Excel dosyayı açarken yerel ayarlar nedeniyle her
satırı tek hücrede gösterebilir. Veri → Metin/CSV'den ile dosyayı seçip
UTF-8 kodlaması ve Virgül ayırıcısı kullanın; yüklemeden önce önizlemede
alanların ayrı sütunlara bölündüğünü doğrulayın. Alternatif olarak mevcut
A sütununu seçip Veri → Metni Sütunlara Dönüştür → Sınırlandırılmış,
yalnız Virgül ve çift tırnak metin niteleyicisi seçilebilir. Windows'un genel
bölge ayarını değiştirmek gerekmez. Tek sütun gözlemi, tek başına sunucu
kayıtlarının bozulduğunu veya eksildiğini göstermez.

## B11 açık iş sırası

1. Teknik canlı kabul ve operatör sürüm/CSV indirme kontrolü tamamlandı;
   Excel'de ayrı sütunlarla okuma kabulü bekliyor (18 Ekim22:18 gözlemi).
2. Final native RADIUS Accept/Reject için sınırlı, dayanıklı yapılandırılmış
   olay toplama; sertifika callback allow sonucu tek başına EAP başarı kanıtı
   değildir. Callback öncesi TLS/CRL retleri ve tekrar paketleri de ele alınmalı.
   Kimlik alanı doğrulanmamışsa unknown; outer identity güvenilir kimlik olmaz.
3. RADIUS accounting protokol doğrulaması ve gerçek NAS Start/Interim/Stop,
   tekrar/sırasız mesaj, yeniden başlatma ve oturum korelasyonu testleri.
4. Müşteri saklama süresi ve archive/retention tasarımı: doğrulanmış dış
   arşiv, tamlık/geri okuma ve yetki/işlem kaydı kabulünden sonra kontrollü
   temizlik. Mevcut append-only engelleri doğrudan kaldırılmaz.

Bu kabul tamamlanana kadar B11'in tamamı tamamlandı sayılmaz. Çalışan
kimlik doğrulama hattında yeni olay toplama ayrı kod/runtime kabulü gerektirir.
