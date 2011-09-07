//
//  DiffissAppDelegate.h
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-04.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiffissAppDelegate : NSObject {
    NSWindow *window;
	
	NSBrowser *browser;
	
	NSString *rpcOutputFilePath;
	NSTask *rpc, *python;
	
	IBOutlet NSPanel *credentials;
	
	NSString *server;
	NSString *domain;
	NSString *user;
	NSString *password;
	
	NSNumber *kerberos;
	
	IBOutlet NSTextField *labelUserName;
	IBOutlet NSTextField *labelPassword;
	IBOutlet NSTextField *labelDomain;
	
	NSNumber *storeInKeychain;
	
	BOOL reauthenticate;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSBrowser *browser;

@property (retain) NSString *server;
@property (retain) NSString *domain;
@property (retain) NSString *user;
@property (retain) NSString *password;
@property (nonatomic,retain) NSNumber *kerberos;
@property (retain) NSNumber *storeInKeychain;

- (BOOL)getDataFromPlist;

- (IBAction)initiateRPC:(id)sender;
- (void)rpcFinished:(NSNotification *)n;

- (IBAction)proceedWithConnection:(id)sender;
- (IBAction)cancelConnection:(id)sender;

- (IBAction)visitWebSite:(id)sender;
- (IBAction)clearCredentials:(id)sender;

@end
