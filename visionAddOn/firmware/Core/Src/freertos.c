/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * File Name          : freertos.c
  * Description        : Code for freertos applications
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

/* Includes ------------------------------------------------------------------*/
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"
#include "cmsis_os.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "c_app_builder.h"
#include "lwip.h"
#include "utils/c_log.h"
#include "utils/allocator.h"
#include "utils/constants.h"
#include "ethernetif.h"
#include <stdio.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
typedef StaticTask_t osStaticThreadDef_t;
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN Variables */

/* USER CODE END Variables */
/* Definitions for networkTask */
osThreadId_t networkTaskHandle;
uint32_t networkTaskBuffer[ 1024 ];
osStaticThreadDef_t networkTaskControlBlock;
const osThreadAttr_t networkTask_attributes = {
  .name = "networkTask",
  .cb_mem = &networkTaskControlBlock,
  .cb_size = sizeof(networkTaskControlBlock),
  .stack_mem = &networkTaskBuffer[0],
  .stack_size = sizeof(networkTaskBuffer),
  .priority = (osPriority_t) osPriorityNormal,
};
/* Definitions for blobDetectorTas */
osThreadId_t blobDetectorTasHandle;
uint32_t blobDetectorBuffer[ 512 ];
osStaticThreadDef_t blobDetectorControlBlock;
const osThreadAttr_t blobDetectorTas_attributes = {
  .name = "blobDetectorTas",
  .cb_mem = &blobDetectorControlBlock,
  .cb_size = sizeof(blobDetectorControlBlock),
  .stack_mem = &blobDetectorBuffer[0],
  .stack_size = sizeof(blobDetectorBuffer),
  .priority = (osPriority_t) osPriorityNormal,
};
/* Definitions for statsTask */
osThreadId_t statsTaskHandle;
uint32_t statsTaskBuffer[ 256 ];
osStaticThreadDef_t statsTaskControlBlock;
const osThreadAttr_t statsTask_attributes = {
  .name = "statsTask",
  .cb_mem = &statsTaskControlBlock,
  .cb_size = sizeof(statsTaskControlBlock),
  .stack_mem = &statsTaskBuffer[0],
  .stack_size = sizeof(statsTaskBuffer),
  .priority = (osPriority_t) osPriorityLow,
};

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */

/* USER CODE END FunctionPrototypes */

void StartNetworkTask(void *argument);
void StartBlobDetectorTask(void *argument);
void StartStatsTask(void *argument);

extern void MX_LWIP_Init(void);
void MX_FREERTOS_Init(void); /* (MISRA C 2004 rule 8.1) */

/* Hook prototypes */
void configureTimerForRunTimeStats(void);
unsigned long getRunTimeCounterValue(void);
void vApplicationStackOverflowHook(xTaskHandle xTask, signed char *pcTaskName);
void vApplicationMallocFailedHook(void);

/* USER CODE BEGIN 1 */
/* Functions needed when configGENERATE_RUN_TIME_STATS is on */
__weak void configureTimerForRunTimeStats(void)
{

}

__weak unsigned long getRunTimeCounterValue(void)
{
return 0;
}
/* USER CODE END 1 */

/* USER CODE BEGIN 4 */
void vApplicationStackOverflowHook(xTaskHandle xTask, signed char *pcTaskName)
{
   /* Run time stack overflow checking is performed if
   configCHECK_FOR_STACK_OVERFLOW is defined to 1 or 2. This hook function is
   called if a stack overflow is detected. */
   (void) xTask;
   log_error("[vApplicationStackOverflowHook] stack overflow of task %s ", pcTaskName);
   Error_Handler();
}
/* USER CODE END 4 */

/* USER CODE BEGIN 5 */
void vApplicationMallocFailedHook(void)
{
   /* vApplicationMallocFailedHook() will only be called if
   configUSE_MALLOC_FAILED_HOOK is set to 1 in FreeRTOSConfig.h. It is a hook
   function that will get called if a call to pvPortMalloc() fails.
   pvPortMalloc() is called internally by the kernel whenever a task, queue,
   timer or semaphore is created. It is also called by various parts of the
   demo application. If heap_1.c or heap_2.c are used, then the size of the
   heap available to pvPortMalloc() is defined by configTOTAL_HEAP_SIZE in
   FreeRTOSConfig.h, and the xPortGetFreeHeapSize() API function can be used
   to query the size of free heap space that remains (although it does not
   provide information on how the remaining heap might be fragmented). */
   log_error("[vApplicationMallocFailedHook]");
   Error_Handler();
}
/* USER CODE END 5 */

/**
  * @brief  FreeRTOS initialization
  * @param  None
  * @retval None
  */
void MX_FREERTOS_Init(void) {
  /* USER CODE BEGIN Init */
  MX_LWIP_Register_locals_to_app_builder();
  /* USER CODE END Init */

  /* USER CODE BEGIN RTOS_MUTEX */
  /* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
  /* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
  app_build();
  persisted_mac = app_fetch_mac_address_from_storage();

  /* USER CODE END RTOS_TIMERS */

  /* USER CODE BEGIN RTOS_QUEUES */
  /* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of networkTask */
  networkTaskHandle = osThreadNew(StartNetworkTask, NULL, &networkTask_attributes);

  /* creation of blobDetectorTas */
  blobDetectorTasHandle = osThreadNew(StartBlobDetectorTask, NULL, &blobDetectorTas_attributes);

  /* creation of statsTask */
  statsTaskHandle = osThreadNew(StartStatsTask, NULL, &statsTask_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */

  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */

}

/* USER CODE BEGIN Header_StartNetworkTask */
/**
  * @brief  Function implementing the networkTask thread.
  * @param  argument: Not used
  * @retval None
  */
/* USER CODE END Header_StartNetworkTask */
void StartNetworkTask(void *argument)
{
  /* init code for LWIP */
  MX_LWIP_Init();
  /* USER CODE BEGIN StartNetworkTask */
  (void)argument;
  log_info("[StartNetworkTask] locking heap");
  lock_heap();
  log_info("[StartNetworkTask] init command handler");
  app_init_command_handler();
  for(;;)
  {
    app_run_command_handler(); // blocking!
    osDelay(1);
  }
  /* USER CODE END StartNetworkTask */
}

/* USER CODE BEGIN Header_StartBlobDetectorTask */
/**
* @brief Function implementing the blobDetectorTas thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_StartBlobDetectorTask */
void StartBlobDetectorTask(void *argument)
{
  /* USER CODE BEGIN StartBlobDetectorTask */
  (void)argument;
  log_info("[StartBlobDetectorTask] init camera");
  app_init_camera();
  app_init_network_config();
  /* Infinite loop */
  for(;;)
  {
    app_run_blob_receiver();
    osDelay(1);
  }
  /* USER CODE END StartBlobDetectorTask */
}

/* USER CODE BEGIN Header_StartStatsTask */
/**
* @brief Function implementing the statsTask thread.
* @param argument: Not used
* @retval None
*/
/* USER CODE END Header_StartStatsTask */
void StartStatsTask(void *argument)
{
  /* USER CODE BEGIN StartStatsTask */
  (void)argument;
  /* Infinite loop */
  for(;;)
  {
    //app_run_network_stats();
    osDelay(100);
  }
  /* USER CODE END StartStatsTask */
}

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */

/* USER CODE END Application */

