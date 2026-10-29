program TestBuilderSession;

{$mode objfpc}{$H+}

uses
  SysUtils, WWorld, WBuilderSession;

var
  World: TWorld;
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
    Builder := TBuilderSession.Create(World);
    try
      Output := Builder.ExecuteCommand('@room Observation Deck');
      Check(World.Rooms.Count = 2, '@ROOM did not create a room');
      Check(World.Rooms[1].Name = 'Observation Deck',
        '@ROOM did not preserve the room name');
      Check(World.Rooms[1].ID = 'observation_deck',
        '@ROOM did not generate the expected stable ID');
      Check(Pos('Created room', Output) > 0,
        '@ROOM did not report successful creation');

      Builder.ExecuteCommand('@room Observation Deck');
      Check(World.Rooms[2].ID = 'observation_deck_2',
        'duplicate generated ID was not made unique');

      Output := Builder.ExecuteCommand('@room');
      Check(Pos('Usage:', Output) > 0,
        '@ROOM without a name did not report usage');

      WriteLn('PASS: WorldWright builder-session smoke test');
    finally
      Builder.Free;
    end;
  finally
    World.Free;
  end;
end.
