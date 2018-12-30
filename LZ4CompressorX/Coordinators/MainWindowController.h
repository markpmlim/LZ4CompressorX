//
//  MainWindowController.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "UserDefines.h"

@class DropViewController;

@interface MainWindowController : NSWindowController {
//  IBOutlet NSWindow   *window;        
    NSView              *hostView;      
    NSMatrix            *compressionMethods;
    NSMatrix            *compressionFormat;
    NSSlider            *fastCompressionSlider;
    NSSlider            *highCompressionSlider;
    NSButton            *worstCaseCheck;
    NSTextField         *suffixTextField;
    NSString            *suffixStr;
    NSPopUpButton       *blockSizePopup;
    NSTextField         *blockSizeLabel;
    NSButton            *cancelButton;
    NSProgressIndicator *spinner;
    NSUInteger          blockSizeTag;
    BOOL                fastCompression;
    BOOL                isWorstCase;
    LZ4Format           lz4Format;
    DropViewController  *dropViewController;
}

@property (assign) IBOutlet NSView              *hostView;      
@property (assign) IBOutlet NSMatrix            *compressionMethods;
@property (assign) IBOutlet NSMatrix            *compressionFormat;
@property (assign) IBOutlet NSSlider            *fastCompressionSlider;
@property (assign) IBOutlet NSSlider            *highCompressionSlider;
@property (assign) IBOutlet NSButton            *worstCaseCheck;
@property (assign) IBOutlet NSTextField         *suffixTextField;
@property (assign) IBOutlet NSPopUpButton       *blockSizePopup;
@property (assign) IBOutlet NSTextField         *blockSizeLabel;
@property (assign) IBOutlet NSButton            *cancelButton;
@property (assign) IBOutlet NSProgressIndicator *spinner;
@property (assign)          NSUInteger          blockSizeTag;
@property (assign)          BOOL                fastCompression;
@property (assign)          BOOL                isWorstCase;
@property (copy)            NSString            *suffixStr;
@property (assign)          LZ4Format           lz4Format;
@property (retain) DropViewController           *dropViewController;

- (IBAction) handleCancel:(id)sender;
- (IBAction) handleCompressionMethod:(id)sender;
- (IBAction) handleCompressionFormat:(id)sender;
- (IBAction) handleWorstCaseClick:(id)sender;
- (IBAction) handleBlockSize:(id)sender;

@end
