"""Pinned dev29 -> dev32 user-enrollment delivery. No full data backup or RADIUS restart."""
from contextlib import contextmanager,closing
from datetime import datetime,timezone
import ast,hashlib,http.client,json,os,pwd,sqlite3,ssl,stat,statistics,subprocess,tempfile,time,uuid
from pathlib import Path
ROOT=Path('/opt/kaname-lab/source')
STATE=Path('/var/lib/kaname-lab')
PHASE='preflight'
EVIDENCE=None
UPDATER={}
OMIT_NEW_USER=False
USER_TABLES={'user_enrollment_profiles','user_enrollment_challenges','user_enrollment_issuances','user_enrollment_rate'}
WORKER_PATHS={'scheduled_backup.py':Path('/opt/authwire-backup/scheduled_backup.py'),'offline_restore_check.py':Path('/opt/authwire-backup/offline_restore_check.py')}
RELEASE_PATH=Path('/opt/authwire-backup/release.json')
APPLICATION_DATA={STATE/'secret-store.key',STATE/'radius/server.pem',STATE/'radius/server-key.pem'}
class GuardError(ValueError):
    def __init__(self,code):self.code=code;super().__init__(code)
def trusted(path):
    info=path.lstat()
    if path.is_symlink() or not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_nlink!=1 or info.st_mode&0o022:raise GuardError('UNTRUSTED_INSTALLED_FILE')
    if any(p.is_symlink() for p in path.parents):raise GuardError('UNTRUSTED_INSTALLED_PATH')
    return path.read_bytes()

