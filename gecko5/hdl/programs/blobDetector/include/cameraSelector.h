#ifndef CAMERASELECTOR_H_INCLUDED
#define CAMERASELECTOR_H_INCLUDED

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  CAM_SEL_IN_OV9281,
  CAM_SEL_IN_FAKE_STATIC,
  CAM_SEL_IN_FAKE_MOVING
} CameraSelectorInput;

typedef enum {
  CAM_SEL_OUT_RAW,
  CAM_SEL_OUT_BIN
} CameraSelectorOutput;

bool cameraSelectorSetInput(CameraSelectorInput input);
bool cameraSelectorSetOutput(CameraSelectorOutput output);

#ifdef __cplusplus
}
#endif

#endif /* CAMERASELECTOR_H_INCLUDED */
