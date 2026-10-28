# Birleşik paketin servis kimliğiyle salt okunur kontrolü

PR106 merge 60c39b36b594e3e1f9076a2a9e50ce87cdeda32b; test head a69f9a6d2c1f6c2476a4ebb258e9299e6129cb14. Dört workflow başarılı.
Genel paket 932 test/28 skipped; native Windows5.1 28 kontrol. Gerçek yönetici olmayan
virtual SCM hesabı, imzalı helper ve AllSigned runspace ile paket doğrulaması ve temizlik geçti.
Bunlar izole test kanıtlarıdır; müşteri DC01/gMSA kabulü değildir.

## Doğrulama
Test-AuthWireCombinedContent.ps1 sadece public doğrulama işlevlerini ve incelenmiş
installer template baytlarını içerir. Private signer/anahtar açma, imzalama veya yazma işlevleri yoktur.
Test-AuthWireServiceCombinedContent geçerli runtime SID'inin beklenen servis SID'iyle
aynı olmasını ister. Dosya yolu istekte alınmaz; Connector/plan/sürüm ve özetlerden sabit
ProgramData kökü altında türetilir. Exact manifest, özgün ZIP, tam dosya kümesi, ACL,
üç imza, betik gövdeleri ve tüm özetler kontrol edilir. CanStage/CanApplyGpo false kalır.

## Operatör teslimatı
Linux: /home/segmentiq/authwire-dc01-combined-runtime-20261028.ps1
SHA256 3caf4882a6871f4936b6021d68c44f664f14556ffc5cd3bdd7ef0bd87e8eec78; 59.966 bayt; Linux kopyasının özeti doğrulandı.
RunProbe, mevcut VIZYONVERI\\aw-deploy$ hesabıyla kısa ömürlü owned SCM servisi oluşturur.
Mevcut signer yalnız operatör tarafında incelenmiş yardımcıları ve test exe'sini imzalar;
servis içindeki doğrulayıcı private key açmaz. Native signer snapshot ve kalıcı Connector
PID/hesap/durum korunumu operatör wrapper'ında kontrol edilir.
Geçici servis/exe/helper/result dizini temizlenir; özet ve incelenmiş imzalı kaynaklar
ProgramData altında kalır. Kalıcı Connector durdurulmaz/yükseltilmez.
Logon rights, key ACL/property/association, trust, AD/GPO, SYSVOL veya endpoint ayarı değiştirilmez.
Hata/temizlik sorunu varsa ProbeVerified false kalır ve kanıt yolu paylaşılmalıdır.

Beklenen event WINDOWS_COMBINED_RUNTIME_DELIVERY; iç sonuçta ProbeVerified,
ServiceLogonVerified, CandidateVerified ve TemporaryServiceRemoved true olmalıdır.
Candidate.ContentVerified ve ServiceIdentityVerified true, RuntimeSid ...1648 olmalıdır.
Müşteri RunProbe çıktısı henüz alınmadı.

## Açık işler
Bu standalone servis hesabı kanıtıdır. Panelin birleşik job/registry kanalı henüz eklenmedi;
mevcut ağ-only aday yükseltilmez ve permanent worker capability kabulü verilmez.
Güncel AD/GPO/alt SYSVOL kapsamı doğrulama, controlled staging yazıcısı/rollback,
GPO ve ağ uygulaması ile gerçek cihaz sertifika/EAP-TLS/VLAN testleri açıktır.
İstemci veya installer çalıştırılmaz; deployment artifact execution false.
İzole doğrulama bütün ürünün tamamlandığı anlamına gelmez; genel 54/94,40 açık korunur.
