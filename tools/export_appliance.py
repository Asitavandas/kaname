"""Export a prepared local VMware VMX using an installed OVF Tool.

No VM is created or modified by this wrapper. The supplied VM must already
be shut down and sanitized. Customer credentials must never be in the VM.
"""
import argparse
import json
import shutil
import subprocess
from pathlib import Path
from .verify_ovf import verify


def main():
    parser = argparse.ArgumentParser(description='KANAME clean VM export')
    parser.add_argument('vmx')
    parser.add_argument('destination')
    parser.add_argument('--sanitized-image-confirmed', action='store_true')
    args = parser.parse_args()
    vmx = Path(args.vmx).absolute()
    target = Path(args.destination).absolute()
    if not args.sanitized_image_confirmed:
        parser.error('Clean-image attestation is required; see docs/APPLIANCE.md')
    if vmx.suffix.lower() != '.vmx' or vmx.is_symlink() or not vmx.is_file():
        parser.error('A local regular VMX file is required')
    if target.exists():
        parser.error('Destination must not already exist')
    tool = shutil.which('ovftool')
    if not tool:
        parser.error('VMware OVF Tool is not installed; no image was produced')
    target.mkdir(parents=True)
    descriptor = target / 'KANAME.ovf'
    subprocess.run([tool, '--shaAlgorithm=SHA256', str(vmx), str(descriptor)], check=True)
    print(json.dumps(verify(descriptor), indent=2))
    print('Export integrity checked. Import, boot and clone-identity tests are still required.')


if __name__ == '__main__':
    main()
