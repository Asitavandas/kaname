# KANAME 0.9.0-dev.1 — kaynak doğrulama ve yerel AD kabul adımı

Ubuntu'daki çalışan 0.8 paneli ve Windows'taki 0.7 kurulumu güncellenmedi. Operatör Ubuntu ilk kurulumunu ve gerçek AD katalog/üyelik eşitlemesini kabul etti.

## Doğrulanan kaynak ve stage

Runtime kaynak commit'i: `9946cd804e787dcc9b8c4fc0dc5ceffbed1a8613`.
Windows CI bağımsızlaştırma commit'i: `0ecdaf8b872c4c8417b2a21dff22fb8bb8ebfa47`; runtime dosyaları aynı.

Linux runner home stage klasörü: `kaname-stage-9946cd804e78`.
Dosya sayısı: 58.
Manifest SHA256: `581299c83b145c2de31cd6049595508ce42ce54b567bdfb1b24fefa29bbfce97`.

- [Genel core/PKI/HTTPS/HTTP kontrolleri](https://github.com/Asitavandas/kaname/actions/runs/37221348063): başarılı; 293 test, 14 platform/bağımlılık skip.
- [Linux native ve kaynak hazırlama](https://github.com/Asitavandas/kaname/actions/runs/37221086065): başarılı. 27 native/koruma testi; gerçek disposable Ubuntu installer/HTTPS/non-root/restart parola korunması geçti. Self-hosted runner 293 test, 14 skip ve doğrulanmış stage.
- [Tarayıcı](https://github.com/Asitavandas/kaname/actions/runs/37220983616): başarılı.
- [Native RADIUS/EAP-TLS](https://github.com/Asitavandas/kaname/actions/runs/37220983648): 24 senaryo başarılı, gerçek kalıcı registry okuyucusu kullanıldı. AD/enrollment fixture; müşteri ağ servisi açılmadı.
- [Geçici Windows kontrolleri](https://github.com/Asitavandas/kaname/actions/runs/37221348081): başarılı; 293 test, 11 platform skip.

Native CI önce OS cryptography 41 ile yeni sertifika UTC API'sinde başarısız oldu; test ortamı ürünün sabit 46.0.0 bağımlılığını isolated venv içinde kullanacak şekilde düzeltildi. Self-hosted fixture'da bir HTTP login 8 saniye timeout yaptı; kaynak değişmeden başarısız job tekrarında bütün 293 test geçti. Bu olayın nedeninin düzeltildiği veya performans/DoS kabulünün tamamlandığı iddia edilmez.

Eski self-hosted Windows validation kuyruğu son teslimin Windows kanıtı değildir; bundan sonraki Windows fixture işleri ayrı concurrency grubundaki geçici Windows runner'da çalışır.

## Operatörden beklenen

Yerel sudo ile stage içindeki `tools/linux_authorization_check.py --source-digest 581299c83b145c2de31cd6049595508ce42ce54b567bdfb1b24fefa29bbfce97` çalıştırılır. Araç mevcut saved AD ayarını kullanarak servis hesabıyla tek GUID/tokenGroups sorgusunu kontrol eder; çalışan panel source/state reset, restart veya paket kurma yapmaz. Katalog yalnız örnek GUID seçmek içindir; izin bilgisi gerçek AD'den yeniden okunur.

Beklenen çıktı: checked=true ve bulunan hesap için account_found=true. Hesap enabled/kind ve security_group_count ayrıca bildirilir; gerçek grup sayısı için sabit bir beklenen sayı yoktur. AD private bilgileri/password/UUID/SID çıktıya yazılmaz. Bu gerçek AD security-token sorgusu sonucu henüz operatörden gelmedi.

## Sonraki bağımlılıklar

Authenticated endpoint enrollment ve trust dağıtımı; controlled FreeRADIUS service apply; manual switch/AP üzerinde fiziksel kablolu/kablosuz EAP-TLS ve VLAN; accounting; appliance hardening/OVF import/boot.

Bu kaynak, tamamlanmış NPS alternatifi veya canlı 802.1X kabulü değildir. Yeni sürüm teslimi sonrası operatörün soruları/değişiklik istekleri alınır; sonraki sürüm yanıtından sonra başlar.
