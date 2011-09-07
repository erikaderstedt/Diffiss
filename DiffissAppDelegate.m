//
//  DiffissAppDelegate.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-04.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "DiffissAppDelegate.h"
#import "KeychainServices.h"

@implementation DiffissAppDelegate

@synthesize window;
@synthesize browser;

@synthesize server,domain,user,password;
@synthesize kerberos, storeInKeychain;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSUserDefaults *standard = [NSUserDefaults standardUserDefaults];
	self.server = [standard stringForKey:@"server"];

	if (server == nil) {
		NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
		self.server = [plist objectForKey:@"ASDefaultServer"];
		self.kerberos = [plist objectForKey:@"ASUseKerberos"];
		self.domain = [plist objectForKey:@"ASDefaultDomain"];
		
		[standard setObject:server forKey:@"server"];
		[standard setObject:domain forKey:@"domain"];
		[standard setObject:kerberos forKey:@"kerberos"];
	}
	
	self.kerberos = [standard objectForKey:@"kerberos"];
	if (![self.kerberos boolValue]) {
		
		self.domain = [standard stringForKey:@"domain"];
		self.user = [standard stringForKey:@"user"];

		[self findPasswordInKeychain];	
		reauthenticate = [standard boolForKey:@"loginRequired"]; 
	} else {
		reauthenticate = NO;
	}
	self.storeInKeychain = [standard objectForKey:@"storeInKeychain"];

	[self getDataFromPlist]; // Start by loading cached data.
	
	[self initiateRPC:self];
}

- (void)setKerberos:(NSNumber *)k {
	NSNumber *old = kerberos;
	kerberos = [k retain];
	[old release];
	
	if (k != nil) {
		BOOL b = ![kerberos boolValue];
		[labelPassword setTextColor:(b?[NSColor controlTextColor]:[NSColor disabledControlTextColor])];
		[labelUserName setTextColor:(b?[NSColor controlTextColor]:[NSColor disabledControlTextColor])];
		[labelDomain setTextColor:(b?[NSColor controlTextColor]:[NSColor disabledControlTextColor])];
	}
}

- (IBAction)proceedWithConnection:(id)sender {
	[credentials setNextResponder:nil];
	[NSApp endSheet:credentials returnCode:0];
}
- (IBAction)cancelConnection:(id)sender {
	[NSApp endSheet:credentials returnCode:1];
}

- (void)credentialsSheetFinished:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[credentials orderOut:self];
	
	if (returnCode == 0) {
		[self initiateRPC:self];
	}
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
	if ([anItem action] == @selector(initiateRPC:)) return (rpc == nil && ![credentials isKeyWindow]);
	if ([anItem action] == @selector(clearCredentials:)) return (rpc == nil && ![credentials isKeyWindow]);
	return NO;
}

- (IBAction)initiateRPC:(id)sender {
	
	if (server == nil || reauthenticate || (![kerberos boolValue] && (domain == nil || user == nil || password == nil))) {
		reauthenticate = NO;
		[NSApp beginSheet:credentials modalForWindow:window modalDelegate:self didEndSelector:@selector(credentialsSheetFinished:returnCode:contextInfo:) contextInfo:NULL];
		return;
	}
	
	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:5];
	
	if ([self.kerberos boolValue]) {
		[arguments addObject:@"-k"];
	} else {
		[arguments addObject:@"-U"];
		
		NSString *arg = [NSString stringWithFormat:@"%@\\%@%%%@", self.domain, self.user, self.password];
		[arguments addObject:arg];
	}
	[arguments addObject:@"-c"];
	[arguments addObject:@"dfsenum 3"];
	[arguments addObject:self.server];

#ifdef DEBUG
	NSLog(@"arguments: %@", arguments);
#endif
	
	rpc = [[NSTask alloc] init];
	rpcOutputFilePath = [[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"rpc_output.txt"] retain];
	if (![[NSFileManager defaultManager] fileExistsAtPath:rpcOutputFilePath]) {
		[[NSFileManager defaultManager] createFileAtPath:rpcOutputFilePath contents:nil attributes:nil];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rpcFinished:) name:NSTaskDidTerminateNotification object:rpc];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ASRPCClientStarting" object:nil];

//	NSString *path1 = [[NSBundle mainBundle] pathForResource:@"SampleRPCoutput" ofType:@"txt"];	
//	[rpc setArguments:[NSArray arrayWithObject:path1]];
//	[rpc setLaunchPath:@"/bin/cat"];
	[rpc setLaunchPath:@"/usr/bin/rpcclient"];
	[rpc setArguments:arguments];
	[rpc setStandardOutput: [NSFileHandle fileHandleForWritingAtPath:rpcOutputFilePath]];
	[rpc launch];
	
}

