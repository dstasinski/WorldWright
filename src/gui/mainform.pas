unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Grids;

type
  { TWorldWrightMainForm is intentionally a single-window shell. The initial
    layout establishes the long-term interaction model without embedding game
    logic in the GUI: world navigation at left, workspace in the center, and a
    Lazarus-inspired property inspector at right. }
  TWorldWrightMainForm = class(TForm)
  private
    FWorldTree: TTreeView;
    FWorkspace: TMemo;
    FInspector: TStringGrid;
    FCommand: TEdit;
    procedure BuildInterface;
    procedure PopulateMockContent;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

implementation

constructor TWorldWrightMainForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner, 1);
  Caption := 'WorldWright - Build your adventure from the inside.';
  Width := 1100;
  Height := 700;
  Position := poScreenCenter;
  BuildInterface;
  PopulateMockContent;
end;

procedure TWorldWrightMainForm.BuildInterface;
var
  LeftPanel, RightPanel, CenterPanel, CommandPanel: TPanel;
  SplitLeft, SplitRight: TSplitter;
begin
  LeftPanel := TPanel.Create(Self);
  LeftPanel.Parent := Self;
  LeftPanel.Align := alLeft;
  LeftPanel.Width := 220;
  LeftPanel.Caption := '';

  FWorldTree := TTreeView.Create(Self);
  FWorldTree.Parent := LeftPanel;
  FWorldTree.Align := alClient;

  SplitLeft := TSplitter.Create(Self);
  SplitLeft.Parent := Self;
  SplitLeft.Align := alLeft;

  RightPanel := TPanel.Create(Self);
  RightPanel.Parent := Self;
  RightPanel.Align := alRight;
  RightPanel.Width := 280;
  RightPanel.Caption := '';

  FInspector := TStringGrid.Create(Self);
  FInspector.Parent := RightPanel;
  FInspector.Align := alClient;
  FInspector.ColCount := 2;
  FInspector.FixedCols := 0;
  FInspector.FixedRows := 1;
  FInspector.Cells[0, 0] := 'Property';
  FInspector.Cells[1, 0] := 'Value';

  SplitRight := TSplitter.Create(Self);
  SplitRight.Parent := Self;
  SplitRight.Align := alRight;

  CenterPanel := TPanel.Create(Self);
  CenterPanel.Parent := Self;
  CenterPanel.Align := alClient;
  CenterPanel.Caption := '';

  CommandPanel := TPanel.Create(Self);
  CommandPanel.Parent := CenterPanel;
  CommandPanel.Align := alBottom;
  CommandPanel.Height := 34;
  CommandPanel.Caption := '';

  FCommand := TEdit.Create(Self);
  FCommand.Parent := CommandPanel;
  FCommand.Align := alClient;
  FCommand.TextHint := 'Enter a player command or @builder command...';

  FWorkspace := TMemo.Create(Self);
  FWorkspace.Parent := CenterPanel;
  FWorkspace.Align := alClient;
  FWorkspace.ReadOnly := True;
  FWorkspace.ScrollBars := ssAutoVertical;
end;

procedure TWorldWrightMainForm.PopulateMockContent;
var
  WorldNode, RoomNode: TTreeNode;
begin
  WorldNode := FWorldTree.Items.Add(nil, 'World');
  RoomNode := FWorldTree.Items.AddChild(WorldNode, 'Laboratory');
  FWorldTree.Items.AddChild(RoomNode, 'Desk');
  FWorldTree.Items.AddChild(RoomNode, 'Brass Key');
  WorldNode.Expand(True);

  FWorkspace.Lines.Add('WorldWright');
  FWorkspace.Lines.Add('Build your adventure from the inside.');
  FWorkspace.Lines.Add('');
  FWorkspace.Lines.Add('Laboratory');
  FWorkspace.Lines.Add('A dusty laboratory filled with abandoned equipment.');
  FWorkspace.Lines.Add('');
  FWorkspace.Lines.Add('> LOOK');
  FWorkspace.Lines.Add('');
  FWorkspace.Lines.Add('This is an initial interface shell. No game engine is active yet.');

  FInspector.RowCount := 5;
  FInspector.Cells[0, 1] := 'Name';
  FInspector.Cells[1, 1] := 'Laboratory';
  FInspector.Cells[0, 2] := 'ID';
  FInspector.Cells[1, 2] := 'laboratory';
  FInspector.Cells[0, 3] := 'Kind';
  FInspector.Cells[1, 3] := 'Room';
  FInspector.Cells[0, 4] := 'Description';
  FInspector.Cells[1, 4] := 'A dusty laboratory...';
end;

end.
