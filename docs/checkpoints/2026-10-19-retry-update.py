"""Pinned signed-launcher retry update; preserve live RADIUS and pilot state."""
from contextlib import contextmanager
from datetime import datetime, timezone
import ast
import hashlib
import http.client
import json
import os
from pathlib import Path
import pwd
import sqlite3
import ssl
import statistics
import subprocess
import time
import uuid
import tempfile
from contextlib import closing

STAGE = Path('/home/kaname-runner/kaname-stage-e2b835def667')
EXPECTED = '35d8f4956827b8f2a3e356cbbbf1f3ecfeb555d28c88adcfd91f7afd92becfcf'
RELEASE = 'e2b835def66769b61ec0b02c804b7dabafb1edc0'
ROOT = Path('/opt/kaname-lab/source')
STATE = Path('/var/lib/kaname-lab')
PHASE = 'preflight'
UPDATER = {}
EVIDENCE = None
ALLOWED = {'kaname/__init__.py', 'kaname/static/index.html', 'kaname/device_client/Install-AuthWire.ps1'}
BASELINE = {'kaname/__init__.py': 'a1647525e850ac75455dbda3c6c6cb5a659612ea434eeea1b2b5875c4ea829f6', 'kaname/__main__.py': 'e01ee55f671609348749b7c045e1cd0cfed825fe172a1fa0435c58e4bd76907a', 'kaname/admin.py': '1ce450a842f099468fdc95ad64f901258219054d08353fdb739700af7cad724e', 'kaname/audit.py': 'fe5bc68873ed722082e26b0d94df8f1c0d42f8e778aef4b14a57df1578491751', 'kaname/device_auth.py': 'b2b7b608f4305bf4555cde83b2a38ecd1269b6979116a3daf2bc9e581928b16d', 'kaname/device_client/AuthWire-Client.ps1': '86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15', 'kaname/device_client/Install-AuthWire.ps1': '4c1b14a1c088b0ac28f63337ff681824da560d6bf9143bf79132720850f2067d', 'kaname/device_enrollment.py': '27df9e22f07859a879d5f0862ae4fb0dfcaebe1af3887fdc4f11f5bcc2d18cc3', 'kaname/directory.py': '8e73ec0e4f4a7837d098f4a1433857b4b29e01ea768e6a69c6b95b347986e8f0', 'kaname/directory_linux.py': '2ce06cdfa2531df4fb5c8b3dca2918036b80e44dd5fc9a12a0c9e8c5d3a076fd', 'kaname/directory_linux_helper.py': '434874a7a060b3850cb4eb6330aacbfc8bd6725c79fb78df293dceea58e83bf7', 'kaname/directory_sync.py': 'e5769d5f79a188f7ebcccefa88073ac2feec91a55b7448291af67a214021220a', 'kaname/directory_windows.ps1': '199bce5da72e3d2277bd27b6a3318f4d0fac1335e3e7d5aeccfda5ae761bd3e3', 'kaname/enrollment.py': '90570901d12047993a8cda63ec34956a4927eb6d1a9f6051d08b53b1f12a4587', 'kaname/membership.py': 'ff8dea55bc79fbc750cb2216afafd069fa86e1fd2408910cbcddce204f5feead', 'kaname/models.py': '7acc7912a324d8a8116ecdb37b4c0c2803936e8beb3650d6a462ad22d1e46f43', 'kaname/operations.py': '5d42b9e9d59ba2b7d47e5ff68c6928205ffa37b1bb3cec41d32f5367a2e84beb', 'kaname/pki.py': '1ccf775e7ad390e40e56ada967cdd387ea96d12fcac2ce6cbf12f420260f28da', 'kaname/planning.py': '9235ff11f3cef34fea918b8ee5237e251f9f60a31a1881a1ecf4cf33bc085814', 'kaname/policy.py': 'e6b3d31c18a79813fba39b0f351fdf487df7df5e7bbc55f82ebe6e4b156f2ae2', 'kaname/radius.py': 'ee73cd5d1ebbf5113ffa5411e9b49ee93e5fb5bf70715ddedbd2964383e793e7', 'kaname/radius_adapter.py': '5b8c123d290009f721785c19ab2c36ec608446b6ed6a08e1b119a3a0a9a97f33', 'kaname/radius_directory.py': '6f8b92c698a1a9ce32b0194798cf34ea5df3d030ea9182b8027f7b076feaee5d', 'kaname/radius_events.py': '563dc2051dae8871dcd655cd23c2796ffd60ca999a0624d023bf2af12e0b1874', 'kaname/radius_observer.py': '52c83f27953d79dfe291683292f45fc0f14b500896440017053dd8804d2c8c30', 'kaname/radius_registry.py': '1f1c14bfedd19f2ce2fe08cbc95c785805d13d873c135fe73f90bcb980b1304c', 'kaname/server.py': '251d9f82653d5b06604f7b50b18651db2e859031be2acb89fb62b6f25a746bc1', 'kaname/services.py': '1a5420b38339589e0debe43f86124ff47f6bbb7471cfecd8560159cc2f8bdeb0', 'kaname/static/access-events.js': '16b3a9c810df582adf37ca2467f2c18e41c2430df70f44213032221b31d065f1', 'kaname/static/app.js': 'fd221ea3269de1f00079d3fcd65df1999e57417fd062c512ae39d46f469fb410', 'kaname/static/audit.js': '7453d6085f52d2f17540b9beb4d984a52e9ae41153c7cbd18383631fac900f6e', 'kaname/static/authwire-logo.png': '5e494fd5af7ae4951ae5bcdd2f59451c56e1fe92638e49d2be0458d539280091', 'kaname/static/device.js': '4d4ced89b9cf7f109c9081c2f5e8bb03e89ffc9812d4bf6cfc84934603da968c', 'kaname/static/index.html': 'f549185368dfbe5351981cb2f82915ec701116841d7e05dfe4561253edb6073c', 'kaname/static/planning.js': 'b063d5b75a649341ac085266f091671e5d1af0c22a199fe2dd37b0cb7950a81c', 'kaname/static/services.js': '760decce82cba11f9b7f3477fdbbd6da9b3c1fa30fdf485b0475a5094d193615', 'kaname/static/styles.css': 'cd9df642f1ef423671bbbc4bd41e67450a304ae105037b384c69d974c2e5e3cb', 'kaname/store.py': 'a7c8564aecb60a9881f366fd4c87e679334ac9ef29a3341952bc556ca26a657f', 'kaname/vault.py': '9272bb391dd5eac66e46bef63417e13987a1f83151a97c4899a8297b6841a0fd', 'pyproject.toml': '011be80d17648c136cabbdf791c0933796f868155ba7b23156e8df450666685c', 'tests/__init__.py': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'tests/helpers.py': '4233f0211a88efa600379ea01592fcb3a51a0f1f2d0fe6c1c317693a6ebbaab5', 'tests/ldap_fixture.py': 'e52929ea4e8a294a1b4d138d10ff7c9598cb360512762f06faf2860bcfe7098d', 'tests/radius_fixture.py': '0a0138421fa38959e479c102ee1a32dfa33a5552c742c37da0baa2a46fa2333c', 'tests/test_admin.py': '21a5d9147c1d4f6f57df64674d56a617d121f8b248ec2c72d826b9d03176d673', 'tests/test_audit.py': 'a021c7da61e454b26b680d12c2076fd2cfe004d0ac24e39effdbc3fadbb1040b', 'tests/test_device_auth.py': '6fc9a298b06adf5d50ba45be81bc601af7bd8fd5b2392a0d44c21344da273841', 'tests/test_device_enrollment.py': '3d83f895702fc22405622104de58bf792cf1758db7762b8d2f633c66d243b2be', 'tests/test_device_http.py': '7fe6d0cc4662450062d1e26a092d4f4eb912c14b7580aa26971e6d69232bdf7a', 'tests/test_directory.py': '6ae80aa1843d66c3465cfeeb57dfd5b64be6bdc00cacdd72ed7a8ff0bb50df0b', 'tests/test_enrollment.py': '09d310a25b40e29a297d4cc61f2ca44da346d4f5f87e1118f3ffc7c4c961d672', 'tests/test_enrollment_http.py': '99bc93d1f3c939673b41b5464a3004697c3c121677d9bcb5e16defc91665f285', 'tests/test_http.py': '7202f1cf45c46b40103a6cebf1d06046859fe7d0bde469a7ee1e866dbf31f9a5', 'tests/test_linux_directory.py': '605fa7f32743e49a9fbbd4713b898481f02d8bc9feff193443cee61b3dfae4b8', 'tests/test_linux_install.py': '0ad196ffb318a762f6ef7c004d675bde2536ce8cc854f48b6d922ecb4feaa73e', 'tests/test_linux_update.py': '383b8bc4dc7da5c52520e2f7603f6c6491fc8ba9a086b33c4dadbd5291ec31ee', 'tests/test_management.py': 'e3efc868afe96cd70ba0cdd57b30a6fdfe7f99735915a033642f821c986af3e5', 'tests/test_membership.py': 'c12840f56a30fcc4801432951477659062b006a85232c8ca5ebabfc1ef3bff93', 'tests/test_offline_restore_check.py': '8154664a8fb24d2b1caec82917aa96c2a19b871ae1e736b69afae5e79c0b0154', 'tests/test_ovf.py': '50a9d7bc9d9904a18b8048f217ddbc44065e36a9137b5bbc3c1e26545e748d10', 'tests/test_pki.py': '338fbb873d989d2f648a8a3dc0843a3b4d0bf9759f25b052dd7686a974c25b90', 'tests/test_pki_cli.py': '6ba4cbee1e94ad019521f6d9c83ff210627bf17fbf100a727137dab2a34db05e', 'tests/test_pki_http.py': 'e4aa1cc56b7138c35789e8ded2e00bc468e6bbb275a66572b0106d11a38d0e92', 'tests/test_planning.py': '1e281eab0ea24d8526a9b33c8222e93ba35f007741537b102c67e92b9a213089', 'tests/test_policy.py': '439ac79cd5a7e2483f5d4d47dc0609c01f51ff93ca8751f01d4a5f14ea823f14', 'tests/test_radius.py': 'f7c083715d2558b8e7516021d9da07764cdef2fc6c4d5b40c349b9d21cc034dd', 'tests/test_radius_crl_install.py': '727ee23fc40795dbead6c6dc4968f177d7dfada54e1cc7d1170e22de982f2b8f', 'tests/test_radius_crl_sync.py': 'bd2392a049e4dccd360577f06377fdf60f07e92aa0df5d5b27ab474ee357f58b', 'tests/test_radius_events.py': '163b956bc730c9d1773c6a3a4c42076b59a03ade976eaf528f4db15cb087a644', 'tests/test_radius_events_deploy.py': '680866bfc284e35dbe5457fb60389c99930460828021cb9f9c8181fda4ed0036', 'tests/test_radius_events_install.py': '18699c2c6e6df22e7ead57486a84cf86741edd1effe1c5babae88f9bda819b24', 'tests/test_radius_live.py': '4bea7038075b62f1db0b80abd74f75579d7fae03363b1b336c89dbfa4ac8b9c3', 'tests/test_radius_module_update.py': '6ced1e3f1ac9d8489a542f9c4915a17fb42ed3620bb5e27de99022e4aa38bd2b', 'tests/test_radius_packets.py': '9a419df7d1f87bcaa5feab9e4bacd30c22e8fadd5e8f9887c7fad6873e9f15e3', 'tests/test_radius_production.py': '1fbbf86654df2b130f9aa7a7b7342a847dd6f86f8afe5b94a3b9d75a1c125aa8', 'tests/test_radius_unit_update.py': '81a1c883849ac5038976a6aa388b15d93afe7ca7c60f46efa12b66471dbe299f', 'tests/test_scheduled_backup.py': '1e5b4ed8b9c82f895d86bd367513e2638b3a1e33be208284dba0caa8a9beb581', 'tests/test_service_control.py': '2f6e08aec74d253929875d56d3d728187e4970eb3869d2afb4971a0398545222', 'tests/test_store.py': '8da8efb6fd5d920cac82e74e6551a6864ad1bb4bda53208333be034bde65b4c4', 'tests/test_windows_diagnose.py': '54b196ab794bc93dc3ea85d0d31584adf0375f5cd6651819ed038b469bc4846c', 'tests/test_windows_update.py': 'd5cf63eca677bfd3ffbdb7b03d7499cbfcd445d89dc71560eadc3bd95454c203', 'tools/AuthWire-GPO-Audit.ps1': '57bd64e51f3f07d1980ad1b517e11622807f9cbeb44c222bb691ea6f964cbb24', 'tools/__init__.py': '7e41a692ddeb7ca616af6038aa8b2d8b14aa1699216b213caaee860937d31403', 'tools/backup_install.py': 'ed18f5c0c3e65aa6d2a6fe8311ddd1fa604b128c724e5854214e986118faf347', 'tools/backup_systemd_check.py': '654c0389375251d42a28be89c472cb8822e606ba7fd44240a8a2b66f1827eb24', 'tools/client_request.py': '86d3d9822451f4239f6316f236b6cfa59ed748c1990ed06ca212b7581a9afedd', 'tools/device_fixture.py': '61d4a7452eaa97dfdadb161527195c0cbb440702c06d28ef0cfeae04ef170c81', 'tools/device_load_smoke.py': '71ec344f9b14c4b7d250fe69591111b5781c5e649dfe92bc50d41c2305e116a1', 'tools/device_startup_windows_check.ps1': 'ef49621d05b84b25093387adf19c4d6e6f82aedbf1a5acbab13c7944c577b696', 'tools/device_windows_smoke.ps1': 'b4a241212f7ece0a940900214b7550f580a5e02debd3ddfdb625ed186d1ab535', 'tools/export_appliance.py': '35ba5228947787ac89cf9f45f1f4961d1bdf1c82cc235568e4c547c48bba54d7', 'tools/gpo_audit_fixture.ps1': '1a1221643b9998c928fb0281c5958570ca462137e9537823e254368fbdcddf50', 'tools/linux_authorization_check.py': 'f719e1716590764df479ebb44a2a0ab02704a68fb3993357d91932fd5fc9a5c0', 'tools/linux_device_setup.py': '98e3f069b1a27755749c903ed7d7bda27737b26a277d1d6228db63cee4918648', 'tools/linux_initialize.py': '525fe5d380829bb3d93f11d374651c98dda58b30022599389043760896c7fbd5', 'tools/linux_install.py': '3623c91616f3e35ae61e7ad5acbc3482ec76071d3a5ba73020f7980f2e783365', 'tools/linux_install_smoke.py': '268b2958e04585e4f7e389a6c6fbbe775601405657a97e137976c81f4bf4fb4b', 'tools/linux_prepare.py': '90da15eb52d658fe35782be00041ec7d0cf6705e3bce9589d145cb04f08cdd76', 'tools/linux_update.py': 'd168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe', 'tools/offline_restore_check.py': 'c9a1cba667eee28e5e6a3579ced0b457b17e1e7193f254b74e6638a87e48f610', 'tools/package_source.py': 'cf217f7259a819603df28ecff9f6cc4c622a64c5fdd653dbf56c69a7fb38b72d', 'tools/radius_crl_install.py': '2b10abf6bbbdb9d4ee5e542d6938ef354ce094e6cf9330bb3da923a61e2e2a8c', 'tools/radius_crl_sync.py': '580da79bc8c18b10f3c4551768954dde9f9470170451ee2fce127c60d73d2559', 'tools/radius_crl_timer_check.py': '38b18baa708a26b740ea0bfeb07cbb7adeed8628a06ffe39aa3115186403b22b', 'tools/radius_events_config.py': 'd587aa0abd803bd2124c3924cfe63da37d07638119feb52fdae76b9640bf66be', 'tools/radius_events_install.py': '7c0b03b0c627f88b2d5b1e2532910e76b91f7318e6114f2198a6522f3627d607', 'tools/radius_events_systemd_check.py': '45d7d3434552d5cab28700a707870701364b86d66351d9a22023ed789e084bbd', 'tools/radius_initialize.py': '8ce73e33fc8b4201bb16cba85978b10122ab7161f33aab796f29c036d470447b', 'tools/radius_install.py': '63045293fc7a4d62d13d69921a2aa4d3e0242dacde9190ac286ec7a8ebcf3233', 'tools/radius_lab.py': 'a9685a597f43ec930d36ad6258a630426ae84442afcac69f5144a5a719c67ea6', 'tools/radius_module_update.py': 'ad5a848ae0d9819e8abe64cb14c420f8799ac67c2ee84609c71b3dcbaac51881', 'tools/radius_native_check.py': '96be8588b8ca30c5ba1c24d37fe0d56bd02f9eb09ae70193a73051c35de79e96', 'tools/radius_prepare.py': 'f9f2d87143365ba701b72446383b536cb5478ddc31e267c6b67f252f9a8a6640', 'tools/radius_runtime.py': '2cdf26595b0f06601b7dd858af102d381a33fb8155458c5189de6a0c03c38738', 'tools/radius_service.py': '7a0caadfb496ac5cc769a6903adc3f0e0f617e443668a6db01b7f37b17199f63', 'tools/radius_unit_systemd_check.py': '51391ca56cce67bdb4458076a241018a019267ae7a0b1af0cc30c55eb19f0fa4', 'tools/radius_unit_update.py': 'c9d4e9daa02d9c42fa7697ce04a9e8caeb6c6190addce3f37daf698e61934526', 'tools/scheduled_backup.py': '06961ebec421158bf7141755355f351e206544a5dc727af89226ffe97ae6f548', 'tools/service_control_broker.py': 'dd84bd794a6a9ce8bdfd348868c9bb6b91573d643831ae26bf2522c3936c65f4', 'tools/service_control_install.py': '08f809038c65b63c983e7c69466b4a357f58d0819966c36e54ab2cde73cb9bc1', 'tools/service_control_systemd_check.py': '6d878746bfd0b37276ebdfa6a20ff74d65b03f377f9d175c4e2b2b2a6b796fd1', 'tools/verify_ovf.py': '10e08fe6f6945d568c1a6a88f8262f3a2879833f829262f8536ba89607c0c12b', 'tools/windows_diagnose.ps1': '257ad0e9d737ea0ad75092e094d7e712bdf3b17a43439977c37efdae3906a553', 'tools/windows_diagnose.py': '3e1c33600cce117b70d14e1c05b64c94194f2e7e8eea55fd7791102468f00253', 'tools/windows_update.py': 'ccdeb93b75f832b6bfc667691b41d322c41733742407c323b0749b9d73230528'}
APPLICATION_DATA = {STATE / 'secret-store.key', STATE / 'radius/server.pem', STATE / 'radius/server-key.pem'}

