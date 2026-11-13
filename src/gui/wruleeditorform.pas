unit WRuleEditorForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, WWorld;

type
  { TWWRuleEditorForm is the focused authoring surface for one neutral
    WorldWright rule. Static layout is designer-owned in wruleeditorform.lfm.
    The form edits TWorldRule semantics only; it never stores Pascal, Inform,
    or TADS source. }
  TWWRuleEditorForm = class(TForm)
    AddActionButton: TButton;
    AddConditionButton: TButton;
    ConditionKindCombo: TComboBox;
    ConditionLeftCombo: TComboBox;
    ConditionRightCombo: TComboBox;
    CloseButton: TButton;
    DeleteItemButton: TButton;
    EditItemButton: TButton;
    MoveUpButton: TButton;
    MoveDownButton: TButton;
    ConditionsList: TListBox;
    ActionsList: TListBox;
    RuleTitleLabel: TLabel;
    ConditionsLabel: TLabel;
    ActionsLabel: TLabel;
    procedure AddActionButtonClick(Sender: TObject);
    procedure AddConditionButtonClick(Sender: TObject);
    procedure ConditionKindComboChange(Sender: TObject);
    procedure DeleteItemButtonClick(Sender: TObject);
    procedure EditItemButtonClick(Sender: TObject);
    procedure MoveUpButtonClick(Sender: TObject);
    procedure MoveDownButtonClick(Sender: TObject);
    procedure ConditionsListClick(Sender: TObject);
    procedure ActionsListClick(Sender: TObject);
  private
    FRule: TWorldRule;
    FWorld: TWorld;
    FDefaultRoom: TWorldRoom;
    function EntityNameByID(const AID: string): string;
    procedure RefreshConditionChoices;
    procedure RefreshRuleView;
    procedure MoveSelected(ADirection: Integer);
    function ConditionConflict(AKind: TWorldConditionKind;
      const ALeftID, ARightID: string; AEditing: TWorldCondition): string;
  public
    procedure EditRule(AWorld: TWorld; ARule: TWorldRule;
      ADefaultRoom: TWorldRoom);
  end;

implementation

{$R *.lfm}

function TWWRuleEditorForm.EntityNameByID(const AID: string): string;
var
  Room: TWorldRoom;
  WorldObject: TWorldObject;
begin
  Result := '[' + AID + ']';
  for Room in FWorld.Rooms do
    if SameText(Room.ID, AID) then Exit(Room.Name);
  for WorldObject in FWorld.Objects do
    if SameText(WorldObject.ID, AID) then Exit(WorldObject.Name);
end;

{ Rebuild the two selection lists from authored rule data. The list indices
  correspond directly to their respective model collections; they are never
  interpreted as a combined numbered list. }
procedure TWWRuleEditorForm.RefreshRuleView;
var
  I: Integer;
  Condition: TWorldCondition;
  RuleAction: TWorldAction;
  ConditionText, ActionText: string;
begin
  ConditionsList.Items.Clear;
  ActionsList.Items.Clear;
  if FRule = nil then Exit;
  RuleTitleLabel.Caption := FRule.Name + ' [' + FRule.ID + ']';
  for I := 0 to FRule.Conditions.Count - 1 do
  begin
    Condition := FRule.Conditions[I];
    case Condition.Kind of
      wckPlayerInRoom:
        ConditionText := 'Player is in ' + EntityNameByID(Condition.RightOperand);
      wckPlayerCarryingObject:
        ConditionText := 'Player is carrying ' + EntityNameByID(Condition.RightOperand);
      wckObjectInRoom:
        ConditionText := EntityNameByID(Condition.LeftOperand) + ' is in ' +
          EntityNameByID(Condition.RightOperand);
      wckObjectCarried:
        ConditionText := EntityNameByID(Condition.LeftOperand) + ' is carried';
    end;
    ConditionsList.Items.Add(ConditionText);
  end;
  for I := 0 to FRule.Actions.Count - 1 do
  begin
    RuleAction := FRule.Actions[I];
    case RuleAction.Kind of
      wakSay: ActionText := 'Say "' + RuleAction.Value + '"';
    end;
    ActionsList.Items.Add(ActionText);
  end;
