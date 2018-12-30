//
//  WorstCaseWindowController.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "WaitWindowController.h"

@implementation WaitWindowController


- (void) dealloc 
{
    [super dealloc];
}

- (void) awakeFromNib
{
    [[self window] setReleasedWhenClosed:NO];   // don't release window's allocated resources
}

- (void) cancelOperation:(id)sender
{
    // This message should make NSApp's runModalSession method
    // return NSRunStoppedResponse (see source of AppDelegate)
    [NSApp stopModal];
}

#pragma mark window delegate method
// No problems if the modal session has already stopped.
- (void) windowWillClose:(NSNotification *)notification {
    //NSLog(@"windowWillClose stopModal");
    [NSApp stopModal];
}

@end
