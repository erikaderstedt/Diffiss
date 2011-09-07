//
//  ProgressIndicatorToolbarItem.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-06.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "ProgressIndicatorToolbarItem.h"


@implementation ProgressIndicatorToolbarItem

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startPi:) name:@"ASRPCClientStarting" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopPi:) name:@"ASRPCClientFinished" object:nil];	
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)startPi:(NSNotification *)n {
	[self setLabel:@"Searching..."];
	[(NSProgressIndicator *)[self view] startAnimation:self];
}

- (void)stopPi:(NSNotification *)n {
	[self setLabel:nil];
	[(NSProgressIndicator *)[self view] stopAnimation:self];
}

@end


