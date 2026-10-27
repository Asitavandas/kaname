# Operator command on DC01 in elevated Windows PowerShell 5.1.
$awUpgradePath = Join-Path $env:TEMP 'AuthWire-Candidate-Worker-Upgrade-20261027.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-candidate-worker-upgrade-20261027.ps1' $awUpgradePath
if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi' }
if ((Get-FileHash -LiteralPath $awUpgradePath -Algorithm SHA256).Hash -ne '3abcfea6d4ba2a6bdc8bf59731d300cebbce6f1aa166947cc948f74452671bff') { throw 'Dosya ozeti eslesmedi' }
& $awUpgradePath -Mode Prepare
