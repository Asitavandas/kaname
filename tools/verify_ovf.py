"""Verify a local OVF package's references, VM sections and SHA256 manifest.

This does not assert that a VMDK boots, validate the entire OVF XSD,
verify a digital signature, or establish hypervisor compatibility.
"""
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

OVF = 'http://schemas.dmtf.org/ovf/envelope/1'
RASD = 'http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData'


class PackageError(ValueError):
    pass


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def local_file(parent, name):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', name) or name in {'.', '..'}:
        raise PackageError('Package references must be safe local filenames')
    path = parent / name
    if path.is_symlink() or not path.is_file():
        raise PackageError('Referenced file is missing or is a symbolic link')
    return path


def verify(path):
    path = Path(path).absolute()
    if path.suffix.lower() != '.ovf' or path.is_symlink() or not path.is_file():
        raise PackageError('A regular local OVF descriptor is required')
    if path.stat().st_size > 2 * 1024 * 1024:
        raise PackageError('OVF descriptor exceeds size limit')
    try:
        data = path.read_text('utf-8-sig')
    except UnicodeError as exc:
        raise PackageError('UTF-8 XML is required') from exc
    if '<!DOCTYPE' in data.upper() or '<!ENTITY' in data.upper():
        raise PackageError('XML entity declarations are not allowed')
    try:
        root = ET.fromstring(data)
    except ET.ParseError as exc:
        raise PackageError('Invalid OVF XML') from exc
    if root.tag != f'{{{OVF}}}Envelope':
        raise PackageError('OVF namespace or envelope is invalid')
    systems = root.findall(f'{{{OVF}}}VirtualSystem')
    if len(systems) != 1:
        raise PackageError('KANAME requires exactly one virtual system')
    files = {}
    expected = {path.name}
    for ref in root.findall(f'{{{OVF}}}References/{{{OVF}}}File'):
        file_id = ref.get(f'{{{OVF}}}id')
        href = ref.get(f'{{{OVF}}}href', '')
        if not file_id or file_id in files or href in expected:
            raise PackageError('Duplicate or missing file reference')
        target = local_file(path.parent, href)
        if target.suffix.lower() != '.vmdk':
            raise PackageError('Only detached VMDK disks may be referenced')
        if target.stat().st_size < 512:
            raise PackageError('Disk file is too small')
        with target.open('rb') as disk:
            if disk.read(4) != b'KDMV':
                raise PackageError('Expected sparse or stream-optimized VMDK header')
        size = ref.get(f'{{{OVF}}}size')
        if size is not None:
            try:
                if int(size) != target.stat().st_size:
                    raise PackageError('Disk reference size mismatch')
            except ValueError as exc:
                raise PackageError('Invalid reference size') from exc
        files[file_id] = href
        expected.add(href)
    disks = root.findall(f'{{{OVF}}}DiskSection/{{{OVF}}}Disk')
    if not disks or not files:
        raise PackageError('A disk and disk reference are required')
    disk_ids = set()
    used_files = set()
    for disk in disks:
        did = disk.get(f'{{{OVF}}}diskId')
        file_ref = disk.get(f'{{{OVF}}}fileRef')
        if not did or did in disk_ids or file_ref not in files:
            raise PackageError('Disk section references are invalid')
        try:
            if int(disk.get(f'{{{OVF}}}capacity', '0')) <= 0:
                raise PackageError('Disk capacity must be positive')
        except ValueError as exc:
            raise PackageError('Invalid disk capacity') from exc
        disk_ids.add(did)
        used_files.add(file_ref)
    if used_files != set(files):
        raise PackageError('Unreferenced disk file')
    resource_types = []
    attached = set()
    for item in systems[0].findall(f'{{{OVF}}}VirtualHardwareSection/{{{OVF}}}Item'):
        kind = item.findtext(f'{{{RASD}}}ResourceType')
        resource_types.append(kind)
        if kind in {'3', '4'}:
            try:
                quantity = int(item.findtext(f'{{{RASD}}}VirtualQuantity', '0'))
                if quantity <= 0:
                    raise PackageError('CPU and RAM quantities must be positive')
            except ValueError as exc:
                raise PackageError('Invalid CPU or RAM quantity') from exc
        if kind == '17':
            host = item.findtext(f'{{{RASD}}}HostResource', '')
            if not host.startswith('ovf:/disk/') or host[len('ovf:/disk/'):] not in disk_ids:
                raise PackageError('Attached disk is not declared')
            attached.add(host[len('ovf:/disk/'):])
    if not {'3', '4', '17', '10'} <= set(resource_types) or attached != disk_ids:
        raise PackageError('CPU memory NIC and attached disk are required')
    if resource_types.count('10') != 1:
        raise PackageError('Initial KANAME contract requires exactly one NIC')
    manifest = local_file(path.parent, path.stem + '.mf')
    if manifest.stat().st_size > 65536:
        raise PackageError('Manifest exceeds size limit')
    entries = {}
    for line in manifest.read_text('ascii').splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'SHA256\(([A-Za-z0-9][A-Za-z0-9_.-]*)\)\s*=\s*([0-9a-fA-F]{64})', line.strip())
        if not match or match.group(1) in entries:
            raise PackageError('Only unique SHA256 manifest entries are allowed')
        name, digest = match.groups()
        entries[name] = digest.lower()
    if set(entries) != expected:
        raise PackageError('Manifest must cover descriptor and every disk exactly')
    for name, digest in entries.items():
        if sha256(local_file(path.parent, name)) != digest:
            raise PackageError('Package integrity mismatch')
    return {'package_integrity_verified': True, 'virtual_systems': 1, 'files': sorted(expected),
            'boot_verified': False, 'hypervisor_import_verified': False,
            'signature_verified': False, 'release_ready': False}


def main():
    parser = argparse.ArgumentParser(description='KANAME OVF integrity check')
    parser.add_argument('descriptor')
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.descriptor), indent=2))
    except (PackageError, OSError, UnicodeError) as exc:
        parser.exit(1, f'OVF verification failed: {exc}\n')


if __name__ == '__main__':
    main()
