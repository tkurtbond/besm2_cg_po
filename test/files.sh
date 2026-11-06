#!/bin/bash
# files.sh CALC FMT DATA: besm2_calc_po against pobesm2_fmt2 (PLAN.md,
# Part B, step 4, TestFiles), on pobesm2_fmt2's fixtures in DATA:
# - formatting a file is formatting what --fill writes of it: the
#   numbers computed, those that disagree kept as overrides;
# - a file with no differences formats byte for byte as pobesm2_fmt2
#   formats it, on both outputs, with the same status;
# - what --fill writes prints through pobesm2_fmt2 as the original
#   does, but for the `\*` that marks an override (and the lines it
#   wraps);
# A file's numbers agree when --check finds no difference and keeps no
# number it couldn't compute (a Skill without a genre, a name not in
# the rulebook) as an override.
# - --upgrade of composite-2e.yaml is composite-ext.yaml, filled, with
#   BESM2ER's names; and prints as composite-2e.yaml does but for the
#   weapons and the renamed lines;
# - --check's differences and status, --fill and --upgrade with -o, and
#   standard input.
# Needs no display.
set -u
calc=$(realpath "$1") fmt=$(realpath "$2") data=$3
status=0
out=$(mktemp -d) || exit 2
trap 'rm -rf "$out"' EXIT
cd "$data" || exit 2

check() { # check LABEL CONDITION...
  local label=$1; shift
  if "$@"; then echo "ok   - $label"; else echo "FAIL - $label"; status=1; fi
}
quiet=0 # failures of `same` print only once per kind
same() { # same LABEL FILE1 FILE2
  if cmp -s "$2" "$3"; then return 0; fi
  echo "FAIL - $1"; status=1
  if [ $quiet -lt 3 ]; then diff "$2" "$3" | head -10; quiet=$((quiet + 1)); fi
  return 1
}
# Without the `\*` of an override, the spaces, the lines and the
# tables' rules, which it can move.
unmark() { sed 's/\\\*//g' "$1" | tr -d ' |\n=+-'; }

formats=("" -m -H "-H -S" -1 -b -l)
n=0 nfill=0 nsame=0 nround=0
for f in *.yaml; do
  n=$((n + 1))
  "$calc" --check "$f" >"$out/check.out" 2>"$out/check.err"; cst=$?
  check "$f: --check writes nothing to standard output" test ! -s "$out/check.out"
  diffs=$(grep -c ': difference: \|kept as an override\|kept as overrides' "$out/check.err")
  if grep -q ': \(difference\|error\): \|^besm2_calc_po: ' "$out/check.err"; then
    check "$f: --check exits 1 on a difference or an error" test $cst -eq 1
  else
    check "$f: --check exits 0 when there is no difference or error" test $cst -eq 0
  fi
  "$calc" --fill "$f" >"$out/fill.yaml" 2>/dev/null; fst=$?
  [ $fst -eq 0 ] && nfill=$((nfill + 1))
  for o in "${formats[@]}"; do
    # shellcheck disable=SC2086
    "$calc" $o "$f" >"$out/calc.out" 2>"$out/calc.err"; st=$?
    if [ $fst -eq 0 ]; then
      # shellcheck disable=SC2086
      "$fmt" $o "$out/fill.yaml" >"$out/fill.out" 2>/dev/null
      same "$f ($o): formats as its --fill" "$out/calc.out" "$out/fill.out" && nround=$((nround + 1))
      # shellcheck disable=SC2086
      "$fmt" $o "$f" >"$out/fmt.out" 2>/dev/null
      unmark "$out/fill.out" >"$out/fill.um"; unmark "$out/fmt.out" >"$out/fmt.um"
      same "$f ($o): its --fill prints as it does, but for the overrides' marks" "$out/fill.um" "$out/fmt.um"
    fi
    if [ "$diffs" -eq 0 ]; then
      # shellcheck disable=SC2086
      "$fmt" $o "$f" >"$out/fmt.out" 2>"$out/fmt.err"; fst2=$?
      sed 's/^besm2_calc_po:/besm2_fmt:/' "$out/calc.err" >"$out/calc.err2"
      same "$f ($o): byte for byte pobesm2_fmt2's" "$out/calc.out" "$out/fmt.out" &&
        same "$f ($o): pobesm2_fmt2's errors" "$out/calc.err2" "$out/fmt.err" &&
        check "$f ($o): pobesm2_fmt2's status" test $st -eq $fst2 && nsame=$((nsame + 1))
    fi
  done
done
echo "#    $n fixtures, $nfill filled, $nround formats as filled, $nsame formats byte for byte"
check "every fixture was tried" test $n -ge 30

# ---- --check ----
"$calc" --check FV2021-Coleopteran-2e.yaml 2>"$out/err"; st=$?
check "--check: the Coleopteran's Heavy Armour" grep -qx \
  "FV2021-Coleopteran-2e.yaml: difference: FV2021 Coleopteran: Heavy Armour (p. 40, PDF 42): points is 7 in the file, 8 by the rules: kept as an override" "$out/err"
