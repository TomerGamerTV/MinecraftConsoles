// AppleTypes.h - Windows API type compatibility for Apple platforms (macOS/iOS)
// Provides DWORD, BYTE, HRESULT, CRITICAL_SECTION, File I/O, Threading, etc.
// Modeled after OrbisStubs.h but using POSIX/macOS APIs.

#pragma once

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <ctime>
#include <cfloat>
#include <cerrno>
#include <pthread.h>
#include <string>
#include <wchar.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <dirent.h>
#include <fcntl.h>

// ============================================================================
// Basic Windows types
// ============================================================================
typedef char                CHAR;
typedef unsigned char       BYTE;
typedef unsigned char      *PBYTE;
typedef unsigned short      WORD;
typedef unsigned int        DWORD;
typedef unsigned int       *PDWORD;
typedef DWORD              *LPDWORD;
typedef unsigned long       ULONG;
typedef unsigned long long  ULONGLONG;
typedef long                LONG;
typedef long               *PLONG;
typedef long long           LONGLONG;
typedef int64_t             LONG64;
typedef unsigned int        UINT;
typedef int                 INT;
// BOOL as bool for consistency between .cpp and .mm files on Apple
// ObjC runtime defines BOOL as bool, so we match it to avoid linker mismatches
typedef bool                BOOL;
typedef float               FLOAT;
typedef void                VOID;
typedef void               *PVOID;
typedef void               *LPVOID;
typedef const void         *LPCVOID;
typedef const char         *LPCSTR;
typedef char               *LPSTR;
typedef const wchar_t      *LPCWSTR;
typedef wchar_t            *LPWSTR;
typedef long                HRESULT;
typedef void               *HANDLE;
typedef void               *HINSTANCE;
typedef void               *HMODULE;
typedef void               *HWND;
typedef unsigned long       SIZE_T;
typedef unsigned long       ULONG_PTR;
typedef long                LONG_PTR;
typedef wchar_t             WCHAR;
typedef short               SHORT;
typedef int                 __int32;
typedef long long           __int64;
typedef bool                boolean;
typedef int                 errno_t;
typedef BOOL               *PBOOL;
typedef float               F32;

// Pointer types used by Windows file/thread APIs
typedef void               *LPSECURITY_ATTRIBUTES;
typedef void               *LPOVERLAPPED;
typedef DWORD              (*LPTHREAD_START_ROUTINE)(LPVOID);

// LARGE_INTEGER pointer
typedef union _LARGE_INTEGER *PLARGE_INTEGER;

// ============================================================================
// Constants
// ============================================================================

// CONST macro
#ifndef CONST
#define CONST const
#endif

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

// ============================================================================
// HRESULT helpers
// ============================================================================
#define S_OK                    ((HRESULT)0L)
#define S_FALSE                 ((HRESULT)1L)
#define E_FAIL                  ((HRESULT)0x80004005L)
#define E_ABORT                 ((HRESULT)0x80004004L)
#define E_INVALIDARG            ((HRESULT)0x80070057L)
#define E_OUTOFMEMORY           ((HRESULT)0x8007000EL)
#define E_NOINTERFACE           ((HRESULT)0x80004002L)
#define SUCCEEDED(hr)           (((HRESULT)(hr)) >= 0)
#define FAILED(hr)              (((HRESULT)(hr)) < 0)
#define HRESULT_SUCCEEDED(hr)   (((HRESULT)(hr)) >= 0)
#define _HRESULT_TYPEDEF_(sc)   (sc)
#define MAKE_HRESULT(sev,fac,code) \
    ((HRESULT)(((unsigned int)(sev)<<31)|((unsigned int)(fac)<<16)|((unsigned int)(code))))

// ============================================================================
// String macros
// ============================================================================
#ifndef _T
#define _T(x) x
#endif
#ifndef TEXT
#define TEXT(x) L##x
#endif

// Min/Max macros - guard to avoid conflicts with ObjC++ system headers
#ifndef __OBJC__
#ifndef min
#define min(a,b) ((a) < (b) ? (a) : (b))
#endif
#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif
#endif // __OBJC__

// ============================================================================
// Structures
// ============================================================================

// FILETIME
typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;

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
} SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;

// RECT
typedef struct _RECT {
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
} RECT, *PRECT;

// LARGE_INTEGER
typedef union _LARGE_INTEGER {
    struct {
        DWORD LowPart;
        LONG  HighPart;
    };
    long long QuadPart;
} LARGE_INTEGER;

// ULARGE_INTEGER
typedef union _ULARGE_INTEGER {
    struct {
        DWORD LowPart;
        DWORD HighPart;
    };
    unsigned long long QuadPart;
} ULARGE_INTEGER;

// MEMORYSTATUS
typedef struct _MEMORYSTATUS {
    DWORD  dwLength;
    DWORD  dwMemoryLoad;
    SIZE_T dwTotalPhys;
    SIZE_T dwAvailPhys;
    SIZE_T dwTotalPageFile;
    SIZE_T dwAvailPageFile;
    SIZE_T dwTotalVirtual;
    SIZE_T dwAvailVirtual;
} MEMORYSTATUS, *LPMEMORYSTATUS;

// WIN32_FIND_DATA
#define MAX_PATH 260

typedef struct _WIN32_FIND_DATAA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    CHAR     cFileName[MAX_PATH];
    CHAR     cAlternateFileName[14];
} WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;
typedef WIN32_FIND_DATAA WIN32_FIND_DATA;
typedef PWIN32_FIND_DATAA PWIN32_FIND_DATA;
typedef LPWIN32_FIND_DATAA LPWIN32_FIND_DATA;

