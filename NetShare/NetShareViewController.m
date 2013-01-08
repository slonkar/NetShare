//
//  NetShareViewController.m
//  NetShare
//
//  Created by Sumit Lonkar on 2/23/12.
//  Copyright (c) 2012. All rights reserved.
//


#import "NetShareAppDelegate.h"
#import "UIDevice_Extended.h"

#include <CFNetwork/CFNetwork.h>

#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>
#import "NetShareViewController.h"

@interface NetShareViewController()
    @property (nonatomic, copy) NSString *currentStatusText;
    @property (nonatomic, assign) NSInteger currentPort;
    @property (nonatomic, copy) NSString *currentAddress;
    @property (nonatomic, assign) NSInteger currentOpenConnections;
    @property (nonatomic, assign) NSInteger currentConnectionCount;

    @property (nonatomic, readonly) BOOL                isStarted;
    @property (nonatomic, retain)   NSNetService *      netService;
    @property (nonatomic, assign)   CFSocketRef         listeningSocket;
    @property (nonatomic, assign)   NSInteger			nConnections;
    @property (nonatomic, readonly) SocksProxy **       sendreceiveStream;

    - (void)_stopServer:(NSString *)reason;
@end

@implementation NetShareViewController
@synthesize nConnections  = _nConnections;
@synthesize netService=_netService;
@synthesize listeningSocket = _listeningSocket;
// Because sendreceiveStream is declared as an array, you have to use a custom getter.  
// A synthesised getter doesn't compile.

- (SocksProxy **)sendreceiveStream
{
    return self->_sendreceiveStream;
}

@synthesize currentStatusText=_currentStatusText;
@synthesize currentPort=_currentPort;
@synthesize currentAddress=_currentAddress;
@synthesize currentOpenConnections=_currentOpenConnections;
@synthesize currentConnectionCount=_currentConnectionCount;
@synthesize uploadData,downloadData;

@synthesize startOrStopButton;
@synthesize infoView;
-(void)dealloc
{
    [super dealloc];
    [infoView release];
    [startOrStopButton release];
    [_currentAddress release];
    [_currentStatusText release];
    [_netService release];
    [self _stopServer:nil];
	int i = 0;
	for ( ; i < self.nConnections ; ++i)
		[self.sendreceiveStream[i] dealloc];
    
}

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.

- (void)_serverDidStartOnPort:(int)port
{
    assert( (port > 0) && (port < 65536) );
    
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
	// Disable device sleep mode
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	
	// Enable proximity sensor (public as of 3.0)
	[UIDevice currentDevice].proximityMonitoringEnabled = YES;
	
	self.currentAddress = [UIDevice localWiFiIPAddress];
	self.currentPort = port;
	self.currentStatusText = NSLocalizedString(@"Started", nil);	
    
    [self.startOrStopButton setImage:[UIImage imageNamed:@"blueWifi"] forState:UIControlStateNormal];
	//[self.startOrStopButton setupAsRedButton];
	
	[self refreshTheData];
	
	//DLog(@"Server Started");
}

- (void)_serverDidStopWithReason:(NSString *)reason
{
    if (reason == nil) {
        reason = NSLocalizedString(@"Stopped", nil);
    }
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	
	// Enable device sleep mode
	[UIApplication sharedApplication].idleTimerDisabled = NO;
	
	// Disable proximity sensor (public as of 3.0)
	[UIDevice currentDevice].proximityMonitoringEnabled = NO;
	
	self.currentAddress = @"";
	self.currentPort = 0;
	self.currentStatusText = reason;
    [self.startOrStopButton setImage:[UIImage imageNamed:@"greenWifi"] forState:UIControlStateNormal];
	//[self.startOrStopButton setupAsGreenButton];
    
	[self refreshTheData];
    
	//DLog(@"Server Stopped: %@", reason);
}
- (NSInteger)countOpen
{
	int countOpen = 0;
	int i;
	for (i = 0 ; i < self.nConnections ; ++i)
	{
		if ( ! self.sendreceiveStream[i].isSendingReceiving )
			++countOpen;
	}
	return countOpen;
}

