# Birleşik worker kuruldu — panelden içerik doğrulama görevi

28 Ekim2026 operator Apply sonucu kabul edildi. Connector release689649c0-61df-40aa-bbfb-b84fa1cc2ac0.
Kanıt: C:\ProgramData\AuthWire-ConnectorUpgradeEvidence-689649c061df40aabbfbb84fa1cc2ac0-69466a1b270542f9832734e1055622f7.
Bu kayıt görevin gönderildiğini veya adayın doğrulandığını iddia etmez.

1. Paneli Ctrl+F5 ile yenile.
2. İmzalı dağıtım adayları bölümündeki **AuthWire Pilot - Merkezi Windows · v1 · Birleşik paket** satırını bul.
3. **Doğrulamayı önizle**. Manifest124360dc...431c5b ve taslak5dd35e4d...a0ce5 aynı kayıt olmalı.
4. **Doğrulamayı gönder**.
5. Yaklaşık30–60 saniye sonra bölümün **Yenile** düğmesiyle aynı görevi izle.

Beklenen mesaj: **İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.**
Bu işlem sertifika kurulumu+ağ profillerini birlikte doğrular; deployment artifact çalıştırmaz,
GPO veya cihazlara dağıtım başlatmaz. Ağ profilleri satırının eski sonucu birleşik kabul sayılmaz.
queued/leased durumunda tekrar görev gönderilmez. Düğme kapalıysa/yoksa veya içerik reddedilirse
mevcut durum ekranı incelenir; paket yeniden üretilmez/imzalanmaz ve Apply tekrar çalıştırılmaz.

Sonuç operatör ekranıyla paylaşılınca kayıt güncellenecek; taze birleşik kapsam ve staging sonraki açık adımlardır.
