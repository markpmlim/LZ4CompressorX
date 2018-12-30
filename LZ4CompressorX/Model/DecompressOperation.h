//
//  DecompressOperation.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainWindowController;
@interface DecompressOperation : NSOperation
{
    NSURL                   *_srcURL;
    MainWindowController    *_delegate;
}

@property (retain) MainWindowController *delegate;

-(id) initWithURL:(NSURL *)url
      andDelegate:(MainWindowController *)delegate;

@end
