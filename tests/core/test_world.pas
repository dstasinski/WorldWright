program TestWorld;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld;

var
  World: TWorld;
  Laboratory, Hallway, ObservationDeck: TWorldRoom;
  BrassKey, OtherKey, ResolvedObject: TWorldObject;
  ResolveStatus: TObjectResolveStatus;

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

    BrassKey := World.AddObject('brass_key', 'brass key', Laboratory);
    BrassKey.Description := 'A small, tarnished brass key.';

    Laboratory.Connect(wdNorth, Hallway);
    Hallway.Connect(wdSouth, Laboratory);

    Check(World.Rooms.Count = 2, 'rooms were not added');
    Check(World.Objects.Count = 1, 'object was not added');
    Check(BrassKey.ID = 'brass_key', 'stable object ID changed');
    Check(BrassKey.Room = Laboratory, 'object room was not retained');
    Check(BrassKey.Description <> '', 'object description was not retained');

    BrassKey.Tag := 'tarnished';
    OtherKey := World.AddObject('brass_key_2', 'brass key', Laboratory);
    OtherKey.Tag := 'shiny';
    ResolveStatus := World.ResolveObjectInRoom(Laboratory, 'brass key',
      ResolvedObject);
    Check(ResolveStatus = orsAmbiguous,
      'duplicate object names were not reported as ambiguous');
    Check(ResolvedObject = nil,
      'ambiguous object lookup returned an arbitrary object');

    ResolveStatus := World.ResolveObjectInRoom(Laboratory, 'shiny brass key',
      ResolvedObject);
    Check((ResolveStatus = orsUnique) and (ResolvedObject = OtherKey),
      'tag phrase did not resolve the exact room object');

    ResolveStatus := World.ResolveObjectInRoom(Laboratory, 'brass_key_2',
      ResolvedObject);
    Check((ResolveStatus = orsUnique) and (ResolvedObject = OtherKey),
      'stable object ID did not resolve the exact duplicate-named object');

    { LocationKind is authoritative: inventory has no room reference, and
      moving back to a room restores both parts of the location invariant. }
    BrassKey.MoveToPlayerInventory;
    Check(BrassKey.LocationKind = olPlayerInventory,
      'moving object to inventory did not change location kind');
    Check(BrassKey.Room = nil,
      'inventory object retained a stale room reference');

    ResolveStatus := World.ResolveObjectInInventory('tarnished brass key',
      ResolvedObject);
    Check((ResolveStatus = orsUnique) and (ResolvedObject = BrassKey),
      'inventory lookup did not resolve an exact tag phrase');
    ResolveStatus := World.ResolveObjectInInventory('brass_key',
      ResolvedObject);
    Check((ResolveStatus = orsUnique) and (ResolvedObject = BrassKey),
      'inventory lookup did not honor an exact stable ID');

    OtherKey.MoveToPlayerInventory;
    ResolveStatus := World.ResolveObjectInInventory('brass key',
      ResolvedObject);
    Check((ResolveStatus = orsAmbiguous) and (ResolvedObject = nil),
      'duplicate carried names were not reported as ambiguous');
    OtherKey.MoveToRoom(Laboratory);

    ResolveStatus := World.ResolveVisibleObject(Laboratory, 'brass key',
      ResolvedObject);
    Check(ResolveStatus = orsAmbiguous,
      'visible lookup did not combine room and inventory name matches');
    ResolveStatus := World.ResolveVisibleObject(Laboratory, 'brass_key',
      ResolvedObject);
    Check((ResolveStatus = orsUnique) and (ResolvedObject = BrassKey),
      'visible lookup did not honor an exact stable ID');
    BrassKey.MoveToRoom(Laboratory);
    Check(BrassKey.LocationKind = olRoom,
      'moving object back to room did not restore room location kind');
    Check(BrassKey.Room = Laboratory,
      'moving object back to room did not restore room reference');

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

    Hallway.Connect(wdEast, ObservationDeck);

    { A carried object is not structurally owned by its former room. Deleting
      that room must therefore preserve the object and its inventory state. }
    BrassKey.MoveToRoom(ObservationDeck);
    BrassKey.MoveToPlayerInventory;
    World.DeleteRoom(ObservationDeck);
    Check(World.Rooms.Count = 2, 'room deletion did not update room count');
    Check(World.FindObjectByID('brass_key') = BrassKey,
      'room deletion incorrectly deleted a carried object');
    Check((BrassKey.LocationKind = olPlayerInventory) and (BrassKey.Room = nil),
      'room deletion corrupted carried object location state');
    Check(Laboratory.ExitTo(wdNorth) = nil,
      'room deletion left a dangling north exit');
    Check(Hallway.ExitTo(wdEast) = nil,
      'room deletion left a dangling east exit');

    WriteLn('PASS: WorldWright core world-model smoke test');
  finally
    World.Free;
  end;
end.
