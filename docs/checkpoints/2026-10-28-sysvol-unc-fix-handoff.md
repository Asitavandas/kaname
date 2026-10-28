# SYSVOL UNC okuma düzeltmesi — Windows Prepare

Müşteri birleşik kapsam sonucu READ_FAILED. Yerel aday okuyucusunun UNC yasağı ile SYSVOL ağ yolu
arasındaki kod uyumsuzluğu düzeltildi ve gerçek Windows SMB paylaşımında test edildi.
Bu teslimat müşteri pozitif kapsam sonucu değildir; Linux dev.43 değişmez.

DC01 yönetici64-bit Windows PowerShell'de:

```powershell
$awFile = Join-Path $env:TEMP 'AuthWire-Sysvol-UNC-Fix-20261028.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-sysvol-unc-fix-20261028.ps1' "$awFile"
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne '7f84588eeda9301d541a25d3e89bc2aeacc7e0e2ffa1fc36a5e57e563bc56498') {
    throw 'Kurulum dosyasi degismis'
}
& ([scriptblock]::Create([IO.File]::ReadAllText($awFile))) -Mode Prepare
```

Beklenen Event=WINDOWS_CONNECTOR_UPGRADE_DELIVERY, ToolVersion1.4.1, Mode=Prepare,
Stage=prepared, Error=null, SourceSignaturesValid/SignerSnapshotPreserved=true,
PreviousReleaseId=e6d734b1-59c8-48e5-8a6e-c40b43be3114,
NewReleaseId=cf74295c-ec97-4edf-a15a-877b155d1740, ServiceTransitioned=false.
Çıktı kabul edilmeden Apply yapılmaz. Ardından aynı hash doğrulanmış launcher ile Apply,
taze health/capability kabulü ve tek yeni birleşik AD/GPO kontrol görevi izlenecek.
GPO veya cihazlara dağıtım yetkisi açılmaz; eski hata kaydı silinmez, doğrulama sınırları gevşetilmez.
