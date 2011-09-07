//
//  KeychainServices.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-06.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "KeychainServices.h"

@implementation DiffissAppDelegate (KeychainServices)

- (void)addToKeychain {
	NSString *serviceName = [NSString stringWithFormat:@"DFS at %@ domain %@", server, domain];
	OSStatus result;
	result = SecKeychainAddGenericPassword(NULL, [serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [serviceName cStringUsingEncoding:NSUTF8StringEncoding], 
								  [user lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [user cStringUsingEncoding:NSUTF8StringEncoding], 
								  [password lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [password cStringUsingEncoding:NSUTF8StringEncoding], NULL);
	if (result != 0) {
		CFStringRef errorString = SecCopyErrorMessageString(result, NULL);
		NSLog(@"Keychain adding error: %@", errorString);
		CFRelease(errorString);
	}
}

- (SecKeychainItemRef)findPasswordInKeychain {
	NSString *serviceName = [NSString stringWithFormat:@"DFS at %@ domain %@", server, domain];
	UInt32 pwLen;
	char *pwData;
	SecKeychainItemRef item;
	OSStatus result;
	
	result = SecKeychainFindGenericPassword(NULL, [serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [serviceName cStringUsingEncoding:NSUTF8StringEncoding], 
									   [user lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [user cStringUsingEncoding:NSUTF8StringEncoding],  
											&pwLen, (void **)&pwData, &item);
	if (result == 0) {
		self.password = [[[NSString alloc] initWithBytes:pwData length:pwLen encoding:NSUTF8StringEncoding] autorelease];
		SecKeychainItemFreeContent(NULL, pwData);
		return item;
	} else {
		CFStringRef errorString = SecCopyErrorMessageString(result, NULL);
		NSLog(@"Keychain find error: %@", errorString);
		CFRelease(errorString);
	}
	
	self.password = nil;
	return NULL;
}

- (void)deleteFromKeychain:(SecKeychainItemRef)r {
	SecKeychainItemDelete(r);
}

@end
