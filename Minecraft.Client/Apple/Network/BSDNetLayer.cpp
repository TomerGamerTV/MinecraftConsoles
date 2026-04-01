// BSDNetLayer.cpp — BSD socket networking implementation for Apple platforms
// Mirrors WinsockNetLayer.cpp using POSIX sockets and pthreads.
// Code structure by LCEMP, adapted for macOS/iOS.

#if defined(__APPLE__)

#include "BSDNetLayer.h"

#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <algorithm>
#include <pthread.h>

// ── Helper: receive exactly `len` bytes (blocking) ───────────────────────────

static bool RecvExact(SOCKET_T sock, uint8_t* buf, int len)
{
    int received = 0;
    while (received < len)
    {
        ssize_t r = recv(sock, buf + received, len - received, 0);
        if (r <= 0)
            return false;
        received += (int)r;
    }
    return true;
}

// ── Static member definitions ────────────────────────────────────────────────

SOCKET_T BSDNetLayer::s_listenSocket          = INVALID_SOCKET_T;
SOCKET_T BSDNetLayer::s_hostConnectionSocket  = INVALID_SOCKET_T;
pthread_t BSDNetLayer::s_acceptThread         = 0;
pthread_t BSDNetLayer::s_clientRecvThread     = 0;

bool BSDNetLayer::s_isHost       = false;
bool BSDNetLayer::s_connected    = false;
bool BSDNetLayer::s_active       = false;
bool BSDNetLayer::s_initialized  = false;

uint8_t     BSDNetLayer::s_localSmallId   = 0;
uint8_t     BSDNetLayer::s_hostSmallId    = 0;
unsigned int BSDNetLayer::s_nextSmallId   = XUSER_MAX_COUNT;

pthread_mutex_t BSDNetLayer::s_sendLock        = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t BSDNetLayer::s_connectionsLock = PTHREAD_MUTEX_INITIALIZER;

std::vector<AppleRemoteConnection> BSDNetLayer::s_connections;

SOCKET_T     BSDNetLayer::s_advertiseSock   = INVALID_SOCKET_T;
pthread_t    BSDNetLayer::s_advertiseThread = 0;
volatile bool BSDNetLayer::s_advertising    = false;
AppleLANBroadcast BSDNetLayer::s_advertiseData = {};
pthread_mutex_t BSDNetLayer::s_advertiseLock = PTHREAD_MUTEX_INITIALIZER;
int          BSDNetLayer::s_hostGamePort     = 0;

SOCKET_T     BSDNetLayer::s_discoverySock    = INVALID_SOCKET_T;
pthread_t    BSDNetLayer::s_discoveryThread  = 0;
volatile bool BSDNetLayer::s_discovering     = false;
pthread_mutex_t BSDNetLayer::s_discoveryLock = PTHREAD_MUTEX_INITIALIZER;
std::vector<AppleLANSession> BSDNetLayer::s_discoveredSessions;

pthread_mutex_t BSDNetLayer::s_disconnectLock  = PTHREAD_MUTEX_INITIALIZER;
std::vector<uint8_t> BSDNetLayer::s_disconnectedSmallIds;

pthread_mutex_t BSDNetLayer::s_freeSmallIdLock = PTHREAD_MUTEX_INITIALIZER;
std::vector<uint8_t> BSDNetLayer::s_freeSmallIds;

SOCKET_T BSDNetLayer::s_smallIdToSocket[256];
pthread_mutex_t BSDNetLayer::s_smallIdToSocketLock = PTHREAD_MUTEX_INITIALIZER;

SOCKET_T BSDNetLayer::s_splitScreenSocket[XUSER_MAX_COUNT];
uint8_t  BSDNetLayer::s_splitScreenSmallId[XUSER_MAX_COUNT];
pthread_t BSDNetLayer::s_splitScreenRecvThread[XUSER_MAX_COUNT];

pthread_t            BSDNetLayer::s_joinThread         = 0;
volatile BSDNetLayer::eJoinState BSDNetLayer::s_joinState = eJoinState_Idle;
volatile int         BSDNetLayer::s_joinAttempt        = 0;
volatile bool        BSDNetLayer::s_joinCancel         = false;
char                 BSDNetLayer::s_joinIP[256]        = {};
int                  BSDNetLayer::s_joinPort           = 0;
uint8_t              BSDNetLayer::s_joinAssignedSmallId = 0;
DisconnectPacket::eDisconnectReason BSDNetLayer::s_joinRejectReason = DisconnectPacket::eDisconnectReason_Generic;

