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

@property (weak, nonatomic) IBOutlet ACEDrawingView *drawingView;
@property (strong, nonatomic) UIAlertView *alarm;
@property (strong, nonatomic) NSMutableArray *accelBuffer;
@property (nonatomic) NSUInteger accelBufferIndex;
#define ACCEL_BUFFER_SIZE (30)

- (IBAction)sendMessage:(id)sender;

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIAccelerometer *a = [UIAccelerometer sharedAccelerometer];
    a.delegate = self;
    a.updateInterval = 1.f/60.f;
    //set up alarm;
    self.alarm = [[UIAlertView alloc] initWithTitle:@"Hey, you!" message:@"Stop stealin' my iPad!" delegate:Nil cancelButtonTitle:@"No" otherButtonTitles:nil];
    self.accelBuffer = [[NSMutableArray alloc] initWithCapacity:ACCEL_BUFFER_SIZE];
    self.accelBufferIndex = 0;
    for (int i = 0; i < ACCEL_BUFFER_SIZE; i++){
        [self.accelBuffer addObject:@(1)];
    }
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
    NSLog(@"ave: %f, val: %f", ave, accelScalar);
    if ((ave > 1.06 || ave < 0.93) && !self.alarm.isVisible) {
        [self.alarm show];
    }
}

- (IBAction)sendMessage:(UITabBarItem*)sender {
    sender.enabled = false;
    [[LRResty client] post:@"http://idoor.herokuapp.com/messages" payload:UIImagePNGRepresentation(self.drawingView.image) withBlock:^(LRRestyResponse *response){
        UIAlertView *sentView = [[UIAlertView alloc] initWithTitle:@"Message Sent!" message:@"Your message has been sent!" delegate:nil cancelButtonTitle:@"Hooray!" otherButtonTitles:nil];
        [sentView show];
        sender.enabled = true;
    }];
}
@end