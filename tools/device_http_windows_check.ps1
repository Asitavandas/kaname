# Exercise the production error reader with an isolated loopback HTTP response.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'kaname\device_client\AuthWire-Client.ps1'
. $source -ValidateOnly
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Client source failed to parse.' }
$functionAst = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Post-Json'}, $true)
if (!$functionAst) { throw 'Client HTTP function is missing.' }
. ([scriptblock]::Create($functionAst.Extent.Text))

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

public sealed class AuthWireHttpResponseFixture : IDisposable {
    readonly TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
    public AuthWireHttpResponseFixture() { listener.Start(); }
    public int Port { get { return ((IPEndPoint)listener.LocalEndpoint).Port; } }

    public Task Reply(int status, string body) {
        return Task.Run(() => {
            using (var client = listener.AcceptTcpClient()) {
                client.ReceiveTimeout = 4000;
                var stream = client.GetStream();
                var header = new StringBuilder();
                while (!header.ToString().EndsWith("\r\n\r\n", StringComparison.Ordinal)) {
                    int next = stream.ReadByte();
                    if (next < 0 || header.Length >= 4096) throw new IOException("Invalid fixture request header.");
                    header.Append((char)next);
                }
                if (header.ToString().IndexOf("Expect: 100-continue", StringComparison.OrdinalIgnoreCase) >= 0) {
                    byte[] interim = Encoding.ASCII.GetBytes("HTTP/1.1 100 Continue\r\n\r\n");
                    stream.Write(interim, 0, interim.Length);
                }
                var length = Regex.Match(header.ToString(), @"Content-Length: (\d+)", RegexOptions.IgnoreCase);
                if (!length.Success) throw new IOException("Missing fixture request length.");
                for (int n = int.Parse(length.Groups[1].Value); n > 0; n--)
                    if (stream.ReadByte() < 0) throw new IOException("Truncated fixture request.");
                string reason = status == 200 ? "OK" : "Forbidden";
                byte[] response = Encoding.ASCII.GetBytes("HTTP/1.0 " + status + " " + reason +
                    "\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " + body.Length +
                    "\r\nConnection: close\r\n\r\n" + body);
                stream.Write(response, 0, response.Length);
            }
        });
    }

    public void Dispose() { listener.Stop(); }
}
'@

function Test-Response([int]$Status, [string]$Body, [string]$ExpectedError) {
    $fixture = New-Object AuthWireHttpResponseFixture
    try {
        $reply = $fixture.Reply($Status, $Body)
        $config = @{url = ('http://127.0.0.1:' + $fixture.Port)}
        $script:serverError = $null
        $failure = $null
        $result = $null
        try { $result = Post-Json '/api/device/issue' @{fixture = $true} }
        catch { $failure = $_ }
        $reply.GetAwaiter().GetResult()
        if ($Status -eq 200) {
            if ($failure -or $result.fixture -ne 'success') { throw 'Successful response did not reach the client.' }
        } elseif (!$failure) {
            throw 'HTTP rejection did not fail the request.'
        }
        if ([string]$script:serverError -cne $ExpectedError) { throw 'Unexpected machine enrollment error code.' }
    } finally { $fixture.Dispose() }
}

$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
try {
    foreach ($culture in 'tr-TR', 'en-US') {
        [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
        Test-Response 403 '{"error":"DEVICE_CERTIFICATE_EXPIRED"}' 'DEVICE_CERTIFICATE_EXPIRED'
        Test-Response 403 '{"error":"device_certificate_expired"}' ''
        Test-Response 403 '{' ''
        Test-Response 200 '{"fixture":"success"}' ''
    }
} finally { [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture }
Write-Output 'AUTHWIRE_WINDOWS_HTTP_ERROR_READER_OK'
