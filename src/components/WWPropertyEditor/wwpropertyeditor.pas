unit WWPropertyEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Grids;

type
  { TWWPropertyKind identifies the editor semantics of a property independently
    of its displayed text. More kinds can be added without coupling this
    component to WorldWright's world model. }
  TWWPropertyKind = (wpkReadOnly, wpkText, wpkEvent);

  { TWWPropertyItem is one row of property metadata. ID is a stable,
    non-visual key supplied by the host; Name is the author-facing caption.
    The collection owns its items. }
  TWWPropertyItem = class(TCollectionItem)
  private
    FID: string;
    FKind: TWWPropertyKind;
    FName: string;
    FValue: string;
  published
    property ID: string read FID write FID;
    property Kind: TWWPropertyKind read FKind write FKind default wpkReadOnly;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
  end;

  TWWPropertyItems = class(TOwnedCollection)
  private
    function GetItem(AIndex: Integer): TWWPropertyItem;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TWWPropertyItem;
    property Items[AIndex: Integer]: TWWPropertyItem read GetItem; default;
  end;

  TWWPropertyChangedEvent = procedure(Sender: TObject;
    AProperty: TWWPropertyItem; const AOldValue, ANewValue: string) of object;

  { TWWPropertyEditor is a reusable Lazarus/Delphi-style property inspector.
    It owns property metadata and presents it through a two-column grid.
    Model objects are deliberately unknown to this control: the host populates
    Properties and later receives edits through OnPropertyChanged.

    Event-valued rows use wpkEvent as a presentation/editing contract only;
    the component does not know what an event means or what model owns it.

    This first milestone establishes the data/API boundary and read-only
    rendering. Inline editing is intentionally deferred until the host can
    validate and commit changes to its model rather than creating UI-only
    state. }
  TWWPropertyEditor = class(TCustomControl)
  private
    FGrid: TStringGrid;
    FProperties: TWWPropertyItems;
    FOnPropertyChanged: TWWPropertyChangedEvent;
    procedure PropertiesChanged(Sender: TObject);
    procedure SetProperties(AValue: TWWPropertyItems);
    procedure SyncGrid;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function AddProperty(const AID, AName, AValue: string;
      AKind: TWWPropertyKind = wpkReadOnly): TWWPropertyItem;
  published
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property PopupMenu;
    property Properties: TWWPropertyItems read FProperties write SetProperties;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnPropertyChanged: TWWPropertyChangedEvent
      read FOnPropertyChanged write FOnPropertyChanged;
  end;

implementation

constructor TWWPropertyItems.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TWWPropertyItem);
end;

function TWWPropertyItems.Add: TWWPropertyItem;
begin
  Result := TWWPropertyItem(inherited Add);
end;

function TWWPropertyItems.GetItem(AIndex: Integer): TWWPropertyItem;
begin
  Result := TWWPropertyItem(inherited Items[AIndex]);
end;

constructor TWWPropertyEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProperties := TWWPropertyItems.Create(Self);
  FProperties.OnChange := @PropertiesChanged;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ColCount := 2;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.RowCount := 1;
  FGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    goRangeSelect, goSmoothScroll];
  FGrid.Cells[0, 0] := 'Property';
  FGrid.Cells[1, 0] := 'Value';
  FGrid.TabStop := True;

  Width := 280;
  Height := 200;
  SyncGrid;
end;

destructor TWWPropertyEditor.Destroy;
begin
  { FGrid is owned by Self through the LCL component ownership mechanism. }
  FProperties.Free;
  inherited Destroy;
end;

procedure TWWPropertyEditor.PropertiesChanged(Sender: TObject);
begin
  SyncGrid;
end;

procedure TWWPropertyEditor.SetProperties(AValue: TWWPropertyItems);
begin
  if AValue = FProperties then
    Exit;
  FProperties.Assign(AValue);
  SyncGrid;
end;

procedure TWWPropertyEditor.SyncGrid;
var
  I: Integer;
begin
  if FGrid = nil then
    Exit;

  FGrid.RowCount := FProperties.Count + 1;
  FGrid.Cells[0, 0] := 'Property';
  FGrid.Cells[1, 0] := 'Value';

  for I := 0 to FProperties.Count - 1 do
  begin
    FGrid.Cells[0, I + 1] := FProperties[I].Name;
    FGrid.Cells[1, I + 1] := FProperties[I].Value;
  end;

  { Keep a useful Lazarus-style property/value split while respecting the
    component's actual width. A later milestone will make the divider user
    adjustable and persistent. }
  if FGrid.ClientWidth > 80 then
  begin
    FGrid.ColWidths[0] := FGrid.ClientWidth div 2;
    FGrid.ColWidths[1] := FGrid.ClientWidth - FGrid.ColWidths[0] - 1;
  end;
end;

procedure TWWPropertyEditor.Resize;
begin
  inherited Resize;
  SyncGrid;
end;

procedure TWWPropertyEditor.Clear;
begin
  FProperties.Clear;
end;

function TWWPropertyEditor.AddProperty(const AID, AName, AValue: string;
  AKind: TWWPropertyKind): TWWPropertyItem;
begin
  Result := FProperties.Add;
  Result.ID := AID;
  Result.Name := AName;
  Result.Value := AValue;
  Result.Kind := AKind;
end;

end.
