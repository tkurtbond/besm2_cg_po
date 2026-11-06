MODULE Besm2CalcMain; (* besm2_calc_po: checks, fills in, upgrades and formats BESM2ER files *)

(* PLAN.md, A3, and Part B, step 4: the command-line program sharing
   besm2_cg_po's calculation modules.  It needs no display.

   Its options are besm2_fmt's (Besm2Cli.NewParser), and three of its
   own, long only, since besm2_fmt's take most letters:
   - --check: every notice of Besm2Character's and Besm2Check's on
     standard error, as "FILE: difference: TEXT" (or warning, error);
     status 1 if there is a difference or an error, or the file has a
     problem.  Nothing on standard output.
   - --fill: the file written back through Besm2Save, every number
     computed, a number that disagrees kept as an override with its
     notice on standard error.
   - --upgrade: as --fill, through Besm2Upgrade first.
   --fill and --upgrade write to -o FILE, or else to standard output, so
   a file is never rewritten unasked (open question 8), and take one
   file (or standard input), since one output holds one file.  A file
   with a problem (a YAML error, an entity that doesn't load) isn't
   written at all, since its entity would be lost.  --check may go with
   either.

   Without them it formats: each file is read and computed, saved in
   memory through Besm2Save, and the saved entities formatted by
   pobesm2_fmt2's formatters, so a file whose numbers agree with the
   rules prints byte for byte as pobesm2_fmt2 prints it.  A problem is
   reported in pobesm2_fmt2's words and in its place among the
   entities; notices are silent.  No file means standard input. *)

IMPORT ArgParser, Besm2Cli, Besm2Config, Besm2Entities, Besm2Grid, Besm2Hmm, Besm2Out, Besm2RawMs,
  Besm2Terse, Besm2Text, Ch := Besm2Character, Besm2Save, Besm2Upgrade, Err, Fyaml, Out, Platform,
  Ropes, SYSTEM;

CONST Program = "besm2_calc_po";

TYPE Rope = Ropes.Rope;

VAR
  check, fill, upgrade: BOOLEAN;
  failed: BOOLEAN;   (* exit 1 *)

PROCEDURE ["C", "strerror"] strerror(e: SYSTEM.INT32): SYSTEM.ADDRESS;

PROCEDURE ErrRope(r: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); Err.String(s^)
END ErrRope;

PROCEDURE ErrReason(e: Platform.ErrorCode);
  VAR p: SYSTEM.ADDRESS; c: CHAR;
BEGIN
  p := strerror(SYSTEM.VAL(SYSTEM.INT32, e));
  IF p # 0 THEN
    SYSTEM.GET(p, c);
    WHILE c # 0X DO Err.Char(c); INC(p); SYSTEM.GET(p, c) END
  END
END ErrReason;

PROCEDURE Usage(a, b: ARRAY OF CHAR);
BEGIN
  Besm2Out.Flush; Out.Flush;
  Err.String(Program); Err.String(": "); Err.String(a); Err.String(b); Err.Ln;
  Platform.Exit(ArgParser.UsageErrorStatus)
END Usage;

PROCEDURE DoCheck(): BOOLEAN;
BEGIN check := TRUE; RETURN TRUE
END DoCheck;

PROCEDURE DoFill(): BOOLEAN;
BEGIN fill := TRUE; RETURN TRUE
END DoFill;

PROCEDURE DoUpgrade(): BOOLEAN;
BEGIN upgrade := TRUE; RETURN TRUE
END DoUpgrade;

(* ---- Reporting ---- *)

(* Problem r of the file source, as pobesm2_fmt2 reports it, with this
   program's name. *)
PROCEDURE Report(r: Ch.Result; VAR source: ARRAY OF CHAR);
BEGIN
  failed := TRUE;
  Besm2Out.Flush;
  Err.String(Program); Err.String(": ");
  IF r.yerr = NIL THEN Err.String("error processing ") END;
  ErrRope(Ch.Problem(r, source)); Err.Ln
END Report;

(* Every notice of the last Read, "SOURCE: KIND: TEXT". *)
PROCEDURE Notices(VAR source: ARRAY OF CHAR);
  VAR n: Ch.Notice;
BEGIN
  Besm2Out.Flush;
  n := Ch.notices;
  WHILE n # NIL DO
    Err.String(source); Err.String(": ");
    IF n.kind = Ch.Difference THEN Err.String("difference: ")
    ELSIF n.kind = Ch.Error THEN Err.String("error: ")
    ELSE Err.String("warning: ")
    END;
    ErrRope(n.text); Err.Ln;
    n := n.next
  END
END Notices;

(* ---- Formatting ---- *)

PROCEDURE Format(e: Besm2Entities.Entity; count: INTEGER);
BEGIN
  CASE Besm2Config.format OF
    Besm2Config.Terse: Besm2Terse.ProcessEntity(e, count)
  | Besm2Config.Grid: Besm2Grid.ProcessEntity(e, count)
  | Besm2Config.Hmm: Besm2Hmm.ProcessEntity(e, count)
  | Besm2Config.RawMs: Besm2RawMs.ProcessEntity(e, count)
  ELSE HALT(20)   (* Besm2Cli sets no other format *)
  END
END Format;

(* The entities read, saved in memory and formatted, and the problems
   in their places among them.  count runs on across the file, as in
   pobesm2_fmt2. *)
PROCEDURE FormatFile(results: Ch.Result; es: Ch.Entities; VAR source: ARRAY OF CHAR);
  VAR doc: Fyaml.Document; root, item: Fyaml.Node; it: Fyaml.ItemIter; r: Ch.Result;
    e: Besm2Entities.Entity; yerr: Fyaml.Error; msg: Rope; count: INTEGER;
BEGIN
  doc := NIL;
  IF es # NIL THEN
    doc := Besm2Save.Document(es);
    IF doc = NIL THEN
      failed := TRUE; Besm2Out.Flush;
      Err.String(Program); Err.String(": "); Err.String(source);
      Err.String(": the entities' YAML couldn't be built (a duplicate key)"); Err.Ln;
      RETURN
    END;
    root := doc.Root(); root.Items(it)
  END;
  count := 0; r := results;
  WHILE r # NIL DO
    IF r.entity = NIL THEN Report(r, source)
    ELSIF it.Next(item) & Besm2Entities.Load(item, e, yerr, msg) THEN INC(count); Format(e, count)
    ELSE
      (* What Besm2Save writes, Besm2Entities reads: a programmer's error. *)
      failed := TRUE; Besm2Out.Flush;
      Err.String(Program); Err.String(": "); Err.String(source); Err.String(": entity ");
      Err.Int(count + 1, 0); Err.String(" as saved doesn't load");
      IF msg # NIL THEN Err.String(": "); ErrRope(msg) END;
      Err.Ln
    END;
    r := r.next
  END;
  IF doc # NIL THEN doc.Close END
END FormatFile;

(* ---- Writing YAML ---- *)

PROCEDURE Write(es: Ch.Entities; VAR source: ARRAY OF CHAR);
  VAR text, msg: Rope; path: Besm2Text.String;
BEGIN
  IF Besm2Config.hasOutputFile THEN
    path := Besm2Text.Chars(Besm2Config.outputFile);
    IF ~Besm2Save.SaveAll(es, path^, msg) THEN
      failed := TRUE;
      Err.String(Program); Err.String(": can't write "); Err.String(path^); Err.String(": ");
      ErrRope(msg); Err.Ln
    END
  ELSE
    text := Besm2Save.ToText(es);
    IF text = NIL THEN
      failed := TRUE;
      Err.String(Program); Err.String(": "); Err.String(source);
      Err.String(": the entities' YAML couldn't be built (a duplicate key)"); Err.Ln
    ELSE Besm2Out.Rope(text)
    END
  END
END Write;

(* ---- Files ---- *)

PROCEDURE ProcessOne(name: Rope; stdin: BOOLEAN);
  VAR results, r: Ch.Result; es: Ch.Entities; path: Besm2Text.String;
    source: ARRAY 4096 OF CHAR; problems: BOOLEAN;
BEGIN
  IF stdin THEN source := Fyaml.stdinName; Ch.Read("", TRUE, results, es)
  ELSE path := Besm2Text.Chars(name); COPY(path^, source); Ch.Read(path^, FALSE, results, es)
  END;
  IF fill OR upgrade OR check THEN
    problems := FALSE; r := results;
    WHILE r # NIL DO IF r.entity = NIL THEN Report(r, source); problems := TRUE END; r := r.next END;
    Notices(source);
    IF check & (Ch.nDifferences > 0) THEN failed := TRUE END;
    IF fill OR upgrade THEN
      IF problems THEN
        Err.String(Program); Err.String(": "); Err.String(source);
        Err.String(": not written, since an entity didn't load"); Err.Ln
      ELSE Write(es, source)
      END
    END
  ELSE FormatFile(results, es, source)
  END
END ProcessOne;

PROCEDURE Main;
  VAR p: ArgParser.Parser; e: Platform.ErrorCode; path: Besm2Text.String; i: INTEGER;
BEGIN
  check := FALSE; fill := FALSE; upgrade := FALSE; failed := FALSE;
  p := Besm2Cli.NewParser(Program, "besm2_calc_po [options] [files...]");
  p.AddOption(ArgParser.MakeOption(0X, "check",
    "List on standard error each number of the files that disagrees with the rules, and what else is wrong; exit 1 if any.",
    DoCheck));
  p.AddOption(ArgParser.MakeOption(0X, "fill",
    "Write the file with every number computed (to -o FILE, or standard output).", DoFill));
  p.AddOption(ArgParser.MakeOption(0X, "upgrade",
    "As --fill, with names split from subjects, BESM2ER names, Defect levels and Weapon Attack details as keys.",
    DoUpgrade));
  p.ParseArguments(1);   (* exits with status 2 on a command-line mistake *)
  IF Besm2Cli.helpShown THEN Out.Flush; Platform.Exit(0) END;
  IF (fill OR upgrade) & (Besm2Cli.files.n > 1) THEN Usage("--fill and --upgrade take one file", "") END;
  IF upgrade THEN Besm2Upgrade.Install END;

  IF Besm2Config.hasOutputFile & ~(fill OR upgrade) THEN
    path := Besm2Text.Chars(Besm2Config.outputFile);
    e := Besm2Out.ToFile(path^);
    IF e # 0 THEN
      Err.String(Program); Err.String(": can't create "); Err.String(path^);
      Err.String(": "); ErrReason(e); Err.Ln;
      Platform.Exit(1)
    END
  END;

  (* The -R/--hmm-root line: once per run, as in pobesm2_fmt2. *)
  IF ~(check OR fill OR upgrade) & Besm2Config.hmmOutput & Besm2Config.hasHmmRoot THEN
    Besm2Out.Repeat(09X, Besm2Config.hmmDepth);
    Besm2Out.Rope(Besm2Config.hmmRoot); Besm2Out.Ln
  END;

  IF Besm2Cli.files.n = 0 THEN ProcessOne(NIL, TRUE)
  ELSE FOR i := 0 TO Besm2Cli.files.n - 1 DO ProcessOne(Besm2Cli.files.items[i], FALSE) END
  END;

  e := Besm2Out.Close();
  IF e # 0 THEN
    Err.String(Program); Err.String(": error writing output: "); ErrReason(e); Err.Ln;
    Platform.Exit(1)
  END;
  IF failed THEN Platform.Exit(1) END
END Main;

BEGIN
  Main
END Besm2CalcMain.
