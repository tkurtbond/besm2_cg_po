MODULE Besm2Upgrade; (* besm2_calc_po --upgrade: the free text of a file into the keys of A4 *)

(* PLAN.md, A3 and A4, and Part B, step 4.  Install makes each entity
   Besm2Character.Read reads go through Entity before it is computed,
   so the numbers it compares and adopts are those of the upgraded
   entity, and Besm2Save then writes A4's keys:
   - a packed name, "Own a Big Mecha: FV2021 Coleopteran", is written
     as `name` and `subject` (Besm2Character already reads it so);
   - a name the rulebook has under another (an alias, question 11:
     "Weapon", "Hanger Queen", "Super-Strength", "Unique Defect",
     "Unarmed Defence") is written as BESM2ER's; Features or
     Accessories as "Accessories" on a mecha and "Features" otherwise
     (p. 32, PDF 34); a difference of case alone is left;
   - a Defect gets its `level`, the rank Besm2Character gave it from
     its points and its Bonus Points a rank (Table 2-3, p. 100,
     PDF 102);
   - a Weapon Attack's `details`, in the book's notation (p. 92,
     PDF 94) or the fixtures' -- "Damage ACV+45, Long-Range: 5 km,
     Unreliable", "Limited Shots ×2 [3 shots]" -- become `damage`,
     `abilities` and `disabilities`, when every part of them is one of
     those; otherwise they are left as they are, with a warning naming
     the first part that isn't.  The damage written there is the
     file's, compared with the rules' as any other;
   - YAML aliases are expanded, since Besm2Save writes what was read.
   It doesn't touch `enhancements` or `limiters` (open question 2) and
   can't make up a `creation`. *)

IMPORT Ch := Besm2Character, C := Besm2Calc, R := Besm2Rules, Besm2Text, Ropes;

TYPE Rope = Ropes.Rope;

VAR features: R.Item;

(* ---- Names ---- *)

(* name, made BESM2ER's name of it, its item, unless they differ only
   in case; Features or Accessories by entity. *)
PROCEDURE Canonical(VAR name: Rope; it: R.Item; isMecha: BOOLEAN);
  VAR s: Besm2Text.String; word: ARRAY 16 OF CHAR;
BEGIN
  IF it = NIL THEN RETURN END;
  s := Besm2Text.Chars(Besm2Text.Trim(name));
  IF it = features THEN
    IF isMecha THEN word := "Accessories" ELSE word := "Features" END;
    IF ~R.SameName(word, s^) THEN name := Ropes.FromString(word) END
  ELSIF ~R.SameName(it.name, s^) THEN name := Ropes.FromString(it.name)
  END
END Canonical;

(* ---- A Weapon Attack's details ---- *)

PROCEDURE IsDigit(c: CHAR): BOOLEAN;
BEGIN RETURN (c >= "0") & (c <= "9")
END IsDigit;

PROCEDURE Lower(c: CHAR): CHAR;
BEGIN IF (c >= "A") & (c <= "Z") THEN c := CHR(ORD(c) + 32) END; RETURN c
END Lower;

(* s[from..to-1] as a number of digits, optionally signed. *)
PROCEDURE Number(VAR s: ARRAY OF CHAR; from, to: LONGINT; VAR n: INTEGER): BOOLEAN;
  VAR neg: BOOLEAN;
BEGIN
  neg := FALSE; n := 0;
  IF (from < to) & ((s[from] = "+") OR (s[from] = "-")) THEN neg := s[from] = "-"; INC(from) END;
  IF from >= to THEN RETURN FALSE END;
  WHILE from < to DO
    IF ~IsDigit(s[from]) OR (n > 9999) THEN RETURN FALSE END;
    n := n * 10 + ORD(s[from]) - ORD("0"); INC(from)
  END;
  IF neg THEN n := -n END;
  RETURN TRUE
END Number;

(* s begins with p, ignoring case. *)
PROCEDURE Prefix(VAR s: ARRAY OF CHAR; p: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (p[i] # 0X) & (Lower(s[i]) = Lower(p[i])) DO INC(i) END;
  RETURN p[i] = 0X
END Prefix;

(* "Damage 45", "Damage ACV+45", "Damage ACV + 45": its 45. *)
PROCEDURE Damage(part: Rope; VAR n: INTEGER): BOOLEAN;
  VAR s: Besm2Text.String; i, j, len: LONGINT;
BEGIN
  s := Besm2Text.Chars(part); len := Ropes.Length(part);
  IF ~Prefix(s^, "damage ") THEN RETURN FALSE END;
  i := 7;
  WHILE (i < len) & (s[i] = " ") DO INC(i) END;
  IF (i + 3 <= len) & (Lower(s[i]) = "a") & (Lower(s[i + 1]) = "c")
     & (Lower(s[i + 2]) = "v") THEN
    i := i + 3; WHILE (i < len) & (s[i] = " ") DO INC(i) END;
    IF (i < len) & (s[i] = "+") THEN INC(i) END;
    WHILE (i < len) & (s[i] = " ") DO INC(i) END
  END;
  j := len; WHILE (j > i) & (s[j - 1] = " ") DO DEC(j) END;
  RETURN Number(s^, i, j, n)
END Damage;

(* The Ability or Disability named name, or with its hyphens spaces
   ("Long-Range"). *)
PROCEDURE FindMod(name: Rope): R.Item;
  VAR s: Besm2Text.String; it: R.Item; i: LONGINT;
BEGIN
  s := Besm2Text.Chars(name);
  it := R.FindKind(R.Ability, s^);
  IF it = NIL THEN it := R.FindKind(R.Disability, s^) END;
  IF it = NIL THEN
    i := 0; WHILE s[i] # 0X DO IF s[i] = "-" THEN s[i] := " " END; INC(i) END;
    it := R.FindKind(R.Ability, s^);
    IF it = NIL THEN it := R.FindKind(R.Disability, s^) END
  END;
  RETURN it
END FindMod;

(* "Name", "Name ×2", "Name x2", each with a detail after ": " or in
   brackets: an Ability or Disability, written with its BESM2ER name.
   Taken more than once, it counts as its slots that many times (A4,
   question 12). *)
PROCEDURE ModOf(part: Rope): Ch.Mod;
  VAR s: Besm2Text.String; len, i, end, digits: LONGINT; name, detail: Rope;
    times: INTEGER; it: R.Item; m: Ch.Mod;
BEGIN
  s := Besm2Text.Chars(part); len := Ropes.Length(part); detail := NIL; end := len;
  IF (len > 0) & (s[len - 1] = "]") THEN
    i := Ropes.IndexChar(part, "[", 0);
    IF i < 0 THEN RETURN NIL END;
    detail := Besm2Text.Trim(Ropes.Substring(part, i + 1, len - i - 2)); end := i
  ELSE
    i := Ropes.Find(part, ":", 0);
    IF i >= 0 THEN detail := Besm2Text.Trim(Ropes.Substring(part, i + 1, len - i - 1)); end := i END
  END;
  WHILE (end > 0) & (s[end - 1] = " ") DO DEC(end) END;
  (* A count: digits after "×" (UTF-8 C3 97) or after " x". *)
  times := 1; digits := end;
  WHILE (digits > 0) & IsDigit(s[digits - 1]) DO DEC(digits) END;
  IF digits < end THEN
    IF (digits >= 2) & (s[digits - 2] = 0C3X) & (s[digits - 1] = 97X) & Number(s^, digits, end, times) THEN
      end := digits - 2
    ELSIF (digits >= 2) & ((s[digits - 1] = "x") OR (s[digits - 1] = "X")) & (s[digits - 2] = " ")
          & Number(s^, digits, end, times) THEN
      end := digits - 1
    END;
    WHILE (end > 0) & (s[end - 1] = " ") DO DEC(end) END
  END;
  name := Besm2Text.Trim(Ropes.Substring(part, 0, end));
  IF (name = NIL) OR (times < 1) THEN RETURN NIL END;
  it := FindMod(name);
  IF it = NIL THEN RETURN NIL END;
  NEW(m); m.name := Ropes.FromString(it.name);
  m.hasDetail := detail # NIL; m.detail := detail;
  IF times > 1 THEN C.InitMod(m, it, it.slots * times) ELSE C.InitMod(m, it, 0) END;
  RETURN m
END ModOf;

(* a's details as damage, abilities and disabilities, if they all are;
   else a warning. *)
PROCEDURE Weapon(e: Ch.Entity; a: Ch.Attr);
  VAR s: Besm2Text.String; text, part, bad, r: Rope; i, start, len: LONGINT; depth, damage: INTEGER;
    abilities, disabilities: C.Mod; m: Ch.Mod; hasDamage, ok: BOOLEAN; p: ARRAY 32 OF CHAR;
BEGIN
  s := Besm2Text.Chars(a.details);
  i := 0; WHILE s[i] # 0X DO IF s[i] < " " THEN s[i] := " " END; INC(i) END;
  text := Ropes.FromString(s^); len := Ropes.Length(text);
  abilities := NIL; disabilities := NIL; hasDamage := FALSE; damage := 0;
  ok := TRUE; bad := NIL; depth := 0; start := 0; i := 0;
  WHILE ok & (i <= len) DO
    IF (i = len) OR ((s[i] = ",") & (depth = 0)) THEN
      part := Besm2Text.Trim(Ropes.Substring(text, start, i - start));
      IF part = NIL THEN (* ", ," or a trailing comma *)
      ELSIF ~hasDamage & Damage(part, damage) THEN hasDamage := TRUE
      ELSE
        m := ModOf(part);
        IF m = NIL THEN ok := FALSE; bad := part
        ELSIF m.item.kind = R.Ability THEN C.AddMod(abilities, m)
        ELSE C.AddMod(disabilities, m)
        END
      END;
      start := i + 1
    ELSIF (s[i] = "(") OR (s[i] = "[") THEN INC(depth)
    ELSIF ((s[i] = ")") OR (s[i] = "]")) & (depth > 0) THEN DEC(depth)
    END;
    INC(i)
  END;
  IF ok THEN
    a.abilities := abilities; a.disabilities := disabilities;
    a.hasAbilities := abilities # NIL; a.hasDisabilities := disabilities # NIL;
    a.structured := TRUE; a.hasDamage := TRUE;
    Ch.SetFileDamage(a, hasDamage, damage);
    a.hasDetails := FALSE; a.details := NIL
  ELSE
    r := Ch.Place(e, a.name, a.subject, a.hasSubject, a.item);
    Besm2Text.Add(r, ': details not upgraded: "'); r := Ropes.Cat(r, bad);
    Besm2Text.Add(r, '" is neither a damage nor a Weapon Ability ('); R.PagesText(R.WeaponAbilitiesPage, p);
    Besm2Text.Add(r, p); Besm2Text.Add(r, ") or Disability ("); R.PagesText(R.WeaponDisabilitiesPage, p);
    Besm2Text.Add(r, p); Besm2Text.Add(r, ")");
    Ch.AddNotice(Ch.Warning, r)
  END
END Weapon;

(* ---- Entities ---- *)

PROCEDURE Entity(e: Ch.Entity);
  VAR a: C.Attr; d: C.Defect; s: C.Skill;
BEGIN
  a := e.attrs;
  WHILE a # NIL DO
    WITH a: Ch.Attr DO
      a.packed := FALSE;
      Canonical(a.name, a.item, e.isMecha);
      IF a.weapon & ~a.structured & a.hasDetails THEN Weapon(e, a) END
    END;
    a := a.next
  END;
  d := e.defects;
  WHILE d # NIL DO
    WITH d: Ch.Defect DO d.packed := FALSE; Canonical(d.name, d.item, e.isMecha); d.hasLevel := TRUE END;
    d := d.next
  END;
  s := e.skills;
  WHILE s # NIL DO
    WITH s: Ch.Skill DO IF s.house = NIL THEN Canonical(s.name, s.item, FALSE) END END;
    s := s.next
  END
END Entity;

(* Upgrades every entity Besm2Character.Read reads from now on. *)
PROCEDURE Install*;
BEGIN Ch.SetUpgrade(Entity)
END Install;

BEGIN
  features := R.Find("Features or Accessories"); ASSERT(features # NIL)
END Besm2Upgrade.
