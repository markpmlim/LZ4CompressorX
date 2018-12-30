//
//  WorstCaseWindowController.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "WorstCaseWindowController.h"

@implementation WorstCaseWindowController

@synthesize txtView;


- (void) dealloc 
{
    if (txtView != nil)
    {
        [txtView release];
        txtView = nil;
    }
    [super dealloc];
}

- (void) awakeFromNib
{
    [[self window] setReleasedWhenClosed:NO];   // don't release window's allocated resources
}

- (void) clearTable
{
    NSTextStorage *myTextStorage = [txtView textStorage];
    NSUInteger len = myTextStorage.length;
    if (len > 0)
    {
        NSRange charRange = NSMakeRange(0, len);
        [myTextStorage deleteCharactersInRange:charRange];
    }
}

- (void) insertTable:(NSMutableAttributedString *)attrStringToInsert
{
    NSTextStorage *myTextStorage = [txtView textStorage];
    [myTextStorage setAttributedString:attrStringToInsert];
    [txtView didChangeText];
}

@end
