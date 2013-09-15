//
//  FirstViewController.m
//  iDoor
//
//  Created by Drew Gross on 2013-09-12.
//  Copyright (c) 2013 Drew Gross. All rights reserved.
//

#import "FirstViewController.h"

@interface FirstViewController ()
@property (weak, nonatomic) IBOutlet UITextField *messageField;
@property (weak, nonatomic) IBOutlet UILabel *mainLabel;
- (IBAction)sendMessage:(id)sender;

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendMessage:(id)sender {
    NSString *message = self.messageField.text;
    
    UIAlertView *sentView = [[UIAlertView alloc] initWithTitle:@"Message Sent!" message:[@"Your message has been sent: " stringByAppendingString:message] delegate:nil cancelButtonTitle:@"Hooray!" otherButtonTitles:nil];
    [sentView show];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://idoor.meteor.com/new_message/" stringByAppendingString:message]]
                                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                                       timeoutInterval:10];
    
    [request setHTTPMethod: @"GET"];
    
    NSError *requestError;
    NSURLResponse *urlResponse = nil;
    
    
    NSData *response1 = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&requestError];
    [response1 description];
    NSLog(@"%@", [[NSString alloc] initWithBytes:[response1 bytes] length:[response1 length] encoding:NSUTF8StringEncoding]);
}
@end
