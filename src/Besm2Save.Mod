MODULE Besm2Save; (* Writes a file's entities as YAML, for pobesm2_fmt2 and the other formatters *)

(* PLAN.md, Part B step 4, as ova_cg_po's OvaSave.  The document is
   built with polibfyaml's emitter, never written as text here, so the
   quoting is libfyaml's: text goes through CreateStyledScalar, plain
   where that is safe, else double-quoted, and a literal block when it
   has more than one line.  Numbers, booleans and keys are plain.

   One document, a sequence of the entities, in order, each with its
   keys in the order of the fixtures (A4), then the keys this program
   doesn't know, as the file had them.  The numbers written are the ones
   in effect: an override where there is one, which the item's
   `overrides:` then lists, so the formatters mark it.  Every key the
   file had is written, even an empty string or list, so a file loaded
   and saved formats the same (Besm2Character).

   Decided (2026-11-06):
   - An attribute's `choices` are written from its times: each choice
     the file had, by the file's name, with the times of its option now
     (dropped at 0); then each option taken that the file didn't name,
     by the rulebook's label.  A choice that isn't an option is kept.
   - An entity with no `stats` (a character) or `derived` gets them:
     Body, Mind and Soul; ACV, DCV, HP, EP, SV and AR if it has Armour
     (a mecha: HP, and AR).  A loaded file always has its own.

   A failed save leaves the old file as it was: the document goes to
   NAME.tmp, which then replaces NAME. *)

IMPORT C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Text, Fyaml, Platform, Ropes;

TYPE
  Rope = Ropes.Rope;
  Node = Fyaml.Node;

VAR
  d: Fyaml.Document;  (* the document being built *)
  ok: BOOLEAN;        (* every AppendPair so far succeeded *)

(* ---- Scalars ---- *)

PROCEDURE Text(r: Rope): Node;
  VAR s: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(r);
  IF Ropes.IndexChar(r, 0AX, 0) >= 0 THEN RETURN d.CreateStyledScalar(s^, Fyaml.StyleLiteral)
  ELSE RETURN d.CreateStyledScalar(s^, Fyaml.StylePlain)
  END
END Text;

PROCEDURE Plain(s: ARRAY OF CHAR): Node;
BEGIN RETURN d.CreateStyledScalar(s, Fyaml.StylePlain)
END Plain;

PROCEDURE Int(i: INTEGER): Node;
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(Besm2Text.Int(i)); RETURN d.CreateScalar(s^)
END Int;

PROCEDURE Bool(b: BOOLEAN): Node;
BEGIN IF b THEN RETURN d.CreateScalar("true") ELSE RETURN d.CreateScalar("false") END
END Bool;

(* n in effect. *)
PROCEDURE Num(VAR n: C.Number): Node;
BEGIN RETURN Int(C.Value(n))
END Num;

(* text as written if isText, else i. *)
PROCEDURE IntOr(isText: BOOLEAN; text: Rope; i: INTEGER): Node;
BEGIN IF isText THEN RETURN Text(text) ELSE RETURN Int(i) END
END IntOr;

PROCEDURE Strings(l: Besm2Text.List): Node;
  VAR seq: Node; i: INTEGER;
BEGIN
  seq := d.CreateSequence();
  FOR i := 0 TO l.n - 1 DO seq.Append(Text(l.items[i])) END;
  RETURN seq
END Strings;

(* A YAML value kept as it was. *)
PROCEDURE RawNode(r: Ch.Raw): Node;
  VAR n: Node; x: Ch.Raw; s: Besm2Text.String; err: Fyaml.Error;
BEGIN
  CASE r.kind OF
    Ch.RawScalar:
      s := Besm2Text.Chars(r.text);
      IF r.style = Fyaml.StyleDoubleQuoted THEN n := d.CreateStyledScalar(s^, Fyaml.StyleDoubleQuoted)
      ELSIF (r.style = Fyaml.StyleLiteral) OR (r.style = Fyaml.StyleFolded) THEN
        n := d.CreateStyledScalar(s^, Fyaml.StyleLiteral)
      ELSE n := d.CreateStyledScalar(s^, Fyaml.StylePlain)
      END
  | Ch.RawSequence:
      n := d.CreateSequence(); x := r.first;
      WHILE x # NIL DO n.Append(RawNode(x)); x := x.next END
  | Ch.RawMapping:
      n := d.CreateMapping(); x := r.first;
      WHILE x # NIL DO
        s := Besm2Text.Chars(x.key);
        IF ok THEN ok := n.AppendPair(Text(x.key), RawNode(x), err) END;
        x := x.next
      END
  END;
  RETURN n
END RawNode;

(* ---- Mappings ---- *)

PROCEDURE Pair(m: Node; key: ARRAY OF CHAR; v: Node);
  VAR err: Fyaml.Error;
BEGIN IF ok THEN ok := m.AppendPair(d.CreateScalar(key), v, err) END
END Pair;

PROCEDURE TextPair(m: Node; key: ARRAY OF CHAR; has: BOOLEAN; r: Rope);
BEGIN IF has THEN Pair(m, key, Text(r)) END
END TextPair;

(* The keys the file had that this program doesn't know. *)
PROCEDURE Extras(m: Node; x: Ch.Raw);
  VAR err: Fyaml.Error;
BEGIN
  WHILE x # NIL DO
    IF ok THEN ok := m.AppendPair(Text(x.key), RawNode(x), err) END;
    x := x.next
  END
END Extras;

(* "overrides: [first]", "[second]", or both, of those overridden. *)
PROCEDURE Overrides(m: Node; first: ARRAY OF CHAR; a: BOOLEAN; second: ARRAY OF CHAR; b: BOOLEAN);
  VAR seq: Node;
BEGIN
  IF a OR b THEN
    seq := d.CreateSequence();
    IF a THEN seq.Append(d.CreateScalar(first)) END;
    IF b THEN seq.Append(d.CreateScalar(second)) END;
    Pair(m, "overrides", seq)
  END
END Overrides;

(* name, packed with its subject as the file had it, and `subject`
   otherwise if it has one. *)
PROCEDURE Name(m: Node; name, subject: Rope; hasSubject, packed: BOOLEAN);
  VAR r: Rope;
BEGIN
  IF packed THEN
    r := name; Besm2Text.Add(r, ": "); r := Ropes.Cat(r, subject); Pair(m, "name", Text(r))
  ELSE
    Pair(m, "name", Text(name));
    IF hasSubject THEN Pair(m, "subject", Text(subject)) END
  END
END Name;

(* ---- Items ---- *)

PROCEDURE StatNode(e: Ch.Entity; s: Ch.Stat): Node;
  VAR m: Node; over: BOOLEAN;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Text(s.name));
  IF s.index >= 0 THEN
    Pair(m, "value", IntOr(s.valueIsText, s.valueText, e.stat[s.index]));
    Pair(m, "points", Num(e.statPoints[s.index])); over := e.statPoints[s.index].overridden
  ELSE
    Pair(m, "value", Text(s.valueText));
    Pair(m, "points", Num(s.points)); over := s.points.overridden
  END;
  Overrides(m, "points", over, "", FALSE);
  Extras(m, s.extra);
  RETURN m
END StatNode;

PROCEDURE SlotNumber(e: Ch.Entity; slot: INTEGER; VAR n: C.Number);
BEGIN
  CASE slot OF
    Ch.ACV: n := e.acv | Ch.DCV: n := e.dcv | Ch.HP: n := e.hp | Ch.EP: n := e.ep
  | Ch.SV: n := e.sv | Ch.AR: n := e.ar
  END
END SlotNumber;

PROCEDURE DerivedNode(e: Ch.Entity; x: Ch.DerivedValue): Node;
  VAR m: Node; n: C.Number; over: BOOLEAN;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Text(x.name));
  IF x.valueIsText THEN Pair(m, "value", Text(x.valueText)); over := FALSE
  ELSE SlotNumber(e, x.slot, n); Pair(m, "value", Num(n)); over := n.overridden
  END;
  IF x.hasAlternatives THEN Pair(m, "alternatives", Strings(x.alternatives)) END;
  Overrides(m, "value", over, "", FALSE);
  Extras(m, x.extra);
  RETURN m
