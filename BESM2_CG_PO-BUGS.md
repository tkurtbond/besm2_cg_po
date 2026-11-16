# besm2_cg_po bugs

Bugs in besm2_cg_po's own code, numbered, newest last. A problem that
comes from the YAML binding goes in that binding's bugs file, and one in
libfyaml itself in the binding's `LIBFYAML-ISSUES.md`; this file records
only how it shows here, with a pointer.

When one is fixed, replace its "Status" with "Fix" and "Verified". When
one turns out not to be a bug, say so in its section rather than
deleting it.


## 1. A customizer whose counts-as isn't a scalar halts the program

**Symptom.** A customizer in `enhancements` or `limiters` whose second
item (its counts-as) is a mapping or a sequence stops the program with
`assertion failed (62)` on standard error and status 10, instead of an
error for the file. Found 2026-11-15 while porting besm2_cg_po to the
web (besm2_cg_web, PLAN.md "Findings").

**Repro** (besm2_cg_po at 2583528), `enh.yaml`, which is pobesm2_fmt2's
`test/data/shape-customizer-short.yaml` with its customizer changed:

```yaml
- name: Good
  stats: [{name: Body, value: 4, points: 8}]
- name: Short
  attributes: [{name: A, level: 1, points: 2, enhancements: [[Foo, {a: 1}]]}]
```

```sh
besm2_calc_po --check enh.yaml; echo "rc=$?"
```

`limiters: [[Foo, [1]]]` does the same. The Ada besm2_fmt reports

```
besm2_fmt: error processing enh.yaml: /1/attributes/0/enhancements/0/1: not a scalar
```

and exits with status 1.

**Cause.** `Customizer` (`src/Besm2Entities.Mod:403`) calls
`part.IntegerValue` on item 1 without checking that it is a scalar.
`Fyaml.Node.IntegerValue` asserts that (`Fyaml.AssertKind`, 62): the
binding treats a call on the wrong kind of node as a programmer error,
so this is a bug here, not in the binding. Item 0 and the applies-to
items go through `Scalar`, which reports "not a scalar".

**Fix.** `Customizer` checks `part.IsScalar()` before
`IntegerValue`, and reports `not a scalar` with the node's path, as in
pobesm2_fmt2 and obesm2_fmt2 (their bug 2). `test/cli.sh` has two new
`besm2_calc_po --check` cases: an enhancement whose counts-as is a
mapping, and a limiter whose counts-as is a sequence.

**Verified** 2026-11-16: the repro gives

```
besm2_calc_po: error processing enh.yaml: /1/attributes/0/enhancements/0/1: not a scalar
```

and status 1. `make test` passes.


## 2. A house Skill's cost that isn't a scalar halts the program

**Symptom.** A house Skill in a creation's `house-skills` whose cost for
a genre is a mapping or a sequence stops the program with `assertion
failed (62)` on standard error and status 10, instead of an error for
the file. Found 2026-11-16 while fixing bug 1, by looking for other
`IntegerValue` calls on nodes not known to be scalars.

**Repro** (besm2_cg_po at dd6fbab), `house.yaml`:

```yaml
- name: Campaign
  creation:
    genre: Cyberpunk
    house-skills:
      - {name: Mecha Piloting, costs: {Cyberpunk: [5]}}
```

```sh
besm2_calc_po --check house.yaml; echo "rc=$?"
```

**Cause.** The same as bug 1: `ReadHouseSkill`
(`src/Besm2Character.Mod:659`) calls `v.IntegerValue` on each cost
without checking that it is a scalar.

**Fix.** `ReadHouseSkill` checks the genre key first, as before, then
`v.IsScalar()` before `IntegerValue`, and reports `not a scalar` with
the node's path. `test/cli.sh` has a new `besm2_calc_po --check` case.

**Verified** 2026-11-16: the repro gives

```
besm2_calc_po: error processing house.yaml: /0/creation/house-skills/0/costs/Cyberpunk: not a scalar
```

and status 1. `make test` passes.
