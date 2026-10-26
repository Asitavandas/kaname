"""Developer-only reviewed-source pin maintenance; default checks without writes.

Use --update only after reviewing a source change. Customer tools never call it.
Authenticode suffixes and checkout CRLF are excluded in the same canonical form
accepted by the signed builder; a marker inside a string literal is not a suffix.
"""
import argparse
import hashlib
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]/'windows'/'connector'
PAYLOAD=['ConnectorServiceRuntime.ps1','Compare-AuthWireSigningKeyAcl.ps1',
         'ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1',
         'New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorHealth.ps1',
         'ConnectorServiceHost.cs','Invoke-AuthWireConnectorProbeJob.ps1']
ALL=PAYLOAD+['ConnectorServicePackage.ps1','ConnectorServiceControl.ps1',
             'Install-AuthWireConnectorService.ps1','Initialize-AuthWireConnectorChannelKey.ps1']

def digest(name):
    text=(ROOT/name).read_text(encoding='utf-8-sig')
    body=re.split(r'(?m)^# SIG # Begin signature block\r?$',text,maxsplit=1)[0]
    body=body.replace('\r\n','\n').rstrip('\r\n')+'\n'
    return hashlib.sha256(body.encode('utf-8')).hexdigest().upper()

def replace_block(path,pattern,header,names,update,footer='\n}'):
    old=path.read_text(encoding='utf-8-sig')
    new_block=header+'\n'+'\n'.join(" '"+n+"'='"+digest(n)+"'" for n in names)+footer
    new,count=re.subn(pattern,lambda _:new_block,old,count=1,flags=re.S)
    if count!=1:raise RuntimeError('Reviewed-source table missing: '+path.name)
    if old!=new:
        if not update:raise RuntimeError('Reviewed-source table differs: '+path.name)
        path.write_text(new,encoding='utf-8')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--update',action='store_true')
    args=parser.parse_args()
    replace_block(ROOT/'ConnectorServicePackage.ps1',
                  r'function Get-AuthWireReviewedPayloadHashes \{\s*@\{.*?\n\s*\}\s*\}',
                  'function Get-AuthWireReviewedPayloadHashes {\n @{',PAYLOAD,args.update,footer='\n }\n}')
    replace_block(ROOT/'New-AuthWireConnectorServicePackage.ps1',
                  r'\$reviewed=@\{.*?\n\}', '$reviewed=@{',ALL,args.update)
    print('AUTHWIRE_REVIEWED_SERVICE_SOURCE_HASHES_OK')

if __name__=='__main__':main()
