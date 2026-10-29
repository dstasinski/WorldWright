program TestBuilderSession;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld, WGameSession, WBuilderSession;

var
  World: TWorld;
  Game: TGameSession;
  Builder: TBuilderSession;
  Output: string;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create('FAIL: ' + AMessage);
end;

begin
  World := TWorld.Create;
  try
    World.AddRoom('laboratory', 'Laboratory');
    Game := TGameSession.Create(World);
    try
      Builder := TBuilderSession.Create(World, Game);
      try
        Output := Builder.ExecuteCommand('@room Observation Deck');
        Check(World.Rooms.Count = 2, '@ROOM did not create a room');
        Check(World.Rooms[1].Name = 'Observation Deck',
          '@ROOM did not preserve the room name');
        Check(World.Rooms[1].ID = 'observation_deck',
          '@ROOM did not generate the expected stable ID');
        Check(Game.CurrentRoom = World.Rooms[1],
          '@ROOM did not make the new room current');
        Check(Pos('Created room', Output) > 0,
          '@ROOM did not report successful creation');

        Output := Builder.ExecuteCommand(
          '@describe Tall windows overlook the city.');
        Check(World.Rooms[1].Description =
          'Tall windows overlook the city.',
          '@DESCRIBE did not update the current room');
        Check(Pos('Description updated', Output) > 0,
          '@DESCRIBE did not report success');
        Check(Pos('Tall windows', Game.ExecuteCommand('LOOK')) > 0,
          'player LOOK did not see builder description');

        Output := Builder.ExecuteCommand('@rename City Observatory');
        Check(World.Rooms[1].Name = 'City Observatory',
          '@RENAME did not update the current room name');
        Check(World.Rooms[1].ID = 'observation_deck',
          '@RENAME changed the stable room ID');
        Check(Pos('City Observatory', Game.ExecuteCommand('LOOK')) > 0,
          'player LOOK did not see renamed room');

        Output := Builder.ExecuteCommand('@object brass key');
        Check(World.Objects.Count = 1, '@OBJECT did not create an object');
        Check(World.Objects[0].Room = Game.CurrentRoom,
          '@OBJECT did not place the object in the current room');
        Check(Pos('brass key', Game.ExecuteCommand('LOOK')) > 0,
          'LOOK did not show the builder-created object');

        Output := Builder.ExecuteCommand('@move Laboratory');
        Check(Game.CurrentRoom = World.Rooms[0],
          '@MOVE did not change the current room');
        Check(Pos('Laboratory', Output) > 0,
          '@MOVE did not report the destination');
        Output := Builder.ExecuteCommand('@move City Observatory');
        Check(Game.CurrentRoom = World.Rooms[1],
          '@MOVE could not find a room by display name');

        Output := Builder.ExecuteCommand('@connect south Laboratory');
        Check(World.Rooms[1].ExitTo(wdSouth) = World.Rooms[0],
          '@CONNECT did not create the requested exit');
        Check(World.Rooms[0].ExitTo(wdNorth) = World.Rooms[1],
          '@CONNECT did not create the reverse exit');
        Check(Pos('Connected', Output) > 0,
          '@CONNECT did not report success');
        Check(Pos('Laboratory', Game.ExecuteCommand('SOUTH')) > 0,
          'player could not traverse builder-created exit');
        Check(Pos('Observation Deck', Game.ExecuteCommand('NORTH')) > 0,
          'player could not traverse reverse builder-created exit');

        Builder.ExecuteCommand('@room Observation Deck');
        Check(World.Rooms[2].ID = 'observation_deck_2',
          'duplicate generated ID was not made unique');
        Output := Builder.ExecuteCommand('@delete');
        Check(World.Rooms.Count = 2,
          '@DELETE did not remove the current room');
        Check(Game.CurrentRoom <> nil,
          '@DELETE left the game session without a current room');
        Check(Pos('Deleted room', Output) > 0,
          '@DELETE did not report success');

        Output := Builder.ExecuteCommand('@room');
        Check(Pos('Usage:', Output) > 0,
          '@ROOM without a name did not report usage');

        Output := Builder.ExecuteCommand('@object');
        Check(Pos('Usage:', Output) > 0,
          '@OBJECT without a name did not report usage');

        Output := Builder.ExecuteCommand('@describe');
        Check(Pos('Usage:', Output) > 0,
          '@DESCRIBE without text did not report usage');

        Output := Builder.ExecuteCommand('@connect');
        Check(Pos('Usage:', Output) > 0,
          '@CONNECT without arguments did not report usage');

        Output := Builder.ExecuteCommand('@rename');
        Check(Pos('Usage:', Output) > 0,
          '@RENAME without a name did not report usage');

        Output := Builder.ExecuteCommand('@move');
        Check(Pos('Usage:', Output) > 0,
          '@MOVE without a room did not report usage');

        Output := Builder.ExecuteCommand('@move Missing Room');
        Check(Pos('not found', Output) > 0,
          '@MOVE did not report a missing room');

        WriteLn('PASS: WorldWright builder-session smoke test');
      finally
        Builder.Free;
      end;
    finally
      Game.Free;
    end;
  finally
    World.Free;
  end;
end.