// WIN32_FILE_ATTRIBUTE_DATA
typedef struct _WIN32_FILE_ATTRIBUTE_DATA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
} WIN32_FILE_ATTRIBUTE_DATA, *LPWIN32_FILE_ATTRIBUTE_DATA;

typedef enum _GET_FILEEX_INFO_LEVELS {
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel
} GET_FILEEX_INFO_LEVELS;

// ============================================================================
// File constants
// ============================================================================
#define GENERIC_READ                  (0x80000000L)
#define GENERIC_WRITE                 (0x40000000L)
#define GENERIC_EXECUTE               (0x20000000L)
#define GENERIC_ALL                   (0x10000000L)

#define FILE_SHARE_READ               0x00000001
#define FILE_SHARE_WRITE              0x00000002
#define FILE_SHARE_DELETE             0x00000004

#define FILE_ATTRIBUTE_READONLY       0x00000001
#define FILE_ATTRIBUTE_HIDDEN         0x00000002
#define FILE_ATTRIBUTE_SYSTEM         0x00000004
#define FILE_ATTRIBUTE_DIRECTORY      0x00000010
#define FILE_ATTRIBUTE_ARCHIVE        0x00000020
#define FILE_ATTRIBUTE_DEVICE         0x00000040
#define FILE_ATTRIBUTE_NORMAL         0x00000080
#define FILE_ATTRIBUTE_TEMPORARY      0x00000100
#define INVALID_FILE_ATTRIBUTES       ((DWORD)-1)

#define FILE_FLAG_WRITE_THROUGH       0x80000000
#define FILE_FLAG_OVERLAPPED          0x40000000
#define FILE_FLAG_NO_BUFFERING        0x20000000
#define FILE_FLAG_RANDOM_ACCESS       0x10000000
#define FILE_FLAG_SEQUENTIAL_SCAN     0x08000000
#define FILE_FLAG_DELETE_ON_CLOSE     0x04000000
#define FILE_FLAG_BACKUP_SEMANTICS    0x02000000

#define FILE_BEGIN                    0
#define FILE_CURRENT                  1
#define FILE_END                      2

#define CREATE_NEW                    1
#define CREATE_ALWAYS                 2
#define OPEN_EXISTING                 3
#define OPEN_ALWAYS                   4
#define TRUNCATE_EXISTING             5

#define INVALID_HANDLE_VALUE          ((HANDLE)(long)-1)
#define INVALID_SET_FILE_POINTER      ((DWORD)-1)
#define INVALID_FILE_SIZE             ((DWORD)0xFFFFFFFF)
#define NO_ERROR                      0L
#define ERROR_SUCCESS                 0L

// ============================================================================
// Memory constants
// ============================================================================
#define PAGE_NOACCESS                 0x01
#define PAGE_READONLY                 0x02
#define PAGE_READWRITE                0x04
#define PAGE_WRITECOPY                0x08
#define PAGE_EXECUTE                  0x10
#define PAGE_EXECUTE_READ             0x20
#define PAGE_EXECUTE_READWRITE        0x40
#define MEM_COMMIT                    0x1000
#define MEM_RESERVE                   0x2000
#define MEM_DECOMMIT                  0x4000
#define MEM_RELEASE                   0x8000
#define MEM_LARGE_PAGES               0x20000000

#define MAXULONG_PTR                  ((ULONG_PTR)~((ULONG_PTR)0))

// ============================================================================
// Threading constants
// ============================================================================
#define INFINITE                      0xFFFFFFFF
#define WAIT_OBJECT_0                 0
#define WAIT_TIMEOUT                  258L
#define WAIT_FAILED                   ((DWORD)0xFFFFFFFF)
#define WAIT_ABANDONED                0x00000080L
#define STILL_ACTIVE                  0x00000103L
#define CREATE_SUSPENDED              0x00000004

#define THREAD_PRIORITY_LOWEST        (-2)
#define THREAD_PRIORITY_BELOW_NORMAL  (-1)
#define THREAD_PRIORITY_NORMAL        0
#define THREAD_PRIORITY_ABOVE_NORMAL  1
#define THREAD_PRIORITY_HIGHEST       2
#define THREAD_PRIORITY_TIME_CRITICAL 15
#define THREAD_PRIORITY_IDLE          (-15)

// ============================================================================
// Misc Windows macros
// ============================================================================
#ifndef WINAPI
#define WINAPI
#endif
#define CDECL
#define APIENTRY
#define CALLBACK
#define STDMETHODCALLTYPE

// MSVC __forceinline -> always_inline on Clang
#define __forceinline __attribute__((always_inline)) inline

#define _countof(arr)                 (sizeof(arr)/sizeof(arr[0]))

// Secure scanf variants - on POSIX, just use the non-secure versions
#define sscanf_s sscanf
#define swscanf_s swscanf
#define wscanf_s wscanf
#define scanf_s scanf

// MSVC _TRUNCATE constant for secure string functions
#define _TRUNCATE ((size_t)-1)

