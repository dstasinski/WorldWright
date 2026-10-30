unit WGameSession;

{ Runtime player session.

  TGameSession owns transient play state but never owns TWorld or its entities.
  It receives semantic parser results, resolves them against the live model,
  and applies player-visible effects such as movement and examination. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, WWorld, WParser;

type
  { Runtime location for one world object. The object itself remains an
    authored definition owned by TWorld; this record-like object is owned by
    TGameSession and may be discarded at any time. }
  TGameObjectState = class
  private
    FWorldObject: TWorldObject;
    FRoom: TWorldRoom;
    FCarried: Boolean;
  public
    constructor Create(AWorldObject: TWorldObject);
    property WorldObject: TWorldObject read FWorldObject;
    property Room: TWorldRoom read FRoom write FRoom;
    property Carried: Boolean read FCarried write FCarried;
  end;

  TGameObjectStateList = specialize TObjectList<TGameObjectState>;

  { TGameSession owns transient play state for a live world. }
  TGameSession = class
  private
    FWorld: TWorld;
    FCurrentRoom: TWorldRoom;
    FPendingKind: TPlayerCommandKind;
    FPendingObjectIDs: TStringList;
    FObjectStates: TGameObjectStateList;
    function ObjectState(AObject: TWorldObject): TGameObjectState;
    function ObjectIsInRoom(AObject: TWorldObject; ARoom: TWorldRoom): Boolean;
    function ResolveObjectInRoom(ARoom: TWorldRoom; const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    function ResolveObjectInInventory(const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    function ResolveVisibleObject(ARoom: TWorldRoom; const ANameOrID: string;
      out AObject: TWorldObject): TObjectResolveStatus;
    function DescribeCurrentRoom: string;
    function Move(ADirection: TWorldDirection): string;
    function Examine(const ANounPhrase: string): string;
    function Take(const ANounPhrase: string): string;
    function Drop(const ANounPhrase: string): string;
    function DescribeInventory: string;
    function BeginDisambiguation(AKind: TPlayerCommandKind;
      const AName: string): string;
    function ExecutePendingChoice(const AInput: string): string;
    function ApplyObjectCommand(AKind: TPlayerCommandKind;
      AObject: TWorldObject): string;
    procedure ClearPendingChoice;
  public
    constructor Create(AWorld: TWorld);
    destructor Destroy; override;
    function ExecuteCommand(const ACommand: string): string;
    function IsObjectCarried(AObject: TWorldObject): Boolean;
    function RuntimeObjectRoom(AObject: TWorldObject): TWorldRoom;
    procedure SynchronizeWorldDefinitions;
    procedure Reset;
    { CurrentRoom is intentionally writable so builder operations can move the
      shared live session without duplicating player-location state. }
    property CurrentRoom: TWorldRoom read FCurrentRoom write FCurrentRoom;
  end;

implementation

constructor TGameObjectState.Create(AWorldObject: TWorldObject);
begin
  inherited Create;
  if AWorldObject = nil then
    raise EArgumentNilException.Create('AWorldObject');
  FWorldObject := AWorldObject;
  { WorldObject.Room is authored initial state. Runtime changes never write it. }
  FRoom := AWorldObject.Room;
  FCarried := AWorldObject.LocationKind = olPlayerInventory;
  if FCarried then
    FRoom := nil;
end;

constructor TGameSession.Create(AWorld: TWorld);
begin
  inherited Create;
  if AWorld = nil then
    raise EArgumentNilException.Create('AWorld');
  FWorld := AWorld;
  FObjectStates := TGameObjectStateList.Create(True);
  Reset;
  { Pending choices retain stable IDs rather than world-owned object pointers.
    Builder mutations can therefore never leave this transient state dangling. }
  FPendingObjectIDs := TStringList.Create;
  FPendingKind := pcUnknown;
end;

destructor TGameSession.Destroy;
begin
  FPendingObjectIDs.Free;
  FObjectStates.Free;
  inherited Destroy;
end;

function TGameSession.ObjectState(AObject: TWorldObject): TGameObjectState;
var
  State: TGameObjectState;
begin
  for State in FObjectStates do
    if State.WorldObject = AObject then
      Exit(State);
  { Builder-created objects become immediately testable without resetting. Their
    first runtime state is copied from their authored initial location. }
  Result := TGameObjectState.Create(AObject);
  FObjectStates.Add(Result);
end;

function TGameSession.ObjectIsInRoom(AObject: TWorldObject;
  ARoom: TWorldRoom): Boolean;
var
  State: TGameObjectState;
begin
  State := ObjectState(AObject);
  Result := (not State.Carried) and (State.Room = ARoom);
end;

function TGameSession.IsObjectCarried(AObject: TWorldObject): Boolean;
begin
  Result := ObjectState(AObject).Carried;
end;

function TGameSession.RuntimeObjectRoom(AObject: TWorldObject): TWorldRoom;
var
  State: TGameObjectState;
begin
  State := ObjectState(AObject);
  if State.Carried then
    Result := nil
  else
    Result := State.Room;
end;

procedure TGameSession.SynchronizeWorldDefinitions;
var
  I: Integer;
  WorldObject: TWorldObject;
  Found: Boolean;
begin
  { Builder operations may add or delete definitions while a test is running.
    Remove runtime records whose definitions no longer exist, comparing pointer
    identity only (never dereferencing a potentially deleted definition).
    Newly authored objects are initialized lazily by ObjectState when needed. }
  for I := FObjectStates.Count - 1 downto 0 do
  begin
    Found := False;
    for WorldObject in FWorld.Objects do
      if FObjectStates[I].WorldObject = WorldObject then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      FObjectStates.Delete(I);
  end;
end;

procedure TGameSession.Reset;
var
  WorldObject: TWorldObject;
begin
  FObjectStates.Clear;
  for WorldObject in FWorld.Objects do
    FObjectStates.Add(TGameObjectState.Create(WorldObject));
  if FWorld.Rooms.Count > 0 then
    FCurrentRoom := FWorld.Rooms[0]
  else
    FCurrentRoom := nil;
  if FPendingObjectIDs <> nil then
    ClearPendingChoice;
end;

function TGameSession.ResolveObjectInRoom(ARoom: TWorldRoom;
  const ANameOrID: string; out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  Ref: string;
begin
  AObject := nil;
  Ref := Trim(ANameOrID);
  for WorldObject in FWorld.Objects do
    if ObjectIsInRoom(WorldObject, ARoom) and SameText(WorldObject.ID, Ref) then
    begin AObject := WorldObject; Exit(orsUnique); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if ObjectIsInRoom(WorldObject, ARoom) and (Trim(WorldObject.Tag) <> '') and
      SameText(WorldObject.Tag, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 1 then Exit(orsUnique);
  if MatchCount > 1 then begin AObject := nil; Exit(orsAmbiguous); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if ObjectIsInRoom(WorldObject, ARoom) and SameText(WorldObject.Name, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 0 then Result := orsNotFound
  else if MatchCount = 1 then Result := orsUnique
  else begin AObject := nil; Result := orsAmbiguous; end;
end;

function TGameSession.ResolveObjectInInventory(const ANameOrID: string;
  out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  Ref: string;
begin
  AObject := nil;
  Ref := Trim(ANameOrID);
  for WorldObject in FWorld.Objects do
    if IsObjectCarried(WorldObject) and SameText(WorldObject.ID, Ref) then
    begin AObject := WorldObject; Exit(orsUnique); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if IsObjectCarried(WorldObject) and (Trim(WorldObject.Tag) <> '') and
      SameText(WorldObject.Tag, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 1 then Exit(orsUnique);
  if MatchCount > 1 then begin AObject := nil; Exit(orsAmbiguous); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if IsObjectCarried(WorldObject) and SameText(WorldObject.Name, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 0 then Result := orsNotFound
  else if MatchCount = 1 then Result := orsUnique
  else begin AObject := nil; Result := orsAmbiguous; end;
end;

function TGameSession.ResolveVisibleObject(ARoom: TWorldRoom;
  const ANameOrID: string; out AObject: TWorldObject): TObjectResolveStatus;
var
  WorldObject: TWorldObject;
  MatchCount: Integer;
  Ref: string;
begin
  AObject := nil;
  Ref := Trim(ANameOrID);
  for WorldObject in FWorld.Objects do
    if (IsObjectCarried(WorldObject) or ObjectIsInRoom(WorldObject, ARoom)) and
      SameText(WorldObject.ID, Ref) then
    begin AObject := WorldObject; Exit(orsUnique); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if (IsObjectCarried(WorldObject) or ObjectIsInRoom(WorldObject, ARoom)) and
      (Trim(WorldObject.Tag) <> '') and SameText(WorldObject.Tag, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 1 then Exit(orsUnique);
  if MatchCount > 1 then begin AObject := nil; Exit(orsAmbiguous); end;
  MatchCount := 0;
  for WorldObject in FWorld.Objects do
    if (IsObjectCarried(WorldObject) or ObjectIsInRoom(WorldObject, ARoom)) and
      SameText(WorldObject.Name, Ref) then
    begin Inc(MatchCount); if MatchCount = 1 then AObject := WorldObject; end;
  if MatchCount = 0 then Result := orsNotFound
  else if MatchCount = 1 then Result := orsUnique
  else begin AObject := nil; Result := orsAmbiguous; end;
end;

procedure TGameSession.ClearPendingChoice;
begin
  FPendingObjectIDs.Clear;
  FPendingKind := pcUnknown;
end;

function TGameSession.DescribeCurrentRoom: string;
var
  WorldObject: TWorldObject;
  ObjectsText: string;
begin
  if FCurrentRoom = nil then
    Exit('You are nowhere.');

  Result := FCurrentRoom.Name;
  if Trim(FCurrentRoom.Description) <> '' then
    Result := Result + LineEnding + FCurrentRoom.Description;

  { Room contents are derived from the world's object collection rather than
    cached on the room, keeping one authoritative location reference. }
  ObjectsText := '';
  for WorldObject in FWorld.Objects do
    if ObjectIsInRoom(WorldObject, FCurrentRoom) then
    begin
      if ObjectsText <> '' then
        ObjectsText := ObjectsText + ', ';
      ObjectsText := ObjectsText + WorldObject.Name;
    end;
  if ObjectsText <> '' then
    Result := Result + LineEnding + 'You can see ' + ObjectsText + ' here.';
end;

function TGameSession.Move(ADirection: TWorldDirection): string;
var
  Destination: TWorldRoom;
begin
  if FCurrentRoom = nil then
    Exit('You are nowhere.');

  Destination := FCurrentRoom.ExitTo(ADirection);
  if Destination = nil then
    Exit('You cannot go that way.');

  FCurrentRoom := Destination;
  Result := DescribeCurrentRoom;
end;

function TGameSession.ApplyObjectCommand(AKind: TPlayerCommandKind;
  AObject: TWorldObject): string;
begin
  case AKind of
    pcExamine:
      begin
        if Trim(AObject.Description) <> '' then
          Result := AObject.Description
        else
          Result := 'You see nothing special about the ' + AObject.Name + '.';
      end;
    pcTake:
      begin
        with ObjectState(AObject) do
        begin
          Carried := True;
          Room := nil;
        end;
        Result := 'Taken.';
      end;
    pcDrop:
      begin
        if FCurrentRoom = nil then
          Result := 'You are nowhere, so there is nowhere to drop it.'
        else
        begin
          with ObjectState(AObject) do
          begin
            Carried := False;
            Room := FCurrentRoom;
          end;
          Result := 'Dropped.';
        end;
      end;
  else
    Result := '';
  end;
end;

function TGameSession.BeginDisambiguation(AKind: TPlayerCommandKind;
  const AName: string): string;
var
  WorldObject: TWorldObject;
  I: Integer;
  IsCandidate: Boolean;
  LocationText: string;
begin
  ClearPendingChoice;
  FPendingKind := AKind;

  for WorldObject in FWorld.Objects do
  begin
    case AKind of
      pcExamine:
        IsCandidate := SameText(WorldObject.Name, Trim(AName)) and
          ((IsObjectCarried(WorldObject)) or
           (ObjectIsInRoom(WorldObject, FCurrentRoom)));
      pcTake:
        IsCandidate := SameText(WorldObject.Name, Trim(AName)) and
          ObjectIsInRoom(WorldObject, FCurrentRoom);
      pcDrop:
        IsCandidate := SameText(WorldObject.Name, Trim(AName)) and
          (IsObjectCarried(WorldObject));
    else
      IsCandidate := False;
    end;
    if IsCandidate then
      FPendingObjectIDs.Add(WorldObject.ID);
  end;

  Result := 'Which "' + Trim(AName) + '" do you mean?';
  for I := 0 to FPendingObjectIDs.Count - 1 do
  begin
    WorldObject := FWorld.FindObjectByID(FPendingObjectIDs[I]);
    if WorldObject = nil then
      Continue;
    if IsObjectCarried(WorldObject) then
      LocationText := 'carried'
    else
      LocationText := 'here';
    if Trim(WorldObject.Tag) <> '' then
      Result := Result + LineEnding + IntToStr(I + 1) + '. ' +
        WorldObject.Tag + ' (' + LocationText + ')'
    else
      Result := Result + LineEnding + IntToStr(I + 1) + '. ' +
        WorldObject.Name + ' #' + IntToStr(I + 1) +
        ' (' + LocationText + ')';
  end;
  Result := Result + LineEnding + 'Enter a number, or another command to cancel.';
end;

function TGameSession.ExecutePendingChoice(const AInput: string): string;
var
  Choice, Code: Integer;
  ChosenObject: TWorldObject;
  PendingKind: TPlayerCommandKind;
begin
  Val(Trim(AInput), Choice, Code);
  if (Code <> 0) or (Choice < 1) or (Choice > FPendingObjectIDs.Count) then
    Exit('');

  { Resolve the stable ID only when the player answers. The world may have
    changed since the ambiguity prompt was displayed. }
  ChosenObject := FWorld.FindObjectByID(FPendingObjectIDs[Choice - 1]);
  PendingKind := FPendingKind;
  ClearPendingChoice;
  if ChosenObject = nil then
    Exit('That choice is no longer available.');
  Result := ApplyObjectCommand(PendingKind, ChosenObject);
end;

function TGameSession.Examine(const ANounPhrase: string): string;
var
  WorldObject: TWorldObject;
  ResolveStatus: TObjectResolveStatus;
begin
  ResolveStatus := ResolveVisibleObject(FCurrentRoom, ANounPhrase,
    WorldObject);
  case ResolveStatus of
    orsAmbiguous:
      Exit(BeginDisambiguation(pcExamine, ANounPhrase));
    orsNotFound:
      Exit('You do not see "' + Trim(ANounPhrase) + '" here.');
  end;

  if Trim(WorldObject.Description) <> '' then
    Exit(WorldObject.Description);
  Result := 'You see nothing special about the ' + WorldObject.Name + '.';
end;

function TGameSession.Take(const ANounPhrase: string): string;
var
  WorldObject: TWorldObject;
  ResolveStatus: TObjectResolveStatus;
begin
  ResolveStatus := ResolveObjectInRoom(FCurrentRoom, ANounPhrase,
    WorldObject);
  case ResolveStatus of
    orsAmbiguous:
      Exit(BeginDisambiguation(pcTake, ANounPhrase));
    orsNotFound:
      Exit('You do not see "' + Trim(ANounPhrase) + '" here.');
  end;

  with ObjectState(WorldObject) do
  begin
    Carried := True;
    Room := nil;
  end;
  Result := 'Taken.';
end;

function TGameSession.Drop(const ANounPhrase: string): string;
var
  WorldObject: TWorldObject;
  ResolveStatus: TObjectResolveStatus;
begin
  ResolveStatus := ResolveObjectInInventory(ANounPhrase, WorldObject);
  case ResolveStatus of
    orsAmbiguous:
      Exit(BeginDisambiguation(pcDrop, ANounPhrase));
    orsNotFound:
      Exit('You are not carrying "' + Trim(ANounPhrase) + '".');
  end;

  if FCurrentRoom = nil then
    Exit('You are nowhere, so there is nowhere to drop it.');
  with ObjectState(WorldObject) do
  begin
    Carried := False;
    Room := FCurrentRoom;
  end;
  Result := 'Dropped.';
end;

function TGameSession.DescribeInventory: string;
var
  WorldObject: TWorldObject;
  InventoryText: string;
begin
  InventoryText := '';
  for WorldObject in FWorld.Objects do
    if IsObjectCarried(WorldObject) then
    begin
      if InventoryText <> '' then
        InventoryText := InventoryText + ', ';
      InventoryText := InventoryText + WorldObject.Name;
    end;

  if InventoryText = '' then
    Result := 'You are carrying nothing.'
  else
    Result := 'You are carrying ' + InventoryText + '.';
end;

function TGameSession.ExecuteCommand(const ACommand: string): string;
var
  Parsed: TParsedPlayerCommand;
begin
  if Trim(ACommand) = '' then
    Exit('');

  if FPendingObjectIDs.Count > 0 then
  begin
    Result := ExecutePendingChoice(ACommand);
    if Result <> '' then
      Exit;
    { Any non-choice input is a new command and cancels the pending question. }
    ClearPendingChoice;
  end;

  Parsed := ParsePlayerCommand(ACommand);
  case Parsed.Kind of
    pcLook:
      Result := DescribeCurrentRoom;
    pcMove:
      Result := Move(Parsed.Direction);
    pcExamine:
      Result := Examine(Parsed.NounPhrase);
    pcTake:
      Result := Take(Parsed.NounPhrase);
    pcDrop:
      Result := Drop(Parsed.NounPhrase);
    pcInventory:
      Result := DescribeInventory;
  else
    Result := 'I do not understand "' + Trim(ACommand) + '".';
  end;
end;

end.
