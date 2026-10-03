# Gerçek RADIUS/EAP-TLS protokol kanıtı — 0.6.0-dev.1

Bu aşama FreeRADIUS ile KANAME politika motoru arasındaki bağlantıyı **gerçek EAP-TLS ve RADIUS paketleriyle**, yalnız geçici loopback laboratuvarında sınar. AD nesneleri ve sertifika-kimlik bağları test verisidir. Gerçek domain, fiziksel Windows supplicant, switch portu veya SSID kabulü değildir. Panelde üretim RADIUS servisi ya da istemci enrollment açılmaz.

## Kanıtın akışı

Native `eapol_test` supplicant EAP-TLS oturumu başlatır. Native FreeRADIUS TLS zinciri, süre, istemci EKU ve CRL'yi doğrular. Yalnız TLS tamamlandığında `kaname-cert-check` sanal sunucusu çağrılır. KANAME sertifika referansını kayıtlı bağa, o bağı güncel dizin hesabına eşler; politika motoru izin veya ret üretir. FreeRADIUS gerçek Access-Challenge/Accept/Reject paketlerini gönderir. Test taşıyıcısı paketlerin Response Authenticator ve Message-Authenticator bütünlüğünü, izin yanıtındaki standart VLAN özniteliklerini doğrular.

Örnek CA müşteri CA'sı değildir: test başında yeni geçici state/CA oluşturulur, test bitince sertifikalar, anahtarlar, secret, ham paketler ve TLS debug logları silinir. Özel test istemci imzalama kodu `tools/radius_lab.py` içindedir; ürün PKI'sında yeni istemci imzalama veya enrollment endpoint'i yoktur. Panelin mevcut CA'sına erişilmez.

## Kimlik ve yetki sınırı

- Sertifika referansı **pinned issuer SHA256 + serial** ile belirlenir. CN, UPN veya dış EAP User-Name yetki kanıtı değildir.
- Kayıt bağı domain, objectGUID, SID ve kullanıcı/bilgisayar türünü birlikte tutar. GUID aynı görünse bile SID veya tür değişmişse ret verilir.
- Her kararda dizin sağlayıcısı çağrılır. Görüntüleme kataloğu, eski başarılı okuma veya distribution grup grafiği erişim izni için fallback değildir.
- Hesap kapalı/silinmişse, kayıt pasifse, sertifika bağlı değilse, dizin erişilemezse veya grup koşulu kalkmışsa ret verilir.
- Kullanıcı sertifikası domain bilgisayarı kanıtı üretmez. `require_domain_device` bilgisayar hesabına bağlanmış geçerli sertifika gerektirir. Aynı oturumda bağımsız kullanıcı+cihaz kanıtı bu milestone'da uygulanmaz.
- Policy sıra/koşul/kısıt davranışı mevcut motorla aynıdır. Ret veya bozuk adapter sonucu VLAN/Accept üretemez.
- Python türleri kriptografik kanıt değildir. Bu modülü çağırma hakkı yalnız yerel, korunan FreeRADIUS adapter'ına ait olacaktır; HTTP panel/simülasyon endpoint'i bu çağrıyı yapmaz.

`TLSAuthorization` henüz varsayılan production registry veya live AD sağlayıcısı içermez. Eksik sağlayıcı ret verir. Geçici `tests/radius_fixture.py` yalnız laboratuvar işaretçisi ve 127.0.0.1 ile çalışır; production service/apply yapılandırmasına eklenmez.

## Native test ortamı

FreeRADIUS 3.2.10, upstream `release_3_2_10`, kaynak commit `9071ea041b9172e52eabbba91619afaf3a238795` sabitlenir. GitHub'ın geçici Ubuntu 24.04 runner'ında bağımsız prefix'e derlenir. Sistem RADIUS servisi kurulmaz/değiştirilmez. Yapılandırma rastgele loopback UDP portunu, yalnız 127.0.0.1 NAS kaynağını ve her çalıştırmada rastgele shared secret'ı kullanır. Proxy, parola yöntemleri ve kullanılmayan EAP yöntemleri açılmaz.

`require_message_authenticator = yes`, `limit_proxy_state = yes`, native TLS zincir/EKU/CRL denetimi, expired CRL reddi ve kapalı TLS session cache kullanılır. İlk uyumluluk kanıtı TLS 1.2 + ECDHE/RSA/AES-GCM ile sınırlıdır; TLS 1.3 ve Windows davranışı ayrı gerçek lab kontrolüdür. Sertifikalar RSA-2048 leaf ve mevcut RSA-3072 KANAME CA ile üretilir. EAP fragment boyutu 512'dir; çoklu challenge/response oturumu zorunlu doğrulanır.

