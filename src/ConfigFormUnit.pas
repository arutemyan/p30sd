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
    MainTabControl: TTabControl;
    ConfigTab: TTabItem;
    Panel1: TPanel;
  private
    { private 宣言 }
  public
    { public 宣言 }
  end;

var
  ConfigForm: TConfigForm;

implementation

{$R *.fmx}
{$R *.Windows.fmx MSWINDOWS}
{$R *.Surface.fmx MSWINDOWS}

uses
  MainUnit;

end.
