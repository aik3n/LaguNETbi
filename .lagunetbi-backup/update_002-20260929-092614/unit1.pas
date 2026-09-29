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
    ShowMenuItem: TMenuItem;
    HideMenuItem: TMenuItem;
    TraySeparator: TMenuItem;
    ExitMenuItem: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure ShowFromTray(Sender: TObject);
    procedure HideToTray(Sender: TObject);
    procedure ExitFromTray(Sender: TObject);
    procedure SelectProfile(Sender: TObject);
    procedure ToggleAutomatic(Sender: TObject);
    procedure ToggleWifi(Sender: TObject);
    procedure TogglePing(Sender: TObject);
    procedure PreviewAction(Sender: TObject);
  private
    FExiting: Boolean;
    FTrayReady: Boolean;
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
