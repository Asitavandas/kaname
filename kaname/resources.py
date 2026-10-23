"""Bounded, read-only Linux guest resource samples. No shell or service actions."""
from datetime import datetime, timezone
from pathlib import Path
import os
import shutil
import threading
import time


class ResourceSampler:
    def __init__(self, proc=Path('/proc'), *, clock=time.monotonic, disk=shutil.disk_usage):
        self.proc=Path(proc);self.clock=clock;self.disk=disk
        self.lock=threading.Lock();self.previous=None;self.cache=None;self.at=None;self.root=None

    def read(self, name, limit):
        with (self.proc/name).open('r',encoding='ascii') as handle:
            value=handle.read(limit+1)
        if len(value)>limit:raise ValueError('RESOURCE_LIMIT')
        return value

    def sample(self, root):
        root=Path(root).absolute()
        with self.lock:
            now=self.clock()
            if self.root==root and self.at is not None and 0<=now-self.at<5:return dict(self.cache)
            if self.root!=root or self.at is not None and now<self.at:self.previous=None
            value={'checked_at':datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00','Z'),
                   'scope':'linux_guest','cpu':{'available':False},'memory':{'available':False},
                   'disk':{'available':False},'uptime':{'available':False}}
            try:
                # First line only; guest/guest_nice duplicate user/nice and are excluded.
                with (self.proc/'stat').open('r',encoding='ascii') as handle:line=handle.readline(4096)
                fields=line.split();assert fields[0]=='cpu' and len(fields)>=9
                ticks=[int(x) for x in fields[1:9]];assert min(ticks)>=0
                total=sum(ticks);idle=ticks[3]+ticks[4];percent=None;seconds=None
                if self.previous:
                    before_total,before_idle,before_time=self.previous;delta=total-before_total;idle_delta=idle-before_idle
                    if delta>0 and 0<=idle_delta<=delta and now>before_time:
                        percent=round(100*(delta-idle_delta)/delta,1);seconds=round(now-before_time,1)
                self.previous=(total,idle,now)
                value['cpu']={'available':True,'percent':percent,'sample_seconds':seconds,'logical_cpus':os.cpu_count() or 1}
            except (OSError,ValueError,IndexError,AssertionError,UnicodeError):self.previous=None
            try:
                rows={}
                for line in self.read('meminfo',32768).splitlines():
                    parts=line.split()
                    if len(parts)>=3 and parts[2]=='kB':rows[parts[0].rstrip(':')]=int(parts[1])*1024
                total=rows['MemTotal'];available=rows['MemAvailable'];assert total>0 and 0<=available<=total
                value['memory']={'available':True,'total_bytes':total,'available_bytes':available,'used_bytes':total-available,'percent':round(100*(total-available)/total,1)}
            except (OSError,ValueError,KeyError,AssertionError,UnicodeError):pass
            try:
                disk=self.disk(root);assert disk.total>0 and 0<=disk.used<=disk.total and 0<=disk.free<=disk.total
                value['disk']={'available':True,'total_bytes':disk.total,'used_bytes':disk.used,'free_bytes':disk.free,'percent':round(100*disk.used/disk.total,1),'scope':'authwire_data_filesystem'}
            except (OSError,ValueError,AssertionError):pass
            try:
                seconds=float(self.read('uptime',256).split()[0]);assert 0<=seconds<10**12
                value['uptime']={'available':True,'seconds':int(seconds)}
            except (OSError,ValueError,IndexError,AssertionError,OverflowError,UnicodeError):pass
            self.root=root;self.at=now;self.cache=value
            return dict(value)


_sampler=ResourceSampler()
def snapshot(root):
    return _sampler.sample(root)
