MODULE TestViewer; (* Besm2Viewer: the rulebook's path, the viewers' commands, okular over D-Bus *)

(* ova_cg_po's TestViewer, adapted to Besm2Viewer (PLAN.md, Part B,
   step 5): the BESM2ER default, no %l, the xdg-open message with both
   pages.

   Run from test/, as make test does, with fakes in the programs'
   places: fake-viewer.sh for every viewer, recording its arguments in
   ../obj/fake-viewer.log, and fake-gdbus.sh, answering from
   ../obj/gdbus.scenario and logging its calls in ../obj/gdbus.log.
   Every fake viewer started is ended by its pid, never by name. The
   real viewers are test/viewer.sh's, on a headless sway. Needs no
   display. *)

IMPORT Check, Besm2Rules, Besm2Spawn, Besm2Text, Besm2Viewer, Platform, Ropes;

CONST
  Fake = "./fake-viewer.sh";
  FakeGdbus = "./fake-gdbus.sh";
  Missing = "besm2-cg-no-such-program";
  ViewerLog = "../obj/fake-viewer.log";
  GdbusLog = "../obj/gdbus.log";
  Scenario = "../obj/gdbus.scenario";
  (* The PDF: blanks and a "'", which a shell would need quoted, and
     "#", "%" and "?", which a URL needs encoded; as okular's
     openDocument is given it, and as a URL encoded in full. *)
  Pdf = "/tmp/an O'Brien #1 100% ?.pdf";
  Url = "file:///tmp/an O'Brien %231 100%25 %3F.pdf";
  FullUrl = "file:///tmp/an%20O%27Brien%20%231%20100%25%20%3F.pdf";
  Page = 60;  (* printed; the PDF's index is 62 *)

TYPE Rope = Ropes.Rope;

VAR
  v: Besm2Viewer.Viewer;
  a: Besm2Spawn.Args;
  path, msg, log, pdf, want: Rope;
  pid, first: INTEGER;
  ok: BOOLEAN;

(* Runs cmd with sh, for setting up; whether it succeeded. *)
PROCEDURE Sh(cmd: ARRAY OF CHAR): BOOLEAN;
  VAR c: Besm2Spawn.Args; out: Rope; st: INTEGER;
BEGIN
  Besm2Spawn.Clear(c); Besm2Spawn.Add(c, "sh"); Besm2Spawn.Add(c, "-c"); Besm2Spawn.Add(c, cmd);
  RETURN (Besm2Spawn.Capture(c, out, st) = 0) & (st = 0)
END Sh;

(* The text of file name; NIL if it can't be read. *)
PROCEDURE Contents(name: ARRAY OF CHAR): Rope;
  VAR c: Besm2Spawn.Args; r: Rope; st: INTEGER;
BEGIN
  Besm2Spawn.Clear(c); Besm2Spawn.Add(c, "cat"); Besm2Spawn.Add(c, name);
  IF (Besm2Spawn.Capture(c, r, st) # 0) OR (st # 0) THEN r := NIL END;
  RETURN r
END Contents;

(* Removes the logs, before a case. *)
PROCEDURE Reset;
  VAR s: ARRAY 64 OF CHAR; err: INTEGER;
BEGIN
  s := ViewerLog; err := Platform.Unlink(s);
  s := GdbusLog; err := Platform.Unlink(s)
END Reset;

(* The fake viewer's record, once written (up to 5 s); NIL if none
   was. *)
PROCEDURE ViewerRecord(): Rope;
  VAR n: INTEGER; id: Platform.FileIdentity;
BEGIN
  n := 0;
  WHILE (Platform.IdentifyByName(ViewerLog, id) # 0) & (n < 100) DO Platform.Delay(50); INC(n) END;
  RETURN Contents(ViewerLog)
END ViewerRecord;

(* The record's arguments, one "<A>" each, joined by blanks: what
   started the fake viewer. *)
PROCEDURE ArgsOf(record: Rope): Rope;
  VAR r: Rope; pos, end: LONGINT;
BEGIN
  r := NIL; pos := Ropes.Find(record, "arg <", 0);
  WHILE pos >= 0 DO
    end := Ropes.IndexChar(record, 0AX, pos);
    IF r # NIL THEN r := Ropes.AppendChar(r, " ") END;
    r := Ropes.Cat(r, Ropes.Substring(record, pos + 4, end - pos - 4));
    pos := Ropes.Find(record, "arg <", end)
  END;
  RETURN r
END ArgsOf;

(* The record's pid, -1 if none. *)
PROCEDURE PidOf(record: Rope): INTEGER;
  VAR pos: LONGINT; n: INTEGER;
BEGIN
  n := -1; pos := Ropes.Find(record, "pid ", 0);
  (* "ppid " comes first; the pid line starts a line. *)
  WHILE (pos > 0) & (Ropes.Fetch(record, pos - 1) # 0AX) DO pos := Ropes.Find(record, "pid ", pos + 1) END;
  IF pos >= 0 THEN
    INC(pos, 4); n := 0;
    WHILE (pos < Ropes.Length(record)) & (Ropes.Fetch(record, pos) >= "0") & (Ropes.Fetch(record, pos) <= "9") DO
      n := n * 10 + ORD(Ropes.Fetch(record, pos)) - ORD("0"); INC(pos)
    END
  END;
  RETURN n
END PidOf;

(* Ends the fake viewer pid, by its pid. *)
PROCEDURE Kill(pid: INTEGER);
  VAR c: Besm2Spawn.Args; out: Rope; st: INTEGER;
BEGIN
  IF pid > 0 THEN
    Besm2Spawn.Clear(c); Besm2Spawn.Add(c, "kill"); Besm2Spawn.AddRope(c, Besm2Text.Int(pid));
    IF Besm2Spawn.Capture(c, out, st) = 0 THEN END
  END
END Kill;

(* Waits up to 5 s for pid to end; whether it did. *)
PROCEDURE Gone(pid: INTEGER): BOOLEAN;
  VAR n: INTEGER;
BEGIN
  n := 0;
  WHILE (Besm2Spawn.Session(pid) # -1) & (n < 100) DO Platform.Delay(50); INC(n) END;
  RETURN Besm2Spawn.Session(pid) = -1
END Gone;

(* Whether no fake viewer starts within a second. *)
PROCEDURE NoViewer(): BOOLEAN;
  VAR id: Platform.FileIdentity;
BEGIN
  Platform.Delay(1000);
  RETURN Platform.IdentifyByName(ViewerLog, id) # 0
END NoViewer;

(* Whether a's arguments, joined by blanks with each in <>, are want. *)
PROCEDURE CommandIs(VAR a: Besm2Spawn.Args; want: ARRAY OF CHAR): BOOLEAN;
  VAR r: Rope; i: INTEGER;
BEGIN
  r := NIL;
  FOR i := 0 TO Besm2Spawn.Count(a) - 1 DO
    IF i > 0 THEN r := Ropes.AppendChar(r, " ") END;
    r := Ropes.AppendChar(r, "<"); r := Ropes.Cat(r, Besm2Spawn.Arg(a, i)); r := Ropes.AppendChar(r, ">")
  END;
  RETURN Ropes.EqualString(r, want)
END CommandIs;

(* Appends s and a newline to r. *)
PROCEDURE Line(VAR r: Rope; s: ARRAY OF CHAR);
BEGIN Besm2Text.Add(r, s); r := Ropes.AppendChar(r, 0AX)
END Line;

(* Adds a tab showing doc, object obj of okular name, to the scenario. *)
PROCEDURE Tab(name, obj, doc: ARRAY OF CHAR);
  VAR c: Besm2Spawn.Args; out: Rope; st: INTEGER;
BEGIN
  Besm2Spawn.Clear(c); Besm2Spawn.Add(c, "sh"); Besm2Spawn.Add(c, "-c");
  Besm2Spawn.Add(c, 'printf "%s\t%s\t%s\n" "$1" "$2" "$3" >> ../obj/gdbus.scenario');
  Besm2Spawn.Add(c, "sh"); Besm2Spawn.Add(c, name); Besm2Spawn.Add(c, obj); Besm2Spawn.Add(c, doc);
  IF Besm2Spawn.Capture(c, out, st) = 0 THEN END
END Tab;

(* Empties the scenario: no okular on the bus. *)
PROCEDURE NoTabs;
BEGIN IF Sh(": > ../obj/gdbus.scenario") THEN END
END NoTabs;

(* Opens Page of pdf in v, which must start the fake viewer with args;
   ends it after. *)
PROCEDURE Starts(VAR v: Besm2Viewer.Viewer; args, label: ARRAY OF CHAR);
  VAR record, msg: Rope; ok: BOOLEAN;
BEGIN
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page, msg) & (msg = NIL);
  record := ViewerRecord();
  Check.Check(ok & Ropes.EqualString(ArgsOf(record), args), label);
  Kill(PidOf(record))
END Starts;

BEGIN
  pdf := Ropes.FromString(Pdf);
  COPY(Fake, Besm2Viewer.okular); COPY(Fake, Besm2Viewer.evince); COPY(Fake, Besm2Viewer.mupdf);
  COPY(Fake, Besm2Viewer.xdgOpen); COPY(FakeGdbus, Besm2Viewer.gdbus);

  (* ---- The PDF ---- *)
  ok := ~Besm2Viewer.Choose(Ropes.FromString("/no/such/a.pdf"), Ropes.FromString("/env.pdf"),
    Ropes.FromString("/saved.pdf"), Ropes.FromString("/home/u"), path);
  Check.Check(ok & Ropes.EqualString(path, "/no/such/a.pdf"), "Choose: --rulebook first; FALSE when it isn't there");
  ok := ~Besm2Viewer.Choose(NIL, Ropes.FromString("/env.pdf"), Ropes.FromString("/saved.pdf"),
    Ropes.FromString("/home/u"), path);
  Check.Check(ok & Ropes.EqualString(path, "/env.pdf"), "Choose: then BESM2_RULEBOOK");
  ok := ~Besm2Viewer.Choose(NIL, NIL, Ropes.FromString("/saved.pdf"), Ropes.FromString("/home/u"), path);
  Check.Check(ok & Ropes.EqualString(path, "/saved.pdf"), "Choose: then the saved path");
  ok := ~Besm2Viewer.Choose(NIL, NIL, NIL, Ropes.FromString("/home/u"), path);
  Check.Check(ok & Ropes.EqualString(path, "/home/u/Reference/RPG/Dyskami/BESM/2E/BESM2ER_bookmarked.pdf"),
    "Choose: then the default under the home directory");
  ok := Besm2Viewer.Choose(Ropes.FromString("fake-viewer.sh"), NIL, NIL, NIL, path);
  msg := Ropes.FromString(Platform.CWD); Besm2Text.Add(msg, "/fake-viewer.sh");
  Check.Check(ok & Ropes.Equal(path, msg), "Choose: a relative path is made absolute; TRUE for a file there");

  (* ---- Viewers ---- *)
  ok := Besm2Viewer.Parse(Ropes.FromString(" okular "), v) & (v.kind = Besm2Viewer.Okular)
    & Besm2Viewer.Parse(Ropes.FromString("evince"), v) & (v.kind = Besm2Viewer.Evince)
    & Besm2Viewer.Parse(Ropes.FromString("mupdf"), v) & (v.kind = Besm2Viewer.Mupdf)
    & Besm2Viewer.Parse(Ropes.FromString("xdg-open"), v) & (v.kind = Besm2Viewer.XdgOpen)
    & Ropes.EqualString(Besm2Viewer.Name(v), "xdg-open");
  Check.Check(ok, "Parse: the viewers' names, and Name");
  ok := Besm2Viewer.Parse(Ropes.FromString("zathura -P %p %f"), v) & (v.kind = Besm2Viewer.Template)
    & Ropes.EqualString(Besm2Viewer.Name(v), "zathura -P %p %f");
  Check.Check(ok, "Parse: a command template");
  Check.Check(~Besm2Viewer.Parse(Ropes.FromString("zathura"), v) & ~Besm2Viewer.Parse(NIL, v)
    & (v.kind = Besm2Viewer.Template), "Parse: a name it doesn't know, a template without %f, nothing: FALSE");

  COPY(Missing, Besm2Viewer.okular);
  Besm2Viewer.Default(v);
  Check.Check(v.kind = Besm2Viewer.Evince, "Default: evince when okular isn't on PATH");
  COPY(Missing, Besm2Viewer.evince); COPY(Missing, Besm2Viewer.mupdf);
  Besm2Viewer.Default(v);
  Check.Check(v.kind = Besm2Viewer.XdgOpen, "Default: xdg-open when none is");
  COPY(Fake, Besm2Viewer.okular); COPY(Fake, Besm2Viewer.evince); COPY(Fake, Besm2Viewer.mupdf);
  Besm2Viewer.Default(v);
  Check.Check(v.kind = Besm2Viewer.Okular, "Default: okular first");

  ok := Besm2Viewer.Parse(Ropes.FromString("view  --page=%p %f%% -l %l x%q %"), v);
  Besm2Viewer.Command(v, pdf, Page, a);
  Check.Check(ok & CommandIs(a, "<view> <--page=62> </tmp/an O'Brien #1 100% ?.pdf%> <-l> <%l> <x%q> <%>"),
    "Command: a template's words, each substitution within its word; no %l, since there are no labels");
  Check.Check(Besm2Rules.PdfIndex(Page) = 62, "the PDF's index of printed page 60 is 62");
  Check.Check(Ropes.EqualString(Besm2Viewer.FileUrl(pdf), Url), "FileUrl: only %, # and ? encoded");

  (* ---- Starting each ---- *)
  ok := Besm2Viewer.Parse(Ropes.FromString("evince"), v);
  Starts(v, "<-i> <62> </tmp/an O'Brien #1 100% ?.pdf>", "evince: -i INDEX PDF");
  ok := Besm2Viewer.Parse(Ropes.FromString("./fake-viewer.sh -P %p %f"), v);
  Starts(v, "<-P> <62> </tmp/an O'Brien #1 100% ?.pdf>", "a template runs as given, with the PDF page");

  ok := Besm2Viewer.Parse(Ropes.FromString("xdg-open"), v);
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page, msg);
  log := ViewerRecord();
  Check.Check(ok & Ropes.EqualString(ArgsOf(log), "</tmp/an O'Brien #1 100% ?.pdf>")
    & Ropes.EqualString(msg, "xdg-open can't turn to a page: turn to p. 60, PDF 62"),
    "xdg-open: PDF, and a message giving the page");
  Kill(PidOf(log));

  COPY(Missing, Besm2Viewer.evince);
  ok := Besm2Viewer.Parse(Ropes.FromString("evince"), v);
  ok := ~Besm2Viewer.Open(v, pdf, Page, msg);
  Check.Check(ok & Ropes.EqualString(msg, "can't start besm2-cg-no-such-program: No such file or directory"),
    "a missing viewer: FALSE, and why");
  COPY(Fake, Besm2Viewer.evince);

  (* ---- mupdf: the last one replaced ---- *)
  ok := Besm2Viewer.Parse(Ropes.FromString("mupdf"), v);
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page, msg) & (msg = NIL);
  log := ViewerRecord(); first := PidOf(log);
  Check.Check(ok & Ropes.EqualString(ArgsOf(log), "</tmp/an O'Brien #1 100% ?.pdf> <62>")
    & (first > 0) & (Besm2Viewer.LastMupdf() = first), "mupdf: PDF INDEX");
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page + 1, msg);
  log := ViewerRecord(); pid := PidOf(log);
  Check.Check(ok & Gone(first) & (pid > 0) & (pid # first) & (Besm2Viewer.LastMupdf() = pid)
    & Ropes.EqualString(ArgsOf(log), "</tmp/an O'Brien #1 100% ?.pdf> <63>"),
    "mupdf: the one started before is ended, the next started");
  Besm2Viewer.EndMupdf;
  Check.Check(Gone(pid) & (Besm2Viewer.LastMupdf() = 0), "EndMupdf: ends the last");

  (* ---- okular over D-Bus ---- *)
  ok := Besm2Viewer.Parse(Ropes.FromString("okular"), v);
  (* Two okulars, the second showing the PDF in its second tab; an
     Instance_ alias and a name not okular's, which mustn't be asked. *)
  NoTabs;
  Tab("org.kde.okular.Instance_1", "/okular", Pdf);
  Tab("org.kde.okularx", "/okular", Pdf);
  Tab("org.kde.okular-100", "/okular", "/tmp/other.pdf");
  Tab("org.kde.okular-200", "/okular", "/tmp/x.pdf");
  Tab("org.kde.okular-200", "/okular2", Pdf);
  Tab("org.kde.okular-200", "/okular3", "/tmp/y.pdf");
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page, msg) & (msg = NIL);
  want := NIL;
  Line(want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
  Line(want, "org.kde.okular-100 /okular org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-100 /okular2 org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-200 /okular org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-200 /okular2 org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-200 /okularshell org.kde.okular.openDocument <file:///tmp/an O'Brien %231 100%25 %3F.pdf>");
  Line(want, "org.kde.okular-200 /okular2 org.kde.okular.goToPage <62>");
  Check.Check(ok & Ropes.Equal(Contents(GdbusLog), want),
    "okular: the tab showing the PDF found, brought forward and turned, over D-Bus");
  Check.Check(NoViewer(), "okular: none started when one shows the PDF");

  (* The tab's document as a file: URL. *)
  NoTabs;
  Tab("org.kde.okular", "/okular", FullUrl);
  Reset;
  ok := Besm2Viewer.Open(v, pdf, Page, msg) & (msg = NIL);
  want := NIL;
  Line(want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
  Line(want, "org.kde.okular /okular org.kde.okular.currentDocument");
  Line(want, "org.kde.okular /okularshell org.kde.okular.openDocument <file:///tmp/an O'Brien %231 100%25 %3F.pdf>");
  Line(want, "org.kde.okular /okular org.kde.okular.goToPage <62>");
  Check.Check(ok & Ropes.Equal(Contents(GdbusLog), want),
    "okular: a document given as a file: URL is found, in an okular started --unique");
  Check.Check(NoViewer(), "okular: none started");

  (* An okular, but not showing the PDF: one is started. *)
  NoTabs;
  Tab("org.kde.okular-100", "/okular", "/tmp/other.pdf");
  Tab("org.kde.okular-100", "/okular2", "/tmp/an O'Brien #1 100% ?.pdf.bak");
  Starts(v, "<--unique> <-p> <62> </tmp/an O'Brien #1 100% ?.pdf>", "okular: started when none shows the PDF");
  want := NIL;
  Line(want, "org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames");
  Line(want, "org.kde.okular-100 /okular org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-100 /okular2 org.kde.okular.currentDocument");
  Line(want, "org.kde.okular-100 /okular3 org.kde.okular.currentDocument");
  Check.Check(Ropes.Equal(Contents(GdbusLog), want), "okular: every tab asked, up to the first missing");

  NoTabs;
  Tab("org.kde.okular-100", "/okular", Pdf);
  COPY(Missing, Besm2Viewer.gdbus);
  Starts(v, "<--unique> <-p> <62> </tmp/an O'Brien #1 100% ?.pdf>", "okular: started --unique without gdbus");
  COPY(FakeGdbus, Besm2Viewer.gdbus);

  Check.Summary
END TestViewer.