STAGE=Path('/home/segmentiq/authwire-stage-dev32-422ab022c0fe')
EXPECTED='d7ad429bc3d7d0a8fea3dc948a75eff5356de8e2b4b0bf11802f6c4f099cdb80'
RELEASE='422ab022c0fe2e54848772934575e035b45610ac'
BASELINE={'kaname/__init__.py': 'f508984ded2cc05c3b141106dd618a0dcaa258fc71d82e5e1b8d8df36052569d', 'kaname/__main__.py': 'e01ee55f671609348749b7c045e1cd0cfed825fe172a1fa0435c58e4bd76907a', 'kaname/admin.py': 'ae7fbe42cdeee7244764beba98ff64b784147d33bb876d2f5b663ca1331362de', 'kaname/audit.py': 'fe5bc68873ed722082e26b0d94df8f1c0d42f8e778aef4b14a57df1578491751', 'kaname/dashboard.py': '882478cead34aba9347df236556be8a23686f7a3cd2aa70740b23ec5064616f2', 'kaname/device_auth.py': 'b2b7b608f4305bf4555cde83b2a38ecd1269b6979116a3daf2bc9e581928b16d', 'kaname/device_client/AuthWire-Client.ps1': 'bf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60', 'kaname/device_client/Install-AuthWire.ps1': 'faec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609', 'kaname/device_enrollment.py': '3cba64df06a78284aabf9b8de6abbdcacbede2244c9df57f6a87af97f623fc3b', 'kaname/directory.py': '8e73ec0e4f4a7837d098f4a1433857b4b29e01ea768e6a69c6b95b347986e8f0', 'kaname/directory_linux.py': '2ce06cdfa2531df4fb5c8b3dca2918036b80e44dd5fc9a12a0c9e8c5d3a076fd', 'kaname/directory_linux_helper.py': '434874a7a060b3850cb4eb6330aacbfc8bd6725c79fb78df293dceea58e83bf7', 'kaname/directory_sync.py': 'e5769d5f79a188f7ebcccefa88073ac2feec91a55b7448291af67a214021220a', 'kaname/directory_windows.ps1': '199bce5da72e3d2277bd27b6a3318f4d0fac1335e3e7d5aeccfda5ae761bd3e3', 'kaname/enrollment.py': '90570901d12047993a8cda63ec34956a4927eb6d1a9f6051d08b53b1f12a4587', 'kaname/membership.py': 'ff8dea55bc79fbc750cb2216afafd069fa86e1fd2408910cbcddce204f5feead', 'kaname/models.py': '8bcd9f2d2ea9960738c1e5a698056340498ce47a3640aa0f304484d2f87b4ef2', 'kaname/operations.py': '5d42b9e9d59ba2b7d47e5ff68c6928205ffa37b1bb3cec41d32f5367a2e84beb', 'kaname/pki.py': '1ccf775e7ad390e40e56ada967cdd387ea96d12fcac2ce6cbf12f420260f28da', 'kaname/planning.py': '9235ff11f3cef34fea918b8ee5237e251f9f60a31a1881a1ecf4cf33bc085814', 'kaname/policy.py': 'bafbd3c9b889400d3dc59238ddbab386ef83aa0d51134966addb9a648fad33de', 'kaname/radius.py': 'edc2eba66c5f4759fe442c2de2ef35e4cffbb04991b61bfc44213e0d7a441395', 'kaname/radius_adapter.py': '5b8c123d290009f721785c19ab2c36ec608446b6ed6a08e1b119a3a0a9a97f33', 'kaname/radius_directory.py': '6f8b92c698a1a9ce32b0194798cf34ea5df3d030ea9182b8027f7b076feaee5d', 'kaname/radius_events.py': '563dc2051dae8871dcd655cd23c2796ffd60ca999a0624d023bf2af12e0b1874', 'kaname/radius_observer.py': '52c83f27953d79dfe291683292f45fc0f14b500896440017053dd8804d2c8c30', 'kaname/radius_registry.py': '1f1c14bfedd19f2ce2fe08cbc95c785805d13d873c135fe73f90bcb980b1304c', 'kaname/resources.py': 'c410c83b1c5414fe084247d21b06c1cef046271a3c8b7ff53209e4cc0a6d4557', 'kaname/server.py': '7a3d89798d2ced5c16c5c601eabeb4bd6b8a3b3d5369fe546d66291f6320005a', 'kaname/services.py': 'f7d6b1643f22300835e579dea38ccea1a4f7eeba26df52979e5b187887313701', 'kaname/static/access-events.js': '78dfa22aa789fa769106b8b0077ce6503adffe98b28931ab81355ef878aae553', 'kaname/static/app.js': '1ca71c0b64e9b033cfc32aa3af4bc52dbf3f8dcd9a049062c8b15e1afc6c2b2f', 'kaname/static/audit.js': '7453d6085f52d2f17540b9beb4d984a52e9ae41153c7cbd18383631fac900f6e', 'kaname/static/authwire-logo.png': '677e49220d7ca57376735a9792b8067e8aaca223ee73806d91ff3dc1eb8d728e', 'kaname/static/dashboard.js': '9383e03df82dabd6b5fe58731322782031ca4f6dadef3b07efa9f42e0cbfd054', 'kaname/static/device.js': '089aa7e989a30ab00e4a0b3c6b96e907c8b3f049a40ecd2f29cfc1040c6ea4fd', 'kaname/static/index.html': '70b524f3d9eaa8e4009dd5e2392ca39dc25e6a84f337377145d44e2c73003b6e', 'kaname/static/planning.js': 'f02cacca6d73eca33a6d82a678d5e91c16100d09b24d1734c37c953cacecac2a', 'kaname/static/services.js': '209c9b1a9bb6370cfed1d3271b70fcaf6a02c5678137edfab5ce70c19d54c8c6', 'kaname/static/styles.css': '4b6148828a5eadb54e17b19e839fe62629e76b7c002c84f09575aa773405b530', 'kaname/store.py': 'a4edd60c668fe88a987ec895d3c21b07d31a523cd1e922c9cabd0a3897d70992', 'kaname/vault.py': '9272bb391dd5eac66e46bef63417e13987a1f83151a97c4899a8297b6841a0fd', 'pyproject.toml': '33fbf23e364e3d290331824b5dc34ceb1ed305e18da61a7925b4c6e78fe30c98', 'tests/__init__.py': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'tests/helpers.py': '4233f0211a88efa600379ea01592fcb3a51a0f1f2d0fe6c1c317693a6ebbaab5', 'tests/ldap_fixture.py': 'e52929ea4e8a294a1b4d138d10ff7c9598cb360512762f06faf2860bcfe7098d', 'tests/radius_fixture.py': '0a0138421fa38959e479c102ee1a32dfa33a5552c742c37da0baa2a46fa2333c', 'tests/test_admin.py': '10d8c3f86fc6a199f73cb4feb399915150f89628796060beb76b7bd92650fa1d', 'tests/test_audit.py': 'a021c7da61e454b26b680d12c2076fd2cfe004d0ac24e39effdbc3fadbb1040b', 'tests/test_dashboard.py': '948647e39494aa3df495cfe5581588ae1c7f4de8a75f92577289dec0baae80bc', 'tests/test_device_auth.py': '6fc9a298b06adf5d50ba45be81bc601af7bd8fd5b2392a0d44c21344da273841', 'tests/test_device_enrollment.py': '8b20268922af94e601965bc5593a08ae76a0bba99fc35fa0fbf5d87be52358aa', 'tests/test_device_expired_fixture.py': '134488bfe60bf18e7d06a7908a6edb228720aacbf396dcb0d98bda3aa3440b98', 'tests/test_device_http.py': '7fe6d0cc4662450062d1e26a092d4f4eb912c14b7580aa26971e6d69232bdf7a', 'tests/test_directory.py': '6ae80aa1843d66c3465cfeeb57dfd5b64be6bdc00cacdd72ed7a8ff0bb50df0b', 'tests/test_enrollment.py': '09d310a25b40e29a297d4cc61f2ca44da346d4f5f87e1118f3ffc7c4c961d672', 'tests/test_enrollment_http.py': '99bc93d1f3c939673b41b5464a3004697c3c121677d9bcb5e16defc91665f285', 'tests/test_expired_recovery_deploy.py': 'f9bd180235f299fc70967d547d5adc65d5728c356e37e447c8e6ee6052d8fab8', 'tests/test_host_power.py': 'b426a68a29f6e964c9be8f2e3c1421341f42aaf5cfd43939bfc81c02e4a2bef9', 'tests/test_http.py': 'f3059e53d7ee654ae3670479a2ea9935f939503310be290bcfe765b2533ed7ee', 'tests/test_linux_directory.py': '605fa7f32743e49a9fbbd4713b898481f02d8bc9feff193443cee61b3dfae4b8', 'tests/test_linux_install.py': '0ad196ffb318a762f6ef7c004d675bde2536ce8cc854f48b6d922ecb4feaa73e', 'tests/test_linux_update.py': '383b8bc4dc7da5c52520e2f7603f6c6491fc8ba9a086b33c4dadbd5291ec31ee', 'tests/test_local_group_feature_removed.py': 'f5e21efc287a5d6496168477bf77854a0b6f1464cc81d5243c92312ff886ee32', 'tests/test_management.py': 'e3efc868afe96cd70ba0cdd57b30a6fdfe7f99735915a033642f821c986af3e5', 'tests/test_membership.py': 'c12840f56a30fcc4801432951477659062b006a85232c8ca5ebabfc1ef3bff93', 'tests/test_offline_restore_check.py': '8154664a8fb24d2b1caec82917aa96c2a19b871ae1e736b69afae5e79c0b0154', 'tests/test_ovf.py': '50a9d7bc9d9904a18b8048f217ddbc44065e36a9137b5bbc3c1e26545e748d10', 'tests/test_pki.py': '338fbb873d989d2f648a8a3dc0843a3b4d0bf9759f25b052dd7686a974c25b90', 'tests/test_pki_cli.py': '6ba4cbee1e94ad019521f6d9c83ff210627bf17fbf100a727137dab2a34db05e', 'tests/test_pki_http.py': 'e4aa1cc56b7138c35789e8ded2e00bc468e6bbb275a66572b0106d11a38d0e92', 'tests/test_planning.py': '1e281eab0ea24d8526a9b33c8222e93ba35f007741537b102c67e92b9a213089', 'tests/test_policy.py': '439ac79cd5a7e2483f5d4d47dc0609c01f51ff93ca8751f01d4a5f14ea823f14', 'tests/test_policy_toggle_deploy.py': '2e16679a0d0920822297249d70738d37accba1b62abfe482a5a6e96ca3a113d2', 'tests/test_principal_policy.py': '07476cb05da8bef4f67792f0debd7ec0eeab29b8fb4efe2f72ab054443f718d8', 'tests/test_radius.py': 'f7c083715d2558b8e7516021d9da07764cdef2fc6c4d5b40c349b9d21cc034dd', 'tests/test_radius_crl_install.py': '727ee23fc40795dbead6c6dc4968f177d7dfada54e1cc7d1170e22de982f2b8f', 'tests/test_radius_crl_sync.py': 'bd2392a049e4dccd360577f06377fdf60f07e92aa0df5d5b27ab474ee357f58b', 'tests/test_radius_events.py': '163b956bc730c9d1773c6a3a4c42076b59a03ade976eaf528f4db15cb087a644', 'tests/test_radius_events_deploy.py': '680866bfc284e35dbe5457fb60389c99930460828021cb9f9c8181fda4ed0036', 'tests/test_radius_events_install.py': '18699c2c6e6df22e7ead57486a84cf86741edd1effe1c5babae88f9bda819b24', 'tests/test_radius_lab_paths.py': '72068e0a61df99b26a9be8e3ef6390df6759640847e9212b839b8d3e5e610efc', 'tests/test_radius_live.py': '4bea7038075b62f1db0b80abd74f75579d7fae03363b1b336c89dbfa4ac8b9c3', 'tests/test_radius_module_update.py': '6ced1e3f1ac9d8489a542f9c4915a17fb42ed3620bb5e27de99022e4aa38bd2b', 'tests/test_radius_packets.py': '9a419df7d1f87bcaa5feab9e4bacd30c22e8fadd5e8f9887c7fad6873e9f15e3', 'tests/test_radius_production.py': '1fbbf86654df2b130f9aa7a7b7342a847dd6f86f8afe5b94a3b9d75a1c125aa8', 'tests/test_radius_unit_update.py': '81a1c883849ac5038976a6aa388b15d93afe7ca7c60f46efa12b66471dbe299f', 'tests/test_resources.py': 'f2a917045c2a5f494dc22e51dc6711d226ead7f67187ec7766ca824b5b506d84', 'tests/test_retry_deploy.py': '00b5b7550ef4ce5fa5dfd61ec354e72a75e9e95a974b428a3e1c027ce07b621b', 'tests/test_retry_network_probe.py': '894a1a472e1e8a091ee22a0d2820458eb0b590e04915d2ed4f78291e83900171', 'tests/test_scheduled_backup.py': '1e5b4ed8b9c82f895d86bd367513e2638b3a1e33be208284dba0caa8a9beb581', 'tests/test_service_control.py': '2f6e08aec74d253929875d56d3d728187e4970eb3869d2afb4971a0398545222', 'tests/test_startup_deploy.py': '4c5c339d18ab26b0d1ac6afea1249f6ce02bf75470405046575aa8623061cd3e', 'tests/test_store.py': '8da8efb6fd5d920cac82e74e6551a6864ad1bb4bda53208333be034bde65b4c4', 'tests/test_windows_diagnose.py': '54b196ab794bc93dc3ea85d0d31584adf0375f5cd6651819ed038b469bc4846c', 'tests/test_windows_update.py': 'd5cf63eca677bfd3ffbdb7b03d7499cbfcd445d89dc71560eadc3bd95454c203', 'tools/AuthWire-GPO-Audit.ps1': '3211b09a844cf3c4bfabc6263f7e549451e87c0ad42ccc02c22b1b1dfbdff88d', 'tools/__init__.py': '7e41a692ddeb7ca616af6038aa8b2d8b14aa1699216b213caaee860937d31403', 'tools/backup_install.py': 'ed18f5c0c3e65aa6d2a6fe8311ddd1fa604b128c724e5854214e986118faf347', 'tools/backup_systemd_check.py': '654c0389375251d42a28be89c472cb8822e606ba7fd44240a8a2b66f1827eb24', 'tools/client_request.py': '86d3d9822451f4239f6316f236b6cfa59ed748c1990ed06ca212b7581a9afedd', 'tools/device_expired_client_harness.ps1': 'f81bb0d9318147b64f39979c7f02ce18244bad9ec38ef670995e13861872e2cb', 'tools/device_expired_fixture.py': '85237cd78e7eee42f5f623252ec115dd1bc1113755de172f8af130629d98bdf8', 'tools/device_expired_windows_check.ps1': '66b2756dcce8af3e6cf4cbf4815916232c75b9fce965f8e8915f9d0d1625af1a', 'tools/device_fixture.py': '61d4a7452eaa97dfdadb161527195c0cbb440702c06d28ef0cfeae04ef170c81', 'tools/device_load_smoke.py': '7e6aff546471c4ad7f1b476d5e30a3185e0fcff753a24936f1fdd6e40b537439', 'tools/device_retry_windows_check.ps1': '744d5425171b15c5b5a0910f69c8aabd3d09656b278fa7124a33766fedef7428', 'tools/device_startup_windows_check.ps1': 'ef49621d05b84b25093387adf19c4d6e6f82aedbf1a5acbab13c7944c577b696', 'tools/device_windows_smoke.ps1': 'b4a241212f7ece0a940900214b7550f580a5e02debd3ddfdb625ed186d1ab535', 'tools/export_appliance.py': '35ba5228947787ac89cf9f45f1f4961d1bdf1c82cc235568e4c547c48bba54d7', 'tools/gpo_audit_fixture.ps1': '1a1221643b9998c928fb0281c5958570ca462137e9537823e254368fbdcddf50', 'tools/gpo_expired_update_fixture.ps1': '4d638f10de52bf9ef1548308196e6f51769e33b0a65543023f8b71a369063d4c', 'tools/gpo_installer_update_fixture.ps1': '997a5069bd125436698d8fbee378f44d8f6da498093e6973dbd1c8d675352f96', 'tools/gpo_retry_update_fixture.ps1': '50c20abb79c4b43b5ff46e2f37a4d2e2767310be6052b5e80ab954b07bebf64d', 'tools/linux_authorization_check.py': 'f719e1716590764df479ebb44a2a0ab02704a68fb3993357d91932fd5fc9a5c0', 'tools/linux_device_setup.py': '98e3f069b1a27755749c903ed7d7bda27737b26a277d1d6228db63cee4918648', 'tools/linux_initialize.py': '525fe5d380829bb3d93f11d374651c98dda58b30022599389043760896c7fbd5', 'tools/linux_install.py': '3623c91616f3e35ae61e7ad5acbc3482ec76071d3a5ba73020f7980f2e783365', 'tools/linux_install_smoke.py': '268b2958e04585e4f7e389a6c6fbbe775601405657a97e137976c81f4bf4fb4b', 'tools/linux_prepare.py': '90da15eb52d658fe35782be00041ec7d0cf6705e3bce9589d145cb04f08cdd76', 'tools/linux_update.py': 'd168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe', 'tools/offline_restore_check.py': 'c9a1cba667eee28e5e6a3579ced0b457b17e1e7193f254b74e6638a87e48f610', 'tools/package_source.py': 'cf217f7259a819603df28ecff9f6cc4c622a64c5fdd653dbf56c69a7fb38b72d', 'tools/radius_crl_install.py': '2b10abf6bbbdb9d4ee5e542d6938ef354ce094e6cf9330bb3da923a61e2e2a8c', 'tools/radius_crl_sync.py': '580da79bc8c18b10f3c4551768954dde9f9470170451ee2fce127c60d73d2559', 'tools/radius_crl_timer_check.py': '38b18baa708a26b740ea0bfeb07cbb7adeed8628a06ffe39aa3115186403b22b', 'tools/radius_events_config.py': 'd587aa0abd803bd2124c3924cfe63da37d07638119feb52fdae76b9640bf66be', 'tools/radius_events_install.py': '7c0b03b0c627f88b2d5b1e2532910e76b91f7318e6114f2198a6522f3627d607', 'tools/radius_events_systemd_check.py': '45d7d3434552d5cab28700a707870701364b86d66351d9a22023ed789e084bbd', 'tools/radius_initialize.py': '8ce73e33fc8b4201bb16cba85978b10122ab7161f33aab796f29c036d470447b', 'tools/radius_install.py': '63045293fc7a4d62d13d69921a2aa4d3e0242dacde9190ac286ec7a8ebcf3233', 'tools/radius_lab.py': 'e3355f948c8717ae342395063b949f6e4d2cf366c1d5b12740088af4790edc0d', 'tools/radius_module_update.py': 'ad5a848ae0d9819e8abe64cb14c420f8799ac67c2ee84609c71b3dcbaac51881', 'tools/radius_native_check.py': '96be8588b8ca30c5ba1c24d37fe0d56bd02f9eb09ae70193a73051c35de79e96', 'tools/radius_prepare.py': 'f9f2d87143365ba701b72446383b536cb5478ddc31e267c6b67f252f9a8a6640', 'tools/radius_runtime.py': '2cdf26595b0f06601b7dd858af102d381a33fb8155458c5189de6a0c03c38738', 'tools/radius_service.py': '7a0caadfb496ac5cc769a6903adc3f0e0f617e443668a6db01b7f37b17199f63', 'tools/radius_unit_systemd_check.py': '51391ca56cce67bdb4458076a241018a019267ae7a0b1af0cc30c55eb19f0fa4', 'tools/radius_unit_update.py': 'c9d4e9daa02d9c42fa7697ce04a9e8caeb6c6190addce3f37daf698e61934526', 'tools/retry_network_probe.py': '8152fb58f5a00e87c57995242eb2f9d40838b3e5b09e3eeea3020f582c396614', 'tools/retry_probe_native_check.py': '2cf726736145de974ec6283ae0c462219a8f0d2b646ce168da26f5c645fd4924', 'tools/scheduled_backup.py': '06961ebec421158bf7141755355f351e206544a5dc727af89226ffe97ae6f548', 'tools/service_control_broker.py': '283651f5d3105e8b915bdbf2f15977ec1038471081fcc1f7f5547c5c94d690d2', 'tools/service_control_install.py': '08f809038c65b63c983e7c69466b4a357f58d0819966c36e54ab2cde73cb9bc1', 'tools/service_control_systemd_check.py': '9c6addaa96569a10ad21cfb2f88f594889808312650d8696a88073b325e08086', 'tools/verify_ovf.py': '10e08fe6f6945d568c1a6a88f8262f3a2879833f829262f8536ba89607c0c12b', 'tools/windows_diagnose.ps1': '257ad0e9d737ea0ad75092e094d7e712bdf3b17a43439977c37efdae3906a553', 'tools/windows_diagnose.py': '3e1c33600cce117b70d14e1c05b64c94194f2e7e8eea55fd7791102468f00253', 'tools/windows_update.py': 'ccdeb93b75f832b6bfc667691b41d322c41733742407c323b0749b9d73230528'}
ALLOWED={'kaname/directory_linux_helper.py', 'tests/test_user_directory.py', 'tools/offline_restore_check.py', 'tests/test_user_enrollment_http.py', 'tools/radius_events_install.py', 'tools/radius_events_systemd_check.py', 'tests/test_radius_events_install.py', 'kaname/__init__.py', 'tests/test_user_client_package.py', 'kaname/static/styles.css', 'kaname/server.py', 'tools/user_client_fixture.py', 'pyproject.toml', 'kaname/static/user-enrollment.js', 'kaname/directory_linux.py', 'tests/test_service_control.py', 'kaname/device_client/AuthWire-User-Client.ps1', 'kaname/device_enrollment.py', 'tests/test_offline_restore_check.py', 'kaname/user_enrollment.py', 'tests/test_user_panel.py', 'kaname/static/index.html', 'kaname/device_auth.py', 'tests/test_scheduled_backup.py', 'kaname/static/app.js', 'kaname/device_client/Install-AuthWire-User.ps1', 'tools/user_client_windows_check.ps1', 'tests/test_user_enrollment.py', 'tools/scheduled_backup.py', 'tests/test_device_auth.py', 'tests/test_user_client_package_http.py'}
NEW_FILES={'kaname/device_client/Install-AuthWire-User.ps1', 'tests/test_user_directory.py', 'tests/test_user_client_package.py', 'kaname/device_client/AuthWire-User-Client.ps1', 'tests/test_user_enrollment_http.py', 'tools/user_client_windows_check.ps1', 'tests/test_user_panel.py', 'kaname/user_enrollment.py', 'tools/user_client_fixture.py', 'tests/test_user_enrollment.py', 'kaname/static/user-enrollment.js', 'tests/test_user_client_package_http.py'}
REMOVED=set()
PROTECTED=['kaname/radius.py', 'kaname/radius_adapter.py', 'kaname/radius_directory.py', 'kaname/policy.py', 'kaname/device_client/AuthWire-Client.ps1', 'kaname/device_client/Install-AuthWire.ps1', 'kaname/static/authwire-logo.png', 'tools/service_control_broker.py']


