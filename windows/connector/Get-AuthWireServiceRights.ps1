#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][ValidatePattern('^S-1-5-21-(\d+-){3}\d+$')][string]$AccountSid
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
if (-not [Environment]::Is64BitProcess) { throw 'POWERSHELL_64_BIT_REQUIRED' }
if ([Environment]::MachineName -ine $ExpectedComputer) { throw 'LOCAL_COMPUTER_MISMATCH' }
$validatedSid = [System.Security.Principal.SecurityIdentifier]::new($AccountSid).Value

if (-not ('AuthWire.Connector.LocalRightsReaderV1' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace AuthWire.Connector {
    public static class LocalRightsReaderV1 {
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
    }
}
'@
}

$allow = @([AuthWire.Connector.LocalRightsReaderV1]::Read('SeServiceLogonRight'))
$deny = @([AuthWire.Connector.LocalRightsReaderV1]::Read('SeDenyServiceLogonRight'))
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_SERVICE_RIGHTS_LSA_READONLY'
    ProbeVersion = '1.0.0'
    Computer = [Environment]::MachineName
    AccountSid = $validatedSid
    AllowAssignedSids = $allow
    DenyAssignedSids = $deny
    DirectAllowAssigned = ($allow -contains $validatedSid)
    DirectDenyAssigned = ($deny -contains $validatedSid)
    ReadSucceeded = $true
    GroupEvaluationPerformed = $false
    EffectiveServiceRightVerified = $false
    ServiceLogonVerified = $false
    PolicyChanged = $false
    AdChanged = $false
    ServicesCreated = $false
    SecretsExported = $false
} | ConvertTo-Json -Depth 4
