MODULE TestWarnings; (* Besm2Warnings: each warning's line *)

(* PLAN.md, Part B, step 6: the Character tab's Warnings.  Entities are
   built by hand with Besm2Character's records, as the file would give
   them, and each warning's line compared with what it should say: what
   it is about with its pages, and the limit with the rule's pages.
   Needs no display. *)

IMPORT Check, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, W := Besm2Warnings,
  Besm2Text, Ropes, Strings;

VAR e: Ch.Entity;

PROCEDURE New(): Ch.Entity;
  VAR e: Ch.Entity;
BEGIN NEW(e); C.InitEntity(e, FALSE); RETURN e
END New;

PROCEDURE Attr(e: Ch.Entity; name, subject: ARRAY OF CHAR; level: INTEGER): Ch.Attr;
  VAR a: Ch.Attr;
BEGIN
  NEW(a); C.InitAttr(a, R.Find(name), level);
  a.name := Ropes.FromString(name);
  a.hasSubject := subject # ""; IF a.hasSubject THEN a.subject := Ropes.FromString(subject) END;
  C.AddAttr(e, a); RETURN a
END Attr;

PROCEDURE Defect(e: Ch.Entity; name: ARRAY OF CHAR; rank: INTEGER): Ch.Defect;
  VAR d: Ch.Defect;
BEGIN
  NEW(d); C.InitDefect(d, R.Find(name), rank); d.name := Ropes.FromString(name); d.hasSubject := FALSE;
  C.AddDefect(e, d); RETURN d
END Defect;

PROCEDURE Skill(e: Ch.Entity; name: ARRAY OF CHAR; level: INTEGER): Ch.Skill;
  VAR s: Ch.Skill;
BEGIN
  NEW(s); C.InitSkill(s, R.FindKind(R.Skill, name), NIL, level, 0); s.name := Ropes.FromString(name);
  C.AddSkill(e, s); RETURN s
END Skill;

PROCEDURE Mod(VAR list: C.Mod; name: ARRAY OF CHAR): Ch.Mod;
  VAR m: Ch.Mod; it: R.Item;
BEGIN
  it := R.FindKind(R.Ability, name); IF it = NIL THEN it := R.FindKind(R.Disability, name) END;
  NEW(m); C.InitMod(m, it, 0); m.name := Ropes.FromString(name); m.hasDetail := FALSE;
  C.AddMod(list, m); RETURN m
END Mod;

(* e has a warning of code whose line is want. *)
PROCEDURE Says(e: Ch.Entity; code: INTEGER; want: ARRAY OF CHAR);
  VAR w: C.Warning; s: Besm2Text.String; label: ARRAY 512 OF CHAR; found: BOOLEAN;
BEGIN
  C.Compute(e);
  w := e.warnings; found := FALSE; s := NIL;
  WHILE (w # NIL) & ~found DO
    IF w.code = code THEN s := Besm2Text.Chars(W.Text(e, w)); found := s^ = want END;
    w := w.next
  END;
  COPY(want, label);
  IF ~found & (s # NIL) THEN Strings.Append("   (got: ", label); Strings.Append(s^, label); Strings.Append(")", label)
  ELSIF ~found THEN Strings.Append("   (no such warning)", label)
  END;
  Check.Check(found, label)
END Says;

PROCEDURE Main;
  VAR a: Ch.Attr; i, n: INTEGER; w: C.Warning; s: Besm2Text.String; ok: BOOLEAN;
BEGIN
  e := New(); e.stat[C.Body] := 13;
  Says(e, C.StatRange, "Body (p. 15, PDF 17): 13 is outside 1 to 12 (p. 16, PDF 18)");
  e := New(); e.stat[C.Mind] := 9; e.creation.statCeiling := 8;
  Says(e, C.StatRange, "Mind (p. 15, PDF 17): 9 is above the campaign's ceiling of 8");
  e := New(); e.stat[C.Body] := 12; e.stat[C.Soul] := 12;
  Says(e, C.TwoAtTwelve, "more than one Stat at 12 (p. 16, PDF 18)");

  e := New(); a := Attr(e, "Frobnicate", "", 1);
  Says(e, C.UnknownItem, "Frobnicate (p. ?): not a name the rulebook has: it costs nothing unless its points are given");
  e := New(); a := Attr(e, "Heightened Senses", "Hearing", 7);
  Says(e, C.LevelRange, "Heightened Senses: Hearing (p. 41, PDF 43): Level 7 is outside 1 to 6");
  e := New(); a := Attr(e, "A.I.", "", 1);
  Says(e, C.MechaOnly, "A.I. (p. 93, PDF 95): for mecha only");
  e := New(); a := Attr(e, "Weapon Attack", "Gun", 1); C.Override(a.damage, 10);
  Says(e, C.LowDamage,
    "Weapon Attack: Gun (p. 81, PDF 83): damage 10 is under 15 a Level (p. 82, PDF 84), without No Damage (p. 91, PDF 93)");
  e := New(); a := Attr(e, "Weapon Attack", "Gun", 1); a.differentGunner := TRUE;
  Says(e, C.GunnerNotMecha,
    "Weapon Attack: Gun (p. 81, PDF 83): a Different Gunner on a character's weapon; it is a mecha's (p. 82, PDF 84)");
  e := New(); a := Attr(e, "Weapon Attack", "Gun", 1);
  IF Mod(a.abilities, "Frobnicate") # NIL THEN END;
  Says(e, C.UnknownItem,
    "Weapon Attack: Gun (p. 81, PDF 83): Frobnicate (p. ?): not a Weapon Ability the rulebook has: it costs nothing unless its points are given");

  e := New(); FOR i := 1 TO 9 DO IF Defect(e, "Unique Character Defect", 1) # NIL THEN END END;
  Says(e, C.TooManyDefects, "more than 8 Defects (p. 100, PDF 102)");
  e := New(); IF Defect(e, "Unique Character Defect", 1) # NIL THEN END;
  IF Defect(e, "Unique Character Defect", 1) # NIL THEN END; e.creation.bonusCeiling := 1;
  Says(e, C.OverBonusCeiling, "the Defects give 2 Bonus Points, above the campaign's ceiling of 1");
  e := New(); a := Attr(e, "Highly Skilled", "", 1); IF Defect(e, "Unskilled", 1) # NIL THEN END;
  Says(e, C.SkilledAndUnskilled, "Highly Skilled (p. 42, PDF 44) with Unskilled (p. 112, PDF 114)");

  e := New(); e.creation.characterPoints := 10; e.stat[C.Body] := 8; e.stat[C.Mind] := 4;
  Says(e, C.OverCharacterPoints, "spent 13 Character Points of 10 (p. 13, PDF 15)");
  e := New(); IF Skill(e, "Stealth", 1) # NIL THEN END;
  Says(e, C.NoGenreSet, "Skills (p. 117, PDF 119), but no genre to price them by (Table 2-4, p. 119, PDF 121)");
  e := New(); e.creation.genre := R.ModernMilitary; IF Skill(e, "Stealth", 7) # NIL THEN END;
  Says(e, C.LevelRange, "Stealth (p. 125, PDF 127): Level 7 is outside 1 to 6 (p. 117, PDF 119)");
  Says(e, C.OverSkillPoints, "spent 28 Skill Points of 20 (p. 117, PDF 119)");

  (* Every warning of these is a line of its own words, never the
     fallback. *)
  n := 0; ok := TRUE;
  w := e.warnings;
  WHILE w # NIL DO
    s := Besm2Text.Chars(W.Text(e, w)); INC(n);
    IF (s^ = "") OR (Strings.Pos("warning ", s^, 0) = 0) THEN ok := FALSE END;
    w := w.next
  END;
  Check.Check(ok & (n > 0), "every warning has its own line");
  Check.Summary
END Main;

BEGIN
  Main
END TestWarnings.
