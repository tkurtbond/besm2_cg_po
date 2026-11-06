#!/usr/bin/env python3
# rulebook-headings.py [-a] [-f] PDF [FIRST LAST]: prints "PDF<TAB>PRINTED<TAB>KIND<TAB>NAME",
# one line per heading of BESM2ER.pdf (the original, with a text layer; not the
# bookmarked copy), in the book's order.  Only headings are printed, never the
# rulebook's text (AGENTS.md); the purchaser line in Helvetica is never read.
#
# The headings are set in OzHandicraftBT-Roman small capitals:
#   KIND "item"   an Attribute, Defect, Skill and the like: capitals at 20 pt,
#                 small capitals at 15 pt;
#   KIND "bullet" a Weapon Attack Ability or Disability and the like: 14 pt,
#                 starting "• ";
#   KIND "step"   a chapter step or section: 24 pt and 18 pt (only with -a,
#                 which also prints the chapter running heads).
#   KIND "field"  with -f, each field an item heading is followed by, as
#                 "Label: value" (Cost, Relevant Stat, Type, Specializations):
#                 the rest of the label's line, and the next lines of the same
#                 block while they continue it (a line ending in "," or "or").
#                 These are costs, Stats, types and names, not descriptions.
# Small capitals come out as lower case, so "Highly Skilled".  PRINTED is
# PDF - 2 (PLAN.md, "The rulebook and its pages").  Needs mutool (MuPDF).
import re, subprocess, sys, xml.etree.ElementTree as ET

FONT = 'OzHandicraftBT-Roman'

def pages(pdf):
    out = subprocess.run(['mutool', 'info', pdf], check=True, capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith('Pages:'):
            return int(line.split()[1])
    sys.exit('rulebook-headings.py: no page count from mutool info')

def heading(parts, big, small):
    """The text of a line made only of FONT at sizes big and small, or None."""
    text = ''
    for size, chars in parts:
        if size == big:
            text += chars
        elif size == small:
            text += chars.lower()
        else:
            return None
    return ' '.join(text.split()) or None

LABELS = ('Cost:', 'Relevant Stat:', 'Type:', 'Specializations:')

def text(line):
    return ''.join(c.get('c') for c in line.iter('char'))

def value(label, box, lines):
    """The value beside a field's label: the rest of its own line, else the
    lines to its right that begin within 2 pt of its top, then the lines just
    below those while the value goes on (ends in ",", "or" or "and")."""
    fonts = list(label.iter('font'))
    own = ' '.join(''.join(c.get('c') for c in f.iter('char')) for f in fonts[1:]).strip()
    if own:
        return ' '.join(own.split())
    beside = sorted((b[0], l, b) for l, b in lines
                    if abs(b[1] - box[1]) < 2 and b[0] > box[0] and l is not label)
    if not beside:
        return ''
    found = ' '.join(text(l) for _, l, _ in beside)
    x, bottom = beside[0][2][0], beside[0][2][3]
    while re.search(r'(,|\bor|\band)\s*$', found):
        below = [(b[1], l, b) for l, b in lines if abs(b[0] - x) < 2 and 0 <= b[1] - bottom < 4]
        if not below:
            break
        _, l, b = min(below, key=lambda t: t[0])
        found += ' ' + text(l)
        bottom = b[3]
    return ' '.join(found.split())

def main(argv):
    every = '-a' in argv
    fields = '-f' in argv
    argv = [a for a in argv if a not in ('-a', '-f')]
    if len(argv) not in (1, 3):
        sys.exit('usage: rulebook-headings.py [-a] [-f] PDF [FIRST LAST]')
    pdf = argv[0]
    first, last = (int(argv[1]), int(argv[2])) if len(argv) == 3 else (1, pages(pdf))
    for index in range(first, last + 1):
        xml = subprocess.run(['mutool', 'draw', '-q', '-F', 'stext', '-o', '-', pdf, str(index)],
                             check=True, capture_output=True).stdout
        page = ET.fromstring(xml)
        every_line = [(l, [float(v) for v in l.get('bbox').split()]) for l in page.iter('line')]
        for line, box in every_line:
            fonts = list(line.iter('font'))
            if fields and fonts and fonts[0].get('name') == FONT \
               and round(float(fonts[0].get('size')), 1) == 10.0:
                label = ''.join(c.get('c') for c in fonts[0].iter('char')).strip()
                if label in LABELS:
                    print(f'{index}\t{index - 2}\tfield\t{label} {value(line, box, every_line)}')
                continue
            if not fonts or any(f.get('name') != FONT for f in fonts):
                continue
            parts = [(round(float(f.get('size')), 1), ''.join(c.get('c') for c in f.iter('char')))
                     for f in fonts]
            found = None
            name = heading(parts, 20.0, 15.0)
            if name:
                found = ('item', name)
            elif len(parts) == 1 and parts[0][0] == 14.0 and parts[0][1].startswith('•'):
                found = ('bullet', ' '.join(parts[0][1][1:].split()))
            elif every:
                name = heading(parts, 24.0, 18.0)
                if name:
                    found = ('step', name)
            if found:
                print(f'{index}\t{index - 2}\t{found[0]}\t{found[1]}')

if __name__ == '__main__':
    main(sys.argv[1:])
