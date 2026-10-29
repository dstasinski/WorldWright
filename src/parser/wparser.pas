unit WParser;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, WWorld;

type
  TPlayerCommandKind = (pcUnknown, pcLook, pcMove, pcExamine);

  { TParsedPlayerCommand is a small target-independent parser result. The
    parser recognizes intent; the engine decides what that intent does. }
  TParsedPlayerCommand = record
    Kind: TPlayerCommandKind;
    Direction: TWorldDirection;
    NounPhrase: string;
  end;

function ParsePlayerCommand(const AInput: string): TParsedPlayerCommand;

implementation

function ParsePlayerCommand(const AInput: string): TParsedPlayerCommand;
var
  Command: string;
begin
  Result.Kind := pcUnknown;
  Result.Direction := wdNorth;
  Command := UpperCase(Trim(AInput));
  Result.NounPhrase := '';

  if (Command = 'LOOK') or (Command = 'L') then
    Result.Kind := pcLook
  else if (Command = 'NORTH') or (Command = 'N') then
  begin
    Result.Kind := pcMove;
    Result.Direction := wdNorth;
  end
  else if (Command = 'SOUTH') or (Command = 'S') then
  begin
    Result.Kind := pcMove;
    Result.Direction := wdSouth;
  end
  else if (Command = 'EAST') or (Command = 'E') then
  begin
    Result.Kind := pcMove;
    Result.Direction := wdEast;
  end
  else if (Command = 'WEST') or (Command = 'W') then
  begin
    Result.Kind := pcMove;
    Result.Direction := wdWest;
  end
  else if Pos('EXAMINE ', Command) = 1 then
  begin
    Result.Kind := pcExamine;
    Result.NounPhrase := Trim(Copy(AInput, 9, MaxInt));
  end
  else if Pos('X ', Command) = 1 then
  begin
    Result.Kind := pcExamine;
    Result.NounPhrase := Trim(Copy(AInput, 3, MaxInt));
  end;
end;

end.
