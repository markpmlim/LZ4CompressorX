#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#import <Cocoa/Cocoa.h>
#include <QuickLook/QuickLook.h>
#include "UserDefines.h"
#include <LZ4Document.h>

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface,
							   QLPreviewRequestRef preview,
							   CFURLRef url,
							   CFStringRef contentTypeUTI,
							   CFDictionaryRef options)
{
	//NSURL *pathURL = (NSURL *)url;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	LZ4Document *doc = [[[LZ4Document alloc] initWithURL:(NSURL *)url] autorelease];
	if (doc != nil)
	{
		[doc reportStatistics];
		NSString *fileName = ((NSURL *)url).path.lastPathComponent;
		NSString *uncompressedSizeStr = @"Unknown Size";
		NSString *ratioStr = @"Unknown";
		NSString *rateStr = @"Unknown";
		if (doc.hasUncompressedSize)
		{
			uncompressedSizeStr = [doc stringFromSize:doc.uncompressedSize];
			float compressionRatio = (float)doc.uncompressedSize/(float)doc.compressedSize;
			float compressionRate = ((float)doc.compressedSize/(float)doc.uncompressedSize) * 100.0;
			ratioStr = [NSString stringWithFormat:@"%.2f", compressionRatio];
			rateStr = [NSString stringWithFormat:@"%.2f %%", compressionRate];
		}
		NSString *compressedSizeStr = [doc stringFromSize:doc.compressedSize];
		NSString *blockCountStr = [NSString stringWithFormat:@"%u", doc.compressedBlockCount];
		NSString *lz4FormatStr = nil;
		switch (doc.lz4Format)
		{
		case kAppleLZ4:
			lz4FormatStr = @"Apple LZ4 Block Compression";
			break;
		case kLegacyLZ4:
			lz4FormatStr = @"Legacy LZ4 Block Compression";
			break;
		case kFrameLZ4:
			lz4FormatStr = @"Generic LZ4 Block Compression";
			break;
		default:
			lz4FormatStr = @"Unknown Compression Format";
			break;
		}
		// Load the html template.
		NSBundle *bundle = [NSBundle bundleForClass:[LZ4Document class]];
		NSString *templatePath = [bundle pathForResource:@"template"
												  ofType:@"html"];
		NSError *err = nil;
		NSString *htmlDoc = [NSString stringWithContentsOfFile:templatePath
													  encoding:NSUTF8StringEncoding
														 error:&err];
		if (err != nil)
		{
			goto bailOut;
		}

		// Modify the values
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__File Name__"
													 withString:fileName];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Compression Format__"
													 withString:lz4FormatStr];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Uncompressed File Size__"
													 withString:uncompressedSizeStr];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Compressed File Size__"
													 withString:compressedSizeStr];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Compressed Block Count__"
													 withString:blockCountStr];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Compression Ratio__"
													 withString:ratioStr];
		htmlDoc = [htmlDoc stringByReplacingOccurrencesOfString:@"__Compression Rate__"
													 withString:rateStr];
		
		// Load the css & image to be attached to the HTML object.
		NSString *cssPath = [bundle pathForResource:@"style"
											 ofType:@"css"];
		NSData *cssData = [NSData dataWithContentsOfFile:cssPath];
		NSString *imgPath = [bundle pathForResource:@"lz4"
											 ofType:@"png"];
		NSData *imgData = [NSData dataWithContentsOfFile:imgPath];

		NSMutableDictionary *cssProps = [[[NSMutableDictionary alloc] init] autorelease];
		[cssProps setObject:@"text/css"			// mime type
					 forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
		[cssProps setObject:cssData
					 forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
		
		NSMutableDictionary *imgProps = [[[NSMutableDictionary alloc] init] autorelease];
		[imgProps setObject:@"image/png"		// mime type
					 forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
		[imgProps setObject:imgData
					 forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
		
		// Setup the dictionary
		NSMutableDictionary *properties = [[[NSMutableDictionary alloc] init] autorelease];
		[properties setObject:@"UTF-8"
					   forKey:(NSString *)kQLPreviewPropertyTextEncodingNameKey];
		[properties setObject:@"text/html"
					   forKey:(NSString *)kQLPreviewPropertyMIMETypeKey];
		[properties setObject:[NSDictionary dictionaryWithObjectsAndKeys:
							   cssProps, @"style.css",
							   imgProps, @"lz4.png",
							   nil]
					   forKey:(NSString *)kQLPreviewPropertyAttachmentsKey];
		QLPreviewRequestSetDataRepresentation(preview,
											  (CFDataRef)[htmlDoc dataUsingEncoding:NSUTF8StringEncoding],
											  kUTTypeHTML,
											  (CFDictionaryRef)properties);
	}
bailOut:
	[pool drain];
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
