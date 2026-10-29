unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, StdCtrls, Grids,
  WWorld, WGameSession, WBuilderSession;

type
  { TWorldWrightMainForm is WorldWright's single top-level application window.
    Static layout lives in mainform.lfm. This unit coordinates the GUI with
    the live model and game session; parser/engine behavior belongs outside
    the form. }
  TWorldWrightMainForm = class(TForm)
    CenterPanel: TPanel;
    CommandMemo: TMemo;
    CommandPanel: TPanel;
    InspectorGrid: TStringGrid;
    LeftPanel: TPanel;
    RightPanel: TPanel;
    SplitLeft: TSplitter;
    SplitRight: TSplitter;
    WorkspaceMemo: TMemo;
    WorldTree: TTreeView;
    procedure CommandMemoChange(Sender: TObject);
    procedure CommandMemoKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FWorld: TWorld;
    FSession: TGameSession;
    FBuilder: TBuilderSession;
    FProcessingInput: Boolean;
    procedure BuildStarterWorld;
    procedure ExecuteInputLine(const ACommand: string);
    procedure ProcessPastedLines;
    procedure RefreshWorldView;
    procedure SubmitCommand;
  end;

var
  WorldWrightMainForm: TWorldWrightMainForm;

implementation

{$R *.lfm}

procedure TWorldWrightMainForm.FormCreate(Sender: TObject);
begin
  FWorld := TWorld.Create;
  BuildStarterWorld;
  FSession := TGameSession.Create(FWorld);
  FBuilder := TBuilderSession.Create(FWorld, FSession);
  RefreshWorldView;

  WorkspaceMemo.Clear;
  WorkspaceMemo.Lines.Add('WorldWright');
  WorkspaceMemo.Lines.Add('Build your adventure from the inside.');
  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add(FSession.ExecuteCommand('LOOK'));
end;

procedure TWorldWrightMainForm.FormDestroy(Sender: TObject);
begin
  FBuilder.Free;
  FSession.Free;
  FWorld.Free;
end;

procedure TWorldWrightMainForm.FormShow(Sender: TObject);
begin
  CommandMemo.SetFocus;
end;

procedure TWorldWrightMainForm.BuildStarterWorld;
var
  Laboratory, Hallway: TWorldRoom;
begin
  Laboratory := FWorld.AddRoom('laboratory', 'Laboratory');
  Laboratory.Description :=
    'A dusty laboratory filled with abandoned equipment.';

  Hallway := FWorld.AddRoom('hallway', 'Hallway');
  Hallway.Description :=
    'A narrow hallway stretches past a row of closed doors.';

  Laboratory.Connect(wdNorth, Hallway);
  Hallway.Connect(wdSouth, Laboratory);
end;

procedure TWorldWrightMainForm.RefreshWorldView;
var
  WorldNode: TTreeNode;
  Room: TWorldRoom;
begin
  WorldTree.Items.Clear;
  WorldNode := WorldTree.Items.Add(nil, 'World');

  for Room in FWorld.Rooms do
    WorldTree.Items.AddChild(WorldNode, Room.Name);

  WorldNode.Expand(True);

  InspectorGrid.RowCount := 5;
  InspectorGrid.Cells[0, 0] := 'Property';
  InspectorGrid.Cells[1, 0] := 'Value';

  if FSession.CurrentRoom <> nil then
  begin
    InspectorGrid.Cells[0, 1] := 'Name';
    InspectorGrid.Cells[1, 1] := FSession.CurrentRoom.Name;
    InspectorGrid.Cells[0, 2] := 'ID';
    InspectorGrid.Cells[1, 2] := FSession.CurrentRoom.ID;
    InspectorGrid.Cells[0, 3] := 'Kind';
    InspectorGrid.Cells[1, 3] := 'Room';
    InspectorGrid.Cells[0, 4] := 'Description';
    InspectorGrid.Cells[1, 4] := FSession.CurrentRoom.Description;
  end;
end;

procedure TWorldWrightMainForm.ExecuteInputLine(const ACommand: string);
var
  Command, Response: string;
begin
  Command := Trim(ACommand);
  if Command = '' then
    Exit;

  WorkspaceMemo.Lines.Add('');
  WorkspaceMemo.Lines.Add('> ' + Command);

  if Command[1] = '@' then
    Response := FBuilder.ExecuteCommand(Command)
  else
    Response := FSession.ExecuteCommand(Command);
  if Response <> '' then
    WorkspaceMemo.Lines.Add(Response);

  RefreshWorldView;
end;

procedure TWorldWrightMainForm.SubmitCommand;
var
  Command: string;
begin
  Command := Trim(CommandMemo.Text);
  if Command = '' then
    Exit;

  FProcessingInput := True;
  try
    CommandMemo.Clear;
  finally
    FProcessingInput := False;
  end;

  ExecuteInputLine(Command);
  WorkspaceMemo.SelStart := Length(WorkspaceMemo.Text);
end;

procedure TWorldWrightMainForm.ProcessPastedLines;
var
  Lines: TStringList;
  I: Integer;
begin
  if FProcessingInput then
    Exit;
  if CommandMemo.Lines.Count <= 1 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Assign(CommandMemo.Lines);
    FProcessingInput := True;
    try
      CommandMemo.Clear;
    finally
      FProcessingInput := False;
    end;

    for I := 0 to Lines.Count - 1 do
      ExecuteInputLine(Lines[I]);

    WorkspaceMemo.SelStart := Length(WorkspaceMemo.Text);
  finally
    Lines.Free;
  end;
end;

procedure TWorldWrightMainForm.CommandMemoChange(Sender: TObject);
begin
  ProcessPastedLines;
end;

procedure TWorldWrightMainForm.CommandMemoKeyPress(Sender: TObject;
  var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    SubmitCommand;
  end;
end;

end.
