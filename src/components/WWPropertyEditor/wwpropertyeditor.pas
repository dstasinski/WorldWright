unit WWPropertyEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Grids, ComCtrls, Graphics;

type
  { TWWPropertyKind identifies the editor semantics of a property independently
    of its displayed text. More kinds can be added without coupling this
    component to WorldWright's world model. }
  TWWPropertyKind = (
    wpkReadOnly,
    wpkText,
    wpkBoolean,
    wpkEnum,
    wpkReference,
    wpkStructured,
    wpkDialog,
    wpkEvent
  );

  { TWWPropertyItem is one row of property metadata. ID is a stable,
    non-visual key supplied by the host; Name is the author-facing caption.
    The collection owns its items. }
  TWWPropertyItem = class(TCollectionItem)
  private
    FID: string;
    FCategory: string;
    FKind: TWWPropertyKind;
    FName: string;
    FValue: string;
  published
    property ID: string read FID write FID;
    property Category: string read FCategory write FCategory;
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

  { The host validates proposed edits because only it understands model
    semantics. Set Accept False to reject the edit and restore the old value. }
  TWWPropertyChangedEvent = procedure(Sender: TObject;
    AProperty: TWWPropertyItem; const AOldValue, ANewValue: string;
    var Accept: Boolean) of object;

  { TWWPropertyEditor is a reusable Lazarus/Delphi-style property inspector.
    It owns property metadata and presents it through a two-column grid.
    Model objects are deliberately unknown to this control: the host populates
    Properties and later receives edits through OnPropertyChanged.

    Event-valued rows use wpkEvent as a presentation/editing contract only;
    the component does not know what an event means or what model owns it.

    Each TWWPropertyKind describes an editing capability rather than a world
    model type. Text uses controlled inline editing today; Boolean, enum,
    reference, structured, dialog, and event kinds are neutral contracts for
    dedicated editors added incrementally. The host must accept proposed model
    changes through OnPropertyChanged, keeping this control presentation-only.
    Read-only/category cells never enter an inline editor. }
  TWWPropertyEditor = class(TCustomControl)
  private
    FPageControl: TPageControl;
    FPropertiesTab: TTabSheet;
    FEventsTab: TTabSheet;
    FGrid: TStringGrid;
    FEventsGrid: TStringGrid;
    FProperties: TWWPropertyItems;
    FOnPropertyChanged: TWWPropertyChangedEvent;
    procedure ConfigureGrid(AGrid: TStringGrid);
    function PropertyForGridRow(AGrid: TStringGrid;
      ARow: Integer): TWWPropertyItem;
    procedure GridSelectEditor(Sender: TObject; ACol, ARow: Integer;
      var Editor: TWinControl);
    procedure GridDrawCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);
    procedure GridPrepareCanvas(Sender: TObject; ACol, ARow: Integer;
      AState: TGridDrawState);
    procedure GridValidateEntry(Sender: TObject; ACol, ARow: Integer;
      const OldValue: string; var NewValue: string);
    procedure SetProperties(AValue: TWWPropertyItems);
    procedure SyncGrid;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function AddProperty(const AID, AName, AValue: string;
      AKind: TWWPropertyKind = wpkReadOnly;
      const ACategory: string = 'General'): TWWPropertyItem;
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

  { Keep the inspector's permanent visual structure inside the reusable
    component. Hosts see one control, while authors get the familiar
    Properties/Events split used by Lazarus and Delphi inspectors. }
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;

  FPropertiesTab := TTabSheet.Create(FPageControl);
  FPropertiesTab.PageControl := FPageControl;
  FPropertiesTab.Caption := 'Properties';

  FEventsTab := TTabSheet.Create(FPageControl);
  FEventsTab.PageControl := FPageControl;
  FEventsTab.Caption := 'Events';

  FGrid := TStringGrid.Create(FPropertiesTab);
  FGrid.Parent := FPropertiesTab;
  ConfigureGrid(FGrid);
  FGrid.OnValidateEntry := @GridValidateEntry;

  FEventsGrid := TStringGrid.Create(FEventsTab);
  FEventsGrid.Parent := FEventsTab;
  ConfigureGrid(FEventsGrid);
  { Event editing/opening is deliberately deferred until neutral rule objects
    exist. The tab is real now so future event support does not require another
    inspector-layout replacement. }
  FEventsGrid.Options := FEventsGrid.Options - [goEditing];

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

