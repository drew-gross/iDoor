//
//  FirstViewController.m
//  iDoor
//
//  Created by Drew Gross on 2013-09-12.
//  Copyright (c) 2013 Drew Gross. All rights reserved.
//

#import "FirstViewController.h"
#import <LRResty.h>

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
    
    [[LRResty client] post:@"http://idoor.herokuapp.com/messages" payload:@{@"content": message} withBlock:^(LRRestyResponse *response){
        UIAlertView *sentView = [[UIAlertView alloc] initWithTitle:@"Message Sent!" message:@"Your message has been sent!" delegate:nil cancelButtonTitle:@"Hooray!" otherButtonTitles:nil];
        [sentView show];
    }];
}
@end
