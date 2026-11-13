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
    ConditionsList: TListBox;
    ActionsList: TListBox;
    RuleTitleLabel: TLabel;
    ConditionsLabel: TLabel;
    ActionsLabel: TLabel;
    procedure AddActionButtonClick(Sender: TObject);
    procedure AddConditionButtonClick(Sender: TObject);
    procedure ConditionKindComboChange(Sender: TObject);
    procedure DeleteItemButtonClick(Sender: TObject);
    procedure ConditionsListClick(Sender: TObject);
    procedure ActionsListClick(Sender: TObject);
  private
    FRule: TWorldRule;
    FWorld: TWorld;
    FDefaultRoom: TWorldRoom;
    function EntityNameByID(const AID: string): string;
    procedure RefreshConditionChoices;
    procedure RefreshRuleView;
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

procedure TWWRuleEditorForm.AddConditionButtonClick(Sender: TObject);
var
  LeftID, RightID: string;
begin
  if (FRule = nil) or (FWorld = nil) then Exit;
  LeftID := '';
  RightID := '';

  case ConditionKindCombo.ItemIndex of
    0:
      begin
        if ConditionRightCombo.ItemIndex < 0 then Exit;
        RightID := FWorld.Rooms[ConditionRightCombo.ItemIndex].ID;
        FRule.AddCondition(wckPlayerInRoom, '', RightID);
      end;
    1:
      begin
        if ConditionRightCombo.ItemIndex < 0 then Exit;
        RightID := FWorld.Objects[ConditionRightCombo.ItemIndex].ID;
        FRule.AddCondition(wckPlayerCarryingObject, '', RightID);
      end;
    2:
      begin
        if (ConditionLeftCombo.ItemIndex < 0) or
           (ConditionRightCombo.ItemIndex < 0) then Exit;
        LeftID := FWorld.Objects[ConditionLeftCombo.ItemIndex].ID;
        RightID := FWorld.Rooms[ConditionRightCombo.ItemIndex].ID;
        FRule.AddCondition(wckObjectInRoom, LeftID, RightID);
      end;
    3:
      begin
        if ConditionLeftCombo.ItemIndex < 0 then Exit;
        LeftID := FWorld.Objects[ConditionLeftCombo.ItemIndex].ID;
        FRule.AddCondition(wckObjectCarried, LeftID, '');
      end;
    else
      Exit;
  end;
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

end.
