#!/bin/bash
# preview.sh CALC FMT: the Preview tab's text (PLAN.md, Part B, step
# 11) against the formatters'.  TestWindow saves obj/preview.yaml and
# its preview in each format; each must be byte for byte what
# besm2_calc_po, and pobesm2_fmt2, print for that file in that format.
# Run after TestWindow, from the top directory.
set -u
calc=$1 fmt=$2
status=0
out=$(mktemp -d) || exit 2
trap 'rm -rf "$out"' EXIT

check() { # check LABEL CONDITION...
  local label=$1; shift
  if "$@"; then echo "ok   - $label"; else echo "FAIL - $label"; status=1; fi
}

for f in grid:preview-grid.rst: terse:preview-terse.rst:-t rawms:preview-rawms.rst:-m hmm:preview.hmm:-H; do
  IFS=: read -r name file opt <<<"$f"
  check "$name: TestWindow saved the preview" test -s "obj/$file"
  "$calc" $opt obj/preview.yaml >"$out/calc" 2>"$out/calc.err"
  check "$name: besm2_calc_po formats the saved file" test $? -eq 0
  check "$name: the preview is besm2_calc_po's output" cmp -s "obj/$file" "$out/calc"
  if [ -x "$fmt" ]; then
    "$fmt" $opt obj/preview.yaml >"$out/fmt" 2>"$out/fmt.err"
    check "$name: the preview is pobesm2_fmt2's output" cmp -s "obj/$file" "$out/fmt"
  else
    echo "ok   - $name: pobesm2_fmt2 not built, skipped"
  fi
done

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
