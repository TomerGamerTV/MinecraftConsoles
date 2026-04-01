// ========================================================================
// (C) Copyright 1994-2014 RAD Game Tools, Inc.  Global types header file
// Apple platform adaptation
// ========================================================================

#ifndef __RADRR_COREH__
#define __RADRR_COREH__
#define RADCOPYRIGHT "Copyright (C) 1994-2014, RAD Game Tools, Inc."

// Apple platform detection
#if defined(__APPLE__)
   #include <TargetConditionals.h>
   #define __RADAPPLE__
   #define __RADMACH__
   #if TARGET_OS_IPHONE || TARGET_OS_TV
      #define __RADIOS__
   #else
      #define __RADMAC__
   #endif
#endif

// Detect 64-bit
#if defined(__LP64__) || defined(__x86_64__) || defined(__arm64__) || defined(__aarch64__)
   #define __RAD64__
   #define __RAD32__
#else
   #define __RAD32__
#endif

// Detect endianness (Apple platforms are little-endian)
#define __RADLITTLEENDIAN__

// ========================================================================
// Base integer types
// ========================================================================

typedef signed char        S8;
typedef unsigned char      U8;
typedef signed short       S16;
typedef unsigned short     U16;
typedef signed int         S32;
typedef unsigned int       U32;
typedef signed long long   S64;
typedef unsigned long long U64;
typedef float              F32;
typedef double             F64;

// Boolean type compatible with RAD conventions
typedef S32 rrbool;

// Pointer-sized integer types
#ifdef __RAD64__
   typedef U64 UINTa;
   typedef S64 SINTa;
#else
   typedef U32 UINTa;
   typedef S32 SINTa;
#endif

// ========================================================================
// Compiler and linkage macros
// ========================================================================

// C linkage block macros for extern "C" wrapping
#ifdef __cplusplus
   #define RADDEFSTART extern "C" {
   #define RADDEFEND }
#else
   #define RADDEFSTART
   #define RADDEFEND
#endif

// Data and function definition/export macros (no DLL import/export on Apple)
#define RADDEFINEDATA
#define RADDEFFUNC
#define RADEXPFUNC
#define RADEXPLINK

// Calling conventions are not used on Apple/ARM/x86_64
#define RADLINK
#define RADINLINE static inline

// Unused parameter suppression
#define RADUNUSED(x) (void)(x)

#endif // __RADRR_COREH__
