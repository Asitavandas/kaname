"""Synthetic integrity fixtures are not bootable appliances and are temporary."""
import tempfile
import unittest
from pathlib import Path
from tools.verify_ovf import verify, sha256, PackageError, OVF, RASD


class OVFTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.disk=self.root/'disk.vmdk'
        self.disk.write_bytes(b'KDMV'+bytes(508))
        self.ovf=self.root/'KANAME.ovf'
        self.xml=f'''<ovf:Envelope xmlns:ovf="{OVF}" xmlns:rasd="{RASD}">
        <ovf:References><ovf:File ovf:id="f1" ovf:href="disk.vmdk" ovf:size="512"/></ovf:References>
        <ovf:DiskSection><ovf:Disk ovf:diskId="d1" ovf:fileRef="f1" ovf:capacity="80"/></ovf:DiskSection>
        <ovf:VirtualSystem ovf:id="KANAME"><ovf:VirtualHardwareSection>
        <ovf:Item><rasd:ResourceType>3</rasd:ResourceType><rasd:VirtualQuantity>4</rasd:VirtualQuantity></ovf:Item>
        <ovf:Item><rasd:ResourceType>4</rasd:ResourceType><rasd:VirtualQuantity>8192</rasd:VirtualQuantity></ovf:Item>
        <ovf:Item><rasd:ResourceType>10</rasd:ResourceType></ovf:Item>
        <ovf:Item><rasd:ResourceType>17</rasd:ResourceType><rasd:HostResource>ovf:/disk/d1</rasd:HostResource></ovf:Item>
        </ovf:VirtualHardwareSection></ovf:VirtualSystem></ovf:Envelope>'''
        self.ovf.write_text(self.xml);self.manifest()

    def manifest(self):
        (self.root/'KANAME.mf').write_text(f'SHA256(KANAME.ovf)= {sha256(self.ovf)}\nSHA256(disk.vmdk)= {sha256(self.disk)}\n')

    def test_integrity_pass_is_not_boot_pass(self):
        result=verify(self.ovf)
        self.assertTrue(result['package_integrity_verified'])
        self.assertFalse(result['boot_verified']);self.assertFalse(result['release_ready'])

    def test_changed_disk_rejected(self):
        self.disk.write_bytes(b'KDMV'+b'x'*508)
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_changed_descriptor_rejected(self):
        self.ovf.write_text(self.xml.replace('KANAME','Another'))
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_missing_disk_rejected(self):
        self.disk.unlink()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_path_escape_rejected(self):
        self.ovf.write_text(self.xml.replace('disk.vmdk','../disk.vmdk'))
        self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_remote_disk_rejected(self):
        self.ovf.write_text(self.xml.replace('disk.vmdk','https://example.com/disk.vmdk'))
        self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_missing_disk_section_rejected(self):
        self.ovf.write_text(self.xml.replace('ovf:fileRef="f1"','ovf:fileRef="missing"'));self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_dtd_rejected(self):
        self.ovf.write_text('<!DOCTYPE test [<!ENTITY a "x">]>'+self.xml);self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_duplicate_manifest_entry_rejected(self):
        with (self.root/'KANAME.mf').open('a') as f:f.write(f'SHA256(disk.vmdk)= {sha256(self.disk)}\n')
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_manifest_must_cover_descriptor(self):
        (self.root/'KANAME.mf').write_text(f'SHA256(disk.vmdk)= {sha256(self.disk)}\n')
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_sha1_not_accepted(self):
        path=self.root/'KANAME.mf';path.write_text(path.read_text().replace('SHA256','SHA1'))
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_symbolic_link_disk_rejected(self):
        actual=self.root/'actual.vmdk';self.disk.rename(actual);self.disk.symlink_to(actual)
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_missing_nic_rejected(self):
        self.ovf.write_text(self.xml.replace('<rasd:ResourceType>10</rasd:ResourceType>','<rasd:ResourceType>11</rasd:ResourceType>'));self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)

    def test_zero_cpu_rejected(self):
        self.ovf.write_text(self.xml.replace('<rasd:VirtualQuantity>4</rasd:VirtualQuantity>','<rasd:VirtualQuantity>0</rasd:VirtualQuantity>'));self.manifest()
        with self.assertRaises(PackageError):verify(self.ovf)
