# DC01, elevated Windows PowerShell 5.1; native metadata read only.
$awNativePath = Join-Path $env:TEMP 'AuthWire-Signer-Native-Metadata-r2-20261027.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-signer-native-metadata-r2-20261027.ps1' $awNativePath
if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi' }
if ((Get-FileHash -LiteralPath $awNativePath -Algorithm SHA256).Hash -ne '2332082ac59f9adec7ac47d2bd9e80e3ca6733f34ba75e256ac1abb33769d908') { throw 'Dosya ozeti eslesmedi' }
& $awNativePath -Thumbprint 'FFC134BC305757457163F99C7479B4168E397129'
