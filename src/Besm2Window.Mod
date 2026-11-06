MODULE Besm2Window; (* besm2_cg_po's main window: the menu bar, the Character tab, and the file's entities *)

(* PLAN.md, Part B, step 6, and A5 (the layout, decided 2026-11-06),
   after ova_cg_po's OvaWindow.  One window, narrow enough to sit beside
   the rulebook's viewer: a menu bar (File, Character, Rulebook) and
   the tabs.  Character (step 6): the name, tagline and size; the
   Stats; the derived values; the points; and the warnings.
   Attributes, Defects and Skills (step 7): each a Besm2ItemPanel, and
   under it the points and the warnings again, so a choice's effect is
   seen where it is made.  Background (step 7): Besm2Background.  The
   others are empty until their steps.

   A file holds one entity or several (characters and mecha).  All are
   kept, in order, and saved back; the one shown is the first that
   isn't a mecha, or the first if all are (step 9 adds the switching).

   Every change a widget makes goes into the entity, then they are all
   computed again (Besm2Character.ComputeAll, since a character prices
   its mecha), then the window shows the entity again, so no widget
   holds the only copy of anything.  Every widget, and every record a
   callback reaches, is kept in module variables, so poc's collector
   sees them (it can't see FLTK's pointers).

   What would wait for the user -- a message, a question, a file
   chooser, the rulebook's viewer -- goes through a procedure variable
   (tell, ask, choosePath, choosePdf, askText, and Besm2Widgets.openPage),
   so a test can answer it.  The rulebook's path and the viewer the user
   chooses are kept in the preferences (UsePreferences), between runs. *)

IMPORT Fl, FlBrowsers, FlDialogs, FlInputs, FlLayout, FlMenus, FlPreferences, FlValuators,
  C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Layout, Besm2Paths, Besm2Save, Besm2Text,
  Besm2Background, Besm2ItemPanel, Besm2Viewer, Besm2Warnings, Besm2WeaponDialog, Besm2Widgets, FlButtons, Ropes;

