# besm2_cg_po -- a BESM2ER character generator in Oberon-2, built with
# poc, the Peaseblossom Oberon Compiler, with pofltk (FLTK) for its
# window and polibfyaml for its files; and besm2_calc_po, the
# command-line program that shares its calculations.  See AGENTS.md
# and PLAN.md.  Taken from ova_cg_po's GNUmakefile.
#
# poc builds a program from its main module's source.  The shared
# modules come compiled, from the poc libraries argparser, ropes,
# polibfyaml and pofltk on the library path; the programs' own modules
# it finds on the import path (src/, and test/ for the tests) and
# compiles again on each build, so a new module needs no rule.  What poc
# writes -- each module's .sym, .ll and .o, and the test programs --
# goes into $(OBJ).
#
# Every program writes this repo's modules' files into the same $(OBJ),
# so make must not build two at once.

SHELL = bash

POC      ?= poc
# Size model: polibfyaml and pofltk require -OC, and models can't be
# mixed, so every module here gets it.
POCFLAGS := -OC

# libfyaml's link flags: the polibfyaml library doesn't record them.
# pofltk's manifest records its own (c++, -lfltk_images, -lfltk).
FYAML_LIBS := $(shell pkg-config --libs libfyaml)
LINK := $(foreach f,$(FYAML_LIBS),-link $(f))

# The libraries, each installed by its own repo into POCLIBDIR: argparser
# and ropes (make -f pocGNUmakefile install in ArgParser and Ropes),
# polibfyaml and pofltk (make install).  None of their sources is copied
# here.  POCLIBDIR doesn't follow PREFIX, which says where the programs
# install.
POCLIBDIR ?= $(HOME)/.local/lib/poc
SHAREDLIBS := argparser ropes polibfyaml pofltk
LIBPATH := -library-path $(abspath $(POCLIBDIR))

# The libraries this build takes are the ones in $(POCLIBDIR).  A library
# on POC_LIBRARY_PATH would stop the build if another poc wrote it.
unexport POC_LIBRARY_PATH
IMPORTS := -import-path src $(LIBPATH)

OBJ := obj

# The window, and the command line.
PROGRAM := besm2_cg_po
MAIN    := Besm2Cg
CALC     := besm2_calc_po
CALCMAIN := Besm2CalcMain
PROGRAMS := $(PROGRAM) $(CALC)

# Every source and library a program is built from, for make's
# dependencies: a reinstalled library rebuilds the programs.
SHAREDLIBMANIFESTS := $(foreach l,$(SHAREDLIBS),$(wildcard $(POCLIBDIR)/*/OC/$(l).library))
PROGSRC := $(wildcard src/*.Mod src/*.c)

# Test support modules, and test programs (test/<name>.Mod, main
# modules): TESTS need no display, GUITESTS do.  More come
# with the modules of PLAN.md, Part B.
TESTSUPPORT := test/Check.Mod
TESTS       := TestRules TestCalc TestOut TestSpawn TestViewer TestPaths TestWarnings
GUITESTS    := TestWindow
TESTBINS    := $(TESTS:%=$(OBJ)/%)
GUITESTBINS := $(GUITESTS:%=$(OBJ)/%)
# Seconds a test may run before it counts as hung, and how long the
# window must keep running to count as started (test-gui).
TIMEOUT  ?= 60
RUNTIME  ?= 3

# Only building needs the libraries, so the cleaning targets don't
# check for them.
ifneq ($(if $(MAKECMDGOALS),$(filter-out clean uninstall print-%,$(MAKECMDGOALS)),all),)
$(foreach l,$(SHAREDLIBS),$(if $(wildcard $(POCLIBDIR)/*/OC/$(l).library),,$(error the $(l) library is not in $(POCLIBDIR); install it from its repo (AGENTS.md))))
endif

.PHONY: all tests test check-pages test-viewers test-gui test-headless test-sway valgrind valgrind-headless valgrind-sway \
  display install uninstall clean
.NOTPARALLEL:

all: $(PROGRAMS)

tests: $(PROGRAMS) $(TESTBINS) $(GUITESTBINS)

$(OBJ):
	mkdir -p $@

$(PROGRAM): src/$(MAIN).Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -output-dir $(OBJ) $(LINK) -o $@ $<

$(CALC): src/$(CALCMAIN).Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -output-dir $(OBJ) $(LINK) -o $@ $<

$(OBJ)/Test%: test/Test%.Mod $(TESTSUPPORT) $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<

# Besm2Rules' tables as text, for tools/check-rules.py and
# tools/check-pages.py.
$(OBJ)/ListRules: test/ListRules.Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) -o $@ $<

$(OBJ)/rules.txt: $(OBJ)/ListRules
	$(OBJ)/ListRules > $@

# pobesm2_fmt2, built, whose fixtures and output test/files.sh compares
# besm2_calc_po's with (PLAN.md, Part B, step 4).
POBESM2_FMT2 ?= $(HOME)/Repos/RPG/Tools/pobesm2_fmt2

