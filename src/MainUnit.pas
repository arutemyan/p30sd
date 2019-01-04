unit MainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  Math, System.Generics.Collections, FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.ListView, System.ImageList, FMX.ImgList, FMX.Layouts, System.DateUtils,
  FMX.TextLayout, FMX.Gestures, FMX.MultiView, System.IOUtils, FMX.DialogService,
  FGX.ProgressDialog
{$IFDEF ANDROID32}
  ,System.Permissions,
  Androidapi.Helpers,
  Androidapi.JNI.App,
  Androidapi.JNI.OS
{$ENDIF}
;

type
  TMainForm = class(TForm)
    PaintImage: TImage;
    Next: TButton;
    Finish: TButton;
    ThumbnailListView: TListView;
    ImageList1: TImageList;
    Layout1: TLayout;
    TotalDrawTimeText: TText;
    CountTimer: TTimer;
    StartButton: TButton;
    GestureManager: TGestureManager;
    ThumbnailMultiView: TMultiView;
    Text1: TText;
    Text2: TText;
    DrawTimeText: TText;
    NextCountTextLabel: TText;
    NextCountText: TText;
    UsePenButton: TButton;
    UseEraserButton: TButton;
    ActivityDialog: TfgActivityDialog;

    procedure FormCreate(Sender: TObject);
    procedure PaintImageMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure PaintImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure NextClick(Sender: TObject);
    procedure FinishClick(Sender: TObject);
    procedure CountTimerTimer(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);


    procedure UsePenButtonClick(Sender: TObject);
    procedure UseEraserButtonClick(Sender: TObject);
    procedure PaintImageMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure PaintImageResized(Sender: TObject);
    procedure ActivityDialogHide(Sender: TObject);
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

    const ThumbSize = Integer(512);
    const ResultImageSize = Integer(4096);

    // 一枚に収まるサムネの数
    const ThumbnailMaxCountInImage = Integer(
      Trunc(ResultImageSize*ResultImageSize / (ThumbSize*ThumbSize))
    );

    // 一枚の画像の横か縦に入るイメージの数
    // 並べるときに使用する
    const ThumbnailResultImageItemMax =
      Integer(Trunc(ResultImageSize / ThumbSize));

    procedure ResetDrawingSetting();
    procedure OnNext();
    function SaveResultFromFile(): Boolean; // 次へ
    procedure ChangePen(IsPen: Boolean);
    procedure OnResize();
  public
    { public 宣言 }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.ActivityDialogHide(Sender: TObject);
begin
  SaveProcessingThread.Terminate;
end;

procedure TMainForm.ChangePen(IsPen: Boolean);
begin
  UsePenButton.Enabled := not IsPen;
  UseEraserButton.Enabled := IsPen;
end;

procedure TMainForm.CountTimerTimer(Sender: TObject);
var
  Sec: Int64;
  TotalSec: Int64;
begin
  Sec := System.DateUtils.MilliSecondsBetween(StartDrawTime, Now);
  DrawTimeText.Text := string.Format('%.2d:%.2d.%.3d',[
    Floor(Sec/60000),
    (Floor(Sec/1000) mod 60),
    Sec mod 1000]);
  TotalSec := System.DateUtils.MilliSecondsBetween(InitialDrawTime, Now);
  TotalDrawTimeText.Text := string.Format('%.2d:%.2d.%.3d',[
    Floor(TotalSec/60000),
    (Floor(TotalSec/1000) mod 60),
    TotalSec mod 1000]);
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
  ImageList1.ClearCache();
  ImageList1.Source.Clear;
  ImageList1.Destination.Clear;
  ThumbImages.Clear;
  ThumbnailListView.Items.Clear();
  NextCountText.Text := ThumbImages.Count.ToString;
  IsFirstStart := True;
  FPress := False;
  ChangePen(True);

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
    SetSize(ThumbSize,ThumbSize);
    if Canvas.BeginScene then
      try
        Canvas.DrawBitmap(PaintImage.Bitmap,
        TRectF.Create(0,0,PaintImage.Bitmap.Width, PaintImage.Bitmap.Height),
        TRectF.Create(0,0,ThumbSize,ThumbSize), 1, False);
      finally
        Canvas.EndScene;
      end;
  end;
  Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Bmp.Canvas.BeginScene;
    Layout.BeginUpdate;
    Layout.TopLeft := TPointF.Create(0, 0);
    Layout.MaxSize := TPointF.Create(ThumbSize,ThumbSize);
    Layout.Font.Size := 20;
    Layout.Color := TAlphaColorRec.Black;
    Layout.WordWrap := False;
    Layout.HorizontalAlign := TTextAlign.Leading;
    Layout.VerticalAlign := TTextAlign.Leading;
    Layout.Text := DrawTimeText.Text;
    Layout.EndUpdate;
    Layout.RenderLayout(Bmp.Canvas);
    Bmp.Canvas.EndScene;
  finally
    Layout.Free;
  end;
  ThumbImages.Add(Bmp);
  PaintImage.Bitmap.Clear(TAlphaColors.White);

  ListItem := ThumbnailListView.Items.Add();
  ListItem.Bitmap := Bmp;
  ListItem.Text := DrawTimeText.Text;
  ThumbnailListView.ItemIndex := ThumbnailListView.Items.Count-1;

  CountTimer.Enabled := false;

  NextCountText.Text := ThumbImages.Count.ToString();
  StartDrawTime := Now;

  ChangePen(True);
