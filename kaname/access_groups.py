"""AuthWire-owned access groups; never writes Active Directory membership.

The existing revisioned runtime_settings table stores definitions and one
primary-keyed membership per domain/object GUID. All membership, policy guard,
revision and audit updates commit together. The RADIUS provider is read-only.
"""
import json
import unicodedata
import uuid
from datetime import datetime, timedelta, timezone

from .directory import validate_catalog
from .models import ValidationError, dns_name, enum, integer, keys, text, validate_policies
from .store import ConflictError

DEFINITIONS = 'authwire_access_groups'
MEMBERS = 'authwire-access-member:'
MAX_GROUPS = 256
MAX_MEMBERS = 500
MAX_TOTAL = 10000


class AccessGroupError(ValueError):
    def __init__(self, code, details=None):
        self.code, self.details = code, details or {}
        super().__init__(code)


def group_id(value):
    from .radius import object_id
    return object_id(value)


def member_key(domain, guid):
    return MEMBERS + domain + ':' + guid


def definitions(db):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='runtime_settings'").fetchone():
        return {}
    row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (DEFINITIONS,)).fetchone()
    rows = json.loads(row[0]) if row else []
    if type(rows) is not list or len(rows) > MAX_GROUPS:
        raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
    result = {}
    for item in rows:
        keys(item, {'id', 'name', 'domain'}, {'id', 'name', 'domain'})
        group_id(item['id']); text(item['name'], 80)
        if dns_name(item['domain']) != item['domain'] or item['id'] in result:
            raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
        result[item['id']] = item
    return result


def memberships(db):
    from .radius import account_sid, object_id
    result = {}
    if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='runtime_settings'").fetchone():
        return result
    rows = db.execute("SELECT name,payload FROM runtime_settings WHERE name GLOB 'authwire-access-member:*' LIMIT ?", (MAX_TOTAL+1,)).fetchall()
    if len(rows) > MAX_TOTAL:
        raise AccessGroupError('ACCESS_GROUP_LIMIT')
    for name, payload in rows:
        value = json.loads(payload)
        keys(value, {'domain','guid','sid','kind','group_id'}, {'domain','guid','sid','kind','group_id'})
        dns_name(value['domain']); object_id(value['guid']); account_sid(value['sid'])
        enum(value['kind'], {'user','computer'}); group_id(value['group_id'])
        if name != member_key(value['domain'], value['guid']):
            raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
        result[name] = value
    return result


def catalog_in(db, domain):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='directory_catalog'").fetchone():
        return None
    row = db.execute('SELECT domain,synced_at,payload FROM directory_catalog WHERE id=1').fetchone()
    if not row or row[0] != domain:
        return None
    return {**validate_catalog(json.loads(row[2]), domain), 'synced_at': row[1]}


def require_current_catalog(catalog):
    try:
        at = datetime.fromisoformat(catalog['synced_at'])
        age = datetime.now(timezone.utc) - at
        if at.tzinfo is None or not -timedelta(minutes=5) <= age <= timedelta(minutes=15) or catalog.get('membership_schema') != 1:
            raise ValueError()
    except (TypeError, KeyError, ValueError):
        raise AccessGroupError('ACCESS_GROUP_CATALOG_REFRESH_REQUIRED') from None


def conflict_view(db, catalog=None, *, groups=None, members=None):
    groups = definitions(db) if groups is None else groups
    members = memberships(db) if members is None else members
    accounts = {(x['guid'], kind): x for plural,kind in (('users','user'),('computers','computer'))
                for x in (catalog or {}).get(plural, [])}
    result = {identity: set() for identity in groups}
    for member in members.values():
        group = groups.get(member['group_id'])
        if not group or group['domain'] != member['domain']:
            raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
        account = accounts.get((member['guid'], member['kind']))
        if account and member['domain'] == (catalog or {}).get('domain') and account['sid'] == member['sid']:
            result[member['group_id']].add(member['sid'])
    return result


