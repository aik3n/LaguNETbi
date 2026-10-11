unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, IniFiles, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Menus, ComCtrls, ImgList;

type
  TQuickForm = class(TForm)
  private
    FTree: TTreeView;
    FStatus: TLabel;
    FProgress: TProgressBar;
    procedure PopupDeactivate(Sender: TObject);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure AddDirectory(const ADirectory: String; AParent: TTreeNode);
  public
    constructor CreatePopup(AOwner: TComponent);
    procedure RefreshScripts(const ARootPath: String);
    procedure ShowNearTray;
  end;

  TForm1 = class(TForm)
    BrandLabel: TLabel;
    TaglineLabel: TLabel;
    ProfilesLabel: TLabel;
    ScriptTree: TTreeView;
    CountLabel: TLabel;
    VersionLabel: TLabel;
    PreviewLabel: TLabel;
    Header: TPanel;
    ProfileTitle: TLabel;
    SubtitleLabel: TLabel;
    AdapterLabel: TLabel;
    Adapter: TComboBox;
    AutomaticBox: TCheckBox;
    AddressLabel: TLabel;
    AddressEdit: TEdit;
    MaskLabel: TLabel;
    MaskEdit: TEdit;
    GatewayLabel: TLabel;
    GatewayEdit: TEdit;
    WifiBox: TCheckBox;
    WifiCombo: TComboBox;
    PingBox: TCheckBox;
    PingEdit: TEdit;
    StatusLabel: TLabel;
    SaveButton: TButton;
    ApplyButton: TButton;
    Footer: TPanel;
    Sidebar: TPanel;
    Content: TPanel;
    TrayIcon: TTrayIcon;
    TrayMenu: TPopupMenu;
    ShowMenuItem: TMenuItem;
    HideMenuItem: TMenuItem;
    TraySeparator: TMenuItem;
    ExitMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure ShowFromTray(Sender: TObject);
    procedure HideToTray(Sender: TObject);
    procedure ExitFromTray(Sender: TObject);
    procedure ShowScriptsPopup(Sender: TObject);
    procedure ScriptTreeClick(Sender: TObject);
    procedure ScriptTreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ScriptTreeDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure ScriptTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ToggleAutomatic(Sender: TObject);
    procedure ToggleWifi(Sender: TObject);
    procedure TogglePing(Sender: TObject);
    procedure PreviewAction(Sender: TObject);
  private
    FExiting: Boolean;
    FTrayReady: Boolean;
    FScriptsPath: String;
    FQuickForm: TQuickForm;
    FDraggedNode: TTreeNode;
    FScriptImages: TImageList;
    FIniPath: String;
    procedure CreateScriptImages;
    function NodeRelativePath(ANode: TTreeNode): String;
    function ScriptNodePath(ANode: TTreeNode): String;
    procedure CaptureExpandedFolders(AList: TStrings);
    procedure ApplyExpandedFolders(AList: TStrings);
    procedure LoadExpandedFolders(AList: TStrings);
    procedure SaveExpandedFolders;
    function IsScriptNode(ANode: TTreeNode): Boolean;
    procedure AddSidebarDirectory(const ADirectory: String; AParent: TTreeNode);
    procedure RefreshSidebarScripts;
    function CountBatFiles(const ADirectory: String): Integer;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

constructor TQuickForm.CreatePopup(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 1);

  Caption := 'LaguNET Scripts';
  Width := 303;
  Height := 450;
  BorderStyle := bsNone;
  Position := poDesigned;
  ShowInTaskBar := stNever;
  Color := clWhite;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  OnDeactivate := @PopupDeactivate;

  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := Self;
  FProgress.Align := alBottom;
  FProgress.Height := 5;
  FProgress.Min := 0;
  FProgress.Max := 17;
  FProgress.Position := 0;
  FProgress.Visible := False;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := alBottom;
  FStatus.Height := 25;
  FStatus.Alignment := taCenter;
  FStatus.Layout := tlCenter;
  FStatus.Caption := '';
  FStatus.Color := clWhite;
  FStatus.ParentColor := False;

  FTree := TTreeView.Create(Self);
  FTree.Parent := Self;
  FTree.Align := alClient;
  FTree.BorderStyle := bsNone;
  FTree.Color := clWhite;
  FTree.ReadOnly := True;
  FTree.Font.Name := 'Verdana';
  FTree.Font.Size := 12;
  FTree.Indent := 20;
  FTree.OnEditing := @TreeEditing;
  FTree.OnDblClick := @TreeDblClick;
