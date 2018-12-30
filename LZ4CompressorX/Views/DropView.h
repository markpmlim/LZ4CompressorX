//
//  DropView.h
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DropView : NSView
{
    NSAttributedString  *_string;
}

@property (retain) NSAttributedString *string;
@end