class GuardError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)

def emit(event, **values): print(json.dumps({'event': event, **values}), flush=True)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

@contextmanager
def file_creation_mask(mask):
    previous = os.umask(mask)
    try: yield
    finally: os.umask(previous)

def trusted(path):
    info = path.lstat()
    if path.is_symlink() or not path.is_file() or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('Root-owned installed file required')
    return path.read_bytes()

def preserved_file(path):
    if path not in APPLICATION_DATA: return trusted(path)
    account = pwd.getpwnam('kaname-lab')
    info = path.lstat()
    # Vault._key requires the service account itself to own this private key.
    # RADIUS material may have been initialized by root or the service account.
    owners = {account.pw_uid} if path == STATE / 'secret-store.key' else {0, account.pw_uid}
    if path.is_symlink() or not path.is_file() or info.st_uid not in owners or info.st_mode & 0o077:
        raise GuardError('APPLICATION_DATA_OWNER_OR_MODE_INVALID')
    return path.read_bytes()

def load_pinned(path, digest):
    data = trusted(path)
    if hashlib.sha256(data).hexdigest() != digest: raise ValueError('Installed helper changed')
    namespace = {'__name__': 'pinned_panel_update_helper', '__file__': str(path)}
    exec(compile(data, str(path), 'exec'), namespace)
    return namespace

