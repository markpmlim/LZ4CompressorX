#ifndef __USER_DEFINES_H__
#define __USER_DEFINES_H__

// LZ4 formats.
typedef enum
{
	kAppleLZ4			= 1,
	kLegacyLZ4			= 2,
	kFrameLZ4			= 3,
	kUnknownLZ4			= 0xffff,
} LZ4Format;

extern const uint8_t lz4FrameMagicNumber[];
extern const uint8_t lz4LegacyMagicNumber[];
extern const uint8_t appleMagicNumber1[];
extern const uint8_t appleMagicNumber2[];
extern const uint8_t appleMagicNumber3[];

#define	sixtyFourK	65536
#endif