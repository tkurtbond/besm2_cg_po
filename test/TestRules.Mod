MODULE TestRules; (* Besm2Rules: the tables, pages, labels, finding, small tables *)

(* What Besm2Rules must be whatever the tables of rules/ say: how many
   items of each kind (PLAN.md, A2), names found once, pages in their
   chapter's span and PDF pages at + 2, the label format (AGENTS.md,
   "Pages"), the aliases, the options' shape, and the small tables
   (Table 2-4, p. 117; Table 4-7, p. 166) at a few places.  Every item's
   numbers are checked against rules/*.tsv by tools/check-rules.py, and
   every page against the PDF's headings by make check-pages.  Needs no
   display. *)

IMPORT Check, R := Besm2Rules, Out;

VAR s: ARRAY 80 OF CHAR;

PROCEDURE Note(name, what: ARRAY OF CHAR);
BEGIN Out.String("    "); Out.String(name); Out.String(": "); Out.String(what); Out.Ln
END Note;

PROCEDURE Counts;
BEGIN
  Check.Check(R.Count(R.Stat) = 3, "3 Stats");
  Check.Check(R.Count(R.Attribute) = 76, "76 Attributes (pp. 20-81)");
  Check.Check(R.Count(R.MechaAttribute) = 13, "13 Mecha Attributes (pp. 93-99)");
  Check.Check(R.Count(R.Defect) = 38, "38 Defects (pp. 101-113)");
  Check.Check(R.Count(R.MechaDefect) = 10, "10 Mecha-Only Defects (pp. 114-116)");
  Check.Check(R.Count(R.Skill) = 52, "52 Skills (pp. 120-128)");
  Check.Check(R.Count(R.Ability) = 34, "34 Weapon Attack Abilities (pp. 83-89)");
  Check.Check(R.Count(R.Disability) = 21, "21 Weapon Attack Disabilities (pp. 89-92)")
END Counts;

(* Each kind's printed pages. *)
PROCEDURE Span(kind: INTEGER; VAR first, last: INTEGER);
BEGIN
  CASE kind OF
    R.Stat: first := 15; last := 15
  | R.Attribute: first := 20; last := 81
  | R.MechaAttribute: first := 93; last := 99
  | R.Defect: first := 101; last := 113
  | R.MechaDefect: first := 114; last := 116
  | R.Skill: first := 120; last := 128
  | R.Ability: first := 83; last := 89
  | R.Disability: first := 89; last := 92
  END
END Span;

PROCEDURE Items;
  VAR k, i, first, last, prev: INTEGER; it, f: R.Item;
    found, pages, order, kinds, opts: BOOLEAN; o: R.Option; required, adds: BOOLEAN; j: INTEGER;
BEGIN
  found := TRUE; pages := TRUE; order := TRUE; kinds := TRUE; opts := TRUE;
  FOR k := 0 TO R.NKinds - 1 DO
    Span(k, first, last); prev := first;
    FOR i := 0 TO R.Count(k) - 1 DO
      it := R.Get(k, i);
      IF it.kind # k THEN kinds := FALSE; Note(it.name, "of another kind") END;
      (* Found by its name, in any case, as itself; Stealth is two *)
      f := R.Find(it.name);
      IF (f # it) & ~((it.name = "Stealth") & (k = R.Skill) & (f # NIL) & (f.kind = R.Attribute)) THEN
        found := FALSE; Note(it.name, "Find gives another item")
      END;
      IF R.FindKind(k, it.name) # it THEN found := FALSE; Note(it.name, "FindKind gives another item") END;
      IF (it.page < first) OR (it.page > last) THEN pages := FALSE; Note(it.name, "page outside its chapter") END;
      IF R.PdfPage(it) # it.page + 2 THEN pages := FALSE; Note(it.name, "PDF page is not page + 2") END;
      IF it.page < prev THEN order := FALSE; Note(it.name, "before the item it follows") END;
      prev := it.page;
      (* An Attribute costing 0 a Level has its cost from its choices:
         a required one, or those it adds up (Environmental Control) *)
      IF (k = R.Attribute) OR (k = R.MechaAttribute) THEN
        required := FALSE; adds := FALSE;
        FOR j := 0 TO it.nOptions - 1 DO
          o := it.option[j];
          IF o.group > 0 THEN
            required := TRUE;
            IF ~o.perLevel OR (o.amount <= 0) THEN opts := FALSE; Note(it.name, "a required choice not a cost a Level") END
          END;
          IF o.perLevel & (o.amount > 0) THEN adds := TRUE END;
          IF (o.maxTimes < 1) OR (o.label = "") THEN opts := FALSE; Note(it.name, "an option without a label or times") END
        END;
        IF (it.cost = 0) & ~adds & ~(R.GmCost IN it.flags) THEN
          opts := FALSE; Note(it.name, "costs nothing")
        END;
        IF required & (it.cost # 0) THEN opts := FALSE; Note(it.name, "a cost and a required choice") END;
        IF (it.maxLevel # 2) & (it.maxLevel # 6) & (it.maxLevel # R.Unlimited) THEN
          opts := FALSE; Note(it.name, "a highest Level not 2, 6 or unlimited")
        END
      END
    END
  END;
  Check.Check(kinds, "every item is of the kind it is listed under");
  Check.Check(found, "every item is found by its name");
  Check.Check(pages, "every page is in its chapter, and its PDF page is page + 2");
  Check.Check(order, "the items are in the book's order");
  Check.Check(opts, "each Attribute's cost is its own or its choices', and its Levels 2, 6 or unlimited")
END Items;

PROCEDURE Finding;
  VAR it: R.Item;
BEGIN
  it := R.Find("highly skilled");
  Check.Check((it # NIL) & (it.name = "Highly Skilled"), "Find ignores case");
  Check.Check(R.Find("Natural Attack") = NIL, "Find gives NIL for a name the book doesn't have");
  Check.Check(R.Find("Weapon") = R.Find("Weapon Attack"), "Find: Weapon is Weapon Attack (BESM 2nd edition)");
  Check.Check(R.Find("Hanger Queen") = R.Find("Hangar Queen"), "Find: Hanger Queen is Hangar Queen");
  Check.Check(R.Find("Accessories") = R.Find("Features or Accessories"), "Find: Accessories");
  Check.Check(R.Find("features") = R.Find("Features or Accessories"), "Find: Features, in any case");
  Check.Check(R.Find("Electronic Counter-Measures (ECM)") = R.Find("ECM"), "Find: the heading's full name");
  Check.Check(R.Find("Unarmed Defence") = R.Find("Unarmed Defense"), "Find: Unarmed Defence");
  it := R.FindKind(R.Skill, "Stealth");
  Check.Check((it # NIL) & (it.page = 125), "FindKind: Stealth the Skill (p. 125)");
  it := R.Find("Stealth");
  Check.Check((it # NIL) & (it.kind = R.Attribute) & (it.page = 73), "Find: Stealth the Attribute (p. 73)");
  Check.Check(R.FindKind(R.Defect, "Weapon") = NIL, "FindKind: an alias of another kind isn't found")
END Finding;

PROCEDURE Labels;
BEGIN
  R.Label(R.Find("Highly Skilled"), s);
  Check.Check(s = "Highly Skilled (p. 42, PDF 44)", "Label: Highly Skilled (p. 42, PDF 44)");
  R.Label(R.FindKind(R.Ability, "Accurate"), s);
  Check.Check(s = "Accurate (p. 83, PDF 85)", "Label: Accurate (p. 83, PDF 85)");
  R.LabelOf("Weapon", s);
  Check.Check(s = "Weapon (p. 81, PDF 83)", "LabelOf keeps the name as written: Weapon (p. 81, PDF 83)");
  R.LabelOf("Natural Attack", s);
  Check.Check(s = "Natural Attack (p. ?)", "LabelOf: Natural Attack (p. ?)");
  R.PageText(NIL, s);
  Check.Check(s = "p. ?", "PageText of NIL: p. ?");
  R.PageText(R.Find("Wind Powered"), s);
  Check.Check(s = "p. 116, PDF 118", "PageText: p. 116, PDF 118");
  R.PageLabel("Secondary Attacks", R.AlternateAttacksPage, s);
  Check.Check(s = "Secondary Attacks (p. 82, PDF 84)", "PageLabel: a rule's page");
  Check.Check(R.PdfPage(NIL) = 0, "PdfPage of NIL is 0");
  Check.Check(R.PdfIndex(R.StagedStatCostPage) = 168, "PdfIndex: p. 166 is PDF 168")
END Labels;

PROCEDURE Numbers;
  VAR it: R.Item;
BEGIN
  it := R.Find("Highly Skilled");
  Check.Check((it.cost = 1) & (it.maxLevel = R.Unlimited), "Highly Skilled: 1 a Level, no highest Level");
  it := R.Find("Weapon Attack");
  Check.Check((it.cost = 4) & (R.Subject IN it.flags), "Weapon Attack: 4 a Level, names its weapon");
  it := R.Find("Own a Big Mecha");
  Check.Check((it.cost = 4) & (it.minCost = 1) & (it.nOptions = 1) & (it.option[0].amount = -1)
    & (it.option[0].maxTimes = R.Unlimited), "Own a Big Mecha: 4 a Level, -1 for each Less Powerful, at least 1");
  it := R.Find("Environmental Control");
  Check.Check((it.cost = 0) & (it.nOptions = 9), "Environmental Control: 9 choices");
  it := R.Find("Flight");
  Check.Check((it.option[0].amount = 4) & it.option[0].perLevel & (it.option[0].group = 1)
    & (it.option[2].amount = -1) & ~it.option[2].perLevel & (it.option[2].group < 0),
    "Flight: 4 a Level hovering, -1 on the total as a skimmer");
  it := R.Find("A.I.");
  Check.Check((it.kind = R.MechaAttribute) & (R.MechaOnly IN it.flags) & (it.cost = 2), "A.I.: Mecha Only, 2 a Level");
  it := R.Find("Mechanical Transformation");
  Check.Check(~(R.MechaOnly IN it.flags), "Mechanical Transformation: not Mecha Only");
  it := R.Find("Diminutive");
  Check.Check((it.cost = 3) & (it.maxLevel = 2) & (R.Special IN it.flags), "Diminutive: 3 BP a rank, 2 ranks, Special");
  it := R.Find("Awkward Size");
  Check.Check(it.maxLevel = 6, "Awkward Size: 6 ranks");
  it := R.Find("Ageism");
  Check.Check((it.cost = 1) & (it.maxLevel = 2) & ~(R.Special IN it.flags), "Ageism: 1 BP a rank, 2 ranks, Normal");
  it := R.Find("Crew Requirement");
  Check.Check((it.kind = R.MechaDefect) & (it.maxLevel = 6), "Crew Requirement: a Mecha-Only Defect of 6 ranks");
  it := R.Find("Contagious");
  Check.Check((it.slots = 3) & (it.maxTimes = 2) & (R.NeedsDetail IN it.flags), "Contagious: 3 slots, twice");
  it := R.Find("Soul Attack");
  Check.Check((it.slots = 5) & (it.altSlots = 2) & (R.NotPersonalGear IN it.flags), "Soul Attack: 5 slots, 2 with No Damage");
  it := R.Find("Area Effect");
  Check.Check(it.maxTimes = R.Unlimited, "Area Effect: as often as wanted");
  it := R.Find("Exposed (Mecha Only)");
  Check.Check((it.kind = R.Disability) & (R.MechaOnly IN it.flags), "Exposed (Mecha Only): a Mecha Only Disability");
  Check.Check(R.Excludes(R.Find("Melee"), R.Find("Stoppable")) & R.Excludes(R.Find("Stoppable"), R.Find("Melee")),
    "Excludes: Melee and Stoppable, either way");
  Check.Check(~R.Excludes(R.Find("Accurate"), R.Find("Aura")), "Excludes: not Accurate and Aura")
END Numbers;

PROCEDURE Tables;
  VAR it: R.Item; g, total: INTEGER; ok: BOOLEAN;
BEGIN
  it := R.FindKind(R.Skill, "Driving");
  Check.Check((it.skillCost[R.HotRodsAndGuns] = 6) & (it.skillCost[R.Cyberpunk] = 3), "Table 2-4: Driving 3 Cyberpunk, 6 Hot Rods and Guns");
  it := R.Find("Heavy Weapons");
  Check.Check(it.skillCost[R.TeenageRomance] = R.NotOffered, "Table 2-4: no Heavy Weapons in Teenage Romance");
  it := R.Find("Computers");
  Check.Check(it.skillCost[R.MedievalFantasy] = R.NotOffered, "Table 2-4: no Computers in Medieval Fantasy");
  ok := TRUE;
  FOR g := 0 TO R.NGenres - 1 DO
    R.GenreName(g, s); IF R.FindGenre(s) # g THEN ok := FALSE; Note(s, "not found") END
  END;
  Check.Check(ok, "every genre is found by its name");
  Check.Check(R.FindGenre("modern military") = R.ModernMilitary, "FindGenre ignores case");
  Check.Check(R.FindGenre("Western") = -1, "FindGenre: -1 for a genre Table 2-4 doesn't have");
  R.GenreName(R.HotRodsAndGuns, s);
  Check.Check(s = "Hot Rods and Guns", "GenreName: Hot Rods and Guns");
  total := 0; FOR g := 1 TO 12 DO INC(total, R.StagedStatCost(g)) END;
  Check.Check((R.StagedStatCost(5) = 5) & (R.StagedStatCost(6) = 7) & (R.StagedStatCost(9) = 14)
    & (R.StagedStatCost(12) = 24) & (total = 117), "Table 4-7: Staged Stat Costs 5, 7, 14, 24")
END Tables;

BEGIN
  Counts; Items; Finding; Labels; Numbers; Tables;
  Check.Summary
END TestRules.