def active_pids():
    result = {}
    for unit in ('authwire-radius.service', 'authwire-service-control.service'):
        subprocess.run(['/usr/bin/systemctl', 'is-active', '--quiet', unit], check=True, timeout=10)
        value = subprocess.check_output(['/usr/bin/systemctl', 'show', unit, '--property=MainPID', '--value'], text=True, timeout=10).strip()
        if not value.isdecimal() or int(value) == 0: raise ValueError('Active pilot service required')
        result[unit] = value
    return result

def snapshot(worker):
    units = ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service',
             'authwire-radius-crl-sync.service', 'authwire-radius-crl-sync.timer',
             'authwire-backup.service', 'authwire-backup.timer')
    paths = [Path('/etc/systemd/system') / n for n in units]
    for unit in tuple(paths):
        drop = Path(str(unit) + '.d')
        if drop.exists():
            if drop.is_symlink() or not drop.is_dir(): raise ValueError('Unsafe unit override')
            paths.extend(p for p in sorted(drop.rglob('*')) if not p.is_dir())
    paths += [Path(p) for p in (
        '/etc/tmpfiles.d/authwire-service-control.conf',
        '/opt/authwire-radius/lib/rlm_python3.so', '/opt/authwire-service-control/broker.py',
        '/opt/authwire-backup/scheduled_backup.py', '/opt/authwire-backup/offline_restore_check.py',
        '/opt/authwire-backup/release.json', '/etc/kaname-lab/web.crt', '/etc/kaname-lab/web.key',
        '/var/lib/kaname-lab/secret-store.key', '/var/lib/kaname-lab/radius/server.pem',
        '/var/lib/kaname-lab/radius/server-key.pem',
        '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
        '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1')]
    files = {}
    for p in paths:
        data = preserved_file(p); info = p.stat()
        files[str(p)] = [hashlib.sha256(data).hexdigest(), info.st_mode & 0o777, info.st_uid, info.st_gid]
    timers = {}
    for unit in ('authwire-radius-crl-sync.timer', 'authwire-backup.timer'):
        values = subprocess.check_output(['/usr/bin/systemctl', 'show', unit, '--property=ActiveState,UnitFileState'], text=True, timeout=10).splitlines()
        if set(values) != {'ActiveState=active', 'UnitFileState=enabled'}: raise ValueError('Active enabled timer required')
        timers[unit] = sorted(values)
    return {'files': files, 'pids': active_pids(), 'timers': timers,
            'business_state': {n: worker['db_fingerprint'](STATE / n) for n in ('kaname.sqlite3', 'administrators.sqlite3')}}

