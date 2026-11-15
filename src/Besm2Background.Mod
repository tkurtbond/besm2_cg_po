MODULE Besm2Background; (* The Background tab: the entity's description and its notes *)

(* PLAN.md, Part B, step 7 (decided 2026-11-06), after ova_cg_po's
   OvaBackground.  The description (`description:`) is an FlText
   editor; the notes (`notes:`, A4) are short lines, never priced,
   listed in a browser, with an input and Add, Change and Remove.

   Besm2Window owns the entities and the file: it builds this tab
   inside its Tabs (Build), shows an entity here (Show), and is told of
   each change (changed).  A message goes through tell, which a test
   sets.  Every change goes into the entity at once, as the user types;
   nothing here holds the only copy. *)

IMPORT Fl, FlBrowsers, FlButtons, FlDialogs, FlInputs, FlText, Ch := Besm2Character, Besm2Text, Ropes;

CONST
  Row = 25;

TYPE
  Rope = Ropes.Rope;

  (* The description's text: each change goes to the entity. *)
  DescriptionBuffer = POINTER TO RECORD (FlText.TextBufferDesc) END;

VAR
  entity: Ch.Entity;
  filling: BOOLEAN;   (* the widgets being set from the entity: no change to report *)

  description-: FlText.TextEditor;
  buffer: DescriptionBuffer;
  notes-: FlBrowsers.HoldBrowser;   (* the notes, in order *)
  noteIn-: FlInputs.Input;
  addNote-, changeNote-, removeNote-: FlButtons.Button;

  (* Set by the window: called after every change the user makes here. *)
  changed*: PROCEDURE;
  (* Shows a message. *)
  tell*: PROCEDURE (text: Rope);

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

PROCEDURE Changed;
BEGIN IF changed # NIL THEN changed END
END Changed;

PROCEDURE DialogTell(text: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(text); FlDialogs.Message(s^)
END DialogTell;

(* ---- The description ---- *)

(* The text, trimmed as the loader trims it, so what is saved loads the
   same; blank is empty, but a key the entity had stays. *)
PROCEDURE (b: DescriptionBuffer) Modified*(pos, inserted, deleted, restyled: INTEGER);
  VAR s: Fl.String; r: Rope;
BEGIN
  IF filling OR (entity = NIL) OR (inserted = 0) & (deleted = 0) THEN RETURN END;
  s := b.Text();
  r := Besm2Text.Trim(Ropes.FromString(s^));
  entity.description := r; entity.hasDescription := entity.hasDescription OR (r # NIL);
  Changed
END Modified;

(* ---- The notes ---- *)

(* The notes listed again, line line selected (0: none) and in the
   input. *)
PROCEDURE ShowNotes(line: INTEGER);
  VAR i: INTEGER; s: Besm2Text.String;
BEGIN
  notes.Clear;
  FOR i := 0 TO entity.notes.n - 1 DO s := Besm2Text.Chars(entity.notes.items[i]); notes.Add(s^) END;
  IF (line > 0) & (line <= notes.Count()) THEN
    notes.SetSelected(line, TRUE);
    SetInput(noteIn, entity.notes.items[line - 1])
  ELSE noteIn.SetValue("")
  END
END ShowNotes;

PROCEDURE NotesAction(w: Fl.Widget);
  VAR line: INTEGER;
BEGIN
  line := notes.Value();
  IF (line > 0) & (line <= entity.notes.n) THEN SetInput(noteIn, entity.notes.items[line - 1]) END
END NotesAction;

(* The notes again, line skip (from 1) left out, and text put at line
   at (0: none; beyond the last: last). *)
PROCEDURE Rebuild(skip, at: INTEGER; text: Rope);
  VAR old: Besm2Text.List; i: INTEGER;
BEGIN
  old := entity.notes; Besm2Text.Clear(entity.notes);
  FOR i := 0 TO old.n - 1 DO
    IF i + 1 = at THEN Besm2Text.Append(entity.notes, text) END;
    IF i + 1 # skip THEN Besm2Text.Append(entity.notes, old.items[i]) END
  END;
  IF at > old.n THEN Besm2Text.Append(entity.notes, text) END;
  entity.hasNotes := entity.hasNotes OR (entity.notes.n > 0)
END Rebuild;

(* Add puts the note last; Change and Remove need a line selected. *)
PROCEDURE NoteButtonAction(w: Fl.Widget);
  VAR line: INTEGER; text: Rope;
BEGIN
  IF entity = NIL THEN RETURN END;
  line := notes.Value();
  IF (w = addNote) OR (w = changeNote) THEN
    text := InputText(noteIn);
    IF text = NIL THEN tell(Ropes.FromString("Type the note first.")); RETURN END
  END;
  IF w = addNote THEN Rebuild(0, entity.notes.n + 1, text); line := entity.notes.n
  ELSIF line = 0 THEN tell(Ropes.FromString("Choose a note first.")); RETURN
  ELSIF w = changeNote THEN Rebuild(line, line, text)
  ELSE Rebuild(line, 0, NIL); line := 0
  END;
  ShowNotes(line);
  Changed
END NoteButtonAction;

(* ---- Showing an entity ---- *)

PROCEDURE Show*(e: Ch.Entity);
  VAR s: Besm2Text.String;
BEGIN
  entity := e;
  filling := TRUE;
  s := Besm2Text.Chars(e.description); buffer.SetText(s^);
  ShowNotes(0);
  filling := FALSE
END Show;

(* ---- Building ---- *)

PROCEDURE Heading(x, y, w: INTEGER; text: ARRAY OF CHAR);
  VAR b: Fl.Box;
BEGIN
  NEW(b); Fl.OpenLabel(b, x, y, w, 20, text); b.SetLabelFont(Fl.Bold)
END Heading;

PROCEDURE Button(VAR b: FlButtons.Button; x, y: INTEGER; label: ARRAY OF CHAR);
BEGIN NEW(b); FlButtons.OpenButton(b, x, y, 70, Row, label); b.action := NoteButtonAction
END Button;

(* Opens the tab's widgets in the group being built, at x, y, w by h. *)
PROCEDURE Build*(x, y, w, h: INTEGER);
  VAR dh, yy: INTEGER;
BEGIN
  dh := (h - 20 - 20 - 3 * (Row + 5) - 10) DIV 2;
  Heading(x, y, w, "Description");
  NEW(buffer); FlText.OpenBuffer(buffer);
  NEW(description); FlText.OpenTextEditor(description, x, y + 20, w, dh, "");
  description.SetBuffer(buffer); description.SetWrapMode(FlText.WrapAtBounds, 0);
  yy := y + 20 + dh + 10;
  Heading(x, yy, w, "Notes");
  yy := yy + 20;
  NEW(notes); FlBrowsers.OpenHoldBrowser(notes, x, yy, w, y + h - yy - 2 * (Row + 5), "");
  notes.SetFormatChar(0X); notes.action := NotesAction;
  yy := y + h - 2 * (Row + 5) + 5;
  NEW(noteIn); FlInputs.OpenInput(noteIn, x + 40, yy, w - 40, Row, "note");
  yy := yy + Row + 5;
  Button(addNote, x, yy, "Add"); Button(changeNote, x + 75, yy, "Change"); Button(removeNote, x + 150, yy, "Remove")
END Build;

(* Gives up the buffer, after the window is deleted. *)
PROCEDURE Close*;
BEGIN
  IF buffer # NIL THEN buffer.Close END;
  buffer := NIL; description := NIL; notes := NIL; noteIn := NIL;
  addNote := NIL; changeNote := NIL; removeNote := NIL; entity := NIL
END Close;

BEGIN
  entity := NIL; filling := FALSE; buffer := NIL;
  changed := NIL; tell := DialogTell
END Besm2Background.
