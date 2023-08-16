unit ProgressFrameUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Ani;

type
  TProgressFrame = class(TFrame)
    FrameCircle: TCircle;
    Background: TRectangle;
    FrameCircle2: TCircle;
    CircleArc: TArc;
    CircleAnimation: TFloatAnimation;
  private
    { private êÈåæ }
  public
    { public êÈåæ }
    procedure ShowActivity;
    procedure HideActivity;
  end;

implementation

{$R *.fmx}

procedure TProgressFrame.ShowActivity;
begin
  Self.Visible := True;
  self.CircleAnimation.Enabled := True;
end;

procedure TProgressFrame.HideActivity;
begin
  Self.CircleAnimation.Enabled := False;
  Self.Visible := False;
end;

end.
