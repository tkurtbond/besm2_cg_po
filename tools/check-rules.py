#!/usr/bin/env python3
# check-rules.py LISTING RULES: checks Besm2Rules' tables, as test/ListRules
# prints them (LISTING), against the tables of rules/ (RULES), which were
# read from the rulebook in Part A (PLAN.md, A2) and checked against its
# headings by check-pages.py.  Part of make test; needs no PDF.
#
# Checked, for every row of the tables: the item is in Besm2Rules once,
# of the right kind, with the same page and PDF page (page + 2), and
#   attributes.tsv     its highest Level, its cost a Level where the
#                      table gives one number ("fixed 2/Level", "4/Level
#                      ..."; 0 where the cost is chosen per Level), the
#                      Subject flag ("yes ..."), the MechaOnly flag
#                      ("(Mecha Only)"); a Mecha-Only Defect's highest
#                      rank ("1-6 BP");
#   headings-fields    a Defect's Special flag (Type);
#   skill-costs.tsv    a Skill's eight costs ("—" is 0, not offered);
#   weapon-abilities-  slots ("counts-as"), the other number after ";",
#   disabilities.tsv   how often it may be taken ("yes/3", "no" is 1),
#                      NeedsDetail (anything but "no" or "(optional ...)"), NotPersonalGear ("not
#                      ... Personal Gear"), MechaOnly ("(Mecha Only)"),
#                      and every pair of its exclusions that names
#                      another Ability or Disability;
# and Besm2Rules has nothing the tables don't.  The few entries the table
# words in a way no rule reads are in EXCEPTIONS, each with its reason.
# Prints "ok   - ..." or "FAIL - ..." and exits 1 on any failure.
import os, re, sys

# (table, name, field): the value Besm2Rules has, and why.
EXCEPTIONS = {
    ('weapon', 'Contagious', 'alt'): 0,       # "3 mild; 6 high": taken twice, not a second number
    ('weapon', 'Unique Ability', 'times'): 'unlimited',            # "GM"
    ('weapon', 'Unique Weapon Disability', 'times'): 'unlimited',  # "GM"
    ('attribute', 'Highly Skilled', 'max'): 'unlimited',           # "open (e.g. 11)"
    ('attribute', 'Unique Character Attribute', 'max'): '6',       # "2 or 6 (GM)"
    ('attribute', 'Super Transformation', 'cost'): '0',            # "3 or 5/Level"
}
# The Defects' ranks and Bonus Points (Table 2-3, p. 100): 1-2 BP, but these.
DEFECT_RANKS = {'Awkward Size': ('1', '6'), 'Diminutive': ('3', '2')}
NOT_ITEMS = {'Unique Defect Sample — Weak Point'}  # an example, p. 112

def table(path):
    with open(path, encoding='utf-8') as f:
        rows = [line.rstrip('\n').split('\t') for line in f if line.strip()]
    return [dict(zip(rows[0], r)) for r in rows[1:]]

