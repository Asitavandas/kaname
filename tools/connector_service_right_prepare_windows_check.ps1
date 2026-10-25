# Actual LSA add/read/cleanup only for a unique unused fixture SID on a disposable CI VM.
$ErrorActionPreference='Stop'
if ($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$source=Join-Path $PSScriptRoot '..\windows\connector\Initialize-AuthWireServiceLogon.ps1'
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors.Message -join '; ') }
$definitions=@($ast.FindAll({
    param($n)
    $n -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $n.StringConstantType.ToString() -eq 'SingleQuotedHereString'
},$true))
if ($definitions.Count -ne 1) { throw 'Expected exactly one native implementation.' }
Add-Type -TypeDefinition $definitions[0].Value
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace AuthWire.Connector {
    public static class FixtureServiceRightCleanupV1 {
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
                const string name = "SeBatchLogonRight";
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

        [DllImport("advapi32.dll", ExactSpelling=true)]
        private static extern uint LsaRemoveAccountRights(IntPtr policy, IntPtr sid, [MarshalAs(UnmanagedType.Bool)] bool allRights, ref UnicodeString right, uint count);
        public static void RemoveFixtureRight(string sidValue, string rightName) {
            if (rightName != "SeServiceLogonRight" && rightName != "SeBatchLogonRight")
                throw new ArgumentException("Fixture cleanup scope.");
            SecurityIdentifier sid = new SecurityIdentifier(sidValue);
            byte[] bytes = new byte[sid.BinaryLength];
            sid.GetBinaryForm(bytes, 0);
            IntPtr policy = IntPtr.Zero, sidBuffer = IntPtr.Zero, text = IntPtr.Zero;
            try {
                ObjectAttributes attributes = new ObjectAttributes();
                attributes.Length = (uint)Marshal.SizeOf(typeof(ObjectAttributes));
                Check(LsaOpenPolicy(IntPtr.Zero, ref attributes, 0x00000811, out policy), "CleanupOpen");
                sidBuffer = Marshal.AllocHGlobal(bytes.Length);
                Marshal.Copy(bytes, 0, sidBuffer, bytes.Length);
                text = Marshal.StringToHGlobalUni(rightName);
                UnicodeString right = new UnicodeString();
                right.Length = checked((ushort)(rightName.Length * 2));
                right.MaximumLength = checked((ushort)(right.Length + 2));
                right.Buffer = text;
                uint status = LsaRemoveAccountRights(policy, sidBuffer, false, ref right, 1);
                if (status != 0xC0000034u) Check(status, "CleanupRemoveSingleRight");
            } finally {
                if (text != IntPtr.Zero) Marshal.FreeHGlobal(text);
                if (sidBuffer != IntPtr.Zero) Marshal.FreeHGlobal(sidBuffer);
                if (policy != IntPtr.Zero) LsaClose(policy);
            }
        }
    }
}
'@
$script:checks=0
function Check([bool]$Value,[string]$Name) {
    if (-not $Value) { throw $Name }; $script:checks++
}
$fixtureSid='S-1-5-21-111-222-333-' + [BitConverter]::ToUInt32([guid]::NewGuid().ToByteArray(),0).ToString()
$computer=[Environment]::MachineName
$instance=[guid]'e195f912-5418-4262-966a-eab64cdcc121'
$publisher='A' * 40
$fakeBootstrap=Join-Path $env:RUNNER_TEMP ('AuthWire-Owned-Fixture-' + [guid]::NewGuid().ToString('N') + '.ps1')
@'
param($Mode,$ExpectedDomain,$ConnectorComputer,$InstanceId,$AccountName,$PublisherThumbprint)
if ($Mode -ne 'Inspect') { throw 'Fixture bootstrap invoked for mutation.' }
$global:AwRightFixture.Inspection | ConvertTo-Json -Depth 6
'@ | Set-Content -LiteralPath $fakeBootstrap -Encoding UTF8
function Reset-Inspection {
    $global:AwRightFixture=@{
        SignatureValid=$true
        Inspection=[pscustomobject]@{
            Event='WINDOWS_CONNECTOR_BOOTSTRAP'; BootstrapVersion='1.0.3'; Mode='Inspect'
            Domain='test.example'; Computer=$computer; ConnectorComputer=$computer
            InstanceId=$instance.ToString('D'); Kds=[pscustomobject]@{Ready=$true}
            ReadyForAccountPreparation=$true; Blockers=@()
            Account=[pscustomobject]@{
                Exists=$true;Name='aw-deploy$';Sid=$fixtureSid;AllowedPasswordHost=$computer
            }
        }
    }
}
function Get-AuthenticodeSignature {
    [CmdletBinding()]param([string]$FilePath)
    if ($FilePath -ne $fakeBootstrap) { throw 'Unexpected fixture signature query.' }
    [pscustomobject]@{
        Status=$(if($global:AwRightFixture.SignatureValid){'Valid'}else{'HashMismatch'})
        SignerCertificate=[pscustomobject]@{Thumbprint=$publisher}
    }
}
function Run-Preparation([string]$Mode='Inspect',[string]$HostName=$computer) {
    & $source -Mode $Mode -ExpectedComputer $HostName -ExpectedDomain 'test.example' -InstanceId $instance `
        -AccountSid $fixtureSid -BootstrapPath $fakeBootstrap -PublisherThumbprint $publisher | ConvertFrom-Json
}
function Expect-Blocked([string]$Message,[string]$HostName=$computer) {
    $caught=$false
    try { $null=Run-Preparation 'PrepareServiceRight' $HostName } catch {
        if ($_.Exception.Message -notlike ('*' + $Message + '*')) { throw }
        $caught=$true
    }
    Check $caught ('Blocked ' + $Message)
    Check (@([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight')) -notcontains $fixtureSid) 'Blocked path has no service-right write'
}
$baselineAllow=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object)
$baselineDeny=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeDenyServiceLogonRight') | Sort-Object)
$baselineBatch=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeBatchLogonRight') | Sort-Object)
$receiptFolder=$null
try {
    Check ($baselineAllow -notcontains $fixtureSid -and $baselineBatch -notcontains $fixtureSid) 'Unique fixture SID starts without rights'
    # Give only the unused fixture SID an unrelated right; the production add must preserve it.
    [AuthWire.Connector.FixtureServiceRightCleanupV1]::GrantServiceRight($fixtureSid)
    Reset-Inspection
    $r=Run-Preparation
    Check (-not $r.LocalPolicyChanged -and -not $r.DirectServiceRightAssigned -and $null -eq $r.ReceiptPath) 'Default Inspect never adds a right or receipt'
    Expect-Blocked 'LOCAL_COMPUTER_MISMATCH' 'WRONG-HOST'
    Reset-Inspection; $global:AwRightFixture.SignatureValid=$false
    Expect-Blocked 'BOOTSTRAP_SIGNATURE_INVALID'
    foreach ($bad in @('version','blocked','absent','sid','instance','domain','kds','reader','name','mode')) {
        Reset-Inspection
        switch ($bad) {
            'version' {$global:AwRightFixture.Inspection.BootstrapVersion='1.0.2'}
            'blocked' {$global:AwRightFixture.Inspection.Blockers=@('OWNERSHIP_MISMATCH')}
            'absent' {$global:AwRightFixture.Inspection.Account.Exists=$false}
            'sid' {$global:AwRightFixture.Inspection.Account.Sid='S-1-5-21-111-222-333-1'}
            'instance' {$global:AwRightFixture.Inspection.InstanceId=[guid]::NewGuid().ToString('D')}
            'domain' {$global:AwRightFixture.Inspection.Domain='other.example'}
            'kds' {$global:AwRightFixture.Inspection.Kds.Ready=$false}
            'reader' {$global:AwRightFixture.Inspection.Account.AllowedPasswordHost='OTHER-HOST'}
            'name' {$global:AwRightFixture.Inspection.Account.Name='customer$'}
            'mode' {$global:AwRightFixture.Inspection.Mode='PrepareAccount'}
        }
        Expect-Blocked 'OWNED_ACCOUNT_READBACK_REQUIRED'
    }
    Reset-Inspection
    $fullPrepare=($baselineDeny.Count -eq 0)
    if ($fullPrepare) {
        $r=Run-Preparation 'PrepareServiceRight'
        $receiptFolder=Split-Path -Parent $r.ReceiptPath
        Check ($r.AddedNow -and $r.LocalPolicyChanged -and $r.DirectServiceRightAssigned) 'Full guarded prepare adds exactly the target right'
        Check ($r.ExistingAssignmentsPreserved -and -not $r.AdChanged -and -not $r.GpoChanged -and -not $r.ServicesCreated -and -not $r.ServiceLogonVerified) 'Preparation preserves independent permissions and service gates'
        $saved=Get-Content -LiteralPath $r.ReceiptPath -Raw | ConvertFrom-Json
        Check ($saved.AccountSid -eq $fixtureSid -and $saved.Right -eq 'SeServiceLogonRight' -and $saved.Phase -eq 'verified') 'Protected receipt records exact verified change'
        $acl=Get-Acl -LiteralPath $receiptFolder
        Check $acl.AreAccessRulesProtected 'Receipt directory disables inherited access'
        $rules=@($acl.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier]))
        Check ($rules.Count -eq 2 -and @($rules | Where-Object {$_.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')}).Count -eq 0) 'Receipt access limited to SYSTEM and Administrators'
        $r=Run-Preparation 'PrepareServiceRight'
        Check (-not $r.AddedNow -and -not $r.LocalPolicyChanged -and $r.PreviouslyAssigned -and $null -eq $r.ReceiptPath) 'Repeated preparation makes no second change'
    } else {
        Expect-Blocked 'SERVICE_DENY_ASSIGNMENTS_REQUIRE_REVIEW'
        [AuthWire.Connector.LocalServiceRightV1]::GrantServiceRight($fixtureSid)
    }
    $allow=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object)
    $deny=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeDenyServiceLogonRight') | Sort-Object)
    $batch=@([AuthWire.Connector.LocalServiceRightV1]::Read('SeBatchLogonRight') | Sort-Object)
    Check (($allow | Where-Object {$_ -ne $fixtureSid}) -join ',' -eq ($baselineAllow -join ',')) 'Existing global service assignments unchanged'
    Check (($deny -join ',') -eq ($baselineDeny -join ',')) 'Deny assignments unchanged'
    Check ($batch -contains $fixtureSid -and (($batch | Where-Object {$_ -ne $fixtureSid}) -join ',') -eq ($baselineBatch -join ',')) 'Target unrelated rights and other batch assignments preserved'
    [AuthWire.Connector.LocalServiceRightV1]::GrantServiceRight($fixtureSid)
    Check (@([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Where-Object {$_ -eq $fixtureSid}).Count -eq 1) 'Native add is idempotent'
    $text=[IO.File]::ReadAllText($source)
    Check (-not $text.Contains('LsaRemoveAccountRights') -and -not $text.Contains('POLICY_ALL_ACCESS,')) 'Production exposes no right removal or all-access request'
} finally {
    # Only our unique unused SID and the two rights created in this fixture are touched.
    [AuthWire.Connector.FixtureServiceRightCleanupV1]::RemoveFixtureRight($fixtureSid,'SeServiceLogonRight')
    [AuthWire.Connector.FixtureServiceRightCleanupV1]::RemoveFixtureRight($fixtureSid,'SeBatchLogonRight')
    Remove-Item -LiteralPath $fakeBootstrap -Force -ErrorAction SilentlyContinue
    if ($null -ne $receiptFolder) { Remove-Item -LiteralPath $receiptFolder -Recurse -Force }
    Remove-Variable AwRightFixture -Scope Global -ErrorAction SilentlyContinue
}
Check ((@([AuthWire.Connector.LocalServiceRightV1]::Read('SeServiceLogonRight') | Sort-Object) -join ',') -eq ($baselineAllow -join ',')) 'Fixture cleanup restores service assignments'
Check ((@([AuthWire.Connector.LocalServiceRightV1]::Read('SeBatchLogonRight') | Sort-Object) -join ',') -eq ($baselineBatch -join ',')) 'Fixture cleanup restores batch assignments'
Write-Output ('AUTHWIRE_SERVICE_RIGHT_PREPARE_NATIVE_OK ' + (@{
    checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString()
    real_local_lsa_add_tested=$true;full_prepare_entry_tested=$fullPrepare
    unused_fixture_sid_only=$true;fixture_cleanup_verified=$true
    real_customer_ad_tested=$false;service_logon_tested=$false;services_created=0
}|ConvertTo-Json -Compress))
