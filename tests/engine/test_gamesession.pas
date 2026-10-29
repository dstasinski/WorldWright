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
