//
//  BrowserController.h
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-04.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BrowserController : NSObject {
	NSDictionary *rpc;
	
	NSImage *folderIcon, *shareIcon, *openFolderIcon;
	
	IBOutlet NSBrowser *browser;
}
@property(retain) NSDictionary *rpc;

- (NSDictionary *)selectedItem;
- (NSDictionary *)parentNodeForColumn:(NSInteger)column;

- (IBAction)doubleClick:(id)sender;

+ (NSString *)convertStringToUTF8Mac:(NSString *)s;

@end