procedure TWWPropertyEditor.ConfigureGrid(AGrid: TStringGrid);
begin
  AGrid.Align := alClient;
  AGrid.ColCount := 2;
  AGrid.FixedCols := 0;
  AGrid.FixedRows := 1;
  AGrid.RowCount := 1;
  { Horizontal rules retain row structure. Vertical rules are drawn explicitly
    for real property rows so category headings can genuinely span both
    columns without a misleading divider through the heading. }
  AGrid.Options := [goFixedHorzLine, goHorzLine, goRangeSelect,
    goSmoothScroll, goEditing];
  AGrid.Cells[0, 0] := 'Property';
  AGrid.Cells[1, 0] := 'Value';
  AGrid.TabStop := True;
  AGrid.OnSelectEditor := @GridSelectEditor;
  AGrid.OnDrawCell := @GridDrawCell;
  AGrid.OnPrepareCanvas := @GridPrepareCanvas;
end;

function TWWPropertyEditor.PropertyForGridRow(AGrid: TStringGrid;
  ARow: Integer): TWWPropertyItem;
var
  I: Integer;
  WantedName, WantedValue: string;
begin
  Result := nil;
  if (ARow < 1) or (ARow >= AGrid.RowCount) then
    Exit;

  WantedName := Trim(AGrid.Cells[0, ARow]);
  WantedValue := AGrid.Cells[1, ARow];
  if WantedValue = '' then
    Exit; { Category rows have no value and never map to metadata. }

  for I := 0 to FProperties.Count - 1 do
    if (FProperties[I].Kind = wpkEvent) = (AGrid = FEventsGrid) then
      if SameText(FProperties[I].Name, WantedName) and
        (FProperties[I].Value = WantedValue) then
      begin
        Result := FProperties[I];
        Exit;
      end;
end;

procedure TWWPropertyEditor.GridSelectEditor(Sender: TObject;
  ACol, ARow: Integer; var Editor: TWinControl);
var
  Grid: TStringGrid;
  Prop: TWWPropertyItem;
begin
  Grid := TStringGrid(Sender);

  { Lazarus property editors expose editing capabilities by property type.
    WorldWright follows the same principle without depending on IDE RTTI.
    For this foundation slice, only plain text values use TStringGrid's
    built-in editor. Other kinds will receive dedicated editors incrementally. }
  if ACol <> 1 then
  begin
    Editor := nil;
    Exit;
  end;

  Prop := PropertyForGridRow(Grid, ARow);
  if (Prop = nil) or (Prop.Kind <> wpkText) then
    Editor := nil;
end;

procedure TWWPropertyEditor.GridDrawCell(Sender: TObject;
  ACol, ARow: Integer; ARect: TRect; AState: TGridDrawState);
var
  Grid: TStringGrid;
  Prop: TWWPropertyItem;
  FullRect: TRect;
  CategoryCaption: string;
begin
  Grid := TStringGrid(Sender);
  if ARow = 0 then
    Exit;

  Prop := PropertyForGridRow(Grid, ARow);
  if Prop <> nil then
  begin
    { With global vertical grid lines disabled, draw the property/value divider
      only on actual property rows. This preserves the familiar two-column
      inspector while category rows remain visually full width. }
    if ACol = 0 then
    begin
      Grid.Canvas.Pen.Color := clBtnShadow;
      Grid.Canvas.MoveTo(ARect.Right - 1, ARect.Top);
      Grid.Canvas.LineTo(ARect.Right - 1, ARect.Bottom);
    end;
    Exit;
  end;

  { Category headings are one logical section header, not a property/value
    pair. Draw the first cell across both columns and suppress the second-cell
    divider/content so authors do not see a misleading empty Value field. }
  if ACol = 0 then
  begin
    FullRect := ARect;
    FullRect.Right := Grid.ClientWidth;
    Grid.Canvas.Brush.Color := clBtnFace;
    Grid.Canvas.FillRect(FullRect);
    Grid.Canvas.Font.Style := [fsBold];
    CategoryCaption := Grid.Cells[0, ARow];
    Grid.Canvas.TextOut(FullRect.Left + 4, FullRect.Top +
      (FullRect.Bottom - FullRect.Top - Grid.Canvas.TextHeight(CategoryCaption)) div 2,
      CategoryCaption);
  end
  else
  begin
    Grid.Canvas.Brush.Color := clBtnFace;
    Grid.Canvas.FillRect(ARect);
  end;
end;

procedure TWWPropertyEditor.GridPrepareCanvas(Sender: TObject;
  ACol, ARow: Integer; AState: TGridDrawState);
var
  Grid: TStringGrid;
  Prop: TWWPropertyItem;
begin
  Grid := TStringGrid(Sender);
  if ARow = 0 then
    Exit;

  Prop := PropertyForGridRow(Grid, ARow);
  if Prop = nil then
  begin
    { Category headings are structural rows. Bold text gives the inspector the
      familiar Object Inspector hierarchy without pretending categories are
      editable properties. }
    Grid.Canvas.Font.Style := [fsBold];
    Grid.Canvas.Brush.Color := clBtnFace;
    Exit;
  end;

  if Prop.Kind = wpkReadOnly then
    Grid.Canvas.Font.Color := clGrayText;
