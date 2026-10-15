# Panel reliability follow-up, 15 October 2026

The operator's screenshots show a STORE_UNAVAILABLE toast on Certificates
and a credential form during reload. The previous code suppressed SQLite
error codes, so the precise historical storage failure is unknown. No
historical database corruption, disk or certificate failure is inferred.

Initial HTML now hides the credential form while the existing HttpOnly cookie
is checked. A neutral loading state remains visible. An actual401 restores
the login form; a connection or data failure offers recovery without replaying
the password. Passwords and session cookies are not persisted in browser storage.

New panel logins have an absolute12-hour expiry and a2-hour idle window.
Existing absolute expires timestamps are retained through upgrades; a new
login receives the new absolute limit. Background requests count as session
activity as before. Activity timestamps are written at most once a minute,
while account enabled/version/permissions and session expiry are read on every
request. This avoids converting parallel dashboard reads into SQLite writers.
The effective idle cutoff can be up to one touch interval earlier.

SQLite BUSY/LOCKED (including extended codes) returns STORE_BUSY. Other SQLite
failures retain STORE_UNAVAILABLE. Logs contain only the fixed operation area,
GET/POST, numeric SQLite code and whether it is transient. No SQL, query string,
exception text, credentials or row data are logged. These diagnostics allow the
actual failure to be identified if it recurs.

The browser retries only GET requests explicitly receiving503/STORE_BUSY,
at most twice after200ms and600ms and within the original request deadline.
It does not retry general503, network errors, passwords, POSTs, issuance,
policy writes or service actions. A writer may have committed before a response
is lost; blindly repeating it would be unsafe.

Focused regression coverage includes an actual reserved SQLite writer while
reading an active session, idle and absolute expiry, revocation/permissions,
safe error classification, delayed F5 session validation, bounded GET recovery,
and exactly one POST after a busy response. Full browser/installer/native gates
remain required. Deployment must preserve native RADIUS PID/module/unit,
policies, trust/key material, database control state and signed Windows source.

The user's VV06 tests are deferred until Monday morning19 October2026.
User-authentication remains on the roadmap; do not close pending selected-leaf
and delayed predecessor cleanup checks without new evidence.
