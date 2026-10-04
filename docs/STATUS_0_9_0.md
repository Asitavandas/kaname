# KANAME 0.9.0-dev.1 — canlı AD yetkilendirme temeli

Operatör Ubuntu 0.8 lab kurulumu, gerçek AD eşitlemesi ve güncellenmiş kullanıcı/üyelikleri kabul etti. Windows 0.7 ve çalışan Ubuntu 0.8 kurulumları korunur. Bu kaynak teslimi panel yükseltmesi veya üretim RADIUS servis kurulumu değildir.

## Eklenen sınır

Sertifika kimliği pinned issuer SHA256 + serial ile kayıtlı AD domain/objectGUID/SID/tür bağına çözülür. Salt okunur registry kaydı, sertifikanın gerçek issuer imzası, clientAuth EKU, validity ve revocation kaydıyla birlikte kontrol eder. Kayıt eksikse veya geçersizse ret verir. Ürün endpoint enrollment veya kayıt yazma endpoint'i açmaz; native testteki kayıtlar yalnız fixture state'indedir.

Linux live provider her çağrıda panelin kayıtlı korumalı AD bağlantısını kullanır. Kerberos/GSSAPI signing/sealing ve IP/DC pinning korunur. Değiştirilemez GUID binary escaped LDAP filtresiyle bulunur; bilgisayar/kullanıcı hesabında BASE kapsamlı tokenGroups sorgulanır. Bu alan AD'nin transitive güvenlik grubu hesabıdır; panelin structural/distribution üyelik grafiğiyle değiştirilmez. Primary SID'nin bulunması ve bütün yanıtın geçerliliği gerekir. Eksik/ranged/duplicate/256 üstü üyelik, yanlış GUID/SID/tür, referral veya sorgu hatasında ret verilir.

Account disabled, computed lockout ve accountExpires bitişi erişimi engeller. Şifre bitişi EAP-TLS hesabını ayrıca kapalı saymaz; parola yöntemi uyumluluğu farklı aşamadır. Güvenlik kararı son başarılı katalogdan verilmez. Silinen hesap bulunamadı sonucu verir. Aynı isimle yeniden oluşturulmuş farklı SID/GUID eski sertifikayı yetkilendiremez.

Bu lab sağlayıcı bir anda tek pahalı AD sorgusuna izin verir; busy istek ret verir, kuyruk/cache allow yoktur. Bir sorguda Kerberos ticket acquisition vardır; ölçek/performance/session lifecycle üretim kabulü tamamlanmadı. Hatalı credential saptanırsa kalıcı pause panel bağlantısı tekrar kaydedilince temizlenir. Eşzamanlı configuration revision değişikliği sonucu geçersiz kılar.

## Gerçek AD tanılama

Test edilen kaynak runner home'unda yeni stage klasöründe hazırlandıktan sonra operatör `tools/linux_authorization_check.py --source-digest MANIFEST_SHA256` aracını yerel sudo ile çalıştırabilir. Launcher kaynak hash'lerini doğrular, root-owned geçici kodu /run altında oluşturur ve işlemi kaname-lab hesabına düşürür. Eski venv/state ve panelde kaydedilmiş bağlantı kullanılır. Kaynaktaki /opt kodu, servis, ağ, paketler veya panel sürümü değiştirilmez.

Katalog yalnız örnek GUID seçmek içindir: bilgisayar varsa ilk bilgisayar, yoksa ilk kullanıcı seçilir. Yetki bilgisi aynı anda gerçek AD'den yeniden okunur. Yalnız found/enabled/kind/security group count ve sabit özet flag'leri yazılır; username/password/domain/IP/GUID/SID veya grup adı çıktıya girmez. Bu test yeni endpoint private key sahipliğini, enrollment ya da EAP-TLS kimliğini kanıtlamaz. Hatalı kayıtlı parola saptanırsa panelin mevcut health uyarısı/pause durumu güncellenebilir.

TokenGroups hesaplamak için AD tarafında erişilebilir Global Catalog gerekir; eksikse silently daha az grup veya katalog fallback'i yapılmaz. İlgili domain controller üzerinde bu hesap mümkün değilse tanılama başarısız olur. KANAME ayrı bir CA veya cloud servisine başvurmaz.

## Doğrulama

- Birim testleri: GUID filtreleme/BASE, yanlış/tam olmayan token yanıtı, disabled/lockout/expiry, eşzamanlı değişiklik, bad credential pause, secret cleanup, registry restart/revocation ve kimlik alanı maskeleme.
- Native LDAP fixture: gerçek OpenLDAP wire/parser ile grup kaldırılması, kapalı/silinmiş hesap, token eksikliği ve critical domain-scope. Anonymous loopback yalnız test içindir; gerçek Kerberos başarı iddiası değildir.
- Native FreeRADIUS/eapol_test: kalıcı registry okuyucusuyla gerçek sertifika, EAP-TLS, Accept/Reject/VLAN/bütünlük senaryoları. AD ve enrollment fixture'dır.
- Mevcut core, HTTPS, panel, Windows ve Linux testleri ayrı çalışır.

Gerçek AD tokenGroups tanılaması operatör sonucunu bekler. Sonraki adım authenticated endpoint enrollment, istemci trust dağıtımı, kontrollü servis apply ve fiziksel Windows kablolu/kablosuz 802.1X'tir. Switch/AP cihaz yönetimi dahil değildir.

Kaynaklar:
- https://learn.microsoft.com/en-us/windows/win32/adschema/a-tokengroups
- https://learn.microsoft.com/en-us/windows/win32/adschema/a-accountexpires
- https://learn.microsoft.com/en-us/windows/win32/adschema/a-msds-user-account-control-computed
- https://www.python-ldap.org/en/latest/reference/ldap.html

Her tamamlanan sürüm tesliminden sonra operatörün soru/değişiklik yanıtı alınır; sonraki sürüm bu yanıttan sonra başlar.
