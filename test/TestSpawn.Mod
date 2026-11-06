MODULE TestSpawn; (* Besm2Spawn: starting a program detached, and capturing one's output *)

(* ova_cg_po's, with its names changed (PLAN.md, Part B, step 5). *)

(* Run from test/, as make test does. The viewer is fake-viewer.sh,
   which records its arguments, parent, session, terminal and
   standard files in ../obj/fake-viewer.log, then runs until ended:
   every one started here is ended by its pid (Terminate), never by
   name. Needs no display. *)

IMPORT Check, Besm2Spawn, Besm2Text, Platform, Ropes;

CONST
  Viewer = "./fake-viewer.sh";
  Log = "../obj/fake-viewer.log";
  (* An argument holding a blank and a "'", which a shell would need
     quoted. *)
  Odd = "/tmp/an O'Brien book.pdf";

TYPE Rope = Ropes.Rope;

VAR
  a: Besm2Spawn.Args;
  p: Besm2Spawn.Process;
  out, line, want: Rope;
  err, status, i, n: INTEGER;
  log: ARRAY 64 OF CHAR;
  big: ARRAY 9000 OF CHAR;
  ok: BOOLEAN;

(* The text of file name, by cat; NIL if it can't be read. *)
PROCEDURE Contents(name: ARRAY OF CHAR): Rope;
  VAR c: Besm2Spawn.Args; r: Rope; st: INTEGER;
BEGIN
  Besm2Spawn.Clear(c); Besm2Spawn.Add(c, "cat"); Besm2Spawn.Add(c, name);
  IF (Besm2Spawn.Capture(c, r, st) # 0) OR (st # 0) THEN r := NIL END;
  RETURN r
END Contents;

(* Waits up to 5 s for file name to exist. *)
PROCEDURE WaitFor(name: ARRAY OF CHAR): BOOLEAN;
  VAR id: Platform.FileIdentity; n: INTEGER;
BEGIN
  n := 0;
  WHILE (Platform.IdentifyByName(name, id) # 0) & (n < 100) DO Platform.Delay(50); INC(n) END;
  RETURN n < 100
END WaitFor;

(* Waits up to 5 s for p to end. *)
PROCEDURE WaitEnd(VAR p: Besm2Spawn.Process): BOOLEAN;
  VAR n: INTEGER;
BEGIN
  n := 0;
  WHILE Besm2Spawn.Alive(p) & (n < 100) DO Platform.Delay(50); INC(n) END;
  RETURN ~Besm2Spawn.Alive(p)
END WaitEnd;

(* Line i (from 0) of r, without its newline; NIL past the end. *)
PROCEDURE Line(r: Rope; i: INTEGER): Rope;
  VAR start, end: LONGINT;
BEGIN
  start := 0;
  WHILE (i > 0) & (start >= 0) DO
    start := Ropes.IndexChar(r, 0AX, start);
    IF start >= 0 THEN INC(start) END;
    DEC(i)
  END;
  IF (start < 0) OR (start >= Ropes.Length(r)) THEN RETURN NIL END;
  end := Ropes.IndexChar(r, 0AX, start);
  IF end < 0 THEN end := Ropes.Length(r) END;
  RETURN Ropes.Substring(r, start, end - start)
END Line;

(* The decimal number after the first blank of s's word word (from 0),
   as "ppid 1 sid 2" holds: Field(s, 1) is 1, Field(s, 3) 2; -1 if
   none. *)
PROCEDURE Field(s: Rope; word: INTEGER): INTEGER;
  VAR pos: LONGINT; n: INTEGER; ch: CHAR;
BEGIN
  pos := 0;
  WHILE (word > 0) & (pos >= 0) DO
    pos := Ropes.IndexChar(s, " ", pos);
    IF pos >= 0 THEN INC(pos) END;
    DEC(word)
  END;
  IF (pos < 0) OR (pos >= Ropes.Length(s)) THEN RETURN -1 END;
  n := 0; ch := Ropes.Fetch(s, pos);
  IF (ch < "0") OR (ch > "9") THEN RETURN -1 END;
  WHILE (pos < Ropes.Length(s)) & (Ropes.Fetch(s, pos) >= "0") & (Ropes.Fetch(s, pos) <= "9") DO
    n := n * 10 + ORD(Ropes.Fetch(s, pos)) - ORD("0"); INC(pos)
  END;
  RETURN n
END Field;

(* Our children in state Z (zombies), by ps: its output's lines. *)
PROCEDURE Zombies(): INTEGER;
  VAR c: Besm2Spawn.Args; r: Rope; st, n: INTEGER;
BEGIN
  Besm2Spawn.Clear(c);
  Besm2Spawn.Add(c, "ps"); Besm2Spawn.Add(c, "-o"); Besm2Spawn.Add(c, "stat="); Besm2Spawn.Add(c, "--ppid");
  Besm2Spawn.AddRope(c, Besm2Text.Int(Platform.PID));
  n := -1;
  IF Besm2Spawn.Capture(c, r, st) = 0 THEN n := SHORT(Ropes.Count(r, "Z")) END;
  RETURN n
END Zombies;

BEGIN
  (* ---- Argument vectors ---- *)
  Besm2Spawn.Clear(a);
  Besm2Spawn.Add(a, "one"); Besm2Spawn.AddRope(a, Ropes.FromString("two words")); Besm2Spawn.Add(a, "");
  Check.Check((Besm2Spawn.Count(a) = 3) & Ropes.EqualString(Besm2Spawn.Arg(a, 0), "one")
    & Ropes.EqualString(Besm2Spawn.Arg(a, 1), "two words") & (Besm2Spawn.Arg(a, 2) = NIL)
    & (Besm2Spawn.Arg(a, 3) = NIL), "Args: Add, AddRope, an empty argument, Arg");

  (* ---- A missing program ---- *)
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "besm2-cg-no-such-viewer"); Besm2Spawn.Add(a, "x.pdf");
  err := Besm2Spawn.Detached(a, p);
  Check.Check((err = Besm2Spawn.ENOENT) & (p.pid = 0), "Detached: a missing program is ENOENT, and no process");
  Check.Check(Ropes.EqualString(Besm2Spawn.ErrorText(err), "No such file or directory"), "ErrorText: ENOENT's text");
  Check.Check(~Besm2Spawn.Alive(p) & ~Besm2Spawn.Terminate(p), "a failed start is neither alive nor terminated");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "/etc/passwd");
  Check.Check(Besm2Spawn.Detached(a, p) # 0, "Detached: a file that isn't a program fails");
  Besm2Spawn.Clear(a);
  Check.Check(Besm2Spawn.Detached(a, p) = Besm2Spawn.EINVAL, "Detached: no program at all is EINVAL");

  (* ---- Arguments arriving exactly ---- *)
  log := Log; err := Platform.Unlink(log);
  Besm2Spawn.Clear(a);
  Besm2Spawn.Add(a, Viewer);
  Besm2Spawn.Add(a, "-p"); Besm2Spawn.Add(a, "62"); Besm2Spawn.Add(a, Odd);
  Besm2Spawn.Add(a, ""); Besm2Spawn.Add(a, "$HOME *.pdf; `x` %f|&");
  err := Besm2Spawn.Detached(a, p);
  Check.Check((err = 0) & (p.pid > 0), "Detached: the fake viewer starts");
  Check.Check(WaitFor(Log), "the fake viewer wrote its record");
  out := Contents(Log);
  want := Ropes.FromString("argc 5");
  ok := Ropes.Equal(Line(out, 0), want)
    & Ropes.EqualString(Line(out, 1), "arg <-p>")
    & Ropes.EqualString(Line(out, 2), "arg <62>")
    & Ropes.EqualString(Line(out, 3), "arg </tmp/an O'Brien book.pdf>")
    & Ropes.EqualString(Line(out, 4), "arg <>")
    & Ropes.EqualString(Line(out, 5), "arg <$HOME *.pdf; `x` %f|&>");
  Check.Check(ok, "the arguments arrive exactly: a blank, a ', an empty one, shell characters");

  (* ---- Its own session, no terminal, no zombie ---- *)
  line := Line(out, 6);
  Check.Check((Field(line, 3) > 0) & (Field(line, 3) # Besm2Spawn.Session(Platform.PID))
    & (Field(line, 3) = Besm2Spawn.Session(p.pid)), "the viewer is in a session of its own");
  Check.Check((Field(line, 1) > 0) & (Field(line, 1) # Platform.PID), "the viewer isn't our child");
  Check.Check(Ropes.EqualString(Line(out, 7), "tty ?"), "the viewer has no terminal");
  Check.Check(Ropes.EqualString(Line(out, 8), "fds /dev/null /dev/null /dev/null"),
    "the viewer's standard input, output and error are /dev/null");
  Check.Check(Zombies() = 0, "no zombie is left behind");

  (* ---- Alive and Terminate ---- *)
  Check.Check(Besm2Spawn.Alive(p), "Alive: the viewer is running");
  i := p.pid;
  Check.Check(Besm2Spawn.Terminate(p) & (p.pid = 0), "Terminate: ends it, and the record is none");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "true");
  err := Besm2Spawn.Detached(a, p);
  Check.Check((err = 0) & WaitEnd(p), "a program that ends by itself is no longer Alive");
  Check.Check(~Besm2Spawn.Terminate(p), "Terminate: false for one already ended");
  n := 0;
  WHILE (Besm2Spawn.Session(i) # -1) & (n < 100) DO Platform.Delay(50); INC(n) END;
  Check.Check(Besm2Spawn.Session(i) = -1, "the terminated viewer is gone");

  (* ---- Capture ---- *)
  Besm2Spawn.Clear(a);
  Besm2Spawn.Add(a, "sh"); Besm2Spawn.Add(a, "-c"); Besm2Spawn.Add(a, 'printf "%s|" "$@"; echo; exit 3');
  Besm2Spawn.Add(a, "sh"); Besm2Spawn.Add(a, Odd); Besm2Spawn.Add(a, "");
  err := Besm2Spawn.Capture(a, out, status);
  want := Ropes.AppendChar(Ropes.FromString("/tmp/an O'Brien book.pdf||"), 0AX);
  Check.Check((err = 0) & (status = 3) & Ropes.Equal(out, want),
    "Capture: the output and the exit status");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "seq"); Besm2Spawn.Add(a, "20000");
  err := Besm2Spawn.Capture(a, out, status);
  (* seq 1 20000's bytes: 9 of 2, 90 of 3, 900 of 4, 9000 of 5, 10001 of 6. *)
  Check.Check((err = 0) & (status = 0) & (Ropes.Length(out) = 108894)
    & Ropes.EqualString(Line(out, 19999), "20000") & (Line(out, 20000) = NIL),
    "Capture: output of many chunks, whole");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "true");
  err := Besm2Spawn.Capture(a, out, status);
  Check.Check((err = 0) & (status = 0) & (out = NIL), "Capture: no output is NIL");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "sh"); Besm2Spawn.Add(a, "-c"); Besm2Spawn.Add(a, "echo x >&2; kill -TERM $$");
  err := Besm2Spawn.Capture(a, out, status);
  Check.Check((err = 0) & (status = -1) & (out = NIL), "Capture: a signal is status -1; standard error isn't captured");
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "besm2-cg-no-such-program");
  err := Besm2Spawn.Capture(a, out, status);
  Check.Check((err = Besm2Spawn.ENOENT) & (status = -1) & (out = NIL), "Capture: a missing program is ENOENT");
  Check.Check(Zombies() = 0, "Capture leaves no zombie");

  (* ---- Too long ---- *)
  FOR i := 0 TO LEN(big) - 2 DO big[i] := "x" END; big[LEN(big) - 1] := 0X;
  Besm2Spawn.Clear(a); Besm2Spawn.Add(a, "true"); Besm2Spawn.Add(a, big);
  Check.Check((Besm2Spawn.Detached(a, p) = Besm2Spawn.E2BIG) & (Besm2Spawn.Capture(a, out, status) = Besm2Spawn.E2BIG),
    "an argument vector too long is E2BIG");

  (* ---- OnPath ---- *)
  Check.Check(Besm2Spawn.OnPath("sh") & Besm2Spawn.OnPath("/bin/sh") & Besm2Spawn.OnPath(Viewer),
    "OnPath: a program on PATH, by path, and relative");
  Check.Check(~Besm2Spawn.OnPath("besm2-cg-no-such-program") & ~Besm2Spawn.OnPath("/etc/passwd")
    & ~Besm2Spawn.OnPath(""), "OnPath: missing, not executable, empty");

  Check.Summary
END TestSpawn.