// MSVC secure vsnprintf variants
// _vsnprintf_s(buf, bufsize, count, fmt, args) or _vsnprintf_s(buf, count, fmt, args)
inline int _vsnprintf_s(char* buf, size_t bufSz, size_t count, const char* fmt, va_list args) {
    return vsnprintf(buf, bufSz, fmt, args);
}
template<size_t N>
inline int _vsnprintf_s(char (&buf)[N], size_t count, const char* fmt, va_list args) {
    return vsnprintf(buf, N, fmt, args);
}
#define _snprintf_s(buf, sz, count, ...) snprintf(buf, sz, __VA_ARGS__)
#define _snwprintf_s(buf, sz, count, ...) swprintf(buf, sz, __VA_ARGS__)
#define ZeroMemory(p, sz)             memset(p, 0, sz)
#define CopyMemory(dst, src, sz)      memcpy(dst, src, sz)
#define MoveMemory(dst, src, sz)      memmove(dst, src, sz)
#define FillMemory(dst, sz, fill)     memset(dst, fill, sz)
#define RtlZeroMemory(dst, sz)        memset(dst, 0, sz)
#define RtlCopyMemory(dst, src, sz)   memcpy(dst, src, sz)
#define RtlMoveMemory(dst, src, sz)   memmove(dst, src, sz)
#define UNREFERENCED_PARAMETER(p)     (void)(p)

// Windows error codes
#define ERROR_CANCELLED                1223L
#define ERROR_NO_MORE_FILES            18L
#define ERROR_FILE_NOT_FOUND           2L
#define ERROR_PATH_NOT_FOUND           3L
#define ERROR_ACCESS_DENIED            5L
#define ERROR_INVALID_HANDLE           6L
#define ERROR_NOT_ENOUGH_MEMORY        8L
#define ERROR_ALREADY_EXISTS           183L
#define ERROR_IO_PENDING               997L
#define ERROR_OPERATION_ABORTED        995L

// Xbox marketplace offering types
#define XMARKETPLACE_OFFERING_TYPE_THEME      0
#define XMARKETPLACE_OFFERING_TYPE_AVATARITEM  1
#define XMARKETPLACE_OFFERING_TYPE_TILE       2

// GetClientRect stub - returns a default window rect
inline BOOL GetClientRect(HWND, RECT* lpRect) {
    // Return a reasonable default; actual size comes from Metal view
    lpRect->left = 0;
    lpRect->top = 0;
    lpRect->right = 1920;
    lpRect->bottom = 1080;
    return TRUE;
}

// Windows codepage constants
#define CP_ACP  0
#define CP_UTF8 65001

// VK constants (keyboard)
#define VK_ESCAPE 0x1B
#define VK_RETURN 0x0D
#define VK_F1     0x70
#define VK_F2     0x71
#define VK_F3     0x72
#define VK_F4     0x73
#define VK_F5     0x74
#define VK_F6     0x75
#define VK_F7     0x76
#define VK_F8     0x77
#define VK_F9     0x78
#define VK_F10    0x79
#define VK_F11    0x7A
#define VK_F12    0x7B
#define VK_F13    0x7C
#define VK_F14    0x7D
#define VK_F15    0x7E

// ============================================================================
// Critical section using pthread mutex
// ============================================================================
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

inline ULONG TryEnterCriticalSection(CRITICAL_SECTION* cs) {
    return (pthread_mutex_trylock(&cs->mutex) == 0) ? 1 : 0;
}

inline void DeleteCriticalSection(CRITICAL_SECTION* cs) {
    pthread_mutex_destroy(&cs->mutex);
}

// ============================================================================
// Event objects using pthread condition variables
// ============================================================================
struct WinEvent {
    pthread_mutex_t mutex;
    pthread_cond_t  cond;
    bool            signaled;
    bool            manualReset;
};

inline HANDLE CreateEvent(void*, BOOL bManualReset, BOOL bInitialState, LPCSTR) {
    WinEvent* evt = new WinEvent;
    pthread_mutex_init(&evt->mutex, nullptr);
    pthread_cond_init(&evt->cond, nullptr);
    evt->signaled = (bInitialState != 0);
    evt->manualReset = (bManualReset != 0);
    return (HANDLE)evt;
}

inline BOOL SetEvent(HANDLE hEvent) {
    WinEvent* evt = (WinEvent*)hEvent;
    pthread_mutex_lock(&evt->mutex);
    evt->signaled = true;
    if (evt->manualReset)
        pthread_cond_broadcast(&evt->cond);
    else
        pthread_cond_signal(&evt->cond);
    pthread_mutex_unlock(&evt->mutex);
    return TRUE;
}

inline BOOL ResetEvent(HANDLE hEvent) {
    WinEvent* evt = (WinEvent*)hEvent;
    pthread_mutex_lock(&evt->mutex);
    evt->signaled = false;
    pthread_mutex_unlock(&evt->mutex);
    return TRUE;
}

// ============================================================================
// Threading
// ============================================================================

// Internal: Apple thread wrapper for CreateThread with CREATE_SUSPENDED support
struct AppleThreadInfo {
    void*   startAddress;   // LPTHREAD_START_ROUTINE cast to void*
    LPVOID  param;
    bool    suspended;
    pthread_mutex_t suspendMutex;
    pthread_cond_t  suspendCond;
    pthread_t thread;
    DWORD   exitCode;
    bool    finished;
};

inline void* _AppleThreadEntry(void* arg) {
    AppleThreadInfo* info = (AppleThreadInfo*)arg;
    // If created suspended, wait until ResumeThread is called
    pthread_mutex_lock(&info->suspendMutex);
    while (info->suspended) {
        pthread_cond_wait(&info->suspendCond, &info->suspendMutex);
    }
    pthread_mutex_unlock(&info->suspendMutex);

    // Call the actual thread function
    typedef DWORD (*ThreadFunc)(LPVOID);
    ThreadFunc func = (ThreadFunc)info->startAddress;
    info->exitCode = func(info->param);
    info->finished = true;
    return nullptr;
}

