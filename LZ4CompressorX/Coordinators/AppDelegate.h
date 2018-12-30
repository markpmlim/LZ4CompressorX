//
//  AppDelegate.h
//  LZ4AppleIIGraphics
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "UserDefines.h"

// Forward declarations of the following classes.
@class MainWindowController;
@class StatisticsWindowController;
@class WaitWindowController;
@class WorstCaseWindowController;

@interface AppDelegate : NSObject
{
    // Instance variables; these objects are instantiated by the
    // applicationDidFinishLaunching method.
    MainWindowController        *mainWinController;
    StatisticsWindowController  *statisticsWinController;
    WaitWindowController        *waitWinController;
    WorstCaseWindowController   *worstCaseWinController;
    NSOperationQueue            *queue;
    
}

@property (retain) MainWindowController         *mainWinController;
@property (retain) StatisticsWindowController   *statisticsWinController;
@property (retain) WaitWindowController         *waitWinController;
@property (retain) WorstCaseWindowController    *worstCaseWinController;
@property (retain) NSOperationQueue             *queue;

// Public methods
- (IBAction) openHelpFile:(id)sender;
- (IBAction) showLogs:(id)sender;
- (IBAction) clearLogs:(id)sender;
- (IBAction) reportStatistics:(id)sender;
- (LZ4Format) identifyFormatAtPath:(NSString *)path;
- (NSString *) stringFromFileSize:(u_int32_t)size;
- (NSMutableAttributedString *) tableAttributedStringFromItems:(NSArray *)items;

@end
