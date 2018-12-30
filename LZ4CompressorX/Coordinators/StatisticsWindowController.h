//
//  WorstCaseWindowController.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StatisticsWindowController: NSWindowController
{
    NSTextView *txtView;
}

@property (retain) IBOutlet NSTextView *txtView;

// public methods
- (void) clearTable;

- (void) appendTable:(NSMutableAttributedString *)attrStringToInsert;

@end