# What needs no display: the unit tests, Besm2Rules against rules/
# (tools/check-rules.py), then test/cli.sh and test/files.sh; fail at
# the end if any failed.
test: $(PROGRAMS) $(TESTBINS) $(OBJ)/rules.txt
	@status=0; for t in $(TESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	echo "== check-rules.py"; tools/check-rules.py $(OBJ)/rules.txt rules || status=1; \
	echo "== cli.sh"; test/cli.sh ./$(PROGRAM) ./$(CALC) || status=1; \
	echo "== files.sh"; test/files.sh ./$(CALC) $(POBESM2_FMT2)/pobesm2_fmt2 $(POBESM2_FMT2)/test/data || status=1; \
	exit $$status

# The rulebook: the original, with a text layer, for the headings by
# font, and the bookmarked copy, whose hand-typed bookmarks are a second
# check (AGENTS.md, "The PDFs").
RULEBOOK ?= $(HOME)/Reference/RPG/Dyskami/BESM/2E/BESM2ER.pdf
BOOKMARKED ?= $(HOME)/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf

# Every page of the tables in rules/, and of Besm2Rules, against the
# rulebook's headings by font (PLAN.md, A2.11).  Not part of make test:
# it needs the PDFs and mutool.  A bookmark that disagrees is a note,
# not a failure.
check-pages: $(OBJ)/rules.txt
	@tools/check-pages.py $(RULEBOOK) $(BOOKMARKED) rules $(OBJ)/rules.txt

# Besm2Viewer with the real viewers, okular, evince and mupdf, on a
# headless sway of test/viewer.sh's own, on a private D-Bus session bus,
# with a scratch HOME (PLAN.md, Part B, step 5).  Not part of make test:
# it needs the viewers, and takes a minute or two.
$(OBJ)/OpenPage: test/OpenPage.Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<
test-viewers: $(OBJ)/OpenPage
	test/viewer.sh $(OBJ)/OpenPage

# FLTK needs a display even for windows never shown.  An agent never
# runs these on the user's desktop (AGENTS.md): use test-headless or
# test-sway.
display:
	@if [ -z "$$DISPLAY$$WAYLAND_DISPLAY" ]; then \
	  echo "the window tests need a display: use make test-headless or make test-sway"; exit 1; \
	fi

# The window tests, then the program itself, which waits for the user:
# it must still be running after RUNTIME seconds, when timeout ends it
# (status 124): it started, drew, and didn't crash.  Then test/quit.sh:
# started again, it quits on Ctrl+Q (X11 only; skipped on Wayland).
# The program's own runs keep their preferences in obj/config, not the
# user's ~/.config.
test-gui: tests display
	@export XDG_CONFIG_HOME=$(CURDIR)/$(OBJ)/config; \
	status=0; for t in $(GUITESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	echo "== $(PROGRAM) (must still be running after $(RUNTIME) s)"; \
	timeout $(RUNTIME) ./$(PROGRAM); st=$$?; \
	if [ $$st -eq 124 ]; then echo "ok   - $(PROGRAM) started and ran"; \
	else echo "FAIL - $(PROGRAM) exited with $$st"; status=1; fi; \
	echo "== quit.sh"; test/quit.sh ./$(PROGRAM) || status=1; \
	exit $$status

# On a virtual X server (Xvfb).  WAYLAND_DISPLAY is unset because FLTK
# prefers Wayland when it is set, even under xvfb-run (pofltk's
# finding).
test-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) test-gui

# On Wayland, on a headless sway (tools/with-sway.sh, pofltk's).
test-sway: tests
	tools/with-sway.sh $(MAKE) test-gui

# The tests under valgrind.  Memory errors fail a run; leaks don't by
# themselves, since FLTK's display stack (fontconfig, Pango, and GTK's
# decorations under Wayland) leaks by design.  pofltk's vg-check.sh fails
# instead on any leak whose allocator is pofltk's (a widget never
# deleted); test/poc-gc.supp holds the collector's stack-scan reports
# (pofltk's AGENTS.md, "Valgrind").  A child Besm2Spawn forks reports
# nothing: it only execs or exits (_exit, leaving its copy of the
# argument vector), and what it runs isn't ours to check.
POFLTK ?= $(HOME)/Repos/Oberon/pofltk
VALGRIND ?= valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=none \
  --error-exitcode=99 --child-silent-after-fork=yes --suppressions=$(CURDIR)/test/poc-gc.supp
valgrind: tests display
	@status=0; for t in $(TESTS) $(GUITESTS); do \
	  echo "== valgrind $$t"; \
	  (cd test && $(VALGRIND) --log-file=../$(OBJ)/$$t.vg ../$(OBJ)/$$t) || status=1; \
	  grep -E 'ERROR SUMMARY' $(OBJ)/$$t.vg; \
	  $(POFLTK)/test/vg-check.sh $(OBJ)/$$t.vg || { echo "FAIL - $$t: memory pofltk allocated was not freed"; status=1; }; \
	done; \
	if [ $$status -eq 0 ]; then echo "All checks passed."; else exit 1; fi

valgrind-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) valgrind

valgrind-sway: tests
	tools/with-sway.sh $(MAKE) valgrind

# ---- Installation ----
#
# To $(PREFIX)/bin, $HOME/local/bin by default, as ova_cg_po's.
# DESTDIR is prepended, for staging.
PREFIX ?= $(HOME)/local
BINDIR ?= $(PREFIX)/bin

install: $(PROGRAMS)
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(PROGRAMS) $(DESTDIR)$(BINDIR)/

uninstall:
	rm -f $(PROGRAMS:%=$(DESTDIR)$(BINDIR)/%)

clean:
	rm -rf $(OBJ) $(PROGRAMS)

print-%: ; @echo $* = $($*)
