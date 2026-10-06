unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Grids;

type
  { TWorldWrightMainForm is WorldWright's single top-level application window.
    Its permanent controls and layout live in mainform.lfm so contributors can
    edit the interface with the Lazarus Form Designer. Pascal code here is
    reserved for behavior and runtime-created content. }
  TWorldWrightMainForm = class(TForm)
    CommandEdit: TEdit;
    CommandPanel: TPanel;
    InspectorGrid: TStringGrid;
    LeftPanel: TPanel;
    RightPanel: TPanel;
    SplitLeft: TSplitter;
    SplitRight: TSplitter;
    WorkspaceMemo: TMemo;
    WorldTree: TTreeView;
    procedure FormCreate(Sender: TObject);
  private
    procedure PopulateMockContent;
  end;

var
  WorldWrightMainForm: TWorldWrightMainForm;

implementation

{$R *.lfm}

procedure TWorldWrightMainForm.FormCreate(Sender: TObject);
begin
  PopulateMockContent;
end;

procedure TWorldWrightMainForm.PopulateMockContent;
var
  WorldNode, RoomNode: TTreeNode;
begin
  { Temporary content makes the initial shell recognizable when first opened.
    It will be removed once the GUI is connected to the live world model. }
  WorldNode := WorldTree.Items.Add(nil, 'World');
  RoomNode := WorldTree.Items.AddChild(WorldNode, 'Laboratory');
  WorldTree.Items.AddChild(RoomNode, 'Desk');
  WorldTree.Items.AddChild(RoomNode, 'Brass Key');
  WorldNode.Expand(True);

  WorkspaceMemo.Lines.Add('WorldWright');
  WorkspaceMemo.Lines.Add('Build your adventure from the inside.');
  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add('Laboratory');
  WorkspaceMemo.Lines.Add('A dusty laboratory filled with abandoned equipment.');
  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add('> LOOK');
  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add('This is an initial interface shell. No game engine is active yet.');

  InspectorGrid.RowCount := 5;
  InspectorGrid.Cells[0, 1] := 'Name';
  InspectorGrid.Cells[1, 1] := 'Laboratory';
  InspectorGrid.Cells[0, 2] := 'ID';
  InspectorGrid.Cells[1, 2] := 'laboratory';
  InspectorGrid.Cells[0, 3] := 'Kind';
  InspectorGrid.Cells[1, 3] := 'Room';
  InspectorGrid.Cells[0, 4] := 'Description';
  InspectorGrid.Cells[1, 4] := 'A dusty laboratory...';
end;

end.