def source_check(files):
    if hashlib.sha256(files['kaname/device_client/AuthWire-Client.ps1']).hexdigest() != '86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15': raise GuardError('CLIENT_SOURCE_CHANGED')
    if hashlib.sha256(files['kaname/device_client/Install-AuthWire.ps1']).hexdigest() != 'faec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609': raise GuardError('UNREVIEWED_INSTALLER_SOURCE')
    # Accept only the exact accepted dev.10 base or exact reviewed candidate.
    # Every pre-existing source file is pinned, including tools and fixtures.
    for name, old_digest in BASELINE.items():
        if name not in files: raise GuardError('BASE_SOURCE_REMOVAL_REFUSED')
        if name.startswith('kaname/') and name not in ALLOWED and hashlib.sha256(files[name]).hexdigest() != old_digest:
            raise GuardError('AUTHENTICATION_SOURCE_CHANGE_REFUSED')
        current = trusted(ROOT / name)
        if hashlib.sha256(current).hexdigest() not in {old_digest, hashlib.sha256(files[name]).hexdigest()}:
            raise GuardError('INSTALLED_SOURCE_DRIFT')
    for name, data in files.items():
        if name in BASELINE: continue
        path = ROOT / name
        if (path.exists() or path.is_symlink()) and trusted(path) != data:
            raise GuardError('UNEXPECTED_EXISTING_FEATURE_SOURCE')
    for prefix in ('kaname', 'tools', 'tests'):
        for path in (ROOT / prefix).rglob('*'):
            if '__pycache__' in path.parts or path.suffix == '.pyc' or path.is_dir(): continue
            if path.relative_to(ROOT).as_posix() not in BASELINE.keys() | files.keys():
                raise GuardError('UNRECOGNIZED_INSTALLED_SOURCE')
    tree = ast.parse(files['kaname/__init__.py'])
    versions = [ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in n.targets)]
    if versions != ['0.14.0-dev.11']: raise GuardError('UNEXPECTED_CANDIDATE_VERSION')


