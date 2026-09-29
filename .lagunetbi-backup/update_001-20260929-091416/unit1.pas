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
    DnsLabel: TLabel;
    DnsEdit: TEdit;
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
  ProfileTitle.Caption := Trim(ProfileList.Items[ProfileList.ItemIndex]);
  AutomaticBox.Checked := ProfileList.ItemIndex = 1;
  if ProfileList.ItemIndex = 2 then
  begin
    AddressEdit.Text := '10.0.0.25';
    GatewayEdit.Text := '10.0.0.1';
  end
  else
  begin
    AddressEdit.Text := '192.168.1.120';
    GatewayEdit.Text := '192.168.1.1';
  end;
  ToggleAutomatic(nil);
  StatusLabel.Caption := 'Prueba visual. Sin cambios en tu red.';
end;

procedure TForm1.ToggleAutomatic(Sender: TObject);
begin
  AddressEdit.Enabled := not AutomaticBox.Checked;
  MaskEdit.Enabled := not AutomaticBox.Checked;
  GatewayEdit.Enabled := not AutomaticBox.Checked;
  DnsEdit.Enabled := not AutomaticBox.Checked;
end;

procedure TForm1.PreviewAction(Sender: TObject);
begin
  StatusLabel.Caption := 'Simulacion completada. Sin cambios en tu red.';
end;

end.