END DerivedNode;

(* A choice or a Weapon Ability or Disability: a plain name, or a
   mapping when it has a count or a detail to say.  A choice's count
   (its times) is said from 2; a Weapon Ability's or Disability's
   counts-as whenever it is given (0: left out), since 1 can be less
   than its slots taken once ({name: Melee, counts-as: 1}, A4; it was
   dropped before 2026-11-06, step 8). *)
PROCEDURE ItemNode(name: Rope; countsAs, from: INTEGER; hasDetail: BOOLEAN; detail: Rope): Node;
  VAR m: Node;
BEGIN
  IF (countsAs < from) & ~hasDetail THEN RETURN Text(name) END;
  m := d.CreateMapping();
  Pair(m, "name", Text(name));
  IF countsAs >= from THEN Pair(m, "counts-as", Int(countsAs)) END;
  TextPair(m, "detail", hasDetail, detail);
  RETURN m
END ItemNode;

PROCEDURE Mods(m: Node; key: ARRAY OF CHAR; has: BOOLEAN; x: C.Mod);
  VAR seq: Node; md: Ch.Mod;
BEGIN
  IF has OR (x # NIL) THEN
    seq := d.CreateSequence();
    WHILE x # NIL DO
      md := x(Ch.Mod);
      seq.Append(ItemNode(md.name, md.countsAs, 1, md.hasDetail, md.detail));
      x := x.next
    END;
    Pair(m, key, seq)
  END
END Mods;

(* See "Decided" above. *)
PROCEDURE Choices(m: Node; a: Ch.Attr);
  VAR seq: Node; c: Ch.Choice; written: SET; i: INTEGER; label: Rope;
BEGIN
  seq := d.CreateSequence(); written := {};
  c := a.choices;
  WHILE c # NIL DO
    IF c.option < 0 THEN seq.Append(ItemNode(c.name, c.times, 2, FALSE, NIL))
    ELSIF ~(c.option IN written) & (a.times[c.option] > 0) THEN
      INCL(written, c.option); seq.Append(ItemNode(c.name, a.times[c.option], 2, FALSE, NIL))
    END;
    c := c.next
  END;
  IF a.item # NIL THEN
    FOR i := 0 TO a.item.nOptions - 1 DO
      IF ~(i IN written) & (a.times[i] > 0) THEN
        label := Ropes.FromString(a.item.option[i].label);
        seq.Append(ItemNode(label, a.times[i], 2, FALSE, NIL))
      END
    END
  END;
  IF a.hasChoices OR (seq.Length() > 0) THEN Pair(m, "choices", seq) END
END Choices;

PROCEDURE AttrNode(x: C.Attr): Node;
  VAR m: Node; a: Ch.Attr;
BEGIN
  a := x(Ch.Attr);
  m := d.CreateMapping();
  Name(m, a.name, a.subject, a.hasSubject, a.packed);
  Pair(m, "level", IntOr(a.levelIsText, a.levelText, a.level));
  Pair(m, "points", Num(a.points));
  TextPair(m, "effective", a.hasEffective, a.effective);
  TextPair(m, "details", a.hasDetails, a.details);
  IF a.hasElements THEN Pair(m, "elements", Strings(a.elements)) END;
  Choices(m, a);
  IF a.enhancements # NIL THEN Pair(m, "enhancements", RawNode(a.enhancements)) END;
  IF a.limiters # NIL THEN Pair(m, "limiters", RawNode(a.limiters)) END;
  Mods(m, "abilities", a.hasAbilities, a.abilities);
  Mods(m, "disabilities", a.hasDisabilities, a.disabilities);
  IF a.hasDamage THEN Pair(m, "damage", Num(a.damage)) END;
  IF a.primary THEN Pair(m, "primary", Bool(TRUE)) END;
  IF a.differentGunner THEN Pair(m, "different-gunner", Bool(TRUE)) END;
  Overrides(m, "points", a.points.overridden, "damage", a.hasDamage & a.damage.overridden);
  Extras(m, a.extra);
  RETURN m
END AttrNode;

PROCEDURE DefectNode(x: C.Defect): Node;
  VAR m: Node; df: Ch.Defect;
BEGIN
  df := x(Ch.Defect);
  m := d.CreateMapping();
  Name(m, df.name, df.subject, df.hasSubject, df.packed);
  IF df.hasLevel THEN Pair(m, "level", Int(df.rank)) END;
  Pair(m, "points", Num(df.points));
  TextPair(m, "details", df.hasDetails, df.details);
  Overrides(m, "points", df.points.overridden, "", FALSE);
  Extras(m, df.extra);
  RETURN m
END DefectNode;

PROCEDURE SkillNode(x: C.Skill): Node;
  VAR m: Node; s: Ch.Skill;
BEGIN
  s := x(Ch.Skill);
  m := d.CreateMapping();
  Pair(m, "name", Text(s.name));
  Pair(m, "level", IntOr(s.levelIsText, s.levelText, s.level));
  Pair(m, "points", Num(s.points));
  IF s.hasSpecialisations THEN Pair(m, "specialisations", Strings(s.specialisations)) END;
  Overrides(m, "points", s.points.overridden, "", FALSE);
  Extras(m, s.extra);
  RETURN m
END SkillNode;

(* ---- Entities ---- *)

PROCEDURE NewStat(e: Ch.Entity; name: ARRAY OF CHAR; i: INTEGER): Node;
  VAR m: Node;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Plain(name)); Pair(m, "value", Int(e.stat[i])); Pair(m, "points", Num(e.statPoints[i]));
  Overrides(m, "points", e.statPoints[i].overridden, "", FALSE);
  RETURN m
