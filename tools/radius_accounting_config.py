"""Opt-in native FreeRADIUS Accounting callback configuration."""


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


def augment_site(site, listen_ip, accounting_port):
    marker = 'server authwire-radius {\n'
    if site.count(marker) != 1:
        raise ValueError('Unexpected AuthWire RADIUS server template')
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
    return site.replace(needle, needle + ' accounting {\n  authwire_accounting\n }\n', 1)