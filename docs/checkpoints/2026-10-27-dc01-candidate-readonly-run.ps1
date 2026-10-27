# DC01, elevated Windows PowerShell 5.1. No execution-policy bypass.
$awVerifierPath = Join-Path $env:TEMP 'AuthWire-Candidate-Readonly-Service-20261027.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-candidate-readonly-service-20261027.ps1' $awVerifierPath
if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi' }
if ((Get-FileHash -LiteralPath $awVerifierPath -Algorithm SHA256).Hash -ne '63e647f0ef017709fe59c3f330f4ce9b0cd431e3dab14699d033463bd0c56518') { throw 'Dosya ozeti eslesmedi' }
& $awVerifierPath -Mode RunProbe
