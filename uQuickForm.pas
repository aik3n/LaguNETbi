unit uQuickForm;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, Graphics,
  StdCtrls, ExtCtrls, ComCtrls, ImgList, IniFiles, uLanguage;

type
  TQuickScriptExecuteEvent = procedure(const AFileName: String) of object;

  { El formulario y sus controles se editan visualmente en uQuickForm.lfm. }
  TQuickForm = class(TForm)
    TreeScripts: TTreeView;
    TreeIcons: TImageList;
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
    FStoredScrollX: Integer;
    FStoredScrollY: Integer;
    function TreeNodeKey(ANode: TTreeNode): String;
    function TreeStateIniPath: String;
    procedure SaveTreeState;
    procedure RestoreTreeState(ARootNode: TTreeNode);
    procedure RestoreTreeScroll;
  private
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

resourcestring
  SLoc_Quick_Applying = 'Applying:';
  SLoc_Quick_Empty = '(no BAT scripts)';
  SLoc_Quick_IPv4Done = 'BAT finished - checking host...';
  SLoc_Quick_PingAttempt = 'Checking host... attempt %d';


type
  { Acceso a las posiciones reales de scroll del TreeView de Lazarus.
    No crea controles nuevos ni interviene en su dibujo. }
  TQuickTreeViewAccess = class(TTreeView)
  end;

function TQuickForm.TreeNodeKey(ANode: TTreeNode): String;
begin
  Result := '';
  while Assigned(ANode) do
  begin
    if Result = '' then
      Result := ANode.Text
    else
      Result := ANode.Text + '/' + Result;
    ANode := ANode.Parent;
  end;
end;

function TQuickForm.TreeStateIniPath: String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) +
    'LaguNETbi.ini';
end;

procedure TQuickForm.SaveTreeState;
var
  Ini: TIniFile;
  Expanded: TStringList;
  I: Integer;
begin
  if not Assigned(TreeScripts) or (TreeScripts.Items.Count = 0) then
    Exit;

  { Las posiciones quedan guardadas tambien en memoria para esta sesion. }
  FStoredScrollX := TQuickTreeViewAccess(TreeScripts).ScrolledLeft;
  FStoredScrollY := TQuickTreeViewAccess(TreeScripts).ScrolledTop;

  Expanded := TStringList.Create;
  try
    for I := 0 to TreeScripts.Items.Count - 1 do
      if TreeScripts.Items[I].Expanded then
        Expanded.Add(TreeNodeKey(TreeScripts.Items[I]));

    { El estado del popup es independiente de [ScriptTree] del formulario. }
    try
      Ini := TIniFile.Create(TreeStateIniPath);
      try
        Ini.EraseSection('TrayPopupTree');
        Ini.WriteInteger('TrayPopupTree', 'ExpandedCount', Expanded.Count);
        for I := 0 to Expanded.Count - 1 do
          Ini.WriteString('TrayPopupTree', 'Expanded' + IntToStr(I), Expanded[I]);
        Ini.WriteInteger('TrayPopupTree', 'ScrollX', FStoredScrollX);
        Ini.WriteInteger('TrayPopupTree', 'ScrollY', FStoredScrollY);
      finally
        Ini.Free;
      end;
    except
      { La persistencia no debe impedir cerrar el popup si el INI
        esta protegido o la carpeta temporalmente no es escribible. }
    end;
  finally
    Expanded.Free;
  end;
end;

procedure TQuickForm.RestoreTreeState(ARootNode: TTreeNode);
var
  Ini: TIniFile;
  Expanded: TStringList;
  I, CountSaved: Integer;
  S: String;
