#!/bin/bash
# cli.sh WINDOW CALC: the command lines of besm2_cg_po and besm2_calc_po,
# and starting the window with no display (PLAN.md, Part B, steps 0 and 6).
# Needs no display: nothing here opens a window.
set -u
prog=$1 calc=$2
status=0
out=$(mktemp -d) || exit 2
trap 'rm -rf "$out"' EXIT

check() { # check LABEL CONDITION...
  local label=$1; shift
  if "$@"; then echo "ok   - $label"; else echo "FAIL - $label"; status=1; fi
}

# run PROGRAM ARGS...: with no display, its output in $out, status in $st.
run() { env -u DISPLAY -u WAYLAND_DISPLAY -u TMUX "$@" >"$out/stdout" 2>"$out/stderr"; st=$?; }

# ---- besm2_cg_po ----

run "$prog" -h
check "besm2_cg_po -h exits 0" test $st -eq 0
check "besm2_cg_po -h prints the usage" grep -q 'besm2_cg_po \[options\]' "$out/stdout"
check "besm2_cg_po -h needs no display" test ! -s "$out/stderr"
check "besm2_cg_po -h tells of --rulebook" grep -q -- '--rulebook' "$out/stdout"
check "besm2_cg_po -h tells of --viewer" grep -q -- '--viewer' "$out/stdout"

run "$prog" --no-such-option
check "besm2_cg_po: an unknown option exits 2" test $st -eq 2


# A file is loaded before the display is needed, so its problems show
# without one.
run "$prog" no-such-file.yaml
check "besm2_cg_po: a missing file exits 1" test $st -eq 1
check "and says so, before needing a display" grep -qx "besm2_cg_po: no-such-file.yaml: error: No such file or directory" "$out/stderr"
printf -- '- name: X\n  stats:\n  - name: Body\n    value: 4\n    points: lots\n' >"$out/bad.yaml"
run "$prog" "$out/bad.yaml"
check "besm2_cg_po: a file that doesn't load exits 1" test $st -eq 1
check "and says where" grep -q "^besm2_cg_po: $out/bad.yaml:5:.*: error: .*not a valid integer" "$out/stderr"
printf -- '- name: X\n  stats:\n  - name: Body\n    value: 4\n    points: 40\n' >"$out/good.yaml"
run "$prog" "$out/good.yaml"
check "besm2_cg_po: a file that loads goes on to need a display" grep -qx 'besm2_cg_po: no display: neither DISPLAY nor WAYLAND_DISPLAY is set' "$out/stderr"
run "$prog" --campaign no-such-file.yaml
check "besm2_cg_po: a missing --campaign exits 1" test $st -eq 1
check "and says so, before needing a display" grep -qx "besm2_cg_po: no-such-file.yaml: error: No such file or directory" "$out/stderr"
run "$prog" --campaign test/data/campaign.yaml
check "besm2_cg_po: a --campaign that loads goes on to need a display" grep -qx 'besm2_cg_po: no display: neither DISPLAY nor WAYLAND_DISPLAY is set' "$out/stderr"
run "$prog" a.yaml b.yaml
check "besm2_cg_po: two files exit 2" test $st -eq 2
check "and says so" grep -qx "besm2_cg_po: one file at a time: b.yaml" "$out/stderr"
run "$prog" --viewer '%z'
check "besm2_cg_po: a --viewer without %f exits 2" test $st -eq 2
check "and says so" grep -q "^besm2_cg_po: --viewer takes .*: %z$" "$out/stderr"

run "$prog"
check "besm2_cg_po: no display exits 1" test $st -eq 1
check "no display says so" grep -qx 'besm2_cg_po: no display: neither DISPLAY nor WAYLAND_DISPLAY is set' "$out/stderr"
check "no display, outside tmux: one line" test "$(wc -l < "$out/stderr")" -eq 1
check "no display writes nothing to standard output" test ! -s "$out/stdout"

env -u DISPLAY -u WAYLAND_DISPLAY TMUX=/tmp/tmux-test/default,1,0 "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "no display in tmux exits 1" test $st -eq 1
check "no display in tmux: the tmux hint" grep -q '^besm2_cg_po: in tmux, .*tmux show-environment -g' "$out/stderr"
check "no display in tmux: two lines" test "$(wc -l < "$out/stderr")" -eq 2

env -u TMUX DISPLAY= WAYLAND_DISPLAY= "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "empty DISPLAY and WAYLAND_DISPLAY count as none" test $st -eq 1

# ---- besm2_calc_po: never needs a display ----

run "$calc" -h
check "besm2_calc_po -h exits 0" test $st -eq 0
check "besm2_calc_po -h prints the usage" grep -q 'besm2_calc_po \[options\]' "$out/stdout"
check "besm2_calc_po -h writes nothing to standard error" test ! -s "$out/stderr"

run "$calc" --no-such-option
check "besm2_calc_po: an unknown option exits 2" test $st -eq 2

run "$calc" no-such-file.yaml
check "besm2_calc_po: a missing file exits 1" test $st -eq 1
check "and says so, as pobesm2_fmt2 does" grep -qx "besm2_calc_po: no-such-file.yaml: error: No such file or directory" "$out/stderr"

run "$calc" --check --fill --upgrade no-such-file.yaml
check "besm2_calc_po: its own options are known" test $st -eq 1

# --campaign (step 10a): the campaign's creation is used, and a
# different one is a difference.
run "$calc" --campaign test/data/campaign.yaml --check test/data/window.yaml
check "besm2_calc_po --campaign --check: a different creation exits 1" test $st -eq 1
check "and says which character, and that the campaign's is used" grep -qx "test/data/window.yaml: difference: Pilot: creation differs from the campaign's, test/data/campaign.yaml, which is used" "$out/stderr"
check "and nothing about the mecha" test "$(wc -l < "$out/stderr")" -eq 1
run "$calc" --campaign test/data/campaign.yaml --fill test/data/window.yaml
check "besm2_calc_po --campaign --fill exits 0" test $st -eq 0
check "and writes the campaign's creation" grep -q '^      stat-points-ceiling: 6$' "$out/stdout"
check "with its Character Points" grep -q '^    character-points: 40$' "$out/stdout"
check "and not the file's own" sh -c '! grep -q "skill-points: 20" "$1"' sh "$out/stdout"
cp "$out/stdout" "$out/filled.yaml"
run "$calc" --campaign test/data/campaign.yaml --check "$out/filled.yaml"
check "besm2_calc_po --campaign --check: the same creation is no difference" test $st -eq 0
run "$calc" --campaign test/data/campaign-extra.yaml test/data/window.yaml
check "besm2_calc_po: a bad --campaign exits 1" test $st -eq 1
check "and says why" grep -qx 'besm2_calc_po: test/data/campaign-extra.yaml: /: "players" is not one of creation' "$out/stderr"
check "and prints nothing" test ! -s "$out/stdout"
run "$calc" --campaign test/data/mecha.yaml test/data/window.yaml
check "besm2_calc_po: a --campaign of only mecha exits 1" test $st -eq 1
check "and says so" grep -qx 'besm2_calc_po: test/data/mecha.yaml has no character to copy from, only mecha' "$out/stderr"

run "$calc" < /dev/null
check "besm2_calc_po reads standard input, here empty, and exits 0, with no display" test $st -eq 0
check "and needs no display" test ! -s "$out/stderr"

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
