"""Pinned installed dev42 -> dev42 typed combined verification jobs; panel and backup worker compatibility."""
from contextlib import contextmanager,closing
from datetime import datetime,timezone
import ast,hashlib,http.client,json,os,pwd,re,sqlite3,ssl,stat,statistics,subprocess,tempfile,time,uuid
from pathlib import Path
ROOT=Path('/opt/kaname-lab/source')
STATE=Path('/var/lib/kaname-lab')
PHASE='preflight'
EVIDENCE=None
UPDATER={}
OMIT_NEW_USER=False
USER_TABLES=set()
APPLICATION_DATA={STATE/'secret-store.key',STATE/'radius/server.pem',STATE/'radius/server-key.pem'}
class GuardError(ValueError):
    def __init__(self,code):self.code=code;super().__init__(code)
STAGE=Path('/home/segmentiq/authwire-stage-dev42-375677c9bd73')
EXPECTED='361af5e19eeabcc1fc526d4f444d23b25966d8df4dced19f9715dec00ffbbdf2'
RELEASE='375677c9bd733cae0f25fd6fc59c0ea826b25f78'
BASELINE={'kaname/__init__.py': '6c060e53ece96d65b924a9df7b785a6ae86fda6640e1cd68c8eb38f180cffa90', 'kaname/__main__.py': 'e01ee55f671609348749b7c045e1cd0cfed825fe172a1fa0435c58e4bd76907a', 'kaname/admin.py': '0bf936500b37607c22915337a45593fd6078a398763526ca021afb7c46295f19', 'kaname/audit.py': 'fe5bc68873ed722082e26b0d94df8f1c0d42f8e778aef4b14a57df1578491751', 'kaname/candidate_jobs.py': '086c08f9f67824ac771e765eb3519f548c34f57eeca61532b31427d4331dde09', 'kaname/connector_channel.py': '1b415b438e6f3467ac6cc88e9dc992cee8ed3c59731594eaa428b538b8932103', 'kaname/connector_jobs.py': '0fe8cd3e4470def0febb970990f5b1b2d6bd129a3cdb72e689c159dd26b130cc', 'kaname/connector_registry.py': '01e716304696ff11fdfbfcb279e60daffcec0ea3ca6c11e4fdd6ea7807a82fb2', 'kaname/dashboard.py': '882478cead34aba9347df236556be8a23686f7a3cd2aa70740b23ec5064616f2', 'kaname/deployment.py': '121aaa19486bf9e68463d041f34267a9ac7af98ab0207a689c97604d85296611', 'kaname/deployment_candidates.py': '7ebce643fc3964e2254a8af116183edfe0e356d961216adfe7da76eb67a40b02', 'kaname/device_auth.py': 'fefe6b58dfd916a49fcdbf825ddbbe54e021b8794f8a471b13a62308cb874de4', 'kaname/device_client/AuthWire-Client.ps1': 'bf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60', 'kaname/device_client/AuthWire-User-Client.ps1': '79437154e5f3938504b2e1c8d8dd8fe17cc2a16a9fcfdbb1cf54a8e36ac08124', 'kaname/device_client/Install-AuthWire-User.ps1': '564ba42e4b1803551d653658c4aa88c3c8efa034949d824c50982ca048a4d008', 'kaname/device_client/Install-AuthWire.ps1': 'faec4a852f61528b8e8df9ab6240323ab4cedae497cadd921568ccf06dac3609', 'kaname/device_enrollment.py': '9d8b1c60167686330f0e1c2b7fa82ba0e3e8b265271235eeb78ff19302a5d300', 'kaname/directory.py': '8e73ec0e4f4a7837d098f4a1433857b4b29e01ea768e6a69c6b95b347986e8f0', 'kaname/directory_linux.py': '2ae83ca4ab7a7a69169c7b5e2b5079654cd69468afbc5cb2a0d0f6e9fcb90a16', 'kaname/directory_linux_helper.py': 'a3225f791cc6887386118b31ca99585a2a73859dcd47935f33bea23cdec7a0e7', 'kaname/directory_sync.py': 'e5769d5f79a188f7ebcccefa88073ac2feec91a55b7448291af67a214021220a', 'kaname/directory_windows.ps1': '199bce5da72e3d2277bd27b6a3318f4d0fac1335e3e7d5aeccfda5ae761bd3e3', 'kaname/enrollment.py': '90570901d12047993a8cda63ec34956a4927eb6d1a9f6051d08b53b1f12a4587', 'kaname/membership.py': 'ff8dea55bc79fbc750cb2216afafd069fa86e1fd2408910cbcddce204f5feead', 'kaname/models.py': 'cd5af23115c1d4bf8b95e09b15f4a5d41a3d91646b4f7a3c6802901430de814e', 'kaname/operations.py': '5d42b9e9d59ba2b7d47e5ff68c6928205ffa37b1bb3cec41d32f5367a2e84beb', 'kaname/pki.py': '1ccf775e7ad390e40e56ada967cdd387ea96d12fcac2ce6cbf12f420260f28da', 'kaname/planning.py': '9235ff11f3cef34fea918b8ee5237e251f9f60a31a1881a1ecf4cf33bc085814', 'kaname/policy.py': '180f10997b365fc1b4ce8b18c6688c8ef21e4a9a019adb1db85a194568897555', 'kaname/radius.py': '64095bd5a4ac3e32331fde4e945aeceba6c9a824857e91f0e135b280f9debe6b', 'kaname/radius_adapter.py': '5b8c123d290009f721785c19ab2c36ec608446b6ed6a08e1b119a3a0a9a97f33', 'kaname/radius_directory.py': '6f8b92c698a1a9ce32b0194798cf34ea5df3d030ea9182b8027f7b076feaee5d', 'kaname/radius_events.py': '563dc2051dae8871dcd655cd23c2796ffd60ca999a0624d023bf2af12e0b1874', 'kaname/radius_observer.py': '52c83f27953d79dfe291683292f45fc0f14b500896440017053dd8804d2c8c30', 'kaname/radius_registry.py': '1f1c14bfedd19f2ce2fe08cbc95c785805d13d873c135fe73f90bcb980b1304c', 'kaname/resources.py': 'c410c83b1c5414fe084247d21b06c1cef046271a3c8b7ff53209e4cc0a6d4557', 'kaname/scope_jobs.py': '1233ce0f245e8f5627259531cb5353a903bc2f63c7bec4700bacd5fafbb7ca0a', 'kaname/server.py': '5929a41ae442c51b2d9e148aa4ced317c32d2d6b7561bf8e2b47921e9c99d70f', 'kaname/services.py': 'f7d6b1643f22300835e579dea38ccea1a4f7eeba26df52979e5b187887313701', 'kaname/static/access-events.js': '78dfa22aa789fa769106b8b0077ce6503adffe98b28931ab81355ef878aae553', 'kaname/static/app.js': 'b7e726d12106be3a61a5f883b8c23eed250fe0ab63abc732fd791d197d7183c9', 'kaname/static/audit.js': '7453d6085f52d2f17540b9beb4d984a52e9ae41153c7cbd18383631fac900f6e', 'kaname/static/authwire-logo.png': '677e49220d7ca57376735a9792b8067e8aaca223ee73806d91ff3dc1eb8d728e', 'kaname/static/dashboard.js': '9383e03df82dabd6b5fe58731322782031ca4f6dadef3b07efa9f42e0cbfd054', 'kaname/static/deployment.js': 'ddc7ade941621230c6f1f99d092864c9116601fd01b89f91f8d8eab5d50a23ab', 'kaname/static/device.js': '089aa7e989a30ab00e4a0b3c6b96e907c8b3f049a40ecd2f29cfc1040c6ea4fd', 'kaname/static/index.html': 'a2de1dca941bd4f872fb94d14f76dbeaa98e2c67be990bbd291329a080fde7dd', 'kaname/static/planning.js': 'f02cacca6d73eca33a6d82a678d5e91c16100d09b24d1734c37c953cacecac2a', 'kaname/static/services.js': '209c9b1a9bb6370cfed1d3271b70fcaf6a02c5678137edfab5ce70c19d54c8c6', 'kaname/static/styles.css': '2d4a49e8abbf17e1abb290da8e6234af0a99873b688e8576681b0246069b280e', 'kaname/static/user-enrollment.js': '120cdfb99f1eb9032f056b4cda4b9dc65aa8790af7cef86562074c35cb4d9aef', 'kaname/store.py': '0107e59ccf292516946bb3a0d7fd0172a5522e5352360f923bcd37fefb78d921', 'kaname/user_enrollment.py': '5dbf6aad6338510616e60214ce6b4711e8d2ed000d2a893704ddee1748fb7924', 'kaname/vault.py': '9272bb391dd5eac66e46bef63417e13987a1f83151a97c4899a8297b6841a0fd', 'pyproject.toml': '3ed3e603d35dc84ec709e6eae2f7db025cbb8dbb37204706861ed20378652a74', 'tests/__init__.py': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'tests/helpers.py': '4233f0211a88efa600379ea01592fcb3a51a0f1f2d0fe6c1c317693a6ebbaab5', 'tests/ldap_fixture.py': 'e52929ea4e8a294a1b4d138d10ff7c9598cb360512762f06faf2860bcfe7098d', 'tests/radius_fixture.py': '0a0138421fa38959e479c102ee1a32dfa33a5552c742c37da0baa2a46fa2333c', 'tests/test_admin.py': '10d8c3f86fc6a199f73cb4feb399915150f89628796060beb76b7bd92650fa1d', 'tests/test_audit.py': 'a021c7da61e454b26b680d12c2076fd2cfe004d0ac24e39effdbc3fadbb1040b', 'tests/test_connector_channel.py': '80a704de4d1bc4e675dbb488575315cd4cb718345835cc3271732d6b0b226473', 'tests/test_connector_registry.py': '7112c2c1d6cf7f371e6fcf3dc8b7903ae1c9b72e059b7081a439e74e1610c6ec', 'tests/test_connector_registry_http.py': '44cb52b42c81def04d01afc3813247538ecb9ed536f3c49844e95dbd8ddc0cdc', 'tests/test_connector_transport.py': '814dbace8d3f2c3082c72a700379971435d081a70605bb26e8e1cfd3ff4980f8', 'tests/test_dashboard.py': '948647e39494aa3df495cfe5581588ae1c7f4de8a75f92577289dec0baae80bc', 'tests/test_deployment.py': '02c7d46e8270be99a714ef2adefd5cb94ac6ace6cc47d4e6cb287db4ad831149', 'tests/test_deployment_candidates.py': 'fbcd5e80d38ab69753177d6a95476f4cb75d6e6857482e97683ceaa9fb13ee6d', 'tests/test_deployment_candidates_http.py': '23eae69fa3c4c7d84ef2ab4f1f02994f5a03043fd8e3734e4d718a21b8d33048', 'tests/test_deployment_http.py': '0c38fb78dc36352d4afc9e794a29060d3cc483cfb0c92882855a4af0b2e7ed1a', 'tests/test_device_auth.py': '00b6417089fe084fc33d1b9ffdbc38d89f4777a5d81991d7ad385bd297503a31', 'tests/test_device_enrollment.py': '8b20268922af94e601965bc5593a08ae76a0bba99fc35fa0fbf5d87be52358aa', 'tests/test_device_expired_fixture.py': '134488bfe60bf18e7d06a7908a6edb228720aacbf396dcb0d98bda3aa3440b98', 'tests/test_device_http.py': '7fe6d0cc4662450062d1e26a092d4f4eb912c14b7580aa26971e6d69232bdf7a', 'tests/test_directory.py': '6ae80aa1843d66c3465cfeeb57dfd5b64be6bdc00cacdd72ed7a8ff0bb50df0b', 'tests/test_enrollment.py': '09d310a25b40e29a297d4cc61f2ca44da346d4f5f87e1118f3ffc7c4c961d672', 'tests/test_enrollment_http.py': '99bc93d1f3c939673b41b5464a3004697c3c121677d9bcb5e16defc91665f285', 'tests/test_expired_recovery_deploy.py': 'f9bd180235f299fc70967d547d5adc65d5728c356e37e447c8e6ee6052d8fab8', 'tests/test_host_power.py': 'b426a68a29f6e964c9be8f2e3c1421341f42aaf5cfd43939bfc81c02e4a2bef9', 'tests/test_http.py': 'f3059e53d7ee654ae3670479a2ea9935f939503310be290bcfe765b2533ed7ee', 'tests/test_linux_directory.py': '605fa7f32743e49a9fbbd4713b898481f02d8bc9feff193443cee61b3dfae4b8', 'tests/test_linux_install.py': '0ad196ffb318a762f6ef7c004d675bde2536ce8cc854f48b6d922ecb4feaa73e', 'tests/test_linux_update.py': '383b8bc4dc7da5c52520e2f7603f6c6491fc8ba9a086b33c4dadbd5291ec31ee', 'tests/test_local_group_feature_removed.py': 'f5e21efc287a5d6496168477bf77854a0b6f1464cc81d5243c92312ff886ee32', 'tests/test_management.py': 'e3efc868afe96cd70ba0cdd57b30a6fdfe7f99735915a033642f821c986af3e5', 'tests/test_membership.py': 'c12840f56a30fcc4801432951477659062b006a85232c8ca5ebabfc1ef3bff93', 'tests/test_offline_restore_check.py': '9e51bd67aaab5970c577bcf70c44f93553d733fa41b9665294454a679b5dcd41', 'tests/test_ovf.py': '50a9d7bc9d9904a18b8048f217ddbc44065e36a9137b5bbc3c1e26545e748d10', 'tests/test_pki.py': '338fbb873d989d2f648a8a3dc0843a3b4d0bf9759f25b052dd7686a974c25b90', 'tests/test_pki_cli.py': '6ba4cbee1e94ad019521f6d9c83ff210627bf17fbf100a727137dab2a34db05e', 'tests/test_pki_http.py': 'e4aa1cc56b7138c35789e8ded2e00bc468e6bbb275a66572b0106d11a38d0e92', 'tests/test_planning.py': '1e281eab0ea24d8526a9b33c8222e93ba35f007741537b102c67e92b9a213089', 'tests/test_policy.py': '439ac79cd5a7e2483f5d4d47dc0609c01f51ff93ca8751f01d4a5f14ea823f14', 'tests/test_policy_identity_http.py': 'f0b946f6d2dcdfca3d9e43d89e176ec0548da0afce18e46b2be7124b264871db', 'tests/test_policy_identity_scope.py': '9d42f66f2df9fd34ce6f2acbb062f6753aa41001f1449419a97aeb2f19edd799', 'tests/test_policy_toggle_deploy.py': '2e16679a0d0920822297249d70738d37accba1b62abfe482a5a6e96ca3a113d2', 'tests/test_principal_policy.py': '07476cb05da8bef4f67792f0debd7ec0eeab29b8fb4efe2f72ab054443f718d8', 'tests/test_radius.py': 'f7c083715d2558b8e7516021d9da07764cdef2fc6c4d5b40c349b9d21cc034dd', 'tests/test_radius_crl_install.py': '727ee23fc40795dbead6c6dc4968f177d7dfada54e1cc7d1170e22de982f2b8f', 'tests/test_radius_crl_sync.py': 'bd2392a049e4dccd360577f06377fdf60f07e92aa0df5d5b27ab474ee357f58b', 'tests/test_radius_events.py': '163b956bc730c9d1773c6a3a4c42076b59a03ade976eaf528f4db15cb087a644', 'tests/test_radius_events_deploy.py': '680866bfc284e35dbe5457fb60389c99930460828021cb9f9c8181fda4ed0036', 'tests/test_radius_events_install.py': 'e4a7d1fe17e7eb3d7eecb8a5c0e2b81cc21cf1924f1cdf61392854a2833ae5ed', 'tests/test_radius_lab_paths.py': '72068e0a61df99b26a9be8e3ef6390df6759640847e9212b839b8d3e5e610efc', 'tests/test_radius_live.py': '4bea7038075b62f1db0b80abd74f75579d7fae03363b1b336c89dbfa4ac8b9c3', 'tests/test_radius_module_update.py': '6ced1e3f1ac9d8489a542f9c4915a17fb42ed3620bb5e27de99022e4aa38bd2b', 'tests/test_radius_packets.py': '9a419df7d1f87bcaa5feab9e4bacd30c22e8fadd5e8f9887c7fad6873e9f15e3', 'tests/test_radius_production.py': '1fbbf86654df2b130f9aa7a7b7342a847dd6f86f8afe5b94a3b9d75a1c125aa8', 'tests/test_radius_unit_update.py': '81a1c883849ac5038976a6aa388b15d93afe7ca7c60f46efa12b66471dbe299f', 'tests/test_resources.py': 'f2a917045c2a5f494dc22e51dc6711d226ead7f67187ec7766ca824b5b506d84', 'tests/test_retry_deploy.py': '00b5b7550ef4ce5fa5dfd61ec354e72a75e9e95a974b428a3e1c027ce07b621b', 'tests/test_retry_network_probe.py': '894a1a472e1e8a091ee22a0d2820458eb0b590e04915d2ed4f78291e83900171', 'tests/test_scheduled_backup.py': 'b75eddafdc5eadbfd337ece382212c5754d91d02a5ba079552c81423d8157846', 'tests/test_service_control.py': '318df099b9ebcff80aaee86061d5eebed50c10c7a25430e91ab7b88701ddaec7', 'tests/test_startup_deploy.py': '4c5c339d18ab26b0d1ac6afea1249f6ce02bf75470405046575aa8623061cd3e', 'tests/test_store.py': '8da8efb6fd5d920cac82e74e6551a6864ad1bb4bda53208333be034bde65b4c4', 'tests/test_user_client_package.py': '41b0a3edcba70172f0334e693080fcbaf144aabf7fc29ac465a3a58bcdabafef', 'tests/test_user_client_package_http.py': '78ae0d0e826a6564d89cf3e720ddcb0d7d5d0c8adaacc4331c7f83aa674c1779', 'tests/test_user_directory.py': 'e8a72f05543671778429ff55b1ba2a4fdaa93f1eef78dad37c9992c45db3b0b3', 'tests/test_user_enrollment.py': '250c28b29ed4e933eab8b93152050446bf4a10fb6ed5678c7ef278c9a66c28f5', 'tests/test_user_enrollment_http.py': 'e08ec3401e74f8eb0bcb6c6c7cbfdf06af66c44235b18564466423124e165498', 'tests/test_user_panel.py': 'b90183d3362b6040cbccf1725e4196f6ec08353e65dc8839551d751138fb5c77', 'tests/test_windows_diagnose.py': '54b196ab794bc93dc3ea85d0d31584adf0375f5cd6651819ed038b469bc4846c', 'tests/test_windows_update.py': 'd5cf63eca677bfd3ffbdb7b03d7499cbfcd445d89dc71560eadc3bd95454c203', 'tools/AuthWire-GPO-Audit.ps1': '3211b09a844cf3c4bfabc6263f7e549451e87c0ad42ccc02c22b1b1dfbdff88d', 'tools/__init__.py': '7e41a692ddeb7ca616af6038aa8b2d8b14aa1699216b213caaee860937d31403', 'tools/backup_install.py': 'ed18f5c0c3e65aa6d2a6fe8311ddd1fa604b128c724e5854214e986118faf347', 'tools/backup_systemd_check.py': '654c0389375251d42a28be89c472cb8822e606ba7fd44240a8a2b66f1827eb24', 'tools/client_request.py': '86d3d9822451f4239f6316f236b6cfa59ed748c1990ed06ca212b7581a9afedd', 'tools/deployment_candidate_ui_smoke.cjs': 'dffa03ae591d76642844d334f86245179c4ad42dab8d7038f53208333681e178', 'tools/device_expired_client_harness.ps1': 'f81bb0d9318147b64f39979c7f02ce18244bad9ec38ef670995e13861872e2cb', 'tools/device_expired_fixture.py': '85237cd78e7eee42f5f623252ec115dd1bc1113755de172f8af130629d98bdf8', 'tools/device_expired_windows_check.ps1': '66b2756dcce8af3e6cf4cbf4815916232c75b9fce965f8e8915f9d0d1625af1a', 'tools/device_fixture.py': '61d4a7452eaa97dfdadb161527195c0cbb440702c06d28ef0cfeae04ef170c81', 'tools/device_load_smoke.py': '7e6aff546471c4ad7f1b476d5e30a3185e0fcff753a24936f1fdd6e40b537439', 'tools/device_retry_windows_check.ps1': '744d5425171b15c5b5a0910f69c8aabd3d09656b278fa7124a33766fedef7428', 'tools/device_startup_windows_check.ps1': 'ef49621d05b84b25093387adf19c4d6e6f82aedbf1a5acbab13c7944c577b696', 'tools/device_windows_smoke.ps1': 'b4a241212f7ece0a940900214b7550f580a5e02debd3ddfdb625ed186d1ab535', 'tools/export_appliance.py': '35ba5228947787ac89cf9f45f1f4961d1bdf1c82cc235568e4c547c48bba54d7', 'tools/gpo_audit_fixture.ps1': '1a1221643b9998c928fb0281c5958570ca462137e9537823e254368fbdcddf50', 'tools/gpo_expired_update_fixture.ps1': '4d638f10de52bf9ef1548308196e6f51769e33b0a65543023f8b71a369063d4c', 'tools/gpo_installer_update_fixture.ps1': '997a5069bd125436698d8fbee378f44d8f6da498093e6973dbd1c8d675352f96', 'tools/gpo_retry_update_fixture.ps1': '50c20abb79c4b43b5ff46e2f37a4d2e2767310be6052b5e80ab954b07bebf64d', 'tools/linux_authorization_check.py': 'f719e1716590764df479ebb44a2a0ab02704a68fb3993357d91932fd5fc9a5c0', 'tools/linux_device_setup.py': '98e3f069b1a27755749c903ed7d7bda27737b26a277d1d6228db63cee4918648', 'tools/linux_initialize.py': '525fe5d380829bb3d93f11d374651c98dda58b30022599389043760896c7fbd5', 'tools/linux_install.py': '3623c91616f3e35ae61e7ad5acbc3482ec76071d3a5ba73020f7980f2e783365', 'tools/linux_install_smoke.py': '268b2958e04585e4f7e389a6c6fbbe775601405657a97e137976c81f4bf4fb4b', 'tools/linux_prepare.py': '90da15eb52d658fe35782be00041ec7d0cf6705e3bce9589d145cb04f08cdd76', 'tools/linux_update.py': 'd168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe', 'tools/offline_restore_check.py': '8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5', 'tools/package_source.py': 'cf217f7259a819603df28ecff9f6cc4c622a64c5fdd653dbf56c69a7fb38b72d', 'tools/radius_crl_install.py': '2b10abf6bbbdb9d4ee5e542d6938ef354ce094e6cf9330bb3da923a61e2e2a8c', 'tools/radius_crl_sync.py': '580da79bc8c18b10f3c4551768954dde9f9470170451ee2fce127c60d73d2559', 'tools/radius_crl_timer_check.py': '38b18baa708a26b740ea0bfeb07cbb7adeed8628a06ffe39aa3115186403b22b', 'tools/radius_events_config.py': 'd587aa0abd803bd2124c3924cfe63da37d07638119feb52fdae76b9640bf66be', 'tools/radius_events_install.py': 'cf48407870d3973af8b9d5f090b730110f15224edb9a4f6ef33bd8bb1a4b0b8f', 'tools/radius_events_systemd_check.py': '20cc29db8f00e630350e6a228ea91da1ee5b72c7e776d93a26880ee119e6f771', 'tools/radius_initialize.py': '8ce73e33fc8b4201bb16cba85978b10122ab7161f33aab796f29c036d470447b', 'tools/radius_install.py': '63045293fc7a4d62d13d69921a2aa4d3e0242dacde9190ac286ec7a8ebcf3233', 'tools/radius_lab.py': '67b35fe98236eeb7c0dc58fd882638174d92992732ac188e869b0d3d62806f19', 'tools/radius_module_update.py': 'ad5a848ae0d9819e8abe64cb14c420f8799ac67c2ee84609c71b3dcbaac51881', 'tools/radius_native_check.py': '96be8588b8ca30c5ba1c24d37fe0d56bd02f9eb09ae70193a73051c35de79e96', 'tools/radius_prepare.py': 'f9f2d87143365ba701b72446383b536cb5478ddc31e267c6b67f252f9a8a6640', 'tools/radius_runtime.py': '2cdf26595b0f06601b7dd858af102d381a33fb8155458c5189de6a0c03c38738', 'tools/radius_service.py': '7a0caadfb496ac5cc769a6903adc3f0e0f617e443668a6db01b7f37b17199f63', 'tools/radius_unit_systemd_check.py': '51391ca56cce67bdb4458076a241018a019267ae7a0b1af0cc30c55eb19f0fa4', 'tools/radius_unit_update.py': 'c9d4e9daa02d9c42fa7697ce04a9e8caeb6c6190addce3f37daf698e61934526', 'tools/retry_network_probe.py': '8152fb58f5a00e87c57995242eb2f9d40838b3e5b09e3eeea3020f582c396614', 'tools/retry_probe_native_check.py': '2cf726736145de974ec6283ae0c462219a8f0d2b646ce168da26f5c645fd4924', 'tools/scheduled_backup.py': 'c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c', 'tools/service_control_broker.py': '283651f5d3105e8b915bdbf2f15977ec1038471081fcc1f7f5547c5c94d690d2', 'tools/service_control_install.py': '08f809038c65b63c983e7c69466b4a357f58d0819966c36e54ab2cde73cb9bc1', 'tools/service_control_systemd_check.py': '9c6addaa96569a10ad21cfb2f88f594889808312650d8696a88073b325e08086', 'tools/user_client_fixture.py': '5010b536e04a95d37061865259b1fc4f74ede1f6c08ceab93174295e85a4ba09', 'tools/user_client_windows_check.ps1': '4225530c7a9e70c41fd3248e70aaec06472ee725db5aba5d784a0ceca029756e', 'tools/verify_ovf.py': '10e08fe6f6945d568c1a6a88f8262f3a2879833f829262f8536ba89607c0c12b', 'tools/windows_diagnose.ps1': '257ad0e9d737ea0ad75092e094d7e712bdf3b17a43439977c37efdae3906a553', 'tools/windows_diagnose.py': '3e1c33600cce117b70d14e1c05b64c94194f2e7e8eea55fd7791102468f00253', 'tools/windows_update.py': 'ccdeb93b75f832b6bfc667691b41d322c41733742407c323b0749b9d73230528'}
ALLOWED={'kaname/server.py', 'kaname/combined_jobs.py', 'pyproject.toml', 'tools/scheduled_backup.py', 'kaname/__init__.py', 'kaname/static/deployment.js', 'kaname/deployment_candidates.py'}
NEW_FILES={'kaname/combined_jobs.py'}
REMOVED=set()
PROTECTED=['kaname/__main__.py', 'kaname/admin.py', 'kaname/audit.py', 'kaname/candidate_jobs.py', 'kaname/connector_channel.py', 'kaname/connector_jobs.py', 'kaname/connector_registry.py', 'kaname/dashboard.py', 'kaname/deployment.py', 'kaname/device_auth.py', 'kaname/device_client/AuthWire-Client.ps1', 'kaname/device_client/AuthWire-User-Client.ps1', 'kaname/device_client/Install-AuthWire-User.ps1', 'kaname/device_client/Install-AuthWire.ps1', 'kaname/device_enrollment.py', 'kaname/directory.py', 'kaname/directory_linux.py', 'kaname/directory_linux_helper.py', 'kaname/directory_sync.py', 'kaname/directory_windows.ps1', 'kaname/enrollment.py', 'kaname/membership.py', 'kaname/models.py', 'kaname/operations.py', 'kaname/pki.py', 'kaname/planning.py', 'kaname/policy.py', 'kaname/radius.py', 'kaname/radius_adapter.py', 'kaname/radius_directory.py', 'kaname/radius_events.py', 'kaname/radius_observer.py', 'kaname/radius_registry.py', 'kaname/resources.py', 'kaname/scope_jobs.py', 'kaname/services.py', 'kaname/static/access-events.js', 'kaname/static/app.js', 'kaname/static/audit.js', 'kaname/static/authwire-logo.png', 'kaname/static/dashboard.js', 'kaname/static/device.js', 'kaname/static/index.html', 'kaname/static/planning.js', 'kaname/static/services.js', 'kaname/static/styles.css', 'kaname/static/user-enrollment.js', 'kaname/store.py', 'kaname/user_enrollment.py', 'kaname/vault.py', 'tests/__init__.py', 'tests/helpers.py', 'tests/ldap_fixture.py', 'tests/radius_fixture.py', 'tests/test_admin.py', 'tests/test_audit.py', 'tests/test_connector_channel.py', 'tests/test_connector_registry.py', 'tests/test_connector_registry_http.py', 'tests/test_connector_transport.py', 'tests/test_dashboard.py', 'tests/test_deployment.py', 'tests/test_deployment_candidates.py', 'tests/test_deployment_candidates_http.py', 'tests/test_deployment_http.py', 'tests/test_device_auth.py', 'tests/test_device_enrollment.py', 'tests/test_device_expired_fixture.py', 'tests/test_device_http.py', 'tests/test_directory.py', 'tests/test_enrollment.py', 'tests/test_enrollment_http.py', 'tests/test_expired_recovery_deploy.py', 'tests/test_host_power.py', 'tests/test_http.py', 'tests/test_linux_directory.py', 'tests/test_linux_install.py', 'tests/test_linux_update.py', 'tests/test_local_group_feature_removed.py', 'tests/test_management.py', 'tests/test_membership.py', 'tests/test_offline_restore_check.py', 'tests/test_ovf.py', 'tests/test_pki.py', 'tests/test_pki_cli.py', 'tests/test_pki_http.py', 'tests/test_planning.py', 'tests/test_policy.py', 'tests/test_policy_identity_http.py', 'tests/test_policy_identity_scope.py', 'tests/test_policy_toggle_deploy.py', 'tests/test_principal_policy.py', 'tests/test_radius.py', 'tests/test_radius_crl_install.py', 'tests/test_radius_crl_sync.py', 'tests/test_radius_events.py', 'tests/test_radius_events_deploy.py', 'tests/test_radius_events_install.py', 'tests/test_radius_lab_paths.py', 'tests/test_radius_live.py', 'tests/test_radius_module_update.py', 'tests/test_radius_packets.py', 'tests/test_radius_production.py', 'tests/test_radius_unit_update.py', 'tests/test_resources.py', 'tests/test_retry_deploy.py', 'tests/test_retry_network_probe.py', 'tests/test_scheduled_backup.py', 'tests/test_service_control.py', 'tests/test_startup_deploy.py', 'tests/test_store.py', 'tests/test_user_client_package.py', 'tests/test_user_client_package_http.py', 'tests/test_user_directory.py', 'tests/test_user_enrollment.py', 'tests/test_user_enrollment_http.py', 'tests/test_user_panel.py', 'tests/test_windows_diagnose.py', 'tests/test_windows_update.py', 'tools/AuthWire-GPO-Audit.ps1', 'tools/__init__.py', 'tools/backup_install.py', 'tools/backup_systemd_check.py', 'tools/client_request.py', 'tools/deployment_candidate_ui_smoke.cjs', 'tools/device_expired_client_harness.ps1', 'tools/device_expired_fixture.py', 'tools/device_expired_windows_check.ps1', 'tools/device_fixture.py', 'tools/device_load_smoke.py', 'tools/device_retry_windows_check.ps1', 'tools/device_startup_windows_check.ps1', 'tools/device_windows_smoke.ps1', 'tools/export_appliance.py', 'tools/gpo_audit_fixture.ps1', 'tools/gpo_expired_update_fixture.ps1', 'tools/gpo_installer_update_fixture.ps1', 'tools/gpo_retry_update_fixture.ps1', 'tools/linux_authorization_check.py', 'tools/linux_device_setup.py', 'tools/linux_initialize.py', 'tools/linux_install.py', 'tools/linux_install_smoke.py', 'tools/linux_prepare.py', 'tools/linux_update.py', 'tools/offline_restore_check.py', 'tools/package_source.py', 'tools/radius_crl_install.py', 'tools/radius_crl_sync.py', 'tools/radius_crl_timer_check.py', 'tools/radius_events_config.py', 'tools/radius_events_install.py', 'tools/radius_events_systemd_check.py', 'tools/radius_initialize.py', 'tools/radius_install.py', 'tools/radius_lab.py', 'tools/radius_module_update.py', 'tools/radius_native_check.py', 'tools/radius_prepare.py', 'tools/radius_runtime.py', 'tools/radius_service.py', 'tools/radius_unit_systemd_check.py', 'tools/radius_unit_update.py', 'tools/retry_network_probe.py', 'tools/retry_probe_native_check.py', 'tools/service_control_broker.py', 'tools/service_control_install.py', 'tools/service_control_systemd_check.py', 'tools/user_client_fixture.py', 'tools/user_client_windows_check.ps1', 'tools/verify_ovf.py', 'tools/windows_diagnose.ps1', 'tools/windows_diagnose.py', 'tools/windows_update.py']