end;

procedure TQuickForm.PopupDeactivate(Sender: TObject);
begin
  Hide;
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
        Node := FTree.Items.AddChild(AParent, SR.Name);
        AddDirectory(FullName, Node);
      end
      else if SameText(ExtractFileExt(SR.Name), '.bat') then
        FTree.Items.AddChild(AParent, SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TQuickForm.RefreshScripts(const ARootPath: String);
var
  RootNode: TTreeNode;
begin
  FTree.Items.BeginUpdate;
  try
    FTree.Items.Clear;
    RootNode := FTree.Items.Add(nil, 'scripts');
    AddDirectory(ARootPath, RootNode);

    if RootNode.Count = 0 then
      FTree.Items.AddChild(RootNode, '(sin scripts .bat)');

    RootNode.Expand(True);
  finally
    FTree.Items.EndUpdate;
  end;

  FStatus.Caption := '';
  FProgress.Visible := False;
end;

procedure TQuickForm.TreeEditing(Sender: TObject; Node: TTreeNode;
  var AllowEdit: Boolean);
begin
  AllowEdit := False;
end;

procedure TQuickForm.TreeDblClick(Sender: TObject);
begin
  if not Assigned(FTree.Selected) then
    Exit;

  if SameText(ExtractFileExt(FTree.Selected.Text), '.bat') then
  begin
    FStatus.Caption := 'Seleccionado: ' + FTree.Selected.Text;
    FStatus.Visible := True;
  end;
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
  FTree.SetFocus;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  TrayIcon.Icon.Assign(Application.Icon);
  FTrayReady := TrayIcon.Show;
  if not FTrayReady then TrayIcon.Hide;

  ToggleAutomatic(nil);
  ToggleWifi(nil);
  TogglePing(nil);

  FScriptsPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'scripts';
  FIniPath := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'LaguNETbi.ini';
  ForceDirectories(FScriptsPath);

  FQuickForm := TQuickForm.CreatePopup(Self);
  FQuickForm.RefreshScripts(FScriptsPath);

  CreateScriptImages;
  RefreshSidebarScripts;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveExpandedFolders;

  if FExiting or not FTrayReady then
  begin
    TrayIcon.Hide;
    CloseAction := caFree;
  end
  else
    CloseAction := caHide;
end;

procedure TForm1.ShowFromTray(Sender: TObject);
begin
  WindowState := wsNormal;
  Show;
  BringToFront;
end;

procedure TForm1.HideToTray(Sender: TObject);
begin
  if FTrayReady then Hide;
end;

procedure TForm1.ExitFromTray(Sender: TObject);
begin
  FExiting := True;
  Close;
end;

procedure TForm1.ShowScriptsPopup(Sender: TObject);
begin
  if not Assigned(FQuickForm) then
    Exit;

  FQuickForm.RefreshScripts(FScriptsPath);
  FQuickForm.ShowNearTray;
end;

procedure TForm1.CreateScriptImages;
var
  Bmp: TBitmap;
begin
  if Assigned(FScriptImages) then
  begin
    ScriptTree.Images := FScriptImages;
    Exit;
  end;

  FScriptImages := TImageList.Create(Self);
  FScriptImages.Width := 16;
  FScriptImages.Height := 16;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(16, 16);
    Bmp.Transparent := True;
    Bmp.TransparentColor := clFuchsia;

    { icono 0 = carpeta }
    Bmp.Canvas.Brush.Color := clFuchsia;
    Bmp.Canvas.FillRect(0, 0, 16, 16);
    Bmp.Canvas.Pen.Color := $2A5CAA;
    Bmp.Canvas.Brush.Color := $8EC5FF;
    Bmp.Canvas.Rectangle(1, 5, 15, 14);
    Bmp.Canvas.Brush.Color := $B8DCFF;
    Bmp.Canvas.Rectangle(2, 3, 8, 7);
    FScriptImages.AddMasked(Bmp, clFuchsia);

    { icono 1 = script/documento }
    Bmp.Canvas.Brush.Color := clFuchsia;
    Bmp.Canvas.FillRect(0, 0, 16, 16);
    Bmp.Canvas.Pen.Color := $7A6A4F;
    Bmp.Canvas.Brush.Color := clWhite;
    Bmp.Canvas.Rectangle(3, 1, 13, 15);
    Bmp.Canvas.Brush.Color := $D9E8FF;
    Bmp.Canvas.Polygon([Point(9,1), Point(12,1), Point(12,4)]);
    Bmp.Canvas.Pen.Color := $B2552A;
    Bmp.Canvas.Line(5, 6, 11, 6);
    Bmp.Canvas.Line(5, 8, 11, 8);
    Bmp.Canvas.Line(5, 10, 11, 10);
    FScriptImages.AddMasked(Bmp, clFuchsia);
  finally
    Bmp.Free;
  end;

  ScriptTree.Images := FScriptImages;
end;

function TForm1.NodeRelativePath(ANode: TTreeNode): String;
var
  Cur: TTreeNode;
begin
  Result := '';
  if not Assigned(ANode) then
    Exit;

  Result := ANode.Text;
  Cur := ANode.Parent;
  while Assigned(Cur) do
  begin
    Result := Cur.Text + PathDelim + Result;
    Cur := Cur.Parent;
  end;
end;

function TForm1.ScriptNodePath(ANode: TTreeNode): String;
begin
  Result := '';
  if not Assigned(ANode) then
    Exit;

  Result := IncludeTrailingPathDelimiter(FScriptsPath) +
    NodeRelativePath(ANode);
end;

procedure TForm1.CaptureExpandedFolders(AList: TStrings);
var
  I: Integer;
  Node: TTreeNode;
begin
  AList.Clear;

  for I := 0 to ScriptTree.Items.Count - 1 do
  begin
    Node := ScriptTree.Items[I];
    if Node.Expanded and DirectoryExists(ScriptNodePath(Node)) then
      AList.Add(NodeRelativePath(Node));
  end;
end;

procedure TForm1.ApplyExpandedFolders(AList: TStrings);
var
  I: Integer;
  Node: TTreeNode;
begin
  for I := 0 to ScriptTree.Items.Count - 1 do
  begin
    Node := ScriptTree.Items[I];
    if DirectoryExists(ScriptNodePath(Node)) and
       (AList.IndexOf(NodeRelativePath(Node)) >= 0) then
      Node.Expand(False);
  end;
end;

procedure TForm1.LoadExpandedFolders(AList: TStrings);
var
  Ini: TIniFile;
  I, N: Integer;
  S: String;
begin
  AList.Clear;

  if not FileExists(FIniPath) then
    Exit;

  Ini := TIniFile.Create(FIniPath);
  try
    N := Ini.ReadInteger('ScriptTree', 'ExpandedCount', 0);
    for I := 0 to N - 1 do
    begin
      S := Ini.ReadString('ScriptTree', 'Expanded' + IntToStr(I), '');
      if S <> '' then
        AList.Add(S);
    end;
  finally
    Ini.Free;
  end;
end;

procedure TForm1.SaveExpandedFolders;
var
  Ini: TIniFile;
  Expanded: TStringList;
  I: Integer;
begin
  if (FIniPath = '') or not Assigned(ScriptTree) then
    Exit;

  Expanded := TStringList.Create;
  try
    CaptureExpandedFolders(Expanded);

    Ini := TIniFile.Create(FIniPath);
    try
      Ini.EraseSection('ScriptTree');
      Ini.WriteInteger('ScriptTree', 'ExpandedCount', Expanded.Count);
      for I := 0 to Expanded.Count - 1 do
        Ini.WriteString('ScriptTree', 'Expanded' + IntToStr(I), Expanded[I]);
    finally
      Ini.Free;
    end;
  finally
    Expanded.Free;
  end;
end;

function TForm1.IsScriptNode(ANode: TTreeNode): Boolean;
begin
  Result := Assigned(ANode) and
    SameText(ExtractFileExt(ANode.Text), '.bat') and
    FileExists(ScriptNodePath(ANode));
end;

procedure TForm1.AddSidebarDirectory(const ADirectory: String; AParent: TTreeNode);
var
  SR: TSearchRec;
  Dirs, Files: TStringList;
  I: Integer;
  Node: TTreeNode;
  FullName: String;
begin
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  try
    Dirs.Sorted := True;
    Dirs.CaseSensitive := False;
    Files.Sorted := True;
    Files.CaseSensitive := False;

    if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;

        FullName := IncludeTrailingPathDelimiter(ADirectory) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          Dirs.Add(SR.Name)
        else if SameText(ExtractFileExt(SR.Name), '.bat') then
          Files.Add(SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;

    for I := 0 to Dirs.Count - 1 do
    begin
      Node := ScriptTree.Items.AddChild(AParent, Dirs[I]);
      Node.ImageIndex := 0;
      Node.SelectedIndex := 0;
      AddSidebarDirectory(
        IncludeTrailingPathDelimiter(ADirectory) + Dirs[I], Node);
    end;

    for I := 0 to Files.Count - 1 do
    begin
      Node := ScriptTree.Items.AddChild(AParent, Files[I]);
      Node.ImageIndex := 1;
      Node.SelectedIndex := 1;
    end;
  finally
    Dirs.Free;
    Files.Free;
  end;
end;

function TForm1.CountBatFiles(const ADirectory: String): Integer;
var
  SR: TSearchRec;
  FullName: String;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, SR) <> 0 then
    Exit;

  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FullName := IncludeTrailingPathDelimiter(ADirectory) + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
        Inc(Result, CountBatFiles(FullName))
      else if SameText(ExtractFileExt(SR.Name), '.bat') then
        Inc(Result);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TForm1.RefreshSidebarScripts;
var
  N: Integer;
  Expanded: TStringList;
begin
  Expanded := TStringList.Create;
  try
    Expanded.CaseSensitive := False;

    if ScriptTree.Items.Count > 0 then
      CaptureExpandedFolders(Expanded)
    else
      LoadExpandedFolders(Expanded);

    ScriptTree.Items.BeginUpdate;
    try
      ScriptTree.Items.Clear;
      AddSidebarDirectory(FScriptsPath, nil);
      ApplyExpandedFolders(Expanded);
    finally
      ScriptTree.Items.EndUpdate;
    end;
  finally
    Expanded.Free;
  end;

  N := CountBatFiles(FScriptsPath);
  if N = 1 then
    CountLabel.Caption := '1 script'
  else
    CountLabel.Caption := IntToStr(N) + ' scripts';
end;

procedure TForm1.ScriptTreeClick(Sender: TObject);
begin
  if not IsScriptNode(ScriptTree.Selected) then
    Exit;

  ProfileTitle.Caption := ChangeFileExt(ScriptTree.Selected.Text, '');
  StatusLabel.Caption := 'Script seleccionado: ' + ScriptTree.Selected.Text;
end;

procedure TForm1.ScriptTreeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  FDraggedNode := nil;
  if Button <> mbLeft then
    Exit;

  Node := ScriptTree.GetNodeAt(X, Y);
  if IsScriptNode(Node) then
  begin
    ScriptTree.Selected := Node;
    FDraggedNode := Node;
    ScriptTree.Cursor := crSizeAll;
    StatusLabel.Caption := 'Mover: ' + Node.Text;
  end;
end;

procedure TForm1.ScriptTreeDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  TargetNode: TTreeNode;
  TargetPath, TargetName: String;
begin
  Accept := False;

  if (Source <> ScriptTree) or not IsScriptNode(FDraggedNode) then
  begin
    ScriptTree.Cursor := crDefault;
    Exit;
  end;

  TargetNode := ScriptTree.GetNodeAt(X, Y);

  { Espacio vacio = raiz de scripts. }
  if not Assigned(TargetNode) then
  begin
    Accept := ExtractFileDir(ScriptNodePath(FDraggedNode)) <>
      ExcludeTrailingPathDelimiter(FScriptsPath);

    if Accept then
    begin
      ScriptTree.Cursor := crSizeAll;
      StatusLabel.Caption := 'Mover ' + FDraggedNode.Text + ' -> scripts';
    end
    else
    begin
      ScriptTree.Cursor := crDefault;
      StatusLabel.Caption := 'El script ya esta en scripts';
    end;
    Exit;
  end;

  TargetPath := ScriptNodePath(TargetNode);
  if DirectoryExists(TargetPath) then
  begin
    Accept := not SameText(
      ExtractFileDir(ScriptNodePath(FDraggedNode)),
      ExcludeTrailingPathDelimiter(TargetPath));

    if Accept then
    begin
      { Seleccionar la carpeta sirve como resaltado visual del destino. }
      ScriptTree.Selected := TargetNode;
      ScriptTree.Cursor := crSizeAll;
      TargetName := TargetNode.Text;
      StatusLabel.Caption := 'Mover ' + FDraggedNode.Text + ' -> ' + TargetName;
    end
    else
    begin
      ScriptTree.Cursor := crDefault;
      StatusLabel.Caption := 'El script ya esta en ' + TargetNode.Text;
    end;
  end
  else
  begin
    ScriptTree.Cursor := crDefault;
    StatusLabel.Caption := 'Suelta sobre una carpeta';
  end;
end;

procedure TForm1.ScriptTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  TargetNode: TTreeNode;
  SourcePath, DestDir, DestPath: String;
  Answer: TModalResult;
begin
  ScriptTree.Cursor := crDefault;

  if (Source <> ScriptTree) or not IsScriptNode(FDraggedNode) then
    Exit;

  SourcePath := ScriptNodePath(FDraggedNode);
  TargetNode := ScriptTree.GetNodeAt(X, Y);

  if Assigned(TargetNode) then
  begin
    DestDir := ScriptNodePath(TargetNode);
    if not DirectoryExists(DestDir) then
      Exit;
  end
  else
    DestDir := FScriptsPath;

  DestPath := IncludeTrailingPathDelimiter(DestDir) + ExtractFileName(SourcePath);

  if SameText(SourcePath, DestPath) then
    Exit;

  if FileExists(DestPath) then
  begin
    Answer := MessageDlg(
      'Ya existe "' + ExtractFileName(DestPath) + '" en esa carpeta.' + LineEnding +
      '¿Quieres reemplazarlo?',
      mtConfirmation, [mbYes, mbNo], 0);
    if Answer <> mrYes then
      Exit;

    if not DeleteFile(DestPath) then
    begin
      MessageDlg('No se pudo reemplazar el archivo de destino.',
        mtError, [mbOK], 0);
      Exit;
    end;
  end;

  if not RenameFile(SourcePath, DestPath) then
  begin
    MessageDlg('No se pudo mover el script.' + LineEnding +
      SourcePath + LineEnding + '->' + LineEnding + DestPath,
      mtError, [mbOK], 0);
    Exit;
  end;

  FDraggedNode := nil;
  RefreshSidebarScripts;
  if Assigned(FQuickForm) then
    FQuickForm.RefreshScripts(FScriptsPath);

  StatusLabel.Caption := 'Movido: ' + ExtractFileName(DestPath);
end;

procedure TForm1.ToggleAutomatic(Sender: TObject);
begin
  AddressEdit.Enabled := not AutomaticBox.Checked;
  MaskEdit.Enabled := not AutomaticBox.Checked;
  GatewayEdit.Enabled := not AutomaticBox.Checked;
end;

procedure TForm1.ToggleWifi(Sender: TObject);
begin
  WifiCombo.Enabled := WifiBox.Checked;
end;

procedure TForm1.TogglePing(Sender: TObject);
begin
  PingEdit.Enabled := PingBox.Checked;
end;

procedure TForm1.PreviewAction(Sender: TObject);
begin
  StatusLabel.Caption := 'Simulacion completada. Sin cambios en tu red.';
end;

end.
