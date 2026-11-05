"""Bounded Linux RADIUS metadata capture with kernel receive timestamps.

Example (root; existing private output directory):
  python -I tools/radius_packet_timing.py --nas 192.0.2.10 \
    --seconds 120 --output /root/authwire-probe/radius.jsonl

Passive only: no packets sent, services changed, secrets read, or raw payloads
written. This is observed packet metadata, not verification of authenticators.
Kernel capture time and userspace read time are distinct; neither establishes
that the switch or supplicant actually accepted an Access-Accept packet.
These are software timestamps, not physical wire timestamps. Cross-host timing
also requires clock synchronization. Duplicate observations are not new logins.
"""
import argparse
import datetime
import ipaddress
import json
import os
from pathlib import Path
import socket
import stat
import struct
import sys
import time

MAX_RECORDS = 10000


def radius_metadata(frame, nas):
    """Parse Ethernet/IPv4/UDP/RADIUS; never return attribute values."""
    if len(frame) < 14:
        return None
    kind, offset = int.from_bytes(frame[12:14], 'big'), 14
    tags = 0
    while kind in (0x8100, 0x88A8):
        if tags == 2 or len(frame) < offset + 4:
            return None
        kind = int.from_bytes(frame[offset + 2:offset + 4], 'big')
        offset += 4
        tags += 1
    ip = frame[offset:]
    if kind != 0x0800 or len(ip) < 20 or ip[0] >> 4 != 4:
        return None
    ihl, total = (ip[0] & 15) * 4, int.from_bytes(ip[2:4], 'big')
    if (ihl < 20 or total < ihl + 8 or total > len(ip) or ip[9] != 17
            or int.from_bytes(ip[6:8], 'big') & 0x3FFF):
        return None
    source, destination = socket.inet_ntoa(ip[12:16]), socket.inet_ntoa(ip[16:20])
    udp = ip[ihl:total]
    sport, dport, length = struct.unpack('!HHH', udp[:6])
    if length < 28 or length != len(udp):
        return None
    if source == nas and dport == 1812:
        direction = 'from_nas'
    elif destination == nas and sport == 1812:
        direction = 'to_nas'
    else:
        return None
    radius = udp[8:]
    rlen = int.from_bytes(radius[2:4], 'big')
    if radius[0] not in (1, 2, 3, 11) or not 20 <= rlen <= 4096 or rlen != len(radius):
        return None
    pos, eap, mppe, ma = 20, bytearray(), set(), False
    while pos < rlen:
        if pos + 2 > rlen:
            return None
        attribute, size = radius[pos], radius[pos + 1]
        if size < 2 or pos + size > rlen:
            return None
        value = radius[pos + 2:pos + size]
        if attribute == 79:
            eap.extend(value)
        elif attribute == 80:
            if size != 18:
                return None
            ma = True
        elif attribute == 26 and len(value) >= 6 and int.from_bytes(value[:4], 'big') == 311:
            vendor_pos = 4
            while vendor_pos < len(value):
                if vendor_pos + 2 > len(value):
                    return None
                vtype, vsize = value[vendor_pos:vendor_pos + 2]
                if vsize < 2 or vendor_pos + vsize > len(value):
                    return None
                if vtype in (16, 17):
                    mppe.add(vtype)
                vendor_pos += vsize
        pos += size
    if eap:
        if len(eap) < 4 or int.from_bytes(eap[2:4], 'big') != len(eap):
            return None
        if eap[0] not in (1, 2, 3, 4) or (eap[0] in (1, 2) and len(eap) < 5):
            return None
        if eap[0] in (3, 4) and len(eap) != 4:
            return None
    return {'direction': direction, 'radius_code': radius[0], 'radius_id': radius[1],
            'eap_code': eap[0] if eap else None, 'eap_id': eap[1] if eap else None,
            'eap_type': eap[4] if eap and eap[0] in (1, 2) else None,
            'mppe_send': 16 in mppe, 'mppe_receive': 17 in mppe,
            'message_authenticator': ma}


def timestamp_option():
    # Native Linux ABI only. Refuse an unverified 32-bit timespec layout.
    if sys.platform != 'linux' or struct.calcsize('@l') != 8:
        raise RuntimeError('Linux 64-bit native timespec required')
    return getattr(socket, 'SO_TIMESTAMPNS', 35)


def kernel_timestamp_ns(ancillary, flags, option):
    if flags & (socket.MSG_TRUNC | socket.MSG_CTRUNC):
        return None
    matches = [data for level, kind, data in ancillary
               if level == socket.SOL_SOCKET and kind == option]
    if len(matches) != 1 or len(matches[0]) != struct.calcsize('@ll'):
        return None
    seconds, nanos = struct.unpack('@ll', matches[0])
    if seconds < 0 or not 0 <= nanos < 1_000_000_000:
        return None
    return seconds * 1_000_000_000 + nanos


def private_output(path):
    path = Path(path)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(directory)
        if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise ValueError('Output directory must be private and owned by the caller')
        fd = os.open(path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=directory)
        return os.fdopen(fd, 'w', encoding='utf-8')
    finally:
        os.close(directory)


def capture(nas, seconds, output):
    nas = str(ipaddress.IPv4Address(nas))
    if not 1 <= seconds <= 300:
        raise ValueError('Capture duration must be 1 through 300 seconds')
    option = timestamp_option()
    records = missing_time = 0
    with socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3)) as sock:
        sock.setsockopt(socket.SOL_SOCKET, option, 1)
        with private_output(output) as handle:
            deadline = time.monotonic() + seconds
            print(json.dumps({'event': 'AUTHWIRE_RADIUS_TIMING_READY',
                              'seconds': seconds, 'timestamp_source': 'linux_kernel'}), flush=True)
            while (remaining := deadline - time.monotonic()) > 0 and records < MAX_RECORDS:
                sock.settimeout(min(remaining, 1.0))
                try:
                    frame, ancillary, flags, address = sock.recvmsg(65535, socket.CMSG_SPACE(64))
                except socket.timeout:
                    continue
                read_ns = time.time_ns()
                row = radius_metadata(frame, nas)
                if row is None:
                    continue
                kernel_ns = kernel_timestamp_ns(ancillary, flags, option)
                if kernel_ns is None:
                    missing_time += 1
                    continue  # Never substitute a userspace timestamp.
                sec, nano = divmod(kernel_ns, 1_000_000_000)
                utc = datetime.datetime.fromtimestamp(sec, datetime.timezone.utc)
                row.update(kernel_ns=kernel_ns, utc=utc.strftime('%Y-%m-%dT%H:%M:%S') +
                           f'.{nano:09d}Z', userspace_read_ns=read_ns,
                           read_lag_ms=(read_ns - kernel_ns) / 1_000_000,
                           interface=address[0], packet_type=address[2])
                handle.write(json.dumps(row, separators=(',', ':')) + '\n')
                handle.flush()
                records += 1
    result = {'event': 'AUTHWIRE_RADIUS_TIMING_DONE', 'records': records,
              'missing_kernel_timestamps': missing_time,
              'record_limit_reached': records == MAX_RECORDS}
    print(json.dumps(result), flush=True)
    if missing_time:
        raise RuntimeError('Matching packets lacked valid kernel timestamps')
    if records == MAX_RECORDS:
        raise RuntimeError('Record limit reached; capture incomplete')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nas', required=True, type=ipaddress.IPv4Address)
    parser.add_argument('--seconds', type=int, default=120)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    capture(args.nas, args.seconds, args.output)


if __name__ == '__main__':
    main()