def trusted(path):
    info=path.lstat()
    if path.is_symlink() or not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_nlink!=1 or info.st_mode&0o022:raise GuardError('UNTRUSTED_INSTALLED_FILE')
    if any(p.is_symlink() for p in path.parents):raise GuardError('UNTRUSTED_INSTALLED_PATH')
    return path.read_bytes()

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
    if label == 'after': paths += ['/api/deployment/candidates','/api/deployment/connector/jobs','/','/app.js','/styles.css','/api/deployment/connector','/api/deployment/status','/deployment.js','/api/user-admin/status?offset=0','/user-enrollment.js','/api/system/resources','/api/dashboard?period=7d','/api/dashboard?period=1h','/api/dashboard?period=6m','/api/dashboard?period=1y','/api/system/power','/api/policies/labels','/api/audit/history', '/api/audit/history?source=administrators', '/api/radius/events']
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

SERVER_PROTECTED={'development_token': '63cc0241ade64f9a32b4f80f1d78fc3340245ae9c1ff4620af3aae74a1c1966c', 'DevelopmentServer.__init__': 'a368773668312ee8da04ec7051161fac5cf119eb2b334604f6aae2d15da44a3a', 'DevelopmentServer.device_maintenance': 'e5492135bf04dcbb368fd0030de49a495e1796871bc4f7f4f4416d6f0907fb10', 'DevelopmentServer.server_close': '18e8102e03eb58eaef7f2a84937e707ff0976c677a7b0f4029192f9ad6e5c4ea', 'Handler.setup': '7124241f5c5086b8d58884a7835357e187f6b4cf71191d6871c54d800bc1b65d', 'Handler.log_message': 'e228fe743b11b2b5ea3a40ac5e4061f907436e61a0b1ea9df5af12af40efceeb', 'Handler.respond': 'e39250b861520d55cfe1b3871fb5651f0f676c03da5494ebb5b1cee936af20be', 'Handler.guard': '3c8aacac302d9d77765b5d78b2f1e000f2d14b7e0b9129f520c6f0a1b4cac052', 'Handler.session_cookie': '1c232a2b757925d012030dc8057abd72df2741e2041462c1e00077907cee4a3c', 'Handler.read_body': '3f92d80bd1e82ee7557911542cea19bccfd88b90f938699635207fc914f2845b', 'Handler.device_services': 'f16e6cc180ee57431b18b8aa4b553a978e4c6e968450de8a0de8811ddb097654', 'Handler.connector_services': 'fca452df88c19426269c5c34c2accce6b679f03ea0f1f2b7c995fe5f0caf15ce', 'Handler.connector_admin': '4a8ed7eef10df48b4b0a4f975c9b2aaef6a510301c985863a90e31a10c5118cf', 'Handler.connector_job_services': 'e2d08f3ac11cdf0dd1d1ff66f5df833a380345e1929c7cc6388bbee2798e76d9', 'Handler.connector_job_admin': '082da8be0513419cd0ff7cd985003e03a2bc70f2c1b0009f7e38382b8c5c505c', 'Handler.user_services': '386c4abcbc07842e359c6830dd36443d15f5a7c449d628e03c959f24986d4ba3', 'Handler.user_post': '8e9c55550d9e7c691920234d10cc0dbe42c702195aa74b281031d12300e6ab0a', 'Handler.user_admin_post': '0fc8361fee81f008f50ba4baf3ba1044857f53862842e26faece6271f267da5f', 'Handler.device_post': 'da5c7229c4fc0baaeb98e956cfdf5440cf26d1bc24763d4570b7b09478621622', 'Handler.device_admin_post': '5f7001453ac91853ff31bc37382c7fd21ab12faec630f8025fe2f58e6f0fd737', 'Handler.pki_write': 'da46d79cf64bb24e417f19e7682abc92cb7e5590aeb19d4ec77510af0bdc78f9', 'Handler.state_projection': 'e9773417d95e69d52a9ea42cc1aaddfc5e8c832587e4b10862fa181f94009fa2', 'Handler.store_error': '14831a892bca8d173bc8142dbfadc3d996b5c5ecd5b7b0bb8f9fb91e916892de', 'Handler.do_GET': '40536714030418079d0eadc866064aaf8081df1f53fde85cde0e630552a20ffe', 'Handler.get_response': 'e2839975c5ae74d6fae7b416c4583c5fad79832f6e8407834132b6a65bc0d92b'}
SERVER_FUNCTIONS=['DevelopmentServer.__init__', 'DevelopmentServer.device_maintenance', 'DevelopmentServer.server_close', 'Handler.connector_admin', 'Handler.connector_job_admin', 'Handler.connector_job_services', 'Handler.connector_peer', 'Handler.connector_services', 'Handler.deployment_candidate_admin', 'Handler.device_admin_post', 'Handler.device_post', 'Handler.device_services', 'Handler.do_GET', 'Handler.do_POST', 'Handler.get_response', 'Handler.guard', 'Handler.log_message', 'Handler.pki_write', 'Handler.read_body', 'Handler.respond', 'Handler.session_cookie', 'Handler.setup', 'Handler.state_projection', 'Handler.store_error', 'Handler.user_admin_post', 'Handler.user_post', 'Handler.user_services', 'development_token']

