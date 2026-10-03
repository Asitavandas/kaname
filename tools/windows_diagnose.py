"""Read-only KANAME installation facts; never emit credentials or config values."""
import argparse
import ast
import hashlib
import importlib.metadata
import json
import re
import sqlite3
import sys
from dataclasses import asdict
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, build_opener, ProxyHandler, HTTPRedirectHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def get_json(path, token=None, payload=None, port=8765):
    # Never send the token through a proxy or follow redirects off loopback.
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    data = None
    if payload is not None:
        data = json.dumps(payload).encode('utf-8')
        headers.update({'Origin': f'http://127.0.0.1:{port}', 'Content-Type': 'application/json'})
    request = Request(f'http://127.0.0.1:{port}{path}', headers=headers, data=data)
    try:
        response = build_opener(ProxyHandler({}), NoRedirect()).open(request, timeout=4)
    except HTTPError as exc:
        response = exc
    except (URLError, OSError, ValueError):
        return None, None
    with response:
        status = response.code
        raw = response.read(262145)
    if len(raw) > 262144:
        return status, None
    try:
        return status, json.loads(raw)
    except (ValueError, UnicodeError):
        return status, None


def source_version(root):
    try:
        module = ast.parse((root / 'kaname' / '__init__.py').read_text(encoding='utf-8'))
        for node in module.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in node.targets):
                value = ast.literal_eval(node.value)
                if isinstance(value, str) and re.fullmatch(r'\d+\.\d+\.\d+(?:-dev\.\d+)?', value):
                    return value
    except (OSError, ValueError, SyntaxError):
        pass
    return None


def read_token(root):
    path = root / 'kaname-state' / 'access-token'
    if path.is_symlink():
        return None
    try:
        if path.stat().st_size > 256:
            return None
        token = path.read_text(encoding='ascii').strip()
        return token if re.fullmatch('[0-9a-f]{64}', token) else None
    except (OSError, UnicodeError):
        return None


