unit uWindowsSupport;

{$mode objfpc}{$H+}

interface

uses
  Classes;

function LaguNETbiIsElevated: Boolean;
function LaguNETbiNetshPath: String;
function LaguNETbiStartupTaskExists: Boolean;
function LaguNETbiSetStartupTask(AEnable: Boolean): Boolean;
function LaguNETbiChangeStartupTask(
  AEnable: Boolean;
  out AError: String
): Boolean;
function LaguNETbiRunElevatedNetsh(
  AParameters: TStrings;
  out AError: String
): Boolean;
function PrepareLaguNETbiStartup: Boolean;

implementation

uses
  Windows, ShellApi, SysUtils, Process, Forms;

type
  TLaguNETbiTokenElevation = record
    TokenIsElevated: DWORD;
  end;

const
  TOKEN_QUERY_LAGUNET = $0008;
  TOKEN_ELEVATION_CLASS_LAGUNET = 20;

function LaguNETbiOpenProcessToken(
  ProcessHandle: THandle;
  DesiredAccess: DWORD;
  var TokenHandle: THandle
): BOOL; stdcall; external 'advapi32.dll' name 'OpenProcessToken';

function LaguNETbiGetTokenInformation(
  TokenHandle: THandle;
  TokenInformationClass: DWORD;
  TokenInformation: Pointer;
  TokenInformationLength: DWORD;
  var ReturnLength: DWORD
): BOOL; stdcall; external 'advapi32.dll' name 'GetTokenInformation';

function LaguNETbiIsElevated: Boolean;
var
  TokenHandle: THandle;
  Elevation: TLaguNETbiTokenElevation;
  ReturnLength: DWORD;
begin
  Result := False;
  TokenHandle := 0;

  if not LaguNETbiOpenProcessToken(
    GetCurrentProcess,
    TOKEN_QUERY_LAGUNET,
    TokenHandle
  ) then
    Exit;

  try
    FillChar(Elevation, SizeOf(Elevation), 0);
    ReturnLength := 0;

    if LaguNETbiGetTokenInformation(
      TokenHandle,
      TOKEN_ELEVATION_CLASS_LAGUNET,
      @Elevation,
      SizeOf(Elevation),
      ReturnLength
    ) then
      Result := Elevation.TokenIsElevated <> 0;
  finally
    CloseHandle(TokenHandle);
  end;
end;

function LaguNETbiNetshPath: String;
var
  Buffer: array[0..MAX_PATH] of WideChar;
  N: UINT;
begin
  Result := '';
  FillChar(Buffer, SizeOf(Buffer), 0);

  N := GetSystemDirectoryW(@Buffer[0], MAX_PATH);
  if (N = 0) or (N >= MAX_PATH) then
    Exit;

  Result := UTF8Encode(UnicodeString(PWideChar(@Buffer[0])));
  Result := IncludeTrailingPathDelimiter(Result) + 'netsh.exe';
end;

function StartLaguNETbiScheduledTask: Boolean;
var
  P: TProcess;
  SchTasksPath: String;
begin
  Result := False;

  SchTasksPath := IncludeTrailingPathDelimiter(
    ExtractFileDir(LaguNETbiNetshPath)
  ) + 'schtasks.exe';

  if not FileExists(SchTasksPath) then
    Exit;

  P := TProcess.Create(nil);
  try
    P.Executable := SchTasksPath;
    P.Options := [poWaitOnExit, poNoConsole];
    P.Parameters.Add('/Run');
    P.Parameters.Add('/TN');
    P.Parameters.Add('LaguNETbi');

    try
      P.Execute;
      Result := P.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    P.Free;
  end;
end;

function LaguNETbiSchtasksPath: String;
begin
  Result := IncludeTrailingPathDelimiter(
    ExtractFileDir(LaguNETbiNetshPath)
  ) + 'schtasks.exe';
end;

function LaguNETbiRunProcess(
  const AExecutable: String;
  AParameters: TStrings;
  out AExitCode: LongInt
): Boolean;
var
  P: TProcess;
