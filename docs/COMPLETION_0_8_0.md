# KANAME 0.8.0-dev.1 — Linux laboratuvar teslim durumu

Kaynak commit: `07fcff58f87670954b46e6a7c2e71e3a11fc9649`.

## Tamamlanan doğrulamalar

- Linux runner: 276 test, hata yok, 13 platform/bağımlılık testi atlandı.
- Windows runner: 276 test, hata yok, 10 platform testi atlandı. Kurulu Windows uygulaması güncellenmedi.
- Geçici Ubuntu native LDAP okuyucusu: 10 test başarılı; sayfalama, domain scope, binary SID/GUID, referral reddi, büyük grup üyelikleri ve kapsamlı grup sorguları.
- Geçici Ubuntu gerçek ilk kurulum: non-root systemd servisi, sertifika doğrulamalı HTTPS erişimi ve parola değişikliğinin servis yeniden başlatılınca korunması başarılı. Fixture DC kullanıldı; müşteri AD kimlik doğrulaması yapılmadı.

Doğrulama kayıtları:
- [Linux native, kurulum ve kaynak hazırlama](https://github.com/Asitavandas/kaname/actions/runs/37217561068)
- [Windows](https://github.com/Asitavandas/kaname/actions/runs/37217561083)
- [Temel kontroller](https://github.com/Asitavandas/kaname/actions/runs/37217561066)
- [Tarayıcı](https://github.com/Asitavandas/kaname/actions/runs/37217156838)
- [RADIUS fixture](https://github.com/Asitavandas/kaname/actions/runs/37217156840)

## Hazırlanan kaynak

Runner kullanıcısının home dizininde `kaname-stage-07fcff58f876` klasörü hazırlandı; 54 kaynak dosyası vardır.
Manifest SHA256:

`199134a1d3a628c1eb70e906aa9ba87aa6805232fc0337d3a31f0ad47eba8ab4`

Bu iş sudo kullanmadı; müşteri AD'sine bağlanmadı ve gerçek KANAME sistem servisini kurmadı.

## Bekleyen yerel kabul

Operatör bir kez `tools/linux_install.py` aracını sudo ile, doğrulanmış manifest hash'i ve yerel domain/DC/panel IP parametreleriyle çalıştırmalıdır. Ayrıntılar [Linux kurulum rehberinde](LINUX_SETUP_0_8_0.md).

Sonrasında HTTPS panelde AD okuma hesabı kaydedilmeli; gerçek Kerberos/GSSAPI bağlantısı, manuel/periyodik eşitleme, kapsam, hata uyarıları ve yeniden başlatma davranışı doğrulanmalıdır. Parola GitHub'a veya terminal komutuna yazılmaz.

Bu teslim Linux laboratuvar paneli ve AD okuyucusudur. Üretim RADIUS dinleyicisi/accounting, istemci sertifika enrollment ve açılabilir OVF henüz tamamlanmadı. Switch/AP ayarları operatör tarafından manuel yapılır.

Sürüm kabulü sonrasında sorular ve değişiklik istekleri alınacak; operatör yanıtı gelmeden sonraki sürüme geçilmeyecek.


## Operatör kabulü — 4 Ekim 2026

Operatör ilk Ubuntu kurulumunda installed=true ve active çıktısını paylaştı. Sonrasında panelde AD eşitlemesinin başarılı olduğunu ve kullanıcılar/üyeliklerin güncellendiğini bildirdi. Şimdilik soru olmadığını, değişiklik isteklerini ayrıca ileteceğini söyledi. HTTPS lab kurulumu ve gerçek AD katalog kabulü tamamlandı. Bu kabul RADIUS üzerinden gerçek cihaz kimlik doğrulaması değildir.
