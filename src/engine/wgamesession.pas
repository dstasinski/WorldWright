unit WGameSession;

{ Runtime player session.

  TGameSession owns transient play state but never owns TWorld or its entities.
  It receives semantic parser results, resolves them against the live model,
  and applies player-visible effects such as movement and examination. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WWorld, WParser;

type
  { TGameSession owns transient play state for a live world. }
  TGameSession = class
  private
    FWorld: TWorld;
    FCurrentRoom: TWorldRoom;
    function DescribeCurrentRoom: string;
    function Move(ADirection: TWorldDirection): string;
    function Examine(const ANounPhrase: string): string;
  public
    constructor Create(AWorld: TWorld);
    function ExecuteCommand(const ACommand: string): string;
    { CurrentRoom is intentionally writable so builder operations can move the
      shared live session without duplicating player-location state. }
    property CurrentRoom: TWorldRoom read FCurrentRoom write FCurrentRoom;
  end;

implementation

constructor TGameSession.Create(AWorld: TWorld);
begin
  inherited Create;
  if AWorld = nil then
    raise EArgumentNilException.Create('AWorld');
  FWorld := AWorld;
  if FWorld.Rooms.Count > 0 then
    FCurrentRoom := FWorld.Rooms[0];
end;

function TGameSession.DescribeCurrentRoom: string;
var
  WorldObject: TWorldObject;
  ObjectsText: string;
begin
  if FCurrentRoom = nil then
    Exit('You are nowhere.');

  Result := FCurrentRoom.Name;
  if Trim(FCurrentRoom.Description) <> '' then
    Result := Result + LineEnding + FCurrentRoom.Description;

  { Room contents are derived from the world's object collection rather than
    cached on the room, keeping one authoritative location reference. }
  ObjectsText := '';
  for WorldObject in FWorld.Objects do
    if WorldObject.Room = FCurrentRoom then
    begin
      if ObjectsText <> '' then
        ObjectsText := ObjectsText + ', ';
      ObjectsText := ObjectsText + WorldObject.Name;
    end;
  if ObjectsText <> '' then
    Result := Result + LineEnding + 'You can see ' + ObjectsText + ' here.';
end;

function TGameSession.Move(ADirection: TWorldDirection): string;
var
  Destination: TWorldRoom;
begin
  if FCurrentRoom = nil then
    Exit('You are nowhere.');

  Destination := FCurrentRoom.ExitTo(ADirection);
  if Destination = nil then
    Exit('You cannot go that way.');

  FCurrentRoom := Destination;
  Result := DescribeCurrentRoom;
end;

function TGameSession.Examine(const ANounPhrase: string): string;
var
  WorldObject: TWorldObject;
begin
  for WorldObject in FWorld.Objects do
    if (WorldObject.Room = FCurrentRoom) and
      SameText(WorldObject.Name, Trim(ANounPhrase)) then
    begin
      if Trim(WorldObject.Description) <> '' then
        Exit(WorldObject.Description);
      Exit('You see nothing special about the ' + WorldObject.Name + '.');
    end;
  Result := 'You do not see "' + Trim(ANounPhrase) + '" here.';
end;

function TGameSession.ExecuteCommand(const ACommand: string): string;
var
  Parsed: TParsedPlayerCommand;
begin
  if Trim(ACommand) = '' then
    Exit('');

  Parsed := ParsePlayerCommand(ACommand);
  case Parsed.Kind of
    pcLook:
      Result := DescribeCurrentRoom;
    pcMove:
      Result := Move(Parsed.Direction);
    pcExamine:
      Result := Examine(Parsed.NounPhrase);
  else
    Result := 'I do not understand "' + Trim(ACommand) + '".';
  end;
end;

end.
