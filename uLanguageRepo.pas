unit uLanguageRepo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLanguageRepoAction = (lraSearch, lraDownload);

  { La red nunca se consulta desde el hilo de la interfaz. }
  TLanguageRepoThread = class(TThread)
  private
    FAction: TLanguageRepoAction;
    FCode: String;
    FFileName: String;
    FError: String;
    FFiles: TStringList;
  protected
    procedure Execute; override;
  public
    constructor Create(AAction: TLanguageRepoAction;
      const ACode, AFileName: String);
    destructor Destroy; override;
    property Action: TLanguageRepoAction read FAction;
    property ErrorText: String read FError;
    property Files: TStringList read FFiles;
  end;

function LanguageRepoValidName(const AName: String): Boolean;
function LanguageRepoCode(const AName: String): String;
procedure LanguageRepoLocalFiles(AFiles: TStrings);
function LanguageRepoLocalFile(const ACode: String): String;

implementation

uses
  Windows, IniFiles, fpjson, jsonparser;

const
  LANG_MAX_LIST = 262144;
  LANG_MAX_FILE = 131072;
  LANG_API_PATH = '/repos/aik3n/LaguNETbi/contents/lang?ref=main';

function LangWinHttpOpen(AUserAgent: PWideChar; AAccessType: DWORD;
  AProxy, ABypass: PWideChar; AFlags: DWORD): Pointer; stdcall;
  external 'winhttp.dll' name 'WinHttpOpen';
function LangWinHttpConnect(ASession: Pointer; AHost: PWideChar;
  APort: Word; AReserved: DWORD): Pointer; stdcall;
  external 'winhttp.dll' name 'WinHttpConnect';
function LangWinHttpOpenRequest(AConnect: Pointer; AVerb, APath,
  AVersion, AReferrer: PWideChar; AAccept: Pointer; AFlags: DWORD): Pointer;
  stdcall; external 'winhttp.dll' name 'WinHttpOpenRequest';
