program LaguNETbi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Unit1, uWindowsSupport
  { you can add units after this };

{$R *.res}

begin
  if (ParamCount = 1) and
     (ParamStr(1) = '--lagunetbi-startup-enable') then
  begin
    if LaguNETbiSetStartupTask(True) then
      Halt(0)
    else
      Halt(1);
  end;

  if (ParamCount = 1) and
     (ParamStr(1) = '--lagunetbi-startup-disable') then
  begin
    if LaguNETbiSetStartupTask(False) then
      Halt(0)
    else
      Halt(1);
  end;

  if not PrepareLaguNETbiStartup then
    Halt(0);

  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  { El formulario principal existe, pero solo aparece si lo solicita el usuario. }
  Application.ShowMainForm := False;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

