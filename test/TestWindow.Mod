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
   PDF... and Viewer....  Runs in test/: its files are data/*.yaml, and
   what it saves goes in ../obj; it opens copies of the data/*.yaml
   it changes there, so a File > Save gone wrong can't change it. *)

IMPORT Check, Fl, FlMenus, C := Besm2Calc, Ch := Besm2Character, Besm2Save, Besm2Text, Besm2Viewer, Besm2Widgets,
  W := Besm2Window, Out, Ropes;

CONST
  SavePath = "../obj/window-test.yaml";
  SavePath2 = "../obj/window-two.yaml";
  OpenPath = "../obj/window.yaml";  (* data/window.yaml, copied *)
  BarePath = "../obj/bare.yaml";  (* data/bare.yaml, copied *)

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;           (* how many messages were shown *)
  told: Rope;               (* the last one *)
  answer, asked: INTEGER;   (* what ask answers, and how often it was asked *)
  question: Rope;           (* what ask asked last *)
  chosen: Rope;             (* what choosePath and choosePdf answer; NIL: cancelled *)
  typed: Rope;              (* what askText answers; NIL: cancelled *)
  prompted: Rope;           (* what askText was shown last *)
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

PROCEDURE AskText(prompt: Rope; VAR text: Rope): BOOLEAN;
BEGIN prompted := prompt; IF typed # NIL THEN text := typed END; RETURN typed # NIL
END AskText;

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
  Check.Check(TitleIs(" - window.yaml"), "the title names the file");
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
  Check.Check(TitleIs(" - window-two.yaml"), "and the title names it");
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

BEGIN
  W.tell := Tell; W.ask := Ask; W.choosePath := ChoosePath; W.choosePdf := ChoosePdf; W.askText := AskText;
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
  W.Close;
  Check.Check(W.window = NIL, "Close deletes it");
  Check.Summary
END TestWindow.