def measure(label):
    token = (STATE / 'access-token').read_text().strip()
    context = ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    results = []
    paths = ['/api/auth/session', '/api/state', '/api/pki/certificates?offset=0', '/api/network', '/api/services']
    if label == 'after': paths += ['/api/audit/history', '/api/audit/history?source=administrators', '/api/radius/events']
    for path in paths:
        codes, times = [], []
        for attempt in range(3):
            connection = http.client.HTTPSConnection('10.35.50.246', 8765, context=context, timeout=20, source_address=('127.0.0.1', 0))
            started = time.monotonic()
            try:
                connection.request('GET', path, headers={'Authorization': 'Bearer ' + token})
                response = connection.getresponse(); response.read(); codes.append(response.status)
            finally: connection.close()
            times.append(round((time.monotonic() - started) * 1000, 1))
        results.append({'path': path, 'statuses': codes, 'median_ms': statistics.median(times), 'max_ms': max(times)})
    emit('PANEL_READ_CHECK', phase=label, authenticated=True, loopback=True, results=results)
    if not all(c == 200 for row in results for c in row['statuses']): raise ValueError('Panel read check failed')

def fresh_backup(worker, target):
    old = target / 'last-success.json'
    old_data = old.read_bytes() if old.exists() else None
    subprocess.run(['/usr/bin/systemctl', 'start', 'authwire-backup.service'], check=True, timeout=650, capture_output=True)
    worker['private'](old)
    data = old.read_bytes()
    if data == old_data: raise ValueError('Fresh backup evidence required')
    record = json.loads(data)
    if record.get('producer') != worker['PRODUCER'] or record.get('event') != 'BACKUP_SUCCESS': raise ValueError('Fresh backup failed')
    for key in ('archive_read_verified', 'file_bytes_and_metadata_verified', 'sqlite_integrity_verified', 'business_state_stable', 'service_processes_preserved'):
        if record.get(key) is not True: raise ValueError('Backup acceptance missing')
    archive = Path(record['backup'])
    if archive.parent != target or not worker['NAME'].fullmatch(archive.name): raise ValueError('Unexpected backup location')
    worker['private'](archive)
    if sha(archive) != record['sha256']: raise ValueError('Backup digest differs')
    emit('PANEL_FRESH_BACKUP', backup=str(archive), sha256=record['sha256'], archive_read_verified=True,
         sqlite_integrity_verified=True, service_processes_preserved=True, data_restore_exercised=False)
    return {'backup': str(archive), 'sha256': record['sha256']}

