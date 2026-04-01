// BSDNetLayer.h — BSD socket networking for Apple platforms
// Same API as WinsockNetLayer (Windows64) but uses POSIX BSD sockets.
// Code structure by LCEMP, adapted for macOS/iOS.

#pragma once

#if defined(__APPLE__)

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include <vector>

#include "../../Common/Network/NetworkPlayerInterface.h"
#include "../../../Minecraft.World/DisconnectPacket.h"

#define APPLE_NET_DEFAULT_PORT       25565
#define APPLE_NET_MAX_CLIENTS        255
#define APPLE_SMALLID_REJECT         0xFF
#define APPLE_NET_RECV_BUFFER_SIZE   65536
#define APPLE_NET_MAX_PACKET_SIZE    (4 * 1024 * 1024)
#define APPLE_LAN_DISCOVERY_PORT     25566
#define APPLE_LAN_BROADCAST_MAGIC    0x4D434C4E  // "MCLN" — same as Windows

// Maximum local players (matches XUSER_MAX_COUNT from Windows)
#ifndef XUSER_MAX_COUNT
#define XUSER_MAX_COUNT 4
#endif

// Portable socket type
typedef int SOCKET_T;
#define INVALID_SOCKET_T (-1)

class Socket;

// ── LAN broadcast packet (same binary layout as Win64LANBroadcast) ───────────

#pragma pack(push, 1)
struct AppleLANBroadcast
{
    uint32_t magic;                // APPLE_LAN_BROADCAST_MAGIC
    uint16_t netVersion;
    uint16_t gamePort;
    wchar_t  hostName[32];
    uint8_t  playerCount;
    uint8_t  maxPlayers;
    uint32_t gameHostSettings;
    uint32_t texturePackParentId;
    uint8_t  subTexturePackId;
    uint8_t  isJoinable;
};
#pragma pack(pop)

// ── Discovered LAN session ───────────────────────────────────────────────────

struct AppleLANSession
{
    char     hostIP[64];
    int      hostPort;
    wchar_t  hostName[32];
    uint16_t netVersion;
    uint8_t  playerCount;
    uint8_t  maxPlayers;
    uint32_t gameHostSettings;
    uint32_t texturePackParentId;
    uint8_t  subTexturePackId;
    bool     isJoinable;
    uint32_t lastSeenTick;
};

// ── Remote connection descriptor ─────────────────────────────────────────────

struct AppleRemoteConnection
{
    SOCKET_T    tcpSocket;
    uint8_t     smallId;
    pthread_t   recvThread;
    volatile bool active;
};

// ══════════════════════════════════════════════════════════════════════════════
// BSDNetLayer — static class mirroring WinsockNetLayer
// ══════════════════════════════════════════════════════════════════════════════

class BSDNetLayer
{
public:
    // Lifecycle
    static bool Initialize();
    static void Shutdown();

    // Host a game on the given port. bindIp may be nullptr for INADDR_ANY.
    static bool HostGame(int port, const char* bindIp = nullptr);

    // Synchronous join (blocks until connected or failed)
    static bool JoinGame(const char* ip, int port);

    // Asynchronous join (background thread, poll with GetJoinState)
    enum eJoinState
    {
        eJoinState_Idle,
        eJoinState_Connecting,
        eJoinState_Success,
        eJoinState_Failed,
        eJoinState_Rejected,
        eJoinState_Cancelled
    };
    static bool BeginJoinGame(const char* ip, int port);
    static void CancelJoinGame();
    static eJoinState GetJoinState();
    static int  GetJoinAttempt();
    static int  GetJoinMaxAttempts();
    static DisconnectPacket::eDisconnectReason GetJoinRejectReason();
    static bool FinalizeJoin();

    // Send data to a player identified by smallId
    static bool SendToSmallId(uint8_t targetSmallId, const void* data, int dataSize);
    static bool SendOnSocket(SOCKET_T sock, const void* data, int dataSize);

    // Split-screen support (additional TCP connections per pad)
    static bool JoinSplitScreen(int padIndex, uint8_t* outSmallId);
    static void CloseSplitScreenConnection(int padIndex);
    static SOCKET_T GetLocalSocket(uint8_t senderSmallId);
    static uint8_t  GetSplitScreenSmallId(int padIndex);

    // State queries
    static bool IsHosting()   { return s_isHost; }
    static bool IsConnected() { return s_connected; }
    static bool IsActive()    { return s_active; }

    static uint8_t GetLocalSmallId() { return s_localSmallId; }
    static uint8_t GetHostSmallId()  { return s_hostSmallId; }

