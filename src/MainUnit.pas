﻿unit MainUnit;
interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  Math, System.Generics.Collections, FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.ListView, System.ImageList, FMX.ImgList, FMX.Layouts, System.DateUtils,
  FMX.TextLayout, FMX.Gestures, FMX.MultiView, System.IOUtils, FMX.DialogService,
  FMX.Edit, FMX.EditBox, FMX.ComboTrackBar, FMX.ComboEdit,
  FMX.ListBox, FMX.WebBrowser, Data.Bind.Components, Data.Bind.ObjectScope,
  REST.Client, REST.Authenticator.OAuth, System.NetEncoding,
  REST.Utils,REST.Types,REST.Response.Adapter,REST.Authenticator.Simple,
  REST.Authenticator.Basic,AppDefine, ConfigManager,
  Data.Bind.EngExt, ProgressFrameUnit,
  IPPeerClient
{$IFDEF ANDROID32}
  ,System.Permissions,
  Androidapi.Helpers,
  Androidapi.JNI.App,
  Androidapi.JNI.OS
{$ENDIF}
  {$IFDEF MSWINDOWS}
  ,REST.Authenticator.OAuth.WebForm.Win
  {$ELSE}
  ,REST.Authenticator.OAuth.WebForm.FMX
  {$ENDIF}
