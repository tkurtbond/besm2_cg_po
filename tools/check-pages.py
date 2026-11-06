#!/usr/bin/env python3
# check-pages.py PDF BOOKMARKED RULES [LISTING]: checks every page in the
# rules tables against the rulebook (A2.11 of PLAN.md), and those of
# Besm2Rules too (Part B, step 1).
#
#   PDF         BESM2ER.pdf, the original, with a text layer;
#   BOOKMARKED  BESM2ER_bookmarked.pdf, whose bookmarks were typed by hand;
#   RULES       the directory of the tables (rules/);
#   LISTING     what test/ListRules prints of Besm2Rules.
#
# The headings are found by font with rulebook-headings.py (beside this
# script), so only headings are read, never the rulebook's text (AGENTS.md).
# Failures, each a line starting "FAIL":
#   - rules/headings.tsv differs from the headings found now;
#   - an item of attributes.tsv, headings-fields.tsv or a Skill of
#     skill-costs.tsv is not an item heading on its page (Skills have no
#     page in their table, so the Skill heading must be found in the Skill
#     chapter, PDF 121-131), or a Weapon Attack Ability or Disability of
#     weapon-abilities-disabilities.tsv is not a bullet heading on its page;
#   - a row whose PDF page isn't its printed page + 2;
#   - with LISTING, an item of Besm2Rules that is not a heading on its
#     page (a Stat is the bullet "Body Stat"; a Weapon Ability or
#     Disability a bullet; any other an item heading), or one of its
#     rules' pages (StatsPage, ...) without its heading.
# A name the heading spells differently is matched through ALIASES below;
# each alias is a spelling the book itself uses elsewhere (Table 2-2, 2-3,
# 2-4 or the running text), recorded in PLAN.md.
# The bookmarks are a second check: one that disagrees with a heading is
# printed as "note", for the user to fix in the bookmark list, and does
# not fail.  Finally the counts of each kind of item are printed.
import difflib, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# table name -> heading name (lower case), where the two differ.
ALIASES = {
    'ecm': 'electronic counter-measures (ecm)',      # p. 28
    'own a big mecha': 'own a big mecha (obm)',       # p. 59
    'weapon attack': 'weapon attack (or special attack)',  # p. 81
    'a.i.': 'artificial intelligence (a.i.)',         # p. 93
    'wind powered': 'wind-powered',                   # p. 116; Table 2-3's spelling
}

# Each section of entries: its PDF pages, the kind of heading, the table
# that lists its entries (with a filter on the rows), and the headings in
# it that are not entries (a section inside an entry, or a note).  Its
# headings, less those, must be the table's names in the same order.
SECTIONS = [  # (label, first PDF page, last, kind, table, row filter)
    ('Attributes', 22, 83, 'item', 'attributes.tsv', None),
    ('Mecha Attributes', 95, 101, 'item', 'attributes.tsv', None),
    ('Defects', 103, 115, 'item', 'headings-fields.tsv', None),
    ('Mecha-Only Defects', 116, 118, 'item', 'attributes.tsv', None),
    ('Skills', 121, 131, 'item', 'skill-costs.tsv', None),
    ('Weapon Attack Abilities', 85, 94, 'bullet', 'weapon-abilities-disabilities.tsv',
     lambda r: r['kind'] == 'ability'),
    ('Weapon Attack Disabilities', 85, 94, 'bullet', 'weapon-abilities-disabilities.tsv',
     lambda r: r['kind'] == 'disability'),
]
NOT_ENTRIES = {  # (PDF page, heading)
    (38, 'Force Field Abilities'), (38, 'Force Field Disabilities'),
    (52, 'Magic Options'), (82, 'Unique Character Attribute Sample — Wealth'),
    (85, 'Hand-Held Weapons'), (85, 'Personal Gear'),
    (131, 'Combat Value'), (131, 'Health Points'), (131, 'Energy Points'),
}

def norm(name):
    return ' '.join(name.lower().replace('’', "'").split())

def table(path):
    with open(path, encoding='utf-8') as f:
        rows = [line.rstrip('\n').split('\t') for line in f if line.strip()]
    head = rows[0]
    return [dict(zip(head, r)) for r in rows[1:]]

def headings(pdf):
    out = subprocess.run([os.path.join(HERE, 'rulebook-headings.py'), '-a', pdf],
                         check=True, capture_output=True, text=True).stdout
    return out

def bookmarks(pdf):
    out = subprocess.run(['mutool', 'show', pdf, 'outline'], capture_output=True, text=True).stdout
    marks = []
    for line in out.splitlines():
        m = re.match(r'^[|+-]\t+"(.*)"\t(?:#page=(\d+))?', line)
        if m:
            marks.append((m.group(1), int(m.group(2)) if m.group(2) else None))
    return marks

