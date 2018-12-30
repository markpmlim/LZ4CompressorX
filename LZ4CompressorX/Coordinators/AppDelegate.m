//
//  AppDelegate.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "StatisticsWindowController.h"
#import "WaitWindowController.h"
#import "WorstCaseWindowController.h"
#import "DecompressOperation.h"
#include "lz4.h"

@implementation AppDelegate
@synthesize mainWinController;
@synthesize statisticsWinController;
@synthesize waitWinController;
@synthesize worstCaseWinController;
@synthesize queue;

FILE *logFilePtr = NULL;

- (id) init
{
    //NSLog(@"min version:%d", __MAC_OS_X_VERSION_MIN_REQUIRED);
    if (NSAppKitVersionNumber < 949)
    {
        if (NSAppKitVersionNumber < 949)
            // Pop up a warning dialog, 
            NSRunAlertPanel(@"Sorry, this program requires Mac OS X 10.5 or later", @"You are running %@", 
                            @"OK", nil, nil, [[NSProcessInfo processInfo] operatingSystemVersionString]);
        // then quit the program
        [NSApp terminate:self]; 
        
    }
    self = [super init];
    if (self != nil)
    {
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    }
    return self;
}

// Not guaranteed to be called on exit.
-(void) dealloc
{
    if (queue != nil)
    {
        [queue release];
        queue = nil;
    }
    if (waitWinController != nil)
    {
        [waitWinController release];
        waitWinController = nil;
    }
    if (statisticsWinController != nil)
    {
        [statisticsWinController release];
        statisticsWinController = nil;
    }
    if (worstCaseWinController != nil)
    {
        [worstCaseWinController release];
        worstCaseWinController = nil;
    }
    if (mainWinController != nil)
    {
        [mainWinController release];
        mainWinController = nil;
    }
    
    [super dealloc];
}

// Returns the url to LZ4CompressorX's console log file.
// It will create the folder /Users/marklim/Library/"Application Support"/LZ4CompressorX
// if it does not exists.
- (NSURL *) urlOfLogFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask,
                                                         YES);
    NSString *basePath = [paths objectAtIndex:0];
    NSString *logFolder = [basePath stringByAppendingString:@"/LZ4CompressorX"];
    NSFileManager *fmgr = [NSFileManager defaultManager];
    BOOL isDir = NO;
    // Important: If the path has a trailing slash; the call below will return NO 
    // irrespective of whether or not there is a regular file at the location.
    BOOL exists = [fmgr fileExistsAtPath:logFolder
                             isDirectory:&isDir];
    if (exists == YES && isDir == NO)
    {
        NSString *message = [NSString localizedStringWithFormat:@"A file (not folder) with the name \"LZ4CompressorX\" exists at the location\n%@.", basePath];
        NSAlert *alert = [NSAlert alertWithMessageText:message
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"All messages will be send to the system log."];
        [alert runModal];
        logFilePtr = NULL;
        return nil;
    }
    else if (!exists)
    {
        //NSLog(@"Creating the Application Support folder: %@", logFolder);
        NSError *outErr = nil;
        if ([fmgr createDirectoryAtPath:logFolder
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&outErr] == NO)
        {
            NSString *message = [NSString localizedStringWithFormat:@"Creating the folder %@\n failed", logFolder];
            NSAlert *alert = [NSAlert alertWithMessageText:message
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"All messages will be send to the system log."];
            [alert runModal];
            logFilePtr = NULL;
            return nil;
        }
    }
    
    // If we get here, the folder "LZ4CompressorX" already exists or is newly-created.
    NSString *logPath = [logFolder stringByAppendingString:@"/messages.log"];
    NSURL *urlLog = [NSURL fileURLWithPath:logPath];
    return urlLog;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application 
    self.mainWinController = [[[MainWindowController alloc] initWithWindowNibName:@"MainWindow"] autorelease];
    [self.mainWinController showWindow:nil];
 
    self.worstCaseWinController = [[[WorstCaseWindowController alloc] initWithWindowNibName:@"WorstCaseWindow"] autorelease];
    // This will force the worst case window to load.
    [self.worstCaseWinController window];
    [[self.worstCaseWinController window] orderOut:nil];

    self.statisticsWinController = [[[StatisticsWindowController alloc] initWithWindowNibName:@"StatisticsWindow"] autorelease];
    // This will force the worst case window to load.
    [self.statisticsWinController window];
    [[self.statisticsWinController window] orderOut:nil];

    self.waitWinController = [[[WaitWindowController alloc] initWithWindowNibName:@"WaitWindow"] autorelease];
    // This will force the worst case window to load.
    [self.waitWinController window];
    [[self.waitWinController window] orderOut:nil];

    // Create the log file if necessary.
    NSURL *logURL = [self urlOfLogFile];
    
    if (logURL != nil)
    {
        logFilePtr = freopen([logURL.path fileSystemRepresentation], "a+", stderr);
        if (logFilePtr == NULL)
        {
            // Put up an alert here?
            NSLog(@"Could not open the console log file. All messages will be sent to system log.");
        }
    }
}


- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

/*
 Magic Number at offset 0:
 Apple: Either 0x62, 0x76, 0x34, 0x31 or 0x62, 0x76, 0x34, 0x2D (4 bytes)
        Trailing magic # at offset (EOF-4): 0x62, 0x76, 0x34, 0x24 (4 bytes)
 Brutal Deluxe: 03 21 4C 18 (4 bytes)
 Generic LZ4 Frame Format: 04 22 4D 18 (4 bytes)
 */
- (LZ4Format) identifyFormatAtPath:(NSString *)path
{
    LZ4Format format;
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];

    NSData *modernSignature = [NSData dataWithBytes:lz4FrameMagicNumber
                                             length:4];
    NSData *legacySignature = [NSData dataWithBytes:lz4LegacyMagicNumber
                                             length:4];
    NSData *appleSignature1 = [NSData dataWithBytes:appleMagicNumber1
                                             length:4];
    NSData *appleSignature2 = [NSData dataWithBytes:appleMagicNumber2
                                             length:4];
    NSData *appleSignature3 = [NSData dataWithBytes:appleMagicNumber3
                                             length:4];
    [fileHandle seekToFileOffset:0];
    NSData *leadingSignature = [fileHandle readDataOfLength:4];
    unsigned long long eof = [fileHandle seekToEndOfFile];
    [fileHandle seekToFileOffset:eof-4];
    NSData *trailingSignature = [fileHandle readDataOfLength:4];
    if ([leadingSignature isEqualToData:legacySignature])
    {
        //printf("legacy\n");
        format = kLegacyLZ4;
    }
    else if ([leadingSignature isEqualToData:modernSignature])
             
    {
        //printf("LZ4 Format\n");
        format = kFrameLZ4;
    }
    else if (([leadingSignature isEqualToData:appleSignature1] ||
              [leadingSignature isEqualToData:appleSignature2]) &&
             [trailingSignature isEqualToData:appleSignature3])
    {
        //printf("Apple\n");
        format = kAppleLZ4;
    }
    else
    {
        format = kUnknownLZ4;
    }
    [fileHandle closeFile];
    return format;
}

/*
 Accepts LZ4 compressed files via a double-click or contextual menu.
 */
- (void) application:(NSApplication *)sender
           openFiles:(NSArray *)filenames
{
    for (NSString *name in filenames)
    {
        LZ4Format format = [self identifyFormatAtPath:name];
        // KIV: support for Frame Format
        if (format == kUnknownLZ4)
        {
            // Send an error message to the log file.
            NSLog(@"The LZ4 format of %@ is unknown", name);
            continue;
        }

        NSURL *url = [NSURL fileURLWithPath:name];
        DecompressOperation *op = [[DecompressOperation alloc] initWithURL:url
                                                               andDelegate:self.mainWinController];

        [op addObserver:(id)self.mainWinController
             forKeyPath:@"isFinished"
                options:0   // It just changes state once, so don't
                            // worry about what's in the notification
                context:NULL];
        
        // Start watching when this operation begins execution, so we can update
        // the user interface.
        [op addObserver:(id)self.mainWinController
             forKeyPath:@"isExecuting"
                options:NSKeyValueObservingOptionNew
                context:NULL];

        [[self queue] addOperation:op];
        [op release];
    }
}

- (IBAction) openHelpFile:(id)sender
{
    NSString *fullPathname;
    fullPathname = [[NSBundle mainBundle] pathForResource:@"Documentation"
                                                   ofType:@"rtfd"];
    [[NSWorkspace sharedWorkspace] openFile:fullPathname];
}