END NewStat;

PROCEDURE NewDerived(name: ARRAY OF CHAR; VAR n: C.Number): Node;
  VAR m: Node;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Plain(name)); Pair(m, "value", Num(n));
  Overrides(m, "value", n.overridden, "", FALSE);
  RETURN m
END NewDerived;

PROCEDURE Stats(m: Node; e: Ch.Entity);
  VAR seq: Node; s: Ch.Stat;
BEGIN
  IF e.fromFile OR (e.stats # NIL) THEN
    IF ~e.hasStats & (e.stats = NIL) THEN RETURN END;
    seq := d.CreateSequence(); s := e.stats;
    WHILE s # NIL DO seq.Append(StatNode(e, s)); s := s.next END;
    Pair(m, "stats", seq)
  ELSIF ~e.isMecha THEN
    seq := d.CreateSequence();
    seq.Append(NewStat(e, "Body", C.Body)); seq.Append(NewStat(e, "Mind", C.Mind));
    seq.Append(NewStat(e, "Soul", C.Soul));
    Pair(m, "stats", seq)
  END
END Stats;

PROCEDURE Derived(m: Node; e: Ch.Entity);
  VAR seq: Node; x: Ch.DerivedValue;
BEGIN
  IF e.fromFile & ~e.hasDerived & (e.derived = NIL) THEN RETURN END;
  seq := d.CreateSequence();
  IF e.fromFile OR (e.derived # NIL) THEN
    x := e.derived;
    WHILE x # NIL DO seq.Append(DerivedNode(e, x)); x := x.next END
  ELSE
    IF ~e.isMecha THEN seq.Append(NewDerived("ACV", e.acv)); seq.Append(NewDerived("DCV", e.dcv)) END;
    seq.Append(NewDerived("HP", e.hp));
    IF ~e.isMecha THEN seq.Append(NewDerived("EP", e.ep)); seq.Append(NewDerived("SV", e.sv)) END;
    IF e.hasAR OR e.ar.overridden THEN seq.Append(NewDerived("AR", e.ar)) END
  END;
  Pair(m, "derived", seq)
END Derived;

PROCEDURE HouseSkillNode(x: C.HouseSkill): Node;
  VAR m, costs: Node; h: Ch.HouseSkill; g: INTEGER; name: ARRAY 64 OF CHAR; err: Fyaml.Error;
BEGIN
  h := x(Ch.HouseSkill);
  m := d.CreateMapping();
  Pair(m, "name", Text(h.name));
  costs := d.CreateMapping();
  FOR g := 0 TO R.NGenres - 1 DO
    IF h.cost[g] > 0 THEN
      R.GenreName(g, name);
      IF ok THEN ok := costs.AppendPair(Plain(name), Int(h.cost[g]), err) END
    END
  END;
  Pair(m, "costs", costs);
  TextPair(m, "stat", h.hasStat, h.stat);
  IF h.hasSpecializations THEN Pair(m, "specializations", Strings(h.specializations)) END;
  RETURN m
END HouseSkillNode;

PROCEDURE Creation(m: Node; e: Ch.Entity);
  VAR n, o, seq: Node; k: SET; c: C.Creation; name: ARRAY 64 OF CHAR; h: C.HouseSkill;
BEGIN
  k := e.creationKeys; c := e.creation;
  IF ~e.hasCreation & (k = {}) THEN RETURN END;
  n := d.CreateMapping();
  IF Ch.CharacterPointsKey IN k THEN Pair(n, "character-points", Int(c.characterPoints)) END;
  IF Ch.BackgroundPointsKey IN k THEN Pair(n, "background-points", Int(c.backgroundPoints)) END;
  IF (Ch.GenreKey IN k) & (c.genre # C.NoGenre) THEN R.GenreName(c.genre, name); Pair(n, "genre", Plain(name)) END;
  IF (Ch.SkillPointsKey IN k) & (c.skillPoints # C.Unset) THEN Pair(n, "skill-points", Int(c.skillPoints)) END;
  IF k * {Ch.OptionsKey, Ch.StagedStatCostKey, Ch.StatCeilingKey, Ch.BonusCeilingKey, Ch.AutoFireSlotsKey} # {} THEN
    o := d.CreateMapping();
    IF Ch.StagedStatCostKey IN k THEN Pair(o, "staged-stat-cost", Bool(c.stagedStatCost)) END;
    IF Ch.StatCeilingKey IN k THEN Pair(o, "stat-ceiling", Int(c.statCeiling)) END;
    IF Ch.BonusCeilingKey IN k THEN Pair(o, "bonus-point-ceiling", Int(c.bonusCeiling)) END;
    IF Ch.AutoFireSlotsKey IN k THEN Pair(o, "auto-fire-slots", Int(c.autoFireSlots)) END;
    Pair(n, "options", o)
  END;
  IF (Ch.HouseSkillsKey IN k) OR (c.houseSkills # NIL) THEN
    seq := d.CreateSequence(); h := c.houseSkills;
    WHILE h # NIL DO seq.Append(HouseSkillNode(h)); h := h.next END;
    Pair(n, "house-skills", seq)
  END;
  Pair(m, "creation", n)
END Creation;

PROCEDURE EntityNode(e: Ch.Entity): Node;
  VAR m, seq: Node; a: C.Attr; df: C.Defect; s: C.Skill;
BEGIN
  m := d.CreateMapping();
  TextPair(m, "name", e.hasName, e.name);
  TextPair(m, "tagline", e.hasTagline, e.tagline);
  TextPair(m, "description", e.hasDescription, e.description);
  TextPair(m, "size", e.hasSize, e.size);
  IF e.hasMechaKey OR e.isMecha THEN Pair(m, "mecha", Bool(e.isMecha)) END;
  Creation(m, e);
  Stats(m, e);
  Derived(m, e);
  IF e.hasAttributes OR (e.attrs # NIL) THEN
    seq := d.CreateSequence(); a := e.attrs;
    WHILE a # NIL DO seq.Append(AttrNode(a)); a := a.next END;
    Pair(m, "attributes", seq)
  END;
  IF e.hasDefects OR (e.defects # NIL) THEN
    seq := d.CreateSequence(); df := e.defects;
    WHILE df # NIL DO seq.Append(DefectNode(df)); df := df.next END;
    Pair(m, "defects", seq)
  END;
  IF e.hasSkills OR (e.skills # NIL) THEN
    seq := d.CreateSequence(); s := e.skills;
    WHILE s # NIL DO seq.Append(SkillNode(s)); s := s.next END;
    Pair(m, "skills", seq)
  END;
  IF e.hasNotes OR (e.notes.n > 0) THEN Pair(m, "notes", Strings(e.notes)) END;
  Extras(m, e.extra);
  RETURN m
END EntityNode;

(* The document of the entities es, in order; NIL if building it failed
   (a duplicate key: a programmer's error, or two unknown keys the same
   once read). *)
PROCEDURE Document*(es: Ch.Entities): Fyaml.Document;
  VAR root: Node; i: LONGINT;
BEGIN
  d := Fyaml.NewDocument(); ok := TRUE;
  root := d.CreateSequence(); d.SetRoot(root);
  IF es # NIL THEN FOR i := 0 TO LEN(es^) - 1 DO root.Append(EntityNode(es[i])) END END;
  IF ~ok THEN d.Close; d := NIL END;
  RETURN d
END Document;

(* The entities es as YAML text; NIL as Document. *)
PROCEDURE ToText*(es: Ch.Entities): Rope;
  VAR doc: Fyaml.Document; s: Fyaml.String; err: Fyaml.Error; r: Rope;
BEGIN
  doc := Document(es); r := NIL;
  IF doc # NIL THEN
    s := doc.ToYAML(Fyaml.emitModeBlock, err);
    IF s # NIL THEN r := Ropes.FromString(s^) END;
    doc.Close
  END;
  d := NIL;
  RETURN r
END ToText;

(* Writes the entities es to the file at path, through path.tmp, which
   replaces it only once written.  FALSE, with msg, if it couldn't be,
   the old file left as it was. *)
PROCEDURE SaveAll*(es: Ch.Entities; path: ARRAY OF CHAR; VAR msg: Rope): BOOLEAN;
  VAR doc: Fyaml.Document; err: Fyaml.Error; tmp, p: Besm2Text.String; t: Rope; e: Platform.ErrorCode;
    written: BOOLEAN;
BEGIN
  msg := NIL;
  doc := Document(es);
  IF doc = NIL THEN
    msg := Ropes.FromString("the entities' YAML couldn't be built (a duplicate key)"); RETURN FALSE
  END;
  t := Ropes.FromString(path); Besm2Text.Add(t, ".tmp"); tmp := Besm2Text.Chars(t);
  written := doc.ToFile(tmp^, Fyaml.emitModeBlock, err);
  doc.Close; d := NIL;
  IF ~written THEN
    msg := Besm2Text.Trim(Ropes.FromString(err.msg^));
    e := Platform.Unlink(tmp^);
    RETURN FALSE
  END;
  p := Besm2Text.Chars(Ropes.FromString(path));
  e := Platform.Rename(tmp^, p^);
  IF e # 0 THEN
    msg := Ropes.FromString("couldn't replace "); Besm2Text.Add(msg, path);
    Besm2Text.Add(msg, " with "); Besm2Text.Add(msg, tmp^); Besm2Text.Add(msg, " (error ");
    msg := Ropes.Cat(msg, Besm2Text.Int(e)); Besm2Text.Add(msg, ")");
    RETURN FALSE
  END;
  RETURN TRUE
END SaveAll;

END Besm2Save.
