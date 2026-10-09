# AuthWire 0.14.0-dev.1 — panel hazırlığı

9 Ekim 2026. Kullanıcı gerçek Windows → Switch/AP → RADIUS → EAP-TLS → VLAN testini pazartesiye (12 Ekim) erteledi. Bu sürüm panel ve kalıcı veri modeli hazırlığıdır. Fiziksel pilot kabulü değildir.

## Ekranlar

- Erişim → Ağ cihazları: marka, model, IP, cihaz türü, konum, not, bağlantı tipi ve yönetim modu. Arama, mod filtresi, ekle/düzenle/sil vardır. IP varsa benzersizdir; Direct hazırlığında IP zorunludur. Cloud kaydında yerel IP isteğe bağlıdır.
- Manual / Import bağlantısızdır. Read Only / Managed için Direct veya Cloud tercihi kaydedilir. Dört modda da bu sürüm cihazlara bağlanmaz, config uygulamaz ve credential toplamaz. Import dosya analizi sonraki aşamadır. RADIUS istemcileri ayrı yönetilir; envanter kaydı RADIUS Client oluşturmaz.
- Erişim kuralları → Gelişmiş kimlik seçimi: User / Computer / Group için son AD kataloğundan aramalı, sayfalı, çoklu seçim; OU için domain içi tam DN; Everyone için tüm doğrulanmış kimlik kapsamı taslağı. Allow/Deny, VLAN ve Wired/Wireless tercihi kaydedilir.
- Seçili kullanıcı/bilgisayar/gruplar ad yerine GUID ve SID ile saklanır. Grup yalnız security group olabilir. OU varlığı bu sürümde AD üzerinde doğrulanmaz. Domain değişince eski taslak açık uyarıyla gösterilir ve yeni domain için yeniden seçilmelidir.

## Çalışma sınırı

Taslaklar `runtime_settings.policy_drafts`, cihazlar `runtime_settings.network_devices` altında saklanır. Runtime `state.policies`, sertifika/PKI/AD bağlantısı ve RADIUS secret kayıtları değiştirilmez. Yeni selector'lar EAP-TLS adapterinin doğrulanmış kimlik bağlamına bağlanana ve test edilene kadar aktif politika olamaz. API `enabled` veya bağlantı credential'larını kabul etmez.

Tüm yazımlar mevcut global revision lease ve append-only audit transaction'ını kullanır. Stale kayıt 409 döner. Audit başarısızsa veri ve revision da geri alınır. Custom profil için `network.devices` varsayılan `none`; SuperAdmin write ve Admin_ReadOnly read alır. Mevcut yetkiler genişletilmez. Taslak yönetimi `policies.rules` yetkisini kullanır; hedef katalog API'si aynı kural yetkisiyle sınırlıdır.

## Doğrulama

`tests.test_planning`: dört yönetim modu, CRUD/restart, credential kapalı şema, IP çakışması, stale revision, audit rollback, beş selector, OU/domain sınırı, GUID/SID eşlemesi, eski politika kararı ve konfigürasyonun korunması.

`tests.test_admin`: yeni endpoint'lerde read-only/custom/CSRF ve HTTP CRUD sınırları. `tools/planning_ui_smoke.cjs`: fixture ile UI kayıt/düzenleme/filtre, beş selector, taslak kalıcılığı, stale yazım, silme, logout temizliği, metin güvenliği ve ekran taşması. Browser CI mevcut panel ve certificate UI kontrollerine ek bu akışı çalıştırır.

Yerel kaynak alımında GitHub connector PNG binary'yi sağlamadı. Bu nedenle yerel tam testte mevcut logo staging testi çalıştırılamadı; repo logo blob'u değiştirilmez. Tam testler ve görsel akışlar orijinal logo ile GitHub CI'da doğrulanmalıdır. Bu kısıt UI veya canlı ağ başarısı gibi gösterilmez.

## Devam

Önce bu panel hazırlığı testlerden geçirilir ve mevcut güvenli Linux güncelleme akışıyla yüklenir. Pazartesi gerçek EAP-TLS pilotu yapılır. Otomatik GPO yazma, switch config apply/rollback, cloud vendor adapterleri, VLAN discovery ve canlı topoloji henüz uygulanmaz. Temel ürün tamamlandığında daha önce konuşulan 1–7 genişletme önerileri kullanıcıya tekrar sunulacaktır.
