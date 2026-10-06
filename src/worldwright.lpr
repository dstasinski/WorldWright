program WorldWright;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, MainForm;

var
  MainWindow: TWorldWrightMainForm;

begin
  Application.Initialize;
  Application.Title := 'WorldWright';
  Application.CreateForm(TWorldWrightMainForm, MainWindow);
  Application.Run;
end.