end;

procedure TWWRuleEditorForm.ConditionsListClick(Sender: TObject);
begin
  if ConditionsList.ItemIndex >= 0 then ActionsList.ItemIndex := -1;
end;

procedure TWWRuleEditorForm.ActionsListClick(Sender: TObject);
begin
  if ActionsList.ItemIndex >= 0 then ConditionsList.ItemIndex := -1;
end;

procedure TWWRuleEditorForm.EditRule(AWorld: TWorld; ARule: TWorldRule;
  ADefaultRoom: TWorldRoom);
begin
  if ARule = nil then
    Exit;
  FWorld := AWorld;
  FRule := ARule;
  FDefaultRoom := ADefaultRoom;
  Caption := 'Rule Editor - ' + FRule.Name;
  ConditionKindCombo.ItemIndex := 0;
  RefreshConditionChoices;
  RefreshRuleView;
  ShowModal;
end;

procedure TWWRuleEditorForm.AddActionButtonClick(Sender: TObject);
var
  TextValue: string;
begin
  if FRule = nil then
    Exit;
  TextValue := '';
  if not InputQuery('Add Say Action', 'Text to say:', TextValue) then
    Exit;
  if Trim(TextValue) = '' then
    Exit;
  FRule.AddAction(wakSay, TextValue);
  RefreshRuleView;
end;

procedure TWWRuleEditorForm.RefreshConditionChoices;
var
  Room: TWorldRoom;
  WorldObject: TWorldObject;
begin
  ConditionLeftCombo.Items.Clear;
  ConditionRightCombo.Items.Clear;
  ConditionLeftCombo.Visible := True;
  ConditionRightCombo.Visible := False;

  if FWorld = nil then Exit;
  case ConditionKindCombo.ItemIndex of
    0:
      begin
        ConditionLeftCombo.Visible := False;
        ConditionRightCombo.Visible := True;
        for Room in FWorld.Rooms do ConditionRightCombo.Items.Add(Room.Name);
      end;
    1:
      begin
        ConditionLeftCombo.Visible := False;
        ConditionRightCombo.Visible := True;
        for WorldObject in FWorld.Objects do ConditionRightCombo.Items.Add(WorldObject.Name);
      end;
    2:
      begin
        ConditionRightCombo.Visible := True;
        for WorldObject in FWorld.Objects do ConditionLeftCombo.Items.Add(WorldObject.Name);
        for Room in FWorld.Rooms do ConditionRightCombo.Items.Add(Room.Name);
      end;
    3:
      for WorldObject in FWorld.Objects do ConditionLeftCombo.Items.Add(WorldObject.Name);
  end;

  if ConditionLeftCombo.Items.Count > 0 then ConditionLeftCombo.ItemIndex := 0;
  if ConditionRightCombo.Items.Count > 0 then ConditionRightCombo.ItemIndex := 0;

  { Room-valued conditions default to the play-test room the author is
    currently in. Match by stable room identity rather than display name so a
    renamed or duplicate-named room cannot select the wrong authored entity. }
  if (FDefaultRoom <> nil) and
     (ConditionKindCombo.ItemIndex in [0, 2]) then
    for Room in FWorld.Rooms do
      if Room = FDefaultRoom then
      begin
        ConditionRightCombo.ItemIndex := FWorld.Rooms.IndexOf(Room);
        Break;
      end;
end;

procedure TWWRuleEditorForm.ConditionKindComboChange(Sender: TObject);
begin
  RefreshConditionChoices;
end;

{ All current conditions are conjunctive. Reject repeated predicates and
  mutually exclusive locations before changing the authored rule. The edited
  instance is excluded so saving an unchanged condition remains valid. }
function TWWRuleEditorForm.ConditionConflict(AKind: TWorldConditionKind;
  const ALeftID, ARightID: string; AEditing: TWorldCondition): string;
