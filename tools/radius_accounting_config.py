"""Opt-in native FreeRADIUS Accounting callback configuration."""


SOURCE = 'AuthWire-Accounting-Source'
VECTOR = 'AuthWire-Accounting-Vector'
STATE = 'AuthWire-Accounting-State'
RUNTIME = 'AuthWire-Accounting-Runtime'


def dictionary():
    return ''.join(f'ATTRIBUTE {name} {code} string\n'
                   for code, name in ((3003, SOURCE), (3004, VECTOR), (3005, STATE), (3007, RUNTIME)))


def module(source, dependencies):
    return f'''python3 authwire_accounting {{
 python_path = "{source}:{dependencies}"
 python_path_mode = prepend
 pass_all_vps_dict = yes
 module = kaname.radius_accounting_observer
 mod_accounting = ${{.module}}
 func_accounting = accounting
}}
'''


def augment_site(site, listen_ip, accounting_port, state, runtime=None):
    needle = ' authenticate {\n  eap\n }\n'
    if site.count(needle) != 1:
        raise ValueError('Unexpected AuthWire RADIUS authentication template')
    if type(accounting_port) is not int or not 1 <= accounting_port <= 65535:
        raise ValueError('Invalid RADIUS accounting port')
    import ipaddress
    listen_ip = str(ipaddress.IPv4Address(listen_ip))
    listener = (f' }}\n listen {{\n  type = acct\n  ipaddr = {listen_ip}\n'
                f'  port = {accounting_port}\n }}\n')
    marker = ' }\n authorize {\n'
    if site.count(marker) != 1:
        raise ValueError('Unexpected AuthWire RADIUS listener template')
    site = site.replace(marker, listener + ' authorize {\n', 1)
    runtime_value = f'   {RUNTIME} := "{runtime}"\n' if runtime is not None else ''
    section = f""" accounting {{
  update control {{
   {SOURCE} := "%{{Packet-Src-IP-Address}}"
   {VECTOR} := "%{{Packet-Authentication-Vector}}"
   {STATE} := "{state}"
{runtime_value}  }}
  authwire_accounting
 }}
"""
    return site.replace(needle, needle + section, 1)
