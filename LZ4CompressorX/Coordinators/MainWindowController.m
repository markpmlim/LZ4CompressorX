//
//  MainWindowController.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "DropViewController.h"
#import "CompressOperation.h"
#import "DecompressOperation.h"


@implementation MainWindowController
@synthesize hostView;
@synthesize compressionMethods;
@synthesize compressionFormat;
@synthesize fastCompressionSlider;
@synthesize highCompressionSlider;
@synthesize suffixTextField;
@synthesize worstCaseCheck;
@synthesize suffixStr;
@synthesize blockSizePopup;
@synthesize blockSizeLabel;
@synthesize cancelButton;
@synthesize spinner;

@synthesize blockSizeTag;
@synthesize fastCompression;
@synthesize isWorstCase;
@synthesize lz4Format;
@synthesize dropViewController;

- (id) initWithWindow:(NSWindow *)window
{
    //NSLog(@"MainWindowController");
    self = [super initWithWindow:window];
    if (self)
    {
        dropViewController = [[DropViewController alloc] init];
        [self.cancelButton setHidden:YES];
        [self.spinner setHidden:YES];
    }
    return self;
}

-(void) dealloc
{
    //NSLog(@"Deallocating window controller");
    if (dropViewController != nil)
    {
        [dropViewController release];
        dropViewController = nil;
    }
    if (suffixStr != nil)
    {
        [suffixStr release];
        suffixStr = nil;
    }
    [super dealloc];
}

- (void) awakeFromNib
{
    self.suffixStr = @"BIN";
    lz4Format = kLegacyLZ4;
    self.blockSizeTag = 4;
}

- (void) loadWindow
{
    //NSLog(@"loadWindow");
    [super loadWindow];
    [self.hostView addSubview:[dropViewController view]];
    [[self.dropViewController view] setFrame: [self.hostView bounds]];
    self.fastCompression = YES;
    [self.fastCompressionSlider setHidden:NO];
    [self.blockSizePopup setHidden:YES];
    [self.blockSizeLabel setHidden:YES];
}

// Needs to control-click drag to App delegate instance
- (IBAction) handleCompressionMethod:(id)sender
{
    NSInteger tag = [sender selectedTag];
    if (tag == 0)
    {
        //NSLog(@"high compression is off");
        self.fastCompression = YES;
        [self.fastCompressionSlider setHidden:NO];
        [self.highCompressionSlider setHidden:YES];
    }
    else if (tag == 1)
    {
        //NSLog(@"high compression is on");
        self.fastCompression = NO;
        [self.fastCompressionSlider setHidden:YES];
        [self.highCompressionSlider setHidden:NO];
    }
}

// Watch for KVO notifications about operations, specifically when they
// start executing and when they finish.
// The observer was added in the source code of DropView but we remove it here.
- (void) observeValueForKeyPath: (NSString *) keyPath
                       ofObject: (id) object
                         change: (NSDictionary *) change
                        context: (void *) context {
    
    if ([keyPath isEqualToString: @"isFinished"])
    {
        // If it's done, the file has been inflated/deflated.
    /*
        if ([object isKindOfClass:[DecompressOperation class]])
            NSLog(@"decompression");
        else
            NSLog(@"compression");
        
        NSLog(@"Finished:%@", object);
    */
        // Unhook the observation for this particular object.
        [object removeObserver: self
                    forKeyPath: @"isFinished"];
        [object removeObserver: self
                    forKeyPath: @"isExecuting"];
        AppDelegate *appDelegate = [NSApp delegate];
        if ([[appDelegate.queue operations] count] == 0)
        {
            [self.cancelButton setHidden:YES];
            [self.spinner stopAnimation:self];
            [self.spinner setHidden:YES];
        }
    }
    else if ([keyPath isEqualToString: @"isExecuting"])
    {
        DecompressOperation *op = (DecompressOperation *) object;
        // KIV. What else do we need to do here?
        //NSLog(@"still executing:%@", object);
    }
    else
    {
        // The notification is uninteresting to us, let someone else handle it.
        [super observeValueForKeyPath: keyPath
                             ofObject: object
                               change: change
                              context: context];
    }
} // observeValueForKeyPath

- (IBAction) handleCancel:(id)sender
{
    //printf("cancel button hit\n");
    AppDelegate *appDelegate = [NSApp delegate];
    if ([[appDelegate.queue operations] count] != 0)
    {
        [appDelegate.queue cancelAllOperations];
    }
    // the observeValueForKeyPath: method will take care of the appearance of the Cancel button & spinner.
}

- (IBAction) handleCompressionFormat:(id)sender
{
    self.lz4Format = [sender selectedTag];
    if (self.lz4Format == 3)
    {
        [self.blockSizePopup setHidden:NO];
        [self.blockSizeLabel setHidden:NO];
    }
    else
    {
        [self.blockSizePopup setHidden:YES];
        [self.blockSizeLabel setHidden:YES];
    }
}

- (IBAction) handleWorstCaseClick:(id)sender
{
    isWorstCase = !isWorstCase;
}

- (IBAction) handleBlockSize:(id)sender
{
    self.blockSizeTag = [[sender selectedItem] tag];
}

@end
