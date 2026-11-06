# besm2_cg_po.  Only check-pages so far; the programs come in Part B
# of PLAN.md, following ova_cg_po's GNUmakefile.

.PHONY: check-pages

# The rulebook: the original, with a text layer, for the headings by
# font, and the bookmarked copy, whose hand-typed bookmarks are a second
# check (AGENTS.md, "The PDFs").
RULEBOOK ?= $(HOME)/Reference/RPG/Dyskami/BESM/2E/BESM2ER.pdf
BOOKMARKED ?= $(HOME)/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf

# Every page of the tables in rules/ against the rulebook's headings by
# font (PLAN.md, A2.11).  Not part of make test: it needs the PDFs and
# mutool.  A bookmark that disagrees is a note, not a failure.
check-pages:
	@tools/check-pages.py $(RULEBOOK) $(BOOKMARKED) rules
