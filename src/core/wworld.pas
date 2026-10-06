unit WWorld;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
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

  { TWorldRoom is the first concrete world entity. Description belongs to the
    neutral model rather than the GUI or an exporter. }
  TWorldRoom = class(TWorldEntity)
  private
    FDescription: string;
  public
    property Description: string read FDescription write FDescription;
  end;

  TWorldRoomList = specialize TObjectList<TWorldRoom>;

  { TWorld owns the live target-independent model. At this early milestone it
    owns only rooms; later entities and relationships will be added here
    without making Inform, TADS, SQLite, or LCL the source of truth. }
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
