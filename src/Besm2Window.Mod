MODULE Besm2Window; (* besm2_cg_po's main window *)

(* PLAN.md, Part B, step 0: the window and its menu bar, with File >
   Quit. The tabs come in later steps. The widgets are kept in module
   variables, so the garbage collector sees them while FLTK holds them. *)

IMPORT Fl, FlMenus;

CONST
  Title* = "BESM2ER Character Generator";
  Width = 640; Height = 800; BarHeight = 25;

TYPE
  MainWindow = POINTER TO RECORD (Fl.DoubleWindowDesc) END;

VAR
  window-: Fl.DoubleWindow;
  bar-: FlMenus.MenuBar;
  quitItem-: INTEGER;

(* File > Quit, and the window's close button: hiding the only window
   ends Fl.Run. *)
PROCEDURE Quit*(w: Fl.Widget);
BEGIN window.Hide
END Quit;

(* The window and its widgets, not yet shown. *)
PROCEDURE Build*;
  VAR main: MainWindow;
BEGIN
  NEW(main); window := main; Fl.OpenDoubleWindow(window, Width, Height, Title);
  NEW(bar); FlMenus.OpenMenuBar(bar, 0, 0, Width, BarHeight, "");
  quitItem := bar.Add("&File/&Quit", ORD("q"), Fl.Command, Quit, {});
  window.End;
  window.action := Quit
END Build;

(* Deletes the window and its widgets (for the tests). *)
PROCEDURE Close*;
BEGIN
  window.Delete;
  window := NIL; bar := NIL
END Close;

END Besm2Window.
