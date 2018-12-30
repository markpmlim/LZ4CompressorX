//
//  WorstCaseWindowController.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WaitWindowController: NSWindowController
{
}

// overridden NSResponder method.
- (void) cancelOperation:(id)sender;

@end
