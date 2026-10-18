"""Literal opt-in native observer configuration, shared by runtime and lab."""
from kaname.radius_observer import CONTEXT, REQUEST_KEY, FINAL_CODE


def dictionary():
    return (f'ATTRIBUTE {CONTEXT} 3000 string\n'
            f'ATTRIBUTE {REQUEST_KEY} 3001 string\n'
            f'ATTRIBUTE {FINAL_CODE} 3002 integer\n')


def module(source, dependencies, *, module_name='kaname.radius_observer'):
    return f'''python3 authwire_access_events {{
 python_path = "{source}:{dependencies}"
 python_path_mode = prepend
 pass_all_vps_dict = yes
 module = {module_name}
 mod_post_auth = ${{.module}}
 func_post_auth = post_auth
}}
'''


def augment_site(site):
    # Materialize virtual packet metadata before any early authorize reject.
    # All custom attributes live in control/session-state, never a wire reply.
    site = site.replace(' authorize {\n', f''' authorize {{
  update control {{
   {REQUEST_KEY} := "%{{Packet-Src-IP-Address}}|%{{Packet-Src-Port}}|%{{Packet-Authentication-Vector}}"
  }}
''', 1)
    site = site.replace(' authenticate {\n  eap\n }\n}', f''' authenticate {{
  eap
 }}
 post-auth {{
  update control {{
   {FINAL_CODE} := 2
  }}
  authwire_access_events
  Post-Auth-Type REJECT {{
   update control {{
    {FINAL_CODE} := 3
   }}
   authwire_access_events
  }}
 }}
}}''', 1)
    return site


def context_copy():
    return f'''  if (&control:{CONTEXT}) {{
   update outer.session-state {{
    {CONTEXT} := &control:{CONTEXT}
   }}
  }}
'''
