//
//  NetShareAppDelegate.m
//  NetShare
//
//  Created by Sumit Lonkar on 2/23/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "NetShareAppDelegate.h"
#import "NetShareViewController.h"
#define MINS(N) N * 60
// number of minutes until the critical or warning UIAlert is displayed
#define PROXY_BG_TIME_WARNING_MINS 1
// interval of seconds to poll/check the time remaining for the background task
#define PROXY_BG_TIME_CHECK_SECS 5

@implementation NetShareAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

+ (NetShareAppDelegate *)sharedAppDelegate
{
    return (NetShareAppDelegate *) [UIApplication sharedApplication].delegate;
}

- (void)didStartNetworking
{
    
}
- (void)didStopNetworking
{
    
}
- (void)dealloc
{
    [_window release];
    [_viewController release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.viewController = [[[NetShareViewController alloc] initWithNibName:@"NetShareViewController" bundle:nil] autorelease];
    UINavigationController *mainNavigationController=[[UINavigationController alloc]initWithRootViewController:self.viewController];
    self.window.rootViewController = mainNavigationController;
    [mainNavigationController release];
    [self.window makeKeyAndVisible];
    return YES;
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"%s", __func__);
    
	// if no networking, then ignore the bg operations
    
	_warningTimeAlertShown = NO;
	_bgTimer = [NSTimer scheduledTimerWithTimeInterval:PROXY_BG_TIME_CHECK_SECS
												target:self
											  selector:@selector(checkBackgroundTimeRemaining:)
											  userInfo:nil
											   repeats:YES];
    __block UIBackgroundTaskIdentifier ident;
	
    ident = [application beginBackgroundTaskWithExpirationHandler: ^{
        NSLog(@"Background task expiring!");
		
        [application endBackgroundTask: ident];
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	application.applicationIconBadgeNumber = 0;
	[application cancelAllLocalNotifications];
	[_bgTimer invalidate];
}
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
