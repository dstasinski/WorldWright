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
    RuleMemo: TMemo;
    procedure AddActionButtonClick(Sender: TObject);
    procedure AddConditionButtonClick(Sender: TObject);
    procedure ConditionKindComboChange(Sender: TObject);
    procedure DeleteItemButtonClick(Sender: TObject);
  private
    FRule: TWorldRule;
    FWorld: TWorld;
    function EntityNameByID(const AID: string): string;
    procedure RefreshConditionChoices;
    procedure RefreshRuleView;
  public
    procedure EditRule(AWorld: TWorld; ARule: TWorldRule);
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

procedure TWWRuleEditorForm.RefreshRuleView;
var
  I: Integer;
  Condition: TWorldCondition;
  RuleAction: TWorldAction;
  ConditionText, ActionText: string;
begin
  RuleMemo.Clear;
  if FRule = nil then Exit;
  RuleMemo.Lines.Add('RULE: ' + FRule.Name);
  RuleMemo.Lines.Add('ID: ' + FRule.ID);
  RuleMemo.Lines.Add('');
  RuleMemo.Lines.Add('Conditions');
  if FRule.Conditions.Count = 0 then
    RuleMemo.Lines.Add('  (none)')
  else
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
      RuleMemo.Lines.Add('  ' + IntToStr(I + 1) + '. ' + ConditionText);
    end;
  RuleMemo.Lines.Add('');
  RuleMemo.Lines.Add('Actions');
  if FRule.Actions.Count = 0 then RuleMemo.Lines.Add('  (none)')
  else
    for I := 0 to FRule.Actions.Count - 1 do
    begin
      RuleAction := FRule.Actions[I];
      case RuleAction.Kind of
        wakSay: ActionText := 'Say "' + RuleAction.Value + '"';
      end;
      RuleMemo.Lines.Add('  ' + IntToStr(FRule.Conditions.Count + I + 1) +
        '. ' + ActionText);
    end;
end;

procedure TWWRuleEditorForm.EditRule(AWorld: TWorld; ARule: TWorldRule);
begin
  if ARule = nil then
    Exit;
  FWorld := AWorld;
  FRule := ARule;
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

procedure TWWRuleEditorForm.DeleteItemButtonClick(Sender: TObject);
var
  ItemText: string;
  ItemNumber, ConditionCount: Integer;
begin
  if FRule = nil then Exit;
  if (FRule.Conditions.Count = 0) and (FRule.Actions.Count = 0) then
  begin
    MessageDlg('Delete Rule Item', 'This rule has no items to delete.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  ItemText := '';
  if not InputQuery('Delete Rule Item',
    'Item number (conditions first, then actions):', ItemText) then Exit;
  if not TryStrToInt(Trim(ItemText), ItemNumber) then
  begin
    MessageDlg('Delete Rule Item', 'Enter a valid item number.',
      mtError, [mbOK], 0);
    Exit;
  end;
  ConditionCount := FRule.Conditions.Count;
  if (ItemNumber >= 1) and (ItemNumber <= ConditionCount) then
    FRule.Conditions.Delete(ItemNumber - 1)
  else if (ItemNumber > ConditionCount) and
          (ItemNumber <= ConditionCount + FRule.Actions.Count) then
    FRule.Actions.Delete(ItemNumber - ConditionCount - 1)
  else
  begin
    MessageDlg('Delete Rule Item', 'That item number does not exist.',
      mtError, [mbOK], 0);
    Exit;
  end;
  RefreshRuleView;
end;

end.
