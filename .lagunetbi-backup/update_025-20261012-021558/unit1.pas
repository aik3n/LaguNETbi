unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Types, IniFiles, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Menus, ComCtrls, ImgList;

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
    DescriptionLabel: TLabel;
    DescriptionEdit: TEdit;
    BatContentLabel: TLabel;
    BatMemo: TMemo;
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
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure ShowFromTray(Sender: TObject);
    procedure HideToTray(Sender: TObject);
    procedure ExitFromTray(Sender: TObject);
    procedure ShowScriptsPopup(Sender: TObject);
    procedure ScriptTreeClick(Sender: TObject);
    procedure ScriptTreeMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ScriptTreeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ScriptTreeDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure ScriptTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ToggleAutomatic(Sender: TObject);
    procedure ToggleWifi(Sender: TObject);
    procedure TogglePing(Sender: TObject);
    procedure ConfigurationChanged(Sender: TObject);
    procedure AutoFillMask(Sender: TObject);
    procedure SaveScriptConfiguration(Sender: TObject);
    procedure PreviewAction(Sender: TObject);
  private
    FExiting: Boolean;
    FTrayReady: Boolean;
    FScriptsPath: String;
    FQuickForm: TQuickForm;
    FDraggedNode: TTreeNode;
    FScriptImages: TImageList;
    FIniPath: String;
    FDescriptionPaths: TStringList;
    FDescriptionTexts: TStringList;
    procedure CreateScriptImages;
    function ReadScriptDescription(const AFileName: String): String;
    function CachedScriptDescription(const AFileName: String): String;
    procedure SetCachedScriptDescription(const AFileName, ADescription: String);
    function CommandValue(const ALine, AKey: String): String;
    function PopToken(var AText: String): String;
    procedure SelectComboValue(ACombo: TComboBox; const AValue: String;
      AAdapterStyle: Boolean);
    function AdapterCommandName: String;
    procedure UpdateBatScrollBars;
    function ParseIPv4(const S: String; out A, B, C, D: Integer): Boolean;
    function IsValidIPv4(const S: String): Boolean;
    function IsValidSubnetMask(const S: String): Boolean;
    function ValidateConfiguration: Boolean;
    procedure UpdateValidationUI;
    procedure LoadScriptConfiguration(const AFileName: String);
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

  FDescriptionPaths := TStringList.Create;
  FDescriptionPaths.CaseSensitive := False;
  FDescriptionTexts := TStringList.Create;

  FQuickForm := TQuickForm.CreatePopup(Self);
  FQuickForm.RefreshScripts(FScriptsPath);

  DescriptionEdit.Enabled := False;
  CreateScriptImages;
  RefreshSidebarScripts;
  UpdateValidationUI;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FDescriptionTexts.Free;
  FDescriptionPaths.Free;
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

function TForm1.ReadScriptDescription(const AFileName: String): String;
const
  Prefix = ':: description=';
var
  Lines: TStringList;
  I: Integer;
  S: String;
begin
  Result := '';

  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(AFileName);
    except
      Exit;
    end;

    for I := 0 to Lines.Count - 1 do
    begin
      S := TrimLeft(Lines[I]);
      if Pos(Prefix, LowerCase(S)) = 1 then
      begin
        Result := Trim(Copy(S, Length(Prefix) + 1, MaxInt));
        Exit;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TForm1.CachedScriptDescription(const AFileName: String): String;
var
  I: Integer;
begin
  Result := '';
  if not Assigned(FDescriptionPaths) or not Assigned(FDescriptionTexts) then
    Exit;

  I := FDescriptionPaths.IndexOf(AFileName);
  if (I >= 0) and (I < FDescriptionTexts.Count) then
    Result := FDescriptionTexts[I];
end;

procedure TForm1.SetCachedScriptDescription(const AFileName,
  ADescription: String);
var
  I: Integer;
