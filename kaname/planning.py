"""Panel preparation only. No network IO and no runtime policy activation."""
import uuid

from .directory import validate_search_base
from .models import ValidationError, address, enum, integer, keys, text


def optional_text(value, maximum=256):
    if value == '':
        return ''
    return text(value, maximum)


def object_id(value, *, new=False):
    if new and value == '':
        return str(uuid.uuid4())
    if type(value) is not str or str(uuid.UUID(value)) != value:
        raise ValidationError('Invalid object identity')
    return value


class Planning:
    def __init__(self, operations):
        self.ops = operations
        self.store = operations.store

    def _list(self, section):
        # Read data and the global lease from the same SQLite snapshot.
        import json
        with self.store.connect() as db:
            db.execute('BEGIN')
            revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
            row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (section,)).fetchone()
        return {'revision': revision, 'items': json.loads(row[0]) if row else [],
                'runtime_applied': False, 'connection_enabled': False}

    def _write(self, section, expected, item=None, delete_id=None):
        import json
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            revision = self.ops._revision(db, expected)
            row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (section,)).fetchone()
            items = json.loads(row[0]) if row else []
            target = delete_id or item['id']
            if delete_id and not any(x['id'] == target for x in items):
                raise ValidationError('PLANNING_ITEM_NOT_FOUND')
            items = [x for x in items if x['id'] != target]
            if item is not None:
                items.append(item)
            if len(items) > 256:
                raise ValidationError('Planning limit exceeded')
            if section == 'network_devices' and len({x['ip'] for x in items if x['ip']}) != len([x for x in items if x['ip']]):
                raise ValidationError('DEVICE_IP_EXISTS')
            self.ops._save(db, section, items)
            self.ops._audit(db, section + ('_deleted' if delete_id else '_saved'), revision)
        return self._list(section)

    def devices(self):
        return self._list('network_devices')

    def save_device(self, expected, value):
        fields = {'id', 'name', 'vendor', 'model', 'ip', 'device_type', 'connection_type', 'management_mode', 'location', 'notes'}
        keys(value, fields, fields)
        mode = enum(value['management_mode'], {'manual', 'read_only', 'managed', 'import'})
        connection = enum(value['connection_type'], {'direct', 'cloud', 'none'})
        if mode in {'manual', 'import'} and connection != 'none' or mode in {'read_only', 'managed'} and connection == 'none':
            raise ValidationError('DEVICE_MODE_CONNECTION_INVALID')
        ip = address(value['ip']) if value['ip'] else ''
        if connection == 'direct' and not ip:
            raise ValidationError('Direct device needs an IP')
        item = {'id': object_id(value['id'], new=True), 'name': text(value['name']),
                'vendor': text(value['vendor']), 'model': optional_text(value['model'], 128), 'ip': ip,
                'device_type': enum(value['device_type'], {'switch', 'ap', 'controller'}),
                'connection_type': connection, 'management_mode': mode,
                'location': optional_text(value['location'], 128), 'notes': optional_text(value['notes'], 512),
                'status': 'inventory_only'}
        return self._write('network_devices', expected, item)

    def delete_device(self, expected, value):
        return self._write('network_devices', expected, delete_id=object_id(value))

    def drafts(self):
        result = self._list('policy_drafts')
        domain = (self.store.snapshot()['config'] or {}).get('ad_domain', '')
        for item in result['items']:
            item['domain_matches'] = item['domain'] == domain
        return result

    def save_draft(self, expected, value):
        fields = {'id', 'name', 'selector_type', 'target_ids', 'ou_dn', 'action', 'vlan', 'access_types'}
        keys(value, fields, fields)
        config = self.store.snapshot()['config'] or {}
        domain = config.get('ad_domain')
        if not domain:
            raise ValidationError('CONFIG_REQUIRED')
        kind = enum(value['selector_type'], {'user', 'computer', 'group', 'ou', 'everyone'})
        ids = value['target_ids']
        if type(ids) is not list or len(ids) > 256 or len(set(object_id(x) for x in ids)) != len(ids):
            raise ValidationError('Invalid target list')
        targets = []
        if kind in {'user', 'computer', 'group'}:
            catalog = self.store.directory_catalog()
            if not catalog or not ids:
                raise ValidationError('DRAFT_TARGET_REQUIRED')
            objects = {x['guid']: x for x in catalog[{'user': 'users', 'computer': 'computers', 'group': 'groups'}[kind]]}
            for guid in ids:
                obj = objects.get(guid)
                if not obj or kind == 'group' and not obj.get('security_enabled', True):
                    raise ValidationError('CATALOG_OBJECT_NOT_FOUND')
                targets.append({k: obj[k] for k in ('guid', 'sid', 'name', 'sam')})
        elif ids:
            raise ValidationError('Unexpected targets')
        ou = validate_search_base(value['ou_dn'], domain) if kind == 'ou' else ''
        if kind == 'ou' and not ou.upper().startswith('OU='):
            raise ValidationError('AD_SCOPE_INVALID')
        if kind != 'ou' and value['ou_dn'] != '':
            raise ValidationError('Unexpected OU')
        action = enum(value['action'], {'allow', 'deny'})
        vlan = value['vlan']
        if action == 'deny' and vlan is not None:
            raise ValidationError('Deny cannot assign VLAN')
        if vlan is not None:
            integer(vlan, 1, 4094)
            if vlan not in {v['id'] for v in self.ops.network()['vlans']}:
                raise ValidationError('VLAN_NOT_DEFINED')
        access = value['access_types']
        if type(access) is not list or not access or len(access) > 2 or len(set(access)) != len(access):
            raise ValidationError('Invalid access types')
        for x in access:
            enum(x, {'wired', 'wireless'})
        item = {'id': object_id(value['id'], new=True), 'name': text(value['name']),
                'domain': domain, 'selector_type': kind, 'target_ids': ids, 'targets': targets,
                'ou_dn': ou, 'action': action, 'vlan': vlan, 'access_types': access,
                'status': 'draft', 'runtime_applied': False}
        self._write('policy_drafts', expected, item)
        return self.drafts()

    def delete_draft(self, expected, value):
        self._write('policy_drafts', expected, delete_id=object_id(value))
        return self.drafts()

    def targets(self, kind, offset=0, query=''):
        enum(kind, {'user', 'computer', 'group'})
        return self.store.directory_page({'user': 'users', 'computer': 'computers', 'group': 'groups'}[kind],
                                         offset, query=query, security_only=kind == 'group')
