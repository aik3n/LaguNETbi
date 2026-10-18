unit uPersistentIPv4;

{$mode objfpc}{$H+}

interface

uses
  Windows;

{ Una IP manual en PersistentStore tiene prioridad frente a la concesion
  activa: es lo que presenta la ventana de propiedades IPv4 de Windows.
  Si no existe, AAddress vuelve vacio y se conserva la lectura activa. }
function ReadPersistentIPv4(AInterfaceIndex: DWORD;
  out AAddress: String; out APrefix: Integer; out AGateway: String;
  out AError: String): Boolean;

implementation

uses
  Classes, SysUtils, Process;

function PowerShellExecutable: String;
var
  WindowsDir: String;
begin
  WindowsDir := GetEnvironmentVariable('WINDIR');
  Result := '';
  if WindowsDir = '' then
    Exit;
  { Sysnative permite a los ejecutables de 32 bits invocar PowerShell de 64 bits. }
  Result := IncludeTrailingPathDelimiter(WindowsDir) +
    'Sysnative\WindowsPowerShell\v1.0\powershell.exe';
  if FileExists(Result) then
    Exit;
  Result := IncludeTrailingPathDelimiter(WindowsDir) +
    'System32\WindowsPowerShell\v1.0\powershell.exe';
  if not FileExists(Result) then
    Result := '';
end;

function ReadPersistentIPv4(AInterfaceIndex: DWORD;
  out AAddress: String; out APrefix: Integer; out AGateway: String;
  out AError: String): Boolean;
var
  P: TProcess;
  Lines: TStringList;
  ExePath, CommandText, Line: String;
  I, N: Integer;
begin
  Result := False;
  AAddress := '';
  APrefix := -1;
  AGateway := '';
  AError := '';

  ExePath := PowerShellExecutable;
  if ExePath = '' then
  begin
    AError := 'No se encuentra Windows PowerShell para leer PersistentStore.';
    Exit;
  end;

  { El indice procede de GetAdaptersAddresses: no se introducen textos del
    usuario en el comando. Salida etiquetada, independiente del idioma. }
  CommandText :=
    '$ErrorActionPreference=''Stop''; ' +
    '$ip=@(Get-NetIPAddress -InterfaceIndex ' + IntToStr(AInterfaceIndex) +
    ' -AddressFamily IPv4 -PolicyStore PersistentStore ' +
    '-ErrorAction SilentlyContinue | Where-Object {' +
    ' $_.PrefixOrigin -eq ''Manual'' -and ' +
    ' $_.IPAddress -ne ''0.0.0.0'' -and ' +
    ' $_.IPAddress -notlike ''169.254.*'' }); ' +
    'if($ip.Count -eq 0) {' +
    ' [Console]::WriteLine(''LAGUNET_DHCP''); exit 0 }; ' +
    '$ip=$ip | Sort-Object IPAddress | Select-Object -First 1; ' +
    '$gw=@(Get-NetRoute -InterfaceIndex ' + IntToStr(AInterfaceIndex) +
    ' -AddressFamily IPv4 -DestinationPrefix ''0.0.0.0/0'' ' +
    '-PolicyStore PersistentStore -ErrorAction SilentlyContinue | ' +
    'Where-Object { $_.NextHop -ne ''0.0.0.0'' }); ' +
    '$next=''''; if($gw.Count -gt 0) {$next=$gw[0].NextHop}; ' +
    '[Console]::WriteLine(''LAGUNET_STATIC''); ' +
    '[Console]::WriteLine($ip.IPAddress); ' +
    '[Console]::WriteLine($ip.PrefixLength); ' +
    '[Console]::WriteLine($next);';

  Lines := TStringList.Create;
  P := TProcess.Create(nil);
  try
    P.Executable := ExePath;
    P.Parameters.Add('-NoProfile');
    P.Parameters.Add('-NonInteractive');
    P.Parameters.Add('-Command');
    P.Parameters.Add(CommandText);
    P.Options := [poWaitOnExit, poNoConsole, poUsePipes, poStderrToOutPut];
    try
      P.Execute;
      Lines.LoadFromStream(P.Output);
    except
      on E: Exception do
      begin
        AError := 'No se pudo consultar IPv4 persistente: ' + E.Message;
        Exit;
      end;
    end;

    if P.ExitStatus <> 0 then
    begin
      AError := 'Windows no pudo consultar PersistentStore.';
      Exit;
    end;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = 'LAGUNET_DHCP' then
      begin
        Result := True;
        Exit;
      end;
      if Line = 'LAGUNET_STATIC' then
      begin
        if I + 2 >= Lines.Count then
          Break;
        AAddress := Trim(Lines[I + 1]);
        if (AAddress = '') or
           (not TryStrToInt(Trim(Lines[I + 2]), N)) or
           (N < 0) or (N > 32) then
          Break;
        APrefix := N;
        if I + 3 < Lines.Count then
          AGateway := Trim(Lines[I + 3]);
        Result := True;
        Exit;
      end;
    end;

    AError := 'La consulta persistente no devolvio datos reconocibles.';
  finally
    P.Free;
    Lines.Free;
  end;
end;

end.
