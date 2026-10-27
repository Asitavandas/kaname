# AuthWire AD ve GPO salt okunur görev kanalı

Durum: dev.40 sunucu ve panel hazırlığı. Yeni Windows scope worker teslimatı ve
gerçek gMSA panel görevi kabulü ayrıca gereklidir. Bu belge çalışan bir GPO
uygulama özelliği veya tamamlanmış merkezi dağıtım iddiası değildir.

## Ayrı kabul kapısı

Mevcut `candidate.verify.v1` yalnız imza ve ağ paketinin içeriğini doğrular.
Yeni işlem `deployment.scope.verify.v1`, aynı aday için ayrı bir okuma sonucu
bekler. Yalnız yönetici tarafından yapıştırılan kontrol çıktısı bu kuyruğu
tamamlayamaz. Özel anahtar veya yönetici parolası Linux'a taşınmaz.

Yeni Windows worker önce mevcut içeriği yeniden doğrulamalı; canlı recursive AD
bilgisayar SID'leri ve etkinlikleri, yönetilen GPO kimliği/sahiplik işareti,
izinleri, link bulunmaması, boş ayar/sürüm durumu ve kök SYSVOL ACL kapsamını
okumalıdır. Bu ilk protokol yalnız mevcut makine Ethernet ve Wi-Fi adayını ve
boş, bağlantısız owned GPO hazırlık durumunu destekler. Kullanıcı dağıtımı,
GPO link verme, dosya yazma, etkin yazma hakkı testi veya tam SYSVOL alt ağaç
doğrulaması değildir. Okuma süre ve çıktı sınırları Windows worker teslimatında
ayrıca test edilmeden müşteri komutu verilmez.

## Sunucu protokolü

- Ayrı kayıt: `windows_deployment_scope_jobs`.
- Peer yolları: `/api/connector/v1/scope/poll` ve `/api/connector/v1/scope/result`.
- İmza amacı: `AUTHWIRE-SCOPE-JOB-POLL-V1` veya `AUTHWIRE-SCOPE-JOB-RESULT-V1`.
- Poll payload tam iki alan: `capability=deployment.scope.verify.v1`, `release_id`.
- Aynı RSA, kurulum/host/SID/key/binding kapsamı, TLS, süre, nonce, gövde özeti,
  HTTP yöntemi/yolu ve replay kontrolleri korunur. Eski probe veya içerik worker
  bu kuyruğa ulaşamaz. Yeni capability son 90 saniyede görülmeden create reddedilir.
- Yönetici önizleme ve oluşturma yolları:
  `/api/deployment/candidates/scope/preview` ve `/scope/create`.
  Her ikisi de güncel `certificates.authority` ve `system.connectors` yazma
  yetkisi, panel oturumu, HTTPS, Host/Origin ve CSRF denetimi gerektirir.

İş hedefi tam şu alanlardan oluşur: `candidate_id`, `plan_id`, `plan_version`,
`gpo_id`, `approval_sha256`, `manifest_sha256`, `dependency_sha256`,
`target_sids_sha256`, `target_count`. Mevcut içeriğin kabul edilmiş olması ve
güncel plan/profile/catalog/config/trust ile aynı kalması zorunludur.
Hedef bilgisayarlar tüm recursive katalog üyeliğinden hesaplanır; UI'deki ilk
20 örnek kayıt kullanılmaz. Desteklenen sözleşme sınırı 1–512 etkin bilgisayardır;
bu bir 200 cihaz performans/saha kabulü değildir. Çözümlenemeyen, kapalı veya
farklı domain SID kapsamındaki hedefler reddedilir.

SID özeti ASCII SHA256'dır:
`AuthWireDeploymentTargetsV1\n` + sıralı SID'lerin her birinin sonunda `\n`.
İş niyeti aynı hedefin canonical JSON digest'ini, binding kapsamını ve iş UUID'sini
`AuthWireDeploymentScopeIntentV1` amacıyla bağlar. Komut, yol, script, filtre
veya URL kabul edilmez.

## Sonuç ve güncellik

Tam sonuç alanları: `job_id`, `lease_id`, `intent_sha256`, `outcome`, `release_id`,
`target_sha256`, `checked_at`, `checks`, `reason`, `observations_sha256`.

Başarı: `outcome=scope_snapshot_verified`, `reason=OK` ve sıralı tam kontrol listesi
`content`, `directory`, `gpo_identity`, `gpo_permissions`, `gpo_unlinked`,
`gpo_empty`, `sysvol_root_acl`. `observations_sha256` worker'ın sınırlandırılmış
normalize okuma snapshot'ının özetidir; sunucuya özel anahtar veya ham GPO içeriği
gönderilmez. Bu özet tek başına bir kontrolün yapıldığının kanıtı sayılmaz; tam
sonuç önceden eşleştirilmiş worker tarafından imzalanmış olmalıdır.

Ret: `scope_snapshot_rejected`, boş `checks`, yalnız `CONTENT_REJECTED`,
`DIRECTORY_SCOPE_CHANGED`, `GPO_SCOPE_CHANGED`, `READ_TIMEOUT` veya `READ_FAILED`.
Başarı zamanı iş oluşturma ile lease bitişi arasında olmalı; ilk tamamlanma
sırasında 90 saniyeden eski veya gelecekte olamaz. Payload sınırı mevcut 1024
bayt olarak korunur. Ham peer istek üst sınırı 4096 bayttır.

İş ömrü 300, lease 90 saniye; eski lease yeniden dağıtılmaz. Kuyruk 32 kayıtla
sınırlı ve tek güncel aktif iş içerir; dolu defter sessizce temizlenmez. Tekrarlı
aynı oluşturma/sonuç idempotenttir, farklı sonuç reddedilir, audit hatasında yazma
geri alınır. Katalog, içerik kabulü veya binding değişirse sonuç geçersiz olur.
Yalnız `synced_at` damgası değişmesi semantik kapsam değişikliği sayılmaz.

Panel tarihi başarılı snapshot ile son 90 saniyedeki güncel snapshot'ı ayırır.
Sürenin dolması, canlı AD'nin aynı kaldığını kanıtlamaz; sonraki uygulama kapısı
tekrar güncel kontrol gerektirecektir. Sonradan gelen ret önceki başarı görünümünü
kaldırır. `connector_verified=false` ve `can_apply=false` her durumda korunur.

## Teslimat sınırı

Bu adım yeni Windows kodunu veya çalışan hizmeti değiştirmez. Mevcut worker
`candidate.verify.v1` ile çalışmaya devam eder. Scope worker'ın ayrı gözden
geçirilmiş, imzalı ve süre sınırları test edilmiş yükseltmesi gereklidir. Ondan
önce panel scope düğmesi capability yokluğunda kapalı kalır. Testteki RSA/HTTPS
scope sonuçları protokol fixture'ıdır; gerçek müşteri AD/GPO okuması değildir.
