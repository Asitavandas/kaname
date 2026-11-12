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
         'ConnectorServiceHost.cs','Invoke-AuthWireConnectorProbeJob.ps1',
         'Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1',
         'DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','Read-AuthWireDeploymentScope.ps1',
         'CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1',
         'CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','Read-AuthWireCombinedDeploymentScope.ps1']
PAYLOAD += ['SysvolInventory.ps1', 'CombinedStagingPreview.ps1', 'Invoke-AuthWireStagingPreviewJob.ps1', 'Read-AuthWireCombinedStagingPreview.ps1']
WRITE_PAYLOAD = [
    'ConnectorWriteServiceRuntime.ps1', 'StagingFilesystem.ps1', 'StagingWritePreclaim.ps1',
    'StagingWriteTransport.ps1', 'StagingWriteConsumption.ps1', 'StagingWriteProcess.ps1',
    'StagingWriteExecution.ps1', 'StagingWriteResult.ps1', 'StagingWriteCycle.ps1',
    'StagingRollbackEvidence.ps1', 'StagingRollbackAuthorization.ps1', 'StagingRollbackExecution.ps1',
    'StagingRollbackResult.ps1', 'StagingWritePollRecord.ps1', 'StagingWriteHistory.ps1',
    'StagingWriteRefusal.ps1', 'StagingWriteLifecycle.ps1', 'StagingWriteScheduler.ps1',
    'Read-AuthWireStagingWritePreflight.ps1', 'Read-AuthWireRollbackPreflight.ps1',
    'Invoke-AuthWireStagingWriteChild.ps1', 'Invoke-AuthWireRollbackChild.ps1',
]
ADMIN_TOOLS = ['ConnectorServicePackage.ps1','ConnectorServiceControl.ps1',
               'Install-AuthWireConnectorService.ps1','Initialize-AuthWireConnectorChannelKey.ps1']
ALL = PAYLOAD + ADMIN_TOOLS

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
                  'function Get-AuthWireReviewedPayloadHashes {\n @{',PAYLOAD+WRITE_PAYLOAD,args.update,footer='\n }\n}')
    replace_block(ROOT/'New-AuthWireConnectorServicePackage.ps1',
                  r'\$reviewed=@\{.*?\n\}', '$reviewed=@{',PAYLOAD+WRITE_PAYLOAD+ADMIN_TOOLS,args.update)
    replace_block(ROOT/'Update-AuthWireConnectorService.ps1',
                  r'\$reviewed=@\{.*?\n\}', '$reviewed=@{',
                  PAYLOAD+WRITE_PAYLOAD+ADMIN_TOOLS+['ConnectorServiceUpgrade.ps1'],args.update)
    print('AUTHWIRE_REVIEWED_SERVICE_SOURCE_HASHES_OK')

if __name__=='__main__':main()
