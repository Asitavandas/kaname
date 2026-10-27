"""Readonly machine-pilot asset composition; not a signed/executable deployment.

No service constructors, private-key/vault reads, schema writes or GPO calls.
The caller supplies an explicit query-only SQLite snapshot and pinned old network ZIP.
"""
import hashlib
import io
import json
from pathlib import Path
import re
from types import SimpleNamespace
from urllib.parse import urlsplit
import zipfile

from cryptography import x509
from cryptography.hazmat.primitives import hashes

from .deployment import network_xml
from .device_enrollment import DeviceEnrollment
from .models import strict_json
from .pki import instant


class BundleError(ValueError):
    pass


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, code):
    if not condition:
        raise BundleError(code)


def read_zip(raw):
    require(type(raw) is bytes and 1 <= len(raw) <= 1048576, 'BUNDLE_ZIP_LIMIT')
    result = {}; total = 0
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        require(1 <= len(archive.infolist()) <= 16, 'BUNDLE_FILE_LIMIT')
        for entry in archive.infolist():
            name = entry.filename
            require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]{0,79}', name) and
                    name.casefold() not in {n.casefold() for n in result} and
                    not entry.is_dir() and not entry.flag_bits & 1 and
                    (entry.external_attr >> 16) & 0o170000 != 0o120000 and
                    entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), 'BUNDLE_ENTRY_REJECTED')
            total += entry.file_size
            require(0 <= entry.file_size <= 262144 and total <= 1048576, 'BUNDLE_CONTENT_LIMIT')
            with archive.open(entry) as stream:
                value = stream.read(262145)
            require(len(value) == entry.file_size, 'BUNDLE_CONTENT_LIMIT')
            result[name] = value
    return result


