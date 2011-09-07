//
//  KeychainServices.h
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-06.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DiffissAppDelegate.h"
#import <Security/Security.h>

@interface DiffissAppDelegate (KeychainServices) 

- (void)addToKeychain;
- (SecKeychainItemRef)findPasswordInKeychain;
- (void)deleteFromKeychain:(SecKeychainItemRef)r;

@end
