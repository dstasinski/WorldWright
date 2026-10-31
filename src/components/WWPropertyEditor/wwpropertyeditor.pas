unit WWPropertyEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, ExtCtrls, StdCtrls, Graphics, Forms;

type
  { Editor capabilities are deliberately independent of WorldWright model
    classes. Hosts describe how a value should be edited; this component only
    supplies the corresponding authoring UI. }
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

  TWWPropertyChangedEvent = procedure(Sender: TObject;
    AProperty: TWWPropertyItem; const AOldValue, ANewValue: string;
    var Accept: Boolean) of object;

  { TWWPropertyEditor is a purpose-built Object Inspector surface.

    Earlier versions used TStringGrid. That made category rows, focus routing,
    and per-type editors depend on grid internals and widgetset-specific
    painting. The inspector now owns explicit rows instead: category rows are
    genuinely single-column controls, while property rows contain a name label
    and a separate value control. This mirrors the useful interaction model of
    Lazarus's Object Inspector without coupling WorldWright to IDE RTTI. }
  TWWPropertyEditor = class(TCustomControl)
  private
    FPageControl: TPageControl;
    FPropertiesTab: TTabSheet;
    FEventsTab: TTabSheet;
    FPropertiesBox: TScrollBox;
    FEventsBox: TScrollBox;
    FProperties: TWWPropertyItems;
    FOnPropertyChanged: TWWPropertyChangedEvent;
    FDividerPercent: Integer;
    procedure BuildPage(ABox: TScrollBox; AEvents: Boolean);
    procedure NameLabelClick(Sender: TObject);
    procedure SetProperties(AValue: TWWPropertyItems);
    procedure SyncInspector;
    procedure ValueEditExit(Sender: TObject);
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
  FDividerPercent := 48;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;

  FPropertiesTab := TTabSheet.Create(FPageControl);
  FPropertiesTab.PageControl := FPageControl;
  FPropertiesTab.Caption := 'Properties';

  FEventsTab := TTabSheet.Create(FPageControl);
  FEventsTab.PageControl := FPageControl;
  FEventsTab.Caption := 'Events';

  FPropertiesBox := TScrollBox.Create(FPropertiesTab);
  FPropertiesBox.Parent := FPropertiesTab;
  FPropertiesBox.Align := alClient;
  FPropertiesBox.BorderStyle := bsNone;

  FEventsBox := TScrollBox.Create(FEventsTab);
  FEventsBox.Parent := FEventsTab;
  FEventsBox.Align := alClient;
  FEventsBox.BorderStyle := bsNone;

  Width := 280;
  Height := 200;
  SyncInspector;
end;

destructor TWWPropertyEditor.Destroy;
begin
  FProperties.Free;
  inherited Destroy;
end;

procedure TWWPropertyEditor.BuildPage(ABox: TScrollBox; AEvents: Boolean);
var
  I, J, TopPos, Divider: Integer;
  Category: string;
  CategorySeen: Boolean;
  HeaderPanel, CategoryPanel, RowPanel: TPanel;
  HeaderProperty, HeaderValue, NameLabel: TLabel;
  ValueEdit: TEdit;
begin
  { Rows are rebuilt from metadata. They are disposable views; no authored
    state is stored in the controls themselves. }
  while ABox.ControlCount > 0 do
    ABox.Controls[0].Free;

  TopPos := 0;
  Divider := (ABox.ClientWidth * FDividerPercent) div 100;
  if Divider < 80 then
    Divider := 80;

  { Keep the familiar Object Inspector column captions above the categorized
    rows. The header is presentation only; category rows below still span the
    full width and are not divided into property/value cells. }
  HeaderPanel := TPanel.Create(ABox);
  HeaderPanel.Parent := ABox;
  HeaderPanel.SetBounds(0, TopPos, ABox.ClientWidth, 28);
  HeaderPanel.Anchors := [akLeft, akTop, akRight];
  HeaderPanel.BevelOuter := bvNone;
  HeaderPanel.Caption := '';

  HeaderProperty := TLabel.Create(HeaderPanel);
  HeaderProperty.Parent := HeaderPanel;
  HeaderProperty.SetBounds(8, 5, Divider - 12, 20);
  HeaderProperty.AutoSize := False;
  HeaderProperty.Caption := 'Property';
  HeaderProperty.Font.Style := [fsBold];

  HeaderValue := TLabel.Create(HeaderPanel);
  HeaderValue.Parent := HeaderPanel;
  HeaderValue.SetBounds(Divider + 4, 5,
    HeaderPanel.ClientWidth - Divider - 8, 20);
  HeaderValue.AutoSize := False;
  HeaderValue.Anchors := [akLeft, akTop, akRight];
  HeaderValue.Caption := 'Value';
  HeaderValue.Font.Style := [fsBold];
  Inc(TopPos, HeaderPanel.Height);

  for I := 0 to FProperties.Count - 1 do
  begin
    if (FProperties[I].Kind = wpkEvent) <> AEvents then
      Continue;

    Category := Trim(FProperties[I].Category);
    if Category = '' then
      Category := 'General';

    CategorySeen := False;
    for J := 0 to I - 1 do
      if ((FProperties[J].Kind = wpkEvent) = AEvents) and
        SameText(Trim(FProperties[J].Category), Category) then
      begin
        CategorySeen := True;
        Break;
      end;
    if CategorySeen then
      Continue;

    { A category is one real full-width control. There is no hidden or painted
      second column, so selection and widgetset drawing cannot expose one. }
    CategoryPanel := TPanel.Create(ABox);
    CategoryPanel.Parent := ABox;
    CategoryPanel.SetBounds(0, TopPos, ABox.ClientWidth, 26);
    CategoryPanel.Anchors := [akLeft, akTop, akRight];
    CategoryPanel.Alignment := taLeftJustify;
    CategoryPanel.Caption := '  ' + Category;
    CategoryPanel.Font.Style := [fsBold];
    CategoryPanel.BevelOuter := bvNone;
    CategoryPanel.Color := clBtnFace;
    CategoryPanel.ParentBackground := False;
    Inc(TopPos, CategoryPanel.Height);

    for J := I to FProperties.Count - 1 do
      if ((FProperties[J].Kind = wpkEvent) = AEvents) and
        SameText(Trim(FProperties[J].Category), Category) then
      begin
        RowPanel := TPanel.Create(ABox);
        RowPanel.Parent := ABox;
        { GTK2 draws the focused TEdit frame outside part of its text area.
          Leave vertical breathing room so the lower focus border is never
          clipped by the next row. }
        RowPanel.SetBounds(0, TopPos, ABox.ClientWidth, 34);
        RowPanel.Anchors := [akLeft, akTop, akRight];
        RowPanel.BevelOuter := bvNone;
        RowPanel.Caption := '';

        NameLabel := TLabel.Create(RowPanel);
        NameLabel.Parent := RowPanel;
        NameLabel.SetBounds(8, 7, Divider - 12, 22);
        NameLabel.AutoSize := False;
        NameLabel.Caption := FProperties[J].Name;
        NameLabel.Tag := J + 1;
        NameLabel.OnClick := @NameLabelClick;

        ValueEdit := TEdit.Create(RowPanel);
        ValueEdit.Parent := RowPanel;
        ValueEdit.SetBounds(Divider, 3,
          RowPanel.ClientWidth - Divider - 4, 27);
        ValueEdit.Anchors := [akLeft, akTop, akRight];
        ValueEdit.Text := FProperties[J].Value;
        ValueEdit.Tag := J + 1;
        ValueEdit.ReadOnly := FProperties[J].Kind <> wpkText;
        if ValueEdit.ReadOnly then
          ValueEdit.Font.Color := clGrayText
        else
          ValueEdit.OnExit := @ValueEditExit;

        Inc(TopPos, RowPanel.Height);
      end;
  end;
end;

procedure TWWPropertyEditor.NameLabelClick(Sender: TObject);
var
  Index, I: Integer;
  ParentRow: TWinControl;
begin
  { Clicking the property name transfers keyboard focus to the value control,
    matching Lazarus/Delphi Object Inspector behavior. }
  Index := TLabel(Sender).Tag;
  ParentRow := TLabel(Sender).Parent;
  for I := 0 to ParentRow.ControlCount - 1 do
    if (ParentRow.Controls[I] is TEdit) and
      (TEdit(ParentRow.Controls[I]).Tag = Index) then
    begin
      TEdit(ParentRow.Controls[I]).SetFocus;
      Exit;
    end;
end;

procedure TWWPropertyEditor.ValueEditExit(Sender: TObject);
var
  Edit: TEdit;
  Prop: TWWPropertyItem;
  Index: Integer;
  OldValue, NewValue: string;
  Accept: Boolean;
begin
  Edit := TEdit(Sender);
  Index := Edit.Tag - 1;
  if (Index < 0) or (Index >= FProperties.Count) then
    Exit;

  Prop := FProperties[Index];
  if Prop.Kind <> wpkText then
    Exit;

  OldValue := Prop.Value;
  NewValue := Edit.Text;
  if NewValue = OldValue then
    Exit;

  Accept := False;
  if Assigned(FOnPropertyChanged) then
    FOnPropertyChanged(Self, Prop, OldValue, NewValue, Accept);

  if Accept then
    Prop.Value := NewValue
  else
    Edit.Text := OldValue;
end;

procedure TWWPropertyEditor.SetProperties(AValue: TWWPropertyItems);
begin
  if AValue = FProperties then
    Exit;
  FProperties.Assign(AValue);
  SyncInspector;
end;

procedure TWWPropertyEditor.SyncInspector;
begin
  if (FPropertiesBox = nil) or (FEventsBox = nil) then
    Exit;
  BuildPage(FPropertiesBox, False);
  BuildPage(FEventsBox, True);
end;

procedure TWWPropertyEditor.Clear;
begin
  FProperties.Clear;
  SyncInspector;
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
  SyncInspector;
end;

end.
