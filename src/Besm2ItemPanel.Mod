MODULE Besm2ItemPanel; (* The Attributes, Defects and Skills tabs' lists and their editors *)

(* PLAN.md, Part B, step 7, after ova_cg_po's OvaTraitPanel.  Each tab
   is a Besm2Widgets.Panel: a browser of the entity's items, one a line
   ("2 Own a Big Mecha: Walker", a tab, "8 pts", a tab, "p. 59, PDF
   61"), and under it the Choice of names, each with both its pages, the
   Spinner for the Level (a Defect's rank), the text field for the
   subject (a Skill's specialisations), and the ? button, which opens
   the rulebook at the chosen name's page.

   - AttrPanel offers the Attributes, then, after a divider, the Mecha
     Attributes; under the subject, the details, and the chosen
     Attribute's options (its choices that change its cost, p. 16), each
     a line: "(x)" one of a required choice, the first by default, "[x]"
     one that is taken or not, "N x" one taken N times; + and - take it
     once more, or once less.
   - DefectPanel offers the Defects, then the Mecha Defects; under the
     subject, the details.
   - SkillPanel offers the Skills, then the entity's house Skills
     (`creation: house-skills`, A4), "(house rule)", which have no page;
     its text field is the specialisations, separated by commas; under
     it the genre, whose Table 2-4 (p. 119) prices them.

   Each edit goes to the model (Besm2Character's NewAttr, ChangeAttr,
   ...), then compute, the window's, computes every entity again; then
   the browser is filled again and changed, the window's, shows the
   numbers.  Nothing here holds the only copy of anything but what the
   user is still choosing (an AttrPanel's options, until Add or
   Change). *)

IMPORT Fl, FlBrowsers, FlButtons, FlInputs, FlMenus, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules,
  Besm2Text, Besm2Widgets, Ropes, Strings;

CONST
  Row = 25; Gap = 5; LabelW = 50;
  MaxLevel = 99;
  (* The browser's columns: the points', and the page's. *)
  PointsW = 60; PageW = 125;
  OptionRows = 4;   (* an AttrPanel's options browser, in rows *)
  HouseLabel = " (house rule)";

TYPE
  Rope = Ropes.Rope;

  (* What every list has: the entity whose items it lists, and what to
     call after a change. *)
  ItemPanel* = POINTER TO ItemPanelDesc;
  ItemPanelDesc* = RECORD (Besm2Widgets.PanelDesc)
    entity-: Ch.Entity;
    changed*: PROCEDURE (p: ItemPanel)
  END;

  Attrs = POINTER TO ARRAY OF Ch.Attr;
  OptionButton = POINTER TO OptionButtonDesc;

  AttrPanel* = POINTER TO AttrPanelDesc;
  AttrPanelDesc* = RECORD (ItemPanelDesc)
    shown: Attrs;  (* shown[i]: line i + 1's *)
    n: INTEGER;
    details-: FlInputs.Input;
    options-: FlBrowsers.HoldBrowser;
    plus-, minus-: OptionButton;
    (* The options being chosen: of optItem, the item chosen, taken
       times[i] times; loaded, the Attribute loaded last (NIL: none). *)
    optItem: R.Item;
    times-: ARRAY R.MaxOptions OF INTEGER;
    loaded: Ch.Attr
  END;

  OptionButtonDesc = RECORD (FlButtons.ButtonDesc)
    panel: AttrPanel;
    step: INTEGER   (* +1, -1 *)
  END;

  Defects = POINTER TO ARRAY OF Ch.Defect;

  DefectPanel* = POINTER TO DefectPanelDesc;
  DefectPanelDesc* = RECORD (ItemPanelDesc)
    shown: Defects;
    n: INTEGER;
    details-: FlInputs.Input
  END;

  Skills = POINTER TO ARRAY OF Ch.Skill;

  GenreChoice = POINTER TO GenreChoiceDesc;

  SkillPanel* = POINTER TO SkillPanelDesc;
  SkillPanelDesc* = RECORD (ItemPanelDesc)
    shown: Skills;
    n: INTEGER;
    genre-: GenreChoice;
    genreHelp-: Besm2Widgets.HelpButton
  END;

  GenreChoiceDesc = RECORD (FlMenus.ChoiceDesc)
    panel: SkillPanel
  END;

VAR
  (* Shows a message: the window's. *)
  tell*: PROCEDURE (text: Rope);
  (* Computes every entity again, after a change: the window's. *)
  compute*: PROCEDURE;

(* ---- Text ---- *)

(* What input i holds, trimmed; NIL if blank. *)
PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: Fl.String;
BEGIN s := i.Text(); RETURN Besm2Text.Trim(Ropes.FromString(s^))
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); i.SetValue(s^)
END SetInput;

(* " " and name, ": " and subject if has, " (" details ")" if any. *)
PROCEDURE AddName(VAR line: Rope; name, subject: Rope; hasSubject: BOOLEAN; details: Rope);
BEGIN
  Besm2Text.Add(line, " ");
  IF Besm2Text.Trim(name) = NIL THEN Besm2Text.Add(line, '""') ELSE line := Ropes.Cat(line, Besm2Text.Trim(name)) END;
  IF hasSubject THEN Besm2Text.Add(line, ": "); line := Ropes.Cat(line, subject) END;
  IF details # NIL THEN Besm2Text.Add(line, " ("); line := Ropes.Cat(line, details); Besm2Text.Add(line, ")") END
END AddName;

(* A tab, points and unit, a tab, and it's pages ("" for none). *)
PROCEDURE AddColumns(VAR line: Rope; points: INTEGER; unit: ARRAY OF CHAR; it: R.Item);
  VAR page: ARRAY 32 OF CHAR;
BEGIN
  line := Ropes.AppendChar(line, 9X);
  Besm2Text.AddInt(line, points); Besm2Text.Add(line, " "); Besm2Text.Add(line, unit);
  line := Ropes.AppendChar(line, 9X);
  IF it # NIL THEN R.PageText(it, page); Besm2Text.Add(line, page) END
END AddColumns;

PROCEDURE AddLine(b: FlBrowsers.HoldBrowser; line: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(line); b.Add(s^)
END AddLine;

(* ---- What every list does ---- *)

PROCEDURE (p: ItemPanel) Level(): INTEGER;
BEGIN RETURN p.spinner.IntValue()
END Level;

PROCEDURE (p: ItemPanel) Changed*;
BEGIN IF p.changed # NIL THEN p.changed(p) END
END Changed;

PROCEDURE Compute;
BEGIN IF compute # NIL THEN compute END
END Compute;

PROCEDURE NoName(): INTEGER;
BEGIN tell(Ropes.FromString("Choose a name first.")); RETURN 0
END NoName;

(* The controls emptied, nothing chosen. *)
PROCEDURE (p: ItemPanel) Blank*;
BEGIN p.ChooseIndex(-1); p.spinner.SetValue(1); p.text.SetValue("")
END Blank;

PROCEDURE OpenItemPanel(p: ItemPanel; x, y, w, h, kind, second, extraRows: INTEGER;
                        title, spinLabel, textLabel: ARRAY OF CHAR);
  VAR widths: ARRAY 3 OF INTEGER;
BEGIN
  p.entity := NIL; p.changed := NIL;
  Besm2Widgets.OpenPanel(p, x, y, w, h, kind, second, extraRows, title, spinLabel, textLabel);
  p.spinner.SetBounds(1, MaxLevel); p.spinner.SetValue(1);
  (* The name takes what the points and the page leave, as the browser is resized. *)
  widths[0] := -1; widths[1] := PointsW; widths[2] := PageW;
  p.browser.SetColumnWidths(widths, 3)
END OpenItemPanel;

(* ---- Attributes ---- *)

(* The Attribute on line line (from 1); NIL for none. *)
PROCEDURE (p: AttrPanel) AttrAt*(line: INTEGER): Ch.Attr;
BEGIN IF (line >= 1) & (line <= p.n) THEN RETURN p.shown[line - 1] ELSE RETURN NIL END
END AttrAt;

PROCEDURE (p: AttrPanel) Fill*;
  VAR a: C.Attr; x: Ch.Attr; line: Rope;
BEGIN
  p.n := 0;
  IF p.entity = NIL THEN RETURN END;
  a := p.entity.attrs; WHILE a # NIL DO INC(p.n); a := a.next END;
  NEW(p.shown, p.n + 1);
  p.n := 0; a := p.entity.attrs;
  WHILE a # NIL DO
    x := a(Ch.Attr); p.shown[p.n] := x; INC(p.n);
    IF x.levelIsText THEN line := x.levelText ELSE line := Besm2Text.Int(x.level) END;
    AddName(line, x.name, x.subject, x.hasSubject, x.details);
    AddColumns(line, C.Value(x.points), "pts", x.item);
    AddLine(p.browser, line);
    a := a.next
  END
END Fill;

PROCEDURE (p: AttrPanel) LineOf(a: C.Attr): INTEGER;
  VAR i: INTEGER; l: C.Attr;
BEGIN
  i := 1; l := p.entity.attrs;
  WHILE (l # NIL) & (l # a) DO INC(i); l := l.next END;
  RETURN i
END LineOf;

(* Whether option i of it counts: taken, or the first of a required
   choice none of whose options is taken. *)
PROCEDURE Counts(it: R.Item; VAR times: ARRAY OF INTEGER; i: INTEGER): BOOLEAN;
  VAR j, g: INTEGER; first: BOOLEAN;
BEGIN
  IF times[i] > 0 THEN RETURN TRUE END;
  g := it.option[i].group;
  IF g <= 0 THEN RETURN FALSE END;
  first := TRUE;
  FOR j := 0 TO it.nOptions - 1 DO
    IF it.option[j].group = g THEN
      IF times[j] > 0 THEN RETURN FALSE END;
      IF j < i THEN first := FALSE END
    END
  END;
  RETURN first
END Counts;

(* The options' lines again, line line selected (0: none). *)
PROCEDURE (p: AttrPanel) ShowOptions(line: INTEGER);
  VAR i: INTEGER; it: R.Item; r: Rope; o: R.Option;
BEGIN
  p.options.Clear; it := p.optItem;
  IF (it = NIL) OR (it.nOptions = 0) THEN
    p.options.Deactivate; p.plus.Deactivate; p.minus.Deactivate;
    RETURN
  END;
  p.options.Activate; p.plus.Activate; p.minus.Activate;
  FOR i := 0 TO it.nOptions - 1 DO
    o := it.option[i];
    IF o.group > 0 THEN
      IF Counts(it, p.times, i) THEN r := Ropes.FromString("(x) ") ELSE r := Ropes.FromString("( ) ") END
    ELSIF o.maxTimes = 1 THEN
      IF p.times[i] > 0 THEN r := Ropes.FromString("[x] ") ELSE r := Ropes.FromString("[ ] ") END
    ELSE r := Besm2Text.Int(p.times[i]); Besm2Text.Add(r, " x ")
    END;
    Besm2Text.Add(r, o.label);
    r := Ropes.AppendChar(r, 9X);
    IF o.amount >= 0 THEN Besm2Text.Add(r, "+") END;
    Besm2Text.AddInt(r, o.amount);
    IF o.perLevel THEN Besm2Text.Add(r, " a Level") END;
    AddLine(p.options, r)
  END;
  IF (line > 0) & (line <= p.options.Count()) THEN p.options.SetSelected(line, TRUE) END
END ShowOptions;

(* After the Choice changes: the options of the name chosen, none
   taken, unless it is the loaded Attribute's, whose are shown. *)
PROCEDURE (p: AttrPanel) Chosen*;
  VAR it: R.Item; i: INTEGER;
BEGIN
  p.Chosen^;
  it := p.Item();
  IF it # p.optItem THEN
    FOR i := 0 TO R.MaxOptions - 1 DO p.times[i] := 0 END;
    IF (p.loaded # NIL) & (p.loaded.item = it) THEN
      FOR i := 0 TO R.MaxOptions - 1 DO p.times[i] := p.loaded.times[i] END
    END;
    p.optItem := it
  END;
  p.ShowOptions(0)
END Chosen;

(* Option line line (from 1) taken once more (step 1) or once less
   (-1): of a choice, the one taken, the others not. *)
PROCEDURE (p: AttrPanel) Step*(line, step: INTEGER);
  VAR i, j: INTEGER; o: R.Option; it: R.Item;
BEGIN
  it := p.optItem;
  IF (it = NIL) OR (line < 1) OR (line > it.nOptions) THEN RETURN END;
  i := line - 1; o := it.option[i];
  IF o.group # 0 THEN
    IF step > 0 THEN
      FOR j := 0 TO it.nOptions - 1 DO IF it.option[j].group = o.group THEN p.times[j] := 0 END END;
      p.times[i] := 1
    ELSE p.times[i] := 0
    END
  ELSIF step > 0 THEN IF p.times[i] < o.maxTimes THEN INC(p.times[i]) END
  ELSIF p.times[i] > 0 THEN DEC(p.times[i])
  END;
  p.ShowOptions(line)
END Step;

PROCEDURE (b: OptionButton) Callback*;
BEGIN
  IF b.panel.options.Value() > 0 THEN b.panel.Step(b.panel.options.Value(), b.step)
  ELSE tell(Ropes.FromString("Choose an option first."))
  END
END Callback;

PROCEDURE (p: AttrPanel) Load*(line: INTEGER);
  VAR a: Ch.Attr; i: INTEGER;
BEGIN
  a := p.shown[line - 1];
  p.loaded := a; p.optItem := a.item;
  FOR i := 0 TO R.MaxOptions - 1 DO p.times[i] := a.times[i] END;
  p.Choose(a.item);
  p.spinner.SetValue(a.level);
  SetInput(p.text, a.subject); SetInput(p.details, a.details)
END Load;

PROCEDURE (p: AttrPanel) Blank*;
BEGIN p.loaded := NIL; p.Blank^; p.details.SetValue("")
END Blank;

PROCEDURE (p: AttrPanel) TakeOptions(a: Ch.Attr);
  VAR i: INTEGER;
BEGIN
  IF (a.item # NIL) & (a.item = p.optItem) THEN
    FOR i := 0 TO R.MaxOptions - 1 DO a.times[i] := p.times[i] END
  END
END TakeOptions;

PROCEDURE (p: AttrPanel) Add*(): INTEGER;
  VAR it: R.Item; a: Ch.Attr;
BEGIN
  it := p.Item();
  IF it = NIL THEN RETURN NoName() END;
  a := Ch.NewAttr(it, p.Level(), InputText(p.text), InputText(p.details));
  p.TakeOptions(a);
  Ch.InsertAttr(p.entity, a);
  Compute;
  RETURN p.LineOf(a)
END Add;

(* A name the rules don't have stays, if none is chosen. *)
PROCEDURE (p: AttrPanel) Change*(line: INTEGER): INTEGER;
  VAR it: R.Item; a: Ch.Attr;
BEGIN
  a := p.shown[line - 1];
  it := p.Item(); IF it = NIL THEN it := a.item END;
  Ch.ChangeAttr(p.entity, a, it, p.Level(), InputText(p.text), InputText(p.details));
  p.TakeOptions(a);
  Compute;
  RETURN p.LineOf(a)
END Change;

PROCEDURE (p: AttrPanel) Remove*(line: INTEGER): BOOLEAN;
BEGIN
  Ch.RemoveAttr(p.entity, p.shown[line - 1]);
  Compute;
  p.Blank;
  RETURN TRUE
END Remove;

(* Lists e's Attributes; nothing selected. *)
(* Shows e's Attributes; a mecha is offered the Mecha Attributes
   first (step 9). *)
PROCEDURE (p: AttrPanel) Show*(e: Ch.Entity);
BEGIN
  IF e.isMecha THEN p.Offer(R.MechaAttribute, R.Attribute) ELSE p.Offer(R.Attribute, R.MechaAttribute) END;
  p.entity := e; p.Refresh(0); p.Blank
END Show;

PROCEDURE OptionButtonAt(p: AttrPanel; x, y, step: INTEGER; label: ARRAY OF CHAR): OptionButton;
  VAR b: OptionButton;
BEGIN
  NEW(b); FlButtons.OpenButton(b, x, y, 30, Row, label); b.panel := p; b.step := step;
  RETURN b
END OptionButtonAt;

(* Opens p at x, y, w wide, its browser h high. *)
PROCEDURE OpenAttrPanel*(p: AttrPanel; x, y, w, h: INTEGER);
  VAR yy: INTEGER; widths: ARRAY 2 OF INTEGER;
BEGIN
  p.n := 0; NEW(p.shown, 1); p.optItem := NIL; p.loaded := NIL;
  NEW(p.details); NEW(p.options);  (* before the Choice is filled, which calls Chosen *)
  OpenItemPanel(p, x, y, w, h, R.Attribute, R.MechaAttribute, 1 + OptionRows, "Attributes", "Level", "subject");
  yy := p.extraY;
  FlInputs.OpenInput(p.details, x + LabelW, yy, w - LabelW, Row, "details");
  yy := yy + Row + Gap;
  FlBrowsers.OpenHoldBrowser(p.options, x + LabelW + 20, yy, w - LabelW - 20 - 75, OptionRows * (Row + Gap) - Gap,
    "options");
  p.options.SetAlign(Fl.AlignLeftTop); p.options.SetFormatChar(0X);
  widths[0] := -1; widths[1] := 80; p.options.SetColumnWidths(widths, 2);
  p.plus := OptionButtonAt(p, x + w - 70, yy, 1, "+");
  p.minus := OptionButtonAt(p, x + w - 35, yy, -1, "-");
  p.plus.SetTooltip("take the option chosen once more"); p.minus.SetTooltip("take it once less");
  p.ShowOptions(0)
END OpenAttrPanel;

(* ---- Defects ---- *)

PROCEDURE (p: DefectPanel) DefectAt*(line: INTEGER): Ch.Defect;
BEGIN IF (line >= 1) & (line <= p.n) THEN RETURN p.shown[line - 1] ELSE RETURN NIL END
END DefectAt;

PROCEDURE (p: DefectPanel) Fill*;
  VAR d: C.Defect; x: Ch.Defect; line: Rope;
BEGIN
  p.n := 0;
  IF p.entity = NIL THEN RETURN END;
  d := p.entity.defects; WHILE d # NIL DO INC(p.n); d := d.next END;
  NEW(p.shown, p.n + 1);
  p.n := 0; d := p.entity.defects;
  WHILE d # NIL DO
    x := d(Ch.Defect); p.shown[p.n] := x; INC(p.n);
    line := Besm2Text.Int(x.rank);
    AddName(line, x.name, x.subject, x.hasSubject, x.details);
    AddColumns(line, -C.Value(x.points), "BP", x.item);
    AddLine(p.browser, line);
    d := d.next
  END
END Fill;

PROCEDURE (p: DefectPanel) LineOf(d: C.Defect): INTEGER;
  VAR i: INTEGER; l: C.Defect;
BEGIN
  i := 1; l := p.entity.defects;
  WHILE (l # NIL) & (l # d) DO INC(i); l := l.next END;
  RETURN i
END LineOf;

PROCEDURE (p: DefectPanel) Load*(line: INTEGER);
  VAR d: Ch.Defect;
BEGIN
  d := p.shown[line - 1];
  p.Choose(d.item);
  p.spinner.SetValue(d.rank);
  SetInput(p.text, d.subject); SetInput(p.details, d.details)
END Load;

PROCEDURE (p: DefectPanel) Blank*;
BEGIN p.Blank^; p.details.SetValue("")
END Blank;

PROCEDURE (p: DefectPanel) Add*(): INTEGER;
  VAR it: R.Item; d: Ch.Defect;
BEGIN
  it := p.Item();
  IF it = NIL THEN RETURN NoName() END;
  d := Ch.NewDefect(it, p.Level(), InputText(p.text), InputText(p.details));
  Ch.InsertDefect(p.entity, d);
  Compute;
  RETURN p.LineOf(d)
END Add;

PROCEDURE (p: DefectPanel) Change*(line: INTEGER): INTEGER;
  VAR it: R.Item; d: Ch.Defect;
BEGIN
  d := p.shown[line - 1];
  it := p.Item(); IF it = NIL THEN it := d.item END;
  Ch.ChangeDefect(p.entity, d, it, p.Level(), InputText(p.text), InputText(p.details));
  Compute;
  RETURN p.LineOf(d)
END Change;

PROCEDURE (p: DefectPanel) Remove*(line: INTEGER): BOOLEAN;
BEGIN
  Ch.RemoveDefect(p.entity, p.shown[line - 1]);
  Compute;
  p.Blank;
  RETURN TRUE
END Remove;

(* Shows e's Defects; a mecha is offered the Mecha Defects first. *)
PROCEDURE (p: DefectPanel) Show*(e: Ch.Entity);
BEGIN
  IF e.isMecha THEN p.Offer(R.MechaDefect, R.Defect) ELSE p.Offer(R.Defect, R.MechaDefect) END;
  p.entity := e; p.Refresh(0); p.Blank
END Show;

PROCEDURE OpenDefectPanel*(p: DefectPanel; x, y, w, h: INTEGER);
BEGIN
  p.n := 0; NEW(p.shown, 1);
  OpenItemPanel(p, x, y, w, h, R.Defect, R.MechaDefect, 1, "Defects", "rank", "subject");
  NEW(p.details); FlInputs.OpenInput(p.details, x + LabelW, p.extraY, w - LabelW, Row, "details")
END OpenDefectPanel;

(* ---- Skills ---- *)

PROCEDURE (p: SkillPanel) SkillAt*(line: INTEGER): Ch.Skill;
BEGIN IF (line >= 1) & (line <= p.n) THEN RETURN p.shown[line - 1] ELSE RETURN NIL END
END SkillAt;

(* The entity's house Skills, in order. *)
PROCEDURE (p: SkillPanel) More*(): INTEGER;
  VAR h: C.HouseSkill; n: INTEGER;
BEGIN
  n := 0;
  IF p.entity # NIL THEN h := p.entity.creation.houseSkills; WHILE h # NIL DO INC(n); h := h.next END END;
  RETURN n
END More;

PROCEDURE (p: SkillPanel) FillMore*;
  VAR h: C.HouseSkill; r: Rope; s: Besm2Text.String;
BEGIN
  IF p.entity = NIL THEN RETURN END;
  h := p.entity.creation.houseSkills;
  WHILE h # NIL DO
    r := Besm2Text.Trim(h(Ch.HouseSkill).name); Besm2Text.Add(r, HouseLabel);
    s := Besm2Text.Chars(r);
    p.choice.AppendText(s^);
    h := h.next
  END
END FillMore;

(* The house Skill chosen; NIL for none, or a rulebook Skill. *)
PROCEDURE (p: SkillPanel) House*(): C.HouseSkill;
  VAR i: INTEGER; h: C.HouseSkill;
BEGIN
  i := p.choice.Value() - p.Offered();
  IF (i < 0) OR (p.entity = NIL) THEN RETURN NIL END;
  h := p.entity.creation.houseSkills;
  WHILE (h # NIL) & (i > 0) DO h := h.next; DEC(i) END;
  RETURN h
END House;

PROCEDURE (p: SkillPanel) ChooseHouse(h: C.HouseSkill);
  VAR i: INTEGER; l: C.HouseSkill;
BEGIN
  i := 0; l := p.entity.creation.houseSkills;
  WHILE (l # NIL) & (l # h) DO INC(i); l := l.next END;
  IF l # NIL THEN p.ChooseIndex(p.Offered() + i) ELSE p.ChooseIndex(-1) END
END ChooseHouse;

PROCEDURE (p: SkillPanel) Fill*;
  VAR s: C.Skill; x: Ch.Skill; line: Rope;
BEGIN
  p.n := 0;
  IF p.entity = NIL THEN RETURN END;
  s := p.entity.skills; WHILE s # NIL DO INC(p.n); s := s.next END;
  NEW(p.shown, p.n + 1);
  p.n := 0; s := p.entity.skills;
  WHILE s # NIL DO
    x := s(Ch.Skill); p.shown[p.n] := x; INC(p.n);
    IF x.levelIsText THEN line := x.levelText ELSE line := Besm2Text.Int(x.level) END;
    AddName(line, x.name, NIL, FALSE, Besm2Text.Join(x.specialisations, ", "));
    IF x.house # NIL THEN
      AddColumns(line, C.Value(x.points), "SP", NIL); Besm2Text.Add(line, "house rule")
    ELSE AddColumns(line, C.Value(x.points), "SP", x.item)
    END;
    AddLine(p.browser, line);
    s := s.next
  END
END Fill;

PROCEDURE (p: SkillPanel) LineOf(s: C.Skill): INTEGER;
  VAR i: INTEGER; l: C.Skill;
BEGIN
  i := 1; l := p.entity.skills;
  WHILE (l # NIL) & (l # s) DO INC(i); l := l.next END;
  RETURN i
END LineOf;

PROCEDURE (p: SkillPanel) Load*(line: INTEGER);
  VAR s: Ch.Skill;
BEGIN
  s := p.shown[line - 1];
  IF s.house # NIL THEN p.ChooseHouse(s.house) ELSE p.Choose(s.item) END;
  p.spinner.SetValue(s.level);
  SetInput(p.text, Besm2Text.Join(s.specialisations, ", "))
END Load;

(* The specialisations typed, separated by commas. *)
PROCEDURE (p: SkillPanel) Specs(VAR l: Besm2Text.List);
  VAR pieces: Ropes.Pieces; i: LONGINT; r: Rope;
BEGIN
  Besm2Text.Clear(l);
  r := InputText(p.text);
  IF r = NIL THEN RETURN END;
  pieces := Ropes.SplitArray(r, ",");
  FOR i := 0 TO LEN(pieces^) - 1 DO Besm2Text.Append(l, pieces[i]) END
END Specs;

PROCEDURE (p: SkillPanel) Add*(): INTEGER;
  VAR it: R.Item; h: C.HouseSkill; s: Ch.Skill; specs: Besm2Text.List;
BEGIN
  it := p.Item(); h := p.House();
  IF (it = NIL) & (h = NIL) THEN RETURN NoName() END;
  p.Specs(specs);
  s := Ch.NewSkill(it, h, p.Level(), specs);
  Ch.InsertSkill(p.entity, s);
  Compute;
  RETURN p.LineOf(s)
END Add;

PROCEDURE (p: SkillPanel) Change*(line: INTEGER): INTEGER;
  VAR it: R.Item; h: C.HouseSkill; s: Ch.Skill; specs: Besm2Text.List;
BEGIN
  s := p.shown[line - 1];
  it := p.Item(); h := p.House();
  IF (it = NIL) & (h = NIL) THEN it := s.item; h := s.house END;
  p.Specs(specs);
  Ch.ChangeSkill(p.entity, s, it, h, p.Level(), specs);
  Compute;
  RETURN p.LineOf(s)
END Change;

PROCEDURE (p: SkillPanel) Remove*(line: INTEGER): BOOLEAN;
BEGIN
  Ch.RemoveSkill(p.entity, p.shown[line - 1]);
  Compute;
  p.Blank;
  RETURN TRUE
END Remove;

(* The genre shown: Choice entry 0 is none, then Besm2Rules' genres. *)
PROCEDURE (p: SkillPanel) ShowGenre;
BEGIN p.genre.Choose(p.entity.creation.genre + 1)
END ShowGenre;

PROCEDURE (c: GenreChoice) Callback*;
  VAR p: SkillPanel;
BEGIN
  p := c.panel;
  IF p.entity = NIL THEN RETURN END;
  Ch.SetGenre(p.entity, c.Value() - 1);
  Compute;
  p.Refresh(p.browser.Value());
  p.Changed
END Callback;

(* Lists e's Skills, offering its house Skills; nothing selected. *)
PROCEDURE (p: SkillPanel) Show*(e: Ch.Entity);
BEGIN p.entity := e; p.Refill; p.ShowGenre; p.Refresh(0); p.Blank
END Show;

PROCEDURE OpenSkillPanel*(p: SkillPanel; x, y, w, h: INTEGER);
  VAR g: INTEGER; name: ARRAY 64 OF CHAR; label: ARRAY 80 OF CHAR;
BEGIN
  p.n := 0; NEW(p.shown, 1);
  OpenItemPanel(p, x, y, w, h, R.Skill, -1, 1, "Skills", "Level", "specialisations");
  NEW(p.genre); FlMenus.OpenChoice(p.genre, x + LabelW, p.extraY, 250, Row, "genre");
  p.genre.panel := p;
  p.genre.AppendText("(none)");
  FOR g := 0 TO R.NGenres - 1 DO
    R.GenreName(g, name);
    p.genre.AppendText(name)
  END;
  p.genre.Choose(0);
  R.PageLabel("Table 2-4", R.SkillCostsPage, label); Strings.Append(": the Skills' costs by genre", label);
  NEW(p.genreHelp); Besm2Widgets.OpenHelpButton(p.genreHelp, x + LabelW + 255, p.extraY, R.SkillCostsPage);
  p.genreHelp.SetTooltip(label)
END OpenSkillPanel;

(* Forgets p, whose widgets were deleted (with their window). *)
PROCEDURE Close*(p: ItemPanel);
BEGIN Besm2Widgets.ClosePanel(p); p.entity := NIL
END Close;

BEGIN
  tell := NIL; compute := NIL
END Besm2ItemPanel.
