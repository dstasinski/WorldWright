unit WWorld;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TWorldRoom = class;

  { TWorldDirection is deliberately target-independent. Exporters may translate
    these values into their own syntax without changing the live model. }
  TWorldDirection = (wdNorth, wdSouth, wdEast, wdWest);

  { TWorldEntity is the common identity-bearing base for objects stored in a
    WorldWright project. Stable IDs are deliberately separate from display
    names so authors may rename things without breaking relationships. }
  TWorldEntity = class
  private
    FID: string;
    FName: string;
  public
    constructor Create(const AID, AName: string);
    property ID: string read FID;
    property Name: string read FName write FName;
  end;

  { TWorldExit represents a directed connection between rooms. The destination
    is a model reference, never a GUI node or exporter-specific identifier. }
  TWorldExit = class
  private
    FDirection: TWorldDirection;
    FDestination: TWorldRoom;
  public
    constructor Create(ADirection: TWorldDirection; ADestination: TWorldRoom);
    property Direction: TWorldDirection read FDirection;
    property Destination: TWorldRoom read FDestination;
  end;

  TWorldExitList = specialize TObjectList<TWorldExit>;

  { TWorldRoom is the first concrete world entity. }
  TWorldRoom = class(TWorldEntity)
  private
    FDescription: string;
    FExits: TWorldExitList;
  public
    constructor Create(const AID, AName: string);
    destructor Destroy; override;
    procedure Connect(ADirection: TWorldDirection; ADestination: TWorldRoom);
    function ExitTo(ADirection: TWorldDirection): TWorldRoom;
    property Description: string read FDescription write FDescription;
    property Exits: TWorldExitList read FExits;
  end;

  TWorldRoomList = specialize TObjectList<TWorldRoom>;

  { TWorld owns the live target-independent model. }
  TWorld = class
  private
    FRooms: TWorldRoomList;
  public
    constructor Create;
    destructor Destroy; override;
    function AddRoom(const AID, AName: string): TWorldRoom;
    property Rooms: TWorldRoomList read FRooms;
  end;

implementation

constructor TWorldEntity.Create(const AID, AName: string);
begin
  inherited Create;
  if Trim(AID) = '' then
    raise EArgumentException.Create('World entity ID must not be empty');
  FID := AID;
  FName := AName;
end;

constructor TWorldExit.Create(ADirection: TWorldDirection;
  ADestination: TWorldRoom);
begin
  inherited Create;
  if ADestination = nil then
    raise EArgumentNilException.Create('ADestination');
  FDirection := ADirection;
  FDestination := ADestination;
end;

constructor TWorldRoom.Create(const AID, AName: string);
begin
  inherited Create(AID, AName);
  FExits := TWorldExitList.Create(True);
end;

destructor TWorldRoom.Destroy;
begin
  FExits.Free;
  inherited Destroy;
end;

procedure TWorldRoom.Connect(ADirection: TWorldDirection;
  ADestination: TWorldRoom);
var
  Exit: TWorldExit;
begin
  for Exit in FExits do
    if Exit.Direction = ADirection then
    begin
      FExits.Remove(Exit);
      Exit.Free;
      Break;
    end;
  FExits.Add(TWorldExit.Create(ADirection, ADestination));
end;

function TWorldRoom.ExitTo(ADirection: TWorldDirection): TWorldRoom;
var
  Exit: TWorldExit;
begin
  for Exit in FExits do
    if Exit.Direction = ADirection then
      Exit(Exit.Destination);
  Result := nil;
end;

constructor TWorld.Create;
begin
  inherited Create;
  FRooms := TWorldRoomList.Create(True);
end;

destructor TWorld.Destroy;
begin
  FRooms.Free;
  inherited Destroy;
end;

function TWorld.AddRoom(const AID, AName: string): TWorldRoom;
begin
  Result := TWorldRoom.Create(AID, AName);
  FRooms.Add(Result);
end;

end.
