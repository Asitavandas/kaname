"""Display relationships from a bounded, single-domain directory snapshot."""
from collections import defaultdict, deque


def related(catalog, kind, target):
    groups = {x['sid']: x for x in catalog['groups']}
    users = {x['sid']: x for x in catalog['users']}
    computers = {x['sid']: x for x in catalog['computers']}
    parents, children = defaultdict(list), defaultdict(list)
    for edge in catalog['memberships']:
        parents[edge['member_sid']].append((edge['group_sid'], edge['type']))
        children[edge['group_sid']].append((edge['member_sid'], edge['type']))
    relations = {}
    priority = {'indirect': 0, 'direct': 1, 'primary': 2}

    def remember(sid, relation):
        if priority[relation] > priority.get(relations.get(sid), -1): relations[sid] = relation

    if kind == 'users':
        queue = deque()
        for group, relation in parents[target['sid']]:
            remember(group, relation); queue.append(group)
        visited = set()
        while queue:
            group = queue.popleft()
            if group in visited: continue
            visited.add(group)
            for parent, _ in parents[group]:
                remember(parent, 'indirect'); queue.append(parent)
        return [{**groups[sid], 'membership': relation} for sid, relation in relations.items()], {
            'primary_group_unresolved': target['primary_group_unresolved'], 'unresolved_members': 0,
            'computer_members': 0, 'nested_groups': 0,
        }
    queue, visited, computer_members = deque([target['sid']]), set(), set()
    unresolved = 0
    while queue:
        group = queue.popleft()
        if group in visited: continue
        visited.add(group); unresolved += groups[group]['unresolved_members']
        for member, relation in children[group]:
            if member in users: remember(member, relation if group == target['sid'] else 'indirect')
            elif member in groups: queue.append(member)
            elif member in computers: computer_members.add(member)
    return [{**users[sid], 'membership': relation} for sid, relation in relations.items()], {
        'primary_group_unresolved': False, 'unresolved_members': unresolved,
        'computer_members': len(computer_members), 'nested_groups': len(visited) - 1,
    }
