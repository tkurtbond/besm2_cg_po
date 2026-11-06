MODULE Besm2Cg; (* besm2_cg_po: a BESM2ER character generator; the main module *)

(* As ova_cg_po's OvaCg: the command line, then a display, then the
   window. A mistake on the command line exits with status 2
   (ArgParser.UsageErrorStatus). The program can't do anything without
   a window, so with no display it says so and exits with status 1,
   before FLTK is asked to open one.  A file that can't be opened is
   said on standard error, status 1, before a display is needed. *)

IMPORT ArgParser, Err, Fl, FlPreferences, Ch := Besm2Character, Besm2Text, Besm2Viewer, Besm2Window, Out,
  Platform, Ropes;

CONST
  Program = "besm2_cg_po";
  FailureStatus = 1;
  (* The preferences: ~/.config/besm2_cg_po/besm2_cg_po.prefs (FLTK's
     vendor and application). *)
  Vendor = "besm2_cg_po"; Application = "besm2_cg_po";

VAR
  parser: ArgParser.Parser;
  helpShown: BOOLEAN;
  file: Ropes.Rope;  (* the file argument; NIL for none *)
  campaignFile: Ropes.Rope;  (* --campaign's; NIL for none *)
  entities: Ch.Entities;  (* the file's; NIL for none *)
  preferences: FlPreferences.Preferences;

PROCEDURE Fail(status: INTEGER; a, b: ARRAY OF CHAR);
BEGIN
  Out.Flush;
  Err.String(Program); Err.String(": "); Err.String(a); Err.String(b); Err.Ln;
  Platform.Exit(status)
END Fail;

PROCEDURE DoHelp(): BOOLEAN;
BEGIN parser.Usage; helpShown := TRUE; RETURN FALSE
END DoHelp;

PROCEDURE DoRulebook(VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN Besm2Window.rulebookOption := Ropes.FromString(arg); RETURN TRUE
END DoRulebook;

PROCEDURE DoViewer(VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF ~Besm2Viewer.Parse(Ropes.FromString(arg), Besm2Window.viewer) THEN
    Fail(ArgParser.UsageErrorStatus,
      "--viewer takes okular, evince, mupdf, xdg-open, or a command with %f for the PDF: ", arg)
  END;
  Besm2Window.viewerOption := TRUE;
  RETURN TRUE
END DoViewer;

PROCEDURE DoCampaign(VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN campaignFile := Ropes.FromString(arg); RETURN TRUE
END DoCampaign;

PROCEDURE DoArgument(startIdx: INTEGER; VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF file # NIL THEN Fail(ArgParser.UsageErrorStatus, "one file at a time: ", arg) END;
  file := Ropes.FromString(arg);
  RETURN TRUE
END DoArgument;

PROCEDURE ParseCommandLine;
BEGIN
  parser := ArgParser.NewParser("besm2_cg_po [options] [file.yaml]", DoArgument);
  parser.AddOption(ArgParser.MakeOption("h", "help", "Display this text.", DoHelp));
  parser.AddOption(ArgParser.MakeStringOption("r", "rulebook",
    "The rulebook's PDF (else BESM2_RULEBOOK, else the one chosen before, else ~/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf).",
    DoRulebook));
  parser.AddOption(ArgParser.MakeStringOption("v", "viewer",
    "okular, evince, mupdf, xdg-open, or a command: %f the PDF, %p its page.", DoViewer));
  parser.AddOption(ArgParser.MakeStringOption(0X, "campaign",
    "A campaign file (or a character's) whose creation File > New starts a character with.", DoCampaign));
  parser.ParseArguments(1)
END ParseCommandLine;

PROCEDURE LoadFile;
  VAR s: Besm2Text.String; msg: Ropes.Rope;
BEGIN
  s := Besm2Text.Chars(file);
  IF ~Ch.LoadAll(s^, entities, msg) THEN
    s := Besm2Text.Chars(msg); Fail(FailureStatus, s^, "")
  END
END LoadFile;

(* --campaign's file, for File > New. *)
PROCEDURE LoadCampaign;
  VAR s: Besm2Text.String; msg: Ropes.Rope; from: Ch.Entity;
BEGIN
  s := Besm2Text.Chars(campaignFile);
  IF ~Ch.LoadCampaign(s^, from, msg) THEN
    s := Besm2Text.Chars(msg); Fail(FailureStatus, s^, "")
  END;
  Besm2Window.campaign := from
END LoadCampaign;

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
  helpShown := FALSE; file := NIL; campaignFile := NIL; entities := NIL;
  ParseCommandLine;
  IF ~helpShown THEN
    IF campaignFile # NIL THEN LoadCampaign END;
    IF file # NIL THEN LoadFile END;
    RequireDisplay;
    Besm2Window.Build;
    NEW(preferences); FlPreferences.Open(preferences, FlPreferences.User, Vendor, Application);
    Besm2Window.UsePreferences(preferences);
    Besm2Window.window.Show;
    IF entities # NIL THEN Besm2Window.Adopt(entities, file) END;
    Fl.Run;
    preferences.Close
  END
END Besm2Cg.
