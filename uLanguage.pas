unit uLanguage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

procedure LanguageInitialize;
function LanguageText(const ASection, AKey, AEnglish: String): String;
function LanguageFormat(const ASection, AKey, AEnglish: String;
  const AArgs: array of const): String;
function LanguageSelected: String;
function LanguageEffective: String;
function LanguageSetSelection(const ACode: String): Boolean;

implementation

uses
  Windows, IniFiles;

{ FPC 3.2.2 no publica esta API en la unidad Windows. }
function LaguNETbiGetUserDefaultUILanguage: Word; stdcall;
  external 'kernel32.dll' name 'GetUserDefaultUILanguage';

var
  LIniPath: String = '';
  LLangDir: String = '';
  LSelected: String = 'auto';
  LEffective: String = 'eng';
  LTranslation: TIniFile = nil;

function LanguageNormalizeChoice(const ACode: String): String;
begin
  Result := LowerCase(Trim(ACode));
  if (Result <> 'auto') and (Result <> 'eng') and
     (Result <> 'spa') then
    Result := 'auto';
end;

function LanguageWindowsCode: String;
var
  PrimaryId: Word;
begin
  { PRIMARYLANGID(GetUserDefaultUILanguage). No dependemos del nombre
    localizado de Windows ni del pais (es-ES, es-MX, etc.). }
  PrimaryId := LaguNETbiGetUserDefaultUILanguage and $03FF;
  case PrimaryId of
    $000A: Result := 'spa';
    $002D: Result := 'eus';
    $0007: Result := 'deu';
    $000C: Result := 'fra';
    $0010: Result := 'ita';
    $0016: Result := 'por';
    else Result := 'eng';
  end;
end;

function LanguageFindFile(const ACode: String): String;
var
  SR: TSearchRec;
  SearchDir, FileCode: String;
begin
  Result := '';
  if (ACode = 'eng') or (LLangDir = '') or
     (not DirectoryExists(LLangDir)) then
    Exit;

  SearchDir := IncludeTrailingPathDelimiter(LLangDir);
  { Esquema codigo-Nombre.ini: se usa el primer guion para determinar
    el codigo y el nombre completo para abrir el archivo. }
  if SysUtils.FindFirst(SearchDir + '*.ini', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Attr and faDirectory) <> 0 then
        Continue;
      if (Length(SR.Name) < 8) or (SR.Name[4] <> '-') then
        Continue;
      FileCode := LowerCase(Copy(SR.Name, 1, 3));
      if (FileCode = ACode) and
         SameText(ExtractFileExt(SR.Name), '.ini') then
      begin
        Result := SearchDir + SR.Name;
        Exit;
      end;
    until SysUtils.FindNext(SR) <> 0;
  finally
    SysUtils.FindClose(SR);
  end;
end;

procedure LanguageLoad;
var
  Code, LocalFile: String;
begin
  FreeAndNil(LTranslation);
  if LSelected = 'auto' then
    Code := LanguageWindowsCode
  else
    Code := LSelected;

  LEffective := 'eng';
  if Code = 'eng' then
    Exit;
  LocalFile := LanguageFindFile(Code);
  if LocalFile = '' then
    Exit;

  try
    LTranslation := TIniFile.Create(LocalFile);
    { Un INI mal formado no debe cambiar ni bloquear el inicio. }
    if LTranslation.ReadString('Language', 'Code', '') <> Code then
    begin
      FreeAndNil(LTranslation);
      Exit;
    end;
    LEffective := Code;
  except
    FreeAndNil(LTranslation);
    LEffective := 'eng';
  end;
end;

procedure LanguageInitialize;
var
  Ini: TIniFile;
begin
  LIniPath := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'LaguNETbi.ini';
  LLangDir := IncludeTrailingPathDelimiter(
    ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'lang';
  LSelected := 'auto';

  if FileExists(LIniPath) then
  begin
    try
      Ini := TIniFile.Create(LIniPath);
      try
        LSelected := LanguageNormalizeChoice(
          Ini.ReadString('Language', 'Selected', 'auto'));
        if not Ini.ValueExists('Language', 'Selected') then
          Ini.WriteString('Language', 'Selected', 'auto');
      finally
        Ini.Free;
      end;
    except
      { Preferencias protegidas: utilizar deteccion automatica. }
      LSelected := 'auto';
    end;
  end;
  LanguageLoad;
end;

function LanguageText(const ASection, AKey, AEnglish: String): String;
begin
  Result := AEnglish;
  if LTranslation = nil then
    Exit;
  try
    Result := LTranslation.ReadString(ASection, AKey, AEnglish);
    if Trim(Result) = '' then
      Result := AEnglish;
  except
    Result := AEnglish;
  end;
end;

function LanguageFormat(const ASection, AKey, AEnglish: String;
  const AArgs: array of const): String;
begin
  try
    Result := Format(LanguageText(ASection, AKey, AEnglish), AArgs);
  except
    { Formatos incorrectos en traducciones externas: usar ingles. }
    Result := Format(AEnglish, AArgs);
  end;
end;

function LanguageSelected: String;
begin
  Result := LSelected;
end;

function LanguageEffective: String;
begin
  Result := LEffective;
end;

function LanguageSetSelection(const ACode: String): Boolean;
var
  Ini: TIniFile;
  Code: String;
begin
  Result := False;
  Code := LanguageNormalizeChoice(ACode);
  if (Code = LSelected) then
  begin
    Result := True;
    Exit;
  end;
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
  LanguageLoad;
  Result := True;
end;

finalization
  FreeAndNil(LTranslation);
end.