begin
  Result := False;
  AExitCode := -1;

  P := TProcess.Create(nil);
  try
    P.Executable := AExecutable;
    P.Parameters.Assign(AParameters);
    P.Options := [poWaitOnExit, poNoConsole];

    try
      P.Execute;
    except
      Exit;
    end;

    AExitCode := P.ExitStatus;
    Result := True;
  finally
    P.Free;
  end;
end;

function LaguNETbiStartupTaskExists: Boolean;
var
  Args: TStringList;
  ExitCode: LongInt;
  TaskExe: String;
begin
  Result := False;
  TaskExe := LaguNETbiSchtasksPath;

  if (TaskExe = '') or not FileExists(TaskExe) then
    Exit;

  Args := TStringList.Create;
  try
    Args.Add('/Query');
    Args.Add('/TN');
    Args.Add('LaguNETbi');

    if LaguNETbiRunProcess(TaskExe, Args, ExitCode) then
      Result := ExitCode = 0;
  finally
    Args.Free;
  end;
end;

function LaguNETbiSetStartupTask(AEnable: Boolean): Boolean;
var
  Args: TStringList;
  ExitCode: LongInt;
  TaskExe, ExePath: String;
begin
  Result := False;
  TaskExe := LaguNETbiSchtasksPath;

  if (TaskExe = '') or not FileExists(TaskExe) then
    Exit;

  Args := TStringList.Create;
  try
    if AEnable then
    begin
      ExePath := ExpandFileName(ParamStr(0));

      Args.Add('/Create');
      Args.Add('/TN');
      Args.Add('LaguNETbi');
      Args.Add('/TR');
      Args.Add(ExePath);
      Args.Add('/SC');
      Args.Add('ONLOGON');
      Args.Add('/RL');
      Args.Add('HIGHEST');
      Args.Add('/IT');
      Args.Add('/F');
    end
    else
    begin
      Args.Add('/Delete');
      Args.Add('/TN');
      Args.Add('LaguNETbi');
      Args.Add('/F');
    end;

    if LaguNETbiRunProcess(TaskExe, Args, ExitCode) then
      Result := ExitCode = 0;
  finally
    Args.Free;
  end;
end;

function LaguNETbiRunElevatedSelf(
  const AParameter: String;
  out AError: String
): Boolean;
var
  SEI: TShellExecuteInfoW;
  VerbW, FileW, ParamsW: UnicodeString;
  ExitCode: DWORD;
  LastErr: DWORD;
begin
  Result := False;
  AError := '';

  VerbW := UnicodeString('runas');
  FileW := UnicodeString(Application.ExeName);
  ParamsW := UnicodeString(AParameter);

  FillChar(SEI, SizeOf(SEI), 0);
  SEI.cbSize := SizeOf(SEI);
  SEI.fMask := SEE_MASK_NOCLOSEPROCESS;
  SEI.lpVerb := PWideChar(VerbW);
  SEI.lpFile := PWideChar(FileW);
  SEI.lpParameters := PWideChar(ParamsW);
  SEI.nShow := SW_HIDE;

  if not ShellExecuteExW(LPSHELLEXECUTEINFOW(@SEI)) then
  begin
    LastErr := GetLastError;
    if LastErr = ERROR_CANCELLED then
      AError := 'Operacion cancelada.'
    else
      AError := 'Windows no pudo completar la operacion. ' +
        SysErrorMessage(LastErr);
    Exit;
  end;

  try
    WaitForSingleObject(SEI.hProcess, INFINITE);

    ExitCode := 1;
    if not GetExitCodeProcess(SEI.hProcess, ExitCode) then
    begin
      AError := 'No se pudo obtener el resultado de la operacion.';
      Exit;
    end;

    if ExitCode <> 0 then
    begin
      AError := 'No se pudo cambiar la opcion de inicio con Windows.';
      Exit;
    end;

    Result := True;
  finally
    CloseHandle(SEI.hProcess);
  end;
end;

