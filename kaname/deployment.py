"""Versioned Windows distribution preparation. No GPO/network/service writer."""
import hashlib
import io
import json
import uuid
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.x509.oid import ExtendedKeyUsageOID

from .directory import validate_catalog
from .membership import related
from .models import ValidationError, boolean, dns_name, enum, integer, keys, text
from .pki import instant
from .store import ConflictError

SECTION = 'windows_deployment_plans'
FIELDS = {'id','version','name','computer_group_sid','machine_profile_id','user_profile_id',
          'wired','wireless','ssid','auth_mode','server_name'}


class DeploymentError(ValueError):
    def __init__(self, code): self.code=code;super().__init__(code)


def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()


def network_xml(plan, thumbprint, *, wireless=False):
    """Microsoft LAN/WLAN + OneX/EAP-TLS schemas; root and server validation on."""
    ns='http://www.microsoft.com/networking/'
    root=ET.Element('WLANProfile' if wireless else 'LANProfile',xmlns=ns+('WLAN' if wireless else 'LAN')+'/profile/v1')
    def child(parent,name,value=None,**attrs):
        node=ET.SubElement(parent,name,attrs)
        if value is not None:node.text=str(value)
        return node
    if wireless:
        child(root,'name',plan['ssid']);ssid=child(child(root,'SSIDConfig'),'SSID')
        child(ssid,'hex',plan['ssid'].encode().hex().upper());child(ssid,'name',plan['ssid'])
        child(root,'connectionType','ESS');child(root,'connectionMode','auto')
    security=child(child(root,'MSM'),'security')
    if wireless:
        enc=child(security,'authEncryption');child(enc,'authentication','WPA2');child(enc,'encryption','AES');child(enc,'useOneX','true')
    else:
        child(security,'OneXEnforced','false');child(security,'OneXEnabled','true')
    one=child(security,'OneX',xmlns=ns+'OneX/v1');child(one,'authMode',plan['auth_mode'])
    host=child(child(one,'EAPConfig'),'EapHostConfig',xmlns='http://www.microsoft.com/provisioning/EapHostConfig')
    common='http://www.microsoft.com/provisioning/EapCommon';method=child(host,'EapMethod')
    for name,value in [('Type','13'),('VendorId','0'),('VendorType','0'),('AuthorId','0')]:child(method,name,value,xmlns=common)
    base=child(child(host,'Config'),'Eap',xmlns='http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1');child(base,'Type','13')
    tls=child(base,'EapType',xmlns='http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1')
    child(child(child(tls,'CredentialsSource'),'CertificateStore'),'SimpleCertSelection','true')
    validation=child(tls,'ServerValidation');child(validation,'DisableUserPromptForServerValidation','true')
    child(validation,'ServerNames',plan['server_name']);child(validation,'TrustedRootCA',' '.join(thumbprint[i:i+2] for i in range(0,40,2)))
    child(tls,'DifferentUsername','false')
    for name in ('PerformServerValidation','AcceptServerName'):child(tls,name,'true',xmlns='http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2')
    ET.indent(root);return ET.tostring(root,encoding='utf-8',xml_declaration=True)


