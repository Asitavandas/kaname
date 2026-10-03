# KANAME — yerel dahili CA denemesi

0.2.0-dev.1 kendi root ve imzalayan CA'sını üretir. Ayrı CA sunucusuna bağlanmaz. Bu aşamada yalnız KANAME'nin kayıtlı DNS adı için RADIUS **sunucu** sertifikası imzalanır. Kullanıcı/bilgisayar enrollment, AD kimliğine bağlama, HTTPS/RADIUS çalışma zamanı ve otomatik güven dağıtımı henüz yoktur.

## Gereksinim

Python 3.12+, geliştirmede doğrulanmış `cryptography==46.0.0`. Panel/çekirdek bunu gerektirmez; PKI CLI ve bütün test seti gerektirir. Aşağıdaki CSR/verify örneğinde OpenSSL CLI kullanılır; bu da üretim appliance içine dahil edilecek bir araçtır. Kaynak paketini denemek için Linux ortamı esas alınmıştır. Windows/OpenSSL kurulumu bu aşamada doğrulanmadı.

Kripto sürüm pini test tekrar üretimi içindir; güncel güvenlik onayı veya nihai appliance paket pini değildir. İmaj aşamasında güncellemeler, SBOM ve bağımlılık paketlerinin doğrulanmış offline kopyaları hazırlanacak.

## Mevcut veriyi koruyarak başlatma

Komutları kaynak klasöründe çalıştırın ve her seferinde aynı `--state-dir` kullanın. Önce panelde ürün FQDN/domain/DC taslağını kaydedin. Örnek FQDN aşağıda `kaname.lab.example`; kendi kayıtlı adınız farklıysa CSR ve verify komutlarına aynı adı yazın.

```bash
python3 -m kaname.pki --state-dir kaname-state status
python3 -m kaname.pki --state-dir kaname-state init
```

Init CA anahtar parolasını iki kez sorar; UTF-8 ile 16–128 byte uzunluğu kabul edilir. Parola AD parolası değildir. Parolayı komut argümanı veya ortam değişkenine yazmayın. Aynı CA varsa init reddedilir; mevcut anahtarlar değiştirilmez. Eski ayar/policy ve panel access-token korunur. Root ve issuer için farklı RSA anahtarları, sertifika seri numaraları ve kurulum UUID'si üretilir.

## Sunucu anahtarı ve CSR

CA'ya sunucu özel anahtarı gönderilmez; CSR yalnız public key ve talep bilgisi taşır. Örnek anahtar da OpenSSL parolasıyla şifreli oluşturulur:

```bash
umask 077
mkdir -m 700 kaname-state/tls-lab
openssl req -new -newkey rsa:2048 -sha256 -keyout kaname-state/tls-lab/radius.key -out kaname-state/tls-lab/radius.csr -subj "/CN=kaname.lab.example" -addext "subjectAltName=DNS:kaname.lab.example"
python3 -m kaname.pki --state-dir kaname-state issue-radius kaname-state/tls-lab/radius.csr kaname-state/tls-lab/radius.pem
```

Sunucu anahtar parolası ile CA anahtar parolası ayrı roller içindir. Üretim servisinin bunları güvenli açması/key vault'a bağlaması sonraki aşamadır. Bu adım RADIUS servisini etkinleştirmez.

CSR: tek PEM, en fazla 64 KiB, geçerli SHA256/384/512 imzası, RSA 2048–4096/e=65537 veya P-256/P-384, tam bir DNS SAN. SAN kayıtlı FQDN ile birebir eşleşmelidir; wildcard, başka SAN, UPN/email, ilave extension veya CA/istemci EKU talebi reddedilir. CSR subject kopyalanmaz; sertifika subject/SAN/amaç KANAME tarafından belirlenir. Çıktı yolunda eski dosya varsa işlem reddedilir.

Sertifika varsayılan 90 gün, en fazla 365 gün; issuer bitişini aşamaz. CA süresi dolmuşsa veya bir günden az kalmışsa imzalama reddedilir. Root CA path length=1, issuer=0; leaf CA yetkisi taşımaz ve yalnız serverAuth EKU içerir.

## Açık materyali dışa aktar ve doğrula

```bash
python3 -m kaname.pki --state-dir kaname-state export-public kaname-state/tls-lab/public-v1
openssl verify -CAfile kaname-state/tls-lab/public-v1/root-ca.pem -untrusted kaname-state/tls-lab/public-v1/issuer-ca.pem -purpose sslserver -verify_hostname kaname.lab.example kaname-state/tls-lab/radius.pem
```

Public export yalnız root CA, issuer CA ve issuer CRL içerir. Özel anahtar/parola içermez. Hedef dizin yeni olmalı; mevcut dizin üzerine yazılmaz. Güvenilir root CA'nın endpoint'e dağıtılması henüz otomatik değildir. Root güveni ile RADIUS sunucu adı kontrolü birlikte gerekir.

Panelde **Sertifikalar → Durumu yenile** CA UUID/parmak izi/geçerlilik/CRL sürümünü gösterir. Bu salt okunur ekrandır; CA oluşturulmuş olması AD/RADIUS bağlantısının hazır olduğunu göstermez.

## İptal ve CRL

```bash
openssl x509 -in kaname-state/tls-lab/radius.pem -noout -serial
python3 -m kaname.pki --state-dir kaname-state revoke HEX_SERI_NUMARASI --reason key_compromise
python3 -m kaname.pki --state-dir kaname-state refresh-crl
python3 -m kaname.pki --state-dir kaname-state export-public kaname-state/tls-lab/public-v2
openssl verify -CAfile kaname-state/tls-lab/public-v2/root-ca.pem -untrusted kaname-state/tls-lab/public-v2/issuer-ca.pem -CRLfile kaname-state/tls-lab/public-v2/issuer-crl.pem -crl_check -purpose sslserver -verify_hostname kaname.lab.example kaname-state/tls-lab/radius.pem
```

`HEX_SERI_NUMARASI` yerine ilk komutta `serial=` sonrasındaki hex değeri yazın; büyük/küçük harf kabul edilir. Son verify komutu iptal edilmiş sertifikayı reddetmelidir. İptal nedeni key_compromise, superseded veya cessation_of_operation olabilir. Tekrar iptal idempotenttir. CRL geçerliliği en fazla 24 saattir; otomatik yenileme/yayın henüz yoktur. Eski CRL dosyasını dağıtmak iptal doğrulamasını güncellemez; yeni public export gerekir.

## Saklama ve sınırlar

Mevcut `kaname-state/kaname.sqlite3` içine ilave PKI tabloları eklenir. Root ve issuer özel anahtarları aynı operatör parolasıyla şifreli PKCS#8 BLOB'dur. Anahtarlar imaj/source ZIP'e konmaz. Public status API hiçbir key BLOB okumaz. Sertifika/CRL yazımı audit ile aynı transaction'da gerçekleşir; audit insert hatasında geri alınır. Parola yanlışsa veya anahtar/sertifika/CRL bozuksa otomatik CA onarımı/recreate yapılmaz.

Bu henüz üretim anahtar kasası, offline root, HSM, root rollover, issuer renewal, istemci enrollment veya otomatik yedekleme değildir. State klasörünü/parolayı koruyun; üretim CA için bu geliştirme sürümünü kullanmayın. Gerçek AD doğrulaması bağlanmadan istemci imzalama API'si açılmayacak.
