MODULE TestModel; (* Besm2Character's editing: what the Attributes, Defects and Skills tabs do to an entity *)

(* PLAN.md, Part B, steps 7, 8 and 9.  The window's lists change an entity only
   through Besm2Character's NewAttr, InsertAttr, ChangeAttr, RemoveAttr,
   the same for Defects and Skills, SetGenre and Relink, and the Weapon
   Attack dialog through NewMod, InsertMod, ChangeMod, RemoveMod,
   CopyMods and SetPrimary; step 9's New Mecha and Duplicate through
   NewMecha, ReadText and Besm2Save.Copy; step 10's Creation dialog
   through SetCreation, TakeCreation, SaveSkills and RestoreCreation,
   and SetGenre's repricing of the Skills a file couldn't price; here each is
   checked on an entity built by hand, then what they made is saved and
   loaded again.  Needs no display.  What it saves goes in ../obj. *)

IMPORT Check, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Save, Besm2Text, Ropes;

CONST SavePath = "../obj/model-test.yaml"; WeaponPath = "../obj/model-weapon.yaml";
  UnpricedPath = "data/unpriced.yaml"; CreationPath = "../obj/model-creation.yaml";

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

(* Step 9: a new mecha, a file read from text, and an entity copied. *)
PROCEDURE Several;
  VAR c, w, cm: Ch.Entity; ces, rs: Ch.Entities; oa: Ch.Attr; results: Ch.Result; text: Rope;
BEGIN
  w := Ch.NewMecha(Rp("Walker"));
  Check.Check(w.isMecha & w.hasMechaKey & Is(w.name, "Walker") & w.hasName & (w.owner = NIL) & (w.available = 0)
    & (w.attrs = NIL), "NewMecha: a mecha, named, with no owner and no Mecha Points");
  c := Ch.New(); c.name := Rp("Pilot"); c.hasName := TRUE;
  oa := Ch.NewAttr(R.Find("Own a Big Mecha"), 2, Rp("Walker"), NIL); Ch.InsertAttr(c, oa);
  Ch.InsertAttr(w, Ch.NewAttr(R.Find("Heavy Armour"), 1, NIL, NIL));
  NEW(ces, 2); ces[0] := c; ces[1] := w; Ch.Relink(ces); Ch.ComputeAll(ces);
  Check.Check((oa.mecha = w) & (w.owner = c) & (C.MechaPoints(oa) = 40) & (w.available = 40) & (w.spent = 4),
    "Own a Big Mecha 2 names it: 40 Mecha Points (p. 59), 4 spent");

  text := Besm2Save.ToText(ces);
  Ch.ReadText(text, results, rs);
  Check.Check((rs # NIL) & (LEN(rs^) = 2) & Is(rs[0].name, "Pilot") & rs[1].isMecha & Is(rs[1].name, "Walker")
    & (rs[0].attrs.mecha = rs[1]) & (rs[1].owner = rs[0]) & (rs[1].available = 40), "ReadText: the entities saved, linked, priced");
  Ch.ReadText(Rp("- name: [bad"), results, rs);
  Check.Check((rs = NIL) OR (LEN(rs^) = 0), "and of text that isn't YAML, none");

  cm := Besm2Save.Copy(ces, 1);
  Check.Check((cm # NIL) & (cm # w) & cm.isMecha & Is(cm.name, "Walker") & (cm.attrs # NIL) & (cm.attrs # w.attrs)
    & (C.Value(cm.attrs.points) = 4) & ~cm.attrs.points.overridden, "Copy: a mecha's copy, priced as its owner prices it, no override");
  cm := Besm2Save.Copy(ces, 0);
  Check.Check((cm # NIL) & (cm # c) & Is(cm.name, "Pilot") & (cm.attrs # oa) & Is(cm.attrs(Ch.Attr).subject, "Walker")
    & (C.Value(cm.attrs.points) = C.Value(oa.points)), "a character's: its Own a Big Mecha still names the mecha");
  Check.Check((oa.mecha = w) & (w.owner = c), "the entities copied unchanged")
END Several;

PROCEDURE Weapons;
  VAR we: Ch.Entity; wes, wback: Ch.Entities; w, w2, bw: Ch.Attr; acc, area, melee, auto: Ch.Mod; copy: C.Mod;
BEGIN
  we := Ch.New(); wes := Ch.One(we);
  w := Ch.NewAttr(R.Find("Weapon Attack"), 4, Rp("Sword"), NIL); Ch.InsertAttr(we, w); Ch.ComputeAll(wes);
  Check.Check((C.Value(w.points) = 16) & (C.Value(w.damage) = 60), "Weapon Attack 4: the primary, 4 a Level, 15 damage a Level (p. 82)");

  acc := Ch.NewMod(we, R.FindKind(R.Ability, "Accurate"), 1, NIL);
  Ch.InsertMod(w, TRUE, acc); Ch.ComputeAll(wes);
  Check.Check((w.abilities = acc) & w.hasAbilities & ~w.hasDisabilities & w.structured & w.hasDamage
    & (acc.countsAs = 0) & (acc.slots = 1) & Is(acc.name, "Accurate"),
    "NewMod, InsertMod: its slots taken once leave counts-as out; the keys saved");
  Check.Check(C.Value(w.damage) = 45, "an Ability slot: 15 less damage");

  area := Ch.NewMod(we, R.FindKind(R.Ability, "Area Effect"), 2, Rp("  wide  "));
  Ch.InsertMod(w, TRUE, area); Ch.ComputeAll(wes);
  Check.Check((acc.next = area) & (area.countsAs = 2) & (C.Times(area) = 2) & Is(area.detail, "wide") & area.hasDetail,
    "twice: counts-as 2, last, its detail trimmed");
  Check.Check(C.Value(w.damage) = 15, "two slots more: 15 damage");

  melee := Ch.NewMod(we, R.FindKind(R.Disability, "Melee"), 1, NIL);
  Ch.InsertMod(w, FALSE, melee); Ch.ComputeAll(wes);
  Check.Check(w.hasDisabilities & (w.disabilities = melee) & (melee.countsAs = 1) & (melee.slots = 1),
    "Melee counting as 1, less than its 2: counts-as kept");
  Check.Check(C.Value(w.damage) = 30, "a Disability slot: 15 more damage");

  Ch.ChangeMod(we, area, NIL, 1, NIL); Ch.ComputeAll(wes);
  Check.Check((area.item.name = "Area Effect") & (area.countsAs = 0) & ~area.hasDetail & (C.Value(w.damage) = 45),
    "ChangeMod: the same name, one slot, no detail");
  Ch.ChangeMod(we, area, R.FindKind(R.Ability, "Long Range"), 1, Rp("far")); Ch.ComputeAll(wes);
  Check.Check(Is(area.name, "Long Range") & (acc.next = area) & Is(area.detail, "far"), "another name, in place");

  copy := Ch.CopyMods(w.abilities);
  Check.Check((copy # acc) & (copy.item = acc.item) & (copy.next # area) & (copy.next.item = area.item)
    & Is(copy.next(Ch.Mod).detail, "far") & (copy.next.next = NIL), "CopyMods: its own records, the same");

  Ch.RemoveMod(w, TRUE, acc); Ch.ComputeAll(wes);
  Check.Check((w.abilities = area) & (C.Value(w.damage) = 60), "RemoveMod: the first");

  auto := Ch.NewMod(we, R.FindKind(R.Ability, "Auto-Fire"), 1, NIL);
  Ch.InsertMod(w, TRUE, auto); Ch.ComputeAll(wes);
  Check.Check((auto.countsAs = 1) & (C.Value(w.damage) = 45), "Auto-Fire counting as 1, as the book's examples");

  w2 := Ch.NewAttr(R.Find("Weapon Attack"), 4, Rp("Bow"), NIL); Ch.InsertAttr(we, w2); Ch.ComputeAll(wes);
  Check.Check(w.isPrimary & ~w2.isPrimary & (C.Value(w2.points) = 2), "two at Level 4: the first the primary, the second 2");
  Ch.SetPrimary(we, w2, TRUE); Ch.ComputeAll(wes);
  Check.Check(w2.primary & w2.isPrimary & ~w.isPrimary & (C.Value(w.points) = 2) & (C.Value(w2.points) = 16),
    "SetPrimary: the second marked, now the primary");
  Ch.SetPrimary(we, w, TRUE); Ch.ComputeAll(wes);
  Check.Check(w.primary & ~w2.primary & w.isPrimary, "marking the first unmarks the second");
  Ch.SetPrimary(we, w, FALSE); Ch.ComputeAll(wes);
  Check.Check(~w.primary & w.isPrimary, "unmarked: the first of the highest Level again");
  w2.differentGunner := TRUE; Ch.ComputeAll(wes);
  Check.Check(C.HasWarning(we, C.GunnerNotMecha, w2), "a different gunner on a character: warned");
  w2.differentGunner := FALSE;

  ok := Besm2Save.SaveAll(wes, WeaponPath, msg) & Ch.LoadAll(WeaponPath, wback, msg);
  Check.Check(ok, "saved and loaded again");
  IF ok THEN
    bw := wback[0].attrs(Ch.Attr);
    Check.Check((bw.abilities # NIL) & (bw.abilities.countsAs = 0) & Is(bw.abilities(Ch.Mod).detail, "far")
      & (bw.abilities.next # NIL) & (bw.abilities.next.countsAs = 1) & (bw.disabilities # NIL)
      & (bw.disabilities.countsAs = 1), "the Abilities and Disabilities, a counts-as of 1 kept");
    Check.Check((C.Value(bw.damage) = C.Value(w.damage)) & (C.Value(bw.points) = C.Value(w.points)) & ~bw.damage.overridden,
      "the damage and points the same")
  END
END Weapons;

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

(* Step 10: a file's Skills with no genre to price them are kept as
   overrides (unpriced); a creation taken from another character, or a
   genre set, prices them, and clears each override it agrees with. *)
PROCEDURE Creation;
  VAR u, camp: Ch.Entity; dr, ga, mp: Ch.Skill; marks: Ch.SkillMarks; oc, c: C.Creation;
    keys: SET; has: BOOLEAN;
BEGIN
  ok := Ch.LoadAll(UnpricedPath, back, msg) & (LEN(back^) = 2);
  Check.Check(ok, "data/unpriced.yaml loaded");
  IF ~ok THEN RETURN END;
  u := back[0]; camp := back[1];
  dr := u.skills(Ch.Skill); ga := dr.next(Ch.Skill); mp := ga.next(Ch.Skill);
  Check.Check(dr.unpriced & dr.points.overridden & (C.Value(dr.points) = 8) & ga.unpriced & mp.unpriced
    & (mp.house = NIL) & mp.points.overridden & ~u.hasCreation,
    "no genre: each Skill's points kept as an unpriced override");
  oc := u.creation; keys := u.creationKeys; has := u.hasCreation; marks := Ch.SaveSkills(u);

  Ch.TakeCreation(u, camp); Ch.ComputeAll(back);
  Check.Check((u.creation.genre = R.Cyberpunk) & (u.creation.characterPoints = 45) & (u.available = 47)
    & (u.creation.statCeiling = 10) & (u.creationKeys = camp.creationKeys) & u.hasCreation,
    "TakeCreation: the numbers, options and keys");
  Check.Check((mp.house # NIL) & (mp.house # camp.creation.houseSkills) & (u.creation.houseSkills = mp.house)
    & Is(mp.house(Ch.HouseSkill).name, "Mecha Piloting"), "the house Skills copied, and the Skill tied to the copy");
  Check.Check(~mp.points.overridden & ~mp.unpriced & (C.Value(mp.points) = 5),
    "the house Skill's price agrees with the file's: the override cleared");
  Check.Check(dr.points.overridden & dr.unpriced & (C.Value(dr.points) = 8),
    "Cyberpunk prices Driving 2 at 6, not the file's 8: kept, still unpriced");

  Ch.SetGenre(u, R.ModernMilitary); Ch.ComputeAll(back);
  Check.Check(~dr.points.overridden & ~dr.unpriced & (C.Value(dr.points) = 8),
    "SetGenre: Modern Military prices it at 8 (p. 119): the override cleared");
  Check.Check(ga.points.overridden & ga.unpriced & (C.Value(ga.points) = 99), "Gaming's 99 still kept");

  ok := Besm2Save.SaveAll(back, CreationPath, msg) & Ch.LoadAll(CreationPath, es, msg) & (LEN(es^) = 2);
  Check.Check(ok, "saved and loaded again");
  IF ok THEN
    Check.Check((es[0].creation.genre = R.ModernMilitary) & (es[0].creation.characterPoints = 45)
      & (es[0].creation.backgroundPoints = 2) & (es[0].creation.statCeiling = 10)
      & (es[0].creation.houseSkills # NIL) & ~es[0].skills.next.next.points.overridden,
      "the creation and its house Skill, and the Skill priced by it")
  END;

  Ch.RestoreCreation(u, oc, keys, has, marks); Ch.ComputeAll(back);
  Check.Check((u.creation.genre = C.NoGenre) & (u.creationKeys = {}) & ~u.hasCreation
    & (u.creation.houseSkills = NIL) & (mp.house = NIL) & mp.points.overridden & mp.unpriced
    & dr.points.overridden & dr.unpriced & (C.Value(dr.points) = 8),
    "RestoreCreation: the creation and every Skill as they were");

  c := u.creation; c.genre := R.ModernMilitary; c.backgroundPoints := 1;
  Ch.SetCreation(u, c, {Ch.GenreKey}, FALSE); Ch.ComputeAll(back);
  Check.Check(u.hasCreation & ~dr.points.overridden & (u.creation.backgroundPoints = 1),
    "SetCreation: a key written makes `creation`; the genre prices Driving")
END Creation;

BEGIN
  Attributes;
  Defects;
  Skills;
  Mecha;
  Several;
  Weapons;
  SaveLoad;
  Creation;
  Check.Summary
END TestModel.
