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
    procedure RefreshRuleView;
  public
    procedure EditRule(ARule: TWorldRule);
  end;

implementation

{$R *.lfm}

procedure TWWRuleEditorForm.RefreshRuleView;
var
  I: Integer;
  Condition: TWorldCondition;
  RuleAction: TWorldAction;
  OperatorText, ActionText: string;
begin
  RuleMemo.Clear;
  if FRule = nil then
    Exit;

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
        wckEquals: OperatorText := '=';
        wckNotEquals: OperatorText := '<>';
      end;
      RuleMemo.Lines.Add('  ' + IntToStr(I + 1) + '. ' +
        Condition.LeftOperand + ' ' + OperatorText + ' ' +
        Condition.RightOperand);
    end;

  RuleMemo.Lines.Add('');
  RuleMemo.Lines.Add('Actions');
  if FRule.Actions.Count = 0 then
    RuleMemo.Lines.Add('  (none)')
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

procedure TWWRuleEditorForm.EditRule(ARule: TWorldRule);
begin
  if ARule = nil then
    Exit;
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
  LeftOperand, OperatorText, RightOperand: string;
  Kind: TWorldConditionKind;
begin
  if FRule = nil then
    Exit;
  LeftOperand := '';
  if not InputQuery('Add Condition', 'Left operand:', LeftOperand) then Exit;
  if Trim(LeftOperand) = '' then Exit;
  OperatorText := '=';
  if not InputQuery('Add Condition', 'Operator (= or <>):', OperatorText) then Exit;
  OperatorText := Trim(OperatorText);
  if OperatorText = '=' then Kind := wckEquals
  else if OperatorText = '<>' then Kind := wckNotEquals
  else
  begin
    MessageDlg('Add Condition', 'Operator must be = or <>.',
      mtError, [mbOK], 0);
    Exit;
  end;
  RightOperand := '';
  if not InputQuery('Add Condition', 'Right operand:', RightOperand) then Exit;
  if Trim(RightOperand) = '' then Exit;
  FRule.AddCondition(Kind, LeftOperand, RightOperand);
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
