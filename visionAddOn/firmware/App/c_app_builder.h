
#ifndef VISIONADDON_APP_CAPPBUILDER_H
#define VISIONADDON_APP_CAPPBUILDER_H

#ifdef __cplusplus
extern "C" {
#endif

#include "cmsis_os2.h"
#include "lwip/netif.h"

void app_register_network_interface(struct netif* networkInterface);
void app_build();
void app_init_camera();
void app_init_command_handler();
void app_init_network_config();
void app_run_command_handler();
void app_run_blob_receiver();
void app_run_network_stats();
uint8_t* app_fetch_mac_address_from_storage();

#ifdef __cplusplus
}
#endif

#endif // VISIONADDON_APP_CAPPBUILDER_H