def server_guards(raw):
    tree=ast.parse(raw);found={}
    for node in tree.body:
        if isinstance(node,(ast.FunctionDef,ast.AsyncFunctionDef)):found[node.name]=node
        elif isinstance(node,ast.ClassDef):
            for method in node.body:
                if isinstance(method,(ast.FunctionDef,ast.AsyncFunctionDef)):found[node.name+'.'+method.name]=method
    if set(found)!=set(SERVER_FUNCTIONS):raise GuardError('SERVER_FUNCTION_SET_CHANGED')
    for name,expected in SERVER_PROTECTED.items():
        if hashlib.sha256(ast.dump(found[name],include_attributes=False).encode()).hexdigest()!=expected:raise GuardError('PROTECTED_SERVER_FUNCTION_CHANGED')

def source_check(files):
    server_guards(files['kaname/server.py'])
    if set(files)!=(set(BASELINE)|NEW_FILES):raise GuardError('SOURCE_SET_DIFFERS')
    if version_of(files)!='0.14.0-dev.42':raise GuardError('CANDIDATE_VERSION_DIFFERS')
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

VOLATILE = {'audit', 'admin_audit', 'access_events', 'admin_sessions', 'admin_login_rate',
            'user_enrollment_challenges', 'user_enrollment_rate', 'device_challenges', 'device_rate', 'pki_enrollment_rate', 'directory_catalog', 'sqlite_sequence'}

