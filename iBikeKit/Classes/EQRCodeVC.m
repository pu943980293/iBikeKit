//
//  EQRCodeVC.m
//  i-ebike
//
//  Created by LPC on 2017/8/15.
//  Copyright © 2017年 audi. All rights reserved.
//

#import "EQRCodeVC.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
/**
 *  UIScreen width.
 */
#define  Width   [UIScreen mainScreen].bounds.size.width

/**
 *  UIScreen height.
 */
#define  Height  [UIScreen mainScreen].bounds.size.height
@interface EQRCodeVC()
<
    AVCaptureMetadataOutputObjectsDelegate,
    CAAnimationDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
>
{
    UIStatusBarStyle orginalStatusBarStyle_;
    UILabel *tipLabel_;
    UIButton *torchBtn_;
    UILabel *torchTipLabel_;
    //光线第一次变暗
    BOOL _isFirstBecomeDark;
    float _lastBrightnessValue;
    BOOL _isFirstAppear;
}
@property (nonatomic ,strong)AVCaptureDevice *device;
@property (nonatomic ,strong)AVCaptureSession *session;
@property (nonatomic ,strong)UIView *maskView;
@property (nonatomic ,strong)UIImageView *scanLineView;

@end
@implementation EQRCodeVC

-(instancetype)init{
    if (self = [super init]) {
    }
    return self;
    
}

-(UIView *)maskView{
    if (!_maskView) {
        _maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        _maskView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        [self.view addSubview:_maskView];
    }
    return _maskView;
}

-(AVCaptureSession *)session{
    if (!_session) {
        //1.获取摄像设备
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        self.device = device;
        //2.创建输入流
        AVCaptureDeviceInput *inPut = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        //3.创建输出流
        AVCaptureMetadataOutput *outPut = [[AVCaptureMetadataOutput alloc]init];
        //设置光感代理输出
        AVCaptureVideoDataOutput *respondOutput = [[AVCaptureVideoDataOutput alloc] init];
        [respondOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        //4.设置代理，在主线程里刷新
        [outPut setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        // 设置扫描范围
        outPut.rectOfInterest = CGRectMake(0.05, 0.2, 0.7, 0.6);
        //5.初始化链接对象（会话对象)
        _session = [[AVCaptureSession alloc]init];
        //高质量采集
        [_session setSessionPreset:AVCaptureSessionPresetHigh];
        if ([_session canAddInput:inPut]) [_session addInput:inPut];
        if ([_session canAddOutput:outPut]) [_session addOutput:outPut];
        if ([_session canAddOutput:respondOutput]) [_session addOutput:respondOutput];
        //6.设置输出类型。需要将元数据输出添加到会话后，才能指定元数据类型，否则会报错；
        //设置扫码支持的编码格式
        outPut.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeCode128Code];
        AVCaptureVideoPreviewLayer *preViewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        preViewLayer.frame = self.view.bounds;
        [self.view.layer insertSublayer:preViewLayer atIndex:0];
    }
    return _session;
}


-(void)viewDidLoad{
    [super viewDidLoad];
    //判断相机权限    
    [self setUpBaseView];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(startSuccess) name:AVCaptureSessionDidStartRunningNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(startFail) name:AVCaptureSessionErrorKey object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterFore) name:UIApplicationWillEnterForegroundNotification object:nil];
}



-(void)viewWillAppear:(BOOL)animated{
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [super viewWillAppear:animated];
    orginalStatusBarStyle_ = [UIApplication sharedApplication].statusBarStyle;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.session startRunning];    
}

-(void)viewWillDisappear:(BOOL)animated{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].statusBarStyle = orginalStatusBarStyle_;
}

-(void)setUpBaseView{
    _isFirstAppear = YES;
    self.view.backgroundColor = [UIColor blackColor];
    //取消按钮
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelBtn setTitle:@"取消" forState:0];
    [cancelBtn sizeToFit];
    cancelBtn.frame = CGRectMake(self.view.frame.size.width - cancelBtn.frame.size.width - 30, 40, cancelBtn.frame.size.width, cancelBtn.frame.size.height);
    [self.view addSubview:cancelBtn];
