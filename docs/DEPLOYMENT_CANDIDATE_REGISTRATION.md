# Bootstrap candidate receipt registration

The first local candidate was prepared and signed on DC01 independently of the
installed Connector worker. This intermediate interface records that **operator
report**, with an immutable plan/binding/dependency snapshot, so the next typed
worker integration has a specific candidate to verify. It is not a substitute
for that integration or the final automated workflow.

In Certificates / Central deployment, **Signed deployment candidates** accepts
the complete JSON output of the reviewed `WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY`
Prepare wrapper. Preview shows the plan version, GPO and manifest hash. Record
requires both current `certificates.authority` and `system.connectors` write
privileges, an interactive HTTPS panel session, CSRF and origin validation. The
principal is re-read under the same administrator transaction before saving.
Read requires both resources. The maintenance bearer cannot register a receipt.

The original text is parsed again server-side to reject duplicate JSON keys.
Only bounded typed successful Prepare reports with false AD/GPO/endpoint/service/
trust/key mutation and execution flags are accepted. Paths are never opened,
returned, retained or executed. Computer identity is compared to the current
paired Connector host; plan/profile/target/trust readiness is checked against a
current transactional local snapshot. A pasted signature status is never trusted
as an authenticated worker attestation: `connector_verified=false`,
`can_apply=false` and **Connector verification pending** remain unconditional.

The record stores only identifiers, digest pins, actor/time and binding/dependency
hashes. Actual plan, profile, membership, config, trust or binding changes mark it
outdated. A directory timestamp refresh alone does not. Up to 32 historical
records are retained; IDs and duplicate responses cannot be replayed into another
actor or pairing. A lost record response is reconciled only by GET, never an
automatic re-submission. The UI clears private drafts on session reset.

API: GET `/api/deployment/candidates`; POST `/preview` and `/record` below that
path. There is no apply/execute/peer-result endpoint here and no dispatch to the
old probe-only worker. This is a bootstrap step, not a permanent requirement to
paste output in the final automated product. The next phase must obtain its own
signed peer evidence, recheck the full current plan/owned GPO scope and native
signature/content before allowing any separate links-free staging operation.
