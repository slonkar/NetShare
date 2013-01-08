//
//  NetShareViewController.h
//  NetShare
//
//  Created by Sumit Lonkar on 2/23/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SocksProxy.h"
enum {
	NCONNECTIONS=100
};
@interface NetShareViewController : UIViewController <SocksProxyDelegate,NSNetServiceDelegate>
{
    IBOutlet UILabel *portLabel;
    IBOutlet UILabel *addressLabel;
    IBOutlet UILabel *statusLabel;
	IBOutlet IBOutlet UILabel *countOpenLabel;
	IBOutlet UILabel *nConnectionsLabel;
    IBOutlet UILabel *uploadedLable;
    IBOutlet UILabel *downloadedLable;
    
    NSNetService * _netService;
    CFSocketRef _listeningSocket;
	
	NSInteger _nConnections;
	SocksProxy * _sendreceiveStream[NCONNECTIONS];
    UIButton *startOrStopButton;
    IBOutlet UIBarButtonItem *doneInfoButton;
}

@property(nonatomic,retain)UIButton *startOrStopButton;
@property(nonatomic,retain) IBOutlet UIView *infoView;
@property (nonatomic, assign) NSInteger uploadData;
@property (nonatomic, assign) NSInteger downloadData;

-(IBAction)doneInfoAction:(id)sender;
-(void)startOrStopAction:(id)sender;
-(void)refreshTheData;
@end