def emit(event, **values): print(json.dumps({'event': event, **values}), flush=True)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

@contextmanager
def file_creation_mask(mask):
    previous = os.umask(mask)
    try: yield
    finally: os.umask(previous)

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

def measure(label):
    token = (STATE / 'access-token').read_text().strip()
    context = ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    results = []
    paths = ['/api/auth/session', '/api/state', '/api/pki/certificates?offset=0', '/api/network', '/api/services', '/api/device-admin/status?offset=0']
    if label == 'after': paths += ['/api/user-admin/status?offset=0','/user-enrollment.js','/api/system/resources','/api/dashboard?period=7d','/api/dashboard?period=1h','/api/dashboard?period=6m','/api/dashboard?period=1y','/api/system/power','/api/policies/labels','/api/audit/history', '/api/audit/history?source=administrators', '/api/radius/events']
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

def version_of(files):
    tree = ast.parse(files['kaname/__init__.py'])
    return next(ast.literal_eval(n.value) for n in tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in n.targets))

def write_ui(path, data, helper):
    if data is None:
        if path.relative_to(ROOT).as_posix() not in (NEW_FILES | REMOVED): raise GuardError('UNREVIEWED_SOURCE_DELETE')
        path.unlink(missing_ok=True)
        return
    if path.suffix != '.png':
        helper['atomic_text'](path, data.decode('utf-8'))
        return
    temporary = path.with_name('.' + path.name + '.update-' + uuid.uuid4().hex)
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try: temporary.unlink()
        except FileNotFoundError: pass


