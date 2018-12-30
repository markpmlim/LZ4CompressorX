//
//  DropView.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "DropViewController.h"

@implementation DropViewController
- (id) init
{
    //NSLog(@"DropViewController");
    self = [super initWithNibName:@"DropView"
                           bundle:nil];
    return self;
}

- (void) loadView
{
    //NSLog(@"loadView");
    [super loadView];
    NSArray *draggedTypes = [NSArray arrayWithObjects:
                                 NSFilenamesPboardType,         // Drag from Finder
                                 nil];
    // View controllers have an built-in outlet for their managed view.
    [self.view registerForDraggedTypes:draggedTypes];
}

@end
