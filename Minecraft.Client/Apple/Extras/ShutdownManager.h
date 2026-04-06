#pragma once
#ifndef SHUTDOWN_MANAGER_H
#define SHUTDOWN_MANAGER_H

// ShutdownManager stub for Apple - all methods are no-ops
class ShutdownManager
{
public:
    typedef enum
    {
        eMainThread,
        eLeaderboardThread,
        eCommerceThread,
        ePostProcessThread,
        eRunUpdateThread,
        eRenderChunkUpdateThread,
        eServerThread,
        eStorageManagerThreads,
        eConnectionReadThreads,
        eConnectionWriteThreads,
        eEventQueueThreads,
        eThreadIdCount
    } EThreadId;

    static void Initialise() {}
    static void StartShutdown() {}
    static void MainThreadHandleShutdown() {}
    static bool HasStarted(EThreadId) { return true; }
    static bool HasStarted(EThreadId, C4JThread::EventArray*) { return true; }
    static bool ShouldRun(EThreadId) { return true; }
    static bool HasFinished(EThreadId) { return true; }
};

#endif // SHUTDOWN_MANAGER_H
