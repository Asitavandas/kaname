# Dev.42 sonrası Windows birleşik worker — Prepare devam noktası

Linux COMBINED_JOBS_FINISHED/verified=true sonucu kabul edildi. Kanıt:
`/var/lib/authwire-updates/combined-jobs-dev42-20261028T114518Z-941ed9a1`.

DC01'de yönetici olarak açılmış64-bit Windows PowerShell'de aşağıdaki komut çalıştırılır.
İşlem yalnız yeni Connector paketini hazırlar; çalışan servis/PID, GPO ve endpoint ayarlarını değiştirmez.
Mevcut gMSA, kanal anahtarı, eşleştirme ve signer korunur. Source kodu mevcut signer ile imzalanır;
önceden hazırlanmış birleşik deployment adayı yeniden oluşturulmaz/imzalanmaz.

```powershell
$awFile = Join-Path $env:TEMP 'AuthWire-Combined-Worker-Upgrade-r2-20261028.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-combined-worker-upgrade-r2-20261028.ps1' "$awFile"
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256).Hash.ToLowerInvariant() -cne '65bf7b7a1963c9c103764c6e1b6677cecb2b5a06d2cffc1bcb56372c9fc86cc3') { throw 'Kurulum dosyasi degismis' }
& ([scriptblock]::Create([IO.File]::ReadAllText($awFile))) -Mode Prepare
```

Beklenen: Event=WINDOWS_CONNECTOR_UPGRADE_DELIVERY, Mode=Prepare,
Stage=prepared, Error=null, SignerSnapshotPreserved=true,
NewReleaseId=689649c0-61df-40aa-bbfb-b84fa1cc2ac0.
Upgrade.PreviousReleaseId=efc5ee91-e39e-4cc4-9cc1-60b648e18cf9,
PackagePrepared=true, ServiceTransitioned=false, CanApplyGpo=false.

Çıktı incelenmeden Apply çalıştırılmaz. Hata çıkarsa aynı işi tekrar yürütmeden tam çıktı değerlendirilir.
Sonraki sıra: Apply → taze authenticated health/CombinedChannelVerified →
birleşik satırda Doğrulamayı önizle → görevi gönder → Yenile → gerçek content sonucu.
GPO kapsamı/staging/endpoint kabulü hâlâ açıktır.

Eski d825... hash'li wrapper b546 başlangıç sürümüne bağlıydı ve Windows'ta çalıştırılmadan düzeltildi.
r2 yalnız başlangıç sürümü girdisini efc5... yapar; embedded21-source arşiv SHA256
dffba96918da2e4295bf018f126de4297335ee4100cd5912370e97fb3b8b7509 değişmedi.
Yeni launcher SHA256:65bf7b7a1963c9c103764c6e1b6677cecb2b5a06d2cffc1bcb56372c9fc86cc3.

## Prepare kabul edildi — Apply devam komutu

28 Ekim 2026 operatör sonucu Stage=prepared, Error=null, SourceSignaturesValid=true,
SignerSnapshotPreserved=true; ServiceTransitioned=false. Çalışan release efc5ee91 olarak kalır.
Tam sonuç: 2026-10-28-customer-combined-worker-prepared.json.

DC01 yönetici PowerShell'de:

```powershell
$awFile = Join-Path $env:TEMP 'AuthWire-Combined-Worker-Upgrade-r2-20261028.ps1'
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne '65bf7b7a1963c9c103764c6e1b6677cecb2b5a06d2cffc1bcb56372c9fc86cc3') {
    throw 'Kurulum dosyasi degismis'
}
& ([scriptblock]::Create([IO.File]::ReadAllText($awFile))) -Mode Apply
```

Bu aşama Connector servisini kontrollü yeniden başlatır. Beklenen Stage=applied, Error=null,
Upgrade.ServiceTransitioned=true, SourceSignaturesValid/SignerSnapshotPreserved=true ve CanApplyGpo=false.
Çıktı kabul edilmeden birleşik job veya GPO/endpoint dağıtımı başlatılmaz.
