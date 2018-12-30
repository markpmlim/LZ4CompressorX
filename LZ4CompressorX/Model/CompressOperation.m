//
//  CompressOperation.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//  This is where the fun (or hair-pulling) starts.

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "StatisticsWindowController.h"
#import "CompressOperation.h"
#include "lz4.h"
#include "lz4hc.h"
#include "lz4frame.h"

// Brutal Deluxe's header
static uint8_t legacyHeader[] =
{
    0x03,0x21,0x4C,0x18,        // legacy format
    0x00,0x00,0x00,0x00,        // original size
    0x00,0x00,0x00,0x4D,
    0x00,0x00,0x00,0x00         // compressed size
};

static const uint32_t legacyHeaderSize = sizeof(legacyHeader);

const uint8_t lz4FrameMagicNumber[4] = {
    0x04,0x22,0x4D,0x18,        // LZ4 Frame Format
};

const uint8_t lz4LegacyMagicNumber[4] = {
    0x03,0x21,0x4C,0x18,        // LZ4 Frame Format
};

const uint8_t appleMagicNumber1[] = {0x62, 0x76, 0x34, 0x31};
const uint8_t appleMagicNumber2[] = {0x62, 0x76, 0x34, 0x2D};
const uint8_t appleMagicNumber3[] = {0x62, 0x76, 0x34, 0x24};


@implementation CompressOperation

@synthesize delegate = _delegate;

- (id) initWithURL:(NSURL *)url
       andDelegate:(MainWindowController *)delegate
{
    self = [super init];
    if (self)
    {
        _srcURL = [url retain];
        self.delegate = delegate;
    }
    return self;
}

- (void) dealloc
{
    if (_srcURL != nil)
    {
        [_srcURL release];
        _srcURL = nil;
    }
    if (_delegate != nil)
    {
        [_delegate release];
        _delegate = nil;
    }
    [super dealloc];
}