POLL_SECTIONS = frozenset(('windows_connector_probe_jobs', 'windows_candidate_verify_jobs',
                           'windows_deployment_scope_jobs', 'windows_combined_verify_jobs'))

def stable_runtime_payload(name, payload):
    """Ignore only validated transport polling metadata, never jobs/results.

    This projection affects comparison only. SQLite backup still copies the
    entire original row, including replay IDs and last_poll. Unknown/malformed
    structures retain their exact original bytes in the stability guard.
    """
    if name not in POLL_SECTIONS or type(payload) is not str or len(payload) > 100000:
        return payload
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError('Duplicate JSON key')
            result[key] = value
        return result
    def constant(value):
        raise ValueError('Non-finite JSON')
    def number(value):
        return type(value) is int and 0 < value < 2**40
    def hexdigest(value):
        return type(value) is str and re.fullmatch('[a-f0-9]{64}', value) is not None
    try:
        v = json.loads(payload, object_pairs_hook=unique, parse_constant=constant)
        if type(v) is not dict or set(v) != {'format','jobs','polls','last_poll'}:
            return payload
        if type(v['format']) is not int or v['format'] != 1 or type(v['jobs']) is not list:
            return payload
        if type(v['polls']) is not list or len(v['polls']) > 128:
            return payload
        for poll in v['polls']:
            if type(poll) is not dict or set(poll) != {'id','until'} or not hexdigest(poll['id']) or not number(poll['until']):
                return payload
        last = v['last_poll']
        if last is not None:
            last_keys = {'scope', 'at'}
            if name != 'windows_connector_probe_jobs':
                last_keys.add('release_id')
            if type(last) is not dict or set(last) != last_keys or not hexdigest(last['scope']) or not number(last['at']):
                return payload
            if 'release_id' in last_keys:
                release = last['release_id']
                if type(release) is not str or str(uuid.UUID(release)) != release or uuid.UUID(release).int == 0:
                    return payload
        return json.dumps({'format':v['format'], 'jobs':v['jobs']}, sort_keys=True,
                          separators=(',',':'), allow_nan=False)
    except (ValueError, TypeError, KeyError, RecursionError):
        return payload

