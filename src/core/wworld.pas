unit WWorld;

{ Core neutral world model.

  This unit deliberately has no GUI, parser, persistence, or exporter
  dependencies. TWorld owns rooms and objects. Rooms own their exits; exits
  reference destination rooms without owning them. Object Room references are
  likewise non-owning. All deletion that can invalidate cross-references
  therefore belongs on TWorld so callers cannot accidentally leave dangling
  model pointers. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections;

type
  TWorldRoom = class;
  TWorldObject = class;
  TWorldRule = class;

  { TWorldDirection is deliberately target-independent. Exporters may translate
    these values into their own syntax without changing the live model. }
  TWorldDirection = (wdNorth, wdSouth, wdEast, wdWest);

  { Object resolution explicitly reports ambiguity so callers never select an
    arbitrary same-named object. Stable-ID matches are always exact. }
  TObjectResolveStatus = (orsNotFound, orsUnique, orsAmbiguous);

  { Explicit location state avoids using Room=nil as a hidden synonym for
    inventory. Future containment/NPC locations can extend this enum cleanly. }
  TWorldObjectLocationKind = (olRoom, olPlayerInventory);

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

  { A semantic event binding stores only the stable ID of a WorldWright rule.
    It never owns the rule and never contains target-language source. Empty
    RuleID means the hook is intentionally unbound. }
  TWorldEventBinding = class
  private
    FEventName: string;
    FRuleID: string;
  public
    constructor Create(const AEventName: string);
    property EventName: string read FEventName;
    property RuleID: string read FRuleID write FRuleID;
  end;

  TWorldEventBindingList = specialize TObjectList<TWorldEventBinding>;

  function FindEventBinding(AEvents: TWorldEventBindingList;
    const AEventName: string): TWorldEventBinding;



  { TWorldRoom is the first concrete world entity. }
  TWorldRoom = class(TWorldEntity)
  private
    FDescription: string;
    FExits: TWorldExitList;
    FEvents: TWorldEventBindingList;
  public
    constructor Create(const AID, AName: string);
    destructor Destroy; override;
    { Connect replaces any existing exit in ADirection. The room owns the
      resulting TWorldExit; ADestination remains owned by TWorld. }
    procedure Connect(ADirection: TWorldDirection; ADestination: TWorldRoom);
    function ExitTo(ADirection: TWorldDirection): TWorldRoom;
    property Description: string read FDescription write FDescription;
    property Exits: TWorldExitList read FExits;
    property Events: TWorldEventBindingList read FEvents;
  end;

  TWorldRoomList = specialize TObjectList<TWorldRoom>;

  { TWorldObject is a physical entity that can initially exist in a room.
    Inventory and containment will extend location semantics in later slices. }
  TWorldObject = class(TWorldEntity)
  private
    FDescription: string;
    FTag: string;
    FRoom: TWorldRoom;
    FLocationKind: TWorldObjectLocationKind;
    FEvents: TWorldEventBindingList;
  public
    constructor Create(const AID, AName: string; ARoom: TWorldRoom);
    destructor Destroy; override;
    procedure MoveToRoom(ARoom: TWorldRoom);
    procedure MoveToPlayerInventory;
    property Description: string read FDescription write FDescription;
    { Player-facing descriptive noun phrase, normally authored without an
      indefinite article (for example "rusty iron key"). Tag is an exact
      alternate player reference and replaces Name for descriptive display;
      prose generation may add grammatical articles such as a/an. }
    property Tag: string read FTag
      write FTag;
    property LocationKind: TWorldObjectLocationKind read FLocationKind;
    property Room: TWorldRoom read FRoom;
    property Events: TWorldEventBindingList read FEvents;
  end;

  TWorldObjectList = specialize TObjectList<TWorldObject>;

  { TWorldRule is the durable neutral identity referenced by semantic events.
    Conditions and actions are intentionally deferred; this slice establishes
    stable authored relationships before defining the rule language itself. }
  TWorldRule = class(TWorldEntity)
  end;

  TWorldRuleList = specialize TObjectList<TWorldRule>;



  { TWorld owns the live target-independent model. }
  TWorld = class
  private
    FRooms: TWorldRoomList;
    FObjects: TWorldObjectList;
    FRules: TWorldRuleList;
  public
    constructor Create;
    destructor Destroy; override;
    { Add methods transfer ownership of the returned entity to TWorld. }
    function AddRoom(const AID, AName: string): TWorldRoom;
    function AddObject(const AID, AName: string; ARoom: TWorldRoom): TWorldObject;
    function AddRule(const AID, AName: string): TWorldRule;
    function FindRuleByID(const AID: string): TWorldRule;
    { Stable IDs are the safe long-lived reference used by transient systems
      such as pending parser choices. The returned object remains world-owned. }
    function FindObjectByID(const AID: string): TWorldObject;
    function ResolveObjectInRoom(ARoom: TWorldRoom; const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    function ResolveObjectInInventory(const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    function ResolveVisibleObject(ARoom: TWorldRoom; const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    { DeleteRoom also removes objects located in ARoom and exits that target
      it, preserving pointer integrity before the room is freed. }
    procedure DeleteRoom(ARoom: TWorldRoom);
    property Rooms: TWorldRoomList read FRooms;
    property Objects: TWorldObjectList read FObjects;
    property Rules: TWorldRuleList read FRules;
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

function FindEventBinding(AEvents: TWorldEventBindingList;
  const AEventName: string): TWorldEventBinding;
var
  Binding: TWorldEventBinding;
begin
  Result := nil;
  if AEvents = nil then
    Exit;
  for Binding in AEvents do
    if SameText(Binding.EventName, Trim(AEventName)) then
      Exit(Binding);
end;

constructor TWorldEventBinding.Create(const AEventName: string);
begin
  inherited Create;
  if Trim(AEventName) = '' then
    raise EArgumentException.Create('Event name must not be empty');
  FEventName := AEventName;
  FRuleID := '';
end;

constructor TWorldRoom.Create(const AID, AName: string);
begin
  inherited Create(AID, AName);
  FExits := TWorldExitList.Create(True);
  FEvents := TWorldEventBindingList.Create(True);
  FEvents.Add(TWorldEventBinding.Create('OnEnter'));
  FEvents.Add(TWorldEventBinding.Create('OnExit'));
  FEvents.Add(TWorldEventBinding.Create('OnLook'));
end;

destructor TWorldRoom.Destroy;
begin
  FEvents.Free;
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
  FLocationKind := olRoom;
  FEvents := TWorldEventBindingList.Create(True);
  FEvents.Add(TWorldEventBinding.Create('OnExamine'));
  FEvents.Add(TWorldEventBinding.Create('OnTake'));
  FEvents.Add(TWorldEventBinding.Create('OnDrop'));
  FEvents.Add(TWorldEventBinding.Create('OnUse'));
end;

destructor TWorldObject.Destroy;
begin
  FEvents.Free;
  inherited Destroy;
end;

procedure TWorldObject.MoveToRoom(ARoom: TWorldRoom);
begin
  if ARoom = nil then
    raise EArgumentNilException.Create('ARoom');
  FRoom := ARoom;
  FLocationKind := olRoom;
end;

procedure TWorldObject.MoveToPlayerInventory;
begin
  FRoom := nil;
  FLocationKind := olPlayerInventory;
end;

constructor TWorld.Create;
begin
  inherited Create;
  FRooms := TWorldRoomList.Create(True);
  FObjects := TWorldObjectList.Create(True);
  FRules := TWorldRuleList.Create(True);
end;

destructor TWorld.Destroy;
begin
  FRules.Free;
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

function TWorld.AddRule(const AID, AName: string): TWorldRule;
begin
  Result := TWorldRule.Create(AID, AName);
  FRules.Add(Result);
end;

function TWorld.FindRuleByID(const AID: string): TWorldRule;
var
  Rule: TWorldRule;
begin
  for Rule in FRules do
    if SameText(Rule.ID, Trim(AID)) then
      Exit(Rule);
  Result := nil;
end;

function TWorld.FindObjectByID(const AID: string): TWorldObject;
var
  WorldObject: TWorldObject;
begin
  for WorldObject in FObjects do
    if SameText(WorldObject.ID, Trim(AID)) then
      Exit(WorldObject);
  Result := nil;
end;

function TWorld.ResolveObjectInRoom(ARoom: TWorldRoom;
  const ANameOrID: string; out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  ReferenceText: string;
begin
  AObject := nil;
  ReferenceText := Trim(ANameOrID);

  { Stable IDs are project-wide unique and therefore take precedence over
    display-name matching, even when duplicate names share a room. }
  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olRoom) and
      (WorldObject.Room = ARoom) and SameText(WorldObject.ID, ReferenceText) then
    begin
      AObject := WorldObject;
      Exit(orsUnique);
    end;

  { Tag is a complete exact alternate player reference, not a prefix and not
    fuzzy matching. Normal Name matching remains the next fallback. }
  MatchCount := 0;
  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olRoom) and
      (WorldObject.Room = ARoom) and
      (Trim(WorldObject.Tag) <> '') and
      SameText(WorldObject.Tag, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;
  if MatchCount = 1 then
    Exit(orsUnique)
  else if MatchCount > 1 then
  begin
    AObject := nil;
    Exit(orsAmbiguous);
  end;

  MatchCount := 0;
  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olRoom) and
      (WorldObject.Room = ARoom) and SameText(WorldObject.Name, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;

  case MatchCount of
    0: Result := orsNotFound;
    1: Result := orsUnique;
  else
    begin
      AObject := nil;
      Result := orsAmbiguous;
    end;
  end;
end;

function TWorld.ResolveObjectInInventory(const ANameOrID: string;
  out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  ReferenceText: string;
begin
  AObject := nil;
  ReferenceText := Trim(ANameOrID);

  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olPlayerInventory) and
      SameText(WorldObject.ID, ReferenceText) then
    begin
      AObject := WorldObject;
      Exit(orsUnique);
    end;

  { Tag is a complete exact alternate player reference, not a prefix and not
    fuzzy matching. Normal Name matching remains the next fallback. }
  MatchCount := 0;
  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olPlayerInventory) and
      (Trim(WorldObject.Tag) <> '') and
      SameText(WorldObject.Tag, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;
  if MatchCount = 1 then
    Exit(orsUnique)
  else if MatchCount > 1 then
  begin
    AObject := nil;
    Exit(orsAmbiguous);
  end;

  MatchCount := 0;
  for WorldObject in FObjects do
    if (WorldObject.LocationKind = olPlayerInventory) and
      SameText(WorldObject.Name, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;

  case MatchCount of
    0: Result := orsNotFound;
    1: Result := orsUnique;
  else
    begin
      AObject := nil;
      Result := orsAmbiguous;
    end;
  end;
end;

function TWorld.ResolveVisibleObject(ARoom: TWorldRoom;
  const ANameOrID: string; out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  ReferenceText: string;
  IsVisible: Boolean;
begin
  AObject := nil;
  ReferenceText := Trim(ANameOrID);

  { Visibility currently consists of the current room plus player inventory.
    Keep this rule in the model so EXAMINE and later visible-object verbs share
    one definition as containment and supporters are introduced. }
  for WorldObject in FObjects do
  begin
    IsVisible := (WorldObject.LocationKind = olPlayerInventory) or
      ((WorldObject.LocationKind = olRoom) and (WorldObject.Room = ARoom));
    if IsVisible and SameText(WorldObject.ID, ReferenceText) then
    begin
      AObject := WorldObject;
      Exit(orsUnique);
    end;
  end;

  { Tag is a complete exact alternate player reference, not a prefix and not
    fuzzy matching. Normal Name matching remains the next fallback. }
  MatchCount := 0;
  for WorldObject in FObjects do
    if (((WorldObject.LocationKind = olPlayerInventory) or
       ((WorldObject.LocationKind = olRoom) and (WorldObject.Room = ARoom)))) and
      (Trim(WorldObject.Tag) <> '') and
      SameText(WorldObject.Tag, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;
  if MatchCount = 1 then
    Exit(orsUnique)
  else if MatchCount > 1 then
  begin
    AObject := nil;
    Exit(orsAmbiguous);
  end;

  MatchCount := 0;
  for WorldObject in FObjects do
  begin
    IsVisible := (WorldObject.LocationKind = olPlayerInventory) or
      ((WorldObject.LocationKind = olRoom) and (WorldObject.Room = ARoom));
    if IsVisible and SameText(WorldObject.Name, ReferenceText) then
    begin
      Inc(MatchCount);
      if MatchCount = 1 then
        AObject := WorldObject;
    end;
  end;

  case MatchCount of
    0: Result := orsNotFound;
    1: Result := orsUnique;
  else
    begin
      AObject := nil;
      Result := orsAmbiguous;
    end;
  end;
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
    if (FObjects[I].LocationKind = olRoom) and
      (FObjects[I].Room = ARoom) then
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
