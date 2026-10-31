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
    FChoices: TStringList;
    function GetChoices: TStrings;
    procedure SetChoices(AValue: TStrings);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
  published
    property ID: string read FID write FID;
    property Category: string read FCategory write FCategory;
    property Kind: TWWPropertyKind read FKind write FKind default wpkReadOnly;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
    property Choices: TStrings read GetChoices write SetChoices;
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
    FUpdateCount: Integer;
    procedure BuildPage(ABox: TScrollBox; AEvents: Boolean);
    procedure NameLabelClick(Sender: TObject);
    procedure SetProperties(AValue: TWWPropertyItems);
    procedure SyncInspector;
    procedure ValueEditExit(Sender: TObject);
    procedure ValueComboExit(Sender: TObject);
    procedure DialogButtonClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
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

constructor TWWPropertyItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FChoices := TStringList.Create;
end;

destructor TWWPropertyItem.Destroy;
begin
  FChoices.Free;
  inherited Destroy;
end;

function TWWPropertyItem.GetChoices: TStrings;
begin
  Result := FChoices;
end;

procedure TWWPropertyItem.SetChoices(AValue: TStrings);
begin
  FChoices.Assign(AValue);
end;

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
  FUpdateCount := 0;

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
  CategoryPanel, RowPanel: TPanel;
  NameCell: TPanel;
  ValueEdit: TEdit;
  ValueCombo: TComboBox;
  DialogButton: TButton;
begin
  { Rows are rebuilt from metadata. They are disposable views; no authored
    state is stored in the controls themselves. }
  while ABox.ControlCount > 0 do
    ABox.Controls[0].Free;

  TopPos := 0;
  Divider := (ABox.ClientWidth * FDividerPercent) div 100;
  if Divider < 80 then
    Divider := 80;

  { Category headings provide sufficient structure; a repeated Property/Value
    header consumed vertical space without adding useful information. }

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

        NameCell := TPanel.Create(RowPanel);
        NameCell.Parent := RowPanel;
        NameCell.SetBounds(0, 0, Divider, RowPanel.ClientHeight);
        NameCell.Alignment := taLeftJustify;
        NameCell.Caption := '  ' + FProperties[J].Name;
        NameCell.BevelOuter := bvNone;
        NameCell.Tag := J + 1;
        NameCell.OnClick := @NameLabelClick;

        if FProperties[J].Kind = wpkDialog then
        begin
          { Dialog properties show a compact read-only preview plus an ellipsis
            button. The modal editor owns only a temporary string; accepted
            changes still flow through the same neutral OnPropertyChanged
            contract as inline editors. }
          ValueEdit := TEdit.Create(RowPanel);
          ValueEdit.Parent := RowPanel;
          ValueEdit.SetBounds(Divider, 3,
            RowPanel.ClientWidth - Divider - 34, 27);
          ValueEdit.Anchors := [akLeft, akTop, akRight];
          ValueEdit.Text := FProperties[J].Value;
          ValueEdit.Tag := J + 1;
          ValueEdit.ReadOnly := True;

          DialogButton := TButton.Create(RowPanel);
          DialogButton.Parent := RowPanel;
          DialogButton.SetBounds(RowPanel.ClientWidth - 32, 3, 28, 27);
          DialogButton.Anchors := [akTop, akRight];
          DialogButton.Caption := '...';
          DialogButton.Tag := J + 1;
          DialogButton.OnClick := @DialogButtonClick;
        end
        else if FProperties[J].Kind in [wpkBoolean, wpkEnum, wpkReference] then
        begin
          ValueCombo := TComboBox.Create(RowPanel);
          ValueCombo.Parent := RowPanel;
          ValueCombo.SetBounds(Divider, 3,
            RowPanel.ClientWidth - Divider - 4, 27);
          ValueCombo.Anchors := [akLeft, akTop, akRight];
          ValueCombo.Tag := J + 1;
          ValueCombo.Style := csDropDownList;
          if FProperties[J].Kind = wpkBoolean then
          begin
            ValueCombo.Items.Add('False');
            ValueCombo.Items.Add('True');
          end
          else
            ValueCombo.Items.Assign(FProperties[J].Choices);
          ValueCombo.ItemIndex := ValueCombo.Items.IndexOf(FProperties[J].Value);
          ValueCombo.OnExit := @ValueComboExit;
        end
        else
        begin
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
        end;

        Inc(TopPos, RowPanel.Height);
      end;
  end;
end;

procedure TWWPropertyEditor.NameLabelClick(Sender: TObject);
var
  Index, I: Integer;
  ParentRow: TWinControl;
begin
  { Property-name cells are captioned panels because GTK2 reliably paints
    their text where dynamic TLabels were disappearing. Clicking a name still
    transfers keyboard focus to the value control,
    matching Lazarus/Delphi Object Inspector behavior. }
  Index := TPanel(Sender).Tag;
  ParentRow := TPanel(Sender).Parent;
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

