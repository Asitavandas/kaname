# AuthWire tahmini süreç ve canlı test raporu

29 Ekim 2026 · Europe/Istanbul · planlama tahmini, teslim tarihi taahhüdü değildir.

## Yönetici özeti

Mevcut düzenli çalışma temposu korunursa panelden ilk otomatik merkezi pilot dağıtımı ve dar uç kabulü için **2–3 hafta**;
temel ürünün açık kabul kapıları ve tek hesap hedefi için **5–8 hafta**;
nihai temel sürüm kılavuzu dahil teslimat için **6–9 hafta** planlıyorum.
Kayıtlı yedi geliştirme paketi de kapsandığında toplam işlevsel kapsam için **12–18 hafta** daha gerçekçi bir aralıktır.

29 Ekim başlangıçlı koşullu takvim:
- İlk otomatik merkezi pilot: **12–19 Kasım 2026**.
- Temel ürünün işlevsel kabulü + tek hesap: **3–24 Aralık 2026**.
- Bu temel sürümün kılavuzu dahil teslimi: **10–31 Aralık 2026**.
- Bütün kayıtlı geliştirmeler ve nihai kılavuz: **21 Ocak–4 Mart 2027**.

Kullanıcının nihai hedefi tüm geliştirmeleri içerirse, temel sürüm kılavuzu tarihi yalnız ara sürüm seçeneğidir.
Tek nihai kılavuz, gerçek hedef kapsam tamamlanıp operatör kabulü alındıktan sonra hazırlanır.
Bu rapor kılavuz oluşturma/teslim etme veya ürün tamamlandı kaydı değildir.

## Dayanak ve belirsizlik

Kaynak sabiti **e5aea433146e9452867159544ef38b49d1e2cf9a**. Güncel CURRENT_STATUS üst kaydı, PR118 sonucu,
27 Ekim ayrıntılı durum raporu, ROADMAP, CONNECTOR_SINGLE_ACCOUNT_CHANNEL ve USER_GUIDE_PLAN incelendi.
ROADMAP'ın eski sürüm notları yerine kurulu sürüm için güncel üst kabul kaydı esas alındı.

Son resmi makro sayım **54/94 tamam,40 açık**:
temel ürün **44/59**, geliştirmeler **10/35**. A03/A04 örtüşen ek kapsamdır, tekrar sayılmadı.
Bu oran zamanın %57'sinin tüketildiğini göstermez; kalan işler farklı büyüklükte ve bağımlılıktadır.
1075 genel testin veya 81 çekirdek kontrolünün geçmesi, kalan 40 işin kapandığı anlamına gelmez.

Bu hesap geçmiş işlerin ölçülmüş saatlerinden çıkarılmış istatistiksel bir tahmin değildir.
Kayıtlı son 25–29 Ekim ilerlemesindeki teslim/test/düzeltme çevrimleri ve kalan teknik kapsamdan yapılan
mühendislik değerlendirmesidir. İlk uçtan uca pilot ve tek hesap geçişinden sonra yeniden tahmin edilmelidir.

Varsayımlar:
- Haftada beş gün düzenli ortak çalışma; gerekli yönetici komutlarının ve sonuçlarının aynı gün ilerlemesi.
- Bu süreler aktif çalışma oturumlarına bağlıdır; sohbet kapalıyken kesintisiz arka plan geliştirme varsayımı yoktur.
- Mevcut domain, CA, Linux, Connector ve kabul edilmiş imzalama/güven yolu yeniden kurulmaz.
- Test PC, switch/AP yönetimi ve gerekli kullanıcı erişimleri planlanan saha oturumunda hazırdır.
- Ciddi yeni güvenlik/kimlik/geri alma mimarisi hatası çıkmaz. Aralıklar olağan test-düzeltme tekrarları içerir;
  büyük bir bulgu ilgili aşamaya ayrıca yaklaşık 2–5 iş günü veya mimari yeniden planlama ekleyebilir.
- Yeni arayüz tasarımı veya yeni ürün özelliği kapsamı bu tahmine eklenmemiştir.
- Sunucu dışı yedek alanı, ayrı restore VM'si ve üretici API yetkisi beklemelerinin son tarihi bilinmiyor;
  bu ön koşullar hazır değilse ilgili kapanış tarihi verilemez.

## Bugünkü durum

Linux için kabul edilen sürüm **0.14.0-dev.44**, Windows Connector **df28f70c**.
Gerçek müşteri ortamında birleşik paket önizlemesi **20 dosya /102464 bayt** ile panelde görüldü.
Dosya yazma/geri alma çekirdeği PR118'de geçici gerçek SMB alanında test edilip ana dala alındı.
Canlı yazma işi, yetkili görev/onay akışı, kesinti sonrası kısmi işlem kurtarması ve GPO aktivasyonu henüz teslim edilmedi.

Bilgisayar sertifikalı Ethernet/Wi-Fi ve VLAN daha önce gerçek cihazda kabul edildi.
Yeni otomatik dağıtım yolu için bunlara regresyon kabulü yapılacak; sıfırdan geliştirme varsayılmadı.
Kullanıcı sertifikalı erişim ve tek gMSA altında AD/Kerberos geçişi ayrıca açık.

