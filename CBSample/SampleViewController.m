//
//  SampleViewController.m
//
//  Created by Tim Burks on 8/10/12.
//  Copyright (c) 2012 Tim Burks. All rights reserved.
//

#import "SampleViewController.h"
#import "SampleService.h"
#import "SampleClient.h"

UITextView *gTextView;

@interface SampleViewController ()
@property (nonatomic, strong) SampleService *service;
@property (nonatomic, strong) SampleClient *client;
@property (nonatomic, strong) UITextView *textView;
@end

@implementation SampleViewController

- (void) loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor redColor];
    UIButton *serviceButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    serviceButton.frame = CGRectInset(CGRectMake(0,25,
                                                 0.5*self.view.bounds.size.width,50),
                                      20, 0);
    [serviceButton setTitle:@"start service" forState:UIControlStateNormal];
    [serviceButton addTarget:self action:@selector(startService:)
            forControlEvents:UIControlEventTouchUpInside];
    serviceButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin+UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:serviceButton];
    UIButton *clientButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    clientButton.frame = CGRectInset(CGRectMake(0.5*self.view.bounds.size.width,25,
                                                0.5*self.view.bounds.size.width,50),
                                     20, 0);
    [clientButton setTitle:@"start client" forState:UIControlStateNormal];
    [clientButton addTarget:self action:@selector(startClient:)
           forControlEvents:UIControlEventTouchUpInside];
    clientButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin+UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleLeftMargin;
    [self.view addSubview:clientButton];
    
    self.textView = [[UITextView alloc]
                     initWithFrame:CGRectInset(CGRectMake(0, 100,
                                                          self.view.bounds.size.width,
                                                          self.view.bounds.size.height-100),
                                               20, 20)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth+UIViewAutoresizingFlexibleHeight;
    self.textView.editable = NO;
    [self.view addSubview:self.textView];
    
    gTextView = self.textView;
}

- (void) startService:(id) sender
{
    NSLog(@"startService: pressed");
    self.service = [[SampleService alloc] init];
    gTextView.text = @"Starting Service";
}

- (void) startClient:(id) sender
{
    NSLog(@"startClient: pressed");
    self.client = [[SampleClient alloc] init];
    gTextView.text = @"Starting Client";
}

@end