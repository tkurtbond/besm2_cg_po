MODULE Besm2Character; (* A file's characters and mecha: Besm2Calc's records, with their names and text *)

(* PLAN.md, Part B step 4.  An Entity is a Besm2Calc.Entity, its
   Attributes, Weapon Abilities and Disabilities, Defects, Skills and
   house Skills extended with what Besm2Calc doesn't need: names,
   subjects, details, elements, the 4E enhancements and limiters, notes,
   and which optional keys the file had, so that a file loaded and saved
   (Besm2Save) formats the same in pobesm2_fmt2.

   Each entity is read first by Besm2Entities, pobesm2_fmt2's loader
   (copied), so a file is accepted or refused, with the same messages,
   as pobesm2_fmt2 does.  Besm2Entities packs what it reads into the
   text the formatters print, so the entity's mapping is then read again
   here, into the records.  The keys Besm2Entities doesn't read (a
   Defect's `level`, a Weapon Attack's `primary`, `creation`) are
   checked here, in its words.

   Then the numbers, as in ova_cg_po's OvaCharacter: a number its
   mapping's `overrides:` lists is an override.  Every other number the
   file holds is compared with the one Besm2Calc computes; one that
   differs is kept as an override too, with a notice: the file is the
   user's (a GM's ruling, a hand edit, an item the rules here don't
   have), and nothing in it is lost.  A value that isn't a number
   (`value: ""`) is kept as written, with a notice.

   Decided here (2026-11-06):
   - A packed name (`name: "Weapon: Railgun"`, no `subject`) is split at
     its first ": " when the whole isn't a rulebook name (no rulebook
     name has a ":") and the part before is; it is saved packed again
     (packed), so --fill changes only numbers.  Aliases ("Weapon",
     "Hanger Queen") are kept as written.  Both are --upgrade's to
     change.
   - A Defect without `level` has the rank its points give (points ÷
     its Bonus Points a rank, at least 1).
   - A Weapon Attack with none of `abilities`, `disabilities` and
     `damage` is unstructured: its points are computed, but it has no
     damage to compare or save.
   - Unknown keys (`page:`, `bogus:`) and the `enhancements` and
     `limiters` are kept as small trees (Raw) and saved as they were,
     after the known keys.  Comments are lost.
   - A string or list the file had, even empty, is kept and saved, so a
     loaded file formats the same (empty-strings-2e); the generator
     makes none, and --check warns about them.

   Imports nothing of the window, so its tests need no display. *)

IMPORT C := Besm2Calc, R := Besm2Rules, Besm2Check, Besm2Entities, Besm2Text, Fyaml, FyamlStreams, Ropes;

