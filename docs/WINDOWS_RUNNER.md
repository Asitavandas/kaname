# Windows lab bağlantısı

Bu bağlantı yalnız KANAME geliştirme/test içindir. Üretim appliance'ı GitHub'a bağımlı olmayacak.

- Depo: Asitavandas/kaname (private).
- Kullanıcının bildirdiği kurulum: C:\Users\Administrator\KANAME.
- Runner: aynı Windows hesabında çalışan interactive GitHub runner, `kaname-windows` etiketi.
- Akış: `.github/workflows/windows-diagnostics.yml`.
- Otomatik tetik: main üzerinde yalnız tanılama dosyası değişiklikleri; ayrıca manuel workflow_dispatch. PR tetikleyicisi yok.
- Çalıştırıcı depo kodunu çalıştırır; bu depoya yazma yetkisi güvenilen kişilerle sınırlı tutulmalı.

Tanılama mevcut kurulumu başlatmaz, migration yapmaz, ayar veya politika kaydetmez, CA başlatmaz, Windows servisi/firewall ayarı değiştirmez. Geçerli yerel panel ve token bulunursa localhost'tan mevcut state okunur; eşleşen politika, domain dışı cihaz ve hesap kapalı senaryoları simüle edilir. Sonuçlar mevcut politikanın gerektirdiği davranışla karşılaştırılır; her kurulumda aynı allow/deny sonucu varsayılmaz. Bu simülasyon ağ trafiğini yönetmez, veri kaydetmez ve gerçek AD/RADIUS testi değildir.

Rapor yalnız kontrol sonuçları, kaynak paketindeki bilinen dosyaların eksik/değişmiş listesi ve sayısal özetleri içerir. Token yalnız süreç belleğinde tutulur; HTTP yönlendirmeleri ve proxy kullanımı kapalıdır. Database read-only açılır; özel anahtar kolonları sorgulanmaz. Yerel config alanları, kullanıcı/grup bilgileri, parolalar ve anahtarlar loglara/artifact'a yüklenmez. Panonun veya daha önce tarayıcıda yapılan işlemlerin geçmişi belirlenemez.

Akış python/dependency kurulumu yapmaz. Bir sorun bulunduğunda onarım ayrı ve mevcut state korunarak hazırlanır. Çalıştırıcı çevrimdışıysa veya etiketi uyuşmuyorsa iş kuyrukta bekler; bu durum KANAME hatası sayılmaz.
