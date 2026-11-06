MODULE Besm2CalcMain; (* besm2_calc_po: checks, fills in, upgrades and formats BESM2ER files *)

(* PLAN.md, Part B: the command-line program sharing besm2_cg_po's
   calculation modules. Step 0 has only its command line; its files
   come in step 4, and until then a file argument is a usage error
   (status 2, ArgParser.UsageErrorStatus). It needs no display. *)

IMPORT ArgParser, Err, Out, Platform;

CONST Program = "besm2_calc_po";

VAR
  parser: ArgParser.Parser;
  helpShown: BOOLEAN;

PROCEDURE Fail(status: INTEGER; a, b: ARRAY OF CHAR);
BEGIN
  Out.Flush;
  Err.String(Program); Err.String(": "); Err.String(a); Err.String(b); Err.Ln;
  Platform.Exit(status)
END Fail;

PROCEDURE DoHelp(): BOOLEAN;
BEGIN parser.Usage; helpShown := TRUE; RETURN FALSE
END DoHelp;

PROCEDURE DoArgument(startIdx: INTEGER; VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN Fail(ArgParser.UsageErrorStatus, "reading files isn't written yet: ", arg); RETURN FALSE
END DoArgument;

BEGIN
  helpShown := FALSE;
  parser := ArgParser.NewParser("besm2_calc_po [options] file.yaml...", DoArgument);
  parser.AddOption(ArgParser.MakeOption("h", "help", "Display this text.", DoHelp));
  parser.ParseArguments(1)
END Besm2CalcMain.
