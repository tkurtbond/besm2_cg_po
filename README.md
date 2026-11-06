# besm2_cg_po - a BESM2ER character generator in Oberon-2, built with poc

`besm2_cg_po` will build characters for Big Eyes Small Mouth, 2nd
Edition Revised (BESM2ER), in a window. You pick Stats, Attributes,
Defects, Skills and Weapon Attacks by name, and it keeps track of
Character Points, Bonus Points and Skill Points and works out the
derived values. It holds no rules text. Each name shows its rulebook
page, both printed and PDF, e.g. `Highly Skilled (p. 42, PDF 44)`, and
the program can open the rulebook's PDF at that page in your PDF viewer.
`besm2_calc_po` is its command-line companion, and shares its
calculations. It checks, fills in, upgrades and formats existing
character files. Both programs write YAML that the existing formatters
print: besm2_fmt, pobesm2_fmt2 and the others.

They are written in Oberon-2 for poc, the
[Peaseblossom](https://github.com/tkurtbond/peaseblossom) Oberon
compiler, with pofltk (FLTK 1.4) for the window and polibfyaml for YAML.

**Status: skeleton** (step 0 of PLAN.md, Part B). The window opens
with File > Quit (Ctrl+Q), and both programs take `-h`. The plan and
the analysis of the rules behind it are in [PLAN.md](PLAN.md).

## Usage

```
besm2_cg_po [options]
besm2_calc_po [options] file.yaml...
```

`-h` lists the options. Neither program opens files yet: a file
argument is reported as a usage error (status 2). `besm2_cg_po` needs a
display (`DISPLAY` or `WAYLAND_DISPLAY`). Without one it says so and
exits with status 1. `besm2_calc_po` never needs a display.

## Building

You need poc, libfyaml (with `pkg-config`), FLTK 1.4, and these poc
libraries installed in `~/.local/lib/poc` (`POCLIBDIR`):

- argparser and ropes (`make -f pocGNUmakefile install` in ArgParser and
  Ropes);
- polibfyaml and pofltk (`make install`).

```
make                  # besm2_cg_po and besm2_calc_po
make test             # what needs no display, and Besm2Rules against rules/
make test-headless    # the window tests, on Xvfb
make test-sway        # the window tests, on a headless sway
make valgrind-headless
make check-pages      # the pages in rules/ and Besm2Rules against the rulebook's PDF
make install          # to ~/local/bin (PREFIX)
```

The window tests never use your desktop: run them through
`test-headless` or `test-sway`.
