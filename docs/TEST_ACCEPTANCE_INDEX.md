# AuthWire kabul kayıtları ve sıradaki iş seçimi

12 Kasım 2026. Sonraki iş seçilirken önce güncel durum raporu, bu dizin ve
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
| G01/A04 yetki öncesi ret nedeninin bildirilmesi | Kaynak kabulü kapalı; canlı teslim açık | 7 Kasım write-refusal-source; PR141,18 CI akışı,134 native kontrol |
| Misafir/VLAN yeniden testi | Tekrar yapılmayacak | Rapor ve kullanıcının açık dışlaması |
| Windows başlangıç testinde görev sonucu gözlemi | Kaynak kabulü kapalı | PR142; 12 Kasım bağımsız Windows ve tam cihaz kayıt akışları başarılı |
| Windows istemcisinin Türkçe ortamda sertifika hata kodunu okuması | Yerel regresyon geçti | VV-Client01 Windows PowerShell; 403 hata kodu `tr-TR` ve `en-US` altında doğrulandı |
| Gerçek expired-pending uç cihaz kurtarma | Saha kabulü açık | B06; 8–9 Kasım sekiz deneme başarısız, görev devre dışı, imzalı dar saha doğrulaması bekliyor |

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

Hazırlık kaydı: docs/checkpoints/2026-11-06-natural-expiry-pilot-prepared.json.
8–9 Kasım arasındaki sekiz deneme sonunda bekleyen istek arşivlenmedi ve
yeni kurulum kaydı oluşmadı. Linux günlüklerinde bu isteklere bağlanabilen
sertifika verme yanıtı bulunamadı. Ayrı yerel HTTP testinde `tr-TR` altında
istemcinin ASCII büyük harfli hata kodunu elediği gösterildi. Aynı yanıt,
büyük/küçük harfe duyarlı doğrulama ile `tr-TR` ve `en-US` altında okundu.
Eski vaka kayıtları ve devre dışı görevi korundu. Bir sonraki saha doğrulaması,
kurumsal yayıncı ile imzalanmış istemci ve aynı süresi dolmuş CSR ile ayrı
test durum dizininde gerçek Kerberos/HTTPS üzerinden yapılabilir.

## Sıradaki bağımsız kaynak işi — 7 Kasım 2026

G01/A04: belirsiz/yarım Windows görev kayıtlarının salt okunur sınıflandırılması
ve kontrollü uzlaştırma incelemesi. Önce özgün offer/CLAIM/authorization/outbox/
ACK ve filesystem kayıtları karşılaştırılacak; bilinmeyen sonuç tamamlandı veya
etki yok diye yükseltilmeyecek. Ayrı onaylı unlock ve journal dış yedek/restore,
aktif scheduler/SCM, kontrollü imzalı teslim ve gerçek gMSA/AD/endpoint kabulü
açık kalır. Kaynak ret bildirimi ve yerel retention geliştirmesi tekrar yapılmaz.
Özgün kanıt: docs/checkpoints/2026-11-07-write-refusal-source.json.