def projection(path):
    """Only known transient/cache tables are excluded from the stability guard.

    All tables, including sessions/audit, are still copied with SQLite backup.
    """
    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=3)) as db:
        db.execute('BEGIN')
        schema = db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").fetchall()
        h = hashlib.sha256(repr(schema).encode())
        for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
            if name in VOLATILE: continue
            quoted = '"' + name.replace('"', '""') + '"'
            where = " WHERE name<>'directory_health'" if name == 'runtime_settings' else ''
            rows = db.execute('SELECT * FROM ' + quoted + where).fetchall()
            if name == 'runtime_settings':
                rows = [(r[0], stable_runtime_payload(r[0], r[1]), *r[2:]) for r in rows]
            h.update(name.encode()); h.update(repr(sorted(rows, key=repr)).encode())
        return h.hexdigest()

def preflight_import(files):
    with tempfile.TemporaryDirectory(prefix='policy-scope-verify-',dir='/opt/kaname-lab') as directory:
        candidate=Path(directory);candidate.chmod(0o755)
        for name,data in files.items():
            p=candidate/name;p.parent.mkdir(parents=True,exist_ok=True,mode=0o755);p.write_bytes(data);p.chmod(0o644)
        subprocess.run(['/usr/sbin/runuser','-u','kaname-lab','--','/opt/kaname-lab/venv/bin/python','-I','-B','-c','import sys;sys.path.insert(0,sys.argv[1]);import kaname.server;import kaname.connector_jobs;import kaname.deployment_candidates;import kaname.candidate_jobs;import kaname.scope_jobs;import kaname.combined_jobs;from kaname.user_enrollment import UserEnrollment;from kaname.device_auth import UserKerberosSessions',str(candidate)],check=True,timeout=30)

