#include "cameraSelector.h"

// cam selector ci
static const int CI_CAM_SELECT_A_OUTPUT_MODE = 0;
static const int CI_CAM_SELECT_A_INPUT_MODE = 1;
static const int CI_CAM_SELECT_B_OUTPUT_MODE_RGB = 0;
static const int CI_CAM_SELECT_B_OUTPUT_MODE_BIN = 1;
static const int CI_CAM_SELECT_B_INPUT_MODE_REAL = 0;
static const int CI_CAM_SELECT_B_INPUT_MODE_FAKE_STATIC = 1;
static const int CI_CAM_SELECT_B_INPUT_MODE_FAKE_MOVING = 2;

bool cameraSelectorSetInput(CameraSelectorInput input){
  switch (input)
  {
    case CAM_SEL_IN_OV9281:
      asm volatile("l.nios_rrr r0,%[ra],%[rb],0xC" ::[ra] "r"(CI_CAM_SELECT_A_INPUT_MODE), [rb] "r"(CI_CAM_SELECT_B_INPUT_MODE_REAL));
      break;
    case CAM_SEL_IN_FAKE_STATIC:
      asm volatile("l.nios_rrr r0,%[ra],%[rb],0xC" ::[ra] "r"(CI_CAM_SELECT_A_INPUT_MODE), [rb] "r"(CI_CAM_SELECT_B_INPUT_MODE_FAKE_STATIC));
      break;
    case CAM_SEL_IN_FAKE_MOVING:
      asm volatile("l.nios_rrr r0,%[ra],%[rb],0xC" ::[ra] "r"(CI_CAM_SELECT_A_INPUT_MODE), [rb] "r"(CI_CAM_SELECT_B_INPUT_MODE_FAKE_MOVING));
      break;
    default:
      return false;
  }
  return true;
}

bool cameraSelectorSetOutput(CameraSelectorOutput output){
    switch (output)
    {
    case CAM_SEL_OUT_RAW:
      asm volatile("l.nios_rrr r0,%[ra],%[rb],0xC" ::[ra] "r"(CI_CAM_SELECT_A_OUTPUT_MODE), [rb] "r"(CI_CAM_SELECT_B_OUTPUT_MODE_RGB));
      break;
    case CAM_SEL_OUT_BIN:
      asm volatile("l.nios_rrr r0,%[ra],%[rb],0xC" ::[ra] "r"(CI_CAM_SELECT_A_OUTPUT_MODE), [rb] "r"(CI_CAM_SELECT_B_OUTPUT_MODE_BIN));
      break;
    default:
      return false;
    }
    return true;
}