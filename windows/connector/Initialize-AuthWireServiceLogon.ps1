#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','PrepareServiceRight')][string]$Mode = 'Inspect',
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName = 'aw-deploy',
    [Parameter(Mandatory=$true)][ValidatePattern('^S-1-5-21-(\d+-){3}\d+$')][string]$AccountSid,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
if (-not [Environment]::Is64BitProcess) { throw 'POWERSHELL_64_BIT_REQUIRED' }
if ([Environment]::MachineName -ine $ExpectedComputer) { throw 'LOCAL_COMPUTER_MISMATCH' }
if ($InstanceId -eq [guid]::Empty) { throw 'INSTANCE_ID_REQUIRED' }
$validatedSid = [System.Security.Principal.SecurityIdentifier]::new($AccountSid).Value
if (-not (Test-Path -LiteralPath $BootstrapPath -PathType Leaf)) { throw 'SIGNED_BOOTSTRAP_REQUIRED' }
$signature = Get-AuthenticodeSignature -FilePath $BootstrapPath
if ($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {
    throw 'BOOTSTRAP_SIGNATURE_INVALID'
}
$inspection = & $BootstrapPath -Mode Inspect -ExpectedDomain $ExpectedDomain -ConnectorComputer $ExpectedComputer `
    -InstanceId $InstanceId -AccountName $AccountName -PublisherThumbprint $PublisherThumbprint | ConvertFrom-Json
if ($inspection.Event -ne 'WINDOWS_CONNECTOR_BOOTSTRAP' -or $inspection.BootstrapVersion -ne '1.0.3' -or
    $inspection.Mode -ne 'Inspect' -or $inspection.Domain -ine $ExpectedDomain -or
    $inspection.Computer -ine $ExpectedComputer -or $inspection.ConnectorComputer -ine $ExpectedComputer -or
    $inspection.InstanceId -ine $InstanceId.ToString('D') -or
    -not $inspection.Kds.Ready -or -not $inspection.ReadyForAccountPreparation -or
    @($inspection.Blockers).Count -ne 0 -or -not $inspection.Account.Exists -or
    $inspection.Account.Name -ine ($AccountName + '$') -or $inspection.Account.Sid -ne $validatedSid -or
    $inspection.Account.AllowedPasswordHost -ine $ExpectedComputer) {
    throw 'OWNED_ACCOUNT_READBACK_REQUIRED'
}
if (-not ('AuthWire.Connector.LocalServiceRightV1' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace AuthWire.Connector {
    public static class LocalServiceRightV1 {
        [StructLayout(LayoutKind.Sequential)]
        private struct ObjectAttributes {
            public uint Length;
            public IntPtr RootDirectory, ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor, SecurityQualityOfService;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct UnicodeString {
            public ushort Length, MaximumLength;
            public IntPtr Buffer;
        }
        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaOpenPolicy(IntPtr systemName, ref ObjectAttributes attributes, uint access, out IntPtr policy);
        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaEnumerateAccountsWithUserRight(IntPtr policy, ref UnicodeString right, out IntPtr buffer, out uint count);
        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaFreeMemory(IntPtr buffer);
        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaClose(IntPtr policy);
        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaNtStatusToWinError(uint status);

        private static void Check(uint status, string operation) {
            if (status != 0)
                throw new Win32Exception(unchecked((int)LsaNtStatusToWinError(status)), operation);
        }

        public static string[] Read(string rightName) {
            if (String.IsNullOrEmpty(rightName)) throw new ArgumentException("Right name required.");
            IntPtr policy = IntPtr.Zero, buffer = IntPtr.Zero, text = IntPtr.Zero;
            try {
                ObjectAttributes attributes = new ObjectAttributes();
                attributes.Length = (uint)Marshal.SizeOf(typeof(ObjectAttributes));
                // Local policy only. VIEW_LOCAL_INFORMATION | LOOKUP_NAMES; no write access.
                Check(LsaOpenPolicy(IntPtr.Zero, ref attributes, 0x00000801, out policy), "LsaOpenPolicy");
                text = Marshal.StringToHGlobalUni(rightName);
                UnicodeString right = new UnicodeString();
                right.Length = checked((ushort)(rightName.Length * 2));
                right.MaximumLength = checked((ushort)(right.Length + 2));
                right.Buffer = text;
                uint count;
                uint status = LsaEnumerateAccountsWithUserRight(policy, ref right, out buffer, out count);
                if (status == 0x8000001Au) return new string[0]; // No accounts with this right.
                Check(status, "LsaEnumerateAccountsWithUserRight");
                if (count != 0 && buffer == IntPtr.Zero) throw new InvalidOperationException("Missing LSA enumeration buffer.");
                List<string> sids = new List<string>();
                for (uint i = 0; i < count; i++) {
                    IntPtr sid = Marshal.ReadIntPtr(buffer, checked((int)(i * (uint)IntPtr.Size)));
                    if (sid == IntPtr.Zero) throw new InvalidOperationException("Missing LSA account SID.");
                    sids.Add(new SecurityIdentifier(sid).Value);
                }
                return sids.ToArray();
            } finally {
                if (buffer != IntPtr.Zero) LsaFreeMemory(buffer);
                if (text != IntPtr.Zero) Marshal.FreeHGlobal(text);
                if (policy != IntPtr.Zero) LsaClose(policy);
            }
        }

        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaAddAccountRights(IntPtr policy, IntPtr sid, ref UnicodeString right, uint count);

        // Fixed right only. This creates an LSA policy entry if needed, never an AD account.
        public static void GrantServiceRight(string sidValue) {
            SecurityIdentifier sid = new SecurityIdentifier(sidValue);
            byte[] bytes = new byte[sid.BinaryLength];
            sid.GetBinaryForm(bytes, 0);
            IntPtr policy = IntPtr.Zero, sidBuffer = IntPtr.Zero, text = IntPtr.Zero;
            try {
                ObjectAttributes attributes = new ObjectAttributes();
                attributes.Length = (uint)Marshal.SizeOf(typeof(ObjectAttributes));
                // VIEW_LOCAL_INFORMATION | LOOKUP_NAMES | CREATE_ACCOUNT; not POLICY_ALL_ACCESS.
                Check(LsaOpenPolicy(IntPtr.Zero, ref attributes, 0x00000811, out policy), "LsaOpenPolicy");
                sidBuffer = Marshal.AllocHGlobal(bytes.Length);
                Marshal.Copy(bytes, 0, sidBuffer, bytes.Length);
                const string name = "SeServiceLogonRight";
                text = Marshal.StringToHGlobalUni(name);
                UnicodeString right = new UnicodeString();
                right.Length = checked((ushort)(name.Length * 2));
                right.MaximumLength = checked((ushort)(right.Length + 2));
                right.Buffer = text;
                Check(LsaAddAccountRights(policy, sidBuffer, ref right, 1), "LsaAddAccountRights");
            } finally {
                if (text != IntPtr.Zero) Marshal.FreeHGlobal(text);
                if (sidBuffer != IntPtr.Zero) Marshal.FreeHGlobal(sidBuffer);
                if (policy != IntPtr.Zero) LsaClose(policy);
            }
        }
    }
}
'@
}
$beforeAllow = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object -Unique)
$beforeDeny = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeDenyServiceLogonRight') | Sort-Object -Unique)
$previouslyPresent = ($beforeAllow -contains $validatedSid)
$addedNow = $false
$receipt = $null
$afterAllow = $beforeAllow
$afterDeny = $beforeDeny

if ($Mode -eq 'PrepareServiceRight') {
    # Conservative gate: any service deny assignment requires separate group review.
    if ($beforeDeny.Count -ne 0) { throw 'SERVICE_DENY_ASSIGNMENTS_REQUIRE_REVIEW' }
    if (-not $previouslyPresent) {
        $folder = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-ServiceRight-' + [guid]::NewGuid().ToString('N'))
        if (Test-Path -LiteralPath $folder) { throw 'EVIDENCE_PATH_ALREADY_EXISTS' }
        $security = New-Object System.Security.AccessControl.DirectorySecurity
        $security.SetSecurityDescriptorSddlForm('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
        $null = [IO.Directory]::CreateDirectory($folder,$security)
        $receipt = Join-Path $folder 'service-right.json'
        $record = [ordered]@{
            Version=1; Computer=[Environment]::MachineName; InstanceId=$InstanceId.ToString('D')
            AccountSid=$validatedSid; Right='SeServiceLogonRight'; PreviousDirectAssignment=$false
            BeforeAllow=$beforeAllow; BeforeDeny=$beforeDeny
            CreatedUtc=[datetime]::UtcNow.ToString('o'); Phase='before_add'; AddReturnedSuccess=$false
        }
        $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $receipt -Encoding UTF8

        $freshAllow = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object -Unique)
        $freshDeny = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeDenyServiceLogonRight') | Sort-Object -Unique)
        if (($freshAllow -join ',') -ne ($beforeAllow -join ',') -or ($freshDeny -join ',') -ne ($beforeDeny -join ',')) {
            throw ('POLICY_CHANGED_BEFORE_ADD_REINSPECT:' + $receipt)
        }
        try {
            [AuthWire.Connector.LocalServiceRightV1]::GrantServiceRight($validatedSid)
            $addedNow = $true
            $record.AddReturnedSuccess = $true
            $record.Phase = 'add_returned_success'
            $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $receipt -Encoding UTF8
            $afterAllow = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object -Unique)
            $afterDeny = @([AuthWire.Connector.LocalServiceRightV1]::Read('SeDenyServiceLogonRight') | Sort-Object -Unique)
            if ($afterAllow -notcontains $validatedSid -or
                @($beforeAllow | Where-Object { $afterAllow -notcontains $_ }).Count -ne 0 -or
                ($beforeDeny -join ',') -ne ($afterDeny -join ',')) {
                throw 'SERVICE_RIGHT_POSTCHECK_FAILED'
            }
            $record.Phase = 'verified'
            $record['AfterAllow'] = $afterAllow
            $record['AfterDeny'] = $afterDeny
            $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $receipt -Encoding UTF8
        } catch {
            throw ('SERVICE_RIGHT_RESULT_REQUIRES_REINSPECTION:' + $receipt + ':' + $_.Exception.Message)
        }
    }
}
[pscustomobject]@{
    Event='WINDOWS_CONNECTOR_SERVICE_RIGHT_PREPARATION'; ToolVersion='1.0.0'; Mode=$Mode
    Computer=[Environment]::MachineName; Account=($AccountName + '$'); AccountSid=$validatedSid
    Right='SeServiceLogonRight'; PreviouslyAssigned=$previouslyPresent; AddedNow=$addedNow
    DirectServiceRightAssigned=($afterAllow -contains $validatedSid)
    AllowAssignedSids=$afterAllow; DenyAssignedSids=$afterDeny
    ExistingAssignmentsPreserved=(@($beforeAllow | Where-Object { $afterAllow -notcontains $_ }).Count -eq 0 -and ($beforeDeny -join ',') -eq ($afterDeny -join ','))
    ReceiptPath=$receipt; LocalPolicyChanged=$addedNow; AdChanged=$false; GpoChanged=$false
    ServiceLogonVerified=$false; GpoPersistenceVerified=$false; ConnectorInstalled=$false
    CanApplyGpo=$false; ServicesCreated=$false; SecretsExported=$false
} | ConvertTo-Json -Depth 5
