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
  Windows, ShellApi, SysUtils, Process, Forms, ActiveX, ComObj, Variants;

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

{ El check refleja solo el inicio automatico de esta copia. }
function LaguNETbiTaskTargetsThisExe: Boolean; forward;

function LaguNETbiStartupTaskExists: Boolean;
begin
  Result := LaguNETbiTaskTargetsThisExe;
end;

function LaguNETbiPowerShellPath: String;
var
  WindowsDir: String;
begin
  Result := '';
  WindowsDir := GetEnvironmentVariable('WINDIR');

  if WindowsDir = '' then
    Exit;

  Result :=
    IncludeTrailingPathDelimiter(WindowsDir) +
    'Sysnative\WindowsPowerShell\v1.0\powershell.exe';

  if FileExists(Result) then
    Exit;

  Result :=
    IncludeTrailingPathDelimiter(WindowsDir) +
    'System32\WindowsPowerShell\v1.0\powershell.exe';

  if not FileExists(Result) then
    Result := '';
end;

function LaguNETbiAllowTaskOnBattery: Boolean;
var
  P: TProcess;
  PowerShellPath: String;
  CommandText: String;
begin
  Result := False;

  PowerShellPath := LaguNETbiPowerShellPath;
  if PowerShellPath = '' then
    Exit;

  CommandText :=
    '$ErrorActionPreference = ''Stop''; ' +
    'Import-Module ScheduledTasks -ErrorAction Stop; ' +
    '$task = Get-ScheduledTask -TaskName ''LaguNETbi'' ' +
      '-TaskPath ''\'' -ErrorAction Stop; ' +
    '$settings = $task.Settings; ' +
    '$settings.DisallowStartIfOnBatteries = $false; ' +
    '$settings.StopIfGoingOnBatteries = $false; ' +
    'Set-ScheduledTask -TaskName ''LaguNETbi'' -TaskPath ''\'' ' +
      '-Settings $settings -ErrorAction Stop | Out-Null;';

  P := TProcess.Create(nil);
  try
    P.Executable := PowerShellPath;
    P.Options := [poWaitOnExit, poNoConsole];
    P.Parameters.Add('-NoProfile');
    P.Parameters.Add('-NonInteractive');
    P.Parameters.Add('-ExecutionPolicy');
    P.Parameters.Add('Bypass');
    P.Parameters.Add('-Command');
    P.Parameters.Add(CommandText);

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

function LaguNETbiSetStartupTask(AEnable: Boolean): Boolean;
var
  Args: TStringList;
  ExitCode: LongInt;
  TaskExe, ExePath: String;
begin
  Result := False;
  { Nunca eliminar una tarea perteneciente a otra copia. }
  if not AEnable and not LaguNETbiTaskTargetsThisExe then
    Exit;
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
    begin
      Result := ExitCode = 0;

      if AEnable and Result then
      begin
        Result := LaguNETbiAllowTaskOnBattery;

        if not Result then
        begin
          Args.Clear;
          Args.Add('/Delete');
          Args.Add('/TN');
          Args.Add('LaguNETbi');
          Args.Add('/F');
          LaguNETbiRunProcess(TaskExe, Args, ExitCode);
        end;
      end;
    end;
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

function LaguNETbiQueryProcessImageNameW(
  AProcess: THandle; AFlags: DWORD; ABuffer: PWideChar;
  var ALength: DWORD
): BOOL; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';

{ No confundimos una copia portable con la instancia de otra carpeta. }
function LaguNETbiSameExeAsWindow(AWindow: HWND): Boolean;
const
  PROCESS_QUERY_LIMITED_INFORMATION_LAGUNET = $1000;
var
  ProcessId, NameLength: DWORD;
  ProcessHandle: THandle;
  Buffer: array[0..2047] of WideChar;
  OtherExe: String;
begin
  Result := False;
  ProcessId := 0;
  GetWindowThreadProcessId(AWindow, @ProcessId);
  if ProcessId = 0 then
    Exit;

  ProcessHandle := OpenProcess(
    PROCESS_QUERY_LIMITED_INFORMATION_LAGUNET, False, ProcessId
  );
  if ProcessHandle = 0 then
    Exit;
  try
    NameLength := Length(Buffer);
    FillChar(Buffer, SizeOf(Buffer), 0);
    if not LaguNETbiQueryProcessImageNameW(
      ProcessHandle, 0, @Buffer[0], NameLength
    ) then
      Exit;
    OtherExe := UTF8Encode(UnicodeString(PWideChar(@Buffer[0])));
    Result := SameText(
      ExpandFileName(OtherExe), ExpandFileName(ParamStr(0))
    );
  finally
    CloseHandle(ProcessHandle);
  end;
end;

{ La tarea de inicio automatico puede seguir apuntando al EXE original.
  La consultamos (sin modificarla) y solo la lanzamos si coincide con
  esta copia. Si no es consultable, iniciamos esta copia normalmente. }
function LaguNETbiTaskTargetsThisExe: Boolean;
var
  InitResult: HRESULT;
  Service, Folder, Task, Actions, Action: OleVariant;
  TaskExe: String;
  FolderPath: WideString;
begin
  Result := False;
  InitResult := CoInitialize(nil);
  try
    try
      Service := CreateOleObject('Schedule.Service');
      Service.Connect;
      FolderPath := '\';
      Folder := Service.GetFolder(FolderPath);
      Task := Folder.GetTask('LaguNETbi');
      if not Boolean(Task.Enabled) then
        Exit;
      Actions := Task.Definition.Actions;
      if Integer(Actions.Count) <> 1 then
        Exit;
      Action := Actions.Item(1);
      TaskExe := Trim(VarToStr(Action.Path));
      if (Length(TaskExe) >= 2) and
         (TaskExe[1] = '"') and (TaskExe[Length(TaskExe)] = '"') then
        TaskExe := Copy(TaskExe, 2, Length(TaskExe) - 2);
      if TaskExe = '' then
        Exit;
      Result := SameText(
        ExpandFileName(TaskExe), ExpandFileName(ParamStr(0))
      );
    except
      { Nunca redirigimos una copia a otra ruta si no podemos verificarla. }
      Result := False;
    end;
  finally
    { Liberar referencias COM antes de desinicializar el apartamento. }
    Action := Unassigned;
    Actions := Unassigned;
    Task := Unassigned;
    Folder := Unassigned;
    Service := Unassigned;
    if (InitResult = 0) or (InitResult = 1) then
      CoUninitialize;
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

  { Buscar todas las instancias: pueden existir copias en otras carpetas. }
  while ExistingWindow <> 0 do
  begin
    if LaguNETbiSameExeAsWindow(ExistingWindow) then
    begin
      ShowWindow(ExistingWindow, SW_RESTORE);
      SetForegroundWindow(ExistingWindow);
      Exit;
    end;
    ExistingWindow := FindWindowExW(
      0, ExistingWindow, nil, PWideChar(CaptionW)
    );
  end;

  { Inicio manual independiente de la tarea de Windows: se ejecuta
    siempre este EXE. La tarea solo se usa al iniciar sesion en Windows. }
  Result := True;
end;

end.
