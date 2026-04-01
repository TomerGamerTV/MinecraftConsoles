// AppleTypes.h - Windows API type compatibility for Apple platforms (macOS/iOS)
// Provides DWORD, BYTE, HRESULT, CRITICAL_SECTION, etc.

#pragma once

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <ctime>
#include <pthread.h>
#include <string>
#include <wchar.h>
#include <unistd.h>

// Basic Windows types
typedef unsigned char       BYTE;
typedef unsigned char      *PBYTE;
typedef unsigned short      WORD;
typedef unsigned int        DWORD;
typedef unsigned long       ULONG;
typedef unsigned long long  ULONGLONG;
typedef long                LONG;
typedef long long           LONGLONG;
typedef unsigned int        UINT;
typedef int                 INT;
typedef int                 BOOL;
typedef float               FLOAT;
typedef void               *PVOID;
typedef void               *LPVOID;
typedef const char         *LPCSTR;
typedef char               *LPSTR;
typedef const wchar_t      *LPCWSTR;
typedef wchar_t            *LPWSTR;
typedef long                HRESULT;
typedef void               *HANDLE;
typedef void               *HINSTANCE;
typedef void               *HWND;
typedef unsigned long       SIZE_T;
typedef unsigned long       ULONG_PTR;
typedef uint16_t            WCHAR;

// Boolean constants
#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

// HRESULT helpers
#define S_OK        ((HRESULT)0L)
#define S_FALSE     ((HRESULT)1L)
#define E_FAIL      ((HRESULT)0x80004005L)
#define E_INVALIDARG ((HRESULT)0x80070057L)
#define E_OUTOFMEMORY ((HRESULT)0x8007000EL)
#define SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)
#define FAILED(hr)    (((HRESULT)(hr)) < 0)
#define HRESULT_SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)

// Windows string macros
#ifndef _T
#define _T(x) x
#endif
#ifndef TEXT
#define TEXT(x) L##x
#endif

// Min/Max
#ifndef min
#define min(a,b) ((a) < (b) ? (a) : (b))
#endif
#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif

// FILETIME
typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME;

// SYSTEMTIME
typedef struct _SYSTEMTIME {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
} SYSTEMTIME;

// RECT
typedef struct _RECT {
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
} RECT;

// LARGE_INTEGER
typedef union _LARGE_INTEGER {
    struct {
        DWORD LowPart;
        LONG  HighPart;
    };
    long long QuadPart;
} LARGE_INTEGER;

// Critical section using pthread mutex
typedef struct _CRITICAL_SECTION {
    pthread_mutex_t mutex;
} CRITICAL_SECTION;

inline void InitializeCriticalSection(CRITICAL_SECTION* cs) {
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&cs->mutex, &attr);
    pthread_mutexattr_destroy(&attr);
}

inline void InitializeCriticalSectionAndSpinCount(CRITICAL_SECTION* cs, DWORD) {
    InitializeCriticalSection(cs);
}

inline void EnterCriticalSection(CRITICAL_SECTION* cs) {
    pthread_mutex_lock(&cs->mutex);
}

inline void LeaveCriticalSection(CRITICAL_SECTION* cs) {
    pthread_mutex_unlock(&cs->mutex);
}

inline void DeleteCriticalSection(CRITICAL_SECTION* cs) {
    pthread_mutex_destroy(&cs->mutex);
}

// Windows threading stubs
inline HANDLE CreateThread(void*, SIZE_T, void* (*)(void*), LPVOID param, DWORD, DWORD* tid) {
    pthread_t* thread = new pthread_t;
    pthread_create(thread, nullptr, (void*(*)(void*))nullptr, param);
    return (HANDLE)thread;
}

inline void CloseHandle(HANDLE h) {
    // Stub
}

inline DWORD WaitForSingleObject(HANDLE h, DWORD timeout) {
    return 0;
}

#define INFINITE 0xFFFFFFFF
#define WAIT_OBJECT_0 0

// Performance counter (high-res timer)
inline BOOL QueryPerformanceFrequency(LARGE_INTEGER* freq) {
    freq->QuadPart = 1000000000LL; // nanoseconds
    return TRUE;
}

inline BOOL QueryPerformanceCounter(LARGE_INTEGER* count) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    count->QuadPart = ts.tv_sec * 1000000000LL + ts.tv_nsec;
    return TRUE;
}

// GetTickCount
inline DWORD GetTickCount() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (DWORD)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

// Sleep
inline void Sleep(DWORD ms) {
    usleep(ms * 1000);
}

// OutputDebugString
inline void OutputDebugStringA(const char* str) {
    fprintf(stderr, "%s", str);
}

inline void OutputDebugStringW(const wchar_t* str) {
    fwprintf(stderr, L"%ls", str);
}

#define OutputDebugString OutputDebugStringA

// GetLocalTime
inline void GetLocalTime(SYSTEMTIME* st) {
    time_t t = time(nullptr);
    struct tm* tm_info = localtime(&t);
    st->wYear = tm_info->tm_year + 1900;
    st->wMonth = tm_info->tm_mon + 1;
    st->wDayOfWeek = tm_info->tm_wday;
    st->wDay = tm_info->tm_mday;
    st->wHour = tm_info->tm_hour;
    st->wMinute = tm_info->tm_min;
    st->wSecond = tm_info->tm_sec;
    st->wMilliseconds = 0;
}