Test sonuçları yalnız sabit case adları, karar nedenleri, RADIUS kodları, VLAN ve bütünlük durumlarıdır. Ham debug log/paket/MPPE anahtarları artifact/log çıktısına aktarılmaz.

## Test matrisi

| Senaryo | Beklenti |
|---|---|
| Bağlı domain bilgisayarı; wired/wireless policy context | Accept, VLAN 33, bütünlük doğrulanmış yanıt |
| Kullanıcı politikası, cihaz şartı kaldırılmış | Accept, VLAN 33 |
| Kullanıcı sertifikası + domain cihazı şartı | Reject |
| Kapalı hesap; kaldırılmış grup; silinmiş hesap; yeniden oluşturulmuş farklı SID | Reject |
| Dizin kesintisi; pasif kayıt; bağlı olmayan sertifika | Reject; eski katalog fallback yok |
| Üstte açık deny, altta allow | Reject; sonraki allow'a geçilmez |
| İptal, expired, yabancı CA veya yanlış EKU istemci sertifikası | Native TLS ret |
| Yanlış sunucu adı veya yabancı sunucu CA güveni | Supplicant ve oturum reddi |
| Eksik/geçersiz Message-Authenticator | Yanıt vermeden discard |
| Tanımsız NAS kaynak IP | Yanıt vermeden discard |
| Geçerli Message-Authenticator ile EAP dışı istek | Reject, VLAN yok |

Wired/wireless burada server-owned erişim bağlamıdır; fiziksel EAPOL ve Windows port/SSID testinin yerine geçmez. Dış EAP adı değiştirilse de sertifika bağı değişmez. RADIUS secret ile kaynak güveni, AD enrollment kimlik kanıtı ve endpoint private key koruması farklı sorumluluklardır.

## Yeniden çalıştırma

`.github/workflows/radius.yml` kaynağı sabitler, native binary'yi derler ve aşağıdaki harness'ı çalıştırır:

```bash
python -m tools.radius_lab --radius-prefix /absolute/isolated/freeradius-prefix --report /absolute/new/kaname-radius-proof.json
```

Bu bir geliştirme testidir; production kurulum talimatı değildir. `unittest` içinde native bağımlılık yoktur; kimlik bağlama/politika sınırı testleri platformlar arasında çalışır. Native protokol testi ayrı CI işinde zorunlu başarılı olmalıdır.

## Sonraki gerçek domain laboratuvarı

Temiz x86_64 Ubuntu Server 24.04 LTS VM, 2 vCPU, 4 GB RAM ve 30 GB disk ilk geliştirme denemesi için yeterli başlangıç tahsisidir; kapasite ölçümü veya üretim minimumu ilanı değildir. VM domain/DC'ye ulaşabilmeli, AD DNS'ini kullanmalı ve Kerberos için saati doğru olmalıdır. GitHub runner geliştirme/test erişimidir; bitmiş appliance'ın çalışma bağımlılığı olmayacaktır.

Sonraki geliştirme, Kerberos signing/sealing ile **live Linux AD** sağlayıcısını ve kimliği kanıtlanan enrollment'ı eklemektir. Sonra manuel hazırlanmış switch/AP ve Windows endpoint üzerinde gerçek kablolu/kablosuz kabul yapılır. Switch/AP yönetim API/SSH/SNMP entegrasyonu eklenmez. İnternet/ayrı CA/ayrı NPS gerektirmeyen kurulu appliance hedefi korunur; OVF henüz açılabilir disk imajı değildir.

## Birincil teknik kaynaklar

- [FreeRADIUS güvenlik duyuruları](https://www.freeradius.org/security/)
- [Pinned upstream EAP-TLS virtual server](https://github.com/FreeRADIUS/freeradius-server/blob/9071ea041b9172e52eabbba91619afaf3a238795/raddb/sites-available/check-eap-tls)
- [Native certificate-check çağrısı ve reply kopyalama](https://github.com/FreeRADIUS/freeradius-server/blob/9071ea041b9172e52eabbba91619afaf3a238795/src/modules/rlm_eap/types/rlm_eap_tls/rlm_eap_tls.c)
- [RADIUS/EAP Message-Authenticator, RFC 3579](https://www.rfc-editor.org/rfc/rfc3579)
- [RADIUS Response Authenticator, RFC 2865](https://www.rfc-editor.org/rfc/rfc2865)