def ready(version,files):
    for attempt in range(30):
        try:
            if UPDATER['health']('10.35.50.246',version,hashlib.sha256(files['kaname/device_client/AuthWire-Client.ps1']).hexdigest()):return
        except (OSError,ValueError):pass
        time.sleep(.25)
    raise GuardError('PANEL_HTTPS_HEALTH_FAILED')

def radius_ready():
    for attempt in range(30):
        try:
            pid=UPDATER['radius_process_guard']()
            if pid:
                with closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
                    # No application database write is performed by this delivery.
                    if db.execute('PRAGMA quick_check').fetchall()!=[('ok',)]:raise GuardError('DATABASE_CHECK_FAILED')
                result=subprocess.run(['/usr/bin/ss','-H','-lunp'],capture_output=True,text=True,check=True,timeout=10)
                if any(':1812 ' in line and ('pid='+pid+',') in line for line in result.stdout.splitlines()):return pid
        except (OSError,ValueError,subprocess.CalledProcessError):pass
        time.sleep(.25)
    raise GuardError('RADIUS_LISTENER_HEALTH_FAILED')

BACKUP_ROOT=Path('/opt/authwire-backup')
BACKUP_OLD='c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c'
BACKUP_NEW='4f489caa2113c86bda5d0d294878920e218769751e0edbb9385aa40135a924b6'
CHECKER='8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5'

