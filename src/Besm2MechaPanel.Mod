MODULE Besm2MechaPanel; (* The window's Mecha tab: a character's Own a Big Mecha and their mecha, or a mecha's owners *)

(* PLAN.md, Part B, step 9.  On a character, a line for each Own a Big
   Mecha (p. 59): its Level and subject, the Mecha Points it gives, and
   the mecha its subject names (A4) with what that spends of all its
   owners give, or that no mecha of that name is in the file.  On a
   mecha, a line for each Own a Big Mecha in the file that names it, with
   its character and the Mecha Points it gives, or that none does.
   A mecha two characters name is priced by the last of them in the
   file (Besm2Calc.Compute), so the others' lines say they don't count.

   Show goes to the line's mecha, or its owner; New Mecha makes the
   line's mecha, named by its subject (or asked for, which then becomes
   the subject), adds it to the file and shows it.  With one line, it is
   the line meant even if not selected.  What the window does goes
   through procedure variables (show, add, tell, askText), set by it. *)

IMPORT Fl, FlBrowsers, FlButtons, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules, Besm2Text, Besm2Widgets,
  Ropes;

CONST Row = 25;

TYPE
  Rope = Ropes.Rope;
  (* A line: the Own a Big Mecha attr of owner. *)
  Line = RECORD owner: Ch.Entity; attr: Ch.Attr END;
  Lines = POINTER TO ARRAY OF Line;

