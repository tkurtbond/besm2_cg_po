# besm2_cg_po - a BESM2ER character generator in Oberon-2, built with poc

`besm2_cg_po` builds characters, and their mecha, for Big Eyes Small
Mouth, 2nd Edition Revised (BESM2ER), in a window. You pick Stats,
Attributes, Defects, Skills and Weapon Attacks by name, and it keeps
track of Character Points, Bonus Points, Skill Points and Mecha Points
and works out the derived values as you go. It holds no rules text.
Each name shows its rulebook page, both printed and PDF, e.g. `Highly
Skilled (p. 42, PDF 44)`, and the program can open the rulebook's PDF
at that page in your PDF viewer.

`besm2_calc_po` is its command-line companion, and shares its
calculations. It checks, fills in, upgrades and formats existing
character files. Both programs write every number into the YAML they
save, so the existing formatters (besm2_fmt, pobesm2_fmt2 and the
others) print their files correctly.

They are written in Oberon-2 for poc, the
[Peaseblossom](https://github.com/tkurtbond/peaseblossom) Oberon
compiler, with pofltk (FLTK 1.4) for the window and polibfyaml for YAML.

**Status: complete** (steps 0 to 12 of PLAN.md, Part B). The plan, the
analysis of the rules behind it, and every decision made along the way,
with its date and pages, are in [PLAN.md](PLAN.md). The YAML keys these
programs add to the format are described in its A4. All of them are
optional, so older files load and print unchanged.

## Usage

```
besm2_cg_po [options] [file.yaml]
besm2_calc_po [options] [files...]
```

`-h` lists each program's options.

**besm2_cg_po** opens the file given, or a new character.
- **`-r`/`--rulebook PATH`** gives the rulebook's PDF. Otherwise it uses
  `BESM2_RULEBOOK`, else the one chosen with Rulebook > Choose PDF...,
  else `~/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf`.
- **`-v`/`--viewer`** gives the viewer: `okular`, `evince`, `mupdf`,
  `xdg-open`, or a command with `%f` for the PDF and `%p` for its page.
  Otherwise it uses the one chosen with Rulebook > Viewer....
- **`--campaign FILE`** starts File > New's characters in a campaign's
  creation (see Campaign files below).

The choices made in the window are kept in
`$XDG_CONFIG_HOME/besm2_cg_po/besm2_cg_po.prefs` (else under
`~/.config`). A file that can't be read, or that the formatters would
refuse, is reported, and the program exits with status 1. The program
needs a display (`DISPLAY` or `WAYLAND_DISPLAY`). Without one it says so
and exits with status 1.

**besm2_calc_po** never needs a display. With no other option, it
formats each file as pobesm2_fmt2 does, after computing every number,
and takes pobesm2_fmt2's formatting options:
- `-t` for terse reST;
- `-m` for groff tbl in a raw ms block;
- `-H` for an h-m-m outline;
- and the rest, as `-h` lists.

It also takes these options:
- **`--check`** lists, on standard error, each number in the files that
  disagrees with the rules, and anything else wrong. It exits with
  status 1 if there is any.
- **`--fill`** writes the file with every number computed, to `-o FILE`
  or standard output.
- **`--upgrade`** does what `--fill` does, and also moves what used to
  be free text into the new keys: subjects split from names, BESM2ER's
  names for older ones, Defect levels, and a Weapon Attack's damage,
  Abilities and Disabilities.
- **`--campaign FILE`** gives each character a campaign's creation
  first. A creation that differs from it is reported as a difference.

## Using the window

The window is 640 by 800, its smallest size. It has seven tabs:
**Character**, **Attributes**, **Defects**, **Skills**, **Mecha**,
**Background** and **Preview**. Every change goes into the character at
once, and every number is recomputed as you work. The title shows the
file's name, then ` *` while there are unsaved changes, and "(i of n)"
when the file holds more than one character or mecha.

### Menus

| Menu | Item | Key |
|---|---|---|
| File | New, New from Campaign..., Open..., Save, Save As..., Quit | Ctrl+N, -, Ctrl+O, Ctrl+S, Ctrl+Shift+S, Ctrl+Q |
| Character | Creation... | |
| Character | Add Character, Add Mecha, Duplicate, Remove... | |
| Character | Move Up, Move Down | |
| Character | Next, Previous | Ctrl+PgDn, Ctrl+PgUp |
| Rulebook | Open, Choose PDF..., Viewer... | |

New, Open and Quit first ask whether to save unsaved changes (Save,
Don't save, Cancel). So does the window's close button.

The menu at the right of the menu bar lists the file's characters and
mecha by number and name. Choose one to show it. Remove... asks first,
and is greyed out when the file holds only one. Move Up and Move Down
change the order. The formatters print every entity after the first as
a subentry, so put the main one first. Save writes all of them, in
order.

### Rulebook pages and overrides

**Rulebook pages.** Every name, in a list or a menu, shows its printed
and PDF page, and each **?** button opens the rulebook at that page.

**Overrides.** Beside each computed number (a Stat's points, the derived
values, an item's points) is an empty box. Type a whole number there to
override the computed one, for a GM's ruling or a house rule. The
computed number stays shown beside it, and whatever is computed from it
uses the override. Empty the box to go back to the computed number.

A file whose numbers differ from the rules' keeps them as overrides,
and says which when it opens.

### The Character tab

The tab has these parts, from the top:
- **Name, Tagline and Size.**
- **The Stats**, Body, Mind and Soul. Each has its value, its points and
  a **?**.
- **The derived values**: ACV, DCV, HP, EP and SV, and AR when the
  character has an Armour.
- **The points**: Character Points (the Stats and Attributes less the
  Bonus Points, against what the creation gives), Bonus Points and Skill
  Points. A total over its limit turns red.
- **The warnings**: what the rules find wrong, with the pages of the
  rules.

The points and the warnings are repeated under the Attributes, Defects,
Skills and Mecha lists, so they stay in view.

### The Attributes, Defects and Skills tabs

Each tab is a list with an editor under it:
- **Adding:** choose a name (each shows its pages), set its Level or
  rank, its subject or details, and press **Add**.
- **Changing:** click a line to load it back into the editor, then
  press **Change** to replace it, or **Remove** to take it out.
- **Options:** an Attribute's options are listed under it. Use **+**
  and **-** to take the selected option once more or once less.
- **The Skills tab** also chooses the genre (Table 2-4), which sets
  every Skill's cost. Specialisations are typed separated by commas; the
  first is free.

**Weapon...**, under the Attributes list, opens the selected Weapon
Attack:
- its subject, Level and details;
- **Primary** and **Different Gunner**;
- its Abilities and Disabilities, each with its slots and details.

Its damage, points and warnings follow each change. **OK** keeps the
subject and details, and **Cancel** puts everything back as it was.

### The Mecha tab

**On a character,** it lists each Own a Big Mecha with its Mecha Points
and what its mecha spends of them. The mecha is the entity in the file
whose name is the Attribute's subject.
- **Show Mecha** goes to that mecha.
- **New Mecha** adds one, named by the subject.

**On a mecha,** it lists each character whose Own a Big Mecha names it.
**Show Owner** goes to that character.

Renaming a mecha renames the subjects that name it, so the link holds.

### The Background tab

The description and the notes. Notes are short lines, printed after the
Skills and never priced.

### The Preview tab

The file's characters and mecha as the formatters print the saved
file, in reST grid tables, terse reST, groff tbl in a raw ms block, or
an h-m-m outline. It is the same text `besm2_calc_po` (with no option,
`-t`, `-m` or `-H`) and pobesm2_fmt2 make of the file. The text is
kept up to date while the tab is shown.
- **Copy** puts all of it on the clipboard.
- **Save...** writes it to a file, suggesting the file's name with
  `.rst` or `.hmm`.

Saving the preview doesn't save the characters.

### Character > Creation...

The rules the character is built under, each with a **?**:
- Character Points and Background Points;
- the genre and the GM's Skill Points;
- Staged Stat Cost (Table 4-7);
- a ceiling on each Stat, a ceiling and a floor on the Stats' total
  cost, and a ceiling on the Bonus Points;
- Auto-Fire counted as 1 slot.

The window follows each change. **OK** keeps the changes, and
**Cancel**, the close button or Escape puts them back. **Copy from**
takes the whole creation, house Skills too, from another character in
the file. On a mecha, Creation... edits its owner's creation, which
prices the mecha. **Add Character** starts with the creation of the
character shown.

### Campaign files

A campaign file holds just a `creation`, for a GM to hand to the
players.
- **Save Campaign...** and **Load Campaign...**, in the Creation dialog,
  write one and read one in. Loading also works from a character's
  file, taking its first character's creation.
- **File > New from Campaign...** starts a character in a campaign, and
  File > New then starts each one in it too.
- **`--campaign`** does the same from the command line for either
  program.

## Building

You need poc, libfyaml (with `pkg-config`), FLTK 1.4, and these poc
libraries installed in `~/.local/lib/poc` (`POCLIBDIR`):

- argparser and ropes (`make -f pocGNUmakefile install` in ArgParser and
  Ropes);
- polibfyaml and pofltk (`make install`).

The tests need a poc from Peaseblossom commit 834fb98 on, which emits a
string literal in an array index; 0.11.0 doesn't. `POC` names another
poc, e.g. `make POC=~/Repos/Oberon/Peaseblossom/build/bin/poc test`.

```
make                  # besm2_cg_po and besm2_calc_po
make install          # both, to ~/local/bin (PREFIX, BINDIR; DESTDIR to stage)
make uninstall
```

## Testing

```
make test             # what needs no display: the unit tests, the rules
                      #   tables, besm2_calc_po against pobesm2_fmt2
make test-headless    # the window tests, on Xvfb
make test-sway        # the window tests, on a headless sway
make valgrind-headless
make valgrind-sway
make valgrind-calc    # the tests needing no display, and besm2_calc_po on
                      #   copies of every fixture, under valgrind
make test-viewers     # the real PDF viewers, on a private sway and D-Bus
make check-pages      # the pages in rules/ and Besm2Rules against the PDF
```

The window tests never use your desktop: run them through
`test-headless` or `test-sway`, never `test-gui` by itself. The tests
compare against pobesm2_fmt2's binary and fixtures, in
`~/Repos/RPG/Tools/pobesm2_fmt2` (`POBESM2_FMT2`), which they only
read. `check-pages` needs `BESM2ER.pdf` and `BESM2ER_bookmarked.pdf`
(`RULEBOOK`, `BOOKMARKED`) and mutool.
