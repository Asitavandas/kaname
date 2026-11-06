# AuthWire kabul kayıtları ve sıradaki iş seçimi

6 Kasım 2026. Sonraki iş seçilirken önce güncel durum raporu, bu dizin ve
kanıt checkpoint'i okunur. Eski bir hazırlık notundaki "bekliyor" ifadesi,
daha sonraki başarılı kabulü yeniden açmaz. Bu kayıt yeni bir PDF raporu değildir.

| Kabul | Durum | Kanıt / kapsam |
|---|---|---|
| Gerçek kontrollü sertifika yenilemesi ve eski cert/CNG anahtar temizliği | Kapalı | 19 Ekim VV06; historical-windows-renewal-boot-closure |
| Normal boot ve doğal SYSTEM görev/bağlantı | Kapalı | 19–21 Ekim VV06; aynı checkpoint |
| Ağsız boot sonrası otomatik dönüş | Kapalı | 20 Ekim VV06 offline-reconnect-acceptance |
| Gerçek hata sonrası zamanlı otomatik retry | Kapalı | 20 Ekim VV06 automatic-retry-recovery-acceptance |
| Süresi dolmuş istemci sertifikasının RADIUS tarafından reddi | Kapalı | 6 Kasım invalid-client-tls-acceptance; event94 |
| Güvenilmeyen issuer istemci sertifikasının RADIUS tarafından reddi | Kapalı | Aynı kayıt; event96 |
| CRL geçici taşıma hatasında sınırlı tekrar ve canlı teslim | Kapalı | 6 Kasım crl-transport-repair-live-acceptance; dev.47 |
| VV-Client01 5 Kasım çökmesi sonrası tekrarlamama | Kapalı | 6 Kasım wired-crash-nonrecurrence-closure; yeni olay yok |
| Misafir/VLAN yeniden testi | Tekrar yapılmayacak | Rapor ve kullanıcının açık dışlaması |
| Gerçek expired-pending uç cihaz kurtarma | Doğal süre dolumu bekliyor | B06; 6 Kasım gerçek seed hazır, 8 Kasım21:06 Türkiye SYSTEM Recover görevi |

Dosya adları docs/checkpoints altında tarihli tam adlarıyla bulunur.
Kapalı dar kabuller, yeni somut hata veya ilgili değişiklik olmadığı sürece
test kuyruğuna tekrar eklenmez. Yeni sürüm için gereken dar teslim doğrulaması
yenileme/reboot testinin baştan yapılması olarak sayılmaz.

## Sıradaki açık kabul

Gerçek expired-pending kayıtta, doğal süre dolumundan sonra aynı eski CSR'nin
sunucudan DEVICE_CERTIFICATE_EXPIRED alması; production Windows istemcisinin
tam aynı pending kaydını arşivlemesi; doğal retry zamanında yeni nonexportable
CNG anahtarı/CSR ile gerçek AD/Kerberos/HTTPS üzerinden toparlanması.
21 Ekimde bu yol native CNG/certreq ile fakat synthetic Kerberos taşımasıyla
test edildi. Aynı fixture yeniden çalıştırılmayacak.

Ayrı dar pilot profili ve özel test durum dizini kullanılır. Mevcut 90 günlük
makine sertifikası/anahtarı, ana kayıt görevi, Ethernet1 ve sistem saati korunur.
Üretim profilinde en düşük geçerlilik iki gündür; doğal süre dolumu beklenir.
Geçmiş sertifikayı veya üretim DB tarihini değiştirerek saha başarısı üretilmez.
Hazırlık veya fixture kabulü, bitmiş gerçek saha kurtarması olarak işaretlenmez.

Aktif vaka: docs/checkpoints/2026-11-06-natural-expiry-pilot-prepared.json.
Önce aynı seed-result.json/recovery-result.json ve sahipli görev kontrol edilir.
Seed veya yeni test profili oluşturma tekrarlanmaz. Doğal süre dolumu gelmeden
bu kabul bitmiş sayılmaz. Bu sırada aynı test profili veya VV-Client01 AD
kimliğini değiştirmeyen, raporda açık başka işler seçilebilir.

