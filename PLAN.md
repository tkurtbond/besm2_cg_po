# PLAN.md - a BESM 2nd Edition Revised character generator in Oberon-2, with poc

`besm2_cg_po` builds a character for *Big Eyes, Small Mouth* 2nd
Edition Revised (BESM2ER) in a window: the user sets Body, Mind and
Soul, picks Attributes, Defects and Skills by name and level, builds
Weapon Attacks from their Abilities and Disabilities, and the program
works out every cost and derived value (ACV, DCV, HP, EP, SV, and the
rest) and keeps the running totals of Character Points, Bonus Points
and Skill Points as the character changes. It holds no rules text:
every name it shows carries its rulebook page, both the page printed
in the book and the PDF's page, and **?** opens the rulebook's PDF at
that page. It saves and loads YAML in besm2_fmt's format, extended as
"A4. The YAML extensions" decides, so pobesm2_fmt2, the Oberon-2 and
Ada `besm2_fmt`s and `besm2-rst` print what it makes.

Beside it, in this repository, is **`besm2_calc_po`** (name to be
confirmed), a command-line program that reads the same YAML, does the
same calculations with the same modules, and checks, fills in or
formats a character ("A3. Where the calculations live").

Both are written in Oberon-2 for poc (Peaseblossom,
`~/Repos/Oberon/Peaseblossom/`), with polibfyaml
(`~/Repos/Oberon/polibfyaml/`) for YAML, Ropes
(`~/Repos/Oberon/Ropes/`) for text and ArgParser for the command line;
the generator also uses pofltk (FLTK 1.4, `~/Repos/Oberon/pofltk/`)
for its window. Their design, build and tests follow `ova_cg_po`
(`~/Repos/RPG/Tools/ova_cg_po/`), the OVA generator, which solves the
same problems (pages beside names, the viewer, overrides, saving
through polibfyaml's emitter, window tests on Xvfb and sway) for
another game; the loader and formatter code is copied from
pobesm2_fmt2 (`~/Repos/RPG/Tools/pobesm2_fmt2/`), as ova_cg_po copies
ova_fmt_po's.

The plan has two parts: **Part A**, the analysis, whose findings are
recorded back into this file before Part B uses them; and **Part B**,
building the programs, in phases, each ending with tests that pass and
a note here marking it `[done]`.

## What exists

| Program | Where | Language, YAML | Notes |
|---|---|---|---|
| `besm2-rst.scm` | `~/current/RPG/Tools/BESM/` | Chicken 5, yaml egg | the original; copied from `besm4-rst.scm` and cut down, so some 4E shapes remain (`enhancements`, `limiters`) |
| `besm2-rst-f.scm` | same | Chicken 5, slibfyaml | reads every document of a file |
| `besm2-rst-e.scm` | same, with `besm-entities.scm` | Chicken 5, yaml egg | entities parsed once into records |
| `besm2-rst-f-e.scm` | same | Chicken 5, slibfyaml | `-f` plus `-e` |
| `besm2_fmt` | `~/Repos/RPG/Tools/besm2_fmt/` | Ada, alibfyaml | **the reference** for golden output; its `QUIRKS.md`, `SOURCE-COMPARISON.md` and PLAN.md list deliberate departures from besm2-rst |
| `obesm2_fmt` | `~/Repos/RPG/Tools/obesm2_fmt/` | voc, olibfyaml | Oberon-2 port of the Ada; `ADA-DIFFERENCES.md` |
| `obesm2_fmt2` | `~/Repos/RPG/Tools/obesm2_fmt2/` | voc, olibfyaml, Ropes | strings as ropes |
| `pobesm2_fmt2` | `~/Repos/RPG/Tools/pobesm2_fmt2/` | poc, polibfyaml, Ropes | `Besm2Entities`, `Besm2Out`, `Besm2Text`, the four formatters: the code both new programs reuse |
| `ova_cg_po` | `~/Repos/RPG/Tools/ova_cg_po/` | poc, polibfyaml, pofltk | the model for the generator: modules, viewer, tests |

### The rulebook and its pages

The rulebook is `~/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf`
(210 PDF pages, 432 x 648 pt), with text in `BESM2ER-nolayout.text`
and `BESM2ER-layout.text` beside it.

- **The PDF has no `/PageLabels`** (`qpdf --json=2
  --json-key=pagelabels` gives `[]`), so a viewer's page box shows the
  PDF page only.
- **The PDF page is the printed page + 2** (PDF page 5 prints 3, 20
  prints 18, 100 prints 98; A2 checks it throughout).
- **Both are always shown** (the user, 2026-11-06): wherever the
  program gives an item's page it gives the page printed in the book,
  for a paper copy or the book's own index and cross-references, and
  the PDF page, for the viewer's page box and its "go to page":
  `Highly Skilled (p. 42, PDF 44)`. See "Pages beside names".
- A viewer is always sent the PDF page (index); evince's
  `--page-label` can't be used, unlike in ova_cg_po, since there are no
  labels.

Contents (printed pages): Character Creation 11 (Summary 12, GM
Discussion 13, Character Outline 14, Stats 15, Attributes 16,
Mecha-Only Attributes 93, Defects 100, Mecha-Only Defects 114, Skill
System 117, Derived Values 129, Background Points 130); Game Mechanics
132 (Weaponry and Equipment 149, Expanded Combat 156-161, Staged Stat
Cost 166); Reference Section 192; Index 196; Character Sheets 202.

### The YAML today

From the fixtures (`besm2_fmt/test/data/`, `~/current/RPG/Tools/BESM/test-data/`):
a file is one or more documents, each a sequence of entities
(characters, templates, mecha, items). An entity has `name`,
`tagline`, `size`, `description`, `mecha`, `stats` (`{name, value,
points}`), `derived` (`{name, value, alternatives}`), `attributes`
(`{name, level, points, effective, details, elements, enhancements,
limiters}`), `defects` (`{name, points, details}`) and `skills`
(`{name, level, points, specialisations}`). `composite-2e.yaml` also
has keys no program knows (`bogus:`, `page:`), which suggests unknown
keys are ignored; A1 confirms it for every program.

**Every cost is written by hand**: the formatters total `points`,
they compute nothing. And the generator needs things that are only
in free text today:

- a Weapon Attack's damage, Abilities and Disabilities are in
  `details` (`Damage 45, Auto-fire, Area Effect, Limited Shots ×2 [3
  shots], Stoppable`);
- whether a Weapon Attack is the primary attack (4 points a level) or
  a secondary one (2 points at the primary's level, 1 below it, p. 82
  "Alternate Attacks"; the Coleopteran's Railgun 3 costs 12, its
  Plasma Fist 2 and Rocket Pod 2 cost 1 each) is only in the points;
- a Defect's rank is only its `points` (`-2`), with no `level`;
- what an Attribute or Defect is about is packed into its name
  (`"Own a Big Mecha: FV2021 Coleopteran"`, `"Weapon: Railgun"`,
  `"Unique Defect: Obsessed by Military History"`), and the name is
  sometimes abbreviated (`Weapon` for Weapon Attack);
- the link from Own a Big Mecha to the mecha entity in the same file
  is by that packed name, by eye;
- nothing records the campaign's Character Points, Background Points,
  the Skill Points, the genre that sets Skill costs, or the optional
  rules in use.

## Part A - Analysis

Each step ends by writing its findings into "Findings" below (or into
a section of its own if large), with the pages and the date, so Part B
works from this file, not from memory. Scratch scripts go in
`tools/` if they are to be kept (as ova_cg_po's
`tools/rulebook-headings.py`), else the scratchpad.

### A1. The existing programs

Goal: one description of what a BESM2ER YAML file *means* today, and
which program is right where they disagree.

1. Read `besm2-rst.scm` and `besm-entities.scm` (the entity records of
   the `-e` variants), and diff `besm2-rst.scm` against `-f`, `-e`,
   `-f-e`, to list every key each reads, whether it is required, and
   how it is shown. Confirm the four variants agree but for the
   multi-document reading the README describes.
2. Read besm2_fmt's PLAN.md (sections 6, 9, the open questions),
   `QUIRKS.md`, `SOURCE-COMPARISON.md`; obesm2_fmt's
   `ADA-DIFFERENCES.md`; pobesm2_fmt2's README and PLAN.md. Make one
   table of the known departures (byte vs. character underlines,
   case folding, empty `effective`, empty lists, multi-document files,
   U+2212 minus) and which side the new programs take: **besm2_fmt's**,
   since it is the golden reference, unless the user says otherwise.
3. Write down the schema as `besm2_fmt` accepts it: each key, its
   type, required or not, and **what each of the eight programs does
   with an unknown key** (ignored, or an error), and with a known key
   of an unexpected shape. That decides whether a file with the new
   keys of A4 can be given to a formatter not yet taught them.
4. Run all the formatters over every fixture (the existing `make
   compare` targets in each repo) and confirm they still agree, so the
   baseline is known before anything changes.
5. Note which pobesm2_fmt2 modules the new programs can copy unchanged
   (`Besm2Entities`, `Besm2Out`, `Besm2Text`, `Besm2Config`, the
   formatters) and what each depends on, and the module names that
   would clash (pobesm2_fmt2 already has `Besm2Cli` and `Besm2Fmt`).
6. Measure how the formatters are built to grow: what it took to add
   the last key to all of them (git history), as evidence for A3.

#### A1 results (done, 2026-11-06)

Read from the sources and docs, and checked by running every program on
small test files (kept only in the scratchpad). Line numbers are
`besm2-rst.scm` (rst), `besm-entities.scm` (ent) and
`besm2_fmt/src/besm2_fmt-entities.adb` (adb).

**A1.4, the baseline.** Every compare and test target passes on the
programs as they are: the Scheme `make compare-fyaml compare-treefyaml
compare-entity compare-entitytree`, 290 matches; besm2_fmt `make test`,
441 ok; obesm2_fmt 554 ok; obesm2_fmt2 1732 ok and pobesm2_fmt2 2874 ok,
each with 1160 compare runs against obesm2_fmt; no `not ok` anywhere,
no working tree changed.

**A1.1, what the Scheme programs read.** A document is a sequence of
entity mappings. Entity keys, all optional: `name`, `tagline`,
`description`, `size`, `mecha`, and the sequences `stats`, `derived`
(kept in order), `attributes`, `defects`, `skills` (sorted by name,
ignoring case).

| Item | Required | Optional |
|---|---|---|
| stat | `name`, `value`, `points` | |
| derived | `name`, `value` | `alternatives` (strings) |
| attribute | `name`, `level`, `points` | `details`, `effective`, `elements`, `enhancements`, `limiters` |
| defect | `name`, `points` | `details` |
| skill | `name`, `level`, `points` | `specialisations` |

- An enhancement or limiter is `Name` (counts as 1), `[name, n]` or
  `[name, n, applies-to...]`. The sign shows which list it is in: −
  for an enhancement, + for a limiter. The `details` text is joined with
  `; ` from three parts in order: the sorted elements, the sorted
  enhancements and limiters together, then `details` (rst:320-346).
- Derived names ACV, DCV, DM, HP, EP, SV, AR are written out in full in
  grid and raw ms, and printed as abbreviations in terse and h-m-m.
- The four variants are the same program apart from YAML access; `-e`
  and `-f-e` load into records first (ent), which changes no output.
  They differ only in how the two YAML libraries type values, in error
  text, and in which documents of a multi-document file they read (the
  README's account, confirmed). How the libraries type values:
  - yaml egg (rst, `-e`): YAML 1.1. A quoted `"6"` is not a number, but
    `6.5` is accepted. `mecha` is true for anything but `false`/`no`,
    even a quoted `"false"`, which was confirmed by running it.
    `enhancements: Area` written as a scalar is silently dropped.
  - slibfyaml (`-f`, `-f-e`): `points` must be an integer, and `mecha`
    must be `true` or `false`.

**A1.2, the departures** (besm2-rst against besm2_fmt; the Oberon
ports follow besm2_fmt). The new programs copy pobesm2_fmt2's
modules, so they take **besm2_fmt's side** on all of them (open
question 1, decided 2026-11-06).

| Departure | besm2-rst | besm2_fmt | Recorded in |
|---|---|---|---|
| Header underline | characters | bytes (a UTF-8 name underlines too long; a defect the ports copy) | obesm2_fmt ADA-DIFFERENCES §2.2 |
| Case-insensitive sort | Unicode | ASCII/Latin-1 bytes, stable | §2.1, §1.4 |
| Minus | ASCII; `-n` gives U+2212 | U+2212; `-n` gives ASCII | §4.1 (besm2_fmt PLAN.md §8 still says the old default) |
| `effective: ""` | `1 ()` | nothing | §4.2 |
| Before `(effective)` | no-break space | space | §4.3 |
| Multi-document files | last (yaml egg), first (`-f` flag), all (fyaml) | all, entity numbers running on | §4.4 |
| Empty lists or details | `()` or a stray `.` | left out | §4.10 |
| Integer overflow, real numbers, non-boolean `mecha` | accepted | errors | §4.7 |
| A file with no documents | error, status 1 | nothing, status 0 | §4.8 |
| `-d` | traces | accepted, does nothing | §4.6 |
| Error wording | Chicken's | its own; the Oberon ports add `FILE:LINE:COL` and a node path | §4.9, §3.1-3.5 |

The quirks fixed in all of them (besm2_fmt QUIRKS.md; ADA-DIFFERENCES
§5.1) now behave the same everywhere. Two departures between the Ada
and the Oberon ports are **in no document** (both confirmed by running
them):

- **YAML aliases.** besm2_fmt doesn't resolve them: `points: *p` gives
  `not a valid integer: "p"`, `name: *n` prints `n`, and `- *h` gives
  `not a mapping`. The three Oberon ports resolve them.
- **Overflow in a total.** `points: 2147483647` plus another stat:
  besm2_fmt dies with `raised CONSTRAINT_ERROR ... overflow check
  failed` (status 1, nothing printed for that file). The Oberon ports
  wrap and print `Hero (2147483647 BP)`, status 0.

Decided by the user (2026-11-06; open question 9): neither is
fixed in the formatters. Real Character, Bonus and Skill Point values
stay far below 32 bits (under 500, likely), so overflow takes a
mistyped file. Both are recorded in obesm2_fmt's ADA-DIFFERENCES.md
as known departures, and the new programs catch them (A3, `--check`).

**A1.3, the schema and unknown keys.** besm2_fmt accepts what the
Scheme table above shows, with these types:

- `str` is a required scalar.
- `int` is a 32-bit integer. Decimal, `+N`, quoted, `0x`/`0o`/`0b` and
  `_` are accepted. A real number, an empty value or one out of range is
  an error.
- `bool` (only `mecha`) is `true`/`false` in any case. `yes` is an
  error.
- A sequence key present with no value (`stats:`) is an error.
- A defect has no `level`. `specialisations` is British only.
- An error in an entity skips that entity, the run goes on, and the
  exit status is 1. A YAML syntax error ends its file.

What all eight programs do with keys:

- **They ignore unknown keys.** Every key of A4 (`subject`, `creation`,
  `overrides`, a defect's `level`, `abilities`, `damage`, and a stat's
  `base` and so on) gave output identical to the file without them,
  status 0, in all of them.
- **A known key of the wrong shape** gives status 1 and the same
  stdout from the four Ada and Oberon programs; only the wording
  differs.

So a file with A4's keys can be given to any formatter today. The
formatters don't fail on it, they just don't print the new keys.

That makes the order of the rollout matter. Once `subject` is split out
of `name`, a formatter not yet taught `subject` prints "Own a Big
Mecha" without its mecha. So the generator and `--upgrade` write the
split form only after all the formatters print `subject` (Part B,
phase 3). Until then they keep the packed `name: subject` in `name`.

**What they compute: sums of the written `points`, nothing else.**

- The entity total is stats + attributes + defects. Skills are
  totalled apart and never added in (rst:506; entities.ads:109).
- Nothing is derived or checked: not the derived values, not points
  against levels, not budgets.
- "BP" is just the label of a negative number in terse and h-m-m:
  `abs(n)`, then BP if n < 0, else CP. A stat of −8 prints `8 BP`.
- A defect with positive `points` prints as `−2` in grid but adds +2 to
  TOTAL. Nothing catches it.

So everything A2 finds is new code in `Besm2Calc`, and `--check`
reports a positive defect, a negative stat and the like.

**Mecha labels** (answers A4's question): with `mecha: true`, terse
and h-m-m say `MP`/`MBP` for CP/BP, and the headings become "Mecha
Sub-Attributes" and "Mecha Defects". Grid and raw ms show nothing
different. That is what a mecha needs, so no change.

**What the saved files must be like**, so that all eight programs read
them alike (from A1.1-A1.3):

- one YAML document per file;
- no aliases;
- numbers as plain unquoted decimal integers in 32-bit range;
- `mecha: true` or `false` exactly;
- no empty lists or empty strings (the key left out instead);
- defects with negative `points`.

`Besm2Save` does this and `TestSave` checks it.

**A1.5, what can be copied** from pobesm2_fmt2 (2400 lines):

| Module | Lines | Copy? |
|---|---|---|
| `Besm2Text` (rope helpers) | 214 | unchanged |
| `Besm2Config` (the settings, exported VARs) | 66 | unchanged; the window sets the VARs, as `OvaMarkdown` sets `OvaConfig.format` |
| `Besm2Out` | 112 | **not yet**: it has no `ToRope`/`TakeRope`. First port ova_fmt_po f6eaa1c ("Keep output in a rope", +66/−5 with a `TestOut`) into pobesm2_fmt2, then copy |
| `Besm2Layout` | 224 | unchanged |
| `Besm2Entities` | 439 | unchanged |
| `Besm2Grid`, `Besm2Terse`, `Besm2Hmm`, `Besm2RawMs` | 252, 207, 223, 290 | unchanged; each exports only `ProcessEntity` |
| `Besm2Cli`, `Besm2Fmt` | 205, 168 | no: pobesm2_fmt2's command line and main. The new programs have their own, under names none of the copied modules has |

- `Besm2Entities` can't hold the generator's model. Its fields are
  read-only, its only entry is `Load(node, ...)` (line 403), levels are
  ropes, and enhancements and limiters are already flattened into
  signed `details` text.
- So, as ova_cg_po does (`OvaSave.ToEntity`, OvaSave.Mod:424-436), the
  generator emits the character as YAML and `Load`s it back to print
  it. `Besm2Character` is the model, and `Besm2Entities` stays an
  unchanged copy.
- ova_cg_po's six copies are byte-identical to ova_fmt_po's. Its rule
  (ova_cg_po AGENTS.md) is to change them upstream, then copy again,
  never editing the copies. `make test` enforces it by formatting every
  saved fixture with the real ova_fmt_po and comparing. besm2_cg_po
  does the same with pobesm2_fmt2.

**A1.6, what a change costs** (git history):

- No YAML key has been added to the BESM programs since `elements`
  (BESM bcf603f, 2023-02-01).
- A change to the output, e.g. "skill total only under `-s`", takes a
  commit in each repository: Scheme 3ff684d (5 `.scm` files, no golden
  files); besm2_fmt bd00d5f; obesm2_fmt f088195 and obesm2_fmt2 c24442f
  (97 golden files each); pobesm2_fmt2 later inherited it. Changing the
  source is a few lines; most of the work is regenerating the golden
  files (366 of them from 58 cases).
- OVA's generator keys took ova_fmt 5334a80 (13 files) and ova_fmt_po
  546192b (73, 60 of them golden), then a re-copy in ova_cg_po.

So **a key the formatters ignore costs them nothing, and one they print
costs 5 repositories and roughly 80-100 golden files in each Ada and
Oberon one.** A4 already prints only `subject` and the Weapon Attack
keys; A1 confirms keeping it to those.

### A2. The rules

Goal: every rule the programs compute, each with its page, and every
item they list, each with its page, checked against the PDF. Only
names, numbers and page numbers go into the programs or this file; no
descriptions.

1. **Page offset.** Confirm PDF = printed + 2 throughout (several
   pages in each chapter, and the reference pages), and note any
   unnumbered plates that would shift it. If it shifts anywhere, the
   tables hold both numbers rather than computing one from the other.
2. **Character creation** (pp. 11-16, 129-131): starting Character
   Points by power level (p. 13), the Stat limits (1-12, the points
   allotted to Stats, p. 15), Attribute levels (1-6, and above 6),
   the Bonus Points from Defects, Background Points (p. 130), Skill
   Points (20, plus Highly Skilled, less Unskilled, p. 117), and how
   the GM's limits (a ceiling on Stats, on Attribute levels, on Bonus
   Points) are stated.
3. **Stats and derived values** (p. 15, 129): Body/Mind/Soul cost;
   ACV, DCV, HP, EP, SV, and how Attributes and Defects change them
   (Combat Mastery, Defence Mastery, Massive Damage, Damn Healthy!,
   Energy Bonus, Armour, Toughness, Extra Attacks, Size, ...); the
   `alternatives` (hand-to-hand vs. ranged ACV with Skills). Work
   every derived value of every fixture character by hand, as
   ova_cg_po did with OVA's samples, and list any the rules don't
   reproduce.
4. **Attributes** (pp. 16-99, Mecha-Only 93-99): for each, its name,
   printed and PDF page, cost per level (fixed, or variable), level
   range, whether it takes a subject (Own a Big Mecha's mecha, Weapon
   Attack's name, Unique Attribute's), whether it is mecha-only,
   whether it grants other points (Highly Skilled: Skill Points; Own a
   Big Mecha: Mecha Points; Item of Power, Companion, Servant, ...),
   and what derived values it changes. Also the Attributes with
   sub-choices (Elemental Control's elements, Features, Sixth Sense,
   Combat Technique, ...), and the abbreviations the existing files use
   (`Weapon`), to keep as aliases.
5. **Weapon Attack** (p. 81) and its **Abilities** (from p. 83) and
   **Disabilities** (from p. 89): the base damage (15 a level), each
   Ability's and Disability's name, pages, its effect on damage (each
   -15 or +15, per the example on p. 92), how many times it may be
   taken, what its detail is (Limited Shots' `[3 shots]`), and which
   exclude each other; the primary and secondary attack costs
   ("Alternate Attacks", p. 82); and the Expanded Combat rules (pp.
   156-161) if they change any of it. This is the BESM2 analogue of
   OVA's Perks and Flaws.
6. **Defects** (pp. 100-116, Mecha-Only 114-116): name, pages, the
   Bonus Points per rank (1, 2, 3, and any with other scales),
   subject, mecha-only, and the Defects that remove points elsewhere
   (Unskilled).
7. **Skills** (pp. 117-128): each Skill's name, pages, its cost per
   level **by genre** (the Skill cost table), its specialisations
   and their rule, and which Stat it is used with. Record the genres
   the table has.
8. **Mecha** (Own a Big Mecha, Mecha Points, Mecha-Only Attributes
   and Defects, Size): how a mecha's points come from its owner's
   Attribute, so the programs can check a mecha entity against its
   owner.
9. **Staged Stat Cost and other options** (p. 166, and any optional
   rule in chapters 2 and 4 that changes costs): which the programs
   offer, like ova_cg_po's Character > Limits.
10. **Errata**: `besm-2nd-rev-errata.ms.pdf` beside the rulebook:
    apply each erratum that changes a cost, page or rule, and say so.
11. **Every page by machine**: as ova_cg_po's
    `tools/rulebook-headings.py` did, find each entry's heading in the
    PDF by its font, and compare with the tables (`make
    check-pages`); then check a sample by eye. Record the counts of
    Attributes, Defects, Skills, Abilities and Disabilities.

#### A2 results (done, 2026-11-06)

The tables are in `rules/` (names, costs, levels, limits and pages
only, with labels in our own words; nothing quoted, and the purchaser
line never read): `headings.tsv` (every heading by font, from
`tools/rulebook-headings.py -a`), `headings-fields.tsv` (each item's
Cost, Type, Relevant Stat and Specializations fields),
`attributes.tsv` (how each Attribute's cost is chosen, its maximum
Level, subject and grants, and the Mecha-Only Defects),
`weapon-abilities-disabilities.tsv`, `skill-costs.tsv` (Table 2-4)
and `errata.tsv`.  Phase B turns them into `Besm2Rules`.

1. **Page offset** (done): printed = PDF - 2 on all 195 numbered
   pages; the unnumbered ones (PDF 1-3, 6, 13, 134, 154, 169,
   204-210) are the cover, chapter openers and sheets, and shift
   nothing.  The bookmarks agree with the headings for 370 entries;
   the ones that didn't (all fixed by the user, 2026-11-06; see 11):
   "Force Field Disabilities" goes to PDF 39 (the heading is PDF 38,
   p. 36); "Mecha-Only Defects" and "Step 8: Background Points" have
   no destination; Linked (Attribute) (p. 87, PDF 89) has no bookmark;
   and these titles are misspelt (their pages are right): Forward,
   Small Mount, Attiributes, Insubstatial, Organization Ties, Size
   Changge, Unique Character Arribute (twice), Manoevre Bonus, Hanger
   Queen, Skills and Specialties, "Table 4-6 blowing Up Worlds".
2. **Creation** (pp. 12-16, 100, 117, 130): starting Character
   Points 15/20/25 (low), 30/35 (average), 40/45 (high), 50/55 (very
   high), 60+ (extremely high) (p. 13); each Stat 1-12 at 1 point a
   point, only one Stat at 12 (p. 16); Attributes Level 1-6 (a few
   1-2) (p. 16); no more than 8 Defects recommended (p. 100);
   20 Skill Points, +10 a Level of Highly Skilled, -10 or -20 for
   Unskilled (p. 117); 1-3 Background Points (p. 130).
3. **Derived values** (pp. 129-130): ACV = (Body + Mind + Soul) div 3;
   DCV = ACV - 2; HP = (Body + Soul) x 5; EP = (Mind + Soul) x 5;
   SV = HP / 5, rounded up (p. 130; corrected 2026-11-06 in step 2,
   was "div 5").  Changed by Combat Mastery (ACV and DCV +1 a
   Level, p. 130's example), Damn Healthy! and Toughness (HP), Energy
   Bonus (EP), Not So Tough and Diminutive (HP).  Place of Power's
   Energy Points are a pool of its own, not added to EP (corrected
   2026-11-06 in step 2).
   **The fixtures by hand:** Enyon Boase comes out exactly (stats 20
   + attributes 18 - defects 3 = 35; ACV 6 + 3 = 9, DCV 7, HP 70,
   EP 60, SV 14); the FV2021 Coleopteran too (Own a Big Mecha 2 =
   40 Mecha Points = attributes 44 - defects 4; HP 40 + Toughness 2
   x 20 = 80).  But the fixtures use names from BESM 2nd edition or
   Big Robots, Cool Starships, not the Revised rulebook (Armour, AR,
   Partial Armour, Super-Strength, Accessories, `Weapon:`, "Hanger
   Queen", "Unique Defect"), so the programs need aliases and must
   accept unknown names (open question 11).  Enyon's own odd names
   (Extra Actions, Leadership, Political Sciences) and his 25 SP were
   bugs, a botched conversion of his 4th Edition self, and are fixed
   (see "Decided": the Red Planet Blue Helmets characters).
4. **Attributes** (pp. 20-99, Table 2-2 pp. 18-19): 89, all in Table
   2-2 at the same page.  About 30 have a cost per Level that depends
   on an option, and some add flat points (attributes.tsv).  Maximum
   Level 6, except 2 for Elasticity, Heightened Awareness,
   Invisibility, Life Support, Meld, Precognition, Shape Change,
   Special Defense and Summonable; Highly Skilled has none; Unique
   Character Attribute's cost and maximum are the GM's.  Grants:
   Highly Skilled 10 Skill Points a Level; Own a Big Mecha 20 Mecha
   Points a Level (p. 59); Magic Power Points; Size Change Defects.
   Table 2-2 against the entries: Meld 2 or 4 (entry 2, 4 or 8);
   Mechanical Transformation 2-4 (entry can reach 5); types and
   Stats of Elasticity, Heightened Senses, Special Movement, Healing,
   Water Speed and Manoeuvre Bonus differ; Table 2-2's "Magic (or
   Psionics)" is headed "(and Psionics)"; Magic (p. 49) sends
   Dynamic Sorcery to p. 86, which is p. 26.  The entries win.
   Super Transformation is Mechanical Transformation's cost + 1 a
   Level (Retro p. 164), so 3 for a half-powered form and 5 for a
   full-powered one, as Mechanical Transformation's 2 and 4.
5. **Weapon Attack** (pp. 81-92): 4 points a Level; damage 15 x
   (Level - Ability slots + Disability slots), at least 15 unless No
   Damage; a secondary attack 2 points at the primary's Level, 1 at a
   lower Level (p. 82); a Different Gunner +5 Mecha Points (p. 82); as
   Personal Gear, 5 damage a Level.  34 Abilities (pp. 83-89), 21
   Disabilities (pp. 89-92; 33 and 22 here before A2.11 counted the
   headings), with their slots (most 1; Aura 2,
   Auto-Fire 3, Incapacitating 3, Contagious 3 or 6, Soul Attack 5,
   Self-Destruct 4, Melee 2, ...), maximums and exclusions.  **Auto-Fire
   counts as 3 in its entry (p. 84), but as 1 in the Hellcat (p. 92),
   the errata's Grey Typhoon, and the Coleopteran's Rocket Pod** (open
   question 12).  Other slips: the Vulcan Cannon is priced 16 for
   Level 3; Keiko's Bug Spray (p. 51) does 0 without No Damage;
   "Limited Uses" and "Area" in two exclusions mean Limited Shots and
   Area Effect.  Expanded Combat (pp. 156-161) changes no cost.
6. **Defects** (pp. 101-116, Table 2-3 p. 100): 39 Normal and Special,
   10 Mecha-Only; all 1-2 BP a rank except Awkward Size and Crew
   Requirement (1-6) and Diminutive (3 or 6); the entries' ranks agree
   with Table 2-3.  Table 2-3 writes "Owned by a Megacorp" and "Wind
   Powered" (headings: Owned By A Megacorp, Wind-Powered).
7. **Skills** (pp. 117-128): 52, all in Table 2-4 (p. 119), whose
   genres are Cyberpunk, Hot Rods and Guns, Martial Arts, Medieval
   Fantasy, Modern Military, Occult Horror, Space Opera and Teenage
   Romance, at 1-6 Skill Points a Level, "-" where a Skill isn't
   offered.  Levels 1-6; one specialisation comes with the Skill, and
   each extra costs 1 Skill Point (p. 118).  Combat Value, Health
   Points and Energy Points are headed like Skills but are the
   derived values (p. 129).  Some Relevant Stat and Specializations
   fields (Artisan, Boating; Gaming, Piloting, Heavy Weapons) are cut
   short by the extraction and need reading by eye.
8. **Mecha** (pp. 59-61, 93-99, 114-116): 20 Mecha Points a Level of
   Own a Big Mecha, shared among the owner's mecha or pooled with
   other players; a mecha starts with 40 HP; Mecha Defects give Mecha
   Bonus Points spent only on the mecha.
9. **Staged Stat Cost** (p. 166, Table 4-7, optional): Stat 1-5 cost
   their value; 6 = 7, 7 = 9, 8 = 11, 9 = 14, 10 = 17, 11 = 20,
   12 = 24.  Variable Damage (p. 162) changes no cost.
10. **Errata** (two pages): the only change of a page is the
    Hellcat's reference (p. 92 says p. 127; it is p. 61); nothing
    changes a cost.
11. **Every page by machine** (done, 2026-11-06): `make check-pages`
    runs `tools/check-pages.py` (about 8 seconds; not part of `make
    test`, as it needs the PDFs and mutool).  It finds the headings by
    font again and checks that:
    - `rules/headings.tsv` is still exactly them (798: 276 items, 271
      bullets, 251 steps);
    - each of the tables' 409 names (`attributes.tsv`,
      `headings-fields.tsv`, `weapon-abilities-disabilities.tsv` and
      the Skills of `skill-costs.tsv`) is a heading of its kind on its
      PDF page, and that page is the printed page + 2;
    - each section's headings, less 9 that are sections inside an
      entry or notes (Force Field Abilities and Disabilities, Magic
      Options, the Wealth sample, Hand-Held Weapons and Personal Gear
      on PDF 85, Combat Value, Health Points, Energy Points), are its
      table's names in the book's order.
    Five table names are shorter than their headings, matched as
    aliases: ECM, Own a Big Mecha, Weapon Attack, A.I. (the headings
    add the full name or the abbreviation) and Wind Powered (Table
    2-3's spelling of Wind-Powered).  The counts: **76 Attributes, 13
    Mecha Attributes, 39 Defects, 10 Mecha-Only Defects, 52 Skills,
    34 Weapon Attack Abilities and 21 Disabilities** (Linked and
    Penetrating each have two headings, so 34 Ability headings are 32
    names).  Every one agrees; nothing in the tables changed.  Shown
    to fail with four planted bugs: a page, two Abilities swapped, a
    misspelt Skill, and a PDF page that isn't printed + 2.
    The bookmarks, checked as a second source, disagreed only where
    result 1 already said (misspelt titles, Force Field Disabilities
    at PDF 39, no Linked (Attribute)); the check prints these as
    notes and passes.  The user then fixed the bookmark list and
    `BESM2ER_bookmarked.pdf` (2026-11-06), and now every bookmark
    agrees: the misspellings, Force Field Disabilities (PDF 38), Linked
    (Attribute) (PDF 89), the Wealth sample's title, "Mecha-Only
    Defects" (PDF 116), "Step 8: Background Points" (PDF 132), Table
    3-4's capital M and Table 3-5 Critical Damage (PDF 148).  Every
    bookmark titled like a heading goes to that heading's page, except
    the chapters, which go to their opening pages (which have no
    heading); "Shock Value" has two, PDF 132 and PDF 163, for the
    book's two headings of that name.  Two pages looked at by eye
    agree with the headings by font: PDF 44 (printed 42; Highly
    Skilled, Illusion) and PDF 92 (printed 90; Drop Shields to Low
    Penetration).
12. **Checked against BESM Retro Second Edition and BESM1E** (AGENTS.md;
    Retro's PDF page is also its printed page + 2).  Retro sides with
    BESM2ER's entries against Table 2-2: Meld 2, 4 or 8 (Retro
    p. 95), Mechanical Transformation 2 or 4 (p. 159), Elasticity and
    Heightened Senses Species/Technological, Special Movement
    Paranormal/Species (Retro's table, pp. 64, 80, 121; "Racial" is
    "Species" there).  Auto-Fire ("Autofire") counts as 3 in Retro
    too, and Retro's Hellcat stat block now agrees (Quad Laser Cannon,
    Level 2, 30 damage: Autofire against Fixed, Low Penetration and
    Unreliable); only its worked example still counts 1.  Keiko's Bug
    Spray is still 0 damage without No Damage in Retro, so the
    generator warns rather than refuses below 15.  The Coleopteran is
    from Big Robots, Cool Starships (PDF 95), converted by the user, so
    its Armour, Partial Armour, Super-Strength and AR are BRCS's;
    "Hanger Queen" is a misspelling (BRCS and BESM2ER both say
    Hangar).  Extra Actions and Political Sciences (Enyon Boase) are
    in none of BESM1E, BRCS, Hot Rods and Gun Bunnies, BESM2ER or Retro
    as items; Leadership and Persuasion are in none but Retro, where
    they are Skills (Table 6-2, p. 194, PDF 196; corrected 2026-11-06,
    see below).  They came from his 4th Edition version, and are now
    fixed or a house rule (see "Decided").

    **Retro against BESM2ER, item by item** (2026-11-06).  Retro has no
    list of its own changes: its foreword (p. 4, PDF 6) promises only
    "expanded and updated content", and the list on pp. 12-13 (PDF
    14-15) is of 2nd to 4th Edition.  So Retro's headings (by font:
    OzHandicraftBT-Roman-SC7 at 24/16.8 pt for items, Calibri-Bold
    12 pt for Weapon Attack Abilities and Disabilities) and tables were
    compared with rules/*.tsv.  Pages are Retro's, printed and PDF.
    - *The same:* Stats cost 1 point per value (Table 3-1, p. 27, PDF
      29); ACV, DCV, Health, Energy and Shock Value have the same
      formulas (p. 212, PDF 214); Skill Points are 20 + 10 per Level
      of Highly Skilled; every Defect's BP range (Awkward Size 1-6,
      Diminutive 3 or 6, Crew Requirement 1-6, the rest 1-2); all 13
      Mecha Attribute costs; and the slots of every Ability and
      Disability both books have.
    - *Attributes* (Table 4-1, p. 50, PDF 52).  Added: Mimic 3/Level
      (p. 98, PDF 100), Nullify 3 (p. 103, PDF 105), Transfer 3
      (p. 133, PDF 135), Unknown Power, Varies (p. 136, PDF 138; not in
      Table 4-1), Wealth 3 (p. 137, PDF 139; BESM2ER's Unique Character
      Attribute sample).  Renamed: Focussed Damage, Organisational Ties,
      Special Defence, Unique Attribute, Weapon (or Special) Attack,
      Magic (was Magic (and Psionics)); "Racial" is "Species".  Costs:
      Dynamic Sorcery's entry says 2 or 4 (Table 4-1 and BESM2ER: 1, 2
      or 4); Transmutation 1, 2, 3 or 4 (BESM2ER 1, 2 or 4).  Astral
      Projection is 1 in Table 4-1 but 3/Level in its entry, as in
      BESM2ER: a slip.  Types: Art of Distraction is Normal,
      Paranormal; Meld Paranormal, Technological; Massive Damage
      "Permanent" (a slip).
    - *Defects* (Table 5-1, p. 167, PDF 169; Table 5-2, p. 187, PDF
      189).  Added: Blind Fury 1-2 BP Special (p. 170, PDF 172),
      Rudimentary Manipulation 1-2 BP Normal (p. 181, PDF 183), Social
      Fault 1-2 BP Normal (p. 183, PDF 185).  Weak Point, BESM2ER's
      Unique Defect sample, is a Defect of its own (p. 186, PDF 188).
      Unique Character Defect is Unique Defect (p. 184, PDF 186).
      Inept Combat is missing from Table 5-1 but its entry is there
      (p. 174, PDF 176).
    - *Weapon Attack* (Table 4-3, p. 140, PDF 142; Table 4-4, p. 150,
      PDF 152).  New Abilities, 1 slot each: Demoralise (p. 143, PDF
      145), Lethargy (p. 146, PDF 148), Selective (p. 148, PDF 150).
      New Disability: Two Hands (p. 153, PDF 155), with no slot count
      in Table 4-4.  Renamed: Autofire, Unique Disability.
    - *Skills* (Table 6-2, p. 194, PDF 196; Table 6-3, p. 209, PDF
      211), the biggest change.  The genres are Action Adventure,
      Cyberpunk, High Fantasy, Mecha Drama, Occult Horror, Romantic
      Comedy, Space Opera and Urban Fantasy (Hot Rods and Guns, Martial
      Arts, Medieval Fantasy, Modern Military and Teenage Romance are
      gone).  64 Skills to BESM2ER's 52.  Gone: Computers, Cooking,
      Driving, Electronics, Piloting, Stealth.  Added: Civilisation,
      Climbing, Domestic Arts, Empathy, Engineering, Environmental
      Sciences, Etiquette, Leadership, Listening, Naturopathy, Occult,
      Occupation, Persuasion, Powerlifting, Religion, Search, Sneak,
      Street Sense.  The Defense Skills are spelt Defence.  In the three
      genres both have (Cyberpunk, Occult Horror, Space Opera), 24 of
      the 43 shared Skills cost differently, mostly by 1.
    - *Optional rules.*  BESM2ER's Staged Stat Cost (Table 4-7, p. 166,
      PDF 168) is gone; Table 8-7, Alternate Stat Costs (p. 261, PDF
      263), offers "Free, then Three" and "Bracket Costs" instead.
    - *Added without costs:* species and class templates (pp. 31-46),
      Tables 2-1 and 2-2 (power levels and benchmarks, pp. 18-20),
      Session Zero, monsters (from p. 268), example builds.

    None of this changes what the programs compute, which is BESM2ER.
    Retro characters would need a second skill-cost table, rows for
    the new items, and Table 8-7 for Staged Stat Cost, all behind one
    switch (say `creation.options: {ruleset: retro}`); not planned.

### A3. Where the calculations live (decided, 2026-11-06)

Two ways to have every number computed:

**(a) Change the eight existing formatters** (four Scheme, the Ada,
three Oberon-2) so each computes the costs and derived values.

- Every rule table and every calculation (A2: some hundreds of
  items, the genre Skill table, the derived values, mecha points,
  Weapon Attack damage) written eight times in four languages, and
  kept byte-for-byte in agreement, as AGENTS.md requires of them. The
  tables are the larger and harder part of the work, and the part most
  likely to be revised (errata, a misread page), so every correction
  is also made eight times.
- The formatters format more than BESM2ER characters: templates,
  items, mecha, and entries from other books (the Coleopteran is
  `BRCS, p. 94=95`) whose Attributes aren't in this rulebook's tables.
  For those they would still have to print the written numbers, so
  they would need both behaviours, and a rule for which applies.
- A formatter that silently changes a number the user wrote changes
  their sheet; one that only warns is a checker, not a formatter.
- Their golden tests and the byte-for-byte comparisons between them
  stay as they are only if computing is off by default, which leaves
  most of the work unused by the formatting they exist for.

**(b) Keep the formatters as formatters, and compute in one place.**
The formatters keep printing what the file says. The calculations
live once, in Oberon-2 modules with no window (`Besm2Rules`,
`Besm2Calc`, `Besm2Character`, `Besm2Save`), used by two programs in
this repository:

- `besm2_cg_po`, the window, which **writes every number into the
  file it saves** (the one in effect: the computed one, or the user's
  override), so any formatter prints a generated character correctly
  without computing anything;
- `besm2_calc_po`, a command-line program for files made or changed
  by hand or by other tools:
  - `--check`: compare every number in the file with the computed
    one; list the differences (with item, printed and PDF page) on
    standard error; exit status 1 if there are any. It also
    reports as errors, naming entity, item and value, every `points`
    or `value` outside −999..999 (e.g. `Hero: stats/Body: points
    2147483647 is outside -999..999`), which catches the overflow the
    formatters don't, and as a warning every YAML anchor or alias,
    which besm2_fmt and the Oberon ports read differently (A1
    results). The generator applies the same range to what is typed
    and never writes an alias;
  - `--fill` (`-o FILE`, or in place with a backup): write the file
    back with every number computed, keeping a listed override
    (`overrides:`); the same `Besm2Save` the generator uses, so the
    two write identical YAML;
  - `--upgrade`: turn the free text of "The YAML today" into the keys
    of A4 where it can (split `Name: subject`, parse a Weapon Attack's
    `details` in the book's notation, give a Defect its level from its
    points, expand aliases), and report what it couldn't parse;
  - the formatting options of besm2_fmt (`-t`, `-m`, `-H`, ...),
    through pobesm2_fmt2's formatters, copied: the character is
    computed first and formatted after. For a file whose numbers agree
    with the rules, the output is byte-for-byte pobesm2_fmt2's (a
    test).

The formatters then change only to **print** the new keys (A4), which
is formatting, the kind of change they are built for.

**Decided: (b).** One implementation of the rules, tested once, shared
by the window and the command line; the formatters keep their
contract ("print what the file says") and their agreement with each
other; and the work on them is limited to printing a few new keys.
`besm2_calc_po` is also the way to bring the existing hand-written
files up to the new keys and check them. The shared modules import no
pofltk, so the command-line program doesn't link FLTK.

Whether the shared modules later move to a library of their own
is left until both programs work.  ova_cg_po's viewer, spawn,
widgets and path modules are copied, not shared (open question 3,
decided 2026-11-06).

### A4. The YAML extensions (decided, 2026-11-06)

Rules for every new key:

- **Optional**, so every existing file loads and formats exactly as
  before; nothing existing changes meaning.
- **A computed number stays where it is today** (`points`, `value`),
  written by the generator and `--fill`, so formatters never compute.
- **Structured keys replace free text only when present**: a file
  with the old free text still formats as before.
- Names are the rulebook's names, so they can be found in
  `Besm2Rules`; the old abbreviations are aliases on loading.

#### What an item is about: `subject`

On an attribute or defect, `subject` holds what was after the `:` in
the packed name, and `name` holds the rulebook's name alone:

```yaml
- name: Own a Big Mecha
  subject: FV2021 Coleopteran
  level: 2
  points: 8
```

Formatters print `name: subject`, which is exactly today's packed
name, so an `--upgrade`d file prints byte-for-byte as before (a
test). Used by Own a Big Mecha, Weapon Attack, Item of Power,
Companion, Unique Attribute, Unique Defect, Conditional Ownership, and
whatever A2 finds takes one. (`description` was the name besm-tools'
`todo.org` proposed, but the entity already has a `description` of
another meaning, so `subject` it is.)

#### Defects: `level`

```yaml
- name: Awkward Size
  level: 2
  points: -2
  details: Huge (1-10 tonnes)
```

`level` is the Defect's rank (1-3, or what A2 finds); `points` stays,
computed from it. Formatters keep printing the Bonus Points from
`points`, so `level` changes nothing they print.

#### Weapon Attacks: `damage`, `abilities`, `disabilities`, `primary`, `different-gunner`

```yaml
- name: Weapon Attack
  subject: Plasma Buster Missiles
  level: 3
  points: 12
  damage: 60
  abilities: [Area Effect, Homing, Long Range]
  disabilities:
    - name: Limited Shots
      counts-as: 2
      detail: 3 shots
    - Slow
    - Stoppable
```

- `abilities` and `disabilities`: each item a name, or a mapping of
  `name`, `counts-as` (the same key ova_fmt uses for repeated Perks
  and Flaws and besm2_fmt for enhancement counts) and `detail`.
  `counts-as` is the slots the item counts as (2026-11-06, open
  question 12): left out, the book's slots for taking it once (Aura 2,
  Auto-Fire 3); for an item taken more than once, its slots in all
  (Limited Shots ×2 is 2); and `{name: Auto-Fire, counts-as: 1}` for
  a weapon priced the way the book's examples price it.  Formatters
  print `×N` only when `counts-as` is 2 or more.
- `damage`: computed (15 a level, less 15 for each Ability, more 15 for
  each Disability, counting repeats; A2 confirms there are no
  exceptions), written like `points`.
- `primary: true`: marks the primary attack, 4 points a level; the
  others are secondary (2 points at the primary's level, 1 below it).
  When no attack says `primary`, the first of the highest level is the
  primary, which is also the cheapest choice, so the key is needed only
  when the user wants otherwise. It is computed and written only when
  an entity has more than one Weapon Attack.
- `different-gunner: true` (2026-11-06, open question 15): a mecha's
  weapon fired by a gunner of its own, 5 Mecha Points more (p. 82,
  PDF 84); left out, false.  `--check` warns about it on a
  character.  Formatters print "Different Gunner" after the
  Disabilities.
- Formatters print these as the book records an attack (p. 92):
  the Abilities, then the Disabilities, a repeat as `×2` (`x2` in
  ASCII mode) and a detail in brackets, then the damage, then
  `details` if any: `Weapon Attack: Plasma Buster Missiles 3 (Area
  Effect, Homing, Long Range, Limited Shots ×2 [3 shots], Slow,
  Stoppable, 60 Damage. 12 CP)`. The existing fixtures write `Damage
  45` first; an `--upgrade`d one will print in the book's order, a
  change in output accepted for the structured form only.
  (2026-11-06, step 3: the name and subject come before the Level, as
  the packed names print today, so a file upgraded to `subject` prints
  byte for byte as before; the book's own "Weapon Attack Level 3:
  Plasma Buster Missiles", p. 92, PDF 94, puts the Level first.  The
  weapon part comes first in the parentheses, before `elements`,
  `choices`, `enhancements`/`limiters` and `details`, all joined with
  "; "; Abilities and Disabilities keep the file's order.)
- `enhancements` and `limiters` (the 4E shapes) **stay as they are**,
  printed as today, for the files that use them; the new programs
  read them but don't compute with them, and `--upgrade` doesn't
  convert them (a 4E enhancement's count is not a 2E Ability). They are
  deprecated for 2E files: `--check` warns about them (open question
  2, decided 2026-11-06).

#### Mecha

No new key: an Own a Big Mecha's `subject` is the `name` of the mecha
entity (with `mecha: true`) in the same file, so the programs find it,
compute its Mecha Points from the owner's level, and check its spending
against them. A `subject` with no such entity is a notice, not an
error (the mecha may be in another file). Attributes of a mecha keep
`points` as today. The formatters already say `MP`/`MBP` and "Mecha
Sub-Attributes" for a mecha in terse and h-m-m (A1 results), so
nothing changes there.

#### Character creation: `creation`

On a character entity:

```yaml
creation:
  character-points: 40      # the campaign's (p. 13)
  background-points: 2      # 0-3 (p. 130)
  genre: Modern Military    # one of Table 2-4's eight genres (p. 119)
  skill-points: 30          # only when the GM's number differs from the rule
  options:                  # the optional rules in use (A2.9)
    staged-stat-cost: true
    stat-ceiling: 10
    bonus-point-ceiling: 8
    auto-fire-slots: 1      # 3 by default (p. 84); 1 as the examples (question 12)
    stat-points-ceiling: 24 # the most CP the Stats may cost in all (p. 16)
    stat-points-floor: 18   # the least CP the Stats may cost in all (p. 16)
  house-skills:             # the campaign's own Skills (house rules)
    - name: Persuasion
      costs: {Modern Military: 3}   # SP a Level, per genre
```

Totals that follow from these (points spent, Bonus Points, Skill
Points left) are not stored: they are computed and shown. Formatters
ignore `creation`; none prints a summary line (open question 2,
decided 2026-11-06).

`house-skills` (2026-11-06, from the user's Persuasion house rule in
Red Planet Blue Helmets): each a `name` and `costs`, a mapping from
Table 2-4's genre names to SP a Level; a genre left out means the
Skill isn't available in it, as "—" in the table.  A house Skill may
also have `stat` (its Relevant Stat) and `specializations` (example
names); specialisations cost as in the book (the first free, each
other 1 SP, p. 118).  A house Skill with a rulebook Skill's name
replaces that Skill's costs.  Shown as "Persuasion (house rule)", with
no page and no PDF button.  It lives in each character's `creation`,
so a file stays complete on its own; the generator can copy the
`house-skills` (and the rest of `creation`) from another character or
a campaign file, to start a new character in the same campaign.

`stat-points-ceiling` and `stat-points-floor` (2026-11-06, step 10a):
p. 16 (PDF 18)'s GM limits on the total Character Points spent on the
Stats, an optional rule; each a whole number 1 or more, and a warning
when the Stats cost more than the ceiling or less than the floor.
(`stat-ceiling` is the ceiling on each Stat.)

**Campaign files** (2026-11-06, step 10a): a file whose top level is a
mapping with only `creation`, as above, rather than a sequence of
entities.  It is what a GM hands the players; the generator and
`besm2_calc --campaign` copy it into each character's `creation`.  The
formatters don't read campaign files.

```yaml
creation:
  character-points: 40
  genre: Modern Military
  options: {stat-points-ceiling: 24}
```

#### Notes: `notes` (2026-11-06)

On any entity, `notes` is a list of short lines that are never priced:
what the rulebook leaves to the player, such as a free unarmed attack
("Punch: Damage ACV+10, Muscle-Powered, Melee", which the fixtures had
as "Natural Attack: Punch" among the Attributes).

```yaml
notes:
  - "Punch: Damage ACV+10, Muscle-Powered, Melee"
```

Each note is trimmed; an empty list prints nothing; a note that isn't a
string is an error (`/1/notes/0: not a scalar`) and its entity is
skipped.  Every formatter prints the notes after Skills, in order:

- terse, grid and raw ms: `**Notes:**`, a blank line, one `- note`
  bullet per note (a line feed inside a note is followed by two
  spaces, so the note stays one bullet), and a blank line.
- h-m-m: a `Notes` heading at depth 2, then the notes at depth 3,
  joined by "; ", or one per line under `-S`.

Done in besm2_fmt (with `test/data/notes-2e.yaml` and `bad-notes.yaml`),
obesm2_fmt, obesm2_fmt2, pobesm2_fmt2 (goldens identical to the Ada's)
and the four Scheme programs (identical to the Ada's `-n` output).

#### Overrides: `overrides`

As in ova_cg_po: any mapping holding a computed number may hold
`overrides:`, the list of its keys whose number the user typed
(`overrides: [points]`, `overrides: [damage]`, a derived value's
`overrides: [value]`). On loading, a listed key's number is the
override; any other number that disagrees with the rules is kept as an
override with a notice, never silently replaced. Formatters ignore
`overrides` except in the terse and grid formats, which mark an
overridden number with `*`, as ova_fmt does (open question 2, decided
2026-11-06).

Step 3 (2026-11-06): a mapping accepts only the keys of its own
computed numbers: `points` on a Stat, Attribute, Defect or Skill,
`damage` on an Attribute, `value` on a Derived Value.  Any other name
(`pionts`, or `value` on a Stat), or an item that isn't a name, is bad
input (`/1/attributes/0/overrides/0: "pionts" is not one of points,
damage`), and the entity is skipped, as a misspelt name would
otherwise drop a mark silently.  The mark is written `\*` (reST),
right after the number: `7\* CP`, `3\* SP`, `20\* Damage`, and in
grid's points and value columns.

#### Sub-choices

`elements` stays for Elemental Control and the like. If A2.4 finds
other Attributes whose choices change their cost, they get `choices:`,
a list of names, printed as `elements` is; otherwise choices stay in
`details`.

Decided at step 3 (2026-11-06): `choices` holds the options of an
Attribute that Besm2Calc prices (A2.4), each item one of Besm2Rules'
option labels for that Attribute (Heavy Armour's "partial, thin
area", "hidden", ...; Flight's "can hover", "glider", ...), as a name
or `{name, counts-as}` for an option taken more than once (printed
`radio ×2`).  The formatters print the choices sorted, after the
elements and before the enhancements and limiters.

#### Rolling it out

1. A fixture, `test/data/keys-ext.yaml` (made-up names), with every
   new key, and the upgraded forms of `composite-2e.yaml` and
   `enyon-boase-2e.yaml`, as `composite-ext.yaml` and
   `enyon-boase-ext.yaml`.  (2026-11-06: `-ext`, not `-2e`, so the
   `all`-mode golden cases, which read every `*-2e` fixture in one
   run, don't change; the other cases read `@(*-2e|*-ext)`.)  The
   upgraded fixtures keep their names as written ("Weapon",
   "Super-Strength", "Hanger Queen"): renaming them is `--upgrade`'s
   job in step 4.  Bad input: `bad-overrides.yaml`, `bad-weapon.yaml`.
   `test/upgraded.sh` checks that `enyon-boase-ext.yaml` prints byte
   for byte as `enyon-boase-2e.yaml` and `composite-ext.yaml` as
   `composite-2e.yaml` but for its weapons' lines.
2. The Ada `besm2_fmt` first: print `subject` and the Weapon Attack
   keys, ignore the rest, golden files for the new fixture, the old
   golden files unchanged; then obesm2_fmt, obesm2_fmt2 and
   pobesm2_fmt2, each byte-for-byte with the Ada; then the four
   `besm2-rst*.scm` (AGENTS.md: all should produce the same output).
3. Each repo committed on its own, with the user's go-ahead.

Done 2026-11-06 (step 3): besm2_fmt (the golden files of the three
`-ext` fixtures and the two bad ones, `test/upgraded.sh`, seven new
`cli.sh` checks), obesm2_fmt, obesm2_fmt2 and pobesm2_fmt2 (the Ada's
golden files copied, passing byte for byte; `make compare` passes), and
the four Scheme programs (`make compare-besm2_fmt`: the Ada's golden
files for every single-file case, matched by all six variants; the
fixtures there are `*-ext-2e.yaml`, for that repository's `%-2e`
rules).  The ports reported a missing key with its path
(`/2/attributes/0/disabilities/0: missing required key "name"`) where
the Ada didn't, which was a fault of alibfyaml: its `Missing_Key` and
`Data_Error` messages had no path or position.  Fixed 2026-11-06 in
alibfyaml, whose messages now start with the line and column of a bad
scalar (or, for a value that isn't a scalar, of its key), when it has
them, and then the path of the mapping (a missing key) or of the value
(bad data), as olibfyaml's do; `Libfyaml.In_File` puts the file name
in front.  The Ada now gives the ports' path, line and column
(`error processing bad-int.yaml:5:42: /1/stats/0/points: not a valid
integer: "lots"`), and `cli.sh` checks them.  ova_fmt, which prints its
own path and location, drops the library's so they aren't printed
twice.  The output is the same.

### A5. The sheet and the window

Look at the character sheets (p. 202 and
`BESM-2E-Character-Sheet-Form-Fillable.pdf`) for what a character
holds and in what order, and sketch the window's tabs from them
before Phase 6. Proposed, to be confirmed with the user:
**Character** (name, tagline, size, the points summary, Stats,
derived values), **Attributes**, **Defects**, **Skills**, **Mecha**
(a mecha entity tied to its owner), **Background** (description, the
Background Points), and a **Preview** tab with pobesm2_fmt2's output
in each of its formats.

**Decided** (the user, 2026-11-06), with the layout drafted for step 6:
the window is 640 by 800, with the menus File, Character and Rulebook,
and the tabs Character, Attributes, Defects, Skills, Mecha, Background
and Preview, each filled in by its step.  The Character tab, top to
bottom: Name, Tagline and Size; the Stats, Body, Mind and Soul, each
"(p. 15, PDF 17)", with its Value spinner, its Points box (computed,
and its override) and a **?**; "Derived values (p. 129, PDF 131)",
ACV, DCV, HP, EP, SV, and AR only with an Armour; the points --
"Character Points: Stats 15 + Attributes 22 - Bonus Points 4 = 33 of
35", "Bonus Points: 4 (ceiling: none)", "Skill Points: 15 of 20" --
and the Warnings.

### Findings

(Filled in by A1-A5, with dates. A1's are in "A1 results".)

- Page offset: PDF = printed + 2 at PDF pages 5, 20, 82-94, 100
  (2026-11-06). No page labels.
- **Where the PDFs come from** (the user, 2026-11-06): `BESM2ER.pdf`
  is the original, and the two `.text` files were made from it.
  `BESM2ER_bookmarked.pdf` was made from it by another program,
  combining it with a list of bookmarks (titles and pages) the user
  typed. That step lost the text layer: `pdftotext` of the bookmarked
  PDF gives dingbats (its Producer is Ghostscript's ps2write, then
  iText). Both have 210 pages. So text and font checks
  (`check-pages`) read `BESM2ER.pdf` or the `.text` files, and the
  viewer opens the bookmarked one; A2.1 confirms the two paginate alike
  page by page.
- **The `.text` files have one form feed per page** (210), so the
  text of PDF page *n* is the *n*th page of the file: a heading found
  there gives its PDF page directly.
- **The bookmarks are a hand-made page index** (`mutool show
  BESM2ER_bookmarked.pdf outline`): chapters, steps, tables and many
  single items (Highly Skilled `#page=44`, printed 42; Weapon Attack
  83; Weapon Attack Abilities 85; Skill System 119), all at printed + 2.
  Since they were typed, they are a second check, not the authority:
  A2.11 compares the tables with the headings found by font in
  `BESM2ER.pdf` and with the bookmarks, and reports a bookmark that
  disagrees, for the user to fix. One is already broken: "Mecha-Only
  Defects" has no destination.
- Weapon Attack: p. 81 (PDF 83); "Alternate Attacks" p. 82 (PDF 84);
  Abilities from p. 83 (PDF 85); Disabilities from p. 89 (PDF 91); the
  worked example p. 92 (PDF 94).
- Secondary Weapon Attacks: 2 points at the primary's level, 1 below
  it; the primary 4 a level ("Alternate Attacks", p. 82). The
  Coleopteran's three weapons fit.
- Weapon Attack damage: 15 a level, -15 per Ability, +15 per
  Disability (the example on p. 92).

## Part B - Building besm2_cg_po and besm2_calc_po

### The modules

The same layering as ova_cg_po, so what isn't the window is tested
with no display, and the command-line program is built from it alone:

| Module | Used by | Contents |
|---|---|---|
| `Besm2Rules` | both | the tables of A2: every Attribute, Defect, Skill, Weapon Ability and Disability with printed page, PDF page, costs, limits, flags, aliases; the Skill cost table by genre; `Label`, `PageText`, `PdfPage` |
| `Besm2Calc` | both | every cost, damage, derived value, total and warning; takes overrides as input |
| `Besm2Character` | both | a character (and its mecha) as records; loading from the YAML nodes (each first through `Besm2Entities.Load`, so a file is refused for what pobesm2_fmt2 refuses, in its words: corrected 2026-11-06), the edits, `Recompute` |
| `Besm2Upgrade` | calc | free text to the keys of A4 |
| `Besm2Entities`, `Besm2Out`, `Besm2Text`, `Besm2Config`, the formatters | both | pobesm2_fmt2's, copied and kept in step (with the new keys once A4 is rolled out) |
| `Besm2Save` | both | YAML through polibfyaml's emitter (`NewDocument`, `CreateStyledScalar`, ...), written to `NAME.tmp` then renamed |
| `Besm2CalcMain` | calc | the command line: `--check`, `--fill`, `--upgrade`, the formatting options |
| `Besm2Cg` | window | the command line (a file, `--rulebook`, `--viewer`), the display check, then the window |
| `Besm2Viewer`, `Besm2Spawn` (+ `.c`) | window | ova_cg_po's `OvaViewer` and `OvaSpawn`, adapted: no page labels, so always the PDF page |
| `Besm2Paths`, `Besm2Settings` | window | as ova_cg_po's |
| `Besm2Widgets` | window | `NumberBox` (computed number and its override box), `HelpButton` (**?**), `Panel` (a list and its editor) |
| `Besm2ItemPanel`, `Besm2Background` | window | the Attributes, Defects and Skills lists; the Background tab (step 7) |
| `Besm2Window`, `Besm2WeaponDialog`, `Besm2MechaPanel`, `Besm2Preview`, ... | window | the window, from A5 |

Names that clash with pobesm2_fmt2's own (`Besm2Cli`, `Besm2Fmt`) are
renamed in the copy, and the copy says so.

### Points the programs keep

- **Character Points**: the total (`creation.character-points` +
  `background-points`), spent on Stats and Attributes, plus the Bonus
  Points the Defects give; shown as spent / available, red when over.
- **Bonus Points**: from Defects, with the GM's ceiling if set.
- **Skill Points**: 20 + Highly Skilled's, less Unskilled's (or
  `creation.skill-points`), spent at the genre's costs.
- **Mecha Points**: from Own a Big Mecha, spent by the mecha entity.

Every number in the window has an override box, as in ova_cg_po
("Overriding a computed number"), and a file whose numbers disagree
with the rules keeps them as overrides with a notice.

### Pages beside names

Wherever a name of a Stat, Attribute, Defect, Skill, Weapon Ability or
Disability appears (lists, menus, dialogs, warnings, `besm2_calc_po`'s
messages) **both pages are beside it**, from one procedure,
`Besm2Rules.Label`, so the format can't differ from place to place:

- in a menu or message: `Highly Skilled (p. 42, PDF 44)`;
- in a list, a narrow page column: `p. 42, PDF 44`
  (`Besm2Rules.PageText`);
- a name not in the tables: `Name (p. ?)` and a warning.

`TestRules` checks every item has both, and that they differ by the
offset (or by what A2.1 records where it doesn't). The **?** button
opens the viewer at the PDF page, and its tooltip gives both. The
saved YAML holds names as the formatters expect them, without pages.

### Build order

0. **Skeleton.** `GNUmakefile` (from ova_cg_po's, building both
   programs), `README.md`, `test/Check.Mod`, `test/poc-gc.supp`,
   `tools/with-sway.sh`; a window with File > Quit that opens and
   quits under Xvfb and sway; `besm2_calc_po -h`; `test/cli.sh` for
   both (`-h`, bad options, no display for the window).
   *Done 2026-11-06.* Until step 4 a file argument is a usage error
   (status 2) in both programs, and `besm2_calc_po` with no file does
   nothing and exits 0.  `test/TestWindow` picks File > Quit and
   presses the close button, so Quit is checked on sway too, where
   `test/quit.sh` (xdotool) is skipped.  `make test`, `test-headless`,
   `test-sway` and `valgrind-headless` pass (0 errors);
   `besm2_calc_po` doesn't link FLTK.
1. **`Besm2Rules`.** The tables from A2; `TestRules`: every name
   present once, both pages for each, each in its section's range,
   costs as the reference section gives them, the label format; `make
   check-pages` against the PDF's headings by font. Shown to fail with
   planted bugs.
   *Done 2026-11-06.* `src/Besm2Rules.Mod`, after `OvaRules`:
   - **The tables:**
     - 3 Stats (p. 15);
     - 76 Attributes (pp. 20-81) and 13 Mecha Attributes (pp. 93-99);
     - 38 Defects (pp. 101-113) and 10 Mecha-Only Defects (pp. 114-116);
     - 52 Skills (pp. 120-128) with Table 2-4's costs (p. 117);
     - 34 Weapon Attack Abilities (pp. 83-89) and 21 Disabilities
       (pp. 89-92), with their slots, the second number some have, how
       often each may be taken, and the 19 pairs that exclude each other;
     - 18 aliases: the headings' full names, Table 2-2's "Magic (or
       Psionics)", and question 11's old names;
     - the pages of the rules themselves (Step 3, ... Table 4-7);
     - the Staged Stat Cost (Table 4-7, p. 166).

     Unique Defect Sample — Weak Point (p. 112) is an example of Unique
     Character Defect, not an item.
   - **Stealth** is both an Attribute (p. 73) and a Skill (p. 125).
     `Find` gives the Attribute, and `FindKind` gives either.
   - **Attribute options:** an Attribute's cost options are labelled
     with short names of the choices, never the book's words.
     - A required choice sets the cost a Level (Flight, Force Field, ...).
     - Other options add or take points a Level or on the total.
     - Some are exclusive (an optional group).
     - Some can be taken more than once (an extra aperture, form, sense).
     - Heavy Armour, Light Armour and Own a Big Mecha cost at least 1
       (pp. 40, 48, 59).
   - **Decided from the text (2026-11-06):**
     - Shape Change's "1 point less" for a single type of change is −1
       a Level (p. 66; its heading reads "2-3 points/level").
     - Magic's Focus, Ritual, Silent and Still change Energy Points, not
       Character Points, so they are not cost options (p. 50).  Its Less
       Powerful is −1, −2 or −3 on the total.
     - Sensors' Underwater, Analytic and Indirect are each bought at 1 a
       Level, as the subject; an analytic function on Sensors already
       owned is +1 on the total (p. 65).
     - Heavy and Light Armour's Hidden and Optimized change how they
       work, not their cost (pp. 40, 48).
     - Contagious is 3 slots mild, taken a second time (6) highly (p. 85).
   - **Deferred:** the Attributes' Types (Table 2-2) and Relevant Stats
     wait until the window needs them.
   - **Tests:**
     - `test/TestRules` checks the counts, each name found once, pages in
       their chapters at PDF + 2, the book's order, the options' shape,
       labels, aliases, spot numbers and the small tables.
     - `test/ListRules` prints the tables.  `tools/check-rules.py` (in
       `make test`) compares every item with `rules/*.tsv`: page, cost,
       highest Level, flags, Skill costs, slots, times and exclusions.
     - `make check-pages` now also checks every item of Besm2Rules, and
       each of its rules' pages, against the PDF's headings.
     - 13 planted bugs were each caught by at least one of the three: a
       page, a Defect left out, a name twice, a cost, a Skill cost, slots,
       an exclusion, the label format, the PDF offset, the Staged table, a
       rule's page, and `Find` ignoring case.
2. **`Besm2Calc`.** Every rule from A2, with `TestCalc` over every
   fixture character and mecha (each number the file holds compared)
   and hand-made cases for each rule, each Weapon Ability and
   Disability, primary and secondary attacks, each limit, and
   overrides feeding what depends on them.
   *Done 2026-11-06.* `src/Besm2Calc.Mod` and `test/TestCalc.Mod`
   (269 checks):
   - **What it holds.** An `Entity` (a character or a mecha) of
     Stats, Attributes (Weapon Attacks with their Abilities and
     Disabilities), Defects and Skills, its `Creation`, and every
     number as a `Number`: the computed value, and an override if the
     user typed one (A4, `overrides`).  `Compute` fills in every
     number and the warnings, each naming what it is about; a
     character's Own a Big Mecha gives its linked mecha its Mecha
     Points, and the mecha is computed with its owner's `Creation`
     (genre, `auto-fire-slots`).  What uses a number uses its
     override: an ACV override feeds DCV, an HP override SV, an item's
     points the totals.
   - **The oracles** (built by hand from their files; step 4's
     `TestFiles` loads the files): Enyon Boase and Cador Trewartha,
     each with the FV2021 Coleopteran, and the WT-34 Bogatyr with an
     owner of Own a Big Mecha 3, and the KA-99 Archangel's two
     weapons.  Every number agrees with the files as corrected to the
     book's slots: Auto-Fire 3 and Melee 2 (open questions 12, 13 and
     14).
   - **The hand-made cases:** each rule of A2 and each warning; every
     Weapon Ability and Disability alone at Level 6 (its damage, as
     Personal Gear, Mecha Only on a character and not on a mecha);
     every pair of them, warned exactly when Besm2Rules excludes them
     (19 pairs); primary and secondary attacks; overrides.
   - **15 planted bugs** were each caught (1 to 17 failures each): ACV
     div 2, no Inept clamp, DCV ignoring an ACV override, SV rounding
     down, Diminutive 2 as 1, a lower secondary at 2, a Different
     Gunner at 4, less powerful at 4, 9 Defects allowed, every
     specialisation charged, `auto-fire-slots` ignored, no least cost,
     negative damage, Personal Gear at full damage, Toughness at 10.
   - **Decisions** (2026-11-06, Claude's, within the rules):
     - SV is HP / 5 rounded up (p. 130, PDF 132), so HP 14 gives 3.
     - Place of Power (p. 63, PDF 65) is its own pool of Energy Points.
     - Diminutive (p. 103, PDF 105) divides HP by 5 at rank 1 and 20 at
       rank 2, rounded down.
     - Inept Combat (p. 105, PDF 107) lowers ACV 1 a rank, never below
       1 (and never raises an ACV already below 1).
     - Optimized armour counts like any other armour in AR (Heavy
       Armour, p. 40, PDF 42; Light Armour, p. 48, PDF 50).
     - A weapon's damage is never below 0: with more Ability slots than
       Levels it is 0, warned as under 15.
     - The primary attack is the one marked `primary`, else the first
       of the highest Level that isn't Personal Gear.  A Different
       Gunner on a character's weapon is warned (it is for mecha).
3. **The YAML extensions** (A4, "Rolling it out") in the formatters,
   before either program writes them.  Done 2026-11-06.
4. **Files and `besm2_calc_po`.** First `ToRope`/`TakeRope` in
   pobesm2_fmt2's `Besm2Out` (open question 10, decided), with a
   `TestOut`, committed in pobesm2_fmt2; then `Besm2Entities`,
   `Besm2Out` and the other modules of A1.5 copied;
   `Besm2Character.Load`/`LoadAll`; `Besm2Save`; `Besm2Upgrade`;
   `--check`, `--fill`, `--upgrade`, and formatting. `TestFiles`: each
   fixture loads, saves and formats through pobesm2_fmt2 the same as
   the original; upgraded fixtures print as before (but for the
   Weapon Attacks' order); numbers that disagree become overrides with
   notices; formatting a file whose numbers agree is byte-for-byte
   pobesm2_fmt2's.

   *Done 2026-11-06.* `Besm2Out.ToRope`/`TakeRope` and `TestOut` in
   pobesm2_fmt2, and `Besm2Cli.NewParser` there too (the options of
   besm2_fmt as a parser a program can add to), then copied with the
   rest of A1.5; `Besm2Character`, `Besm2Check`, `Besm2Save`,
   `Besm2Upgrade`, `Besm2CalcMain`; `test/files.sh` (TestFiles, as a
   script, since it runs two programs), in `make test`, against
   pobesm2_fmt2's binary and fixtures (`POBESM2_FMT2`, by default
   `~/Repos/RPG/Tools/pobesm2_fmt2`).  Decisions:
   - **Reading.**  A file is parsed with `Fyaml.NoResolve`, so its
     aliases can be reported, then resolved.  Each entity goes through
     `Besm2Entities.Load` first, so what pobesm2_fmt2 refuses is
     refused in its words and in its place, then is read into records.
     Anchors that no alias names change nothing, and polibfyaml can't
     see them, so only aliases are reported.
   - **A number in the file** that is text where a number belongs
     ("level: special") is kept as text (the `levelIsText` flags) and
     printed back as written, with a warning; it is never priced.
   - **Keep, not Adopt**, for a number the rules can't compute: a name
     not in the rulebook, and every Skill of an entity without
     `creation.genre` (one notice for them all: "no genre in creation
     to price Skills by (Table 2-4, p. 119, PDF 121)").  The file's
     number is kept as an override, so it prints with `\*`: such a
     file is not one "whose numbers agree", and `test/files.sh`
     doesn't expect it byte for byte (enyon-boase-2e and -ext).
   - **A Defect's rank** when it has no `level`: its Bonus Points over
     its cost a rank, at least 1 (Table 2-3, p. 100, PDF 102).
   - **Notices** are of three kinds: *difference* (a number that
     disagrees, kept as an override), *warning*, *error* (a `points`
     or `value` outside −999..999, from `Besm2Check`).  A message is
     "ENTITY: ITEM (p. N, PDF M): TEXT", the item with both pages
     from `Besm2Rules`; `besm2_calc_po` puts "FILE: KIND: " in front.
     `Besm2Check` looks at the file's nodes (aliases, ranges,
     `enhancements`/`limiters`, `different-gunner` on a character,
     empty strings and lists), since those exist only as written.
   - **Options.**  `--check`, `--fill` and `--upgrade` are long only:
     besm2_fmt's options take most letters.  `--check` may go with
     either of the others.  `--fill` and `--upgrade` take one file or
     standard input, since one output holds one file, and write
     nothing for a file with a problem (an entity that doesn't load
     would be lost), saying so, exit 1.
   - **Formatting** reads and computes each file, saves it in memory
     through `Besm2Save`, and formats what was saved with the copied
     formatters, so a file prints exactly as its `--fill` output
     prints through pobesm2_fmt2.  Notices are silent; problems are
     reported as pobesm2_fmt2 reports them, under this program's name.
   - **The upgrade** is a hook (`Besm2Character.SetUpgrade`, set by
     `Besm2Upgrade.Install`) run on each entity after it is read and
     before it is computed, so the numbers compared are the upgraded
     entity's.  It splits packed names, writes BESM2ER's names for
     aliases (Features or Accessories by entity; case alone is left),
     gives Defects their `level`, and turns a Weapon Attack's
     `details` into `damage`, `abilities` and `disabilities` when
     every comma-separated part is a damage ("Damage ACV+45") or a
     Weapon Ability or Disability ("Long-Range: 5 km", "Limited Shots
     ×2 [3 shots]"); otherwise the details stay, with a warning naming
     the first part it couldn't read (and both pages of the Abilities
     and Disabilities).  A damage that was in the details is the
     file's, compared as any other (`damageInFile`); one that wasn't
     is computed.  "But for the Weapon Attacks' order" turned out to
     be the order *within* a weapon's line: the formatters print
     Abilities, then Disabilities, then the damage, where the free
     text had the damage first.
   - **Checked by `test/files.sh`:** of pobesm2_fmt2's 33 fixtures,
     the 17 that load fill; every one formats as its `--fill` prints
     in seven formatter option sets; that `--fill` prints as the
     original but for the overrides' marks; the files whose numbers
     agree (including the bad ones, errors and status) format byte for
     byte as pobesm2_fmt2's; `--upgrade composite-2e.yaml`, given
     composite-ext's `creation`, is composite-ext.yaml with BESM2ER's
     names, and prints as composite-2e but for the weapons and the
     renamed lines; `--fill` and `--upgrade` are idempotent.
5. **The rulebook viewer.** `Besm2Viewer`/`Besm2Spawn` from
   ova_cg_po (okular over D-Bus, evince, mupdf, xdg-open, a template
   with `%f` the file and `%p` the PDF page; reusing a running viewer);
   `TestViewer` with fake viewers, `make test-viewers` with the real
   ones on a headless sway.

   *Done 2026-11-06.* `src/Besm2Viewer.Mod`, `src/Besm2Spawn.Mod` and
   `src/Besm2Spawn.c` are ova_cg_po's `OvaViewer`, `OvaSpawn` and
   `OvaSpawn.c`, copied (open question 3) with the names changed
   (`Ova` to `Besm2`, the C functions `ova_spawn_` to
   `besm2_spawn_`).  Besm2Spawn is otherwise unchanged.  Besm2Viewer's
   changes:
   - **No `%l`.**  The PDF has no page labels ("The rulebook and its
     pages"), so a template has `%f` (the PDF) and `%p` (the PDF page,
     `Besm2Rules.PdfIndex`, the printed page + 2) only; a `%l` stays
     as written, as any other `%` does.  okular gets `-p`, evince `-i`
     and mupdf the page argument, all the PDF page, as in ova_cg_po;
     evince's `--page-label` is never used.
   - **The PDF:** `--rulebook`, then `BESM2_RULEBOOK`, then the saved
     path, then `~/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf`,
     made absolute (AGENTS.md, "The PDFs").
   - **xdg-open's message** gives both pages through
     `Besm2Rules.PagesText`: "xdg-open can't turn to a page: turn to
     p. 60, PDF 62".
   - `Open` still takes the printed page, so callers pass an item's
     page as Besm2Rules holds it.
   Tests: `test/TestSpawn.Mod`, `test/TestViewer.Mod` (both in
   `TESTS`, with the fakes `test/fake-viewer.sh` and
   `test/fake-gdbus.sh`), and `test/OpenPage.Mod` with
   `test/viewer.sh` for `make test-viewers`, all ova_cg_po's, adapted
   as above.  Planted bugs caught: sending the printed page instead of
   the PDF page (5 TestViewer failures), and a child that doesn't
   `setsid` (TestSpawn: "the viewer is in a session of its own").
   `make test` passes, `make test-viewers` passes all 29 checks with
   the real okular, evince and mupdf, and TestSpawn and TestViewer are
   clean under valgrind.
6. **The window: Character tab.** Name, tagline, size, Stats, derived
   values with their override boxes, the points summary; File New,
   Open, Save, Save As with the save-first question; Rulebook > Open,
   Choose PDF..., Viewer....
   Decided with the user (2026-11-06), besides the layout (A5):
   - A file with several entities, until step 9 can switch between
     them, shows its first character (not a mecha); every entity is
     kept, and saved back in its order, unchanged unless shown.
   - A new character has no `creation`, so no Character Points until
     step 10's Character > Creation...: the points show only what is
     spent, "33 (no limit set)", never red.  A file's `creation` is
     used as written.  (Step 10 gave it Creation...; Add Character
     copies the creation of the character shown.)
   - The Background tab (description and notes) moves to step 7.

   *Done 2026-11-06.*  New modules, none with a window but
   Besm2Widgets:
   - `src/Besm2Widgets.Mod`: the number box (the computed number, and
     an entry for its override; empty clears it, text that isn't a
     whole number is refused and said so) and the **?** button, which
     calls `openPage` with the printed page.  From ova_cg_po's
     OvaWidgets, cut to what step 6 uses.
   - `src/Besm2Warnings.Mod`: each `Besm2Calc` warning as a line, what
     it is about with both pages, and the limit with the rule's pages,
     e.g. "spent 21 Character Points of 20 (p. 13, PDF 15)".
   - `src/Besm2Paths.Mod`: a path made absolute, for the rulebook
     chosen (ova_cg_po's OvaPaths).
   - `src/Besm2Character.Mod` gained `New` (a character with no file:
     Stats at 1, no `creation`), `One`, and `UseStat`/`UseDerived`: a
     file's entity that didn't list a Stat or derived value gets it
     listed once the user changes it, so it is saved; one from no file
     writes them all anyway (Besm2Save).
   - `src/Besm2Window.Mod`, rewritten, and `src/Besm2Cg.Mod`:
     `besm2_cg_po [options] [file.yaml]` loads the file before it needs
     a display (so a bad file fails as besm2_calc_po's does, status 1);
     a second file is status 2; `--rulebook` and `--viewer` as
     besm2_calc_po's are, the ones chosen in the window kept in the
     preferences.
   Decided while building it (2026-11-06):
   - **No Character menu yet.**  FLTK shows a menu only with items in
     it, and its first, Creation..., is step 10's; it comes then.
     (Step 9 added the menu, step 10 Creation... at its head.)
   - **A mecha shown** (a file of only mecha) has its Stats spinners
     and boxes off, and of the derived values only HP (p. 59: a mecha
     has no Stats); its points are "Mecha Points: Attributes ... -
     Bonus Points ... = ...".  AR shows with Heavy or Light Armour, or
     an override of AR.
   - **A file's differences** (`Besm2Character.notices`) are told once,
     on opening: "Numbers the file gives differently from the rules,
     kept as overrides, and what else it has:", then each notice,
     wrapped at 80 characters (`Besm2Layout.WordWrap`) so the message
     fits on the screen; a wrap can fall inside "(p. 15, PDF 17)".
   - **The save-first question** names the file, or "the characters"
     if a file-less set has several, or the character's name, or "the
     character": "Save the changes to Kei first?"  Save with Save As
     cancelled leaves everything as it was.
   Tests:
   - `test/TestWarnings.Mod` (in `TESTS`): every warning's line,
     including the pages (its first draft had two wrong: Weapon Attack
     is p. 81, and Stealth the Skill p. 125, not the Attribute).  `test/TestPaths.Mod` (in `TESTS`).
   - `test/TestWindow.Mod` (in `GUITESTS`), on its own fixtures in
     `test/data/` (made up, every number as the rules compute it but
     `differs.yaml`'s): the menus and shortcuts; a new character; a
     Stat's spinner, the text inputs, overrides typed, emptied and
     refused; the points lines and their red; the warnings; New, Open,
     Save and Save As, and the save-first question answered each way,
     through File > New, File > Open, File > Quit and the close
     button; a file with a mecha first, saved back whole and in order;
     a file without Stats saving the one changed; the notices wrapped;
     a mecha alone; Rulebook > Open, Choose PDF... and Viewer..., with
     a rulebook missing, a viewer that won't start, and one that does.
     What it saves goes in `obj/`, and the fixtures it changes are
     copied there first, so a Save gone wrong can't change them (one
     planted bug did, before that).
   - `test/cli.sh`: a missing file and a file that doesn't load exit 1
     with no display needed; a file that loads goes on to need one; two
     files, and a `--viewer` without `%f`, exit 2; `-h` names
     `--rulebook` and `--viewer`.
   Planted bugs caught by TestWindow: the points never red; the first
   entity shown even if a mecha (5 failures); AR always shown; a
   changed Stat not listed (`UseStat` skipped); Don't save refusing to
   leave (4); Save As not keeping the path (4).  `make test`, `make
   test-headless` and `make test-sway` pass (quit.sh is skipped on
   sway, needing X11), and `make valgrind-headless` is clean.
7. **Attributes, Defects and Skills tabs.** Pick by name (with both
   pages) and level, subject, detail, Add / Change / Remove, **?**; the
   totals and warnings update as you go; Skills' specialisations and
   the genre.  And the Background tab: the description and the notes
   (decided 2026-11-06).

   *Done 2026-11-06.*  New modules:
   - `src/Besm2ItemPanel.Mod`: `AttrPanel`, `DefectPanel` and
     `SkillPanel`, each a `Besm2Widgets.Panel` (the list, the Choice of
     names with both pages, its **?**, the Level spinner, a text field,
     Add / Change / Remove) over one entity.  Each list line is the
     Level (or rank), the name, `: subject`, ` (details)`, then the
     points ("4 pts", "1 BP", "8 SP") and both pages, in columns.
   - `src/Besm2Background.Mod`: the Background tab, after ova_cg_po's
     OvaBackground: the description in a text editor and the notes in
     a list with an input and Add / Change / Remove.  Each change goes
     into the entity as it is made.
   - `src/Besm2Character.Mod` gained the edits the panels make:
     `NewAttr`, `InsertAttr`, `ChangeAttr`, `RemoveAttr`, the same for
     Defects and Skills, `SetGenre` and `Relink`.
   Decided while building it (2026-11-06):
   - **Add puts an item last**, selected; Change keeps its place;
     Remove leaves nothing selected.  Change with the same name keeps
     the record (and its options, and keys the window doesn't show);
     with another name a new record takes its place.  Change with no
     name chosen keeps the old name, so a name the rules don't have
     can still be re-levelled.
   - **Options** (an Attribute's choices, A2) are listed under the
     Attribute: `(x)`/`( )` for one of a required choice (the first
     counts until another is taken), `[x]`/`[ ]` for one that is taken
     or not, `N x` for one taken several times, then the amount.
     **+** and **-** take the selected one once more or once less.
   - **The genre** is chosen on the Skills tab (Table 2-4's **?**, p.
     119, PDF 121), since it sets every Skill's cost; choosing it adds
     `creation: genre`.  Step 10's Creation... shows it too.
   - **Specialisations** are typed separated by commas, trimmed, blanks
     dropped; the first is free and each other 1 SP (p. 118).
   - **House Skills** (`creation: skills`) are offered after the
     rulebook's, marked "(house rule)", their **?** blank.
   - **The totals and warnings** of the Character tab are repeated
     under each list, so they update in view as you go.
   - **Own a Big Mecha's mecha** is linked again (`Relink`, which
     doesn't add notices) after every change, so a subject typed or
     changed links or unlinks it.
   - On a mecha the Attributes list still offers Attributes first,
     then the Mecha-only ones; step 9 may turn that round.
   - Known: a Skill loaded from a file with no genre keeps its points
     as an override (they can't be checked), even after a genre is
     chosen; clearing the override is step 10's Creation... question.
     (Closed in step 10: such a Skill is marked unpriced, and once a
     genre or house Skill prices it, an override the price agrees with
     is cleared; one that disagrees is kept.)
   - **A poc bug**, found here: a string literal inside an array index
     (`a[F("x")]`) is never emitted, and the link fails ("use of
     undefined value '@.str...'").  The tests compute such an index
     first.  Reported as Peaseblossom's PLAN.md item 18 (22396a9);
     the workaround stays until it is fixed.
   Tests:
   - `test/TestModel.Mod` (in `TESTS`, no display): the edits on an
     entity built by hand: options kept or dropped by ChangeAttr,
     ranks and Bonus Points, specialisations trimmed, the genre's
     costs, a house Skill, Relink, and saving and loading all of it
     again.
   - `test/TestWindow.Mod`: the Attributes, Defects, Skills and
     Background tabs driven as a user would on a copy of
     `data/window.yaml`: names with both pages, **?**'s page, "Choose
     a name first.", the options and **+** / **-**, Add / Change /
     Remove, the points and warnings on every tab, a mecha unlinked
     and linked again, the genre, specialisations, a house Skill, the
     description and notes, then File > Save and loaded again.
   Planted bugs caught: ChangeAttr always replacing (3 failures);
   specialisations untrimmed (6); SetGenre not marking `creation`;
   the first of a choice not counted; **+** leaving the others of a
   choice taken (5, once a check going back within a choice was
   added); options not taken on Add (5); a genre change not priced;
   the tabs' points not set (2); a note's Change appending; the
   description untrimmed (2); Remove keeping its selection; no Relink
   at all (the window relinks twice, so removing one is not seen).
   `make test`, `make test-headless`, `make test-sway` and `make
   valgrind-headless` pass.
8. **Weapon Attacks.** The dialog: subject, level, Abilities and
   Disabilities with counts and details, primary; damage and cost
   following each change.

   *Done 2026-11-06.*  New module `src/Besm2WeaponDialog.Mod`: the
   **Weapon...** button under the Attributes list opens it on the
   selected Weapon Attack ("Choose a Weapon Attack first." otherwise).
   It has the subject, the Level, the details, **Primary** and
   **Different Gunner**, and two panels, Abilities (p. 83, PDF 85)
   and Disabilities (p. 89, PDF 91), each a list with the Choice of
   names and both pages, **?**, a slots spinner, a details field and
   Add / Change / Remove.  Each line is the name, `xN` when taken
   more than once, `(details)`, the slots and both pages.  Under them
   the damage and the points, and the warnings for this attack,
   follow every change.
   `src/Besm2Character.Mod` gained `NewMod`, `InsertMod`, `ChangeMod`,
   `RemoveMod`, `CopyMods` and `SetPrimary`.
   Decided while building it (2026-11-06):
   - **The slots spinner sets `counts-as`.**  Choosing a name sets it
     to that item's slots once; a different number is written as
     `counts-as` (Melee taken as 1, Auto-Fire as 1).
   - **The Level, primary, gunner and the lists change the attack at
     once**, so the window's totals follow; the subject and details
     are taken on **OK**.  **Cancel** puts back the record, both lists
     and every attack's `primary` as they were when it opened.
   - **Primary** is greyed when the entity has one Weapon Attack.
     Unmarking an attack that is still the first of the highest Level
     says it is still the primary (p. 82, PDF 84).
   - **Personal Gear** is left out: the YAML has no key for it.
   Found while building it: Besm2Save dropped `counts-as` when it was
   1, so Melee taken as 1 was saved as `- Melee` and loaded again as 2
   slots (60 damage instead of 45).  `counts-as` is now written
   whenever it was given, 1 included (`ItemNode`).
   Tests: `test/TestModel.Mod`'s Weapons (damage and points, the Mod
   edits, counts-as, the primary, GunnerNotMecha, saved and loaded
   again) and `test/TestWindow.Mod`'s Weapons (the dialog driven as a
   user would, Cancel and OK, two attacks and the primary, Save As and
   loaded again, and Close cancelling an open dialog).
   Planted bugs caught: save dropping counts-as 1; NewMod always
   writing counts-as; Cancel keeping the lists (once a check changing
   an item in place before Cancel was added); choosing a name leaving
   the slots; Close leaving the dialog open; no recompute after a
   change.  `make test`, `make test-headless`, `make test-sway` and
   `make valgrind-headless` pass.
9. **Mecha and several entities.** A mecha entity tied to its
   owner's Own a Big Mecha, its Mecha Points checked; several entities
   in a file (Add, Duplicate, Remove, Move, Next/Previous), as
   ova_cg_po's Phase 13.
   *Done 2026-11-06.*  New module `src/Besm2MechaPanel.Mod`: the
   **Mecha** tab.  On a character it lists each Own a Big Mecha
   (p. 59, PDF 61) with its Mecha Points (20 a Level) and what its
   mecha spends of them ("Walker spends 18 of 20", ": over" past
   them, "not counted", "no mecha of that name in the file", "no
   subject: no mecha"); on a mecha, each character's Own a Big Mecha
   naming it.  **?** buttons open Own a Big Mecha and Mecha
   Attributes.  **Show Mecha** / **Show Owner** goes to the other
   entity; **New Mecha** adds a mecha named by the subject (asking for
   the name, and setting the subject, when there is none).
   The window gained a **Character** menu (Add Character, Add Mecha,
   Duplicate, Remove..., Move Up, Move Down, Next on Ctrl+PgDn,
   Previous on Ctrl+PgUp) and a Choice of the file's entities at the
   menu bar's right ("2. Walker (mecha)", `&` doubled); the title ends
   "(i of n)" when the file has more than one.
   `src/Besm2Character.Mod` gained `ReadText` and `NewMecha`,
   `src/Besm2Save.Mod` `Copy` (the entity written and read again),
   `src/Besm2Widgets.Mod` `Panel.Offer`.
   Decided while building it (2026-11-06):
   - **Two characters naming one mecha**: the last in the file prices
     it (as `Besm2Calc.Compute` already did); the other's line says
     "not counted: X owns it".
   - **Renaming a mecha** carries the new name to the subject of every
     Own a Big Mecha tied to it, so the tie survives.
   - **Duplicate keeps the name**, so a duplicated mecha is unowned
     (Link ties the first mecha of a name) until it is renamed; Move
     can change which one is tied, and the tab shows which.
   - **Remove asks first** and is greyed for the only entity; the one
     after is shown, or the one before when the last was removed.
   - **On a mecha**, the Attributes and Defects tabs offer the Mecha
     Attributes and Mecha Defects first.
   Found while building it: a mecha whose owner was removed or renamed
   kept its old Mecha Points, since `Besm2Calc.Totals` set them only
   when it had an owner.  An unowned mecha now has 0 (shown "(no owner
   in the file)").
   Tests: `test/TestModel.Mod`'s Several (NewMecha, ToText and
   ReadText, Copy of a mecha and a character) and
   `test/TestWindow.Mod`'s Several (the menu and Choice, the Mecha tab
   on both sides, rename, New Mecha, Duplicate, Move, Remove cancelled
   and done, Next/Previous, Save and loaded again, File > New).
   Planted bugs caught: no rename of the subjects; Next not greyed on
   the last; `&` not doubled; Remove showing the first; no "not
   counted"; New Mecha not setting the subject.  `make test`, `make
   test-headless`, `make test-sway` and `make valgrind-headless` pass.
10. **Options and limits.** Character > Creation...: the campaign's
    Character Points, Background Points, genre, Skill Points, Staged
    Stat Cost, the GM's ceilings.
    *Done 2026-11-06.*  New module `src/Besm2Creation.Mod`: the
    **Creation** dialog (OvaSettings' pattern: modal, changes go into
    the model live, Cancel or the close button restores what was there
    at open).  Each control has a **?** to its page: Character Points
    (p. 13, PDF 15; default 40 when turned on), Background Points (p.
    130, PDF 132), genre (Table 2-4, p. 119, PDF 121), Skill Points (p.
    117, PDF 119; while off, the rule's number is shown), Staged Stat
    Cost (p. 166, PDF 168), a Stat ceiling (p. 16, PDF 18; default
    10), a Bonus Point ceiling (p. 100, PDF 102, "no more than eight
    Defects"; default 8) and one Auto-Fire slot (p. 84, PDF 86).  A
    summary line shows what the creation gives.
    **Copy from** takes the creation (and its house Skills, copied
    deep) of another entity in the file, or of the first character in
    another file (**From File...**; a file of only mecha is refused
    with a message).  **Add Character** copies the creation of the
    character shown (or of a mecha's owner).  On a mecha, Creation...
    edits its owner's creation ("..., which prices the mecha"), and is
    greyed for an unowned mecha.
    `src/Besm2Character.Mod` gained `SetCreation`, `TakeCreation`,
    `SaveSkills`/`RestoreCreation` (for Cancel) and `Reprice`.
    Decided while building it (2026-11-06):
    - **Keys kept.**  An option turned off that was in the file when
      the dialog opened (or was copied in) keeps its key, written
      false, so a file's explicit `staged-stat-cost: false` survives;
      one turned on and off again in the dialog leaves no key.
      Character Points, Skill Points and the ceilings are removed when
      off.
    - **Unpriced Skills** (no genre, or neither in the rulebook nor a
      house Skill) are repriced whenever the genre or house Skills
      change; an override the new price agrees with is cleared.
    Found while building it: p. 16 (PDF 18)'s GM ceiling or floor is
    on the total Character Points spent on Stats, while A4's
    `options: stat-ceiling` is a ceiling on each Stat (whose range p.
    16 gives as 1 to 12).  Left as A4 has it, for the user to decide
    whether to add a total ceiling and floor.
    Tests: `test/TestModel.Mod`'s Creation (`test/data/unpriced.yaml`,
    `test/data/creation.yaml`: Reprice, SetCreation, TakeCreation,
    SaveSkills and RestoreCreation, saved and loaded again) and
    `test/TestWindow.Mod`'s Creation (every control, Ok, Cancel, Copy
    from, From File..., a mecha's owner, Add Character, Close with the
    dialog open).  Planted bugs caught: Reprice's agreement test;
    RestoreCreation's house Skills; the deep copy of house Skills;
    Key ignoring the opening keys; Cancel's restore; the opening keys
    not reset after a copy; Add Character not copying; Close not
    cancelling the dialog.  `make test`, `make test-headless`, `make
    test-sway` and `make valgrind-headless` pass.
10a. **Campaign files.** (Added 2026-11-06 at the user's request.)  A
    GM's campaign as a file of its own, to hand to the players: a YAML
    file holding only a `creation:` mapping (A4).  The Creation dialog
    gets **Load Campaign...** (in place of From File...; it reads a
    campaign file, or a character file, whose first character's
    creation it takes) and **Save Campaign...**; File gets **New from
    Campaign...**; the last campaign file is kept in the preferences;
    `besm2_cg --campaign FILE` starts the new character from it, and
    `besm2_calc --campaign FILE` gives each character of the files the
    campaign's creation before checking, filling or upgrading them,
    with a notice for each whose own creation differed.  The creation
    is copied, never linked: each character's file stays complete on
    its own.  With it, p. 16 (PDF 18)'s GM limits on the total
    Character Points spent on Stats, as an optional rule (the user,
    2026-11-06): `options: stat-points-ceiling` and
    `stat-points-floor`, each a warning when the Stats cost more or
    less.

    *Done 2026-11-06.*  `Besm2Character.LoadCampaign` reads a
    campaign file (a root mapping whose only key is `creation`; any
    other key is refused, saying where) or a character file (its first
    character's creation; a file of only mecha is refused), and
    `Besm2Save.SaveCampaign` writes one, `creation` always present.
    `Besm2Calc` adds `stat-points-ceiling` and `stat-points-floor`
    (each 1 or more) to the creation, and warns `StatPointsAbove` and
    `StatPointsBelow` on the Stats' cost (Staged if Staged Stat Cost is
    on), with both pages; the Character tab's Character Points line
    adds "; Stats at least F, at most C" and turns red on either.  The
    Creation dialog has a check and spinner for each (defaults 24 and
    12), and Load Campaign... and Save Campaign... on their own row;
    File > New from Campaign... (after New) loads one and starts a
    character in it, and File > New then starts each in it too
    (`Besm2Window.campaign`).  `besm2_calc --campaign` reports
    "LABEL: creation differs from the campaign's, FILE, which is
    used" as a difference, so `--check` exits 1.  A calculation
    warning such as `StatPointsAbove` is not printed by `--check`, as
    no calculation warning is; the window shows them.  Test data
    `test/data/campaign.yaml`, `campaign-extra.yaml` (an extra key) and
    `campaign-zero.yaml` (a floor of 0).  Tests: TestCalc (the limits,
    and a Staged cost), TestWarnings (both texts), TestModel (loading,
    refusals, saving and loading again), TestWindow (the dialog's rows,
    Load and Save Campaign..., Cancel, New from Campaign..., copied not
    linked, New afterwards) and test/cli.sh (`--campaign` on both
    programs, a bad or mecha-only campaign).  Planted bugs, each caught:
    the ceiling or the floor compared one off; the floor's warning
    showing the ceiling; the floor not saved; not read; a campaign
    file's extra keys allowed; New not using the campaign; the
    campaign linked instead of copied; the floor's warning not red;
    the ceiling not shown in the dialog; besm2_calc's notice dropped;
    the campaign's creation not taken.  `make test`, `test-headless`,
    `test-sway` and `valgrind-headless` pass (no valgrind errors).
11. **Preview tab.** The formatters' output of the character as it
    stands; Copy and Save.
    *Decided 2026-11-06:* the tab shows the whole file's entities, in
    order, as the formatters print the file the window would save:
    the entities are saved in memory by `Besm2Save`, loaded again by
    `Besm2Entities` and printed by pobesm2_fmt2's formatters with its
    default options, as `besm2_calc_po` does, so the text is the same
    as `besm2_calc_po`'s or any formatter's for the saved file.  A
    Choice picks the format: reST grid tables (the default), terse
    reST, groff tbl in a raw ms block, or an h-m-m outline.  The
    text is made only while the tab is shown, when it is switched to
    and after each change (`Besm2Window.ShowPreview`, from
    `ShowTitle`).  Copy puts all of it on the clipboard.  Save...
    suggests the file's name without `.yaml` or `.yml`, or, with no
    file, the entity's name (nothing if it has none), with `.rst`
    (raw ms is a reST directive too) or `.hmm`, and says so if it
    can't write the file.
    *Done 2026-11-06:* `src/Besm2Preview.Mod`; the Preview tab in
    `Besm2Window`.  Tests: TestWindow's Preview (nothing made before
    the tab is shown, or while another tab is; made on switching to it
    and displayed; the four formats; what Save... suggests with no
    file, and for `.rst` and `.hmm`; a file's entities all shown; the
    name and tagline typed followed; Copy; a Save... that can't write
    told), and `test/preview.sh`, run by test-gui after TestWindow,
    which compares the preview TestWindow saves in each format with
    `besm2_calc_po`'s and pobesm2_fmt2's output for the same saved
    file, byte for byte.  Planted bugs, each caught: the preview made
    while its tab is hidden; switching tabs not making it; terse and
    raw ms swapped; Save... always suggesting `.rst`; `.yaml` kept in
    the suggestion; Copy doing nothing; a failed write not told; only
    the first entity printed; changing the format not making it again;
    the display not set; the file written one byte short.  One planted
    bug can't be caught: passing every entity the number 1 changes
    nothing with the default options, as the number only chooses the
    subunderliner, which is off by default.  `make test`,
    `test-headless`, `test-sway` and `valgrind-headless` pass (no
    valgrind errors).
12. **Finish.** READMEs, valgrind clean on Xvfb and sway (and the
    command-line program with no display), `make install`.

### Testing

- `make test` (no display): `TestRules`, `TestCalc`, `TestFiles`,
  `TestModel`, `TestSpawn`, `TestViewer` (fake viewers),
  `test/cli.sh`, and `besm2_calc_po` against every fixture.
- `make test-headless` / `make test-sway`: the window tests, on Xvfb
  or a headless sway, never on the user's desktop.
- `make test-viewers`: the real viewers on a private sway and D-Bus.
- `make check-pages`: the tables against the PDF (needs the PDF).
- `make valgrind-headless` / `valgrind-sway`.
- Oracles: the fixture characters for calculations; pobesm2_fmt2 and
  the Ada besm2_fmt for files and formatting.
- Every new test is shown to fail with a planted bug before it is
  trusted, as in ova_cg_po.

## Copyright

The programs and this repository hold the names of Stats, Attributes,
Defects, Skills and Weapon Abilities and Disabilities, their costs,
levels, limits and pages, and nothing of the rules' text. Tests that
need the rulebook's text (`check-pages`, the Skill-table check) read it
from the user's PDF at test time and keep none of it.

## Open questions

1. ~~Which side of the known besm-rst / besm2_fmt differences~~ the
   new programs follow.  Decided: besm2_fmt's (A1.2); the Oberon-2
   ports already match it byte for byte.
2. ~~Printing the new keys~~.  Decided:
   - Weapon Attacks print in the book's order (p. 92, PDF 94), so a
     file `--upgrade`d to the structured keys prints differently there;
     that change is accepted.
   - `creation` gets no summary line in any format; it is for the
     generator and `besm2_calc_po`.
   - An overridden number is marked `*` in the terse and grid formats,
     as ova_fmt does; the other formats print it unmarked.
   - `enhancements` and `limiters` are deprecated for 2E files:
     `--check` warns about them, the formatters keep printing them,
     and `--upgrade` leaves them alone (A4).
3. ~~Share or copy~~ ova_cg_po's viewer, spawn, widgets and paths
   modules.  Decided: copy them, as ova_cg_po copies ova_fmt_po's, so
   a change in one generator can't break the other.
4. ~~Keep the Scheme programs in step~~ with the new keys.  Decided:
   yes, last, after the Ada and the Oberon-2 ports (AGENTS.md); `notes`
   already went in that way.
5. ~~Mecha~~: one file or two.  Decided: both are read.  The generator
   saves the owner and the mecha in one file, as `composite-2e.yaml`
   does; `--check` looks for the mecha in the same file and, when it
   isn't there, gives the notice of A4 ("Mecha").
6. ~~Non-character entities~~ (templates, items).  Decided: the
   programs compute and edit characters and mecha first; other
   entities are loaded and printed by the formatters as now, and are
   left for later.
7. ~~The window's tabs~~ (A5).  Decided: a layout is drafted from
   ova_cg_po's tabs when Part B reaches the window, and brought to the
   user then.  Brought, and approved as drafted (2026-11-06): A5.
8. ~~`besm2_calc_po`'s name~~, and `--fill` without `-o`.  Decided:
   the name stays; without `-o`, `--fill` and `--upgrade` write to
   standard output, so a file is never rewritten unasked.
9. ~~The two undocumented Ada/Oberon departures~~: decided, see
   below.
10. ~~Port `OvaOut.ToRope`/`TakeRope` into pobesm2_fmt2's `Besm2Out`~~
    (with a `TestOut`), committed in pobesm2_fmt2, before besm2_cg_po
    copies its modules (A1.5).  Decided: yes, in Phase 4.

11. **Names the rulebook doesn't have** (A2 results, 3): the fixtures
    use BESM 2nd edition and Big Robots, Cool Starships names.
    Proposed: keep a table of aliases (`Weapon` = Weapon Attack,
    Accessories = Features or Accessories, Hanger Queen = Hangar
    Queen, ...), and accept any other name as a custom item whose
    numbers the user types (an `overrides` entry), with a `--check`
    warning.  (Enyon Boase's names were bugs, now fixed, not aliases;
    Pawl Cardynham's "Unarmed Defence" is the British spelling of
    Unarmed Defense and may be an alias.)
    Partly decided (2026-11-06, by the user): an alias is read, but the
    generator and `besm2_calc_po --upgrade` write BESM2ER's name
    (Hangar Queen, p. 105; Super Strength, p. 74; Heavy Armour, p. 40;
    Unique Character Defect, p. 112; Unarmed Defense, p. 128; Weapon
    Attack, p. 81, with the weapon's name as its `subject`).  Armour
    with a separate Partial Armour Defect is done the BESM2ER way, as
    the campaign's FV2021 Coleopteran already is: Heavy Armour's
    Partial option takes points off its own cost (p. 40), no Defect.
    "X" placeholders (the unfinished Glanna Matthews and Lowdy Penhale)
    are illegal values, not names; a placeholder is 0.
    Decided (2026-11-06, by the user, the rest):
    - **Features or Accessories** (p. 32, PDF 34) is one Attribute in
      `Besm2Rules`, with two display names: "Accessories" on an entity
      with `mecha: true`, "Features" otherwise.  Either word (or the
      full name) is read as it, and `--check` gives at most a warning
      when the word doesn't match the entity; the generator and
      `--upgrade` write the matching word.  The formatters print the
      name as written, so they don't change.
    - **"Natural Attack: Punch"** is not an Attribute (it costs
      nothing); it becomes a note (A4, `notes`).  The fixture
      FV2021-Coleopteran-2e.yaml (and its copies in composite-2e.yaml
      and composite-multi-doc-2e.yaml) was rebuilt from the campaign's
      Coleopteran: Heavy Armour with the Partial option, no Partial
      Armour Defect, the punch as a note, and 43 MP of Attributes, −3
      of Defects, 40 MP in all.  Its `details` are short table values
      (levels, ranges, damage, Weapon Attack Abilities and
      Disabilities); the campaign file's sentences that paraphrase the
      rulebook were left out (AGENTS.md, copyright).  Its spellings
      ("Hanger Queen", "Weapon:", Super-Strength) are kept as aliases
      for the tests.
    - In the campaign (Red-Planet-Blue-Helmets/2ER, 2026-11-06): the
      punch is a note in the Coleopteran, KA-99 Archangel and WT-34
      Bogatyr, and Glanna Matthews's and Lowdy Penhale's "X" entries
      are named "0".  The Bogatyr's Partial Armor Defect (−1) is now
      Heavy Armour 3's Partial option, thin (−1 to its cost, p. 40):
      11 MP, and the same 60 MP in all.  The Archangel's Jumping had
      two `details` keys (a duplicate key, so no program loaded the
      file); the user kept "5 times normal".
    - Found doing so (2026-11-06): in the grid tables the Scheme
      programs never let a word end in a column's last place, and the
      Ada and Oberon-2 programs do, so a detail line that exactly
      fills its column wraps one word earlier in Scheme (the
      Coleopteran's and Bogatyr's Life Support, the Bogatyr's Heavy
      Armour).  None of the test fixtures has such a line.  Decided
      (2026-11-06, by the user): fill the last place.  schemepunk's
      `wrapped` stops a line short of the width and balances the
      lines rather than filling them, so the Scheme programs now use
      their own greedy wrap, the same as besm2_fmt's Word_Wrap; their
      grid output matches besm2_fmt `-n` on the campaign's and the
      fixtures' 2E files at widths 25, 40, 60 (the default) and 120, except for the
      differences already in obesm2_fmt's ADA-DIFFERENCES.md (2.2,
      4.2).
12. **Auto-Fire: 3 slots or 1** (A2 results, 5 and 12): the entry
    says 3, and so do Retro's rule and its corrected Hellcat; BESM2ER's
    examples and the Coleopteran use 1.  Proposed: 3, with a
    `creation.options` switch for 1, and the Coleopteran file marks
    its damage as overridden.
    Decided (2026-11-06, by the user): Auto-Fire takes **3 slots**, as
    its entry says (p. 84, PDF 86).  The switch
    `creation.options: {auto-fire-slots: 1}` (default 3) prices every
    Auto-Fire of that character, and its mecha, as 1 slot, the way the
    examples do.  A single weapon converted from those examples says
    so on its own Ability, `{name: Auto-Fire, counts-as: 1}`, not with
    `overrides`, so its damage stays computed and `--check` passes.
    The campaign's FV2021 Coleopteran Rocket Pod (Level 2: Auto-Fire,
    Area Effect, Limited Shots ×2, Stoppable) is written that way:
    15 × (2 − 2 + 3) = 45, as its file says now.  It gets the keys
    when the formatters learn the Weapon Attack keys (A4), since
    today they would ignore them.  So `counts-as` is the slots an
    Ability or Disability counts as (A4, Weapon Attacks): left out,
    it is the book's slots times one.
    Changed (2026-11-06, by the user, with question 14): the Rocket
    Pod takes the book's 3 slots too, not `counts-as: 1`: 15 × (2 − 4
    + 3) = 15 damage.  The switch and `counts-as` stay for anyone who
    wants the examples' pricing; no campaign file uses them.
13. **Melee: 2 slots or 1** (step 2, 2026-11-06): Melee is a 2-slot
    Disability (p. 91, PDF 93), but the campaign prices it as 1: the
    Coleopteran's Plasma Fist (Level 2, Melee and Limited Shots, 60
    damage), the Bogatyr's Plasma Sword (Level 3, Melee, 60) and the
    Archangel's Harmonic Knife (Level 1, Melee, 30).  With 2 slots they
    would be 75, 75 and 45.  Proposed, as question 12: Melee keeps its
    2 slots, and those three weapons say `{name: Melee, counts-as: 1}`
    when they get the Weapon Attack keys, so their files' damage stays
    as it is and computed.  `TestCalc` builds them that way.
    Decided (2026-11-06, by the user): Melee is **2 slots**, as the
    rulebook says, and the weapons are corrected to it: the Plasma
    Fist and the Plasma Sword are Damage ACV+75, the Harmonic Knife
    ACV+45.  Their points don't change.  Changed in the campaign's
    mecha and in the fixtures and goldens of besm2_fmt, obesm2_fmt,
    obesm2_fmt2, pobesm2_fmt2 and the Scheme programs ("ACV+60" became
    "ACV+75", the same width, so no output reflowed), and in the
    campaign's .rst files; every test passes.  `TestCalc` expects 75.
14. **The Gatling Gun and the Auto-Laser** (step 2, 2026-11-06): the
    Bogatyr's Gatling Gun (Level 3: Accurate, Auto-Fire, Limited Shots,
    Unreliable) and the Archangel's Auto-Laser (Level 1: Auto-Fire,
    Limited Shots, Unreliable) both say 30 damage.  The rules give the
    Gatling Gun 15 with Auto-Fire at 3 slots and 45 at 1, and the
    Auto-Laser 0 (below 15, warned) at 3 and 45 at 1; no choice of
    slots gives 30 for either.  Their points (2 each, secondary
    attacks) and the mecha's totals are right either way.  Proposed:
    give them `counts-as: 1` like the Rocket Pod and change their
    damage to 45, or keep 30 as an override (A4, `overrides`), which
    `--check` will then list.
    Decided (2026-11-06, by the user): Auto-Fire is **3 slots**, as
    both BESM2ER and Retro say, for every campaign weapon: the Rocket
    Pod and the Gatling Gun are Damage 15, and the Auto-Laser takes
    Limited Shots ×2 (3 shots), so 15 × (1 − 3 + 3) = 15, at the same
    2 points.  No points or totals change.  Changed in the campaign's
    mecha and its two .rst files, and the Rocket Pod in the fixtures,
    goldens and `TestEntities` of besm2_fmt, obesm2_fmt, obesm2_fmt2,
    pobesm2_fmt2 and the Scheme programs ("ACV+45" became "ACV+15",
    the same width; each changed only where the nearest weapon name
    before it is the Rocket Pod, so the Railgun's ACV+45 stays: 547
    of each).  Every test passes.
15. **A YAML key for a Different Gunner** (step 2, 2026-11-06): a mecha
    weapon with a gunner of its own costs 5 Mecha Points more (p. 82,
    PDF 84), and Besm2Calc prices it, but A4 has no key for it.
    Proposed: `different-gunner: true` on a Weapon Attack, beside
    `primary`, printed after the Disabilities as "Different Gunner";
    left out, false.  No file has one yet.
    Decided (2026-11-06, by the user): as proposed (A4, Weapon
    Attacks).
16. **Arkady Varenkov's mecha** (step 2, 2026-11-06): his Own a Big
    Mecha's subject is "WT-34 Bogatry"
    (`Red-Planet-Blue-Helmets/2ER/Entities/NPCs/arkady-varenkov.yaml`,
    line 42, and `red-planet-blue-helmets.rst`, line 154), but the
    mecha is "WT-34 Bogatyr", so A4's link by name would not find it.
    Proposed: correct the spelling in both (a campaign commit, with
    the user's go-ahead).  His Own a Big Mecha 3 (12 points, 60 Mecha
    Points) matches the Bogatyr's 60.
    Done (2026-11-06, by the user's decision): corrected there and in
    `notes.hmm`, campaign commit 85debd2.

Decided (2026-11-06, by the user unless it says otherwise; questions
1-8 and 10 by the user taking Claude's suggestions):

- ~~How pages are shown~~: both the printed page and the PDF page,
  everywhere ("The rulebook and its pages", "Pages beside names").
- ~~Compute in the formatters, or a new program~~: a new command-line
  program sharing the generator's modules; the formatters only learn to
  print the new keys (A3; decided by Claude at the user's request).
- ~~How the free text becomes structured~~: `subject`, a Defect's
  `level`, the Weapon Attack keys, the mecha link through `subject`,
  `creation`, `overrides` (A4; decided by Claude at the user's
  request; the printing decided in question 2).
- ~~YAML aliases and overflow in a total~~ (question 9): not fixed in
  the formatters; recorded in obesm2_fmt's ADA-DIFFERENCES.md (a
  commit there, with the user's go-ahead); `--check` reports a number
  outside −999..999 as an error and an alias as a warning; the
  generator never writes either (A1 results, A3).
- ~~The Red Planet Blue Helmets characters~~ (2026-11-06): the campaign
  uses Table 2-4's Modern Military costs (p. 119, PDF 121), with
  Persuasion a house rule at 3 SP a Level (`creation.house-skills`,
  A4).  Enyon Boase's differences were bugs from his 4th Edition
  version: Extra Actions is Extra Attacks (p. 32, PDF 34), "+1 Extra
  Attack"; Leadership is the specialisation of Military Sciences 1
  (p. 123, PDF 125; 5 SP); and Political Sciences is Social Sciences 1
  (p. 125, PDF 127; Politics, 2 SP).  So he has 20 SP like the others.
  The other PCs' slips were fixed to Modern Military costs (Vyvyan,
  Jope and Kitto, each 20 SP), and every "Extra Action" detail now
  says "Extra Attack".  Fixed in the campaign's files and in the
  fixtures and goldens of besm2_fmt, obesm2_fmt, obesm2_fmt2,
  pobesm2_fmt2 and the Scheme programs (not the 4th Edition files).
