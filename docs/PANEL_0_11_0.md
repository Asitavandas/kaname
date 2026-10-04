# KANAME 0.11.0-dev.1 — günlük kullanım ve sıralı menü

Kullanıcı eski görünüm ve renk kısıtlarını kaldırarak paneli daha tanıdık, sade ve kolay yönetilir hale getirme yetkisi verdi. Menü, saklanan alt başlıklar yerine görünür Hazırla → Kullanıcılar → Erişim → Kontrol et sırasını izler. Yönetim bölümü panel hesaplarını AD hesaplarından ayırır. Numara bir zorunluluk veya policy önceliği değildir; her ekran doğrudan açılır.

Kontrol merkezi son AD okumasındaki kullanıcı ve grup sayılarını, kayıtlı kural sayısını ve CA durumunu gösterir. Yetkisiz alanlar sayım üretmez. Hazırlık durumu bağlantının şu anda sağlıklı veya ağ erişiminin etkin olduğu anlamına gelmez. Lab/RADIUS sınırı görünür kalır. Sayısal veriler yalnız yetkiyle dönen sunucu durumundan alınır.

Kullanıcılar ve gruplar ayrı ARIA sekmelerindedir; klavye okları, Home/End ve sunucuda sayfalı arama korunur. Avatar, ad, hesap ve durum satırları textContent kullanır. Üyelik ayrıntıları ve güvenlik grubundan kural seçimi mevcut API ile çalışır. AD salt okunur; hesap oluşturma, silme veya değiştirme eklenmez. Mobil menü açma, kapatma ve Escape içerir; localStorage kullanılmaz.

Yeni görünüm açık çalışma alanı, mavi işlem düğmeleri ve lacivert/lime kontrol merkezi kullanır. Mevcut PKI sekmeleri, geçici sırların temizlenmesi, HTTPS, API, veritabanı, yetki kontrolü ve güncelleme mekanizması korunur. Kullanıcının ertelediği gerçek AD kullanıcı sertifikası testi otomatik yürütülmez.

Doğrulama: browser workflow masaüstü/mobil görüntüler, menü sırası, direkt geçiş, mobil aç/kapa, ARIA sekmeleri, kullanıcı araması ve önceki tüm işlev/yetki kontrollerini çalıştırır. Foundation ve linux-stage mevcut testleri zorunludur. Ekran görüntüleri yalnız geçici fixture verisidir. Yerel sudo updater çalıştırılana kadar canlı sürüm değişmez.
