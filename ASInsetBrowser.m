//
//  ASInsetBrowser.m
//  Diffiss
//
//  Created by Erik Aderstedt on 2009-11-26.
//  Copyright 2009 Aderstedt Software AB. All rights reserved.
//

#import "ASInsetBrowser.h"
#import "ASInsetBrowserCell.h"

@implementation ASInsetBrowser

+ (Class)cellClass {
	return [ASInsetBrowserCell class];
}

@end