## İş paketleri ve süreler

İşgünü bir planlama birimidir; tek bir komutun çalışma süresi değildir.
Geliştirme, teknik doğrulama, düzeltme ve kontrollü teslim çevrimini kapsar.
Saha sütunu operatörün aktif oturum zamanını gösterir; günlük çalışma süresine ikinci kez eklenmez.

| İş | Şu anki durum / kalan kapsam | Tahmini çalışma | Aktif saha oturumu | Ön koşul / kapanış |
|---|---|---:|---:|---|
| 1. Onaylı staging/geri alma görevi | Çekirdek hazır. Yetkili panel/API işi, bounded worker, canlı AD/GPO kontrolü, idempotency ve kısmi işlem kurtarması açık | 4–7 iş günü | 1–2 saat | Aynı gMSA ile gerçek yazma, tekrar/kesinti ve güvenli geri alma kanıtı |
| 2. GPO etkinleştirme | Startup/uzantı/sürüm/link/çoğaltma ve kapsam koruması açık | 2–4 iş günü | 2–3 saat | İş1; ilk seçilmiş pilot PC'de doğal kurulum ve beklenen sertifika/ağ sonucu |
| 3. Kullanıcı EAP-TLS | Sunucu/istemci/panel hazır. Gerçek kullanıcı deposu, Ethernet/Wi-Fi, kullanıcı VLAN ve kimlik geçişi kabulü açık | 2–4 iş günü | 2–4 saat | Kontrollü kullanıcı dağıtımı, en az iki farklı kullanıcıyla ret/izin ve yaşam döngüsü |
| 4. Tek hesap standardı | gMSA Connector çalışıyor. AD katalog/canlı okuma ve Windows Kerberos acceptor taşınacak; eski bağımlılıklar kaldırılacak | 6–10 iş günü | 2–3 saat | Kimlik bütünlüğü, MIC/path/body/CSR bağı, replay/ret/kesinti testleri; eski hesapları ancak bağımlılık kanıtından sonra kaldırma |
| 5. Sertifika/AD olumsuz ve kurtarma | Expiry, yanlış issuer, rollover, silinmiş/kapalı hesap, AD kesintisi ve kalan retry çeşitleri | 3–5 iş günü | 3–4 saat | Ayrı test profili/uç; mevcut erişimi koruyan ret ve güvenli toparlanma |
| 6. Accounting ve işletim kayıtları | Start/Stop/Interim, oturum ilişkisi, saklama/temizlik ve hata görünürlüğü | 3–5 iş günü | 1–2 saat | NAS desteği ve gerçek oturum verisi; kaynak-zaman ilişkisi ayrıca doğrulanır |
| 7. Yedek/restore ve temiz appliance | Yerel yedek var; sunucu dışı kopya, gerçek boot restore, temiz import/bağımsız kimlik ve güncelleme geri dönüşü açık | 3–5 iş günü | 2–4 saat | Dış hedef ve ayrı VM; altyapı bekleme süresi hariç |
| 8. Temel regresyon/kapasite | Kademeli yayılım, kalan panel/servis/güç senaryoları, kontrollü yük ve gözlem | 2–4 aktif iş günü + 7–14 takvim günü gözlem | 2–3 saat | Önce dar pilot; gerçek 200 uç yoksa sentetik yük gerçek 200 uç kabulünü kapatmaz |
| 9. G02/G03 ilk cihaz ailesi | Mod temelleri var. Gerçek cihaz okuma/uygulama/geri alma ve ilk üretici bulut bağlantısı açık | 6–12 iş günü | 3–5 saat | Kullanılabilir desteklenen resmi API ve erişim. İlk üretici/sınırlı model içindir; ek üreticiler yeniden tahmin edilir |
| 10. G04 VLAN/port keşfi | Otomatik kaynak, tazelik, doğru port/SSID/cihaz eşleme | 3–5 iş günü | 1–2 saat | İş9 veya güvenilir cihaz okuma yolu |
| 11. G05 tüm kimlik seçicileri | OU/Everyone ve tüm seçicilerin gerçek yetkilendirme/ret kapsamı | 2–4 iş günü | 1–2 saat | Gerçek AD ve kullanıcı/bilgisayar kimliği; kullanıcıdan bilgisayar hedefi tahmin edilmez |
| 12. G06 canlı topoloji | Port/oturum modeli, Accounting eşleşmesi, port/SSID değişimi ve UI doğruluğu | 4–7 iş günü | 2–3 saat | İş6+9+10; güvenilir canlı veri |
| 13. G07 açıklanabilir öneriler | Veri kalitesi, korelasyon, açıklama ve yanlış alarm ölçümü | 4–7 iş günü + veri gözlemi | 1–2 saat | İş6+10+12 ve temsil edici trafik; veri birikimi takvimi uzatabilir |
| 14. Nihai Türkçe Word/PDF kılavuzu | Tüm nihai ekran/başlık/alan/buton/durum, gerçek görüntüler, adımlar, başarı ve hata çözümleri | 3–5 iş günü | 1–2 saat son inceleme | Hedef işlevsel sürüm ve operatör kabulünden sonra |

