MODULE TestPaths; (* Besm2Paths: normalizing, absolute and relative paths, and rebasing a portrait's *)

(* Paths are text alone here, so these need no files and no display. *)

IMPORT Check, Besm2Paths, Besm2Text, Out, Platform, Ropes;

TYPE Rope = Ropes.Rope;

VAR cwd: Rope;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN IF s = "" THEN RETURN NIL ELSE RETURN Ropes.FromString(s) END
END R;

PROCEDURE Is(r: Rope; s: ARRAY OF CHAR; label: ARRAY OF CHAR);
  VAR x: Besm2Text.String;
BEGIN
  Check.Check(Ropes.EqualString(r, s), label);
  IF ~Ropes.EqualString(r, s) THEN x := Besm2Text.Chars(r); Out.String("    got: "); Out.String(x^); Out.Ln END
END Is;

BEGIN
  cwd := Ropes.FromString(Platform.CWD);

  Is(Besm2Paths.Normalize(R("a/./b//../c/")), "a/c", "Normalize: . and doubled / dropped, .. takes out a name");
  Is(Besm2Paths.Normalize(R("/../a/..")), "/", "Normalize: .. at the root stays at the root");
  Is(Besm2Paths.Normalize(R("../../a")), "../../a", "Normalize: a relative path's leading .. kept");
  Is(Besm2Paths.Normalize(R("a/..")), ".", "Normalize: nothing left is .");

  Is(Besm2Paths.Absolute(R("images/a.png"), R("/home/u/chars")), "/home/u/chars/images/a.png",
    "Absolute: against the base");
  Is(Besm2Paths.Absolute(R("../a.png"), R("/home/u/chars")), "/home/u/a.png", "Absolute: .. out of the base");
  Is(Besm2Paths.Absolute(R("/x/y.png"), R("/home/u")), "/x/y.png", "Absolute: an absolute path is itself");
  Check.Check(Ropes.Equal(Besm2Paths.Absolute(R("a.png"), NIL), Ropes.Cat(Ropes.AppendChar(cwd, "/"), R("a.png"))),
    "Absolute: no base is the working directory");
  Check.Check(Besm2Paths.Absolute(NIL, R("/a")) = NIL, "Absolute: NIL is NIL");

  Is(Besm2Paths.Dir(R("/home/u/chars/hana.yaml")), "/home/u/chars", "Dir: the file's directory");
  Is(Besm2Paths.Dir(R("/hana.yaml")), "/", "Dir: at the root");
  Check.Check(Ropes.Equal(Besm2Paths.Dir(R("hana.yaml")), cwd), "Dir: of a relative name, the working directory");

  Is(Besm2Paths.Relative(R("/home/u/chars/images/a.png"), R("/home/u/chars")), "images/a.png", "Relative: below");
  Is(Besm2Paths.Relative(R("/home/u/pics/a.png"), R("/home/u/chars")), "../pics/a.png", "Relative: beside");
  Is(Besm2Paths.Relative(R("/x/a.png"), R("/home/u/chars")), "../../../x/a.png", "Relative: all the way up");
  Is(Besm2Paths.Relative(R("/home/u/chars"), R("/home/u/chars")), ".", "Relative: the directory itself");
  Is(Besm2Paths.Relative(R("/home/u/charsx/a.png"), R("/home/u/chars")), "../charsx/a.png",
    "Relative: a name's prefix isn't a directory");

  Is(Besm2Paths.Rebase(R("images/a.png"), R("/home/u/chars"), R("/home/u/backup")), "../chars/images/a.png",
    "Rebase: the file moved, the image didn't");
  Is(Besm2Paths.Rebase(R("/home/u/pics/a.png"), NIL, R("/home/u/chars")), "../pics/a.png",
    "Rebase: an absolute path, on the first save");
  Is(Besm2Paths.Rebase(R("a.png"), NIL, R("/home/u")), "a.png", "Rebase: a relative path with no from stays");
  Check.Check(Besm2Paths.Rebase(NIL, R("/a"), R("/b")) = NIL, "Rebase: no portrait, none");

  Check.Summary
END TestPaths.
