# KANAME — OVF dağıtım sözleşmesi

## Hedef

İlk appliance: Ubuntu Server 24.04 LTS hedef tabanı, x86_64, başlangıç boyutu 4 vCPU / 8 GiB RAM / 80 GB disk, bir NIC, BIOS firmware. Bunlar başlangıç boyutlarıdır; kullanıcı/oturum yüküne göre ölçümle güncellenecek. VM içinde panel/API, RADIUS, AD adaptörü, PKI, veritabanı ve servis işleticisi bulunacak. Çalışma sırasında internet veya başka bir ürün bağlantısı gerekmez.

Teslim üç dosyalıdır: OVF descriptor, stream-optimized VMDK ve SHA256 `.mf`. Dosyalar birlikte taşınır. OVA istenirse ayrıca tek arşiv olarak üretilebilir; kullanıcı talebinin ana teslimi OVF'dir. SHA256 manifest aktarım bütünlüğü kontrolüdür; yayıncı kimliği veya dijital imza doğrulaması değildir. Üretim release'i ayrıca imzalı teslim ve güvenilir imza anahtarı dağıtımı gerektirir.

## Platform matrisi

| Hedef | Yol | Bu sürümde kanıt |
|---|---|---|
| VMware vSphere/ESXi | OVF import, NIC mapping, ilk açılış | Henüz yok; ilk release hedefi |
| VMware Workstation/Fusion | Platform sürümü bazında OVF/OVA import | Henüz yok |
| VirtualBox | OVF import ve sanal donanım uyarlaması | Henüz yok |
| Proxmox/KVM | OVF/disk import ve donanım/driver uyarlaması | Henüz yok |
| Hyper-V | Native OVF import varsayılmaz; VHDX dönüşümü ve ayrı paket gerekebilir | İlk OVF teslimi için destek ilan edilmez |

“İstenen yere kurulum” bağımsız ve taşınabilir appliance hedefidir; her hypervisor için test sonucu olmadan uyumluluk sözü verilmez. Host network, DNS ve AD erişimi operatörün sağladığı altyapıdır.

## İmaj üretimi ve ilk açılış

Build VM hiçbir müşterinin domain'ine katılmaz. İmajda domain join, keytab, admin erişimi, CA özel anahtarı, RADIUS secret, müşteri veritabanı veya build parolası bulunmaz. Packer kurulum secret'ları export öncesi silinir. Makine kimliği ve etkinse SSH host key'leri temizlenir; SSH varsayılan ürün erişimi değildir.

İlk açılış konsolu ağ/DNS/saat ve ilk yönetici için yerel akış sunacak. UUID, machine-id, yönetici erişimi, PKI anahtarları ve daha sonra tanımlanan RADIUS secrets her kurulumda yeniden üretilecek. İlk kurulumda varsayılan ortak parola yoktur. İmajı açıp domain/CA ayarı yaptıktan sonra “golden image” diye yeniden export etmek güvenli kabul edilmez. Kurulum sonrası tam disk clone'unu desteklemek ayrıca kimlik yenileme ve AD/CA migrasyon tasarımı gerektirir.

## Hazır VMX export aracı

Bu araç VM kurmaz; önceden kapatılmış, temizlenmiş ve VMware OVF Tool bulunan bir ortamda yerel VMX dışa aktarımını başlatır:

```bash
python3 -m tools.export_appliance /absolute/clean/KANAME.vmx /absolute/new-output --sanitized-image-confirmed
```

Çıktı dizini önceden var olmamalıdır. `--sanitized-image-confirmed` imajı otomatik temizlemez; build pipeline/operatörün yukarıdaki temizlik işlemini yaptığını belirtir. Yerel disk yolları dışında vSphere bağlantı parolası/URL'si kabul edilmez. Dışa aktarım sonrası bütünlük denetimi yapılır. Import/boot ve iki bağımsız kurulum testi hâlâ gerekir.

Packer'ın vSphere builder export bloğu örneği `appliance/export-block.pkr.hcl.example` içindedir. **Tam bir build tarifi değildir**; ISO checksum, unattended install, plugin lock, hardening, servis kurulumu ve secret temizliği sonraki aşamada gerçek VM laboratuvarıyla tamamlanacak.

## Paket doğrulama

```bash
python3 -m tools.verify_ovf /absolute/output/KANAME.ovf
```

Denetim: yerel güvenli dosya referansları, tek sanal sistem, VMDK header/size, DiskSection ve bağlı diskler, CPU/RAM/NIC varlığı, tek NIC, SHA256 manifest kapsamı ve digest eşleşmesi. DTD/entity ve dış URL referansları reddedilir. Tam OVF XSD doğrulaması, kaynak boyutlarının hedef sözleşmesiyle bütünüyle eşitliği, disk dosya sistemi, bootloader, dijital imza ve hypervisor uyumluluğu bu aracın kapsamı değildir.

Başarılı denetimin çıktısında `boot_verified`, `hypervisor_import_verified`, `signature_verified` ve `release_ready` false kalır. Testlerde geçici sentetik disk header'ı kullanılır; bu bir çalışabilir appliance olarak dağıtılmaz.

## Release kapıları

Kaynak testleri → sabitlenmiş temiz build → içerik/secret taraması → manifest/OVF → gerçek import/boot → iki bağımsız kurulum kimliği → AD + gerçek kablolu/kablosuz EAP-TLS → harici CA ve internet olmadan çalışma → yedek/restore ve güncelleme rollback → imzalı release.

Bu ZIP **kaynak paketidir**. İçinde OVF veya VMDK release bulunmaz.
