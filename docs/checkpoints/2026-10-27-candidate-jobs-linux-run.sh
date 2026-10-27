# Operator command on AuthWire Linux; does not run automatically.
sudo /opt/kaname-lab/venv/bin/python -I -B -c 'import hashlib,pathlib; p=pathlib.Path("/home/segmentiq/authwire-candidate-jobs-20261027.py"); b=p.read_bytes(); assert hashlib.sha256(b).hexdigest()=="9ce550af4267e27f3d29d776b2a5590afc376a7b08a3bb2607834858afdb9f1d", "Kurulum dosyasi degismis"; exec(compile(b,str(p),"exec"))'
