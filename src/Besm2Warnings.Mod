MODULE Besm2Warnings; (* A Besm2Calc warning as a line for the window: what it is about, and the rule's pages *)

(* PLAN.md, Part B, step 6: the Character tab's Warnings list.  Each
   line names what the warning is about, as the file names it with its
   pages ("Weapon Attack: Gun (p. 82, PDF 84)"), and the condition in a
   few words with the numbers and the rule's pages: names, numbers,
   limits and pages only, never the rulebook's words (AGENTS.md).  The
   pages are those Besm2Calc's codes give.  No window: TestWarnings
   needs no display. *)

IMPORT C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Text, Ropes;

CONST
  CharacterPointsPage = 13;  (* Step 1: the campaign's Character Points *)
  StatLimitsPage = 16;       (* Step 3: 1 to 12, one Stat at 12, the GM's ceiling or floor *)
  MaxStat = 12; MaxDefects = 8; MaxSkillLevel = 6;

TYPE Rope = Ropes.Rope;

VAR highlySkilled, unskilled, ownABigMecha, noDamage: R.Item;

PROCEDURE AddPages(VAR r: Rope; page: INTEGER);
  VAR p: ARRAY 32 OF CHAR;
BEGIN R.PagesText(page, p); Besm2Text.Add(r, " ("); Besm2Text.Add(r, p); Besm2Text.Add(r, ")")
END AddPages;

PROCEDURE AddLabel(VAR r: Rope; it: R.Item);
  VAR s: ARRAY 128 OF CHAR;
BEGIN R.Label(it, s); Besm2Text.Add(r, s)
END AddLabel;

(* name, ": " subject if has, and it's pages, "(p. ?)" for NIL. *)
PROCEDURE AddName(VAR r: Rope; name, subject: Rope; has: BOOLEAN; it: R.Item);
BEGIN
  name := Besm2Text.Trim(name);
  IF name = NIL THEN Besm2Text.Add(r, '""') ELSE r := Ropes.Cat(r, name) END;
  IF has & (Besm2Text.Trim(subject) # NIL) THEN Besm2Text.Add(r, ": "); r := Ropes.Cat(r, Besm2Text.Trim(subject)) END;
  IF it = NIL THEN Besm2Text.Add(r, " (p. ?)") ELSE AddPages(r, it.page) END
END AddName;

PROCEDURE AttrName(VAR r: Rope; a: C.Attr);
BEGIN
  IF a IS Ch.Attr THEN
    WITH a: Ch.Attr DO AddName(r, a.name, a.subject, a.hasSubject, a.item) END
  ELSIF a.item # NIL THEN AddLabel(r, a.item)
  ELSE Besm2Text.Add(r, "an attribute (p. ?)")
  END
END AttrName;

PROCEDURE DefectName(VAR r: Rope; d: C.Defect);
BEGIN
  IF d IS Ch.Defect THEN
    WITH d: Ch.Defect DO AddName(r, d.name, d.subject, d.hasSubject, d.item) END
  ELSIF d.item # NIL THEN AddLabel(r, d.item)
  ELSE Besm2Text.Add(r, "a defect (p. ?)")
  END
END DefectName;

(* A house Skill is the campaign's: no page. *)
PROCEDURE SkillName(VAR r: Rope; s: C.Skill);
BEGIN
  IF s IS Ch.Skill THEN
    WITH s: Ch.Skill DO
      IF (s.house # NIL) & (s.item = NIL) THEN
        IF Besm2Text.Trim(s.name) = NIL THEN Besm2Text.Add(r, '""') ELSE r := Ropes.Cat(r, Besm2Text.Trim(s.name)) END;
        Besm2Text.Add(r, " (the campaign's)")
      ELSE AddName(r, s.name, NIL, FALSE, s.item)
      END
    END
  ELSIF s.item # NIL THEN AddLabel(r, s.item)
  ELSE Besm2Text.Add(r, "a skill (p. ?)")
  END
END SkillName;

PROCEDURE ModName(VAR r: Rope; m: C.Mod);
BEGIN
  IF m IS Ch.Mod THEN
    WITH m: Ch.Mod DO AddName(r, m.name, NIL, FALSE, m.item) END
  ELSIF m.item # NIL THEN AddLabel(r, m.item)
  ELSE Besm2Text.Add(r, "an ability (p. ?)")
  END
END ModName;

PROCEDURE StatName(VAR r: Rope; i: INTEGER);
BEGIN
  CASE i OF
    C.Body: Besm2Text.Add(r, "Body")
  | C.Mind: Besm2Text.Add(r, "Mind")
  | C.Soul: Besm2Text.Add(r, "Soul")
  ELSE Besm2Text.Add(r, "a Stat")
  END;
  AddPages(r, R.StatsPage)
END StatName;

(* What w is about, then ": ". *)
PROCEDURE Subject(VAR r: Rope; w: C.Warning);
BEGIN
  IF w.attr # NIL THEN AttrName(r, w.attr); Besm2Text.Add(r, ": ")
  ELSIF w.defect # NIL THEN DefectName(r, w.defect); Besm2Text.Add(r, ": ")
  ELSIF w.skill # NIL THEN SkillName(r, w.skill); Besm2Text.Add(r, ": ")
  ELSIF w.stat >= 0 THEN StatName(r, w.stat); Besm2Text.Add(r, ": ")
  END;
  IF w.mod # NIL THEN ModName(r, w.mod); Besm2Text.Add(r, ": ") END
END Subject;

(* "Level 7 is outside 1 to 6" *)
PROCEDURE Outside(VAR r: Rope; what: ARRAY OF CHAR; n, max: INTEGER);
BEGIN
  Besm2Text.Add(r, what); Besm2Text.Add(r, " "); Besm2Text.AddInt(r, n); Besm2Text.Add(r, " is outside 1 to ");
  IF max = R.Unlimited THEN Besm2Text.Add(r, "any") ELSE Besm2Text.AddInt(r, max) END
END Outside;

(* "spent 40 Character Points of 35" *)
PROCEDURE Spent(VAR r: Rope; spent, of: INTEGER; what: ARRAY OF CHAR; page: INTEGER);
BEGIN
  Besm2Text.Add(r, "spent "); Besm2Text.AddInt(r, spent); Besm2Text.Add(r, " ");
  Besm2Text.Add(r, what); Besm2Text.Add(r, " of "); Besm2Text.AddInt(r, of); AddPages(r, page)
END Spent;

(* w, a warning of e's last Compute, as one line. *)
PROCEDURE Text*(e: C.Entity; w: C.Warning): Rope;
  VAR r: Rope; s: ARRAY 64 OF CHAR; max: INTEGER;
BEGIN
  r := NIL;
  Subject(r, w);
  CASE w.code OF
    C.UnknownItem:
      IF w.mod # NIL THEN Besm2Text.Add(r, "not a Weapon Ability")
      ELSE Besm2Text.Add(r, "not a name")
      END;
      Besm2Text.Add(r, " the rulebook has: it costs nothing unless its points are given")
  | C.LevelRange:
      IF w.attr # NIL THEN
        IF w.attr.item # NIL THEN max := w.attr.item.maxLevel ELSE max := R.Unlimited END;
        Outside(r, "Level", w.attr.level, max)
      ELSIF w.defect # NIL THEN
        IF w.defect.item # NIL THEN max := w.defect.item.maxLevel ELSE max := R.Unlimited END;
        Outside(r, "rank", w.defect.rank, max); AddPages(r, R.DefectsPage)
      ELSIF w.skill # NIL THEN Outside(r, "Level", w.skill.level, MaxSkillLevel); AddPages(r, R.SkillsPage)
      END
  | C.StatRange:
      IF (w.stat >= 0) & (w.stat < C.NStats) THEN Besm2Text.AddInt(r, e.stat[w.stat]) END;
      IF (e.creation.statCeiling > 0) & (w.stat >= 0) & (w.stat < C.NStats)
         & (e.stat[w.stat] > e.creation.statCeiling) & (e.stat[w.stat] <= MaxStat) THEN
        Besm2Text.Add(r, " is above the campaign's ceiling of "); Besm2Text.AddInt(r, e.creation.statCeiling)
      ELSE
        Besm2Text.Add(r, " is outside 1 to "); Besm2Text.AddInt(r, MaxStat); AddPages(r, StatLimitsPage)
      END
  | C.TwoAtTwelve:
      Besm2Text.Add(r, "more than one Stat at "); Besm2Text.AddInt(r, MaxStat); AddPages(r, StatLimitsPage)
  | C.TooManyDefects:
      Besm2Text.Add(r, "more than "); Besm2Text.AddInt(r, MaxDefects); Besm2Text.Add(r, " Defects");
      AddPages(r, R.DefectsPage)
  | C.OverCharacterPoints:
      Spent(r, e.spent, e.available, "Character Points", CharacterPointsPage)
  | C.OverSkillPoints:
      Spent(r, e.skillSpent, e.skillPoints, "Skill Points", R.SkillsPage)
  | C.OverMechaPoints:
      Spent(r, e.spent, e.available, "Mecha Points", ownABigMecha.page)
  | C.Excluded:
      Besm2Text.Add(r, "can't go with an earlier Ability or Disability of the attack")
  | C.TooOften:
      IF w.mod # NIL THEN Besm2Text.Add(r, "taken more times than it may be")
      ELSE Besm2Text.Add(r, "an option taken more times than it may be")
      END
  | C.OptionClash:
      Besm2Text.Add(r, "two options of one choice")
  | C.NotOffered:
      Besm2Text.Add(r, "not offered in ");
      R.GenreName(e.creation.genre, s); Besm2Text.Add(r, s);
      Besm2Text.Add(r, " (Table 2-4,"); R.PagesText(R.SkillCostsPage, s);
      Besm2Text.Add(r, " "); Besm2Text.Add(r, s); Besm2Text.Add(r, ")")
  | C.LowDamage:
      Besm2Text.Add(r, "damage "); Besm2Text.AddInt(r, C.Value(w.attr.damage));
      IF w.attr.personalGear THEN Besm2Text.Add(r, " is under 5 a Level as Personal Gear")
      ELSE Besm2Text.Add(r, " is under 15 a Level")
      END;
      AddPages(r, R.AlternateAttacksPage); Besm2Text.Add(r, ", without "); AddLabel(r, noDamage)
  | C.NotPersonalGear:
      Besm2Text.Add(r, "not for a Personal Gear weapon"); AddPages(r, R.WeaponAbilitiesPage)
  | C.MechaOnly:
      Besm2Text.Add(r, "for mecha only")
  | C.OverBonusCeiling:
      Besm2Text.Add(r, "the Defects give "); Besm2Text.AddInt(r, e.bonusPoints);
      Besm2Text.Add(r, " Bonus Points, above the campaign's ceiling of "); Besm2Text.AddInt(r, e.creation.bonusCeiling)
  | C.SecondaryAbove:
      Besm2Text.Add(r, "a secondary Weapon Attack above its primary's Level"); AddPages(r, R.AlternateAttacksPage)
  | C.GunnerNotMecha:
      Besm2Text.Add(r, "a Different Gunner on a character's weapon; it is a mecha's"); AddPages(r, R.AlternateAttacksPage)
  | C.SkilledAndUnskilled:
      AddLabel(r, highlySkilled); Besm2Text.Add(r, " with "); AddLabel(r, unskilled)
  | C.NoGenreSet:
      Besm2Text.Add(r, "Skills"); AddPages(r, R.SkillsPage);
      Besm2Text.Add(r, ", but no genre to price them by (Table 2-4,"); R.PagesText(R.SkillCostsPage, s);
      Besm2Text.Add(r, " "); Besm2Text.Add(r, s); Besm2Text.Add(r, ")")
  | C.NoCost:
      Besm2Text.Add(r, "its cost is the GM's: give its points")
  | C.StatPointsAbove:
      Besm2Text.Add(r, "the Stats cost "); Besm2Text.AddInt(r, e.statTotal);
      Besm2Text.Add(r, " Character Points, above the campaign's ceiling of ");
      Besm2Text.AddInt(r, e.creation.statPointsCeiling); AddPages(r, StatLimitsPage)
  | C.StatPointsBelow:
      Besm2Text.Add(r, "the Stats cost "); Besm2Text.AddInt(r, e.statTotal);
      Besm2Text.Add(r, " Character Points, below the campaign's floor of ");
      Besm2Text.AddInt(r, e.creation.statPointsFloor); AddPages(r, StatLimitsPage)
  ELSE
    Besm2Text.Add(r, "warning "); Besm2Text.AddInt(r, w.code)
  END;
  RETURN r
END Text;

BEGIN
  highlySkilled := R.Find("Highly Skilled"); ASSERT(highlySkilled # NIL);
  unskilled := R.Find("Unskilled"); ASSERT(unskilled # NIL);
  ownABigMecha := R.Find("Own a Big Mecha"); ASSERT(ownABigMecha # NIL);
  noDamage := R.FindKind(R.Disability, "No Damage"); ASSERT(noDamage # NIL)
END Besm2Warnings.
