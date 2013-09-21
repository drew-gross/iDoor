//
//  FirstViewController.m
//  iDoor
//
//  Created by Drew Gross on 2013-09-12.
//  Copyright (c) 2013 Drew Gross. All rights reserved.
//

#import "FirstViewController.h"
#import <LRResty.h>
#import <ACEDrawingView.h>
#import <CoreMotion/CoreMotion.h>

@interface FirstViewController ()

//message
@property (weak, nonatomic) IBOutlet ACEDrawingView *drawingView;
@property (weak, nonatomic) IBOutlet UINavigationItem *sendButton;

//alarm
@property (strong, nonatomic) UIAlertView *alarm;
@property (strong, nonatomic) AVAudioPlayer *player;
@property (nonatomic) BOOL alarmPhotoTimerAdded;

//accel check
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSMutableArray *accelBufferX;
@property (strong, nonatomic) NSMutableArray *accelBufferY;
@property (strong, nonatomic) NSMutableArray *accelBufferZ;
@property (nonatomic) NSUInteger accelBufferIndex;
#define ACCEL_BUFFER_SIZE (30)

//photo capture
@property (strong, nonatomic) AVCaptureSession *cameraSession;
@property (strong, nonatomic) AVCaptureStillImageOutput *imageOutput;
@property (weak, nonatomic) IBOutlet UIImageView *captureView;

@property (weak, nonatomic) IBOutlet UIImageView* cameraImageView;
@property (strong, nonatomic) AVCaptureDevice* device;
@property (strong, nonatomic) AVCaptureSession* captureSession;
@property (strong, nonatomic) UIImage* cameraImage;

- (IBAction)sendMessage:(id)sender;

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupAccelerometer];
    [self setupAlarm];
    [self setupCamera];
    
}

- (void)setupAccelerometer{
    self.accelBufferX = [[NSMutableArray alloc] initWithCapacity:ACCEL_BUFFER_SIZE];
    self.accelBufferY = [[NSMutableArray alloc] initWithCapacity:ACCEL_BUFFER_SIZE];
    self.accelBufferZ = [[NSMutableArray alloc] initWithCapacity:ACCEL_BUFFER_SIZE];
    self.accelBufferIndex = 0;
    for (int i = 0; i < ACCEL_BUFFER_SIZE; i++){
        [self.accelBufferX addObject:@(-1)];
        [self.accelBufferY addObject:@(0)];
        [self.accelBufferZ addObject:@(0)];
    }
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = 0.2;
    [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error){
        //write new value into circular buffer
        self.accelBufferX[self.accelBufferIndex] = @(accelerometerData.acceleration.x);
        self.accelBufferY[self.accelBufferIndex] = @(accelerometerData.acceleration.y);
        self.accelBufferZ[self.accelBufferIndex] = @(accelerometerData.acceleration.z);
        self.accelBufferIndex = (self.accelBufferIndex + 1) % ACCEL_BUFFER_SIZE;
        
        //check circular buffer average
        double aveX = 0;
        double aveY = 0;
        double aveZ = 0;
        for (int i = 0; i < ACCEL_BUFFER_SIZE; i++) {
            aveX += [self.accelBufferX[i] doubleValue];
            aveY += [self.accelBufferY[i] doubleValue];
            aveZ += [self.accelBufferZ[i] doubleValue];
        }
        aveX /= ACCEL_BUFFER_SIZE;
        aveY /= ACCEL_BUFFER_SIZE;
        aveZ /= ACCEL_BUFFER_SIZE;
        if ((aveX < -1.15 || aveX > -0.85) && !self.alarm.isVisible) {
            [self.alarm show];
            [self.player play];
            if (!self.alarmPhotoTimerAdded) {
                self.alarmPhotoTimerAdded = true;
                [self alarmPhoto];
                [[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:60*3 target:self selector:@selector(alarmPhoto) userInfo:nil repeats:YES] forMode:NSDefaultRunLoopMode];
            }
        }
    }];
}

- (void)setupAlarm
{
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"alarm" ofType:@"wav"];
    NSURL *soundFileURL = [[NSURL alloc] initFileURLWithPath:soundFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    [self.player prepareToPlay];
    [self.player setDelegate:self];
    self.alarm = [[UIAlertView alloc] initWithTitle:@"Hey, you!" message:@"Stop stealin' my iPad!" delegate:Nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    //if alarming, send another image every 3 minutes
    self.alarmPhotoTimerAdded = false;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) alarmPhoto {
    [[LRResty client] post:@"http://idoor.herokuapp.com/alarm" payload:UIImagePNGRepresentation(self.cameraImage)];
}

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) completed {
    if (completed == YES) {
        [self.player play];
    }
}

- (IBAction)sendMessage:(UITabBarItem*)sender {
    sender.enabled = false;
    self.sendButton.title = @"Sending...";
    
    //take a picture
    AVCaptureConnection *connection = nil;
    for (AVCaptureConnection *conn in self.imageOutput.connections) {
        for (AVCaptureInputPort *port in [conn inputPorts]) {
            if ([[port mediaType] isEqual: AVMediaTypeVideo]) {
                connection = conn;
                break;
            }
        }
    }
    
    CGSize sentImageSize = CGSizeMake(500, 500);
    UIGraphicsBeginImageContext(sentImageSize);
    [self.cameraImage drawInRect:CGRectMake(0,0,sentImageSize.width,sentImageSize.height)];
    UIImage* cameraImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    CGSize sentDrawingSize = CGSizeMake(500, 500);
    UIGraphicsBeginImageContext(sentDrawingSize);
    [self.drawingView.image drawInRect:CGRectMake(0,0,sentDrawingSize.width,sentDrawingSize.height)];
    UIImage* drawingImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *imageData = UIImagePNGRepresentation(cameraImage);
    NSData *drawingData = UIImagePNGRepresentation(drawingImage);
    
    //send the message
    [[LRResty client] post:@"http://idoor.herokuapp.com/messages" payload:drawingData withBlock:^(LRRestyResponse *response){
        UIAlertView *sentView = [[UIAlertView alloc] initWithTitle:@"Message Sent!" message:@"Your message has been sent!" delegate:nil cancelButtonTitle:@"Hooray!" otherButtonTitles:nil];
        [sentView show];
        sender.enabled = true;
        self.sendButton.title = @"Send Drew a Message";
        [self.drawingView clear];
        [[LRResty client] post:@"http://idoor.herokuapp.com/messages" payload:imageData withBlock:^(LRRestyResponse *response) {
            //nothing
        }];
    }];
}

- (IBAction)clearMessage:(id)sender {
    [self.drawingView clear];
}

- (void)setupCamera
{
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for(AVCaptureDevice *device in devices)
    {
        if([device position] == AVCaptureDevicePositionFront)
            self.device = device;
    }
    
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString *) kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [output setVideoSettings:videoSettings];
    
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:input];
    [self.captureSession addOutput:output];
    [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];\
    
    [self.captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    self.cameraImage = [UIImage imageWithCGImage:newImage scale:.05f orientation:UIImageOrientationDownMirrored];
    
    CGImageRelease(newImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}
    

@end