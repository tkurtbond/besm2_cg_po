MODULE Besm2Widgets; (* What the window shares with its dialogs: the number boxes, the ? buttons, the lists *)

(* PLAN.md, Part B, steps 6 and 7: OvaWidgets's NumberBox, HelpButton
   and Panel, copied from ova_cg_po.

   Beside every number the program computes is an empty entry box (A3,
   `overrides`).  A NumberBox is both: the computed number, shown
   read-only, and the box, whose text is the override in effect ("" for
   none).  Where its number lives is its Target, which the window
   extends for each kind of number (a Stat's points, the ACV, ...), so
   the box reads and sets the model, never a copy.

   A HelpButton, "?", opens the rulebook at a printed page, through
   openPage, which the window sets (it adds the 2 to the PDF's page).

   A Panel is a list and its editor, the shape A5 gives the Attributes,
   Defects and Skills tabs and step 8's Weapon Abilities and
   Disabilities: a browser of lines, under it a Choice of every name of
   one kind (Besm2Rules.Label: "Highly Skilled (p. 42, PDF 44)"), and,
   after a divider, those of a second kind (the Mecha Attributes after
   the Attributes) and any its extension adds (a character's house
   Skills), a Spinner, a text field, rows the extension fills, and Add,
   Change, Remove and ? buttons.  What the lines are, and what the
   buttons do to the model, are its extension's (its methods).  Changed
   from OvaWidgets: the second kind, in place of the Boss Abilities;
   the extension's own names (More, FillMore); and the extension's rows
   (extraRows, extraY). *)

IMPORT Fl, FlBrowsers, FlButtons, FlInputs, FlMenus, FlValuators, Besm2Calc, Besm2Rules;

CONST
  (* A NumberBox's size: the computed number, then the box. *)
  ShownWidth = 40; EntryWidth = 45; Gap = 2;
  Width* = ShownWidth + Gap + EntryWidth;
  Height* = 25;
  Tooltip = "empty: use the computed value";

TYPE
  (* Where a NumberBox's number lives. *)
  Target* = POINTER TO TargetDesc;
  TargetDesc* = RECORD END;

  NumberBox* = POINTER TO NumberBoxDesc;

  Entry = POINTER TO EntryDesc;
  EntryDesc = RECORD (FlInputs.InputDesc)
    box: NumberBox
  END;

  NumberBoxDesc* = RECORD (Fl.GroupDesc)
    shown-: FlInputs.Output;  (* the computed number *)
    entry-: FlInputs.Input;   (* the override: "" for none *)
    target*: Target;
    (* After the user leaves the box: the override set from its text,
       or (ok FALSE) the text refused, and the box emptied. *)
    changed*: PROCEDURE (b: NumberBox; ok: BOOLEAN)
  END;

  HelpButton* = POINTER TO HelpButtonDesc;
  HelpButtonDesc* = RECORD (FlButtons.ButtonDesc)
    page*: INTEGER  (* the printed page; 0: nothing to show *)
  END;

  Panel* = POINTER TO PanelDesc;
  PanelDesc* = RECORD
    kind-, second-: INTEGER;  (* the Choice's: Besm2Rules kinds; second -1: none *)
    browser-: FlBrowsers.HoldBrowser;
    choice-: FlMenus.Choice;
    spinner-: FlValuators.Spinner;
    text-: FlInputs.Input;
    add-, change-, remove-: FlButtons.Button;
    help-: HelpButton;
    extraY-: INTEGER;  (* the y of the extension's first row *)
    bottom-: INTEGER;  (* the y under the panel's last row *)
    next: Panel        (* the open panels *)
  END;

VAR
  panels: Panel;  (* every panel opened: the callbacks' way back to it *)

  (* What a HelpButton does with its page: the window's, which opens
     the rulebook there. *)
  openPage*: PROCEDURE (page: INTEGER);

(* ---- Targets ---- *)

(* The number, in n. *)
PROCEDURE (t: Target) Get*(VAR n: Besm2Calc.Number);
BEGIN HALT(99)
END Get;

(* Sets the number to n. *)
PROCEDURE (t: Target) Put*(VAR n: Besm2Calc.Number);
BEGIN HALT(99)
END Put;

(* ---- NumberBox ---- *)

(* Shows the target's number: computed, and its override. *)
PROCEDURE (b: NumberBox) Display*;
  VAR n: Besm2Calc.Number; s: ARRAY 32 OF CHAR;
BEGIN
  IF b.target # NIL THEN
    b.target.Get(n);
    Besm2Calc.ComputedText(n, s); b.shown.SetValue(s);
    IF n.overridden THEN Besm2Calc.Text(n, s) ELSE s := "" END;
    b.entry.SetValue(s)
  ELSE
    b.shown.SetValue(""); b.entry.SetValue("")
  END
END Display;

(* The box's text read into its target's override (an empty box clears
   it); text that isn't a number for it is refused, and the override
   cleared. *)
PROCEDURE (b: NumberBox) Take*;
  VAR n: Besm2Calc.Number; s: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  IF b.target = NIL THEN RETURN END;
  b.target.Get(n);
  b.entry.Value(s);
  ok := Besm2Calc.Parse(s, n);
  IF ~ok THEN Besm2Calc.Clear(n) END;
  b.target.Put(n);
  b.Display;
  IF b.changed # NIL THEN b.changed(b, ok) END
END Take;

PROCEDURE (e: Entry) Callback*;
BEGIN e.box.Take
END Callback;

(* Opens a NumberBox at x, y, Width by Height, labelled above. *)
PROCEDURE OpenNumberBox*(b: NumberBox; x, y: INTEGER; label-: ARRAY OF CHAR);
  VAR e: Entry; o: FlInputs.Output;
BEGIN
  Fl.OpenGroup(b, x, y, Width, Height, label);
  b.SetAlign(Fl.AlignTop);
  NEW(o); FlInputs.OpenOutput(o, x, y, ShownWidth, Height, "");
  o.SetTooltip("computed");
  NEW(e); FlInputs.OpenInput(e, x + ShownWidth + Gap, y, EntryWidth, Height, "");
  e.box := b; e.SetTooltip(Tooltip);
  e.SetWhen(Fl.WhenRelease + Fl.WhenEnterKey);
  b.End;
  b.shown := o; b.entry := e;
  b.target := NIL; b.changed := NIL
END OpenNumberBox;

(* ---- HelpButton ---- *)

PROCEDURE (b: HelpButton) Callback*;
BEGIN
  IF (b.page > 0) & (openPage # NIL) THEN openPage(b.page) END
END Callback;

(* Opens a "?" button, 25 by 25, showing page (0: none yet). *)
PROCEDURE OpenHelpButton*(b: HelpButton; x, y, page: INTEGER);
BEGIN
  FlButtons.OpenButton(b, x, y, 25, 25, "?");
  b.page := page;
  b.SetTooltip("open the rulebook at this page")
END OpenHelpButton;

(* ---- Panel ---- *)

(* The extension's: fills the browser from the model, lines in the
   model's order. *)
PROCEDURE (p: Panel) Fill*;
BEGIN HALT(99)
END Fill;

(* The extension's: the controls set from the browser's line (1 is the
   first), the one the user selected. *)
PROCEDURE (p: Panel) Load*(line: INTEGER);
BEGIN HALT(99)
END Load;

(* The extension's: what Add, Change and Remove do to the model, from
   the controls; Change and Remove on the selected line. Add and Change
   return the line the item will be on once Fill runs again (a change
   can move it), or 0 if they changed nothing; Remove whether it
   removed it. Each leaves the model recomputed. *)
PROCEDURE (p: Panel) Add*(): INTEGER;
BEGIN HALT(99)
END Add;

PROCEDURE (p: Panel) Change*(line: INTEGER): INTEGER;
BEGIN HALT(99)
END Change;

PROCEDURE (p: Panel) Remove*(line: INTEGER): BOOLEAN;
BEGIN HALT(99)
END Remove;

(* How many of the rulebook's names the Choice offers: kind's, then
   second's. *)
PROCEDURE (p: Panel) Offered*(): INTEGER;
  VAR n: INTEGER;
BEGIN
  n := Besm2Rules.Count(p.kind);
  IF p.second >= 0 THEN n := n + Besm2Rules.Count(p.second) END;
  RETURN n
END Offered;

(* The extension's: how many names of its own the Choice offers after
   the rulebook's (FillMore adds them); none here. *)
PROCEDURE (p: Panel) More*(): INTEGER;
BEGIN RETURN 0
END More;

(* The extension's: adds More() names to the Choice. *)
PROCEDURE (p: Panel) FillMore*;
BEGIN
END FillMore;

(* The rulebook's name chosen; NIL for none, or one of the extension's. *)
PROCEDURE (p: Panel) Item*(): Besm2Rules.Item;
  VAR i, n: INTEGER;
BEGIN
  i := p.choice.Value(); n := Besm2Rules.Count(p.kind);
  IF (i >= 0) & (i < n) THEN RETURN Besm2Rules.Get(p.kind, i)
  ELSIF (i >= n) & (i < p.Offered()) THEN RETURN Besm2Rules.Get(p.second, i - n)
  ELSE RETURN NIL
  END
END Item;

(* After the Choice changes: the ? button turns to the chosen name's
   page; an extension sets the Spinner's bounds and the text field
   too. *)
PROCEDURE (p: Panel) Chosen*;
  VAR it: Besm2Rules.Item;
BEGIN
  it := p.Item();
  IF it # NIL THEN p.help.page := it.page ELSE p.help.page := 0 END
END Chosen;

(* What happens after a change the panel made: the window's or dialog's
   refresh. *)
PROCEDURE (p: Panel) Changed*;
BEGIN
END Changed;

(* Chooses Choice entry i (-1: none), and sets the ? button. *)
PROCEDURE (p: Panel) ChooseIndex*(i: INTEGER);
BEGIN
  p.choice.Choose(i);
  p.Chosen
END ChooseIndex;

(* Chooses it in the Choice (none for NIL, or an item the Choice
   doesn't offer), and sets the ? button. *)
PROCEDURE (p: Panel) Choose*(it: Besm2Rules.Item);
  VAR i, n: INTEGER;
BEGIN
  n := -1;
  IF it # NIL THEN
    IF it.kind = p.kind THEN i := 0
    ELSIF it.kind = p.second THEN i := Besm2Rules.Count(p.kind)
    ELSE i := -1
    END;
    IF i >= 0 THEN
      n := 0; WHILE (n < Besm2Rules.Count(it.kind)) & (Besm2Rules.Get(it.kind, n) # it) DO INC(n) END;
      n := n + i
    END
  END;
  p.ChooseIndex(n)
END Choose;

(* The Choice filled with the names p offers: a divider under the last
   of its kind's, then second's, then the extension's. *)
PROCEDURE FillChoice(p: Panel);
  VAR i, n, last: INTEGER; label: ARRAY 64 OF CHAR; flags: SET; it: Besm2Rules.Item;
BEGIN
  n := Besm2Rules.Count(p.kind); last := p.Offered() - 1;
  FOR i := 0 TO last DO
    IF i < n THEN it := Besm2Rules.Get(p.kind, i) ELSE it := Besm2Rules.Get(p.second, i - n) END;
    Besm2Rules.Label(it, label);
    IF (i = n - 1) & (i < last) OR (i = last) & (p.More() > 0) THEN flags := FlMenus.MenuDivider
    ELSE flags := {}
    END;
    p.choice.AddText(label, NIL, flags)
  END;
  p.FillMore
END FillChoice;

(* The Choice filled again, with nothing chosen: after the extension's
   names change. *)
PROCEDURE (p: Panel) Refill*;
BEGIN
  p.choice.Clear;
  FillChoice(p);
  p.ChooseIndex(-1)
END Refill;

(* The Choice offers kind's names, then second's (-1: none), from now
   on: filled again, with nothing chosen, if that changes it. *)
PROCEDURE (p: Panel) Offer*(kind, second: INTEGER);
BEGIN
  IF (kind # p.kind) OR (second # p.second) THEN
    p.kind := kind; p.second := second; p.Refill
  END
END Offer;

(* The browser filled again, its line line selected (0: none) and the
   controls loaded from it. *)
PROCEDURE (p: Panel) Refresh*(line: INTEGER);
BEGIN
  p.browser.Clear;
  p.Fill;
  IF (line > 0) & (line <= p.browser.Count()) THEN
    p.browser.SetSelected(line, TRUE);
    p.Load(line)
  END
END Refresh;

PROCEDURE PanelOf(w: Fl.Widget): Panel;
  VAR p: Panel;
BEGIN
  p := panels;
  WHILE (p # NIL) & (w # p.browser) & (w # p.choice) & (w # p.add) & (w # p.change) & (w # p.remove) DO
    p := p.next
  END;
  RETURN p
END PanelOf;

PROCEDURE BrowserAction(w: Fl.Widget);
  VAR p: Panel;
BEGIN
  p := PanelOf(w);
  IF (p # NIL) & (p.browser.Value() > 0) THEN p.Load(p.browser.Value()) END
END BrowserAction;

PROCEDURE ChoiceAction(w: Fl.Widget);
  VAR p: Panel;
BEGIN p := PanelOf(w); IF p # NIL THEN p.Chosen END
END ChoiceAction;

(* Add and Change leave their item's line selected; Remove, none.
   Change and Remove need a line selected. *)
PROCEDURE ButtonAction(w: Fl.Widget);
  VAR p: Panel; line: INTEGER; done: BOOLEAN;
BEGIN
  p := PanelOf(w);
  IF p = NIL THEN RETURN END;
  line := p.browser.Value();
  IF w = p.add THEN line := p.Add(); done := line > 0
  ELSIF line = 0 THEN done := FALSE
  ELSIF w = p.change THEN line := p.Change(line); done := line > 0
  ELSE done := p.Remove(line); line := 0
  END;
  IF done THEN
    p.Refresh(line);
    p.Changed
  END
END ButtonAction;

(* Opens p at x, y, w wide, its browser h high, its Choice of kind's
   names, then second's (-1: none), its Spinner labelled spinLabel, its
   text field textLabel, then extraRows rows for the extension, from
   extraY, then the buttons. *)
PROCEDURE OpenPanel*(p: Panel; x, y, w, h, kind, second, extraRows: INTEGER;
                     title-, spinLabel-, textLabel-: ARRAY OF CHAR);
  CONST Row = 25; Gap = 5; LabelW = 50;
  VAR yy: INTEGER; b: FlButtons.Button; widths: ARRAY 2 OF INTEGER;
BEGIN
  p.kind := kind; p.second := second;
  NEW(p.browser); FlBrowsers.OpenHoldBrowser(p.browser, x, y + 20, w, h - 20, title);
  p.browser.SetAlign(Fl.AlignTopLeft);
  p.browser.SetFormatChar(0X);  (* names are text, never format codes *)
  widths[0] := w - 70; widths[1] := 0;
  p.browser.SetColumnWidths(widths, 2);
  p.browser.action := BrowserAction;
  yy := y + h + Gap;
  NEW(p.choice); FlMenus.OpenChoice(p.choice, x, yy, w - 30, Row, "");
  p.next := panels; panels := p;  (* before FillChoice, which may call the extension *)
  FillChoice(p);
  p.choice.action := ChoiceAction;
  NEW(p.help); OpenHelpButton(p.help, x + w - 25, yy, 0);
  yy := yy + Row + Gap;
  NEW(p.spinner); FlValuators.OpenSpinner(p.spinner, x + LabelW, yy, 60, Row, spinLabel);
  p.spinner.SetStep(1);
  NEW(p.text); FlInputs.OpenInput(p.text, x + LabelW + 60 + 120, yy, w - LabelW - 180, Row, textLabel);
  yy := yy + Row + Gap;
  p.extraY := yy;
  yy := yy + extraRows * (Row + Gap);
  NEW(b); FlButtons.OpenButton(b, x, yy, 70, Row, "Add"); b.action := ButtonAction; p.add := b;
  NEW(b); FlButtons.OpenButton(b, x + 75, yy, 70, Row, "Change"); b.action := ButtonAction; p.change := b;
  NEW(b); FlButtons.OpenButton(b, x + 150, yy, 70, Row, "Remove"); b.action := ButtonAction; p.remove := b;
  p.bottom := yy + Row
END OpenPanel;

(* Forgets p, whose widgets were deleted (with their window). *)
PROCEDURE ClosePanel*(p: Panel);
  VAR q: Panel;
BEGIN
  IF panels = p THEN panels := p.next
  ELSE
    q := panels;
    WHILE (q # NIL) & (q.next # p) DO q := q.next END;
    IF q # NIL THEN q.next := p.next END
  END;
  p.next := NIL
END ClosePanel;

BEGIN
  openPage := NIL; panels := NIL
END Besm2Widgets.
