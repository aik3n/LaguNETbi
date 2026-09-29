unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Menus, ComCtrls;

type
  TQuickForm = class(TForm)
  private
    FTree: TTreeView;
    FStatus: TLabel;
    FProgress: TProgressBar;
    procedure PopupDeactivate(Sender: TObject);
    procedure TreeDblClick(Sender: TObject);
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
    ProfileList: TListBox;
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
    procedure SelectProfile(Sender: TObject);
    procedure ToggleAutomatic(Sender: TObject);
    procedure ToggleWifi(Sender: TObject);
    procedure TogglePing(Sender: TObject);
    procedure PreviewAction(Sender: TObject);
  private
    FExiting: Boolean;
    FTrayReady: Boolean;
    FScriptsPath: String;
    FQuickForm: TQuickForm;
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
  FTree.Font.Name := 'Verdana';
  FTree.Font.Size := 12;
  FTree.Indent := 20;
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
  ForceDirectories(FScriptsPath);

  FQuickForm := TQuickForm.CreatePopup(Self);
  FQuickForm.RefreshScripts(FScriptsPath);
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
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

procedure TForm1.SelectProfile(Sender: TObject);
begin
  if ProfileList.ItemIndex < 0 then Exit;

  ProfileTitle.Caption := ChangeFileExt(Trim(ProfileList.Items[ProfileList.ItemIndex]), '');

  case ProfileList.ItemIndex of
    0:
      begin
        AutomaticBox.Checked := False;
        AddressEdit.Text := '192.168.1.120';
        MaskEdit.Text := '255.255.255.0';
        GatewayEdit.Text := '192.168.1.1';
        WifiBox.Checked := True;
        WifiCombo.ItemIndex := 0;
        PingBox.Checked := True;
        PingEdit.Text := '192.168.1.1';
      end;
    1:
      begin
        AutomaticBox.Checked := False;
        AddressEdit.Text := '10.0.0.25';
        MaskEdit.Text := '255.255.255.0';
        GatewayEdit.Text := '10.0.0.1';
        WifiBox.Checked := False;
        PingBox.Checked := True;
        PingEdit.Text := '10.0.0.1';
      end;
  else
    begin
      AutomaticBox.Checked := True;
      AddressEdit.Text := '';
      MaskEdit.Text := '';
      GatewayEdit.Text := '';
      WifiBox.Checked := False;
      PingBox.Checked := False;
      PingEdit.Text := '';
    end;
  end;

  ToggleAutomatic(nil);
  ToggleWifi(nil);
  TogglePing(nil);
  StatusLabel.Caption := 'Prueba visual. Sin cambios en tu red.';
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