def backup_candidate(files):
    data=files['tools/scheduled_backup.py']
    if hashlib.sha256(data).hexdigest()!=BACKUP_NEW:raise GuardError('BACKUP_CANDIDATE_PIN_DIFFERS')
    release=(json.dumps({'offline_restore_check.py':CHECKER,'scheduled_backup.py':BACKUP_NEW},sort_keys=True,indent=2)+'\n').encode()
    return {'scheduled_backup.py':data,'release.json':release}

def backup_before():
    data={n:trusted(BACKUP_ROOT/n) for n in ('scheduled_backup.py','release.json')}
    digest=hashlib.sha256(data['scheduled_backup.py']).hexdigest()
    try:release=json.loads(data['release.json'])
    except (ValueError,TypeError):raise GuardError('BACKUP_RELEASE_INVALID')
    if digest not in {BACKUP_OLD,BACKUP_NEW} or release!={'offline_restore_check.py':CHECKER,'scheduled_backup.py':digest}:
        raise GuardError('BACKUP_RELEASE_PIN_DIFFERS')
    if sha(BACKUP_ROOT/'offline_restore_check.py')!=CHECKER:raise GuardError('RESTORE_CHECKER_CHANGED')
    return data

def write_backup(name,data,helper):
    path=BACKUP_ROOT/name
    trusted(path);info=path.stat()
    with file_creation_mask(0o022):helper['atomic_text'](path,data.decode('utf-8'),mode=info.st_mode&0o777)
    os.chown(path,info.st_uid,info.st_gid)
    if trusted(path)!=data:raise GuardError('BACKUP_WRITE_VERIFY_FAILED')

def backup_preserved(before,after,files):
    expected={k:list(v) for k,v in before.items()}
    for name,data in backup_candidate(files).items():
        path=str(BACKUP_ROOT/name)
        expected[path][0]=hashlib.sha256(data).hexdigest()
    return expected==after

def restore(files,helper,previous,can_restore,backup_previous):
    if not can_restore():
        emit('COMBINED_JOBS_ROLLBACK_DEFERRED',reason='CONCURRENT_BUSINESS_STATE_CHANGED',source_left_at_reviewed_candidate=True)
        raise GuardError('ROLLBACK_REQUIRES_STATE_REVIEW')
    # Refuse to overwrite a third-party change. Old or exact reviewed candidate only.
    candidate=backup_candidate(files)
    for name,old in backup_previous.items():
        if trusted(BACKUP_ROOT/name) not in (old,candidate[name]):raise GuardError('BACKUP_ROLLBACK_REQUIRES_REVIEW')
    for name,old in previous.items():
        path=ROOT/name
        current=trusted(path) if path.exists() else None
        if current not in (old,files[name]):raise GuardError('SOURCE_ROLLBACK_REQUIRES_REVIEW')
    helper['command']('/usr/bin/systemctl','stop','kaname-lab.service')
    with file_creation_mask(0o022):
        for name in sorted(ALLOWED):write_ui(ROOT/name,previous[name],helper)
    for name,data in backup_previous.items():write_backup(name,data,helper)
    radius_ready()
    helper['command']('/usr/bin/systemctl','start','kaname-lab.service');ready(version_of(previous),files)
    emit('COMBINED_JOBS_SOURCE_ROLLED_BACK',data_restored=False,policy_restored=False,certificate_restored=False,radius_active=True,backup_worker_rolled_back=True)

