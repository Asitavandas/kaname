# SYSVOL paket hazırlığı: tam envanter ön koşulu

Dev.40 scope kontrolü kök ACL ve dört kök girdisini doğrular. Alt dizinlerde
önceden bırakılmış dosyaları doğrulamaz. SYSVOL'a yazmadan önce bu boşluk kapanır.

`SysvolInventory.ps1` yalnız okur: alt dizinleri, dosya boyutlarını, SHA256 ve
SDDL değerlerini normalleştirilmiş bir özete bağlar. Reparse point takip etmez;
1024 girdi (kök dahil),16 alt seviye, dosya başına16MiB/toplam32MiB sınırı vardır.
Okuma hatası kısmi başarı sayılmaz. İki tam okuma özeti eşleşmeden mevcut durum
sabit kabul edilmez. Bu bir transaction veya SMB snapshot değildir; eşzamanlı
saldırgan/yönetici değişikliğine karşı atomik yazma garantisi sağlamaz. I/O'nun
kesin süre sınırı, kalıcı worker entegrasyonunda mevcut bounded child ile korunmalıdır.

Boş yönetilen dağıtım sınıflandırması kökte Machine/User dizinlerini ve GPO.cmt /
GPT.INI dosyalarını gerektirir; alt dizinler boş olabilir, alt dosya varsa yazma
öncesi inceleme gerektirir. Bu sınıflandırma GPO kimliği/marker/izin/link/sürüm
kontrolünün yerine geçmez. Başka ürünün dosyası silinmez veya sahiplenilmez.

Mevcut imzalı aday yalnız ağ XML paketidir. Tam enrollment/installer paketi ayrıca
hazırlanmalı; ağ XML'ini SYSVOL'a koymak sertifika dağıtıldığı anlamına gelmez.
Sonraki yazıcı ayrı typed preview/onay kapsamı, sabit owned GPO yolu, geçici ayrı
klasör, tam manifest/hash/ACL kontrolü, başarısızlıkta yalnız kendi yeni dosyalarını
kaldırma ve tekrar çalıştırma/journal kontrolü gerektirir. GPO linkleri, startup
ayarları veya sürüm sayaçları bu envanter bileşeni tarafından değiştirilmez.

Native Windows testi yalnız kendi geçici NTFS ağacında çalışır; müşteri AD/SYSVOL
kabulü değildir. Üretim worker'a yükleme ve müşteri tam envanter okuması henüz yoktur.

Envanter dosyaların ana veri akışı ve standart owner/group/DACL verileriyle sınırlıdır;
alternatif NTFS veri akışları, SACL/audit veya hardlink topolojisi taranmaz. Bu
sonuç tek başına staging/uygulama yetkisi oluşturmaz.
