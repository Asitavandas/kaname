# Internal fixed-purpose key engine. Caller must validate the signed bootstrap/account.
function Assert-AuthWireChannelPath {
    param([string]$Path)
    $p=[IO.Path]::GetFullPath($Path)
    while($p){
        if(Test-Path -LiteralPath $p){if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'CONNECTOR_REPARSE_POINT_REJECTED'}}
        $next=[IO.Path]::GetDirectoryName($p);if($next -eq $p){break};$p=$next
    }
}

function Write-AuthWireChannelReceipt {
    param([string]$Path,[hashtable]$Value)
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 6))
        $stream=[IO.FileStream]::new($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
        if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temporary,$Path,$null)}else{[IO.File]::Move($temporary,$Path)}
    }finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
}

function Assert-AuthWireChannelOwner {
    param([string]$Path)
    $owner=(Get-Acl -LiteralPath $Path).GetOwner([Security.Principal.SecurityIdentifier]).Value
    $i=[Security.Principal.WindowsIdentity]::GetCurrent()
    try{$caller=$i.User.Value}finally{$i.Dispose()}
    if($owner -notin @('S-1-5-18','S-1-5-32-544',$caller)){throw 'CONNECTOR_OWNER_MISMATCH'}
}

function Assert-AuthWireChannelReceiptAcl {
    param([string]$Path,[string]$Sid)
    Assert-AuthWireChannelPath $Path;Assert-AuthWireChannelOwner $Path
    $acl=Get-Acl -LiteralPath $Path
    $rules=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    if($rules.Count -ne 3){throw 'CONNECTOR_RECEIPT_ACL_MISMATCH'}
    foreach($r in $rules){
        $who=$r.IdentityReference.Value;$mask=[int]$r.FileSystemRights
        if($r.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
            ($who -in @('S-1-5-18','S-1-5-32-544') -and $mask -ne 2032127) -or
            ($who -eq $Sid -and $mask -notin @(1179785,1179817)) -or
            $who -notin @('S-1-5-18','S-1-5-32-544',$Sid)){throw 'CONNECTOR_RECEIPT_ACL_MISMATCH'}
    }
    foreach($who in @('S-1-5-18','S-1-5-32-544',$Sid)){if(@($rules|Where-Object{$_.IdentityReference.Value -eq $who}).Count -ne 1){throw 'CONNECTOR_RECEIPT_ACL_MISMATCH'}}
}

function Get-AuthWireChannelFileSddl {
    param([string]$Path,[string]$Sid,[switch]$Directory)
    $acl=Get-Acl -LiteralPath $Path
    $owner=$acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    $group=$acl.GetGroup([Security.Principal.SecurityIdentifier]).Value
    $flags=if($Directory){'OICI'}else{''}
    $read=if($Directory){'FRFX'}else{'FR'}
    return ('O:'+$owner+'G:'+$group+'D:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$read+';;;'+$Sid+')')
}

