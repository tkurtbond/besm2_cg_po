MODULE Besm2Widgets; (* What the window shares with its dialogs: the number boxes and the ? buttons *)

(* PLAN.md, Part B, step 6: OvaWidgets's NumberBox and HelpButton,
   copied from ova_cg_po (its Panel comes with step 7's lists).

   Beside every number the program computes is an empty entry box (A3,
   `overrides`).  A NumberBox is both: the computed number, shown
   read-only, and the box, whose text is the override in effect ("" for
   none).  Where its number lives is its Target, which the window
   extends for each kind of number (a Stat's points, the ACV, ...), so
   the box reads and sets the model, never a copy.

   A HelpButton, "?", opens the rulebook at a printed page, through
   openPage, which the window sets (it adds the 2 to the PDF's page). *)

IMPORT Fl, FlButtons, FlInputs, Besm2Calc;

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

VAR
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

BEGIN
  openPage := NIL
END Besm2Widgets.
