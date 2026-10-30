unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Menus,
  WWorld, WGameSession, WBuilderSession, WWPropertyEditor;

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
    PropertyEditor: TWWPropertyEditor;
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
    function RoomTreeLabel(ARoom: TWorldRoom): string;
    procedure ProcessPastedLines;
    procedure PropertyEditorPropertyChanged(Sender: TObject;
      AProperty: TWWPropertyItem; const AOldValue, ANewValue: string;
      var Accept: Boolean);
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
  PropertyEditor.OnPropertyChanged := @PropertyEditorPropertyChanged;
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

{ Return the author-facing object label used by the World Tree. Tag is the
  complete player-facing phrase when present, so it replaces Name in this
  projection rather than being prepended to it. Tagged labels also expose the
  stable ID because authors commonly need that exact builder reference. }
function TWorldWrightMainForm.ObjectTreeLabel(AObject: TWorldObject): string;
begin
  if Trim(AObject.Tag) <> '' then
    Result := Trim(AObject.Tag) + ' [' + AObject.ID + ']'
  else
    Result := AObject.Name;
end;

{ Room selection and current authoring location are intentionally separate.
  Mark the session's current room in the tree so authors can inspect another
  entity without losing sight of where player/builder commands currently act.
  The marker is view-only and never becomes part of the room's model Name. }
function TWorldWrightMainForm.RoomTreeLabel(ARoom: TWorldRoom): string;
begin
  if ARoom = FSession.CurrentRoom then
    Result := ARoom.Name + ' [current]'
  else
    Result := ARoom.Name;
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
  SelectInventory, SelectWorld: Boolean;
begin
  { Preserve logical selection before destroying the old nodes. Entity IDs are
    stable across a refresh and remain valid when TAKE/DROP changes a parent. }
  SelectedID := '';
  SelectInventory := False;
  SelectWorld := False;
  if WorldTree.Selected <> nil then
  begin
    if WorldTree.Selected.Data <> nil then
      SelectedID := TWorldEntity(WorldTree.Selected.Data).ID
    else
    begin
      SelectInventory := SameText(WorldTree.Selected.Text, 'Inventory');
      SelectWorld := SameText(WorldTree.Selected.Text, 'World');
    end;
  end;

  WorldTree.Items.Clear;
  WorldNode := WorldTree.Items.Add(nil, 'World');

  { The tree is a projection of the complete live object state. Room-located
    objects appear beneath their structural room. Carried objects are grouped
    separately under Inventory so transient player state is visible without
    falsely presenting inventory as a room or persistent containment parent. }
  for Room in FWorld.Rooms do
  begin
    RoomNode := WorldTree.Items.AddChild(WorldNode, RoomTreeLabel(Room));
    RoomNode.Data := Room;
    for WorldObject in FWorld.Objects do
      if FSession.RuntimeObjectRoom(WorldObject) = Room then
        begin
          NewNode := WorldTree.Items.AddChild(RoomNode, ObjectTreeLabel(WorldObject));
          NewNode.Data := WorldObject;
        end;
    RoomNode.Expand(True);
  end;

  InventoryNode := WorldTree.Items.AddChild(WorldNode, 'Inventory');
  for WorldObject in FWorld.Objects do
    if FSession.IsObjectCarried(WorldObject) then
      begin
        NewNode := WorldTree.Items.AddChild(InventoryNode, ObjectTreeLabel(WorldObject));
        NewNode.Data := WorldObject;
      end;
  InventoryNode.Expand(True);

  WorldNode.Expand(True);

  { Restore selection by model identity, never by the destroyed TTreeNode.
    This also follows an object when its displayed parent changes between a
    room and Inventory. Structural World and Inventory selections are restored separately. }
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
    SelectedNode := InventoryNode
  else if SelectWorld then
    SelectedNode := WorldNode;

  if SelectedNode <> nil then
    WorldTree.Selected := SelectedNode;

  RefreshInspector;
end;

procedure TWorldWrightMainForm.PropertyEditorPropertyChanged(
  Sender: TObject; AProperty: TWWPropertyItem;
  const AOldValue, ANewValue: string; var Accept: Boolean);
var
  NewName: string;
  SelectedEntity: TWorldEntity;
begin
  Accept := False;

  { Property metadata identifies semantics by stable ID rather than caption.
    This first editing slice deliberately enables only Name; Tag and
    Description remain displayed as text-kind metadata but will receive their
    own model-backed handlers in subsequent slices. }
  if not SameText(AProperty.ID, 'name') then
    Exit;
  if (WorldTree.Selected = nil) or (WorldTree.Selected.Data = nil) then
    Exit;

  SelectedEntity := TWorldEntity(WorldTree.Selected.Data);
  NewName := Trim(ANewValue);
  if NewName = '' then
    Exit;

  SelectedEntity.Name := NewName;
  Accept := True;

  { Rebuild labels from the model immediately. Stable entity IDs preserve the
    selected node even though its displayed room/object name may have changed. }
  RefreshWorldView;
end;

procedure TWorldWrightMainForm.RefreshInspector;
var
  SelectedEntity: TWorldEntity;
  SelectedObject: TWorldObject;
  SelectedRoom: TWorldRoom;
  LocationText: string;
begin
  { TWWPropertyEditor is only a presentation/editor surface. MainForm adapts
    selected WorldWright entities into neutral property metadata; the component
    itself remains independent of the world model. }
  PropertyEditor.Clear;

  SelectedEntity := nil;
  if (WorldTree.Selected <> nil) and (WorldTree.Selected.Data <> nil) then
    SelectedEntity := TWorldEntity(WorldTree.Selected.Data);

  if (WorldTree.Selected <> nil) and
    (WorldTree.Selected.Data = nil) and
    SameText(WorldTree.Selected.Text, 'World') then
  begin
    PropertyEditor.AddProperty('name', 'Name', 'World');
    PropertyEditor.AddProperty('kind', 'Kind', 'Project World');
    PropertyEditor.AddProperty('room_count', 'Rooms',
      IntToStr(FWorld.Rooms.Count));
    PropertyEditor.AddProperty('object_count', 'Objects',
      IntToStr(FWorld.Objects.Count));
    Exit;
  end;

  if (WorldTree.Selected <> nil) and
    (WorldTree.Selected.Data = nil) and
    SameText(WorldTree.Selected.Text, 'Inventory') then
  begin
    PropertyEditor.AddProperty('name', 'Name', 'Inventory');
    PropertyEditor.AddProperty('kind', 'Kind', 'Player Inventory');
    Exit;
  end;

  if SelectedEntity is TWorldObject then
  begin
    SelectedObject := TWorldObject(SelectedEntity);
    PropertyEditor.AddProperty('name', 'Name', SelectedObject.Name, wpkText);
    PropertyEditor.AddProperty('id', 'ID', SelectedObject.ID);
    PropertyEditor.AddProperty('kind', 'Kind', 'Object');
    PropertyEditor.AddProperty('tag', 'Tag', SelectedObject.Tag, wpkText);
    PropertyEditor.AddProperty('description', 'Description',
      SelectedObject.Description, wpkText);

    { Show both authored and runtime location explicitly. The authored initial
      value is what persistence/export uses; the runtime value is disposable
      play-test state and may differ after TAKE/DROP. }
    if SelectedObject.Room <> nil then
      LocationText := SelectedObject.Room.Name
    else
      LocationText := '';
    PropertyEditor.AddProperty('initial_location', 'Initial Location',
      LocationText);

    if FSession.IsObjectCarried(SelectedObject) then
      LocationText := 'Inventory'
    else if FSession.RuntimeObjectRoom(SelectedObject) <> nil then
      LocationText := FSession.RuntimeObjectRoom(SelectedObject).Name
    else
      LocationText := '';
    PropertyEditor.AddProperty('runtime_location', 'Test Location',
      LocationText);
    Exit;
  end;

  { The inspector is selection-driven. CurrentRoom remains independently
    represented by the World Tree's [current] marker. }
  if not (SelectedEntity is TWorldRoom) then
    Exit;

  SelectedRoom := TWorldRoom(SelectedEntity);
  PropertyEditor.AddProperty('name', 'Name', SelectedRoom.Name, wpkText);
  PropertyEditor.AddProperty('id', 'ID', SelectedRoom.ID);
  PropertyEditor.AddProperty('kind', 'Kind', 'Room');
  PropertyEditor.AddProperty('description', 'Description',
    SelectedRoom.Description, wpkText);
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
