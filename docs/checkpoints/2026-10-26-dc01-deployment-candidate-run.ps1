& {
    $ErrorActionPreference = 'Stop'
    $awDir = Join-Path $env:TEMP ('AuthWire-Candidate-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $awDir
    $awTool = Join-Path $awDir 'AuthWire-Deployment-Candidate.ps1'
    $awZip = Join-Path $awDir 'AuthWire-Network-Profiles.zip'

    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-deployment-candidate-20261026.ps1' $awTool
    if ($LASTEXITCODE -ne 0) { throw 'Komut dosyasi aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ine '9a6fd20aa72fb5a157d17344f6c531dfef608b17399f540e9708412e26745264') {
        throw 'Komut dosyasinin ozeti eslesmedi; calistirilmadi.'
    }

    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-pilot-network-profiles-20261026.zip' $awZip
    if ($LASTEXITCODE -ne 0) { throw 'Ag profili paketi aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awZip -Algorithm SHA256).Hash -ine '528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38') {
        throw 'Ag profili paketinin ozeti eslesmedi; calistirilmadi.'
    }

    & $awTool -Mode Prepare -NetworkProfileZip $awZip
}
