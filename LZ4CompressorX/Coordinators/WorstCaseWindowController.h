//
//  WorstCaseWindowController.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WorstCaseWindowController: NSWindowController
{
    NSTextView *txtView;
}

@property (retain) IBOutlet NSTextView  *txtView;

// public methods
- (void) clearTable;

- (void) insertTable:(NSMutableAttributedString *)attrStringToInsert;

@end