inline HANDLE CreateThread(void*, SIZE_T, void* startAddress, LPVOID param, DWORD flags, DWORD* tid) {
    AppleThreadInfo* info = new AppleThreadInfo;
    info->startAddress = startAddress;
    info->param = param;
    info->suspended = (flags & CREATE_SUSPENDED) != 0;
    info->exitCode = STILL_ACTIVE;
    info->finished = false;
    pthread_mutex_init(&info->suspendMutex, nullptr);
    pthread_cond_init(&info->suspendCond, nullptr);

    pthread_create(&info->thread, nullptr, _AppleThreadEntry, info);

    if (tid) *tid = (DWORD)(uintptr_t)info; // Use as pseudo thread ID
    return (HANDLE)info;
}

inline DWORD ResumeThread(HANDLE hThread) {
    AppleThreadInfo* info = (AppleThreadInfo*)hThread;
    pthread_mutex_lock(&info->suspendMutex);
    info->suspended = false;
    pthread_cond_signal(&info->suspendCond);
    pthread_mutex_unlock(&info->suspendMutex);
    return 0;
}

inline BOOL SetThreadPriority(HANDLE, int) {
    return TRUE; // Stub - thread priorities not directly portable
}

inline BOOL GetExitCodeThread(HANDLE hThread, LPDWORD lpExitCode) {
    AppleThreadInfo* info = (AppleThreadInfo*)hThread;
    *lpExitCode = info->finished ? info->exitCode : STILL_ACTIVE;
    return TRUE;
}

inline DWORD GetCurrentThreadId() {
    uint64_t tid;
    pthread_threadid_np(nullptr, &tid);
    return (DWORD)tid;
}

inline BOOL CloseHandle(HANDLE h) {
    // Stub - handles are closed by specific close functions
    return TRUE;
}

inline DWORD WaitForSingleObject(HANDLE h, DWORD timeout) {
    // Try to detect if it's an event by checking if it's an WinEvent
    // For thread handles, join the thread
    WinEvent* evt = (WinEvent*)h;
    pthread_mutex_lock(&evt->mutex);
    if (timeout == INFINITE) {
        while (!evt->signaled) {
            pthread_cond_wait(&evt->cond, &evt->mutex);
        }
    } else {
        if (!evt->signaled) {
            struct timespec ts;
            clock_gettime(CLOCK_REALTIME, &ts);
            ts.tv_sec += timeout / 1000;
            ts.tv_nsec += (timeout % 1000) * 1000000;
            if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
            pthread_cond_timedwait(&evt->cond, &evt->mutex, &ts);
        }
    }
    BOOL wasSignaled = evt->signaled;
    if (!evt->manualReset) evt->signaled = false; // auto-reset
    pthread_mutex_unlock(&evt->mutex);
    return wasSignaled ? WAIT_OBJECT_0 : WAIT_TIMEOUT;
}

inline DWORD WaitForMultipleObjects(DWORD nCount, const HANDLE* lpHandles, BOOL bWaitAll, DWORD dwMilliseconds) {
    // Simplified: poll events
    if (bWaitAll) {
        for (DWORD i = 0; i < nCount; i++) {
            WaitForSingleObject(lpHandles[i], dwMilliseconds);
        }
        return WAIT_OBJECT_0;
    } else {
        // Wait for any - simplified polling implementation
        DWORD elapsed = 0;
        while (elapsed < dwMilliseconds || dwMilliseconds == INFINITE) {
            for (DWORD i = 0; i < nCount; i++) {
                DWORD result = WaitForSingleObject(lpHandles[i], 0);
                if (result == WAIT_OBJECT_0) return WAIT_OBJECT_0 + i;
            }
            usleep(1000); // 1ms
            elapsed++;
        }
        return WAIT_TIMEOUT;
    }
}

// ============================================================================
// Performance counter / timing
// ============================================================================
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

inline DWORD GetTickCount() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (DWORD)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

inline void Sleep(DWORD ms) {
    usleep(ms * 1000);
}

// ============================================================================
// Debug output
// ============================================================================
inline void OutputDebugStringA(const char* str) {
    fprintf(stderr, "%s", str);
}

inline void OutputDebugStringW(const wchar_t* str) {
    fwprintf(stderr, L"%ls", str);
}

#define OutputDebugString OutputDebugStringA

inline void DebugBreak() { __builtin_trap(); }

// ============================================================================
// Time functions
// ============================================================================
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

inline void GetSystemTime(SYSTEMTIME* st) { GetLocalTime(st); }

inline BOOL SystemTimeToFileTime(const SYSTEMTIME*, FILETIME* ft) {
    ft->dwLowDateTime = 0;
    ft->dwHighDateTime = 0;
    return TRUE;
}

inline BOOL FileTimeToSystemTime(const FILETIME*, SYSTEMTIME* st) {
    GetLocalTime(st);
    return TRUE;
}

// ============================================================================
// File I/O using POSIX
// ============================================================================

// Internal: store file descriptors as HANDLE via casting
// HANDLE is void*, we store (fd + 1) to avoid fd=0 looking like NULL
#define _FD_TO_HANDLE(fd) ((HANDLE)(intptr_t)((fd) + 1))
#define _HANDLE_TO_FD(h)  ((int)((intptr_t)(h) - 1))

