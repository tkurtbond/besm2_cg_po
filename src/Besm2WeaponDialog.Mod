MODULE Besm2WeaponDialog; (* The Weapon Attack dialog: its Level, Abilities, Disabilities, primary, damage and points *)

(* PLAN.md, Part B, step 8, after ova_cg_po's OvaAttackDialog.  A Weapon
   Attack (p. 81) of the entity shown: its subject and details, its
   Level, whether it is the primary attack and has a different gunner
   (p. 82), and its Weapon Abilities (p. 83) and Disabilities (p. 89),
   each a Besm2Widgets.Panel: a line a name ("Melee x2 (sword)", a tab,
   "2 slots", a tab, both its pages), the Choice of names, the Spinner
   for the slots it counts as in all (A4's `counts-as`; it starts at
   the name's slots taken once, and is saved only when it differs), and
   the text field for its detail.  Under them its damage and points,
   each with its override box, and its warnings.

   The dialog changes the model as the user works, and changed, the
   window's, computes every entity again and shows them, so the numbers
   it shows are Besm2Calc's; Cancel puts back what was there when it
   opened.  The subject and details are taken on OK.  It doesn't wait:
   Edit shows it, and OK or Cancel calls done.  Personal Gear (p. 83)
   isn't offered: A4 has no key for it. *)

IMPORT Fl, FlBrowsers, FlButtons, FlInputs, FlValuators, C := Besm2Calc, Ch := Besm2Character,
  R := Besm2Rules, Besm2Text, Besm2Warnings, Besm2Widgets, Ropes;

CONST
  Width = 760; Height = 640; Row = 25; Gap = 5;
  PanelW = 365; PanelH = 200;
  MaxSlots = 99;
  SlotsW = 70; PageW = 125;
  (* Number.which *)
  Damage = 0; Points = 1;

TYPE
  Rope = Ropes.Rope;
  Mods = POINTER TO ARRAY OF Ch.Mod;

  (* The Abilities' or the Disabilities' list and editor. *)
  ModPanel = POINTER TO RECORD (Besm2Widgets.PanelDesc)
    ability: BOOLEAN;
    shown: Mods;  (* shown[i]: line i + 1's *)
    n: INTEGER
  END;

  (* The attack's damage or points. *)
  Number = POINTER TO RECORD (Besm2Widgets.TargetDesc) which: INTEGER END;

  Flags = POINTER TO ARRAY OF BOOLEAN;

VAR
  dialog-: Fl.DoubleWindow;  (* NIL when closed *)
  title-: Fl.Box;
  help-: Besm2Widgets.HelpButton;
  level-: FlValuators.Spinner;
  subjectIn-, detailsIn-: FlInputs.Input;
  primary-, gunner-: FlButtons.CheckButton;
  abilities-, disabilities-: ModPanel;
  damage-, points-: Besm2Widgets.NumberBox;
  warnings-: FlBrowsers.Browser;
  ok-, cancel-: FlButtons.Button;

  entity-: Ch.Entity;
  attr-: Ch.Attr;  (* what is edited *)
  saved: Ch.AttrDesc;
  savedAbilities, savedDisabilities: C.Mod;
  savedPrimary: Flags;  (* each of the entity's Attributes' primary, in order *)
  titleText: ARRAY 64 OF CHAR;
  done: PROCEDURE (changed: BOOLEAN);

  (* Shows a message: the window's. *)
  tell*: PROCEDURE (text: Rope);
  (* Computes every entity again and shows them, after a change: the
     window's. *)
  changed*: PROCEDURE;

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: Fl.String;
BEGIN s := i.Text(); RETURN Besm2Text.Trim(Ropes.FromString(s^))
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); i.SetValue(s^)
END SetInput;

(* How many of the entity's Attributes are Weapon Attacks. *)
PROCEDURE Weapons(): INTEGER;
  VAR a: C.Attr; n: INTEGER;
BEGIN
  n := 0; a := entity.attrs;
  WHILE a # NIL DO IF a.weapon THEN INC(n) END; a := a.next END;
  RETURN n
END Weapons;

(* The attack's numbers, flags and warnings, as computed. *)
PROCEDURE ShowNumbers;
  VAR w: C.Warning; s: Besm2Text.String;
BEGIN
  damage.Display; points.Display;
  primary.SetValue(attr.isPrimary);
  IF Weapons() > 1 THEN primary.Activate ELSE primary.Deactivate END;
  gunner.SetValue(attr.differentGunner);
  warnings.Clear;
  w := entity.warnings;
  WHILE w # NIL DO
    IF w.attr = attr THEN s := Besm2Text.Chars(Besm2Warnings.Text(entity, w)); warnings.Add(s^) END;
    w := w.next
  END
END ShowNumbers;

PROCEDURE Recompute;
BEGIN
  IF changed # NIL THEN changed END;
  ShowNumbers
END Recompute;

(* ---- Numbers ---- *)

PROCEDURE (t: Number) Get*(VAR n: C.Number);
BEGIN IF t.which = Damage THEN n := attr.damage ELSE n := attr.points END
END Get;

PROCEDURE (t: Number) Put*(VAR n: C.Number);
BEGIN IF t.which = Damage THEN attr.damage := n ELSE attr.points := n END
END Put;

PROCEDURE NumberChanged(b: Besm2Widgets.NumberBox; ok: BOOLEAN);
  VAR msg: Rope;
BEGIN
  IF ~ok THEN
    msg := Rp("Not a number for the ");
    IF b = damage THEN Besm2Text.Add(msg, "damage") ELSE Besm2Text.Add(msg, "points") END;
    Besm2Text.Add(msg, ": a whole number. The computed number is used.");
    tell(msg)
  END;
  Recompute
END NumberChanged;

PROCEDURE NumberBox(VAR b: Besm2Widgets.NumberBox; which, x, y: INTEGER; label: ARRAY OF CHAR);
  VAR t: Number;
BEGIN
  NEW(b); Besm2Widgets.OpenNumberBox(b, x, y, label);
  NEW(t); t.which := which; b.target := t;
  b.changed := NumberChanged
END NumberBox;

(* ---- The Abilities and Disabilities ---- *)

PROCEDURE (p: ModPanel) List(): C.Mod;
BEGIN IF p.ability THEN RETURN attr.abilities ELSE RETURN attr.disabilities END
END List;

PROCEDURE (p: ModPanel) Fill*;
  VAR m: C.Mod; x: Ch.Mod; line: Rope; page: ARRAY 32 OF CHAR; s: Besm2Text.String;
BEGIN
  p.n := 0; m := p.List();
  WHILE m # NIL DO INC(p.n); m := m.next END;
  NEW(p.shown, p.n + 1);
  p.n := 0; m := p.List();
  WHILE m # NIL DO
    x := m(Ch.Mod); p.shown[p.n] := x; INC(p.n);
    IF Besm2Text.Trim(x.name) = NIL THEN line := Rp('""') ELSE line := Besm2Text.Trim(x.name) END;
    IF C.Times(x) > 1 THEN Besm2Text.Add(line, " x"); Besm2Text.AddInt(line, C.Times(x)) END;
    IF x.hasDetail THEN Besm2Text.Add(line, " ("); line := Ropes.Cat(line, x.detail); Besm2Text.Add(line, ")") END;
    line := Ropes.AppendChar(line, 9X);
    Besm2Text.AddInt(line, x.slots);
    IF x.slots = 1 THEN Besm2Text.Add(line, " slot") ELSE Besm2Text.Add(line, " slots") END;
    line := Ropes.AppendChar(line, 9X);
    IF x.item # NIL THEN R.PageText(x.item, page); Besm2Text.Add(line, page) END;
    s := Besm2Text.Chars(line); p.browser.Add(s^);
    m := m.next
  END
END Fill;

PROCEDURE (p: ModPanel) LineOf(m: C.Mod): INTEGER;
  VAR i: INTEGER; l: C.Mod;
BEGIN
  i := 1; l := p.List();
  WHILE (l # NIL) & (l # m) DO INC(i); l := l.next END;
  RETURN i
END LineOf;

(* The ? button turns to the name's page, or its kind's for none; the
   slots start at the name's, taken once. *)
PROCEDURE (p: ModPanel) Chosen*;
  VAR it: R.Item;
BEGIN
  p.Chosen^;
  it := p.Item();
  IF it = NIL THEN
    IF p.ability THEN p.help.page := R.WeaponAbilitiesPage ELSE p.help.page := R.WeaponDisabilitiesPage END
  ELSIF entity # NIL THEN p.spinner.SetValue(C.OnceSlots(entity, it))
  END
END Chosen;

PROCEDURE (p: ModPanel) Load*(line: INTEGER);
  VAR m: Ch.Mod;
BEGIN
  m := p.shown[line - 1];
  p.Choose(m.item);
  p.spinner.SetValue(m.slots);
  SetInput(p.text, m.detail)
END Load;

PROCEDURE (p: ModPanel) Slots(): INTEGER;
BEGIN RETURN SHORT(ENTIER(p.spinner.Value() + 0.5))
END Slots;

PROCEDURE (p: ModPanel) Add*(): INTEGER;
  VAR it: R.Item; m: Ch.Mod;
BEGIN
  it := p.Item();
  IF it = NIL THEN tell(Rp("Choose a name first.")); RETURN 0 END;
  m := Ch.NewMod(entity, it, p.Slots(), InputText(p.text));
  Ch.InsertMod(attr, p.ability, m);
  Recompute;
  RETURN p.LineOf(m)
END Add;

(* A name the rules don't have stays, if none is chosen. *)
PROCEDURE (p: ModPanel) Change*(line: INTEGER): INTEGER;
  VAR m: Ch.Mod;
BEGIN
  m := p.shown[line - 1];
  Ch.ChangeMod(entity, m, p.Item(), p.Slots(), InputText(p.text));
  Recompute;
  RETURN p.LineOf(m)
END Change;

PROCEDURE (p: ModPanel) Remove*(line: INTEGER): BOOLEAN;
BEGIN
  Ch.RemoveMod(attr, p.ability, p.shown[line - 1]);
  Recompute;
  p.ChooseIndex(-1); p.text.SetValue("");
  RETURN TRUE
END Remove;

PROCEDURE Panel(VAR p: ModPanel; x, y: INTEGER; ability: BOOLEAN);
  VAR widths: ARRAY 4 OF INTEGER;
BEGIN
  NEW(p); p.ability := ability; p.n := 0; NEW(p.shown, 1);
  IF ability THEN
    Besm2Widgets.OpenPanel(p, x, y, PanelW, PanelH, R.Ability, -1, 0, "Abilities", "slots", "detail")
  ELSE
    Besm2Widgets.OpenPanel(p, x, y, PanelW, PanelH, R.Disability, -1, 0, "Disabilities", "slots", "detail")
  END;
  widths[0] := PanelW - SlotsW - PageW; widths[1] := SlotsW; widths[2] := 0;
  p.browser.SetColumnWidths(widths, 3);
  p.spinner.SetBounds(1, MaxSlots); p.spinner.SetValue(1);
  p.ChooseIndex(-1)
END Panel;

(* ---- The attack's own controls ---- *)

PROCEDURE LevelAction(w: Fl.Widget);
BEGIN
  Ch.ChangeAttr(entity, attr, attr.item, SHORT(ENTIER(level.Value() + 0.5)), attr.subject, attr.details);
  Recompute
END LevelAction;

(* Marking it primary unmarks the others; unmarking it leaves the
   first of the highest Level the primary (p. 82), which may be it. *)
PROCEDURE PrimaryAction(w: Fl.Widget);
BEGIN
  Ch.SetPrimary(entity, attr, primary.Value());
  Recompute;
  IF attr.isPrimary & ~attr.primary THEN
    tell(Rp("It is still the primary: unless another is marked, the first Weapon Attack of the highest Level is."))
  END
END PrimaryAction;

PROCEDURE GunnerAction(w: Fl.Widget);
BEGIN
  attr.differentGunner := gunner.Value();
  Recompute
END GunnerAction;

(* ---- Opening and closing ---- *)

PROCEDURE Finish(isOk: BOOLEAN);
  VAR d: PROCEDURE (changed: BOOLEAN);
BEGIN
  Besm2Widgets.ClosePanel(abilities); Besm2Widgets.ClosePanel(disabilities);
  dialog.Hide; dialog.Delete;
  dialog := NIL; title := NIL; help := NIL; level := NIL; subjectIn := NIL; detailsIn := NIL;
  primary := NIL; gunner := NIL; abilities := NIL; disabilities := NIL;
  damage := NIL; points := NIL; warnings := NIL; ok := NIL; cancel := NIL;
  d := done; done := NIL;
  entity := NIL; attr := NIL; savedAbilities := NIL; savedDisabilities := NIL; savedPrimary := NIL;
  saved.next := NIL; saved.abilities := NIL; saved.disabilities := NIL;
  IF d # NIL THEN d(isOk) END
END Finish;

PROCEDURE OkAction(w: Fl.Widget);
BEGIN
  Ch.ChangeAttr(entity, attr, attr.item, attr.level, InputText(subjectIn), InputText(detailsIn));
  attr.levelIsText := saved.levelIsText & (attr.level = saved.level);
  IF attr.levelIsText THEN attr.levelText := saved.levelText END;
  IF changed # NIL THEN changed END;
  Finish(TRUE)
END OkAction;

(* Everything put back as it was. *)
PROCEDURE CancelAction(w: Fl.Widget);
  VAR next: C.Attr; a: C.Attr; i: INTEGER;
BEGIN
  next := attr.next; attr^ := saved; attr.next := next;
  attr.abilities := savedAbilities; attr.disabilities := savedDisabilities;
  i := 0; a := entity.attrs;
  WHILE (a # NIL) & (i < LEN(savedPrimary^)) DO a.primary := savedPrimary[i]; INC(i); a := a.next END;
  IF changed # NIL THEN changed END;
  Finish(FALSE)
END CancelAction;

PROCEDURE Build;
  VAR b: FlButtons.Button; y, x2: INTEGER;
BEGIN
  NEW(dialog); Fl.OpenDoubleWindow(dialog, Width, Height, "Weapon Attack");
  NEW(title); Fl.OpenBox(title, 10, 10, 300, Row, titleText);
  title.SetAlign(Fl.AlignLeft + Fl.AlignInside); title.SetLabelFont(Fl.Bold);
  NEW(help); Besm2Widgets.OpenHelpButton(help, 315, 10, attr.item.page);
  NEW(level); FlValuators.OpenSpinner(level, 420, 10, 60, Row, "Level");
  level.SetBounds(1, 99); level.SetStep(1); level.action := LevelAction;
  NEW(subjectIn); FlInputs.OpenInput(subjectIn, 70, 40, 300, Row, "subject");
  NEW(detailsIn); FlInputs.OpenInput(detailsIn, 440, 40, Width - 450, Row, "details");
  NEW(primary); FlButtons.OpenCheckButton(primary, 10, 70, 200, Row, "the primary attack");
  primary.action := PrimaryAction;
  NEW(gunner); FlButtons.OpenCheckButton(gunner, 220, 70, 260, Row, "a different gunner (a mecha's)");
  gunner.action := GunnerAction;
  x2 := 10 + PanelW + 10;
  Panel(abilities, 10, 100, TRUE);
  Panel(disabilities, x2, 100, FALSE);
  y := abilities.bottom + 30;
  NumberBox(damage, Damage, 10, y, "damage");
  NumberBox(points, Points, 10 + Besm2Widgets.Width + 30, y, "points");
  y := y + Row + 25;
  NEW(warnings); FlBrowsers.OpenBrowser(warnings, 10, y, Width - 20, Height - 45 - y, "Warnings");
  warnings.SetAlign(Fl.AlignTopLeft); warnings.SetFormatChar(0X);
  NEW(b); FlButtons.OpenButton(b, Width - 190, Height - 35, 85, Row, "OK"); b.action := OkAction; ok := b;
  NEW(b); FlButtons.OpenButton(b, Width - 95, Height - 35, 85, Row, "Cancel"); b.action := CancelAction; cancel := b;
  dialog.End;
  dialog.action := CancelAction;  (* the close button *)
  dialog.SetModal
END Build;

(* Edits a, a Weapon Attack of e.  done is called after OK or Cancel,
   changed TRUE for OK. *)
PROCEDURE Edit*(e: Ch.Entity; a: Ch.Attr; d: PROCEDURE (changed: BOOLEAN));
  VAR p: C.Attr; i, n: INTEGER;
BEGIN
  ASSERT(dialog = NIL); ASSERT(a.weapon);
  entity := e; attr := a; done := d;
  saved := a^;
  savedAbilities := Ch.CopyMods(a.abilities); savedDisabilities := Ch.CopyMods(a.disabilities);
  n := 0; p := e.attrs; WHILE p # NIL DO INC(n); p := p.next END;
  NEW(savedPrimary, n + 1);
  i := 0; p := e.attrs; WHILE p # NIL DO savedPrimary[i] := p.primary; INC(i); p := p.next END;
  R.Label(a.item, titleText);
  Build;
  level.SetValue(a.level);
  SetInput(subjectIn, a.subject); SetInput(detailsIn, a.details);
  abilities.Refresh(0); disabilities.Refresh(0);
  ShowNumbers;
  dialog.Show
END Edit;

(* For tests: OK and Cancel, as if pushed; the Level, primary and
   different gunner as if set. *)
PROCEDURE Ok*;
BEGIN OkAction(ok)
END Ok;

PROCEDURE Cancel*;
BEGIN CancelAction(cancel)
END Cancel;

PROCEDURE SetLevel*(n: INTEGER);
BEGIN level.SetValue(n); LevelAction(level)
END SetLevel;

PROCEDURE SetPrimary*(on: BOOLEAN);
BEGIN primary.SetValue(on); PrimaryAction(primary)
END SetPrimary;

PROCEDURE SetGunner*(on: BOOLEAN);
BEGIN gunner.SetValue(on); GunnerAction(gunner)
END SetGunner;

BEGIN
  dialog := NIL; done := NIL; tell := NIL; changed := NIL; entity := NIL; attr := NIL
END Besm2WeaponDialog.
