#ifndef PACKETS_H
#define PACKETS_H

// This is some sort of TCP packet

UINT8 packetPtr0[] = {  0x8,
 0x1,
 0x3c,
 0x0,
 0x0,
 0x18,
 0x39,
 0x74,
 0xce,
 0xa6,
 0xf0,
 0x7d,
 0x68,
 0xc1,
 0xb1,
 0xc,
 0x0,
 0x18,
 0x39,
 0x74,
 0xce,
 0xa4,
 0x20,
 0x8f,
 0xaa,
 0xaa,
 0x3,
 0x0,
 0x0,
 0x0,
 0x8,
 0x0,
 0x45,
 0x0,
 0x0,
 0x34,
 0x6b,
 0xa2,
 0x40,
 0x0,
 0x40,
 0x6,
 0x20,
 0x67,
 0xc0,
 0xa8,
 0x1,
 0x4,
 0x4a,
 0x7d,
 0xa2,
 0x91,
 0x9e,
 0x85,
 0x0,
 0x50,
 0x76,
 0xe2,
 0x7f,
 0x89,
 0x26,
 0x84,
 0x17,
 0x39,
 0x80,
 0x10,
 0x0,
 0x98,
 0xf3,
 0x7b,
 0x0,
 0x0,
 0x1,
 0x1,
 0x8,
 0xa,
 0x0,
 0x2,
 0x4d,
 0x1d,
 0x13,
 0x49,
 0xa0,
 0x87,
 0xbd,
 0xad,
 0x21,
 0x84,
};

UINT8 *packets[] = { packetPtr0 };
UINT32 packetLengths[] = { sizeof(packetPtr0)/sizeof(UINT8) };

#endif
