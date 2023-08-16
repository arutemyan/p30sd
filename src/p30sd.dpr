program p30sd;

uses
  System.StartUpCopy,
  FMX.Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  ConfigFormUnit in 'ConfigFormUnit.pas' {ConfigForm},
  AppDefine in 'AppDefine.pas',
  ConfigManager in 'ConfigManager.pas',
  ProgressFrameUnit in 'ProgressFrameUnit.pas' {ProgressFrame: TFrame};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TConfigForm, ConfigForm);
  Application.Run;
end.