check "--check: and exits 1" test $st -eq 1
"$calc" --check enyon-boase-ext.yaml 2>"$out/err"; st=$?
check "--check: a file with only warnings exits 0" test $st -eq 0
check "--check: the warnings show both pages" grep -q '(p. 59, PDF 61)' "$out/err"
printf -- '- name: Big\n  stats:\n  - name: Body\n    value: 4\n    points: 5000\n' >"$out/big.yaml"
"$calc" --check "$out/big.yaml" 2>"$out/err"; st=$?
check "--check: a number outside -999..999 is an error" grep -q ': error: Big: stats/Body: points 5000 is outside -999\.\.999$' "$out/err"
check "--check: and exits 1" test $st -eq 1
"$calc" --check < FV2021-Coleopteran-2e.yaml 2>"$out/err"
check "--check: standard input is (stdin)" grep -q '^(stdin): difference: ' "$out/err"

# ---- --fill ----
"$calc" --fill -o "$out/o.yaml" FV2021-Coleopteran-2e.yaml >"$out/stdout" 2>"$out/err"; st=$?
check "--fill -o: exits 0" test $st -eq 0
check "--fill -o: nothing on standard output" test ! -s "$out/stdout"
"$calc" --fill FV2021-Coleopteran-2e.yaml >"$out/stdout.yaml" 2>/dev/null
same "--fill -o writes what --fill prints" "$out/o.yaml" "$out/stdout.yaml"
check "--fill: a disagreeing number is an override" grep -q '^    - points$' "$out/o.yaml"
check "--fill: and its notice is on standard error" grep -q ': difference: .*kept as an override$' "$out/err"
"$calc" --fill "$out/o.yaml" >"$out/again.yaml" 2>"$out/err"
same "--fill of --fill's output is the same" "$out/o.yaml" "$out/again.yaml"
check "--fill: an override listed is no difference" bash -c '! grep -q ": difference: " "$1"' - "$out/err"
"$calc" --fill < FV2021-Coleopteran-2e.yaml >"$out/stdin.yaml" 2>/dev/null
same "--fill reads standard input" "$out/stdin.yaml" "$out/stdout.yaml"
"$calc" --fill bad-int.yaml >"$out/stdout" 2>"$out/err"; st=$?
check "--fill: a file with a problem exits 1" test $st -eq 1
check "--fill: and isn't written" test ! -s "$out/stdout"
check "--fill: and says so" grep -qx 'besm2_calc_po: bad-int.yaml: not written, since an entity didn'"'"'t load' "$out/err"
"$calc" --fill a.yaml b.yaml >/dev/null 2>"$out/err"; st=$?
check "--fill takes one file: exits 2" test $st -eq 2
check "--fill takes one file: says so" grep -qx 'besm2_calc_po: --fill and --upgrade take one file' "$out/err"

# ---- --upgrade ----
"$calc" --upgrade composite-2e.yaml >"$out/up.yaml" 2>"$out/err"; st=$?
check "--upgrade composite-2e.yaml exits 0" test $st -eq 0
# composite-ext.yaml has a creation block, which --upgrade can't make up:
# add it to the original first.  Its names are as written.
sed '0,/^- name: Lieutenant Enyon Boase$/s//&\n  creation:\n    character-points: 35\n    genre: Modern Military/' \
  composite-2e.yaml >"$out/c2e.yaml"
"$calc" --upgrade "$out/c2e.yaml" >"$out/up2.yaml" 2>/dev/null
"$calc" --fill composite-ext.yaml 2>/dev/null |
  sed 's/^\(  - name: \)Weapon$/\1Weapon Attack/; s/^\(  - name: \)Super-Strength$/\1Super Strength/;
       s/^\(  - name: \)Hanger Queen$/\1Hangar Queen/; s/^\(  - name: \)Unique Defect$/\1Unique Character Defect/' \
  >"$out/ext.yaml"
same "--upgrade composite-2e.yaml is composite-ext.yaml with BESM2ER's names" "$out/up2.yaml" "$out/ext.yaml"
"$fmt" composite-2e.yaml | sed 's/\\\*/  /g' >"$out/a"
"$fmt" "$out/up.yaml" | sed 's/\\\*/  /g' >"$out/b"
# The lines that differ: of the weapons and the renamed items only.
diff "$out/a" "$out/b" | grep '^<' | grep -v 'Weapon\|Unique Defect\|Super-Strength\|Hanger Queen\|^< |          |          |' >"$out/other"
check "--upgrade prints as before but for the weapons and the names" test ! -s "$out/other"
"$calc" --upgrade "$out/up.yaml" >"$out/up3.yaml" 2>/dev/null
same "--upgrade of --upgrade's output is the same" "$out/up.yaml" "$out/up3.yaml"
printf -- '- name: W\n  attributes:\n  - name: Weapon Attack\n    subject: Odd\n    level: 1\n    points: 4\n    details: Damage 15, Frobnicate\n' >"$out/odd.yaml"
"$calc" --upgrade "$out/odd.yaml" >"$out/odd-up.yaml" 2>"$out/err"
check "--upgrade: a part it can't read leaves the details" grep -q '^    details: "Damage 15, Frobnicate"$' "$out/odd-up.yaml"
check "--upgrade: and says which" grep -q 'details not upgraded: "Frobnicate" is neither a damage nor a Weapon Ability (p. 83, PDF 85) or Disability (p. 89, PDF 91)$' "$out/err"

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
