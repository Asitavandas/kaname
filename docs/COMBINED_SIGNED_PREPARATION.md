# Birleşik imzalı yerel hazırlık — A04

Özgün imzasız makine taslağı DC01'e aktarıldı; operatör SHA256 değerinin
5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5 olduğunu doğruladı.
Bu aktarım kabulüdür; ayrı asistan DC01 okuması, imzalama veya kurulum kabulü değildir.

PR105 merge a97fc75b79348320edc062c09ce7bed9440752de; son test head fde15f7f3bc8acc88f9f24d77ff320137ac3fea0.
Dört workflow başarılı; genel paket 929 test/28 skipped. Native Windows PowerShell 5.1
testinde 21 kontrol: üç gerçek Authenticode imzası, CLR marker01 ile kalıcı makine anahtarı,
değişmeyen key/certificate/ACL snapshot, özgün ZIP koruma, tekrar hazırlamada değişiklik yapmama,
bozuk dosya/manifest/ek dosya/büyük dosya/yol/yanlış pin reddi.

## Operatör teslimatı
Linux /home/segmentiq/authwire-dc01-combined-candidate-20261028.ps1
SHA256 25667b231cffdfeec7cd73aadb85dd3054569efe61a677dadb0443824a92033f; 36.657 bayt; Linux kopyası özeti doğrulandı.
Kaynak bileşeni 5069c9f5682e064391c601c6dd1d3d648bdb5a86.
Sabit wrapper kaynakları ve müşteri ZIP özetini pinler; DC01/vizyonveri.local/64-bit WinPS5.1/elevated operator koşulu vardır.
Inspect, Prepare ve Verify desteklenir. Müşteri Prepare sonucu henüz alınmadı.

## Yerel kopya
ProgramData/AuthWire-CombinedCandidates-4c23eebe071546d188eea2e96ad7ee46 altında ayrı
bir hedef oluşturur. Özgün ZIP ayrıca original-draft.zip olarak korunur.
Mevcut istemci gövdesi korunur; yeni kopyadaki installer, main'deki incelenmiş retry-trigger
zamanlama düzeltmesini içerir. Bu Linux template'ini veya mevcut cihaz dosyalarını değiştirmez.
İstemci ve installer imzalanır; enrollment SHA256SUMS yeniden üretilir.
Tüm çıktı özetleri signed-manifest.json içinde, aynı JSON'u içeren comment-only
AuthWire-Combined-Manifest.ps1 imzası altında korunur. Üç imza aynı pinned publisher'a ait olmalıdır.
Manifest veya installer çalıştırılmaz. Mevcut başarılı hedef üzerine yazılmaz, doğrulanır.

## Anahtar ve kabul sınırı
Kalıcı provider/name/unique-name/public-key eşleşmesi, RSA3072/export0/signing-only,
exact key SDDL ve CLR marker snapshot imzalama öncesi/sonrası kontrol edilir.
Managed GetRSAPrivateKey kullanılmaz; key property/association/ACL/trust onarılmaz veya değiştirilmez.
Hazırlama elevated operatör kimliğiyle yapılır; müşteri gMSA runtime imzalama/dağıtımı kabulü değildir.
Harici timestamp servisi kullanılmaz; mevcut sertifika zinciri/iptal/geçerlilik kontrolleri korunur.

can_stage=false, can_apply=false. SYSVOL staging, GPO link/ayar/sürüm uygulaması, mevcut
Connector değişimi, enrollment çalıştırma, Ethernet/Wi-Fi import/aktivasyon veya endpoint değişikliği yok.
Mevcut panel adayı ağ formatındadır; birleşik paketi kabul etmiş gibi güncellenmez.
İmzalı yerel müşteri çıktısı, yeni birleşik worker/registry/staging yolu ve gerçek endpoint
sertifika/EAP-TLS/VLAN kabulü açıktır. Genel 54/94 (40 açık) değişmez.
