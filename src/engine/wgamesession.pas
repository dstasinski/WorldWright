unit WGameSession;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WWorld;

type
  { TGameSession owns transient play state for a live world. }
  TGameSession = class
  private
    FWorld: TWorld;
    FCurrentRoom: TWorldRoom;
    function DescribeCurrentRoom: string;
    function Move(ADirection: TWorldDirection): string;
  public
    constructor Create(AWorld: TWorld);
    function ExecuteCommand(const ACommand: string): string;
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
begin
  if FCurrentRoom = nil then
    Exit('You are nowhere.');

  Result := FCurrentRoom.Name;
  if Trim(FCurrentRoom.Description) <> '' then
    Result := Result + LineEnding + FCurrentRoom.Description;
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

function TGameSession.ExecuteCommand(const ACommand: string): string;
var
  Command: string;
begin
  Command := UpperCase(Trim(ACommand));

  if Command = '' then
    Exit('');

  if (Command = 'LOOK') or (Command = 'L') then
    Exit(DescribeCurrentRoom);
  if (Command = 'NORTH') or (Command = 'N') then
    Exit(Move(wdNorth));
  if (Command = 'SOUTH') or (Command = 'S') then
    Exit(Move(wdSouth));
  if (Command = 'EAST') or (Command = 'E') then
    Exit(Move(wdEast));
  if (Command = 'WEST') or (Command = 'W') then
    Exit(Move(wdWest));

  Result := 'I do not understand "' + Trim(ACommand) + '".';
end;

end.
