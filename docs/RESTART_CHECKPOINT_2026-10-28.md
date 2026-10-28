# AuthWire devam noktası — 28 Ekim 2026

Kullanıcı çalıştığı sunucuyu kapatıp açmadan önce ilerlemenin kalıcı kaydını istedi.
Hangi fiziksel/VM sunucusunun yeniden başlatılacağı belirtilmedi.
Bu kayıt güç işlemi, tam sistem/veri yedeği veya kurtarma testi gerçekleştirmez.
Kaynak taban commit: e7b1e2c4fc0161667f7dce60c9f6872fe043f247.
Yeni geliştirme bu devam noktasında duraklatıldı.

## Yeniden başlatma öncesi Linux yedeği — tamamlandı

28 Ekim 2026 10:28:35 İstanbul tarihinde yeni BACKUP_SUCCESS kabul edildi.
Arşiv: /var/backups/authwire/scheduled/authwire-scheduled-20261028T072835Z-004fe2d609b1.tar.gz
SHA256: 3c4b00b745063980c962f712a426a4ce2e845d62abb096ec2346941a5062c002
1687 dosya /4 DB; arşiv, byte/metadata, SQLite bütünlüğü, kararlı iş durumu ve ürün süreçleri doğrulandı.
Operatör helper bağımsız arşiv hash kontrolünü tamamladı; asistan journal/systemd/worker hash'lerini ayrıca okudu.
r2 worker SHA256: c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c.
Timer etkin; ürün servisleri durdurulmadı/yeniden başlatılmadı.
Bu arşivde veri restore veya tam OS boot restore provası yapılmadı; off-host kopya ve Windows/DC01 yedeği ayrı.
Henüz reboot yapılmış veya açılış sonrası sağlık doğrulanmış sayılmaz.

## Güncel devam adımı — birleşik kayıt dev.41 hazır, canlı uygulama bekliyor

Kullanıcı her tamamlanan işlemi GitHub'a kayıt etme tercihini yineledi; tam yedek her işlemde alınmayacak.
PR109 merge 749d84faa21058c6719df2ba4f635b8f80e87f1d; test head edebc092a5bcd253533a4ba53ee954034676830d.
960 test/28 skipped ve altı workflow geçti. A04 registry alt adımı hazır; live dev.41 ve browser kabulü bekler.
Linux helper: /home/segmentiq/authwire-combined-registration-20261028.py
SHA256: 408a2dcd5de9f5542bec00f7bcd86be9c3b3c415cb9adc90c108a9a075be151c
Stage: /home/segmentiq/authwire-stage-dev41-ae21bb729cf5
Manifest: 93cbe46e5af959a0778500e3d5020691164692182463077ceaef78ffa5546bb7
Yalnız panel restart planlı; RADIUS/broker/yedek/GPO/Windows değişmez.
Operatör uygulama sonucundan sonra mevcut birleşik imzalama çıktısı ayrı hazırlık kaydı olarak alınacak.
Ardından typed birleşik kalıcı Connector worker/job kanalı hazırlanacak.
Önceki ağ-only doğrulaması birleşik paket doğrulaması diye kabul edilmeyecek.

## Son kabul edilen durum
- Linux AuthWire: son operatör kabulü 0.14.0-dev.40.
- Windows kalıcı Connector: son kabul edilen release efc5ee91-e39e-4cc4-9cc1-60b648e18cf9.
- Birleşik imzalı paket DC01 üzerinde oluşturuldu; üç imza doğrulandı.
- aw-deploy$ hesabıyla gerçek geçici SCM kontrolü başarılı: exact runtime SID ...1648,
  ContentVerified/ServiceIdentityVerified/ProbeVerified true; SignaturesVerified=3.
- Geçici servis/exe/verifier/result dizini kaldırıldı, Error=null/CleanupErrors=[].
- Son PID9288 geçici probe PID'idir; tekrar var olması beklenmez.
- Kalıcı Connector değiştirilmedi; deployment artifact çalıştırılmadı.
- GpoStateChecked=false, DirectoryFreshnessChecked=false, CanStage=false, CanApplyGpo=false.
- Genel durum 54/94 tamam,40 açık; ürünün tamamı kabul edilmiş sayılmaz.
- READY_FOR_FINAL_GUIDE=false; nihai sade Türkçe ayrıntılı Word/PDF kılavuz teslimatı bekler.

## Kalıcı konumlar ve özetler
Linux kaynak: /opt/kaname-lab/source
Linux DB: /var/lib/kaname-lab/kaname.sqlite3
Linux özgün birleşik ZIP: /home/segmentiq/authwire-pilot-combined-draft-20261028.zip
ZIP SHA256: 5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5
Linux son kontrol helper'ı: /home/segmentiq/authwire-dc01-combined-runtime-20261028.ps1
Helper SHA256: 3caf4882a6871f4936b6021d68c44f664f14556ffc5cd3bdd7ef0bd87e8eec78

