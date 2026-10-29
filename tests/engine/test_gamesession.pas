program TestGameSession;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld, WGameSession;

var
  World: TWorld;
  Laboratory, Hallway: TWorldRoom;
  Session: TGameSession;
  Output: string;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create('FAIL: ' + AMessage);
end;

begin
  World := TWorld.Create;
  try
    Laboratory := World.AddRoom('laboratory', 'Laboratory');
    Laboratory.Description :=
      'A dusty laboratory filled with abandoned equipment.';
    Hallway := World.AddRoom('hallway', 'Hallway');
    Hallway.Description := 'A narrow hallway stretches north and south.';
    with World.AddObject('brass_key', 'brass key', Laboratory) do
      Description := 'A small, tarnished brass key.';
    Laboratory.Connect(wdNorth, Hallway);
    Hallway.Connect(wdSouth, Laboratory);

    Session := TGameSession.Create(World);
    try
      Check(Session.CurrentRoom = Laboratory,
        'session did not start in first room');

      Output := Session.ExecuteCommand('look');
      Check(Pos('Laboratory', Output) > 0, 'LOOK omitted room name');
      Check(Pos(Laboratory.Description, Output) > 0,
        'LOOK omitted room description');
      Check(Pos('brass key', Output) > 0,
        'LOOK omitted an object in the current room');

      Output := Session.ExecuteCommand('examine brass key');
      Check(Pos('tarnished brass key', Output) > 0,
        'EXAMINE did not return the object description');

      Output := Session.ExecuteCommand('take brass key');
      Check(Pos('Taken', Output) > 0, 'TAKE did not report success');
      Check(Pos('brass key', Session.ExecuteCommand('inventory')) > 0,
        'INVENTORY did not show the carried object');
      Check(Pos('tarnished brass key',
        Session.ExecuteCommand('examine brass key')) > 0,
        'EXAMINE could not inspect a carried object');
      Check(Pos('brass key', Session.ExecuteCommand('look')) = 0,
        'TAKE left the object visible in the room');

      Output := Session.ExecuteCommand('drop brass key');
      Check(Pos('Dropped', Output) > 0, 'DROP did not report success');
      Check(Pos('carrying nothing', Session.ExecuteCommand('i')) > 0,
        'DROP left the object in inventory');
      Check(Pos('brass key', Session.ExecuteCommand('look')) > 0,
        'DROP did not return the object to the current room');

      World.AddObject('brass_key_2', 'brass key', Laboratory);
      Output := Session.ExecuteCommand('examine brass key');
      Check(Pos('Which', Output) > 0,
        'EXAMINE did not ask for clarification on duplicate names');

      Output := Session.ExecuteCommand('take brass key');
      Check(Pos('Which', Output) > 0,
        'TAKE did not report duplicate-name ambiguity');

      Output := Session.ExecuteCommand('x missing thing');
      Check(Pos('do not see', Output) > 0,
        'EXAMINE did not report an object absent from the room');

      Output := Session.ExecuteCommand('N');
      Check(Session.CurrentRoom = Hallway, 'N did not move north');
      Check(Pos('Hallway', Output) > 0,
        'movement did not describe destination room');

      Output := Session.ExecuteCommand('south');
      Check(Session.CurrentRoom = Laboratory, 'SOUTH did not move south');

      Output := Session.ExecuteCommand('east');
      Check(Session.CurrentRoom = Laboratory,
        'blocked movement changed current room');
      Check(Pos('cannot go', Output) > 0,
        'blocked movement did not explain failure');

      Output := Session.ExecuteCommand('dance');
      Check(Pos('do not understand', Output) > 0,
        'unknown command did not return a useful response');

      WriteLn('PASS: WorldWright game-session smoke test');
    finally
      Session.Free;
    end;
  finally
    World.Free;
  end;
end.
