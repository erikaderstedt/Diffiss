//
//  BrowserController.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-04.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "BrowserController.h"
#import "ASInsetBrowser.h"
#import "ASInsetBrowserCell.h"

@implementation BrowserController

@synthesize rpc;

- (void)awakeFromNib {
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:@"DiffissNewDataAvailable" object:nil];
	
	// Load image.
	folderIcon = [[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"folder_closed_16x16" ofType:@"png"]]];
	openFolderIcon = [[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"folder_open_16x16" ofType:@"png"]]];
	shareIcon = [[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"share1_16x16" ofType:@"png"]]];
				  
	[browser setTarget:self];
	[browser setDoubleAction:@selector(doubleClick:)];
	ASInsetBrowserCell *prototype = [[ASInsetBrowserCell alloc] initTextCell:@""];
	[browser setCellPrototype:prototype];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[rpc release];
	[folderIcon release];
	[shareIcon release];
	[super dealloc];
}

- (void)refresh:(NSNotification *)n {
	self.rpc = [n object];
		
	[browser reloadColumn:0];
}

- (NSDictionary *)selectedItem {
	NSInteger selectedColumn = [browser selectedColumn];
	if (selectedColumn != -1) {
		NSDictionary *s = [self parentNodeForColumn:selectedColumn];
		NSArray *subnodes = [s valueForKey:@"subnodes"];
		NSDictionary *d = [subnodes objectAtIndex:[browser selectedRowInColumn:selectedColumn]];
		
		return d;
	}		
	return nil;
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem {
	if ([anItem action] == @selector(doubleClick:)) {
		NSDictionary *d = [self selectedItem];
		return (d != nil && [d valueForKey:@"subnodes"] == nil);
	}
	return NO;
}

+ (NSString *)convertStringToUTF8Mac:(NSString *)s {
	NSString *decomposed = [s decomposedStringWithCanonicalMapping];
	
	/*	Å=A%CC%8A
	 å=a%CC%8A
	 
	 Ä=A%CC%88
	 ä=a%CC%88
	 
	 Ö=O%CC%88
	 ö=o%CC%88
	 */	
	char *buffer1, *buffer2;
	int length = [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 2;
	buffer1 = calloc(1, length);
	buffer2 = calloc(1, length * 3);

	NSData *d1 = [decomposed dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	[d1 getBytes:buffer1 length:length];
	buffer1[[d1 length]] = 0;
	int i, j;
	for (i = j = 0; buffer1[i]; i++) {
		if (buffer1[i] < 0) {
			j += sprintf(buffer2 + j, "%%%2X", (unsigned char)buffer1[i]);
		} else {
			buffer2[j++] = buffer1[i];
		}
	}
	buffer2[j] = 0;
	NSString *result = [NSString stringWithCString:buffer2 encoding:NSASCIIStringEncoding];
	free(buffer1); free(buffer2);
	return result;
}

- (IBAction)doubleClick:(id)sender {
	NSDictionary *d = [self selectedItem];
	if (d != nil && [d valueForKey:@"subnodes"] == nil) {
		// Leaf.
		NSArray *shares = [d valueForKey:@"shares"];
		if (shares == nil || [shares count] == 0) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"No service", nil) defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"There is no service at the requested location.", nil)];
			[alert runModal];
		} else {
			NSDictionary *share1 = [shares objectAtIndex:0];
			NSString *urlString = [NSString stringWithFormat:@"smb://%@/%@", [share1 valueForKey:@"server"], [share1 valueForKey:@"share"]];
//			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
			
			// Replace åäö in share names
			urlString = [BrowserController convertStringToUTF8Mac:urlString];
			
			NSDictionary *errorDict;
			NSString *source = [NSString stringWithFormat:@"tell application \"Finder\" to open location \"%@\"", urlString];
			NSLog(@"Applescript connection source: '%@'", source);
			NSAppleScript *aScript = [[NSAppleScript alloc] initWithSource:source];
			[aScript executeAndReturnError:&errorDict];
			[aScript release];
		}
	}
}

- (NSDictionary *)parentNodeForColumn:(NSInteger)column {
	if (column == 0) return rpc;
	
    // Walk up to this column, finding the selected row in the column before it and using that in the children array
	NSDictionary *s = rpc;
    for (NSInteger i = 0; i < column; i++) {
        NSInteger selectedRowInColumn = [browser selectedRowInColumn:i];
		s = [[s valueForKey:@"subnodes"] objectAtIndex:selectedRowInColumn];
    }
    
	return s;
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column {
	NSDictionary *s = [self parentNodeForColumn:column];
	NSArray *subnodes;
	int numNodes = 0;
	if ((subnodes = [s valueForKey:@"subnodes"])) numNodes = [subnodes count];
	return numNodes;
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(NSBrowserCell *)cell atRow:(NSInteger)row column:(NSInteger)column {
    // Lazily setup the cell's properties in this method
	NSDictionary *s = [self parentNodeForColumn:column];
	NSArray *subnodes = [s valueForKey:@"subnodes"];
	NSAssert(subnodes, @"What? No subnodes?");
	
	NSDictionary *subnode = [subnodes objectAtIndex:row];
	[cell setTitle:[subnode valueForKey:@"path"]];

	[cell setLeaf:![subnode valueForKey:@"subnodes"]];
	if (![cell isLeaf]) {
		[cell setImage:folderIcon]; 
		[cell setAlternateImage:openFolderIcon]; 
	} else {
		[cell setImage:shareIcon];
		[cell setAlternateImage:nil];
	}
}

@end
