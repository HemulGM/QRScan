unit QRS.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Ani, FMX.Layouts, FMX.Objects, FMX.Controls.Presentation, FMX.Media,
  FMX.TabControl, FMX.Platform, FMX.ListBox, QRS.Scanner, Skia, Skia.FMX,
  FMX.Effects;

type
  TFormMain = class(TForm)
    RectangleFrame: TRectangle;
    AniIndicatorCamera: TAniIndicator;
    CameraComponent: TCameraComponent;
    RectangleLT: TRectangle;
    RectangleRT: TRectangle;
    RectangleLB: TRectangle;
    RectangleRB: TRectangle;
    TabControlMain: TTabControl;
    TabItemScan: TTabItem;
    TabItemHistory: TTabItem;
    TabItemOther: TTabItem;
    ListBoxHistory: TListBox;
    LayoutHead: TLayout;
    Label3: TLabel;
    Circle1: TCircle;
    Label4: TLabel;
    ButtonBack: TButton;
    Path2: TPath;
    StyleBook: TStyleBook;
    RectangleBG: TRectangle;
    Layout1: TLayout;
    Layout2: TLayout;
    Layout3: TLayout;
    Layout4: TLayout;
    ButtonHistory: TButton;
    ButtonOther: TButton;
    ButtonScan: TButton;
    Path3: TPath;
    Path1: TPath;
    Path4: TPath;
    procedure FormCreate(Sender: TObject);
    procedure CameraComponentSampleBufferReady(Sender: TObject; const ATime: TMediaTime);
    procedure TabControlMainChange(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RectangleFramePaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure ButtonBackClick(Sender: TObject);
    procedure ButtonScanClick(Sender: TObject);
    procedure ButtonHistoryClick(Sender: TObject);
    procedure ButtonOtherClick(Sender: TObject);
  private
    FQRScan: TQRScan;
    procedure StartScan;
    procedure OpenTab(Tab: TTabItem; Reverse: Boolean = False);
    function CropBitmap(const ABitmap: TBitmap): TBitmap;
    function ScanFrames(const Bitmap: TBitmap): Boolean;
    function AppEventHandler(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure StopScan;
    procedure FOnScanResult(Sender: TObject);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

uses
  {$IFDEF ANDROID or IOS}
  Androidapi.NativeWindow, FMX.Presentation.Android.Style,
  Androidapi.NativeWindowJni, Androidapi.JNIBridge, System.Permissions,
  Androidapi.Helpers, Androidapi.JNI.Os, Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.JavaTypes, Androidapi.JNI.Webkit, Androidapi.JNI.Net,
  Androidapi.JNI.App, Androidapi.JNI.Support, FMX.Platform.Android,
  Androidapi.JNI.Media,
  {$ENDIF}
  System.DateUtils, System.Math, System.IOUtils;

{$R *.fmx}

function TFormMain.CropBitmap(const ABitmap: TBitmap): TBitmap;
var
  LCropW, LCropH, LCropMargin: Integer;
begin
  LCropMargin := Round(Abs(ABitmap.Width - ABitmap.Height) / 2);
  LCropW := LCropMargin;
  LCropH := 0;
  if ABitmap.Width < ABitmap.Height then
  begin
    LCropW := 0;
    LCropH := LCropMargin;
  end;

  Result := TBitmap.Create(ABitmap.Width - (2 * LCropW), ABitmap.Height - (2 * LCropH));
  Result.CopyFromBitmap(ABitmap, Rect(LCropW, LCropH, ABitmap.Width - LCropW, ABitmap.Height - LCropH), 0, 0);
end;

function TFormMain.ScanFrames(const Bitmap: TBitmap): Boolean;
begin
  Result := False;
  if FQRScan.IsBusy then
    Exit;
  Result := True;
  FQRScan.Scan(Bitmap);
end;

procedure TFormMain.ButtonBackClick(Sender: TObject);
begin
  OpenTab(TabItemScan, True);
end;

procedure TFormMain.ButtonHistoryClick(Sender: TObject);
begin
  OpenTab(TabItemHistory);
end;

procedure TFormMain.ButtonOtherClick(Sender: TObject);
begin
  OpenTab(TabItemOther);
end;

procedure TFormMain.ButtonScanClick(Sender: TObject);
begin
  StartScan;
end;

procedure TFormMain.CameraComponentSampleBufferReady(Sender: TObject; const ATime: TMediaTime);
var
  LBuffer, LReducedBuffer: TBitmap;
begin
  LBuffer := TBitmap.Create;
  try
    CameraComponent.SampleBufferToBitmap(LBuffer, True);
    RectangleBG.Fill.Bitmap.Bitmap.Assign(LBuffer);
    AniIndicatorCamera.Visible := False;
    LReducedBuffer := CropBitmap(LBuffer);
    RectangleFrame.Fill.Kind := TBrushKind.Bitmap;
    RectangleFrame.Fill.Bitmap.WrapMode := TWrapMode.TileStretch;
    RectangleFrame.Fill.Bitmap.Bitmap.Assign(LReducedBuffer);
    if not ScanFrames(LReducedBuffer) then
      LReducedBuffer.Free;
  finally
    LBuffer.Free;
  end;
end;

function TFormMain.AppEventHandler(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
begin
  Result := False;

  if AAppEvent in [
    TApplicationEvent.WillBecomeInactive,
    TApplicationEvent.EnteredBackground,
    TApplicationEvent.WillTerminate
    ] then
    StopScan;
end;

procedure TFormMain.StopScan;
begin
  CameraComponent.Active := False;
  RectangleFrame.Fill.Kind := TBrushKind.Solid;
  AniIndicatorCamera.Visible := False;
end;

procedure TFormMain.TabControlMainChange(Sender: TObject);
begin
  ButtonBack.Visible := TabControlMain.ActiveTab <> TabItemScan;

  if TabControlMain.ActiveTab <> TabItemScan then
    StopScan
  else
    StartScan;
end;

procedure TFormMain.FOnScanResult(Sender: TObject);
begin
  if FQRScan.LastResult.IsEmpty then
    Exit;
  if not CameraComponent.Active then
    Exit;
  ShowMessage(FQRScan.LastResult);
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  var LAppEventService: IFMXApplicationEventService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, LAppEventService) then
    LAppEventService.SetApplicationEventHandler(AppEventHandler);

  ListBoxHistory.Clear;
  FQRScan := TQRScan.Create;
  FQRScan.OnResult := FOnScanResult;
  TAnimation.AniFrameRate := 300;

  ListBoxHistory.AniCalculations.Animation := True;
  ListBoxHistory.AniCalculations.Interval := 1;
  ListBoxHistory.AniCalculations.Averaging := True;
  ListBoxHistory.AniCalculations.BoundsAnimation := True;
  TabControlMainChange(nil);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  CameraComponent.OnSampleBufferReady := nil;
  StopScan;
  FQRScan.Free;
end;

procedure TFormMain.OpenTab(Tab: TTabItem; Reverse: Boolean);
begin
  if not Reverse then
    TabControlMain.SetActiveTabWithTransitionAsync(Tab, TTabTransition.Slide, TTabTransitionDirection.Normal, nil)
  else
    TabControlMain.SetActiveTabWithTransitionAsync(Tab, TTabTransition.Slide, TTabTransitionDirection.Reversed, nil);
  //TabControlMain.ActiveTab := Tab;
end;

procedure TFormMain.RectangleFramePaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
const
  ASize = 6;
begin
  Canvas.BeginScene;
  try
    var List := FQRScan.Points.LockList;
    try
      for var Item in List do
      begin
        var R: TRectF;
        R.Left := (Item.X - (ASize / 2)) * (RectangleFrame.Width / RectangleFrame.Fill.Bitmap.Bitmap.Width);
        R.Top := (Item.Y - (ASize / 2)) * (RectangleFrame.Height / RectangleFrame.Fill.Bitmap.Bitmap.Height);
        R.Width := ASize;
        R.Height := ASize;
        Canvas.Fill.Color := TAlphaColors.White;
        Canvas.FillEllipse(R, 1);
      end;
    finally
      FQRScan.Points.UnlockList;
    end;
  finally
    Canvas.EndScene;
  end;
end;

procedure TFormMain.StartScan;
begin
  AniIndicatorCamera.Visible := True;
  {$IFDEF ANDROID}
  var PermCamera := JStringToString(TJManifest_permission.JavaClass.CAMERA);
  if not PermissionsService.IsPermissionGranted(PermCamera) then
    PermissionsService.RequestPermissions(
      [PermCamera],
      procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
      begin
        if (Length(AGrantResults) > 0) and (AGrantResults[0] = TPermissionStatus.Granted) then
        begin
          CameraComponent.FocusMode := TFocusMode.ContinuousAutoFocus;
          CameraComponent.CaptureSettingPriority := TVideoCaptureSettingPriority.FrameRate;
          CameraComponent.Active := True;
          OpenTab(TabItemScan, True);
        end;
      end)
  else
  begin
    CameraComponent.FocusMode := TFocusMode.ContinuousAutoFocus;
    CameraComponent.CaptureSettingPriority := TVideoCaptureSettingPriority.FrameRate;
    CameraComponent.Active := True;
    OpenTab(TabItemScan, True);
  end;
  {$ELSE}
  CameraComponent.FocusMode := TFocusMode.ContinuousAutoFocus;
  CameraComponent.CaptureSettingPriority := TVideoCaptureSettingPriority.FrameRate;
  CameraComponent.Active := True;
  OpenTab(TabItemScan, True);
  {$ENDIF}
end;

end.

