MODULE Besm2Calc; (* The numbers of a character and its mecha, computed from the rules *)

(* PLAN.md, A2 and Part B step 2.  Every cost, damage, derived value,
   total and warning of a BESM2ER character or mecha:

   - Character Points: the Stats (1 a point, or the Staged Stat Cost,
     p. 166), the Attributes (cost a Level and their options, p. 16),
     Weapon Attacks (4 a Level for the primary, 2 or 1 for a secondary,
     +5 for a Different Gunner, p. 82), less the Defects' Bonus Points
     (p. 100);
   - derived values (pp. 129-130): ACV, DCV, Health Points, Energy
     Points, Shock Value, and the Armour Rating (pp. 40, 48);
   - Skill Points (p. 117): 20, +10 a Level of Highly Skilled, -10 a
     rank of Unskilled, spent at the genre's costs (Table 2-4, p. 119, PDF 121);
   - Mecha Points (p. 59): 20 a Level of Own a Big Mecha, 5 fewer for
     each "less powerful", spent on the mecha's Attributes less its
     Defects; a mecha's 40 Health Points and Toughness's 20 a Level
     (p. 99).

   An entity (a character or a mecha) is given as records the client
   allocates and sets up with Init and Add (Besm2Character, step 4,
   extends them with names, subjects and details), never here.  Every
   computed number is a Number, which also holds the user's override
   (A4, `overrides`); Compute reads the overrides of the numbers others
   are computed from (an item's points, ACV, HP) so that an override
   counts downstream, sets every computed value, and leaves the
   overrides alone.

   Decided here (PLAN.md, step 2): Place of Power's Energy Points are a
   pool of their own (p. 63), not added to EP; Optimized armour (pp. 40,
   48) counts in the Armour Rating like any other; Diminutive's divided
   Health Points are rounded down, as the book gives no rule.

   Imports nothing of the window or the files, so its tests need no
   display. *)

IMPORT R := Besm2Rules;

CONST
  NStats* = 3;  Body* = 0; Mind* = 1; Soul* = 2;  (* Entity.stat's indexes *)
  NoGenre* = -1;    (* Creation.genre unset *)
  Unset* = -1;      (* Creation.skillPoints: the rule's number *)

  (* Warning codes.  Each names what it is about in its attribute,
     defect, skill, Weapon Ability or Disability (mod), or Stat; NIL (or
     stat -1) for the entity as a whole. *)
  UnknownItem* = 0;    (* attribute, defect, skill or mod: a name Besm2Rules doesn't have *)
  LevelRange* = 1;     (* attribute: Level not 1 to its highest; defect: rank not 1 to its highest; skill: not 1-6 *)
  StatRange* = 2;      (* stat: not 1-12 (p. 16), or above the campaign's stat-ceiling *)
  TwoAtTwelve* = 3;    (* more than one Stat at 12 (p. 16) *)
  TooManyDefects* = 4; (* a character with more than 8 Defects (p. 100) *)
  OverCharacterPoints* = 5;  (* spent more than the creation's Character Points (p. 13) *)
  OverSkillPoints* = 6;      (* spent more Skill Points than it has (p. 117) *)
  OverMechaPoints* = 7;      (* a mecha spent more than its owners' Own a Big Mecha gives (p. 59) *)
  Excluded* = 8;       (* mod: goes with an earlier mod of the attack as the book forbids *)
  TooOften* = 9;       (* mod: taken more times than it may be; attribute: an option, likewise *)
  OptionClash* = 10;   (* attribute: two options of one choice *)
  NotOffered* = 11;    (* skill: the genre doesn't have it (Table 2-4's "-") *)
  LowDamage* = 12;     (* attribute: a Weapon Attack under 15 damage (5 as Personal Gear) without No Damage (p. 82) *)
  NotPersonalGear* = 13;  (* mod: not for a Personal Gear weapon (p. 83) *)
  MechaOnly* = 14;     (* attribute or defect: for mecha only, on a character *)
  OverBonusCeiling* = 15;  (* the Defects give more than the campaign's bonus-point-ceiling *)
  SecondaryAbove* = 16;    (* attribute: a secondary Weapon Attack above its primary's Level (p. 82) *)
  GunnerNotMecha* = 17;    (* attribute: a Different Gunner on a character's weapon (p. 82) *)
  SkilledAndUnskilled* = 18;  (* Highly Skilled with Unskilled (p. 112) *)
  NoGenreSet* = 19;    (* skills, but no genre to price them by *)
  NoCost* = 20;        (* attribute: its cost is the GM's (or its Level's choice), and no override gives it *)
  StatPointsAbove* = 21;  (* the Stats cost more than the campaign's stat-points-ceiling (p. 16) *)
  StatPointsBelow* = 22;  (* the Stats cost less than the campaign's stat-points-floor (p. 16) *)

  MaxSkillLevel = 6;
  MaxStat* = 12;
  MaxDefects = 8;       (* recommended, p. 100 *)
  BaseSkillPoints = 20; SkillPointsALevel = 10;
  DamageALevel = 15; GearDamageALevel = 5;
  PrimaryCost = 4; SameLevelCost = 2; LowerLevelCost = 1;
  GunnerCost = 5;
  MechaPointsALevel = 20; LessPowerfulPoints = 5;
  MechaHP = 40; ToughnessHP = 20;
  BookAutoFireSlots* = 3;

TYPE
  (* A number on the sheet: the computed value, and the override the
     user typed, if any. *)
  Number* = RECORD
    value-: INTEGER;
    overridden-: BOOLEAN;
    ovValue-: INTEGER
  END;

  Entity* = POINTER TO EntityDesc;

  (* The campaign's own Skill (A4, `house-skills`): its Skill Points a
     Level by genre, R.NotOffered where it isn't available. *)
  HouseSkill* = POINTER TO HouseSkillDesc;
  HouseSkillDesc* = RECORD
    next*: HouseSkill;
    cost*: ARRAY R.NGenres OF INTEGER
  END;

  (* A4's `creation`: the campaign's numbers and options.  0 for
     characterPoints, statCeiling, bonusCeiling, statPointsCeiling or
     statPointsFloor: none given, so no limit is checked.  statCeiling
     is on each Stat; statPointsCeiling and statPointsFloor on the
     Character Points the Stats cost in all (p. 16, an optional rule). *)
  Creation* = RECORD
    characterPoints*, backgroundPoints*: INTEGER;
    genre*: INTEGER;        (* R.Cyberpunk .. R.TeenageRomance, or NoGenre *)
    skillPoints*: INTEGER;  (* the GM's, or Unset *)
    stagedStatCost*: BOOLEAN;
    statCeiling*, bonusCeiling*: INTEGER;
    statPointsCeiling*, statPointsFloor*: INTEGER;
    autoFireSlots*: INTEGER;  (* 3, or 1 as the book's examples (open question 12) *)
    houseSkills*: HouseSkill
  END;

  (* A Weapon Ability or Disability.  countsAs is A4's `counts-as`, the
     slots it counts as in all; 0 when left out: the book's slots,
     taken once (Auto-Fire's from Creation.autoFireSlots). *)
  Mod* = POINTER TO ModDesc;
  ModDesc* = RECORD
    next*: Mod;
    item*: R.Item;      (* NIL: a name Besm2Rules doesn't have *)
    countsAs*: INTEGER;
    slots-: INTEGER     (* what it counted as in the last Compute *)
  END;

  (* An Attribute or Mecha Attribute, at level, with each of its item's
     options taken times[i] times (a choice of a group > 0 left at 0
     everywhere is its first option).  A Weapon Attack has its
     Abilities and Disabilities; an Own a Big Mecha its mecha. *)
  Attr* = POINTER TO AttrDesc;
  AttrDesc* = RECORD
    next*: Attr;
    item*: R.Item;      (* NIL: a name Besm2Rules doesn't have *)
    level*: INTEGER;
    times*: ARRAY R.MaxOptions OF INTEGER;
    abilities*, disabilities*: Mod;
    primary*: BOOLEAN;          (* A4's `primary`: the user's primary attack *)
    differentGunner*: BOOLEAN;  (* a mecha weapon of its own gunner, +5 MP (p. 82) *)
    personalGear*: BOOLEAN;     (* a weapon of Personal Gear: no points of its own, a third of the damage (p. 83) *)
    mecha*: Entity;             (* Own a Big Mecha's, A4's `subject`; NIL if not in the file *)
    points*, damage*: Number;
    weapon-, isPrimary-: BOOLEAN  (* a Weapon Attack; and the primary, after Compute *)
  END;

  Defect* = POINTER TO DefectDesc;
  DefectDesc* = RECORD
    next*: Defect;
    item*: R.Item;      (* NIL: a name Besm2Rules doesn't have *)
    rank*: INTEGER;     (* A4's `level` *)
    points*: Number     (* negative, as the files write it: -BP *)
  END;

  (* A Skill: a rulebook one (item), or a house one (house, whose costs
     win); specs is how many specialisations it lists, the first free
     and each other 1 SP (p. 118). *)
  Skill* = POINTER TO SkillDesc;
  SkillDesc* = RECORD
    next*: Skill;
    item*: R.Item;
    house*: HouseSkill;
    level*, specs*: INTEGER;
    points*: Number
  END;

  Warning* = POINTER TO WarningDesc;
  WarningDesc* = RECORD
    next-: Warning;
    code-: INTEGER;
    attr-: Attr; defect-: Defect; skill-: Skill; mod-: Mod;
    stat-: INTEGER      (* Body, Mind, Soul, or -1 *)
  END;

  EntityDesc* = RECORD
    isMecha*: BOOLEAN;
    owner*: Entity;     (* a mecha's, set by Compute of its owner; its creation prices the mecha *)
    stat*: ARRAY NStats OF INTEGER;
    statPoints*: ARRAY NStats OF Number;
    attrs*: Attr; defects*: Defect; skills*: Skill;  (* in the order added *)
    creation*: Creation;
    acv*, dcv*, hp*, ep*, sv*, ar*: Number;
    hasAR-: BOOLEAN;    (* it has Heavy or Light Armour *)
    (* The totals: Character Points (Mecha Points for a mecha) spent on
       Stats and Attributes, the Defects' Bonus Points (>= 0), spent
       less Bonus Points, and what it has to spend (0 for a mecha no
       owner gives points); Skill Points it has and spent. *)
    statTotal-, attrTotal-, bonusPoints-, spent-, available-: INTEGER;
    skillPoints-, skillSpent-: INTEGER;
    warnings-: Warning  (* from the last Compute, in the order found *)
  END;

VAR
  weaponAttack, combatMastery, ineptCombat, damnHealthy, notSoTough, diminutive,
  energyBonus, highlySkilled, unskilled, heavyArmour, lightArmour, toughness,
  ownABigMecha, noDamage, autoFire: R.Item;

(* ---- Numbers ---- *)

PROCEDURE Set(VAR n: Number; value: INTEGER);
BEGIN n.value := value
END Set;

PROCEDURE Override*(VAR n: Number; value: INTEGER);
BEGIN n.overridden := TRUE; n.ovValue := value
END Override;

(* Back to the computed value. *)
PROCEDURE Clear*(VAR n: Number);
BEGIN n.overridden := FALSE; n.ovValue := 0
END Clear;

(* The value in effect: the override if there is one. *)
PROCEDURE Value*(VAR n: Number): INTEGER;
BEGIN IF n.overridden THEN RETURN n.ovValue ELSE RETURN n.value END
END Value;

PROCEDURE AppendChar(c: CHAR; VAR s: ARRAY OF CHAR);
  VAR i: INTEGER;
BEGIN
  i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
  IF i < LEN(s) - 1 THEN s[i] := c; s[i + 1] := 0X END
END AppendChar;

PROCEDURE Format(n: INTEGER; VAR s: ARRAY OF CHAR);
  VAR d: ARRAY 12 OF CHAR; i: INTEGER;
BEGIN
  s[0] := 0X;
  IF n < 0 THEN AppendChar("-", s); n := -n END;
  i := 0; REPEAT d[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  WHILE i > 0 DO DEC(i); AppendChar(d[i], s) END
END Format;

(* The number in effect, in decimal. *)
PROCEDURE Text*(VAR n: Number; VAR s: ARRAY OF CHAR);
BEGIN Format(Value(n), s)
END Text;

(* The computed number, whatever the override. *)
PROCEDURE ComputedText*(VAR n: Number; VAR s: ARRAY OF CHAR);
BEGIN Format(n.value, s)
END ComputedText;

(* Sets n's override from what the user typed in its box: blank clears
   it, an integer (-999999..999999) sets it; FALSE, n unchanged, for
   anything else. *)
PROCEDURE Parse*(s: ARRAY OF CHAR; VAR n: Number): BOOLEAN;
  VAR i, j, v, digits: INTEGER; neg: BOOLEAN;
BEGIN
  i := 0; WHILE (i < LEN(s)) & ((s[i] = " ") OR (s[i] = 9X)) DO INC(i) END;
  j := i; WHILE (j < LEN(s)) & (s[j] # 0X) DO INC(j) END;
  WHILE (j > i) & ((s[j - 1] = " ") OR (s[j - 1] = 9X)) DO DEC(j) END;
  IF j = i THEN Clear(n); RETURN TRUE END;
  neg := FALSE;
  IF s[i] = "-" THEN neg := TRUE; INC(i) END;
  v := 0; digits := 0;
  WHILE (i < j) & (s[i] >= "0") & (s[i] <= "9") & (digits < 6) DO
    v := 10 * v + ORD(s[i]) - ORD("0"); INC(i); INC(digits)
  END;
  IF (digits = 0) OR (i < j) THEN RETURN FALSE END;
  IF neg THEN v := -v END;
  Override(n, v);
  RETURN TRUE
END Parse;

PROCEDURE InitNumber(VAR n: Number);
BEGIN n.value := 0; Clear(n)
END InitNumber;

(* ---- Building an entity ---- *)

PROCEDURE InitCreation*(VAR c: Creation);
BEGIN
  c.characterPoints := 0; c.backgroundPoints := 0; c.genre := NoGenre; c.skillPoints := Unset;
  c.stagedStatCost := FALSE; c.statCeiling := 0; c.bonusCeiling := 0;
  c.statPointsCeiling := 0; c.statPointsFloor := 0;
  c.autoFireSlots := BookAutoFireSlots; c.houseSkills := NIL
END InitCreation;

(* A character (isMecha FALSE) with each Stat at 1, or a mecha. *)
PROCEDURE InitEntity*(e: Entity; isMecha: BOOLEAN);
  VAR i: INTEGER;
BEGIN
  e.isMecha := isMecha; e.owner := NIL;
  FOR i := 0 TO NStats - 1 DO e.stat[i] := 1; InitNumber(e.statPoints[i]) END;
  e.attrs := NIL; e.defects := NIL; e.skills := NIL;
  InitCreation(e.creation);
  InitNumber(e.acv); InitNumber(e.dcv); InitNumber(e.hp); InitNumber(e.ep); InitNumber(e.sv);
  InitNumber(e.ar); e.hasAR := FALSE;
  e.statTotal := 0; e.attrTotal := 0; e.bonusPoints := 0; e.spent := 0; e.available := 0;
  e.skillPoints := 0; e.skillSpent := 0; e.warnings := NIL
END InitEntity;

PROCEDURE InitAttr*(a: Attr; item: R.Item; level: INTEGER);
  VAR i: INTEGER;
BEGIN
  a.next := NIL; a.item := item; a.level := level;
  FOR i := 0 TO R.MaxOptions - 1 DO a.times[i] := 0 END;
  a.abilities := NIL; a.disabilities := NIL;
  a.primary := FALSE; a.differentGunner := FALSE; a.personalGear := FALSE; a.mecha := NIL;
  InitNumber(a.points); InitNumber(a.damage);
  a.weapon := (item # NIL) & (item = weaponAttack); a.isPrimary := FALSE
END InitAttr;

PROCEDURE InitMod*(m: Mod; item: R.Item; countsAs: INTEGER);
BEGIN m.next := NIL; m.item := item; m.countsAs := countsAs; m.slots := 0
END InitMod;

PROCEDURE InitDefect*(d: Defect; item: R.Item; rank: INTEGER);
BEGIN d.next := NIL; d.item := item; d.rank := rank; InitNumber(d.points)
END InitDefect;

PROCEDURE InitSkill*(s: Skill; item: R.Item; house: HouseSkill; level, specs: INTEGER);
BEGIN
  s.next := NIL; s.item := item; s.house := house; s.level := level; s.specs := specs;
  InitNumber(s.points)
END InitSkill;

PROCEDURE InitHouseSkill*(h: HouseSkill);
  VAR g: INTEGER;
BEGIN h.next := NIL; FOR g := 0 TO R.NGenres - 1 DO h.cost[g] := R.NotOffered END
END InitHouseSkill;

(* The option of a's item labelled label is taken times times. *)
PROCEDURE SetOption*(a: Attr; label: ARRAY OF CHAR; times: INTEGER);
  VAR i: INTEGER;
BEGIN
  ASSERT(a.item # NIL);
  i := 0; WHILE (i < a.item.nOptions) & ~R.SameName(a.item.option[i].label, label) DO INC(i) END;
  ASSERT(i < a.item.nOptions);
  a.times[i] := times
END SetOption;

PROCEDURE AddAttr*(e: Entity; a: Attr);
  VAR p: Attr;
BEGIN
  IF e.attrs = NIL THEN e.attrs := a ELSE p := e.attrs; WHILE p.next # NIL DO p := p.next END; p.next := a END
END AddAttr;

PROCEDURE AddMod*(VAR list: Mod; m: Mod);
  VAR p: Mod;
BEGIN
  IF list = NIL THEN list := m ELSE p := list; WHILE p.next # NIL DO p := p.next END; p.next := m END
END AddMod;

PROCEDURE AddDefect*(e: Entity; d: Defect);
  VAR p: Defect;
BEGIN
  IF e.defects = NIL THEN e.defects := d ELSE p := e.defects; WHILE p.next # NIL DO p := p.next END; p.next := d END
END AddDefect;

PROCEDURE AddSkill*(e: Entity; s: Skill);
  VAR p: Skill;
BEGIN
  IF e.skills = NIL THEN e.skills := s ELSE p := e.skills; WHILE p.next # NIL DO p := p.next END; p.next := s END
END AddSkill;

PROCEDURE AddHouseSkill*(VAR c: Creation; h: HouseSkill);
  VAR p: HouseSkill;
BEGIN
  IF c.houseSkills = NIL THEN c.houseSkills := h
  ELSE p := c.houseSkills; WHILE p.next # NIL DO p := p.next END; p.next := h
  END
END AddHouseSkill;

(* ---- Warnings ---- *)

PROCEDURE Warn(e: Entity; code: INTEGER; a: Attr; d: Defect; s: Skill; m: Mod; stat: INTEGER);
  VAR w, p: Warning;
BEGIN
  NEW(w); w.next := NIL; w.code := code;
  w.attr := a; w.defect := d; w.skill := s; w.mod := m; w.stat := stat;
  IF e.warnings = NIL THEN e.warnings := w
  ELSE p := e.warnings; WHILE p.next # NIL DO p := p.next END; p.next := w
  END
END Warn;

(* Whether e has a warning code (about a, if a isn't NIL). *)
PROCEDURE HasWarning*(e: Entity; code: INTEGER; a: Attr): BOOLEAN;
  VAR w: Warning;
BEGIN
  w := e.warnings;
  WHILE (w # NIL) & ((w.code # code) OR (a # NIL) & (w.attr # a)) DO w := w.next END;
  RETURN w # NIL
END HasWarning;

(* How many warnings e has. *)
PROCEDURE WarningCount*(e: Entity): INTEGER;
  VAR w: Warning; n: INTEGER;
BEGIN
  n := 0; w := e.warnings; WHILE w # NIL DO INC(n); w := w.next END;
  RETURN n
END WarningCount;

(* ---- Helpers ---- *)

PROCEDURE Max(a, b: INTEGER): INTEGER;
BEGIN IF a > b THEN RETURN a ELSE RETURN b END
END Max;

PROCEDURE Min(a, b: INTEGER): INTEGER;
BEGIN IF a < b THEN RETURN a ELSE RETURN b END
END Min;

(* The total Level of the item's Attributes on e (or rank of its Defects). *)
PROCEDURE Levels(e: Entity; it: R.Item): INTEGER;
  VAR a: Attr; d: Defect; n: INTEGER;
BEGIN
  n := 0;
  IF it.kind IN {R.Defect, R.MechaDefect} THEN
    d := e.defects; WHILE d # NIL DO IF d.item = it THEN INC(n, d.rank) END; d := d.next END
  ELSE
    a := e.attrs; WHILE a # NIL DO IF a.item = it THEN INC(n, a.level) END; a := a.next END
  END;
  RETURN n
END Levels;

(* The creation that prices e: its owner's for a mecha. *)
PROCEDURE Rules(e: Entity; VAR c: Creation);
BEGIN
  IF e.isMecha & (e.owner # NIL) THEN c := e.owner.creation ELSE c := e.creation END
END Rules;

(* ---- Stats ---- *)

PROCEDURE ComputeStats(e: Entity);
  VAR i, twelves, v: INTEGER;
BEGIN
  twelves := 0; e.statTotal := 0;
  FOR i := 0 TO NStats - 1 DO
    v := e.stat[i];
    IF (v < 1) OR (v > MaxStat) OR (e.creation.statCeiling > 0) & (v > e.creation.statCeiling) THEN
      Warn(e, StatRange, NIL, NIL, NIL, NIL, i)
    END;
    IF v = MaxStat THEN INC(twelves) END;
    IF e.creation.stagedStatCost & (v >= 1) & (v <= MaxStat) THEN Set(e.statPoints[i], R.StagedStatCost(v))
    ELSE Set(e.statPoints[i], v)
    END;
    INC(e.statTotal, Value(e.statPoints[i]))
  END;
  IF twelves > 1 THEN Warn(e, TwoAtTwelve, NIL, NIL, NIL, NIL, -1) END;
  IF (e.creation.statPointsCeiling > 0) & (e.statTotal > e.creation.statPointsCeiling) THEN
    Warn(e, StatPointsAbove, NIL, NIL, NIL, NIL, -1)
  END;
  IF (e.creation.statPointsFloor > 0) & (e.statTotal < e.creation.statPointsFloor) THEN
    Warn(e, StatPointsBelow, NIL, NIL, NIL, NIL, -1)
  END
END ComputeStats;

(* ---- Attributes ---- *)

(* a's points before any Weapon Attack rule: its cost a Level, with its
   options' points a Level, times its Level, with its options' points
   on the total, and at least its item's least cost.  Warns of clashing
   or repeated options, and of a cost no rule gives. *)
PROCEDURE AttrPoints(e: Entity; a: Attr): INTEGER;
  VAR it: R.Item; i, j, perLevel, flat, n: INTEGER; chosen: BOOLEAN;
BEGIN
  it := a.item; perLevel := it.cost; flat := 0;
  FOR i := 0 TO it.nOptions - 1 DO
    n := a.times[i];
    IF (it.option[i].group > 0) & (n = 0) THEN
      (* A required choice left open is its first option. *)
      chosen := FALSE;
      FOR j := 0 TO it.nOptions - 1 DO
        IF (it.option[j].group = it.option[i].group) & (a.times[j] > 0) THEN chosen := TRUE END
      END;
      j := 0; WHILE it.option[j].group # it.option[i].group DO INC(j) END;
      IF ~chosen & (j = i) THEN n := 1 END
    END;
    IF n > it.option[i].maxTimes THEN Warn(e, TooOften, a, NIL, NIL, NIL, -1) END;
    IF (n > 0) & (it.option[i].group # 0) THEN
      FOR j := 0 TO i - 1 DO
        IF (it.option[j].group = it.option[i].group) & (a.times[j] > 0) THEN
          Warn(e, OptionClash, a, NIL, NIL, NIL, -1)
        END
      END
    END;
    IF it.option[i].perLevel THEN INC(perLevel, n * it.option[i].amount)
    ELSE INC(flat, n * it.option[i].amount)
    END
  END;
  IF ((perLevel = 0) OR (R.GmCost IN it.flags)) & ~a.points.overridden THEN
    Warn(e, NoCost, a, NIL, NIL, NIL, -1)
  END;
  RETURN Max(it.minCost, perLevel * a.level + flat)
END AttrPoints;

(* The slots Weapon Ability or Disability it counts as, taken once, as
   Creation c prices it: the book's, Auto-Fire's c's; 1 for NIL. *)
PROCEDURE SlotsOnce(it: R.Item; VAR c: Creation): INTEGER;
BEGIN
  IF it = NIL THEN RETURN 1
  ELSIF it = autoFire THEN RETURN c.autoFireSlots
  ELSE RETURN it.slots
  END
END SlotsOnce;

(* The same, as e's campaign prices it (a mecha's owner's). *)
PROCEDURE OnceSlots*(e: Entity; it: R.Item): INTEGER;
  VAR c: Creation;
BEGIN Rules(e, c); RETURN SlotsOnce(it, c)
END OnceSlots;

(* The slots m counts as, as Creation c prices it. *)
PROCEDURE Slots(m: Mod; VAR c: Creation): INTEGER;
BEGIN
  IF m.countsAs > 0 THEN RETURN m.countsAs ELSE RETURN SlotsOnce(m.item, c) END
END Slots;

(* How many times m is taken: its slots over the book's for one. *)
PROCEDURE Times*(m: Mod): INTEGER;
BEGIN
  IF (m.countsAs = 0) OR (m.item = NIL) OR (m.item.slots = 0) THEN RETURN 1
  ELSE RETURN Max(1, m.countsAs DIV m.item.slots)
  END
END Times;

(* Checks one list of mods of a, and gives its slots. *)
PROCEDURE ModSlots(e: Entity; a: Attr; list: Mod; VAR c: Creation): INTEGER;
  VAR m: Mod; n: INTEGER;
BEGIN
  n := 0; m := list;
  WHILE m # NIL DO
    m.slots := Slots(m, c); INC(n, m.slots);
    IF m.item = NIL THEN Warn(e, UnknownItem, a, NIL, NIL, m, -1)
    ELSE
      IF Times(m) > m.item.maxTimes THEN Warn(e, TooOften, a, NIL, NIL, m, -1) END;
      IF a.personalGear & (R.NotPersonalGear IN m.item.flags) THEN Warn(e, NotPersonalGear, a, NIL, NIL, m, -1) END;
      IF (R.MechaOnly IN m.item.flags) & ~e.isMecha THEN Warn(e, MechaOnly, a, NIL, NIL, m, -1) END
    END;
    m := m.next
  END;
  RETURN n
END ModSlots;

(* Whether m excludes, or repeats, a mod before it in a's lists. *)
PROCEDURE CheckExclusions(e: Entity; a: Attr);
  VAR m, p: Mod; lists: ARRAY 2 OF Mod; i, j: INTEGER; stop: BOOLEAN;
BEGIN
  lists[0] := a.abilities; lists[1] := a.disabilities;
  FOR i := 0 TO 1 DO
    m := lists[i];
    WHILE m # NIL DO
      IF m.item # NIL THEN
        stop := FALSE; j := 0;
        WHILE (j <= i) & ~stop DO
          p := lists[j];
          WHILE (p # NIL) & (p # m) & ~stop DO
            IF (p.item # NIL) & R.Excludes(p.item, m.item) THEN
              Warn(e, Excluded, a, NIL, NIL, m, -1); stop := TRUE
            END;
            p := p.next
          END;
          INC(j)
        END
      END;
      m := m.next
    END
  END
END CheckExclusions;

PROCEDURE HasMod(list: Mod; it: R.Item): BOOLEAN;
BEGIN
  WHILE (list # NIL) & (list.item # it) DO list := list.next END;
  RETURN list # NIL
END HasMod;

(* A Weapon Attack's damage (p. 82): 15 a Level, less 15 a slot of its
   Abilities, more 15 a slot of its Disabilities, never below 0; 5 instead of 15 as
   Personal Gear (p. 83); 0 with No Damage. *)
PROCEDURE ComputeDamage(e: Entity; a: Attr; VAR c: Creation);
  VAR n, each: INTEGER;
BEGIN
  n := a.level - ModSlots(e, a, a.abilities, c) + ModSlots(e, a, a.disabilities, c);
  IF n < 0 THEN n := 0 END;  (* more Ability slots than Levels: no damage, and warned *)
  CheckExclusions(e, a);
  IF a.personalGear THEN each := GearDamageALevel ELSE each := DamageALevel END;
  IF HasMod(a.disabilities, noDamage) THEN Set(a.damage, 0)
  ELSE
    Set(a.damage, each * n);
    IF Value(a.damage) < each THEN Warn(e, LowDamage, a, NIL, NIL, NIL, -1) END
  END;
  IF a.differentGunner & ~e.isMecha THEN Warn(e, GunnerNotMecha, a, NIL, NIL, NIL, -1) END
END ComputeDamage;

(* The primary attack (p. 82): the one marked primary, else the first of
   the highest Level, of the Weapon Attacks that aren't Personal Gear. *)
PROCEDURE Primary(e: Entity): Attr;
  VAR a, best: Attr;
BEGIN
  best := NIL; a := e.attrs;
  WHILE a # NIL DO
    IF a.weapon & ~a.personalGear THEN
      IF a.primary THEN RETURN a END;
      IF (best = NIL) OR (a.level > best.level) THEN best := a END
    END;
    a := a.next
  END;
  RETURN best
END Primary;

PROCEDURE ComputeAttrs(e: Entity);
  VAR a, primary: Attr; c: Creation; p: INTEGER;
BEGIN
  Rules(e, c);
  primary := Primary(e);
  e.attrTotal := 0; a := e.attrs;
  WHILE a # NIL DO
    a.weapon := (a.item # NIL) & (a.item = weaponAttack);
    a.isPrimary := a = primary;
    IF a.item = NIL THEN
      Warn(e, UnknownItem, a, NIL, NIL, NIL, -1); Set(a.points, 0)
    ELSE
      IF (a.level < 1) OR (a.level > a.item.maxLevel) THEN Warn(e, LevelRange, a, NIL, NIL, NIL, -1) END;
      IF (R.MechaOnly IN a.item.flags) & ~e.isMecha THEN Warn(e, MechaOnly, a, NIL, NIL, NIL, -1) END;
      IF a.weapon THEN
        ComputeDamage(e, a, c);
        IF a.personalGear THEN p := 0
        ELSIF a.isPrimary THEN p := PrimaryCost * a.level
        ELSIF a.level = primary.level THEN p := SameLevelCost
        ELSIF a.level < primary.level THEN p := LowerLevelCost
        ELSE p := SameLevelCost; Warn(e, SecondaryAbove, a, NIL, NIL, NIL, -1)
        END;
        IF a.differentGunner THEN INC(p, GunnerCost) END;
        Set(a.points, p)
      ELSE
        Set(a.points, AttrPoints(e, a))
      END
    END;
    INC(e.attrTotal, Value(a.points));
    a := a.next
  END
END ComputeAttrs;

(* ---- Defects ---- *)

PROCEDURE ComputeDefects(e: Entity);
  VAR d: Defect; n: INTEGER;
BEGIN
  e.bonusPoints := 0; n := 0; d := e.defects;
  WHILE d # NIL DO
    IF d.item = NIL THEN
      Warn(e, UnknownItem, NIL, d, NIL, NIL, -1); Set(d.points, -d.rank)
    ELSE
      IF (d.rank < 1) OR (d.rank > d.item.maxLevel) THEN Warn(e, LevelRange, NIL, d, NIL, NIL, -1) END;
      IF (R.MechaOnly IN d.item.flags) & ~e.isMecha THEN Warn(e, MechaOnly, NIL, d, NIL, NIL, -1) END;
      Set(d.points, -d.item.cost * d.rank)
    END;
    DEC(e.bonusPoints, Value(d.points)); INC(n);
    d := d.next
  END;
  IF ~e.isMecha & (n > MaxDefects) THEN Warn(e, TooManyDefects, NIL, NIL, NIL, NIL, -1) END;
  IF (e.creation.bonusCeiling > 0) & (e.bonusPoints > e.creation.bonusCeiling) THEN
    Warn(e, OverBonusCeiling, NIL, NIL, NIL, NIL, -1)
  END
END ComputeDefects;

(* ---- Skills ---- *)

PROCEDURE ComputeSkills(e: Entity);
  VAR s: Skill; g, cost, hs, us: INTEGER; warned: BOOLEAN;
BEGIN
  hs := Levels(e, highlySkilled); us := Levels(e, unskilled);
  IF (hs > 0) & (us > 0) THEN Warn(e, SkilledAndUnskilled, NIL, NIL, NIL, NIL, -1) END;
  IF e.creation.skillPoints # Unset THEN e.skillPoints := e.creation.skillPoints
  ELSE e.skillPoints := BaseSkillPoints + SkillPointsALevel * (hs - us)
  END;
  g := e.creation.genre; warned := FALSE;
  e.skillSpent := 0; s := e.skills;
  WHILE s # NIL DO
    IF (s.level < 1) OR (s.level > MaxSkillLevel) THEN Warn(e, LevelRange, NIL, NIL, s, NIL, -1) END;
    IF (s.item = NIL) & (s.house = NIL) THEN Warn(e, UnknownItem, NIL, NIL, s, NIL, -1); cost := 0
    ELSIF g = NoGenre THEN
      IF ~warned THEN Warn(e, NoGenreSet, NIL, NIL, NIL, NIL, -1); warned := TRUE END;
      cost := 0
    ELSE
      IF s.house # NIL THEN cost := s.house.cost[g] ELSE cost := s.item.skillCost[g] END;
      IF cost = R.NotOffered THEN Warn(e, NotOffered, NIL, NIL, s, NIL, -1) END
    END;
    Set(s.points, cost * s.level + Max(0, s.specs - 1));
    INC(e.skillSpent, Value(s.points));
    s := s.next
  END;
  IF e.skillSpent > e.skillPoints THEN Warn(e, OverSkillPoints, NIL, NIL, NIL, NIL, -1) END
END ComputeSkills;

(* ---- Derived values ---- *)

(* The Armour Rating (pp. 40, 48): Heavy Armour 10 a Level (4 if
   Hidden), Light Armour 2, 5, 7, 10, 12, 15 by Level (its Level if
   Hidden). *)
PROCEDURE ArmourRating(e: Entity): INTEGER;
  VAR a: Attr; n, hidden: INTEGER;
BEGIN
  n := 0; e.hasAR := FALSE; a := e.attrs;
  WHILE a # NIL DO
    IF (a.item # NIL) & ((a.item = heavyArmour) OR (a.item = lightArmour)) THEN
      e.hasAR := TRUE;
      hidden := 0; WHILE ~R.SameName(a.item.option[hidden].label, "hidden") DO INC(hidden) END;
      IF a.item = heavyArmour THEN
        IF a.times[hidden] > 0 THEN INC(n, 4 * a.level) ELSE INC(n, 10 * a.level) END
      ELSE
        IF a.times[hidden] > 0 THEN INC(n, a.level) ELSE INC(n, 5 * a.level DIV 2) END
      END
    END;
    a := a.next
  END;
  RETURN n
END ArmourRating;

PROCEDURE ComputeDerived(e: Entity);
  VAR cv, ic, hp, dim: INTEGER;
BEGIN
  Set(e.ar, ArmourRating(e));
  IF e.isMecha THEN
    Set(e.hp, MechaHP + ToughnessHP * Levels(e, toughness))
  ELSE
    cv := (e.stat[Body] + e.stat[Mind] + e.stat[Soul]) DIV 3 + Levels(e, combatMastery);
    (* Inept Combat (p. 105) lowers it 1 a rank, but not below 1. *)
    ic := Levels(e, ineptCombat);
    IF ic > 0 THEN cv := Max(cv - ic, Min(cv, 1)) END;
    Set(e.acv, cv);
    Set(e.dcv, Value(e.acv) - 2);
    hp := (e.stat[Body] + e.stat[Soul]) * 5 + 10 * Levels(e, damnHealthy) - 10 * Levels(e, notSoTough);
    dim := Levels(e, diminutive);
    IF dim = 1 THEN hp := hp DIV 5 ELSIF dim >= 2 THEN hp := hp DIV 20 END;
    Set(e.hp, hp);
    Set(e.ep, (e.stat[Mind] + e.stat[Soul]) * 5 + 10 * Levels(e, energyBonus))
  END;
  (* Shock Value (p. 130): HP / 5, rounded up. *)
  hp := Max(0, Value(e.hp));
  Set(e.sv, (hp + 4) DIV 5)
END ComputeDerived;

(* ---- Mecha ---- *)

(* The Mecha Points one Own a Big Mecha gives (p. 59). *)
PROCEDURE MechaPoints*(a: Attr): INTEGER;
  VAR less: INTEGER;
BEGIN
  less := 0; WHILE ~R.SameName(a.item.option[less].label, "less powerful, 5 fewer MP") DO INC(less) END;
  RETURN MechaPointsALevel * a.level - LessPowerfulPoints * a.times[less]
END MechaPoints;

PROCEDURE Totals(e: Entity);
BEGIN
  e.spent := e.statTotal + e.attrTotal - e.bonusPoints;
  IF e.isMecha THEN
    (* No owner gives none: not the Mecha Points of one it had, gone
       since (removed, or its Own a Big Mecha renamed). *)
    IF e.owner = NIL THEN e.available := 0 END;
    IF (e.owner # NIL) & (e.spent > e.available) THEN Warn(e, OverMechaPoints, NIL, NIL, NIL, NIL, -1) END
  ELSE
    IF e.creation.characterPoints > 0 THEN e.available := e.creation.characterPoints + e.creation.backgroundPoints
    ELSE e.available := 0
    END;
    IF (e.creation.characterPoints > 0) & (e.spent > e.available) THEN
      Warn(e, OverCharacterPoints, NIL, NIL, NIL, NIL, -1)
    END
  END
END Totals;

PROCEDURE ComputeOne(e: Entity);
BEGIN
  e.warnings := NIL;
  IF e.isMecha THEN e.statTotal := 0 ELSE ComputeStats(e) END;
  ComputeAttrs(e);
  ComputeDefects(e);
  IF e.isMecha THEN e.skillPoints := 0; e.skillSpent := 0 ELSE ComputeSkills(e) END;
  ComputeDerived(e);
  Totals(e)
END ComputeOne;

(* Computes every number of e, and of each mecha its Own a Big Mecha
   Attributes give, which then has e as its owner and the Mecha Points
   of all of them.  A mecha given alone keeps its owner, if any, but
   not its Mecha Points: compute its owner. *)
PROCEDURE Compute*(e: Entity);
  VAR a: Attr;
BEGIN
  ComputeOne(e);
  IF ~e.isMecha THEN
    a := e.attrs;
    WHILE a # NIL DO
      IF (a.item = ownABigMecha) & (a.mecha # NIL) THEN a.mecha.owner := e; a.mecha.available := 0 END;
      a := a.next
    END;
    a := e.attrs;
    WHILE a # NIL DO
      IF (a.item = ownABigMecha) & (a.mecha # NIL) THEN INC(a.mecha.available, MechaPoints(a)) END;
      a := a.next
    END;
    a := e.attrs;
    WHILE a # NIL DO
      IF (a.item = ownABigMecha) & (a.mecha # NIL) & (a.mecha.owner = e) THEN ComputeOne(a.mecha) END;
      a := a.next
    END
  END
END Compute;

PROCEDURE Need(name: ARRAY OF CHAR): R.Item;
  VAR it: R.Item;
BEGIN it := R.Find(name); ASSERT(it # NIL); RETURN it
END Need;

BEGIN
  weaponAttack := Need("Weapon Attack"); combatMastery := Need("Combat Mastery");
  ineptCombat := Need("Inept Combat"); damnHealthy := Need("Damn Healthy!");
  notSoTough := Need("Not So Tough"); diminutive := Need("Diminutive");
  energyBonus := Need("Energy Bonus"); highlySkilled := Need("Highly Skilled");
  unskilled := Need("Unskilled"); heavyArmour := Need("Heavy Armour");
  lightArmour := Need("Light Armour"); toughness := Need("Toughness");
  ownABigMecha := Need("Own a Big Mecha"); noDamage := Need("No Damage");
  autoFire := Need("Auto-Fire")
END Besm2Calc.
