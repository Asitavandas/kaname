# KANAME 0.4.0-dev.1 — tamamlanma kaydı

Tarih: 4 Ekim 2026 (Europe/Istanbul).
Kaynak yayın commit'i: b16d50c7b7fc6c2d2c39e49d7a4aaf253ffbb35d.

## Teslim edilen davranış

- Panel girişinde kullanıcı adı/parola; ilk kurulum admin/Kaname. PowerShell/token günlük girişten çıkarıldı.
- System → Administrators: hesap ekleme, düzenleme, parola/profil/durum değişikliği ve silme.
- Admin Profiles: başlangıç profilleri dahil düzenleme/silme; SuperAdmin, Admin_ReadOnly ve menü/sekme bazında Custom.
- Yetkiler yalnız menüde değil API'de uygulanır. Custom durum yanıtında yetkisiz alanlar çıkarılır. Profil değişikliği sonraki istekte; kullanıcı/parola değişikliği oturumları sonlandırır.
- Politikada manuel SID yerine aranan grup adı/çoklu seçim. Grup kısıtı yok seçeneği diğer koşulları kaldırmaz. SID içeride kalıcı eşleşme kimliği olarak korunur.
- Yükleme sürerken işlem düğmeleri kapalı; çıkış sonrası eski oturuma ait geciken yanıtlar atılır.
- Tüm hesaplar ve kullanılmayan profiller silinebilir; son hesap uyarılır, yeniden başlatmada varsayılan hesap yeniden oluşturulmaz. Kullanılan profil önce kullanıcı atamaları değiştirilerek boşaltılır.

## Doğrulama

Son yayın commit’inin kontrolleri: Windows ve Linux toplam 191 test çalıştırdı. Windows 189 başarılı, 2 atlandı; Linux 186 başarılı, 5 Windows özel testi atlandı. Chromium geçici veriyle kullanıcı/parola girişi, oturum yenileme, kullanıcı/profil CRUD, ReadOnly sunucu reddi, Custom sekme/veri sınırları, AD fixture, parola temizliği, grup adı seçimi ve geciken eski oturum yanıtı sınırını doğruladı. Bu tarayıcı testi gerçek AD kullanmadı.

## Windows güncellemesi

Windows update işlemi başarılı tamamlandı. Panel 0.4.0-dev.1 ile HTTP 200 yanıtlıyor. Kurulu 63 kaynak dosyasında eksik/değişmiş dosya bulunmadı. Kaynak ve yerel SQLite yedeği oluşturuldu; config, politika, CA ve AD katalog verileri güncelleme öncesi/sonrası aynı.

Önceki sürümde panel hesapları bulunmadığından administrators.sqlite3 ilk kez oluşturuldu. İlk admin/Kaname girişi gerçek Windows HTTP endpoint'inde cookie ile test edildi; bütün SuperAdmin izinleri, durum okuma, çıkış ve çıkış sonrası 401 doğrulandı. Oturum/cookie/CSRF/parola hash'i rapora taşınmadı. Sonraki sürümlerde mevcut hesaplar korunur ve varsayılan parola tekrar denenmez.

Tanılama: Python 3.14.8, cryptography 46.0.0, kayıt sürümü 11, 1 politika (0 etkin), CA mevcut. Bu değerler güncelleme öncesindeki kullanıcı verileriyle eşleşti. Üç simülasyon yerel politika motoruyla aynı sonucu verdi; iki NO_MATCHING_POLICY, bir ACCOUNT_DISABLED. Bunlar gerçek ağ doğrulaması değildir. Tanılama real_ad_tested=false değeri bu otomasyonun gerçek AD kimlik bilgisi kullanmadığını belirtir; operatörün önceki başarılı AD denemesini geçersiz kılmaz.

| Kontrol | Sonuç | GitHub kaydı |
|---|---|---|
| Linux test/syntax | 191 test, 186 başarılı, 5 atlandı | [Foundation](https://github.com/Asitavandas/kaname/actions/runs/37154103312) |
| Windows test | 191 test, 189 başarılı, 2 atlandı | [Windows](https://github.com/Asitavandas/kaname/actions/runs/37154103272) |
| Chromium akışları | Başarılı; gerçek AD kullanılmadı | [Browser](https://github.com/Asitavandas/kaname/actions/runs/37154103283) |
| Windows yedek/update/giriş/tanılama | Başarılı | [Update](https://github.com/Asitavandas/kaname/actions/runs/37154103290) |

## Operatör kabulü ve kalan kapsam

Operatör önceki 0.3.2 AD denemesinde başarılı 55 sonuç bildirdi. Bu bildirim katalog okuma kabulüdür; sayının bütün kategorileri temsil ettiği veya ağ kimlik doğrulaması kanıtı olduğu varsayılmaz. Bu sürümde gerçek AD parolası tekrar istenmez; mevcut katalog korunur.

Gerçek RADIUS/EAP-TLS, AD ile doğrulanmış istemci enrollment, üretim HTTPS/servis, Linux AD adaptörü ve açılabilir OVF hâlâ sonraki aşamalardır. Switch/AP yönetimi veya yönetim entegrasyon testleri kapsam dışıdır; cihaz ayarlarını operatör elle yapar.

Bu sürüm tamamlandıktan sonra operatöre “Soruların veya değiştirmek/düzenlemek istediğin yerler var mı?” sorulacak; yanıt alınmadan sonraki sürüme geçilmeyecek.
