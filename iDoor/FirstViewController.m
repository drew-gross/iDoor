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

@interface FirstViewController ()

//message
@property (weak, nonatomic) IBOutlet ACEDrawingView *drawingView;

//alarm
@property (strong, nonatomic) UIAlertView *alarm;
@property (strong, nonatomic) AVAudioPlayer *player;

//accel check
@property (strong, nonatomic) NSMutableArray *accelBuffer;
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
    //set up accel
    UIAccelerometer *a = [UIAccelerometer sharedAccelerometer];
    a.delegate = self;
    a.updateInterval = 1.f/60.f;
    self.accelBuffer = [[NSMutableArray alloc] initWithCapacity:ACCEL_BUFFER_SIZE];
    self.accelBufferIndex = 0;
    for (int i = 0; i < ACCEL_BUFFER_SIZE; i++){
        [self.accelBuffer addObject:@(1)];
    }
    
    //set up alarm
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"alarm" ofType:@"wav"];
    NSURL *soundFileURL = [[NSURL alloc] initFileURLWithPath:soundFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    [self.player prepareToPlay];
    [self.player setDelegate:self];
    self.alarm = [[UIAlertView alloc] initWithTitle:@"Hey, you!" message:@"Stop stealin' my iPad!" delegate:Nil cancelButtonTitle:@"No" otherButtonTitles:nil];
    
    
    [self setupCamera];
    
    /*
    //set up camera
    self.cameraSession = [[AVCaptureSession alloc] init];
    self.cameraSession.sessionPreset = AVCaptureSessionPresetPhoto;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *e = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&e];
    [self.cameraSession addInput:input];
    
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [self.imageOutput setOutputSettings:outputSettings];
    [self.cameraSession addOutput:self.imageOutput];
    
    [self.cameraSession startRunning];*/
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
    //write new value into circular buffer
    double accelScalar = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z);
    self.accelBuffer[self.accelBufferIndex] = @(accelScalar);
    self.accelBufferIndex = (self.accelBufferIndex + 1) % ACCEL_BUFFER_SIZE;
    
    //check circular buffer average
    double ave = 0;
    for (int i = 0; i < ACCEL_BUFFER_SIZE; i++) {
        ave += [self.accelBuffer[i] doubleValue];
    }
    ave /= ACCEL_BUFFER_SIZE;
    if ((ave > 1.07 || ave < 0.92) && !self.alarm.isVisible) {
        [self.alarm show];
        [self.player play];
    }
}

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) completed {
    if (completed == YES) {
        [self.player play];
    }
}

- (IBAction)sendMessage:(UITabBarItem*)sender {
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
    
    NSData *imageData = UIImagePNGRepresentation(self.cameraImage);
    NSData *drawingData = UIImagePNGRepresentation(self.drawingView.image);
    
    //send the message
    sender.enabled = false;
    [[LRResty client] post:@"http://idoor.herokuapp.com/messages" payload:imageData withBlock:^(LRRestyResponse *response){
        UIAlertView *sentView = [[UIAlertView alloc] initWithTitle:@"Message Sent!" message:@"Your message has been sent!" delegate:nil cancelButtonTitle:@"Hooray!" otherButtonTitles:nil];
        [sentView show];
        sender.enabled = true;
        [self.drawingView clear];
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