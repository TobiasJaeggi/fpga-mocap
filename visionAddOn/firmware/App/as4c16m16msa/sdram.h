// slightly modified version of https://gitlab.ti.bfh.ch/lts6/leguan-platformio/-/blob/main/lib/sdram/sdram.c
/*
 * sdram.h
 *
 *  Created on: Nov 11, 2020
 *      Author: theo
 */

#ifndef VISIONADDON_AS4C16M16MSA_SDRAM_H
#define VISIONADDON_AS4C16M16MSA_SDRAM_H

#ifdef __cplusplus
extern "C" {
#endif

#include "stm32f7xx_hal.h"


#define SDRAM_MODEREG_BURST_LENGTH_1 0
#define SDRAM_MODEREG_BURST_LENGTH_2 1
#define SDRAM_MODEREG_BURST_LENGTH_4 2
#define SDRAM_MODEREG_BURST_LENGTH_8 3
#define SDRAM_MODEREG_BURST_LENGTH_FULL 7
#define SDRAM_MODEREG_BURST_TYPE_SEQUENTIAL 0
#define SDRAM_MODEREG_BURST_TYPE_INTERLEAVED (1<<3)
#define SDRAM_MODEREG_CAS_LATENCY_2 (2 << 4)
#define SDRAM_MODEREG_CAS_LATENCY_3 (3 << 4)
#define SDRAM_MODEREG_OPERATING_MODE_STANDARD 0
#define SDRAM_MODEREG_WRITEBURST_MODE_PROGRAMMED 0
#define SDRAM_MODEREG_WRITEBURST_MODE_SINGLE (1<<9)


void initSdram(SDRAM_HandleTypeDef *handle);

#ifdef __cplusplus
}
#endif

#endif // VISIONADDON_AS4C16M16MSA_SDRAM_H
