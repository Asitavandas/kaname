# KANAME 0.10.1-dev.1 — kompakt bakır/krem arayüz

Kullanıcının seçtiği 1 numaralı kompakt tasarım uygulanır: ana arka plan #F5EFEB, sol menü #2B2B2B, menü yazıları ve ikonlar #C88565. Bakır buton üzerinde koyu metin, küçük kontroller, altı Türkçe menü grubu ve genel bakış ekranı vardır. Genel bakış mevcut yetkilere göre dönen durum bilgisini kullanır; AD kataloğu canlı bağlantı kanıtı olarak gösterilmez.

Sertifikalar liste, otorite ve iptal listesi sekmelerine ayrılır. CA parmak izleri otorite sekmesinde bulunur. Oluşturma ve iptal formları sağdan açılır; kapatınca, sekme/ekran değişince veya oturum kapanınca parolalar ve geçici CSR temizlenir. PEM CSR dosyası seçilebilir; özel anahtar veya 64 KB üstü dosya reddedilir. Form alanına alma kriptografik doğrulama değildir; mevcut sunucu doğrulamaları devam eder. Arama yalnız yüklenen sertifika sayfasını filtreler. İptal onayı ve geri alınamazlık uyarısı korunur.

API, policy modeli, AD okuma/enrollment doğrulaması ve veritabanı şeması değiştirilmez. Müşteri ortamında AD kullanıcı sertifikası testi kullanıcı isteğiyle ertelenmiştir; UI fixture testleri bu kabulün yerine geçmez. Gerçek AD veya RADIUS testi otomatik başlatılmaz.

Yerel mevcut 321 test: başarılı (15 ortam bağımlı test atlandı). Browser workflow mevcut kullanıcı/profil, politika, AD fixture, ağ kaydı ve izin sınırı kontrollerine tema rengi, kontrol yüksekliği, sekme klavyesi, CSR/private key ayrımı, sırların kapatınca temizlenmesi ve dar ekran yatay taşma kontrollerini ekler. Ekran görüntüleri yalnız geçici fixture verisidir.

Dağıtım: linux-stage kaynak manifesti ve digest'i doğrulanır; mevcut yerel tools/linux_update.py yedek alır ve aynı HTTPS kimliğiyle health/preservation kontrolü yapar. Kullanıcı yerel sudo komutunu çalıştırana kadar çalışan Ubuntu paneli önceki sürümde kalır. Windows kurulumuna değişiklik uygulanmaz.