// Check for cancellation
- (void) compress
{
    NSFileManager *fmgr = [NSFileManager defaultManager];
    NSError *err = nil;
    NSDictionary *fileAttr = [fmgr attributesOfItemAtPath: _srcURL.path
                                                    error:&err];
    size_t sourceSize = (size_t)[fileAttr fileSize];
    if (sourceSize > LZ4_MAX_INPUT_SIZE)
    {
        NSLog(@"File Size of %@ is too big", _srcURL.path);
        goto bailOut;
    }
    NSData *originalData = [NSData dataWithContentsOfURL:_srcURL
                                                 options:NSMappedRead
                                                   error:&err];
    NSMutableData *compressedData = nil;
    LZ4Format format = self.delegate.lz4Format;
    if ([self isCancelled])
    {
        goto bailOut;
    }

    BOOL didCancelled = NO;
    if (format == kFrameLZ4)
    {
        size_t maxDestSize = LZ4F_compressBound(sourceSize, NULL);
        //printf("max size:%lu\n", maxDestSize);
        void *outBuffer = malloc(maxDestSize);
        LZ4F_preferences_t prefs;
        memset(&prefs, 0, sizeof(LZ4F_preferences_t));
        // Note: multiple blocks will be used if "sourceSize" > maxBlockSize
        // Valid values of blockSizeTag = 4, 5, 6, 7
        prefs.frameInfo.blockSizeID = self.delegate.blockSizeTag;
        // "blockMode" will be changed by LZ4F_compressFrame function if necessary.
        prefs.frameInfo.blockMode = LZ4F_blockLinked;   // LZ4F_blockIndependent
        prefs.frameInfo.contentChecksumFlag = LZ4F_contentChecksumEnabled;
        prefs.frameInfo.frameType = LZ4F_frame;
        prefs.frameInfo.contentSize = sourceSize;
        prefs.autoFlush = 1;                // always 1
        NSInteger level = [[self.delegate highCompressionSlider] integerValue];
        prefs.compressionLevel = level;     // compressionLevel

        size_t outSize = LZ4F_compressFrame(outBuffer, maxDestSize, originalData.bytes, sourceSize, &prefs);
        if (LZ4F_isError(outSize))
        {
            const char* errStr = LZ4F_getErrorName(outSize);
            NSLog(@"Frame compression of %@ failed with error:%s", _srcURL.path, errStr);
            free(outBuffer);
            return;
        }
        if ([self isCancelled] == NO)
        {
            compressedData = [NSMutableData dataWithBytesNoCopy:outBuffer
                                                         length:outSize];
        }
        else
        {
            //printf("Compression: Generic Format cancelled\n");
            didCancelled = YES;
        }
    } // modern generic format
    else if (format == kLegacyLZ4)
    {
        // maxDestSize should be obtained using LZ4_compressBound(sourceSize)
        // use a 16-byte header
        uint32_t maxDestSize = (uint32_t)(legacyHeaderSize + LZ4_compressBound(sourceSize));
        //printf("%ld %ld %ld\n", legacyHeaderSize,sourceSize, maxDestSize);
        
        char *outBuffer = (char *)malloc(maxDestSize);
        memcpy(outBuffer, legacyHeader, legacyHeaderSize);
        uint32_t tmp = NSSwapHostIntToLittle(sourceSize);
        memcpy(outBuffer+4, &tmp, sizeof(uint32_t));
        int outSize = 0;

        if ([self.delegate fastCompression])
        {
            // Values <= 0 will be set to 1 --> LZ4_compress_default; we don't have
            // to change the value of accel to 1
            NSInteger accel = [[self.delegate fastCompressionSlider] integerValue];
            // The max value of accel needs to be determined manually.
            //NSLog(@"Fast Compression value:%ld", accel);
            outSize = LZ4_compress_fast(originalData.bytes,
                                        outBuffer+legacyHeaderSize,
                                        sourceSize,
                                        maxDestSize,
                                        (int)accel);
            if (outSize < 0)
            {
                NSLog(@"Fast Compression of %@ failed", _srcURL.path);
                free(outBuffer);
                return;
            }
            tmp = NSSwapHostIntToLittle(outSize);
            memcpy(outBuffer+12, &tmp, sizeof(uint32_t));
            //printf("Fast Compression was successful:%ld\n", outSize);
        }
        else
        {
            // Valid values: 0 - 16; 0 means default which is 9 - the called function
            // will do the needful. We don't have to do anything.
            NSInteger level = [[self.delegate highCompressionSlider] integerValue];
            //printf("high compression value:%ld\n", level);
            outSize = LZ4_compress_HC(originalData.bytes,
                                      outBuffer+legacyHeaderSize,
                                      sourceSize,
                                      maxDestSize,
                                      (int)level);
            if (outSize < 0)
            {
                free(outBuffer);
                NSLog(@"High Compression of %@ failed", _srcURL.path);
                return;
            }
            tmp = NSSwapHostIntToLittle(outSize);
            memcpy(outBuffer+12, &tmp, sizeof(uint32_t));
            //printf("high Compression was successful: %ld\n", outSize);
        }
        if ([self isCancelled] == NO)
        {
            // Use NSMutableData in case we want to support Apple's LZ4 format.
            compressedData = [NSMutableData dataWithBytesNoCopy:outBuffer
                                                         length:outSize+legacyHeaderSize];
        }
        else
        {
            //printf("Compression:Legacy Format cancelled\n");
            didCancelled = YES;
        }
    } // legacy format
    else if (format == kAppleLZ4)
    {
        uint32_t maxDestSize = (uint32_t)LZ4_compressBound(sourceSize);
        uint8 *outBuffer = (uint8 *)malloc(maxDestSize);
        bzero(outBuffer, maxDestSize);
        int outSize = 0;
        uint32_t bytesRemaining = sourceSize;
        uint8 *srcBegin = (uint8 *)originalData.bytes;
        uint8 *srcPtr = srcBegin;
        uint8 *srcEnd = srcBegin + sourceSize;
        NSInteger level = [[self.delegate highCompressionSlider] integerValue];
        NSInteger accel = [[self.delegate fastCompressionSlider] integerValue];
        uint32_t totalOutputBlocks = 0;
        compressedData = [NSMutableData data];
        uint8 *destPtr = outBuffer;
        NSData *appleSignature1 = [NSData dataWithBytes:appleMagicNumber1
                                                 length:4];
        NSData *appleSignature2 = [NSData dataWithBytes:appleMagicNumber2
                                                 length:4];
        NSData *appleSignature3 = [NSData dataWithBytes:appleMagicNumber3
                                                 length:4];
        while (srcPtr < srcEnd)
        {
            if (self.isCancelled)
            {
                //printf("Compression:Apple Format cancelled\n");
                didCancelled = YES;
                break;
            }
            if (bytesRemaining > sixtyFourK)
            {
                if ([self.delegate fastCompression])
                {
                    outSize = LZ4_compress_fast(srcPtr,
                                                destPtr,
                                                sixtyFourK,
                                                maxDestSize-outSize,
                                                (int)accel);
                }
                else
                {
                    outSize = LZ4_compress_HC(srcPtr,
                                              destPtr,
                                              sixtyFourK,
                                              maxDestSize-outSize,
                                              (int)level);
                    
                }
                if (outSize < 0)
                {
                    NSLog(@"Could not compress block %u of file:%@", totalOutputBlocks, _srcURL.path);
                    compressedData = nil;
                    break;
                }
                NSData *dataChunk = [NSData dataWithBytes:destPtr
                                                   length:outSize];
                NSData *uncompressedSizeData = nil;
                NSData *compressedSizeData = nil;
                uint8_t size[4] = {0};
                if (outSize == sixtyFourK)
                {
                    // block was not compressed
                    //printf("block remained uncompressed\n");
                    size[0] = (outSize & 0x000000ff);
                    size[1] = ((outSize & 0x0000ff00) >> 8);
                    size[2] = ((outSize & 0x00ff0000) >> 16);
                    size[3] = ((outSize & 0xff000000) >> 24);
                    uncompressedSizeData = [NSData dataWithBytes:size
                                                          length:4];
                    [compressedData appendData:appleSignature2];
                    [compressedData appendData:uncompressedSizeData];
                    [compressedData appendData:dataChunk];
                }
                else
                {
                    // block was compressed
                    //printf("block was compressed\n");
                    size[0] = (sixtyFourK & 0x000000ff);
                    size[1] = ((sixtyFourK & 0x0000ff00) >> 8);
                    size[2] = ((sixtyFourK & 0x00ff0000) >> 16);
                    size[3] = ((sixtyFourK & 0xff000000) >> 24);
                    uncompressedSizeData = [NSData dataWithBytes:size
                                                          length:4];
                    size[0] = (outSize & 0x000000ff);
                    size[1] = ((outSize & 0x0000ff00) >> 8);
                    size[2] = ((outSize & 0x00ff0000) >> 16);
                    size[3] = ((outSize & 0xff000000) >> 24);
                    compressedSizeData = [NSData dataWithBytes:size
                                                        length:4];
                    [compressedData appendData:appleSignature1];
                    [compressedData appendData:uncompressedSizeData];
                    [compressedData appendData:compressedSizeData];
                    [compressedData appendData:dataChunk];
                }
                totalOutputBlocks++;
                srcPtr += sixtyFourK;
                destPtr += outSize;
                bytesRemaining -= sixtyFourK;
            }
            else
            {
                if ([self.delegate fastCompression])
                {
                    outSize = LZ4_compress_fast(srcPtr,
                                                destPtr,
                                                bytesRemaining,
                                                maxDestSize-outSize,
                                                (int)accel);
                }
                else
                {
                    outSize = LZ4_compress_HC(srcPtr,
                                              destPtr,
                                              bytesRemaining,
                                              maxDestSize-outSize,
                                              (int)level);
                }
                if (outSize < 0)
                {
                    NSLog(@"Could not compress block %u of file:%@", totalOutputBlocks, _srcURL.path);
                    compressedData = nil;
                    break;
                }
                NSData *dataChunk = [NSData dataWithBytes:destPtr
                                                   length:outSize];
                NSData *uncompressedSizeData = nil;
                NSData *compressedSizeData = nil;
                uint8_t size[4] = {0};
                if (outSize == bytesRemaining)
                {
                    // block was not compressed
                    //printf("last block remained uncompressed\n");
                    size[0] = (outSize & 0x000000ff);
                    size[1] = ((outSize & 0x0000ff00) >> 8);
                    size[2] = ((outSize & 0x00ff0000) >> 16);
                    size[3] = ((outSize & 0xff000000) >> 24);
                    uncompressedSizeData = [NSData dataWithBytes:size
                                                          length:4];
                    [compressedData appendData:appleSignature2];
                    [compressedData appendData:uncompressedSizeData];
                    [compressedData appendData:dataChunk];
                }
                else
                {
                    // block was compressed
                    //printf("last block was compressed\n");
                    size[0] = (bytesRemaining & 0x000000ff);
                    size[1] = ((bytesRemaining & 0x0000ff00) >> 8);
                    size[2] = ((bytesRemaining & 0x00ff0000) >> 16);
                    size[3] = ((bytesRemaining & 0xff000000) >> 24);
                    uncompressedSizeData = [NSData dataWithBytes:size
                                                          length:4];
                    size[0] = (outSize & 0x000000ff);
                    size[1] = ((outSize & 0x0000ff00) >> 8);
                    size[2] = ((outSize & 0x00ff0000) >> 16);
                    size[3] = ((outSize & 0xff000000) >> 24);
                    compressedSizeData = [NSData dataWithBytes:size
                                                        length:4];
                    [compressedData appendData:appleSignature1];
                    [compressedData appendData:uncompressedSizeData];
                    [compressedData appendData:compressedSizeData];
                    [compressedData appendData:dataChunk];
                }
                totalOutputBlocks++;
                srcPtr += bytesRemaining;
                destPtr += outSize;
                bytesRemaining = 0;
            }
        } // while
        if (! didCancelled)
        {
            //printf("# of compressed blocks:%u\n", totalOutputBlocks);
            [compressedData appendData:appleSignature3];
        }
    } // Apple compatible Format

    if (! didCancelled)
    {
        //printf("writing LZ4 file\n");
        NSString *srcPath = _srcURL.path;
        NSString *destPath = [srcPath stringByDeletingPathExtension];
        destPath = [destPath stringByAppendingPathExtension:@"LZ4"];
        [compressedData writeToFile:destPath
                         atomically:YES];
    }

bailOut:
    return;
}

// overridden method
- (void) main
{
    if (self.isCancelled)
    {
        return;
    }
    // Deflate the file here!
    [self compress];
}

@end