// helper method
- (NSString *) stringFromFileSize:(u_int32_t)size
{
    NSString *sizeStr;
    NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [numberFormatter setMaximumFractionDigits:1];
    
    double sz;
    if (size < 1024)
    {
        sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:size]];
        sizeStr = [NSString stringWithFormat:@"%@ bytes", sizeStr];
    }
    else if (size >= 1024 && size < 1048576)
    {
        sz = (double)size/1024;
        sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
        sizeStr = [NSString stringWithFormat:@"%@ KB", sizeStr];
    }
    else if (size >= 1048576 && size < 1073741824)
    {
        sz = (double)size/1048576;
        sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
        sizeStr = [NSString stringWithFormat:@"%@ MB", sizeStr];
    }
    else
    {
        sz = (double)size/1073741824;
        sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
        sizeStr = [NSString stringWithFormat:@"%@ GB", sizeStr];
    }
    return sizeStr;
}

/*
 Internal method.
 */
- (void) addCell:(NSString *)string
         toTable:(NSTextTable *)table
             row:(int)row
          column:(int)column
    withAligment:(NSTextAlignment)textAlignment
          toText:(NSMutableAttributedString *)tableString
{
    // Create the text table block for a cell of a row, referring to the table object
    NSTextTableBlock *block = [[NSTextTableBlock alloc] initWithTable:table
                                                          startingRow:row
                                                              rowSpan:1
                                                       startingColumn:column
                                                           columnSpan:1];
    
    // Create attributes for the text block.
    NSColor *backgroundColor = [NSColor colorWithCalibratedRed:0xFF 
                                                         green:0xFF 
                                                          blue:0. 
                                                         alpha:0xFF];;
    NSColor *borderColor = [NSColor whiteColor];
    
    [block setBackgroundColor:backgroundColor];
    [block setBorderColor:borderColor];
    [block setWidth:0.0
               type:NSTextBlockAbsoluteValueType
           forLayer:NSTextBlockBorder];
    [block setWidth:2.0
               type:NSTextBlockAbsoluteValueType
           forLayer:NSTextBlockPadding];
    
    // Create a paragraph style object for the cell, setting the text block as an attribute
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setTextBlocks:[NSArray arrayWithObjects:block, nil]];
    if (row == 0)
    {
        [paragraphStyle setAlignment:NSCenterTextAlignment];
    }
    else
    {
        if (column == 0)
            [paragraphStyle setAlignment:NSLeftTextAlignment];
        else
            [paragraphStyle setAlignment:textAlignment];
    }
    
    [block release];
    
    // Create an attributed string for the cell, adding the paragraph style as an attribute.
    // The cell string must end with a paragraph marker, such as a newline character.
    NSMutableAttributedString *cellString = [[NSMutableAttributedString alloc] initWithString:string];
    [cellString addAttribute:NSParagraphStyleAttributeName
                       value:paragraphStyle
                       range:NSMakeRange(0, [cellString length])];
    [cellString addAttribute:NSForegroundColorAttributeName
                       value:[NSColor blueColor]
                       range:NSMakeRange(0, [cellString length])];
    [paragraphStyle release];
    
    // Append the cell string to the table string.
    [tableString appendAttributedString:cellString];
    [cellString release];
}

/*
 Each item in the "items" array is an instance of NSArray.
 */
- (NSMutableAttributedString *) tableAttributedStringFromItems:(NSArray *)items
{
    // Create a table object
    NSTextTable *textTable = [[[NSTextTable alloc] init] autorelease];
    // Set the # of table columns
    [textTable setNumberOfColumns:[[items objectAtIndex:0] count]];
    
    //Create an attributed string for the table.
    NSMutableAttributedString *tableString = [[NSMutableAttributedString alloc] init];
    NSUInteger r = 0;
    NSUInteger c = 0;
    NSArray *anArray;
    NSTextAlignment alignment = NSRightTextAlignment;
    
    for (anArray in items)
    {
        c = 0;
        // Step through each item and create a row from it
        for (NSString *str in anArray)
        {
            [self addCell:str
                  toTable:textTable
                      row:r
                   column:c
             withAligment:alignment
                   toText:tableString];
            c++;
        }
        r++;
    }
    return [tableString autorelease];
}

/*
 This method should return 2 values viz. the uncompressed & compressed sizes
 */
