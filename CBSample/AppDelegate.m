//
//  Appdelegate.m
//
//  Created by Tim Burks on 7/3/12.
//  Copyright (c) 2012 Tim Burks. All rights reserved.
//

#import "AppDelegate.h"
#import "Common.h"
#import "SampleViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[SampleViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