inline HANDLE CreateFileA(LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                          LPSECURITY_ATTRIBUTES, DWORD dwCreationDisposition,
                          DWORD dwFlagsAndAttributes, HANDLE) {
    int flags = 0;

    // Access mode
    if ((dwDesiredAccess & GENERIC_READ) && (dwDesiredAccess & GENERIC_WRITE))
        flags = O_RDWR;
    else if (dwDesiredAccess & GENERIC_WRITE)
        flags = O_WRONLY;
    else
        flags = O_RDONLY;

    // Creation disposition
    switch (dwCreationDisposition) {
        case CREATE_ALWAYS:    flags |= O_CREAT | O_TRUNC; break;
        case CREATE_NEW:       flags |= O_CREAT | O_EXCL; break;
        case OPEN_ALWAYS:      flags |= O_CREAT; break;
        case OPEN_EXISTING:    break;
        case TRUNCATE_EXISTING: flags |= O_TRUNC; break;
    }

    int fd = open(lpFileName, flags, 0666);
    if (fd < 0) return INVALID_HANDLE_VALUE;
    return _FD_TO_HANDLE(fd);
}

#define CreateFile CreateFileA

// CreateFileW - wide char version, converts to narrow and calls CreateFileA
inline HANDLE CreateFileW(LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
                          LPSECURITY_ATTRIBUTES sa, DWORD dwCreationDisposition,
                          DWORD dwFlagsAndAttributes, HANDLE hTemplate) {
    char narrowName[1024];
    wcstombs(narrowName, lpFileName, sizeof(narrowName));
    return CreateFileA(narrowName, dwDesiredAccess, dwShareMode, sa, dwCreationDisposition, dwFlagsAndAttributes, hTemplate);
}

inline BOOL WriteFile(HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite,
                      LPDWORD lpNumberOfBytesWritten, LPOVERLAPPED) {
    int fd = _HANDLE_TO_FD(hFile);
    ssize_t written = write(fd, lpBuffer, nNumberOfBytesToWrite);
    if (written < 0) return FALSE;
    if (lpNumberOfBytesWritten) *lpNumberOfBytesWritten = (DWORD)written;
    return TRUE;
}

inline BOOL ReadFile(HANDLE hFile, LPVOID lpBuffer, DWORD nNumberOfBytesToRead,
                     LPDWORD lpNumberOfBytesRead, LPOVERLAPPED) {
    int fd = _HANDLE_TO_FD(hFile);
    ssize_t bytesRead = read(fd, lpBuffer, nNumberOfBytesToRead);
    if (bytesRead < 0) { if (lpNumberOfBytesRead) *lpNumberOfBytesRead = 0; return FALSE; }
    if (lpNumberOfBytesRead) *lpNumberOfBytesRead = (DWORD)bytesRead;
    return TRUE;
}

inline BOOL SetFilePointer(HANDLE hFile, LONG lDistanceToMove, PLONG lpDistanceToMoveHigh, DWORD dwMoveMethod) {
    int fd = _HANDLE_TO_FD(hFile);
    int whence = SEEK_SET;
    switch (dwMoveMethod) {
        case FILE_BEGIN:   whence = SEEK_SET; break;
        case FILE_CURRENT: whence = SEEK_CUR; break;
        case FILE_END:     whence = SEEK_END; break;
    }

    off_t offset = (off_t)lDistanceToMove;
    if (lpDistanceToMoveHigh)
        offset |= ((off_t)(*lpDistanceToMoveHigh)) << 32;

    off_t result = lseek(fd, offset, whence);
    return (result != (off_t)-1);
}

inline DWORD GetFileSize(HANDLE hFile, LPDWORD lpFileSizeHigh) {
    int fd = _HANDLE_TO_FD(hFile);
    off_t curPos = lseek(fd, 0, SEEK_CUR);
    off_t size = lseek(fd, 0, SEEK_END);
    lseek(fd, curPos, SEEK_SET);
    if (lpFileSizeHigh) *lpFileSizeHigh = (DWORD)(size >> 32);
    return (DWORD)size;
}

inline BOOL GetFileSizeEx(HANDLE hFile, PLARGE_INTEGER lpFileSize) {
    int fd = _HANDLE_TO_FD(hFile);
    off_t curPos = lseek(fd, 0, SEEK_CUR);
    off_t size = lseek(fd, 0, SEEK_END);
    lseek(fd, curPos, SEEK_SET);
    lpFileSize->QuadPart = size;
    return TRUE;
}

// GetFileAttributes - check if file/directory exists and get attributes
inline DWORD GetFileAttributesA(LPCSTR lpFileName) {
    struct stat st;
    if (stat(lpFileName, &st) != 0) return INVALID_FILE_ATTRIBUTES;
    DWORD attrs = 0;
    if (S_ISDIR(st.st_mode)) attrs |= FILE_ATTRIBUTE_DIRECTORY;
    else attrs |= FILE_ATTRIBUTE_NORMAL;
    return attrs;
}
#define GetFileAttributes GetFileAttributesA

inline BOOL GetFileAttributesExA(LPCSTR lpFileName, GET_FILEEX_INFO_LEVELS, LPVOID lpFileInformation) {
    struct stat st;
    if (stat(lpFileName, &st) != 0) return FALSE;
    WIN32_FILE_ATTRIBUTE_DATA* data = (WIN32_FILE_ATTRIBUTE_DATA*)lpFileInformation;
    data->dwFileAttributes = S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
    data->nFileSizeLow = (DWORD)(st.st_size & 0xFFFFFFFF);
    data->nFileSizeHigh = (DWORD)(st.st_size >> 32);
    return TRUE;
}
#define GetFileAttributesEx GetFileAttributesExA

