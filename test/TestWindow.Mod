MODULE TestWindow; (* Besm2Window: the window and File > Quit *)

(* Needs a display: run by make test-gui, under make test-headless or
   make test-sway (AGENTS.md: never on the desktop). The menu item is
   picked, as ova_cg_po's TestWindow does, so Quit is checked on
   Wayland too, where test/quit.sh can't send keys. *)

IMPORT Check, Fl, FlMenus, Besm2Window;

VAR
  i, key: INTEGER;
  state: SET;
  label: ARRAY 64 OF CHAR;

BEGIN
  Besm2Window.Build;
  Check.Check(Besm2Window.window.IsOpen() & ~Besm2Window.window.Shown(), "the window opens, not shown until asked");
  Besm2Window.window.GetLabel(label);
  Check.Check(label = Besm2Window.Title, "the window's title");
  i := Besm2Window.bar.FindIndex("&File/&Quit");
  Check.Check((i >= 0) & (i = Besm2Window.quitItem), "the menu bar has File > Quit");
  Besm2Window.bar.ItemShortcut(i, key, state);
  Check.Check((key = ORD("q")) & (state = Fl.Command), "File > Quit's shortcut is Ctrl+Q");
  Besm2Window.window.Show;
  Check.Check(Besm2Window.window.Shown(), "Show shows it");
  Besm2Window.bar.Pick(Besm2Window.quitItem);
  Check.Check(~Besm2Window.window.Shown(), "File > Quit hides it, which ends Fl.Run");
  Besm2Window.window.Show;
  Besm2Window.window.DoCallback;
  Check.Check(~Besm2Window.window.Shown(), "so does the close button");
  Besm2Window.Close;
  Check.Check(Besm2Window.window = NIL, "Close deletes it");
  Check.Summary
END TestWindow.