class AccessGroups:
    def __init__(self, operations):
        self.ops, self.store = operations, operations.store

    def _context(self, db):
        revision, config = db.execute('SELECT revision,config FROM state WHERE id=1').fetchone()
        config = json.loads(config) if config else {}
        return revision, config.get('ad_domain', '')

    def list(self):
        with self.store.connect() as db:
            db.execute('BEGIN')
            revision, domain = self._context(db)
            groups, members = definitions(db), memberships(db)
        items = []
        for group in groups.values():
            if group['domain'] != domain:
                continue
            selected = [m for m in members.values() if m['group_id'] == group['id']]
            items.append({**group, 'member_count':len(selected),
                          'user_count':sum(m['kind']=='user' for m in selected),
                          'computer_count':sum(m['kind']=='computer' for m in selected)})
        return {'revision':revision,'items':sorted(items,key=lambda x:(x['name'].casefold(),x['id']))}

    def targets(self, offset=0, query=''):
        integer(offset,0,10000)
        if type(query) is not str or len(query)>128 or any(ord(c)<32 for c in query):
            raise ValidationError('Invalid group query')
        items=[g for g in self.list()['items'] if query.casefold() in g['name'].casefold()]
        return {'items':[{**g,'sid':'local:'+g['id'],'sam':str(g['member_count'])+' üye','kind':'local_group'} for g in items[offset:offset+100]],
                'total':len(items),'offset':offset,'catalog_available':True}

    def detail(self, identity):
        group_id(identity)
        with self.store.connect() as db:
            db.execute('BEGIN')
            revision, domain = self._context(db)
            group = definitions(db).get(identity)
            if not group or group['domain'] != domain:
                raise AccessGroupError('ACCESS_GROUP_NOT_FOUND')
            members = [m for m in memberships(db).values() if m['group_id'] == identity]
            catalog = catalog_in(db, domain)
        accounts = {(a['guid'],kind):a for plural,kind in (('users','user'),('computers','computer'))
                    for a in (catalog or {}).get(plural, [])}
        items=[]
        for member in members:
            account=accounts.get((member['guid'],member['kind']))
            available=bool(account and account['sid']==member['sid'])
            name=(account['name'].removesuffix('$') if member['kind']=='computer' else account['name']) if available else member['guid']
            items.append({**member,'name':name,'sam':account['sam'] if available else '',
                          'available':available,'enabled':account['enabled'] if available else False})
        return {'revision':revision,'group':group,'members':sorted(items,key=lambda x:(x['name'].casefold(),x['guid']))}

    def save(self, expected, value):
        keys(value, {'id','name','members'}, {'id','name','members'})
        identity=group_id(value['id']) if value['id'] else str(uuid.uuid4())
        name=text(value['name'],80).strip()
        if not name:
            raise ValidationError('Invalid group name')
        refs=value['members']
        if type(refs) is not list or len(refs)>MAX_MEMBERS:
            raise AccessGroupError('ACCESS_GROUP_LIMIT')
        for ref in refs:
            keys(ref,{'guid','kind'},{'guid','kind'});group_id(ref['guid']);enum(ref['kind'],{'user','computer'})
        if len({r['guid'] for r in refs})!=len(refs):
            raise ValidationError('Duplicate group member')
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');revision=self.ops._revision(db,expected)
            _,domain=self._context(db)
            if not domain:raise ValidationError('CONFIG_REQUIRED')
            groups,members=definitions(db),memberships(db)
            old=groups.get(identity)
            if value['id'] and (not old or old['domain']!=domain):raise AccessGroupError('ACCESS_GROUP_NOT_FOUND')
            normal=lambda s:unicodedata.normalize('NFKC',s).casefold()
            if any(g['id']!=identity and g['domain']==domain and normal(g['name'])==normal(name) for g in groups.values()):
                raise AccessGroupError('ACCESS_GROUP_NAME_EXISTS')
            if not old and len(groups)>=MAX_GROUPS:raise AccessGroupError('ACCESS_GROUP_LIMIT')
            catalog=catalog_in(db,domain)
            accounts={(a['guid'],kind):a for plural,kind in (('users','user'),('computers','computer')) for a in (catalog or {}).get(plural,[])}
            selected={}
            for ref in refs:
                key=member_key(domain,ref['guid']);existing=members.get(key)
                if existing and existing['group_id']!=identity:
                    other=groups.get(existing['group_id'])
                    if not other:raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
                    account=accounts.get((ref['guid'],ref['kind'])) or {}
                    raise AccessGroupError('ACCESS_GROUP_MEMBER_EXISTS',{'group_name':other['name'],'member_name':account.get('name',ref['guid'])})
                account=accounts.get((ref['guid'],ref['kind']))
                if existing:
                    if existing['kind']!=ref['kind'] or account and account['sid']!=existing['sid']:
                        raise AccessGroupError('ACCESS_GROUP_IDENTITY_CHANGED')
                    selected[key]=existing
                else:
                    require_current_catalog(catalog)
                    if not account:raise AccessGroupError('ACCESS_GROUP_MEMBER_NOT_FOUND')
                    selected[key]={'domain':domain,'guid':ref['guid'],'sid':account['sid'],'kind':ref['kind'],'group_id':identity}
            removed={k for k,m in members.items() if m['group_id']==identity and k not in selected}
            candidate={k:m for k,m in members.items() if k not in removed};candidate.update(selected)
            if len(candidate)>MAX_TOTAL:raise AccessGroupError('ACCESS_GROUP_LIMIT')
            groups[identity]={'id':identity,'name':name,'domain':domain}
            policies=validate_policies(json.loads(db.execute('SELECT policies FROM state WHERE id=1').fetchone()[0]))
            from .policy import policy_conflicts,PolicyConflictError
            conflicts=policy_conflicts(policies,catalog,conflict_view(db,catalog,groups=groups,members=candidate))
            if conflicts:raise PolicyConflictError(conflicts)
            for key in removed:db.execute('DELETE FROM runtime_settings WHERE name=?',(key,))
            for key,member in selected.items():
                if key not in members:db.execute('INSERT INTO runtime_settings VALUES (?,?)',(key,json.dumps(member)))
            self.ops._save(db,DEFINITIONS,list(groups.values()))
            self.ops._audit(db,'access_group_saved:'+identity,revision)
        return self.detail(identity)

    def delete(self, expected, identity):
        group_id(identity)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');revision=self.ops._revision(db,expected)
            _,domain=self._context(db);groups=definitions(db)
            if identity not in groups or groups[identity]['domain']!=domain:raise AccessGroupError('ACCESS_GROUP_NOT_FOUND')
            policies=json.loads(db.execute('SELECT policies FROM state WHERE id=1').fetchone()[0])
            if any(identity in p['conditions'].get('local_group_ids',[]) for p in policies):
                raise AccessGroupError('ACCESS_GROUP_IN_USE')
            for key,member in memberships(db).items():
                if member['group_id']==identity:db.execute('DELETE FROM runtime_settings WHERE name=?',(key,))
            del groups[identity];self.ops._save(db,DEFINITIONS,list(groups.values()))
            self.ops._audit(db,'access_group_deleted:'+identity,revision)
        return self.list()

    def authorization(self, account):
        from .radius import CurrentDirectoryAccount
        if type(account) is not CurrentDirectoryAccount:raise AccessGroupError('ACCESS_GROUP_IDENTITY_INVALID')
        with self.store.connect() as db:
            db.execute('BEGIN');_,domain=self._context(db)
            policies=validate_policies(json.loads(db.execute('SELECT policies FROM state WHERE id=1').fetchone()[0]))
            refs={g for p in policies for g in p['conditions'].get('local_group_ids',[])}
            if not refs:return policies,frozenset()
            groups=definitions(db)
            if account.domain!=domain or any(g not in groups or groups[g]['domain']!=domain for g in refs):
                raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
            row=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(member_key(domain,account.object_guid),)).fetchone()
            selected=set()
            if row:
                member=json.loads(row[0])
                if (member.get('domain'),member.get('guid'),member.get('sid'),member.get('kind'))==(domain,account.object_guid,account.sid,account.kind):
                    if member.get('group_id') not in groups:raise AccessGroupError('ACCESS_GROUP_STORE_INVALID')
                    selected.add(member['group_id'])
        return policies,frozenset(selected)