;
type
  TMainForm = class(TForm)
    PaintImage: TImage;
    ThumbnailListView: TListView;
    ThumbImageList: TImageList;
    BaseLayout: TLayout;
    TotalDrawTimeText: TText;
    CountTimer: TTimer;
    GestureManager: TGestureManager;
    ThumbnailMultiView: TMultiView;
    Text1: TText;
    Text2: TText;
    DrawTimeText: TText;
    NextCountTextLabel: TText;
    NextCountText: TText;
    UseEraserButton: TSpeedButton;
    UseEraserButtonImage: TImage;
    UsePenButton: TSpeedButton;
    UsePenButtonImage: TImage;
    Next: TSpeedButton;
    NextImage: TImage;
    ResetButton: TSpeedButton;
    ResetImage: TImage;
    FinishButton: TSpeedButton;
    FinishButtonImage: TImage;
    IconImageList: TImageList;
    StartSettingPanel: TPanel;
    StartButton: TButton;
    InitInfoText: TText;
    NormSelectBox: TComboBox;
    OpenConfigButton: TButton;
    ProgressFrame: TProgressFrame;
    procedure FormCreate(Sender: TObject);
    procedure PaintImageMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure PaintImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure NextClick(Sender: TObject);
    procedure FinishButtonClick(Sender: TObject);
    procedure CountTimerTimer(Sender: TObject);
    procedure ResetButtonClick(Sender: TObject);

    procedure UsePenButtonClick(Sender: TObject);
    procedure UseEraserButtonClick(Sender: TObject);
    procedure PaintImageMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure PaintImageResized(Sender: TObject);
    procedure ActivityDialogHide(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
    procedure OpenConfigButtonClick(Sender: TObject);

  private
    { private 宣言 }
    FDownPos: TPointF;
    FPress: Boolean; // Android や端末だとDownをうまく拾ってくれないので。
    ThumbImages: TList<TBitmap>;
    StartDrawTime: TDateTime;
    InitialDrawTime: TDateTime;
    SaveProcessingThread: TThread;
    // 一番最初のときはtrue. 次にMouseDownよばれたらFalse
    IsFirstStart: Boolean;
    const ThumbPixelSize = Integer(512);
    // 一枚の画像の横か縦に入るイメージの数
    // 並べるときに使用する
    const ThumbnailResulImgLineItemMax = Integer(8);
    procedure ResetDrawingSetting();
    procedure OnNext();
    function SaveResultFromFile(): Boolean; // 次へ
    procedure ChangePen(IsPen: Boolean);
    procedure OnResize();
    function GetNormCount(): Integer;
    procedure OnMouseDown(State: TShiftState; X, Y: Single);
    procedure OnFinish();
    procedure UpdatePictureWriteCount();// 描いた枚数を更新
  public
    { public 宣言 }
    ConfigManager: TConfigManager;
  end;
var
  MainForm: TMainForm;
implementation
{$R *.fmx}
uses ConfigFormUnit;

function TMainForm.GetNormCount(): Integer;
begin
  Result := Integer.Parse(NormSelectBox.Selected.Text);
end;
procedure TMainForm.ActivityDialogHide(Sender: TObject);
begin
  SaveProcessingThread.Terminate;
end;
procedure TMainForm.ChangePen(IsPen: Boolean);
var
  Old: Boolean;
begin
  Old := UsePenButton.Enabled;
  UsePenButton.Enabled := not IsPen;
  UseEraserButton.Enabled := IsPen;
  if Old <> UsePenButton.Enabled then
  begin
    if IsPen = True then begin
      UsePenButtonImage.Bitmap := IconImageList.Bitmap(TSizeF.Create(128,128), 1);
      UseEraserButtonImage.Bitmap := IconImageList.Bitmap(TSizeF.Create(128,128), 2);
    end else begin
      UsePenButtonImage.Bitmap := IconImageList.Bitmap(TSizeF.Create(128,128), 0);
      UseEraserButtonImage.Bitmap := IconImageList.Bitmap(TSizeF.Create(128,128), 3);
    end;
  end;
end;
procedure TMainForm.CountTimerTimer(Sender: TObject);
var
  Sec: Int64;
  TotalSec: Int64;
begin
  Sec := System.DateUtils.MilliSecondsBetween(StartDrawTime, Now);
  DrawTimeText.Text := string.Format(
    '%.2d:%.2d.%.3d',
    [
      Floor(Sec/60000),
      (Floor(Sec/1000) mod 60),
      Sec mod 1000
    ]
  );
  TotalSec := System.DateUtils.MilliSecondsBetween(InitialDrawTime, Now);
  TotalDrawTimeText.Text := string.Format(
    '%.2d:%.2d.%.3d',
    [
      Floor(TotalSec/60000),
      (Floor(TotalSec/1000) mod 60),
      TotalSec mod 1000
    ]
  );
end;
procedure TMainForm.ResetDrawingSetting();
begin
  if ThumbImages = nil then
  begin
    ThumbImages := TList<TBitmap>.Create();
  end else begin
    ThumbImages.Clear();
  end;
  PaintImage.Bitmap.Clear(TAlphaColors.White);
  PaintImage.AutoCapture := True;
  PaintImage.CanFocus := True;
  CountTimer.Enabled := false;
  self.DrawTimeText.Text := '00:00.000';
  self.TotalDrawTimeText.Text := '00:00.000';
  self.NextCountText.Text := '0';
  StartDrawTime := Now;
  InitialDrawTime := Now;// 初期化のためだけにしている(MouseDownで更新される)
  ThumbImageList.ClearCache();
  ThumbImageList.Source.Clear;
  ThumbImageList.Destination.Clear;
  ThumbImages.Clear;
  ThumbnailListView.Items.Clear();
  UpdatePictureWriteCount();
  IsFirstStart := True;
  FPress := False;
  StartSettingPanel.Enabled := True;
  StartSettingPanel.Visible := True;
  ChangePen(True);
  InitInfoText.Text := 'コンボボックスの値が-1以外の場合その枚数に到達した時点で自動的に保存されます。';

end;
procedure TMainForm.UpdatePictureWriteCount();
begin
  if GetNormCount() > 0 then
  begin
    NextCountText.Text := ThumbImages.Count.ToString()
    + ' / '
    + NormSelectBox.Selected.Text;
  end else begin
    NextCountText.Text := ThumbImages.Count.ToString();
  end;
end;
procedure TMainForm.OnNext();
var
  Bmp: TBitmap;
  ListItem: TListViewItem;
  Layout: TTextLayout;
begin
  Bmp := TBitmap.Create();
{$IFNDEF ANDROID32}
  // AndroidだとTrueの場合しんでしまう。
  Bmp.Canvas.Blending := True;
{$ENDIF}
  with Bmp do
  begin;
    SetSize(ThumbPixelSize,ThumbPixelSize);
    if Canvas.BeginScene then
      try
        Canvas.DrawBitmap(PaintImage.Bitmap,
          TRectF.Create(0,0,PaintImage.Bitmap.Width, PaintImage.Bitmap.Height),
          TRectF.Create(0,0,ThumbPixelSize,ThumbPixelSize), 1, False);
      finally
        Canvas.EndScene;
      end;
  end;
  Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Bmp.Canvas.BeginScene;
    Layout.BeginUpdate;
    Layout.TopLeft := TPointF.Create(0, 0);
    Layout.MaxSize := TPointF.Create(ThumbPixelSize,ThumbPixelSize);
    Layout.Font.Size := 20;
    Layout.Color := TAlphaColorRec.Black;
    Layout.WordWrap := False;
    Layout.HorizontalAlign := TTextAlign.Leading;
    Layout.VerticalAlign := TTextAlign.Leading;
    Layout.Text := DrawTimeText.Text;
    Layout.EndUpdate;
    Layout.RenderLayout(Bmp.Canvas);
  finally
    Bmp.Canvas.EndScene;
    Layout.Free;
  end;
  ThumbImages.Add(Bmp);
  PaintImage.Bitmap.Clear(TAlphaColors.White);
  ListItem := ThumbnailListView.Items.Add();
  ListItem.Bitmap := Bmp;
  ListItem.Text := DrawTimeText.Text;
  ThumbnailListView.ItemIndex := ThumbnailListView.Items.Count-1;
  CountTimer.Enabled := false;
  UpdatePictureWriteCount();
  StartDrawTime := Now;
  // ノルマが設定されている場合は迎えた時点で自動終了
  if (GetNormCount() > 0) and (ThumbImages.Count = GetNormCount()) then
  begin
    OnFinish();
    Exit;
  end;
  ChangePen(True);
end;

function TMainForm.SaveResultFromFile(): Boolean;
var
  Bmp: TBitmap;
  I: Integer;
  OldIdx: Integer;
  ImgCount: Integer;
  LineBrush: TStrokeBrush;
  SaveFunc: TProc;
  BaseFileName: string;
  DateTimeString: string;
  BaseDir: string;
  RealThumbImgLineItemMax: Integer; // 横＆縦のイメージの数。16枚なら4*4で4が入る。
  RealThumbImageItemTotal: Integer;// 横＆縦のイメージの数。16枚なら16が入る。
  ResultImageLinePixelSize: Integer;
  ImageLineFloat: Extended;
begin
  const FooterOneLineSize = 20;
  ImageLineFloat := Sqrt(Extended(ThumbImages.Count));
  RealThumbImgLineItemMax := Trunc(ImageLineFloat);
   If Frac(ImageLineFloat) <> 0 Then
   begin
     //切り上げ対応
     RealThumbImgLineItemMax := RealThumbImgLineItemMax + 1;
   end;
  if (RealThumbImgLineItemMax > ThumbnailResulImgLineItemMax) then
      RealThumbImgLineItemMax := ThumbnailResulImgLineItemMax;
  // 一枚にぶちこむイメージの数。
  // ThumbnailResulImgLineItemMax^2を超えることはない。
  RealThumbImageItemTotal := RealThumbImgLineItemMax*RealThumbImgLineItemMax;
  // キャンバスサイズ（横＆縦）
  ResultImageLinePixelSize := RealThumbImgLineItemMax * ThumbPixelSize;
  SaveFunc := procedure()
    var
      II: Integer;
      SaveFileName: string;
    begin
      // 線を描画
      with Bmp.Canvas do
      begin
        BeginScene();
        try

          // ヘッダ情報を書き込む
          var RecF := TRectF.Create(
            0,
            ResultImageLinePixelSize,
            ResultImageLinePixelSize,
            ResultImageLinePixelSize + FooterOneLineSize
          );

          Bmp.Canvas.FillRect(RecF, 1, LineBrush);

          var TotalSec := System.DateUtils.MilliSecondsBetween(InitialDrawTime, Now);
          FillText(RecF, string.Format('%s (%.2dmin %.2dsec) %d', [
            Now.ToString(),
            Floor(TotalSec/60000),
            (Floor(TotalSec/1000) mod 60),
            I
          ] ), False, 1, [], TTextAlign.Leading, TTextAlign.Leading);


          for II := 0 to RealThumbImgLineItemMax-1 do
          begin
            DrawLine(
              TpointF.Create((II * ThumbPixelSize), 0),
              TpointF.Create((II * ThumbPixelSize), ResultImageLinePixelSize),
              1,
              LineBrush);
            DrawLine(
              TpointF.Create(0, (II * ThumbPixelSize)),
              TpointF.Create(ResultImageLinePixelSize, (II * ThumbPixelSize)),
              1,
              LineBrush);
          end;
        finally
          EndScene;
        end;
        SaveFileName:= BaseFileName + (OldIdx+1).ToString() + '.png';
        Bmp.SaveToFile(SaveFileName);
      end;
    end;
  if ThumbImages.Count = 0 then begin
    Result := True; // 保存するものがないときも成功でいいでしょう
    Exit();
  end;
  BaseDir := '';
{$IFDEF ANDROID32}
  BaseDir := System.IOUtils.TPath.GetSharedPicturesPath() + '/';
{$ENDIF}
  TDirectory.CreateDirectory(BaseDir + 'result');
  DateTimeToString(DateTimeString, 'yyyyMMdd_HHmmss_', Now);
  BaseFileName := BaseDir + 'result/' + DateTimeString;
  LineBrush := TStrokeBrush.Create(TBrushKind.Solid, TAlphaColors.Black);
  OldIdx := 0;
  ImgCount := 0;
  Bmp := TBitmap.Create();
  Bmp.SetSize(ResultImageLinePixelSize,ResultImageLinePixelSize + FooterOneLineSize);

  Bmp.Clear(TAlphaColorRec.White);

  for I := 0 to ThumbImages.Count-1 do
  begin
    if Trunc(I / RealThumbImageItemTotal) <> OldIdx then
    begin
      SaveFunc();
      Bmp.Clear(TAlphaColorRec.White);
      Inc(OldIdx);
      ImgCount := 0;
    end;
    Bmp.CopyFromBitmap(
      ThumbImages[I],
      TRect.Create(0,0,ThumbImages[I].Width,ThumbImages[I].Height),
      (ImgCount mod RealThumbImgLineItemMax) * ThumbPixelSize,
      (ImgCount div RealThumbImgLineItemMax) * ThumbPixelSize);
    Inc(ImgCount);
    if I = (ThumbImages.Count-1) then begin
       SaveFunc();
    end;
  end;
  Result := True;
end;
procedure TMainForm.StartButtonClick(Sender: TObject);
begin
  //Panelを非表示にしたら開始とする
  StartSettingPanel.Enabled := False;
  StartSettingPanel.Visible := False;
  UpdatePictureWriteCount();
end;

procedure TMainForm.OnFinish();
begin
  // timerが動いていたら何かしら描いてると思う
  if CountTimer.Enabled = True then
  begin
    OnNext();
  end;
  if ThumbImages.Count = 0 then begin
    FMX.Dialogs.ShowMessage('まだ開始していないか0枚です');
    Exit;
  end;
  if not ProgressFrame.Visible then
  begin
    SaveProcessingThread := TThread.CreateAnonymousThread(procedure
      begin
        try
          TThread.Synchronize(nil, procedure
            begin
              ProgressFrame.ShowActivity;
            end);
          // ダイアログを出したいので、表示されるためだけのsleep
          // てきとー。
          sleep(100);
          //TThread.Synchronize(nil, procedure
          //  begin
              if SaveResultFromFile() = False then begin
                ProgressFrame.HideActivity;
                FMX.Dialogs.ShowMessage('保存に失敗しました');
                Exit;
              end;
              ResetDrawingSetting();
              ProgressFrame.HideActivity;
          //  end);
        finally
          if not TThread.CheckTerminated then
            TThread.Synchronize(nil, procedure
              begin
                ProgressFrame.HideActivity;
              end);
        end;
      end);
    ProgressFrame.ShowActivity;

    SaveProcessingThread.FreeOnTerminate := False;
    SaveProcessingThread.Start;
  end;

//{$IFDEF WIN32 or WIN64}
//  if (SaveProcessingThread <> nil)
//    and (not SaveProcessingThread.Finished) then
//  begin
//    SaveProcessingThread.WaitFor;
//  end;
//{$ENDIF}
  //ProgressFrame.HideActivity;
end;
procedure TMainForm.FinishButtonClick(Sender: TObject);
begin
  OnFinish();
end;
procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  ModalResult: Boolean;
begin
  TDialogService.MessageDialog(
    '終了してもよろしいですか？',
    TMsgDlgType.mtConfirmation,
    mbYesNo, TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
      begin
        if (AResult = mrYes) then
        begin
          ModalResult := true;
          // はいのときは保存処理をよんでおくか
          // timerが動いていたら何かしら描いてると思う
          if CountTimer.Enabled = True then
          begin
            OnNext();
          end;
          SaveResultFromFile();
        end else begin
          ModalResult := false;
        end;
      end);
  CanClose := ModalResult;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ConfigManager := TConfigManager.Create();
  ConfigManager.Load();
  // Twitter API仕様変更に伴いTokenを消しとく
  ConfigManager.AccessToken := '';
  ConfigManager.AccessTokenSecret := '';
  ProgressFrame.HideActivity;
{$IFDEF ANDROID32}
  PermissionsService.RequestPermissions(
    [
      JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE),
      JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE)
    ],
    procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
    begin
      if (Length(AGrantResults) >= 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
        begin
        end
      else
        begin
          FMX.Dialogs.ShowMessage('このアプリの動作にはストレージ権限が必要です');
        end;
    end);
{$ENDIF}
  PaintImage.Bitmap := TBitmap.Create();
  OnResize();
  ResetDrawingSetting();
