//
//  LZ4Document.m
//  LZ4CompressorX
//
//  Created by mark lim on 5/13/18.
//
//

#import "Cocoa/Cocoa.h"
#import "LZ4Document.h"
#import "lz4.h"

const uint8_t appleMagicNumber1[] = {0x62, 0x76, 0x34, 0x31};
const uint8_t appleMagicNumber2[] = {0x62, 0x76, 0x34, 0x2D};
const uint8_t appleMagicNumber3[] = {0x62, 0x76, 0x34, 0x24};

const uint8_t lz4FrameMagicNumber[4] = {
	0x04,0x22,0x4D,0x18,		// LZ4 Frame Format
};

const uint8_t lz4LegacyMagicNumber[4] = {
	0x03,0x21,0x4C,0x18,
};


@implementation LZ4Document

@synthesize urlOfFile;
@synthesize lz4Format;
@synthesize hasUncompressedSize;
@synthesize uncompressedSize;
@synthesize compressedSize;
@synthesize compressedBlockCount;

- (id) initWithURL:(NSURL *)url
{
	self = [super init];
	if (self != nil)
	{
		urlOfFile = [url retain];
		lz4Format = [self identifyFormatAtPath:url.path];
		if (lz4Format == kUnknownLZ4)
		{
			[urlOfFile release];
			[self release];
			self = nil;
		}
	}
	return self;
}

- (void) dealloc
{
	if (urlOfFile != nil)
	{
		[urlOfFile release];
		urlOfFile = nil;
	}
	[super dealloc];
}

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


- (void) sizesFromAppleLZ4:(NSFileHandle *)fileHandle
{
	//printf("apple LZ4\n");
	self.uncompressedSize = 0;
	self.compressedSize = 0;
	self.compressedBlockCount = 0;

	uint32_t uncompressedBlockSize = 0;
	uint32_t compressedBlockSize = 0;
	// On entry, we must set the offset to the beginning of file
	// becase there are 2 different magic #s.
	unsigned long long currentOffset = 0;
	BOOL atEOF = YES;
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
			self.uncompressedSize += uncompressedBlockSize;
			self.compressedSize += compressedBlockSize;
			self.compressedBlockCount++;
			currentOffset += (headerSize + compressedBlockSize);
		}
		else if (magicNum == 0x2D347662)
		{
			//printf("uncompressed block\n");
			data = [fileHandle readDataOfLength:4];
			tmp = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
			uncompressedBlockSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
			compressedBlockSize = uncompressedBlockSize;
			self.uncompressedSize += uncompressedBlockSize;
			self.compressedSize += compressedBlockSize;
			self.compressedBlockCount++;
			currentOffset += (headerSize - 4 + compressedBlockSize);
		}
		else if (magicNum == 0x24347662)
		{
			//printf("Trailer\n");
			atEOF = NO;
		}
	} while (atEOF);
}

/*
 Computes the property "compressedSize".
 */
- (void) compressedSizeOfGenericLZ4:(NSFileHandle *)fileHandle
						 headerSize:(uint32_t)startingOffset
					  blockCheckSum:(BOOL)hasBCS
{
	uint32_t compressedBlockSize = 0;
	self.compressedSize = 0;
	self.compressedBlockCount = 0;
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
				compressedBlockSize &= 0x7fffffff;		// yes
			self.compressedSize += compressedBlockSize;
			self.compressedBlockCount++;
			currentOffset += (4 + compressedBlockSize);
			currentOffset += hasBCS ? 4 : 0;
		}
		else
		{
			isEOM = YES;
		}
	} while (!isEOM);
}

- (void) reportStatistics
{
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:urlOfFile.path];
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
	self.uncompressedSize = 0;
	self.compressedSize = 0;
	self.hasUncompressedSize = YES;
	if ([leadingSignature isEqualToData:legacySignature])
	{
		//printf("legacy\n");
		NSData *data = [fileHandle readDataOfLength:4];
		self.uncompressedSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
		[fileHandle seekToFileOffset:12];
		data = [fileHandle readDataOfLength:4];
		self.compressedSize = NSSwapLittleIntToHost(*(uint32_t *)data.bytes);
		self.compressedBlockCount = 1;
	}
	else if ([leadingSignature isEqualToData:appleSignature1] || [leadingSignature isEqualToData:appleSignature2])
	{
		// iterate through the LZ4 file.
		[self sizesFromAppleLZ4:fileHandle];
	}
	else if ([leadingSignature isEqualToData:modernSignature])
	{
		NSData *data = [fileHandle readDataOfLength:1];
		uint8_t frameFlag = *(uint8_t *)data.bytes;
		if (frameFlag & 0x08)
		{
			// The original uncompressed file size is present.
			[fileHandle seekToFileOffset:6];
			data = [fileHandle readDataOfLength:8];
			self.uncompressedSize = (uint32_t)NSSwapLittleLongLongToHost(*(uint64_t *)data.bytes);
			//printf("uncompressedSize: %u", uncompressedSize);
			// ver 1.8 or 1.7?
			uint32_t headerSize = (frameFlag & 0x01) ? 19 : 15;
			// block checksum after compressed block size is present.
			BOOL hasBlockCheckSum = (frameFlag & 0x10) ? YES : NO;
			//printf("headerSize %u\n", headerSize);
			[self compressedSizeOfGenericLZ4:fileHandle
								  headerSize:headerSize
							   blockCheckSum:hasBlockCheckSum];
		}
		else
		{
			self.hasUncompressedSize = NO;
			uint32_t headerSize = (frameFlag & 0x01) ? 11 : 7;
			// block checksum after compressed block size is present.
			BOOL hasBlockCheckSum = (frameFlag & 0x10) ? YES : NO;
			//printf("headerSize %u\n", headerSize);
			[self compressedSizeOfGenericLZ4:fileHandle
								  headerSize:headerSize
							   blockCheckSum:hasBlockCheckSum];
		}
	}
	
	[fileHandle closeFile];
}

/*
 Assumes max size is 2 113 929 216 bytes (0x7E000000) 
 */
- (NSString *) stringFromSize:(uint32_t)size
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
	else if (size >= 1073741824 && size <= LZ4_MAX_INPUT_SIZE)
	{
		sz = (double)size/1073741824;
		sizeStr = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:sz]];
		sizeStr = [NSString stringWithFormat:@"%@ GB", sizeStr];
	}
	else
	{
		sizeStr = [NSString stringWithFormat:@"Value is too large"];
	}

	return sizeStr;
}
@end

