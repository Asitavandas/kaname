# Operator command on DC01 in elevated Windows PowerShell 5.1 after accepted Prepare.
$awUpgradePath = Join-Path $env:TEMP 'AuthWire-Candidate-Worker-Upgrade-20261027.ps1'
if ((Get-FileHash -LiteralPath $awUpgradePath -Algorithm SHA256).Hash -ne '3abcfea6d4ba2a6bdc8bf59731d300cebbce6f1aa166947cc948f74452671bff') { throw 'Dosya ozeti eslesmedi' }
& $awUpgradePath -Mode Apply
