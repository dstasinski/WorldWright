unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Grids, Menus,
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
    GoHereMenuItem: TMenuItem;
    InspectorGrid: TStringGrid;
    LeftPanel: TPanel;
    WorldTreePopupMenu: TPopupMenu;
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
    procedure GoHereMenuItemClick(Sender: TObject);
    procedure WorldTreePopupMenuPopup(Sender: TObject);
    procedure WorldTreeDblClick(Sender: TObject);
    procedure WorldTreeSelectionChanged(Sender: TObject);
  private
    FWorld: TWorld;
    FSession: TGameSession;
    FBuilder: TBuilderSession;
    FProcessingInput: Boolean;
    procedure BuildStarterWorld;
    procedure ExecuteInputLine(const ACommand: string);
    function ObjectTreeLabel(AObject: TWorldObject): string;
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

{ Return the author-facing object label used by the World Tree. A Tag is a
  parser-visible prefix qualifier, so showing the same phrase here makes
  otherwise identical object names distinguishable without changing Name or ID.
  Tagged labels also expose the stable ID in brackets because authors commonly
  need that exact reference for builder commands when display names collide. }
function TWorldWrightMainForm.ObjectTreeLabel(AObject: TWorldObject): string;
begin
  if Trim(AObject.Tag) <> '' then
    Result := Trim(AObject.Tag) + ' ' + AObject.Name + ' [' + AObject.ID + ']'
  else
    Result := AObject.Name;
end;

{ Rebuild the current bootstrap tree/inspector from the model after every
  command. These controls are temporary UI surfaces; model state never lives
  in the tree or grid. }
procedure TWorldWrightMainForm.RefreshWorldView;
var
  WorldNode, RoomNode, InventoryNode, NewNode, SelectedNode: TTreeNode;
  Room: TWorldRoom;
  WorldObject: TWorldObject;
  SelectedID: string;
  SelectInventory: Boolean;
begin
  { Preserve logical selection before destroying the old nodes. Entity IDs are
    stable across a refresh and remain valid when TAKE/DROP changes a parent. }
  SelectedID := '';
  SelectInventory := False;
  if WorldTree.Selected <> nil then
  begin
    if WorldTree.Selected.Data <> nil then
      SelectedID := TWorldEntity(WorldTree.Selected.Data).ID
    else
      SelectInventory := SameText(WorldTree.Selected.Text, 'Inventory');
  end;

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
        begin
          NewNode := WorldTree.Items.AddChild(RoomNode, ObjectTreeLabel(WorldObject));
          NewNode.Data := WorldObject;
        end;
    RoomNode.Expand(True);
  end;

  InventoryNode := WorldTree.Items.AddChild(WorldNode, 'Inventory');
  for WorldObject in FWorld.Objects do
    if WorldObject.LocationKind = olPlayerInventory then
      begin
        NewNode := WorldTree.Items.AddChild(InventoryNode, ObjectTreeLabel(WorldObject));
        NewNode.Data := WorldObject;
      end;
  InventoryNode.Expand(True);

  WorldNode.Expand(True);

  { Restore selection by model identity, never by the destroyed TTreeNode.
    This also follows an object when its displayed parent changes between a
    room and Inventory. Structural Inventory selection is restored separately. }
  SelectedNode := nil;
  if SelectedID <> '' then
  begin
    NewNode := WorldTree.Items.GetFirstNode;
    while NewNode <> nil do
    begin
      if (NewNode.Data <> nil) and
        SameText(TWorldEntity(NewNode.Data).ID, SelectedID) then
      begin
        SelectedNode := NewNode;
        Break;
      end;
      NewNode := NewNode.GetNext;
    end;
  end
  else if SelectInventory then
    SelectedNode := InventoryNode;

  if SelectedNode <> nil then
    WorldTree.Selected := SelectedNode;

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

procedure TWorldWrightMainForm.GoHereMenuItemClick(Sender: TObject);
begin
  { Context-menu navigation deliberately shares the exact double-click path,
    which in turn routes through @MOVE and preserves builder semantics. }
  WorldTreeDblClick(WorldTree);
end;

procedure TWorldWrightMainForm.WorldTreePopupMenuPopup(Sender: TObject);
begin
  { Go Here is meaningful only for actual room entities. Structural nodes and
    objects may still be selected/inspected but are not navigation targets. }
  GoHereMenuItem.Enabled :=
    (WorldTree.Selected <> nil) and
    (WorldTree.Selected.Data <> nil) and
    (TWorldEntity(WorldTree.Selected.Data) is TWorldRoom);
end;

procedure TWorldWrightMainForm.WorldTreeDblClick(Sender: TObject);
var
  SelectedEntity: TWorldEntity;
begin
  { Double-click is author navigation, not player movement. Route it through
    the existing @MOVE builder command so GUI and command-line authoring share
    one implementation and do not accidentally acquire traversal semantics. }
  if (WorldTree.Selected = nil) or (WorldTree.Selected.Data = nil) then
    Exit;

  SelectedEntity := TWorldEntity(WorldTree.Selected.Data);
  if not (SelectedEntity is TWorldRoom) then
    Exit;

  ExecuteInputLine('@MOVE ' + SelectedEntity.ID);
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
