# KANAME 0.6.0-dev.1 — tamamlanma kaydı

Tarih: 4 Ekim 2026 (Europe/Istanbul).
Kaynak yayın commit'i: 4028e7814258ecd326e187a88fdbfcf2b498abd8.
Operatör 0.5 menü/üyelik teslimini kabul edip sonraki aşamaya geçişi onayladı.

## Teslim edilen davranış ve kapsam

Native FreeRADIUS 3.2.10 + eapol_test ile gerçek EAP-TLS/RADIUS protokol laboratuvarı ve sertifikaya bağlı iç yetkilendirme sınırı eklendi. TLS tamamlandıktan sonra pinned issuer/serial registry bağına, domain/objectGUID/SID/tür güncel dizin hesabına eşlenir. Mevcut sıralı politika motoru native certificate-check virtual server üzerinden kullanılır. Ret ve bozuk adapter sonucu VLAN veya Accept üretemez. Eksik registry/provider varsayılan ret verir.

Loopback laboratuvarı kendi geçici CA'sını ve test bağlarını kullanır; AD sağlayıcısı sentetiktir. Display katalog/grup ilişkileri erişim kararı fallback'i değildir. Müşteri CA'sına istemci imzalama açılmadı. Panelde production RADIUS servisi veya client enrollment etkinleştirilmedi. Gerçek domain, Windows EAPOL port/SSID, TLS 1.3 ve açılabilir OVF kabulü bu teslim değildir.

## Doğrulama

| Kontrol | Sonuç | GitHub kaydı |
|---|---|---|
| Native EAP-TLS/RADIUS | 22 senaryo başarılı: 3 Accept, 16 Reject, 3 discard | [Protocol](https://github.com/Asitavandas/kaname/actions/runs/37161629365) |
| Linux test/syntax | 231 test; 224 başarılı, 7 Windows özel testi atlandı | [Foundation](https://github.com/Asitavandas/kaname/actions/runs/37161629324) |
| Windows test | 231 test; 229 başarılı, 2 atlandı | [Windows](https://github.com/Asitavandas/kaname/actions/runs/37161629322) |
| Chromium panel akışları | Başarılı; login, CRUD, RBAC, mevcut menü/AD üyelik akışları | [Browser](https://github.com/Asitavandas/kaname/actions/runs/37161629337) |
| Windows update ön kontrolü | 231 test; 229 başarılı, 2 atlandı | [Update](https://github.com/Asitavandas/kaname/actions/runs/37161629421) |
| Windows yedek/update/tanılama | Başarılı; HTTP 200 ve kaynak/durum eşleşmesi | [Update](https://github.com/Asitavandas/kaname/actions/runs/37161629421) |

Native test bütün Access-Challenge/Accept/Reject yanıtlarında Response Authenticator ve Message-Authenticator'ı denetler. İzin paketinde standart Tunnel-Type=13, Tunnel-Medium-Type=6 ve Tunnel-Private-Group-ID=33 doğrulandı. Ret yanıtları VLAN taşımaz. Native TLS iptal, süre, client EKU ve yabancı CA retleri; supplicant yanlış sunucu adı/güven retleri başarılıdır. Dizin kesintisi/kapalı-silinmiş-farklı SID hesap, kaldırılmış grup, pasif/bağlı olmayan sertifika ve üst deny politikası ret üretir. Kullanıcı sertifikası domain bilgisayar şartını karşılayamaz.

Ham paketler, MPPE anahtarları, shared secret, test CA/leaf özel anahtarları veya debug logları rapora aktarılmadı. Sanitised native sonuç [RADIUS_PROOF_0_6_0.json](RADIUS_PROOF_0_6_0.json); yöntem ve sınırlar [RADIUS_PROTOCOL.md](RADIUS_PROTOCOL.md).

Native kaynak commit'i: 9071ea041b9172e52eabbba91619afaf3a238795. Test paketleri:
- eapoltest=2:2.10-21ubuntu0.4
- libpython3.12t64=3.12.3-1ubuntu0.17
- libssl3t64=3.0.13-0ubuntu3.16

## Ara Windows hatası ve sınırı

Kaynak hazırlama kontrolünde panel login ve hesap kayıt HTTP testlerinde aralıklı 8 saniyelik timeout görüldü. İlk aynı-kaynak retry da farklı bir hesap kayıt isteğinde timeout verdi; aktif daemon worker geçici SQLite dosyasını tuttuğu için cleanup ayrıca başarısız oldu. HTTP test fixture'ı artık worker'ları server_close sırasında bekler. Timeout tanılaması yalnız kaynak dosyası/fonksiyon/satır konumlarını kaydeder; request/header/body/local/parola yazmaz.

Timeout artırılmadı, test kapatılmadı, otomatik HTTP retry eklenmedi; Windows güvenlik yazılımı veya sistem ayarı değiştirilmedi. Güncel fixture kontrolü, son yayın Windows testi ve update gate başarılıdır. İlk gecikmenin kesin ortam nedeni kanıtlanmış sayılmaz; üretim HTTP/servis ve performans aşamasında yeniden ölçülecek bir lab gözlemidir.

## Windows güncellemesi

Kurulu sürüm 0.6.0-dev.1; 73 dosyalık kaynak manifestinde eksik/değişmiş dosya yok. Kaynak ve yerel SQLite yedeği oluşturuldu. Config, politikalar, CA, token, AD kataloğu ve panel hesap/profil satırları güncelleme öncesi/sonrası korundu. Mevcut hesaplar yeniden oluşturulmadı; varsayılan parola sıfırlanmadı veya yeniden denenmedi.

Tanılama Python 3.14.8, cryptography 46.0.0, revision 16, 1 politika (1 etkin), CA mevcut sonucunu verdi. Etkisiz simülasyonlarda matching policy POLICY_ALLOW; domain dışı cihaz DOMAIN_DEVICE_REQUIRED; kapalı hesap ACCOUNT_DISABLED beklenen sonuçlarını verdi. Bu simülasyonlar ağ erişimi kanıtı değildir. real_ad_tested=false güncelleme otomasyonunun gerçek AD kimlik bilgisi kullanmadığını belirtir; operatörün katalog okuma kabulünü geçersiz kılmaz.

## Sonraki aşama ve operatör kabulü

Mevcut panel hesabıyla giriş yapılır; Ctrl+F5 sürüm etiketini yeniler. Bu sürüm için AD kataloğunu yeniden içe aktarma zorunluluğu yoktur.

Sonraki çalışma temiz Ubuntu Server 24.04 LTS VM'de live Kerberos AD sağlayıcısı ve kimliği kanıtlanmış client enrollment'dır; ardından manuel hazırlanmış port/SSID ve Windows endpoint ile gerçek kablolu/kablosuz EAP-TLS kabulü yapılır. İlk lab tahsisi 2 vCPU/4 GB RAM/30 GB disk; bu bir üretim minimum kapasite ilanı değildir. Switch/AP yönetim entegrasyonu kapsam dışında kalır. Accounting, controlled apply/rollback, production HTTPS/secret vault/rate limit, CRL dağıtım/yenileme, offline appliance ve bootable OVF sonraki kapılardır.

Bu sürüm tamamlandı. Operatöre “Soruların veya değiştirmek/düzenlemek istediğin yerler var mı?” sorulacak; yanıt gelmeden sonraki sürüm/özellik çalışmasına geçilmeyecek.