// String helpers
inline int _stricmp(const char* a, const char* b) { return strcasecmp(a, b); }
inline int _strnicmp(const char* a, const char* b, size_t n) { return strncasecmp(a, b, n); }
inline int _wcsicmp(const wchar_t* a, const wchar_t* b) { return wcscasecmp(a, b); }
inline char* _strlwr(char* str) { for (char* p = str; *p; ++p) *p = tolower(*p); return str; }
inline char* _strupr(char* str) { for (char* p = str; *p; ++p) *p = toupper(*p); return str; }
inline int sprintf_s(char* buf, size_t sz, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int ret = vsnprintf(buf, sz, fmt, args);
    va_end(args);
    return ret;
}
inline int swprintf_s(wchar_t* buf, size_t sz, const wchar_t* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args);
    return ret;
}
inline int _snprintf(char* buf, size_t sz, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int ret = vsnprintf(buf, sz, fmt, args);
    va_end(args);
    return ret;
}
inline int _snwprintf(wchar_t* buf, size_t sz, const wchar_t* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args);
    return ret;
}

#define _countof(arr) (sizeof(arr)/sizeof(arr[0]))
#define ZeroMemory(p, sz) memset(p, 0, sz)
#define CopyMemory(dst, src, sz) memcpy(dst, src, sz)
#define MoveMemory(dst, src, sz) memmove(dst, src, sz)

// Windows codepage constants
#define CP_ACP 0
#define CP_UTF8 65001

// WideCharToMultiByte / MultiByteToWideChar compatibility
inline int WideCharToMultiByte(unsigned int, unsigned int, const wchar_t* src, int srcLen,
                                char* dst, int dstLen, const char*, const int*) {
    if (!dst || dstLen == 0) {
        // Calculate required length
        return (int)wcstombs(nullptr, src, 0) + 1;
    }
    size_t len = wcstombs(dst, src, dstLen);
    if (len == (size_t)-1) return 0;
    if ((int)len < dstLen) dst[len] = '\0';
    return (int)len + 1;
}

inline int MultiByteToWideChar(unsigned int, unsigned int, const char* src, int srcLen,
                                wchar_t* dst, int dstLen) {
    if (!dst || dstLen == 0) {
        return (int)mbstowcs(nullptr, src, 0) + 1;
    }
    size_t len = mbstowcs(dst, src, dstLen);
    if (len == (size_t)-1) return 0;
    if ((int)len < dstLen) dst[len] = L'\0';
    return (int)len + 1;
}

// wcscpy_s compatibility
inline int wcscpy_s(wchar_t* dst, size_t dstSz, const wchar_t* src) {
    if (!dst || !src) return -1;
    wcsncpy(dst, src, dstSz);
    if (dstSz > 0) dst[dstSz - 1] = L'\0';
    return 0;
}

// swprintf_s with wchar (used extensively in the codebase)
inline int swprintf_s(wchar_t* buf, int sz, const wchar_t* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args);
    return ret;
}

// strcpy_s compatibility
inline int strcpy_s(char* dst, size_t dstSz, const char* src) {
    if (!dst || !src) return -1;
    strncpy(dst, src, dstSz);
    if (dstSz > 0) dst[dstSz - 1] = '\0';
    return 0;
}

// Fake D3D11 types for API compatibility (used in 4J_Render.h constants)
typedef struct { int unused; } *ID3D11Device;
typedef struct { int unused; } *ID3D11DeviceContext;
typedef struct { int unused; } *IDXGISwapChain;
typedef struct { int unused; } *ID3D11Buffer;
typedef struct { int unused; } *ID3D11ShaderResourceView;
typedef struct { int unused; } *ID3D11RenderTargetView;
typedef struct { int unused; } *ID3D11DepthStencilView;

// D3D11 RECT alias
typedef RECT D3D11_RECT;

// D3D11 blend constants (needed by 4J_Render.h GL_ constants)
enum {
    D3D11_BLEND_ZERO = 1,
    D3D11_BLEND_ONE = 2,
    D3D11_BLEND_SRC_COLOR = 3,
    D3D11_BLEND_INV_SRC_COLOR = 4,
    D3D11_BLEND_SRC_ALPHA = 5,
    D3D11_BLEND_INV_SRC_ALPHA = 6,
    D3D11_BLEND_DEST_ALPHA = 7,
    D3D11_BLEND_DEST_COLOR = 8,
    D3D11_BLEND_INV_DEST_COLOR = 9,
    D3D11_BLEND_BLEND_FACTOR = 14,
    D3D11_BLEND_INV_BLEND_FACTOR = 15,
};

// D3D11 comparison constants
enum {
    D3D11_COMPARISON_NEVER = 1,
    D3D11_COMPARISON_LESS = 2,
    D3D11_COMPARISON_EQUAL = 3,
    D3D11_COMPARISON_LESS_EQUAL = 4,
    D3D11_COMPARISON_GREATER = 5,
    D3D11_COMPARISON_NOT_EQUAL = 6,
    D3D11_COMPARISON_GREATER_EQUAL = 7,
    D3D11_COMPARISON_ALWAYS = 8,
};

// _alloca for Apple
#include <alloca.h>
#define _alloca alloca
#define _malloca alloca
#define _freea(p)

// errno_t
typedef int errno_t;
inline errno_t fopen_s(FILE** f, const char* name, const char* mode) {
    *f = fopen(name, mode);
    return *f ? 0 : errno;
}

// tchar compat
#define _tcslen strlen
#define _tcscpy strcpy
#define _tcscat strcat