var
  C: TWorldCondition;
begin
  Result := '';
  for C in FRule.Conditions do
  begin
    if C = AEditing then Continue;
    if (C.Kind = AKind) and SameText(C.LeftOperand, ALeftID) and
       SameText(C.RightOperand, ARightID) then
      Exit('This condition already exists in the rule.');

    if (AKind = wckPlayerInRoom) and (C.Kind = wckPlayerInRoom) and
       not SameText(C.RightOperand, ARightID) then
      Exit('The player cannot be in two different rooms at the same time.');

    if (AKind = wckObjectInRoom) and (C.Kind = wckObjectInRoom) and
       SameText(C.LeftOperand, ALeftID) and
       not SameText(C.RightOperand, ARightID) then
      Exit('The same object cannot be in two different rooms at the same time.');

    if (AKind = wckObjectInRoom) and (C.Kind = wckObjectCarried) and
       SameText(C.LeftOperand, ALeftID) then
      Exit('An object cannot be in a room and carried at the same time.');

    if (AKind = wckObjectCarried) and (C.Kind = wckObjectInRoom) and
       SameText(C.LeftOperand, ALeftID) then
      Exit('An object cannot be carried and in a room at the same time.');

    if (AKind = wckPlayerCarryingObject) and
       (C.Kind = wckObjectInRoom) and
       SameText(C.LeftOperand, ARightID) then
      Exit('An object cannot be carried by the player and in a room at the same time.');

    if (AKind = wckObjectInRoom) and
       (C.Kind = wckPlayerCarryingObject) and
       SameText(C.RightOperand, ALeftID) then
      Exit('An object cannot be in a room and carried by the player at the same time.');
  end;
end;

procedure TWWRuleEditorForm.AddConditionButtonClick(Sender: TObject);
var
  LeftID, RightID: string;
  Existing: TWorldCondition;
  NewKind: TWorldConditionKind;
  Conflict: string;
begin
  if (FRule = nil) or (FWorld = nil) then Exit;
  LeftID := '';
  RightID := '';
  Existing := nil;
  if (AddConditionButton.Caption = 'Update Condition') and
     (ConditionsList.ItemIndex >= 0) then
    Existing := FRule.Conditions[ConditionsList.ItemIndex];

  case ConditionKindCombo.ItemIndex of
    0:
      begin
        if ConditionRightCombo.ItemIndex < 0 then Exit;
        RightID := FWorld.Rooms[ConditionRightCombo.ItemIndex].ID;
        NewKind := wckPlayerInRoom;
      end;
    1:
      begin
        if ConditionRightCombo.ItemIndex < 0 then Exit;
        RightID := FWorld.Objects[ConditionRightCombo.ItemIndex].ID;
        NewKind := wckPlayerCarryingObject;
      end;
    2:
      begin
        if (ConditionLeftCombo.ItemIndex < 0) or
           (ConditionRightCombo.ItemIndex < 0) then Exit;
        LeftID := FWorld.Objects[ConditionLeftCombo.ItemIndex].ID;
        RightID := FWorld.Rooms[ConditionRightCombo.ItemIndex].ID;
        NewKind := wckObjectInRoom;
      end;
    3:
      begin
        if ConditionLeftCombo.ItemIndex < 0 then Exit;
        LeftID := FWorld.Objects[ConditionLeftCombo.ItemIndex].ID;
        NewKind := wckObjectCarried;
      end;
    else
      Exit;
  end;
  Conflict := ConditionConflict(NewKind, LeftID, RightID, Existing);
  if Conflict <> '' then
  begin
    MessageDlg('Invalid Condition', Conflict, mtWarning, [mbOK], 0);
    Exit;
  end;
  if Existing <> nil then
  begin
    Existing.Kind := NewKind;
    Existing.LeftOperand := LeftID;
    Existing.RightOperand := RightID;
  end
  else
    FRule.AddCondition(NewKind, LeftID, RightID);
  AddConditionButton.Caption := 'Add Condition';
  RefreshRuleView;
end;