// FindFirstFile / FindNextFile using POSIX opendir/readdir
struct AppleFindData {
    DIR*        dir;
    std::string basePath;
};

inline HANDLE FindFirstFileA(LPCSTR lpFileName, LPWIN32_FIND_DATA lpFindFileData) {
    // lpFileName is like "path/*" - extract directory part
    std::string path(lpFileName);
    size_t sep = path.rfind('/');
    if (sep == std::string::npos) sep = path.rfind('\\');
    std::string dirPath = (sep != std::string::npos) ? path.substr(0, sep) : ".";

    DIR* dir = opendir(dirPath.c_str());
    if (!dir) return INVALID_HANDLE_VALUE;

    AppleFindData* fd = new AppleFindData;
    fd->dir = dir;
    fd->basePath = dirPath;

    // Read first entry, skipping . and ..
    struct dirent* entry;
    while ((entry = readdir(fd->dir)) != nullptr) {
        if (entry->d_name[0] == '.' && (entry->d_name[1] == '\0' ||
            (entry->d_name[1] == '.' && entry->d_name[2] == '\0'))) continue;

        strncpy(lpFindFileData->cFileName, entry->d_name, MAX_PATH - 1);
        lpFindFileData->cFileName[MAX_PATH - 1] = '\0';
        lpFindFileData->dwFileAttributes = (entry->d_type == DT_DIR) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
        lpFindFileData->nFileSizeLow = 0;
        lpFindFileData->nFileSizeHigh = 0;
        return (HANDLE)fd;
    }

    closedir(fd->dir);
    delete fd;
    return INVALID_HANDLE_VALUE;
}
#define FindFirstFile FindFirstFileA

inline BOOL FindNextFileA(HANDLE hFindFile, LPWIN32_FIND_DATAA lpFindFileData) {
    AppleFindData* fd = (AppleFindData*)hFindFile;
    struct dirent* entry;
    while ((entry = readdir(fd->dir)) != nullptr) {
        if (entry->d_name[0] == '.' && (entry->d_name[1] == '\0' ||
            (entry->d_name[1] == '.' && entry->d_name[2] == '\0'))) continue;

        strncpy(lpFindFileData->cFileName, entry->d_name, MAX_PATH - 1);
        lpFindFileData->cFileName[MAX_PATH - 1] = '\0';
        lpFindFileData->dwFileAttributes = (entry->d_type == DT_DIR) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
        return TRUE;
    }
    return FALSE;
}
#define FindNextFile FindNextFileA

inline BOOL FindClose(HANDLE hFindFile) {
    AppleFindData* fd = (AppleFindData*)hFindFile;
    closedir(fd->dir);
    delete fd;
    return TRUE;
}

inline BOOL CreateDirectoryA(LPCSTR lpPathName, LPSECURITY_ATTRIBUTES) {
    return (mkdir(lpPathName, 0755) == 0 || errno == EEXIST) ? TRUE : FALSE;
}
#define CreateDirectory CreateDirectoryA

inline BOOL DeleteFileA(LPCSTR lpFileName) {
    return (unlink(lpFileName) == 0) ? TRUE : FALSE;
}
#define DeleteFile DeleteFileA

inline BOOL MoveFileA(LPCSTR lpExistingFileName, LPCSTR lpNewFileName) {
    return (rename(lpExistingFileName, lpNewFileName) == 0) ? TRUE : FALSE;
}
#define MoveFile MoveFileA

inline DWORD GetLastError() {
    return (DWORD)errno;
}

inline VOID GlobalMemoryStatus(LPMEMORYSTATUS lpBuffer) {
    memset(lpBuffer, 0, sizeof(MEMORYSTATUS));
    // Return reasonable defaults for game use
    lpBuffer->dwTotalPhys = 8UL * 1024 * 1024 * 1024; // 8GB
    lpBuffer->dwAvailPhys = 4UL * 1024 * 1024 * 1024; // 4GB
}

// ============================================================================
// VirtualAlloc / VirtualFree using mmap
// ============================================================================
inline LPVOID VirtualAlloc(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD) {
    // For MEM_RESERVE, just reserve address space
    // For MEM_COMMIT, actually allocate
    int prot = PROT_READ | PROT_WRITE;
    int flags = MAP_PRIVATE | MAP_ANON;
    if (lpAddress) flags |= MAP_FIXED;

    void* result = mmap(lpAddress, dwSize, prot, flags, -1, 0);
    if (result == MAP_FAILED) return nullptr;
    return result;
}

inline BOOL VirtualFree(LPVOID lpAddress, SIZE_T dwSize, DWORD) {
    if (dwSize == 0) dwSize = 1; // munmap requires non-zero
    munmap(lpAddress, dwSize);
    return TRUE;
}

// ============================================================================
// String helpers
// ============================================================================
inline int _stricmp(const char* a, const char* b) { return strcasecmp(a, b); }
inline int _strnicmp(const char* a, const char* b, size_t n) { return strncasecmp(a, b, n); }
inline int _wcsicmp(const wchar_t* a, const wchar_t* b) { return wcscasecmp(a, b); }
inline char* _strlwr(char* str) { for (char* p = str; *p; ++p) *p = tolower(*p); return str; }
inline char* _strupr(char* str) { for (char* p = str; *p; ++p) *p = toupper(*p); return str; }