class Deployment:
    def __init__(self,operations):self.ops=operations;self.store=operations.store

    def _snapshot(self,db):
        revision,config=db.execute('SELECT revision,config FROM state WHERE id=1').fetchone();config=json.loads(config) if config else {}
        tables={x[0] for x in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        row=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()
        state={'revision':revision,'config':config,'plans':json.loads(row[0]) if row else [],'catalog':None,'machine_profiles':[],'user_profiles':[],'authority':None,'revoked_serials':[]}
        if 'directory_catalog' in tables:
            row=db.execute('SELECT domain,synced_at,payload FROM directory_catalog WHERE id=1').fetchone()
            if row and row[0]==config.get('ad_domain'):state['catalog']={**validate_catalog(json.loads(row[2]),row[0]),'synced_at':row[1]}
        for table,key in [('device_profiles','machine_profiles'),('user_enrollment_profiles','user_profiles')]:
            if table in tables:
                state[key]=[dict(zip(('id','version','name','domain','group_sid','validity_days','renew_before_days','enabled'),r)) for r in db.execute('SELECT * FROM '+table+' ORDER BY name,id')]
        if 'pki_authority' in tables:state['authority']=db.execute('SELECT root_cert,issuer_cert FROM pki_authority WHERE id=1').fetchone()
        if 'pki_certificates' in tables:state['revoked_serials']=[r[0] for r in db.execute('SELECT serial FROM pki_certificates WHERE revoked_at IS NOT NULL')]
        return state

    def _read(self):
        with self.store.connect() as db:db.execute('BEGIN');return self._snapshot(db)

    def status(self, *, q='', offset=0):
        if type(q) is not str or len(q)>128:raise ValidationError('Invalid search')
        integer(offset,0,100000);s=self._read();catalog=s['catalog'] or {};allgroups=catalog.get('groups',[])
        groups=[g for g in allgroups if g.get('security_enabled') and q.casefold() in (g['name']+' '+g['sid']).casefold()]
        names={g['sid']:g['name'] for g in allgroups}
        return {'revision':s['revision'],'domain':s['config'].get('ad_domain',''),'server_name':s['config'].get('appliance_fqdn',''),
                'catalog_synced_at':catalog.get('synced_at'),'membership_available':catalog.get('membership_schema')==1,
                'plans':[{**p,'computer_group_name':names.get(p['computer_group_sid'])} for p in s['plans']],
                'groups':[{'sid':g['sid'],'name':g['name']} for g in groups[offset:offset+100]],'offset':offset,'total':len(groups),
                'machine_profiles':s['machine_profiles'],'user_profiles':s['user_profiles'],
                'connector':{'configured':False,'can_apply':False},'runtime_applied':False}

    def _validate(self,value,s):
        keys(value,FIELDS,FIELDS);v=dict(value)
        if type(v['id']) is not str or str(uuid.UUID(v['id']))!=v['id']:raise ValidationError('Invalid plan id')
        integer(v['version'],0,2**31-2);v['name']=text(v['name'],80).strip()
        if not v['name']:raise ValidationError('Empty name')
        for key in ['wired','wireless']:boolean(v[key])
        if not (v['wired'] or v['wireless']):raise DeploymentError('DEPLOYMENT_NETWORK_REQUIRED')
        if type(v['ssid']) is not str or any(ord(c)<32 for c in v['ssid']) or len(v['ssid'].encode())>32:raise ValidationError('Invalid SSID')
        if v['wireless'] and not v['ssid']:raise DeploymentError('DEPLOYMENT_SSID_REQUIRED')
        if not v['wireless'] and v['ssid']:raise ValidationError('SSID without WiFi')
        enum(v['auth_mode'],{'machine','user','machineOrUser'});v['server_name']=dns_name(v['server_name'])
        if not s['config'].get('ad_domain'):raise DeploymentError('DEPLOYMENT_DIRECTORY_REQUIRED')
        group=next((g for g in (s['catalog'] or {}).get('groups',[]) if g['sid']==v['computer_group_sid'] and g.get('security_enabled')),None)
        if group is None:raise DeploymentError('DEPLOYMENT_GROUP_NOT_FOUND')
        for key,source,required in [('machine_profile_id','machine_profiles',v['auth_mode']!='user'),('user_profile_id','user_profiles',v['auth_mode']!='machine')]:
            if type(v[key]) is not str:raise ValidationError('Invalid profile id')
            profile=next((p for p in s[source] if p['id']==v[key] and p['domain']==s['config']['ad_domain']),None)
            if required and profile is None:raise DeploymentError('DEPLOYMENT_PROFILE_REQUIRED')
            if not required and v[key]:raise ValidationError('Unused enrollment profile')
            if key=='machine_profile_id' and profile and profile['group_sid']!=v['computer_group_sid']:raise DeploymentError('DEPLOYMENT_MACHINE_GROUP_MISMATCH')
        return v

    def save(self,value,actor):
        keys(value,{'expected_revision','plan'},{'expected_revision','plan'})
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');revision=self.ops._revision(db,value['expected_revision']);s=self._snapshot(db)
            v=self._validate(value['plan'],s);old=next((p for p in s['plans'] if p['id']==v['id']),None)
            if v['version']!=(old['version'] if old else 0):raise ConflictError('REVISION_CONFLICT')
            v['version']+=1;v['domain']=s['config']['ad_domain']
            v['history']=((old.get('history',[])+[{k:x for k,x in old.items() if k!='history'}])[-5:]) if old else []
            plans=[p for p in s['plans'] if p['id']!=v['id']]+[v]
            if len(plans)>100:raise DeploymentError('DEPLOYMENT_PLAN_LIMIT')
            self.ops._save(db,SECTION,plans);self.ops._audit(db,'windows_deployment_plan_saved:'+v['id'],revision)
        return {'id':v['id'],'version':v['version'],'runtime_applied':False,'gpo_changed':False}

    def _targets(self,s,sid,kind):
        catalog=s['catalog']
        if not catalog or catalog.get('membership_schema')!=1:return {'available':False,'count':None,'enabled':None,'disabled':None,'unresolved':None,'sample':[]}
        group=next((g for g in catalog['groups'] if g['sid']==sid and g.get('security_enabled')),None)
        if group is None:return {'available':False,'count':None,'enabled':None,'disabled':None,'unresolved':None,'sample':[]}
        accounts,stats=related(catalog,'groups',group);items=sorted((a for a in accounts if a['kind']==kind),key=lambda a:a['sid'])
        return {'available':True,'count':len(items),'enabled':sum(bool(a['enabled']) for a in items),'disabled':sum(not a['enabled'] for a in items),
                'unresolved':stats['unresolved_members'],'sample':[{'name':a['name'],'sid':a['sid']} for a in items[:20]]}

    def _trust(self,s,plan):
        try:
            root,issuer=(x509.load_pem_x509_certificate(b) for b in s['authority'])
            leaf_path=self.store.root/'radius/server.pem'
            if leaf_path.is_symlink():raise ValueError()
            leaf=x509.load_pem_x509_certificate(leaf_path.read_bytes());now=instant()
            root.verify_directly_issued_by(root);issuer.verify_directly_issued_by(root);leaf.verify_directly_issued_by(issuer)
            if any(not c.not_valid_before_utc<=now<c.not_valid_after_utc for c in (root,issuer,leaf)):raise ValueError()
            if not root.extensions.get_extension_for_class(x509.BasicConstraints).value.ca:raise ValueError()
            if ExtendedKeyUsageOID.SERVER_AUTH not in leaf.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value:raise ValueError()
            if format(leaf.serial_number,'x') in s['revoked_serials']:raise ValueError()
            if plan['server_name'] not in leaf.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName):raise ValueError()
            return {'ready':True,'root_thumbprint':root.fingerprint(hashes.SHA1()).hex(),'root_sha256':root.fingerprint(hashes.SHA256()).hex(),'radius_leaf_sha256':leaf.fingerprint(hashes.SHA256()).hex()}
        except (OSError,ValueError,TypeError,InvalidSignature,x509.ExtensionNotFound):return {'ready':False}

    def _preview(self,value):
        keys(value,{'expected_revision','id','version'},{'expected_revision','id','version'});integer(value['version'],1,2**31-1)
        integer(value['expected_revision'],0,2**53-2)
        s=self._read()
        if value['expected_revision']!=s['revision']:raise ConflictError('REVISION_CONFLICT')
        p=next((p for p in s['plans'] if p['id']==value['id']),None)
        if not p:raise DeploymentError('DEPLOYMENT_PLAN_NOT_FOUND')
        if p['version']!=value['version']:raise ConflictError('REVISION_CONFLICT')
        blockers=[]
        try:self._validate({k:p[k] for k in FIELDS},s)
        except (ValueError,KeyError):blockers.append('PLAN_DEPENDENCY_CHANGED')
        if p['domain']!=s['config'].get('ad_domain'):blockers.append('DOMAIN_CHANGED')
        computers=self._targets(s,p['computer_group_sid'],'computers');users=None;profiles=[]
        for key,source in [('machine_profile_id','machine_profiles'),('user_profile_id','user_profiles')]:
            if not p[key]:continue
            profile=next((x for x in s[source] if x['id']==p[key]),None)
            if profile:profiles.append(profile)
            if profile is None or not profile['enabled']:blockers.append('ENROLLMENT_PROFILE_NOT_ENABLED')
            if key=='user_profile_id' and profile:users=self._targets(s,profile['group_sid'],'users')
        for target in [computers]+([users] if users else []):
            if not target['available']:blockers.append('MEMBERSHIP_UNAVAILABLE')
            elif not target['enabled']:blockers.append('NO_ENABLED_TARGETS')
            if target['unresolved']:blockers.append('UNRESOLVED_MEMBERS')
        trust=self._trust(s,p)
        if not trust['ready']:blockers.append('RADIUS_SERVER_TRUST_NOT_READY')
        token=digest({'plan':p,'profiles':profiles,'catalog':s['catalog'],'config':s['config'],'trust':trust,'revision':s['revision']})
        result={'id':p['id'],'version':p['version'],'revision':s['revision'],'domain':p['domain'],'plan':p,'preview_hash':token,'enrollment_profiles':profiles,
                'computer_targets':computers,'user_targets':users,'catalog_synced_at':(s['catalog'] or {}).get('synced_at'),
                'trust':trust,'artifact_blockers':sorted(set(blockers)),'can_export_profiles':not blockers,
                'can_apply':False,'apply_blockers':['WINDOWS_CONNECTOR_NOT_CONFIGURED'],
                'runtime_applied':False,'gpo_changed':False,'target_basis':'cached_AD_membership_not_endpoint_installation',
                'required_steps':['restricted_windows_connector','signed_client_and_network_assets','GPO_scope_preview','pilot_endpoint_acceptance']}
        return result,s

    def preview(self,value):return self._preview(value)[0]

    def package(self,value):
        keys(value,{'expected_revision','id','version','preview_hash'},{'expected_revision','id','version','preview_hash'})
        preview,s=self._preview({k:v for k,v in value.items() if k!='preview_hash'})
        if type(value['preview_hash']) is not str or value['preview_hash']!=preview['preview_hash']:raise DeploymentError('DEPLOYMENT_PREVIEW_STALE')
        if not preview['can_export_profiles']:raise DeploymentError('DEPLOYMENT_ARTIFACT_NOT_READY')
        p=preview['plan'];files={'root-ca.pem':s['authority'][0],'issuer-ca.pem':s['authority'][1],
            'plan.json':(json.dumps(preview,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode()}
        if p['wired']:files['Wired-EAP-TLS.xml']=network_xml(p,preview['trust']['root_thumbprint'])
        if p['wireless']:files['WiFi-EAP-TLS.xml']=network_xml(p,preview['trust']['root_thumbprint'],wireless=True)
        files['README.txt']=('AuthWire versioned network profile preparation\r\n'
            'This archive does not install a client, enroll a certificate, or create/link/apply a GPO.\r\n'
            'The future restricted Windows connector must verify current AD scope, enrollment readiness,\r\n'
            'trusted enterprise Authenticode signatures, package hashes and rollback before applying.\r\n'
            'Computer targets and user certificate targets are separate; a user does not imply a computer.\r\n'
            'Targets are a cached directory preview, not confirmed endpoint installation.\r\n'
            'Existing credentials, certificate private keys, GPOs, policies and services were not changed.\r\n').encode()
        files['manifest.json']=(json.dumps({'format':1,'plan_id':p['id'],'version':p['version'],'preview_hash':preview['preview_hash'],
            'files':{n:hashlib.sha256(b).hexdigest() for n,b in sorted(files.items())}},sort_keys=True,indent=2)+'\n').encode()
        output=io.BytesIO()
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
            for name,b in sorted(files.items()):
                info=zipfile.ZipInfo(name,date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;archive.writestr(info,b)
        return output.getvalue()