end;
procedure TMainForm.OnMouseDown(State: TShiftState; X, Y: Single);
begin
  if StartSettingPanel.Enabled = True then
  begin
    // まだ開始してない
    Exit;
  end;
  if not ((ssLeft in State) or (ssTouch in State)) then begin
    Exit;
  end;
  FDownPos := TPointF.Create(X,Y);
  FPress := True;
  if CountTimer.Enabled = false then
  begin
    // TotalTimeの帳尻をあわせる・・・。
    InitialDrawTime := self.InitialDrawTime + (Now - StartDrawTime);
    StartDrawTime := Now;
    CountTimer.Enabled := true;
  end;
  if IsFirstStart = True then
  begin
    InitialDrawTime := Now;
    IsFirstStart := False;
  end;
end;
procedure TMainForm.PaintImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  OnMouseDown(Shift, X, Y);
end;
procedure TMainForm.PaintImageMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
var
  ImageCanvas: TCanvas;
  Point: TPointF;
begin
  if not ((ssLeft in Shift) or (ssTouch in Shift)) then
  begin
    Exit;
  end;
  Point := TPointF.Create(X,Y);
  if FPress = False then
  begin
    // ここを通るってことはDownが正しくとれてない。悲しい。
    OnMouseDown(Shift, X, Y);
    Exit;
  end;
  ImageCanvas := PaintImage.Bitmap.Canvas;
  with PaintImage.Bitmap.Canvas do
  begin
    ImageCanvas.BeginScene;
    try
      // EnabledがFalseのときに有効なので注意
      // どうかとおもうがこれで。
      if UsePenButton.Enabled = False then
      begin
        Stroke.Thickness := 1;
        Stroke.Color := TAlphaColors.Black;
        Stroke.Kind := TBrushKind.Solid;
        DrawLine(FDownPos, Point, 1.0);
      end else begin
        Stroke.Thickness := 10;
        Stroke.Color := TAlphaColors.White;
        Stroke.Kind := TBrushKind.Solid;
        DrawLine(FDownPos, Point, 1.0);
      end;
    finally
      ImageCanvas.EndScene;
    end;
    FDownPos := Point;
  end;
