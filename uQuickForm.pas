unit uQuickForm;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, Graphics,
  StdCtrls, ExtCtrls, ComCtrls;

type
  TQuickScriptExecuteEvent = procedure(const AFileName: String) of object;

  { El formulario y sus controles se editan visualmente en uQuickForm.lfm. }
  TQuickForm = class(TForm)
    TreeScripts: TTreeView;
    StatusText: TLabel;
    QuickProgress: TProgressBar;
    FocusTimer: TTimer;
    procedure PopupDeactivate(Sender: TObject);
    procedure FocusTimerTick(Sender: TObject);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeEditing(Sender: TObject; Node: TTreeNode;
      var AllowEdit: Boolean);
  private
    FRunning: Boolean;
    FScriptsPath: String;
    FOnExecuteScript: TQuickScriptExecuteEvent;
    function SelectedScriptPath: String;
    procedure AddDirectory(const ADirectory: String; AParent: TTreeNode);
  public
    procedure RefreshScripts(const ARootPath: String);
    procedure BeginExecution(const AName: String; AUsePing: Boolean;
      ATimeoutSeconds: Integer);
    procedure SetIPv4Done;
    procedure SetPingProgress(AAttempt, AReplies: Integer);
    procedure FinishExecution(const AStatus: String);
    procedure ShowNearTray;
    property OnExecuteScript: TQuickScriptExecuteEvent
      read FOnExecuteScript write FOnExecuteScript;
  end;

implementation

{$R *.lfm}

procedure TQuickForm.PopupDeactivate(Sender: TObject);
begin
  if Assigned(FocusTimer) then
    FocusTimer.Enabled := False;

  Hide;
end;
procedure TQuickForm.FocusTimerTick(Sender: TObject);
begin
  if not Visible then
  begin
    FocusTimer.Enabled := False;
    Exit;
  end;

  { GetForegroundWindow devuelve la ventana superior que tiene
    realmente el foco en Windows. Si ya no somos nosotros, cerramos. }
  if GetForegroundWindow <> Handle then
  begin
    FocusTimer.Enabled := False;
    Hide;
  end;
end;

procedure TQuickForm.AddDirectory(const ADirectory: String; AParent: TTreeNode);
var
  SR: TSearchRec;
  Node: TTreeNode;
  FullName: String;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, SR) <> 0 then
    Exit;

  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FullName := IncludeTrailingPathDelimiter(ADirectory) + SR.Name;

      if (SR.Attr and faDirectory) <> 0 then
      begin
        Node := TreeScripts.Items.AddChild(AParent, SR.Name);
        AddDirectory(FullName, Node);
      end
      else if SameText(ExtractFileExt(SR.Name), '.bat') then
        TreeScripts.Items.AddChild(AParent, SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TQuickForm.RefreshScripts(const ARootPath: String);
var
  RootNode: TTreeNode;
begin
  if FRunning then
    Exit;
  FScriptsPath := ARootPath;

  TreeScripts.Items.BeginUpdate;
  try
    TreeScripts.Items.Clear;
    RootNode := TreeScripts.Items.Add(nil, 'scripts');
    AddDirectory(ARootPath, RootNode);

    if RootNode.Count = 0 then
      TreeScripts.Items.AddChild(RootNode, '(sin scripts .bat)');

    RootNode.Expand(True);
  finally
    TreeScripts.Items.EndUpdate;
  end;

  StatusText.Caption := '';
  QuickProgress.Visible := False;
end;

procedure TQuickForm.TreeEditing(Sender: TObject; Node: TTreeNode;
  var AllowEdit: Boolean);
begin
  AllowEdit := False;
end;

function TQuickForm.SelectedScriptPath: String;
var
  Node, Cur: TTreeNode;
  RelativePath: String;
begin
  Result := '';

  Node := TreeScripts.Selected;
  if not Assigned(Node) then
    Exit;

  if not SameText(ExtractFileExt(Node.Text), '.bat') then
    Exit;

  RelativePath := Node.Text;
  Cur := Node.Parent;

  { El nodo raiz se llama "scripts", pero FScriptsPath ya apunta a esa
    carpeta, asi que no lo duplicamos. }
  while Assigned(Cur) and Assigned(Cur.Parent) do
  begin
    RelativePath := Cur.Text + PathDelim + RelativePath;
    Cur := Cur.Parent;
  end;

  Result := IncludeTrailingPathDelimiter(FScriptsPath) + RelativePath;
end;

procedure TQuickForm.TreeDblClick(Sender: TObject);
var
  ScriptPath: String;
begin
  if not Assigned(FOnExecuteScript) then
    Exit;

  ScriptPath := SelectedScriptPath;
  if (ScriptPath = '') or not FileExists(ScriptPath) then
    Exit;

  FocusTimer.Enabled := False;
  Hide;
  FOnExecuteScript(ScriptPath);
end;
procedure TQuickForm.BeginExecution(const AName: String; AUsePing: Boolean;
  ATimeoutSeconds: Integer);
begin
  FRunning := True;
  { El arbol sigue disponible mientras un ping comprueba el destino. }
  TreeScripts.Enabled := True;

  QuickProgress.Min := 0;
  if AUsePing then
    QuickProgress.Max := ATimeoutSeconds + 1
  else
    QuickProgress.Max := 1;

  QuickProgress.Position := 0;
  QuickProgress.Visible := True;
  StatusText.Caption := 'Aplicando: ' + AName;
  StatusText.Visible := True;
end;

procedure TQuickForm.SetIPv4Done;
begin
  QuickProgress.Position := 1;

  if QuickProgress.Max > 1 then
    StatusText.Caption := 'BAT finalizado - comprobando equipo...';
end;

procedure TQuickForm.SetPingProgress(AAttempt, AReplies: Integer);
begin
  QuickProgress.Position := 1 + AAttempt;
  StatusText.Caption := Format(
    'Comprobando equipo... intento %d',
    [AAttempt]
  );
end;
procedure TQuickForm.FinishExecution(const AStatus: String);
begin
  QuickProgress.Position := 0;
  QuickProgress.Visible := False;
  StatusText.Caption := AStatus;
  StatusText.Visible := True;
  TreeScripts.Enabled := True;
  FRunning := False;
end;
procedure TQuickForm.ShowNearTray;
var
  R: TRect;
begin
  R := Screen.WorkAreaRect;
  Left := R.Right - Width;
  Top := R.Bottom - Height;

  Show;
  BringToFront;
  TreeScripts.SetFocus;

  FocusTimer.Enabled := True;
end;

end.
