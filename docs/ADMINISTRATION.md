# KANAME panel yönetimi — 0.5.0-dev.1

## Menüler

Sol menü başlıkları akordiyon biçimindedir. Başlığa tıklayınca alt sekmeler açılır/kapanır; bir başlık açılınca diğeri kapanır. Yetkiniz olmayan sekmeler gösterilmez.

## Giriş

`http://127.0.0.1:8765/` adresinde kullanıcı adı/parola formu açılır. İlk kurulum **admin / Kaname** hesabıyla giriş yapılır. Bu hesap AD hesabı değildir. Günlük girişte PowerShell veya access-token dosyası kullanılmaz. Üstteki **Parolamı değiştir** ile mevcut parolanızı doğrulayarak yeni parola kaydedebilirsiniz; değişiklikten sonra yeniden giriş yapılır. Yeni parolalar en az 8 karakterdir.

## Administrators

Sol menüde **System → Administrators** açılır. **Yeni kullanıcı** ile kullanıcı adı, parola, profil ve hesap durumu seçilir. **Düzenle** aynı alanları değiştirir; parola boş bırakılırsa korunur. **Sil** onayından sonra hesap ve oturumları kaldırılır. Kendi hesabınızı/parolanızı değiştirmeniz de mevcut oturumları sonlandırır. AD kullanıcıları bu panel hesaplarına otomatik dönüşmez.

## Admin Profiles

Sol menüde ayrı **System → Admin Profiles** sekmesinde **Yeni profil** veya **Düzenle** seçilir.

| Tür | Yetki |
|---|---|
| SuperAdmin | Bütün menü/sekme kaynaklarında Read/Write. |
| Admin_ReadOnly | Bütün kaynaklarda Read; kayıt değiştiremez. Karar testi kayıt değiştirmeyen simülasyon olarak kullanılabilir. |
| Custom | Her menü/sekme için Erişim yok, Read veya Read/Write seçilir. |

Profil adı ve türü değiştirilebilir. Başlangıçtaki SuperAdmin ve Admin_ReadOnly profilleri de düzenlenebilir ve silinebilir. Kullanılan profili silmeden önce ona bağlı hesapları başka profile taşıyın veya silin. Profil değişiklikleri mevcut oturumların bir sonraki isteğinde geçerlidir. Profil/kullanıcı yönetme hakkı olan Custom hesap kendi yetkilerinden daha fazla yetki veremez veya kendisinden yetkili hesabı değiştiremez/silemez.

Kurulumdaki Ürün, Dizin ve Ağ erişimi ayrı kaynaklardır. Diğer kaynaklar Politikalar, Karar testi, İşlem geçmişi, Sertifikalar, User&Authentication altında AD bağlantısı ve Users/User Groups katalog, System altında Administrators ve Admin Profiles'dır. AD bağlantısı ve listeler ayrı yetkilendirilebilir. Eski Custom profilin directory.catalog hakkı bağlantı hakkını da korur; matriste ayrı ayar kaydedildiğinde iki alan bağımsızdır. Erişim yok seçilen veri sunucu yanıtında da çıkarılır. Profil yalnız görüntüyü değiştirmez; doğrudan API isteği de aynı yetkiye tabidir. Yeni ürün sekmeleri eklendikçe matris genişletilecektir.

Bütün hesaplar, son hesap dahil, silinebilir. Son hesabın silinmesinde panel açıkça uyarır ve oturum kapanır. Silinen varsayılan hesaplar yeniden başlatmada geri gelmez. Böyle bir durumda erişim için yerel bakım erişimi veya uygun veritabanı yedeği gerekir; mevcut erişimle başka hesabı oluşturmak daha kolaydır. Yerel bakım anahtarı normal panel kullanıcılarına dağıtılmaz.

## AD grup seçimi

SID, AD'nin kullanıcı veya gruba verdiği benzersiz güvenlik kimliğidir. Grup adı değişebilir; politika eşleşmesi ad yerine bu kimlikle saklanır. Aynı isimle silinip yeniden oluşturulan grup farklı SID alır ve eski politikaya otomatik dahil olmaz.

Yeni politikada **AD grup kısıtı yok** seçilirse grup üyeliği kontrolü kaldırılır; erişim türü, EAP yöntemi, domain cihazı ve diğer koşullar geçerlidir. Bu seçim tek başına herkese izin vermez. Bir gruba göre sınırlandırmak için kutuyu kaldırın ve AD'den okunmuş listede grup adı arayın/seçin. Birden fazla grup seçilirse herhangi birine üyelik koşulu yeterlidir. SID yazmanız gerekmez; KANAME içeride saklar. Katalog yoksa User&Authentication → Active Directory ekranından bilgileri getirin. Users/User Groups ekranında kullanıcı/grup adına tıklayarak karşılıklı üyelik detaylarını açabilirsiniz. Daha önce okunmuş katalog üyelik içermiyorsa AD'den bir kez yeniden okuyun.

Listeden seçim canlı üyelik/EAP doğrulaması değildir; mevcut karar testi bir simülasyondur. Çalışan 802.1X/RADIUS ve OVF sonraki geliştirme aşamalarındadır. Switch/AP ayarları operatör tarafından elle yapılır.

## Sürüm çalışma kuralı

Her sürüm tamamlandığında **Soruların veya değiştirmek/düzenlemek istediğin yerler var mı?** sorulur. Operatör yanıtlamadan sonraki sürüm veya yeni kapsam başlatılmaz.
