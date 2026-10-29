unit WBuilderSession;

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
    function MakeRoomID(const AName: string): string;
    function RoomIDExists(const AID: string): Boolean;
    function CreateRoom(const AName: string): string;
    function DescribeRoom(const ADescription: string): string;
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

function TBuilderSession.RoomIDExists(const AID: string): Boolean;
var
  Room: TWorldRoom;
begin
  for Room in FWorld.Rooms do
    if SameText(Room.ID, AID) then
      Exit(True);
  Result := False;
end;

function TBuilderSession.MakeRoomID(const AName: string): string;
var
  I: Integer;
  Ch: Char;
  BaseID, Candidate, NormalizedName: string;
begin
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
    BaseID := 'room';

  Candidate := BaseID;
  I := 2;
  while RoomIDExists(Candidate) do
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

  ID := MakeRoomID(Name);
  Room := FWorld.AddRoom(ID, Name);
  FGameSession.CurrentRoom := Room;
  Result := 'Created room "' + Name + '" [' + ID + '].';
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
  if SameText(Command, '@DESCRIBE') then
    Exit(DescribeRoom(Argument));
  if SameText(Command, '@CONNECT') then
    Exit(ConnectRoom(Argument));

  Result := 'Unknown builder command "' + Command + '".';
end;

end.