Tablodaki üst süreleri toplamak tek bir teslim tarihi vermez: bazı gözlemler, rapor kontrolleri ve bağımsız
işler çakışabilir; kritik bağımlılıklar ardışık ilerler. A03/A04 ile B/G kapsamındaki örtüşmeler tekrar sayılmadı.
Tek hesap taşınması ve cihaz API'si belirsizliği en yüksek paketlerdir. Temel tarih aralığının güveni orta,
yedi geliştirmenin tamamı için güven daha düşüktür.

## Canlı testler ne kadar sürer?

- İlk otomatik pilot turu: hazırlıklar hazır olduğunda **2–4 saat aktif oturum**; genellikle 1–2 güne bölünür.
- Temel ürünün kalan saha kabulleri: yaklaşık **15–25 saat aktif operatör katılımı**;
  sonuç ve düzeltmelere göre **5–8 ayrı test gününe** dağılabilir; bu günlerde toplam yaklaşık 2–4 saat ayrılması varsayılır.
- Yedi geliştirme ve cihaz/topoloji/öneri kabulleri de dahil: toplam yaklaşık **25–40 saat aktif saha çalışması**.
- Buna ek olarak **7–14 takvim günü gözlem** planlanır; bu süre boyunca bilgisayar başında beklemek gerekmez.
  Yenileme, ağ geri dönüşü, otomatik görevler, audit ve veri kalitesi izlenir; geliştirme ile örtüşebilir.
- Gözlemde hata çıkarsa ilgili test grubu düzeltmeden sonra tekrarlanır. Altyapı/cihaz erişimi beklemeleri
  aktif test saatlerine dahil değildir.

Her gün test PC başında bulunman gerekmiyor. Hazır kabul paketlerini test günlerinde bir veya iki adet 60–120 dakikalık oturumda
birleştirmek, ekran/komut/kanıt turlarını planlı yapmak ve sonuçları aynı oturumda kaydetmek uygun olur.
İlk dar kabulde tek PC yeterli olabilir; kullanıcı ayrımı için birden fazla AD kullanıcı kimliği,
bazı expiry/olumsuz senaryolar için ayrı test profili veya ikinci uç, restore için ayrı VM gerekir.
200 uç ölçek kabulü fiziksel/gerçek kapsam olmadan tamamlandı yazılmaz.

## Kritik sıra ve tahmini kapanışlar

1. İlk hafta: onaylı staging/rollback görev akışı, canlı scope adapter'ı, kesinti kurtarma ve teknik testler.
2. İkinci/üçüncü hafta: müşteri teslimatı, GPO aktivasyonu, ilk otomatik pilot ve uç regresyonu.
3. Üçüncü–altıncı hafta: kullanıcı EAP-TLS, tek hesap AD/Kerberos taşınması, yaşam döngüsü ve işletim açıkları.
4. Beşinci–sekizinci hafta: temel sürümün restore/kapasite/regresyon ve uzun gözlem kabullerini kapatma.
5. Hedef yalnız temel sürümse: kabul sonrası 3–5 iş günü kılavuz ve son teslim.
6. Hedef bütün geliştirmelerse: cihaz entegrasyonları → keşif → topoloji → öneri; toplam 12–18 hafta,
   nihai kılavuz gerçek kapsam kabulünden sonra.

Tamamlanma yalnız kaynağın yazılmasıyla verilmez: teknik test, müşteri kurulumu, gerçek uç kabulü,
hata/geri dönüş ve kayıt zinciri gereken başlıkta birlikte kapanmalıdır.

## Tahmini en çok değiştirecek konular

- Tek gMSA'ya AD ve Kerberos taşınmasında beklenmeyen kimlik/uyumluluk bulgusu.
- GPO/DFSR/yerel politika farkları veya gerçek uçlarda ayrı Windows/NIC davranışı.
- Gerçek kullanıcı EAP-TLS geçişi ve yaşam döngüsünde yeni hata.
- Dış yedek hedefi, ayrı restore VM'si ve gerçek ölçek uçlarının bulunmaması.
- Cihaz entegrasyonları için desteklenen API veya gerekli yetkinin sağlanamaması.
- Tekrarlanan bağlantı kayıpları, kurulum çıktılarının günler sonra gelmesi veya kapsam değişikliği.

Bu durumlarda güvenlik/doğrulama kapıları gevşetilmez; ilgili paketin takvimi güncellenir.
Tekrarlı genel testler rastgele çoğaltılmaz; anlamlı değişiklik/hata/çözülmemiş risk olduğunda çalıştırılır.

## Sonraki adım

Mevcut geliştirme sırası değişmedi: yetkili, idempotent staging/geri alma görev protokolü;
güncel AD/PDC/GPO ve imza kontrollerini kullanan bounded Connector adapter'ı ve kısmi işlem kurtarması.
Bu rapor hazırlanırken panel, AD/GPO, cihaz, servis, yedek veya hesap ayarı değiştirilmedi.
READY_FOR_FINAL_GUIDE=false ve GUIDE_DELIVERED=false korunur.
