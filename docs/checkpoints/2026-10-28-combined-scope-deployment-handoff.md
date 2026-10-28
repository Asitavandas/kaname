# Birleşik kapsam — dev.43 Linux kurulumu

Son canlı kabul dev.42 + Windows689649c0 + birleşik content pozitif/browser sonucudur.
Yeni kontrol kaynak/test/teslimatı hazırdır; müşteri pozitif kapsam sonucu değildir.

Linux'ta:

```bash
sudo /opt/kaname-lab/venv/bin/python -I -B -c 'import hashlib,pathlib; p=pathlib.Path("/home/segmentiq/authwire-combined-scope-jobs-20261028.py"); b=p.read_bytes(); assert hashlib.sha256(b).hexdigest()=="19a33302b0b80dbf186a75e4e09aae91195ae82ce905e59dd2341d8c277d36d2", "Kurulum dosyasi degismis"; exec(compile(b,str(p),"exec"))'
```

Beklenen COMBINED_SCOPE_JOBS_FINISHED /verified=true /version0.14.0-dev.43;
radius_restarted=false, protected_files/broker_process/radius_process/timers/business_state=true,
backup_workers_changed=true, combined_scope_worker_delivery_pending=true, gpo_apply_enabled=false.
Bu aşama panel restart ve beşinci queue backup worker uyumluluğu güncellemesidir; tam yedek başlatmaz.
Hata olursa aynı işlemi tekrar çalıştırmadan tam çıktı değerlendirilir.

Başarılı Linux sonucundan sonra Windows24-source launcher ile Prepare, ardından Apply yapılacak.
Windows path /home/segmentiq/authwire-dc01-combined-scope-worker-upgrade-20261028.ps1;
SHA256 44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2; yeni releasee6d734b1-59c8-48e5-8a6e-c40b43be3114.
Beklenen current689649c0'dır. Yeni release taze birleşik scope capability istemeden kabul edilmez.
Sonrasında birleşik paket satırında AD/GPO kontrolünü önizle → gönder → Yenile ile gerçek scope sonucu alınır.
GPO/endpoint dağıtımı bu read-only kanalda açılmaz.

## Dev.43 kabul edildi — Windows Prepare

Linux COMBINED_SCOPE_JOBS_FINISHED/verified=true kaydedildi. Windows current release689649c0.
DC01 yönetici64-bit Windows PowerShell'de:

```powershell
$awFile = Join-Path $env:TEMP 'AuthWire-Combined-Scope-Worker-Upgrade-20261028.ps1'
scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-dc01-combined-scope-worker-upgrade-20261028.ps1' "$awFile"
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne '44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2') {
    throw 'Kurulum dosyasi degismis'
}
& ([scriptblock]::Create([IO.File]::ReadAllText($awFile))) -Mode Prepare
```

Beklenen Event=WINDOWS_CONNECTOR_UPGRADE_DELIVERY, ToolVersion1.4.0, Mode=Prepare,
Stage=prepared, Error=null, SourceSignaturesValid/SignerSnapshotPreserved=true,
Upgrade.PreviousReleaseId=689649c0-61df-40aa-bbfb-b84fa1cc2ac0,
NewReleaseId=e6d734b1-59c8-48e5-8a6e-c40b43be3114, ServiceTransitioned=false.
Çıktı kabul edilmeden Apply çalıştırılmaz. Henüz GPO/endpoint uygulaması yapılmaz.

## Windows Prepare kabul edildi — Apply devam komutu

28 Ekim2026 operatör sonucu Stage=prepared, Error=null, SourceSignaturesValid=true,
SignerSnapshotPreserved=true, ServiceTransitioned=false. Current689649c0 korunuyor.
Tam çıktı: 2026-10-28-customer-combined-scope-worker-prepared.json.

DC01 yönetici64-bit Windows PowerShell'de:

```powershell
$awFile = Join-Path $env:TEMP 'AuthWire-Combined-Scope-Worker-Upgrade-20261028.ps1'
if ((Get-FileHash -LiteralPath $awFile -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne '44d7be4e9c3ff2b473e6beed69e498d5976fc49f4341ff48310c6826b5bb54f2') {
    throw 'Kurulum dosyasi degismis'
}
& ([scriptblock]::Create([IO.File]::ReadAllText($awFile))) -Mode Apply
```

Beklenen Stage=applied, Error=null, Upgrade.ServiceTransitioned=true,
NewReleaseId=e6d734b1-59c8-48e5-8a6e-c40b43be3114,
SourceSignaturesValid/SignerSnapshotPreserved=true, CanApplyGpo=false.
Çıktı kabul edilmeden görev gönderilmez; bu update GPO/endpoint dağıtımı açmaz.
