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
   the ones that don't, for the user to fix in the bookmark list:
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
   SV = HP div 5.  Changed by Combat Mastery (ACV and DCV +1 a
   Level, p. 130's example), Damn Healthy! and Toughness (HP), Energy
   Bonus and Place of Power (EP), Not So Tough and Diminutive (HP).
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
   lower Level (p. 82); a Different Gunner +5 Mecha Points (p. 83); as
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
    `BESM2ER_bookmarked.pdf` (2026-11-06): the misspellings and Force
    Field Disabilities are right now.  Still to fix there, from this
    check and the outline: no Linked (Attribute) bookmark (PDF 89);
    "Unique Character Attribute — Wealth" lacks the heading's
    "Sample"; "Mecha-Only Defects" (PDF 116) and "Step 8: Background
    Points" (PDF 132, both found by font) have no destination; "Table
    3-4 Defense Roll modifiers" should have a capital M; and Table 3-5
    (PDF 148; "Criticals" in the chapter, "Critical Damage" in the
    book's list of tables) has no bookmark.  Two pages looked at by eye agree with the
    headings by font: PDF 44 (printed 42; Highly Skilled, Illusion)
    and PDF 92 (printed 90; Drop Shields to Low Penetration).
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
    Hangar).  Extra Actions, Leadership, Persuasion and Political
    Sciences (Enyon Boase) are in none of BESM1E, BRCS, Hot Rods and
    Gun Bunnies, BESM2ER or Retro as items; they came from his 4th
    Edition version, and are now fixed or a house rule (see "Decided").

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

#### Weapon Attacks: `damage`, `abilities`, `disabilities`, `primary`

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
- Formatters print these as the book records an attack (p. 92):
  the Abilities, then the Disabilities, a repeat as `×2` (`x2` in
  ASCII mode) and a detail in brackets, then the damage, then
  `details` if any: `Weapon Attack 3: Plasma Buster Missiles (Area
  Effect, Homing, Long Range, Limited Shots ×2 [3 shots], Slow,
  Stoppable, 60 Damage. 12 CP)`. The existing fixtures write `Damage
  45` first; an `--upgrade`d one will print in the book's order, a
  change in output accepted for the structured form only.
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

#### Sub-choices

`elements` stays for Elemental Control and the like. If A2.4 finds
other Attributes whose choices change their cost, they get `choices:`,
a list of names, printed as `elements` is; otherwise choices stay in
`details`.

#### Rolling it out

1. A fixture, `test/data/extended-2e.yaml`, with every new key, and
   the upgraded forms of `composite-2e.yaml` and
   `enyon-boase-2e.yaml`.
2. The Ada `besm2_fmt` first: print `subject` and the Weapon Attack
   keys, ignore the rest, golden files for the new fixture, the old
   golden files unchanged; then obesm2_fmt, obesm2_fmt2 and
   pobesm2_fmt2, each byte-for-byte with the Ada; then the four
   `besm2-rst*.scm` (AGENTS.md: all should produce the same output).
3. Each repo committed on its own, with the user's go-ahead.

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
| `Besm2Character` | both | a character (and its mecha) as records; loading from `Besm2Entities`' entities, the edits, `Recompute` |
| `Besm2Upgrade` | calc | free text to the keys of A4 |
| `Besm2Entities`, `Besm2Out`, `Besm2Text`, `Besm2Config`, the formatters | both | pobesm2_fmt2's, copied and kept in step (with the new keys once A4 is rolled out) |
| `Besm2Save` | both | YAML through polibfyaml's emitter (`NewDocument`, `CreateStyledScalar`, ...), written to `NAME.tmp` then renamed |
| `Besm2CalcMain` | calc | the command line: `--check`, `--fill`, `--upgrade`, the formatting options |
| `Besm2Cg` | window | the command line (a file, `--rulebook`, `--viewer`), the display check, then the window |
| `Besm2Viewer`, `Besm2Spawn` (+ `.c`) | window | ova_cg_po's `OvaViewer` and `OvaSpawn`, adapted: no page labels, so always the PDF page |
| `Besm2Paths`, `Besm2Settings` | window | as ova_cg_po's |
| `Besm2Widgets` | window | `NumberBox` (computed number and its override box), `HelpButton` (**?**), `Panel` (a list and its editor) |
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
1. **`Besm2Rules`.** The tables from A2; `TestRules`: every name
   present once, both pages for each, each in its section's range,
   costs as the reference section gives them, the label format; `make
   check-pages` against the PDF's headings by font. Shown to fail with
   planted bugs.
2. **`Besm2Calc`.** Every rule from A2, with `TestCalc` over every
   fixture character and mecha (each number the file holds compared)
   and hand-made cases for each rule, each Weapon Ability and
   Disability, primary and secondary attacks, each limit, and
   overrides feeding what depends on them.
3. **The YAML extensions** (A4, "Rolling it out") in the formatters,
   before either program writes them.
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
5. **The rulebook viewer.** `Besm2Viewer`/`Besm2Spawn` from
   ova_cg_po (okular over D-Bus, evince, mupdf, xdg-open, a template
   with `%f` the file and `%p` the PDF page; reusing a running viewer);
   `TestViewer` with fake viewers, `make test-viewers` with the real
   ones on a headless sway.
6. **The window: Character tab.** Name, tagline, size, Stats, derived
   values with their override boxes, the points summary; File New,
   Open, Save, Save As with the save-first question; Rulebook > Open,
   Choose PDF..., Viewer....
7. **Attributes, Defects and Skills tabs.** Pick by name (with both
   pages) and level, subject, detail, Add / Change / Remove, **?**; the
   totals and warnings update as you go; Skills' specialisations and
   the genre.
8. **Weapon Attacks.** The dialog: subject, level, Abilities and
   Disabilities with counts and details, primary; damage and cost
   following each change.
9. **Mecha and several entities.** A mecha entity tied to its
   owner's Own a Big Mecha, its Mecha Points checked; several entities
   in a file (Add, Duplicate, Remove, Move, Next/Previous), as
   ova_cg_po's Phase 13.
10. **Options and limits.** Character > Creation...: the campaign's
    Character Points, Background Points, genre, Skill Points, Staged
    Stat Cost, the GM's ceilings.
11. **Preview tab.** The formatters' output of the character as it
    stands; Copy and Save.
12. **Finish.** READMEs, valgrind clean on Xvfb and sway (and the
    command-line program with no display), `make install`.

### Testing

- `make test` (no display): `TestRules`, `TestCalc`, `TestFiles`,
  `TestModel`, `TestViewer` (fake viewers), `test/cli.sh`, and
  `besm2_calc_po` against every fixture.
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
   user then.
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