inline int sprintf_s(char* buf, size_t sz, const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vsnprintf(buf, sz, fmt, args);
    va_end(args); return ret;
}
// Array overload: sprintf_s(char buf[N], fmt, ...)
template<size_t N>
inline int sprintf_s(char (&buf)[N], const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vsnprintf(buf, N, fmt, args);
    va_end(args); return ret;
}
inline int swprintf_s(wchar_t* buf, size_t sz, const wchar_t* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args); return ret;
}
inline int swprintf_s(wchar_t* buf, int sz, const wchar_t* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args); return ret;
}
inline int _snprintf(char* buf, size_t sz, const char* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vsnprintf(buf, sz, fmt, args);
    va_end(args); return ret;
}
inline int _snwprintf(wchar_t* buf, size_t sz, const wchar_t* fmt, ...) {
    va_list args; va_start(args, fmt);
    int ret = vswprintf(buf, sz, fmt, args);
    va_end(args); return ret;
}

inline errno_t fopen_s(FILE** f, const char* name, const char* mode) {
    *f = fopen(name, mode);
    return *f ? 0 : errno;
}

inline int wcscpy_s(wchar_t* dst, size_t dstSz, const wchar_t* src) {
    if (!dst || !src) return -1;
    wcsncpy(dst, src, dstSz);
    if (dstSz > 0) dst[dstSz - 1] = L'\0';
    return 0;
}

inline int strcpy_s(char* dst, size_t dstSz, const char* src) {
    if (!dst || !src) return -1;
    strncpy(dst, src, dstSz);
    if (dstSz > 0) dst[dstSz - 1] = '\0';
    return 0;
}

inline errno_t _itoa_s(int value, char* buf, size_t sz, int radix) {
    if (radix == 10) snprintf(buf, sz, "%d", value);
    else if (radix == 16) snprintf(buf, sz, "%x", value);
    else return -1;
    return 0;
}

inline errno_t _i64toa_s(int64_t value, char* buf, size_t sz, int radix) {
    if (radix == 10) snprintf(buf, sz, "%lld", (long long)value);
    else if (radix == 16) snprintf(buf, sz, "%llx", (long long)value);
    else return -1;
    return 0;
}

// _itow - convert int to wide string
inline wchar_t* _itow(int value, wchar_t* buf, int radix) {
    if (radix == 10) swprintf(buf, 64, L"%d", value);
    else if (radix == 16) swprintf(buf, 64, L"%x", value);
    else if (radix == 36) {
        // Base-36 conversion (used for chunk storage paths)
        const wchar_t digits[] = L"0123456789abcdefghijklmnopqrstuvwxyz";
        wchar_t tmp[64];
        int i = 0;
        bool neg = (value < 0);
        unsigned int uval = neg ? (unsigned int)(-value) : (unsigned int)value;
        if (uval == 0) { buf[0] = L'0'; buf[1] = L'\0'; return buf; }
        while (uval > 0) { tmp[i++] = digits[uval % 36]; uval /= 36; }
        int j = 0;
        if (neg) buf[j++] = L'-';
        while (i > 0) buf[j++] = tmp[--i];
        buf[j] = L'\0';
    }
    else buf[0] = L'\0';
    return buf;
}

// _itow_s - secure version of _itow
inline errno_t _itow_s(int value, wchar_t* buf, size_t sz, int radix) {
    _itow(value, buf, radix);
    return 0;
}
// Overload: _itow_s(value, buf, radix) with buf as array
template<size_t N>
inline errno_t _itow_s(int value, wchar_t (&buf)[N], int radix) {
    _itow(value, buf, radix);
    return 0;
}

// WideCharToMultiByte / MultiByteToWideChar
inline int WideCharToMultiByte(unsigned int, unsigned int, const wchar_t* src, int srcLen,
                                char* dst, int dstLen, const char*, const int*) {
    if (!dst || dstLen == 0) return (int)wcstombs(nullptr, src, 0) + 1;
    size_t len = wcstombs(dst, src, dstLen);
    if (len == (size_t)-1) return 0;
    if ((int)len < dstLen) dst[len] = '\0';
    return (int)len + 1;
}

inline int MultiByteToWideChar(unsigned int, unsigned int, const char* src, int srcLen,
                                wchar_t* dst, int dstLen) {
    if (!dst || dstLen == 0) return (int)mbstowcs(nullptr, src, 0) + 1;
    size_t len = mbstowcs(dst, src, dstLen);
    if (len == (size_t)-1) return 0;
    if ((int)len < dstLen) dst[len] = L'\0';
    return (int)len + 1;
}

// ============================================================================
// Fake D3D11 types for API compatibility
// ============================================================================
typedef struct { int unused; } *ID3D11Device;
typedef struct { int unused; } *ID3D11DeviceContext;
typedef struct { int unused; } *IDXGISwapChain;
typedef struct { int unused; } *ID3D11Buffer;
typedef struct { int unused; } *ID3D11ShaderResourceView;
typedef struct { int unused; } *ID3D11RenderTargetView;
typedef struct { int unused; } *ID3D11DepthStencilView;
typedef struct { int unused; } *ID3D11Texture2D;
typedef struct { int unused; } *ID3D11VertexShader;
typedef struct { int unused; } *ID3D11PixelShader;
typedef struct { int unused; } *ID3D11SamplerState;
typedef struct { int unused; } *ID3D11RasterizerState;
typedef struct { int unused; } *ID3D11DepthStencilState;
typedef struct { int unused; } *ID3D11BlendState;
typedef struct { int unused; } *ID3D11InputLayout;