//    @weakify(self)
//    [[cancelBtn rac_signalForControlEvents:UIControlEventTouchUpInside]subscribeNext:^(id x) {
//        @strongify(self)
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }];
    
    
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50+pathWidth;
    
    tipLabel_ = [[UILabel alloc] initWithFrame:CGRectMake(50, orginY+15, pathWidth, 20)];
    tipLabel_.text = @"测试";
    tipLabel_.textAlignment = NSTextAlignmentCenter;
    tipLabel_.font = [UIFont systemFontOfSize:14];
    tipLabel_.textColor = [UIColor colorWithWhite:.7 alpha:1];
    [self.view addSubview:tipLabel_];
    
    torchBtn_ = [UIButton buttonWithType:UIButtonTypeCustom];
    torchBtn_.frame = CGRectMake(Width/2-15, orginY+40, 30, 30);
    torchBtn_.hidden = YES;
    [torchBtn_ setImage:[UIImage imageNamed:@"torch_n"] forState:UIControlStateNormal];
    [torchBtn_ setImage:[UIImage imageNamed:@"torch_s"] forState:UIControlStateSelected];
    [torchBtn_ addTarget:self action:@selector(switchTorchClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:torchBtn_];
    
    torchTipLabel_ = [[UILabel alloc] initWithFrame:CGRectMake(Width/2-50, orginY+75, 100, 30)];
    torchTipLabel_.hidden = YES;
        torchTipLabel_.text = @"测试";
    torchTipLabel_.textAlignment = NSTextAlignmentCenter;
    torchTipLabel_.font = [UIFont systemFontOfSize:14];
    torchTipLabel_.textColor = [UIColor whiteColor];
    [self.view addSubview:torchTipLabel_];
    [self.view.layer insertSublayer:self.maskView.layer atIndex:0];
}

- (void)initScanUI{
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_scanBg.png"]];
    imageView.frame = CGRectMake(50, orginY, pathWidth, pathWidth);
    [self.view addSubview:imageView];

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.duration = 0.25;
    animation.fromValue = @(0);
    animation.toValue = @(1);
    animation.delegate = self;
    [imageView.layer addAnimation:animation forKey:nil];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag{
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    CGMutablePathRef path = CGPathCreateMutable();
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    //内部方框path
    CGPathAddRect(path, nil, CGRectMake(50, orginY, pathWidth, pathWidth));
    //外部大框path
    CGPathAddRect(path, nil, _maskView.bounds);
    //两个path取差集，即去除差集部分
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.path = path;
    _maskView.layer.mask = maskLayer;
    [self initScanLineView];
}

- (void)initScanLineView{
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    
    if (_scanLineView) {
        [_scanLineView removeFromSuperview];
        _scanLineView = nil;
    }
    _scanLineView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_scanLine.png"]];
    CGRect frame = CGRectMake(55, orginY, pathWidth-10, 5);
    _scanLineView.frame = frame;
    frame.origin.y += pathWidth-5;
    [UIView animateWithDuration:4.0 delay:0.2 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:^{
        self->_scanLineView.frame = frame;
    } completion:nil];
    [self.view addSubview:_scanLineView];
}

-(void)enterFore{
    [self.session startRunning];
    [self initScanLineView];
}

-(void)startSuccess{
    if (_isFirstAppear) {
        [self initScanUI];
        _isFirstAppear = NO;
    }
}

-(void)startFail{

}

#pragma mark -- <AVCaptureMetadataOutputObjectsDelegate>
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    NSLog(@"fun = %s line = %d",__func__,__LINE__);
    //扫描到后，关闭扫码；
    for(AVMetadataObject *current in metadataObjects) {
        if ([current isKindOfClass:[AVMetadataMachineReadableCodeObject class]]
            && [current.type isEqualToString:AVMetadataObjectTypeQRCode])
        {
            NSString *scannedResult = [(AVMetadataMachineReadableCodeObject *) current stringValue];
            scannedResult = [scannedResult stringByReplacingOccurrencesOfString:@"\r" withString:@""];
            scannedResult = [scannedResult stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            if (scannedResult.length==0) {
                return;
            }

            [self disposeQRCode:scannedResult];
            NSLog(@"sannedResult ---- %@",scannedResult);
            [self.navigationController pushViewController:[NSClassFromString(@"PUOrderResultViewController") new] animated:YES];
            [_session stopRunning];
            break;
        }
    }
}


/**处理二维码*/
-(void)disposeQRCode:(NSString*)qrCode{
//    [self.view makeToast:@"处理二维码"];
}

#pragma mark - 光感回调
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    // 该值在 -5~12 之间
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    if ((_lastBrightnessValue>0 && brightnessValue>0) ||
        (_lastBrightnessValue<=0 && brightnessValue<=0)) {
        return;
    }
    _lastBrightnessValue = brightnessValue;
    [self switchTorchBtnState:brightnessValue<=0];
}


- (void)switchTorchClick:(UIButton *)btn{
    [self switchTorch:!btn.isSelected];
}

- (void)switchTorch:(BOOL)on{
    //更换按钮状态
    torchBtn_.selected = on;
    torchTipLabel_.text = on?@"打开":@"关闭";
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        if (on) {
            //调用led闪光灯
            [device lockForConfiguration:nil];
            [device setTorchMode: AVCaptureTorchModeOn];
        } else {
            //关闭闪光灯
            if (device.torchMode == AVCaptureTorchModeOn) {
                [device setTorchMode: AVCaptureTorchModeOff];
            }
        }
    }
}

- (void)switchTorchBtnState:(BOOL)show{
    torchBtn_.hidden = !show && !torchBtn_.isSelected;
    torchTipLabel_.hidden = !show && !torchBtn_.isSelected;
    tipLabel_.hidden = show || torchBtn_.isSelected;
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [_session stopRunning];
}


@end
