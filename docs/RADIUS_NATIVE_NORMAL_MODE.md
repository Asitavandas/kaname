# Native Python attribute parser backport

The pinned FreeRADIUS 3.2.10 Python module parsed returned attribute values
inside a DEBUG macro. With debugging disabled, an adapter's Auth-Type Accept
and VLAN/reply values were not parsed. A valid policy decision could therefore
end in Access-Reject. Debug-mode-only EAP-TLS tests hid the defect.

Backport upstream commit 58bafac6e5d4eb098d533cc0e7fe2fd41a73d213 to the
existing pinned source 9071ea041b9172e52eabbba91619afaf3a238795. Parsing now
happens before optional logging, and invalid attribute values are discarded.
The backport retains secret-value redaction in both success and failure logs.
CI cache identity includes the exact patch digest. Runtime manifests explicitly
identify the base revision and backported commit.

CI runs the full synthetic EAP-TLS/policy/VLAN/security matrix in normal and
debug modes. A separate localhost UDP check verifies authenticated Accept and
Reject responses, reply values, and VLAN attributes with debugging disabled.
Neither check uses customer AD or binds a LAN listener.

For an existing protected installation, tools/radius_module_update.py accepts
the reviewed runtime digest, verifies the original module against its installed
manifest, and backs it up with that manifest. It replaces only lib/rlm_python3.so
and updates its manifest entry atomically. A start failure restores both files
and the previous service state. Inactive services stay inactive; enabled state,
unit hardening, other native binaries, application state, policies, certificates
and Windows settings are preserved. The launcher is stdlib-only and uses the
same private update lock as the application updater.

After local sudo installation, verify the normal-mode native check and one real
wired EAP-TLS connection before moving the pilot to wireless.
