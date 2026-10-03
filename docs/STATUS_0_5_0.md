# KANAME 0.5.0-dev.1 — tamamlanma kaydı

Tarih: 4 Ekim 2026 (Europe/Istanbul).
Yayın commit'i: d646462bb8791c36d718fca661a2c82daea15d55.

## Teslim edilen davranış

- Sol menü başlıkları akordiyon olarak açılır/kapanır; yetkiye göre görünür.
- System altında Administrators ve Admin Profiles ayrı sekmelerdir.
- User&Authentication altında Active Directory bağlantı ekranı ve Users/User Groups katalog ekranı bulunur.
- Users ve User Groups aynı ekranda, bağımsız arama ve sayfalama ile listelenir.
- Kullanıcı adına tıklanınca Member of; grup adına tıklanınca Members detayları açılır. Detaydan karşı kullanıcı/grup detayına geçilebilir.
- Doğrudan, primary ve iç içe grup ilişkileri ayırt edilir. Büyük grup member aralıkları denetlenerek okunur; distribution grupları listelenirken politika seçicisi yalnız security gruplarını gösterir.
- Eski katalog üyelik bilgisi içermiyorsa boş üyelik sonucu gösterilmez. Yeni bilgi için Active Directory ekranından bir kez yeniden okuma gerekir.
- Bağlantı ile katalog okuma yetkileri ayrı yönetilir; eski Custom profillerin mevcut hakları korunur. API detayları da yetki denetiminden geçer.
- Yönetim verileri yüklenirken mevcut satırların düzenleme/silme işlemleri dahil eylemler bekletilir; eski oturumdan geciken yanıtlar yeni oturumu etkilemez.

## Son yayın kontrolleri

| Kontrol | Sonuç | GitHub kaydı |
|---|---|---|
| Linux test/syntax | 208 test; 201 başarılı, 7 Windows özel testi atlandı | [Foundation](https://github.com/Asitavandas/kaname/actions/runs/37158728084) |
| Windows bağımsız doğrulama | 208 test; 206 başarılı, 2 atlandı | [Windows](https://github.com/Asitavandas/kaname/actions/runs/37158728062) |
| Chromium panel akışları | Başarılı; akordiyon, ayrı sekmeler, karşılıklı üyelik detayları, CRUD ve yetki sınırları | [Browser](https://github.com/Asitavandas/kaname/actions/runs/37158728070) |
| Windows update ön kontrolü | 208 test; 206 başarılı, 2 atlandı | [Update](https://github.com/Asitavandas/kaname/actions/runs/37158728046) |
| Windows yedek/güncelleme/tanılama | Başarılı; HTTP 200, kaynak ve durum eşleşiyor | [Update](https://github.com/Asitavandas/kaname/actions/runs/37158728046) |

Önceki kaynak hazırlama kontrolünde bir localhost HTTP olumsuz yetki testi zaman aşımına uğradı. Aynı kaynakla yeniden çalıştırma başarılı oldu; son yayın commit'inin iki Windows kontrolü de geçti. Testi kapatma veya zaman aşımı sınırını büyütme yapılmadı.

LDAP fixture kontrolleri Windows helper'ın primary grup ve üye aralığı okumasını doğruladı. Tarayıcı testi geçici katalog kullandı. Bu güncellemede gerçek AD kimlik bilgileri kullanılmadı ve gerçek domain üyelikleri tarafımızdan kabul edilmiş sayılmadı.

## Windows kurulum sonucu

Kurulu sürüm 0.5.0-dev.1; 66 dosyalık kaynak manifestinde eksik/değişmiş dosya yok. Kaynak ve yerel durum yedeği oluşturuldu. Config, politikalar, CA, erişim token'ı, AD kataloğu ve panel hesap/profil verileri güncelleme öncesi/sonrası korundu.

Mevcut panel hesapları yeniden oluşturulmadı; varsayılan admin/Kaname parolası tekrar denenmedi veya sıfırlanmadı. Operatör mevcut hesabıyla giriş yapmalıdır. Tanılama HTTP 200, kaynak sürümü ve yerel durum eşleşmesi ile üç etkisiz politika simülasyonunu doğruladı. Revision 11, 1 politika (0 etkin), CA mevcut. real_ad_tested=false bu otomasyonun gerçek AD kullanmadığını belirtir; operatörün önceki başarılı AD okumasını geçersiz kılmaz.

## Operatör kontrolü

1. http://127.0.0.1:8765/ adresini açıp Ctrl+F5 ile yenile.
2. Mevcut panel hesabıyla giriş yap.
3. User&Authentication → Active Directory ekranında Bağlan ve bilgileri getir ile kataloğu bir kez yenile.
4. Users/User Groups ekranında bir kullanıcı ve bir grup adına tıklayarak iki yöndeki üyelikleri kontrol et.
5. Akordiyon menüyü ve System altındaki ayrı Administrators/Admin Profiles sekmelerini kontrol et.

AD parolası kalıcı kaydedilmez. Başarısız okuma mevcut kataloğu korur. Yapısal üyelik gösterimi Windows erişim token'ı veya gerçek ağ kimlik doğrulaması kanıtı değildir. Kapsam/limitler için [AD üyelikleri](DIRECTORY_MEMBERSHIP.md).

## Sonraki kapsam ve duraklama

Gerçek RADIUS/EAP, AD ile doğrulanmış istemci enrollment, üretim HTTPS/servis, Linux AD adaptörü ve açılabilir OVF sonraki aşamalardır. Switch/AP yönetimi ve entegrasyon testleri kapsam dışıdır; cihazları operatör elle yapılandırır.

Bu sürüm tamamlandı. Operatöre “Soruların veya değiştirmek/düzenlemek istediğin yerler var mı?” sorulacak; yanıt gelmeden sonraki sürüm/özellik çalışmasına geçilmeyecek.
