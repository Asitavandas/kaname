#!/usr/bin/env bash
# Run on the AuthWire Linux host as the operator; requires local sudo.
sudo /opt/kaname-lab/venv/bin/python -I -B -c 'import hashlib,pathlib; p=pathlib.Path("/home/segmentiq/authwire-candidate-registry-20261027.py"); b=p.read_bytes(); assert hashlib.sha256(b).hexdigest()=="20216103bd6ba7f5f4c057716ff65212a7a1a11895cb0a62587c6eb6d8d3ca29", "Kurulum dosyasi degismis"; exec(compile(b,str(p),"exec"))'
