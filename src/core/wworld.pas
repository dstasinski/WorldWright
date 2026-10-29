unit WWorld;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TWorldRoom = class;
  TWorldObject = class;

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

  { TWorldObject is a physical entity that can initially exist in a room.
    Inventory and containment will extend location semantics in later slices. }
  TWorldObject = class(TWorldEntity)
  private
    FDescription: string;
    FRoom: TWorldRoom;
  public
    constructor Create(const AID, AName: string; ARoom: TWorldRoom);
    property Description: string read FDescription write FDescription;
    property Room: TWorldRoom read FRoom write FRoom;
  end;

  TWorldObjectList = specialize TObjectList<TWorldObject>;

  { TWorld owns the live target-independent model. }
  TWorld = class
  private
    FRooms: TWorldRoomList;
    FObjects: TWorldObjectList;
  public
    constructor Create;
    destructor Destroy; override;
    function AddRoom(const AID, AName: string): TWorldRoom;
    function AddObject(const AID, AName: string; ARoom: TWorldRoom): TWorldObject;
    procedure DeleteRoom(ARoom: TWorldRoom);
    property Rooms: TWorldRoomList read FRooms;
    property Objects: TWorldObjectList read FObjects;
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
  I: Integer;
begin
  { FExits owns its TWorldExit instances, so Delete both removes and frees the
    existing exit. Do not free the item a second time. }
  for I := FExits.Count - 1 downto 0 do
    if FExits[I].Direction = ADirection then
    begin
      FExits.Delete(I);
      Break;
    end;
  FExits.Add(TWorldExit.Create(ADirection, ADestination));
end;

function TWorldRoom.ExitTo(ADirection: TWorldDirection): TWorldRoom;
var
  RoomExit: TWorldExit;
begin
  for RoomExit in FExits do
    if RoomExit.Direction = ADirection then
      Exit(RoomExit.Destination);
  Result := nil;
end;

constructor TWorldObject.Create(const AID, AName: string; ARoom: TWorldRoom);
begin
  inherited Create(AID, AName);
  if ARoom = nil then
    raise EArgumentNilException.Create('ARoom');
  FRoom := ARoom;
end;

constructor TWorld.Create;
begin
  inherited Create;
  FRooms := TWorldRoomList.Create(True);
  FObjects := TWorldObjectList.Create(True);
end;

destructor TWorld.Destroy;
begin
  FObjects.Free;
  FRooms.Free;
  inherited Destroy;
end;

function TWorld.AddRoom(const AID, AName: string): TWorldRoom;
begin
  Result := TWorldRoom.Create(AID, AName);
  FRooms.Add(Result);
end;

function TWorld.AddObject(const AID, AName: string;
  ARoom: TWorldRoom): TWorldObject;
begin
  Result := TWorldObject.Create(AID, AName, ARoom);
  FObjects.Add(Result);
end;

procedure TWorld.DeleteRoom(ARoom: TWorldRoom);
var
  Room: TWorldRoom;
  I: Integer;
begin
  if ARoom = nil then
    raise EArgumentNilException.Create('ARoom');

  { Objects in a deleted room cannot retain a dangling room reference. Stage 1
    deletes them with the room; later containment semantics may offer choices. }
  for I := FObjects.Count - 1 downto 0 do
    if FObjects[I].Room = ARoom then
      FObjects.Delete(I);

  { Remove all exit references before the owning room list frees destination. }
  for Room in FRooms do
    if Room <> ARoom then
      for I := Room.Exits.Count - 1 downto 0 do
        if Room.Exits[I].Destination = ARoom then
          Room.Exits.Delete(I);

  FRooms.Remove(ARoom);
end;

end.