end;

procedure TWWPropertyEditor.GridValidateEntry(Sender: TObject;
  ACol, ARow: Integer; const OldValue: string; var NewValue: string);
var
  Accept: Boolean;
  Prop: TWWPropertyItem;
begin
  { Only value cells backed by wpkText are editable. TStringGrid supplies one
    editor for the grid, so validation is the final authority that prevents
    property names and protected values from becoming UI-only state. }
  if ACol <> 1 then
  begin
    NewValue := OldValue;
    Exit;
  end;

  Prop := PropertyForGridRow(FGrid, ARow);
  if Prop = nil then
  begin
    NewValue := OldValue;
    Exit;
  end;
  if Prop.Kind <> wpkText then
  begin
    NewValue := OldValue;
    Exit;
  end;

  if NewValue = OldValue then
    Exit;

  { An edit is rejected unless the host explicitly accepts it. This prevents
    the inspector from ever becoming a second, unsynchronized data model. }
  Accept := False;
  if Assigned(FOnPropertyChanged) then
    FOnPropertyChanged(Self, Prop, OldValue, NewValue, Accept);

  if not Accept then
    NewValue := OldValue;
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
  I, J: Integer;
  Category: string;
  CategorySeen: Boolean;

  procedure AddCategoryRow(AGrid: TStringGrid; const ACategory: string);
  begin
    AGrid.RowCount := AGrid.RowCount + 1;
    AGrid.Cells[0, AGrid.RowCount - 1] := ACategory;
    AGrid.Cells[1, AGrid.RowCount - 1] := '';
  end;

  procedure AddItemRow(AGrid: TStringGrid; AItem: TWWPropertyItem);
  begin
    AGrid.RowCount := AGrid.RowCount + 1;
    AGrid.Cells[0, AGrid.RowCount - 1] := '  ' + AItem.Name;
    AGrid.Cells[1, AGrid.RowCount - 1] := AItem.Value;
  end;
begin
  if FGrid = nil then
    Exit;

  { Properties and Events are two projections of the same neutral metadata
    collection. This keeps the host API stable while giving each semantic kind
    its own Lazarus/Delphi-style inspector tab. }
  FGrid.RowCount := 1;
  FEventsGrid.RowCount := 1;

  { Render each category once, in first-use order, followed by its indented
    members. Category rows deliberately have no value; they are presentation
    structure rather than editable property metadata. }
  for I := 0 to FProperties.Count - 1 do
  begin
    Category := Trim(FProperties[I].Category);
    if Category = '' then
      Category := 'General';

    CategorySeen := False;
    for J := 0 to I - 1 do
      if SameText(Trim(FProperties[J].Category), Category) and
        ((FProperties[J].Kind = wpkEvent) =
         (FProperties[I].Kind = wpkEvent)) then
      begin
        CategorySeen := True;
        Break;
      end;
    if CategorySeen then
      Continue;

    if FProperties[I].Kind = wpkEvent then
      AddCategoryRow(FEventsGrid, Category)
    else
      AddCategoryRow(FGrid, Category);

    for J := I to FProperties.Count - 1 do
      if SameText(Trim(FProperties[J].Category), Category) and
        ((FProperties[J].Kind = wpkEvent) =
         (FProperties[I].Kind = wpkEvent)) then
      begin
        if FProperties[J].Kind = wpkEvent then
          AddItemRow(FEventsGrid, FProperties[J])
        else
          AddItemRow(FGrid, FProperties[J]);
      end;
  end;

  { Keep a useful Lazarus-style property/value split while respecting the
    component's actual width. TStringGrid's column boundary can be dragged by
    the user; Resize intentionally rebalances it only when the whole inspector
    changes size. }
  if FGrid.ClientWidth > 80 then
  begin
    FGrid.ColWidths[0] := FGrid.ClientWidth div 2;
    FGrid.ColWidths[1] := FGrid.ClientWidth - FGrid.ColWidths[0] - 1;
  end;
  if FEventsGrid.ClientWidth > 80 then
  begin
    FEventsGrid.ColWidths[0] := FEventsGrid.ClientWidth div 2;
    FEventsGrid.ColWidths[1] := FEventsGrid.ClientWidth -
      FEventsGrid.ColWidths[0] - 1;
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
  SyncGrid;
end;

function TWWPropertyEditor.AddProperty(const AID, AName, AValue: string;
  AKind: TWWPropertyKind; const ACategory: string): TWWPropertyItem;
begin
  Result := FProperties.Add;
  Result.ID := AID;
  Result.Category := ACategory;
  Result.Name := AName;
  Result.Value := AValue;
  Result.Kind := AKind;
  SyncGrid;
end;

end.