function LaguNETbiChangeStartupTask(
  AEnable: Boolean;
  out AError: String
): Boolean;
var
  Param: String;
begin
  AError := '';

  if LaguNETbiIsElevated then
  begin
    Result := LaguNETbiSetStartupTask(AEnable);
    if not Result then
      AError := 'No se pudo modificar la tarea programada LaguNETbi.';
    Exit;
  end;

  if AEnable then
    Param := '--lagunetbi-startup-enable'
  else
    Param := '--lagunetbi-startup-disable';

  Result := LaguNETbiRunElevatedSelf(Param, AError);
end;

function LaguNETbiQuoteArgument(const S: String): String;
begin
  Result := '"' + StringReplace(S, '"', '\"', [rfReplaceAll]) + '"';
end;

function LaguNETbiRunElevatedNetsh(
  AParameters: TStrings;
  out AError: String
): Boolean;
var
  SEI: TShellExecuteInfoW;
  VerbW, FileW, ParamsW: UnicodeString;
  Params, NetshPath: String;
  I: Integer;
  ExitCode, LastErr: DWORD;
begin
  Result := False;
  AError := '';

  NetshPath := LaguNETbiNetshPath;
  if (NetshPath = '') or not FileExists(NetshPath) then
  begin
    AError := 'No se encontro netsh.exe en System32.';
    Exit;
  end;

  Params := '';
  for I := 0 to AParameters.Count - 1 do
  begin
    if Params <> '' then
      Params := Params + ' ';
    Params := Params + LaguNETbiQuoteArgument(AParameters[I]);
  end;

  VerbW := UnicodeString('runas');
  FileW := UnicodeString(NetshPath);
  ParamsW := UnicodeString(Params);

  FillChar(SEI, SizeOf(SEI), 0);
  SEI.cbSize := SizeOf(SEI);
  SEI.fMask := SEE_MASK_NOCLOSEPROCESS;
  SEI.lpVerb := PWideChar(VerbW);
  SEI.lpFile := PWideChar(FileW);
  SEI.lpParameters := PWideChar(ParamsW);
  SEI.nShow := SW_HIDE;

  if not ShellExecuteExW(LPSHELLEXECUTEINFOW(@SEI)) then
  begin
    LastErr := GetLastError;
    if LastErr = ERROR_CANCELLED then
      AError := 'Operacion cancelada: no se concedieron permisos.'
    else
      AError := 'No se pudo iniciar netsh.exe. ' +
        SysErrorMessage(LastErr);
    Exit;
  end;

  try
    WaitForSingleObject(SEI.hProcess, INFINITE);

    ExitCode := 1;
    if not GetExitCodeProcess(SEI.hProcess, ExitCode) then
    begin
      AError := 'No se pudo obtener el resultado de netsh.exe.';
      Exit;
    end;

    if ExitCode <> 0 then
    begin
      AError := 'netsh.exe devolvio el codigo ' +
        IntToStr(ExitCode) + '.';
      Exit;
    end;

    Result := True;
  finally
    CloseHandle(SEI.hProcess);
  end;
end;

function PrepareLaguNETbiStartup: Boolean;
var
  CaptionW: UnicodeString;
  ExistingWindow: HWND;
begin
  Result := False;

  { Una ventana oculta en el tray sigue siendo localizable. }
  CaptionW := UnicodeString('LaguNET bi');
  ExistingWindow := FindWindowW(nil, PWideChar(CaptionW));

  if ExistingWindow <> 0 then
  begin
    ShowWindow(ExistingWindow, SW_RESTORE);
    SetForegroundWindow(ExistingWindow);
    Exit;
  end;

  { Si nos lanzo la tarea programada, ya tenemos privilegios. }
  if LaguNETbiIsElevated then
  begin
    Result := True;
    Exit;
  end;

  { Doble clic normal: arrancamos la tarea ya autorizada y salimos. }
  if StartLaguNETbiScheduledTask then
  begin
    Result := False;
    Exit;
  end;

  { Fallback de lectura/edicion si la tarea no existe. }
  Result := True;
end;

end.
