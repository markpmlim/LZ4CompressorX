//
//  WorstCaseWindowController.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "StatisticsWindowController.h"

@implementation StatisticsWindowController

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

- (void) appendTable:(NSMutableAttributedString *)attrStringToAdd
{
    NSRange charRange = [txtView rangeForUserTextChange];
    NSTextStorage *myTextStorage = [txtView textStorage];

    if ([txtView isEditable] && charRange.location != NSNotFound)
    {
        if ([txtView shouldChangeTextInRange:charRange
                           replacementString:nil])
        {
        /*  //NSLog(@"insert:%@", attrStringToInsert);
            [myTextStorage replaceCharactersInRange:charRange
                               withAttributedString:attrStringToInsert];
        */
            [myTextStorage appendAttributedString:attrStringToAdd];
            [txtView setSelectedRange:NSMakeRange(charRange.location, 0)
                             affinity:NSSelectionAffinityDownstream
                       stillSelecting:NO];
            [txtView didChangeText];
        }
    }
}

@end