def preservation(before, after, files):
    expected_files = dict(before['files'])
    installer = '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1'
    expected_files[installer] = [hashlib.sha256(files['kaname/device_client/Install-AuthWire.ps1']).hexdigest(), *expected_files[installer][1:]]
    return {'files': after['files'] == expected_files, 'pids': after['pids'] == before['pids'],
            'timers': after['timers'] == before['timers'], 'business_state': after['business_state'] == before['business_state']}


def restore_check(worker, backup, files):
    checker = load_pinned(Path('/opt/authwire-backup/offline_restore_check.py'),
                          hashlib.sha256(files['tools/offline_restore_check.py']).hexdigest())
    original = checker['validate_copy']
    def extended(root):
        value = original(root)
        path = root / 'var/lib/kaname-lab/radius-events/access.sqlite3'
        with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=1)) as db:
            value['checks']['access_history_database_integrity_ok'] = db.execute('PRAGMA integrity_check').fetchall() == [('ok',)]
            db.execute('SELECT id,event_id,request_id,at,response_code,reason FROM access_events LIMIT 1').fetchall()
            value['checks']['access_history_columns_readable'] = True
        if not all(value['checks'].values()): raise GuardError('ACCESS_HISTORY_RESTORE_CHECK_FAILED')
        return value
    checker['validate_copy'] = extended
    result = checker['check'](backup['backup'], backup['sha256'], Path('/var/lib/authwire-restore-checks'))
    worker['atomic_json'](EVIDENCE / 'restore.json', result)
    emit('RETRY_UPDATE_RESTORE_VERIFIED', **result)