def main(argv):
    if len(argv) != 2:
        sys.exit('usage: check-rules.py LISTING RULES')
    listing, rules = argv
    fails = []
    def fail(msg):
        fails.append(msg)
        print('FAIL - ' + msg)

    items, aliases, excludes = {}, {}, set()
    with open(listing, encoding='utf-8') as f:
        for line in f:
            r = line.rstrip('\n').split('\t')
            if r[0] == 'alias':
                aliases[r[1]] = r[2]
            elif r[0] == 'exclude':
                excludes.add(frozenset(r[1:3]))
            elif r[0] == 'section':
                continue
            else:
                key = (r[0], r[3])
                if key in items:
                    fail(f'{r[3]} ({r[0]}) is in Besm2Rules twice')
                items[key] = dict(kind=r[0], page=r[1], pdf=r[2], name=r[3], cost=r[4], max=r[5],
                                  min=r[6], flags=set(filter(None, r[7].split(','))),
                                  slots=r[8], alt=r[9], times=r[10], skill=r[11])
    names = [n for _, n in items]
    for n in set(names):
        if names.count(n) > 1 and n != 'Stealth':  # an Attribute (p. 73) and a Skill (p. 123)
            fail(f'{n} is the name of {names.count(n)} items')
    seen = set()

    def get(kind, name, file):
        it = items.get((kind, name))
        if it is None:
            fail(f'{file}: {name} is not a {kind} of Besm2Rules')
        else:
            seen.add((kind, name))
        return it

    def same(file, it, field, want):
        if it[field] != want:
            fail(f'{file}: {it["name"]} has {field} {it[field]!r}, the table {want!r}')

    def pages(file, it, row):
        same(file, it, 'page', row['page'])
        same(file, it, 'pdf', str(int(row['page']) + 2))
        same(file, it, 'pdf', row['pdf'])

    def flag(file, it, f, want):
        if (f in it['flags']) != want:
            fail(f'{file}: {it["name"]} {"lacks" if want else "has"} the flag {f}')

    def exc(table, name, field, value):
        return EXCEPTIONS.get((table, name, field), value)

    f = 'attributes.tsv'
    for row in table(os.path.join(rules, f)):
        n, rule = row['name'], row['cost-rule']
        if rule.startswith('Mecha-Only Defect'):
            it = get('mecha-defect', n, f)
            if it:
                pages(f, it, row)
                same(f, it, 'max', re.search(r'1-(\d+) BP', rule).group(1))
                same(f, it, 'cost', '1')
                flag(f, it, 'mecha-only', True)
            continue
        it = get('mecha-attribute' if int(row['page']) >= 93 else 'attribute', n, f)
        if not it:
            continue
        pages(f, it, row)
        same(f, it, 'max', exc('attribute', n, 'max', row['max-level']))
        m = re.match(r'(?:fixed )?(\d+)/Level', rule)
        same(f, it, 'cost', exc('attribute', n, 'cost', m.group(1) if m else '0'))
        flag(f, it, 'subject', row['subject'].startswith('yes'))
        flag(f, it, 'mecha-only', '(Mecha Only)' in rule)

    f = 'headings-fields.tsv'
    for row in table(os.path.join(rules, f)):
        if not 101 <= int(row['page']) <= 113 or row['name'] in NOT_ITEMS:
            continue
        it = get('defect', row['name'], f)
        if it:
            pages(f, it, row)
            cost, rank = DEFECT_RANKS.get(row['name'], ('1', '2'))
            same(f, it, 'cost', cost)
            same(f, it, 'max', rank)
            flag(f, it, 'special', row['type'] == 'Special')
            flag(f, it, 'gm-cost', row['type'] == 'Normal or Special')

    f = 'skill-costs.tsv'
    for row in table(os.path.join(rules, f)):
        it = get('skill', row['skill'], f)
        if it:
            costs = [row[g] for g in list(row)[1:]]
            same(f, it, 'skill', ','.join('0' if c == '—' else c for c in costs))
            if not 120 <= int(it['page']) <= 128:
                fail(f'{f}: {it["name"]} is on p. {it["page"]}, not in the Skills (pp. 120-128)')

    f = 'weapon-abilities-disabilities.tsv'
    wnames = set()
    rows = table(os.path.join(rules, f))
    for row in rows:
        wnames.add(row['name'])
    for row in rows:
        n = row['name']
        it = get(row['kind'], n, f)
        if not it:
            continue
        pages(f, it, row)
        c = row['counts-as']
        same(f, it, 'slots', re.match(r'\d+', c).group(0))
        m = re.search(r';\s*(\d+)', c)
        same(f, it, 'alt', str(exc('weapon', n, 'alt', m.group(1) if m else '0')))
        r = row['repeatable/max']
        m = re.match(r'yes/(\w+)', r)
        same(f, it, 'times', exc('weapon', n, 'times', m.group(1) if m else '1'))
        d = row['needs-detail']
        flag(f, it, 'needs-detail', d != 'no' and 'optional' not in d)
        flag(f, it, 'not-personal-gear', bool(re.search(r'\bnot\b[^;]*Personal Gear', row['exclusions'])))
        flag(f, it, 'mecha-only', '(Mecha Only)' in n)
        for other in (x.strip() for x in row['exclusions'].split(';')):
            if other in wnames and frozenset((n, other)) not in excludes:
                fail(f'{f}: {n} and {other} should exclude each other')
    for pair in excludes:
        a, b = sorted(pair)
        listed = {x.strip() for r in rows if r['name'] in pair for x in r['exclusions'].split(';')}
        if not (pair & listed):
            fail(f'Besm2Rules excludes {a} and {b}, but the table doesn\'t')

    for kind, n in items:
        if kind != 'stat' and (kind, n) not in seen:
            fail(f'{n} ({kind}) is in Besm2Rules but in none of the tables')
    stats = sorted(n for k, n in items if k == 'stat')
    if stats != ['Body', 'Mind', 'Soul']:
        fail(f'the Stats are {stats}')
    for a, n in aliases.items():
        if a in names:
            fail(f'the alias {a} is also an item\'s name')

    if fails:
        print(f'FAIL - {len(fails)} failures')
        return 1
    print(f'ok   - all {len(seen)} items of rules/ are in Besm2Rules, as the tables give them, '
          f'with {len(excludes)} exclusions and {len(aliases)} aliases')
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
