MODULE Besm2Preview; (* The Preview tab: the file's entities as the formatters print them, to copy or save *)

(* PLAN.md, Part B, step 11, after ova_cg_po's OvaMarkdownTab.  The
   entities as they stand -- all of the file's, in order, as the
   formatters would print the file the window saves -- in the format
   chosen: reST grid tables, terse reST, groff tbl in a `.. raw:: ms`
   block, or an h-m-m outline, with pobesm2_fmt2's default options.
   The text is made as besm2_calc_po makes it: the entities saved in
   memory through Besm2Save, loaded by Besm2Entities and printed by
   pobesm2_fmt2's formatters, so it is what besm2_calc_po, or any of
   the formatters, prints for the saved file.  Copy puts all of it on
   the clipboard; Save... writes it to a file.

   Besm2Window owns the entities: it builds this tab inside its Tabs
   (Build), and shows the entities here (Show) when the tab is shown
   and after each change while it is.  A message and the file chooser
   go through procedure variables a test sets. *)

IMPORT Fl, FlButtons, FlDialogs, FlMenus, FlText, Fyaml, Platform, SYSTEM,
  Ch := Besm2Character, Besm2Entities, Besm2Grid, Besm2Hmm, Besm2Out, Besm2RawMs, Besm2Save,
  Besm2Spawn, Besm2Terse, Besm2Text, Ropes;

CONST
  Row = 25;

  (* The formats, in the Choice's order *)
  Grid* = 0; Terse* = 1; RawMs* = 2; Hmm* = 3;

TYPE Rope = Ropes.Rope;

VAR
  text-: Rope;                     (* the text shown *)
  format-: FlMenus.Choice;
  display-: FlText.TextDisplay;
  buffer: FlText.TextBuffer;
  copy-, save-: FlButtons.Button;
  entities: Ch.Entities;           (* the entities shown *)
  base: Rope;                      (* the file chooser's suggestion, without its extension; NIL: none *)

  (* tell shows a message; choosePath asks where to save the text,
     suggesting suggested (NIL: nothing). The window's dialogs; a test
     sets its own. *)
  tell*: PROCEDURE (text: Rope);
  choosePath*: PROCEDURE (suggested: Rope; VAR path: Rope): BOOLEAN;

PROCEDURE DialogTell(text: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(text); FlDialogs.Message(s^)
END DialogTell;

PROCEDURE DialogPath(suggested: Rope; VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; path: Fl.String; s: Besm2Text.String; ok: BOOLEAN;
BEGIN
  NEW(c); FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseSaveFile);
  c.SetTitle("Save the preview as"); c.SetOptions(FlDialogs.SaveAsConfirm);
  IF suggested # NIL THEN s := Besm2Text.Chars(suggested); c.SetPresetFile(s^) END;
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN path := c.Name(0); ok := path # NIL END;
  IF ok THEN p := Ropes.FromString(path^); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPath;

(* ---- The text ---- *)

PROCEDURE FormatEntity(e: Besm2Entities.Entity; f, count: INTEGER);
BEGIN
  CASE f OF
    Grid: Besm2Grid.ProcessEntity(e, count)
  | Terse: Besm2Terse.ProcessEntity(e, count)
  | RawMs: Besm2RawMs.ProcessEntity(e, count)
  | Hmm: Besm2Hmm.ProcessEntity(e, count)
  END
END FormatEntity;

(* es in format f, as besm2_calc_po formats a file of them; NIL, with
   msg, if they couldn't be saved or loaded again. *)
PROCEDURE Text*(es: Ch.Entities; f: INTEGER; VAR msg: Rope): Rope;
  VAR doc: Fyaml.Document; root, item: Fyaml.Node; it: Fyaml.ItemIter; e: Besm2Entities.Entity;
    yerr: Fyaml.Error; count: INTEGER; r: Rope; ok: BOOLEAN;
BEGIN
  msg := NIL;
  doc := Besm2Save.Document(es);
  IF doc = NIL THEN msg := Ropes.FromString("the entities' YAML couldn't be built (a duplicate key)"); RETURN NIL END;
  root := doc.Root(); root.Items(it);
  Besm2Out.ToRope; count := 0; ok := TRUE;
  WHILE ok & it.Next(item) DO
    IF Besm2Entities.Load(item, e, yerr, msg) THEN INC(count); FormatEntity(e, f, count)
    ELSE
      (* What Besm2Save writes, Besm2Entities reads: a programmer's error. *)
      ok := FALSE;
      r := Ropes.FromString("entity "); r := Ropes.Cat(r, Besm2Text.Int(count + 1));
      Besm2Text.Add(r, " as saved doesn't load");
      IF msg # NIL THEN Besm2Text.Add(r, ": "); r := Ropes.Cat(r, msg) END;
      msg := r
    END
  END;
  r := Besm2Out.TakeRope();
  doc.Close;
  IF ~ok THEN RETURN NIL END;
  IF r = NIL THEN r := Ropes.FromString("") END;
  RETURN r
END Text;

(* Shows es (base: the name to suggest to Save..., without its
   extension; NIL: none) in the format chosen. *)
PROCEDURE Show*(es: Ch.Entities; b: Rope);
  VAR s: Besm2Text.String; msg, r: Rope;
BEGIN
  entities := es; base := b;
  text := Text(es, format.Value(), msg);
  IF text = NIL THEN
    r := Ropes.FromString("(no preview: "); r := Ropes.Cat(r, msg); Besm2Text.Add(r, ")");
    s := Besm2Text.Chars(r)
  ELSE s := Besm2Text.Chars(text)
  END;
  buffer.SetText(s^)
END Show;

(* Format: the entities shown again, the other way. *)
PROCEDURE FormatAction(w: Fl.Widget);
BEGIN IF entities # NIL THEN Show(entities, base) END
END FormatAction;

(* Copy: the whole text on the clipboard. *)
PROCEDURE CopyAction(w: Fl.Widget);
  VAR s: Besm2Text.String;
BEGIN IF text # NIL THEN s := Besm2Text.Chars(text); Fl.Copy(s^, Fl.Clipboard) END
END CopyAction;

(* r written to the file at path, replacing it; FALSE, with msg, if it
   couldn't be. *)
PROCEDURE WriteText*(r: Rope; path: ARRAY OF CHAR; VAR msg: Rope): BOOLEAN;
  VAR h: Platform.FileHandle; e, e2: Platform.ErrorCode; s, p: Besm2Text.String;
BEGIN
  msg := NIL; p := Besm2Text.Chars(Ropes.FromString(path));
  e := Platform.New(p^, h);
  IF e = 0 THEN
    s := Besm2Text.Chars(r);
    e := Platform.Write(h, SYSTEM.ADR(s[0]), Ropes.Length(r));
    e2 := Platform.Close(h);
    IF e = 0 THEN e := e2 END
  END;
  IF e # 0 THEN
    msg := Ropes.FromString("can't write "); Besm2Text.Add(msg, path); Besm2Text.Add(msg, ": ");
    msg := Ropes.Cat(msg, Besm2Spawn.ErrorText(e))
  END;
  RETURN e = 0
END WriteText;

(* The extension of format f's files: .rst for the reST ones (raw ms
   is a reST directive), .hmm for the outline. *)
PROCEDURE Extension(f: INTEGER; VAR ext: ARRAY OF CHAR);
BEGIN IF f = Hmm THEN COPY(".hmm", ext) ELSE COPY(".rst", ext) END
END Extension;

(* Save...: the text in a file the user chooses, BASE.rst or BASE.hmm
   suggested. *)
PROCEDURE SaveAction(w: Fl.Widget);
  VAR p, msg, suggested: Rope; s: Besm2Text.String; ext: ARRAY 8 OF CHAR;
BEGIN
  IF text = NIL THEN RETURN END;
  suggested := NIL;
  IF base # NIL THEN Extension(format.Value(), ext); suggested := base; Besm2Text.Add(suggested, ext) END;
  IF choosePath(suggested, p) THEN
    s := Besm2Text.Chars(p);
    IF ~WriteText(text, s^, msg) THEN tell(msg) END
  END
END SaveAction;

(* Test hooks: the format chosen, Copy, and Save.... *)
PROCEDURE SetFormat*(f: INTEGER);
BEGIN format.Choose(f); FormatAction(format)
END SetFormat;

PROCEDURE Copy*;
BEGIN CopyAction(copy)
END Copy;

PROCEDURE Save*;
BEGIN SaveAction(save)
END Save;

(* Opens the tab's widgets, inside the group being built, at x, y, w
   by h. *)
PROCEDURE Build*(x, y, w, h: INTEGER);
BEGIN
  NEW(format); FlMenus.OpenChoice(format, x + 60, y, 200, Row, "Format:");
  format.AddText("reST grid tables", NIL, {});
  format.AddText("terse reST", NIL, {});
  format.AddText("groff tbl in raw ms", NIL, {});
  format.AddText("h-m-m outline", NIL, {});
  format.Choose(Grid);
  format.action := FormatAction;
  format.SetTooltip("how to print the file's characters and mecha, as the formatters do");
  NEW(copy); FlButtons.OpenButton(copy, x + 270, y, 80, Row, "Copy");
  copy.action := CopyAction; copy.SetTooltip("put the whole text on the clipboard");
  NEW(save); FlButtons.OpenButton(save, x + 355, y, 100, Row, "Save...");
  save.action := SaveAction; save.SetTooltip("write the text to a file");
  NEW(buffer); FlText.OpenBuffer(buffer);
  NEW(display); FlText.OpenTextDisplay(display, x, y + Row + 10, w, h - Row - 10, "");
  display.SetBuffer(buffer); display.SetTextFont(Fl.Courier)
END Build;

(* Gives up the buffer, after the window is deleted. *)
PROCEDURE Close*;
BEGIN
  IF buffer # NIL THEN buffer.Close END;
  buffer := NIL; display := NIL; copy := NIL; save := NIL; format := NIL; text := NIL; entities := NIL; base := NIL
END Close;

BEGIN
  text := NIL; format := NIL; display := NIL; buffer := NIL; copy := NIL; save := NIL; entities := NIL; base := NIL;
  tell := DialogTell; choosePath := DialogPath
END Besm2Preview.
