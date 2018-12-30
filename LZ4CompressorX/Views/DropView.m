//
//  DropView.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "AppDelegate.h"
#import "DropView.h"
#import "DecompressOperation.h"
#import "CompressOperation.h"
#import "MainWindowController.h"
#import "WorstCaseWindowController.h"
#include "lz4.h"

/*
 Note: An instance of NSView has access to its instance of NSWindow,
 but it cannot directly access its instance of NSViewController.
 */
@implementation DropView

@synthesize string = _string;
//@synthesize textTable;

- (id) initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // Initialization code here.
        NSFont *font = [NSFont systemFontOfSize:20];
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:font
                                                               forKey:NSFontAttributeName];
        self.string =  [[[NSAttributedString alloc] initWithString:@"Drop your files here"
                                                        attributes:attributes] autorelease];
    }
    return self;
}

- (void) dealloc
{
    self.string = nil;
    [super dealloc];
}

// overridden method.
- (void) drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor greenColor] set];
    [NSBezierPath fillRect:dirtyRect];
    
    NSRect bounds = [self bounds];
    // Center the text horizontally and vertically within the view.
    NSSize stringSize = [self.string size];
    NSPoint point;
    point.y = bounds.size.height/2 - stringSize.height/2;
    point.x = bounds.size.width/2 - stringSize.width/2;
    [self.string drawAtPoint:point];
}

// Implementation of some NSDraggingDestination protocol methods
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationEvery;
}

- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    BOOL result = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([[pboard types] containsObject:NSFilenamesPboardType])
    {
        NSFileManager *fmgr = [NSFileManager defaultManager];
        BOOL isDir;
        NSArray *paths = [pboard propertyListForType:NSFilenamesPboardType];
        AppDelegate *appDelegate = [NSApp delegate];
        MainWindowController *winCtlr = [[self window] windowController];
        NSMutableArray *filteredPaths = [NSMutableArray array];
        NSMutableArray *filteredCompressedPaths = [NSMutableArray array];
        
        for (NSString *path in paths)
        {
            // check that path is not a folder
            if ([fmgr fileExistsAtPath:path
                           isDirectory:&isDir] && isDir) {
                NSLog(@"Folder not accepted");
                continue;
            }
            LZ4Format format = [appDelegate identifyFormatAtPath:path];
                 //continue;
            if (format == kUnknownLZ4)
                // assume it's not compressed.
                [filteredPaths addObject:path];
            else
                [filteredCompressedPaths addObject:path];
        } // for

        if ([filteredCompressedPaths count] != 0)
        {
            for (NSString *path in filteredCompressedPaths)
            {
                NSURL *url = [NSURL fileURLWithPath:path];
                DecompressOperation *op = [[DecompressOperation alloc] initWithURL:url
                                                                       andDelegate:winCtlr];

                [op addObserver: (id)winCtlr
                     forKeyPath: @"isFinished"
                        options: 0  // It just changes state once, so don't
                                    // worry about what's in the notification
                        context: NULL];

                // Monitor this operation so we can update the user interface.
                [op addObserver: (id)winCtlr
                     forKeyPath: @"isExecuting"
                        options: NSKeyValueObservingOptionNew
                        context: NULL];
                [[appDelegate queue] addOperation:op];
                [op release];
            }
            [winCtlr.cancelButton setHidden:NO];
            [winCtlr.spinner setHidden:NO];
            [winCtlr.spinner startAnimation:nil];
            result = YES;
        }
        else if ([filteredPaths count] != 0)
        {
            NSFileManager *fmgr = [NSFileManager defaultManager];
            NSMutableArray *items = [NSMutableArray array];
            BOOL isWorstCase = winCtlr.isWorstCase;

            for (NSString *path in filteredPaths)
            {
                NSError *error;
                if (isWorstCase)
                {
                    error = nil;
                    NSDictionary *attr = [fmgr attributesOfItemAtPath:path
                                                                error:&error];
                    int fileSize = [attr fileSize];
                    int worstSize = LZ4_compressBound(fileSize);
                    NSString *nameStr = [NSString stringWithFormat:@"%@\n", [path lastPathComponent]];
                    NSString *sizeStr = [NSString stringWithFormat:@"%@\n", [appDelegate stringFromFileSize:fileSize]];
                    NSString *worstSizeStr = [NSString stringWithFormat:@"%@\n", [appDelegate stringFromFileSize:worstSize]];
                    NSString *compressionRateStr = [NSString stringWithFormat:@"%.2f%%\n", ((double)worstSize/(double)fileSize)*100];

                    NSArray *rowArray = [NSArray arrayWithObjects:nameStr, sizeStr, worstSizeStr, compressionRateStr, nil];
                    [items addObject:rowArray];
                }
                else
                {
                    NSURL *url = [NSURL fileURLWithPath:path];
                    CompressOperation *op = [[CompressOperation alloc] initWithURL:url
                                                                       andDelegate:winCtlr];
                    [op addObserver:(id)winCtlr
                         forKeyPath:@"isFinished"
                            options:0   // It just changes state once, so don't
                                        // worry about what's in the notification
                            context:NULL];
                    
                    // Watch for when this operation starts executing, so we can update
                    // the user interface.
                    [op addObserver:(id)winCtlr
                         forKeyPath:@"isExecuting"
                            options:NSKeyValueObservingOptionNew
                            context:NULL];
                    [[appDelegate queue] addOperation:op];
                    [op release];
                }
            }

            if (isWorstCase)
            {
                // header.
                NSString *nameHeaderStr = [NSString stringWithFormat:@"Name of File\n"];
                NSString *sizeHeaderStr = [NSString stringWithFormat:@"Original File Size\n"];
                NSString *worstSizeHeaderStr = [NSString stringWithFormat:@"Worst Case File Size\n"];
                NSString *compressionRateHeaderStr = [NSString stringWithFormat:@"Compression Rate\n"];
                NSArray *rowArray = [NSArray arrayWithObjects:nameHeaderStr, sizeHeaderStr, worstSizeHeaderStr, compressionRateHeaderStr, nil];
                [items addObject:rowArray];
                NSMutableAttributedString *attrStr = [appDelegate tableAttributedStringFromItems:items];
                WorstCaseWindowController *wcWinCtlr = [appDelegate worstCaseWinController];
                [wcWinCtlr clearTable];
                // Insert this into text view of worst case window 
                [wcWinCtlr insertTable:attrStr];
                [wcWinCtlr showWindow:nil];
            }
            else
            {
                [winCtlr.cancelButton setHidden:NO];
                [winCtlr.spinner setHidden:NO];
                [winCtlr.spinner startAnimation:nil];
            }
            result = YES;
        }
    }
    return result;
}

@end