- (void)_sendreceiveDidStart
{
    self.currentStatusText = NSLocalizedString(@"Receiving", nil);
	
	NSInteger countOpen = [self countOpen];
	self.currentOpenConnections = countOpen;
	
	if (!countOpen) {
		[[NetShareAppDelegate sharedAppDelegate] didStartNetworking];
	}
	
	[self refreshTheData];
}
- (void)_updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    
	self.currentStatusText = statusString;
    
	//DLog(@"Status: %@", statusString);
    
}


- (void)_sendreceiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = NSLocalizedString(@"Receive succeeded", nil);
    }
	self.currentStatusText = statusString;
	NSInteger countOpen = [self countOpen];
	self.currentOpenConnections = countOpen;
	if (!countOpen) {
		[[NetShareAppDelegate sharedAppDelegate] didStopNetworking];		
	}
    
	[self refreshTheData];
	
	//DLog(@"Connection ended %d %d: %@", countOpen, self.nConnections, statusString);
}


- (void)_downloadData:(NSInteger)bytes
{
    self.downloadData += bytes/1024;
	
	[self refreshTheData];
}


- (void)_uploadData:(NSInteger)bytes
{
    self.uploadData += bytes/1024;
	
	[self refreshTheData];
}
#pragma mark * Core transfer code

// This is the code that actually does the networking.





- (BOOL)isStarted
{
    return (self.netService != nil);
}

// Have to write our own setter for listeningSocket because CF gets grumpy 
// if you message NULL.

- (void)setListeningSocket:(CFSocketRef)newValue
{
    if (newValue != self->_listeningSocket) {
        if (self->_listeningSocket != NULL) {
            CFRelease(self->_listeningSocket);
        }
        self->_listeningSocket = newValue;
        if (self->_listeningSocket != NULL) {
            CFRetain(self->_listeningSocket);
        }
    }
}


- (void)_acceptConnection:(int)fd
{
	SocksProxy *proxy = nil;
	int i;
	for (i = 0 ; i < self.nConnections ; ++i)
	{
		if (!self.sendreceiveStream[i].isSendingReceiving) 
		{
			proxy = self.sendreceiveStream[i];
			break;
		}
	}
	
	if(!proxy) {
		if(i>NCONNECTIONS) {
			close(fd);
			return;
		}
		proxy = [SocksProxy new];
		self.sendreceiveStream[i] = proxy;
		self.sendreceiveStream[i].delegate = self;
		++self.nConnections;
		self.currentConnectionCount = self.nConnections;
	}
	int countOpen = 0;
	for (i = 0 ; i < self.nConnections ; ++i)
	{
		if (!self.sendreceiveStream[i].isSendingReceiving)
			++countOpen;
	}
    
	//DLog(@"Accept connection %d %d", countOpen, self.nConnections);
    
	if (![proxy startSendReceive:fd])
		close(fd);
	
	[self refreshTheData];
}


static void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
// Called by CFSocket when someone connects to our listening socket.  
// This implementation just bounces the request up to Objective-C.
{
    NetShareViewController *  obj;
    
#pragma unused(type)
    assert(type == kCFSocketAcceptCallBack);
#pragma unused(address)
    // assert(address == NULL);
    assert(data != NULL);
    
    obj = (NetShareViewController *) info;
    assert(obj != nil);
    
#pragma unused(s)
    assert(s == obj->_listeningSocket);
    
    [obj _acceptConnection:*(int *)data];
}


- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
// A NSNetService delegate callback that's called if our Bonjour registration 
// fails.  We respond by shutting down the server.
//
// This is another of the big simplifying assumptions in this sample. 
// A real server would use the real name of the device for registrations, 
// and handle automatically renaming the service on conflicts.  A real 
// client would allow the user to browse for services.  To simplify things 
// we just hard-wire the service name in the client and, in the server, fail 
// if there's a service name conflict.
{
#pragma unused(sender)
    assert(sender == self.netService);
#pragma unused(errorDict)
    
    [self _stopServer:@"Registration failed"];
}


- (void)_startServer
{
    BOOL        success;
    int         err;
    int         fd;
    int         junk;
    struct sockaddr_in addr;
    int         port;
	
	self.nConnections = 0;
    // Create a listening socket and use CFSocket to integrate it into our 
    // runloop.  We bind to port 0, which causes the kernel to give us 
    // any free port, then use getsockname to find out what port number we 
    // actually got.
    
    port = 0;
    
	fd = socket(AF_INET, SOCK_STREAM, 0);
	success = (fd != -1);
    
	if (success) {
		memset(&addr, 0, sizeof(addr));
		addr.sin_len    = sizeof(addr);
		addr.sin_family = AF_INET;
		addr.sin_addr.s_addr = INADDR_ANY;
		
		int iport;
		int ports[] = {20000,30000,40000,50000,0,-1};
		for (iport = 0 ; ports[iport] >= 0 ; ++iport) {
			port=ports[iport];
			addr.sin_port   = htons(port);
			err = bind(fd, (const struct sockaddr *) &addr, sizeof(addr));
			success = (err == 0);
			if (success)
				break;
		}
	}
	if (success) {
		err = listen(fd, 5);
		success = (err == 0);
	}
	if (success) {
		socklen_t   addrLen;
        
		addrLen = sizeof(addr);
		err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
		success = (err == 0);
		
		if (success) {
			assert(addrLen == sizeof(addr));
			port = ntohs(addr.sin_port);
		}
	}
    if (success) {
        CFSocketContext context = { 0, self, NULL, NULL, NULL };
        
        self.listeningSocket = CFSocketCreateWithNative(
                                                        NULL, 
                                                        fd, 
                                                        kCFSocketAcceptCallBack, 
                                                        AcceptCallback, 
                                                        &context
                                                        );
        success = (self.listeningSocket != NULL);
        
        if (success) {
            CFRunLoopSourceRef  rls;
            
            CFRelease(self.listeningSocket);        // to balance the create
            
            fd = -1;        // listeningSocket is now responsible for closing fd
            
            rls = CFSocketCreateRunLoopSource(NULL, self.listeningSocket, 0);
            assert(rls != NULL);
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            
            CFRelease(rls);
        }
    }
    
    // Now register our service with Bonjour.  See the comments in -netService:didNotPublish: 
    // for more info about this simplifying assumption.
    
    if (success) {
        //self.netService = [[[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSUpload._tcp." name:@"Test" port:port] autorelease];
        self.netService = [[[NSNetService alloc] initWithDomain:@""		
														   type:@"_socks5._tcp." 
														   name:@"Test" 
														   port:port] autorelease];
        success = (self.netService != nil);
    }
    if (success) {
        self.netService.delegate = self;
        
        [self.netService publishWithOptions:NSNetServiceNoAutoRename];
        
        // continues in -netServiceDidPublish: or -netService:didNotPublish: ...
    }
    
    // Clean up after failure.
    
    if ( success ) {
        assert(port != 0);
        [self _serverDidStartOnPort:port];
    } else {
        [self _stopServer:@"Start failed"];
        if (fd != -1) {
            junk = close(fd);
            assert(junk == 0);
        }
    }
}


- (void)_stopServer:(NSString *)reason
{
	int i = 0;
	for ( ; i < self.nConnections ; ++i) {
		if (self.sendreceiveStream[i].isSendingReceiving)
			[self.sendreceiveStream[i] stopSendReceiveWithStatus:@"Cancelled"];
    }
	
    if (self.netService != nil) {
        [self.netService stop];
        self.netService = nil;
    }
    if (self.listeningSocket != NULL) {
        CFSocketInvalidate(self.listeningSocket);
        self.listeningSocket = NULL;
    }
    [self _serverDidStopWithReason:reason];
}


