program TestGameSession;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld, WGameSession;

var
  World: TWorld;
  Room: TWorldRoom;
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
    Room := World.AddRoom('laboratory', 'Laboratory');
    Room.Description := 'A dusty laboratory filled with abandoned equipment.';

    Session := TGameSession.Create(World);
    try
      Check(Session.CurrentRoom = Room, 'session did not start in first room');

      Output := Session.ExecuteCommand('look');
      Check(Pos('Laboratory', Output) > 0, 'LOOK omitted room name');
      Check(Pos(Room.Description, Output) > 0, 'LOOK omitted room description');

      Output := Session.ExecuteCommand('L');
      Check(Pos('Laboratory', Output) > 0, 'L alias did not perform LOOK');

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