// Multiplayer launch flags
bool g_AppleMultiplayerHost = false;
bool g_AppleMultiplayerJoin = false;
int  g_AppleMultiplayerPort = APPLE_NET_DEFAULT_PORT;
char g_AppleMultiplayerIP[256] = {};

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Lifecycle
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::Initialize()
{
    if (s_initialized) return true;

    // BSD sockets need no WSAStartup — just initialise internal state
    for (int i = 0; i < 256; i++)
        s_smallIdToSocket[i] = INVALID_SOCKET_T;

    for (int i = 0; i < XUSER_MAX_COUNT; i++)
    {
        s_splitScreenSocket[i]    = INVALID_SOCKET_T;
        s_splitScreenSmallId[i]   = APPLE_SMALLID_REJECT;
        s_splitScreenRecvThread[i] = 0;
    }

    s_initialized = true;
    printf("[BSDNet] Initialised\n");
    return true;
}

void BSDNetLayer::Shutdown()
{
    if (!s_initialized) return;

    StopAdvertising();
    StopDiscovery();

    // Close all connections
    pthread_mutex_lock(&s_connectionsLock);
    for (auto& conn : s_connections)
    {
        conn.active = false;
        if (conn.tcpSocket != INVALID_SOCKET_T)
        {
            close(conn.tcpSocket);
            conn.tcpSocket = INVALID_SOCKET_T;
        }
    }
    s_connections.clear();
    pthread_mutex_unlock(&s_connectionsLock);

    if (s_listenSocket != INVALID_SOCKET_T)
    {
        close(s_listenSocket);
        s_listenSocket = INVALID_SOCKET_T;
    }
    if (s_hostConnectionSocket != INVALID_SOCKET_T)
    {
        close(s_hostConnectionSocket);
        s_hostConnectionSocket = INVALID_SOCKET_T;
    }

    for (int i = 0; i < XUSER_MAX_COUNT; i++)
    {
        if (s_splitScreenSocket[i] != INVALID_SOCKET_T)
        {
            close(s_splitScreenSocket[i]);
            s_splitScreenSocket[i] = INVALID_SOCKET_T;
        }
    }

    for (int i = 0; i < 256; i++)
        s_smallIdToSocket[i] = INVALID_SOCKET_T;

    s_isHost      = false;
    s_connected   = false;
    s_active      = false;
    s_initialized = false;
    s_nextSmallId = XUSER_MAX_COUNT;

    printf("[BSDNet] Shutdown complete\n");
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Host
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::HostGame(int port, const char* bindIp)
{
    if (!s_initialized) return false;

    s_listenSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s_listenSocket == INVALID_SOCKET_T)
    {
        printf("[BSDNet] Failed to create listen socket: %s\n", strerror(errno));
        return false;
    }

    // Allow port reuse
    int opt = 1;
    setsockopt(s_listenSocket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    // Disable Nagle's algorithm for lower latency
    setsockopt(s_listenSocket, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(port);
    if (bindIp)
        inet_pton(AF_INET, bindIp, &addr.sin_addr);
    else
        addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(s_listenSocket, (struct sockaddr*)&addr, sizeof(addr)) < 0)
    {
        printf("[BSDNet] bind() failed on port %d: %s\n", port, strerror(errno));
        close(s_listenSocket);
        s_listenSocket = INVALID_SOCKET_T;
        return false;
    }

    if (listen(s_listenSocket, APPLE_NET_MAX_CLIENTS) < 0)
    {
        printf("[BSDNet] listen() failed: %s\n", strerror(errno));
        close(s_listenSocket);
        s_listenSocket = INVALID_SOCKET_T;
        return false;
    }

    s_isHost       = true;
    s_connected    = true;
    s_active       = true;
    s_localSmallId = 0;
    s_hostSmallId  = 0;
    s_hostGamePort = port;

    // Start accept thread
    pthread_create(&s_acceptThread, nullptr, AcceptThreadProc, nullptr);

    printf("[BSDNet] Hosting game on port %d\n", port);
    return true;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Join (synchronous)
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::JoinGame(const char* ip, int port)
{
    if (!s_initialized) return false;

    SOCKET_T sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == INVALID_SOCKET_T) return false;

    int opt = 1;
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

    struct sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(port);
    inet_pton(AF_INET, ip, &addr.sin_addr);

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0)
    {
        printf("[BSDNet] connect() to %s:%d failed: %s\n", ip, port, strerror(errno));
        close(sock);
        return false;
    }

    // Read assigned smallId from host (first byte after connection)
    uint8_t assignedSmallId = 0;
    if (!RecvExact(sock, &assignedSmallId, 1))
    {
        close(sock);
        return false;
    }

    if (assignedSmallId == APPLE_SMALLID_REJECT)
    {
        printf("[BSDNet] Connection rejected by host\n");
        close(sock);
        return false;
    }

    s_hostConnectionSocket = sock;
    s_localSmallId = assignedSmallId;
    s_hostSmallId  = 0;
    s_isHost       = false;
    s_connected    = true;
    s_active       = true;

    // Register in socket map
    pthread_mutex_lock(&s_smallIdToSocketLock);
    s_smallIdToSocket[s_hostSmallId] = sock;
    pthread_mutex_unlock(&s_smallIdToSocketLock);

    // Start client receive thread
    pthread_create(&s_clientRecvThread, nullptr, ClientRecvThreadProc, nullptr);

    printf("[BSDNet] Joined game at %s:%d, smallId=%d\n", ip, port, assignedSmallId);
    return true;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Join (asynchronous)
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::BeginJoinGame(const char* ip, int port)
{
    if (!s_initialized) return false;
    if (s_joinState == eJoinState_Connecting) return false;

    strncpy(s_joinIP, ip, sizeof(s_joinIP) - 1);
    s_joinPort    = port;
    s_joinCancel  = false;
    s_joinAttempt = 0;
    s_joinState   = eJoinState_Connecting;

    pthread_create(&s_joinThread, nullptr, JoinThreadProc, nullptr);
    return true;
}

void BSDNetLayer::CancelJoinGame()
{
    s_joinCancel = true;
    s_joinState  = eJoinState_Cancelled;
}

BSDNetLayer::eJoinState BSDNetLayer::GetJoinState()  { return s_joinState; }
int BSDNetLayer::GetJoinAttempt()                     { return s_joinAttempt; }
int BSDNetLayer::GetJoinMaxAttempts()                 { return JOIN_MAX_ATTEMPTS; }
DisconnectPacket::eDisconnectReason BSDNetLayer::GetJoinRejectReason() { return s_joinRejectReason; }

bool BSDNetLayer::FinalizeJoin()
{
    if (s_joinState != eJoinState_Success) return false;
    s_joinState = eJoinState_Idle;
    return true;
}

void* BSDNetLayer::JoinThreadProc(void* param)
{
    for (int attempt = 0; attempt < JOIN_MAX_ATTEMPTS && !s_joinCancel; attempt++)
    {
        s_joinAttempt = attempt + 1;

        if (JoinGame(s_joinIP, s_joinPort))
        {
            s_joinState = eJoinState_Success;
            return nullptr;
        }

        if (s_joinCancel) break;

        // Brief delay before retry
        usleep(500000); // 500ms
    }

    if (!s_joinCancel)
        s_joinState = eJoinState_Failed;

    return nullptr;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Send
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::SendOnSocket(SOCKET_T sock, const void* data, int dataSize)
{
    if (sock == INVALID_SOCKET_T || !data || dataSize <= 0) return false;

    // Send 4-byte length header followed by payload (same framing as Windows)
    uint32_t header = (uint32_t)dataSize;
    pthread_mutex_lock(&s_sendLock);

    ssize_t sent = send(sock, &header, sizeof(header), 0);
    if (sent != sizeof(header))
    {
        pthread_mutex_unlock(&s_sendLock);
        return false;
    }

    int totalSent = 0;
    while (totalSent < dataSize)
    {
        sent = send(sock, (const char*)data + totalSent, dataSize - totalSent, 0);
        if (sent <= 0)
        {
            pthread_mutex_unlock(&s_sendLock);
            return false;
        }
        totalSent += (int)sent;
    }

    pthread_mutex_unlock(&s_sendLock);
    return true;
}

bool BSDNetLayer::SendToSmallId(uint8_t targetSmallId, const void* data, int dataSize)
{
    SOCKET_T sock = GetSocketForSmallId(targetSmallId);
    return SendOnSocket(sock, data, dataSize);
}

SOCKET_T BSDNetLayer::GetSocketForSmallId(uint8_t smallId)
{
    pthread_mutex_lock(&s_smallIdToSocketLock);
    SOCKET_T sock = s_smallIdToSocket[smallId];
    pthread_mutex_unlock(&s_smallIdToSocketLock);
    return sock;
}

void BSDNetLayer::ClearSocketForSmallId(uint8_t smallId)
{
    pthread_mutex_lock(&s_smallIdToSocketLock);
    s_smallIdToSocket[smallId] = INVALID_SOCKET_T;
    pthread_mutex_unlock(&s_smallIdToSocketLock);
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Disconnection queue
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::PopDisconnectedSmallId(uint8_t* outSmallId)
{
    pthread_mutex_lock(&s_disconnectLock);
    if (s_disconnectedSmallIds.empty())
    {
        pthread_mutex_unlock(&s_disconnectLock);
        return false;
    }
    *outSmallId = s_disconnectedSmallIds.back();
    s_disconnectedSmallIds.pop_back();
    pthread_mutex_unlock(&s_disconnectLock);
    return true;
}

void BSDNetLayer::PushFreeSmallId(uint8_t smallId)
{
    pthread_mutex_lock(&s_freeSmallIdLock);
    s_freeSmallIds.push_back(smallId);
    pthread_mutex_unlock(&s_freeSmallIdLock);
}

void BSDNetLayer::CloseConnectionBySmallId(uint8_t smallId)
{
    SOCKET_T sock = GetSocketForSmallId(smallId);
    if (sock != INVALID_SOCKET_T)
    {
        close(sock);
        ClearSocketForSmallId(smallId);
    }

    pthread_mutex_lock(&s_connectionsLock);
    for (auto& conn : s_connections)
    {
        if (conn.smallId == smallId)
        {
            conn.active = false;
            break;
        }
    }
    pthread_mutex_unlock(&s_connectionsLock);
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Split screen stubs
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::JoinSplitScreen(int padIndex, uint8_t* outSmallId)
{
    // TODO: Open additional TCP connection to host for pad `padIndex`
    return false;
}

void BSDNetLayer::CloseSplitScreenConnection(int padIndex)
{
    if (padIndex < 0 || padIndex >= XUSER_MAX_COUNT) return;
    if (s_splitScreenSocket[padIndex] != INVALID_SOCKET_T)
    {
        close(s_splitScreenSocket[padIndex]);
        s_splitScreenSocket[padIndex] = INVALID_SOCKET_T;
    }
}

SOCKET_T BSDNetLayer::GetLocalSocket(uint8_t senderSmallId)
{
    if (senderSmallId == s_localSmallId)
        return s_hostConnectionSocket;

    for (int i = 0; i < XUSER_MAX_COUNT; i++)
    {
        if (s_splitScreenSmallId[i] == senderSmallId)
            return s_splitScreenSocket[i];
    }
    return INVALID_SOCKET_T;
}

uint8_t BSDNetLayer::GetSplitScreenSmallId(int padIndex)
{
    if (padIndex < 0 || padIndex >= XUSER_MAX_COUNT)
        return APPLE_SMALLID_REJECT;
    return s_splitScreenSmallId[padIndex];
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Accept thread (host only)
// ══════════════════════════════════════════════════════════════════════════════

void* BSDNetLayer::AcceptThreadProc(void* param)
{
    while (s_active && s_isHost)
    {
        struct sockaddr_in clientAddr = {};
        socklen_t addrLen = sizeof(clientAddr);

        SOCKET_T clientSock = accept(s_listenSocket, (struct sockaddr*)&clientAddr, &addrLen);
        if (clientSock == INVALID_SOCKET_T)
        {
            if (!s_active) break;
            continue;
        }

        int opt = 1;
        setsockopt(clientSock, IPPROTO_TCP, TCP_NODELAY, &opt, sizeof(opt));

        // Assign a smallId
        uint8_t assignedId = APPLE_SMALLID_REJECT;

        pthread_mutex_lock(&s_freeSmallIdLock);
        if (!s_freeSmallIds.empty())
        {
            assignedId = s_freeSmallIds.back();
            s_freeSmallIds.pop_back();
        }
        pthread_mutex_unlock(&s_freeSmallIdLock);

        if (assignedId == APPLE_SMALLID_REJECT)
        {
            assignedId = (uint8_t)s_nextSmallId;
            if (s_nextSmallId < APPLE_NET_MAX_CLIENTS)
                s_nextSmallId++;
            else
                assignedId = APPLE_SMALLID_REJECT;
        }

        // Send the assigned ID to the client
        send(clientSock, &assignedId, 1, 0);

        if (assignedId == APPLE_SMALLID_REJECT)
        {
            close(clientSock);
            continue;
        }

        // Register connection
        AppleRemoteConnection conn = {};
        conn.tcpSocket = clientSock;
        conn.smallId   = assignedId;
        conn.active    = true;

        pthread_mutex_lock(&s_connectionsLock);
        s_connections.push_back(conn);
        pthread_mutex_unlock(&s_connectionsLock);

        pthread_mutex_lock(&s_smallIdToSocketLock);
        s_smallIdToSocket[assignedId] = clientSock;
        pthread_mutex_unlock(&s_smallIdToSocketLock);

        // Start a receive thread for this client
        AppleRemoteConnection* connPtr = &s_connections.back();
        pthread_create(&connPtr->recvThread, nullptr, RecvThreadProc, (void*)(uintptr_t)assignedId);

        char ipStr[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &clientAddr.sin_addr, ipStr, sizeof(ipStr));
        printf("[BSDNet] Client connected from %s, assigned smallId=%d\n", ipStr, assignedId);
    }

    return nullptr;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Receive threads
// ══════════════════════════════════════════════════════════════════════════════

void* BSDNetLayer::RecvThreadProc(void* param)
{
    uint8_t smallId = (uint8_t)(uintptr_t)param;
    SOCKET_T sock   = GetSocketForSmallId(smallId);

    uint8_t* recvBuf = new uint8_t[APPLE_NET_RECV_BUFFER_SIZE];

    while (s_active)
    {
        // Read 4-byte length header
        uint32_t packetLen = 0;
        if (!RecvExact(sock, (uint8_t*)&packetLen, 4))
            break;

        if (packetLen > APPLE_NET_MAX_PACKET_SIZE)
        {
            printf("[BSDNet] Packet too large from smallId=%d: %u bytes\n", smallId, packetLen);
            break;
        }

        // Read payload
        uint8_t* payload = (packetLen <= APPLE_NET_RECV_BUFFER_SIZE)
            ? recvBuf
            : new uint8_t[packetLen];

        if (!RecvExact(sock, payload, (int)packetLen))
        {
            if (payload != recvBuf) delete[] payload;
            break;
        }

        // Dispatch to game code
        HandleDataReceived(smallId, s_localSmallId, payload, packetLen);

        if (payload != recvBuf) delete[] payload;
    }

    delete[] recvBuf;

    // Signal disconnection
    pthread_mutex_lock(&s_disconnectLock);
    s_disconnectedSmallIds.push_back(smallId);
    pthread_mutex_unlock(&s_disconnectLock);

    printf("[BSDNet] Recv thread exiting for smallId=%d\n", smallId);
    return nullptr;
}

void* BSDNetLayer::ClientRecvThreadProc(void* param)
{
    SOCKET_T sock = s_hostConnectionSocket;
    uint8_t* recvBuf = new uint8_t[APPLE_NET_RECV_BUFFER_SIZE];

    while (s_active && s_connected)
    {
        uint32_t packetLen = 0;
        if (!RecvExact(sock, (uint8_t*)&packetLen, 4))
            break;

        if (packetLen > APPLE_NET_MAX_PACKET_SIZE)
            break;

        uint8_t* payload = (packetLen <= APPLE_NET_RECV_BUFFER_SIZE)
            ? recvBuf
            : new uint8_t[packetLen];

        if (!RecvExact(sock, payload, (int)packetLen))
        {
            if (payload != recvBuf) delete[] payload;
            break;
        }

        HandleDataReceived(s_hostSmallId, s_localSmallId, payload, packetLen);

        if (payload != recvBuf) delete[] payload;
    }

    delete[] recvBuf;

    s_connected = false;
    printf("[BSDNet] Client recv thread exiting (disconnected from host)\n");
    return nullptr;
}

void* BSDNetLayer::SplitScreenRecvThreadProc(void* param)
{
    // TODO: Same as ClientRecvThreadProc but for split-screen pad sockets
    return nullptr;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Data dispatch
// ══════════════════════════════════════════════════════════════════════════════

void BSDNetLayer::HandleDataReceived(uint8_t fromSmallId, uint8_t toSmallId,
                                     unsigned char* data, unsigned int dataSize)
{
    // Forward to the platform-agnostic network manager
    // Same as Windows: calls into IQNet / NetworkPlayerInterface
    // TODO: g_NetworkManager.OnDataReceived(fromSmallId, toSmallId, data, dataSize);
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - LAN Advertising (UDP broadcast)
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::StartAdvertising(int gamePort, const wchar_t* hostName,
                                   unsigned int gameSettings, unsigned int texPackId,
                                   unsigned char subTexId, unsigned short netVer)
{
    if (s_advertising) return true;

    s_advertiseSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (s_advertiseSock == INVALID_SOCKET_T) return false;

    // Enable broadcast
    int opt = 1;
    setsockopt(s_advertiseSock, SOL_SOCKET, SO_BROADCAST, &opt, sizeof(opt));

    // Fill broadcast data
    memset(&s_advertiseData, 0, sizeof(s_advertiseData));
    s_advertiseData.magic               = APPLE_LAN_BROADCAST_MAGIC;
    s_advertiseData.netVersion          = netVer;
    s_advertiseData.gamePort            = (uint16_t)gamePort;
    s_advertiseData.playerCount         = 1;
    s_advertiseData.maxPlayers          = 8;
    s_advertiseData.gameHostSettings    = gameSettings;
    s_advertiseData.texturePackParentId = texPackId;
    s_advertiseData.subTexturePackId    = subTexId;
    s_advertiseData.isJoinable          = 1;
    if (hostName)
        wcsncpy(s_advertiseData.hostName, hostName, 31);

    s_advertising = true;
    s_hostGamePort = gamePort;

    pthread_create(&s_advertiseThread, nullptr, AdvertiseThreadProc, nullptr);
    printf("[BSDNet] LAN advertising started on port %d\n", APPLE_LAN_DISCOVERY_PORT);
    return true;
}

void BSDNetLayer::StopAdvertising()
{
    s_advertising = false;
    if (s_advertiseSock != INVALID_SOCKET_T)
    {
        close(s_advertiseSock);
        s_advertiseSock = INVALID_SOCKET_T;
    }
}

void BSDNetLayer::UpdateAdvertisePlayerCount(uint8_t count)
{
    pthread_mutex_lock(&s_advertiseLock);
    s_advertiseData.playerCount = count;
    pthread_mutex_unlock(&s_advertiseLock);
}

void BSDNetLayer::UpdateAdvertiseMaxPlayers(uint8_t maxPlayers)
{
    pthread_mutex_lock(&s_advertiseLock);
    s_advertiseData.maxPlayers = maxPlayers;
    pthread_mutex_unlock(&s_advertiseLock);
}

void BSDNetLayer::UpdateAdvertiseJoinable(bool joinable)
{
    pthread_mutex_lock(&s_advertiseLock);
    s_advertiseData.isJoinable = joinable ? 1 : 0;
    pthread_mutex_unlock(&s_advertiseLock);
}

void* BSDNetLayer::AdvertiseThreadProc(void* param)
{
    struct sockaddr_in broadcastAddr = {};
    broadcastAddr.sin_family      = AF_INET;
    broadcastAddr.sin_port        = htons(APPLE_LAN_DISCOVERY_PORT);
    broadcastAddr.sin_addr.s_addr = INADDR_BROADCAST;

    while (s_advertising)
    {
        pthread_mutex_lock(&s_advertiseLock);
        AppleLANBroadcast data = s_advertiseData;
        pthread_mutex_unlock(&s_advertiseLock);

        sendto(s_advertiseSock, &data, sizeof(data), 0,
               (struct sockaddr*)&broadcastAddr, sizeof(broadcastAddr));

        // Broadcast every 2 seconds
        usleep(2000000);
    }

    return nullptr;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - LAN Discovery
// ══════════════════════════════════════════════════════════════════════════════

bool BSDNetLayer::StartDiscovery()
{
    if (s_discovering) return true;

    s_discoverySock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (s_discoverySock == INVALID_SOCKET_T) return false;

    int opt = 1;
    setsockopt(s_discoverySock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    #ifdef SO_REUSEPORT
    setsockopt(s_discoverySock, SOL_SOCKET, SO_REUSEPORT, &opt, sizeof(opt));
    #endif

    struct sockaddr_in addr = {};
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons(APPLE_LAN_DISCOVERY_PORT);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(s_discoverySock, (struct sockaddr*)&addr, sizeof(addr)) < 0)
    {
        printf("[BSDNet] Discovery bind() failed: %s\n", strerror(errno));
        close(s_discoverySock);
        s_discoverySock = INVALID_SOCKET_T;
        return false;
    }

    s_discovering = true;

    pthread_mutex_lock(&s_discoveryLock);
    s_discoveredSessions.clear();
    pthread_mutex_unlock(&s_discoveryLock);

    pthread_create(&s_discoveryThread, nullptr, DiscoveryThreadProc, nullptr);
    printf("[BSDNet] LAN discovery started\n");
    return true;
}

void BSDNetLayer::StopDiscovery()
{
    s_discovering = false;
    if (s_discoverySock != INVALID_SOCKET_T)
    {
        close(s_discoverySock);
        s_discoverySock = INVALID_SOCKET_T;
    }
}

std::vector<AppleLANSession> BSDNetLayer::GetDiscoveredSessions()
{
    pthread_mutex_lock(&s_discoveryLock);
    std::vector<AppleLANSession> copy = s_discoveredSessions;
    pthread_mutex_unlock(&s_discoveryLock);
    return copy;
}

void* BSDNetLayer::DiscoveryThreadProc(void* param)
{
    uint8_t recvBuf[4096];

    while (s_discovering)
    {
        // Use select() with a timeout so we can check s_discovering periodically
        fd_set readSet;
        FD_ZERO(&readSet);
        FD_SET(s_discoverySock, &readSet);

        struct timeval timeout = {};
        timeout.tv_sec  = 1;
        timeout.tv_usec = 0;

        int ready = select(s_discoverySock + 1, &readSet, nullptr, nullptr, &timeout);
        if (ready <= 0) continue;

        struct sockaddr_in senderAddr = {};
        socklen_t addrLen = sizeof(senderAddr);
        ssize_t received = recvfrom(s_discoverySock, recvBuf, sizeof(recvBuf), 0,
                                     (struct sockaddr*)&senderAddr, &addrLen);

        if (received < (ssize_t)sizeof(AppleLANBroadcast))
            continue;

        AppleLANBroadcast* bcast = (AppleLANBroadcast*)recvBuf;
        if (bcast->magic != APPLE_LAN_BROADCAST_MAGIC)
            continue;

        // Build session entry
        AppleLANSession session = {};
        inet_ntop(AF_INET, &senderAddr.sin_addr, session.hostIP, sizeof(session.hostIP));
        session.hostPort           = bcast->gamePort;
        wcsncpy(session.hostName, bcast->hostName, 31);
        session.netVersion         = bcast->netVersion;
        session.playerCount        = bcast->playerCount;
        session.maxPlayers         = bcast->maxPlayers;
        session.gameHostSettings   = bcast->gameHostSettings;
        session.texturePackParentId = bcast->texturePackParentId;
        session.subTexturePackId   = bcast->subTexturePackId;
        session.isJoinable         = bcast->isJoinable != 0;
        // lastSeenTick would be set by the game tick counter
        session.lastSeenTick       = 0;

        // Update or add to discovered sessions
        pthread_mutex_lock(&s_discoveryLock);
        bool found = false;
        for (auto& existing : s_discoveredSessions)
        {
            if (strcmp(existing.hostIP, session.hostIP) == 0 && existing.hostPort == session.hostPort)
            {
                existing = session;
                found = true;
                break;
            }
        }
        if (!found)
            s_discoveredSessions.push_back(session);
        pthread_mutex_unlock(&s_discoveryLock);
    }

    return nullptr;
}

#endif // __APPLE__