typedef RECT D3D11_RECT;

// D3D11_VIEWPORT
typedef struct D3D11_VIEWPORT {
    FLOAT TopLeftX;
    FLOAT TopLeftY;
    FLOAT Width;
    FLOAT Height;
    FLOAT MinDepth;
    FLOAT MaxDepth;
} D3D11_VIEWPORT;

// D3D11 blend constants
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

// ============================================================================
// Interlocked atomic intrinsics
// ============================================================================
inline LONG InterlockedCompareExchangeRelease(volatile LONG* dest, LONG exchange, LONG comparand) {
    return __sync_val_compare_and_swap(dest, comparand, exchange);
}

inline int64_t InterlockedCompareExchangeRelease64(volatile int64_t* dest, int64_t exchange, int64_t comparand) {
    return __sync_val_compare_and_swap(dest, comparand, exchange);
}

inline LONG InterlockedIncrement(volatile LONG* addend) {
    return __sync_add_and_fetch(addend, 1);
}

inline LONG InterlockedDecrement(volatile LONG* addend) {
    return __sync_sub_and_fetch(addend, 1);
}

inline LONG InterlockedExchange(volatile LONG* target, LONG value) {
    return __sync_lock_test_and_set(target, value);
}

// ============================================================================
// alloca
// ============================================================================
#include <alloca.h>
#define _alloca alloca
#define _malloca alloca
#define _freea(p)

// ============================================================================
// tchar compat
// ============================================================================
#define _tcslen strlen
#define _tcscpy strcpy
#define _tcscat strcat

// ============================================================================
// __debugbreak
// ============================================================================
#if defined(__aarch64__)
#define __debugbreak() __asm__ volatile("brk #0")
#elif defined(__x86_64__)
#define __debugbreak() __asm__ volatile("int3")
#else
#define __debugbreak() __builtin_trap()
#endif

// ============================================================================
// Thread-local storage (TLS) using pthreads
// ============================================================================
inline DWORD AppleTlsAlloc() { pthread_key_t k; pthread_key_create(&k, nullptr); return (DWORD)k; }
#define TlsAlloc() AppleTlsAlloc()
#define TlsSetValue(idx, val) pthread_setspecific((pthread_key_t)(idx), (val))
#define TlsGetValue(idx) pthread_getspecific((pthread_key_t)(idx))

// ============================================================================
// __declspec(thread) -> thread_local
// ============================================================================
#define __declspec(x) __declspec_##x
#define __declspec_thread thread_local

// ============================================================================
// Misc stubs
// ============================================================================
inline HMODULE GetModuleHandle(LPCSTR) { return nullptr; }

// _wfopen_s - wide-char file open (convert to narrow and use fopen)
inline errno_t _wfopen_s(FILE** f, const wchar_t* name, const wchar_t* mode) {
    char narrowName[1024];
    char narrowMode[32];
    wcstombs(narrowName, name, sizeof(narrowName));
    wcstombs(narrowMode, mode, sizeof(narrowMode));
    *f = fopen(narrowName, narrowMode);
    return *f ? 0 : errno;
}

// GUID struct (used by DirectSound in miniaudio, etc.)
typedef struct _GUID {
    unsigned int   Data1;
    unsigned short Data2;
    unsigned short Data3;
    unsigned char  Data4[8];
} GUID, *LPGUID;
typedef const GUID *LPCGUID;

// Additional Windows types that may be needed
typedef ULONG_PTR DWORD_PTR;
typedef long      INT_PTR;
typedef unsigned long UINT_PTR;

// PCWSTR - pointer to const wide string
typedef const wchar_t *PCWSTR;

// SetFilePointerEx
inline BOOL SetFilePointerEx(HANDLE hFile, LARGE_INTEGER liDistanceToMove, LARGE_INTEGER* lpNewFilePointer, DWORD dwMoveMethod) {
    int fd = _HANDLE_TO_FD(hFile);
    int whence = SEEK_SET;
    switch (dwMoveMethod) {
        case FILE_BEGIN:   whence = SEEK_SET; break;
        case FILE_CURRENT: whence = SEEK_CUR; break;
        case FILE_END:     whence = SEEK_END; break;
    }
    off_t result = lseek(fd, (off_t)liDistanceToMove.QuadPart, whence);
    if (result == (off_t)-1) return FALSE;
    if (lpNewFilePointer) lpNewFilePointer->QuadPart = result;
    return TRUE;
}

// FlushFileBuffers
inline BOOL FlushFileBuffers(HANDLE hFile) {
    int fd = _HANDLE_TO_FD(hFile);
    return (fsync(fd) == 0) ? TRUE : FALSE;
}

// GetCurrentDirectoryA
inline DWORD GetCurrentDirectoryA(DWORD nBufferLength, LPSTR lpBuffer) {
    if (getcwd(lpBuffer, nBufferLength)) return (DWORD)strlen(lpBuffer);
    return 0;
}
#define GetCurrentDirectory GetCurrentDirectoryA

// SetCurrentDirectoryA
inline BOOL SetCurrentDirectoryA(LPCSTR lpPathName) {
    return (chdir(lpPathName) == 0) ? TRUE : FALSE;
}
#define SetCurrentDirectory SetCurrentDirectoryA

// XGetLanguage / XGetLocale / XEnableGuestSignin - declared in extraX64.h,
// implemented in Apple platform code