CONST
  (* Raw.kind *)
  (* Notice.kind *)
  Difference* = Besm2Check.Difference; Warning* = Besm2Check.Warning; Error* = Besm2Check.Error;
  RawScalar* = 0; RawSequence* = 1; RawMapping* = 2;

  (* DerivedValue.slot: which of the entity's numbers it is *)
  NoSlot* = -1; ACV* = 0; DCV* = 1; HP* = 2; EP* = 3; SV* = 4; AR* = 5;

  (* Entity.creationKeys: the keys of `creation` (and its `options`)
     to write: those the file had, and those the generator sets. *)
  CharacterPointsKey* = 0; BackgroundPointsKey* = 1; GenreKey* = 2; SkillPointsKey* = 3;
  OptionsKey* = 4; StagedStatCostKey* = 5; StatCeilingKey* = 6; BonusCeilingKey* = 7;
  AutoFireSlotsKey* = 8; HouseSkillsKey* = 9;

  EntityKeys = "name, tagline, description, size, mecha, stats, derived, attributes, defects, skills, notes, creation";
  StatKeys = "name, value, points, overrides";
  DerivedKeys = "name, value, alternatives, overrides";
  AttrKeys = "name, subject, level, points, effective, details, elements, choices, enhancements, limiters, abilities, disabilities, damage, primary, different-gunner, overrides";
  DefectKeys = "name, subject, level, points, details, overrides";
  SkillKeys = "name, level, points, specialisations, overrides";
  CreationKeys = "character-points, background-points, genre, skill-points, options, house-skills";
  OptionKeys = "staged-stat-cost, stat-ceiling, bonus-point-ceiling, auto-fire-slots";
  HouseSkillKeys = "name, costs, stat, specializations";

TYPE
  Rope = Ropes.Rope;

  (* YAML kept as it was: an unknown key's value, or the enhancements
     and limiters.  A scalar has text and its style (Fyaml.StylePlain,
     ...); a collection its items or pairs, in first, each pair a Raw
     with its key. *)
  Raw* = POINTER TO RawDesc;
  RawDesc* = RECORD
    next*: Raw;
    key*: Rope;        (* in a mapping, or a list of extra keys: the key; else NIL *)
    kind*, style*: INTEGER;
    text*: Rope;
    first*: Raw
  END;

  Stat* = POINTER TO StatDesc;
  StatDesc* = RECORD
    next*: Stat;
    name*: Rope;
    index*: INTEGER;     (* C.Body, C.Mind, C.Soul; -1: not a Stat's name *)
    (* The value as written when it isn't an integer, or the name isn't a
       Stat's, saved as it is; else the value is the entity's
       stat[index]. *)
    valueIsText*: BOOLEAN; valueText*: Rope;
    (* A Stat's points are the entity's statPoints[index]; these are
       those of a name that isn't a Stat's. *)
    points*: C.Number;
    extra*: Raw;
    fPoints: INTEGER; listed: BOOLEAN
  END;

  DerivedValue* = POINTER TO DerivedValueDesc;
  DerivedValueDesc* = RECORD
    next*: DerivedValue;
    name*: Rope;
    slot*: INTEGER;      (* ACV .. AR, or NoSlot: a name it doesn't compute (DM) *)
    (* The value as written (valueText, NIL if empty): for NoSlot, or
       not an integer. *)
    valueIsText*: BOOLEAN; valueText*: Rope;
    hasAlternatives*: BOOLEAN; alternatives*: Besm2Text.List;
    extra*: Raw;
    fValue: INTEGER; listed: BOOLEAN
  END;

  (* A Weapon Ability or Disability.  name as written; countsAs 0: none
     written. *)
  Mod* = POINTER TO ModDesc;
  ModDesc* = RECORD (C.ModDesc)
    name*: Rope;
    hasDetail*: BOOLEAN; detail*: Rope
  END;

  (* An item of `choices`: name as written, its option of the
     attribute's item (-1: none of them), and how many times. *)
  Choice* = POINTER TO ChoiceDesc;
  ChoiceDesc* = RECORD
    next*: Choice;
    name*: Rope;
    option*, times*: INTEGER
  END;

  Attr* = POINTER TO AttrDesc;
  AttrDesc* = RECORD (C.AttrDesc)
    name*, subject*: Rope;
    hasSubject*: BOOLEAN;  (* a subject, from `subject` or the packed name *)
    packed*: BOOLEAN;      (* saved as one packed name, as the file had it *)
    levelIsText*: BOOLEAN; levelText*: Rope;  (* the level as written, when it isn't an integer *)
    hasEffective*, hasDetails*, hasElements*, hasChoices*: BOOLEAN;
    effective*, details*: Rope;
    elements*: Besm2Text.List;
    choices*: Choice;      (* the file's names for the options of times *)
    (* A Weapon Attack with `abilities`, `disabilities` or `damage`;
       hasAbilities and hasDisabilities: the key, even empty. *)
    structured*, hasAbilities*, hasDisabilities*: BOOLEAN;
    hasDamage*: BOOLEAN;   (* damage is saved *)
    enhancements*, limiters*: Raw;  (* the sequences, or NIL *)
    extra*: Raw;
    fPoints, fDamage: INTEGER; listedPoints, listedDamage: BOOLEAN;
    damageInFile: BOOLEAN  (* the file gave a damage, to compare *)
  END;

  Defect* = POINTER TO DefectDesc;
  DefectDesc* = RECORD (C.DefectDesc)
    name*, subject*: Rope;
    hasSubject*, packed*: BOOLEAN;
    hasLevel*: BOOLEAN;    (* the rank is saved as `level` *)
    hasDetails*: BOOLEAN; details*: Rope;
    extra*: Raw;
    fPoints: INTEGER; listed: BOOLEAN
  END;

  Skill* = POINTER TO SkillDesc;
  SkillDesc* = RECORD (C.SkillDesc)
    name*: Rope;
    levelIsText*: BOOLEAN; levelText*: Rope;
    hasSpecialisations*: BOOLEAN; specialisations*: Besm2Text.List;
    extra*: Raw;
    fPoints: INTEGER; listed: BOOLEAN
  END;

  HouseSkill* = POINTER TO HouseSkillDesc;
  HouseSkillDesc* = RECORD (C.HouseSkillDesc)
    name*: Rope;
    hasStat*: BOOLEAN; stat*: Rope;
    hasSpecializations*: BOOLEAN; specializations*: Besm2Text.List
  END;

  Entity* = POINTER TO EntityDesc;
  EntityDesc* = RECORD (C.EntityDesc)
    (* Read from a file: saved with only the keys it had.  Else made
       here, and saved with Stats and derived values (Besm2Save). *)
    fromFile*: BOOLEAN;
    hasName*, hasTagline*, hasDescription*, hasSize*: BOOLEAN;
    name*, tagline*, description*, size*: Rope;
    hasMechaKey*: BOOLEAN;  (* `mecha:` is written even when false *)
    hasStats*, hasDerived*, hasAttributes*, hasDefects*, hasSkills*, hasNotes*: BOOLEAN;
    stats*: Stat;
    derived*: DerivedValue;
    notes*: Besm2Text.List;
    hasCreation*: BOOLEAN;
    creationKeys*: SET;
    extra*: Raw;
    label-: Rope            (* for notices: its name, or "entity N" *)
  END;

  Entities* = POINTER TO ARRAY OF Entity;

  (* Called on each entity Read reads, before it is computed (SetUpgrade). *)
  Hook* = PROCEDURE (e: Entity);

  (* Something to say about a file read (notices).  A Difference is a
     number of the file's the rules give differently, or a value that
     isn't a number; --check fails on it.  A Warning is the rest: a
     name the rulebook doesn't have, a number it doesn't price, a mecha
     not in the file, an alias, a deprecated key, an empty string.  An
     Error is a number outside -999..999 (Besm2Check). *)
  Notice* = POINTER TO NoticeDesc;
  NoticeDesc* = RECORD
    next-: Notice;
    kind-: INTEGER;    (* Difference, Warning, Error *)
    text-: Rope        (* "Hero: Body (p. 15, PDF 17): points is ..." *)
  END;

  (* What reading a file gave, in its order: an entity, or a problem
     -- a polibfyaml error (yerr), or a message of Besm2Entities' or
     this module's (msg, "/0/attributes/2: not a mapping", or "expected
     a top-level YAML sequence of entities in FILE") -- as pobesm2_fmt2
     reports them. *)
  Result* = POINTER TO ResultDesc;
  ResultDesc* = RECORD
    next-: Result;
    entity-: Entity;
    yerr-: Fyaml.Error;
    msg-: Rope
  END;

VAR
  (* What the last Read, Load or LoadAll found to say about the file:
     each number kept as an override, each value kept that isn't a
     number, each mecha not found. *)
  notices-: Notice;
  nNotices-, nDifferences-: INTEGER;   (* nDifferences: the Differences and Errors *)
  lastNotice: Notice;
  yamlError: Fyaml.Error;
  message: Rope;
  ownABigMecha: R.Item;
  upgrade: Hook;   (* SetUpgrade's, or NIL *)

(* ---- Errors, in Besm2Entities' words ---- *)

PROCEDURE Fail(n: Fyaml.Node; text: ARRAY OF CHAR): BOOLEAN;
  VAR path: Fyaml.String;
BEGIN
  path := n.Path();
  message := Ropes.FromString(path^); Besm2Text.Add(message, ": "); Besm2Text.Add(message, text);
  RETURN FALSE
END Fail;

PROCEDURE FailRope(n: Fyaml.Node; text: Rope): BOOLEAN;
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(text); RETURN Fail(n, s^)
END FailRope;

(* ---- Reading what Besm2Entities has checked ---- *)

PROCEDURE ScalarText(n: Fyaml.Node): Rope;
  VAR t: Fyaml.String;
BEGIN t := n.Scalar(); RETURN Ropes.FromString(t^)
END ScalarText;

(* The text of m's key, a scalar, and whether it is there. *)
PROCEDURE Field(m: Fyaml.Node; key: ARRAY OF CHAR; VAR has: BOOLEAN; VAR r: Rope);
BEGIN
  r := NIL; has := m.HasKey(key);
  IF has THEN r := ScalarText(m.Value(key)) END
END Field;

PROCEDURE Int(m: Fyaml.Node; key: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER; err: Fyaml.Error;
BEGIN
  IF ~m.IntegerField(key, i, err) THEN i := 0 END;
  RETURN i
END Int;

(* The scalars of m's key, a sequence, and whether it is there. *)
PROCEDURE Strings(m: Fyaml.Node; key: ARRAY OF CHAR; VAR has: BOOLEAN; VAR l: Besm2Text.List);
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter;
BEGIN
  Besm2Text.Clear(l); seq := m.Value(key); has := seq # NIL;
  IF has THEN
    seq.Items(it);
    WHILE it.Next(item) DO Besm2Text.Append(l, ScalarText(item)) END
  END
END Strings;

(* Whether m's `overrides:` lists key. *)
PROCEDURE Listed(m: Fyaml.Node; key: ARRAY OF CHAR): BOOLEAN;
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter; found: BOOLEAN;
BEGIN
  found := FALSE; seq := m.Value("overrides");
  IF seq # NIL THEN
    seq.Items(it);
    WHILE it.Next(item) DO found := found OR item.ScalarIs(key) END
  END;
  RETURN found
END Listed;

(* An integer of 6 digits or fewer, with an optional "-", and blanks
   around it: what Besm2Calc.Parse takes. *)
PROCEDURE IntOf(r: Rope; VAR i: INTEGER): BOOLEAN;
  VAR s: Besm2Text.String; n: C.Number;
BEGIN
  s := Besm2Text.Chars(r); C.Clear(n);
  IF C.Parse(s^, n) & n.overridden THEN i := n.ovValue; RETURN TRUE END;
  RETURN FALSE
END IntOf;

(* ---- Raw YAML ---- *)

PROCEDURE ReadRaw(n: Fyaml.Node): Raw;
  VAR r, x, last: Raw; it: Fyaml.ItemIter; pit: Fyaml.PairIter; item, key: Fyaml.Node;
BEGIN
  NEW(r); r.next := NIL; r.key := NIL; r.first := NIL; r.text := NIL; r.style := n.Style();
  IF n.IsScalar() THEN r.kind := RawScalar; r.text := ScalarText(n)
  ELSE
    last := NIL;
    IF n.IsSequence() THEN
      r.kind := RawSequence; n.Items(it);
      WHILE it.Next(item) DO
        x := ReadRaw(item);
        IF last = NIL THEN r.first := x ELSE last.next := x END;
        last := x
      END
    ELSE
      r.kind := RawMapping; n.Pairs(pit);
      WHILE pit.Next(key, item) DO
        x := ReadRaw(item);
        IF key.IsScalar() THEN x.key := ScalarText(key) ELSE x.key := Ropes.FromString("?") END;
        IF last = NIL THEN r.first := x ELSE last.next := x END;
        last := x
      END
    END
  END;
  RETURN r
END ReadRaw;

(* The pairs of mapping m whose keys aren't in known (names separated
   by ", "), in order, each with its key; NIL for none. *)
PROCEDURE Extras(m: Fyaml.Node; known: ARRAY OF CHAR): Raw;
  VAR pit: Fyaml.PairIter; key, value: Fyaml.Node; names: Ropes.Pieces; k: Rope;
    i: LONGINT; found: BOOLEAN; first, last, x: Raw;
BEGIN
  names := Ropes.SplitArray(Ropes.FromString(known), ", ");
  first := NIL; last := NIL; m.Pairs(pit);
  WHILE pit.Next(key, value) DO
    IF key.IsScalar() THEN k := ScalarText(key) ELSE k := Ropes.FromString("?") END;
    found := FALSE;
    FOR i := 0 TO LEN(names^) - 1 DO found := found OR Ropes.Equal(k, names[i]) END;
    IF ~found THEN
      x := ReadRaw(value); x.key := k;
      IF last = NIL THEN first := x ELSE last.next := x END;
      last := x
    END
  END;
  RETURN first
END Extras;

(* An error, in Besm2Entities' words, for a key of mapping m not in
   known: a misspelt one would otherwise be dropped silently. *)
PROCEDURE OnlyKeys(m: Fyaml.Node; known: ARRAY OF CHAR): BOOLEAN;
  VAR x: Raw; t: Rope;
BEGIN
  x := Extras(m, known);
  IF x # NIL THEN
    t := Ropes.FromChar('"'); t := Ropes.Cat(t, x.key); Besm2Text.Add(t, '" is not one of ');
    Besm2Text.Add(t, known);
    RETURN FailRope(m, t)
  END;
  RETURN TRUE
END OnlyKeys;

(* ---- Names ---- *)

(* The item named name, of kind first, else second (-1: none). *)
PROCEDURE Lookup(first, second: INTEGER; name: Rope): R.Item;
  VAR s: Besm2Text.String; it: R.Item;
BEGIN
  s := Besm2Text.Chars(Besm2Text.Trim(name));
  it := R.FindKind(first, s^);
  IF (it = NIL) & (second >= 0) THEN it := R.FindKind(second, s^) END;
  RETURN it
END Lookup;

(* The item of m's name and subject: with `subject`, the name's; else
   the whole name's, or, failing that, the part before the first ": ",
   the rest being the subject (packed). *)
PROCEDURE Named(m: Fyaml.Node; first, second: INTEGER; VAR name, subject: Rope;
                VAR hasSubject, packed: BOOLEAN): R.Item;
  VAR it: R.Item; has: BOOLEAN; i, len: LONGINT;
BEGIN
  Field(m, "name", has, name); Field(m, "subject", hasSubject, subject); packed := FALSE;
  it := Lookup(first, second, name);
  IF (it = NIL) & ~hasSubject THEN
    i := Ropes.Find(name, ": ", 0);
    IF i >= 0 THEN
      it := Lookup(first, second, Ropes.Substring(name, 0, i));
      IF it # NIL THEN
        len := Ropes.Length(name);
        subject := Besm2Text.Trim(Ropes.Substring(name, i + 2, len - i - 2));
        name := Ropes.Substring(name, 0, i);
        hasSubject := TRUE; packed := TRUE
      END
    END
  END;
  RETURN it
END Named;

(* ---- Items ---- *)

PROCEDURE StatIndex(name: Rope): INTEGER;
  VAR s: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(Besm2Text.Trim(name));
  IF R.SameName(s^, "Body") THEN RETURN C.Body
  ELSIF R.SameName(s^, "Mind") THEN RETURN C.Mind
  ELSIF R.SameName(s^, "Soul") THEN RETURN C.Soul
  END;
  RETURN -1
END StatIndex;

PROCEDURE ReadStat(m: Fyaml.Node; e: Entity): Stat;
  VAR s: Stat; has: BOOLEAN; v: Rope; i: INTEGER;
BEGIN
  NEW(s); s.next := NIL; s.valueIsText := FALSE; s.valueText := NIL;
  Field(m, "name", has, s.name); Field(m, "value", has, v);
  s.index := StatIndex(s.name);
  IF (s.index >= 0) & IntOf(v, i) THEN e.stat[s.index] := i ELSE s.valueIsText := TRUE; s.valueText := v END;
  C.Clear(s.points); s.fPoints := Int(m, "points"); s.listed := Listed(m, "points");
  s.extra := Extras(m, StatKeys);
  RETURN s
END ReadStat;

PROCEDURE Slot(name: Rope; isMecha: BOOLEAN): INTEGER;
  VAR s: Besm2Text.String; slot: INTEGER;
BEGIN
  s := Besm2Text.Chars(Besm2Text.Trim(name)); slot := NoSlot;
  IF R.SameName(s^, "ACV") OR R.SameName(s^, "Attack Combat Value") THEN slot := ACV
  ELSIF R.SameName(s^, "DCV") OR R.SameName(s^, "Defence Combat Value")
     OR R.SameName(s^, "Defense Combat Value") THEN slot := DCV
  ELSIF R.SameName(s^, "HP") OR R.SameName(s^, "Health Points") THEN slot := HP
  ELSIF R.SameName(s^, "EP") OR R.SameName(s^, "Energy Points") THEN slot := EP
  ELSIF R.SameName(s^, "SV") OR R.SameName(s^, "Shock Value") THEN slot := SV
  ELSIF R.SameName(s^, "AR") OR R.SameName(s^, "Armour Rating") OR R.SameName(s^, "Armor Rating") THEN
    slot := AR
  END;
  (* A mecha has no Combat Value or Energy Points of its own (p. 59). *)
  IF isMecha & ((slot = ACV) OR (slot = DCV) OR (slot = EP)) THEN slot := NoSlot END;
  RETURN slot
END Slot;

PROCEDURE ReadDerived(m: Fyaml.Node; e: Entity): DerivedValue;
  VAR d: DerivedValue; has: BOOLEAN; v: Rope;
BEGIN
  NEW(d); d.next := NIL; d.valueIsText := FALSE; d.valueText := NIL;
  Field(m, "name", has, d.name); Field(m, "value", has, v);
  d.slot := Slot(d.name, e.isMecha);
  IF (d.slot = NoSlot) OR ~IntOf(v, d.fValue) THEN d.valueIsText := TRUE; d.valueText := v END;
  Strings(m, "alternatives", d.hasAlternatives, d.alternatives);
  d.listed := Listed(m, "value");
  d.extra := Extras(m, DerivedKeys);
  RETURN d
END ReadDerived;

(* An item of `abilities` or `disabilities`, of kind. *)
PROCEDURE ReadMod(n: Fyaml.Node; kind: INTEGER): Mod;
  VAR x: Mod; has: BOOLEAN; countsAs: INTEGER;
BEGIN
  NEW(x); x.hasDetail := FALSE; x.detail := NIL; countsAs := 0;
  IF n.IsScalar() THEN x.name := ScalarText(n)
  ELSE
    Field(n, "name", has, x.name);
    IF n.HasKey("counts-as") THEN countsAs := Int(n, "counts-as") END;
    Field(n, "detail", x.hasDetail, x.detail)
  END;
  C.InitMod(x, Lookup(kind, -1, x.name), countsAs);
  RETURN x
END ReadMod;

PROCEDURE ReadMods(m: Fyaml.Node; key: ARRAY OF CHAR; kind: INTEGER; VAR has: BOOLEAN; VAR list: C.Mod);
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter;
BEGIN
  seq := m.Value(key); has := seq # NIL;
  IF has THEN
    seq.Items(it);
    WHILE it.Next(item) DO C.AddMod(list, ReadMod(item, kind)) END
  END
END ReadMods;

(* `choices`, each an option of a's item, or kept by name if it isn't. *)
PROCEDURE ReadChoices(m: Fyaml.Node; a: Attr);
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter; c, last: Choice; has: BOOLEAN;
    s: Besm2Text.String; i: INTEGER;
BEGIN
  seq := m.Value("choices"); a.hasChoices := seq # NIL; a.choices := NIL; last := NIL;
  IF a.hasChoices THEN
    seq.Items(it);
    WHILE it.Next(item) DO
      NEW(c); c.next := NIL; c.times := 1;
      IF item.IsScalar() THEN c.name := ScalarText(item)
      ELSE
        Field(item, "name", has, c.name);
        IF item.HasKey("counts-as") THEN c.times := Int(item, "counts-as") END
      END;
      c.option := -1;
      IF a.item # NIL THEN
        s := Besm2Text.Chars(Besm2Text.Trim(c.name));
        i := 0; WHILE (i < a.item.nOptions) & ~R.SameName(a.item.option[i].label, s^) DO INC(i) END;
        IF i < a.item.nOptions THEN c.option := i; INC(a.times[i], c.times) END
      END;
      IF last = NIL THEN a.choices := c ELSE last.next := c END;
      last := c
    END
  END
END ReadChoices;

PROCEDURE ReadAttr(m: Fyaml.Node; e: Entity; VAR x: Attr): BOOLEAN;
  VAR a: Attr; it: R.Item; first, second, level: INTEGER; levelText, name, subject: Rope;
    has, hasSubject, packed: BOOLEAN;
BEGIN
  NEW(a); x := a;
  IF e.isMecha THEN first := R.MechaAttribute; second := R.Attribute
  ELSE first := R.Attribute; second := R.MechaAttribute
  END;
  it := Named(m, first, second, name, subject, hasSubject, packed);
  Field(m, "level", has, levelText);
  a.levelIsText := ~IntOf(levelText, level);
  IF a.levelIsText THEN level := 0 ELSE levelText := NIL END;
  C.InitAttr(a, it, level);
  a.name := name; a.subject := subject; a.hasSubject := hasSubject; a.packed := packed;
  a.levelText := levelText;
  Field(m, "effective", a.hasEffective, a.effective);
  Field(m, "details", a.hasDetails, a.details);
  Strings(m, "elements", a.hasElements, a.elements);
  ReadChoices(m, a);
  a.enhancements := NIL; a.limiters := NIL;
  IF m.HasKey("enhancements") THEN a.enhancements := ReadRaw(m.Value("enhancements")) END;
  IF m.HasKey("limiters") THEN a.limiters := ReadRaw(m.Value("limiters")) END;
  ReadMods(m, "abilities", R.Ability, a.hasAbilities, a.abilities);
  ReadMods(m, "disabilities", R.Disability, a.hasDisabilities, a.disabilities);
  a.hasDamage := m.HasKey("damage");
  a.structured := a.hasAbilities OR a.hasDisabilities OR a.hasDamage;
  IF a.weapon & a.structured THEN a.hasDamage := TRUE END;
  IF ~m.BooleanFieldOr("different-gunner", FALSE, a.differentGunner, yamlError)
     OR ~m.BooleanFieldOr("primary", FALSE, a.primary, yamlError) THEN
    RETURN FALSE
  END;
  a.fPoints := Int(m, "points"); a.listedPoints := Listed(m, "points");
  a.damageInFile := m.HasKey("damage");
  a.fDamage := 0; IF a.damageInFile THEN a.fDamage := Int(m, "damage") END;
  a.listedDamage := Listed(m, "damage");
  a.extra := Extras(m, AttrKeys);
  RETURN TRUE
END ReadAttr;

PROCEDURE ReadDefect(m: Fyaml.Node; e: Entity; VAR x: Defect): BOOLEAN;
  VAR d: Defect; it: R.Item; first, second, rank: INTEGER; name, subject: Rope;
    hasSubject, packed: BOOLEAN;
BEGIN
  NEW(d); x := d;
  IF e.isMecha THEN first := R.MechaDefect; second := R.Defect
  ELSE first := R.Defect; second := R.MechaDefect
  END;
  it := Named(m, first, second, name, subject, hasSubject, packed);
  d.fPoints := Int(m, "points"); d.listed := Listed(m, "points");
  d.hasLevel := m.HasKey("level");
  IF d.hasLevel THEN
    IF ~m.IntegerField("level", rank, yamlError) THEN RETURN FALSE END
  ELSE
    (* Besm2Calc prices a Defect it doesn't have at 1 a rank. *)
    IF it = NIL THEN rank := -d.fPoints
    ELSIF it.cost > 0 THEN rank := -d.fPoints DIV it.cost
    ELSE rank := 1
    END;
    IF rank < 1 THEN rank := 1 END
  END;
  C.InitDefect(d, it, rank);
  d.name := name; d.subject := subject; d.hasSubject := hasSubject; d.packed := packed;
  Field(m, "details", d.hasDetails, d.details);
  d.extra := Extras(m, DefectKeys);
  RETURN TRUE
END ReadDefect;

(* The house Skill named name, ignoring case; NIL if none. *)
PROCEDURE House(e: Entity; name: Rope): HouseSkill;
  VAR h: C.HouseSkill; s, t: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(Besm2Text.Trim(name));
  h := e.creation.houseSkills;
  WHILE h # NIL DO
    t := Besm2Text.Chars(Besm2Text.Trim(h(HouseSkill).name));
    IF R.SameName(s^, t^) THEN RETURN h(HouseSkill) END;
    h := h.next
  END;
  RETURN NIL
END House;

PROCEDURE ReadSkill(m: Fyaml.Node; e: Entity): Skill;
  VAR s: Skill; has: BOOLEAN; name, levelText: Rope; level: INTEGER; h: HouseSkill;
BEGIN
  NEW(s);
  Field(m, "name", has, name); Field(m, "level", has, levelText);
  s.levelIsText := ~IntOf(levelText, level);
  IF s.levelIsText THEN level := 0 ELSE levelText := NIL END;
  Strings(m, "specialisations", s.hasSpecialisations, s.specialisations);
  h := House(e, name);
  C.InitSkill(s, Lookup(R.Skill, -1, name), h, level, s.specialisations.n);
  s.name := name; s.levelText := levelText;
  s.fPoints := Int(m, "points"); s.listed := Listed(m, "points");
  s.extra := Extras(m, SkillKeys);
  RETURN s
END ReadSkill;

(* ---- Creation: keys Besm2Entities doesn't read ---- *)

PROCEDURE Mapping(n: Fyaml.Node): BOOLEAN;
BEGIN RETURN n.IsMapping() OR Fail(n, "not a mapping")
END Mapping;

PROCEDURE Genre(n: Fyaml.Node; VAR g: INTEGER): BOOLEAN;
  VAR s: Fyaml.String; t: Rope;
BEGIN
  IF ~n.IsScalar() THEN RETURN Fail(n, "not a scalar") END;
  s := n.Scalar(); g := R.FindGenre(s^);
  IF g < 0 THEN
    t := Ropes.FromChar('"'); Besm2Text.Add(t, s^); Besm2Text.Add(t, '" is not a genre of Table 2-4');
    RETURN FailRope(n, t)
  END;
  RETURN TRUE
END Genre;

PROCEDURE ReadHouseSkill(m: Fyaml.Node; VAR h: HouseSkill): BOOLEAN;
  VAR costs, k, v: Fyaml.Node; pit: Fyaml.PairIter; g, cost: INTEGER; name: Fyaml.String;
BEGIN
  NEW(h); C.InitHouseSkill(h);
  IF ~Mapping(m) OR ~OnlyKeys(m, HouseSkillKeys) OR ~m.StringField("name", name, yamlError) THEN
    RETURN FALSE
  END;
  h.name := Ropes.FromString(name^);
  costs := m.Required("costs", yamlError);
  IF costs = NIL THEN RETURN FALSE END;
  IF ~Mapping(costs) THEN RETURN FALSE END;
  costs.Pairs(pit);
  WHILE pit.Next(k, v) DO
    IF ~Genre(k, g) OR ~v.IntegerValue(cost, yamlError) THEN RETURN FALSE END;
    IF cost < 1 THEN RETURN Fail(v, "a Skill's cost must be positive") END;
    h.cost[g] := cost
  END;
  h.hasStat := m.HasKey("stat"); h.stat := NIL;
  IF h.hasStat THEN
    IF ~m.StringField("stat", name, yamlError) THEN RETURN FALSE END;
    h.stat := Ropes.FromString(name^)
  END;
  Besm2Text.Clear(h.specializations); h.hasSpecializations := m.HasKey("specializations");
  IF h.hasSpecializations THEN
    v := m.Value("specializations");
    IF ~v.IsSequence() THEN RETURN Fail(v, "not a sequence") END;
    Strings(m, "specializations", h.hasSpecializations, h.specializations)
  END;
  RETURN TRUE
END ReadHouseSkill;

PROCEDURE ReadOptions(m: Fyaml.Node; e: Entity): BOOLEAN;
  VAR c: C.Creation;
BEGIN
  c := e.creation;
  IF ~Mapping(m) OR ~OnlyKeys(m, OptionKeys) THEN RETURN FALSE END;
  IF m.HasKey("staged-stat-cost") THEN
    INCL(e.creationKeys, StagedStatCostKey);
    IF ~m.BooleanField("staged-stat-cost", c.stagedStatCost, yamlError) THEN RETURN FALSE END
  END;
  IF m.HasKey("stat-ceiling") THEN
    INCL(e.creationKeys, StatCeilingKey);
    IF ~m.IntegerField("stat-ceiling", c.statCeiling, yamlError) THEN RETURN FALSE END
  END;
  IF m.HasKey("bonus-point-ceiling") THEN
    INCL(e.creationKeys, BonusCeilingKey);
    IF ~m.IntegerField("bonus-point-ceiling", c.bonusCeiling, yamlError) THEN RETURN FALSE END
  END;
  IF m.HasKey("auto-fire-slots") THEN
    INCL(e.creationKeys, AutoFireSlotsKey);
    IF ~m.IntegerField("auto-fire-slots", c.autoFireSlots, yamlError) THEN RETURN FALSE END;
    IF (c.autoFireSlots # 1) & (c.autoFireSlots # 3) THEN
      RETURN Fail(m.Value("auto-fire-slots"), "auto-fire-slots must be 1 or 3")
    END
  END;
  e.creation := c;
  RETURN TRUE
END ReadOptions;

PROCEDURE ReadCreation(m: Fyaml.Node; e: Entity): BOOLEAN;
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter; h: HouseSkill;
BEGIN
  IF ~Mapping(m) OR ~OnlyKeys(m, CreationKeys) THEN RETURN FALSE END;
  IF m.HasKey("character-points") THEN
    INCL(e.creationKeys, CharacterPointsKey);
    IF ~m.IntegerField("character-points", e.creation.characterPoints, yamlError) THEN RETURN FALSE END
  END;
  IF m.HasKey("background-points") THEN
    INCL(e.creationKeys, BackgroundPointsKey);
    IF ~m.IntegerField("background-points", e.creation.backgroundPoints, yamlError) THEN RETURN FALSE END
  END;
  IF m.HasKey("genre") THEN
    INCL(e.creationKeys, GenreKey);
    IF ~Genre(m.Value("genre"), e.creation.genre) THEN RETURN FALSE END
  END;
  IF m.HasKey("skill-points") THEN
    INCL(e.creationKeys, SkillPointsKey);
    IF ~m.IntegerField("skill-points", e.creation.skillPoints, yamlError) THEN RETURN FALSE END;
    IF e.creation.skillPoints < 0 THEN RETURN Fail(m.Value("skill-points"), "skill-points must not be negative") END
  END;
  IF m.HasKey("options") THEN
    INCL(e.creationKeys, OptionsKey);
    IF ~ReadOptions(m.Value("options"), e) THEN RETURN FALSE END
  END;
  IF m.HasKey("house-skills") THEN
    INCL(e.creationKeys, HouseSkillsKey);
    seq := m.Value("house-skills");
    IF ~seq.IsSequence() THEN RETURN Fail(seq, "not a sequence") END;
    seq.Items(it);
    WHILE it.Next(item) DO
      IF ~ReadHouseSkill(item, h) THEN RETURN FALSE END;
      C.AddHouseSkill(e.creation, h)
    END
  END;
  RETURN TRUE
END ReadCreation;

(* ---- Entities ---- *)

(* Entity n of the file (1 for the first), from mapping m, which
   Besm2Entities has accepted.  FALSE, with yamlError or message set,
   for a fault in a key it doesn't read. *)
PROCEDURE ReadEntity(m: Fyaml.Node; n: INTEGER; VAR e: Entity): BOOLEAN;
  VAR seq, item: Fyaml.Node; it: Fyaml.ItemIter; s, sl: Stat; d, dl: DerivedValue;
    a: Attr; df: Defect; mecha: BOOLEAN;
BEGIN
  NEW(e);
  IF ~m.BooleanFieldOr("mecha", FALSE, mecha, yamlError) THEN RETURN FALSE END;
  C.InitEntity(e, mecha); e.fromFile := TRUE;
  e.hasMechaKey := m.HasKey("mecha");
  Field(m, "name", e.hasName, e.name); Field(m, "tagline", e.hasTagline, e.tagline);
  Field(m, "description", e.hasDescription, e.description); Field(m, "size", e.hasSize, e.size);
  IF e.hasName & (Besm2Text.Trim(e.name) # NIL) THEN e.label := Besm2Text.Trim(e.name)
  ELSE e.label := Ropes.FromString("entity "); Besm2Text.AddInt(e.label, n)
  END;
  e.creationKeys := {}; e.hasCreation := m.HasKey("creation");
  IF e.hasCreation & ~ReadCreation(m.Value("creation"), e) THEN RETURN FALSE END;
  e.stats := NIL; sl := NIL; seq := m.Value("stats"); e.hasStats := seq # NIL;
  IF e.hasStats THEN
    seq.Items(it);
    WHILE it.Next(item) DO
      s := ReadStat(item, e);
      IF sl = NIL THEN e.stats := s ELSE sl.next := s END;
      sl := s
    END
  END;
  e.derived := NIL; dl := NIL; seq := m.Value("derived"); e.hasDerived := seq # NIL;
  IF e.hasDerived THEN
    seq.Items(it);
    WHILE it.Next(item) DO
      d := ReadDerived(item, e);
      IF dl = NIL THEN e.derived := d ELSE dl.next := d END;
      dl := d
    END
  END;
  seq := m.Value("attributes"); e.hasAttributes := seq # NIL;
  IF e.hasAttributes THEN
    seq.Items(it);
    WHILE it.Next(item) DO
      IF ~ReadAttr(item, e, a) THEN RETURN FALSE END;
      C.AddAttr(e, a)
    END
  END;
  seq := m.Value("defects"); e.hasDefects := seq # NIL;
  IF e.hasDefects THEN
    seq.Items(it);
    WHILE it.Next(item) DO
      IF ~ReadDefect(item, e, df) THEN RETURN FALSE END;
      C.AddDefect(e, df)
    END
  END;
  seq := m.Value("skills"); e.hasSkills := seq # NIL;
  IF e.hasSkills THEN
    seq.Items(it);
    WHILE it.Next(item) DO C.AddSkill(e, ReadSkill(item, e)) END
  END;
  Strings(m, "notes", e.hasNotes, e.notes);
  e.extra := Extras(m, EntityKeys);
  RETURN TRUE
END ReadEntity;

(* ---- Computing ---- *)

(* Computes e: through its owner, for a mecha one gives. *)
PROCEDURE Recompute*(e: C.Entity);
BEGIN
  IF e.isMecha & (e.owner # NIL) THEN C.Compute(e.owner) ELSE C.Compute(e) END
END Recompute;

(* Computes the entities of a file: the characters, so each gives its
   mecha its owner, then each mecha no one owns. *)
PROCEDURE ComputeAll*(es: Entities);
  VAR i: LONGINT;
BEGIN
  IF es = NIL THEN RETURN END;
  FOR i := 0 TO LEN(es^) - 1 DO IF es[i].isMecha THEN es[i].owner := NIL END END;
  FOR i := 0 TO LEN(es^) - 1 DO IF ~es[i].isMecha THEN C.Compute(es[i]) END END;
  FOR i := 0 TO LEN(es^) - 1 DO IF es[i].isMecha & (es[i].owner = NIL) THEN C.Compute(es[i]) END END
END ComputeAll;

(* ---- The generator's ---- *)

(* A new character, with no file, no name and no creation (PLAN.md,
   Part B, step 6): Besm2Save writes its Stats and derived values. *)
PROCEDURE New*(): Entity;
  VAR e: Entity;
BEGIN
  NEW(e); C.InitEntity(e, FALSE); e.fromFile := FALSE;
  e.hasName := FALSE; e.hasTagline := FALSE; e.hasDescription := FALSE; e.hasSize := FALSE;
  e.name := NIL; e.tagline := NIL; e.description := NIL; e.size := NIL;
  e.hasMechaKey := FALSE;
  e.hasStats := FALSE; e.hasDerived := FALSE; e.hasAttributes := FALSE; e.hasDefects := FALSE;
  e.hasSkills := FALSE; e.hasNotes := FALSE;
  e.stats := NIL; e.derived := NIL; Besm2Text.Clear(e.notes);
  e.hasCreation := FALSE; e.creationKeys := {}; e.extra := NIL;
  e.label := Ropes.FromString("the character");
  C.Compute(e);
  RETURN e
END New;

(* The new entities: e alone. *)
PROCEDURE One*(e: Entity): Entities;
  VAR es: Entities;
BEGIN NEW(es, 1); es[0] := e; RETURN es
END One;

(* Stat i of e, which the user set: an entity from a file gets it in
   its `stats`, as a number, if it lacked it or had it as text; one
   made here gets them all anyway (Besm2Save). *)
PROCEDURE UseStat*(e: Entity; i: INTEGER);
  VAR s, last: Stat;
BEGIN
  IF ~e.fromFile THEN RETURN END;
  s := e.stats; last := NIL;
  WHILE (s # NIL) & (s.index # i) DO last := s; s := s.next END;
  IF s = NIL THEN
    NEW(s); s.next := NIL; s.index := i;
    CASE i OF C.Body: s.name := Ropes.FromString("Body")
    | C.Mind: s.name := Ropes.FromString("Mind")
    | C.Soul: s.name := Ropes.FromString("Soul")
    END;
    C.Clear(s.points); s.extra := NIL; s.fPoints := 0; s.listed := FALSE;
    IF last = NIL THEN e.stats := s ELSE last.next := s END
  END;
  s.valueIsText := FALSE; s.valueText := NIL;
  e.hasStats := TRUE
END UseStat;

(* The derived value of slot, which the user overrode: as UseStat. *)
PROCEDURE UseDerived*(e: Entity; slot: INTEGER);
  VAR d, last: DerivedValue;
BEGIN
  IF ~e.fromFile THEN RETURN END;
  d := e.derived; last := NIL;
  WHILE (d # NIL) & (d.slot # slot) DO last := d; d := d.next END;
  IF d = NIL THEN
    NEW(d); d.next := NIL; d.slot := slot;
    CASE slot OF ACV: d.name := Ropes.FromString("ACV") | DCV: d.name := Ropes.FromString("DCV")
    | HP: d.name := Ropes.FromString("HP") | EP: d.name := Ropes.FromString("EP")
    | SV: d.name := Ropes.FromString("SV") | AR: d.name := Ropes.FromString("AR")
    END;
    d.hasAlternatives := FALSE; Besm2Text.Clear(d.alternatives); d.extra := NIL;
    d.fValue := 0; d.listed := FALSE;
    IF last = NIL THEN e.derived := d ELSE last.next := d END
  END;
  d.valueIsText := FALSE; d.valueText := NIL;
  e.hasDerived := TRUE
END UseDerived;

PROCEDURE Note(kind: INTEGER; r: Rope);
  VAR n: Notice;
BEGIN
  NEW(n); n.next := NIL; n.kind := kind; n.text := r;
  IF notices = NIL THEN notices := n ELSE lastNotice.next := n END;
  lastNotice := n; INC(nNotices);
  IF kind # Warning THEN INC(nDifferences) END
END Note;

PROCEDURE ClearNotices;
BEGIN notices := NIL; lastNotice := NIL; nNotices := 0; nDifferences := 0
END ClearNotices;

(* A notice of kind about the file Read is reading, from a Hook. *)
PROCEDURE AddNotice*(kind: INTEGER; r: Rope);
BEGIN Note(kind, r)
END AddNotice;

(* where, ": ", and name, and ": " and subject if it has one. *)
PROCEDURE Within(where, name, subject: Rope; hasSubject: BOOLEAN; page: INTEGER): Rope;
  VAR r: Rope; p: ARRAY 32 OF CHAR;
BEGIN
  r := where; Besm2Text.Add(r, ": ");
  IF Besm2Text.Trim(name) = NIL THEN Besm2Text.Add(r, '""') ELSE r := Ropes.Cat(r, Besm2Text.Trim(name)) END;
  IF hasSubject THEN Besm2Text.Add(r, ": "); r := Ropes.Cat(r, Besm2Text.Trim(subject)) END;
  IF page > 0 THEN R.PagesText(page, p); Besm2Text.Add(r, " ("); Besm2Text.Add(r, p); Besm2Text.Add(r, ")") END;
  RETURN r
END Within;

(* The printed page of it, for Within: 0, none, for NIL. *)
PROCEDURE PageOf(it: R.Item): INTEGER;
BEGIN IF it = NIL THEN RETURN 0 ELSE RETURN it.page END
END PageOf;

(* "LABEL: Name: subject (p. N, PDF N+2)", an item of e's for a notice. *)
PROCEDURE Place*(e: Entity; name, subject: Rope; hasSubject: BOOLEAN; it: R.Item): Rope;
BEGIN RETURN Within(e.label, name, subject, hasSubject, PageOf(it))
END Place;

(* Makes a's damage the file's, damage, to be compared with the rules',
   if has; else it is computed, with nothing to compare (a Hook's). *)
PROCEDURE SetFileDamage*(a: Attr; has: BOOLEAN; damage: INTEGER);
BEGIN a.damageInFile := has; a.fDamage := damage; a.listedDamage := FALSE
END SetFileDamage;

(* h is called on each entity Read reads, before it is computed; NIL:
   none.  besm2_calc_po's --upgrade (Besm2Upgrade). *)
PROCEDURE SetUpgrade*(h: Hook);
BEGIN upgrade := h
END SetUpgrade;

(* A derived value's page: SV's own, or Step 7's (p. 129). *)
PROCEDURE DerivedPage(slot: INTEGER): INTEGER;
BEGIN
  IF slot = SV THEN RETURN R.ShockValuePage ELSIF slot = NoSlot THEN RETURN 0 ELSE RETURN R.DerivedValuesPage END
END DerivedPage;

(* A Stat's page, if name is a Stat's. *)
PROCEDURE StatPage(s: Stat): INTEGER;
BEGIN IF s.index < 0 THEN RETURN 0 ELSE RETURN R.StatsPage END
END StatPage;

(* Ties each Own a Big Mecha to the mecha its subject names, of the
   entities es; a subject no mecha has is a notice (the mecha may be
   in another file, A4). *)
PROCEDURE Link(es: Entities);
  VAR i, j: LONGINT; a: C.Attr; r: Rope;
BEGIN
  FOR i := 0 TO LEN(es^) - 1 DO
    a := es[i].attrs;
    WHILE a # NIL DO
      IF (a.item = ownABigMecha) & a(Attr).hasSubject THEN
        j := 0;
        WHILE (j < LEN(es^))
              & ~(es[j].isMecha & es[j].hasName
                  & Ropes.Equal(Besm2Text.Trim(es[j].name), Besm2Text.Trim(a(Attr).subject))) DO
          INC(j)
        END;
        IF j < LEN(es^) THEN a.mecha := es[j]
        ELSE
          r := Within(es[i].label, a(Attr).name, a(Attr).subject, TRUE, PageOf(a.item));
          Besm2Text.Add(r, ": no mecha of that name in the file");
          Note(Warning, r)
        END
      END;
      a := a.next
    END
  END
END Link;

(* The file's number for n: an override if listed, or if it differs
   from the computed number, with a notice. *)
PROCEDURE Adopt(VAR n: C.Number; file: INTEGER; listed: BOOLEAN; where: Rope; what: ARRAY OF CHAR);
  VAR r: Rope;
BEGIN
  IF listed THEN C.Override(n, file)
  ELSIF file # n.value THEN
    C.Override(n, file);
    r := where; Besm2Text.Add(r, ": "); Besm2Text.Add(r, what); Besm2Text.Add(r, " is ");
    Besm2Text.AddInt(r, file); Besm2Text.Add(r, " in the file, ");
    Besm2Text.AddInt(r, n.value); Besm2Text.Add(r, " by the rules: kept as an override");
    Note(Difference, r)
  END
END Adopt;

(* The file's number for n, which the rules don't give (why), kept as
   an override, with a notice unless listed or why is "". *)
PROCEDURE Keep(VAR n: C.Number; file: INTEGER; listed: BOOLEAN; where: Rope; what, why: ARRAY OF CHAR);
  VAR r: Rope;
BEGIN
  C.Override(n, file);
  IF ~listed & (why # "") THEN
    r := where; Besm2Text.Add(r, ": "); Besm2Text.Add(r, why); Besm2Text.Add(r, ": ");
    Besm2Text.Add(r, what); Besm2Text.Add(r, " ");
    Besm2Text.AddInt(r, file); Besm2Text.Add(r, " kept as an override");
    Note(Warning, r)
  END
END Keep;

(* A value or level kept as written, text, that isn't a number. *)
PROCEDURE NotANumber(where: Rope; what: ARRAY OF CHAR; text: Rope);
  VAR r: Rope;
BEGIN
  r := where; Besm2Text.Add(r, ": "); Besm2Text.Add(r, what); Besm2Text.Add(r, ' is "');
  r := Ropes.Cat(r, text); Besm2Text.Add(r, '" in the file, not a number: kept as written');
  Note(Difference, r)
END NotANumber;

PROCEDURE SlotNumber(e: Entity; slot: INTEGER; VAR n: C.Number);
BEGIN
  CASE slot OF
    ACV: n := e.acv | DCV: n := e.dcv | HP: n := e.hp | EP: n := e.ep | SV: n := e.sv | AR: n := e.ar
  END
END SlotNumber;

PROCEDURE SetSlot(e: Entity; slot: INTEGER; n: C.Number);
BEGIN
  CASE slot OF
    ACV: e.acv := n | DCV: e.dcv := n | HP: e.hp := n | EP: e.ep := n | SV: e.sv := n | AR: e.ar := n
  END
END SetSlot;

(* The derived values computed from others (DCV from ACV, SV from HP)
   are adopted in a second pass (late), after those others, so that an
   overridden ACV doesn't make the file's DCV, which agrees with it,
   look wrong. *)
PROCEDURE AdoptDerived(e: Entity; late: BOOLEAN);
  VAR d: DerivedValue; n: C.Number; isLate: BOOLEAN;
BEGIN
  d := e.derived;
  WHILE d # NIL DO
    isLate := (d.slot = DCV) OR (d.slot = SV);
    IF (d.slot # NoSlot) & (isLate = late) & ~d.valueIsText THEN
      SlotNumber(e, d.slot, n);
      Adopt(n, d.fValue, d.listed, Within(e.label, d.name, NIL, FALSE, DerivedPage(d.slot)), "value");
      SetSlot(e, d.slot, n)
    END;
    d := d.next
  END
END AdoptDerived;

(* Every number of e but the late derived values (AdoptDerived), and
   a notice for each value kept that isn't a number. *)
PROCEDURE AdoptItems(e: Entity);
  VAR s: Stat; d: DerivedValue; a: C.Attr; df: C.Defect; sk: C.Skill; where, r: Rope;
    unpriced: BOOLEAN; page: ARRAY 32 OF CHAR;
BEGIN
  s := e.stats;
  WHILE s # NIL DO
    where := Within(e.label, s.name, NIL, FALSE, StatPage(s));
    IF s.valueIsText & (s.index >= 0) THEN NotANumber(where, "value", s.valueText) END;
    IF s.index < 0 THEN Keep(s.points, s.fPoints, s.listed, where, "points", "not a Stat of the rulebook")
    ELSIF e.isMecha THEN
      (* A mecha's Stats aren't bought (p. 59). *)
      Keep(e.statPoints[s.index], s.fPoints, s.listed, where, "points", "a mecha's Stat")
    ELSE Adopt(e.statPoints[s.index], s.fPoints, s.listed, where, "points")
    END;
    s := s.next
  END;
  d := e.derived;
  WHILE d # NIL DO
    IF (d.slot # NoSlot) & d.valueIsText THEN
      NotANumber(Within(e.label, d.name, NIL, FALSE, DerivedPage(d.slot)), "value", d.valueText)
    END;
    d := d.next
  END;
  AdoptDerived(e, FALSE);
  a := e.attrs;
  WHILE a # NIL DO
    WITH a: Attr DO
      where := Within(e.label, a.name, a.subject, a.hasSubject, PageOf(a.item));
      IF a.levelIsText THEN NotANumber(where, "level", a.levelText) END;
      IF a.item = NIL THEN Keep(a.points, a.fPoints, a.listedPoints, where, "points", "not in the rulebook")
      ELSE Adopt(a.points, a.fPoints, a.listedPoints, where, "points")
      END;
      IF a.hasDamage & a.damageInFile THEN Adopt(a.damage, a.fDamage, a.listedDamage, where, "damage") END
    END;
    a := a.next
  END;
  df := e.defects;
  WHILE df # NIL DO
    WITH df: Defect DO
      Adopt(df.points, df.fPoints, df.listed, Within(e.label, df.name, df.subject, df.hasSubject, PageOf(df.item)), "points")
    END;
    df := df.next
  END;
  (* Without a genre no Skill has a price (Table 2-4, p. 119, PDF 121): one
     notice for them all. *)
  unpriced := FALSE; sk := e.skills;
  WHILE sk # NIL DO
    WITH sk: Skill DO
      where := Within(e.label, sk.name, NIL, FALSE, PageOf(sk.item));
      IF sk.levelIsText THEN NotANumber(where, "level", sk.levelText) END;
      IF (sk.item = NIL) & (sk.house = NIL) THEN
        Keep(sk.points, sk.fPoints, sk.listed, where, "points", "not in the rulebook")
      ELSIF e.creation.genre = C.NoGenre THEN
        Keep(sk.points, sk.fPoints, sk.listed, where, "points", "");
        unpriced := unpriced OR ~sk.listed
      ELSE Adopt(sk.points, sk.fPoints, sk.listed, where, "points")
      END
    END;
    sk := sk.next
  END;
  IF unpriced THEN
    r := e.label; Besm2Text.Add(r, ": no genre in creation to price Skills by (Table 2-4, ");
    R.PagesText(R.SkillCostsPage, page); Besm2Text.Add(r, page); Besm2Text.Add(r, "): their points kept as overrides");
    Note(Warning, r)
  END
END AdoptItems;

(* Links, computes and adopts the numbers of the entities of a file. *)
PROCEDURE Finish(es: Entities);
  VAR i: LONGINT;
BEGIN
  Link(es);
  ComputeAll(es);
  FOR i := 0 TO LEN(es^) - 1 DO AdoptItems(es[i]) END;
  ComputeAll(es);
  FOR i := 0 TO LEN(es^) - 1 DO AdoptDerived(es[i], TRUE) END;
  ComputeAll(es)
END Finish;

(* ---- Files ---- *)

PROCEDURE AddResult(VAR first, last: Result; e: Entity; yerr: Fyaml.Error; msg: Rope);
  VAR r: Result;
BEGIN
  NEW(r); r.next := NIL; r.entity := e; r.yerr := yerr; r.msg := msg;
  IF last = NIL THEN first := r ELSE last.next := r END;
  last := r
END AddResult;

(* Reads the file at path, or standard input if stdin, as pobesm2_fmt2
   reads it: every entity of every document, each read by
   Besm2Entities, then here; a document whose top level isn't a
   sequence is a problem, and the file goes on; a YAML error ends the
   file.  results: each entity read, or problem, in order; es: the
   entities, linked, computed and with the file's numbers (notices,
   for all of them, each naming its entity).  Besm2Config.unicodeMinus
   is Besm2Entities', so parse the command line first. *)
PROCEDURE Read*(path: ARRAY OF CHAR; stdin: BOOLEAN; VAR results: Result; VAR es: Entities);
  VAR s: FyamlStreams.Stream; d: Fyaml.Document; err, yerr: Fyaml.Error; root, item: Fyaml.Node;
    it: Fyaml.ItemIter; x: Besm2Entities.Entity; e: Entity; last, r: Result; msg: Rope;
    n, i: INTEGER; resolved: BOOLEAN;
BEGIN
  results := NIL; last := NIL; es := NIL; ClearNotices;
  (* Read unresolved, so that Besm2Check can see the aliases, then
     resolved, as pobesm2_fmt2 reads. *)
  IF stdin THEN s := FyamlStreams.OpenStdinWith({Fyaml.NoResolve}, err)
  ELSE s := FyamlStreams.OpenFileWith(path, {Fyaml.NoResolve}, err)
  END;
  IF s = NIL THEN AddResult(results, last, NIL, err, NIL); RETURN END;
  n := 0; i := 0;
  d := s.Next(err);
  WHILE d # NIL DO
    Besm2Check.Aliases(d.Root(), Note);
    resolved := d.Resolve(yerr);
    IF resolved THEN root := d.Root() END;
    IF ~resolved THEN AddResult(results, last, NIL, yerr, NIL)
    ELSIF (root = NIL) OR ~root.IsSequence() THEN
      msg := Ropes.FromString("expected a top-level YAML sequence of entities in ");
      IF stdin THEN Besm2Text.Add(msg, Fyaml.stdinName) ELSE Besm2Text.Add(msg, path) END;
      AddResult(results, last, NIL, NIL, msg)
    ELSE
      root.Items(it);
      WHILE it.Next(item) DO
        INC(i);
        IF ~Besm2Entities.Load(item, x, yerr, msg) THEN AddResult(results, last, NIL, yerr, msg)
        ELSE
          yamlError := NIL; message := NIL;
          IF ReadEntity(item, i, e) THEN
            IF upgrade # NIL THEN upgrade(e) END;
            AddResult(results, last, e, NIL, NIL); INC(n);
            Besm2Check.Entity(item, e.label, Note)
          ELSE AddResult(results, last, NIL, yamlError, message)
          END
        END
      END
    END;
    (* The entities' nodes are read; the document can go. *)
    d.Close;
    d := s.Next(err)
  END;
  IF err # NIL THEN AddResult(results, last, NIL, err, NIL) END;
  s.Close;
  IF n > 0 THEN
    NEW(es, n); i := 0; r := results;
    WHILE r # NIL DO IF r.entity # NIL THEN es[i] := r.entity; INC(i) END; r := r.next END;
    Finish(es)
  END
END Read;

(* The text of problem r, for a message: polibfyaml's, or "PATH: MSG". *)
PROCEDURE Problem*(r: Result; path: ARRAY OF CHAR): Rope;
  VAR m: Rope;
BEGIN
  IF r.yerr # NIL THEN RETURN Besm2Text.Trim(Ropes.FromString(r.yerr.msg^)) END;
  IF r.msg # NIL THEN m := Ropes.FromString(path); Besm2Text.Add(m, ": "); RETURN Ropes.Cat(m, r.msg) END;
  RETURN NIL
END Problem;

(* Every entity in the file at path, in order, as Read gives them.
   FALSE, with msg, if the file can't be read, has any problem (the
   first is msg), or holds no entities. *)
PROCEDURE LoadAll*(path: ARRAY OF CHAR; VAR es: Entities; VAR msg: Rope): BOOLEAN;
  VAR results, r: Result;
BEGIN
  msg := NIL;
  Read(path, FALSE, results, es);
  r := results; WHILE (r # NIL) & (r.entity # NIL) DO r := r.next END;
  IF r # NIL THEN msg := Problem(r, path); es := NIL; RETURN FALSE END;
  IF es = NIL THEN msg := Ropes.FromString(path); Besm2Text.Add(msg, " holds no entities"); RETURN FALSE END;
  RETURN TRUE
END LoadAll;

(* The one character in the file at path, as LoadAll, with es, all the
   file's entities (its mecha with it); FALSE, with msg, as LoadAll, or
   if the file holds more than one character, or none. *)
PROCEDURE Load*(path: ARRAY OF CHAR; VAR c: Entity; VAR es: Entities; VAR msg: Rope): BOOLEAN;
  VAR i: LONGINT; n: INTEGER;
BEGIN
  c := NIL;
  IF ~LoadAll(path, es, msg) THEN RETURN FALSE END;
  n := 0;
  FOR i := 0 TO LEN(es^) - 1 DO IF ~es[i].isMecha THEN INC(n); IF c = NIL THEN c := es[i] END END END;
  IF n # 1 THEN
    c := NIL; msg := Ropes.FromString(path); Besm2Text.Add(msg, " holds ");
    Besm2Text.AddInt(msg, n); Besm2Text.Add(msg, " characters, not one");
    RETURN FALSE
  END;
  RETURN TRUE
END Load;

BEGIN
  ClearNotices; upgrade := NIL;
  ownABigMecha := R.Find("Own a Big Mecha"); ASSERT(ownABigMecha # NIL)
END Besm2Character.