begin
  FStoredScrollX := 0;
  FStoredScrollY := 0;
  if not Assigned(ARootNode) then
    Exit;

  if not FileExists(TreeStateIniPath) then
  begin
    ARootNode.Expand(True);
    Exit;
  end;

  Expanded := TStringList.Create;
  try
    Expanded.CaseSensitive := False;
    try
      Ini := TIniFile.Create(TreeStateIniPath);
      try
        { -1 significa primera ejecucion: conservar el comportamiento anterior. }
        CountSaved := Ini.ReadInteger('TrayPopupTree', 'ExpandedCount', -1);
        if CountSaved < 0 then
        begin
          ARootNode.Expand(True);
          Exit;
        end;
        if CountSaved > TreeScripts.Items.Count then
          CountSaved := TreeScripts.Items.Count;
        for I := 0 to CountSaved - 1 do
        begin
          S := Ini.ReadString('TrayPopupTree', 'Expanded' + IntToStr(I), '');
          if S <> '' then
            Expanded.Add(S);
        end;
        FStoredScrollX := Ini.ReadInteger('TrayPopupTree', 'ScrollX', 0);
        FStoredScrollY := Ini.ReadInteger('TrayPopupTree', 'ScrollY', 0);
      finally
        Ini.Free;
      end;
    except
      ARootNode.Expand(True);
      Exit;
    end;

    { Nodos padres antes que hijos: se restaura el estado de cada carpeta,
      incluso si uno de sus antecesores sigue colapsado. }
    for I := 0 to TreeScripts.Items.Count - 1 do
      if Expanded.IndexOf(TreeNodeKey(TreeScripts.Items[I])) >= 0 then
        TreeScripts.Items[I].Expand(False);
  finally
    Expanded.Free;
  end;
end;

procedure TQuickForm.RestoreTreeScroll;
begin
  if not Assigned(TreeScripts) or not TreeScripts.HandleAllocated then
    Exit;
  { Lazarus limita automaticamente los valores al rango visible actual. }
  TQuickTreeViewAccess(TreeScripts).ScrolledTop := FStoredScrollY;
  TQuickTreeViewAccess(TreeScripts).ScrolledLeft := FStoredScrollX;
end;

procedure TQuickForm.PopupDeactivate(Sender: TObject);
begin
  if Assigned(FocusTimer) then
    FocusTimer.Enabled := False;

  SaveTreeState;
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
    SaveTreeState;
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
        Node.ImageIndex := 0;
        Node.SelectedIndex := 0;
        AddDirectory(FullName, Node);
      end
      else if SameText(ExtractFileExt(SR.Name), '.bat') then
      begin
        Node := TreeScripts.Items.AddChild(AParent, SR.Name);
        Node.ImageIndex := 1;
        Node.SelectedIndex := 1;
      end;
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
  { Si se reconstruye con el popup visible, conservar el estado actual. }
  if Visible and (TreeScripts.Items.Count > 0) then
    SaveTreeState;
  FScriptsPath := ARootPath;

  TreeScripts.Items.BeginUpdate;
  try
    TreeScripts.Items.Clear;
    RootNode := TreeScripts.Items.Add(nil, 'scripts');
    RootNode.ImageIndex := 0;
    RootNode.SelectedIndex := 0;
    AddDirectory(ARootPath, RootNode);

    if RootNode.Count = 0 then
      TreeScripts.Items.AddChild(RootNode,
        SLoc_Quick_Empty);

    RestoreTreeState(RootNode);
  finally
    TreeScripts.Items.EndUpdate;
  end;
  if Visible then
    RestoreTreeScroll;

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
  SaveTreeState;
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
  StatusText.Caption := SLoc_Quick_Applying + ' ' + AName;
  StatusText.Visible := True;
end;

procedure TQuickForm.SetIPv4Done;
begin
  QuickProgress.Position := 1;

  if QuickProgress.Max > 1 then
    StatusText.Caption := SLoc_Quick_IPv4Done;
end;

procedure TQuickForm.SetPingProgress(AAttempt, AReplies: Integer);
begin
  QuickProgress.Position := 1 + AAttempt;
  StatusText.Caption := Format(SLoc_Quick_PingAttempt, [AAttempt]);
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
  RestoreTreeScroll;

  FocusTimer.Enabled := True;
end;

end.
