# Birleşik makine dağıtım taslağı — 28 Ekim 2026

Bu, A04 merkezi Windows dağıtımı maddesinin paket hazırlama alt adımıdır.
Yeni ürün kapsamı veya A03 kullanıcı doğrulaması kabulü değildir.

## Hazırlanan içerik
- Eski ağ ZIP'i baytları değiştirilmeden korunur ve açılmış XML/public CA dosyaları eklenir.
- Mevcut DeviceEnrollment.package üzerinden public sertifika kurulum varlıkları üretilir.
- İstemci ve canlı kurulum şablonu değiştirilmez. Bütün dosyalar manifest ile özetlenir.
- Tek SQLite mode=ro + query_only transaction içinde kayıtlı plan/profil/config/public CA okunur.
- Özel anahtar/vault veya şifre okunmaz; istemci/installer çalıştırılmaz.

## Operatör teslimatı
Linux /home/segmentiq/authwire-machine-bundle-export-20261028.py
SHA256 c68f70763ee3bc7de1951501611f61f4fef6df8abdef2dc976cb25043624d8f0
Kaynak bileşeni e0edcd463a4da5f5f77695052bba580bd3829f28.
Sabit kaynak scripti docs/checkpoints/2026-10-28-linux-machine-bundle-export.py.

--inspect-public Linux uid1000 ile geçti: kaynak pinleri ve özgün ağ ZIP özeti doğrulandı.
Bu kontrolde özel DB/TLS dosyası açılmadı, çıktı oluşturulmadı.
Operatör sudo export'u 28 Ekim 2026'da başarılı: 18 dosya /29.086 bayt.
ZIP SHA256 5dd35e4d28f6b6495223224f89d339c4cdd595099df5ac726b812238feca0ce5.
Asistan arşiv ve tüm manifest dosya özetlerini Linux'ta ayrıca salt okunur doğruladı.
DC01 aktarımı ve birleşik format için imzalama uygulaması henüz kabul edilmedi.
Eski ağ-only candidate signer bu taslağa doğrudan uygulanamaz.
Beklenen çıktı /home/segmentiq/authwire-pilot-combined-draft-20261028.zip, 0600 operatör sahipliği.
Önceden mevcut çıktı veya symlink reddedilir, üzerine yazılmaz.
Plan 524653f5-1359-46f5-84a5-46355bb82aff v1; beklenen mevcut makine profili/CA/config ile eşleşmezse export durur.
Yeni profil yaratılmaz; DB, servis, AD/GPO, endpoint, trust veya key ACL değişmez.

## Bilinen kaynak farkı
Canlı Install-AuthWire.ps1 SHA256 faec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609.
Main şablonu ab1a11c68381006173518df77deeb0d32fc56e0b28cc260c42b7378c624be14a.
Fark, retry trigger zamanının geleceğe/üst saniyeye yuvarlanması düzeltmesidir.
Bu export canlı betiği değiştirmeden kullanır. Main'deki bu düzeltmenin canlı kurulum varlıklarına alınması,
gerekirse yeni taslak üretilmesi ve gerçek Windows retry kabulü dağıtım öncesi ayrı takip edilmelidir.

## Açık kapılar
Taslak imzasızdır: requires_windows_signing=true, can_stage=false, can_apply=false.
Windows imzalama/son paket onayı, kontrollü SYSVOL staging,
GPO uygulama/bağlama ve test cihazında sertifika + Ethernet/Wi-Fi EAP-TLS/VLAN kabulü açık.
Enrollment installer tek başına ağ XML'lerini etkinleştirmez; ağ uygulama yolu ayrıca geliştirilmelidir.
Mevcut ağ adayı veya panel attestation tam kurulum adayı gibi yükseltilmez.
Linux dev.40, Windows efc5ee91 ve genel 54/94 (40 açık) değişmez.
Tam yedek alınmaz. Nihai kılavuz için hazır/kapanış kabulü verilmez.
