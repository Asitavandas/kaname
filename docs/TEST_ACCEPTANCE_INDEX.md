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
| VV06 pilot gruptan çıkarma ve AD hesabını devre dışı bırakma sonrası ret ve geri dönüş | Kapalı | 14 Ekim ve önceki kablolu kayıtlar; CURRENT_STATUS.md, VV06 saha kanıtı |
| B02 silinmiş AD bilgisayar hesabı ve AD erişilemezliği sonrası geri dönüş | Açık, ortam bekliyor | 12 Kasım kullanıcı kararı. Ayrı Windows test kimliği ve yalıtılmış AD kesinti ortamı hazır olduğunda devam edilir. |
| Süresi dolmuş istemci sertifikasının RADIUS tarafından reddi | Kapalı | 6 Kasım invalid-client-tls-acceptance; event94 |
| Güvenilmeyen issuer istemci sertifikasının RADIUS tarafından reddi | Kapalı | Aynı kayıt; event96 |
| CRL geçici taşıma hatasında sınırlı tekrar ve canlı teslim | Kapalı | 6 Kasım crl-transport-repair-live-acceptance; dev.47 |
| VV-Client01 5 Kasım çökmesi sonrası tekrarlamama | Kapalı | 6 Kasım wired-crash-nonrecurrence-closure; yeni olay yok |
| G01/A04 yetki öncesi ret nedeninin bildirilmesi | Kaynak kabulü kapalı; canlı teslim açık | 7 Kasım write-refusal-source; PR141,18 CI akışı,134 native kontrol |
| G01/A04 belirsiz Windows görev kayıtlarının salt okunur sınıflandırması | Kaynak kabulü kapalı; canlı teslim açık | PR144, kaynak `f9e9ba5`; Windows yaşam döngüsü 8 senaryo / 219 kontrol ve günlük geçmişi 4 senaryo / 205 kontrol |
| G01/A04 doğrulanmış Windows kanıtının sunucu görev kaydıyla salt okunur eşleştirilmesi | Kaynak kabulü kapalı; canlı teslim açık | PR145, kaynak `49737ba`; doğrulanmış ACK, kayıp ACK ve kayıp CLAIM için 3 gerçek Windows–SQLite karşılaştırması |
| G01/A04 eksik veya çelişkili kayıtlarda operatör kararının kaydı | Kaynak kabulü kapalı; canlı teslim açık | PR146; gerçek HTTPS oturumu, eski kanıt ve aynı onayın tekrar denetimleri |
| Misafir/VLAN yeniden testi | Tekrar yapılmayacak | Rapor ve kullanıcının açık dışlaması |
| Windows başlangıç testinde görev sonucu gözlemi | Kaynak kabulü kapalı | PR142; 12 Kasım bağımsız Windows ve tam cihaz kayıt akışları başarılı |
| Windows istemcisinin Türkçe ortamda sertifika hata kodunu okuması | Kaynak ve saha doğrulaması geçti | PR143; `tr-TR` ve `en-US` Windows regresyonu, sekiz başarılı CI akışı |
| Gerçek expired-pending uç cihaz kurtarma | Kapalı | B06; 12 Kasım VV-Client01 gerçek Kerberos/HTTPS, arşiv, doğal retry, kurulum makbuzu ve temizlik |

Dosya adları docs/checkpoints altında tarihli tam adlarıyla bulunur.
Kapalı dar kabuller, yeni somut hata veya ilgili değişiklik olmadığı sürece
test kuyruğuna tekrar eklenmez. Yeni sürüm için gereken dar teslim doğrulaması
yenileme/reboot testinin baştan yapılması olarak sayılmaz.

## Gerçek bekleyen istek kurtarmasının saha kabulü

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
12 Kasımda kurumsal yayıncı ile imzalanmış istemci, ayrı test durum dizininde
aynı doğal olarak süresi dolmuş CSR ile gerçek Kerberos/HTTPS üzerinden geçti.
Bekleyen istek aynen arşivlendi. İstemcinin belirlediği zamanda yeni CNG
anahtarı ve sertifika, çevrimiçi zincir ve kurulum makbuzu doğrulandı. Test
anahtarları ve sertifikası temizlendi. Ana cihaz kimliği, Ethernet1 ve eski
vaka kayıtları korundu. Kanıt: docs/checkpoints/2026-11-12-natural-expiry-field-accepted.json.

## Sıradaki saha kabulleri

B02 için silinmiş ayrı test hesabı ve yalıtılmış AD erişilemezliği/geri dönüşü
açık. VV06 pilot grup üyeliğini kaldırma/geri ekleme ve hesabı kapatma/açma
senaryoları önceki kablolu kabulde tamamlandı. Gerçek kullanıcı EAP-TLS için
ayrı test kullanıcıları ve kablosuz uç gerekir. Diğer testler 12 Kasım durum
raporunun açık saha kabulü listesinden bağımlılıklarıyla izlenir.

## G01/A04 devamı — 12 Kasım 2026

Doğrulanmış yerel kanıtın sunucu görev kaydıyla karşılaştırılması ayrı Windows
CI ortamında geçti. Kayıp ACK durumunda eşleşen sunucu sonucu ile yerel onayın
eksikliği birlikte görülebiliyor. Operatör, kaydı incelemede tutma veya
eşleşen sunucu sonucunu gördüğünü kaydetme kararını güncel kanıta bağlı olarak
onaylayabilir. Bu karar denetim geçmişine eklenir. Sıradaki açık iş onaylı
kilit açmadır. Harici günlük yedeği ve geri yükleme, aktif scheduler/SCM,
kontrollü imzalı teslim ve gerçek gMSA/AD/uç kabulü ayrıca açıktır.
Önceki ret bildirimi kanıtı: docs/checkpoints/2026-11-07-write-refusal-source.json.

