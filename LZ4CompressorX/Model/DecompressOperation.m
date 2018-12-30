//
//  DecompressOperation.m
//  LZCompressorX
//
//  Created by mark lim on 5/1/18.
//  Copyright 2018 Incremental Innovation. All rights reserved.
//
//  This is where the fun (or hair-pulling) starts.
// KIV. Instead of an array of paths, consider instantiating with
// a single path URL. Multiple threads can be used.

#import "DecompressOperation.h"
#import "MainWindowController.h"
#import "AppDelegate.h"
#include "lz4.h"
#include "lz4frame.h"

NSString *const compressedSizeKey = @"Compressed Size";
NSString *const originalSizeKey = @"Original Size";
NSString *const lz4FormatKey = @"LZ4 Format";
NSString *const compressedDataKey = @"Compressed Data";


@implementation DecompressOperation
@synthesize delegate = _delegate;

- (id) initWithURL:(NSURL *)url
       andDelegate:(MainWindowController *)delegate
{
    self = [super init];
    if (self)
    {
        _srcURL = [url retain];     // must retain this because url was set to autorelease
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


/*
 Extract the compressed data which was deflated with the LZ4 format.
 We need to preserve the original size.
 LZ4_decompress_safe must be used since the compressedSize &
 maxDecompressedSize are known.
 */
- (NSData *) compressedDataFromFileData:(NSData *)fileContents
                                 format:(LZ4Format)format
{
    NSMutableData *mutableContents = [NSMutableData dataWithData:fileContents];
    NSRange range;
    if (format == kLegacyLZ4 || format == kFrameLZ4)
    {
        range = NSMakeRange(0, 16);
        [mutableContents replaceBytesInRange:range
                                   withBytes:NULL
                                      length:0];
    }
    else if (format == kAppleLZ4)
    {
        // Remove trailing magic number first.
        range = NSMakeRange(mutableContents.length-4, 4);
        [mutableContents replaceBytesInRange:range
                                   withBytes:NULL
                                      length:0];
        // Then remove leading magic number which is 12 bytes.
        range = NSMakeRange(0, 12);
        [mutableContents replaceBytesInRange:range
                                   withBytes:NULL
                                      length:0];
    }
    return mutableContents;
}

/*
 Returns a custom dictionary to be used to decompress a file.
 */
- (NSDictionary *) compressionDictionaryAtURL:(NSURL *)url
{
    NSData *fileContents = [NSData dataWithContentsOfURL:url];
    AppDelegate *appDelegate = [NSApp delegate];
    LZ4Format format = [appDelegate identifyFormatAtPath:url.path];
    u_int32_t compressedSize;
    u_int32_t originalSize = 0;
    
    if (format == kLegacyLZ4 || format == kAppleLZ4)
    {
        u_int32_t tmp;
        memcpy(&tmp, fileContents.bytes+4, sizeof(uint32_t));
        originalSize = NSSwapLittleIntToHost(tmp);
        compressedSize = fileContents.length - 16;
    }
    NSData *compressedData = [self compressedDataFromFileData:fileContents
                                                       format:format];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              compressedData, compressedDataKey,
                              [NSNumber numberWithUnsignedInt:format], lz4FormatKey,
                              [NSNumber numberWithUnsignedInt:compressedSize], compressedSizeKey,
                              [NSNumber numberWithUnsignedInt:originalSize], originalSizeKey,
                              nil];
    return dict;
}

/*
 The compressed blocks may not be independent i.e. during the decoding of
 a block the previous output blocks (up to 64 K) may be needed.
 */
- (NSMutableData *) decompressAppleFrame:(NSData *)fileData
{
    //printf("decompressAppleFrame\n");
    uint32_t headerSize = 12;
    uint8_t *srcBegin = (uint8_t *)fileData.bytes;
    uint8_t *srcPtr = srcBegin;
    // Assumes there is a trailing magic number
    uint8_t *srcEnd = srcBegin + fileData.length;
    NSMutableData *inflatedData = [NSMutableData data];

    // Get the size of uncompressed (original) file first
    unsigned long long decompressedFileSize = 0;
    while (srcPtr < srcEnd)
    {
        uint32_t tmp = 0;
        memcpy(&tmp, srcPtr, sizeof(uint32_t));
        uint32_t magicNumber = NSSwapLittleIntToHost(tmp);
        memcpy(&tmp, srcPtr+4, sizeof(uint32_t));
        uint32_t blockSize = NSSwapLittleIntToHost(tmp);
        decompressedFileSize += blockSize;
        if (magicNumber == 0x31347662)
        {
            memcpy(&tmp, srcPtr+8, sizeof(uint32_t));
            uint32_t compressedBlockSize = NSSwapLittleIntToHost(tmp);
            srcPtr += (headerSize + compressedBlockSize);
        }
        else if (magicNumber == 0x2D347662)
        {
            srcPtr += (headerSize - 4 + blockSize);
        }
        else if (magicNumber == 0x24347662)
        {
            break;
        }
    }

    uint8_t *outBuffer = (uint8_t *)malloc(decompressedFileSize);
    srcPtr = srcBegin;
    unsigned long long currentOffset = 0;
    BOOL didCancelled = NO;
    while (srcPtr < srcEnd)
    {
        if ([self isCancelled])
        {
            didCancelled = YES;
            break;
        }
        uint32_t tmp = 0;
        memcpy(&tmp, srcPtr, sizeof(uint32_t));
        uint32_t magicNumber = NSSwapLittleIntToHost(tmp);
        if (magicNumber == 0x24347662)
        {
            // There should be no data after this octet.
            //printf("%p\n", srcPtr-srcBegin);
            break;
        }

        memcpy(&tmp, srcPtr+4, sizeof(uint32_t));
        uint32_t originalBlockSize = NSSwapLittleIntToHost(tmp);
        memcpy(&tmp, srcPtr+8, sizeof(uint32_t));
        uint32_t compressedBlockSize = NSSwapLittleIntToHost(tmp);
        if (magicNumber == 0x31347662)
        {
            // The function LZ4_uncompress is deprecated - use LZ4_decompress_fast
            // "outSize" should be the decompressed size of the block.
            int outSize = LZ4_decompress_fast(srcPtr + headerSize,
                                              outBuffer + currentOffset,
                                              (int)originalBlockSize);
            if (outSize < 0)
            {
                NSLog(@"Error decompressing Apple LZ4 frame");
                //printf("Error decompressing Apple LZ4 frame\n");
                //printf("%p\n", srcPtr-srcBegin);
                inflatedData = nil;
                break;
            }
            srcPtr += (headerSize + compressedBlockSize);
        }
        else if (magicNumber == 0x2D347662)
        {
            // Just copy the uncompressed data from the block
            compressedBlockSize = originalBlockSize;
            memcpy(outBuffer + currentOffset, srcPtr + headerSize - 4, originalBlockSize);
            srcPtr += (headerSize - 4 + compressedBlockSize);
        }
        else
        {
            NSLog(@"Wrong Magic Number: %0x", magicNumber);
            inflatedData = nil;
            break;
        }
        //printf("%0x %0x %0x\n", originalBlockSize, compressedBlockSize, outSize);
        NSData *outData = [NSData dataWithBytes:outBuffer + currentOffset
                                         length:originalBlockSize];
        [inflatedData appendData:outData];
        currentOffset += originalBlockSize;
        //printf("pointers: %p %p\n", srcPtr, srcEnd);
    } // while
    free(outBuffer);
    if (didCancelled)
    {
        //printf("Apple LZ4: did cancelled\n");
        inflatedData = nil;
    }
    return inflatedData;
}

-(void) decompress
{
    NSError *errOut = nil;
    NSData *originalData = [NSData dataWithContentsOfURL:_srcURL
                                                 options:NSMappedRead
                                                   error:&errOut];
    NSMutableData *inflatedData = nil;
    if (errOut == nil)
    {
        uint32_t tmp;
        memcpy(&tmp, originalData.bytes, sizeof(uint32_t));
        uint32_t magic_number = NSSwapLittleIntToHost(tmp);
        if (magic_number != 0x184c2103 &&
            magic_number != 0x31347662 &&
            magic_number != 0x2D347662 &&
            magic_number != 0x184d2204)
        {
            NSLog(@"magic number not found");
            return;
        }
        
        // If Apple LZ4 format, check that the trailing signature is there 
        uint32_t magic_number2;
        if (magic_number == 0x31347662 || magic_number == 0x2D347662)
        {
            memcpy(&tmp, originalData.bytes+originalData.length-4, sizeof(uint32_t));
            magic_number2 = NSSwapLittleIntToHost(tmp);
            if (magic_number2 != 0x24347662)
            {
                NSLog(@"Apple LZ4: trailing magic number not found for file:%@", _srcURL.path);
                return;
            }
            //NSLog(@"offset: %ld trailing magic number:0x%0x", originalData.length-4, magic_number2);
        }

        BOOL wasCancelled = NO;
        if (magic_number == 0x184d2204)
        {   // Generic LZ4 format
            LZ4F_decompressionContext_t dcContext;          // this is a pointer
            LZ4F_errorCode_t errCode = LZ4F_createDecompressionContext(&dcContext, LZ4F_VERSION);
            if (LZ4F_isError(errCode))
            {
                NSLog(@"Decompression Context Error:%s", LZ4F_getErrorName(errCode));
                return;
            }

            uint8_t *srcPtr = (uint8_t *)originalData.bytes;
            size_t inSize = originalData.length;
            LZ4F_frameInfo_t frameInfo;
            errCode = LZ4F_getFrameInfo(dcContext, &frameInfo, srcPtr, &inSize);
            // if errCode is +ve, it's a hint for the src size for the next
            // call to the function LZ4F_decompress
            //printf("%lu %lu\n", inSize, errCode);
            if (LZ4F_isError(errCode))
            {
                // errCode is -ve.
                NSLog(@"Frame Info err:%s", LZ4F_getErrorName(errCode));
                errCode = LZ4F_freeDecompressionContext(dcContext);
                return;
            }

            size_t outSize = 0;
            switch (frameInfo.blockSizeID)
            {
            case max64KB:
                outSize = (1 << 16);
                break;
            case max256KB:
                outSize = (1 << 18);
                break;
            case max1MB:
                outSize = (1 << 20);
                break;
            case max4MB:
                outSize = (1 << 22);
                break;
            default:
                outSize = (1 << 16);
            }

            // If there are no errors after a call to LZ4F_getFrameInfo or LZ4F_decompress,
            // the var "inSize" is the # of bytes read provided the decompression is complete.
            srcPtr += inSize;
            inSize = errCode;
            void *outBuffer = malloc(outSize);
            inflatedData = [NSMutableData data];
            // KIV-can we handle multi-frames?
            while (errCode > 0)
            {
                if ([self isCancelled])
                {
                    wasCancelled = YES;
                    break;
                }
                errCode = LZ4F_decompress(dcContext, outBuffer, &outSize, srcPtr, &inSize, NULL);
                if (LZ4F_isError(errCode))
                {
                    NSLog(@"Cannot inflate file:%@  LZ4 Error:%s\n",
                          _srcURL.path, LZ4F_getErrorName(errCode));
                    errCode = LZ4F_freeDecompressionContext(dcContext);
                    free(outBuffer);
                    return;
                }
                //printf("%lu %lu %lu\n", outSize, inSize, errCode);
                // use the outSize to get the decompressed data.
                NSData *inflatedChunk = [NSData dataWithBytes:outBuffer
                                                       length:outSize];
                [inflatedData appendData:inflatedChunk];
                srcPtr += inSize;
                inSize = errCode;       // errCode is src size for next LZ4F_decompress call.
            } // while

            //printf("original sizes %lu\n", [inflatedData length]);
            errCode = LZ4F_freeDecompressionContext(dcContext);
            free(outBuffer);
            if (wasCancelled)
            {
                //printf("Generic LZ4: Decompression cancelled\n");
                inflatedData = nil;
            }
        }
        else if (magic_number == 0x184c2103)
        {
            // Legacy format - assumes compressed data is stored in a single block.
            uint32_t headerSize = 16;
            memcpy(&tmp, originalData.bytes+4, sizeof(uint32_t));
            uint32_t originalSize = NSSwapLittleIntToHost(tmp);
            
            char *outBuffer = (char *)malloc(originalSize);
            // The function LZ4_uncompress is deprecated - use LZ4_decompress_fast
            // "outSize" should be the decompressed size of the file.
            int outSize = LZ4_decompress_fast(originalData.bytes + headerSize,
                                              outBuffer,
                                              (int)originalSize);

            if (outSize < 0)
            {
                free(outBuffer);
                return;
            }
            if (![self isCancelled])
            {
                inflatedData = [NSData dataWithBytesNoCopy:outBuffer
                                                    length:originalSize];
            }
         }
        else if (magic_number == 0x31347662 || magic_number == 0x2D347662)
        {
            inflatedData = [self decompressAppleFrame:originalData];
        }

        if (inflatedData != nil)
        {
            NSString *srcPath = _srcURL.path;
            NSString *fileExt = self.delegate.suffixStr;
            if ([fileExt length] == 0)
            {
                fileExt = @"BNRY";
            }
            NSString *destPath = [NSString stringWithString:srcPath];
            NSString *name = [destPath lastPathComponent];
            name = [name stringByDeletingPathExtension];
            destPath = [destPath stringByDeletingLastPathComponent];
            destPath = [destPath stringByAppendingPathComponent:name];
            destPath = [destPath stringByAppendingPathExtension:fileExt];
            
            NSURL *destURL = [NSURL fileURLWithPath:destPath];
            [inflatedData writeToURL:destURL
                          atomically:YES];
            
        }
    }
}

- (void) main
{
    if ([self isCancelled])
        goto bailOut;

    // Inflate the file here!
    [self decompress];

bailOut:
    return;
}
@end
