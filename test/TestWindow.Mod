MODULE TestWindow; (* Besm2Window: the Character tab, driven as a user would, and its files *)

(* Needs a display: run by make test-gui, under make test-headless or
   make test-sway (AGENTS.md: never on the desktop).  Widgets are driven
   directly, as pofltk's tests do: a value set, then DoCallback; a menu
   item picked, so File > Quit is checked on Wayland too, where
   test/quit.sh can't send keys.  What would wait for the user (a
   message, a question, a file chooser, a line of text) is answered by
   the procedures here.

   PLAN.md, Part B, step 6: the Stats, the derived values and their
   overrides, the points and their red, the warnings; File New, Open,
   Save, Save As and the save-first question; Rulebook > Open, Choose
   PDF... and Viewer....  Step 7: the Attributes, Defects, Skills and
   Background tabs, then what they made saved and loaded again.  Step
   8: the Weapon Attack dialog, its Cancel and OK, and Close while it
   is open.  Step 9: the Mecha tab, the Character menu and the
   entities' Choice, then the file of several saved and loaded again.
   Step 10: Character > Creation..., each of its controls, its Cancel,
   OK and Copy from, a mecha's owner's, and Add Character's copy of the
   creation; Close while it is open.  Step 11: the Preview tab, made
   only while it is shown, in each format, its Copy and Save...; the
   previews it saves in ../obj test/preview.sh compares with the
   formatters'.  Runs in test/: its files are data/*.yaml, and what it saves goes in
   ../obj; it opens copies of the data/*.yaml it changes there, so a
   File > Save gone wrong can't change it.  poc drops a string literal
   inside an array index (a[F("x")]), so none is written there. *)

IMPORT Check, Fl, FlBrowsers, FlText, FlValuators, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Background,
  Besm2ItemPanel, MP := Besm2MechaPanel, Besm2Save, Besm2Text, Besm2Viewer, Besm2Widgets, D := Besm2WeaponDialog, Cr := Besm2Creation, Pv := Besm2Preview, W := Besm2Window, Out, Ropes;

CONST
  SavePath = "../obj/window-test.yaml";
  SavePath2 = "../obj/window-two.yaml";
  OpenPath = "../obj/window.yaml";  (* data/window.yaml, copied *)
  BarePath = "../obj/bare.yaml";  (* data/bare.yaml, copied *)
  WeaponPath = "../obj/window-weapon.yaml";
  SeveralPath = "../obj/window-several.yaml";  (* data/window.yaml, copied *)
  CreationPath = "../obj/window-creation.yaml";  (* data/window.yaml, copied *)
  CampaignPath = "../obj/window-campaign.yaml";
  PreviewPath = "../obj/preview.yaml";  (* data/window.yaml, copied; test/preview.sh formats it *)

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;           (* how many messages were shown *)
  told: Rope;               (* the last one *)
  answer, asked: INTEGER;   (* what ask answers, and how often it was asked *)
  question: Rope;           (* what ask asked last *)
  chosen: Rope;             (* what choosePath and choosePdf answer; NIL: cancelled *)
  suggestedName: Rope;      (* what Preview's file chooser was told to suggest *)
  typed: Rope;              (* what askText answers; NIL: cancelled *)
  prompted: Rope;           (* what askText was shown last *)
  confirmed: BOOLEAN;       (* what confirm answers *)
  confirms: INTEGER;        (* how often it was asked *)
  es: Ch.Entities;
  e: Ch.Entity;
  msg: Rope;
  s: ARRAY 256 OF CHAR;
  i, key, before: INTEGER;
  state: SET;
  ok: BOOLEAN;

(* ---- What would wait for the user ---- *)

PROCEDURE Tell(text: Rope);
  VAR s: Besm2Text.String;
BEGIN INC(tells); told := text; s := Besm2Text.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(q: Rope): INTEGER;
BEGIN INC(asked); question := q; RETURN answer
END Ask;

PROCEDURE ChoosePath(save: BOOLEAN; VAR p: Rope): BOOLEAN;
BEGIN p := chosen; RETURN chosen # NIL
END ChoosePath;

PROCEDURE ChoosePdf(VAR p: Rope): BOOLEAN;
BEGIN p := chosen; RETURN chosen # NIL
END ChoosePdf;

(* Preview's file chooser: chosen, and what it suggested kept. *)
PROCEDURE ChoosePreview(suggested: Rope; VAR p: Rope): BOOLEAN;
BEGIN suggestedName := suggested; p := chosen; RETURN chosen # NIL
END ChoosePreview;

PROCEDURE AskText(prompt: Rope; VAR text: Rope): BOOLEAN;
BEGIN prompted := prompt; IF typed # NIL THEN text := typed END; RETURN typed # NIL
END AskText;

PROCEDURE Confirm(q, yes: Rope): BOOLEAN;
BEGIN INC(confirms); question := q; RETURN confirmed
END Confirm;

(* ---- Driving and looking ---- *)

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

PROCEDURE Is(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.EqualString(r, s)
END Is;

(* Whether r ends with s. *)
PROCEDURE Ends(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
  VAR n, m: LONGINT;
BEGIN
  n := Ropes.Length(r); m := 0; WHILE s[m] # 0X DO INC(m) END;
  RETURN (n >= m) & Ropes.EqualString(Ropes.Substring(r, n - m, m), s)
END Ends;

(* Whether the window's title is Title then rest. *)
PROCEDURE TitleIs(rest: ARRAY OF CHAR): BOOLEAN;
  VAR s: ARRAY 256 OF CHAR; r: Rope;
BEGIN
  W.window.GetLabel(s); r := Rp(W.Title); Besm2Text.Add(r, rest);
  IF ~Ropes.EqualString(r, s) THEN Out.String("    title: "); Out.String(s); Out.Ln END;
  RETURN Ropes.EqualString(r, s)
END TitleIs;

(* Whether points line i reads want, red if red. *)
PROCEDURE Line(i: INTEGER; want: ARRAY OF CHAR; red: BOOLEAN): BOOLEAN;
  VAR s: ARRAY 256 OF CHAR; color: INTEGER;
BEGIN
  W.points[i].GetLabel(s);
  IF red THEN color := Fl.Red ELSE color := Fl.ForegroundColor END;
  IF s # want THEN Out.String("    line: "); Out.String(s); Out.Ln END;
  RETURN (s = want) & (W.points[i].LabelColor() = color)
END Line;

(* Whether box b shows n: its computed number, and its override or "". *)
PROCEDURE Shows(b: Besm2Widgets.NumberBox; VAR n: C.Number): BOOLEAN;
  VAR shown, entry, want: ARRAY 32 OF CHAR;
BEGIN
  b.shown.Value(shown); b.entry.Value(entry);
  C.ComputedText(n, want);
  IF shown # want THEN RETURN FALSE END;
  IF n.overridden THEN C.Text(n, want) ELSE want := "" END;
  RETURN entry = want
END Shows;

(* Whether every number box shows the entity's number, and each
   spinner its Stat. *)
PROCEDURE AllShown(): BOOLEAN;
  VAR e: Ch.Entity; ok: BOOLEAN; i: INTEGER;
BEGIN
  e := W.entity;
  ok := Shows(W.derived[Ch.ACV], e.acv) & Shows(W.derived[Ch.DCV], e.dcv) & Shows(W.derived[Ch.HP], e.hp)
    & Shows(W.derived[Ch.EP], e.ep) & Shows(W.derived[Ch.SV], e.sv) & Shows(W.derived[Ch.AR], e.ar);
  FOR i := 0 TO C.NStats - 1 DO
    ok := ok & Shows(W.statPoints[i], e.statPoints[i]) & (ENTIER(W.statValue[i].Value() + 0.5) = e.stat[i])
  END;
  RETURN ok
END AllShown;

(* The last line of the warnings holding text; 0 if none. *)
PROCEDURE Warning(text: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER; line: ARRAY 256 OF CHAR;
BEGIN
  i := W.warnings.Count();
  WHILE i > 0 DO
    W.warnings.GetText(i, line);
    IF Ropes.Find(Rp(line), text, 0) >= 0 THEN RETURN i END;
    DEC(i)
  END;
  RETURN 0
END Warning;

(* Sets Stat i's spinner to v, as the user does. *)
PROCEDURE SetStat(i, v: INTEGER);
BEGIN W.statValue[i].SetValue(v); W.statValue[i].DoCallback
END SetStat;

(* Types text into box b and leaves it. *)
PROCEDURE Type(b: Besm2Widgets.NumberBox; text: ARRAY OF CHAR);
BEGIN b.entry.SetValue(text); b.entry.DoCallback
END Type;

PROCEDURE Pick(item: INTEGER);
BEGIN W.bar.Pick(item)
END Pick;

(* The menu item at path, with its shortcut. *)
PROCEDURE Item(path: ARRAY OF CHAR; item, wantKey: INTEGER; wantState: SET): BOOLEAN;
  VAR i, key: INTEGER; state: SET;
BEGIN
  i := W.bar.FindIndex(path);
  IF (i < 0) OR (i # item) THEN RETURN FALSE END;
  W.bar.ItemShortcut(i, key, state);
  RETURN (key = wantKey) & (state = wantState)
END Item;

(* Loads path as the program does, for what was saved. *)
PROCEDURE Reload(path: ARRAY OF CHAR): Ch.Entities;
  VAR es: Ch.Entities; msg: Rope;
BEGIN
  IF ~Ch.LoadAll(path, es, msg) THEN es := NIL END;
  RETURN es
END Reload;

(* Copies the file at from to the file at to, as entities, so what the
   window saves can't change a fixture. *)
PROCEDURE Copy(from, to: ARRAY OF CHAR);
  VAR es: Ch.Entities; msg: Rope;
BEGIN
  es := Reload(from); ASSERT(es # NIL);
  IF ~Besm2Save.SaveAll(es, to, msg) THEN HALT(98) END
END Copy;

(* ---- The lists (step 7) ---- *)

(* Whether tab t's points line i reads as the Character tab's, which
   Line checks. *)
PROCEDURE TabLine(t, i: INTEGER): BOOLEAN;
  VAR s, want: ARRAY 256 OF CHAR;
BEGIN
  W.tabPoints[t][i].GetLabel(s); W.points[i].GetLabel(want);
  RETURN (s = want) & (W.tabPoints[t][i].LabelColor() = W.points[i].LabelColor())
END TabLine;

(* Whether every tab's warnings are the Character tab's. *)
PROCEDURE TabWarnings(): BOOLEAN;
  VAR t, i: INTEGER; a, b: ARRAY 256 OF CHAR; ok: BOOLEAN;
BEGIN
  ok := TRUE;
  FOR t := 0 TO W.NLists - 1 DO
    ok := ok & (W.tabWarnings[t].Count() = W.warnings.Count());
    IF ok THEN
      FOR i := 1 TO W.warnings.Count() DO W.warnings.GetText(i, a); W.tabWarnings[t].GetText(i, b); ok := ok & (a = b) END
    END
  END;
  RETURN ok
END TabWarnings;

(* Whether line line of browser b holds s. *)
PROCEDURE Holds(b: FlBrowsers.Browser; line: INTEGER; s: ARRAY OF CHAR): BOOLEAN;
  VAR text: ARRAY 256 OF CHAR;
BEGIN
  IF (line < 1) OR (line > b.Count()) THEN RETURN FALSE END;
  b.GetText(line, text);
  IF Ropes.Find(Rp(text), s, 0) < 0 THEN Out.String("    line: "); Out.String(text); Out.Ln END;
  RETURN Ropes.Find(Rp(text), s, 0) >= 0
END Holds;

(* Selects line line of browser b, as a click does. *)
PROCEDURE Select(b: FlBrowsers.Browser; line: INTEGER);
BEGIN b.SetSelected(line, TRUE); b.DoCallback
END Select;

(* Chooses it in p's Choice, as the user does. *)
PROCEDURE ChooseItem(p: Besm2Widgets.Panel; it: R.Item);
BEGIN p.Choose(it); p.choice.DoCallback
END ChooseItem;

(* The line of option label of it (from 1). *)
PROCEDURE OptLine(it: R.Item; label: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER;
BEGIN
  i := 0; WHILE (i < it.nOptions) & ~R.SameName(it.option[i].label, label) DO INC(i) END;
  ASSERT(i < it.nOptions); RETURN i + 1
END OptLine;

(* ---- The checks ---- *)

PROCEDURE Basics;
  VAR label: ARRAY 64 OF CHAR;
BEGIN
  W.Build;
  Check.Check(W.window.IsOpen() & ~W.window.Shown(), "the window opens, not shown until asked");
  W.window.GetLabel(label);
  Check.Check(label = W.Title, "the window's title");
  Check.Check(Item("&File/&New", W.newItem, ORD("n"), Fl.Command)
    & Item("&File/&Open...", W.openItem, ORD("o"), Fl.Command)
    & Item("&File/&Save", W.saveItem, ORD("s"), Fl.Command)
    & Item("&File/Save &As...", W.saveAsItem, ORD("s"), Fl.Command + Fl.Shift)
    & Item("&File/&Quit", W.quitItem, ORD("q"), Fl.Command),
    "File: New, Open..., Save, Save As..., Quit, with Ctrl+N, O, S, Shift+S, Q");
  Check.Check(Item("&Rulebook/&Open", W.rulebookItem, 0, {})
    & Item("&Rulebook/&Choose PDF...", W.choosePdfItem, 0, {})
    & Item("&Rulebook/&Viewer...", W.viewerItem, 0, {}),
    "Rulebook: Open, Choose PDF..., Viewer...");
  W.window.Show;
  Check.Check(W.window.Shown(), "Show shows it");
  Pick(W.quitItem);
  Check.Check(~W.window.Shown() & (asked = 0), "File > Quit hides it, unchanged without asking, which ends Fl.Run");
  W.window.Show;
  W.window.DoCallback;
  Check.Check(~W.window.Shown() & (asked = 0), "so does the close button");
  W.window.Show
END Basics;

(* A new character: Stats at 1, no file, no limits. *)
PROCEDURE NewCharacter;
  VAR e: Ch.Entity; label: ARRAY 64 OF CHAR;
BEGIN
  e := W.entity;
  Check.Check((LEN(W.entities^) = 1) & (W.current = 0) & ~e.isMecha & (W.path = NIL) & ~W.modified,
    "it starts with a new character, no file, unchanged");
  Check.Check((e.stat[C.Body] = 1) & (e.stat[C.Mind] = 1) & (e.stat[C.Soul] = 1) & ~e.hasCreation,
    "its Stats are 1, and it has no creation block");
  Check.Check(AllShown(), "every box shows its number");
  Check.Check(~W.derived[Ch.AR].Visible() & W.derived[Ch.ACV].Visible() & W.derived[Ch.SV].Visible()
    & W.statValue[C.Body].Active(),
    "no armour: AR hidden; ACV to SV and the Stats shown");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 3 + Attributes 0 - Bonus Points 0 = 3 (no limit set)", FALSE),
    "Character Points: what is spent, no limit set, not red");
  Check.Check(Line(W.BonusPoints, "Bonus Points: 0 (ceiling: none)", FALSE), "Bonus Points: none, no ceiling");
  W.points[W.SkillPoints].GetLabel(label);
  Check.Check(Ropes.Find(Rp(label), "Skill Points: 0 of ", 0) = 0, "Skill Points: none spent");
  Check.Check(W.warnings.Count() = 0, "and no warnings")
END NewCharacter;

PROCEDURE Editing;
  VAR e: Ch.Entity; label: ARRAY 128 OF CHAR;
BEGIN
  e := W.entity;
  SetStat(C.Body, 5);
  Check.Check((e.stat[C.Body] = 5) & (C.Value(e.statPoints[C.Body]) = 5) & AllShown(),
    "a Stat's spinner sets it, and its points, and every number shown follows");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 7 + Attributes 0 - Bonus Points 0 = 7 (no limit set)", FALSE),
    "and the Character Points");
  Check.Check(W.modified, "a change marks the character changed");
  Check.Check(TitleIs(" *"), "and the title says so");
  W.nameIn.SetValue("Kei Tanaka"); W.nameIn.DoCallback;
  Check.Check(e.hasName & Is(e.name, "Kei Tanaka"), "the name typed is the character's");
  W.taglineIn.SetValue("  Pilot  "); W.taglineIn.DoCallback;
  Check.Check(e.hasTagline & Is(e.tagline, "Pilot"), "the tagline typed, trimmed");
  W.sizeIn.SetValue("Medium"); W.sizeIn.DoCallback;
  Check.Check(e.hasSize & Is(e.size, "Medium"), "the size typed");

  Type(W.derived[Ch.HP], "99");
  Check.Check(e.hp.overridden & (C.Value(e.hp) = 99) & AllShown(), "a number typed in HP's box overrides it");
  Type(W.statPoints[C.Mind], "4");
  Check.Check(e.statPoints[C.Mind].overridden & (e.statTotal = 10) & (e.spent = 10),
    "an override of a Stat's points counts in the Character Points");
  Type(W.statPoints[C.Mind], "");
  Check.Check(~e.statPoints[C.Mind].overridden & (e.statTotal = 7), "and emptied, the computed points count again");
  before := tells;
  Type(W.derived[Ch.SV], "lots");
  Check.Check((tells = before + 1) & ~e.sv.overridden & AllShown(), "text that isn't a number is refused, and said so");
  Check.Check(Ends(told, "SV: a whole number. The computed number is used."), "naming the box");
  Type(W.statPoints[C.Soul], "x");
  Check.Check(Ends(told, "Soul's points: a whole number. The computed number is used."), "or the Stat");
  Type(W.derived[Ch.AR], "3");
  Check.Check(e.ar.overridden & W.derived[Ch.AR].Visible(), "an override of AR shows it")
END Editing;

(* The save-first question, answered each way, through File > New. *)
PROCEDURE SaveFirst;
  VAR e: Ch.Entity; es: Ch.Entities;
BEGIN
  e := W.entity;
  answer := W.Cancel; asked := 0;
  Pick(W.newItem);
  Check.Check((asked = 1) & Is(question, "Save the changes to Kei Tanaka first?"),
    "File > New with changes asks to save them first, naming the character");
  Check.Check((W.entity = e) & W.modified, "Cancel: the character stays, changed");
  answer := W.SaveFirst; chosen := NIL; asked := 0;
  Pick(W.newItem);
  Check.Check((asked = 1) & (W.entity = e) & W.modified, "Save, and Save As cancelled: it stays");
  answer := W.SaveFirst; chosen := Rp(SavePath); asked := 0;
  Pick(W.newItem);
  Check.Check((asked = 1) & (W.entity # e) & (W.path = NIL) & ~W.modified & (W.entity.stat[C.Body] = 1),
    "Save, and a file chosen: saved, then a new character");
  es := Reload(SavePath);
  Check.Check((es # NIL) & (LEN(es^) = 1) & Is(es[0].name, "Kei Tanaka") & (es[0].stat[C.Body] = 5),
    "the file saved holds the character");
  Check.Check((es # NIL) & es[0].hp.overridden & (C.Value(es[0].hp) = 99) & es[0].ar.overridden
    & (C.Value(es[0].ar) = 3) & ~es[0].sv.overridden,
    "with its overrides, and only those");
  SetStat(C.Mind, 3);
  answer := W.Discard; asked := 0; e := W.entity;
  Pick(W.newItem);
  Check.Check((asked = 1) & Is(question, "Save the changes to the character first?") & (W.entity # e) & ~W.modified,
    "Don't save: a new character, unnamed in the question");
  Pick(W.newItem);
  Check.Check(asked = 1, "unchanged, File > New doesn't ask")
END SaveFirst;

(* A file with a mecha before the character. *)
PROCEDURE Files;
  VAR e: Ch.Entity; es: Ch.Entities; label: ARRAY 128 OF CHAR;
BEGIN
  Copy("data/window.yaml", OpenPath);
  before := tells; chosen := Rp(OpenPath);
  Pick(W.openItem);
  e := W.entity;
  Check.Check((LEN(W.entities^) = 2) & (W.current = 1) & Is(e.name, "Pilot") & W.entities[0].isMecha,
    "File > Open: every entity, the first character shown, after the mecha");
  Check.Check((tells = before) & ~W.modified, "a file the rules agree with: nothing said, unchanged");
  Check.Check(TitleIs(" - window.yaml (2 of 2)"), "the title names the file, and which of its entities is shown");
  Check.Check(Is(W.path, OpenPath), "and the path is kept");
  W.nameIn.Value(label);
  Check.Check(label = "Pilot", "the name is shown");
  Check.Check(AllShown() & W.derived[Ch.AR].Visible(), "every number shown, and AR, with Heavy Armour");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 20", FALSE),
    "Character Points: of the creation block's");
  Check.Check(Line(W.SkillPoints, "Skill Points: 8 of 20", FALSE), "Skill Points: of the creation block's");
  Check.Check(W.warnings.Count() = 0, "no warnings");
  SetStat(C.Body, 6);
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 14 + Attributes 8 - Bonus Points 1 = 21 of 20", TRUE),
    "one point over: red");
  Check.Check(Warning("spent 21 Character Points of 20 (p. 13, PDF 15)") > 0, "and a warning says so, with both pages");
  SetStat(C.Body, 13);
  Check.Check(Warning("Body (p. 15, PDF 17): 13 is outside 1 to 12 (p. 16, PDF 18)") > 0, "a Stat above 12: warned");
  SetStat(C.Body, 6);
  Check.Check(Warning("outside 1 to 12") = 0, "and back: not");

  chosen := Rp(SavePath2);
  Pick(W.saveAsItem);
  Check.Check(Is(W.path, SavePath2) & ~W.modified, "File > Save As: saved, to the file now shown");
  Check.Check(TitleIs(" - window-two.yaml (2 of 2)"), "and the title names it");
  es := Reload(SavePath2);
  Check.Check((es # NIL) & (LEN(es^) = 2) & Is(es[0].name, "Walker") & es[0].isMecha & Is(es[1].name, "Pilot")
    & (es[1].stat[C.Body] = 6) & (C.Value(es[1].statPoints[C.Body]) = 6),
    "every entity saved, in order, with the change");
  SetStat(C.Soul, 5); chosen := NIL;
  Pick(W.saveItem);
  es := Reload(SavePath2);
  Check.Check(~W.modified & (es # NIL) & (es[1].stat[C.Soul] = 5), "File > Save: to the same file, without asking");

  SetStat(C.Soul, 4); answer := W.Cancel; asked := 0;
  Pick(W.quitItem);
  Check.Check((asked = 1) & Is(question, "Save the changes to window-two.yaml first?") & W.window.Shown(),
    "File > Quit with changes asks, naming the file; Cancel: still shown");
  answer := W.Discard;
  W.window.DoCallback;
  Check.Check((asked = 2) & ~W.window.Shown(), "the close button asks too; Don't save: hidden");
  W.window.Show;
  Copy("data/bare.yaml", BarePath);
  answer := W.Cancel; asked := 0; chosen := Rp(BarePath);
  Pick(W.openItem);
  Check.Check((asked = 1) & Is(W.entity.name, "Pilot"), "File > Open with changes asks first; Cancel: nothing opened");
  answer := W.Discard;
  Pick(W.openItem);
  Check.Check(Is(W.entity.name, "Bare") & ~W.modified, "Don't save: opened")
END Files;

(* A file's entity with no Stats or derived values gets the ones
   changed. *)
PROCEDURE Bare;
  VAR es: Ch.Entities; e: Ch.Entity;
BEGIN
  e := W.entity;
  Check.Check(e.fromFile & ~e.hasStats & ~e.hasDerived, "a file's character without Stats or derived values");
  SetStat(C.Mind, 3);
  Type(W.derived[Ch.EP], "7");
  chosen := Rp(SavePath);
  Pick(W.saveAsItem);
  es := Reload(SavePath);
  Check.Check((es # NIL) & es[0].hasStats & (es[0].stat[C.Mind] = 3) & es[0].hasDerived & es[0].ep.overridden
    & (C.Value(es[0].ep) = 7), "saves the Stat and the derived value changed")
END Bare;

(* A file whose numbers differ: kept as overrides, and said so, each
   line short enough for the screen. *)
PROCEDURE Notices;
  VAR i, n, longest, lines: LONGINT;
BEGIN
  (* Opened, not copied: a copy keeps the override, and differs no
     more.  Nothing here saves. *)
  before := tells; chosen := Rp("data/differs.yaml"); answer := W.Discard;
  Pick(W.openItem);
  Check.Check((tells = before + 1) & ~W.modified & W.entity.statPoints[C.Body].overridden & (C.Value(W.entity.statPoints[C.Body]) = 9),
    "a number the rules give differently: kept as an override, and said so");
  Check.Check(Ropes.Find(told, "points is 9 in the file, 4 by the rules", 0) > 0, "the notice says both numbers");
  n := Ropes.Length(told); longest := 0; lines := 1; i := 0;
  WHILE i < n DO
    IF Ropes.Fetch(told, i) = 0AX THEN INC(lines); i := i + 1; n := n - i; told := Ropes.Substring(told, i, n); i := 0
    ELSE INC(i); IF i > longest THEN longest := i END
    END
  END;
  Check.Check((longest <= 80) & (lines >= 4), "its lines wrapped at 80")
END Notices;

PROCEDURE Mecha;
  VAR e: Ch.Entity; label: ARRAY 128 OF CHAR;
BEGIN
  before := tells; chosen := Rp("data/mecha.yaml"); answer := W.Discard;
  Pick(W.openItem);
  e := W.entity;
  Check.Check(e.isMecha & Is(e.name, "Lone Mecha") & (tells = before) & ~W.statValue[C.Body].Active()
    & ~W.statPoints[C.Soul].Active(),
    "a mecha alone is shown, its Stats off");
  Check.Check(W.derived[Ch.HP].Visible() & ~W.derived[Ch.ACV].Visible() & ~W.derived[Ch.DCV].Visible()
    & ~W.derived[Ch.EP].Visible() & ~W.derived[Ch.SV].Visible(), "of the derived values, only HP");
  W.points[W.CharacterPoints].GetLabel(label);
  Check.Check(Ropes.Find(Rp(label), "Mecha Points: Attributes 0 - Bonus Points 0 = ", 0) = 0, "and Mecha Points")
END Mecha;

PROCEDURE Attributes;
  CONST ListsPath = "../obj/lists.yaml";
  VAR p: Besm2ItemPanel.AttrPanel; flight: R.Item; a, keep: Ch.Attr; label: ARRAY 128 OF CHAR; n, line: INTEGER;
BEGIN
  Copy("data/window.yaml", ListsPath);
  chosen := Rp(ListsPath); answer := W.Discard; Pick(W.openItem);
  e := W.entity; p := W.attrPanel;
  Check.Check((p.browser.Count() = 2) & Holds(p.browser, 1, "1 Own a Big Mecha: Walker")
    & Holds(p.browser, 1, "4 pts") & Holds(p.browser, 1, "p. 59, PDF 61") & Holds(p.browser, 2, "1 Heavy Armour"),
    "Attributes: the character's listed, level, name: subject, points and both pages");
  Check.Check(TabLine(W.AttributesList, W.CharacterPoints) & TabLine(W.SkillsList, W.SkillPoints) & TabWarnings(),
    "the lists' tabs show the Character tab's points and warnings");

  before := tells; n := p.browser.Count(); p.Blank; p.add.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Choose a name first.") & (p.browser.Count() = n) & ~W.modified,
    "Add with no name chosen: said so, nothing added");

  flight := R.Find("Flight");
  ChooseItem(p, flight);
  p.choice.ItemLabel(p.choice.Value(), label);
  Check.Check((label = "Flight (p. 33, PDF 35)") & (p.help.page = 33), "a name chosen: shown with both pages; ? turns to its page");
  Check.Check(p.options.Active() & (p.options.Count() = flight.nOptions) & Holds(p.options, 1, "(x) ")
    & Holds(p.options, OptLine(flight, "cannot hover"), "( ) cannot hover"), "its options, the first of a choice counted");
  before := tells; p.plus.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Choose an option first."), "+ with no option: said so");
  line := OptLine(flight, "cannot hover"); Select(p.options, line); p.plus.DoCallback;
  Select(p.options, 1); p.plus.DoCallback;
  Check.Check(Holds(p.options, 1, "(x) ") & Holds(p.options, line, "( ) cannot hover"), "+ on another of a choice: it, not the one before");
  Select(p.options, line); p.plus.DoCallback;
  line := OptLine(flight, "skimmer or hovercraft"); Select(p.options, line); p.plus.DoCallback;
  Check.Check(Holds(p.options, 1, "( ) ") & Holds(p.options, OptLine(flight, "cannot hover"), "(x) cannot hover")
    & Holds(p.options, line, "[x] skimmer"), "+: one of a choice, the others not; an option alone taken");
  p.spinner.SetValue(2); p.details.SetValue("  wings ");
  p.add.DoCallback;
  a := e.attrs.next.next(Ch.Attr);
  Check.Check((p.browser.Count() = 3) & (p.browser.Value() = 3) & (a.item = flight) & (a.level = 2) & Is(a.details, "wings")
    & (C.Value(a.points) = 5) & W.modified, "Add: last, selected, at its Level, its options, 5 points");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 13 - Bonus Points 1 = 25 of 20", TRUE)
    & TabLine(W.AttributesList, W.CharacterPoints) & TabLine(W.DefectsList, W.CharacterPoints)
    & (Warning("Character Points") > 0) & TabWarnings(), "the totals and warnings, here and on every tab, as you go");

  keep := a; p.Blank; Select(p.browser, 3);
  Check.Check((p.choice.Value() >= 0) & (p.Item() = flight) & (ENTIER(p.spinner.Value() + 0.5) = 2)
    & Holds(p.options, OptLine(flight, "cannot hover"), "(x) cannot hover"), "a line selected: its name, Level and options loaded");
  p.spinner.SetValue(3); p.change.DoCallback;
  a := e.attrs.next.next(Ch.Attr);
  Check.Check((a = keep) & (a.level = 3) & (C.Value(a.points) = 8) & (p.browser.Value() = 3) & Holds(p.browser, 3, "3 Flight (wings)"),
    "Change: the same Attribute, at its new Level");
  Select(p.browser, 1); p.text.SetValue("Nobody"); p.change.DoCallback;
  Check.Check((e.attrs(Ch.Attr).mecha = NIL) & Is(e.attrs(Ch.Attr).subject, "Nobody"), "Own a Big Mecha's subject changed: unlinked");
  Select(p.browser, 1); p.text.SetValue("Walker"); p.change.DoCallback;
  Check.Check(e.attrs(Ch.Attr).mecha = W.entities[0], "and named again: linked to its mecha");
  Select(p.browser, 3); p.remove.DoCallback;
  Check.Check((p.browser.Count() = 2) & (p.browser.Value() = 0) & (p.choice.Value() < 0)
    & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 20", FALSE)
    & TabLine(W.AttributesList, W.CharacterPoints), "Remove: gone, nothing selected, the totals back");
  before := tells; p.change.DoCallback; p.remove.DoCallback;
  Check.Check((tells = before) & (p.browser.Count() = 2), "Change and Remove with no line: nothing")
END Attributes;

(* Whether p's Choice offers each of the rulebook's names as its label
   gives it, one item each, in order: a "/" in a name ("Girl/Guy
   Magnet") is no submenu. *)
PROCEDURE Offers(p: Besm2Widgets.Panel): BOOLEAN;
  VAR i, n: INTEGER; it: R.Item; want, label: ARRAY 128 OF CHAR;
BEGIN
  IF p.choice.Length() # p.Offered() + p.More() + 1 THEN RETURN FALSE END;
  n := R.Count(p.kind);
  FOR i := 0 TO p.Offered() - 1 DO
    IF i < n THEN it := R.Get(p.kind, i) ELSE it := R.Get(p.second, i - n) END;
    R.Label(it, want); p.choice.ItemLabel(i, label);
    IF label # want THEN RETURN FALSE END
  END;
  RETURN TRUE
END Offers;

PROCEDURE Defects;
  VAR p: Besm2ItemPanel.DefectPanel; d: Ch.Defect; magnet: R.Item;
BEGIN
  p := W.defectPanel;
  Check.Check((p.browser.Count() = 1) & Holds(p.browser, 1, "1 Unique Character Defect: Stubborn") & Holds(p.browser, 1, "1 BP"),
    "Defects: listed, rank, name: subject, Bonus Points");
  ChooseItem(p, R.Find("Easily Distracted"));
  Check.Check(p.help.page = 104, "? at its page");
  magnet := R.Find("Girl/Guy Magnet"); ChooseItem(p, magnet);
  Check.Check(Offers(p) & (p.Item() = magnet), "every name offered as it is, a / too");
  ChooseItem(p, R.Find("Easily Distracted"));
  p.spinner.SetValue(2); p.details.SetValue("cats"); p.add.DoCallback;
  d := e.defects.next(Ch.Defect);
  Check.Check((d # NIL) & (d.rank = 2) & Is(d.details, "cats") & Holds(p.browser, 2, "2 Easily Distracted (cats)")
    & Holds(p.browser, 2, "2 BP") & (e.bonusPoints = 3), "Add: its rank, and its Bonus Points");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 3 = 18 of 20", FALSE)
    & TabLine(W.DefectsList, W.CharacterPoints) & TabLine(W.DefectsList, W.BonusPoints), "and the totals");
  Select(p.browser, 2); p.spinner.SetValue(1); p.change.DoCallback;
  Check.Check((e.defects.next = d) & (d.rank = 1) & (e.bonusPoints = 2), "Change: its rank");
  Select(p.browser, 2); p.remove.DoCallback;
  Check.Check((e.defects.next = NIL) & (e.bonusPoints = 1), "Remove")
END Defects;

PROCEDURE Skills;
  VAR p: Besm2ItemPanel.SkillPanel; s: Ch.Skill; h: Ch.HouseSkill; label: ARRAY 128 OF CHAR;
BEGIN
  p := W.skillPanel;
  Check.Check((p.genre.Value() = R.ModernMilitary + 1) & (p.browser.Count() = 1) & Holds(p.browser, 1, "2 Driving")
    & Holds(p.browser, 1, "8 SP") & Holds(p.browser, 1, "p. 122, PDF 124"), "Skills: the genre, and the Skill at its cost");
  Check.Check(p.genreHelp.page = R.SkillCostsPage, "the genre's ? at Table 2-4");
  Pick(W.saveItem);
  p.genre.Choose(R.Cyberpunk + 1); p.genre.DoCallback;
  Check.Check((e.creation.genre = R.Cyberpunk) & (C.Value(e.skills.points) = 6) & Holds(p.browser, 1, "6 SP") & W.modified
    & Line(W.SkillPoints, "Skill Points: 6 of 20", FALSE) & TabLine(W.SkillsList, W.SkillPoints),
    "another genre: every Skill priced again (p. 119)");
  Select(p.browser, 1); p.text.SetValue(" Cars, , Trucks "); p.change.DoCallback;
  s := e.skills(Ch.Skill);
  Check.Check((s.specs = 2) & Is(s.specialisations.items[1], "Trucks") & Holds(p.browser, 1, "2 Driving (Cars, Trucks)")
    & (C.Value(s.points) = 7), "specialisations: split at commas, trimmed, blanks dropped; the second 1 SP");
  p.text.SetValue(""); Select(p.browser, 1); p.text.Value(label);
  Check.Check(label = "Cars, Trucks", "selected: its specialisations loaded, joined by commas");

  NEW(h); C.InitHouseSkill(h); h.name := Rp("Mecha Piloting"); h.cost[R.Cyberpunk] := 5;
  h.hasStat := FALSE; h.hasSpecializations := FALSE; Besm2Text.Clear(h.specializations);
  C.AddHouseSkill(e.creation, h);
  p.Show(e);
  p.ChooseIndex(p.Offered()); p.choice.DoCallback;
  p.choice.ItemLabel(p.Offered(), label);
  Check.Check((label = "Mecha Piloting (house rule)") & (p.House() = h) & (p.help.page = 0), "a house Skill offered after the rulebook's");
  p.spinner.SetValue(1); p.add.DoCallback;
  Check.Check((e.skills.next # NIL) & (e.skills.next(Ch.Skill).house = h) & Holds(p.browser, 2, "5 SP")
    & Holds(p.browser, 2, "house rule") & (e.skillSpent = 12), "Add: priced at its genre's cost");
  Select(p.browser, 2); p.remove.DoCallback;
  Check.Check((e.skills.next = NIL) & (e.skillSpent = 7), "Remove")
END Skills;

PROCEDURE Background;
  VAR es: Ch.Entities; b: Ch.Entity; glider: INTEGER; buffer: FlText.TextBuffer;
BEGIN
  Pick(W.saveItem);
  buffer := Besm2Background.description.Buffer(); buffer.Insert(0, "  A test pilot.  ");
  Check.Check(Is(e.description, "A test pilot.") & e.hasDescription & W.modified, "Background: the description, as typed, trimmed");
  before := tells; Besm2Background.noteIn.SetValue("  "); Besm2Background.addNote.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Type the note first.") & (e.notes.n = 0), "a blank note: said so");
  Besm2Background.noteIn.SetValue(" first "); Besm2Background.addNote.DoCallback;
  Besm2Background.noteIn.SetValue("second"); Besm2Background.addNote.DoCallback;
  Check.Check((e.notes.n = 2) & Is(e.notes.items[0], "first") & e.hasNotes & (Besm2Background.notes.Count() = 2)
    & (Besm2Background.notes.Value() = 2), "notes added, last, trimmed");
  before := tells; Besm2Background.notes.SetSelected(2, FALSE); Besm2Background.removeNote.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Choose a note first."), "Remove with none selected: said so");
  Select(Besm2Background.notes, 1); Besm2Background.noteIn.SetValue("one"); Besm2Background.changeNote.DoCallback;
  Check.Check((e.notes.n = 2) & Is(e.notes.items[0], "one") & Is(e.notes.items[1], "second"), "Change: in place");
  Select(Besm2Background.notes, 2); Besm2Background.removeNote.DoCallback;
  Check.Check((e.notes.n = 1) & (Besm2Background.notes.Count() = 1), "Remove");

  ChooseItem(W.attrPanel, R.Find("Flight"));
  glider := OptLine(R.Find("Flight"), "glider"); Select(W.attrPanel.options, glider); W.attrPanel.plus.DoCallback;
  W.attrPanel.add.DoCallback;
  Pick(W.saveItem);
  es := Reload("../obj/lists.yaml");
  Check.Check(~W.modified & (es # NIL) & (LEN(es^) = 2), "File > Save");
  IF es # NIL THEN
    b := es[1];
    Check.Check((b.creation.genre = R.Cyberpunk) & (b.skills.specs = 2) & Is(b.description, "A test pilot.")
      & (b.notes.n = 1) & Is(b.notes.items[0], "one"), "and loaded again: the genre, the specialisations, the description, the notes");
    Check.Check((b.attrs.next.next # NIL) & (b.attrs.next.next(Ch.Attr).times[glider - 1] = 1)
      & ~b.attrs.next.next(Ch.Attr).points.overridden & (b.attrs(Ch.Attr).mecha = es[0]), "the option, priced the same; the mecha linked")
  END
END Background;

PROCEDURE Rulebook;
  VAR pdf: Rope;
BEGIN
  before := tells;
  W.rulebookOption := Rp("/no/such/rulebook.pdf"); chosen := NIL;
  Besm2Widgets.openPage(42);
  Check.Check((tells = before + 1)
    & Is(told, "The rulebook isn't at /no/such/rulebook.pdf: choose it with Rulebook > Choose PDF..., or give it with --rulebook or BESM2_RULEBOOK."),
    "a ? with no rulebook: asked for it, and, not given, said where to give it");
  chosen := Rp("data/window.yaml");  (* a file that is there *)
  Pick(W.choosePdfItem);
  pdf := W.rulebookOption;
  Check.Check((pdf # NIL) & (Ropes.Length(pdf) > 0) & (Ropes.Fetch(pdf, 0) = "/") & Ends(pdf, "/test/data/window.yaml"),
    "Rulebook > Choose PDF...: the file chosen, as an absolute path");
  typed := Rp("evince");
  Pick(W.viewerItem);
  Check.Check(Is(Besm2Viewer.Name(W.viewer), "evince"), "Rulebook > Viewer...: a viewer named");
  Check.Check(Ropes.Find(prompted, "%p its page", 0) >= 0, "the question says what %f and %p are");
  before := tells; typed := Rp("frobnicate");
  Pick(W.viewerItem);
  Check.Check((tells = before + 1) & Is(Besm2Viewer.Name(W.viewer), "evince"),
    "not a viewer: said so, and the viewer kept");
  typed := Rp("/no/such/viewer %f %p");
  Pick(W.viewerItem);
  before := tells;
  Pick(W.rulebookItem);
  Check.Check((tells = before + 1) & (Ropes.Find(told, "can't start /no/such/viewer", 0) = 0),
    "Rulebook > Open: a viewer that won't start is said so");
  typed := Rp("true %f %p");
  Pick(W.viewerItem);
  before := tells;
  Besm2Widgets.openPage(42);
  Check.Check(tells = before, "a viewer that starts: nothing said")
END Rulebook;

(* The last line of the dialog's warnings holding text; 0 if none. *)
(* ---- Mecha and several entities (step 9) ---- *)

(* Whether menu item i is inactive. *)
PROCEDURE Inactive(i: INTEGER): BOOLEAN;
BEGIN RETURN ~W.bar.ItemActive(i)
END Inactive;

(* Whether the Choice's item i reads want. *)
PROCEDURE ChoiceIs(i: INTEGER; want: ARRAY OF CHAR): BOOLEAN;
  VAR label: ARRAY 128 OF CHAR;
BEGIN
  W.entityChoice.ItemLabel(i, label);
  IF label # want THEN Out.String("    choice: "); Out.String(label); Out.Ln END;
  RETURN label = want
END ChoiceIs;

PROCEDURE Choose(i: INTEGER);
BEGIN W.entityChoice.Choose(i); W.entityChoice.DoCallback
END Choose;

(* The Attr of e tied to m; NIL for none. *)
PROCEDURE TiedTo(e, m: Ch.Entity): Ch.Attr;
  VAR a: C.Attr;
BEGIN
  a := e.attrs; WHILE (a # NIL) & (a.mecha # m) DO a := a.next END;
  IF a = NIL THEN RETURN NIL ELSE RETURN a(Ch.Attr) END
END TiedTo;

PROCEDURE Several;
  VAR pilot, walker, hopper, copy: Ch.Entity; p: Besm2ItemPanel.AttrPanel; a: Ch.Attr; label: ARRAY 128 OF CHAR;
BEGIN
  Check.Check(Item("&Character/&Next", W.nextItem, Fl.KeyPageDown, Fl.Command)
    & Item("&Character/&Previous", W.previousItem, Fl.KeyPageUp, Fl.Command)
    & Item("&Character/&Remove...", W.removeItem, 0, {}), "the Character menu, Next and Previous on Ctrl+PgDn and PgUp");
  Copy("data/window.yaml", SeveralPath);
  chosen := Rp(SeveralPath); answer := W.Discard; Pick(W.openItem);
  walker := W.entities[0]; pilot := W.entities[1]; p := W.attrPanel;
  Check.Check((W.current = 1) & TitleIs(" - window-several.yaml (2 of 2)") & (W.entityChoice.Length() = 3)
    & ChoiceIs(0, "1. Walker (mecha)") & ChoiceIs(1, "2. Pilot") & (W.entityChoice.Value() = 1),
    "two entities: the title says which, the Choice lists them");
  Check.Check(~Inactive(W.removeItem) & ~Inactive(W.moveUpItem) & ~Inactive(W.previousItem) & Inactive(W.moveDownItem)
    & Inactive(W.nextItem), "the last: Move Down and Next off");

  Check.Check((MP.n = 1) & Holds(MP.list, 1, "1 Own a Big Mecha: Walker") & Holds(MP.list, 1, "20 MP")
    & Holds(MP.list, 1, "Walker spends 4 of 20") & (MP.list.Count() = 1) & MP.showButton.Active() & MP.newButton.Active()
    & TabLine(W.MechaList, W.CharacterPoints) & TabWarnings(),
    "Mecha tab: the character's Own a Big Mecha, its Mecha Points, its mecha's; the totals");
  MP.showButton.DoCallback;
  Check.Check((W.current = 0) & (W.entity = walker) & TitleIs(" - window-several.yaml (1 of 2)")
    & Inactive(W.moveUpItem) & Inactive(W.previousItem) & ~Inactive(W.nextItem), "Show Mecha, the only line: the mecha shown");
  Check.Check((MP.n = 1) & Holds(MP.list, 1, "Pilot: 1 Own a Big Mecha: Walker") & Holds(MP.list, 1, "20 MP")
    & ~MP.newButton.Active() & Line(W.CharacterPoints, "Mecha Points: Attributes 4 - Bonus Points 0 = 4 of 20", FALSE),
    "on the mecha: its owner, and its Mecha Points of what that gives");
  Check.Check((p.kind = R.MechaAttribute) & (p.second = R.Attribute) & (W.defectPanel.kind = R.MechaDefect),
    "a mecha's lists offer the Mecha Attributes and Defects first");
  W.nameIn.SetValue("Strider"); W.nameIn.DoCallback;
  Check.Check(Is(pilot.attrs(Ch.Attr).subject, "Strider") & (pilot.attrs.mecha = walker) & ChoiceIs(0, "1. Strider (mecha)")
    & W.modified, "the mecha renamed: its owner's Own a Big Mecha follows, still tied; the Choice too");
  MP.showButton.DoCallback;
  Check.Check((W.entity = pilot) & (p.kind = R.Attribute) & (p.second = R.MechaAttribute)
    & Holds(MP.list, 1, "1 Own a Big Mecha: Strider"), "Show Owner: the character, its lists the character's again");

  p.Blank; ChooseItem(p, R.Find("Own a Big Mecha")); p.text.SetValue(""); p.spinner.SetValue(1); p.add.DoCallback;
  Check.Check((MP.n = 2) & Holds(MP.list, 2, "no subject"), "an Own a Big Mecha with no subject: no mecha");
  before := tells; MP.newButton.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Choose an Own a Big Mecha first.") & (LEN(W.entities^) = 2),
    "New Mecha, two lines, none chosen: said so");
  Select(MP.list, 1); before := tells; MP.newButton.DoCallback;
  Check.Check((tells = before + 1) & (LEN(W.entities^) = 2), "New Mecha on one with its mecha: said so");
  Select(MP.list, 2); typed := Rp("  Hopper "); MP.newButton.DoCallback; typed := NIL;
  hopper := W.entity; a := TiedTo(pilot, hopper);
  Check.Check((LEN(W.entities^) = 3) & (W.current = 2) & hopper.isMecha & Is(hopper.name, "Hopper") & (a # NIL)
    & Is(a.subject, "Hopper") & (hopper.owner = pilot) & (hopper.available = 20) & TitleIs(" - window-several.yaml (3 of 3) *"),
    "New Mecha, the name asked: the subject given it, the mecha last, shown, tied");
  W.nameIn.SetValue("Hop & Skip"); W.nameIn.DoCallback;
  Check.Check(ChoiceIs(2, "3. Hop && Skip (mecha)") & Is(a.subject, "Hop & Skip") & (a.mecha = hopper),
    "an & shown as itself (FLTK holds it doubled)");

  Pick(W.duplicateItem); copy := W.entity;
  Check.Check((LEN(W.entities^) = 4) & (W.current = 3) & (copy # hopper) & Is(copy.name, "Hop & Skip") & (copy.owner = NIL)
    & (copy.attrs = NIL)
    & Line(W.CharacterPoints, "Mecha Points: Attributes 0 - Bonus Points 0 = 0 (no owner in the file)", FALSE)
    & (MP.n = 0) & Holds(MP.list, 1, "No character in the file owns this mecha") & ~MP.showButton.Active(),
    "Duplicate: the copy last, shown; a mecha of a name already tied, so no owner");
  Pick(W.moveUpItem);
  Check.Check((W.current = 2) & (W.entities[2] = copy) & (W.entities[3] = hopper) & (a.mecha = copy) & (hopper.owner = NIL)
    & ChoiceIs(2, "3. Hop && Skip (mecha)"), "Move Up: swapped, still shown; the first of the name is the one tied");
  confirmed := FALSE; before := confirms; Pick(W.removeItem);
  Check.Check((confirms = before + 1) & Is(question, "Remove Hop & Skip from the file?") & (LEN(W.entities^) = 4),
    "Remove..., cancelled: asked, nothing removed");
  confirmed := TRUE; Pick(W.removeItem);
  Check.Check((LEN(W.entities^) = 3) & (W.current = 2) & (W.entity = hopper) & (a.mecha = hopper) & (hopper.owner = pilot),
    "Remove: gone, the one after shown, the other tied again");

  Pick(W.addMechaItem);
  Check.Check((LEN(W.entities^) = 4) & (W.current = 3) & W.entity.isMecha & ~W.entity.hasName & ChoiceIs(3, "4. (no name) (mecha)")
    & Holds(MP.list, 1, "No character in the file owns this mecha"), "Add Mecha: a new mecha, last");
  Pick(W.nextItem);
  Check.Check(W.current = 3, "Next at the last: nothing");
  Pick(W.previousItem);
  Check.Check(W.entity = hopper, "Previous");
  Pick(W.nextItem);
  Check.Check(W.current = 3, "Next");
  Choose(1);
  Check.Check(W.entity = pilot, "the Choice shows the one chosen");
  Pick(W.addCharacterItem);
  Check.Check((LEN(W.entities^) = 5) & (W.current = 4) & ~W.entity.isMecha & (MP.n = 0)
    & Holds(MP.list, 1, "add it on the Attributes tab") & ~MP.showButton.Active(), "Add Character: a new one, last");
  before := tells; MP.newButton.DoCallback;
  Check.Check((tells = before + 1) & (LEN(W.entities^) = 5), "New Mecha with no Own a Big Mecha: said so");

  Choose(1); Pick(W.duplicateItem); copy := W.entity;
  Check.Check((LEN(W.entities^) = 6) & Is(copy.name, "Pilot") & (walker.owner = copy) & Holds(MP.list, 1, "Strider spends 4 of 20"),
    "a character duplicated: its copy, last, prices their mecha");
  Choose(1);
  Check.Check(Holds(MP.list, 1, "Strider is Pilot's: not counted"), "and the first says its doesn't count");
  Choose(0);
  Check.Check((MP.n = 2) & Holds(MP.list, 1, "not counted: Pilot owns it") & ~Holds(MP.list, 2, "not counted"),
    "the mecha lists both, and which counts");
  Choose(5); Pick(W.removeItem);
  Check.Check((LEN(W.entities^) = 5) & (W.current = 4) & (walker.owner = pilot), "the copy removed, the last: the one before shown");

  chosen := Rp(SeveralPath); Pick(W.saveItem);
  es := Reload(SeveralPath);
  Check.Check((es # NIL) & (LEN(es^) = 5) & Is(es[0].name, "Strider") & Is(es[1].name, "Pilot") & Is(es[2].name, "Hop & Skip")
    & es[3].isMecha & ~es[3].hasName & ~es[4].isMecha & (TiedTo(es[1], es[0]) # NIL) & (TiedTo(es[1], es[2]) # NIL)
    & (es[2].available = 20), "saved and loaded again: in order, tied, priced");

  answer := W.Discard; Pick(W.saveItem); Pick(W.newItem);
  Check.Check((LEN(W.entities^) = 1) & Inactive(W.removeItem) & Inactive(W.nextItem) & Inactive(W.previousItem)
    & TitleIs("") & ChoiceIs(0, "1. (no name)"), "File > New: one, Remove off, the title without a count")
END Several;

PROCEDURE DialogWarning(text: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER; line: ARRAY 256 OF CHAR;
BEGIN
  i := D.warnings.Count();
  WHILE i > 0 DO
    D.warnings.GetText(i, line);
    IF Ropes.Find(Rp(line), text, 0) >= 0 THEN RETURN i END;
    DEC(i)
  END;
  RETURN 0
END DialogWarning;

(* ---- Creation (step 10) ---- *)

PROCEDURE Spun(v: FlValuators.Spinner): INTEGER;
BEGIN RETURN SHORT(ENTIER(v.Value() + 0.5))
END Spun;

PROCEDURE LabelIs(b: Fl.Widget; want: ARRAY OF CHAR): BOOLEAN;
  VAR label: ARRAY 256 OF CHAR;
BEGIN
  b.GetLabel(label);
  IF label # want THEN Out.String("    label: "); Out.String(label); Out.Ln END;
  RETURN label = want
END LabelIs;

PROCEDURE Creation;
  VAR pilot, walker, added: Ch.Entity; dr: C.Skill; keys: SET; was: BOOLEAN; c: Ch.Entities; label: ARRAY 128 OF CHAR;
BEGIN
  Check.Check(Item("&Character/Cr&eation...", W.creationItem, 0, {}) & (W.creationItem < W.addCharacterItem),
    "Character > Creation..., first");
  Copy("data/window.yaml", CreationPath);
  chosen := Rp(CreationPath); answer := W.Discard; Pick(W.openItem);
  walker := W.entities[0]; pilot := W.entities[1]; dr := pilot.skills;
  keys := pilot.creationKeys; was := W.modified;
  Check.Check(~Inactive(W.creationItem), "active on a character");

  Choose(0);
  Check.Check(~Inactive(W.creationItem), "and on a mecha with an owner");
  Pick(W.creationItem);
  Check.Check((Cr.dialog # NIL) & (Cr.target = pilot) & LabelIs(Cr.title, "The creation of Pilot, which prices the mecha"),
    "a mecha's: its owner's creation");
  Cr.Cancel; Choose(1);

  Pick(W.creationItem);
  Check.Check((Cr.dialog # NIL) & (Cr.target = pilot) & LabelIs(Cr.title, "The creation of Pilot"), "Creation...: the dialog");
  Check.Check(LabelIs(Cr.pointsOn, "Character Points (p. 13, PDF 15)") & LabelIs(Cr.stagedOn, "Staged Stat Cost, Table 4-7 (p. 166, PDF 168)")
    & LabelIs(Cr.statOn, "A ceiling on each Stat (p. 16, PDF 18)") & LabelIs(Cr.autoFireOn, "Auto-Fire counts as 1 slot (p. 84, PDF 86)"),
    "each row with both pages");
  Check.Check(Cr.pointsOn.Value() & (Spun(Cr.pointsIn) = 20) & (Cr.genre.Value() = R.ModernMilitary + 1)
    & Cr.skillOn.Value() & (Spun(Cr.skillIn) = 20) & (Spun(Cr.backgroundIn) = 0) & ~Cr.stagedOn.Value()
    & ~Cr.statOn.Value() & ~Cr.statIn.Active() & (Spun(Cr.statIn) = 10) & ~Cr.bonusOn.Value() & (Spun(Cr.bonusIn) = 8)
    & ~Cr.autoFireOn.Value(), "the file's creation shown; the numbers not set at their defaults, inactive");
  Check.Check(~Cr.statPointsCeilingOn.Value() & ~Cr.statPointsCeilingIn.Active() & (Spun(Cr.statPointsCeilingIn) = 24)
    & ~Cr.statPointsFloorOn.Value() & ~Cr.statPointsFloorIn.Active() & (Spun(Cr.statPointsFloorIn) = 12)
    & LabelIs(Cr.statPointsCeilingOn, "A ceiling on the Stats' total cost (p. 16, PDF 18)")
    & LabelIs(Cr.statPointsFloorOn, "A floor on the Stats' total cost (p. 16, PDF 18)"),
    "the Stats' total: no limits, the spinners at their defaults");
  Check.Check(~Cr.copyChoice.Active() & ~Cr.copyButton.Active() & Cr.loadButton.Active() & Cr.saveButton.Active(),
    "no other character to copy from; a campaign to load or save");
  Check.Check(LabelIs(Cr.summary, "Character Points: 20 spent of 20.  Skill Points: 8 spent of 20."), "the points");

  Cr.SetCharacterPoints(TRUE, 25);
  Check.Check((pilot.available = 25) & W.modified
    & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 25", FALSE),
    "Character Points 25: the window follows");
  Cr.SetStatPointsCeiling(TRUE, 12);
  Check.Check((pilot.creation.statPointsCeiling = 12) & (Ch.StatPointsCeilingKey IN pilot.creationKeys)
    & C.HasWarning(pilot, C.StatPointsAbove, NIL) & Cr.statPointsCeilingIn.Active()
    & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 25; Stats at most 12", TRUE),
    "a ceiling of 12 on the Stats' total: 13 is above it, in red");
  Cr.SetStatPointsCeiling(TRUE, 13); Cr.SetStatPointsFloor(TRUE, 14);
  Check.Check(~C.HasWarning(pilot, C.StatPointsAbove, NIL) & C.HasWarning(pilot, C.StatPointsBelow, NIL)
    & (Ch.StatPointsFloorKey IN pilot.creationKeys)
    & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 25; Stats at least 14, at most 13", TRUE),
    "a floor of 14: 13 is below it");
  Cr.SetStatPointsFloor(TRUE, 13);
  Check.Check(~C.HasWarning(pilot, C.StatPointsBelow, NIL)
    & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 25; Stats at least 13, at most 13", FALSE),
    "13 at both: within them");
  Cr.SetBackgroundPoints(2);
  Check.Check((pilot.available = 27) & (Ch.BackgroundPointsKey IN pilot.creationKeys), "Background Points 2: 27");
  Cr.SetGenre(R.Cyberpunk);
  Check.Check((C.Value(dr.points) = 6) & (W.skillPanel.genre.Value() = R.Cyberpunk + 1)
    & LabelIs(Cr.summary, "Character Points: 20 spent of 27.  Skill Points: 6 spent of 20."),
    "Cyberpunk: Driving 3 a Level, and the Skills tab's genre follows");
  Cr.SetSkillPoints(FALSE, 0);
  Check.Check((pilot.creation.skillPoints = C.Unset) & ~(Ch.SkillPointsKey IN pilot.creationKeys) & ~Cr.skillIn.Active()
    & (Spun(Cr.skillIn) = 20) & (pilot.skillPoints = 20), "the GM's Skill Points off: the rule's 20, shown");
  Cr.SetStatCeiling(TRUE, 4);
  Check.Check((pilot.creation.statCeiling = 4) & C.HasWarning(pilot, C.StatRange, NIL) & Cr.statIn.Active(),
    "a ceiling of 4: Body 5 is above it");
  Cr.SetBonusCeiling(TRUE, 1);
  Check.Check((pilot.creation.bonusCeiling = 1) & ~C.HasWarning(pilot, C.OverBonusCeiling, NIL), "a Bonus Point ceiling of 1");
  Cr.SetStaged(TRUE);
  Check.Check(pilot.creation.stagedStatCost & (C.Value(pilot.statPoints[C.Body]) = R.StagedStatCost(5)), "Staged Stat Cost");
  Cr.SetAutoFireOne(TRUE);
  Check.Check((pilot.creation.autoFireSlots = 1) & (Ch.AutoFireSlotsKey IN pilot.creationKeys), "Auto-Fire as 1 slot");
  Cr.Cancel;
  Check.Check((Cr.dialog = NIL) & (pilot.creation.characterPoints = 20) & (pilot.creation.backgroundPoints = 0)
    & (pilot.creation.genre = R.ModernMilitary) & (pilot.creation.skillPoints = 20) & (pilot.creation.statCeiling = 0)
    & (pilot.creation.bonusCeiling = 0) & ~pilot.creation.stagedStatCost & (pilot.creation.autoFireSlots = 3)
    & (pilot.creation.statPointsCeiling = 0) & (pilot.creation.statPointsFloor = 0)
    & (pilot.creationKeys = keys) & (C.Value(dr.points) = 8) & (W.skillPanel.genre.Value() = R.ModernMilitary + 1)
    & (W.modified = was) & Line(W.CharacterPoints, "Character Points: Stats 13 + Attributes 8 - Bonus Points 1 = 20 of 20", FALSE),
    "Cancel: everything as it was");

  Pick(W.creationItem);
  Cr.SetCharacterPoints(FALSE, 0);
  Check.Check((pilot.available = 0) & ~(Ch.CharacterPointsKey IN pilot.creationKeys) & ~Cr.pointsIn.Active() & (Spun(Cr.pointsIn) = 20),
    "Character Points off: no limit; the spinner keeps 20");
  Cr.SetStaged(TRUE); Cr.SetStaged(FALSE);
  Check.Check(~(Ch.StagedStatCostKey IN pilot.creationKeys), "an option turned on and off again: not written");
  Cr.SetBackgroundPoints(1);
  Cr.Ok;
  Check.Check((Cr.dialog = NIL) & W.modified & (pilot.creation.backgroundPoints = 1), "OK: kept");
  chosen := Rp(CreationPath); Pick(W.saveItem);
  c := Reload(CreationPath);
  Check.Check((c # NIL) & (c[1].creation.characterPoints = 0) & (c[1].creation.backgroundPoints = 1)
    & (c[1].creation.genre = R.ModernMilitary) & (c[1].creationKeys = {Ch.BackgroundPointsKey, Ch.GenreKey, Ch.SkillPointsKey}),
    "saved and loaded again: no Character Points, Background Points 1");

  Pick(W.addCharacterItem); added := W.entity;
  Check.Check((added # pilot) & (added.creation.genre = R.ModernMilitary) & (added.creation.backgroundPoints = 1)
    & (added.creationKeys = pilot.creationKeys) & added.hasCreation, "Add Character: the shown one's creation");
  Pick(W.creationItem);
  Cr.copyChoice.ItemLabel(0, label);
  Check.Check(Cr.copyChoice.Active() & (Cr.copyChoice.Length() = 2) & (label = "Pilot"), "Copy from: the other character");
  Cr.SetGenre(R.Cyberpunk); Cr.SetCharacterPoints(TRUE, 50);
  Cr.Copy(0);
  Check.Check((added.creation.genre = R.ModernMilitary) & (added.creation.characterPoints = 0) & (Cr.genre.Value() = R.ModernMilitary + 1)
    & ~Cr.pointsOn.Value(), "Copy: Pilot's creation, shown");
  chosen := Rp("data/campaign.yaml"); Cr.LoadCampaign;
  Check.Check((added.creation.characterPoints = 40) & (added.creation.statPointsCeiling = 6) & (added.creation.statPointsFloor = 4)
    & Cr.statPointsCeilingOn.Value() & (Spun(Cr.statPointsCeilingIn) = 6) & Cr.statPointsFloorOn.Value() & (Spun(Cr.statPointsFloorIn) = 4)
    & (Spun(Cr.pointsIn) = 40), "Load Campaign...: a campaign file's creation, shown");
  chosen := Rp("data/window.yaml"); Cr.LoadCampaign;
  Check.Check((added.creation.characterPoints = 20) & (added.creation.backgroundPoints = 0) & Cr.pointsOn.Value() & (Spun(Cr.pointsIn) = 20)
    & (added.creation.statPointsCeiling = 0) & ~Cr.statPointsCeilingOn.Value() & ~Cr.statPointsFloorOn.Value(),
    "Load Campaign... of a character file: its first character's whole creation");
  chosen := Rp("data/creation.yaml"); Cr.LoadCampaign; Cr.SetBackgroundPoints(0);
  Check.Check((added.creation.genre = R.Cyberpunk) & (Ch.StagedStatCostKey IN added.creationKeys)
    & ~(Ch.BackgroundPointsKey IN added.creationKeys), "a copy's options kept as it wrote them, off too");
  Cr.SetStatPointsCeiling(TRUE, 30);
  chosen := Rp(CampaignPath); Cr.SaveCampaign;
  ok := Ch.LoadCampaign(CampaignPath, e, msg);
  Check.Check(ok & (e.creation.genre = R.Cyberpunk) & (e.creation.statPointsCeiling = 30) & (e.creationKeys = added.creationKeys),
    "Save Campaign...: written, and loads again as it was");
  chosen := Rp("data/window.yaml"); Cr.LoadCampaign;
  before := tells; chosen := Rp("data/mecha.yaml"); Cr.LoadCampaign;
  Check.Check((tells = before + 1) & (added.creation.characterPoints = 20), "a file of only mecha: said so, nothing copied");
  before := tells; chosen := Rp("data/no-such-file.yaml"); Cr.LoadCampaign;
  Check.Check(tells = before + 1, "a file that won't load: said so");
  chosen := NIL; Cr.LoadCampaign;
  Check.Check(added.creation.characterPoints = 20, "the file chooser cancelled: nothing");
  before := tells; Cr.SaveCampaign;
  Check.Check(tells = before, "Save Campaign... cancelled: nothing");
  Cr.Ok;
  Check.Check(pilot.creation.backgroundPoints = 1, "Pilot's own creation not changed by the copy");

  Pick(W.addMechaItem);
  Check.Check(W.entity.isMecha & (W.entity.owner = NIL) & Inactive(W.creationItem), "a mecha with no owner: inactive");
  Choose(0)
END Creation;

(* File > New from Campaign... (step 10a). *)
PROCEDURE NewFromCampaign;
  VAR first: Ch.Entity;
BEGIN
  Check.Check(Item("&File/New from &Campaign...", W.newFromCampaignItem, 0, {})
    & (W.newItem < W.newFromCampaignItem) & (W.newFromCampaignItem < W.openItem), "File > New from Campaign..., after New");
  answer := W.Discard; first := W.entity;
  chosen := NIL; Pick(W.newFromCampaignItem);
  Check.Check((W.entity = first) & (W.campaign = NIL), "cancelled: nothing");
  before := tells; chosen := Rp("data/no-such-file.yaml"); Pick(W.newFromCampaignItem);
  Check.Check((tells = before + 1) & (W.entity = first) & (W.campaign = NIL), "a file that won't load: said so, nothing");
  chosen := Rp("data/campaign.yaml"); Pick(W.newFromCampaignItem);
  e := W.entity;
  Check.Check((W.campaign # NIL) & (e # first) & (LEN(W.entities^) = 1) & e.hasCreation & ~e.isMecha
    & (e.creation.characterPoints = 40) & (e.creation.genre = R.ModernMilitary)
    & (e.creation.statPointsCeiling = 6) & (e.creation.statPointsFloor = 4) & (e.creationKeys = W.campaign.creationKeys) & ~W.modified,
    "a campaign: a new character in it");
  Check.Check(Line(W.CharacterPoints, "Character Points: Stats 3 + Attributes 0 - Bonus Points 0 = 3 of 40; Stats at least 4, at most 6", TRUE),
    "its Stats below the campaign's floor");
  Pick(W.creationItem); Cr.SetCharacterPoints(TRUE, 30); Cr.SetStatPointsFloor(FALSE, 0); Cr.Ok;
  Check.Check((e.creation.characterPoints = 30) & (W.campaign.creation.characterPoints = 40) & (W.campaign.creation.statPointsFloor = 4),
    "copied, not linked: the campaign unchanged by an edit");
  Pick(W.newItem);
  Check.Check((W.entity # e) & (W.entity.creation.characterPoints = 40) & (W.entity.creation.statPointsFloor = 4),
    "File > New afterwards: in the campaign");
  W.campaign := NIL; Pick(W.newItem);
  Check.Check(W.entity.creation.statPointsCeiling = 0, "no campaign: no limits")
END NewFromCampaign;

(* Whether r contains s. *)
PROCEDURE Contains(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN (r # NIL) & (Ropes.Find(r, s, 0) >= 0)
END Contains;

(* Whether the preview's display shows its text. *)
PROCEDURE Displayed(): BOOLEAN;
  VAR b: FlText.TextBuffer; s: Besm2Text.String; t: Besm2Text.String;
BEGIN
  b := Pv.display.Buffer(); NEW(s, b.Length() + 1); b.GetText(s^); t := Besm2Text.Chars(Pv.text);
  RETURN s^ = t^
END Displayed;

(* Shows tab g, as a click on it does. *)
PROCEDURE ShowTab(g: Fl.Group);
BEGIN W.tabs.SetValue(g); W.tabs.DoCallback
END ShowTab;

(* The Preview tab (step 11).  It saves the file and the preview in
   each format in ../obj, which test/preview.sh then compares with
   besm2_calc_po's and pobesm2_fmt2's output for that file. *)
PROCEDURE Preview;
  VAR before: Rope; label: ARRAY 64 OF CHAR;
BEGIN
  answer := W.Discard; Pick(W.newItem);
  Check.Check(Pv.text = NIL, "Preview: nothing made before the tab is shown");
  ShowTab(W.previewTab);
  Check.Check((Pv.text # NIL) & Displayed(), "shown: made, and displayed");
  Pv.format.ItemLabel(0, label);
  Check.Check((Pv.format.Value() = Pv.Grid) & (label = "reST grid tables") & Pv.format.IsItem(3) & ~Pv.format.IsItem(4),
    "four formats, grid tables first");
  chosen := NIL; suggestedName := Rp("x"); Pv.Save;
  Check.Check(suggestedName = NIL, "Save... for a new character without a name or file: nothing suggested");

  Copy("data/window.yaml", PreviewPath);
  chosen := Rp(PreviewPath); Pick(W.openItem);
  Check.Check(Contains(Pv.text, "Pilot") & Contains(Pv.text, "Walker") & Displayed(), "a file opened: all its entities, shown");
  W.nameIn.SetValue("Test Pilot"); W.nameIn.DoCallback;
  Check.Check(Contains(Pv.text, "Test Pilot") & Displayed(), "the name typed: the preview follows");
  W.taglineIn.SetValue("Previewed"); W.taglineIn.DoCallback;
  Check.Check(Contains(Pv.text, "Previewed"), "the tagline too");
  chosen := Rp(PreviewPath); Pick(W.saveItem);

  chosen := NIL; Pv.Save;
  Check.Check(Is(suggestedName, "preview.rst"), "Save...: the file's name, .rst");
  chosen := Rp("../obj/preview-grid.rst"); Pv.Save;
  before := Pv.text;
  Pv.SetFormat(Pv.Terse);
  Check.Check((Pv.text # NIL) & ~Ropes.Equal(Pv.text, before) & Contains(Pv.text, "Test Pilot") & Displayed(), "terse: another text");
  chosen := Rp("../obj/preview-terse.rst"); Pv.Save;
  Pv.SetFormat(Pv.RawMs);
  Check.Check(Contains(Pv.text, ".. raw:: ms") & Displayed(), "raw ms: a raw ms block");
  chosen := Rp("../obj/preview-rawms.rst"); Pv.Save;
  Pv.SetFormat(Pv.Hmm);
  chosen := NIL; Pv.Save;
  Check.Check(Contains(Pv.text, "Test Pilot") & Is(suggestedName, "preview.hmm") & Displayed(), "h-m-m: suggested as .hmm");
  chosen := Rp("../obj/preview.hmm"); Pv.Save;

  before := Pv.text;
  ShowTab(W.characterTab);
  W.nameIn.SetValue("Hidden Pilot"); W.nameIn.DoCallback;
  Check.Check(Pv.text = before, "the tab not shown: not made again");
  ShowTab(W.previewTab);
  Check.Check(Contains(Pv.text, "Hidden Pilot"), "shown again: made again");

  Pv.Copy;
  Check.Check(Fl.ClipboardHasText(), "Copy: text on the clipboard");
  before := Pv.text; i := tells;
  chosen := Rp("../obj/no-such-dir/preview.rst"); Pv.Save;
  Check.Check((tells = i + 1) & Is(told, "can't write ../obj/no-such-dir/preview.rst: No such file or directory"),
    "Save... where it can't: said so");
  Pv.SetFormat(Pv.Grid); ShowTab(W.characterTab)
END Preview;

PROCEDURE Weapons;
  VAR p: Besm2ItemPanel.AttrPanel; wa: R.Item; a, a2: Ch.Attr; m: Ch.Mod; was: BOOLEAN; es: Ch.Entities;
    label: ARRAY 128 OF CHAR;
BEGIN
  answer := W.Discard; Pick(W.newItem);
  e := W.entity; p := W.attrPanel; wa := R.Find("Weapon Attack");
  before := tells; W.weaponButton.DoCallback;
  Check.Check((tells = before + 1) & Is(told, "Choose a Weapon Attack first.") & (D.dialog = NIL),
    "Weapon... with no Weapon Attack selected: said so");
  ChooseItem(p, wa); p.spinner.SetValue(4); p.text.SetValue("Sword"); p.add.DoCallback;
  a := e.attrs(Ch.Attr); was := W.modified;
  W.weaponButton.DoCallback;
  Check.Check((D.dialog # NIL) & (D.attr = a) & (D.help.page = 81) & (ENTIER(D.level.Value() + 0.5) = 4)
    & ~D.primary.Active() & D.primary.Value(), "Weapon...: its dialog, ? at p. 81, its Level; the only one, the primary");
  D.title.GetLabel(label);
  Check.Check(label = "Weapon Attack (p. 81, PDF 83)", "its name, with both pages");
  Check.Check(Shows(D.damage, a.damage) & Shows(D.points, a.points) & (C.Value(a.damage) = 60) & (C.Value(a.points) = 16),
    "its damage and points");

  ChooseItem(D.abilities, R.FindKind(R.Ability, "Accurate"));
  Check.Check((D.abilities.help.page = 83) & (ENTIER(D.abilities.spinner.Value() + 0.5) = 1), "an Ability chosen: ? at its page, its slots");
  D.abilities.add.DoCallback;
  Check.Check((D.abilities.browser.Count() = 1) & Holds(D.abilities.browser, 1, "Accurate") & Holds(D.abilities.browser, 1, "1 slot")
    & Holds(D.abilities.browser, 1, "p. 83, PDF 85") & (C.Value(a.damage) = 45) & Shows(D.damage, a.damage) & W.modified,
    "Add: listed, with its slots and both pages; the damage follows");

  ChooseItem(D.disabilities, R.FindKind(R.Disability, "Melee"));
  Check.Check(ENTIER(D.disabilities.spinner.Value() + 0.5) = 2, "Melee: its 2 slots");
  D.disabilities.spinner.SetValue(1); D.disabilities.text.SetValue(" sword "); D.disabilities.add.DoCallback;
  m := a.disabilities(Ch.Mod);
  Check.Check((m # NIL) & (m.countsAs = 1) & Holds(D.disabilities.browser, 1, "Melee (sword)") & Holds(D.disabilities.browser, 1, "1 slot")
    & (C.Value(a.damage) = 60), "counting as 1: counts-as, its detail, the damage");

  Select(D.abilities.browser, 1);
  Check.Check(D.abilities.Item() = R.FindKind(R.Ability, "Accurate"), "a line selected: loaded");
  D.abilities.spinner.SetValue(2); D.abilities.change.DoCallback;
  Check.Check(Holds(D.abilities.browser, 1, "Accurate x2") & Holds(D.abilities.browser, 1, "2 slots") & (C.Value(a.damage) = 45),
    "Change: twice, x2");

  D.SetLevel(5);
  Check.Check((a.level = 5) & (C.Value(a.damage) = 60) & (C.Value(a.points) = 20) & Shows(D.points, a.points)
    & Holds(p.browser, 1, "5 Weapon Attack: Sword") & Holds(p.browser, 1, "20 pts"), "the Level: damage, points, and the list, follow");
  Type(D.damage, "50");
  Check.Check(a.damage.overridden & (C.Value(a.damage) = 50) & Shows(D.damage, a.damage), "the damage overridden");
  D.SetGunner(TRUE);
  Check.Check(a.differentGunner & (C.Value(a.points) = 25) & (DialogWarning("Different Gunner") > 0), "a different gunner: +5, and warned on a character");

  D.Cancel;
  Check.Check((D.dialog = NIL) & (a.level = 4) & (a.abilities = NIL) & (a.disabilities = NIL) & ~a.damage.overridden
    & ~a.differentGunner & (C.Value(a.damage) = 60) & (C.Value(a.points) = 16) & (W.modified = was)
    & Holds(p.browser, 1, "4 Weapon Attack: Sword"), "Cancel: everything as it was");

  W.weaponButton.DoCallback;
  ChooseItem(D.disabilities, R.FindKind(R.Disability, "Melee")); D.disabilities.spinner.SetValue(1); D.disabilities.add.DoCallback;
  ChooseItem(D.abilities, R.FindKind(R.Ability, "Area Effect")); D.abilities.add.DoCallback;
  D.subjectIn.SetValue(" Spear ");
  Select(D.abilities.browser, 1); D.abilities.remove.DoCallback;
  Check.Check((D.abilities.browser.Count() = 0) & (a.abilities = NIL), "Remove");
  ChooseItem(D.abilities, R.FindKind(R.Ability, "Area Effect")); D.abilities.add.DoCallback;
  D.Ok;
  Check.Check((D.dialog = NIL) & Is(a.subject, "Spear") & (a.abilities # NIL) & (a.disabilities.countsAs = 1)
    & (C.Value(a.damage) = 60) & Holds(p.browser, 1, "4 Weapon Attack: Spear") & W.modified, "OK: kept, the subject taken");

  ChooseItem(p, wa); p.spinner.SetValue(4); p.text.SetValue("Bow"); p.add.DoCallback;
  a2 := a.next(Ch.Attr);
  Check.Check(a.isPrimary & (C.Value(a2.points) = 2), "a second at the same Level: 2 points");
  Select(p.browser, 1); W.weaponButton.DoCallback;
  Check.Check(D.primary.Active() & D.primary.Value(), "two: primary can be changed");
  before := tells; D.SetPrimary(FALSE);
  Check.Check((tells = before + 1) & a.isPrimary & D.primary.Value(), "unmarked: still the primary, and said why");
  Select(D.disabilities.browser, 1); D.disabilities.spinner.SetValue(2); D.disabilities.change.DoCallback;
  Check.Check(a.disabilities.countsAs = 0, "Melee changed to its own 2 slots: counts-as left out");
  D.Cancel;
  Check.Check((a.disabilities # NIL) & (a.disabilities.countsAs = 1) & (C.Value(a.damage) = 60) & ~a.primary,
    "Cancel: a changed Disability as it was");
  Select(p.browser, 2); W.weaponButton.DoCallback;
  D.SetPrimary(TRUE);
  Check.Check(a2.primary & a2.isPrimary & ~a.isPrimary & (C.Value(a2.points) = 16) & (C.Value(a.points) = 2)
    & Holds(p.browser, 1, "2 pts"), "the second marked: the primary, priced so, and the first a secondary");
  D.Ok;

  chosen := Rp(WeaponPath); Pick(W.saveAsItem);
  es := Reload(WeaponPath);
  Check.Check((es # NIL) & (es[0].attrs.disabilities # NIL) & (es[0].attrs.disabilities.countsAs = 1)
    & es[0].attrs.next.primary & ~es[0].attrs.primary, "saved and loaded again: counts-as 1, the primary");

  Select(p.browser, 1); W.weaponButton.DoCallback;
  D.SetLevel(6)  (* left open: W.Close cancels it *)
END Weapons;

BEGIN
  W.tell := Tell; W.ask := Ask; W.confirm := Confirm; confirmed := FALSE; confirms := 0; W.choosePath := ChoosePath; W.choosePdf := ChoosePdf; W.chooseCampaign := ChoosePath; Pv.choosePath := ChoosePreview; Pv.tell := Tell; W.askText := AskText;
  tells := 0; asked := 0; answer := W.Cancel; chosen := NIL; typed := NIL;
  Basics;
  NewCharacter;
  Editing;
  SaveFirst;
  Files;
  Bare;
  Notices;
  Mecha;
  Rulebook;
  Attributes;
  Defects;
  Skills;
  Background;
  Several;
  Creation;
  NewFromCampaign;
  Preview;
  Weapons;
  Pick(W.creationItem); Cr.SetCharacterPoints(TRUE, 77);
  W.Close;
  Check.Check(W.window = NIL, "Close deletes it");
  Check.Check((D.dialog = NIL) & (e.attrs.level = 4), "and cancels the Weapon Attack dialog");
  Check.Check((Cr.dialog = NIL) & (e.creation.characterPoints = 0), "and the Creation dialog");
  Check.Summary
END TestWindow.
