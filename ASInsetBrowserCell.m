//
//  ASInsetBrowserCell.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-26.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "ASInsetBrowserCell.h"

#define LogR(t,z) NSLog(@"%@: {{%.0f, %.0f}, {%.0f, %.0f}}", t, z.origin.x, z.origin.y, z.size.width, z.size.height)

@implementation ASInsetBrowserCell

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)v {
	float yInset = 0.0;
	frame = NSInsetRect(frame, 2.0, yInset);
	[super drawInteriorWithFrame:frame inView:v];
}

@end
