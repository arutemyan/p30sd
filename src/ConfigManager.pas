unit ConfigManager;

interface

uses
  System.IniFiles, System.IOUtils, System.SysUtils, System.NetEncoding;

type
  TConfigManager = class

  private
    { private êÈåæ }
    NetEncoding: TNetEncoding;


    function GetIniPath(): string;
    function Crypt(const Value : string) : string;
    function Encrypt(const Value : string): string;
    function Decrypt(const Value : string): string;
  public
    { public êÈåæ }
    AccessToken: string;
    AccessTokenSecret: string;

    procedure Load();
    procedure Save();
  end;

implementation

function TConfigManager.GetIniPath(): string;
begin
{$IFDEF MSWINDOWS}
  Result := TPath.Combine(System.SysUtils.GetCurrentDir,'p30sd.ini');
{$ELSE}
  Result := TPath.Combine(TPath.GetDocumentsPath,'p30sd.ini');
{$ENDIF}
end;

function TConfigManager.Crypt(const Value : string) : string;
var
  CharIndex : integer;
begin
  Result := Value;
  for CharIndex := 1 to Length(Value) do
    Result[CharIndex] := chr(not(ord(Value[CharIndex])));
end;

function TConfigManager.Decrypt(const Value : string) : string;
begin
  //Result := Value;
  Result := Crypt(NetEncoding.Decode(Value));
end;


function TConfigManager.Encrypt(const Value : string) : string;
begin
  //Result := Value;
  Result := NetEncoding.Encode(Crypt(Value)).Replace(#13,'').Replace(#10,'');
end;



 procedure TConfigManager.Load();
var
  IniFile: TMemIniFile;
  IniPath: string;
begin
  NetEncoding := System.NetEncoding.TBase64Encoding.Create();
  IniPath := GetIniPath();
  if (not FileExists(IniPath)) then
  begin
    AccessToken := '';
    AccessTokenSecret := '';
    Exit;
  end;
  IniFile := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    AccessToken := IniFile.ReadString('Twitter', 'AccessToken', '');
    if AccessToken <> '' then
      AccessToken := Decrypt(AccessToken);

    AccessTokenSecret := IniFile.ReadString('Twitter', 'AccessTokenSecret', '');
    if AccessTokenSecret <> '' then
      AccessTokenSecret := Decrypt(AccessTokenSecret);
  finally
    IniFile.Free;
  end;
  Save();
end;

procedure TConfigManager.Save();
var
  IniFile: TMemIniFile;
  IniPath: string;
begin
  IniPath := GetIniPath();
  if (not FileExists(IniPath)) then
  begin
    AccessToken := '';
    AccessTokenSecret := '';
  end;
  IniFile := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    if AccessToken = '' then begin
      IniFile.WriteString('Twitter', 'AccessToken', '');
    end else begin
      IniFile.WriteString('Twitter', 'AccessToken', Encrypt(AccessToken));
    end;

    if AccessTokenSecret = '' then begin
      IniFile.WriteString('Twitter', 'AccessTokenSecret', '');
    end else begin
      IniFile.WriteString('Twitter', 'AccessTokenSecret', Encrypt(AccessTokenSecret));
    end;

    IniFile.UpdateFile();
  finally
    IniFile.Free;
  end;
end;

end.
