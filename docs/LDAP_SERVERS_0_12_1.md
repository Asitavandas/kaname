# LDAP Servers — 0.12.1

Directory setup is named **LDAP Servers**. The reference form provides Name, LDAP Server, fixed protected LDAP port 389, CN Identifier sAMAccountName, Distinguished Name, Username and Password. Schedule options are under Eşitleme ayarları. The existing single saved AD connection is preserved.

Distinguished Name accepts a unique OU name, a relative DN, or a full DN in the configured domain. Enter multiple scopes on separate lines, at most 16. Commas inside a DN describe hierarchy. An empty value or the domain DN explicitly selects the entire domain. Overlapping scopes are read once.

The Linux reader reads all three object categories strictly in the union of selected subtrees. Accounts do not need to belong to a group to appear. Selected groups do not pull members from outside that union. Outside direct/nested members and unavailable primary groups remain unresolved. Select all required OUs explicitly when cross-OU membership should appear. Missing or ambiguous OU names fail closed; use the full DN to disambiguate. The last successful catalog survives failed or partial reads.

Test connectivity checks only DNS allowlisting and TCP 389. Test user credentials performs the existing Kerberos signed/sealed LDAP bind and verifies the entered scope, without saving form changes, replacing the catalog or changing saved-connection health. A blank password reuses the protected saved secret only for the same server and user. Both endpoints require directory.connection Write and normal CSRF protections, revision checks, a single-operation lock and retry cooldown.

The displayed name and newline scope persist across reloads and restart. Legacy saved configurations without a name receive LDAP Server as a default, preserving encrypted credentials and administrators. RADIUS is not activated. The Windows panel adapter stays unchanged and automatic Windows CI jobs are paused; this update is for the Linux panel only.
