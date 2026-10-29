unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Grids,
  WWorld, WGameSession, WBuilderSession;

type
  { TWorldWrightMainForm is WorldWright's single top-level application window.
    Static layout lives in mainform.lfm. This unit coordinates the GUI with
    the live model and game session; parser/engine behavior belongs outside
    the form. }
  TWorldWrightMainForm = class(TForm)
    CenterPanel: TPanel;
    CommandMemo: TMemo;
    CommandPanel: TPanel;
    InspectorGrid: TStringGrid;
    LeftPanel: TPanel;
    RightPanel: TPanel;
    SplitLeft: TSplitter;
    SplitRight: TSplitter;
    WorkspaceMemo: TMemo;
    WorldTree: TTreeView;
    procedure CommandMemoChange(Sender: TObject);
    procedure CommandMemoKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure WorldTreeSelectionChanged(Sender: TObject);
  private
    FWorld: TWorld;
    FSession: TGameSession;
    FBuilder: TBuilderSession;
    FProcessingInput: Boolean;
    procedure BuildStarterWorld;
    procedure ExecuteInputLine(const ACommand: string);
    procedure ProcessPastedLines;
    procedure RefreshWorldView;
    procedure RefreshInspector;
    procedure SubmitCommand;
  end;

var
  WorldWrightMainForm: TWorldWrightMainForm;

implementation

{$R *.lfm}

procedure TWorldWrightMainForm.FormCreate(Sender: TObject);
begin
  FWorld := TWorld.Create;
  BuildStarterWorld;
  FSession := TGameSession.Create(FWorld);
  FBuilder := TBuilderSession.Create(FWorld, FSession);
  RefreshWorldView;

  WorkspaceMemo.Clear;
  WorkspaceMemo.Lines.Add('WorldWright');
  WorkspaceMemo.Lines.Add('Build your adventure from the inside.');
  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add(FSession.ExecuteCommand('LOOK'));
end;

procedure TWorldWrightMainForm.FormDestroy(Sender: TObject);
begin
  FBuilder.Free;
  FSession.Free;
  FWorld.Free;
end;

procedure TWorldWrightMainForm.FormShow(Sender: TObject);
begin
  CommandMemo.SetFocus;
end;

procedure TWorldWrightMainForm.BuildStarterWorld;
var
  Laboratory, Hallway: TWorldRoom;
begin
  Laboratory := FWorld.AddRoom('laboratory', 'Laboratory');
  Laboratory.Description :=
    'A dusty laboratory filled with abandoned equipment.';

  Hallway := FWorld.AddRoom('hallway', 'Hallway');
  Hallway.Description :=
    'A narrow hallway stretches past a row of closed doors.';

  Laboratory.Connect(wdNorth, Hallway);
  Hallway.Connect(wdSouth, Laboratory);
end;

{ Rebuild the current bootstrap tree/inspector from the model after every
  command. These controls are temporary UI surfaces; model state never lives
  in the tree or grid. }
procedure TWorldWrightMainForm.RefreshWorldView;
var
  WorldNode, RoomNode, InventoryNode: TTreeNode;
  Room: TWorldRoom;
  WorldObject: TWorldObject;
begin
  WorldTree.Items.Clear;
  WorldNode := WorldTree.Items.Add(nil, 'World');

  { The tree is a projection of the complete live object state. Room-located
    objects appear beneath their structural room. Carried objects are grouped
    separately under Inventory so transient player state is visible without
    falsely presenting inventory as a room or persistent containment parent. }
  for Room in FWorld.Rooms do
  begin
    RoomNode := WorldTree.Items.AddChild(WorldNode, Room.Name);
    RoomNode.Data := Room;
    for WorldObject in FWorld.Objects do
      if (WorldObject.LocationKind = olRoom) and
        (WorldObject.Room = Room) then
        with WorldTree.Items.AddChild(RoomNode, WorldObject.Name) do
          Data := WorldObject;
    RoomNode.Expand(True);
  end;

  InventoryNode := WorldTree.Items.AddChild(WorldNode, 'Inventory');
  for WorldObject in FWorld.Objects do
    if WorldObject.LocationKind = olPlayerInventory then
      with WorldTree.Items.AddChild(InventoryNode, WorldObject.Name) do
        Data := WorldObject;
  InventoryNode.Expand(True);

  WorldNode.Expand(True);

  { Rebuilding invalidates TTreeNode instances, so selection is intentionally
    not treated as durable model state. With no explicit selection, the
    inspector continues to describe the current room. }
  RefreshInspector;
end;

procedure TWorldWrightMainForm.RefreshInspector;
var
  SelectedEntity: TWorldEntity;
  SelectedObject: TWorldObject;
  SelectedRoom: TWorldRoom;
  LocationText: string;
