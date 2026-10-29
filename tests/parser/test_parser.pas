program TestParser;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld, WParser;

var
  Parsed: TParsedPlayerCommand;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create('FAIL: ' + AMessage);
end;

begin
  Parsed := ParsePlayerCommand('look');
  Check(Parsed.Kind = pcLook, 'LOOK was not recognized');

  Parsed := ParsePlayerCommand('n');
  Check((Parsed.Kind = pcMove) and (Parsed.Direction = wdNorth),
    'N was not recognized as north movement');

  Parsed := ParsePlayerCommand('WEST');
  Check((Parsed.Kind = pcMove) and (Parsed.Direction = wdWest),
    'WEST was not recognized as west movement');

  Parsed := ParsePlayerCommand('dance');
  Check(Parsed.Kind = pcUnknown, 'unknown input was not preserved as unknown');

  WriteLn('PASS: WorldWright player-parser smoke test');
end.
