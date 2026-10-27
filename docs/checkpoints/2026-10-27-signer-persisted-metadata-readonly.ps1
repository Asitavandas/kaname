# DC01, fresh elevated Windows PowerShell 5.1; read-only metadata only.
$awMetadataPath = Join-Path $env:TEMP 'AuthWire-Signer-Persisted-Metadata-20261027.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-signer-persisted-metadata-20261027.ps1' $awMetadataPath
if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi' }
if ((Get-FileHash -LiteralPath $awMetadataPath -Algorithm SHA256).Hash -ne 'a337c3e2cd0db356c30995527992a99288ff92e11069d45329c3a57dad6c4c2d') { throw 'Dosya ozeti eslesmedi' }
& $awMetadataPath -Thumbprint 'FFC134BC305757457163F99C7479B4168E397129'
