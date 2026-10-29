unit WBuilderSession;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WWorld;

type
  { TBuilderSession interprets authoring commands against the same live neutral
    model used by play mode. It does not own the world. }
  TBuilderSession = class
  private
    FWorld: TWorld;
    function MakeRoomID(const AName: string): string;
    function RoomIDExists(const AID: string): Boolean;
    function CreateRoom(const AName: string): string;
  public
    constructor Create(AWorld: TWorld);
    function ExecuteCommand(const ACommand: string): string;
  end;

implementation

constructor TBuilderSession.Create(AWorld: TWorld);
begin
  inherited Create;
  if AWorld = nil then
    raise EArgumentNilException.Create('AWorld');
  FWorld := AWorld;
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
begin
  Name := Trim(AName);
  if Name = '' then
    Exit('Usage: @ROOM <name>');

  ID := MakeRoomID(Name);
  FWorld.AddRoom(ID, Name);
  Result := 'Created room "' + Name + '" [' + ID + '].';
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

  Result := 'Unknown builder command "' + Command + '".';
end;

end.
