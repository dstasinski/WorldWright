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

        Builder.ExecuteCommand('@room Observation Deck');
        Check(World.Rooms[2].ID = 'observation_deck_2',
          'duplicate generated ID was not made unique');

        Output := Builder.ExecuteCommand('@room');
        Check(Pos('Usage:', Output) > 0,
          '@ROOM without a name did not report usage');

        Output := Builder.ExecuteCommand('@describe');
        Check(Pos('Usage:', Output) > 0,
          '@DESCRIBE without text did not report usage');

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