function Initialize-AuthWireChannelKeyCore {
    param([ValidateSet('Inspect','PrepareKey')][string]$Mode='Inspect',
          [Parameter(Mandatory=$true)][string]$Directory,
          [Parameter(Mandatory=$true)][hashtable]$BaseBinding)
    $fields=@('instance_id','connector_id','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256')
    if($BaseBinding.Count -ne 7 -or @($fields|Where-Object{-not $BaseBinding.ContainsKey($_)}).Count){throw 'CONNECTOR_BINDING_INVALID'}
    foreach($n in @('instance_id','connector_id','host_guid')){
        $g=[guid]::Empty
        if($BaseBinding[$n] -isnot [string] -or -not [guid]::TryParseExact($BaseBinding[$n],'D',[ref]$g) -or $g -eq [guid]::Empty -or $g.ToString('D') -cne $BaseBinding[$n]){throw 'CONNECTOR_BINDING_INVALID'}
    }
    foreach($n in @('host_fqdn','appliance_fqdn')){
        $v=$BaseBinding[$n]
        if($v -isnot [string] -or $v.Length -gt 253 -or $v -cne $v.ToLowerInvariant() -or $v.Split('.').Count -lt 2){throw 'CONNECTOR_BINDING_INVALID'}
        foreach($s in $v.Split('.')){if($s -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z'){throw 'CONNECTOR_BINDING_INVALID'}}
    }
    $sid=$BaseBinding.service_sid
    if($sid -isnot [string] -or $sid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z' -or $BaseBinding.appliance_tls_sha256 -cnotmatch '\A[0-9a-f]{64}\z'){throw 'CONNECTOR_BINDING_INVALID'}
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try{
        $principal=[Security.Principal.WindowsPrincipal]::new($identity)
        if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'CONNECTOR_ELEVATED_ADMIN_REQUIRED'}
    }finally{$identity.Dispose()}
    Assert-AuthWireChannelPath $Directory
    Initialize-AuthWireChannelTypes
    $receiptPath=Join-Path $Directory 'channel-key.json'
    if(-not (Test-Path -LiteralPath $Directory) -and $Mode -eq 'Inspect'){
        return [pscustomobject]@{ReadyForPrepare=$true;KeyCreated=$false;KeyPropertiesVerified=$false;ReadAclVerified=$false;ServiceKeyAccessVerified=$false;ReceiptPath=$receiptPath;ConnectorInstalled=$false;AdChanged=$false;GpoChanged=$false;SecretsExported=$false}
    }
    $createdRoot=$false
    if(-not (Test-Path -LiteralPath $Directory)){
        $null=New-Item -ItemType Directory -Path $Directory -ErrorAction Stop;$createdRoot=$true
        $security=Get-Acl -LiteralPath $Directory
        $security.SetSecurityDescriptorSddlForm((Get-AuthWireChannelFileSddl $Directory $sid -Directory))
        Set-Acl -LiteralPath $Directory -AclObject $security
    }
    if(-not (Test-Path -LiteralPath $Directory -PathType Container)){throw 'CONNECTOR_DIRECTORY_INVALID'}
    Assert-AuthWireChannelOwner $Directory
    $expectedRoot=Get-AuthWireChannelFileSddl $Directory $sid -Directory
    if(-not (Compare-AuthWireSigningKeyAcl $expectedRoot (Get-Acl -LiteralPath $Directory).Sddl).AclEquivalent){throw 'CONNECTOR_DIRECTORY_ACL_MISMATCH'}
    # Inspect never creates a directory, lock file, key or receipt.
    if($Mode -eq 'Inspect' -and -not (Test-Path -LiteralPath $receiptPath)){throw 'CONNECTOR_KEY_PREPARATION_REQUIRES_REVIEW'}
    $lock=$null;$key=$null;$rsa=$null;$newKey=$false
    try{
        if($Mode -eq 'PrepareKey'){
            $lockPath=Join-Path $Directory 'channel-key.lock';Assert-AuthWireChannelPath $lockPath
            $lock=[IO.FileStream]::new($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        }
        if(Test-Path -LiteralPath $receiptPath){
            Assert-AuthWireChannelReceiptAcl $receiptPath $sid
            if((Get-Item -LiteralPath $receiptPath).Length -gt 16384){throw 'CONNECTOR_KEY_RECEIPT_MISMATCH'}
            $r=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
            $allowed=@('Format','Phase','KeyName','Binding','PublicKeyPem','KeySha256','ExpectedKeySddl')
            if(@($r.PSObject.Properties).Count -ne 7 -or @($r.PSObject.Properties.Name|Where-Object{$_ -notin $allowed}).Count){throw 'CONNECTOR_KEY_PREPARATION_REQUIRES_REVIEW'}
            if($r.Format -isnot [int] -or $r.Format -ne 1 -or $r.Phase -cne 'verified' -or $r.KeyName -cnotmatch ('\AAuthWire-Channel-'+([guid]$BaseBinding.connector_id).ToString('N')+'-[0-9a-f]{32}\z') -or @($r.Binding.PSObject.Properties).Count -ne 7){throw 'CONNECTOR_KEY_PREPARATION_REQUIRES_REVIEW'}
            foreach($n in $fields){if($r.Binding.$n -cne $BaseBinding[$n]){throw 'CONNECTOR_KEY_SCOPE_MISMATCH'}}
            $key=[Security.Cryptography.CngKey]::Open($r.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
        }else{
            if(-not $createdRoot){throw 'CONNECTOR_KEY_PREPARATION_REQUIRES_REVIEW'}
            $name='AuthWire-Channel-'+([guid]$BaseBinding.connector_id).ToString('N')+'-'+[guid]::NewGuid().ToString('N')
            $r=@{Format=1;Phase='before_create';KeyName=$name;Binding=$BaseBinding.Clone()}
            Write-AuthWireChannelReceipt $receiptPath $r
            $p=[Security.Cryptography.CngKeyCreationParameters]::new()
            $p.Provider=[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
            $p.KeyCreationOptions=[Security.Cryptography.CngKeyCreationOptions]::MachineKey
            $p.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None;$p.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing
            $p.Parameters.Add([Security.Cryptography.CngProperty]::new('Length',[BitConverter]::GetBytes(3072),[Security.Cryptography.CngPropertyOptions]::None))
            $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,$name,$p);$newKey=$true
            $r.Phase='key_created';Write-AuthWireChannelReceipt $receiptPath $r
        }
        $rsa=[Security.Cryptography.RSACng]::new($key)
        if(-not $key.IsMachineKey -or $key.IsEphemeral -or [int]$key.ExportPolicy -ne 0 -or [int]$key.KeyUsage -ne 2 -or $rsa.KeySize -ne 3072){throw 'CONNECTOR_KEY_POLICY_REJECTED'}
        if($key.UniqueName -cnotmatch '\A[A-Za-z0-9_-]{20,150}\z'){throw 'CONNECTOR_KEY_FILE_REJECTED'}
        $keyFile=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
        Assert-AuthWireChannelPath $keyFile
        Assert-AuthWireChannelOwner $keyFile
        $expectedKey=Get-AuthWireChannelFileSddl $keyFile $sid
        if($newKey){
            $acl=Get-Acl -LiteralPath $keyFile;$acl.SetSecurityDescriptorSddlForm($expectedKey)
            Set-Acl -LiteralPath $keyFile -AclObject $acl
        }
        if(-not (Compare-AuthWireSigningKeyAcl $expectedKey (Get-Acl -LiteralPath $keyFile).Sddl).AclEquivalent){throw 'CONNECTOR_KEY_ACL_MISMATCH'}
        $pem=[AuthWire.Connector.ChannelTypesV1]::PublicPem($rsa)
        $keyId=Get-AuthWireChannelPublicKeyId $rsa
        if($newKey){
            $r.Phase='verified';$r.PublicKeyPem=$pem;$r.KeySha256=$keyId;$r.ExpectedKeySddl=$expectedKey
            Write-AuthWireChannelReceipt $receiptPath $r
        }elseif($r.PublicKeyPem -cne $pem -or $r.KeySha256 -cne $keyId -or -not (Compare-AuthWireSigningKeyAcl $r.ExpectedKeySddl (Get-Acl -LiteralPath $keyFile).Sddl).AclEquivalent){throw 'CONNECTOR_KEY_RECEIPT_MISMATCH'}
        [pscustomobject]@{ReadyForPrepare=$true;KeyCreated=$newKey;KeyName=$key.KeyName;KeySha256=$keyId;KeyPropertiesVerified=$true;ReadAclVerified=$true;ServiceKeyAccessVerified=$false;ReceiptPath=$receiptPath;PairingCandidate=($BaseBinding.Clone()+@{public_key_pem=$pem});ConnectorInstalled=$false;AdChanged=$false;GpoChanged=$false;SecretsExported=$false}
    }finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()};if($lock){$lock.Dispose()}}
}