- (void)startOrStopAction:(id)sender
{
    if (self.isStarted) {
        [self _stopServer:nil];
    } else {
        [self _startServer];
    }
	
	[self refreshTheData];
    
}

-(void)refreshTheData
{
    NSLog(@"Reload all the data");
    
    //Set Address Lable
    addressLabel.text = self.currentAddress;
    if (self.currentAddress.length == 0)
        addressLabel.text = @"n/a";
    
    //Set Port Lable
    if (self.currentPort)
        portLabel.text = [[NSNumber numberWithInt:self.currentPort] stringValue];
    else
        portLabel.text = @"n/a";
    
    //Set Connection Count
     nConnectionsLabel.text= [[NSNumber numberWithInt:self.currentConnectionCount] stringValue];

    //Set Open Connection Count
    countOpenLabel.text = [[NSNumber numberWithInt:self.currentOpenConnections] stringValue];
    
    //Set Uploaded Data
    uploadedLable.text = [[NSNumber numberWithInt:self.uploadData] stringValue];

    
    //Set Downloaded Data
    downloadedLable.text=[[NSNumber numberWithInt:self.downloadData] stringValue];

    // Set Status
    statusLabel.text=self.currentStatusText;

}

- (void)applicationDidEnterForeground:(NSNotification *)n
{
	//DLog(@"refreshing ip address",n);
	
	// refresh the IP address, just in case
	self.currentAddress = [UIDevice localWiFiIPAddress];
	[self refreshTheData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)slideDownDidStop
{
    [self.infoView removeFromSuperview];

}
-(IBAction)doneInfoAction:(id)sender
{
    NSLog(@"Hide Information View");
    self.navigationController.navigationBarHidden=NO;
    
    self.infoView.frame = CGRectMake(0.0, 0.0, 320.0, 480.0);
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    [UIView setAnimationTransition:UIViewAnimationOptionTransitionNone forView:self.infoView cache:YES];
    
    // we need to perform some post operations after the animation is complete
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(slideDownDidStop)];
    [self.infoView setFrame:CGRectMake(0.0,480.0, 320.0, 480.0)];
    [UIView commitAnimations];
}

-(void)ShowInfo
{

    NSLog(@"About Us Selected");

    self.navigationController.navigationBarHidden=YES;
    
    [self.view addSubview:infoView];
    self.infoView.frame = CGRectMake(0.0, 480.0, 320.0, 480.0);
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    //[UIView setAnimationTransition:UIViewAnimationOptionTransitionNone forView:slateImage cache:YES];
    [self.infoView setFrame:CGRectMake(0.0,0.0, 320.0, 480.0)];
    [UIView commitAnimations];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidEnterForeground:)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
    //assert(self.startOrStopButton != nil);
    self.currentStatusText = NSLocalizedString(@"Tap Button To Start The Server", nil);
    
	// Do any additional setup after loading the view, typically from a nib.
    self.title=@"NetShare";
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    //Add Connection Button
    
    self.startOrStopButton =[UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *wifiImage = [UIImage imageNamed:@"greenWifi.png"];
    [self.startOrStopButton setImage:wifiImage forState:UIControlStateNormal];
    [self.startOrStopButton addTarget:self action:@selector(startOrStopAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.startOrStopButton setFrame:CGRectMake(0,0, wifiImage.size.width, wifiImage.size.height)];
    [self.startOrStopButton setCenter:CGPointMake(160, 360)];
    [self.view addSubview:self.startOrStopButton];
    
    //Information About How To Operate This App
    
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight]; 
    [infoButton addTarget:self action:@selector(ShowInfo) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:infoButton]autorelease];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    self.startOrStopButton = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
