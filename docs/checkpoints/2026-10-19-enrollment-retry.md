# Enrollment retry deadline düzeltmesi — aday dev.11

19 Ekim2026. Canlı sürümdev.10; otomatik retry kabulü henüz yoktur.

## Saha kanıtı

VV06 ağsız boot17:27:45 sonrası kablo gelince EAP başarılı ve10.10.110.4/24.
Enrollment17:40:59 çalışması session aşamasında1 ile bitti.
retry.json17:54:02 hedefliyordu; gerçek task NextRun21:00/RestartCount0 kaldı.
DC discovery/TCP88 ve panelTCP8765 sonradan sağlıklı.
Kontrollü manuel18:17:11 çalışması0 ve retry dosyası yok.
Bu manuel başarı doğal otomatik toparlanma kabulü değildir; ilk hatanın
kesin SSPI/HTTPS alt nedeni mevcut kayıtta yoktur. DNS1.1.1.1 düzenlemesi açıktır.

## Dar değişiklik

AuthWire-Client.ps1 body SHA86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15
değişmez. TLS/SSPI, PKI/CSR/anahtar, receipt/yenileme ve RADIUS/policy kodu değişmez.
İmzalı installer özel AuthWire dizinine kopyalanır; ana SYSTEM task bu dosyayı
-RunClient ile çağırır. İmzalı dosya, mevcut imzalı istemciyi ayrı AllSigned
PowerShell sürecinde çalıştırır ve exit code'u ana göreve taşır.

retry.json varsa gerçek tek seferlik SYSTEM görevi, yerel saate doğru
çevrilmiş UTC deadline'a kurulur. Periyodik polling veya yeni servis yoktur.
İkinci task adı AuthWire Certificate Enrollment Retry; -RetryCheck modu
asıl task'ı başlatır. Böylece ana task LastRun/LastResult gerçek denemeyi gösterir.
Retry görevine yalnız SYSTEM/Administrators tam erişim verilir.
İki görev de ağ koşulu, pil izni, IgnoreNew ve süre sınırlarını korur.
Erken retry invocation yeniden kurulur; Running/Queued main tekrar başlatılmaz.
Launcher ve değişmeyen istemci mutex'leri eşzamanlı çalışmayı sınırlar.

Başarılı istemci sonucu0 + retry dosyası yok + mevcut geçerli private-key
sertifikası birlikte görülürse yalnız eski retry_pending durum kaydı düzeltilir.
last_verified kontrol zamanıdır; sertifika verilme zamanı uydurulmaz.
Yeni issuance'ın gerçek installed/last_success kaydı değiştirilmez.
Geçersiz/değişmeyen geçmiş deadline sıcak bir yeniden deneme döngüsüne çevrilmez.
Normal GPO tekrar uygulaması eski istemciden kalmış pending deadline'ı da kurar.

## Test ve dağıtım sınırları

Yerel25 enrollment/koruma testi geçti.125 dosyalı gerçek kabul edilmiş dev.10
kaynağına karşı yalnız installer/sürüm metaverisi değişimine izin veren guard
ve130 dosyalı adayın tam tekrar uygulanma kontrolü geçti.
Gerçek imzalı SYSTEM/zaman trigger'ı fixture'ı CI sırası bekliyor.
CNG yaşam döngüsü, imzalı GPO/ACL/asset ve mevcut EAP/LDAP/browser kontrolleri
sonuçlanmadan canlıya uygulanmaz. Fixture gerçek müşteri ağının kesilmesi,
gerçek reboot veya AD bağlantısı yerine geçmez.

Linux checkpoint2026-10-19-retry-update.py henüz RELEASE_NOT_PINNED:
çalıştırılması değişiklikten önce reddedilir. CI sonrasında tam Git blob ve
manifest doğrulamasıyla pinlenecektir; RADIUS restart yapılmayacaktır.
Önce/sonra özel yedek, PID/dosya/iş durumu koruması ve izole veri restore şarttır.
DC01 updater2026-10-19-retry-installer-update.ps1 sadece mevcut publisher ile
kurucuyu değiştirir; client/config/trust/INI/ACL korunur.
Mevcut pilot sertifikaları veya kullanıcı/cihaz policy'leri değiştirilmez.
Ardından gerçek VV06 GPO reapply/boot ve doğal ağ geri dönüşü beklenir.
