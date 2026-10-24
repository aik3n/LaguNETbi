unit uBatInterpreter;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
function ExecuteNetworkProfile(const AFileName: String; out AError: String): Boolean;
implementation
uses Process, uWindowsSupport;

type
  TOperation = class
    Args: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;
constructor TOperation.Create;
begin inherited Create; Args:=TStringList.Create; end;
destructor TOperation.Destroy;
begin Args.Free; inherited Destroy; end;

{ Tokenizador de datos, no interprete de cmd.exe. Las comillas solo agrupan
  espacios. Las lineas nunca se pasan a un shell. }
function Tokens(const S: String; A: TStrings): Boolean;
var I: Integer; Q: Boolean; V: String; C: Char;
begin
  A.Clear; V:=''; Q:=False;
  for I:=1 to Length(S) do begin
    C:=S[I];
    if C='"' then Q:=not Q
    else if (C<=#32) and not Q then begin
      if V<>'' then begin A.Add(V); V:=''; end;
    end else V:=V+C;
  end;
  Result:=not Q;
  if Result and (V<>'') then A.Add(V);
end;
function Field(const S, Key: String): String;
begin
  Result:='';
  if Pos(LowerCase(Key)+'=',LowerCase(S))=1 then
    Result:=Copy(S,Length(Key)+2,MaxInt);
end;
function IPv4(const S: String): Boolean;
var P: TStringList; I,N: Integer;
begin
  Result:=False; P:=TStringList.Create;
  try
    P.StrictDelimiter:=True; P.Delimiter:='.'; P.DelimitedText:=S;
    if P.Count<>4 then Exit;
    for I:=0 to 3 do
      if (P[I]='') or not TryStrToInt(P[I],N) or (N<0) or (N>255) then Exit;
    Result:=True;
  finally P.Free; end;
end;
function MaskOK(const S: String): Boolean;
var P:TStringList; I,N,J: Integer; ZeroSeen:Boolean;
begin
  Result:=False;
  if not IPv4(S) then Exit;
  P:=TStringList.Create;
  try
    P.StrictDelimiter:=True; P.Delimiter:='.'; P.DelimitedText:=S;
    ZeroSeen:=False;
    for I:=0 to 3 do begin
      N:=StrToInt(P[I]);
      for J:=7 downto 0 do begin
        if (N and (1 shl J))<>0 then begin
          if ZeroSeen then Exit;
        end else ZeroSeen:=True;
      end;
    end;
    Result:=True;
  finally P.Free; end;
end;
function SafeValue(const S: String): Boolean;
var I: Integer;
begin
  Result:=(S<>'') and (Pos('"',S)=0);
  for I:=1 to Length(S) do
    if (Ord(S[I])<32) or (S[I] in ['&','|','<','>','^','%','!']) then Exit(False);
end;
function ParseCommand(const S: String; A: TStrings; out Known: Boolean): Boolean;
var T:TStringList; V,IP,Mask,GW: String; I:Integer;
begin
  Result:=False; Known:=False;
  T:=TStringList.Create;
  try
    if not Tokens(Trim(S),T) then Exit;
    if T.Count=0 then begin Result:=True; Exit; end;
    if (T[0]='::') or (Copy(T[0],1,2)='::') or
      SameText(T[0],'rem') or SameText(T[0],'@rem') or
      SameText(Trim(S),'@echo off') or SameText(Trim(S),'echo off') or
      SameText(Trim(S),'pause') or SameText(Trim(S),'@pause') or
      SameText(T[0],'echo') or SameText(T[0],'@echo') then begin
      Result:=True; Exit;
    end;
    if (T.Count>=5) and SameText(T[0],'netsh') and
       SameText(T[1],'interface') and SameText(T[2],'ipv4') and
       SameText(T[3],'set') and SameText(T[4],'address') then begin
      Known:=True;
      if T.Count<7 then Exit;
      V:=Field(T[5],'name');
      if not SafeValue(V) then Exit;
      A.Add('interface'); A.Add('ipv4'); A.Add('set');
      A.Add('address'); A.Add('name='+V);
      if (T.Count=7) and SameText(T[6],'source=dhcp') then
        A.Add('source=dhcp')
      else begin
        if (not SameText(T[6],'static')) and
           (not SameText(T[6],'source=static')) then Exit;
        if (T.Count<9) or (T.Count>10) then Exit;
        IP:=Field(T[7],'address'); if IP='' then IP:=T[7];
        Mask:=Field(T[8],'mask'); if Mask='' then Mask:=T[8];
        if not IPv4(IP) or not MaskOK(Mask) then Exit;
        A.Add('source=static'); A.Add('address='+IP); A.Add('mask='+Mask);
        GW:='none';
        if T.Count=10 then begin
          GW:=Field(T[9],'gateway'); if GW='' then GW:=T[9];
          if not SameText(GW,'none') and not IPv4(GW) then Exit;
        end;
        A.Add('gateway='+GW);
      end;
      Result:=True; Exit;
    end;
    if (T.Count>=3) and SameText(T[0],'netsh') and
       SameText(T[1],'wlan') and SameText(T[2],'connect') then begin
      Known:=True;
      if (T.Count<4) or (T.Count>5) then Exit;
      V:=Field(T[3],'name');
      if not SafeValue(V) then Exit;
      A.Add('wlan'); A.Add('connect'); A.Add('name='+V);
      if T.Count=5 then begin
        IP:=Field(T[4],'ssid');
        if not SafeValue(IP) then Exit;
        A.Add('ssid='+IP);
      end else A.Add('ssid='+V);
      Result:=True; Exit;
    end;
    { Instruccion ajena: no ejecutar ni interpretar. }
    Result:=True;
  finally T.Free; end;
end;
function RunNetsh(Args:TStrings; out Err:String):Boolean;
var P:TProcess; Path:String;
begin
  if not LaguNETbiIsElevated then
    Exit(LaguNETbiRunElevatedNetsh(Args,Err));
  Result:=False;
  Path:=LaguNETbiNetshPath;
  if (Path='') or not FileExists(Path) then begin
    Err:='No se encuentra netsh.exe'; Exit;
  end;
  P:=TProcess.Create(nil);
  try
    P.Executable:=Path; P.Parameters.Assign(Args);
    P.Options:=[poWaitOnExit,poNoConsole];
    try
      P.Execute;
      Result:=P.ExitStatus=0;
      if not Result then Err:='netsh devolvio codigo '+IntToStr(P.ExitStatus);
    except on E:Exception do Err:=E.Message; end;
  finally P.Free; end;
end;
function ExecuteNetworkProfile(const AFileName: String; out AError: String): Boolean;
var L:TStringList; Jobs:TList; Args:TStringList; Op:TOperation;
    I:Integer; Known:Boolean;
begin
  Result:=False; AError:='';
  L:=TStringList.Create; Jobs:=TList.Create;
  try
    try L.LoadFromFile(AFileName);
    except on E:Exception do begin AError:=E.Message; Exit; end; end;
    { Interpretar el perfil completo ANTES de modificar la red. }
    for I:=0 to L.Count-1 do begin
      Args:=TStringList.Create;
      try
        if not ParseCommand(L[I],Args,Known) then begin
          AError:='Parametros no admitidos en linea '+IntToStr(I+1);
          Exit;
        end;
        if Known then begin
          Op:=TOperation.Create;
          Op.Args.Assign(Args); Jobs.Add(Op);
        end;
      finally Args.Free; end;
    end;
    if Jobs.Count=0 then begin
      AError:='El perfil no contiene operaciones de red reconocidas.';
      Exit;
    end;
    for I:=0 to Jobs.Count-1 do begin
      Op:=TOperation(Jobs[I]);
      if not RunNetsh(Op.Args,AError) then Exit;
    end;
    Result:=True;
  finally
    for I:=0 to Jobs.Count-1 do TOperation(Jobs[I]).Free;
    Jobs.Free; L.Free;
  end;
end;
end.