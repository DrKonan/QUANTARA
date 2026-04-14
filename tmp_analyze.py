import sys, json
d = json.load(sys.stdin)
leagues = {}
for f in d.get('response', []):
    lid = f['league']['id']
    lname = f['league']['name']
    lcountry = f['league']['country']
    if lid not in leagues:
        leagues[lid] = {'name': lname, 'country': lcountry, 'count': 0}
    leagues[lid]['count'] += 1

our_ids = {39, 140, 78, 135, 61, 2, 3, 1, 4, 6, 233}
print(f"Total: {d['results']} matches in {len(leagues)} leagues")
print("\n=== Nos ligues configurees ===")
for lid in our_ids:
    if lid in leagues:
        l = leagues[lid]
        print(f"  [{lid}] {l['name']} ({l['country']}): {l['count']} matchs")
    else:
        print(f"  [{lid}] PAS DE MATCH AUJOURD'HUI")

print("\n=== Top 20 ligues par nombre de matchs ===")
for lid, l in sorted(leagues.items(), key=lambda x: x[1]['count'], reverse=True)[:20]:
    marker = " <<<" if lid in our_ids else ""
    print(f"  [{lid}] {l['name']} ({l['country']}): {l['count']} matchs{marker}")