def source_check(files):
    if set(files)!=(set(BASELINE)|NEW_FILES):raise GuardError('SOURCE_SET_DIFFERS')
    if version_of(files)!='0.14.0-dev.32':raise GuardError('CANDIDATE_VERSION_DIFFERS')
    for name in PROTECTED:
        if hashlib.sha256(files[name]).hexdigest()!=BASELINE[name]:raise GuardError('PROTECTED_AUTHENTICATION_SOURCE_CHANGED')
    for name,data in files.items():
        digest=hashlib.sha256(data).hexdigest()
        if name in BASELINE and name not in ALLOWED and digest!=BASELINE[name]:raise GuardError('UNREVIEWED_SOURCE_CHANGE')
        p=ROOT/name
        if name in BASELINE:
            if hashlib.sha256(trusted(p)).hexdigest() not in {BASELINE[name],digest}:raise GuardError('INSTALLED_SOURCE_DRIFT')
        elif (p.exists() or p.is_symlink()) and trusted(p)!=data:raise GuardError('UNEXPECTED_EXISTING_SOURCE')
    for prefix in ('kaname','tools','tests'):
        for p in (ROOT/prefix).rglob('*'):
            if '__pycache__' in p.parts or p.suffix=='.pyc' or p.is_dir():continue
            if p.relative_to(ROOT).as_posix() not in files:raise GuardError('UNRECOGNIZED_INSTALLED_SOURCE')

