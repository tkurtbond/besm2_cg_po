MODULE TestModel; (* Besm2Character's editing: what the Attributes, Defects and Skills tabs do to an entity *)

(* PLAN.md, Part B, step 7.  The window's lists change an entity only
   through Besm2Character's NewAttr, InsertAttr, ChangeAttr, RemoveAttr,
   the same for Defects and Skills, SetGenre and Relink; here each is
   checked on an entity built by hand, then what they made is saved and
   loaded again.  Needs no display.  What it saves goes in ../obj. *)

IMPORT Check, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Save, Besm2Text, Ropes;

CONST SavePath = "../obj/model-test.yaml";

TYPE Rope = Ropes.Rope;

VAR
  es, back: Ch.Entities;
  e, m: Ch.Entity;
  a, a2, keep: Ch.Attr;
  d, d2: Ch.Defect;
  s, s2: Ch.Skill;
  h: Ch.HouseSkill;
  specs: Besm2Text.List;
  msg: Rope;
  ok: BOOLEAN;

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

PROCEDURE Is(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.EqualString(r, s)
END Is;

PROCEDURE Count(a: C.Attr): INTEGER;
  VAR n: INTEGER;
BEGIN n := 0; WHILE a # NIL DO INC(n); a := a.next END; RETURN n
END Count;

(* Index of option label of it.  Called outside an index: poc drops a
   string literal inside an array index (a[F("x")]), 2026-11-06. *)
PROCEDURE Opt(it: R.Item; label: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER;
BEGIN
  i := 0; WHILE (i < it.nOptions) & ~R.SameName(it.option[i].label, label) DO INC(i) END;
  ASSERT(i < it.nOptions); RETURN i
END Opt;

PROCEDURE Attributes;
  VAR i, hover: INTEGER;
BEGIN
  e := Ch.New(); es := Ch.One(e);
  a := Ch.NewAttr(R.Find("Flight"), 2, NIL, Rp("  wings  "));
  Ch.InsertAttr(e, a); Ch.ComputeAll(es);
  Check.Check((e.attrs = a) & e.hasAttributes & Is(a.name, "Flight") & ~a.hasSubject & Is(a.details, "wings"),
    "NewAttr, InsertAttr: the rulebook's name, details trimmed, no subject");
  Check.Check(C.Value(a.points) = 8, "Flight 2: the first of its required choice, can hover, 4 a Level (p. 33)");
  i := Opt(a.item, "cannot hover"); a.times[i] := 1; i := Opt(a.item, "skimmer or hovercraft"); a.times[i] := 1;
  Ch.ComputeAll(es);
  Check.Check(C.Value(a.points) = 5, "cannot hover, a skimmer: 3 a Level, -1 on the total");

  a2 := Ch.NewAttr(R.Find("Heavy Armour"), 1, Rp(""), NIL); Ch.InsertAttr(e, a2); Ch.ComputeAll(es);
  Check.Check((Count(e.attrs) = 2) & (e.attrs.next = a2) & ~a2.hasSubject & ~a2.hasDetails, "a second: last; blank is none");
  Check.Check(e.attrTotal = 9, "both in the total");

  keep := a; hover := Opt(a.item, "cannot hover");
  Ch.ChangeAttr(e, a, a.item, 3, Rp("Sky"), NIL); Ch.ComputeAll(es);
  Check.Check((a = keep) & (a.level = 3) & Is(a.subject, "Sky") & ~a.hasDetails & (a.times[hover] = 1),
    "ChangeAttr, the same name: the same record, its options kept");
  Check.Check(C.Value(a.points) = 8, "and priced at its new Level");

  a.extra := NIL;
  Ch.ChangeAttr(e, a, R.Find("Highly Skilled"), 2, NIL, NIL); Ch.ComputeAll(es);
  Check.Check((a # keep) & (e.attrs = a) & (a.next = a2) & Is(a.name, "Highly Skilled") & (a.times[0] = 0),
    "another name: a new record in its place, no options");
  Check.Check(C.Value(a.points) = 2, "priced as the new name");

  Ch.RemoveAttr(e, a2); Ch.ComputeAll(es);
  Check.Check((Count(e.attrs) = 1) & (e.attrs = a) & (a.next = NIL) & (e.attrTotal = 2), "RemoveAttr: the last");
  Ch.RemoveAttr(e, a); Ch.ComputeAll(es);
  Check.Check((e.attrs = NIL) & (e.attrTotal = 0), "and the only one")
END Attributes;

PROCEDURE Defects;
BEGIN
  d := Ch.NewDefect(R.Find("Unique Character Defect"), 2, Rp("Stubborn"), NIL);
  Ch.InsertDefect(e, d);
  d2 := Ch.NewDefect(R.Find("Easily Distracted"), 1, NIL, Rp("cats"));
  Ch.InsertDefect(e, d2); Ch.ComputeAll(es);
  Check.Check(e.hasDefects & (e.defects = d) & (d.next = d2) & d.hasLevel & Is(d.subject, "Stubborn")
    & Is(d2.details, "cats"), "NewDefect, InsertDefect: in order; the rank is saved");
  Check.Check((C.Value(d.points) = -2) & (e.bonusPoints = 3), "Bonus Points: one a rank");
  Ch.ChangeDefect(e, d, d.item, 1, NIL, NIL); Ch.ComputeAll(es);
  Check.Check(~d.hasSubject & (e.bonusPoints = 2), "ChangeDefect: the rank and subject");
  Ch.RemoveDefect(e, d); Ch.ComputeAll(es);
  Check.Check((e.defects = d2) & (e.bonusPoints = 1), "RemoveDefect: the first")
END Defects;

PROCEDURE Skills;
BEGIN
  Besm2Text.Clear(specs); Besm2Text.Append(specs, Rp(" Cars ")); Besm2Text.Append(specs, NIL);
  Besm2Text.Append(specs, Rp("Trucks"));
  s := Ch.NewSkill(R.FindKind(R.Skill, "Driving"), NIL, 2, specs);
  Ch.InsertSkill(e, s); Ch.ComputeAll(es);
  Check.Check(e.hasSkills & Is(s.name, "Driving") & (s.specs = 2) & Is(s.specialisations.items[0], "Cars")
    & s.hasSpecialisations, "NewSkill: specialisations trimmed, blanks dropped");
  Ch.SetGenre(e, R.ModernMilitary); Ch.ComputeAll(es);
  Check.Check(e.hasCreation & (e.creation.genre = R.ModernMilitary) & (C.Value(s.points) = 9),
    "SetGenre: Modern Military, Driving 4 a Level (p. 119); the first specialisation free, the second 1 (p. 118)");
  Ch.SetGenre(e, R.Cyberpunk); Ch.ComputeAll(es);
  Check.Check(C.Value(s.points) = 7, "Cyberpunk: 3 a Level");

  NEW(h); C.InitHouseSkill(h); h.name := Rp("Mecha Piloting"); h.cost[R.Cyberpunk] := 5;
  h.hasStat := FALSE; h.hasSpecializations := FALSE; Besm2Text.Clear(h.specializations);
  C.AddHouseSkill(e.creation, h);
  Besm2Text.Clear(specs);
  s2 := Ch.NewSkill(NIL, h, 1, specs); Ch.InsertSkill(e, s2); Ch.ComputeAll(es);
  Check.Check((s2.house = h) & Is(s2.name, "Mecha Piloting") & (C.Value(s2.points) = 5) & (e.skillSpent = 12),
    "a house Skill: its name and its cost");
  Ch.ChangeSkill(e, s2, R.FindKind(R.Skill, "Driving"), NIL, 1, specs); Ch.ComputeAll(es);
  Check.Check((s2.house = NIL) & Is(s2.name, "Driving") & (s.next = s2), "ChangeSkill: to a rulebook Skill, in place");
  Ch.RemoveSkill(e, s2); Ch.ComputeAll(es);
  Check.Check((s.next = NIL) & (e.skillSpent = 7), "RemoveSkill")
END Skills;

PROCEDURE Mecha;
BEGIN
  m := Ch.New(); m.isMecha := TRUE; m.hasMechaKey := TRUE; m.name := Rp("Walker"); m.hasName := TRUE;
  NEW(es, 2); es[0] := e; es[1] := m;
  a := Ch.NewAttr(R.Find("Own a Big Mecha"), 1, Rp("Nobody"), NIL); Ch.InsertAttr(e, a);
  Ch.Relink(es);
  Check.Check(a.mecha = NIL, "Relink: Own a Big Mecha's subject names no mecha");
  Ch.ChangeAttr(e, a, a.item, 1, Rp("Walker"), NIL); Ch.Relink(es);
  Check.Check(a.mecha = m, "named: linked");
  Ch.ChangeAttr(e, a, a.item, 1, Rp("Other"), NIL); Ch.Relink(es);
  Check.Check(a.mecha = NIL, "renamed: unlinked")
END Mecha;

PROCEDURE SaveLoad;
  VAR b: Ch.Entity; ba: Ch.Attr; glider: INTEGER;
BEGIN
  a := Ch.NewAttr(R.Find("Flight"), 2, NIL, NIL); glider := Opt(a.item, "glider"); a.times[glider] := 1; Ch.InsertAttr(e, a);
  Ch.ComputeAll(es);
  ok := Besm2Save.SaveAll(es, SavePath, msg);
  Check.Check(ok, "saved");
  ok := ok & Ch.LoadAll(SavePath, back, msg) & (LEN(back^) = 2);
  Check.Check(ok, "and loaded again");
  IF ok THEN
    b := back[0]; ba := b.attrs.next(Ch.Attr);
    Check.Check((b.creation.genre = R.Cyberpunk) & (b.defects # NIL) & Is(b.skills(Ch.Skill).name, "Driving")
      & (b.skills.specs = 2), "the genre, the Defect, the Skill and its specialisations");
    Check.Check((ba.item = a.item) & (ba.times[glider] = 1) & (C.Value(ba.points) = C.Value(a.points))
      & ~ba.points.overridden, "the option taken, and the points the same, not an override");
    Check.Check(Is(b.attrs(Ch.Attr).subject, "Other") & (b.defects(Ch.Defect).rank = 1), "the subject, the rank")
  END
END SaveLoad;

BEGIN
  Attributes;
  Defects;
  Skills;
  Mecha;
  SaveLoad;
  Check.Summary
END TestModel.
