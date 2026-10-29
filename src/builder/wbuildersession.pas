unit WBuilderSession;

{ Live authoring command session.

  Builder commands mutate the same neutral TWorld used by TGameSession. This
  unit owns neither dependency. Stable entity IDs are generated here for
  interactive authoring, while names remain freely editable display labels.
  Builder helpers validate command-level preconditions; structural integrity
  remains the responsibility of the core model. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WWorld, WGameSession;

type
  { TBuilderSession interprets authoring commands against the same live neutral
    model and current play session. It owns neither object. }
  TBuilderSession = class
  private
    FWorld: TWorld;
    FGameSession: TGameSession;
    function MakeEntityID(const AName, ADefaultBase: string): string;
    function EntityIDExists(const AID: string): Boolean;
    function CreateRoom(const AName: string): string;
    function CreateObject(const AName: string): string;
    function DescribeObject(const AArguments: string): string;
    function FindObjectInCurrentRoom(const ANameOrID: string): TWorldObject;
    function DescribeRoom(const ADescription: string): string;
    function RenameRoom(const AName: string): string;
    function MoveToRoom(const ARoom: string): string;
    function DeleteCurrentRoom: string;
    function ConnectRoom(const AArguments: string): string;
    function FindRoom(const ANameOrID: string): TWorldRoom;
    function ParseDirection(const AText: string; out ADirection,
      AReverse: TWorldDirection): Boolean;
  public
    constructor Create(AWorld: TWorld; AGameSession: TGameSession);
    function ExecuteCommand(const ACommand: string): string;
  end;

implementation

constructor TBuilderSession.Create(AWorld: TWorld; AGameSession: TGameSession);
begin
  inherited Create;
  if AWorld = nil then
    raise EArgumentNilException.Create('AWorld');
  if AGameSession = nil then
    raise EArgumentNilException.Create('AGameSession');
  FWorld := AWorld;
  FGameSession := AGameSession;
end;

function TBuilderSession.EntityIDExists(const AID: string): Boolean;
var
  Room: TWorldRoom;
  WorldObject: TWorldObject;
begin
  for Room in FWorld.Rooms do
    if SameText(Room.ID, AID) then
      Exit(True);
  for WorldObject in FWorld.Objects do
    if SameText(WorldObject.ID, AID) then
      Exit(True);
  Result := False;
end;

function TBuilderSession.MakeEntityID(const AName, ADefaultBase: string): string;
var
  I: Integer;
  Ch: Char;
  BaseID, Candidate, NormalizedName: string;
begin
  { IDs are lowercase ASCII slugs because they are persistence/interchange
    identities, not presentation text. Suffixes make them unique across all
    entity types currently present in the project. }
  BaseID := '';
  NormalizedName := LowerCase(Trim(AName));
  for I := 1 to Length(NormalizedName) do
  begin
    Ch := NormalizedName[I];
    if Ch in ['a'..'z', '0'..'9'] then
      BaseID := BaseID + Ch
    else if (Ch in [' ', '-', '_']) and
      (BaseID <> '') and (BaseID[Length(BaseID)] <> '_') then
      BaseID := BaseID + '_';
  end;

  while (BaseID <> '') and (BaseID[Length(BaseID)] = '_') do
    Delete(BaseID, Length(BaseID), 1);
  if BaseID = '' then
    BaseID := ADefaultBase;

  Candidate := BaseID;
  I := 2;
  while EntityIDExists(Candidate) do
  begin
    Candidate := BaseID + '_' + IntToStr(I);
    Inc(I);
  end;
  Result := Candidate;
end;

function TBuilderSession.CreateRoom(const AName: string): string;
var
  Name, ID: string;
  Room: TWorldRoom;
begin
  Name := Trim(AName);
  if Name = '' then
    Exit('Usage: @ROOM <name>');

  ID := MakeEntityID(Name, 'room');
  Room := FWorld.AddRoom(ID, Name);
  FGameSession.CurrentRoom := Room;
  Result := 'Created room "' + Name + '" [' + ID + '].';
end;

function TBuilderSession.CreateObject(const AName: string): string;
var
  Name, ID: string;
begin
  Name := Trim(AName);
  if Name = '' then
    Exit('Usage: @OBJECT <name>');
  if FGameSession.CurrentRoom = nil then
    Exit('There is no current room for the object.');

  ID := MakeEntityID(Name, 'object');
  FWorld.AddObject(ID, Name, FGameSession.CurrentRoom);
  Result := 'Created object "' + Name + '" [' + ID + '] in "' +
    FGameSession.CurrentRoom.Name + '".';
end;

function TBuilderSession.FindObjectInCurrentRoom(
  const ANameOrID: string): TWorldObject;
var
  WorldObject: TWorldObject;
begin
  { Builder object lookup is intentionally scoped to the current room. This
    avoids silently editing a same-named object elsewhere in the world. }
  for WorldObject in FWorld.Objects do
    if (WorldObject.Room = FGameSession.CurrentRoom) and
      (SameText(WorldObject.ID, Trim(ANameOrID)) or
       SameText(WorldObject.Name, Trim(ANameOrID))) then
      Exit(WorldObject);
  Result := nil;
end;

function TBuilderSession.DescribeObject(const AArguments: string): string;
var
  ObjectRef, Description: string;
  SpacePos: SizeInt;
  WorldObject: TWorldObject;
begin
  if FGameSession.CurrentRoom = nil then
    Exit('There is no current room containing the object.');

  SpacePos := Pos(' ', Trim(AArguments));
  if SpacePos = 0 then
    Exit('Usage: @DESCRIBEOBJECT <object> <description>');

  ObjectRef := Copy(Trim(AArguments), 1, SpacePos - 1);
  Description := Trim(Copy(Trim(AArguments), SpacePos + 1, MaxInt));
  if Description = '' then
    Exit('Usage: @DESCRIBEOBJECT <object> <description>');

  WorldObject := FindObjectInCurrentRoom(ObjectRef);
  if WorldObject = nil then
    Exit('Object "' + ObjectRef + '" was not found in the current room.');

  WorldObject.Description := Description;
  Result := 'Description updated for object "' + WorldObject.Name + '".';
end;

function TBuilderSession.DescribeRoom(const ADescription: string): string;
var
  Description: string;
begin
  Description := Trim(ADescription);
  if Description = '' then
    Exit('Usage: @DESCRIBE <description>');
  if FGameSession.CurrentRoom = nil then
    Exit('There is no current room to describe.');

  FGameSession.CurrentRoom.Description := Description;
  Result := 'Description updated for "' +
    FGameSession.CurrentRoom.Name + '".';
end;



function TBuilderSession.RenameRoom(const AName: string): string;
var
  Name, OldName: string;
begin
  Name := Trim(AName);
  if Name = '' then
    Exit('Usage: @RENAME <name>');
  if FGameSession.CurrentRoom = nil then
    Exit('There is no current room to rename.');

  OldName := FGameSession.CurrentRoom.Name;
  FGameSession.CurrentRoom.Name := Name;
  Result := 'Renamed room "' + OldName + '" to "' + Name + '".';
end;


function TBuilderSession.MoveToRoom(const ARoom: string): string;
var
  TargetText: string;
  Target: TWorldRoom;
begin
  TargetText := Trim(ARoom);
  if TargetText = '' then
    Exit('Usage: @MOVE <room>');

  Target := FindRoom(TargetText);
  if Target = nil then
    Exit('Room "' + TargetText + '" was not found.');

  FGameSession.CurrentRoom := Target;
  Result := 'Moved builder location to "' + Target.Name + '".';
end;


function TBuilderSession.DeleteCurrentRoom: string;
var
  RoomToDelete, NextRoom: TWorldRoom;
  OldName: string;
begin
  RoomToDelete := FGameSession.CurrentRoom;
  if RoomToDelete = nil then
    Exit('There is no current room to delete.');
  if FWorld.Rooms.Count <= 1 then
    Exit('The last room in the world cannot be deleted.');

  if FWorld.Rooms[0] <> RoomToDelete then
    NextRoom := FWorld.Rooms[0]
  else
    NextRoom := FWorld.Rooms[1];

  OldName := RoomToDelete.Name;
  FGameSession.CurrentRoom := NextRoom;
  FWorld.DeleteRoom(RoomToDelete);
  Result := 'Deleted room "' + OldName + '". Current room is "' +
    NextRoom.Name + '".';
end;

function TBuilderSession.FindRoom(const ANameOrID: string): TWorldRoom;
var
  Room: TWorldRoom;
begin
  for Room in FWorld.Rooms do
    if SameText(Room.ID, Trim(ANameOrID)) or
      SameText(Room.Name, Trim(ANameOrID)) then
      Exit(Room);
  Result := nil;
end;

function TBuilderSession.ParseDirection(const AText: string; out ADirection,
  AReverse: TWorldDirection): Boolean;
begin
  Result := True;
  if SameText(AText, 'NORTH') or SameText(AText, 'N') then
  begin
    ADirection := wdNorth;
    AReverse := wdSouth;
  end
  else if SameText(AText, 'SOUTH') or SameText(AText, 'S') then
  begin
    ADirection := wdSouth;
    AReverse := wdNorth;
  end
  else if SameText(AText, 'EAST') or SameText(AText, 'E') then
  begin
    ADirection := wdEast;
    AReverse := wdWest;
  end
  else if SameText(AText, 'WEST') or SameText(AText, 'W') then
  begin
    ADirection := wdWest;
    AReverse := wdEast;
  end
  else
    Result := False;
end;

function TBuilderSession.ConnectRoom(const AArguments: string): string;
var
  DirectionText, TargetText: string;
  SpacePos: SizeInt;
  Direction, Reverse: TWorldDirection;
  Target: TWorldRoom;
begin
  if FGameSession.CurrentRoom = nil then
    Exit('There is no current room to connect.');

  SpacePos := Pos(' ', Trim(AArguments));
  if SpacePos = 0 then
    Exit('Usage: @CONNECT <direction> <room>');

  DirectionText := Copy(Trim(AArguments), 1, SpacePos - 1);
  TargetText := Trim(Copy(Trim(AArguments), SpacePos + 1, MaxInt));
  if TargetText = '' then
    Exit('Usage: @CONNECT <direction> <room>');

  if not ParseDirection(DirectionText, Direction, Reverse) then
    Exit('Unknown direction "' + DirectionText + '".');

  Target := FindRoom(TargetText);
  if Target = nil then
    Exit('Room "' + TargetText + '" was not found.');
  if Target = FGameSession.CurrentRoom then
    Exit('A room cannot be connected to itself.');

  FGameSession.CurrentRoom.Connect(Direction, Target);
  Target.Connect(Reverse, FGameSession.CurrentRoom);
  Result := 'Connected "' + FGameSession.CurrentRoom.Name + '" ' +
    LowerCase(DirectionText) + ' to "' + Target.Name + '".';
end;

function TBuilderSession.ExecuteCommand(const ACommand: string): string;
var
  Command, Argument: string;
  SpacePos: SizeInt;
begin
  Command := Trim(ACommand);
  if Command = '' then
    Exit('');

  SpacePos := Pos(' ', Command);
  if SpacePos > 0 then
  begin
    Argument := Trim(Copy(Command, SpacePos + 1, MaxInt));
    Command := Copy(Command, 1, SpacePos - 1);
  end
  else
    Argument := '';

  if SameText(Command, '@ROOM') then
    Exit(CreateRoom(Argument));
  if SameText(Command, '@OBJECT') then
    Exit(CreateObject(Argument));
  if SameText(Command, '@DESCRIBEOBJECT') then
    Exit(DescribeObject(Argument));
  if SameText(Command, '@DESCRIBE') then
    Exit(DescribeRoom(Argument));
  if SameText(Command, '@RENAME') then
    Exit(RenameRoom(Argument));
  if SameText(Command, '@MOVE') then
    Exit(MoveToRoom(Argument));
  if SameText(Command, '@DELETE') then
    Exit(DeleteCurrentRoom);
  if SameText(Command, '@CONNECT') then
    Exit(ConnectRoom(Argument));

  Result := 'Unknown builder command "' + Command + '".';
end;

end.
