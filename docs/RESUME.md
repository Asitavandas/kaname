# Bağlantı sonrası devam kaydı

Kontrol edilen başlangıç: KANAME 0.1.0-dev.1.

1. Mevcut kaynak klasörü ve kaydedilmiş başlangıç ZIP'i bulundu. 34 kaynak dosyasının SHA256 değeri arşivdeki SOURCE_MANIFEST.json ile eşleşti; değiştirilmiş/kayıp dosya yoktu.
2. Başlangıç ZIP CRC kontrolü geçti. SHA256: `d1b6d5fc0a96cea31f0c16dab348970b7d69192143c74c8410e3d1d21d18e00c`.
3. Mevcut 70 test yeniden çalıştırıldı ve geçti. Yarım kalmış dosya yazımı görülmedi; başlangıç teslimi dosya olarak tamamlanmıştı.
4. Çekirdek politika modeli, validator ve OVF export/verifier yeniden yazılmadı. Dahili PKI ilave modül/tablolar ve CA durum ekranı olarak eklendi.
5. Eski config/policy ve revision değerlerinin yeni PKI işlemleri boyunca korunması otomatik testle doğrulandı. Mevcut CA tekrar init ile silinmez/değiştirilmez.
6. İlk teslim ZIP'i yerinde korunur. Devam teslimi 0.2.0-dev.1 kaynak paketidir; açılabilir OVF değildir.

Kalan bağlantılar: gerçek AD, AD ile kanıtlanan istemci enrollment, FreeRADIUS/EAP-TLS, GPO/trust dağıtımı, üretim panel/servis apply, temiz OVF imajı ve gerçek import/boot. Switch/AP yönetimi kapsam dışı; manuel hazırlanmış cihazlarla gerçek 802.1X testi kapsamda.


## 4 Ekim 2026 — 0.7 yönetim değişiklikleri

Kullanıcı VLAN envanteri, sırasız/çakışan kaydı engelleyen politika, salt okunur filtreli/periyodik AD eşitleme, korumalı parola saklama, ekranda bağlantı alarmı, isimli grup simülasyonu ve RADIUS kaynak IP/secret/1812-1813 port ayarlarını onayladı. AD üyelik yazma, e-posta, timeout/retry ve switch/AP yönetimi dahil edilmedi. Windows çalışma kökü C:\Users\Administrator\KANAME. Ubuntu müşteri VM'i hazır değil. Test/yayın kaydı docs/STATUS_0_7_0.md içinde; mevcut durum korunarak devam edilir.
