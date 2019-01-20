unit ConfigFormUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Edit,
  REST.Client, REST.Authenticator.OAuth, System.NetEncoding, AppDefine,
  REST.Utils,REST.Types,REST.Response.Adapter,REST.Authenticator.Simple,
  REST.Authenticator.Basic,
  Data.Bind.EngExt,
  IPPeerClient
{$IFDEF ANDROID32}
  ,System.Permissions
  ,Androidapi.Helpers
  ,Androidapi.JNI.App
  ,Androidapi.JNI.OS
{$ENDIF}
{$IFDEF MSWINDOWS}
  ,REST.Authenticator.OAuth.WebForm.Win, FMX.TabControl
{$ELSE}
  ,REST.Authenticator.OAuth.WebForm.FMX, FMX.TabControl
{$ENDIF}
;
type
  TConfigForm = class(TForm)
    TwitterGetRequestTokenButton: TButton;
    TwitterAuthButton: TButton;
    TwitterPINCode: TEdit;
    MainTabControl: TTabControl;
    TwitterTab: TTabItem;
    Label1: TLabel;
    TwitterAuthDeleteButton: TButton;
    procedure TwitterAuthButtonClick(Sender: TObject);
    procedure TwitterGetRequestTokenButtonClick(Sender: TObject);
    procedure TwitterAuthDeleteButtonClick(Sender: TObject);

    { twitter の認証状態を見てボタンのアクティブ状態を切り替える }
    procedure UpdateTwitterButtonGroup();
    procedure FormCreate(Sender: TObject);
  private
    { private 宣言 }

    procedure ExecGetTwitterRequestToken();
  public
    { public 宣言 }
  end;

var
  ConfigForm: TConfigForm;

implementation

{$R *.fmx}
{$R *.LgXhdpiTb.fmx ANDROID}
{$R *.Windows.fmx MSWINDOWS}

uses
  MainUnit;

procedure TConfigForm.UpdateTwitterButtonGroup();
var
  IsAuth: boolean;
begin
  IsAuth := False;
  if ((MainForm.ConfigManager.AccessToken<>'') and
    (MainForm.ConfigManager.AccessTokenSecret<>'')) then
  begin
    IsAuth := True;
  end;

  TwitterPINCode.Enabled := not IsAuth;
  self.TwitterAuthButton.Enabled := not IsAuth;
  self.TwitterGetRequestTokenButton.Enabled := not IsAuth;
  self.TwitterAuthDeleteButton.Enabled := IsAuth;
end;

procedure TConfigForm.TwitterGetRequestTokenButtonClick(Sender: TObject);
begin
  ExecGetTwitterRequestToken();
end;

procedure TConfigForm.FormCreate(Sender: TObject);
begin
  UpdateTwitterButtonGroup();
end;

procedure TConfigForm.TwitterAuthButtonClick(Sender: TObject);
var
  LToken: string;
begin
  with MainForm do
  begin

    /// grab the verifier from the edit-field
    OAuth1Authenticator.VerifierPIN := TwitterPINCode.Text;

    /// here, we want to change the request-token and the verifier into an access-token
    if (OAuth1Authenticator.RequestToken = '') or (OAuth1Authenticator.VerifierPIN = '') then
    begin
      FMX.Dialogs.ShowMessage('Request-token and verifier are both required.');
      EXIT;
    end;

    /// we want to request an access-token
    OAuth1Authenticator.AccessToken := '';
    OAuth1Authenticator.AccessTokenSecret := '';

    RESTClient.BaseURL := OAuth1Authenticator.AccessTokenEndpoint;
    RESTClient.Authenticator := OAuth1Authenticator;

    RESTRequest.Method := TRESTRequestMethod.rmPOST;
    RESTRequest.Params.AddItem('oauth_verifier', OAuth1Authenticator.VerifierPIN, TRESTRequestParameterKind.pkGETorPOST,
      [TRESTRequestParameterOption.poDoNotEncode]);

    RESTRequest.Execute;

    if RESTResponse.GetSimpleValue('oauth_token', LToken) then
    begin
      //OAuth1Authenticator.AccessToken := LToken;
      MainForm.ConfigManager.AccessToken := LToken;
    end;

    if RESTResponse.GetSimpleValue('oauth_token_secret', LToken) then
    begin
      //OAuth1Authenticator.AccessTokenSecret := LToken;
      MainForm.ConfigManager.AccessTokenSecret := LToken;
    end;

    MainForm.ConfigManager.Save();

    /// now we should remove the request-token
    OAuth1Authenticator.RequestToken := '';
    OAuth1Authenticator.RequestTokenSecret := '';
    OAuth1Authenticator.VerifierPin := '';

    //SendTwitter();
    UpdateTwitterButtonGroup();
  end;

end;



procedure TConfigForm.TwitterAuthDeleteButtonClick(Sender: TObject);
begin
  MainForm.ConfigManager.AccessToken := '';
  MainForm.ConfigManager.AccessTokenSecret := '';
  MainForm.ConfigManager.Save();
  UpdateTwitterButtonGroup();
end;

procedure TConfigForm.ExecGetTwitterRequestToken();
var
  LToken: string;
  wv: Tfrm_OAuthWebForm;
  LURL: string;
begin

  with MainForm do
  begin

    /// we need to transfer the data here manually
    OAuth1Authenticator.ConsumerKey := TAppDefine.TwitterConsumerKey;
    OAuth1Authenticator.ConsumerSecret := TAppDefine.TwitterConsumerSecretKey;

    OAuth1Authenticator.AccessToken       := '';
    OAuth1Authenticator.AccessTokenSecret := '';
    OAuth1Authenticator.RequestToken      := '';
    OAuth1Authenticator.RequestTokenSecret:= '';
    OAuth1Authenticator.VerifierPIN       := '';

    /// a client-id is required
    if (OAuth1Authenticator.ConsumerKey = '') then
    begin
      FMX.Dialogs.ShowMessage('A Consumer-ID ("client-id" or "app-id") is required.');
      EXIT;
    end;

    /// step #1, get request-token
    RESTClient.BaseURL := OAuth1Authenticator.RequestTokenEndpoint;
    RESTClient.Authenticator := OAuth1Authenticator;

    RESTRequest.Method := TRESTRequestMethod.rmPOST;

    RESTRequest.Execute;

    if RESTResponse.GetSimpleValue('oauth_token', LToken) then
      OAuth1Authenticator.RequestToken := LToken;
    if RESTResponse.GetSimpleValue('oauth_token_secret', LToken) then
      OAuth1Authenticator.RequestTokenSecret := LToken;

    /// step #2: get the auth-verifier (PIN must be entered by the user!)
    LURL := OAuth1Authenticator.AuthenticationEndpoint;
    LURL := LURL + '?oauth_token=' + OAuth1Authenticator.RequestToken;

    wv := Tfrm_OAuthWebForm.Create(self);
    try
      wv.ShowWithURL(LURL);
    finally
      //wv.Release;
    end;
  end;

end;


end.
