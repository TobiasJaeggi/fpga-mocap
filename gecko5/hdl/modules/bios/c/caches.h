#ifndef __CACHES_H__
#define __CACHES_H__

#define CACHE_DIRECT_MAPPED   0 
#define CACHE_TWO_WAY         1
#define CACHE_FOUR_WAY        2
#define CACHE_WRITE_THROUGH   0 << 8
#define CACHE_WRITE_BACK      1 << 8
#define CACHE_REPLACE_FIFO    0 << 16
#define CACHE_REPLACE_PLRU    1 << 16
#define CACHE_REPLACE_LRU     2 << 16
#define CACHE_COHERENCE       1 << 18
#define CACHE_MSI             0 << 20
#define CACHE_MESI            1 << 20
#define CACHE_SNARFING_ENABLE 1 << 21
#define CACHE_FLUSH           1 << 29
#define CACHE_SIZE_1k         0 << 30
#define CACHE_SIZE_2k         1 << 30
#define CACHE_SIZE_4k         2 << 30
#define CACHE_SIZE_8k         3 << 30

#define setInstructionCacheConfig( value ) asm volatile ("l.mtspr r0,%[in1],0x6"::[in1]"r"(value))
#define setDataCacheConfig( value ) asm volatile ("l.mtspr r0,%[in1],0x5"::[in1]"r"(value))

/*
 * Important: before enabling the caches, you should set the configuration of the cache.
 * default configuration is: 8k 4-way set associative
 * the "dummy" variable below should be of type int, hence: int dummy; or unsigned int dummy;
 */
#define enableInstructionCache( dummy ) asm volatile ("l.mfspr %[out1],r0,17":[out1]"=r"(dummy)); dummy |= 1<<4; asm volatile ("l.mtspr r0,%[in1],17"::[in1]"r"(dummy))
#define enableDataCache( dummy ) asm volatile ("l.mfspr %[out1],r0,17":[out1]"=r"(dummy)); dummy |= 1<<3; asm volatile ("l.mtspr r0,%[in1],17"::[in1]"r"(dummy))
#define enableBothCaches( dummy ) asm volatile ("l.mfspr %[out1],r0,17":[out1]"=r"(dummy)); dummy |= 3<<3; asm volatile ("l.mtspr r0,%[in1],17"::[in1]"r"(dummy))

#define flushInstructionCache() asm volatile ("l.mtspr r0,%[in1],0x6"::[in1]"r"(CACHE_FLUSH))
#define flushDataCache() asm volatile ("l.mtspr r0,%[in1],0x5"::[in1]"r"(CACHE_FLUSH))

#endif