- (BOOL)getDataFromPlist {
	NSString *plistPath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"rpc_output.plist"];
#ifdef DEBUG
	NSLog(@"plist path: %@", plistPath);
#endif
	if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		return NO;
	}
	
	// Get the data.
	NSData *qData = [[NSFileHandle fileHandleForReadingAtPath:plistPath] readDataToEndOfFile];
	
	NSString *errorString = nil;
	NSDictionary *sie = [NSPropertyListSerialization propertyListFromData:qData 
														  mutabilityOption:NSPropertyListImmutable 
																	format:NULL
														  errorDescription:&errorString];
	
	// Check whether the data was valid.
	if (sie == nil || errorString != nil) {
		if (sie == nil) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid RPC response", nil) defaultButton:NSLocalizedString(@"Abort", nil) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"The response from the DFS master server could not be interpreted.", nil)];
			[alert runModal];
			
			// Log the invalid RPC response.
			
			NSLog(@"Invalid response in path: %@", rpcOutputFilePath);
		}
		if (errorString != nil) NSLog(@"Parser error: %@", errorString);
		return NO;
	}
	if ([sie objectForKey:@"Error"]) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"loginRequired"];
		reauthenticate = YES;
		
		if (python != nil) {
			// Not running on cached data.
			
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Connection error", nil) 
											 defaultButton:NSLocalizedString(@"Retry",nil) 
										   alternateButton:NSLocalizedString(@"Settings", nil) 
											   otherButton:NSLocalizedString(@"Cancel",nil) 
								 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"The connection failed due to '%@'. Do you wish to retry, reenter your connection settings, or cancel?", nil), [sie objectForKey:@"Reason"]]];
			
			[alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
		}
		
		return NO;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"DiffissNewDataAvailable" object:sie];

	return YES;
}	

- (void)rpcFinished:(NSNotification *)n {
	if ([n object] != rpc) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ASRPCClientFinished" object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:rpc];
	[rpc release];
	rpc = nil;
	
	python = [[NSTask alloc] init];
	NSPipe *output = [[NSPipe alloc] init];
	NSString *path2 = [[NSBundle mainBundle] pathForResource:@"rpc_parser" ofType:@"py"];
	[python setArguments:[NSArray arrayWithObject:path2]];
	[python setLaunchPath:@"/usr/bin/python"];
	[python setStandardInput:[NSFileHandle fileHandleForReadingAtPath:rpcOutputFilePath]];
	NSString *plistPath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"rpc_output.plist"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		[[NSFileManager defaultManager] createFileAtPath:plistPath contents:nil attributes:nil];
	}
	[python setStandardOutput:[NSFileHandle fileHandleForWritingAtPath:plistPath]];
	[python launch];
	[python waitUntilExit];
	
//	NSError *error = nil;
//	NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;	
//	NSDictionary *sie = [NSPropertyListSerialization propertyListWithData:qData options:0 format:&format error:&error];
	
	// Clean-up
//	[[NSFileManager defaultManager] removeItemAtPath:plistPath error:NULL];
	
	if ([self getDataFromPlist]) {	
		if ([self.storeInKeychain boolValue]) {
			[[NSUserDefaults standardUserDefaults] setObject:server forKey:@"server"];
			BOOL k = [self.kerberos boolValue];
			[[NSUserDefaults standardUserDefaults] setBool:k forKey:@"kerberos"];
			if (!k) {
				[[NSUserDefaults standardUserDefaults] setObject:domain forKey:@"domain"];
				[[NSUserDefaults standardUserDefaults] setObject:user forKey:@"user"];
				
				NSString *pw = [self.password retain];
				SecKeychainItemRef r = [self findPasswordInKeychain];
				if (r != NULL) {
					[self deleteFromKeychain:r];
				}
				self.password = [pw autorelease];
				[self addToKeychain];
			}
		}
		
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"loginRequired"];
		
		[[NSFileManager defaultManager] removeItemAtPath:rpcOutputFilePath error:NULL];
	}
	
	[output release];	
	[python release];
	python = nil;

	[rpcOutputFilePath release];
}
		 
- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertDefaultReturn) {
		[self initiateRPC:self];
	} else if (returnCode == NSAlertAlternateReturn) {
		[[alert window] orderOut:self];
		reauthenticate = YES;
		[self initiateRPC:self];
	}
}

- (IBAction)visitWebSite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.aderstedtsoftware.com/diffiss/index.html"]];
}

- (IBAction)clearCredentials:(id)sender {
	reauthenticate = YES;
}

@end
