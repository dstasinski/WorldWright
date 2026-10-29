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

  Parsed := ParsePlayerCommand('examine brass key');
  Check((Parsed.Kind = pcExamine) and
    (Parsed.NounPhrase = 'brass key'),
    'EXAMINE did not preserve its noun phrase');

  Parsed := ParsePlayerCommand('X brass key');
  Check((Parsed.Kind = pcExamine) and
    (Parsed.NounPhrase = 'brass key'),
    'X did not parse as EXAMINE');

  Parsed := ParsePlayerCommand('take brass key');
  Check((Parsed.Kind = pcTake) and (Parsed.NounPhrase = 'brass key'),
    'TAKE did not preserve its noun phrase');

  Parsed := ParsePlayerCommand('get brass key');
  Check(Parsed.Kind = pcTake, 'GET did not parse as TAKE');

  Parsed := ParsePlayerCommand('drop brass key');
  Check((Parsed.Kind = pcDrop) and (Parsed.NounPhrase = 'brass key'),
    'DROP did not preserve its noun phrase');

  Parsed := ParsePlayerCommand('inventory');
  Check(Parsed.Kind = pcInventory, 'INVENTORY was not recognized');

  Parsed := ParsePlayerCommand('i');
  Check(Parsed.Kind = pcInventory, 'I did not parse as INVENTORY');

  Parsed := ParsePlayerCommand('dance');
  Check(Parsed.Kind = pcUnknown, 'unknown input was not preserved as unknown');

  WriteLn('PASS: WorldWright player-parser smoke test');
end.