- (void) sizesFromAppleLZ4:(NSFileHandle *)fileHandle
          uncompressedSize:(uint32_t *)uncompressedSize
            compressedSize:(uint32_t *)compressedSize
{
    *uncompressedSize = 0;
    *compressedSize = 0;
    uint32_t uncompressedBlockSize = 0;
    uint32_t compressedBlockSize = 0;
    // On entry, we must set the offset to the beginning of file because
    // there are 2 magic #s, one at offset 0 and the other at offset (EOF-4).
    unsigned long long currentOffset = 0;
    BOOL atEOF = NO;
    uint32_t headerSize = 12;
    do { 
        [fileHandle seekToFileOffset:currentOffset];
        NSData *data = [fileHandle readDataOfLength:4];
        uint32_t magicNum = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
        uint32_t tmp = 0;

        if (magicNum == 0x31347662)
        {
            //printf("compressed block\n");
            data = [fileHandle readDataOfLength:4];
            tmp = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            uncompressedBlockSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            data = [fileHandle readDataOfLength:4];
            tmp = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            compressedBlockSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            *uncompressedSize += uncompressedBlockSize;
            *compressedSize += compressedBlockSize;
            currentOffset += (headerSize + compressedBlockSize);
        }
        else if (magicNum == 0x2D347662)
        {
            //printf("uncompressed block\n");
            data = [fileHandle readDataOfLength:4];
            tmp = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            uncompressedBlockSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
            compressedBlockSize = uncompressedBlockSize;
            *uncompressedSize += uncompressedBlockSize;
            *compressedSize += compressedBlockSize;
            currentOffset += (headerSize - 4 + compressedBlockSize);
        }
        else if (magicNum == 0x24347662)
        {
            //printf("Trailer\n");
            atEOF = YES;
        }
    } while (!atEOF);
}

/*
 This method returns compressed size of a Generic LZ4 file.
 */
- (uint32_t) compressedSizeOfGenericLZ4:(NSFileHandle *)fileHandle
                             headerSize:(uint32_t)startingOffset
                          blockCheckSum:(BOOL)hasBCS
{
    // On entry, original uncompressed file size is already read.
    uint32_t compressedSize = 0;
    uint32_t compressedBlockSize = 0;
    unsigned long long currentOffset = startingOffset;
    BOOL isEOM = NO;
    do {
        [fileHandle seekToFileOffset:currentOffset];
        NSData *data = [fileHandle readDataOfLength:4];
        compressedBlockSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
        if (compressedBlockSize != 0)
        {
            // is the block uncompressed?
            if (compressedBlockSize & 0x80000000)
                compressedBlockSize &= 0x7fffffff;      // yes
            compressedSize += compressedBlockSize;
            currentOffset += (4 + compressedBlockSize);
            // block checksum?
            currentOffset += hasBCS ? 4 : 0;
        }
        else
        {
            isEOM = YES;
        }
    } while (!isEOM);
    return compressedSize;
}

/*
 Apple LZ4 files - scan the entire file to copy the uncompressed
 size of each block.
 Legacy LZ4 file - original uncompressed file size is at offset 4.
 Generic LZ4 file - must have the optional original file size present.
 */