def snapshot_assets(db, network_bytes, *, network_sha256, plan_id, plan_version,
                    tls_pem, tls_sha256, hostname, port):
    """Return bytes from one caller-owned read transaction; never commit or write.

    The original network candidate remains unchanged. Current public DB values
    must match its saved plan/profiles/CA. Global audit revision changes alone do
    not invalidate those immutable plan dependencies.
    """
    require(db.execute('PRAGMA query_only').fetchone()[0] == 1 and db.in_transaction,
            'BUNDLE_QUERY_ONLY_SNAPSHOT_REQUIRED')
    require(type(network_sha256) is str and re.fullmatch('[a-f0-9]{64}', network_sha256)
            and sha(network_bytes) == network_sha256, 'BUNDLE_NETWORK_HASH_MISMATCH')
    network = read_zip(network_bytes)
    require('plan.json' in network and 'manifest.json' in network, 'BUNDLE_NETWORK_REQUIRED')
    preview = strict_json(network['plan.json']); plan = preview['plan']
    require(plan['id'] == plan_id and type(plan_version) is int and plan['version'] == plan_version,
            'BUNDLE_PLAN_MISMATCH')
    require(plan['auth_mode'] == 'machine' and not plan['user_profile_id'], 'BUNDLE_MACHINE_PILOT_ONLY')
    require(type(plan['wired']) is bool and type(plan['wireless']) is bool and
            (plan['wired'] or plan['wireless']), 'BUNDLE_NETWORK_REQUIRED')
    names = {'root-ca.pem', 'issuer-ca.pem', 'plan.json', 'manifest.json', 'README.txt'}
    names |= {'Wired-EAP-TLS.xml'} if plan['wired'] else set()
    names |= {'WiFi-EAP-TLS.xml'} if plan['wireless'] else set()
    require(set(network) == names, 'BUNDLE_NETWORK_FILE_SET')
    manifest = strict_json(network['manifest.json'])
    require(manifest == {'format': 1, 'plan_id': plan_id, 'version': plan_version,
                        'preview_hash': preview['preview_hash'],
                        'files': {n: sha(b) for n, b in network.items() if n != 'manifest.json'}},
            'BUNDLE_NETWORK_MANIFEST_MISMATCH')
    row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', ('windows_deployment_plans',)).fetchone()
    require(row is not None, 'BUNDLE_PLAN_NOT_FOUND')
    plans = strict_json(row[0]); current = [p for p in plans if p['id'] == plan_id]
    require(len(current) == 1 and current[0] == plan, 'BUNDLE_PLAN_CHANGED')
    config = strict_json(db.execute('SELECT config FROM state WHERE id=1').fetchone()[0])
    require(config['ad_domain'] == plan['domain'] and config['appliance_fqdn'] == hostname,
            'BUNDLE_DOMAIN_OR_HOST_CHANGED')
    fields = ('id','version','name','domain','group_sid','validity_days','renew_before_days','enabled')
    row = db.execute('SELECT * FROM device_profiles WHERE id=?', (plan['machine_profile_id'],)).fetchone()
    require(row is not None, 'BUNDLE_PROFILE_REQUIRED')
    profile = dict(zip(fields, row))
    require(preview['enrollment_profiles'] == [profile] and profile['enabled'] == 1 and
            profile['domain'] == plan['domain'] and profile['group_sid'] == plan['computer_group_sid'],
            'BUNDLE_PROFILE_CHANGED')
    row = db.execute('SELECT root_cert,issuer_cert FROM pki_authority WHERE id=1').fetchone()
    require(row and row[0] == network['root-ca.pem'] and row[1] == network['issuer-ca.pem'], 'BUNDLE_CA_CHANGED')
    root, issuer = [x509.load_pem_x509_certificate(b) for b in row]
    root.verify_directly_issued_by(root); issuer.verify_directly_issued_by(root)
    now = instant()
    require(all(c.not_valid_before_utc <= now < c.not_valid_after_utc and
                c.extensions.get_extension_for_class(x509.BasicConstraints).value.ca
                for c in (root, issuer)), 'BUNDLE_CA_NOT_CURRENT')
    root_sha1 = root.fingerprint(hashes.SHA1()).hex()
    require(preview['trust']['root_thumbprint'] == root_sha1, 'BUNDLE_ROOT_MISMATCH')
    for enabled, filename, wireless in [(plan['wired'],'Wired-EAP-TLS.xml',False),
                                       (plan['wireless'],'WiFi-EAP-TLS.xml',True)]:
        if enabled:
            require(network[filename] == network_xml(plan, root_sha1, wireless=wireless), 'BUNDLE_NETWORK_XML_CHANGED')
    tls = x509.load_pem_x509_certificate(tls_pem)
    require(tls.fingerprint(hashes.SHA256()).hex() == tls_sha256 and
            tls.not_valid_before_utc <= now < tls.not_valid_after_utc and
            hostname in tls.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName),
            'BUNDLE_TLS_MISMATCH')
    require(type(port) is int and 1 <= port <= 65535, 'BUNDLE_PORT_REQUIRED')
    # Reuse the unchanged production public-asset exporter through its two
    # read-only inputs. Do not instantiate enrollment/PKI services on a RO DB.
    context = SimpleNamespace(profile=lambda identity: dict(profile) if identity == profile['id'] else None,
                              pki=SimpleNamespace(public_bundle=lambda: {'root-ca.pem':row[0], 'issuer-ca.pem':row[1]}))
    enrollment_raw = DeviceEnrollment.package(context, profile['id'], hostname=hostname, port=port, tls_pem=tls_pem)
    enrollment = read_zip(enrollment_raw)
    expected = {'AuthWire-Client.ps1','Install-AuthWire.ps1','config.json','root-ca.pem','issuer-ca.pem','README.txt','SHA256SUMS.txt'}
    if tls.issuer == tls.subject:
        expected.add('https-trust.pem')
    require(set(enrollment) == expected, 'BUNDLE_ENROLLMENT_FILE_SET')
    cfg = strict_json(enrollment['config.json'])
    require(cfg == {'url':f'https://{hostname}:{port}', 'spn':'HTTP/'+hostname, 'domain':plan['domain'],
                    'profile_id':profile['id'], 'tls_sha256':tls_sha256}, 'BUNDLE_ENROLLMENT_CONFIG')
    require(urlsplit(cfg['url']).hostname == hostname, 'BUNDLE_ENROLLMENT_CONFIG')
    files = {'network-profiles.zip':network_bytes}
    files.update({'network/'+n:b for n,b in network.items()})
    files.update({'enrollment/'+n:b for n,b in enrollment.items()})
    files['README.txt'] = (
        'AuthWire machine pilot combined asset preparation\r\n'
        'UNSIGNED DRAFT: Windows signature validation and final signed approval are required.\r\n'
        'Nothing was copied to SYSVOL, installed, enrolled or activated.\r\n'
        'The existing enrollment installer does not import Ethernet/Wi-Fi XML.\r\n'
        'A separately reviewed GPO/network application path is still required.\r\n'
        'No shared client certificate, private key, password or code-signing key is included.\r\n'
    ).encode('ascii')
    info = {'format':'AuthWireMachineDeploymentDraftV1','plan_id':plan_id,'plan_version':plan_version,
            'machine_profile_id':profile['id'],'machine_profile_version':profile['version'],
            'network_zip_sha256':network_sha256,'source_preview_sha256':preview['preview_hash'],
            'requires_windows_signing':True,'certificate_service_runtime_tested':False,
            'can_stage':False,'can_apply':False,'runtime_applied':False,'gpo_changed':False,
            'files':{n:sha(b) for n,b in sorted(files.items())}}
    files['bundle-manifest.json'] = (json.dumps(info,sort_keys=True,indent=2)+'\n').encode()
    out = io.BytesIO()
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,data in sorted(files.items()):
            entry=zipfile.ZipInfo(name,(2026,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED
            entry.external_attr=0o100644 << 16;archive.writestr(entry,data)
    return out.getvalue()
