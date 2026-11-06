MODULE TestCalc; (* Besm2Calc: the fixtures by hand, and a case for each rule *)

(* PLAN.md, Part B step 2.  The oracle is the characters and mecha
   whose numbers follow the rules (PLAN.md, A2 results, 3): besm2_fmt's
   fixtures Lieutenant Enyon Boase and the FV2021 Coleopteran, and the
   Red Planet Blue Helmets campaign's Cador Trewartha and WT-34
   Bogatyr, each built here by hand from its file, and every number the
   file holds compared with Besm2Calc's.  (Step 4's TestFiles loads the
   files themselves.)  Auto-Fire is 3 slots and Melee 2, as the book
   says, and the campaign's weapons were corrected to them (open
   questions 12, 13 and 14); so is the KA-99 Archangel's pair.

   Then a hand-made case for each rule: Stats, the Staged Stat Cost,
   each derived value and what changes it, options, least costs, each
   Weapon Ability and Disability (its damage, Personal Gear, Mecha
   Only, and which others it excludes), primary and secondary attacks,
   Different Gunners, Skill Points and Skills, Mecha Points, each
   limit and warning, and overrides counting downstream.  Needs no
   display. *)

IMPORT Check, C := Besm2Calc, R := Besm2Rules, Out, Strings;

VAR
  label: ARRAY 256 OF CHAR;
  sample: ARRAY 48 OF CHAR;  (* what is being checked, for labels *)
  e: C.Entity; a: C.Attr; d: C.Defect; s: C.Skill; m: C.Mod; h: C.HouseSkill;

(* ---- Labels and checks ---- *)

PROCEDURE AppendInt(n: INTEGER; VAR s: ARRAY OF CHAR);
  VAR t: ARRAY 12 OF CHAR; i, j: INTEGER; c: CHAR;