procedure TWWPropertyEditor.DialogButtonClick(Sender: TObject);
var
  Button: TButton;
  Prop: TWWPropertyItem;
  DialogForm: TForm;
  Editor: TMemo;
  ButtonsPanel: TPanel;
  OKButton, CancelButton: TButton;
  Index: Integer;
  OldValue, NewValue: string;
  Accept: Boolean;
begin
  Button := TButton(Sender);
  Index := Button.Tag - 1;
  if (Index < 0) or (Index >= FProperties.Count) then
    Exit;

  Prop := FProperties[Index];
  if Prop.Kind <> wpkDialog then
    Exit;

  DialogForm := TForm.CreateNew(Self);
  try
    DialogForm.Caption := 'Edit ' + Prop.Name;
    DialogForm.Position := poScreenCenter;
    DialogForm.Width := 560;
    DialogForm.Height := 360;
    DialogForm.BorderStyle := bsSizeable;
    DialogForm.Font.Assign(Font);

    ButtonsPanel := TPanel.Create(DialogForm);
    ButtonsPanel.Parent := DialogForm;
    ButtonsPanel.Align := alBottom;
    ButtonsPanel.Height := 46;
    ButtonsPanel.BevelOuter := bvNone;

    CancelButton := TButton.Create(ButtonsPanel);
    CancelButton.Parent := ButtonsPanel;
    CancelButton.Caption := 'Cancel';
    CancelButton.ModalResult := mrCancel;
    CancelButton.SetBounds(ButtonsPanel.Width - 180, 8, 80, 30);
    CancelButton.Anchors := [akTop, akRight];

    OKButton := TButton.Create(ButtonsPanel);
    OKButton.Parent := ButtonsPanel;
    OKButton.Caption := 'OK';
    OKButton.ModalResult := mrOK;
    OKButton.Default := True;
    OKButton.SetBounds(ButtonsPanel.Width - 92, 8, 80, 30);
    OKButton.Anchors := [akTop, akRight];

    Editor := TMemo.Create(DialogForm);
    Editor.Parent := DialogForm;
    Editor.Align := alClient;
    Editor.ScrollBars := ssAutoBoth;
    Editor.WordWrap := True;
    Editor.Lines.Text := Prop.Value;
    Editor.SelectAll;
    { Do not call SetFocus before ShowModal. GTK2 rejects focus requests for
      controls whose containing form is not yet visible. As the dialog's main
      client control, the memo naturally receives the initial keyboard focus
      once the modal form is activated. }

    if DialogForm.ShowModal <> mrOK then
      Exit;

    OldValue := Prop.Value;
    NewValue := Editor.Lines.Text;
    { TMemo.Lines.Text carries a trailing line ending on some widgetsets.
      Authored descriptions are plain text values, so remove only that
      transport artifact while preserving intentional internal line breaks. }
    while (NewValue <> '') and (NewValue[Length(NewValue)] in [#10, #13]) do
      Delete(NewValue, Length(NewValue), 1);
    if NewValue = OldValue then
      Exit;

    Accept := False;
    if Assigned(FOnPropertyChanged) then
      FOnPropertyChanged(Self, Prop, OldValue, NewValue, Accept);
    if Accept then
    begin
      Prop.Value := NewValue;
      SyncInspector;
    end;
  finally
    DialogForm.Free;
  end;
end;

procedure TWWPropertyEditor.ValueComboExit(Sender: TObject);
var
  Combo: TComboBox;
  Prop: TWWPropertyItem;
  Index: Integer;
  OldValue, NewValue: string;
  Accept: Boolean;
begin
  Combo := TComboBox(Sender);
  Index := Combo.Tag - 1;
  if (Index < 0) or (Index >= FProperties.Count) then
    Exit;

  Prop := FProperties[Index];
  OldValue := Prop.Value;
  NewValue := Combo.Text;
  if NewValue = OldValue then
    Exit;

  Accept := False;
  if Assigned(FOnPropertyChanged) then
    FOnPropertyChanged(Self, Prop, OldValue, NewValue, Accept);

  if Accept then
    Prop.Value := NewValue
  else
    Combo.ItemIndex := Combo.Items.IndexOf(OldValue);
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
  if FUpdateCount > 0 then
    Exit;
  if (FPropertiesBox = nil) or (FEventsBox = nil) then
    Exit;
  BuildPage(FPropertiesBox, False);
  BuildPage(FEventsBox, True);
end;

procedure TWWPropertyEditor.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

procedure TWWPropertyEditor.EndUpdate;
begin
  if FUpdateCount = 0 then
    Exit;
  Dec(FUpdateCount);
  if FUpdateCount = 0 then
    SyncInspector;
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