begin
  InspectorGrid.Clean;
  InspectorGrid.Cells[0, 0] := 'Property';
  InspectorGrid.Cells[1, 0] := 'Value';

  SelectedEntity := nil;
  if (WorldTree.Selected <> nil) and (WorldTree.Selected.Data <> nil) then
    SelectedEntity := TWorldEntity(WorldTree.Selected.Data);

  { Inventory is a structural/session node rather than a TWorldEntity. Give it
    explicit inspector content instead of falling through to CurrentRoom. }
  if (WorldTree.Selected <> nil) and
    (WorldTree.Selected.Data = nil) and
    SameText(WorldTree.Selected.Text, 'Inventory') then
  begin
    InspectorGrid.RowCount := 3;
    InspectorGrid.Cells[0, 1] := 'Name';
    InspectorGrid.Cells[1, 1] := 'Inventory';
    InspectorGrid.Cells[0, 2] := 'Kind';
    InspectorGrid.Cells[1, 2] := 'Player Inventory';
    Exit;
  end;

  if SelectedEntity is TWorldObject then
  begin
    SelectedObject := TWorldObject(SelectedEntity);
    InspectorGrid.RowCount := 6;
    InspectorGrid.Cells[0, 1] := 'Name';
    InspectorGrid.Cells[1, 1] := SelectedObject.Name;
    InspectorGrid.Cells[0, 2] := 'ID';
    InspectorGrid.Cells[1, 2] := SelectedObject.ID;
    InspectorGrid.Cells[0, 3] := 'Kind';
    InspectorGrid.Cells[1, 3] := 'Object';
    InspectorGrid.Cells[0, 4] := 'Tag';
    InspectorGrid.Cells[1, 4] := SelectedObject.Tag;
    InspectorGrid.Cells[0, 5] := 'Description';
    InspectorGrid.Cells[1, 5] := SelectedObject.Description;
    if SelectedObject.LocationKind = olPlayerInventory then
      LocationText := 'Inventory'
    else if SelectedObject.Room <> nil then
      LocationText := SelectedObject.Room.Name
    else
      LocationText := '';
    InspectorGrid.RowCount := 7;
    InspectorGrid.Cells[0, 6] := 'Location';
    InspectorGrid.Cells[1, 6] := LocationText;
    Exit;
  end;

  if SelectedEntity is TWorldRoom then
    SelectedRoom := TWorldRoom(SelectedEntity)
  else
    SelectedRoom := FSession.CurrentRoom;

  InspectorGrid.RowCount := 5;
  if SelectedRoom <> nil then
  begin
    InspectorGrid.Cells[0, 1] := 'Name';
    InspectorGrid.Cells[1, 1] := SelectedRoom.Name;
    InspectorGrid.Cells[0, 2] := 'ID';
    InspectorGrid.Cells[1, 2] := SelectedRoom.ID;
    InspectorGrid.Cells[0, 3] := 'Kind';
    InspectorGrid.Cells[1, 3] := 'Room';
    InspectorGrid.Cells[0, 4] := 'Description';
    InspectorGrid.Cells[1, 4] := SelectedRoom.Description;
  end;
end;

procedure TWorldWrightMainForm.WorldTreeSelectionChanged(Sender: TObject);
begin
  { Tree node Data is a non-owning pointer into FWorld. Nodes are rebuilt after
    each command, so no node outlives the model entity it currently displays. }
  RefreshInspector;
end;

{ Route @ commands to authoring and ordinary text to play. Both sessions share
  FWorld and FSession.CurrentRoom, so changes are immediately visible to the
  other side before the GUI refreshes. }
procedure TWorldWrightMainForm.ExecuteInputLine(const ACommand: string);
var
  Command, Response: string;
begin
  Command := Trim(ACommand);
  if Command = '' then
    Exit;

  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add('> ' + Command);

  if Command[1] = '@' then
    Response := FBuilder.ExecuteCommand(Command)
  else
    Response := FSession.ExecuteCommand(Command);
  if Response <> '' then
    WorkspaceMemo.Lines.Add(Response);

  RefreshWorldView;
end;

procedure TWorldWrightMainForm.SubmitCommand;
var
  Command: string;
begin
  Command := Trim(CommandMemo.Text);
  if Command = '' then
    Exit;

  FProcessingInput := True;
  try
    CommandMemo.Clear;
  finally
    FProcessingInput := False;
  end;

  ExecuteInputLine(Command);
  WorkspaceMemo.SelStart := Length(WorkspaceMemo.Text);
end;

{ TMemo is used for input so a multiline paste can be treated as a command
  batch. FProcessingInput suppresses OnChange recursion while clearing it. }
procedure TWorldWrightMainForm.ProcessPastedLines;
var
  Lines: TStringList;
  I: Integer;
begin
  if FProcessingInput then
    Exit;
  if CommandMemo.Lines.Count <= 1 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Assign(CommandMemo.Lines);
    FProcessingInput := True;
    try
      CommandMemo.Clear;
    finally
      FProcessingInput := False;
    end;

    for I := 0 to Lines.Count - 1 do
      ExecuteInputLine(Lines[I]);

    WorkspaceMemo.SelStart := Length(WorkspaceMemo.Text);
  finally
    Lines.Free;
  end;
end;

procedure TWorldWrightMainForm.CommandMemoChange(Sender: TObject);
begin
  ProcessPastedLines;
end;

procedure TWorldWrightMainForm.CommandMemoKeyPress(Sender: TObject;
  var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    SubmitCommand;
  end;
end;

end.
