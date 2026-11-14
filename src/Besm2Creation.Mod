MODULE Besm2Creation; (* The Creation dialog: the campaign's numbers and options, A4's `creation` *)

(* PLAN.md, Part B, step 10, after ova_cg_po's OvaSettings.  Character >
   Creation... edits the `creation` of the character shown (of a mecha,
   its owner's, which prices it): its Character Points (p. 13), Background
   Points (p. 130), genre (Table 2-4, p. 119), the GM's Skill Points
   (p. 117), and the options: Staged Stat Cost (Table 4-7, p. 166), a
   ceiling on each Stat (p. 16) and on the Bonus Points (p. 100),
   Auto-Fire counted as 1 slot (p. 84; open question 12), and a ceiling
   and a floor on the Character Points the Stats cost in all (p. 16;
   step 10a).  Each row has
   its pages and a ? button.  A number has a check button: off, the key
   isn't written, and no limit is checked; its spinner keeps what it
   held, and one never set starts at a default (the GM's Skill Points:
   the rule's number, shown while it is off).

   Copy from takes the whole `creation`, house Skills too, from another
   character of the file (Ch.TakeCreation), so that a campaign's
   characters share it; Load Campaign... takes it from a campaign file
   (PLAN.md, A4, step 10a), or the first character of a file of
   entities, and Save Campaign... writes it as a campaign file, for the
   GM to hand the players.

   The dialog changes the model as the user works, and changed, the
   window's, computes every entity again and shows them; Cancel puts back
   the creation and the Skills' points as they were when it opened.  It
   doesn't wait: Edit shows it, and OK or Cancel calls done. *)

IMPORT Fl, FlButtons, FlMenus, FlValuators, C := Besm2Calc, Ch := Besm2Character, R := Besm2Rules,
  Besm2Save, Besm2Text, Besm2Widgets, Ropes;

CONST
  Width = 560; Height = 470; Row = 25; Gap = 8;
  LabelW = 330; SpinX = 345; SpinW = 70; HelpX = 425; Top = 40;
  (* The defaults of a number never set. *)
  DefaultCharacterPoints = 40;  (* p. 13's example campaign *)
  DefaultStatCeiling = 10;
  DefaultBonusCeiling = 8;      (* p. 100: no more than eight Defects *)
  DefaultStatPointsCeiling = 24; DefaultStatPointsFloor = 12;  (* p. 16's 12 to 24 *)
  MaxPoints = 999; MaxBackground = 3; MaxBonus = 99;
  CharacterPointsPage = 13;     (* Step 1 *)
  StatCeilingPage = 16;         (* Step 3: the GM's ceiling or floor *)
  AutoFirePage = 84;

TYPE
  Rope = Ropes.Rope;

VAR
  dialog-: Fl.DoubleWindow;  (* NIL when closed *)
  title-: Fl.Box;
  pointsOn-, skillOn-, stagedOn-, statOn-, bonusOn-, autoFireOn-,
  statPointsCeilingOn-, statPointsFloorOn-: FlButtons.CheckButton;
  pointsIn-, backgroundIn-, skillIn-, statIn-, bonusIn-,
  statPointsCeilingIn-, statPointsFloorIn-: FlValuators.Spinner;
  genre-: FlMenus.Choice;     (* entry 0: none, then Besm2Rules' genres *)
  summary-: Fl.Box;
  copyChoice-: FlMenus.Choice;  (* others[i]: entry i *)
  copyButton-, loadButton-, saveButton-, ok-, cancel-: FlButtons.Button;

  target-: Ch.Entity;  (* whose creation is edited *)
  others: Ch.Entities;  (* the file's other characters, NIL at the end *)
  (* What was there when it opened, for Cancel. *)
  savedCreation: C.Creation;
  savedKeys: SET; savedHas: BOOLEAN;
  savedSkills: Ch.SkillMarks;
  (* The keys and `creation` to keep: at open, or after a copy. *)
  baseKeys: SET; baseHas: BOOLEAN;
  showing: BOOLEAN;  (* Show is setting the controls *)
  titleText: ARRAY 96 OF CHAR;
  done: PROCEDURE (changed: BOOLEAN);

  (* Shows a message: the window's. *)
  tell*: PROCEDURE (text: Rope);
  (* Asks for a campaign file to load, or to save to if save: the
     window's. *)
  chooseCampaign*: PROCEDURE (save: BOOLEAN; VAR path: Rope): BOOLEAN;
  (* Computes every entity again and shows them, after a change: the
     window's. *)
  changed*: PROCEDURE;

PROCEDURE Rp(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END Rp;

PROCEDURE Int(s: FlValuators.Spinner): INTEGER;
BEGIN RETURN SHORT(ENTIER(s.Value() + 0.5))
END Int;

PROCEDURE Enable(w: Fl.Widget; on: BOOLEAN);
BEGIN IF on THEN w.Activate ELSE w.Deactivate END
END Enable;

(* The points as computed: "Character Points: 33 spent of 40.  Skill
   Points: 15 spent of 20." *)
PROCEDURE ShowSummary;
  VAR r: Rope; s: Besm2Text.String;
BEGIN
  r := Rp("Character Points: "); Besm2Text.AddInt(r, target.spent); Besm2Text.Add(r, " spent");
  IF target.available > 0 THEN Besm2Text.Add(r, " of "); Besm2Text.AddInt(r, target.available)
  ELSE Besm2Text.Add(r, " (no limit set)")
  END;
  Besm2Text.Add(r, ".  Skill Points: "); Besm2Text.AddInt(r, target.skillSpent);
  Besm2Text.Add(r, " spent of "); Besm2Text.AddInt(r, target.skillPoints); Besm2Text.Add(r, ".");
  s := Besm2Text.Chars(r); summary.SetLabel(s^); summary.Redraw
END ShowSummary;

(* The spinners active where their check is on; the GM's Skill Points,
   while off, the rule's number. *)
PROCEDURE ShowEnabled;
BEGIN
  Enable(pointsIn, pointsOn.Value()); Enable(skillIn, skillOn.Value());
  Enable(statIn, statOn.Value()); Enable(bonusIn, bonusOn.Value());
  Enable(statPointsCeilingIn, statPointsCeilingOn.Value()); Enable(statPointsFloorIn, statPointsFloorOn.Value());
  IF ~skillOn.Value() THEN skillIn.SetValue(target.skillPoints) END;
  ShowSummary
END ShowEnabled;

(* The controls set from the target's creation; the spinners of the
   numbers not set keep what they hold. *)
PROCEDURE Show;
  VAR c: C.Creation;
BEGIN
  showing := TRUE;
  c := target.creation;
  pointsOn.SetValue(c.characterPoints > 0);
  IF c.characterPoints > 0 THEN pointsIn.SetValue(c.characterPoints) END;
  backgroundIn.SetValue(c.backgroundPoints);
  genre.Choose(c.genre + 1);
  skillOn.SetValue(c.skillPoints # C.Unset);
  IF c.skillPoints # C.Unset THEN skillIn.SetValue(c.skillPoints) END;
  stagedOn.SetValue(c.stagedStatCost);
  statOn.SetValue(c.statCeiling > 0);
  IF c.statCeiling > 0 THEN statIn.SetValue(c.statCeiling) END;
  bonusOn.SetValue(c.bonusCeiling > 0);
  IF c.bonusCeiling > 0 THEN bonusIn.SetValue(c.bonusCeiling) END;
  autoFireOn.SetValue(c.autoFireSlots = 1);
  statPointsCeilingOn.SetValue(c.statPointsCeiling > 0);
  IF c.statPointsCeiling > 0 THEN statPointsCeilingIn.SetValue(c.statPointsCeiling) END;
  statPointsFloorOn.SetValue(c.statPointsFloor > 0);
  IF c.statPointsFloor > 0 THEN statPointsFloorIn.SetValue(c.statPointsFloor) END;
  ShowEnabled;
  showing := FALSE
END Show;

(* k with key in it if on, or if it was among the keys to keep. *)
PROCEDURE Key(VAR k: SET; key: INTEGER; on: BOOLEAN);
BEGIN
  IF on OR (key IN baseKeys) THEN INCL(k, key) ELSE EXCL(k, key) END
END Key;

(* The target's creation made from the controls, and everything
   computed again.  A number turned off is no key (no limit); an option
   turned off, or Background Points of 0, is written only if it was. *)
PROCEDURE Take;
  VAR c: C.Creation; k: SET;
BEGIN
  IF showing THEN RETURN END;
  c := target.creation; k := target.creationKeys;
  IF pointsOn.Value() THEN c.characterPoints := Int(pointsIn); INCL(k, Ch.CharacterPointsKey)
  ELSE c.characterPoints := 0; EXCL(k, Ch.CharacterPointsKey)
  END;
  c.backgroundPoints := Int(backgroundIn); Key(k, Ch.BackgroundPointsKey, c.backgroundPoints # 0);
  c.genre := genre.Value() - 1;
  IF c.genre # C.NoGenre THEN INCL(k, Ch.GenreKey) ELSE EXCL(k, Ch.GenreKey) END;
  IF skillOn.Value() THEN c.skillPoints := Int(skillIn); INCL(k, Ch.SkillPointsKey)
  ELSE c.skillPoints := C.Unset; EXCL(k, Ch.SkillPointsKey)
  END;
  c.stagedStatCost := stagedOn.Value(); Key(k, Ch.StagedStatCostKey, c.stagedStatCost);
  IF statOn.Value() THEN c.statCeiling := Int(statIn); INCL(k, Ch.StatCeilingKey)
  ELSE c.statCeiling := 0; EXCL(k, Ch.StatCeilingKey)
  END;
  IF bonusOn.Value() THEN c.bonusCeiling := Int(bonusIn); INCL(k, Ch.BonusCeilingKey)
  ELSE c.bonusCeiling := 0; EXCL(k, Ch.BonusCeilingKey)
  END;
  IF autoFireOn.Value() THEN c.autoFireSlots := 1 ELSE c.autoFireSlots := C.BookAutoFireSlots END;
  Key(k, Ch.AutoFireSlotsKey, autoFireOn.Value());
  IF statPointsCeilingOn.Value() THEN c.statPointsCeiling := Int(statPointsCeilingIn); INCL(k, Ch.StatPointsCeilingKey)
  ELSE c.statPointsCeiling := 0; EXCL(k, Ch.StatPointsCeilingKey)
  END;
  IF statPointsFloorOn.Value() THEN c.statPointsFloor := Int(statPointsFloorIn); INCL(k, Ch.StatPointsFloorKey)
  ELSE c.statPointsFloor := 0; EXCL(k, Ch.StatPointsFloorKey)
  END;
  Ch.SetCreation(target, c, k, baseHas);
  IF changed # NIL THEN changed END;
  ShowEnabled
END Take;

PROCEDURE ControlAction(w: Fl.Widget);
BEGIN Take
END ControlAction;

(* ---- Copy from ---- *)

(* The target's creation from's; what to keep is now from's. *)
PROCEDURE CopyFrom(from: Ch.Entity);
BEGIN
  Ch.TakeCreation(target, from);
  baseKeys := target.creationKeys; baseHas := target.hasCreation;
  IF changed # NIL THEN changed END;
  Show
END CopyFrom;

PROCEDURE CopyAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  i := copyChoice.Value();
  IF (i >= 0) & (i < LEN(others^)) & (others[i] # NIL) THEN CopyFrom(others[i])
  ELSE tell(Rp("There is no other character in the file to copy from."))
  END
END CopyAction;

(* The creation of a campaign file the user chooses, or of the first
   character of a file of entities. *)
PROCEDURE LoadAction(w: Fl.Widget);
  VAR p, msg: Rope; s: Besm2Text.String; from: Ch.Entity;
BEGIN
  IF (chooseCampaign # NIL) & chooseCampaign(FALSE, p) THEN
    s := Besm2Text.Chars(p);
    IF Ch.LoadCampaign(s^, from, msg) THEN CopyFrom(from) ELSE tell(msg) END
  END
END LoadAction;

(* The creation as it stands, to a campaign file the user chooses. *)
PROCEDURE SaveAction(w: Fl.Widget);
  VAR p, msg: Rope; s: Besm2Text.String;
BEGIN
  IF (chooseCampaign # NIL) & chooseCampaign(TRUE, p) THEN
    s := Besm2Text.Chars(p);
    IF ~Besm2Save.SaveCampaign(target, s^, msg) THEN tell(msg) END
  END
END SaveAction;

(* ---- Opening and closing ---- *)

PROCEDURE Finish(isOk: BOOLEAN);
  VAR d: PROCEDURE (changed: BOOLEAN);
BEGIN
  dialog.Hide; dialog.Delete;
  dialog := NIL; title := NIL; summary := NIL; genre := NIL; copyChoice := NIL;
  pointsOn := NIL; skillOn := NIL; stagedOn := NIL; statOn := NIL; bonusOn := NIL; autoFireOn := NIL;
  pointsIn := NIL; backgroundIn := NIL; skillIn := NIL; statIn := NIL; bonusIn := NIL;
  statPointsCeilingOn := NIL; statPointsFloorOn := NIL; statPointsCeilingIn := NIL; statPointsFloorIn := NIL;
  copyButton := NIL; loadButton := NIL; saveButton := NIL; ok := NIL; cancel := NIL;
  d := done; done := NIL;
  target := NIL; others := NIL; savedSkills := NIL; savedCreation.houseSkills := NIL;
  IF d # NIL THEN d(isOk) END
END Finish;

PROCEDURE OkAction(w: Fl.Widget);
BEGIN Finish(TRUE)
END OkAction;

(* Everything put back as it was. *)
PROCEDURE CancelAction(w: Fl.Widget);
BEGIN
  Ch.RestoreCreation(target, savedCreation, savedKeys, savedHas, savedSkills);
  IF changed # NIL THEN changed END;
  Finish(FALSE)
END CancelAction;

(* A row's label, name with page's pages, and its ? button. *)
PROCEDURE Label(VAR s: ARRAY OF CHAR; name: ARRAY OF CHAR; page, y: INTEGER);
  VAR h: Besm2Widgets.HelpButton;
BEGIN
  R.PageLabel(name, page, s);
  NEW(h); Besm2Widgets.OpenHelpButton(h, HelpX, y, page); h.SetTooltip(s)
END Label;

PROCEDURE Check(VAR b: FlButtons.CheckButton; name: ARRAY OF CHAR; page, y: INTEGER);
  VAR s: ARRAY 96 OF CHAR;
BEGIN
  Label(s, name, page, y);
  NEW(b); FlButtons.OpenCheckButton(b, 10, y, LabelW, Row, s); b.action := ControlAction
END Check;

PROCEDURE Spinner(VAR i: FlValuators.Spinner; lo, hi, value, y: INTEGER);
BEGIN
  NEW(i); FlValuators.OpenSpinner(i, SpinX, y, SpinW, Row, "");
  i.SetBounds(lo, hi); i.SetStep(1); i.SetValue(value); i.action := ControlAction
END Spinner;

PROCEDURE Build;
  VAR b: Fl.Box; s: ARRAY 96 OF CHAR; y, g, n: INTEGER; label: Rope; t: Besm2Text.String;
BEGIN
  NEW(dialog); Fl.OpenDoubleWindow(dialog, Width, Height, "Creation");
  NEW(title); Fl.OpenBox(title, 10, 8, Width - 20, Row, titleText);
  title.SetAlign(Fl.AlignLeft + Fl.AlignInside); title.SetLabelFont(Fl.Bold);
  y := Top;
  Check(pointsOn, "Character Points", CharacterPointsPage, y);
  Spinner(pointsIn, 1, MaxPoints, DefaultCharacterPoints, y);
  y := y + Row + Gap;
  Label(s, "Background Points", R.BackgroundPointsPage, y);
  NEW(b); Fl.OpenBox(b, 10, y, LabelW, Row, s); b.SetAlign(Fl.AlignLeft + Fl.AlignInside);
  Spinner(backgroundIn, 0, MaxBackground, 0, y);
  y := y + Row + Gap;
  Label(s, "Genre, Table 2-4", R.SkillCostsPage, y);
  NEW(b); Fl.OpenBox(b, 10, y, LabelW - 120, Row, s); b.SetAlign(Fl.AlignLeft + Fl.AlignInside);
  NEW(genre); FlMenus.OpenChoice(genre, LabelW - 110, y, 195, Row, "");
  genre.AddText("(none)", NIL, {});
  FOR g := 0 TO R.NGenres - 1 DO
    R.GenreName(g, s);
    genre.AddText(s, NIL, {})
  END;
  genre.action := ControlAction;
  y := y + Row + Gap;
  Check(skillOn, "The GM's Skill Points", R.SkillsPage, y);
  Spinner(skillIn, 0, MaxPoints, 0, y);
  y := y + Row + Gap;
  Check(stagedOn, "Staged Stat Cost, Table 4-7", R.StagedStatCostPage, y);
  y := y + Row + Gap;
  Check(statOn, "A ceiling on each Stat", StatCeilingPage, y);
  Spinner(statIn, 1, C.MaxStat, DefaultStatCeiling, y);
  y := y + Row + Gap;
  Check(bonusOn, "A ceiling on the Bonus Points", R.DefectsPage, y);
  Spinner(bonusIn, 1, MaxBonus, DefaultBonusCeiling, y);
  y := y + Row + Gap;
  Check(autoFireOn, "Auto-Fire counts as 1 slot", AutoFirePage, y);
  y := y + Row + Gap;
  Check(statPointsCeilingOn, "A ceiling on the Stats' total cost", StatCeilingPage, y);
  Spinner(statPointsCeilingIn, 1, MaxPoints, DefaultStatPointsCeiling, y);
  y := y + Row + Gap;
  Check(statPointsFloorOn, "A floor on the Stats' total cost", StatCeilingPage, y);
  Spinner(statPointsFloorIn, 1, MaxPoints, DefaultStatPointsFloor, y);
  y := y + Row + Gap;
  NEW(summary); Fl.OpenBox(summary, 10, y, Width - 20, Row, "");
  summary.SetAlign(Fl.AlignLeft + Fl.AlignInside);
  y := y + Row + Gap;
  NEW(copyChoice); FlMenus.OpenChoice(copyChoice, 90, y, 250, Row, "Copy from");
  n := 0;
  WHILE others[n] # NIL DO
    label := Besm2Text.Trim(others[n].name);
    IF label = NIL THEN label := Rp("(no name)") END;
    t := Besm2Text.Chars(label); copyChoice.AddText(t^, NIL, {});
    INC(n)
  END;
  IF n > 0 THEN copyChoice.Choose(0) END;
  NEW(copyButton); FlButtons.OpenButton(copyButton, 345, y, 70, Row, "Copy");
  copyButton.action := CopyAction;
  copyButton.SetTooltip("the whole creation, house Skills too, of the character chosen");
  IF n = 0 THEN copyChoice.Deactivate; copyButton.Deactivate END;
  y := y + Row + Gap;
  NEW(loadButton); FlButtons.OpenButton(loadButton, 10, y, 150, Row, "Load Campaign...");
  loadButton.action := LoadAction;
  loadButton.SetTooltip("the whole creation of a campaign file, or of the first character of a file");
  NEW(saveButton); FlButtons.OpenButton(saveButton, 170, y, 150, Row, "Save Campaign...");
  saveButton.action := SaveAction;
  saveButton.SetTooltip("the whole creation, as a campaign file to hand the players");
  NEW(ok); FlButtons.OpenButton(ok, Width - 190, Height - 35, 85, Row, "OK"); ok.action := OkAction;
  NEW(cancel); FlButtons.OpenButton(cancel, Width - 95, Height - 35, 85, Row, "Cancel"); cancel.action := CancelAction;
  dialog.End;
  dialog.action := CancelAction;  (* the close button *)
  dialog.SetModal
END Build;

(* Edits the creation of e, or of its owner if e is a mecha (which
   must have one); es is the file's entities, the others of which may
   be copied from.  done is called after OK or Cancel, changed TRUE for
   OK. *)
PROCEDURE Edit*(e: Ch.Entity; es: Ch.Entities; d: PROCEDURE (changed: BOOLEAN));
  VAR i: LONGINT; n: INTEGER; r: Rope;
BEGIN
  ASSERT(dialog = NIL);
  IF e.isMecha THEN ASSERT(e.owner # NIL); target := e.owner(Ch.Entity) ELSE target := e END;
  done := d;
  savedCreation := target.creation; savedKeys := target.creationKeys; savedHas := target.hasCreation;
  savedSkills := Ch.SaveSkills(target);
  baseKeys := savedKeys; baseHas := savedHas;
  NEW(others, LEN(es^) + 1); n := 0;
  FOR i := 0 TO LEN(es^) - 1 DO
    IF (es[i] # target) & ~es[i].isMecha THEN others[n] := es[i]; INC(n) END
  END;
  others[n] := NIL;
  r := Rp("The creation of ");
  IF Besm2Text.Trim(target.name) = NIL THEN Besm2Text.Add(r, "the character (no name)")
  ELSE r := Ropes.Cat(r, Besm2Text.Trim(target.name))
  END;
  IF e.isMecha THEN Besm2Text.Add(r, ", which prices the mecha") END;
  Ropes.ToString(r, titleText);
  Build;
  Show;
  dialog.Show
END Edit;

(* For tests: OK and Cancel, as if pushed; each control as if set;
   Copy from the other character n (0: the first), Load Campaign...
   and Save Campaign.... *)
PROCEDURE Ok*;
BEGIN OkAction(ok)
END Ok;

PROCEDURE Cancel*;
BEGIN CancelAction(cancel)
END Cancel;

PROCEDURE SetNumber(b: FlButtons.CheckButton; i: FlValuators.Spinner; on: BOOLEAN; n: INTEGER);
BEGIN
  showing := TRUE; b.SetValue(on); IF on THEN i.SetValue(n) END; showing := FALSE;
  Take
END SetNumber;

(* on FALSE: no Character Points, so no limit; n is then ignored. *)
PROCEDURE SetCharacterPoints*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(pointsOn, pointsIn, on, n)
END SetCharacterPoints;

PROCEDURE SetBackgroundPoints*(n: INTEGER);
BEGIN backgroundIn.SetValue(n); Take
END SetBackgroundPoints;

(* g: a Besm2Rules genre, or C.NoGenre. *)
PROCEDURE SetGenre*(g: INTEGER);
BEGIN genre.Choose(g + 1); Take
END SetGenre;

PROCEDURE SetSkillPoints*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(skillOn, skillIn, on, n)
END SetSkillPoints;

PROCEDURE SetStaged*(on: BOOLEAN);
BEGIN stagedOn.SetValue(on); Take
END SetStaged;

PROCEDURE SetStatCeiling*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(statOn, statIn, on, n)
END SetStatCeiling;

PROCEDURE SetBonusCeiling*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(bonusOn, bonusIn, on, n)
END SetBonusCeiling;

PROCEDURE SetAutoFireOne*(on: BOOLEAN);
BEGIN autoFireOn.SetValue(on); Take
END SetAutoFireOne;

PROCEDURE Copy*(n: INTEGER);
BEGIN copyChoice.Choose(n); CopyAction(copyButton)
END Copy;

PROCEDURE SetStatPointsCeiling*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(statPointsCeilingOn, statPointsCeilingIn, on, n)
END SetStatPointsCeiling;

PROCEDURE SetStatPointsFloor*(on: BOOLEAN; n: INTEGER);
BEGIN SetNumber(statPointsFloorOn, statPointsFloorIn, on, n)
END SetStatPointsFloor;

PROCEDURE LoadCampaign*;
BEGIN LoadAction(loadButton)
END LoadCampaign;

PROCEDURE SaveCampaign*;
BEGIN SaveAction(saveButton)
END SaveCampaign;

BEGIN
  dialog := NIL; done := NIL; tell := NIL; chooseCampaign := NIL; changed := NIL; target := NIL; others := NIL;
  showing := FALSE
END Besm2Creation.
