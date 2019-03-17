unit ConfigManager;

interface

uses
  System.IniFiles, System.IOUtils, System.SysUtils, System.NetEncoding,
  System.Hash;

type
  TConfigManager = class

  private
    { private 宣言 }
    NetEncoding: TNetEncoding;
    CryptKey: string;
    EncryptType: Integer;
    CryptKeyHash: string;
    function GetIniPath(): string;
    function Crypt(const Value: string) : string;
    function Encrypt(const Value: string): string;
    function Decrypt(const Value: string): string;
  public
    { public 宣言 }
    AccessToken: string;
    AccessTokenSecret: string;

    procedure Load();
    procedure Save();
    constructor Create();
  end;

implementation

constructor TConfigManager.Create();
begin
  CryptKey := GetEnvironmentVariable('USERNAME')
    + GetEnvironmentVariable('CLIENTNAME')
    + GetEnvironmentVariable('OS')
    + GetEnvironmentVariable('PROCESSOR_LEVEL');
  if (CryptKey.IsEmpty = True) then begin
    CryptKey := '__DEFAULT__';
  end;
  CryptKeyHash := THashSHA2.GetHashString(CryptKey);

  // 更にキーに計算したハッシュ値を
  // 連結させてさらにハッシュ化したものをキーにする。
  CryptKey := THashSHA2.GetHashString(CryptKeyHash + '_' + CryptKey);
end;

function TConfigManager.GetIniPath(): string;
begin
{$IFDEF MSWINDOWS}
  Result := TPath.Combine(System.SysUtils.GetCurrentDir,'p30sd.ini');
{$ELSE}
  Result := TPath.Combine(TPath.GetDocumentsPath,'p30sd.ini');
{$ENDIF}
end;

function TConfigManager.Crypt(const Value: string) : string;
var
  CharIndex : Integer;
begin
  Result := Value;
  if EncryptType = 1 then
  begin
    for CharIndex := 1 to Length(Value) do
      Result[CharIndex] := chr(
        (ord(Value[CharIndex])) xor (ord(CryptKey[CharIndex mod (CryptKey.Length+1)]))
      );
  end else begin
    for CharIndex := 1 to Length(Value) do
      Result[CharIndex] := chr(not(ord(Value[CharIndex])));
  end;
end;

function TConfigManager.Decrypt(const Value: string) : string;
begin
  //Result := Value;
  Result := Crypt(NetEncoding.Decode(Value));
end;


function TConfigManager.Encrypt(const Value: string) : string;
begin
  //Result := Value;
  Result := NetEncoding.Encode(Crypt(Value)).Replace(#13,'').Replace(#10,'');
end;



 procedure TConfigManager.Load();
var
  IniFile: TMemIniFile;
  IniPath: string;
  IniCryptKeyHash: string;
begin
  NetEncoding := System.NetEncoding.TBase64Encoding.Create();
  IniPath := GetIniPath();
  if (not FileExists(IniPath)) then
  begin
    AccessToken := '';
    AccessTokenSecret := '';
    EncryptType := 0;
    Exit;
  end;
  IniFile := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    EncryptType := IniFile.ReadInteger('Twitter', 'EncryptType', 0);

    // キーの値が有効かを確認する
    IniCryptKeyHash := IniFile.ReadString('System', 'KeyHash', '');
    if ((IniCryptKeyHash.IsEmpty = False)
      and (IniCryptKeyHash <> CryptKeyHash)) then
    begin
      AccessToken := '';
      AccessTokenSecret := '';
    end else begin
      AccessToken := IniFile.ReadString(
        'Twitter', 'AccessToken', '');
      AccessTokenSecret := IniFile.ReadString(
        'Twitter', 'AccessTokenSecret', '');
    end;
  finally
    IniFile.Free;
  end;

  if EncryptType = 0 then
  begin
    Save();
  end;
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

  // encrypt type は 1 を強制
  EncryptType := 1;

  IniFile := TMemIniFile.Create(IniPath, TEncoding.UTF8);
  try
    if AccessToken = '' then begin
      IniFile.WriteString('Twitter', 'AccessToken', '');
    end else begin
      IniFile.WriteString('Twitter', 'AccessToken',
        Encrypt(AccessToken));
    end;

    if AccessTokenSecret = '' then begin
      IniFile.WriteString('Twitter', 'AccessTokenSecret', '');
    end else begin
      IniFile.WriteString('Twitter', 'AccessTokenSecret',
        Encrypt(AccessTokenSecret));
    end;

    IniFile.WriteInteger('Twitter', 'EncryptType',
      EncryptType);

    IniFile.WriteString('System', 'KeyHash',
      CryptKeyHash);

    IniFile.UpdateFile();
  finally
    IniFile.Free;
  end;
end;

end.
