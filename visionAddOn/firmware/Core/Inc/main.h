/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f7xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define LED_RED_Pin GPIO_PIN_2
#define LED_RED_GPIO_Port GPIOE
#define LED_GREEN_Pin GPIO_PIN_3
#define LED_GREEN_GPIO_Port GPIOE
#define BUTTON1_Pin GPIO_PIN_13
#define BUTTON1_GPIO_Port GPIOC
#define POE_TYPE_Pin GPIO_PIN_6
#define POE_TYPE_GPIO_Port GPIOF
#define STM_DBG_9_Pin GPIO_PIN_10
#define STM_DBG_9_GPIO_Port GPIOF
#define STM_DBG_10_Pin GPIO_PIN_0
#define STM_DBG_10_GPIO_Port GPIOA
#define STM_DBG_15_Pin GPIO_PIN_0
#define STM_DBG_15_GPIO_Port GPIOB
#define STM_DBG_16_Pin GPIO_PIN_1
#define STM_DBG_16_GPIO_Port GPIOB
#define STM_DBG_17_Pin GPIO_PIN_2
#define STM_DBG_17_GPIO_Port GPIOB
#define STM_DBG_21_Pin GPIO_PIN_10
#define STM_DBG_21_GPIO_Port GPIOB
#define WATCHDOG_Pin GPIO_PIN_11
#define WATCHDOG_GPIO_Port GPIOD
#define STM_DBG_0_Pin GPIO_PIN_3
#define STM_DBG_0_GPIO_Port GPIOG
#define STM_DBG_1_Pin GPIO_PIN_6
#define STM_DBG_1_GPIO_Port GPIOG
#define STM_DBG_2_Pin GPIO_PIN_7
#define STM_DBG_2_GPIO_Port GPIOG
#define STM_DBG_11_Pin GPIO_PIN_8
#define STM_DBG_11_GPIO_Port GPIOA
#define TMS_Pin GPIO_PIN_13
#define TMS_GPIO_Port GPIOA
#define TCK_Pin GPIO_PIN_14
#define TCK_GPIO_Port GPIOA
#define STM_DBG_23_Pin GPIO_PIN_10
#define STM_DBG_23_GPIO_Port GPIOC
#define STM_DBG_24_Pin GPIO_PIN_11
#define STM_DBG_24_GPIO_Port GPIOC
#define STM_DBG_20_Pin GPIO_PIN_12
#define STM_DBG_20_GPIO_Port GPIOC
#define STM_DBG_19_Pin GPIO_PIN_2
#define STM_DBG_19_GPIO_Port GPIOD
#define STM_DBG_8_Pin GPIO_PIN_4
#define STM_DBG_8_GPIO_Port GPIOD
#define STM_DGB_25_Pin GPIO_PIN_6
#define STM_DGB_25_GPIO_Port GPIOD
#define EXTI10_SPI_NEW_DATA_Pin GPIO_PIN_10
#define EXTI10_SPI_NEW_DATA_GPIO_Port GPIOG
#define EXTI10_SPI_NEW_DATA_EXTI_IRQn EXTI15_10_IRQn
#define STM_DBG_4_Pin GPIO_PIN_11
#define STM_DBG_4_GPIO_Port GPIOG
#define STM_DBG_5_Pin GPIO_PIN_12
#define STM_DBG_5_GPIO_Port GPIOG
#define STM_DBG_6_Pin GPIO_PIN_13
#define STM_DBG_6_GPIO_Port GPIOG
#define STM_DBG_7_Pin GPIO_PIN_14
#define STM_DBG_7_GPIO_Port GPIOG
#define SWO_Pin GPIO_PIN_3
#define SWO_GPIO_Port GPIOB
#define STM_DBG_18_Pin GPIO_PIN_5
#define STM_DBG_18_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
