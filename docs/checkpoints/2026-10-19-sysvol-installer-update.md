# DC01 pilot SYSVOL kurucusu — 19 Ekim 2026

Linux0.14.0-dev.10 güncellemesi ve veri restore kabulü tamamlandı.
Bu adım yalnız mevcut pilot SYSVOL Install-AuthWire.ps1 dosyasını değiştirir.
Windows AuthWire-Client.ps1, config/trust varlıkları, GPO INI/filtre/ayarları
korunur; task veya enrollment bu DC01 adımıyla çalıştırılmaz.

## DC01

Checkpoint: [2026-10-19-sysvol-installer-update.ps1](2026-10-19-sysvol-installer-update.ps1).
SHA256: 4eba25638ad6f8a6d697c91005266524df1b4c124d690059c4feb1b4dd384bb6.

Dosyayı DC01 Downloads klasörüne indirin. Mevcut code-signing private key'inin
bulunduğu hesapla Yönetici Windows PowerShell5.1 açın. Aşağıdaki komut önce
dosyayı doğrular, mevcut yayıncıyla imzalar ve çalıştırır. ExecutionPolicy
gevşetilmez; anahtar export edilmez.

```powershell
$ErrorActionPreference = 'Stop'
$awFile = Join-Path $env:USERPROFILE 'Downloads\2026-10-19-sysvol-installer-update.ps1'
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256).Hash -ine '4eba25638ad6f8a6d697c91005266524df1b4c124d690059c4feb1b4dd384bb6') {
    throw 'Dosya dogrulamasi basarisiz.'
}
$awCert = @(Get-ChildItem Cert:\CurrentUser\My,Cert:\LocalMachine\My |
    Where-Object {
        $_.Thumbprint -ieq '6E74B513F766E01730719684A41B2664380CA68A' -and $_.HasPrivateKey
    })[0]
if (!$awCert) { throw 'Mevcut imzalama sertifikasinin ozel anahtari bulunamadi.' }
$awSigned = Set-AuthenticodeSignature -FilePath $awFile -Certificate $awCert -HashAlgorithm SHA256
if ($awSigned.Status -ne 'Valid') { throw 'Dosya imzasi dogrulanamadi.' }
& $awFile
```

Beklenen event SYSVOL_INSTALLER_UPDATED, verified=true,
client_and_assets_preserved=true, package_permissions_preserved=true.
Backup yolu JSON'da bildirilir; private ACL altında eski imzalı installer
ve hash/izin manifest'i tutulur. Önkoşul sağlanmazsa ilerlenmez; kendi
değişimi sonrasındaki hata kontrollü geri alınır. Dışarıdan ek değişiklik
saptanırsa otomatik üstüne yazılmaz. Çıktıyı kabul kaydına ekleyin.
DC01 gerçek kabulü19 Ekim17:14 operatör çıktısıyla tamamlandı: verified/updated=true,
client/assets/ACL korunmuş, tek AllSigned giriş; tam imzalı installer SHA256
35cf0487ffe84cbbc763cd10d0427e33ebae76c5e7b87447482dc16738fa8238.
Yedek C:\ProgramData\AuthWire-Admin-Backup-20261019-171142-08ad3aebefaf4a478fefcd96a0f81875.
VV06 boot kabulü hâlâ açıktır. Clipboard yolu kullanıldı; alternatif geçici
Linux aktarım süreci kapatıldı. Dosya hash ve imza kontrolleri korunmuştur.

## Sonraki VV06 kabulü

DC01 doğrulaması başarılı olduktan sonra VV06 Yönetici PowerShell'de
gpupdate /target:computer /force, ardından gerçek Restart-Computer yapılır.
Makine açıldıktan sonra task Running/Queued ise doğal sonucunu bekleyin;
elle Start-ScheduledTask çağırmak boot kabulü yerine geçmez.

```powershell
$awBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$awInfo = Get-ScheduledTaskInfo -TaskName 'AuthWire Certificate Enrollment'
$awTask = Get-ScheduledTask -TaskName 'AuthWire Certificate Enrollment'
[pscustomobject]@{
    Computer = $env:COMPUTERNAME
    LastBootUpTime = $awBoot
    LastRunTime = $awInfo.LastRunTime
    RanAfterBoot = ($awInfo.LastRunTime -ge $awBoot)
    TaskState = $awTask.State
    LastTaskResult = $awInfo.LastTaskResult
    ClientSignature = (Get-AuthenticodeSignature 'C:\ProgramData\AuthWire\AuthWire-Client.ps1').Status
    RetryFileExists = (Test-Path 'C:\ProgramData\AuthWire\retry.json')
} | Format-List
netsh lan show interfaces
Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 |
    Select-Object IPAddress, PrefixLength, AddressState
```

Gerçek kabul: RanAfterBoot=true, Ready/LastTaskResult0, signatureValid,
retry yok; mevcut seri5899e122009871b0d5536890bee81e4f0499e605 /
thumb4CFD8321AE08D6074B99AF5C194151AD5F99F454 ve yeni private key korunmuş,
Ethernet Authentication succeeded ve beklenen VLAN110 DHCP erişimi.
Running/267009 görevin henüz tamamlanmadığıdır; başarılı diye kapatılmaz.
Offline/expired/kapasite ve daha geniş GPO yayılımı ayrı açık kapılardır.

## İzole test kanıtı

PR39, aday03eea0623f1923e49b7a547f7906e18692d4b80d,
Windows2025 / Windows PowerShell5.1 işi118088248063:
gerçek Authenticode, tam eski/yeni template pinleri, aynı publisher,
imzalı varlık koruması, ACL/byte koruması, idempotence, değiştirilmiş varlık ve
yanlış publisher reddi, inject edilmiş post-replace hata sonrası gerçek
eski dosya/izin geri alma geçti. Tam üretim installer'ı fixture'da yürütülmedi;
yalnız protected updater dosya yolu denendi. VV06 gerçek reboot yerine geçmez.
