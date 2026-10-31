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
    CloseButton: TButton;
    DeleteItemButton: TButton;
    RuleMemo: TMemo;
    procedure AddActionButtonClick(Sender: TObject);
    procedure AddConditionButtonClick(Sender: TObject);
    procedure DeleteItemButtonClick(Sender: TObject);
  private
    FRule: TWorldRule;
    FWorld: TWorld;
    function ChooseFromList(const ACaption, APrompt: string;
      AItems: TStrings; out AIndex: Integer): Boolean;
    function EntityNameByID(const AID: string): string;
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

function TWWRuleEditorForm.ChooseFromList(const ACaption, APrompt: string;
  AItems: TStrings; out AIndex: Integer): Boolean;
var
  Choice: string;
begin
  Choice := '';
  Result := InputQuery(ACaption,
    APrompt + LineEnding + AItems.Text, Choice);
  if not Result then Exit;
  if not TryStrToInt(Trim(Choice), AIndex) then Exit(False);
  Dec(AIndex);
  Result := (AIndex >= 0) and (AIndex < AItems.Count);
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

procedure TWWRuleEditorForm.AddConditionButtonClick(Sender: TObject);
var
  Kinds, Choices: TStringList;
  KindIndex, ChoiceIndex: Integer;
  Room: TWorldRoom;
  WorldObject: TWorldObject;
  LeftID, RightID: string;
begin
  if (FRule = nil) or (FWorld = nil) then Exit;
  Kinds := TStringList.Create;
  Choices := TStringList.Create;
  try
    Kinds.Add('1. Player is in room');
    Kinds.Add('2. Player is carrying object');
    Kinds.Add('3. Object is in room');
    Kinds.Add('4. Object is carried');
    if not ChooseFromList('Add Condition', 'Choose condition type:', Kinds,
      KindIndex) then Exit;

    LeftID := '';
    RightID := '';
    case KindIndex of
      0:
        begin
          for Room in FWorld.Rooms do
            Choices.Add(IntToStr(Choices.Count + 1) + '. ' + Room.Name);
          if not ChooseFromList('Add Condition', 'Choose room:', Choices,
            ChoiceIndex) then Exit;
          RightID := FWorld.Rooms[ChoiceIndex].ID;
          FRule.AddCondition(wckPlayerInRoom, '', RightID);
        end;
      1:
        begin
          for WorldObject in FWorld.Objects do
            Choices.Add(IntToStr(Choices.Count + 1) + '. ' + WorldObject.Name);
          if not ChooseFromList('Add Condition', 'Choose object:', Choices,
            ChoiceIndex) then Exit;
          RightID := FWorld.Objects[ChoiceIndex].ID;
          FRule.AddCondition(wckPlayerCarryingObject, '', RightID);
        end;
      2:
        begin
          for WorldObject in FWorld.Objects do
            Choices.Add(IntToStr(Choices.Count + 1) + '. ' + WorldObject.Name);
          if not ChooseFromList('Add Condition', 'Choose object:', Choices,
            ChoiceIndex) then Exit;
          LeftID := FWorld.Objects[ChoiceIndex].ID;
          Choices.Clear;
          for Room in FWorld.Rooms do
            Choices.Add(IntToStr(Choices.Count + 1) + '. ' + Room.Name);
          if not ChooseFromList('Add Condition', 'Choose room:', Choices,
            ChoiceIndex) then Exit;
          RightID := FWorld.Rooms[ChoiceIndex].ID;
          FRule.AddCondition(wckObjectInRoom, LeftID, RightID);
        end;
      3:
        begin
          for WorldObject in FWorld.Objects do
            Choices.Add(IntToStr(Choices.Count + 1) + '. ' + WorldObject.Name);
          if not ChooseFromList('Add Condition', 'Choose object:', Choices,
            ChoiceIndex) then Exit;
          LeftID := FWorld.Objects[ChoiceIndex].ID;
          FRule.AddCondition(wckObjectCarried, LeftID, '');
        end;
    end;
    RefreshRuleView;
  finally
    Choices.Free;
    Kinds.Free;
  end;
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
