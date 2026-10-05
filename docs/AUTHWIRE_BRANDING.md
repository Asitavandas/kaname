# AuthWire adı ve logosu — 0.11.1-dev.1

Ürünün yeni adı AuthWire. Kullanıcının sağladığı üst Λ / alt W metal amblemi, görsel düzenleme aracıyla plaka arka planından ayrılarak transparan PNG olarak panele eklenir. Wordmark gerçek AuthWire metnidir. Logo sol menüde, giriş ekranında, kontrol merkezinde ve sekme ikonunda sunucunun kendi statik yolu üzerinden sunulur; istemcinin dış servise erişmesi gerekmez.

Paneldeki başlık, yardım, pencere adı, RADIUS açıklaması ve indirilen sertifika dosya adları AuthWire olur. Health/API ürün adı ve yeni oluşturulacak sertifika/CSR subject adları da AuthWire olur. Linux güncelleme/geri dönüş ve eski Windows kontrol araçları iki ürün adını kabul eder.

Kurulu kaname Python paket yolu, servis/dizin adları, kaynak artifact kimliği, X-Kaname-CSRF başlığı, oturum cookie kimliği ve DPAPI entropy değişmez. Parolalar bir marka metni olarak değiştirilmez. Önceden oluşturulmuş CA veya sertifikaların imzalı subject bilgisi yeniden yazılmaz ve CA yeniden oluşturulmaz. Bu uyumluluk kimlikleri mevcut kurulum/veriye erişimi korur; ürün ekranında gösterilmez.

Logo source manifest'e dahil edilir ve tüm kaynak dosyaları gibi digest ile doğrulanır. Güncelleme ayar ve yönetici koruması, HTTPS kimliği ve yedek davranışını korur. Gerçek müşteri AD sertifika testi ertelenmiş kalır; otomatik başlatılmaz.