DC01 imzalı aday:
C:\ProgramData\AuthWire-CombinedCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5-1359-46f5-84a5-46355bb82aff-v1-5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5-ab1a11c683810061
İmzalı manifest SHA256: 124360dc02e641fe6532f5058fa4915610f74d5c2de7028c5913d7cb9d431c5b
Publisher: FFC134BC305757457163F99C7479B4168E397129
DC01 runtime kaynakları: C:\ProgramData\AuthWire-CombinedRuntimeSources-4bd3a5483f44fd62
DC01 kontrol özeti: C:\ProgramData\AuthWire-CandidateProbe-707b20123a304c599e8463068f0fdcd1\summary.json
Windows Temp altındaki aktarım kopyası veya açık PowerShell değişkenlerine devam için güvenilmez.
Gerekirse özgün ZIP Linux home konumundan tekrar aktarılabilir; paketi yeniden üretmek/imzalamak gerekmez.

## Kimlik ve hedefler
Domain: vizyonveri.local; DC01: dc01.vizyonveri.local
Appliance: https://kaname.vizyonveri.local:8765/ ; Linux IP son bilinen10.35.50.246
Connector ID: 4c23eebe-0715-46d1-88ee-a2e96ad7ee46
Servis: AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46
Hesap: VIZYONVERI\aw-deploy$
SID: S-1-5-21-34256453-3348971241-2809240126-1648
Plan: 524653f5-1359-46f5-84a5-46355bb82aff v1
Makine profili: e3597842-3499-4ace-aaf3-29890eabd908 v3
Owned deployment GPO: 8c6808fd-a382-4bf2-9c9c-d9e1d46082a3
Korunan trust GPO: e5a9ab39-3709-49cb-837a-0208d2eb3b12
TLS DER SHA256: a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d

## Yeniden açılışta devam sırası
1. Kullanıcının hangi host/VM'leri yeniden başlattığını öğren; etkilenenleri salt okunur kontrol et.
2. Linux erişimi, authwire-radius.service ve authwire-service-control.service aktifliği,
   panel HTTPS/session ve backup timer durumunu doğrula.
3. DC01 AD/DNS erişimi; kalıcı Connector servis hesabı, running durumu ve açılıştan sonra
   üretilmiş taze authenticated health/başarı zamanını kontrol et.
   Yeniden açılışta PID değişmesi normaldir; eski PID eşitliğini şart koşma.
4. Gerekliyse kalıcı aday dosyaları/manifest ve özgün ZIP'in özetlerini kontrol et.
   Önceki başarıyı her açılışta aynı uzun probe'ları tekrar çalıştırma gerekçesi sayma;
   sadece başarısız/taze doğrulama gerektiren sınır için hedefli kontrol yap.
5. Kaynak/iş verisi değişikliği veya başarısız başlangıç yoksa aşağıdaki geliştirmeye devam et.
   Sorun çıkarsa önce teşhis et; installer/Prepare/Apply komutlarını körlemesine tekrarlama.
   Yeni hesap/anahtar/sertifika/GPO oluşturma veya anahtar association/ACL onarma varsayımı yapma.

## Sıradaki geliştirme ve açık kabul kapıları
1. Birleşik paket için panel/Connector job + registry entegrasyonu.
   Mevcut ağ-only aday formatını birleşik paket diye yükseltme.
2. Kontrollü staging öncesinde taze AD hedef/GPO/tam SYSVOL kapsamı kontrolleri.
3. Controlled SYSVOL staging yazıcısı, koruma/rollback ve operatör kabulü.
4. GPO/ağ uygulama yolu; pilot cihazda sertifika edinimi, Ethernet/Wi-Fi EAP-TLS ve VLAN.
5. Kullanıcı doğrulaması/diğer A03 ve mevcut rapordaki açık saha/ölçek testleri kapanmış sayılmaz.
6. Tek hesap/standart kurulum sadeleştirmesi ve ayrıntılı final kullanım kılavuzu açık kalır.

## Kabul kanıtı
docs/checkpoints/2026-10-28-customer-combined-gmsa-runtime-accepted.json
docs/COMBINED_RUNTIME_VERIFICATION.md
Son araç PR106: merge60c39b36b594e3e1f9076a2a9e50ce87cdeda32b,
test head a69f9a6d2c1f6c2476a4ebb258e9299e6129cb14;
932 test/28 skipped, native Windows28 kontrol; dört workflow başarılı.
Başarı geçmişi yeniden açılış sonrası taze servis sağlığının yerine geçmez.

Devam cümlesi: “Sunucuyu açtım, 28 Ekim devam kaydından devam edelim.”
