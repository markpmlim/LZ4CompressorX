//
//  LZ4Document.h
//  LZ4CompressorX
//
//  Created by mark lim on 5/13/18.
//
//

#import <Foundation/Foundation.h>
#include "UserDefines.h"

@interface LZ4Document : NSObject
{
	NSURL *urlOfFile;
	LZ4Format lz4Format;
	BOOL hasUncompressedSize;
	uint32_t uncompressedSize;
	uint32_t compressedSize;
	uint32_t compressedBlockCount;
}

@property (retain) NSURL *urlOfFile;
@property (assign) LZ4Format lz4Format;
@property (assign) BOOL hasUncompressedSize;
@property (assign) uint32_t uncompressedSize;
@property (assign) uint32_t compressedSize;
@property (assign) uint32_t compressedBlockCount;

- (id) initWithURL:(NSURL *)url;
- (LZ4Format) identifyFormatAtPath:(NSString *)path;
- (void) reportStatistics;
- (NSString *) stringFromSize:(uint32_t)size;
@end
