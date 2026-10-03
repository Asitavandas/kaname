# AD_SEARCH_FAILED incelemesi — 0.3.1-dev.1

Kullanıcının ilk denemesi `administrator` biçimi nedeniyle INVALID_INPUT verdi. UPN biçimine geçilen ikinci denemede AD_SEARCH_FAILED görüldü. İkinci hata, okuyucunun bind sonrasındaki sorgu/öznitelik işleme yolundan geldi; önceki kod kesin sorgu aşamasını raporlamıyordu.

Kod incelemesinde SID/GUID için LDAP DirectoryAttribute indexer'ına doğrudan erişildiği bulundu. Bu indexer bazı ikili değerleri UTF-8 metni olarak döndürebilir. Okuyucu artık SID/GUID değerlerini `GetValues([byte[]])`, metin özniteliklerini `GetValues([string])` ile alır. Bilinen yerleşik grup SID'leri, domain SID'si, GUID, devre dışı kullanıcı ve grup JSON dönüşümü Windows .NET self-test kapsamına alındı.

Bu düzeltme somut bir veri dönüşümü kusurunu giderir. Kullanıcının gerçek AD okumasının tamamlandığı henüz kanıtlanmış değildir; parola yerel panelde yeniden girilerek tekrar denenmelidir. Bu sürüm hata devam ederse yalnız sabit aşama/neden kodlarını gösterir. Ham exception mesajı, DN, katalog veya kimlik bilgisi API/GitHub'a aktarılmaz.

Kullanıcı adı biçimi ve boş parola panelde anlaşılır biçimde kontrol edilir. İşlem durumu ve hata açıklaması bağlantı düğmesinin yanında gösterilir. İstek gönderildiğinde parola alanı temizlenir. Eski katalog başarısız okuma nedeniyle değiştirilmez.

## Doğrulamalar

- [Windows Python 3.14.8](https://github.com/Asitavandas/kaname/actions/runs/37148824107): 170 test, 168 başarılı, 2 ortam/platform nedeniyle atlanan test. Windows .NET ikili öznitelik self-test başarılı; gerçek AD ağına çağrı yapmaz.
- [Linux Python 3.12](https://github.com/Asitavandas/kaname/actions/runs/37148824105): 170 test, 169 başarılı, Windows .NET testi atlandı.
- [Chromium panel akışları](https://github.com/Asitavandas/kaname/actions/runs/37148824094): UPN açıklaması, parola temizliği, başarısız okuma aşaması, fixture katalog okuması ve mevcut panel akışları başarılı.
- [Windows güncelleme](https://github.com/Asitavandas/kaname/actions/runs/37148824075): kaynak commit `ffe9ba87650fd2ba11efa57a6f6d81498d666302`; test kapısından sonra yerel yedekle 0.3.0-dev.1 → 0.3.1-dev.1 geçişi.

Güncelleme sonucu başarılı: yapılandırma/politika/CA/token koruma kontrolleri geçti. Kullanıcının güncelleme öncesindeki revision 10 değeri korundu. Panel HTTP 200 döndü, tokenı kabul etti ve yerel veritabanıyla eşleşti. Yayın manifestinde eksik/değişmiş dosya yok. Üç önceki inert politika simülasyonu yine beklenen sonuçları verdi.

Güncelleyici önceki 0.3.0-dev.1 yayın hashlerini güvenilen kaynak manifestinden tanır; kullanıcıya ait kaynak değişiklikleri yine reddedilir. Önceki manifestin kendi hash'i de yeni yayında doğrulanır. Ayar, politika, CA ve token koruma kontrolleri devam eder. Switch/AP ayarları değiştirilmez.

Microsoft birincil API kaynağı: https://github.com/dotnet/dotnet-api-docs/blob/main/xml/System.DirectoryServices.Protocols/DirectoryAttribute.xml

## Yeniden deneme

Windows'ta `http://127.0.0.1:8765` adresini Ctrl+F5 ile yenileyin. Active Directory ekranında aynı DC FQDN, `kullanici@domain` ve parolayı girip Bağlan ve bilgileri getir düğmesine basın. Başarılıysa kullanıcı/grup/bilgisayar sayılarını, başarısızsa yeni açıklamadaki aşama/neden kodlarını bildirin. Parola veya erişim tokenı paylaşılmamalıdır.