begin
  if not Assigned(FDescriptionPaths) or not Assigned(FDescriptionTexts) then
    Exit;

  I := FDescriptionPaths.IndexOf(AFileName);
  if I >= 0 then
    FDescriptionTexts[I] := ADescription
  else
  begin
    FDescriptionPaths.Add(AFileName);
    FDescriptionTexts.Add(ADescription);
  end;
end;

function TForm1.CommandValue(const ALine, AKey: String): String;
var
  LowerLine, LowerKey: String;
  P, StartPos, EndPos: Integer;
begin
  Result := '';
  LowerLine := LowerCase(ALine);
  LowerKey := LowerCase(AKey);
  P := Pos(LowerKey, LowerLine);
  if P = 0 then
    Exit;

  StartPos := P + Length(AKey);
  while (StartPos <= Length(ALine)) and (ALine[StartPos] in [' ', #9]) do
    Inc(StartPos);

  if (StartPos > Length(ALine)) or (ALine[StartPos] <> '=') then
    Exit;

  Inc(StartPos);
  while (StartPos <= Length(ALine)) and (ALine[StartPos] in [' ', #9]) do
    Inc(StartPos);

  if StartPos > Length(ALine) then
    Exit;

  if ALine[StartPos] = '"' then
  begin
    Inc(StartPos);
    EndPos := StartPos;
    while (EndPos <= Length(ALine)) and (ALine[EndPos] <> '"') do
      Inc(EndPos);
    Result := Copy(ALine, StartPos, EndPos - StartPos);
  end
  else
  begin
    EndPos := StartPos;
    while (EndPos <= Length(ALine)) and
      not (ALine[EndPos] in [' ', #9]) do
      Inc(EndPos);
    Result := Copy(ALine, StartPos, EndPos - StartPos);
  end;
end;

function TForm1.PopToken(var AText: String): String;
var
  P: Integer;
begin
  AText := TrimLeft(StringReplace(AText, #9, ' ', [rfReplaceAll]));
  P := Pos(' ', AText);
  if P = 0 then
  begin
    Result := AText;
    AText := '';
  end
  else
  begin
    Result := Copy(AText, 1, P - 1);
    Delete(AText, 1, P);
    AText := TrimLeft(AText);
  end;
end;

procedure TForm1.SelectComboValue(ACombo: TComboBox; const AValue: String;
  AAdapterStyle: Boolean);
var
  I, P: Integer;
  Candidate: String;
begin
  if AValue = '' then
    Exit;

  for I := 0 to ACombo.Items.Count - 1 do
  begin
    Candidate := ACombo.Items[I];
    if AAdapterStyle then
    begin
      P := Pos('  -  ', Candidate);
      if P > 0 then
        Candidate := Trim(Copy(Candidate, 1, P - 1));
    end;

    if SameText(Candidate, AValue) then
    begin
      ACombo.ItemIndex := I;
      Exit;
    end;
  end;

  ACombo.Items.Add(AValue);
  ACombo.ItemIndex := ACombo.Items.Count - 1;
end;

function TForm1.AdapterCommandName: String;
var
  P: Integer;
begin
  Result := Trim(Adapter.Text);
  P := Pos('  -  ', Result);
  if P > 0 then
    Result := Trim(Copy(Result, 1, P - 1));
end;

procedure TForm1.UpdateBatScrollBars;
var
  I, MaxWidth, LineHeight, VisibleLines, W: Integer;
  NeedHorz, NeedVert: Boolean;
  MeasureBmp: TBitmap;
begin
  if not Assigned(BatMemo) or not BatMemo.HandleAllocated then
    Exit;

  MeasureBmp := TBitmap.Create;
  try
    MeasureBmp.SetSize(1, 1);
    MeasureBmp.Canvas.Font.Assign(BatMemo.Font);

    LineHeight := MeasureBmp.Canvas.TextHeight('Wg');
    if LineHeight < 1 then
      LineHeight := 1;

    VisibleLines := (BatMemo.ClientHeight - 4) div LineHeight;
    if VisibleLines < 1 then
      VisibleLines := 1;

    NeedVert := BatMemo.Lines.Count > VisibleLines;

    MaxWidth := 0;
    for I := 0 to BatMemo.Lines.Count - 1 do
    begin
      W := MeasureBmp.Canvas.TextWidth(BatMemo.Lines[I]);
      if W > MaxWidth then
        MaxWidth := W;
    end;

    { Un pequeño margen evita que aparezca la horizontal por 1-2 px. }
    NeedHorz := MaxWidth > (BatMemo.ClientWidth - 12);
  finally
    MeasureBmp.Free;
  end;

  Windows.ShowScrollBar(BatMemo.Handle, SB_VERT, NeedVert);
  Windows.ShowScrollBar(BatMemo.Handle, SB_HORZ, NeedHorz);
end;

function TForm1.ParseIPv4(const S: String;
  out A, B, C, D: Integer): Boolean;
var
  Parts: TStringList;
  I, V: Integer;
begin
  Result := False;
  A := 0;
  B := 0;
  C := 0;
  D := 0;

  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := '.';
    Parts.DelimitedText := Trim(S);

    if Parts.Count <> 4 then
      Exit;

    for I := 0 to 3 do
    begin
      if (Parts[I] = '') or not TryStrToInt(Parts[I], V) then
        Exit;
      if (V < 0) or (V > 255) then
        Exit;

      case I of
        0: A := V;
        1: B := V;
        2: C := V;
        3: D := V;
      end;
    end;

    Result := True;
  finally
    Parts.Free;
  end;
end;

function TForm1.IsValidIPv4(const S: String): Boolean;
var
  A, B, C, D: Integer;
begin
  Result := ParseIPv4(S, A, B, C, D);
end;

function TForm1.IsValidSubnetMask(const S: String): Boolean;
var
  A, B, C, D, I, V: Integer;
  Octets: array[0..3] of Integer;
  MustBeZero: Boolean;
begin
  Result := False;

  if not ParseIPv4(S, A, B, C, D) then
    Exit;

  Octets[0] := A;
  Octets[1] := B;
  Octets[2] := C;
  Octets[3] := D;
  MustBeZero := False;

  for I := 0 to 3 do
  begin
    V := Octets[I];

    if MustBeZero then
    begin
      if V <> 0 then
        Exit;
      Continue;
    end;

    case V of
      255:
        ;
      254, 252, 248, 240, 224, 192, 128, 0:
        MustBeZero := True;
    else
      Exit;
    end;
  end;

  Result := True;
end;

function TForm1.ValidateConfiguration: Boolean;
var
  AdapterOK, AddressOK, MaskOK, GatewayOK, WifiOK, PingOK: Boolean;
begin
  AdapterOK := Trim(Adapter.Text) <> '';

  if AutomaticBox.Checked then
  begin
    AddressOK := True;
    MaskOK := True;
    GatewayOK := True;
  end
  else
  begin
    AddressOK := IsValidIPv4(AddressEdit.Text);
    MaskOK := IsValidSubnetMask(MaskEdit.Text);
    GatewayOK := (Trim(GatewayEdit.Text) = '') or
      IsValidIPv4(GatewayEdit.Text);
  end;

  WifiOK := (not WifiBox.Checked) or
    ((Trim(WifiCombo.Text) <> '') and
     (not SameText(Trim(WifiCombo.Text), 'Sin seleccionar')));

  PingOK := (not PingBox.Checked) or IsValidIPv4(PingEdit.Text);

  Result := AdapterOK and AddressOK and MaskOK and GatewayOK and
    WifiOK and PingOK;
end;

procedure TForm1.UpdateValidationUI;
const
  InvalidColor = TColor($00D0D0FF);
var
  AdapterOK, AddressOK, MaskOK, GatewayOK, WifiOK, PingOK: Boolean;
  ConfigOK, HasSelectedScript: Boolean;
begin
  AdapterOK := Trim(Adapter.Text) <> '';

  if AutomaticBox.Checked then
  begin
    AddressOK := True;
    MaskOK := True;
    GatewayOK := True;
  end
  else
  begin
    AddressOK := IsValidIPv4(AddressEdit.Text);
    MaskOK := IsValidSubnetMask(MaskEdit.Text);
    GatewayOK := (Trim(GatewayEdit.Text) = '') or
      IsValidIPv4(GatewayEdit.Text);
  end;

  WifiOK := (not WifiBox.Checked) or
    ((Trim(WifiCombo.Text) <> '') and
     (not SameText(Trim(WifiCombo.Text), 'Sin seleccionar')));

  PingOK := (not PingBox.Checked) or IsValidIPv4(PingEdit.Text);

  if AdapterOK then
    Adapter.Color := clWindow
  else
    Adapter.Color := InvalidColor;

  if AutomaticBox.Checked or AddressOK then
    AddressEdit.Color := clWindow
  else
    AddressEdit.Color := InvalidColor;

  if AutomaticBox.Checked or MaskOK then
    MaskEdit.Color := clWindow
  else
    MaskEdit.Color := InvalidColor;

  if AutomaticBox.Checked or GatewayOK then
    GatewayEdit.Color := clWindow
  else
    GatewayEdit.Color := InvalidColor;

  if (not WifiBox.Checked) or WifiOK then
    WifiCombo.Color := clWindow
  else
    WifiCombo.Color := InvalidColor;

  if (not PingBox.Checked) or PingOK then
    PingEdit.Color := clWindow
  else
    PingEdit.Color := InvalidColor;

  ConfigOK := AdapterOK and AddressOK and MaskOK and GatewayOK and
    WifiOK and PingOK;

  HasSelectedScript := Assigned(ScriptTree.Selected);
  if HasSelectedScript then
    HasSelectedScript := IsScriptNode(ScriptTree.Selected);

  SaveButton.Enabled := ConfigOK and HasSelectedScript;
  ApplyButton.Enabled := ConfigOK;
end;

procedure TForm1.LoadScriptConfiguration(const AFileName: String);
var
  Lines: TStringList;
  I, P: Integer;
  S, L, Rest, AdapterName, WifiName: String;
begin
  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(AFileName);
    except
      BatMemo.Clear;
      StatusLabel.Caption := 'No se pudo leer ' + ExtractFileName(AFileName);
      Exit;
    end;

    { Siempre mostramos lo que acaba de leerse del archivo real. }
    BatMemo.Lines.Assign(Lines);
    UpdateBatScrollBars;

    DescriptionEdit.Text := '';
    Adapter.ItemIndex := -1;
    WifiCombo.ItemIndex := -1;
    AutomaticBox.Checked := False;
    AddressEdit.Text := '';
    MaskEdit.Text := '';
    GatewayEdit.Text := '';
    WifiBox.Checked := False;
    PingBox.Checked := False;
    PingEdit.Text := '';

    for I := 0 to Lines.Count - 1 do
    begin
      S := Trim(Lines[I]);
      L := LowerCase(S);

      if Pos(':: description=', L) = 1 then
        DescriptionEdit.Text :=
          Trim(Copy(S, Length(':: description=') + 1, MaxInt))
      else if Pos('netsh interface ipv4 set address', L) > 0 then
      begin
        AdapterName := CommandValue(S, 'name');
        SelectComboValue(Adapter, AdapterName, True);

        if (Pos('source=dhcp', L) > 0) or (Pos(' dhcp', L) > 0) then
          AutomaticBox.Checked := True
        else
        begin
          P := Pos(' static ', L);
          if P > 0 then
          begin
            Rest := Trim(Copy(S, P + Length(' static '), MaxInt));
            AddressEdit.Text := PopToken(Rest);
            MaskEdit.Text := PopToken(Rest);
            GatewayEdit.Text := PopToken(Rest);
          end;
        end;
      end
      else if Pos('netsh wlan connect', L) > 0 then
      begin
        WifiBox.Checked := True;
        WifiName := CommandValue(S, 'name');
        SelectComboValue(WifiCombo, WifiName, False);
      end
      else if SameText(S, ':: No conectar') then
        WifiBox.Checked := False
      else if Pos(':: testping=', L) = 1 then
      begin
        PingBox.Checked := True;
        PingEdit.Text :=
          Trim(Copy(S, Length(':: testPing=') + 1, MaxInt));
      end
      else if SameText(S, ':: No test Ping') then
        PingBox.Checked := False;
    end;

    DescriptionEdit.Enabled := True;
    SetCachedScriptDescription(AFileName, DescriptionEdit.Text);
    ToggleAutomatic(nil);
    ToggleWifi(nil);
    TogglePing(nil);
    UpdateValidationUI;
  finally
    Lines.Free;
  end;
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

      FullName := IncludeTrailingPathDelimiter(ADirectory) + Files[I];
      FDescriptionPaths.Add(FullName);
      FDescriptionTexts.Add(ReadScriptDescription(FullName));
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

    FDescriptionPaths.Clear;
    FDescriptionTexts.Clear;

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
var
  ScriptPath: String;
begin
  if not IsScriptNode(ScriptTree.Selected) then
  begin
    DescriptionEdit.Text := '';
    DescriptionEdit.Enabled := False;
    BatMemo.Clear;
    UpdateBatScrollBars;
    UpdateValidationUI;
    Exit;
  end;

  ScriptPath := ScriptNodePath(ScriptTree.Selected);
  ProfileTitle.Caption := ChangeFileExt(ScriptTree.Selected.Text, '');
  LoadScriptConfiguration(ScriptPath);
  StatusLabel.Caption := 'Script cargado: ' + ScriptTree.Selected.Text;
end;

procedure TForm1.ScriptTreeMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Node: TTreeNode;
  Description: String;
begin
  Node := ScriptTree.GetNodeAt(X, Y);
  Description := '';

  if Assigned(Node) and SameText(ExtractFileExt(Node.Text), '.bat') then
    Description := CachedScriptDescription(ScriptNodePath(Node));

  ScriptTree.Hint := Description;
  ScriptTree.ShowHint := Description <> '';
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
  UpdateValidationUI;
end;

procedure TForm1.ToggleWifi(Sender: TObject);
begin
  WifiCombo.Enabled := WifiBox.Checked;
  UpdateValidationUI;
end;

procedure TForm1.TogglePing(Sender: TObject);
begin
  PingEdit.Enabled := PingBox.Checked;
  UpdateValidationUI;
end;

procedure TForm1.ConfigurationChanged(Sender: TObject);
begin
  UpdateValidationUI;
end;

procedure TForm1.AutoFillMask(Sender: TObject);
begin
  { Es solo un valor por defecto practico, no una mascara calculada. }
  if AutomaticBox.Checked then
    Exit;

  if Trim(MaskEdit.Text) <> '' then
    Exit;

  if not IsValidIPv4(AddressEdit.Text) then
    Exit;

  MaskEdit.Text := '255.255.255.0';
  UpdateValidationUI;
end;

procedure TForm1.SaveScriptConfiguration(Sender: TObject);
var
  ScriptPath, Description: String;
  AddressLine, WifiLine, PingLine: String;
  AdapterName, S, L, GatewayValue: String;
  Lines, Output: TStringList;
  I: Integer;
  AddressDone, WifiDone, PingDone, DescriptionDone: Boolean;
begin
  { La validacion de UI no es la unica barrera: volvemos a validar aqui. }
  UpdateValidationUI;
  if not ValidateConfiguration then
    Exit;

  if not IsScriptNode(ScriptTree.Selected) then
  begin
    MessageDlg('Selecciona primero un script .bat.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  ScriptPath := ScriptNodePath(ScriptTree.Selected);
  AdapterName := AdapterCommandName;
  Description := Trim(DescriptionEdit.Text);
  GatewayValue := Trim(GatewayEdit.Text);

  if AdapterName = '' then
  begin
    MessageDlg('Selecciona un adaptador de red.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  { Construir las lineas gestionadas a partir de los CAMPOS ACTUALES. }
  if AutomaticBox.Checked then
    AddressLine := 'netsh interface ipv4 set address name="' +
      AdapterName + '" source=dhcp'
  else
  begin
    AddressLine := 'netsh interface ipv4 set address name="' +
      AdapterName + '" static ' + Trim(AddressEdit.Text) + ' ' +
      Trim(MaskEdit.Text);

    if GatewayValue <> '' then
      AddressLine := AddressLine + ' ' + GatewayValue;
  end;

  if WifiBox.Checked then
    WifiLine := 'netsh wlan connect name ="' + Trim(WifiCombo.Text) +
      '" ssid ="' + Trim(WifiCombo.Text) + '"'
  else
    WifiLine := '';

  if PingBox.Checked then
    PingLine := ':: testPing=' + Trim(PingEdit.Text)
  else
    PingLine := '';

  Lines := TStringList.Create;
  Output := TStringList.Create;
  try
    try
      Lines.LoadFromFile(ScriptPath);
    except
      MessageDlg('No se pudo leer el script antes de guardarlo.',
        mtError, [mbOK], 0);
      Exit;
    end;

    AddressDone := False;
    WifiDone := False;
    PingDone := False;
    DescriptionDone := False;

    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I];
      L := LowerCase(Trim(S));

      { Description: gestionamos una sola metadata y eliminamos duplicados. }
      if Pos(':: description=', L) = 1 then
      begin
        if not DescriptionDone then
        begin
          if Description <> '' then
            Output.Add(':: description=' + Description);
          DescriptionDone := True;
        end;
        Continue;
      end;

      { La primera linea IPv4 reconocida pertenece al editor.
        Si existen otras lineas similares, se conservan como contenido custom. }
      if (not AddressDone) and
        (Pos('netsh interface ipv4 set address', L) > 0) then
      begin
        Output.Add(AddressLine);
        AddressDone := True;
        Continue;
      end;

      { Igual para Wi-Fi. }
      if (not WifiDone) and
        ((Pos('netsh wlan connect', L) > 0) or
         SameText(Trim(S), ':: No conectar')) then
      begin
        if WifiLine <> '' then
          Output.Add(WifiLine);
        WifiDone := True;
        Continue;
      end;

      { Igual para testPing. }
      if (not PingDone) and
        ((Pos(':: testping=', L) = 1) or
         SameText(Trim(S), ':: No test Ping')) then
      begin
        if PingLine <> '' then
          Output.Add(PingLine);
        PingDone := True;
        Continue;
      end;

      { Cualquier otra linea se conserva sin interpretarla. }
      Output.Add(S);
    end;

    { Description es opcional. Si no existia y ahora tiene valor, va arriba. }
    if not DescriptionDone and (Description <> '') then
      Output.Insert(0, ':: description=' + Description);

    { La configuracion actual debe quedar representada incluso si el BAT
      original no tenia alguna de estas lineas. }
    if not AddressDone then
      Output.Add(AddressLine);

    if (not WifiDone) and (WifiLine <> '') then
      Output.Add(WifiLine);

    if (not PingDone) and (PingLine <> '') then
      Output.Add(PingLine);

    try
      Output.SaveToFile(ScriptPath);
    except
      MessageDlg('No se pudo guardar el script.',
        mtError, [mbOK], 0);
      Exit;
    end;
  finally
    Output.Free;
    Lines.Free;
  end;

  SetCachedScriptDescription(ScriptPath, Description);

  { Fuente de verdad: tras guardar, releemos el archivo REAL. }
  LoadScriptConfiguration(ScriptPath);
  UpdateValidationUI;
  StatusLabel.Caption := 'Guardado: ' + ExtractFileName(ScriptPath);
end;

procedure TForm1.PreviewAction(Sender: TObject);
begin
  UpdateValidationUI;
  if not ValidateConfiguration then
    Exit;

  StatusLabel.Caption := 'Configuracion valida. Todavia no se ejecuta ningun comando.';
end;

end.