VAR
  list-: FlBrowsers.HoldBrowser;
  showButton-, newButton-: FlButtons.Button;
  n-: INTEGER;              (* how many lines are Own a Big Mecha's: 0 for a line that only says none *)
  lines: Lines;
  entities: Ch.Entities;    (* the file's *)
  entity: Ch.Entity;        (* the one shown *)
  ownABigMecha: R.Item;

  tell*: PROCEDURE (text: Rope);
  askText*: PROCEDURE (prompt: Rope; VAR text: Rope): BOOLEAN;
  show*: PROCEDURE (e: Ch.Entity);   (* shows e *)
  add*: PROCEDURE (e: Ch.Entity);    (* adds e to the file, last, and shows it *)

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

(* "Own a Big Mecha (p. 59, PDF 61)". *)
PROCEDURE ItemLabel(): Rope;
  VAR s: ARRAY 64 OF CHAR;
BEGIN R.Label(ownABigMecha, s); RETURN Rp(s)
END ItemLabel;

(* What an entity is called: its name, or "(no name)". *)
PROCEDURE NameOf(e: Ch.Entity): Rope;
BEGIN
  IF e.hasName & (Besm2Text.Trim(e.name) # NIL) THEN RETURN Besm2Text.Trim(e.name) ELSE RETURN Rp("(no name)") END
END NameOf;

(* "2 Own a Big Mecha: Walker", as the Attributes list shows it. *)
PROCEDURE AttrText(a: Ch.Attr): Rope;
  VAR r: Rope;
BEGIN
  r := Besm2Text.Int(a.level); Besm2Text.Add(r, " Own a Big Mecha");
  IF a.hasSubject & (a.subject # NIL) THEN Besm2Text.Add(r, ": "); r := Ropes.Cat(r, a.subject) END;
  RETURN r
END AttrText;

PROCEDURE AddLine(owner: Ch.Entity; a: Ch.Attr);
  VAR more: Lines; i: INTEGER;
BEGIN
  IF n = LEN(lines^) THEN
    NEW(more, 2 * n); FOR i := 0 TO n - 1 DO more[i] := lines[i] END; lines := more
  END;
  lines[n].owner := owner; lines[n].attr := a; INC(n)
END AddLine;

PROCEDURE Put(r: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); list.Add(s^)
END Put;

(* Line i's text, columns separated by tabs: on a character, the Own a
   Big Mecha, its Mecha Points, and its mecha's; on a mecha, the
   character, its Own a Big Mecha and its Mecha Points. *)
PROCEDURE Text(i: INTEGER): Rope;
  VAR r: Rope; a: Ch.Attr; m: C.Entity;
BEGIN
  a := lines[i].attr;
  IF entity.isMecha THEN r := NameOf(lines[i].owner); Besm2Text.Add(r, ": "); r := Ropes.Cat(r, AttrText(a))
  ELSE r := AttrText(a)
  END;
  r := Ropes.AppendChar(r, 9X); r := Ropes.Cat(r, Besm2Text.Int(C.MechaPoints(a))); Besm2Text.Add(r, " MP");
  m := a.mecha;
  IF entity.isMecha THEN
    IF m.owner # lines[i].owner THEN
      r := Ropes.AppendChar(r, 9X); Besm2Text.Add(r, "not counted: ");
      r := Ropes.Cat(r, NameOf(m.owner(Ch.Entity))); Besm2Text.Add(r, " owns it")
    END
  ELSE
    r := Ropes.AppendChar(r, 9X);
    IF (m # NIL) & (m.owner # entity) THEN
      r := Ropes.Cat(r, NameOf(m(Ch.Entity))); Besm2Text.Add(r, " is ");
      r := Ropes.Cat(r, NameOf(m.owner(Ch.Entity))); Besm2Text.Add(r, "'s: not counted")
    ELSIF m # NIL THEN
      r := Ropes.Cat(r, NameOf(m(Ch.Entity))); Besm2Text.Add(r, " spends ");
      r := Ropes.Cat(r, Besm2Text.Int(m.spent)); Besm2Text.Add(r, " of ");
      r := Ropes.Cat(r, Besm2Text.Int(m.available));
      IF m.spent > m.available THEN Besm2Text.Add(r, ": over") END
    ELSIF a.hasSubject & (Besm2Text.Trim(a.subject) # NIL) THEN Besm2Text.Add(r, "no mecha of that name in the file")
    ELSE Besm2Text.Add(r, "no subject: no mecha")
    END
  END;
  RETURN r
END Text;

(* The lines again, line line selected (0: none). *)
PROCEDURE Fill(line: INTEGER);
  VAR i, j: LONGINT; a: C.Attr; r: Rope;
BEGIN
  list.Clear; n := 0;
  IF entity = NIL THEN RETURN END;
  IF entity.isMecha THEN
    FOR j := 0 TO LEN(entities^) - 1 DO
      IF ~entities[j].isMecha THEN
        a := entities[j].attrs;
        WHILE a # NIL DO
          IF (a.item = ownABigMecha) & (a.mecha = entity) THEN AddLine(entities[j], a(Ch.Attr)) END;
          a := a.next
        END
      END
    END
  ELSE
    a := entity.attrs;
    WHILE a # NIL DO IF a.item = ownABigMecha THEN AddLine(entity, a(Ch.Attr)) END; a := a.next END
  END;
  FOR i := 0 TO n - 1 DO Put(Text(SHORT(i))) END;
  IF n = 0 THEN
    IF entity.isMecha THEN
      r := Rp("No character in the file owns this mecha: give one ");
      r := Ropes.Cat(r, ItemLabel());
      IF entity.hasName & (Besm2Text.Trim(entity.name) # NIL) THEN
        Besm2Text.Add(r, " with the subject "); r := Ropes.Cat(r, Besm2Text.Trim(entity.name))
      END;
      Besm2Text.Add(r, ".")
    ELSE r := Rp("No "); r := Ropes.Cat(r, ItemLabel()); Besm2Text.Add(r, ": add it on the Attributes tab.")
    END;
    Put(r)
  END;
  IF (line >= 1) & (line <= n) THEN IF list.Select(line, TRUE) THEN END END;
  IF entity.isMecha THEN showButton.SetLabel("Show Owner"); newButton.Deactivate
  ELSE showButton.SetLabel("Show Mecha"); newButton.Activate
  END;
  IF n = 0 THEN showButton.Deactivate ELSE showButton.Activate END
END Fill;

(* Shows entity e of es. *)
PROCEDURE Show*(es: Ch.Entities; e: Ch.Entity);
BEGIN entities := es; entity := e; Fill(0)
END Show;

(* The lines again, after a change elsewhere, keeping the one selected. *)
PROCEDURE Refresh*;
BEGIN IF list # NIL THEN Fill(list.Value()) END
END Refresh;

(* The line meant: the one selected, or the only one; -1 for none, said
   why. *)
PROCEDURE Meant(): INTEGER;
  VAR line: INTEGER;
BEGIN
  line := list.Value();
  IF (line >= 1) & (line <= n) THEN RETURN line - 1
  ELSIF n = 1 THEN RETURN 0
  ELSIF n = 0 THEN
    IF entity.isMecha THEN tell(Rp("No character in the file owns this mecha."))
    ELSE tell(Ropes.Cat(Ropes.Cat(Rp("Give the character "), ItemLabel()), Rp(" on the Attributes tab first.")))
    END;
    RETURN -1
  ELSE tell(Rp("Choose an Own a Big Mecha first.")); RETURN -1
  END
END Meant;

PROCEDURE ShowAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  i := Meant();
  IF i < 0 THEN RETURN END;
  IF entity.isMecha THEN show(lines[i].owner)
  ELSIF lines[i].attr.mecha # NIL THEN show(lines[i].attr.mecha(Ch.Entity))
  ELSE tell(Rp("That Own a Big Mecha's mecha isn't in the file: New Mecha makes it."))
  END
END ShowAction;

PROCEDURE NewAction(w: Fl.Widget);
  VAR i: INTEGER; a: Ch.Attr; name: Rope;
BEGIN
  IF entity.isMecha THEN RETURN END;
  i := Meant();
  IF i < 0 THEN RETURN END;
  a := lines[i].attr;
  IF a.mecha # NIL THEN tell(Rp("That Own a Big Mecha has its mecha already: Show Mecha shows it.")); RETURN END;
  IF a.hasSubject THEN name := Besm2Text.Trim(a.subject) ELSE name := NIL END;
  IF name = NIL THEN
    IF ~askText(Rp("The mecha's name (the Own a Big Mecha's subject):"), name) THEN RETURN END;
    name := Besm2Text.Trim(name);
    IF name = NIL THEN tell(Rp("A mecha is found by its name: give one.")); RETURN END;
    a.subject := name; a.hasSubject := TRUE
  END;
  add(Ch.NewMecha(name))
END NewAction;

(* Opens the tab's widgets at x, y, w wide, its list h high. *)
PROCEDURE Build*(x, y, w, h: INTEGER);
  VAR label: ARRAY 64 OF CHAR; hb: Besm2Widgets.HelpButton; widths: ARRAY 3 OF INTEGER;
BEGIN
  R.Label(ownABigMecha, label);
  NEW(list); FlBrowsers.OpenHoldBrowser(list, x, y + 20, w - 30, h - 20, label);
  list.SetAlign(Fl.AlignTopLeft); list.SetFormatChar(0X);
  widths[0] := 260; widths[1] := 70; widths[2] := 0; list.SetColumnWidths(widths, 3);
  NEW(hb); Besm2Widgets.OpenHelpButton(hb, x + w - 25, y + 20, ownABigMecha.page);
  NEW(showButton); FlButtons.OpenButton(showButton, x, y + h + 5, 110, Row, "Show Mecha");
  showButton.action := ShowAction;
  showButton.SetTooltip("show the mecha of the line chosen, or its owner");
  NEW(newButton); FlButtons.OpenButton(newButton, x + 115, y + h + 5, 110, Row, "New Mecha");
  newButton.action := NewAction;
  newButton.SetTooltip("add the mecha the Own a Big Mecha chosen names to the file");
  NEW(hb); Besm2Widgets.OpenHelpButton(hb, x + 235, y + h + 5, R.MechaAttributesPage);
  hb.SetTooltip("Mecha Attributes")
END Build;

(* Forgets the widgets, deleted with their window. *)
PROCEDURE Close*;
BEGIN list := NIL; showButton := NIL; newButton := NIL; entities := NIL; entity := NIL; n := 0; NEW(lines, 4)
END Close;

BEGIN
  ownABigMecha := R.Find("Own a Big Mecha"); ASSERT(ownABigMecha # NIL);
  NEW(lines, 4); n := 0; list := NIL; entities := NIL; entity := NIL;
  tell := NIL; askText := NIL; show := NIL; add := NIL
END Besm2MechaPanel.