function LangWinHttpSetTimeouts(AHandle: Pointer; AResolve, AConnect,
  ASend, AReceive: Integer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetTimeouts';
function LangWinHttpSendRequest(AHandle: Pointer; AHeaders: PWideChar;
  AHeaderLength: DWORD; AOptional: Pointer; AOptionalLength,
  ATotalLength: DWORD; AContext: PtrUInt): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSendRequest';
function LangWinHttpReceiveResponse(AHandle, AReserved: Pointer): BOOL;
  stdcall; external 'winhttp.dll' name 'WinHttpReceiveResponse';
function LangWinHttpQueryHeaders(AHandle: Pointer; AInfo: DWORD;
  AName: PWideChar; ABuffer: Pointer; var ASize: DWORD;
  AIndex: Pointer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpQueryHeaders';
function LangWinHttpReadData(AHandle, ABuffer: Pointer; ASize: DWORD;
  var ARead: DWORD): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpReadData';
function LangWinHttpCloseHandle(AHandle: Pointer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpCloseHandle';

function LangHttpGet(const AHost, APath: String;
  AMaxBytes: Integer): RawByteString;
const
  FLAG_SECURE = DWORD($00800000);
  STATUS_CODE_NUMBER = DWORD($20000000) or 19;
var
  Session, Connection, Request: Pointer;
  AgentW, HostW, PathW, MethodW, HeadersW: UnicodeString;
  Status, StatusLen, ReadCount: DWORD;
  Buffer: array[0..8191] of Byte;
  Previous: Integer;
begin
  Result := '';
  AgentW := UnicodeString('LaguNETbi/2.0');
  HostW := UnicodeString(AHost);
  PathW := UnicodeString(APath);
  MethodW := UnicodeString('GET');
  HeadersW := UnicodeString('Accept: application/vnd.github+json'#13#10 +
    'Cache-Control: no-cache'#13#10);
  Session := LangWinHttpOpen(PWideChar(AgentW), 0, nil, nil, 0);
  if Session = nil then
    raise Exception.Create('Cannot initialize HTTPS.');
  try
    LangWinHttpSetTimeouts(Session, 3000, 4000, 4000, 5000);
    Connection := LangWinHttpConnect(Session, PWideChar(HostW), 443, 0);
    if Connection = nil then
      raise Exception.Create('Cannot connect to GitHub.');
    try
      Request := LangWinHttpOpenRequest(Connection, PWideChar(MethodW),
        PWideChar(PathW), nil, nil, nil, FLAG_SECURE);
      if Request = nil then
        raise Exception.Create('Cannot open HTTPS request.');
      try
        if not LangWinHttpSendRequest(Request, PWideChar(HeadersW),
          DWORD(-1), nil, 0, 0, 0) then
          raise Exception.Create('Cannot send HTTPS request.');
        if not LangWinHttpReceiveResponse(Request, nil) then
          raise Exception.Create('GitHub did not respond.');
        Status := 0;
        StatusLen := SizeOf(Status);
        if not LangWinHttpQueryHeaders(Request, STATUS_CODE_NUMBER, nil,
          @Status, StatusLen, nil) then
          raise Exception.Create('Cannot read HTTP status.');
        if Status <> 200 then
          raise Exception.Create('GitHub returned HTTP ' + IntToStr(Status) + '.');
        repeat
          ReadCount := 0;
          if not LangWinHttpReadData(Request, @Buffer[0], SizeOf(Buffer),
            ReadCount) then
            raise Exception.Create('Incomplete HTTPS response.');
          if ReadCount = 0 then
            Break;
          Previous := Length(Result);
          if (Previous + Integer(ReadCount)) > AMaxBytes then
            raise Exception.Create('Language download exceeds size limit.');
          SetLength(Result, Previous + Integer(ReadCount));
          Move(Buffer[0], Result[Previous + 1], ReadCount);
        until False;
      finally
        LangWinHttpCloseHandle(Request);
      end;
    finally
      LangWinHttpCloseHandle(Connection);
    end;
  finally
    LangWinHttpCloseHandle(Session);
  end;
end;

function LanguageRepoValidName(const AName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(AName) < 9) or (Length(AName) > 120) or
     (AName[4] <> '-') or
     (not SameText(ExtractFileExt(AName), '.ini')) then
    Exit;
  for I := 1 to 3 do
    if not (AName[I] in ['a'..'z']) then
      Exit;
  for I := 5 to Length(AName) - 4 do
    if (Ord(AName[I]) < 32) or
       (AName[I] in ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
      Exit;
  if Trim(Copy(AName, 5, Length(AName)-8)) = '' then
    Exit;
  Result := True;
end;

function LanguageRepoCode(const AName: String): String;
begin
  Result := '';
  if LanguageRepoValidName(AName) then
    Result := Copy(AName, 1, 3);
end;

function LangDir: String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(
    ExpandFileName(ParamStr(0)))) + 'lang';
end;

procedure LanguageRepoLocalFiles(AFiles: TStrings);
var
  SR: SysUtils.TSearchRec;
  Dir: String;
begin
  AFiles.Clear;
  Dir := LangDir;
  if not DirectoryExists(Dir) then
    Exit;
  if SysUtils.FindFirst(IncludeTrailingPathDelimiter(Dir) + '*.ini',
    faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if ((SR.Attr and faDirectory) = 0) and
         LanguageRepoValidName(SR.Name) then
        AFiles.Add(SR.Name);
    until SysUtils.FindNext(SR) <> 0;
  finally
    SysUtils.FindClose(SR);
  end;
end;

function LanguageRepoLocalFile(const ACode: String): String;
var
  List: TStringList;
  I: Integer;
begin
  Result := '';
  List := TStringList.Create;
  try
    LanguageRepoLocalFiles(List);
    for I := 0 to List.Count - 1 do
      if LanguageRepoCode(List[I]) = ACode then
      begin
        Result := IncludeTrailingPathDelimiter(LangDir) + List[I];
        Exit;
      end;
  finally
    List.Free;
  end;
end;

function LangEncodedFilename(const AName: String): String;
const
  HEX: array[0..15] of Char = '0123456789ABCDEF';
var
  I: Integer;
  B: Byte;
begin
  Result := '';
  for I := 1 to Length(AName) do
  begin
    B := Ord(AName[I]);
    if (B >= 65) and (B <= 90) or
       (B >= 97) and (B <= 122) or
       (B >= 48) and (B <= 57) or (B in [45,46,95]) then
      Result := Result + Char(B)
    else
      Result := Result + '%' + HEX[B shr 4] + HEX[B and 15];
  end;
end;

procedure TLanguageRepoThread.Execute;
var
  Data: RawByteString;
  JSON: TJSONData;
  Arr: TJSONArray;
  Entry: TJSONObject;
  I: Integer;
  FileName, Code, Dir, Destination, Temp: String;
  Stream: TFileStream;
  Ini: TIniFile;
begin
  try
    if FAction = lraSearch then
    begin
      Data := LangHttpGet('api.github.com', LANG_API_PATH, LANG_MAX_LIST);
      JSON := GetJSON(UTF8String(Data));
      try
        if JSON.JSONType <> jtArray then
          raise Exception.Create('GitHub did not return a language list.');
        Arr := TJSONArray(JSON);
        for I := 0 to Arr.Count - 1 do
        begin
          if Terminated then Exit;
          if Arr.Items[I].JSONType <> jtObject then Continue;
          Entry := TJSONObject(Arr.Items[I]);
          if Entry.Get('type', '') <> 'file' then Continue;
          FileName := Entry.Get('name', '');
          if LanguageRepoValidName(FileName) then
            FFiles.Add(FileName);
        end;
      finally
        JSON.Free;
      end;
    end
    else
    begin
      if not LanguageRepoValidName(FFileName) or
         (LanguageRepoCode(FFileName) <> FCode) then
        raise Exception.Create('Invalid language filename.');
      if LanguageRepoLocalFile(FCode) <> '' then Exit;
      Data := LangHttpGet('raw.githubusercontent.com',
        '/aik3n/LaguNETbi/main/lang/' + LangEncodedFilename(FFileName),
        LANG_MAX_FILE);
      if Terminated then Exit;
      Dir := LangDir;
      if not ForceDirectories(Dir) then
        raise Exception.Create('Cannot create lang directory.');
      Destination := IncludeTrailingPathDelimiter(Dir) + FFileName;
      Temp := Destination + '.download';
      if FileExists(Destination) then
        raise Exception.Create('Language file already exists.');
      if FileExists(Temp) then
        raise Exception.Create('Pending language download already exists.');
      try
        Stream := TFileStream.Create(Temp, fmCreate or fmShareExclusive);
        try
          if Length(Data) = 0 then
            raise Exception.Create('Empty translation.');
          Stream.WriteBuffer(Data[1], Length(Data));
        finally
          Stream.Free;
        end;
        Ini := TIniFile.Create(Temp);
        try
          if not SameText(Ini.ReadString('Language','Code',''), FCode) then
            raise Exception.Create('Translation language code mismatch.');
          if (not Ini.SectionExists('Main')) and
             (not Ini.SectionExists('Settings')) then
            raise Exception.Create('Invalid translation file.');
        finally
          Ini.Free;
        end;
        if Terminated then Exit;
        if not RenameFile(Temp, Destination) then
          raise Exception.Create('Cannot install translation file.');
      finally
        if FileExists(Temp) then SysUtils.DeleteFile(Temp);
      end;
    end;
  except
    on E: Exception do FError := E.Message;
  end;
end;

constructor TLanguageRepoThread.Create(AAction: TLanguageRepoAction;
  const ACode, AFileName: String);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FAction := AAction;
  FCode := ACode;
  FFileName := AFileName;
  FFiles := TStringList.Create;
end;

destructor TLanguageRepoThread.Destroy;
begin
  FFiles.Free;
  inherited Destroy;
end;

end.