BEGIN
  IF n < 0 THEN Strings.Append("-", s); n := -n END;
  i := 0; REPEAT t[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  t[i] := 0X; j := 0; DEC(i);
  WHILE j < i DO c := t[j]; t[j] := t[i]; t[i] := c; INC(j); DEC(i) END;
  Strings.Append(t, s)
END AppendInt;

PROCEDURE L(what: ARRAY OF CHAR);
BEGIN COPY(sample, label); Strings.Append(": ", label); Strings.Append(what, label)
END L;

(* Checks got = want, the label saying both. *)
PROCEDURE Is(got, want: INTEGER; what: ARRAY OF CHAR);
BEGIN
  L(what); Strings.Append(" ", label); AppendInt(want, label);
  IF got # want THEN Strings.Append(" (got ", label); AppendInt(got, label); Strings.Append(")", label) END;
  Check.Check(got = want, label)
END Is;

PROCEDURE Yes(ok: BOOLEAN; what: ARRAY OF CHAR);
BEGIN L(what); Check.Check(ok, label)
END Yes;

(* Whether e has a warning code about a (or about anything if a is NIL),
   as want says. *)
PROCEDURE Warns(code: INTEGER; about: C.Attr; want: BOOLEAN; what: ARRAY OF CHAR);
BEGIN
  L(what);
  IF want THEN Strings.Append(": warned", label) ELSE Strings.Append(": not warned", label) END;
  Check.Check(C.HasWarning(e, code, about) = want, label)
END Warns;

(* e has no warnings; else they are listed. *)
PROCEDURE NoWarnings;
  VAR w: C.Warning;
BEGIN
  L("no warnings");
  IF e.warnings # NIL THEN
    Strings.Append(" (got", label); w := e.warnings;
    WHILE w # NIL DO
      Strings.Append(" ", label); AppendInt(w.code, label);
      IF w.attr # NIL THEN Strings.Append("@L", label); AppendInt(w.attr.level, label) END;
      w := w.next
    END;
    Strings.Append(")", label)
  END;
  Check.Check(e.warnings = NIL, label)
END NoWarnings;

(* ---- Building ---- *)

PROCEDURE Need(kind: INTEGER; name: ARRAY OF CHAR): R.Item;
  VAR it: R.Item;
BEGIN
  IF kind < 0 THEN it := R.Find(name) ELSE it := R.FindKind(kind, name) END;
  IF it = NIL THEN Out.String("no such item: "); Out.String(name); Out.Ln END;
  ASSERT(it # NIL);
  RETURN it
END Need;

PROCEDURE New(isMecha: BOOLEAN): C.Entity;
BEGIN NEW(e); C.InitEntity(e, isMecha); RETURN e
END New;

PROCEDURE Stats(body, mind, soul: INTEGER);
BEGIN e.stat[C.Body] := body; e.stat[C.Mind] := mind; e.stat[C.Soul] := soul
END Stats;

(* A new Attribute of e. *)
PROCEDURE At(name: ARRAY OF CHAR; level: INTEGER): C.Attr;
  VAR x: C.Attr;
BEGIN NEW(x); C.InitAttr(x, Need(-1, name), level); C.AddAttr(e, x); RETURN x
END At;

PROCEDURE Unknown(level: INTEGER): C.Attr;
  VAR x: C.Attr;
BEGIN NEW(x); C.InitAttr(x, NIL, level); C.AddAttr(e, x); RETURN x
END Unknown;

(* A new Weapon Attack of e; a is it, for Ab and Di. *)
PROCEDURE Wp(level: INTEGER): C.Attr;
BEGIN a := At("Weapon Attack", level); RETURN a
END Wp;

(* A Weapon Ability (or Disability) of a, counting as countsAs (0: the book's). *)
PROCEDURE ModOf(it: R.Item; countsAs: INTEGER);
BEGIN
  NEW(m); C.InitMod(m, it, countsAs);
  IF (it # NIL) & (it.kind = R.Disability) THEN C.AddMod(a.disabilities, m) ELSE C.AddMod(a.abilities, m) END
END ModOf;

PROCEDURE Ab(name: ARRAY OF CHAR; countsAs: INTEGER);
BEGIN ModOf(Need(R.Ability, name), countsAs)
END Ab;

PROCEDURE Di(name: ARRAY OF CHAR; countsAs: INTEGER);
BEGIN ModOf(Need(R.Disability, name), countsAs)
END Di;

PROCEDURE Df(name: ARRAY OF CHAR; rank: INTEGER): C.Defect;
BEGIN NEW(d); C.InitDefect(d, Need(-1, name), rank); C.AddDefect(e, d); RETURN d
END Df;

PROCEDURE Sk(name: ARRAY OF CHAR; level, specs: INTEGER): C.Skill;
BEGIN NEW(s); C.InitSkill(s, Need(R.Skill, name), NIL, level, specs); C.AddSkill(e, s); RETURN s
END Sk;

(* A house Skill of e's creation at cost in Modern Military, and a Skill of it. *)
PROCEDURE HouseSk(cost, level: INTEGER): C.Skill;
BEGIN
  NEW(h); C.InitHouseSkill(h); h.cost[R.ModernMilitary] := cost; C.AddHouseSkill(e.creation, h);
  NEW(s); C.InitSkill(s, NIL, h, level, 1); C.AddSkill(e, s); RETURN s
END HouseSk;

(* ---- The fixtures and the campaign ---- *)

PROCEDURE Coleopteran(): C.Entity;
  VAR mecha: C.Entity;
BEGIN
  mecha := New(TRUE);
  a := At("Heavy Armour", 2); C.SetOption(a, "partial, thin area", 1);
  a := At("Super-Strength", 1);
  a := At("Toughness", 2);
  a := At("Ground Speed", 1);
  a := At("Manoeuvre Bonus", 4);
  a := At("Accessories", 2);
  a := At("Life Support", 2);
  a := At("Sensors", 1);
  a := Wp(3); Ab("Long Range", 0); Di("Unreliable", 0);                 (* Railgun *)
  a := Wp(2); Di("Melee", 0); Di("Limited Shots", 0);                    (* Plasma Fist *)
  a := Wp(2); Ab("Auto-Fire", 0); Ab("Area Effect", 0);                  (* Rocket Pod *)
  Di("Limited Shots", 2); Di("Stoppable", 0);
  d := Df("Awkward Size", 2);
  d := Df("Hanger Queen", 1);
  RETURN mecha
END Coleopteran;

PROCEDURE CheckColeopteran(mecha: C.Entity; owner: ARRAY OF CHAR);
  VAR want: ARRAY 11 OF INTEGER; i: INTEGER; p: C.Attr;
BEGIN
  e := mecha; COPY(owner, sample); Strings.Append("'s FV2021 Coleopteran", sample);
  want[0] := 7; want[1] := 3; want[2] := 8; want[3] := 2; want[4] := 4; want[5] := 2;
  want[6] := 2; want[7] := 1; want[8] := 12; want[9] := 1; want[10] := 1;
  i := 0; p := e.attrs;
  WHILE p # NIL DO
    COPY("attribute ", label); AppendInt(i + 1, label); Strings.Append(" points", label);
    Is(C.Value(p.points), want[i], label); INC(i); p := p.next
  END;
  p := e.attrs; FOR i := 1 TO 8 DO p := p.next END;
  Is(C.Value(p.damage), 45, "Railgun damage"); Yes(p.isPrimary, "Railgun is the primary");
  Is(C.Value(p.next.damage), 75, "Plasma Fist damage");
  Is(C.Value(p.next.next.damage), 15, "Rocket Pod damage");
  Is(C.Value(e.defects.points), -2, "Awkward Size 2");
  Is(C.Value(e.defects.next.points), -1, "Hangar Queen 1");
  Is(e.attrTotal, 43, "attributes"); Is(e.bonusPoints, 3, "Mecha Bonus Points");
  Is(e.spent, 40, "Mecha Points spent"); Is(e.available, 40, "Mecha Points");
  Is(C.Value(e.ar), 20, "AR"); Yes(e.hasAR, "has AR"); Is(C.Value(e.hp), 80, "HP");
  NoWarnings
END CheckColeopteran;

PROCEDURE Enyon;
  VAR pc, mecha: C.Entity; obm: C.Attr;
BEGIN
  sample := "Enyon Boase";
  mecha := Coleopteran();
  pc := New(FALSE); Stats(8, 6, 6);
  e.creation.characterPoints := 35; e.creation.genre := R.ModernMilitary;
  a := At("Combat Mastery", 3);
  a := At("Extra Attacks", 1);
  obm := At("Own a Big Mecha", 2); obm.mecha := mecha;
  d := Df("Conditional Ownership", 2);
  d := Df("Unique Defect", 1);
  s := Sk("Interrogation", 1, 0);
  s := Sk("Law", 1, 1);
  s := Sk("Military Sciences", 1, 1);
  s := HouseSk(3, 1);  (* Persuasion, the campaign's house rule *)
  s := Sk("Social Sciences", 1, 1);
  s := Sk("Stealth", 1, 0);
  s := Sk("Visual Arts", 1, 0);
  s := Sk("Writing", 1, 1);
  C.Compute(pc);
  e := pc;
  Is(C.Value(e.statPoints[C.Body]), 8, "Body points"); Is(e.statTotal, 20, "Stats");
  Is(C.Value(e.acv), 9, "ACV"); Is(C.Value(e.dcv), 7, "DCV"); Is(C.Value(e.hp), 70, "HP");
  Is(C.Value(e.ep), 60, "EP"); Is(C.Value(e.sv), 14, "SV"); Yes(~e.hasAR, "has no AR");
  Is(C.Value(e.attrs.points), 6, "Combat Mastery 3"); Is(C.Value(e.attrs.next.points), 4, "Extra Attacks 1");
  Is(C.Value(obm.points), 8, "Own a Big Mecha 2"); Is(e.attrTotal, 18, "attributes");
  Is(C.Value(e.defects.points), -2, "Conditional Ownership 2");
  Is(C.Value(e.defects.next.points), -1, "Unique Character Defect 1");
  Is(e.bonusPoints, 3, "Bonus Points"); Is(e.spent, 35, "Character Points spent");
  Is(e.available, 35, "Character Points");
  s := e.skills;
  Is(C.Value(s.points), 3, "Interrogation 1"); s := s.next;
  Is(C.Value(s.points), 1, "Law 1"); s := s.next;
  Is(C.Value(s.points), 5, "Military Sciences 1"); s := s.next;
  Is(C.Value(s.points), 3, "Persuasion 1 (house rule)"); s := s.next;
  Is(C.Value(s.points), 2, "Social Sciences 1"); s := s.next;
  Is(C.Value(s.points), 4, "Stealth 1 (the Skill)"); s := s.next;
  Is(C.Value(s.points), 1, "Visual Arts 1"); s := s.next;
  Is(C.Value(s.points), 1, "Writing 1");
  Is(e.skillPoints, 20, "Skill Points"); Is(e.skillSpent, 20, "Skill Points spent");
  NoWarnings;
  Yes(mecha.owner = pc, "owns the Coleopteran");
  CheckColeopteran(mecha, "Enyon Boase")
END Enyon;

PROCEDURE Cador;
  VAR pc, mecha: C.Entity; obm: C.Attr;
BEGIN
  sample := "Cador Trewartha";
  mecha := Coleopteran();
  pc := New(FALSE); Stats(6, 6, 6);
  e.creation.characterPoints := 35; e.creation.genre := R.ModernMilitary;
  a := At("Art of Distraction", 1);
  a := At("Combat Mastery", 3);
  a := At("Extra Attacks", 1);
  obm := At("Own a Big Mecha", 2); obm.mecha := mecha;
  d := Df("Conditional Ownership", 2);
  s := Sk("Gun Combat", 2, 1);
  s := Sk("Heavy Weapons", 2, 1);
  C.Compute(pc); e := pc;
  Is(e.statTotal, 18, "Stats");
  Is(C.Value(e.acv), 9, "ACV"); Is(C.Value(e.dcv), 7, "DCV"); Is(C.Value(e.hp), 60, "HP");
  Is(C.Value(e.ep), 60, "EP"); Is(C.Value(e.sv), 12, "SV");
  Is(C.Value(e.attrs.points), 1, "Art of Distraction 1");
  Is(e.attrTotal, 19, "attributes"); Is(e.bonusPoints, 2, "Bonus Points");
  Is(e.spent, 35, "Character Points spent");
  Is(C.Value(e.skills.points), 10, "Gun Combat 2"); Is(C.Value(e.skills.next.points), 10, "Heavy Weapons 2");
  Is(e.skillSpent, 20, "Skill Points spent");
  NoWarnings;
  CheckColeopteran(mecha, "Cador Trewartha")
END Cador;

PROCEDURE Bogatyr;
  VAR pc, mecha: C.Entity; obm, rifle, sword, gatling: C.Attr; i: INTEGER;
BEGIN
  sample := "WT-34 Bogatyr";
  mecha := New(TRUE);
  a := At("Heavy Armour", 3); C.SetOption(a, "partial, thin area", 1);
  a := At("Super Strength", 3);
  a := At("Toughness", 3);
  a := At("Ground Speed", 2);
  a := At("Manoeuvre Bonus", 2);
  a := At("Manoeuvre Bonus", 2);
  a := At("Space Flight", 1);
  a := At("Features or Accessories", 2);
  a := At("Life Support", 2);
  a := At("Sensors", 2);
  rifle := Wp(3); Ab("Long Range", 0); Di("Unreliable", 0);
  sword := Wp(3); Di("Melee", 0);
  gatling := Wp(3); Ab("Accurate", 0); Ab("Auto-Fire", 0); Di("Limited Shots", 0); Di("Unreliable", 0);
  d := Df("Awkward Size", 3);
  d := Df("Volatile", 1);
  (* Its owner, as Arkady Varenkov's Own a Big Mecha 3 *)
  pc := New(FALSE); Stats(4, 4, 4);
  obm := At("Own a Big Mecha", 3); obm.mecha := mecha;
  C.Compute(pc);
  Is(C.Value(obm.points), 12, "its owner's Own a Big Mecha 3");
  e := mecha;
  a := e.attrs;
  Is(C.Value(a.points), 11, "Heavy Armour 3, partial thin"); a := a.next;
  Is(C.Value(a.points), 9, "Super Strength 3"); a := a.next;
  Is(C.Value(a.points), 12, "Toughness 3"); a := a.next;
  Is(C.Value(a.points), 4, "Ground Speed 2"); a := a.next;
  Is(C.Value(a.points), 2, "Manoeuvre Bonus 2"); a := a.next; a := a.next;
  Is(C.Value(a.points), 2, "Space Flight 1"); a := a.next;
  FOR i := 1 TO 3 DO Is(C.Value(a.points), 2, "Accessories, Life Support, Sensors 2"); a := a.next END;
  Is(C.Value(rifle.points), 12, "Particle Beam Rifle 3"); Is(C.Value(rifle.damage), 45, "Particle Beam Rifle damage");
  Is(C.Value(sword.points), 2, "Plasma Sword 3"); Is(C.Value(sword.damage), 75, "Plasma Sword damage");
  Is(C.Value(gatling.points), 2, "Gatling Gun 3");
  Is(C.Value(gatling.damage), 15, "Gatling Gun damage");
  Is(e.attrTotal, 64, "attributes"); Is(e.bonusPoints, 4, "Mecha Bonus Points");
  Is(e.spent, 60, "Mecha Points spent"); Is(e.available, 60, "Mecha Points");
  Is(C.Value(e.ar), 30, "AR"); Is(C.Value(e.hp), 100, "HP");
  NoWarnings
END Bogatyr;

(* ---- Stats and derived values ---- *)

PROCEDURE StatsAndDerived;
  VAR b: C.Attr; w: C.Warning;
BEGIN
  sample := "Stats";
  e := New(FALSE); Stats(8, 1, 12); e.creation.stagedStatCost := TRUE; C.Compute(e);
  Is(C.Value(e.statPoints[C.Body]), 11, "Staged Stat Cost of 8"); Is(C.Value(e.statPoints[C.Soul]), 24, "of 12");
  Is(e.statTotal, 36, "Staged total"); NoWarnings;
  e := New(FALSE); Stats(12, 12, 0); C.Compute(e);
  Warns(C.TwoAtTwelve, NIL, TRUE, "two at 12"); Warns(C.StatRange, NIL, TRUE, "a Stat of 0");
  w := e.warnings; WHILE (w # NIL) & (w.code # C.StatRange) DO w := w.next END;
  Is(w.stat, C.Soul, "the Stat out of range");
  e := New(FALSE); Stats(13, 4, 4); C.Compute(e); Warns(C.StatRange, NIL, TRUE, "a Stat of 13");
  e := New(FALSE); Stats(9, 4, 4); e.creation.statCeiling := 8; C.Compute(e);
  Warns(C.StatRange, NIL, TRUE, "9 above a stat-ceiling of 8");
  e.creation.statCeiling := 9; C.Compute(e); NoWarnings;

  sample := "Derived values";
  e := New(FALSE); Stats(6, 6, 6); a := At("Combat Mastery", 2); C.Compute(e);
  Is(C.Value(e.acv), 8, "ACV 6 + Combat Mastery 2"); Is(C.Value(e.dcv), 6, "DCV");
  d := Df("Inept Combat", 2); C.Compute(e);
  Is(C.Value(e.acv), 6, "and Inept Combat 2"); Is(C.Value(e.dcv), 4, "its DCV");
  e := New(FALSE); Stats(2, 1, 1); d := Df("Inept Combat", 2); C.Compute(e);
  Is(C.Value(e.acv), 1, "Inept Combat doesn't lower ACV below 1");
  e := New(FALSE); Stats(1, 1, 1); a := At("Combat Mastery", 1); d := Df("Inept Combat", 2); C.Compute(e);
  Is(C.Value(e.acv), 1, "nor Combat Mastery's 2 below 1");
  e := New(FALSE); Stats(6, 4, 6); b := At("Damn Healthy!", 2); C.Compute(e);
  Is(C.Value(e.hp), 80, "HP 60 + Damn Healthy! 2"); Is(C.Value(e.sv), 16, "SV");
  d := Df("Not So Tough", 1); C.Compute(e); Is(C.Value(e.hp), 70, "and Not So Tough 1");
  d := Df("Diminutive", 1); C.Compute(e); Is(C.Value(e.hp), 14, "and Diminutive 1: / 5");
  Is(C.Value(e.sv), 3, "SV 14 / 5 rounded up");
  d.rank := 2; C.Compute(e); Is(C.Value(e.hp), 3, "Diminutive 2: 70 / 20, rounded down");
  Is(C.Value(d.points), -6, "Diminutive 2 gives 6 BP");
  Is(C.Value(e.sv), 1, "SV 3 / 5 rounded up");
  e := New(FALSE); Stats(4, 5, 3); a := At("Energy Bonus", 3); C.Compute(e);
  Is(C.Value(e.ep), 70, "EP 40 + Energy Bonus 3");
  a := At("Place of Power", 2); C.Compute(e); Is(C.Value(e.ep), 70, "Place of Power's EP are its own");
  e := New(FALSE); Stats(4, 4, 4);
  a := At("Heavy Armour", 2); C.SetOption(a, "hidden", 1);
  b := At("Light Armour", 3); C.Compute(e);
  Is(C.Value(e.ar), 15, "AR: Heavy Armour 2 hidden 8 + Light Armour 3 7"); Yes(e.hasAR, "has AR");
  C.SetOption(a, "hidden", 0); C.SetOption(b, "hidden", 1); C.Compute(e);
  Is(C.Value(e.ar), 23, "AR: Heavy Armour 2 20 + Light Armour 3 hidden 3");
  b.level := 6; C.SetOption(b, "hidden", 0); C.Compute(e); Is(C.Value(e.ar), 35, "Light Armour 6 15");
  b.level := 1; C.Compute(e); Is(C.Value(e.ar), 22, "Light Armour 1 2");
  e := New(TRUE); C.Compute(e); Is(C.Value(e.hp), 40, "a mecha's 40 HP"); Is(C.Value(e.sv), 8, "its SV")
END StatsAndDerived;

(* ---- Attributes ---- *)

PROCEDURE Attributes;
  VAR b: C.Attr; mecha: C.Entity;
BEGIN
  sample := "Attributes";
  e := New(FALSE); Stats(4, 4, 4);
  a := At("Super Strength", 2); C.Compute(e); Is(C.Value(a.points), 6, "Super Strength 2, whole body by default");
  C.SetOption(a, "one limb", 1); C.Compute(e); Is(C.Value(a.points), 4, "one limb");
  NoWarnings;
  C.SetOption(a, "whole body", 1); C.Compute(e); Warns(C.OptionClash, a, TRUE, "both");

  e := New(FALSE); Stats(4, 4, 4);
  a := At("Heavy Armour", 1); C.SetOption(a, "partial, unarmoured area", 1); C.Compute(e);
  Is(C.Value(a.points), 2, "Heavy Armour 1, partial unarmoured");
  a := At("Light Armour", 1); C.SetOption(a, "partial, unprotected area", 1); C.Compute(e);
  Is(C.Value(a.points), 1, "Light Armour 1, partial unprotected: at least 1");
  NoWarnings;
  C.SetOption(a, "partial, thin area", 1); C.Compute(e); Warns(C.OptionClash, a, TRUE, "both partial options");
  C.SetOption(a, "partial, thin area", 0); C.SetOption(a, "partial, unprotected area", 2); C.Compute(e);
  Warns(C.TooOften, a, TRUE, "a partial option twice");

  e := New(FALSE); Stats(4, 4, 4);
  mecha := New(TRUE); e := mecha;
  a := At("Toughness", 1);
  e := New(FALSE); Stats(4, 4, 4);
  a := At("Own a Big Mecha", 1); a.mecha := mecha; C.SetOption(a, "less powerful, 5 fewer MP", 1);
  C.Compute(e); Is(C.Value(a.points), 3, "Own a Big Mecha 1, less powerful");
  Is(mecha.available, 15, "its Mecha Points"); Is(mecha.spent, 4, "spent");
  e := mecha; NoWarnings;
  e := mecha.owner;
  C.SetOption(a, "less powerful, 5 fewer MP", 4); C.Compute(e);
  Is(C.Value(a.points), 1, "less powerful 4 times: at least 1"); Is(mecha.available, 0, "no Mecha Points");
  e := mecha; Warns(C.OverMechaPoints, NIL, TRUE, "the mecha spends more");
  e := mecha.owner;
  b := At("Own a Big Mecha", 1); b.mecha := mecha; C.Compute(e);
  Is(mecha.available, 20, "two Own a Big Mecha share it");

  e := New(FALSE); Stats(4, 4, 4);
  a := At("Highly Skilled", 11); C.Compute(e); Is(C.Value(a.points), 11, "Highly Skilled has no highest Level");
  a.level := 0; C.Compute(e); Warns(C.LevelRange, a, TRUE, "Level 0");
  a := At("Life Support", 3); C.Compute(e); Warns(C.LevelRange, a, TRUE, "Life Support 3, above 2");
  a := At("Toughness", 1); C.Compute(e); Warns(C.MechaOnly, a, TRUE, "Toughness on a character");
  a := At("Unique Character Attribute", 2); C.Compute(e); Warns(C.NoCost, a, TRUE, "the GM's cost, not given");
  C.Override(a.points, 5); C.Compute(e); Warns(C.NoCost, a, FALSE, "given by an override");
  a := Unknown(1); C.Compute(e); Warns(C.UnknownItem, a, TRUE, "an unknown Attribute")
END Attributes;

(* ---- Weapon Attacks ---- *)

(* Each Ability and Disability alone: its damage, with and without
   Personal Gear, and Mecha Only on a character. *)
PROCEDURE EachMod(kind: INTEGER);
  VAR i, slots, n, n2, want: INTEGER; it: R.Item; ok, gear, mechaOnly: BOOLEAN; bad: ARRAY 256 OF CHAR;
BEGIN
  ok := TRUE; gear := TRUE; mechaOnly := TRUE; bad := "";
  FOR i := 0 TO R.Count(kind) - 1 DO
    it := R.Get(kind, i);
    e := New(FALSE); Stats(4, 4, 4); a := Wp(6); ModOf(it, 0); C.Compute(e);
    slots := it.slots; IF R.SameName(it.name, "Auto-Fire") THEN slots := 3 END;
    IF kind = R.Ability THEN n := 6 - slots ELSE n := 6 + slots END;
    want := 15 * n; IF R.SameName(it.name, "No Damage") THEN want := 0 END;
    IF R.MechaOnly IN it.flags THEN n2 := 1 ELSE n2 := 0 END;
    IF (C.Value(a.damage) # want) OR (C.HasWarning(e, C.MechaOnly, a) # (R.MechaOnly IN it.flags))
      OR (C.WarningCount(e) # n2) THEN
      ok := FALSE; Strings.Append(" ", bad); Strings.Append(it.name, bad)
    END;
    a.personalGear := TRUE; C.Compute(e);
    IF R.SameName(it.name, "No Damage") THEN want := 0 ELSE want := 5 * n END;
    IF (C.Value(a.damage) # want) OR (C.Value(a.points) # 0)
      OR (C.HasWarning(e, C.NotPersonalGear, a) # (R.NotPersonalGear IN it.flags)) THEN
      gear := FALSE; Strings.Append(" gear:", bad); Strings.Append(it.name, bad)
    END;
    e := New(TRUE); a := Wp(6); ModOf(it, 0); C.Compute(e);
    IF C.WarningCount(e) # 0 THEN mechaOnly := FALSE; Strings.Append(" mecha:", bad); Strings.Append(it.name, bad) END
  END;
  IF kind = R.Ability THEN sample := "each Weapon Ability" ELSE sample := "each Weapon Disability" END;
  IF bad # "" THEN L(bad); Out.String("  failed:"); Out.String(label); Out.Ln END;
  Yes(ok, "its damage at Level 6, and Mecha Only warned on a character");
  Yes(gear, "as Personal Gear: a third of it, no points, and warned if not for Personal Gear");
  Yes(mechaOnly, "on a mecha, no warnings")
END EachMod;

(* Every pair of Abilities and Disabilities: warned exactly when
   Besm2Rules excludes them. *)
PROCEDURE Exclusions;
  VAR i, j, k, n, pairs: INTEGER; x, y: R.Item; ok: BOOLEAN;
  PROCEDURE Get(i: INTEGER): R.Item;
  BEGIN
    IF i < R.Count(R.Ability) THEN RETURN R.Get(R.Ability, i) ELSE RETURN R.Get(R.Disability, i - R.Count(R.Ability)) END
  END Get;
BEGIN
  sample := "Exclusions"; n := R.Count(R.Ability) + R.Count(R.Disability); ok := TRUE; pairs := 0;
  FOR i := 0 TO n - 1 DO
    FOR j := 0 TO n - 1 DO
      IF i # j THEN
        x := Get(i); y := Get(j);
        e := New(TRUE); a := Wp(6); ModOf(x, 0); ModOf(y, 0); C.Compute(e);
        IF C.HasWarning(e, C.Excluded, a) # R.Excludes(x, y) THEN
          ok := FALSE; Out.String("  failed: "); Out.String(x.name); Out.String(" with "); Out.String(y.name); Out.Ln
        END;
        IF R.Excludes(x, y) THEN INC(pairs) END
      END
    END
  END;
  k := pairs DIV 2;
  Yes(ok, "every pair of Abilities and Disabilities warned exactly when excluded");
  Is(k, 19, "excluded pairs")
END Exclusions;

PROCEDURE Weapons;
  VAR p, q, g: C.Attr; mecha, pc: C.Entity;
BEGIN
  sample := "Weapon Attacks";
  e := New(FALSE); Stats(4, 4, 4);
  p := Wp(3); q := Wp(2); C.Compute(e);
  Is(C.Value(p.points), 12, "primary 3"); Is(C.Value(q.points), 1, "secondary below it");
  Yes(p.isPrimary & ~q.isPrimary, "the first of the highest Level is primary");
  q.level := 3; C.Compute(e); Is(C.Value(q.points), 2, "secondary at its Level");
  q.level := 4; C.Compute(e); Is(C.Value(q.points), 16, "a higher Level becomes the primary");
  Is(C.Value(p.points), 1, "and the first one below it");
  q.level := 3; q.primary := TRUE; C.Compute(e);
  Yes(q.isPrimary & ~p.isPrimary, "primary: true chooses it"); Is(C.Value(p.points), 2, "the other at its Level");
  q.level := 2; C.Compute(e); Is(C.Value(q.points), 8, "a primary 2");
  Warns(C.SecondaryAbove, p, TRUE, "a secondary above the primary");
  q.primary := FALSE;
  g := Wp(6); g.personalGear := TRUE; C.Compute(e);
  Yes(p.isPrimary, "a Personal Gear weapon isn't the primary");
  Is(C.Value(g.points), 0, "nor costs anything"); Is(C.Value(g.damage), 30, "5 damage a Level");
  NoWarnings;
  p.differentGunner := TRUE; C.Compute(e); Warns(C.GunnerNotMecha, p, TRUE, "a Different Gunner on a character");

  sample := "KA-99 Archangel";
  e := New(TRUE); p := Wp(1); Di("Melee", 0);                                (* Harmonic Knife *)
  q := Wp(1); Ab("Auto-Fire", 0); Di("Limited Shots", 2); Di("Unreliable", 0);  (* Auto-Laser *)
  C.Compute(e);
  Is(C.Value(p.points), 4, "Harmonic Knife 1"); Is(C.Value(p.damage), 45, "its damage");
  Is(C.Value(q.points), 2, "Auto-Laser 1"); Is(C.Value(q.damage), 15, "its damage"); NoWarnings;

  sample := "Weapon Attacks";
  e := New(TRUE); p := Wp(2); q := Wp(2); q.differentGunner := TRUE; C.Compute(e);
  Is(C.Value(q.points), 7, "a secondary with a Different Gunner"); NoWarnings;

  e := New(FALSE); Stats(4, 4, 4);
  a := Wp(1); Ab("Accurate", 0); C.Compute(e);
  Is(C.Value(a.damage), 0, "Level 1, Accurate"); Warns(C.LowDamage, a, TRUE, "under 15");
  a := Wp(1); Di("No Damage", 0); Ab("Accurate", 0); C.Compute(e);
  Is(C.Value(a.damage), 0, "No Damage"); Warns(C.LowDamage, a, FALSE, "with No Damage");
  e := New(FALSE); Stats(4, 4, 4);
  a := Wp(6); Di("Limited Shots", 3); C.Compute(e);
  Is(C.Value(a.damage), 135, "Limited Shots x3"); NoWarnings;
  e.attrs.disabilities.countsAs := 4; C.Compute(e); Warns(C.TooOften, a, TRUE, "Limited Shots x4");
  e := New(FALSE); Stats(4, 4, 4);
  a := Wp(6); Ab("Contagious", 6); C.Compute(e); Is(C.Value(a.damage), 0, "Contagious x2");
  Warns(C.LowDamage, a, TRUE, "0 damage"); Warns(C.TooOften, a, FALSE, "taken twice");
  e := New(FALSE); Stats(4, 4, 4); a := Wp(6); Ab("Area Effect", 5); C.Compute(e); Is(C.Value(a.damage), 15, "Area Effect x5, unlimited");
  NoWarnings;
  a := Wp(6); ModOf(NIL, 0); C.Compute(e); Is(C.Value(a.damage), 75, "an unknown Ability is one slot");
  Warns(C.UnknownItem, a, TRUE, "an unknown Ability");

  sample := "Auto-Fire";
  mecha := New(TRUE); a := Wp(2); Ab("Auto-Fire", 0);
  pc := New(FALSE); Stats(4, 4, 4); a := At("Own a Big Mecha", 1); a.mecha := mecha;
  C.Compute(pc); Is(C.Value(mecha.attrs.damage), 0, "3 slots by default, never below 0"); Is(mecha.attrs.abilities.slots, 3, "its slots");
  pc.creation.autoFireSlots := 1; C.Compute(pc);
  Is(C.Value(mecha.attrs.damage), 15, "1 slot with the owner's auto-fire-slots 1");
  pc.creation.autoFireSlots := 3; mecha.attrs.abilities.countsAs := 1; C.Compute(pc);
  Is(C.Value(mecha.attrs.damage), 15, "counts-as 1"); e := mecha; Warns(C.TooOften, NIL, FALSE, "counts-as 1")
END Weapons;

(* ---- Defects, Skills and the totals ---- *)

PROCEDURE DefectsSkillsTotals;
  VAR i: INTEGER;
BEGIN
  sample := "Defects";
  e := New(FALSE); Stats(4, 4, 4);
  d := Df("Awkward Size", 6); C.Compute(e); Is(C.Value(d.points), -6, "Awkward Size 6");
  d.rank := 7; C.Compute(e); Yes(C.HasWarning(e, C.LevelRange, NIL), "Awkward Size 7: out of range");
  d.rank := 1;
  d := Df("Hangar Queen", 3); C.Compute(e); Yes(C.HasWarning(e, C.LevelRange, NIL), "Hangar Queen 3");
  d.rank := 2;
  d := Df("Crew Requirement", 1); C.Compute(e); Yes(C.HasWarning(e, C.MechaOnly, NIL), "a Mecha-Only Defect on a character");
  e := New(FALSE); Stats(4, 4, 4);
  FOR i := 1 TO 8 DO d := Df("Awkward", 1) END; C.Compute(e);
  Warns(C.TooManyDefects, NIL, FALSE, "8 Defects"); Is(e.bonusPoints, 8, "8 BP");
  d := Df("Awkward", 1); C.Compute(e); Warns(C.TooManyDefects, NIL, TRUE, "9 Defects");
  e.creation.bonusCeiling := 8; C.Compute(e); Warns(C.OverBonusCeiling, NIL, TRUE, "9 BP, ceiling 8");
  e.creation.bonusCeiling := 9; C.Compute(e); Warns(C.OverBonusCeiling, NIL, FALSE, "ceiling 9");
  sample := "Stats' total";
  e := New(FALSE); Stats(4, 4, 4);
  e.creation.statPointsCeiling := 11; C.Compute(e); Warns(C.StatPointsAbove, NIL, TRUE, "Stats 12, ceiling 11");
  e.creation.statPointsCeiling := 12; C.Compute(e); Warns(C.StatPointsAbove, NIL, FALSE, "Stats 12, ceiling 12");
  e.creation.statPointsFloor := 13; C.Compute(e); Warns(C.StatPointsBelow, NIL, TRUE, "Stats 12, floor 13");
  e.creation.statPointsFloor := 12; C.Compute(e); Warns(C.StatPointsBelow, NIL, FALSE, "Stats 12, floor 12");
  e.creation.statPointsCeiling := 0; e.creation.statPointsFloor := 0; e.creation.stagedStatCost := TRUE;
  e.stat[C.Body] := 11; C.Compute(e);
  e.creation.statPointsCeiling := e.statTotal - 1; C.Compute(e);
  Warns(C.StatPointsAbove, NIL, TRUE, "the Stats' cost, Staged, not their values");
  sample := "Defects";
  NEW(d); C.InitDefect(d, NIL, 2); C.AddDefect(e, d); C.Compute(e);
  Is(C.Value(d.points), -2, "an unknown Defect, its rank"); Yes(C.HasWarning(e, C.UnknownItem, NIL), "warned");

  sample := "Skills";
  e := New(FALSE); Stats(4, 4, 4); e.creation.genre := R.ModernMilitary; C.Compute(e);
  Is(e.skillPoints, 20, "20 Skill Points");
  a := At("Highly Skilled", 2); C.Compute(e); Is(e.skillPoints, 40, "and Highly Skilled 2");
  d := Df("Unskilled", 1); C.Compute(e); Is(e.skillPoints, 30, "and Unskilled 1");
  Warns(C.SkilledAndUnskilled, NIL, TRUE, "both");
  e := New(FALSE); Stats(4, 4, 4); e.creation.genre := R.ModernMilitary;
  d := Df("Unskilled", 2); C.Compute(e); Is(e.skillPoints, 0, "Unskilled 2");
  e.creation.skillPoints := 30; C.Compute(e); Is(e.skillPoints, 30, "the GM's 30");
  s := Sk("Gun Combat", 3, 3); C.Compute(e); Is(C.Value(s.points), 17, "Gun Combat 3, 3 specialisations");
  e.creation.genre := R.TeenageRomance; C.Compute(e); Is(C.Value(s.points), 11, "in Teenage Romance");
  s := Sk("Gun Combat", 7, 1); C.Compute(e); Warns(C.LevelRange, NIL, TRUE, "Level 7");
  e := New(FALSE); Stats(4, 4, 4); e.creation.genre := R.MedievalFantasy;
  s := Sk("Gun Combat", 1, 1); C.Compute(e); Is(C.Value(s.points), 0, "Gun Combat in Medieval Fantasy");
  Warns(C.NotOffered, NIL, TRUE, "not offered");
  e := New(FALSE); Stats(4, 4, 4); s := Sk("Law", 1, 1); s := Sk("Law", 1, 1); C.Compute(e);
  Warns(C.NoGenreSet, NIL, TRUE, "no genre"); Is(C.WarningCount(e), 1, "warned once");
  e := New(FALSE); Stats(4, 4, 4); e.creation.genre := R.ModernMilitary;
  s := HouseSk(3, 2); C.Compute(e); Is(C.Value(s.points), 6, "a house Skill 2 at 3");
  e.creation.genre := R.SpaceOpera; C.Compute(e); Warns(C.NotOffered, NIL, TRUE, "a house Skill outside its genres");
  e.creation.genre := R.ModernMilitary;
  s := Sk("Military Sciences", 3, 1); C.Compute(e); Is(e.skillSpent, 21, "21 spent");
  Warns(C.OverSkillPoints, NIL, TRUE, "over 20");
  s.house := h; C.Compute(e); Is(C.Value(s.points), 9, "a house Skill's costs win over the book's");

  sample := "Totals";
  e := New(FALSE); Stats(6, 6, 6); e.creation.characterPoints := 20; a := At("Combat Mastery", 2);
  C.Compute(e); Warns(C.OverCharacterPoints, NIL, TRUE, "22 spent of 20");
  e.creation.backgroundPoints := 2; C.Compute(e); Is(e.available, 22, "and 2 Background Points");
  Warns(C.OverCharacterPoints, NIL, FALSE, "22 of 22");
  e.creation.characterPoints := 0; C.Compute(e); Is(e.available, 0, "no budget"); NoWarnings
END DefectsSkillsTotals;

(* ---- Overrides ---- *)

PROCEDURE Overrides;
  VAR txt: ARRAY 16 OF CHAR; mecha: C.Entity;
BEGIN
  sample := "Overrides";
  e := New(FALSE); Stats(6, 6, 6); e.creation.genre := R.ModernMilitary;
  a := At("Combat Mastery", 1); d := Df("Awkward", 1); s := Sk("Law", 1, 1);
  C.Override(e.statPoints[C.Mind], 9); C.Compute(e);
  Is(C.Value(e.statPoints[C.Mind]), 9, "Mind's points"); Is(e.statPoints[C.Mind].value, 6, "computed still");
  Is(e.statTotal, 21, "count in the Stats");
  C.Override(a.points, 5); C.Compute(e); Is(e.attrTotal, 5, "an Attribute's in the total");
  Is(e.spent, 25, "and in what is spent");
  C.Override(d.points, -3); C.Compute(e); Is(e.bonusPoints, 3, "a Defect's in the Bonus Points");
  C.Override(s.points, 4); C.Compute(e); Is(e.skillSpent, 4, "a Skill's in Skill Points spent");
  C.Override(e.acv, 12); C.Compute(e); Is(C.Value(e.dcv), 10, "ACV's in DCV"); Is(e.acv.value, 7, "ACV computed");
  C.Override(e.hp, 47); C.Compute(e); Is(C.Value(e.sv), 10, "HP's in SV, rounded up");
  C.Clear(e.hp); C.Compute(e); Is(C.Value(e.sv), 12, "cleared");
  mecha := New(TRUE); a := At("Toughness", 1); C.Override(a.points, 30);
  e := New(FALSE); Stats(4, 4, 4); a := At("Own a Big Mecha", 1); a.mecha := mecha; C.Compute(e);
  e := mecha; Warns(C.OverMechaPoints, NIL, TRUE, "a mecha's Attribute in its Mecha Points");

  sample := "Numbers";
  Yes(C.Parse(" -12 ", e.ar) & e.ar.overridden & (C.Value(e.ar) = -12), "Parse -12");
  C.Text(e.ar, txt); Yes(txt = "-12", "Text"); C.ComputedText(e.ar, txt); Yes(txt = "0", "ComputedText");
  Yes(~C.Parse("1x", e.ar) & (C.Value(e.ar) = -12), "Parse rejects 1x, unchanged");
  Yes(~C.Parse("-", e.ar), "and a lone -");
  Yes(C.Parse("  ", e.ar) & ~e.ar.overridden, "blank clears")
END Overrides;

BEGIN
  Enyon; Cador; Bogatyr;
  StatsAndDerived; Attributes;
  EachMod(R.Ability); EachMod(R.Disability); Exclusions; Weapons;
  DefectsSkillsTotals; Overrides;
  Check.Summary
END TestCalc.