def main():
    global PHASE, UPDATER, EVIDENCE
    if EXPECTED == "RELEASE_NOT_PINNED" or RELEASE == "RELEASE_NOT_PINNED": raise GuardError("RELEASE_NOT_PINNED")
    if os.geteuid() != 0: raise ValueError('Local sudo required')
    import cryptography
    if cryptography.__version__ != '46.0.0': raise GuardError('PINNED_VENV_PYTHON_REQUIRED')
    PHASE = 'preflight_helpers'
    UPDATER = load_pinned(ROOT / 'tools/linux_update.py', 'd168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe')
    PHASE = 'preflight_manifest'; files = UPDATER['verified_files'](STAGE, EXPECTED)
    PHASE = 'preflight_sources'; source_check(files)
    worker_path = Path('/opt/authwire-backup/scheduled_backup.py')
    worker_sha = sha(worker_path)
    allowed_worker_shas = {hashlib.sha256(files['tools/scheduled_backup.py']).hexdigest()}
    if worker_sha not in allowed_worker_shas: raise GuardError('UNRECOGNIZED_BACKUP_WORKER')
    worker = load_pinned(worker_path, worker_sha)
    PHASE = 'preflight_preservation'; before = snapshot(worker)
    PHASE = 'preflight_evidence'; target = worker['prepare_directory']()
    EVIDENCE = target / ('retry-update-dev11-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
    EVIDENCE.mkdir(mode=0o700)
    worker['atomic_json'](EVIDENCE / 'before.json', {'release': RELEASE, 'manifest': EXPECTED, 'checked_utc': worker['utc'](), 'snapshot': before})
    previous = target / 'last-success.json'
    if previous.exists():
        worker['private'](previous)
        record = json.loads(previous.read_bytes())
        archive = Path(record['backup'])
        if (record.get('event') != 'BACKUP_SUCCESS' or record.get('producer') != worker['PRODUCER']
                or archive.parent != target or not worker['NAME'].fullmatch(archive.name)):
            raise GuardError('PREVIOUS_BACKUP_EVIDENCE_INVALID')
        worker['private'](archive)
        if sha(archive) != record['sha256']: raise GuardError('PREVIOUS_BACKUP_DIGEST_DIFFERS')
        timer = subprocess.check_output(['/usr/bin/systemctl', 'show', 'authwire-backup.timer', '--property=LastTriggerUSec'], text=True, timeout=10).strip()
        worker['atomic_json'](EVIDENCE / 'previous-backup.json', {'backup': record, 'timer': timer})
        emit('PREVIOUS_BACKUP_EVIDENCE', backup=str(archive), sha256=record['sha256'], created_utc=record['created_utc'], timer=timer, digest_verified=True)
    emit('RETRY_UPDATE_PREFLIGHT', protected_authentication_source_identical=True, radius_active=True,
         service_pids=before['pids'], baseline_persisted=True, evidence=str(EVIDENCE))
    PHASE = 'baseline_read_checks'; measure('before')
    PHASE = 'fresh_data_backup_before'; fresh_backup(worker, target)
    if snapshot(worker) != before: raise GuardError('PREPARATION_STATE_CHANGED')
    PHASE = 'panel_source_update'
    same = all((ROOT / n).is_file() and not (ROOT / n).is_symlink() and (ROOT / n).read_bytes() == b for n, b in files.items())
    with file_creation_mask(0o022): updated = {'already_current': True} if same else UPDATER['update'](STAGE, EXPECTED)
    emit('RETRY_SOURCE_UPDATED', **updated)
    PHASE = 'preservation_after_source'
    checks = preservation(before, snapshot(worker), files)
    worker['atomic_json'](EVIDENCE / 'source-preservation.json', checks)
    if not all(checks.values()): raise GuardError('SOURCE_UPDATE_PRESERVATION_FAILED')
    source_check(files)
    if any(trusted(ROOT / n) != b for n, b in files.items()): raise GuardError('INSTALLED_SOURCE_DIFFERS')
    PHASE = 'preservation_after_update'
    after = snapshot(worker); checks = preservation(before, after, files)
    worker['atomic_json'](EVIDENCE / 'preservation.json', {'checks': checks, 'after': after})
    emit('RETRY_UPDATE_PRESERVATION', checks=checks, baseline_persisted=True)
    if not all(checks.values()): raise GuardError('UPDATE_PRESERVATION_FAILED')
    PHASE = 'fresh_data_backup_after'; backup = fresh_backup(worker, target)
    PHASE = 'isolated_restore_check'; restore_check(worker, backup, files)
    if not all(preservation(before, snapshot(worker), files).values()): raise GuardError('FINAL_PRESERVATION_FAILED')
    PHASE = 'panel_read_checks_after'; measure('after')
    worker['atomic_json'](EVIDENCE / 'finished.json', {'verified': True, 'version': '0.14.0-dev.11', 'checked_utc': worker['utc'](), 'release': RELEASE})
    os.sync()
    emit('RETRY_UPDATE_FINISHED', verified=True, version='0.14.0-dev.11', radius_active=True,
         radius_process_preserved=True, radius_restarted=False, broker_process_preserved=True, protected_state_preserved=True,
         backup_timer_preserved=True, windows_changed=False, policy_changed=False, certificates_changed=False,
         native_module_changed=False, original_preflight_snapshot_persisted=True,
         gpo_installer_source_updated=True, signed_sysvol_update_pending=True, vv06_automatic_retry_acceptance_pending=True)

if __name__ == '__main__':
    try: main()
    except Exception as error:
        emit('RETRY_UPDATE_FAILED', phase=PHASE, category=type(error).__name__,
             guard_code=getattr(error, 'code', None),
             updater_stage=UPDATER.get('_PHASE') if PHASE == 'panel_source_update' else None,
             evidence=str(EVIDENCE) if EVIDENCE else None,
             sqlite_code=getattr(error, 'sqlite_errorcode', None) if isinstance(error, sqlite3.Error) else None,
             exit_code=error.returncode if isinstance(error, subprocess.CalledProcessError) else None)
        raise SystemExit(1)
