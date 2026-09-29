unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Menus;

type
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
    ScriptsMenuItem: TMenuItem;
    ScriptsRefreshItem: TMenuItem;
    ScriptsSeparator: TMenuItem;
    ShowMenuItem: TMenuItem;
    HideMenuItem: TMenuItem;
    TraySeparator: TMenuItem;
    ExitMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure ShowFromTray(Sender: TObject);
    procedure HideToTray(Sender: TObject);
    procedure ExitFromTray(Sender: TObject);
    procedure TrayMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RefreshScriptsMenu(Sender: TObject);
    procedure ScriptMenuClick(Sender: TObject);
    procedure SelectProfile(Sender: TObject);
    procedure ToggleAutomatic(Sender: TObject);
    procedure ToggleWifi(Sender: TObject);
    procedure TogglePing(Sender: TObject);
    procedure PreviewAction(Sender: TObject);
  private
    FExiting: Boolean;
    FTrayReady: Boolean;
    FScriptsPath: String;
    procedure PopulateScriptsMenu;
    procedure AddScriptsFromDirectory(const ADirectory: String; AParent: TMenuItem);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

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
  PopulateScriptsMenu;
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

procedure TForm1.TrayMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    TrayMenu.PopUp(X, Y);
end;

procedure TForm1.AddScriptsFromDirectory(const ADirectory: String; AParent: TMenuItem);
var
  SR: TSearchRec;
  Item: TMenuItem;
  FullName: String;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FullName := IncludeTrailingPathDelimiter(ADirectory) + SR.Name;

      if (SR.Attr and faDirectory) <> 0 then
      begin
        Item := TMenuItem.Create(TrayMenu);
        Item.Caption := SR.Name;
        AParent.Add(Item);
        AddScriptsFromDirectory(FullName, Item);
        if Item.Count = 0 then
          Item.Enabled := False;
      end
      else if SameText(ExtractFileExt(SR.Name), '.bat') then
      begin
        Item := TMenuItem.Create(TrayMenu);
        Item.Caption := ChangeFileExt(SR.Name, '');
        Item.Hint := FullName;
        Item.OnClick := @ScriptMenuClick;
        AParent.Add(Item);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TForm1.PopulateScriptsMenu;
var
  I: Integer;
  EmptyItem: TMenuItem;
begin
  for I := ScriptsMenuItem.Count - 1 downto 0 do
    ScriptsMenuItem.Delete(I);

  AddScriptsFromDirectory(FScriptsPath, ScriptsMenuItem);

  if ScriptsMenuItem.Count = 0 then
  begin
    EmptyItem := TMenuItem.Create(TrayMenu);
    EmptyItem.Caption := '(sin scripts .bat)';
    EmptyItem.Enabled := False;
    ScriptsMenuItem.Add(EmptyItem);
  end;
end;

procedure TForm1.RefreshScriptsMenu(Sender: TObject);
begin
  PopulateScriptsMenu;
  StatusLabel.Caption := 'Menu de scripts actualizado.';
end;

procedure TForm1.ScriptMenuClick(Sender: TObject);
var
  Item: TMenuItem;
begin
  if not (Sender is TMenuItem) then Exit;

  Item := TMenuItem(Sender);
  StatusLabel.Caption := 'Script seleccionado: ' + ExtractFileName(Item.Hint);
  ShowFromTray(nil);
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
