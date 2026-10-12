# RADIUS embedded Python correction — 0.14.0-dev.2

The standalone panel/diagnostic interpreter can authorize a certificate while
the native FreeRADIUS callback rejects it with `AUTHORIZATION_INPUT_INVALID`.
On Ubuntu 24.04 the embedded interpreter defaults to distro package precedence:
it can import cryptography 41.0.7 instead of the appliance's pinned 46.0.0.
The older package lacks the timezone-aware X.509 validity properties required
by the certificate registry. Embedded Python also exposes an empty
`sys.executable`, so the isolated live-AD helper cannot use it as a program.

The generated native module now explicitly prepends the source and the package
directory used by the runtime generator. No certificate validation, CRL check,
AD protection, source-IP binding or policy condition is relaxed.

When there is no standalone interpreter, the Linux AD reader selects only
`/opt/kaname-lab/venv/bin/python` from the protected installed layout. It refuses
an uninstalled checkout, a missing executable, non-root ownership or paths
writable by other accounts. Normal Python processes retain their interpreter.
Passwords remain in the child process's standard input and ticket directories
are removed by the parent. The helper runs without writing bytecode.

Regression coverage checks the native embedded cryptography version and UTC
date API, helper IPC selection, untrusted-layout rejection and stdin-only
credentials. Native configuration checks do not replace a real AD/switch pilot.

After applying the verified source update to an already running RADIUS server,
restart the existing service so its embedded interpreter and generated module
configuration are loaded again:

```bash
sudo systemctl restart authwire-radius.service
```

Verify the service and its UDP listener, then repeat one EAP-TLS connection on
the designated pilot port. Existing CA material, issued certificates, AD and
switch settings are reused.