def schema_statements(files):
    tree=ast.parse(files['kaname/user_enrollment.py'])
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='UserEnrollment')
    init=next(n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name=='__init__')
    loops=[n for n in ast.walk(init) if isinstance(n,ast.For) and isinstance(n.iter,ast.Tuple)]
    if len(loops)!=1:raise GuardError('USER_SCHEMA_SOURCE_DIFFERS')
    values=ast.literal_eval(loops[0].iter)
    if len(values)!=5 or any(not isinstance(v,str) or not v.startswith(('CREATE TABLE IF NOT EXISTS user_enrollment_','CREATE INDEX IF NOT EXISTS user_enrollment_owner')) for v in values):raise GuardError('USER_SCHEMA_STATEMENT_DIFFERS')
    return values

def user_schema(db):
    return [r for r in db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name") if r[2] in USER_TABLES]

def expected_schema(statements):
    with closing(sqlite3.connect(':memory:')) as db:
        for statement in statements:db.execute(statement)
        return user_schema(db)

def projection(path):
    VOLATILE={'user_enrollment_rate', 'access_events', 'audit', 'device_challenges', 'device_rate', 'directory_catalog', 'user_enrollment_challenges', 'admin_login_rate', 'admin_audit', 'pki_enrollment_rate', 'sqlite_sequence', 'admin_sessions'}
    omitted=USER_TABLES if OMIT_NEW_USER and path.name=='kaname.sqlite3' else set()
    with closing(sqlite3.connect(path.as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        db.execute('BEGIN')
        schema=[r for r in db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name") if r[2] not in omitted]
        h=hashlib.sha256(repr(schema).encode())
        for name, in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
            if name in VOLATILE or name in omitted:continue
            quoted='"'+name.replace('"','""')+'"'
            where=" WHERE name<>'directory_health'" if name=='runtime_settings' else ''
            rows=db.execute('SELECT * FROM '+quoted+where).fetchall()
            h.update(name.encode());h.update(repr(sorted(rows,key=repr)).encode())
        return h.hexdigest()

def plan_schema(files):
    global OMIT_NEW_USER
    statements=schema_statements(files);expected=expected_schema(statements)
    with closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        present={n for n, in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}&USER_TABLES
        if present and (present!=USER_TABLES or user_schema(db)!=expected):raise GuardError('EXISTING_USER_SCHEMA_DIFFERS')
    OMIT_NEW_USER=not present
    return statements,expected

def install_schema(statements,expected):
    with closing(sqlite3.connect(STATE/'kaname.sqlite3',timeout=3)) as db:
        with db:
            db.execute('BEGIN IMMEDIATE')
            for statement in statements:db.execute(statement)
            if user_schema(db)!=expected:raise GuardError('USER_SCHEMA_DIFFERS')
            if OMIT_NEW_USER and any(db.execute('SELECT count(*) FROM '+name).fetchone()[0] for name in USER_TABLES):raise GuardError('NEW_USER_SCHEMA_NOT_EMPTY')
        if db.execute('PRAGMA quick_check').fetchall()!=[('ok',)]:raise GuardError('DATABASE_CHECK_FAILED')

def verify_empty_schema(expected):
    with closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        if user_schema(db)!=expected:raise GuardError('USER_SCHEMA_CHANGED')
        if OMIT_NEW_USER and any(db.execute('SELECT count(*) FROM '+name).fetchone()[0] for name in USER_TABLES):raise GuardError('NEW_USER_BUSINESS_STATE_CHANGED')

def worker_plan(files):
    old={n:trusted(p) for n,p in WORKER_PATHS.items()};old_release=trusted(RELEASE_PATH);release=json.loads(old_release)
    if set(release)!=set(WORKER_PATHS) or any(release[n]!=hashlib.sha256(old[n]).hexdigest() for n in old):raise GuardError('BACKUP_RELEASE_DIFFERS')
    for name,data in old.items():
        if hashlib.sha256(data).hexdigest() not in {BASELINE['tools/'+name],hashlib.sha256(files['tools/'+name]).hexdigest()}:raise GuardError('BACKUP_WORKER_DRIFT')
    candidate={n:files['tools/'+n] for n in WORKER_PATHS}
    # The reviewed scheduled worker addition is exactly these two transient tables.
    changed=old['scheduled_backup.py'].replace(b"'device_challenges', 'device_rate',",b"'user_enrollment_challenges', 'user_enrollment_rate', 'device_challenges', 'device_rate',",1)
    if old['scheduled_backup.py']!=candidate['scheduled_backup.py'] and changed!=candidate['scheduled_backup.py']:raise GuardError('UNREVIEWED_BACKUP_CHANGE')
    new_release=(json.dumps({n:hashlib.sha256(b).hexdigest() for n,b in candidate.items()},sort_keys=True,indent=2)+'\n').encode()
    return old,old_release,candidate,new_release

def preflight_import(files):
    with tempfile.TemporaryDirectory(prefix='user-panel-verify-',dir='/opt/kaname-lab') as directory:
        candidate=Path(directory);candidate.chmod(0o755)
        for name,data in files.items():
            p=candidate/name;p.parent.mkdir(parents=True,exist_ok=True,mode=0o755);p.write_bytes(data);p.chmod(0o644)
        subprocess.run(['/usr/sbin/runuser','-u','kaname-lab','--','/opt/kaname-lab/venv/bin/python','-I','-B','-c','import sys;sys.path.insert(0,sys.argv[1]);import kaname.server;from kaname.user_enrollment import UserEnrollment;from kaname.device_auth import UserKerberosSessions',str(candidate)],check=True,timeout=30)

def ready(version,files):
    for attempt in range(30):
        try:
            if UPDATER['health']('10.35.50.246',version,hashlib.sha256(files['kaname/device_client/AuthWire-Client.ps1']).hexdigest()):return
        except (OSError,ValueError):pass
        time.sleep(.25)
    raise GuardError('PANEL_HTTPS_HEALTH_FAILED')

def apply(files,helper,statements,expected,workers):
    old={n:trusted(ROOT/n) if (ROOT/n).exists() else None for n in ALLOWED}
    changed=any(old[n]!=files[n] for n in ALLOWED)
    old_workers,old_release,candidate,new_release=workers
    worker_changed=any(old_workers[n]!=candidate[n] for n in candidate) or old_release!=new_release
    if not changed and not worker_changed:
        install_schema(statements,expected);ready(version_of(files),files);return False
    for name,data in old.items():
        if data is not None:
            target=EVIDENCE/'source-before'/name;target.parent.mkdir(parents=True,exist_ok=True,mode=0o700);target.write_bytes(data);target.chmod(0o600)
    touched=False
    try:
        helper['command']('/usr/bin/systemctl','stop','kaname-lab.service');touched=True
        with file_creation_mask(0o022):
            for name in sorted(ALLOWED):write_ui(ROOT/name,files[name],helper)
        for name,p in WORKER_PATHS.items():helper['atomic_text'](p,candidate[name].decode(),mode=p.stat().st_mode&0o777)
        helper['atomic_text'](RELEASE_PATH,new_release.decode(),mode=RELEASE_PATH.stat().st_mode&0o777)
        install_schema(statements,expected)
        helper['command']('/usr/bin/systemctl','start','kaname-lab.service');ready(version_of(files),files)
        return True
    except Exception:
        if touched:
            helper['command']('/usr/bin/systemctl','stop','kaname-lab.service')
            with file_creation_mask(0o022):
                for name in sorted(ALLOWED):write_ui(ROOT/name,old[name],helper)
            for name,p in WORKER_PATHS.items():helper['atomic_text'](p,old_workers[name].decode(),mode=p.stat().st_mode&0o777)
            helper['atomic_text'](RELEASE_PATH,old_release.decode(),mode=RELEASE_PATH.stat().st_mode&0o777)
            helper['command']('/usr/bin/systemctl','start','kaname-lab.service');ready(version_of(old),files)
        raise

def restore(files,helper,previous,workers):
    helper['command']('/usr/bin/systemctl','stop','kaname-lab.service')
    with file_creation_mask(0o022):
        for name in sorted(ALLOWED):write_ui(ROOT/name,previous[name],helper)
    for name,p in WORKER_PATHS.items():helper['atomic_text'](p,workers[0][name].decode(),mode=p.stat().st_mode&0o777)
    helper['atomic_text'](RELEASE_PATH,workers[1].decode(),mode=RELEASE_PATH.stat().st_mode&0o777)
    helper['command']('/usr/bin/systemctl','start','kaname-lab.service');ready(version_of(previous),files)

def main():
    global PHASE,EVIDENCE,UPDATER
    if os.geteuid()!=0:raise GuardError('LOCAL_SUDO_REQUIRED')
    import fcntl
    descriptor=os.open('/run/kaname-lab-update.lock',os.O_RDWR|os.O_NOFOLLOW)
    with os.fdopen(descriptor,'r+') as lock:
        info=os.fstat(lock.fileno())
        if info.st_uid!=0 or info.st_nlink!=1 or info.st_mode&0o077 or not stat.S_ISREG(info.st_mode):raise GuardError('PRIVATE_UPDATE_LOCK_REQUIRED')
        fcntl.flock(lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        PHASE='preflight_helpers'
        UPDATER=load_pinned(ROOT/'tools/linux_update.py',BASELINE['tools/linux_update.py'])
        UPDATER['safe_tree'](ROOT,owner=0,quarantine_bytecode=True)
        files=UPDATER['verified_files'](STAGE,EXPECTED);source_check(files);preflight_import(files)
        # Use the candidate snapshot projection without importing writable staged code.
        import sys
        sys.path.insert(0,str(ROOT))
        statements,expected=plan_schema(files);workers=worker_plan(files)
        worker=load_pinned(WORKER_PATHS['scheduled_backup.py'],hashlib.sha256(workers[0]['scheduled_backup.py']).hexdigest())
        worker['db_fingerprint']=projection
        before=snapshot(worker)
        if UPDATER['radius_process_guard']()!=before['pids']['authwire-radius.service']:raise GuardError('RADIUS_PROCESS_CHANGED')
        target=Path('/var/lib/authwire-updates');target.mkdir(mode=0o700,exist_ok=True);worker['private'](target,directory=True)
        EVIDENCE=target/('user-panel-dev32-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]);EVIDENCE.mkdir(mode=0o700)
        worker['atomic_json'](EVIDENCE/'before.json',{'release':RELEASE,'manifest':EXPECTED,'snapshot':before,'full_backup_requested':False})
        for name,data in workers[0].items():(EVIDENCE/(name+'.before')).write_bytes(data)
        (EVIDENCE/'backup-release.before.json').write_bytes(workers[1])
        emit('USER_PANEL_PREFLIGHT',protected_radius_source_identical=True,radius_active=True,service_pids=before['pids'],planned_radius_restart=False,user_profiles_created=False,full_data_backup=False,evidence=str(EVIDENCE))
        PHASE='panel_health_before';measure('before')
        if snapshot(worker)!=before:raise GuardError('PREPARATION_STATE_CHANGED')
        previous={n:trusted(ROOT/n) if (ROOT/n).exists() else None for n in ALLOWED}
        PHASE='source_update';changed=apply(files,UPDATER,statements,expected,workers)
        try:
            PHASE='preservation_after';source_check(files);verify_empty_schema(expected)
            after=snapshot(worker)
            expected_files=dict(before['files'])
            for name,p in WORKER_PATHS.items():expected_files[str(p)]=[hashlib.sha256(workers[2][name]).hexdigest(),*before['files'][str(p)][1:]]
            expected_files[str(RELEASE_PATH)]=[hashlib.sha256(workers[3]).hexdigest(),*before['files'][str(RELEASE_PATH)][1:]]
            checks={'protected_files':after['files']==expected_files,'pids':after['pids']==before['pids'],'timers':after['timers']==before['timers'],'preexisting_business_state':after['business_state']==before['business_state']}
            if not all(checks.values()):raise GuardError('USER_PANEL_PRESERVATION_FAILED')
            if any(trusted(ROOT/n)!=data for n,data in files.items()):raise GuardError('INSTALLED_SOURCE_DIFFERS')
            if UPDATER['radius_process_guard']()!=before['pids']['authwire-radius.service']:raise GuardError('RADIUS_PROCESS_CHANGED')
            PHASE='panel_health_after';measure('after')
            verify_empty_schema(expected)
            if snapshot(worker)!=after:raise GuardError('STATE_CHANGED_DURING_HEALTH_CHECK')
        except Exception:
            if changed:restore(files,UPDATER,previous,workers)
            raise
        result={'verified':True,'version':'0.14.0-dev.32','release':RELEASE,'changed':changed,'checks':checks,'radius_active':True,'radius_restarted':False,'radius_process_preserved':True,'broker_process_preserved':True,'backup_workers_updated':True,'user_schema_added':OMIT_NEW_USER,'user_profiles_created':False,'policy_changed':False,'certificates_changed':False,'windows_endpoints_changed':False,'machine_client_changed':False,'ad_gpo_changed':False,'full_data_backup_created':False,'backup_timer_preserved':True,'operator_browser_acceptance_pending':True,'real_endpoint_acceptance_pending':True,'evidence':str(EVIDENCE)}
        worker['atomic_json'](EVIDENCE/'finished.json',result);os.sync();emit('USER_PANEL_FINISHED',**result)

if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('USER_PANEL_FAILED',phase=PHASE,category=type(error).__name__,guard_code=getattr(error,'code',None),evidence=str(EVIDENCE) if EVIDENCE else None,exit_code=error.returncode if isinstance(error,subprocess.CalledProcessError) else None)
        raise SystemExit(1)