- (IBAction) reportStatistics:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    op.canChooseFiles = YES;
    op.canChooseDirectories = NO;
    op.allowsMultipleSelection = YES;
    op.canCreateDirectories = NO;

    NSInteger buttonID = [op runModal];
    if (buttonID == NSFileHandlingPanelOKButton)
    {
        [self.statisticsWinController clearTable];
        NSMutableArray *filterCompressedPaths = [NSMutableArray array];
        for (NSURL *url in op.URLs)
        {
            LZ4Format format = [self identifyFormatAtPath:url.path];
            BOOL isLZ4Compressed = (format == kAppleLZ4) || (format == kLegacyLZ4) || (format == kFrameLZ4);
            if (isLZ4Compressed)
                [filterCompressedPaths addObject:url];
        }

        int lzVersion = LZ4_versionNumber();
        if (filterCompressedPaths.count != 0)
        {
            NSModalSession session = [NSApp beginModalSessionForWindow:[self.waitWinController window]];
            BOOL isCancelled = NO;
            
            // setup the headers of the Compression Statistics table.
            NSString *nameHeaderStr = [NSString stringWithFormat:@"Name of File\n"];
            NSString *sizeHeaderStr = [NSString stringWithFormat:@"Original File Size\n"];
            NSString *compressedSizeHeaderStr = [NSString stringWithFormat:@"Compressed File Size\n"];
            NSString *compressionRateHeaderStr = [NSString stringWithFormat:@"Compression Rate\n"];
            NSMutableArray *items = [NSMutableArray array];
            NSArray *rowArray = [NSArray arrayWithObjects:nameHeaderStr, sizeHeaderStr, compressedSizeHeaderStr, compressionRateHeaderStr, nil];
            [items addObject:rowArray];
            NSMutableAttributedString *attrStr = [self tableAttributedStringFromItems:items];
            for (NSURL *url in filterCompressedPaths)
            {
                NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:url.path];
                NSData *modernSignature = [NSData dataWithBytes:lz4FrameMagicNumber
                                                         length:4];
                NSData *legacySignature = [NSData dataWithBytes:lz4LegacyMagicNumber
                                                         length:4];
                NSData *appleSignature1 = [NSData dataWithBytes:appleMagicNumber1
                                                         length:4];
                NSData *appleSignature2 = [NSData dataWithBytes:appleMagicNumber2
                                                         length:4];
                [fileHandle seekToFileOffset:0];
                NSData *leadingSignature = [fileHandle readDataOfLength:4];
                uint32_t uncompressedSize = 0;
                uint32_t compressedSize = 0;
                if ([leadingSignature isEqualToData:legacySignature])
                {
                    NSData *data = [fileHandle readDataOfLength:4];
                    uncompressedSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
                    [fileHandle seekToFileOffset:12];
                    data = [fileHandle readDataOfLength:4];
                    compressedSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
                }
                else if ([leadingSignature isEqualToData:appleSignature1] || [leadingSignature isEqualToData:appleSignature2])
                {
                    // Scan the entire LZ4 file.
                    [self sizesFromAppleLZ4:fileHandle
                           uncompressedSize:&uncompressedSize
                             compressedSize:&compressedSize];
                }
                else if ([leadingSignature isEqualToData:modernSignature])
                {
                    if (lzVersion < 10701)
                    {
                        // Record the error message in the log file.
                        NSLog(@"Sorry, the file %@ must be compressed with LZ4 version 1.7.1 or later", url.path);
                        continue;
                    }
                    NSData *data = [fileHandle readDataOfLength:1];
                    uint8_t frameFlag = *(uint8_t *)data.bytes;
                    if (frameFlag & 0x08)
                    {
                        // The original uncompressed file size is present.
                        [fileHandle seekToFileOffset:6];
                        data = [fileHandle readDataOfLength:8];
                        uncompressedSize = *(uint32_t *)data.bytes;
                        //printf("uncompress size:%u\n", uncompressedSize);
                        //printf("iterating to get compressed sizes\n");
                        // ver 1.8 or 1.7?
                        uint32_t headerSize = (frameFlag & 0x01) ? 19 : 15;
                        // block checksum after compressed block size is present.
                        BOOL hasBlockCheckSum = (frameFlag & 0x10) ? YES : NO;
                        //printf("headerSize %u\n", headerSize);
                        compressedSize = [self compressedSizeOfGenericLZ4:fileHandle
                                                               headerSize:headerSize
                                                            blockCheckSum:hasBlockCheckSum];
                    }
                    else
                    {
                        NSLog(@"Original (uncompressed) file size not present");
                        continue;
                    }
                }

                [fileHandle closeFile];
                NSString *nameStr = [NSString stringWithFormat:@"%@\n", [url.path lastPathComponent]];
                NSString *sizeStr = [NSString stringWithFormat:@"%@\n", [self stringFromFileSize:uncompressedSize]];
                NSString *compressedSizeStr = [NSString stringWithFormat:@"%@\n", [self stringFromFileSize:compressedSize]];
                NSString *compressionRateStr = [NSString stringWithFormat:@"%.2f%%\n", ((double)compressedSize/(double)uncompressedSize)*100];
                NSArray *rowArray = [NSArray arrayWithObjects:nameStr, sizeStr, compressedSizeStr, compressionRateStr, nil];
                [items addObject:rowArray];

                [[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
                if ([NSApp runModalSession:session] != NSRunContinuesResponse)
                {
                    // Forced exit from the for loop.
                    isCancelled = YES;
                    break;
                }
            } // for

            [NSApp endModalSession:session];
            [[self.waitWinController window] orderOut:self];
            if (!isCancelled)
            {
                attrStr = [self tableAttributedStringFromItems:items];
                [self.statisticsWinController appendTable:attrStr];
                [self.statisticsWinController showWindow:nil];
            }
        } // if
    }
}

- (IBAction) showLogs:(id)sender
{
    if (logFilePtr != NULL)
    {
        fflush(logFilePtr);
        NSURL *consoleURL = [self urlOfLogFile];
        NSString *logFilePath = consoleURL.path;
        // We assume nobody gets funny and remove the log file while
        // the program is executing.
        [[NSWorkspace sharedWorkspace] openFile:logFilePath
                                withApplication:@"Console.app"];
    }
}

- (IBAction) clearLogs:(id)sender
{
    if (logFilePtr != NULL)
    {
        fflush(logFilePtr);
        rewind(logFilePtr);
        ftruncate(fileno(logFilePtr), 0);
    }
}
@end