    static SOCKET_T GetSocketForSmallId(uint8_t smallId);

    // Data receive callback (called from recv threads)
    static void HandleDataReceived(uint8_t fromSmallId, uint8_t toSmallId,
                                   unsigned char* data, unsigned int dataSize);

    // Disconnection queue
    static bool PopDisconnectedSmallId(uint8_t* outSmallId);
    static void PushFreeSmallId(uint8_t smallId);
    static void CloseConnectionBySmallId(uint8_t smallId);

    // LAN advertising (UDP broadcast)
    static bool StartAdvertising(int gamePort, const wchar_t* hostName,
                                 unsigned int gameSettings, unsigned int texPackId,
                                 unsigned char subTexId, unsigned short netVer);
    static void StopAdvertising();
    static void UpdateAdvertisePlayerCount(uint8_t count);
    static void UpdateAdvertiseMaxPlayers(uint8_t maxPlayers);
    static void UpdateAdvertiseJoinable(bool joinable);

    // LAN discovery (listen for broadcasts)
    static bool StartDiscovery();
    static void StopDiscovery();
    static std::vector<AppleLANSession> GetDiscoveredSessions();

    static int GetHostPort() { return s_hostGamePort; }

    // Socket map management
    static void ClearSocketForSmallId(uint8_t smallId);

private:
    // Thread entry points (POSIX thread signature)
    static void* AcceptThreadProc(void* param);
    static void* RecvThreadProc(void* param);
    static void* ClientRecvThreadProc(void* param);
    static void* SplitScreenRecvThreadProc(void* param);
    static void* AdvertiseThreadProc(void* param);
    static void* DiscoveryThreadProc(void* param);
    static void* JoinThreadProc(void* param);

    // Async join state
    static pthread_t            s_joinThread;
    static volatile eJoinState  s_joinState;
    static volatile int         s_joinAttempt;
    static volatile bool        s_joinCancel;
    static char                 s_joinIP[256];
    static int                  s_joinPort;
    static uint8_t              s_joinAssignedSmallId;
    static DisconnectPacket::eDisconnectReason s_joinRejectReason;
    static const int            JOIN_MAX_ATTEMPTS = 4;

    // Sockets and threads
    static SOCKET_T   s_listenSocket;
    static SOCKET_T   s_hostConnectionSocket;
    static pthread_t  s_acceptThread;
    static pthread_t  s_clientRecvThread;

    // State flags
    static bool s_isHost;
    static bool s_connected;
    static bool s_active;
    static bool s_initialized;

    // SmallId tracking
    static uint8_t      s_localSmallId;
    static uint8_t      s_hostSmallId;
    static unsigned int  s_nextSmallId;

    // Mutexes (replacing Windows CRITICAL_SECTION)
    static pthread_mutex_t s_sendLock;
    static pthread_mutex_t s_connectionsLock;

    // Active connections
    static std::vector<AppleRemoteConnection> s_connections;

    // LAN advertising
    static SOCKET_T          s_advertiseSock;
    static pthread_t         s_advertiseThread;
    static volatile bool     s_advertising;
    static AppleLANBroadcast s_advertiseData;
    static pthread_mutex_t   s_advertiseLock;
    static int               s_hostGamePort;

    // LAN discovery
    static SOCKET_T          s_discoverySock;
    static pthread_t         s_discoveryThread;
    static volatile bool     s_discovering;
    static pthread_mutex_t   s_discoveryLock;
    static std::vector<AppleLANSession> s_discoveredSessions;

    // Disconnect queue
    static pthread_mutex_t   s_disconnectLock;
    static std::vector<uint8_t> s_disconnectedSmallIds;

    // Free smallId pool
    static pthread_mutex_t   s_freeSmallIdLock;
    static std::vector<uint8_t> s_freeSmallIds;

    // O(1) smallId -> socket lookup (same as Windows version)
    static SOCKET_T          s_smallIdToSocket[256];
    static pthread_mutex_t   s_smallIdToSocketLock;

    // Per-pad split-screen connections (client-side, non-host only)
    static SOCKET_T   s_splitScreenSocket[XUSER_MAX_COUNT];
    static uint8_t    s_splitScreenSmallId[XUSER_MAX_COUNT];
    static pthread_t  s_splitScreenRecvThread[XUSER_MAX_COUNT];
};

// Multiplayer launch flags (set by command-line / UI before game starts)
extern bool g_AppleMultiplayerHost;
extern bool g_AppleMultiplayerJoin;
extern int  g_AppleMultiplayerPort;
extern char g_AppleMultiplayerIP[256];

#endif // __APPLE__