end;

procedure TMainForm.PaintImageMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FPress := False;
end;
procedure TMainForm.OnResize();
var
  BufferTmp: TBitmap;
  OffsetX, OffsetY, CopyWidth, CopyHeight: Integer;
begin
  BufferTmp := TBitmap.Create(
    Trunc(PaintImage.Bitmap.Width),
    Trunc(PaintImage.Bitmap.Height));
  BufferTmp.CopyFromBitmap(
    PaintImage.Bitmap);
  if BaseLayout.Width > BaseLayout.Height then
  begin
    PaintImage.Width := BaseLayout.Height;
    PaintImage.Height := BaseLayout.Height;
    PaintImage.Bitmap.SetSize(Floor(PaintImage.Height),Floor(PaintImage.Height));
  end else begin
    PaintImage.Width := BaseLayout.Width;
    PaintImage.Height := BaseLayout.Width;
    PaintImage.Bitmap.SetSize(Floor(PaintImage.Width),Floor(PaintImage.Width));
  end;
  OffsetX := Trunc((PaintImage.Width - BufferTmp.Width) / 2);
  if OffsetX < 0 then
    OffsetX := 0;
  OffsetY := Trunc((PaintImage.Height - BufferTmp.Height) / 2);
  if OffsetY < 0 then
    OffsetY := 0;
  CopyWidth := BufferTmp.Width;
  if CopyWidth > PaintImage.Width then
    CopyWidth := Trunc(PaintImage.Width);
  CopyHeight := BufferTmp.Height;
  if CopyHeight > PaintImage.Height then
    CopyHeight := Trunc(PaintImage.Height);
  PaintImage.Bitmap.Clear(TAlphaColorRec.White);
  PaintImage.Bitmap.CopyFromBitmap(
    BufferTmp,
    TRect.Create(0,0,CopyWidth,CopyHeight),
    OffsetX, OffsetY);
  BufferTmp.Free;
end;
procedure TMainForm.OpenConfigButtonClick(Sender: TObject);
begin
  ConfigForm.Show;
end;
procedure TMainForm.PaintImageResized(Sender: TObject);
begin
  OnResize;
end;
procedure TMainForm.NextClick(Sender: TObject);
begin
  OnNext();
end;

procedure TMainForm.ResetButtonClick(Sender: TObject);
begin
  TDialogService.MessageDialog(
    'いままでの途中経過は破棄されますがよろしいですか？',
    TMsgDlgType.mtConfirmation,
    mbYesNo, TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
        if (AResult = mrYes) then
        begin
          ResetDrawingSetting();
        end;
    end);
end;
procedure TMainForm.UseEraserButtonClick(Sender: TObject);
begin
  ChangePen(False);
end;
procedure TMainForm.UsePenButtonClick(Sender: TObject);
begin
  ChangePen(True);
end;


end.