end;


function TMainForm.SaveResultFromFile(): Boolean;
var
  Bmp: TBitmap;
  I:   Integer;
  OldIdx: Integer;
  ImgCount: Integer;
  LineBrush: TStrokeBrush;
  SaveFunc: TProc;
  BaseFileName: string;
  DateTimeString: string;
  BaseDir: string;
begin
  SaveFunc := procedure
    var
      II: Integer;
    begin
      // 線を描画
      with Bmp.Canvas do
      begin
        BeginScene();
        try
          for II := 0 to ThumbnailResultImageItemMax-1 do
          begin
            DrawLine(
              TpointF.Create((II * ThumbSize), 0),
              TpointF.Create((II * ThumbSize), ResultImageSize),
              1,
              LineBrush);
            DrawLine(
              TpointF.Create(0, (II * ThumbSize)),
              TpointF.Create(ResultImageSize, (II * ThumbSize)),
              1,
              LineBrush);
          end;
        finally
          EndScene;
        end;
        Bmp.SaveToFile(
          BaseFileName + (OldIdx+1).ToString() + '.png');
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
  Bmp.SetSize(ResultImageSize,ResultImageSize);
  Bmp.Clear(TAlphaColorRec.White);
  for I := 0 to ThumbImages.Count-1 do
  begin
    if Trunc(I / ThumbnailMaxCountInImage) <> OldIdx then
    begin
      SaveFunc();
      Bmp.Clear(TAlphaColorRec.White);
      Inc(OldIdx);
      ImgCount := 0;
    end;
    Bmp.CopyFromBitmap(
      ThumbImages[I],
      TRect.Create(0,0,ThumbImages[I].Width,ThumbImages[I].Height),
      (ImgCount mod ThumbnailResultImageItemMax) * ThumbSize,
      (ImgCount div ThumbnailResultImageItemMax) * ThumbSize);
    Inc(ImgCount);
    if I = (ThumbImages.Count-1) then begin
       SaveFunc();
    end;
  end;
  Result := True;
end;

procedure TMainForm.FinishClick(Sender: TObject);
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
  if not ActivityDialog.IsShown then
  begin
    SaveProcessingThread := TThread.CreateAnonymousThread(procedure
      begin
        try
          TThread.Synchronize(nil, procedure
            begin
              ActivityDialog.Show;
            end);

          // ダイアログを出したいので、表示されるためだけのsleep
          // てきとー。
          Sleep(100);

          TThread.Synchronize(nil, procedure
            begin
              if SaveResultFromFile() = False then begin
                ActivityDialog.Hide;
                FMX.Dialogs.ShowMessage('保存に失敗しました');
                Exit;
              end;
              ResetDrawingSetting();
              ActivityDialog.Hide;
            end);
        finally
          if not TThread.CheckTerminated then
            TThread.Synchronize(nil, procedure
              begin
                ActivityDialog.Hide;
              end);
        end;
      end);
    SaveProcessingThread.FreeOnTerminate := False;
    SaveProcessingThread.Start;
  end;
{$IFDEF WIN32 or WIN64}
  if (SaveProcessingThread <> nil)
    and (not SaveProcessingThread.Finished) then
  begin
    SaveProcessingThread.WaitFor;
  end;
{$ENDIF}
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
{$IFDEF ANDROID32}
  PermissionsService.RequestPermissions(
    [
      JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE),
      JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE)],
    procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
    begin
      if (Length(AGrantResults) >= 1) and (AGrantResults[0] = TPermissionStatus.Granted) then
        begin
        end
      else
        begin
          FMX.Dialogs.ShowMessage('このアプリの動作にはストレージの権限が必要です');
        end;
    end);
{$ENDIF}
  PaintImage.Bitmap := TBitmap.Create();
  OnResize();

  ResetDrawingSetting();
end;

procedure TMainForm.PaintImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  if not ((ssLeft in Shift) or (ssTouch in Shift)) then begin
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

procedure TMainForm.PaintImageMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
var
  ImageCanvas: TCanvas;
  Point: TPointF;
begin
  if not ((ssLeft in Shift) or (ssTouch in Shift)) then begin
    Exit;
  end;

  if FPress = False then
  begin
    // ここを通るってことはDownが正しくとれてない。悲しい。
    FPress := True;
    FDownPos := Point;
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
        Point := TPointF.Create(X,Y);
        DrawLine(FDownPos, Point, 1.0);
      end else begin
        Stroke.Thickness := 10;
        Stroke.Color := TAlphaColors.White;
        Stroke.Kind := TBrushKind.Solid;
        Point := TPointF.Create(X,Y);
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
begin
  if Layout1.Width > Layout1.Height then begin
    PaintImage.Width := Layout1.Height;
    PaintImage.Height := Layout1.Height;
    PaintImage.Bitmap.SetSize(Floor(PaintImage.Height),Floor(PaintImage.Height));
  end else begin
    PaintImage.Width := Layout1.Width;
    PaintImage.Height := Layout1.Width;
    PaintImage.Bitmap.SetSize(Floor(PaintImage.Width),Floor(PaintImage.Width));
  end;
  PaintImage.Bitmap.Clear(TAlphaColorRec.White);
end;

procedure TMainForm.PaintImageResized(Sender: TObject);
begin
  OnResize;
end;

procedure TMainForm.NextClick(Sender: TObject);
begin
  OnNext();
end;



procedure TMainForm.StartButtonClick(Sender: TObject);
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
