unit WGameSession;

{ Runtime player session.

  TGameSession owns transient play state but never owns TWorld or its entities.
  It receives semantic parser results, resolves them against the live model,
  and applies player-visible effects such as movement and examination. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, WWorld, WParser;

type
  { TGameSession owns transient play state for a live world. }
  TGameSession = class
  private
    FWorld: TWorld;
    FCurrentRoom: TWorldRoom;
    FPendingKind: TPlayerCommandKind;
    FPendingObjectIDs: TStringList;
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
    { CurrentRoom is intentionally writable so builder operations can move the
      shared live session without duplicating player-location state. }
    property CurrentRoom: TWorldRoom read FCurrentRoom write FCurrentRoom;
  end;

implementation

constructor TGameSession.Create(AWorld: TWorld);
begin
  inherited Create;
  if AWorld = nil then
    raise EArgumentNilException.Create('AWorld');
  FWorld := AWorld;
  if FWorld.Rooms.Count > 0 then
    FCurrentRoom := FWorld.Rooms[0];
  { Pending choices retain stable IDs rather than world-owned object pointers.
    Builder mutations can therefore never leave this transient state dangling. }
  FPendingObjectIDs := TStringList.Create;
  FPendingKind := pcUnknown;
end;

destructor TGameSession.Destroy;
begin
  FPendingObjectIDs.Free;
  inherited Destroy;
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
    if (WorldObject.LocationKind = olRoom) and
      (WorldObject.Room = FCurrentRoom) then
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
        AObject.MoveToPlayerInventory;
        Result := 'Taken.';
      end;
    pcDrop:
      begin
        if FCurrentRoom = nil then
          Result := 'You are nowhere, so there is nowhere to drop it.'
        else
        begin
          AObject.MoveToRoom(FCurrentRoom);
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
          ((WorldObject.LocationKind = olPlayerInventory) or
           ((WorldObject.LocationKind = olRoom) and
            (WorldObject.Room = FCurrentRoom)));
      pcTake:
        IsCandidate := SameText(WorldObject.Name, Trim(AName)) and
          (WorldObject.LocationKind = olRoom) and
          (WorldObject.Room = FCurrentRoom);
      pcDrop:
        IsCandidate := SameText(WorldObject.Name, Trim(AName)) and
          (WorldObject.LocationKind = olPlayerInventory);
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
    if WorldObject.LocationKind = olPlayerInventory then
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
  ResolveStatus := FWorld.ResolveVisibleObject(FCurrentRoom, ANounPhrase,
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
  ResolveStatus := FWorld.ResolveObjectInRoom(FCurrentRoom, ANounPhrase,
    WorldObject);
  case ResolveStatus of
    orsAmbiguous:
      Exit(BeginDisambiguation(pcTake, ANounPhrase));
    orsNotFound:
      Exit('You do not see "' + Trim(ANounPhrase) + '" here.');
  end;

  WorldObject.MoveToPlayerInventory;
  Result := 'Taken.';
end;

function TGameSession.Drop(const ANounPhrase: string): string;
var
  WorldObject: TWorldObject;
  ResolveStatus: TObjectResolveStatus;
begin
  ResolveStatus := FWorld.ResolveObjectInInventory(ANounPhrase, WorldObject);
  case ResolveStatus of
    orsAmbiguous:
      Exit(BeginDisambiguation(pcDrop, ANounPhrase));
    orsNotFound:
      Exit('You are not carrying "' + Trim(ANounPhrase) + '".');
  end;

  if FCurrentRoom = nil then
    Exit('You are nowhere, so there is nowhere to drop it.');
  WorldObject.MoveToRoom(FCurrentRoom);
  Result := 'Dropped.';
end;

function TGameSession.DescribeInventory: string;
var
  WorldObject: TWorldObject;
  InventoryText: string;
begin
  InventoryText := '';
  for WorldObject in FWorld.Objects do
    if WorldObject.LocationKind = olPlayerInventory then
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
