MODULE Besm2Check; (* What a file says that its numbers don't: aliases, ranges, deprecated keys *)

(* PLAN.md, A3, and Part B, step 4: besm2_calc_po's --check reports,
   besides the numbers that disagree with the rules (Besm2Character's
   differences),
   - as an error, every `points` or `value` outside -999..999 (e.g.
     "Hero: stats/Body: points 2147483647 is outside -999..999"), the
     overflow the formatters don't catch (A1 results, open question 9);
   - as a warning, every YAML alias, which besm2_fmt doesn't resolve
     and the Oberon ports do (A1 results);
   - as warnings, `enhancements` and `limiters` (4E's shapes, deprecated
     for 2E files: open question 2), `different-gunner` on a character
     (it is a mecha's weapon's, p. 82, PDF 84: open question 15), and
     empty strings and lists.
   They are looked for on the file's nodes, not on what Besm2Character
   made of them, since an alias exists only before the document is
   resolved, and an empty string only as written.

   An anchor (&name) no alias names changes nothing, and polibfyaml
   can't see one, so only aliases are reported (2026-11-06).

   Messages name the entity (its name, or "entity N"), the section, and
   the item by its name ("stats/Body", "attributes/Weapon Attack: Gun");
   an alias, which has a place in the file, by its path and its line
   and column.  besm2_calc_po puts the file's name in front. *)

IMPORT Besm2Text, Fyaml, Ropes;

CONST
  (* What a note is: Besm2Character.Notice's kinds. *)
  Difference* = 0; Warning* = 1; Error* = 2;
  (* The range of a number --check accepts (open question 9). *)
  Low* = -999; High* = 999;

TYPE
  Rope = Ropes.Rope;
  (* Takes each thing found, of kind Warning or Error. *)
  Note* = PROCEDURE (kind: INTEGER; r: Rope);

VAR label: Rope;   (* the entity's, for Say *)

(* i's decimal digits, after r ("-" first if negative). *)
PROCEDURE AddLong(VAR r: Rope; i: LONGINT);
  VAR d: ARRAY 24 OF CHAR; n: INTEGER; s: ARRAY 2 OF CHAR;
BEGIN
  IF i < 0 THEN Besm2Text.Add(r, "-"); i := -i END;
  n := 0;
  REPEAT d[n] := CHR(ORD("0") + SHORT(i MOD 10)); i := i DIV 10; INC(n) UNTIL i = 0;
  s[1] := 0X;
  WHILE n > 0 DO DEC(n); s[0] := d[n]; Besm2Text.Add(r, s) END
END AddLong;

(* ---- Aliases ---- *)

(* Every alias in n, a node of a document parsed with Fyaml.NoResolve,
   to note, as "PATH (line L, column C): an alias, star and name in
   brackets, ...". *)
PROCEDURE Aliases*(n: Fyaml.Node; note: Note);
  VAR it: Fyaml.ItemIter; pi: Fyaml.PairIter; item, k, v: Fyaml.Node;
    r: Rope; line, column: INTEGER; s: Fyaml.String;
BEGIN
  IF n = NIL THEN RETURN END;
  IF n.IsAlias() THEN
    s := n.Path(); r := Ropes.FromString(s^);
    IF n.Location(line, column) THEN
      Besm2Text.Add(r, " (line "); Besm2Text.AddInt(r, line);
      Besm2Text.Add(r, ", column "); Besm2Text.AddInt(r, column); Besm2Text.Add(r, ")")
    END;
    s := n.Scalar(); Besm2Text.Add(r, ": an alias (*"); Besm2Text.Add(r, s^);
    Besm2Text.Add(r, "), which besm2_fmt doesn't resolve and the Oberon-2 programs do");
    note(Warning, r)
  ELSIF n.IsSequence() THEN
    n.Items(it); WHILE it.Next(item) DO Aliases(item, note) END
  ELSIF n.IsMapping() THEN
    n.Pairs(pi); WHILE pi.Next(k, v) DO Aliases(k, note); Aliases(v, note) END
  END
END Aliases;

(* ---- An entity ---- *)

PROCEDURE Text(n: Fyaml.Node): Rope;
  VAR s: Fyaml.String;
BEGIN s := n.Scalar(); RETURN Ropes.FromString(s^)
END Text;

(* path/key, or key alone at the top (path NIL). *)
PROCEDURE Sub(path: Rope; key: Rope): Rope;
  VAR r: Rope;
BEGIN
  IF path = NIL THEN RETURN key END;
  r := path; Besm2Text.Add(r, "/"); RETURN Ropes.Cat(r, key)
END Sub;

(* "LABEL: PATH: text", or "LABEL: text" for the entity itself. *)
PROCEDURE Say(note: Note; kind: INTEGER; path: Rope; text: ARRAY OF CHAR);
  VAR r: Rope;
BEGIN
  r := label; Besm2Text.Add(r, ": ");
  IF path # NIL THEN r := Ropes.Cat(r, path); Besm2Text.Add(r, ": ") END;
  Besm2Text.Add(r, text); note(kind, r)
END Say;

(* An item's name for messages: "Body", "Weapon Attack: Gun", or its
   index when it has none. *)
PROCEDURE ItemName(m: Fyaml.Node; i: INTEGER): Rope;
  VAR r: Rope; v: Fyaml.Node;
BEGIN
  r := NIL;
  IF m.HasKey("name") THEN v := m.Value("name"); IF v.IsScalar() THEN r := Besm2Text.Trim(Text(v)) END END;
  IF r = NIL THEN Besm2Text.AddInt(r, i) END;
  IF m.HasKey("subject") THEN
    v := m.Value("subject");
    IF v.IsScalar() THEN Besm2Text.Add(r, ": "); r := Ropes.Cat(r, Besm2Text.Trim(Text(v))) END
  END;
  RETURN r
END ItemName;

(* Every empty string and empty list or mapping in n, at path: a
   list's mappings named by ItemName, its other items by index. *)
PROCEDURE Empties(n: Fyaml.Node; path: Rope; note: Note);
  VAR it: Fyaml.ItemIter; pi: Fyaml.PairIter; item, k, v: Fyaml.Node; i: INTEGER; w: Rope;
BEGIN
  IF n = NIL THEN RETURN END;
  IF n.IsScalar() THEN
    IF Besm2Text.Trim(Text(n)) = NIL THEN Say(note, Warning, path, "an empty string") END
  ELSIF n.IsSequence() THEN
    IF n.Length() = 0 THEN Say(note, Warning, path, "an empty list")
    ELSE
      i := 0; n.Items(it);
      WHILE it.Next(item) DO
        IF item.IsMapping() THEN w := ItemName(item, i) ELSE w := NIL; Besm2Text.AddInt(w, i) END;
        Empties(item, Sub(path, w), note); INC(i)
      END
    END
  ELSIF n.IsMapping() THEN
    IF n.Length() = 0 THEN Say(note, Warning, path, "an empty mapping")
    ELSE
      n.Pairs(pi);
      WHILE pi.Next(k, v) DO IF k.IsScalar() THEN Empties(v, Sub(path, Text(k)), note) END END
    END
  END
END Empties;

(* The value of n's key as an integer, if it is one. *)
PROCEDURE IntValue(m: Fyaml.Node; key: ARRAY OF CHAR; VAR i: LONGINT): BOOLEAN;
  VAR v: Fyaml.Node; err: Fyaml.Error;
BEGIN
  IF ~m.HasKey(key) THEN RETURN FALSE END;
  v := m.Value(key);
  RETURN v.IsScalar() & v.IsInteger() & v.LongIntValue(i, err)
END IntValue;

PROCEDURE Range(m: Fyaml.Node; where: Rope; key: ARRAY OF CHAR; note: Note);
  VAR i: LONGINT; r: Rope;
BEGIN
  IF IntValue(m, key, i) & ((i < Low) OR (i > High)) THEN
    r := where; Besm2Text.Add(r, ": "); Besm2Text.Add(r, key); Besm2Text.Add(r, " ");
    AddLong(r, i); Besm2Text.Add(r, " is outside ");
    Besm2Text.AddInt(r, Low); Besm2Text.Add(r, ".."); Besm2Text.AddInt(r, High);
    note(Error, r)
  END
END Range;

(* The items of section key of entity m. *)
PROCEDURE Section(m: Fyaml.Node; key: ARRAY OF CHAR; isMecha: BOOLEAN; note: Note);
  VAR s, item: Fyaml.Node; it: Fyaml.ItemIter; where, r: Rope; i: INTEGER;
BEGIN
  IF ~m.HasKey(key) THEN RETURN END;
  s := m.Value(key);
  IF ~s.IsSequence() THEN RETURN END;
  i := 0; s.Items(it);
  WHILE it.Next(item) DO
    IF item.IsMapping() THEN
      where := Sub(Ropes.FromString(key), ItemName(item, i));
      r := label; Besm2Text.Add(r, ": "); r := Ropes.Cat(r, where);
      Range(item, r, "points", note); Range(item, r, "value", note);
      IF item.HasKey("enhancements") THEN
        Say(note, Warning, where, "enhancements are 4th Edition's, deprecated for 2nd Edition files")
      END;
      IF item.HasKey("limiters") THEN
        Say(note, Warning, where, "limiters are 4th Edition's, deprecated for 2nd Edition files")
      END;
      IF ~isMecha & item.HasKey("different-gunner") THEN
        Say(note, Warning, where, "different-gunner on a character: it is for a mecha's weapons (p. 82, PDF 84)")
      END
    END;
    INC(i)
  END
END Section;

(* What entity m, called name in messages, says that --check reports
   besides its numbers. *)
PROCEDURE Entity*(m: Fyaml.Node; name: Rope; note: Note);
  VAR v: Fyaml.Node; isMecha, b: BOOLEAN; err: Fyaml.Error;
BEGIN
  IF (m = NIL) OR ~m.IsMapping() THEN RETURN END;
  label := name;
  isMecha := FALSE;
  IF m.HasKey("mecha") THEN v := m.Value("mecha"); isMecha := v.IsScalar() & v.BooleanValue(b, err) & b END;
  Section(m, "stats", isMecha, note);
  Section(m, "derived", isMecha, note);
  Section(m, "attributes", isMecha, note);
  Section(m, "defects", isMecha, note);
  Section(m, "skills", isMecha, note);
  Empties(m, NIL, note)
END Entity;

END Besm2Check.