def apply(files,helper,can_restore):
    old={n:trusted(ROOT/n) if (ROOT/n).exists() else None for n in ALLOWED}
    backup_old=backup_before();candidate=backup_candidate(files)
    if all(old[n]==files[n] for n in ALLOWED) and backup_old==candidate:
        ready(version_of(files),files);radius_ready();return False
    for name,data in old.items():
        if data is not None:
            target=EVIDENCE/'source-before'/name;target.parent.mkdir(parents=True,exist_ok=True,mode=0o700);target.write_bytes(data);target.chmod(0o600)
    for name,data in backup_old.items():
        target=EVIDENCE/'backup-worker-before'/name;target.parent.mkdir(parents=True,exist_ok=True,mode=0o700);target.write_bytes(data);target.chmod(0o600)
    touched=False
    try:
        touched=True
        helper['command']('/usr/bin/systemctl','stop','kaname-lab.service')
        UPDATER['quarantine_caches'](ROOT,EVIDENCE,owner=0)
        with file_creation_mask(0o022):
            for name in sorted(ALLOWED):write_ui(ROOT/name,files[name],helper)
        for name,data in candidate.items():write_backup(name,data,helper)
        backup_before()
        radius_ready()
        helper['command']('/usr/bin/systemctl','start','kaname-lab.service');ready(version_of(files),files)
        return True
    except Exception:
        if touched:restore(files,helper,old,can_restore,backup_old)
        raise

def backup_idle():
    value=subprocess.check_output(['/usr/bin/systemctl','show','authwire-backup.service','--property=ActiveState','--value'],text=True,timeout=10).strip()
    if value not in {'inactive','failed'}:raise GuardError('SCHEDULED_BACKUP_CURRENTLY_RUNNING')

def peer_pin(certificate):
    context=ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    connection=http.client.HTTPSConnection('10.35.50.246',8765,context=context,timeout=5,source_address=('127.0.0.1',0))
    try:
        connection.connect()
        return hashlib.sha256(connection.sock.getpeercert(binary_form=True)).hexdigest()
    finally:connection.close()

def public_metadata():
    # Only public certificate/context fields; no TLS or database permission bypass.
    import sys
    sys.path.insert(0,str(ROOT))
    from kaname.connector_registry import ConnectorRegistry
    probe=ConnectorRegistry.__new__(ConnectorRegistry)
    probe.web_certificate=trusted(Path('/etc/kaname-lab/web.crt'))
    with closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        db.execute('BEGIN')
        context=probe._context(db)
    if peer_pin(probe.web_certificate)!=context['appliance_tls_sha256']:raise GuardError('APPLIANCE_TLS_FILE_RUNTIME_DIFFERS')
    return {'format':'AuthWireConnectorAppliancePublicV1',**context,
            'base_url':'https://'+context['appliance_fqdn']+':8765/',
            'source_release':RELEASE,'version':'0.14.0-dev.42',
            'secrets_exported':False,'binding_created':False}


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
        backup_saved=backup_before()
        worker=load_pinned(BACKUP_ROOT/'scheduled_backup.py',hashlib.sha256(backup_saved['scheduled_backup.py']).hexdigest())
        worker['db_fingerprint']=projection
        before=snapshot(worker)
        if UPDATER['radius_process_guard']()!=before['pids']['authwire-radius.service']:raise GuardError('RADIUS_PROCESS_CHANGED')
        if radius_ready()!=before['pids']['authwire-radius.service']:raise GuardError('RADIUS_LISTENER_CHANGED')
        target=Path('/var/lib/authwire-updates');target.mkdir(mode=0o700,exist_ok=True);worker['private'](target,directory=True)
        EVIDENCE=target/('combined-jobs-dev42-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8]);EVIDENCE.mkdir(mode=0o700)
        worker['atomic_json'](EVIDENCE/'before.json',{'release':RELEASE,'manifest':EXPECTED,'snapshot':before,'full_backup_requested':False})
        emit('COMBINED_JOBS_PREFLIGHT',reviewed_readonly_combined_jobs=True,authentication_guards_preserved=True,protected_authentication_source_identical=True,radius_active=True,service_pids=before['pids'],planned_radius_restart=False,full_data_backup=False,evidence=str(EVIDENCE))
        PHASE='panel_health_before';measure('before')
        if snapshot(worker)!=before:raise GuardError('PREPARATION_STATE_CHANGED')
        previous={n:trusted(ROOT/n) if (ROOT/n).exists() else None for n in ALLOWED}
        def can_restore():
            return all(projection(STATE/n)==digest for n,digest in before['business_state'].items())
        PHASE='backup_idle_guard';backup_idle()
        PHASE='source_update';changed=apply(files,UPDATER,can_restore)
        try:
            PHASE='preservation_after';source_check(files)
            after=snapshot(worker)
            checks={'protected_files':backup_preserved(before['files'],after['files'],files),'broker_process':after['pids']['authwire-service-control.service']==before['pids']['authwire-service-control.service'],'radius_process':after['pids']['authwire-radius.service']==before['pids']['authwire-radius.service'],'timers':after['timers']==before['timers'],'business_state':after['business_state']==before['business_state']}
            if not all(checks.values()):raise GuardError('COMBINED_JOBS_PRESERVATION_FAILED')
            if any(trusted(ROOT/n)!=data for n,data in files.items()):raise GuardError('INSTALLED_SOURCE_DIFFERS')
            if radius_ready()!=after['pids']['authwire-radius.service']:raise GuardError('RADIUS_PROCESS_CHANGED')
            PHASE='panel_health_after';measure('after')
            if snapshot(worker)!=after:raise GuardError('STATE_CHANGED_DURING_HEALTH_CHECK')
            PHASE='public_metadata';public=public_metadata()
            if snapshot(worker)!=after:raise GuardError('STATE_CHANGED_DURING_PUBLIC_METADATA')
        except Exception:
            if changed:restore(files,UPDATER,previous,can_restore,backup_saved)
            raise
        worker['atomic_json'](EVIDENCE/'public-appliance.json',public)
        result={'verified':True,'version':'0.14.0-dev.42','release':RELEASE,'changed':changed,'checks':checks,'radius_active':True,'radius_restarted':False,'radius_process_preserved':True,'radius_pid_before':before['pids']['authwire-radius.service'],'radius_pid_after':after['pids']['authwire-radius.service'],'broker_process_preserved':True,'policy_changed':False,'deployment_plans_created':False,'gpo_changed':False,'connector_binding_written':False,'connector_healthy_claimed':False,'certificates_changed':False,'windows_endpoints_changed':False,'windows_packages_changed':False,'ad_gpo_changed':False,'native_module_changed':False,'backup_workers_changed':hashlib.sha256(backup_saved['scheduled_backup.py']).hexdigest()!=BACKUP_NEW,'full_data_backup_created':False,'backup_timer_preserved':True,'pairing_actions_executed':False,'probe_jobs_created':False,'candidate_jobs_created':False,'gpo_apply_enabled':False,'combined_worker_delivery_pending':True,'candidate_records_created':False,'combined_job_channel_added':True,'combined_jobs_created':False,'scope_jobs_created':False,'operator_browser_acceptance_pending':True,'real_endpoint_acceptance_pending':True,'evidence':str(EVIDENCE),'public_appliance':public}
        worker['atomic_json'](EVIDENCE/'finished.json',result);os.sync();emit('COMBINED_JOBS_FINISHED',**result)

if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('COMBINED_JOBS_FAILED',phase=PHASE,category=type(error).__name__,guard_code=getattr(error,'code',None),evidence=str(EVIDENCE) if EVIDENCE else None,exit_code=error.returncode if isinstance(error,subprocess.CalledProcessError) else None)
        raise SystemExit(1)

