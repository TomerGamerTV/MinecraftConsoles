// Iggy Perfmon -- Apple stub
// Copyright 2008-2013 RAD Game Tools

#ifndef __RAD_INCLUDE_IGGYPERFMON_H__
#define __RAD_INCLUDE_IGGYPERFMON_H__

#include "rrCore.h"

#define IDOC

RADDEFSTART

#ifndef __RAD_HIGGYPERFMON_
#define __RAD_HIGGYPERFMON_
typedef void * HIGGYPERFMON;
#endif

// Allocator callbacks for perfmon
typedef void * RADLINK iggyperfmon_malloc(void *handle, U32 size);
typedef void RADLINK iggyperfmon_free(void *handle, void *ptr);

IDOC RADEXPFUNC HIGGYPERFMON RADEXPLINK IggyPerfmonCreate(iggyperfmon_malloc *perf_malloc, iggyperfmon_free *perf_free, void *callback_handle);

typedef struct Iggy Iggy;
typedef struct GDrawFunctions GDrawFunctions;

// Abstracted gamepad state for the perf monitor overlay
IDOC typedef union {
   U32 bits;
   struct {
      U32 dpad_up             :1;
      U32 dpad_down           :1;
      U32 dpad_left           :1;
      U32 dpad_right          :1;
      U32 button_up           :1;      // Triangle / Y
      U32 button_down         :1;      // Cross / A
      U32 button_left         :1;      // Square / X
      U32 button_right        :1;      // Circle / B
      U32 shoulder_left_hi    :1;      // L1 / LB
      U32 shoulder_right_hi   :1;      // R1 / RB
      U32 trigger_left_low    :1;
      U32 trigger_right_low   :1;
   } field;
} IggyPerfmonPad;

// Draw and tick the perf monitor overlay
IDOC RADEXPFUNC void RADEXPLINK IggyPerfmonTickAndDraw(HIGGYPERFMON p, GDrawFunctions* gdraw_funcs,
                    const IggyPerfmonPad* pad,
                    int pm_tile_ul_x, int pm_tile_ul_y, int pm_tile_lr_x, int pm_tile_lr_y);

IDOC RADEXPFUNC void  RADEXPLINK IggyPerfmonDestroy(HIGGYPERFMON p, GDrawFunctions* iggy_draw);

RADDEFEND

#endif//__RAD_INCLUDE_IGGYPERFMON_H__
