program TestWorld;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld;

var
  World: TWorld;
  Room: TWorldRoom;

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

    Check(World.Rooms.Count = 1, 'room was not added');
    Check(Room.ID = 'laboratory', 'stable room ID changed');
    Check(Room.Name = 'Laboratory', 'room name was not retained');
    Check(Room.Description <> '', 'room description was not retained');

    WriteLn('PASS: WorldWright core world-model smoke test');
  finally
    World.Free;
  end;
end.
