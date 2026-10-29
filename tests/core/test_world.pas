program TestWorld;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld;

var
  World: TWorld;
  Laboratory, Hallway, ObservationDeck: TWorldRoom;

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

    Laboratory.Connect(wdNorth, Hallway);
    Hallway.Connect(wdSouth, Laboratory);

    Check(World.Rooms.Count = 2, 'rooms were not added');
    Check(Laboratory.ID = 'laboratory', 'stable room ID changed');
    Check(Laboratory.Name = 'Laboratory', 'room name was not retained');
    Check(Laboratory.Description <> '', 'room description was not retained');
    Check(Laboratory.ExitTo(wdNorth) = Hallway,
      'north exit did not point to hallway');
    Check(Hallway.ExitTo(wdSouth) = Laboratory,
      'south exit did not point to laboratory');
    Check(Laboratory.ExitTo(wdEast) = nil,
      'missing exit unexpectedly had a destination');

    { Replacing an existing direction must safely dispose the old owned exit
      and leave exactly one exit for that direction. }
    ObservationDeck := World.AddRoom('observation_deck', 'Observation Deck');
    Laboratory.Connect(wdNorth, ObservationDeck);
    Check(Laboratory.ExitTo(wdNorth) = ObservationDeck,
      'replacement north exit did not point to observation deck');
    Check(Laboratory.Exits.Count = 1,
      'replacing an exit left a duplicate direction');

    WriteLn('PASS: WorldWright core world-model smoke test');
  finally
    World.Free;
  end;
end.
