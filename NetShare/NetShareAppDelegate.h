//
//  NetShareAppDelegate.h
//  NetShare
//
//  Created by Sumit Lonkar on 2/23/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NetShareViewController;

@interface NetShareAppDelegate : UIResponder <UIApplicationDelegate>
{
    NSInteger _networkingCount;
	NSTimer	*_bgTimer;
	BOOL _warningTimeAlertShown;
}
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) NetShareViewController *viewController;
+ (NetShareAppDelegate *)sharedAppDelegate;
- (void)didStartNetworking;
- (void)didStopNetworking;

@end
