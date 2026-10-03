# KANAME 0.2.0-dev.1 — doğrulama raporu

Başlangıç kontrolü: 2026-10-02. Ortam: Linux, Python 3.12.14, cryptography 46.0.0, OpenSSL 3.0.13. Kaynak koddan çalıştırma; müşteri verisi veya gerçek domain bağlantısı kullanılmadı. Önceki 34 dosya ve 70 test korunarak devam edildi.

## Tamamlanan kontroller

| Kontrol | Sonuç | Kapsam |
|---|---|---|
| `unittest discover -s tests -t .` | **127/127 geçti, skip yok** | 31 politika/girdi, 11 SQLite, 20 HTTP, 51 PKI/CLI, 14 OVF testi |
| Gerçek yerel TLS handshake | Geçti | CA/issuer/leaf zinciri, private key eşleşmesi ve DNS adı doğrulaması |
| OpenSSL zincir/DNS/iptal | Geçti | Doğru leaf kabul; yanlış DNS ve güncel CRL ile iptal edilmiş leaf ret |
| Python compileall | Geçti | Ürün, araçlar ve testlerin derlenebilirliği |
| JavaScript `node --check` | Geçti | Panel ve tarayıcı test betiğinin sözdizimi |
| ZIP arşiv CRC/içerik kontrolü | Geçti | Kaynak/belge/test envanteri, state ve secret dosyalarının hariç tutulması; ZIP içindeki SOURCE_MANIFEST.json ile SHA256 |

Son test çalıştırmasının özeti:

```text
Ran 127 tests in 7.425s
OK
```

HTTP testleri gerçek geçici loopback sunucusuna istek gönderir. Politikada varsayılan ret, başarısız kimlik, AD kesintisi, kapalı hesap, domain cihazı/EAP kısıtı, sıra, eşleşmeyen koşuldan devam ve VLAN doğrulanmıştır. Veritabanında stale revision ve audit insert hatasının transaction rollback'i doğrulanmıştır. Host/Origin/token, JSON sınırı, statik path traversal ve simülasyonun runtime uygulamadığı kontrol edilmiştir.

Yeni PKI testleri: farklı kurulumda farklı kimlik/anahtar, şifreli PKCS#8, root/issuer chain/constraints, yanlış parola/bozuk/mismatched anahtar, zayıf CSR key, signature tampering, fazla SAN/wildcard/UPN/CA/client EKU reddi, issuer geçerlilik sınırı, init/issuance/revocation audit rollback, idempotent iptal, CRL refresh/clock rollback, public status/export'ta secret görünmemesi, CLI confirmation ve eski dosyayı koruma. Önceki yapılandırma/politika satırlarının ilave PKI tabloları ve CA işlemleri boyunca korunması doğrulandı.

Tam test çıktısı `docs/test-run.txt` dosyasındadır. Bu testler CI tarifi ile de çalıştırılabilir; GitHub üzerinde bir CI run başlatılmadı.

OVF testlerinde geçici sentetik VMDK header'ı oluşturulur; manifest bozulması, eksik referans, dosya/path/URL/symlink, DTD ve eksik sanal donanım reddi doğrulanır. Bu fixture herhangi bir işletim sistemi veya bootloader içermez ve release imajı değildir.

## Henüz doğrulanmayanlar

| Kontrol | Durum / nedeni |
|---|---|
| Tarayıcı/ekran ve wizard uçtan uca | `tools/ui_smoke.cjs` hazır; çalıştırma Chromium binary olmadığı için başlayamadı. Browser indirmesi geçerli arşiv dönmedi. PASS sayılmaz. |
| Gerçek AD okuma/domain join | AD ortamı yok; adaptör uygulanmadı. |
| İstemci enrollment/AD eşlemesi | Henüz uygulanmadı. Yerel CA/server CSR/iptal/CRL modülü doğrulandı; istemci sertifikası yolu kapalı. |
| PKI üretim key vault/root lifecycle | HSM/offline root, issuer renewal, root rollover, CRL dağıtımı ve otomatik yenileme henüz yok. |
| FreeRADIUS/EAP/802.1X | Runtime yok; protokol adaptörü uygulanmadı. |
| Switch/AP üzerinden kablolu/kablosuz | Manuel hazırlanmış fiziksel/VM ağ laboratuvarı yok. Yönetim entegrasyonu ayrıca kapsam dışında. |
| VMware OVF Tool export | Araç ve hazırlanmış temiz VM yok. |
| OVF import, açılış, clone uniqueness | Hypervisor ve gerçek disk imajı yok. |
| Windows çalıştırma | Windows'ta test edilmedi. |
| Üretim güvenliği, yük, HA, backup/update | Sonraki aşama kabul kapıları. |

127 test belirtilen kaynak davranışlarına kanıttır; yerel TLS testi EAP-TLS değildir. NPS özellik eşitliği, gerçek AD/802.1X, üretim hazır oluş veya appliance uyumluluğuna kanıt değildir.
