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
