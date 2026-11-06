MODULE Besm2Cg; (* besm2_cg_po: a BESM2ER character generator; the main module *)

(* As ova_cg_po's OvaCg: the command line, then a display, then the
   window. A mistake on the command line exits with status 2
   (ArgParser.UsageErrorStatus). The program can't do anything without
   a window, so with no display it says so and exits with status 1,
   before FLTK is asked to open one. Opening a file comes in step 4 of
   PLAN.md, Part B; until then a file argument is a usage error. *)

IMPORT ArgParser, Err, Fl, Besm2Window, Out, Platform;

CONST
  Program = "besm2_cg_po";
  FailureStatus = 1;

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
BEGIN Fail(ArgParser.UsageErrorStatus, "opening files isn't written yet: ", arg); RETURN FALSE
END DoArgument;

PROCEDURE ParseCommandLine;
BEGIN
  parser := ArgParser.NewParser("besm2_cg_po [options]", DoArgument);
  parser.AddOption(ArgParser.MakeOption("h", "help", "Display this text.", DoHelp));
  parser.ParseArguments(1)
END ParseCommandLine;

(* TRUE if the environment variable name is set and not empty. *)
PROCEDURE IsSet(name: ARRAY OF CHAR): BOOLEAN;
  VAR val: ARRAY 2 OF CHAR;
BEGIN RETURN Platform.getEnv(name, val) & (val[0] # 0X)
END IsSet;

(* With no display, the reason and, in tmux, where it may have come
   from (ova_cg_po's finding: a tmux session last attached from a
   terminal without a display drops DISPLAY and WAYLAND_DISPLAY from
   new panes). *)
PROCEDURE RequireDisplay;
BEGIN
  IF ~IsSet("DISPLAY") & ~IsSet("WAYLAND_DISPLAY") THEN
    Out.Flush;
    Err.String(Program); Err.String(": no display: neither DISPLAY nor WAYLAND_DISPLAY is set"); Err.Ln;
    IF IsSet("TMUX") THEN
      Err.String(Program);
      Err.String(": in tmux, the session may have been attached from a terminal without one;");
      Err.String(" reattach from the desktop, or set them from `tmux show-environment -g`"); Err.Ln
    END;
    Platform.Exit(FailureStatus)
  END
END RequireDisplay;

BEGIN
  helpShown := FALSE;
  ParseCommandLine;
  IF ~helpShown THEN
    RequireDisplay;
    Besm2Window.Build;
    Besm2Window.window.Show;
    Fl.Run
  END
END Besm2Cg.