def database_facts(root):
    path = root / 'kaname-state' / 'kaname.sqlite3'
    facts = {'exists': path.is_file(), 'readable': False, 'config_saved': False,
             'policies_count': 0, 'enabled_policies_count': 0, 'ca_initialized': False}
    snapshot = None
    if not facts['exists'] or path.is_symlink():
        return facts, snapshot
    try:
        # mode=ro must not create or migrate a missing/older database.
        connection = sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=3)
        try:
            connection.execute('PRAGMA query_only=ON')
            row = connection.execute('SELECT revision,config,policies FROM state WHERE id=1').fetchone()
            if row is None or type(row[0]) is not int or row[0] < 0:
                return facts, None
            config = json.loads(row[1]) if row[1] else None
            policies = json.loads(row[2])
            # Validation code comes from the reviewed checkout, not local runtime.
            from kaname.models import validate_config, validate_policies
            if config is not None:
                validate_config(config)
            validate_policies(policies)
            facts.update(readable=True, revision=row[0], config_saved=config is not None,
                         policies_count=len(policies), enabled_policies_count=sum(p['enabled'] for p in policies))
            tables = {r[0] for r in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if 'pki_authority' in tables:
                # Read presence only. Do not SELECT key columns or whole rows.
                facts['ca_initialized'] = connection.execute('SELECT 1 FROM pki_authority WHERE id=1').fetchone() is not None
            snapshot = {'revision': row[0], 'config': config, 'policies': policies}
        finally:
            connection.close()
    except (sqlite3.Error, ValueError, TypeError, KeyError, OSError):
        facts['read_error'] = 'DATABASE_OR_SCHEMA_INVALID'
    return facts, snapshot


def simulation_checks(snapshot, token, port):
    from kaname.policy import VerifiedIdentity, evaluate
    policies = snapshot['policies']
    enabled = next((p for p in policies if p['enabled']), None)
    payload = {'authenticated': True, 'directory_available': True, 'account_enabled': True,
               'domain_device': True, 'group_sids': [], 'access_type': 'wired',
               'nas_ip': '192.0.2.2', 'eap_method': 'EAP-TLS'}
    if enabled:
        conditions = enabled['conditions']
        payload.update(group_sids=conditions['group_sids'][:1],
                       access_type=(conditions['access_types'] or ['wired'])[0],
                       nas_ip=(conditions['nas_ips'] or ['192.0.2.2'])[0],
                       eap_method=enabled['constraints']['eap_methods'][0])
    checks = {}
    for name, modifications in [('matching_policy', {}), ('non_domain_device', {'domain_device': False}),
                                ('disabled_account', {'account_enabled': False})]:
        context = {**payload, **modifications}
        identity = VerifiedIdentity(**{**context, 'group_sids': frozenset(context['group_sids'])})
        expected = evaluate(policies, identity)
        status, response = get_json('/api/simulate', token=token, payload=context, port=port)
        # Only our local enum value and comparison result are emitted. Full API
        # responses can contain policy IDs/VLANs and must never reach the log.
        checks[name] = {'expected_reason': expected.reason,
                        'passed': status == 200 and isinstance(response, dict)
                        and response.get('simulation_only') is True and response.get('network_enforced') is False
                        and response.get('decision') == asdict(expected)}
    return checks


def diagnose(root, port=8765):
    root = Path(root)
    report = {'schema_version': 1, 'inspection': 'read-only-with-inert-simulation',
              'root_exists': root.is_dir(), 'python_version': '.'.join(map(str, sys.version_info[:3])),
              'python_312': sys.version_info[:2] == (3, 12),
              'venv_exists': (root / '.venv' / 'Scripts' / 'python.exe').is_file(),
              'using_venv': sys.prefix != sys.base_prefix,
              'source_version': source_version(root), 'secrets_exported': False}
    try:
        version = importlib.metadata.version('cryptography')
        report['cryptography_46_installed'] = version == '46.0.0'
    except importlib.metadata.PackageNotFoundError:
        report['cryptography_46_installed'] = False
    baseline = Path(__file__).with_name('windows_baseline.json')
    release = Path(__file__).with_name('windows_release.json')
    if release.is_file() and json.loads(release.read_text(encoding='utf-8')).get('version') == report['source_version']:
        baseline = release
    manifest = json.loads(baseline.read_text(encoding='utf-8'))
    expected = manifest['files']
    missing, changed = [], []
    for name, digest in expected.items():
        path = root / name
        if not path.is_file() or path.is_symlink():
            missing.append(name)
        else:
            try:
                if path.stat().st_size > 2_000_000 or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                    changed.append(name)
            except OSError:
                changed.append(name)
    report['source_baseline'] = {'version': manifest['version'], 'missing_files': missing, 'changed_files': changed}
    token = read_token(root)
    report['access_token_exists'] = (root / 'kaname-state' / 'access-token').is_file()
    report['access_token_valid'] = token is not None
    report['database'], snapshot = database_facts(root)
    code, health = get_json('/healthz', port=port)
    product = code == 200 and isinstance(health, dict) and health.get('product') == 'KANAME'
    report['panel'] = {'http_status': code, 'kaname_responding': product}
    if product:
        report['panel']['matches_source_version'] = health.get('version') == report['source_version']
        ready_code, ready = get_json('/readyz', port=port)
        report['panel']['expected_development_readiness'] = ready_code == 503 and isinstance(ready, dict) and ready.get('reason') == 'AD_PKI_RADIUS_NOT_CONNECTED'
        if token:
            state_code, state = get_json('/api/state', token=token, port=port)
            authenticated = state_code == 200 and isinstance(state, dict) and state.get('product') == 'KANAME'
            report['panel']['token_accepted'] = authenticated
            report['panel']['state_http_status'] = state_code
            report['panel']['matches_local_state'] = authenticated and snapshot is not None and all(state.get(k) == v for k, v in snapshot.items())
            if authenticated and report['panel']['matches_local_state']:
                report['panel']['simulation_checks'] = simulation_checks(snapshot, token, port)
    report['previous_browser_login'] = 'cannot_determine'
    report['previous_manual_simulation'] = 'cannot_determine'
    report['real_ad_tested'] = False
    report['radius_ovf'] = 'not_implemented_in_this_version'
    return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    # -I ignores the checkout on sys.path. Add reviewed checkout explicitly.
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    try:
        report = diagnose(args.root)
    except Exception:
        # Never print exceptions; their text can contain local paths or input data.
        report = {'schema_version': 1, 'diagnostic_error': 'INSPECTION_FAILED', 'secrets_exported': False}
    output = Path(args.output)
    if output.exists():
        raise SystemExit('Report destination already exists')
    output.write_text(json.dumps(report, ensure_ascii=True, indent=2) + '\n', encoding='utf-8')
    print('KANAME_REPORT_BEGIN')
    print(json.dumps(report, ensure_ascii=True, indent=2))
    print('KANAME_REPORT_END')


if __name__ == '__main__':
    main()