{ Delete only an explicitly selected row. No ambiguous item-number prompt and
  no mutation when neither collection has an active selection. }
procedure TWWRuleEditorForm.DeleteItemButtonClick(Sender: TObject);
begin
  if FRule = nil then Exit;
  if ConditionsList.ItemIndex >= 0 then
    FRule.Conditions.Delete(ConditionsList.ItemIndex)
  else if ActionsList.ItemIndex >= 0 then
    FRule.Actions.Delete(ActionsList.ItemIndex)
  else
  begin
    MessageDlg('Delete Rule Item', 'Select a condition or action first.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  RefreshRuleView;
end;

{ Edit the selected semantic condition through the existing typed controls.
  The selection is identified by list index; only stable entity IDs are stored. }
procedure TWWRuleEditorForm.EditItemButtonClick(Sender: TObject);
var
  C: TWorldCondition;
  A: TWorldAction;
  Value: string;
  I: Integer;
begin
  if FRule = nil then Exit;
  if ConditionsList.ItemIndex >= 0 then
  begin
    C := FRule.Conditions[ConditionsList.ItemIndex];
    case C.Kind of
      wckPlayerInRoom: ConditionKindCombo.ItemIndex := 0;
      wckPlayerCarryingObject: ConditionKindCombo.ItemIndex := 1;
      wckObjectInRoom: ConditionKindCombo.ItemIndex := 2;
      wckObjectCarried: ConditionKindCombo.ItemIndex := 3;
    end;
    RefreshConditionChoices;
    if ConditionLeftCombo.Visible then
      for I := 0 to FWorld.Objects.Count - 1 do
        if SameText(FWorld.Objects[I].ID, C.LeftOperand) then
          ConditionLeftCombo.ItemIndex := I;
    if ConditionRightCombo.Visible then
    begin
      if ConditionKindCombo.ItemIndex in [0, 2] then
      begin
        for I := 0 to FWorld.Rooms.Count - 1 do
          if SameText(FWorld.Rooms[I].ID, C.RightOperand) then
            ConditionRightCombo.ItemIndex := I;
      end
      else
        for I := 0 to FWorld.Objects.Count - 1 do
          if SameText(FWorld.Objects[I].ID, C.RightOperand) then
            ConditionRightCombo.ItemIndex := I;
    end;
    MessageDlg('Edit Condition',
      'Choose the new values above, then use Update Condition.',
      mtInformation, [mbOK], 0);
    AddConditionButton.Caption := 'Update Condition';
  end
  else if ActionsList.ItemIndex >= 0 then
  begin
    A := FRule.Actions[ActionsList.ItemIndex];
    Value := A.Value;
    if InputQuery('Edit Say Action', 'Text to say:', Value) then
    begin
      A.Value := Value;
      RefreshRuleView;
    end;
  end;
end;

{ Preserve order within each list. Never move an action across the
  conditions/actions boundary. }
procedure TWWRuleEditorForm.MoveSelected(ADirection: Integer);
var
  I, J: Integer;
  IsCondition: Boolean;
begin
  if FRule = nil then Exit;
  IsCondition := ConditionsList.ItemIndex >= 0;
  if IsCondition then
  begin
    I := ConditionsList.ItemIndex;
    J := I + ADirection;
    if (J < 0) or (J >= FRule.Conditions.Count) then Exit;
    FRule.Conditions.Exchange(I, J);
  end
  else
  begin
    I := ActionsList.ItemIndex;
    J := I + ADirection;
    if (I < 0) or (J < 0) or (J >= FRule.Actions.Count) then Exit;
    FRule.Actions.Exchange(I, J);
  end;
  RefreshRuleView;
  if IsCondition then ConditionsList.ItemIndex := J
  else ActionsList.ItemIndex := J;
end;

procedure TWWRuleEditorForm.MoveUpButtonClick(Sender: TObject);
begin
  MoveSelected(-1);
end;

procedure TWWRuleEditorForm.MoveDownButtonClick(Sender: TObject);
begin
  MoveSelected(1);
end;

end.
