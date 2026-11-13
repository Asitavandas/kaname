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


def augment_site(site):
    marker = 'server authwire-radius {\n'
    if site.count(marker) != 1:
        raise ValueError('Unexpected AuthWire RADIUS server template')
    needle = ' authenticate {\n  eap\n }\n'
    if site.count(needle) != 1:
        raise ValueError('Unexpected AuthWire RADIUS authentication template')
    return site.replace(needle, needle + ' accounting {\n  authwire_accounting\n }\n', 1)