def main(argv):
    if len(argv) not in (3, 4):
        sys.exit('usage: check-pages.py PDF BOOKMARKED RULES [LISTING]')
    pdf, marked, rules = argv[:3]
    listing = argv[3] if len(argv) == 4 else None
    fails = 0
    def fail(msg):
        nonlocal fails
        fails += 1
        print('FAIL - ' + msg)

    found = headings(pdf)
    with open(os.path.join(rules, 'headings.tsv'), encoding='utf-8') as f:
        kept = f.read()
    if found != kept:
        a, b = found.splitlines(), kept.splitlines()
        for i, (x, y) in enumerate(zip(a, b)):
            if x != y:
                fail(f'rules/headings.tsv line {i + 1}: {y!r}, the PDF has {x!r}')
                break
        if len(a) != len(b):
            fail(f'rules/headings.tsv has {len(b)} headings, the PDF {len(a)}')
    else:
        print(f'ok   - rules/headings.tsv is the {len(kept.splitlines())} headings found by font')

    by_page = {}  # (pdf page, kind) -> set of names
    for line in found.splitlines():
        p, _, kind, name = line.split('\t')
        by_page.setdefault((int(p), kind), set()).add(norm(name))

    def at(name, pdfpage, kind):
        n = norm(name)
        return ALIASES.get(n, n) in by_page.get((pdfpage, kind), set())

    checked = 0
    for file, kind in (('attributes.tsv', 'item'), ('headings-fields.tsv', 'item'),
                       ('weapon-abilities-disabilities.tsv', 'bullet')):
        for row in table(os.path.join(rules, file)):
            page, p = int(row['page']), int(row['pdf'])
            if p != page + 2:
                fail(f'{file}: {row["name"]} is p. {page} but PDF {p}')
            elif not at(row['name'], p, kind):
                fail(f'{file}: {row["name"]} (p. {page}, PDF {p}) is not a heading there')
            checked += 1

    skills = {}
    for (p, kind), names in by_page.items():
        if kind == 'item' and 121 <= p <= 131:
            for n in names:
                skills[n] = p
    for row in table(os.path.join(rules, 'skill-costs.tsv')):
        n = norm(row['skill'])
        if ALIASES.get(n, n) not in skills:
            fail(f'skill-costs.tsv: {row["skill"]} is not a Skill heading (PDF 121-131)')
        checked += 1
    if not fails:
        print(f'ok   - all {checked} names of the tables are headings on their pages')

    if listing:
        n_items = n_sections = 0
        before = fails
        with open(listing, encoding='utf-8') as f:
            for line in f:
                r = line.rstrip('\n').split('\t')
                if r[0] in ('alias', 'exclude'):
                    continue
                if r[0] == 'section':
                    p = int(r[1]) + 2
                    if not any(norm(r[2]) in by_page.get((p, k), set()) for k in ('step', 'item', 'bullet')):
                        fail(f'Besm2Rules: the page {r[1]} (PDF {p}) has no heading {r[2]!r}')
                    n_sections += 1
                    continue
                kind, page, p, name = r[0], int(r[1]), int(r[2]), r[3]
                if p != page + 2:
                    fail(f'Besm2Rules: {name} is p. {page} but PDF {p}')
                elif kind == 'stat':
                    if not at(name + ' Stat', p, 'bullet'):
                        fail(f'Besm2Rules: the Stat {name} (p. {page}, PDF {p}) is not a heading there')
                elif not at(name, p, 'bullet' if kind in ('ability', 'disability') else 'item'):
                    fail(f'Besm2Rules: {name} (p. {page}, PDF {p}) is not a heading there')
                n_items += 1
        if fails == before:
            print(f'ok   - all {n_items} items and {n_sections} rules\' pages of Besm2Rules are headings on their pages')

    # The bookmarks: each table name with a bookmark must point at its page.
    marks = {}
    for title, p in bookmarks(marked):
        for t in {norm(title), norm(re.sub(r'\s*\([^)]*\)$', '', title))}:
            marks.setdefault(t, set()).add(p)
    notes = 0
    seen = set()
    for file in ('attributes.tsv', 'headings-fields.tsv', 'weapon-abilities-disabilities.tsv'):
        for row in table(os.path.join(rules, file)):
            n, p = norm(row['name']), int(row['pdf'])
            n = ALIASES.get(n, n)
            if (n, p) in seen:
                continue
            seen.add((n, p))
            if n not in marks:
                near = difflib.get_close_matches(n, marks, 1, 0.8)
                hint = f', but one is titled {near[0]!r}' if near else ''
                print(f'note - no bookmark for {row["name"]} (p. {row["page"]}, PDF {p}){hint}')
                notes += 1
            elif p not in marks[n]:
                pages = ', '.join(str(x) for x in sorted(marks[n], key=lambda x: x or 0))
                print(f'note - the bookmark {row["name"]} goes to PDF {pages}, the heading is PDF {p}')
                notes += 1
    print(f'{"ok  " if not notes else "note"} - {notes} bookmarks disagree with the tables')

    ordered = [(int(p), k, n) for p, _, k, n in (l.split('\t') for l in found.splitlines())]
    for label, first, last, kind, file, keep in SECTIONS:
        rows = [r for r in table(os.path.join(rules, file))
                if (keep is None or keep(r)) and first <= int(r.get('pdf', first)) <= last]
        names = [norm(r.get('name') or r.get('skill')) for r in rows]
        names = [ALIASES.get(n, n) for n in names]
        heads = [norm(n) for p, k, n in ordered
                 if k == kind and first <= p <= last and (p, n) not in NOT_ENTRIES]
        if keep is not None:  # Abilities and Disabilities share their pages
            others = {norm(r['name']) for r in table(os.path.join(rules, file)) if not keep(r)}
            heads = [h for h in heads if h not in others]
        if heads != names:
            extra = [h for h in heads if h not in names]
            missing = [n for n in names if n not in heads]
            fail(f'{label}: the headings and {file} differ' +
                 (f'; headings not in it: {", ".join(extra)}' if extra else '') +
                 (f'; not headings: {", ".join(missing)}' if missing else '') +
                 ('; the order differs' if not extra and not missing else ''))
        else:
            print(f'ok   - {label} (PDF {first}-{last}): {len(names)}, in the book\'s order')
    if fails:
        print(f'FAIL - {fails} failures')
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
