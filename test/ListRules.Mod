MODULE ListRules; (* Besm2Rules' tables, one item a line, for the checks *)

(* Prints, for every item of Besm2Rules, a line of tab-separated fields:
     KIND PAGE PDF NAME COST MAX MINCOST FLAGS SLOTS ALTSLOTS MAXTIMES SKILLCOSTS
   KIND is stat, attribute, mecha-attribute, defect, mecha-defect,
   skill, ability or disability; MAX and MAXTIMES are "unlimited" for
   Unlimited; FLAGS the flags' names, comma-separated; SKILLCOSTS a
   Skill's eight costs in Table 2-4's order, comma-separated.  Then a
   line "alias<TAB>ALIAS<TAB>NAME" for each alias, and
   "exclude<TAB>NAME<TAB>NAME" for each pair of Weapon Abilities and
   Disabilities that don't go together, and "section<TAB>PAGE<TAB>HEADING"
   for each of the rules' pages (StatsPage, ...) with the heading it
   is checked against.
   tools/check-rules.py compares it with rules/*.tsv (make test), and
   tools/check-pages.py with the PDF's headings (make check-pages). *)

IMPORT Out, R := Besm2Rules;

VAR k, i, j, g: INTEGER; it, other: R.Item; alias: R.Name;

PROCEDURE Tab;
BEGIN Out.Char(9X)
END Tab;

PROCEDURE Num(n: INTEGER);
BEGIN
  IF n = R.Unlimited THEN Out.String("unlimited") ELSE Out.Int(n, 0) END
END Num;

PROCEDURE Kind(k: INTEGER);
BEGIN
  CASE k OF
    R.Stat: Out.String("stat")
  | R.Attribute: Out.String("attribute")
  | R.MechaAttribute: Out.String("mecha-attribute")
  | R.Defect: Out.String("defect")
  | R.MechaDefect: Out.String("mecha-defect")
  | R.Skill: Out.String("skill")
  | R.Ability: Out.String("ability")
  | R.Disability: Out.String("disability")
  END
END Kind;

PROCEDURE Section(page: INTEGER; heading: ARRAY OF CHAR);
BEGIN
  Out.String("section"); Tab; Out.Int(page, 0); Tab; Out.String(heading); Out.Ln
END Section;

PROCEDURE Flags(f: SET);
  VAR first: BOOLEAN;
  PROCEDURE F(flag: INTEGER; name: ARRAY OF CHAR);
  BEGIN
    IF flag IN f THEN
      IF ~first THEN Out.Char(",") END;
      Out.String(name); first := FALSE
    END
  END F;
BEGIN
  first := TRUE;
  F(R.Subject, "subject"); F(R.MechaOnly, "mecha-only"); F(R.GmCost, "gm-cost");
  F(R.Special, "special"); F(R.NeedsDetail, "needs-detail"); F(R.NotPersonalGear, "not-personal-gear")
END Flags;

BEGIN
  FOR k := 0 TO R.NKinds - 1 DO
    FOR i := 0 TO R.Count(k) - 1 DO
      it := R.Get(k, i);
      Kind(it.kind); Tab; Out.Int(it.page, 0); Tab; Out.Int(R.PdfPage(it), 0); Tab;
      Out.String(it.name); Tab; Num(it.cost); Tab; Num(it.maxLevel); Tab; Num(it.minCost); Tab;
      Flags(it.flags); Tab; Num(it.slots); Tab; Num(it.altSlots); Tab; Num(it.maxTimes); Tab;
      IF it.kind = R.Skill THEN
        FOR g := 0 TO R.NGenres - 1 DO
          IF g > 0 THEN Out.Char(",") END; Out.Int(it.skillCost[g], 0)
        END
      END;
      Out.Ln
    END
  END;
  FOR i := 0 TO R.AliasCount() - 1 DO
    R.GetAlias(i, alias, it);
    Out.String("alias"); Tab; Out.String(alias); Tab; Out.String(it.name); Out.Ln
  END;
  FOR k := R.Ability TO R.Disability DO
    FOR i := 0 TO R.Count(k) - 1 DO
      it := R.Get(k, i);
      FOR g := k TO R.Disability DO
        FOR j := 0 TO R.Count(g) - 1 DO
          other := R.Get(g, j);
          IF ((g > k) OR (j > i)) & R.Excludes(it, other) THEN
            Out.String("exclude"); Tab; Out.String(it.name); Tab; Out.String(other.name); Out.Ln
          END
        END
      END
    END
  END;
  Section(R.StatsPage, "Step 3: Assign Stats");
  Section(R.AttributesPage, "Step 4: Character Attributes");
  Section(R.AlternateAttacksPage, "Alternate Attacks");
  Section(R.WeaponAbilitiesPage, "Weapon Attack Abilities");
  Section(R.WeaponDisabilitiesPage, "Attack Disabilities");
  Section(R.MechaAttributesPage, "Mecha-Only Attributes");
  Section(R.DefectsPage, "Step 5: Character Defects");
  Section(R.MechaDefectsPage, "Mecha-Only Defects");
  Section(R.SkillsPage, "Step 6: Skill System");
  Section(R.SkillsPage, "Skill Point Costs");
  Section(R.DerivedValuesPage, "Step 7: Derived Values");
  Section(R.ShockValuePage, "Shock Value (Optional)");
  Section(R.BackgroundPointsPage, "Step 8: Background Points");
  Section(R.StagedStatCostPage, "Staged Stat Cost — Optional Rule")
END ListRules.
