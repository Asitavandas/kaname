# Domain kökünden AD sorgusu — 0.3.2-dev.1

0.3.1 sürümündeki gerçek laboratuvar denemesi `AD_SEARCH_FAILED`, `users_search`, `UNKNOWN` sonucunu verdi. Bu kod yolu bind ve RootDSE/domain kontrolünden sonra çalışır. SID/GUID dönüşümü öncesindedir.

Windows'ta gerçek .NET LDAP istemcisini kullanan, yalnız 127.0.0.1 üzerinde çalışan bir LDAP protokol fixture'ı eklendi. Kullanıcı sorgusu, iki sayfalı sonuç, metin/ikili öznitelik dönüşümü, grup ve bilgisayar sorgusu bu fixture ile başarılı oldu. Beklenmeyen referral döndürülen test, aynı sorgu aşamasında hata oluşturdu. Böylece yalnız SID/GUID dönüşüm testinin gerçek sorgu davranışını kapsamadığı görüldü.

Microsoft dokümantasyonuna göre domain kökünden subtree aramaları DomainDnsZones, ForestDnsZones, configuration veya alt-domain naming context'lerine continuation referral döndürebilir. İlk okuyucu referral chasing'i kapatıyor ancak response içindeki tüm referansları da reddediyordu. Gerçek laboratuvar hatası bu davranışla uyumludur; önceki hata raporu referans sayısını ayırmadığından kullanıcının tam cevabı elde edilmiş değildir.

## Düzeltme

Her kullanıcı/grup/bilgisayar LDAP sorgu sayfasına kritik `LDAP_SERVER_DOMAIN_SCOPE_OID` (`1.2.840.113556.1.4.1339`) eklendi. Kontrol aramayı kimliği doğrulanmış domain naming context'iyle sınırlar ve continuation referral üretimini engeller. Kerberos, signing/sealing, DC DNS/IP ve RootDSE domain kontrolü korunur. Referral chasing kapalıdır. Kontrole rağmen gelen beklenmeyen referans hâlâ reddedilir ve artık `REFERRAL_RETURNED` sabit nedeni gösterilir. Kontrolün tanınmaması halinde kapsamı genişleten fallback uygulanmaz.

Bu sürüm tek kayıtlı domain'in kataloğunu okur; forest/child-domain kataloğu toplamaz. Başarısız okuma, önceki katalog ve kullanıcı yapılandırmasını değiştirmez.

## Test kanıtı

- [Windows Python 3.14.8](https://github.com/Asitavandas/kaname/actions/runs/37149745358): 174 test, 172 başarılı, 2 ortam/platform nedeniyle atlandı. Windows .NET LDAP wire fixture, her sayfada kritik domain-scope kontrolünün doğru OID/critical/value biçiminde gönderildiğini doğrular.
- [Linux Python 3.12](https://github.com/Asitavandas/kaname/actions/runs/37149745359): 174 test, 169 başarılı, Windows'a özel 5 test atlandı.
- [Chromium](https://github.com/Asitavandas/kaname/actions/runs/37149745407): panel ve fixture dizin akışları başarılı.
- [Windows güncelleme](https://github.com/Asitavandas/kaname/actions/runs/37149745465): commit `e4f644d95e8e9cb6bbae4708b4b4ca8ba02087ff`, 0.3.1 → 0.3.2 kaynak geçişi; mevcut state/CA/token koruma kapısı.

Güncelleme başarılı ve yerel yedek oluşturuldu. Yapılandırma, politika, CA ve token koruma kontrolleri geçti; revision 10 korundu. Panel HTTP 200 döndü, mevcut tokenı kabul etti ve yerel state ile eşleşti. Kaynak manifestinde eksik/değişmiş dosya bulunmadı.

Fixture anonim LDAP'yi yalnız açık SelfTest/FixturePort CLI test modunda sabit loopback hedefinde kullanır. Üretim API'si bu seçenekleri çağırmaz ve üretim okuyucu Kerberos korumasından çıkmaz. Fixture'a gerçek AD kimlik bilgisi, gerçek kullanıcı/grup verisi veya dış ağ adresi verilmez.

Gerçek AD kataloğunun başarılı okunduğu henüz doğrulanmadı. Operatör Windows panelini Ctrl+F5 ile yenileyip kimlik bilgilerini yalnız yerel Active Directory ekranında yeniden girerek denemelidir. Başarıda kategori sayıları, hatada sabit aşama/neden kodları yeterlidir; parola/token gönderilmez.

Microsoft kaynakları:
- https://learn.microsoft.com/en-us/previous-versions/windows/desktop/ldap/ldap-server-domain-scope-oid
- https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/ldap-paged-queries-subordinate-referrals-not-chased
