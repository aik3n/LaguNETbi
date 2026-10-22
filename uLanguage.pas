unit uLanguage;
{$mode objfpc}{$H+}
interface
uses SysUtils;
procedure LanguageInitialize;
function LanguageSelected: String;
function LanguageDesiredCode: String;
function LanguageSetSelection(const ACode: String): Boolean;
implementation
uses IniFiles;

function LaguNETbiGetUserDefaultUILanguage: Word; stdcall;
  external 'kernel32.dll' name 'GetUserDefaultUILanguage';
var
  LIniPath: String = '';
  LSelected: String = 'auto';

function NormalizeCode(const ACode: String): String;
var I: Integer;
begin
  Result := LowerCase(Trim(ACode));
  if Result = 'spa' then Result := 'es'
  else if Result = 'eus' then Result := 'eu'
  else if Result = 'deu' then Result := 'de'
  else if Result = 'eng' then Result := 'en'
  else if Result = 'fra' then Result := 'fr'
  else if Result = 'ita' then Result := 'it'
  else if Result = 'por' then Result := 'pt';
  if Result = 'auto' then Exit;
  if Length(Result) <> 2 then
  begin
    Result := 'auto';
    Exit;
  end;
  for I := 1 to 2 do
    if not (Result[I] in ['a'..'z']) then
    begin
      Result := 'auto';
      Exit;
    end;
end;

function WindowsLanguage: String;
begin
  case LaguNETbiGetUserDefaultUILanguage and $03FF of
    $000A: Result := 'es';
    $002D: Result := 'eu';
    $0007: Result := 'de';
    $000C: Result := 'fr';
    $0010: Result := 'it';
    $0016: Result := 'pt';
    else Result := 'en';
  end;
end;

procedure LanguageInitialize;
var Ini: TIniFile;
begin
  LIniPath := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'LaguNETbi.ini';
  LSelected := 'auto';
  if not FileExists(LIniPath) then Exit;
  try
    Ini := TIniFile.Create(LIniPath);
    try
      LSelected := NormalizeCode(Ini.ReadString('Language', 'Selected', 'auto'));
    finally
      Ini.Free;
    end;
  except
    LSelected := 'auto';
  end;
end;

function LanguageSelected: String;
begin
  Result := LSelected;
end;

function LanguageDesiredCode: String;
begin
  if LSelected = 'auto' then Result := WindowsLanguage
  else Result := LSelected;
end;

function LanguageSetSelection(const ACode: String): Boolean;
var Ini: TIniFile; Code: String;
begin
  Result := False;
  Code := NormalizeCode(ACode);
  if Code = LSelected then Exit(True);
  try
    Ini := TIniFile.Create(LIniPath);
    try
      Ini.WriteString('Language', 'Selected', Code);
    finally
      Ini.Free;
    end;
  except
    Exit;
  end;
  LSelected := Code;
  Result := True;
end;
end.