CONST
  Title* = "BESM2ER Character Generator";
  Width = 640; Height = 800; BarHeight = 25; TabHeight = 25;
  Row = 25;
  LeftX = 10; ColumnW = 620;
  Top = BarHeight + TabHeight + 10;
  CharacterPointsPage = 13;
  NoticeWidth = 80;  (* characters on a line of the notices *)

  (* ask's answers *)
  SaveFirst* = 0; Discard* = 1; Cancel* = 2;

  (* points: the summary's lines *)
  CharacterPoints* = 0; BonusPoints* = 1; SkillPoints* = 2; NPointLines = 3;

  (* tabPoints and tabWarnings: the list tabs' *)
  AttributesList* = 0; DefectsList* = 1; SkillsList* = 2; NLists* = 3;
  ListBottom = Height - 220;  (* where a list tab's panel ends, and its points begin *)

TYPE
  Rope = Ropes.Rope;

  (* A Stat's points: which is C.Body, C.Mind or C.Soul. *)
  StatNumber = POINTER TO RECORD (Besm2Widgets.TargetDesc) which: INTEGER END;
  (* A derived value: slot is Ch.ACV .. Ch.AR. *)
  DerivedNumber = POINTER TO RECORD (Besm2Widgets.TargetDesc) slot: INTEGER END;
  MainWindow = POINTER TO RECORD (Fl.DoubleWindowDesc) END;

VAR
  window-: Fl.DoubleWindow;
  bar-: FlMenus.MenuBar;
  tabs-: FlLayout.Tabs;
  characterTab-, attributesTab-, defectsTab-, skillsTab-, mechaTab-, backgroundTab-, previewTab-: Fl.Group;
  newItem-, openItem-, saveItem-, saveAsItem-, quitItem-: INTEGER;
  rulebookItem-, choosePdfItem-, viewerItem-: INTEGER;

  (* The file's entities, in order, and the one shown, entities[current];
     the file they came from or were saved to (NIL: none), and whether
     any has changed since. *)
  entities-: Ch.Entities;
  current-: INTEGER;
  entity-: Ch.Entity;
  path-: Rope;
  modified-: BOOLEAN;

  nameIn-, taglineIn-, sizeIn-: FlInputs.Input;
  statValue-: ARRAY C.NStats OF FlValuators.Spinner;
  statPoints-: ARRAY C.NStats OF Besm2Widgets.NumberBox;
  derived-: ARRAY Ch.AR + 1 OF Besm2Widgets.NumberBox;  (* by slot *)
  points-: ARRAY NPointLines OF Fl.Box;
  warnings-: FlBrowsers.Browser;
  attrPanel-: Besm2ItemPanel.AttrPanel;
  weaponButton-: FlButtons.Button;  (* the Attributes tab's: Besm2WeaponDialog on the line selected *)
  defectPanel-: Besm2ItemPanel.DefectPanel;
  skillPanel-: Besm2ItemPanel.SkillPanel;
  tabPoints-: ARRAY NLists, NPointLines OF Fl.Box;
  tabWarnings-: ARRAY NLists OF FlBrowsers.Browser;

  (* What would wait for the user; a test sets its own.  tell shows a
     message; ask asks whether to save first (SaveFirst, Discard,
     Cancel); choosePath asks for a file to open, or to save to if save;
     choosePdf for the rulebook's PDF; askText for a line of text,
     showing text as it is. *)
  tell*: PROCEDURE (text: Rope);
  ask*: PROCEDURE (question: Rope): INTEGER;
  choosePath*: PROCEDURE (save: BOOLEAN; VAR path: Rope): BOOLEAN;
  choosePdf*: PROCEDURE (VAR path: Rope): BOOLEAN;
  askText*: PROCEDURE (prompt: Rope; VAR text: Rope): BOOLEAN;

  (* The rulebook: --rulebook's path, or the one chosen this run (NIL:
     none), and the one saved in the preferences (NIL: none). *)
  rulebookOption*: Rope;
  savedRulebook-: Rope;
  (* The viewer, and whether --viewer chose it, so the preferences'
     doesn't replace it. *)
  viewer*: Besm2Viewer.Viewer;
  viewerOption*: BOOLEAN;
  (* Where the rulebook and viewer are kept (NIL: nowhere). *)
  preferences-: FlPreferences.Preferences;
  showing: BOOLEAN;  (* ShowAll is setting the widgets: their callbacks change nothing *)
  weaponLine: INTEGER;      (* the Weapon Attack's line, while its dialog is open *)
  weaponModified: BOOLEAN;  (* modified, when it opened *)

PROCEDURE^ ShowAll;

(* ---- Text ---- *)

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

(* What input i holds; NIL if empty. *)
PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: Besm2Text.String;
BEGIN
  NEW(s, i.Length() + 1); i.Value(s^);
  RETURN Ropes.FromString(s^)
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); i.SetValue(s^)
END SetInput;

(* ---- What would wait for the user ---- *)

PROCEDURE DialogTell(text: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(text); FlDialogs.Message(s^)
END DialogTell;

PROCEDURE DialogAsk(question: Rope): INTEGER;
  VAR s: Besm2Text.String; r: INTEGER;
BEGIN
  s := Besm2Text.Chars(question);
  r := FlDialogs.Choice(s^, "Save", "Don't save", "Cancel");
  IF (r < 0) OR (r > 2) THEN r := Cancel END;
  RETURN r
END DialogAsk;

PROCEDURE DialogPath(save: BOOLEAN; VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; name: ARRAY 4096 OF CHAR; filter: ARRAY 32 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c);
  IF save THEN
    FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseSaveFile);
    c.SetTitle("Save the character as"); c.SetOptions(FlDialogs.SaveAsConfirm)
  ELSE
    FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile);
    c.SetTitle("Open a character")
  END;
  filter := "YAML *.{yaml,yml}"; filter[4] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, name); p := Ropes.FromString(name); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPath;

PROCEDURE DialogPdf(VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; name: ARRAY 4096 OF CHAR; filter: ARRAY 16 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c); FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile);
  c.SetTitle("The rulebook's PDF");
  filter := "PDF *.pdf"; filter[3] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, name); p := Ropes.FromString(name); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPdf;

PROCEDURE DialogText(prompt: Rope; VAR text: Rope): BOOLEAN;
  VAR s: Besm2Text.String; value: ARRAY 4096 OF CHAR; ok: BOOLEAN;
BEGIN
  s := Besm2Text.Chars(text); COPY(s^, value);
  s := Besm2Text.Chars(prompt);
  ok := FlDialogs.Input(s^, value);
  IF ok THEN text := Ropes.FromString(value) END;
  RETURN ok
END DialogText;

(* ---- The rulebook ---- *)

(* Keeps text under name in the preferences, written at once. *)
PROCEDURE Keep(name: ARRAY OF CHAR; text: Rope);
  VAR s: Besm2Text.String;
BEGIN
  IF preferences # NIL THEN
    s := Besm2Text.Chars(text); preferences.SetText(name, s^);
    IF ~preferences.Flush() THEN tell(Rp("The preferences couldn't be written.")) END
  END
END Keep;

(* What the preferences hold under name; NIL for nothing. *)
PROCEDURE Kept(name: ARRAY OF CHAR): Rope;
  VAR s: Besm2Text.String;
BEGIN
  NEW(s, preferences.TextLength(name) + 1); preferences.GetText(name, "", s^);
  RETURN Besm2Text.Trim(Ropes.FromString(s^))
END Kept;

(* Takes the rulebook's path and the viewer from p (NIL: none), where
   the ones the user chooses are kept; --viewer's wins over the one
   kept, and --rulebook's and BESM2_RULEBOOK's over the path kept
   (Besm2Viewer.FindRulebook).  A viewer kept that isn't one is
   ignored. *)
PROCEDURE UsePreferences*(p: FlPreferences.Preferences);
  VAR v: Besm2Viewer.Viewer;
BEGIN
  preferences := p; savedRulebook := NIL;
  IF p # NIL THEN
    savedRulebook := Kept("rulebook");
    IF ~viewerOption & Besm2Viewer.Parse(Kept("viewer"), v) THEN viewer := v END
  END
END UsePreferences;

(* Asks for the rulebook's PDF, uses it from now on, and keeps it. *)
PROCEDURE ChooseRulebook(): BOOLEAN;
  VAR p: Rope;
BEGIN
  IF ~choosePdf(p) THEN RETURN FALSE END;
  p := Besm2Paths.Absolute(p, NIL);
  rulebookOption := p; savedRulebook := p; Keep("rulebook", p);
  RETURN TRUE
END ChooseRulebook;

(* Opens the rulebook at printed page page (the viewer is sent the
   PDF's).  If it isn't found, asks for it once; if not given, says
   why. *)
PROCEDURE OpenPage(page: INTEGER);
  VAR pdf, msg: Rope;
BEGIN
  IF ~Besm2Viewer.FindRulebook(rulebookOption, savedRulebook, pdf) THEN
    IF ~ChooseRulebook() OR ~Besm2Viewer.FindRulebook(rulebookOption, savedRulebook, pdf) THEN
      msg := Rp("The rulebook isn't at "); msg := Ropes.Cat(msg, pdf);
      Besm2Text.Add(msg, ": choose it with Rulebook > Choose PDF..., or give it with --rulebook or BESM2_RULEBOOK.");
      tell(msg);
      RETURN
    END
  END;
  IF Besm2Viewer.Open(viewer, pdf, page, msg) THEN END;
  IF msg # NIL THEN tell(msg) END
END OpenPage;

PROCEDURE RulebookAction(w: Fl.Widget);
BEGIN Besm2Widgets.openPage(1)
END RulebookAction;

PROCEDURE ChoosePdfAction(w: Fl.Widget);
BEGIN IF ChooseRulebook() THEN END
END ChoosePdfAction;

(* Rulebook > Viewer...: a viewer's name or a command, kept. *)
PROCEDURE ViewerAction(w: Fl.Widget);
  VAR text, msg: Rope; v: Besm2Viewer.Viewer;
BEGIN
  text := Besm2Viewer.Name(viewer);
  IF askText(Rp("Viewer: okular, evince, mupdf, xdg-open, or a command (%f the PDF, %p its page)"), text) THEN
    IF Besm2Viewer.Parse(text, v) THEN
      viewer := v; Keep("viewer", Besm2Viewer.Name(v))
    ELSE
      msg := Rp("Not a viewer: "); msg := Ropes.Cat(msg, text);
      Besm2Text.Add(msg, ". Give okular, evince, mupdf, xdg-open, or a command with %f for the PDF.");
      tell(msg)
    END
  END
END ViewerAction;

(* ---- Title and changes ---- *)

(* The file's name, path without its directory. *)
PROCEDURE FileName(): Rope;
  VAR slash: LONGINT;
BEGIN
  slash := Ropes.RIndexChar(path, "/", Ropes.Length(path));
  RETURN Ropes.Substring(path, slash + 1, Ropes.Length(path) - slash - 1)
END FileName;

PROCEDURE ShowTitle;
  VAR t: Rope; s: Besm2Text.String;
BEGIN
  t := Rp(Title);
  IF path # NIL THEN Besm2Text.Add(t, " - "); t := Ropes.Cat(t, FileName()) END;
  IF modified THEN Besm2Text.Add(t, " *") END;
  s := Besm2Text.Chars(t); window.SetLabel(s^)
END ShowTitle;

(* The warnings, on the Character tab and each list tab. *)
PROCEDURE ShowWarnings;
  VAR w: C.Warning; s: Besm2Text.String; t: INTEGER;
BEGIN
  warnings.Clear;
  FOR t := 0 TO NLists - 1 DO tabWarnings[t].Clear END;
  w := entity.warnings;
  WHILE w # NIL DO
    s := Besm2Text.Chars(Besm2Warnings.Text(entity, w)); warnings.Add(s^);
    FOR t := 0 TO NLists - 1 DO tabWarnings[t].Add(s^) END;
    w := w.next
  END
END ShowWarnings;

PROCEDURE SetLine(b: Fl.Box; r: Rope; red: BOOLEAN);
  VAR s: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(r); b.SetLabel(s^);
  IF red THEN b.SetLabelColor(Fl.Red) ELSE b.SetLabelColor(Fl.ForegroundColor) END;
  b.Redraw
END SetLine;

(* Points line i, r, on the Character tab and each list tab. *)
PROCEDURE SetLines(i: INTEGER; r: Rope; red: BOOLEAN);
  VAR t: INTEGER;
BEGIN
  SetLine(points[i], r, red);
  FOR t := 0 TO NLists - 1 DO SetLine(tabPoints[t][i], r, red) END
END SetLines;

(* The points: "Character Points: Stats 15 + Attributes 22 - Bonus
   Points 4 = 33 of 35" (Mecha Points for a mecha, without Stats),
   "Bonus Points: 4 (ceiling: none)", "Skill Points: 15 of 20"; each red
   when it is over its limit. *)
PROCEDURE ShowPoints;
  VAR e: Ch.Entity; r: Rope;
BEGIN
  e := entity;
  IF e.isMecha THEN r := Rp("Mecha Points: ")
  ELSE r := Rp("Character Points: Stats "); Besm2Text.AddInt(r, e.statTotal); Besm2Text.Add(r, " + ")
  END;
  Besm2Text.Add(r, "Attributes "); Besm2Text.AddInt(r, e.attrTotal);
  Besm2Text.Add(r, " - Bonus Points "); Besm2Text.AddInt(r, e.bonusPoints);
  Besm2Text.Add(r, " = "); Besm2Text.AddInt(r, e.spent);
  IF e.available > 0 THEN Besm2Text.Add(r, " of "); Besm2Text.AddInt(r, e.available)
  ELSE Besm2Text.Add(r, " (no limit set)")
  END;
  SetLines(CharacterPoints, r,
    C.HasWarning(e, C.OverCharacterPoints, NIL) OR C.HasWarning(e, C.OverMechaPoints, NIL));
  r := Rp("Bonus Points: "); Besm2Text.AddInt(r, e.bonusPoints); Besm2Text.Add(r, " (ceiling: ");
  IF e.creation.bonusCeiling > 0 THEN Besm2Text.AddInt(r, e.creation.bonusCeiling) ELSE Besm2Text.Add(r, "none") END;
  Besm2Text.Add(r, ")");
  SetLines(BonusPoints, r, C.HasWarning(e, C.OverBonusCeiling, NIL));
  r := Rp("Skill Points: "); Besm2Text.AddInt(r, e.skillSpent); Besm2Text.Add(r, " of ");
  Besm2Text.AddInt(r, e.skillPoints);
  SetLines(SkillPoints, r, C.HasWarning(e, C.OverSkillPoints, NIL))
END ShowPoints;

(* Every number shown again: the Stats only on a character, a mecha
   has none (p. 59); ACV, DCV, EP and SV likewise; AR only with
   armour, or an override of it. *)
PROCEDURE ShowNumbers;
  VAR i: INTEGER; e: Ch.Entity;
BEGIN
  e := entity;
  FOR i := 0 TO C.NStats - 1 DO
    statValue[i].SetValue(e.stat[i]); statPoints[i].Display;
    IF e.isMecha THEN statValue[i].Deactivate; statPoints[i].Deactivate
    ELSE statValue[i].Activate; statPoints[i].Activate
    END
  END;
  FOR i := Ch.ACV TO Ch.AR DO derived[i].Display END;
  FOR i := Ch.ACV TO Ch.SV DO
    IF e.isMecha & (i # Ch.HP) THEN derived[i].Hide ELSE derived[i].Show END
  END;
  IF e.hasAR OR e.ar.overridden THEN derived[Ch.AR].Show ELSE derived[Ch.AR].Hide END;
  ShowPoints;
  ShowWarnings
END ShowNumbers;

(* After any change to an entity: computed again and shown. *)
PROCEDURE Changed;
BEGIN
  Ch.Relink(entities);  (* an edit may have named a mecha *)
  Ch.ComputeAll(entities);
  modified := TRUE;
  ShowTitle;
  ShowNumbers
END Changed;

(* ---- Numbers ---- *)

PROCEDURE (t: StatNumber) Get*(VAR n: C.Number);
BEGIN n := entity.statPoints[t.which]
END Get;

PROCEDURE (t: StatNumber) Put*(VAR n: C.Number);
BEGIN entity.statPoints[t.which] := n; Ch.UseStat(entity, t.which)
END Put;

PROCEDURE (t: DerivedNumber) Get*(VAR n: C.Number);
  VAR e: Ch.Entity;
BEGIN
  e := entity;
  CASE t.slot OF
    Ch.ACV: n := e.acv | Ch.DCV: n := e.dcv | Ch.HP: n := e.hp | Ch.EP: n := e.ep | Ch.SV: n := e.sv
  | Ch.AR: n := e.ar
  END
END Get;

PROCEDURE (t: DerivedNumber) Put*(VAR n: C.Number);
  VAR e: Ch.Entity;
BEGIN
  e := entity;
  CASE t.slot OF
    Ch.ACV: e.acv := n | Ch.DCV: e.dcv := n | Ch.HP: e.hp := n | Ch.EP: e.ep := n | Ch.SV: e.sv := n
  | Ch.AR: e.ar := n
  END;
  Ch.UseDerived(e, t.slot)
END Put;

(* What a number box is for, in its message. *)
PROCEDURE BoxName(b: Besm2Widgets.NumberBox; VAR s: ARRAY OF CHAR);
  VAR t: Besm2Widgets.Target;
BEGIN
  b.GetLabel(s); t := b.target;
  IF s = "" THEN
    WITH t: StatNumber DO
      CASE t.which OF C.Body: COPY("Body's points", s) | C.Mind: COPY("Mind's points", s)
      | C.Soul: COPY("Soul's points", s)
      END
    ELSE
    END
  END
END BoxName;

(* A number box's text taken; refused text is said so. *)
PROCEDURE NumberChanged(b: Besm2Widgets.NumberBox; ok: BOOLEAN);
  VAR label: ARRAY 64 OF CHAR; msg: Rope;
BEGIN
  IF ~ok THEN
    BoxName(b, label);
    msg := Rp("Not a number");
    IF label # "" THEN Besm2Text.Add(msg, " for "); Besm2Text.Add(msg, label) END;
    Besm2Text.Add(msg, ": a whole number. The computed number is used.");
    tell(msg)
  END;
  Changed
END NumberChanged;

PROCEDURE StatAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  IF showing THEN RETURN END;
  FOR i := 0 TO C.NStats - 1 DO
    IF w = statValue[i] THEN
      entity.stat[i] := SHORT(ENTIER(statValue[i].Value() + 0.5));
      Ch.UseStat(entity, i)
    END
  END;
  Changed
END StatAction;

(* ---- Text ---- *)

(* has and r set from text: an entity keeps a key it had, even emptied. *)
PROCEDURE SetText(VAR has: BOOLEAN; VAR r: Rope; text: Rope);
BEGIN r := text; has := has OR (text # NIL)
END SetText;

PROCEDURE TextAction(w: Fl.Widget);
  VAR e: Ch.Entity;
BEGIN
  IF showing THEN RETURN END;
  e := entity;
  IF w = nameIn THEN SetText(e.hasName, e.name, Besm2Text.Trim(InputText(nameIn)))
  ELSIF w = taglineIn THEN SetText(e.hasTagline, e.tagline, Besm2Text.Trim(InputText(taglineIn)))
  ELSIF w = sizeIn THEN SetText(e.hasSize, e.size, Besm2Text.Trim(InputText(sizeIn)))
  END;
  modified := TRUE; ShowTitle
END TextAction;

PROCEDURE TextInput(VAR i: FlInputs.Input; x, y, w: INTEGER; label: ARRAY OF CHAR);
BEGIN
  NEW(i); FlInputs.OpenInput(i, x, y, w, Row, label);
  i.SetWhen(Fl.WhenChanged); i.action := TextAction
END TextInput;

(* ---- Everything shown ---- *)

PROCEDURE ShowAll;
BEGIN
  showing := TRUE;
  SetInput(nameIn, entity.name); SetInput(taglineIn, entity.tagline); SetInput(sizeIn, entity.size);
  attrPanel.Show(entity); defectPanel.Show(entity); skillPanel.Show(entity);
  Besm2Background.Show(entity);
  ShowNumbers;
  ShowTitle;
  showing := FALSE
END ShowAll;

(* ---- Files ---- *)

(* The entity shown of es: the first that isn't a mecha, or the first. *)
PROCEDURE First(es: Ch.Entities): INTEGER;
  VAR i: LONGINT;
BEGIN
  FOR i := 0 TO LEN(es^) - 1 DO IF ~es[i].isMecha THEN RETURN SHORT(i) END END;
  RETURN 0
END First;

(* Shows the entities es, from file p (NIL: none). *)
PROCEDURE Take(es: Ch.Entities; p: Rope);
BEGIN
  entities := es; current := First(es); entity := es[current]; path := p; modified := FALSE;
  Ch.ComputeAll(entities);
  ShowAll
END Take;

(* Shows the entities es, just loaded by Besm2Character.LoadAll from
   the file at p, and says what the file gives that the rules compute
   differently, and so are kept as overrides, and the rest it found
   (Besm2Character.notices), each naming its entity, wrapped at
   NoticeWidth so the message fits on the screen. *)
PROCEDURE Adopt*(es: Ch.Entities; p: Rope);
  VAR r: Rope; n: Ch.Notice; lines: Besm2Text.List; sep: ARRAY 4 OF CHAR;
BEGIN
  Take(es, p);
  IF Ch.notices # NIL THEN
    r := Rp("Numbers the file gives differently from the rules,"); r := Ropes.AppendChar(r, 0AX);
    Besm2Text.Add(r, "kept as overrides, and what else it has:");
    sep[0] := 0AX; sep[1] := " "; sep[2] := " "; sep[3] := 0X;  (* a notice's next line, indented *)
    n := Ch.notices;
    WHILE n # NIL DO
      Besm2Layout.WordWrap(n.text, NoticeWidth, lines);
      r := Ropes.AppendChar(r, 0AX); r := Ropes.Cat(r, Besm2Text.Join(lines, sep));
      n := n.next
    END;
    tell(r)
  END
END Adopt;

(* Opens the entities in the file at p; FALSE, said why, if it can't. *)
PROCEDURE Load*(p: Rope): BOOLEAN;
  VAR es: Ch.Entities; msg: Rope; s: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(p);
  IF ~Ch.LoadAll(s^, es, msg) THEN tell(msg); RETURN FALSE END;
  Adopt(es, p);
  RETURN TRUE
END Load;

(* Saves every entity to p; FALSE, said why, if it can't. *)
PROCEDURE SaveTo(p: Rope): BOOLEAN;
  VAR msg: Rope; s: Besm2Text.String;
BEGIN
  s := Besm2Text.Chars(p);
  IF ~Besm2Save.SaveAll(entities, s^, msg) THEN tell(msg); RETURN FALSE END;
  path := p; modified := FALSE; ShowTitle;
  RETURN TRUE
END SaveTo;

PROCEDURE SaveAs(): BOOLEAN;
  VAR p: Rope;
BEGIN RETURN choosePath(TRUE, p) & SaveTo(p)
END SaveAs;

PROCEDURE Save(): BOOLEAN;
BEGIN
  IF path = NIL THEN RETURN SaveAs() ELSE RETURN SaveTo(path) END
END Save;

(* Whether the entities may be put away: saved, or the user doesn't
   want them saved.  The question names the file, or the character if
   it is the only one and has no file. *)
PROCEDURE MayLeave(): BOOLEAN;
  VAR q: Rope; ok: BOOLEAN;
BEGIN
  ok := ~modified;
  IF ~ok THEN
    q := Rp("Save the changes to ");
    IF path # NIL THEN q := Ropes.Cat(q, FileName())
    ELSIF LEN(entities^) > 1 THEN Besm2Text.Add(q, "the characters")
    ELSIF entity.name # NIL THEN q := Ropes.Cat(q, entity.name)
    ELSE Besm2Text.Add(q, "the character")
    END;
    Besm2Text.Add(q, " first?");
    CASE ask(q) OF
      SaveFirst: ok := Save()
    | Discard: ok := TRUE
    | Cancel: ok := FALSE
    END
  END;
  RETURN ok
END MayLeave;

PROCEDURE NewAction(w: Fl.Widget);
BEGIN IF MayLeave() THEN Take(Ch.One(Ch.New()), NIL) END
END NewAction;

PROCEDURE OpenAction(w: Fl.Widget);
  VAR p: Rope;
BEGIN
  IF MayLeave() & choosePath(FALSE, p) THEN IF Load(p) THEN END END
END OpenAction;

PROCEDURE SaveAction(w: Fl.Widget);
BEGIN IF Save() THEN END
END SaveAction;

PROCEDURE SaveAsAction(w: Fl.Widget);
BEGIN IF SaveAs() THEN END
END SaveAsAction;

(* File > Quit, and the window's close button: hide the window, which
   ends Fl.Run, once the changes are saved or let go. *)
PROCEDURE Quit*(w: Fl.Widget);
BEGIN IF MayLeave() THEN window.Hide END
END Quit;

(* ---- Building ---- *)

PROCEDURE Label(x, y, w: INTEGER; text: ARRAY OF CHAR);
  VAR b: Fl.Box;
BEGIN
  NEW(b); Fl.OpenBox(b, x, y, w, Row, text);
  b.SetAlign(Fl.AlignLeft + Fl.AlignInside); b.SetLabelFont(Fl.Bold)
END Label;

PROCEDURE Plain(x, y, w: INTEGER; text: ARRAY OF CHAR);
  VAR b: Fl.Box;
BEGIN
  NEW(b); Fl.OpenBox(b, x, y, w, Row, text);
  b.SetAlign(Fl.AlignLeft + Fl.AlignInside)
END Plain;

PROCEDURE Help(x, y, page: INTEGER);
  VAR h: Besm2Widgets.HelpButton;
BEGIN NEW(h); Besm2Widgets.OpenHelpButton(h, x, y, page)
END Help;

PROCEDURE Tab(VAR g: Fl.Group; name: ARRAY OF CHAR);
BEGIN
  NEW(g); Fl.OpenGroup(g, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight, name)
END Tab;

PROCEDURE StatRow(i, y: INTEGER; name: ARRAY OF CHAR);
  VAR label: ARRAY 64 OF CHAR; t: StatNumber; b: Besm2Widgets.NumberBox; s: FlValuators.Spinner;
BEGIN
  R.PageLabel(name, R.StatsPage, label);
  Plain(LeftX, y, 200, label);
  NEW(s); FlValuators.OpenSpinner(s, LeftX + 210, y, 60, Row, "");
  s.SetBounds(0, 99); s.SetStep(1); s.action := StatAction;
  s.SetTooltip("the Stat's value: 1 to 12 (p. 16, PDF 18)");
  statValue[i] := s;
  NEW(b); Besm2Widgets.OpenNumberBox(b, LeftX + 290, y, "");
  NEW(t); t.which := i; b.target := t; b.changed := NumberChanged;
  statPoints[i] := b;
  Help(LeftX + 290 + Besm2Widgets.Width + 10, y, R.StatsPage)
END StatRow;

PROCEDURE DerivedBox(slot, x, y: INTEGER; label: ARRAY OF CHAR);
  VAR t: DerivedNumber; b: Besm2Widgets.NumberBox;
BEGIN
  NEW(b); Besm2Widgets.OpenNumberBox(b, x, y, label);
  NEW(t); t.slot := slot; b.target := t; b.changed := NumberChanged;
  derived[slot] := b
END DerivedBox;

PROCEDURE BuildCharacterTab;
  VAR y, i: INTEGER; label: ARRAY 64 OF CHAR;
BEGIN
  Tab(characterTab, "Character");
  TextInput(nameIn, LeftX + 60, Top, 330, "Name");
  TextInput(sizeIn, LeftX + 440, Top, 180, "Size");
  TextInput(taglineIn, LeftX + 60, Top + 30, 560, "Tagline");

  y := Top + 70;
  Label(LeftX, y, 200, "Stats");
  Plain(LeftX + 210, y, 60, "Value"); Plain(LeftX + 290, y, Besm2Widgets.Width, "Points");
  y := y + Row + 5;
  StatRow(C.Body, y, "Body"); StatRow(C.Mind, y + 30, "Mind"); StatRow(C.Soul, y + 60, "Soul");

  y := y + 100;
  R.PageLabel("Derived values", R.DerivedValuesPage, label);
  Label(LeftX, y, 300, label); Help(LeftX + 310, y, R.DerivedValuesPage);
  y := y + Row + 25;
  DerivedBox(Ch.ACV, LeftX, y, "ACV"); DerivedBox(Ch.DCV, LeftX + 100, y, "DCV");
  DerivedBox(Ch.HP, LeftX + 200, y, "HP"); DerivedBox(Ch.EP, LeftX + 300, y, "EP");
  DerivedBox(Ch.SV, LeftX + 400, y, "SV"); DerivedBox(Ch.AR, LeftX + 500, y, "AR");

  y := y + Row + 15;
  R.PageLabel("Points", CharacterPointsPage, label);
  Label(LeftX, y, 300, label); Help(LeftX + 310, y, CharacterPointsPage);
  y := y + Row;
  FOR i := 0 TO NPointLines - 1 DO
    NEW(points[i]); Fl.OpenBox(points[i], LeftX, y, ColumnW, Row, "");
    points[i].SetAlign(Fl.AlignLeft + Fl.AlignInside);
    y := y + Row
  END;

  y := y + 30;
  NEW(warnings); FlBrowsers.OpenBrowser(warnings, LeftX, y, ColumnW, Height - y - 10, "Warnings");
  warnings.SetAlign(Fl.AlignTopLeft); warnings.SetFormatChar(0X);
  characterTab.End
END BuildCharacterTab;

(* The points and the warnings, from y down, on list tab t. *)
PROCEDURE BuildTotals(t, y: INTEGER);
  VAR i: INTEGER; b: FlBrowsers.Browser;
BEGIN
  FOR i := 0 TO NPointLines - 1 DO
    NEW(tabPoints[t][i]); Fl.OpenBox(tabPoints[t][i], LeftX, y, ColumnW, Row, "");
    tabPoints[t][i].SetAlign(Fl.AlignLeft + Fl.AlignInside);
    y := y + Row
  END;
  y := y + 25;
  NEW(b); FlBrowsers.OpenBrowser(b, LeftX, y, ColumnW, Height - y - 10, "Warnings");
  b.SetAlign(Fl.AlignTopLeft); b.SetFormatChar(0X);
  tabWarnings[t] := b
END BuildTotals;

(* What the list tabs need of the window. *)
PROCEDURE Compute;
BEGIN Ch.Relink(entities); Ch.ComputeAll(entities)
END Compute;

PROCEDURE PanelTell(text: Rope);
BEGIN tell(text)
END PanelTell;

PROCEDURE PanelChanged(p: Besm2ItemPanel.ItemPanel);
BEGIN Changed
END PanelChanged;

(* The Weapon Attack dialog's (step 8): after each change it makes, and
   after OK or Cancel (Cancel leaves modified as it was). *)
PROCEDURE WeaponChanged;
BEGIN Changed; attrPanel.Refresh(weaponLine)
END WeaponChanged;

PROCEDURE WeaponDone(ok: BOOLEAN);
BEGIN
  IF ~ok THEN modified := weaponModified; ShowTitle END;
  attrPanel.Refresh(weaponLine); weaponLine := 0
END WeaponDone;

PROCEDURE WeaponAction(w: Fl.Widget);
  VAR a: Ch.Attr;
BEGIN
  a := attrPanel.AttrAt(attrPanel.browser.Value());
  IF (a = NIL) OR ~a.weapon THEN tell(Rp("Choose a Weapon Attack first."))
  ELSE
    weaponLine := attrPanel.browser.Value(); weaponModified := modified;
    Besm2WeaponDialog.Edit(entity, a, WeaponDone)
  END
END WeaponAction;

PROCEDURE BuildLists;
  CONST ExtraBottom = 120;  (* a panel's rows under its browser, but for the extension's *)
  VAR h: INTEGER;
BEGIN
  Besm2ItemPanel.tell := PanelTell; Besm2ItemPanel.compute := Compute;
  Tab(attributesTab, "Attributes");
  (* Its details and options: 5 rows more than the others' 1. *)
  h := ListBottom - 10 - Top - ExtraBottom - 4 * (Row + 5);
  NEW(attrPanel); Besm2ItemPanel.OpenAttrPanel(attrPanel, LeftX, Top, ColumnW, h);
  attrPanel.changed := PanelChanged;
  NEW(weaponButton); FlButtons.OpenButton(weaponButton, LeftX + 225, attrPanel.bottom - Row, 90, Row, "Weapon...");
  weaponButton.action := WeaponAction;
  weaponButton.SetTooltip("the Weapon Attack selected: its Abilities, Disabilities and damage (p. 81, PDF 83)");
  BuildTotals(AttributesList, ListBottom);
  attributesTab.End;
  h := ListBottom - 10 - Top - ExtraBottom;
  Tab(defectsTab, "Defects");
  NEW(defectPanel); Besm2ItemPanel.OpenDefectPanel(defectPanel, LeftX, Top, ColumnW, h);
  defectPanel.changed := PanelChanged;
  BuildTotals(DefectsList, ListBottom);
  defectsTab.End;
  Tab(skillsTab, "Skills");
  NEW(skillPanel); Besm2ItemPanel.OpenSkillPanel(skillPanel, LeftX, Top, ColumnW, h);
  skillPanel.changed := PanelChanged;
  BuildTotals(SkillsList, ListBottom);
  skillsTab.End
END BuildLists;

PROCEDURE BackgroundChanged;
BEGIN modified := TRUE; ShowTitle
END BackgroundChanged;

(* Opens the window, not yet shown, with a new character. *)
PROCEDURE Build*;
  VAR main: MainWindow;
BEGIN
  NEW(main); window := main; Fl.OpenDoubleWindow(window, Width, Height, Title);
  NEW(bar); FlMenus.OpenMenuBar(bar, 0, 0, Width, BarHeight, "");
  newItem := bar.Add("&File/&New", ORD("n"), Fl.Command, NewAction, {});
  openItem := bar.Add("&File/&Open...", ORD("o"), Fl.Command, OpenAction, {});
  saveItem := bar.Add("&File/&Save", ORD("s"), Fl.Command, SaveAction, {});
  saveAsItem := bar.Add("&File/Save &As...", ORD("s"), Fl.Command + Fl.Shift, SaveAsAction, FlMenus.MenuDivider);
  quitItem := bar.Add("&File/&Quit", ORD("q"), Fl.Command, Quit, {});
  rulebookItem := bar.Add("&Rulebook/&Open", 0, {}, RulebookAction, FlMenus.MenuDivider);
  choosePdfItem := bar.Add("&Rulebook/&Choose PDF...", 0, {}, ChoosePdfAction, {});
  viewerItem := bar.Add("&Rulebook/&Viewer...", 0, {}, ViewerAction, {});
  NEW(tabs); FlLayout.OpenTabs(tabs, 0, BarHeight, Width, Height - BarHeight, "");
  BuildCharacterTab;
  (* Filled in by later steps of PLAN.md, Part B. *)
  BuildLists;
  Tab(mechaTab, "Mecha"); mechaTab.End;
  Tab(backgroundTab, "Background");
  Besm2Background.tell := PanelTell; Besm2Background.changed := BackgroundChanged;
  Besm2Background.Build(LeftX, Top, ColumnW, Height - Top - 10);
  backgroundTab.End;
  Tab(previewTab, "Preview"); previewTab.End;
  tabs.SetResizable(characterTab);
  tabs.End;
  window.SetResizable(tabs);
  window.SizeRange(Width, Height, 0, 0);
  window.End;
  window.action := Quit;
  Take(Ch.One(Ch.New()), NIL)
END Build;

(* Deletes the window and everything in it, for tests. *)
PROCEDURE Close*;
  VAR i, t: INTEGER;
BEGIN
  IF Besm2WeaponDialog.dialog # NIL THEN Besm2WeaponDialog.Cancel END;
  window.Delete;
  window := NIL; bar := NIL; tabs := NIL;
  characterTab := NIL; attributesTab := NIL; defectsTab := NIL; skillsTab := NIL; mechaTab := NIL;
  backgroundTab := NIL; previewTab := NIL;
  nameIn := NIL; taglineIn := NIL; sizeIn := NIL; warnings := NIL;
  FOR i := 0 TO C.NStats - 1 DO statValue[i] := NIL; statPoints[i] := NIL END;
  FOR i := Ch.ACV TO Ch.AR DO derived[i] := NIL END;
  FOR i := 0 TO NPointLines - 1 DO points[i] := NIL END;
  FOR t := 0 TO NLists - 1 DO
    tabWarnings[t] := NIL;
    FOR i := 0 TO NPointLines - 1 DO tabPoints[t][i] := NIL END
  END;
  Besm2ItemPanel.Close(attrPanel); Besm2ItemPanel.Close(defectPanel); Besm2ItemPanel.Close(skillPanel);
  attrPanel := NIL; defectPanel := NIL; skillPanel := NIL; weaponButton := NIL;
  Besm2Background.Close
END Close;

BEGIN
  tell := DialogTell; ask := DialogAsk; choosePath := DialogPath; choosePdf := DialogPdf; askText := DialogText;
  Besm2Widgets.openPage := OpenPage;
  Besm2WeaponDialog.tell := PanelTell; Besm2WeaponDialog.changed := WeaponChanged; weaponLine := 0;
  rulebookOption := NIL; savedRulebook := NIL; preferences := NIL;
  Besm2Viewer.Default(viewer); viewerOption := FALSE;
  entities := NIL; current := 0; entity := NIL; path := NIL; modified := FALSE; showing := FALSE
END Besm2Window.
