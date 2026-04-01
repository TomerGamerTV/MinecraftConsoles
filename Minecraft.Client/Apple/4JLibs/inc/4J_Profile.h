// 4J_Profile.h - Apple platform profile manager
// Same class API as the Windows C_4JProfile but with Apple-compatible types.
// Xbox Live, rich presence, and achievements are stubbed because they do not
// exist on Apple platforms.

#pragma once

#include "../../AppleTypes.h"
#include <string>

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
class C4JStringTable;

// CXuiStringTable stub - Xbox UI string table does not exist on Apple
typedef C4JStringTable CXuiStringTable;

// PlayerUID - simple wrapper on Apple (no Xbox Live XUID)
class PlayerUID
{
public:
    uint64_t uid;

    PlayerUID() : uid(0) {}
    explicit PlayerUID(uint64_t value) : uid(value) {}

    bool operator==(const PlayerUID &rhs) const { return uid == rhs.uid; }
    bool operator!=(const PlayerUID &rhs) const { return uid != rhs.uid; }

    std::wstring ToString() const { return std::to_wstring(uid); }
};

typedef PlayerUID *PPlayerUID;

// Xbox compat constant
#ifndef XUSER_INDEX_ANY
#define XUSER_INDEX_ANY 0x000000FF
#endif

// ---------------------------------------------------------------------------
// Award / upsell enums (shared across platforms)
// ---------------------------------------------------------------------------
enum eAwardType
{
    eAwardType_Achievement = 0,
    eAwardType_GamerPic,
    eAwardType_Theme,
    eAwardType_AvatarItem,
};

enum eUpsellType
{
    eUpsellType_Custom = 0,
    eUpsellType_Achievement,
    eUpsellType_GamerPic,
    eUpsellType_Theme,
    eUpsellType_AvatarItem,
};

enum eUpsellResponse
{
    eUpsellResponse_Declined,
    eUpsellResponse_Accepted_NoPurchase,
    eUpsellResponse_Accepted_Purchase,
};

// ---------------------------------------------------------------------------
// C_4JProfile
// ---------------------------------------------------------------------------
class C_4JProfile
{
public:
    struct PROFILESETTINGS
    {
        int  iYAxisInversion;
        int  iControllerSensitivity;
        int  iVibration;
        bool bSwapSticks;
    };

    // Initialise the profile system
    void    Initialise(DWORD dwTitleID,
                       DWORD dwOfferID,
                       unsigned short usProfileVersion,
                       UINT uiProfileValuesC,
                       UINT uiProfileSettingsC,
                       DWORD *pdwProfileSettingsA,
                       int iGameDefinedDataSizeX4,
                       unsigned int *puiGameDefinedDataChangedBitmask);

    void    SetTrialTextStringTable(CXuiStringTable *pStringTable, int iAccept, int iReject);
    void    SetTrialAwardText(eAwardType AwardType, int iTitle, int iText);

    int     GetLockedProfile();
    void    SetLockedProfile(int iProf);

    bool    IsSignedIn(int iQuadrant);
    bool    IsSignedInLive(int iProf);
    bool    IsGuest(int iQuadrant);

    UINT    RequestSignInUI(bool bFromInvite, bool bLocalGame,
                            bool bNoGuestsAllowed, bool bMultiplayerSignIn,
                            bool bAddUser,
                            int (*Func)(void *, const bool, const int),
                            void *lpParam, int iQuadrant = XUSER_INDEX_ANY);
    UINT    DisplayOfflineProfile(int (*Func)(void *, const bool, const int),
                                  void *lpParam, int iQuadrant = XUSER_INDEX_ANY);
    UINT    RequestConvertOfflineToGuestUI(int (*Func)(void *, const bool, const int),
                                           void *lpParam, int iQuadrant = XUSER_INDEX_ANY);

    void    SetPrimaryPlayerChanged(bool bVal);
    bool    QuerySigninStatus(void);

    void    GetXUID(int iPad, PlayerUID *pXuid, bool bOnlineXuid);
    BOOL    AreXUIDSEqual(PlayerUID xuid1, PlayerUID xuid2);
    BOOL    XUIDIsGuest(PlayerUID xuid);

    bool    AllowedToPlayMultiplayer(int iProf);
    bool    GetChatAndContentRestrictions(int iPad, bool *pbChatRestricted,
                                          bool *pbContentRestricted, int *piAge);

    void    StartTrialGame();

    void    AllowedPlayerCreatedContent(int iPad, bool thisQuadrantOnly,
                                        BOOL *allAllowed, BOOL *friendsAllowed);
    BOOL    CanViewPlayerCreatedContent(int iPad, bool thisQuadrantOnly,
                                        PPlayerUID pXuids, DWORD dwXuidCount);

    void    ShowProfileCard(int iPad, PlayerUID targetUid);

    bool    GetProfileAvatar(int iPad,
                             int (*Func)(void *, BYTE *, DWORD), void *lpParam);
    void    CancelProfileAvatarRequest();

    // SYS
    int     GetPrimaryPad();
    void    SetPrimaryPad(int iPad);
    char   *GetGamertag(int iPad);
    std::wstring GetDisplayName(int iPad);
    bool    IsFullVersion();

    void    SetSignInChangeCallback(void (*Func)(void *, bool, unsigned int), void *lpParam);
    void    SetNotificationsCallback(void (*Func)(void *, DWORD, unsigned int), void *lpParam);

    bool    RegionIsNorthAmerica(void);
    bool    LocaleIsUSorCanada(void);
    long    GetLiveConnectionStatus();
    bool    IsSystemUIDisplayed();

    void    SetProfileReadErrorCallback(void (*Func)(void *), void *lpParam);

    // PROFILE DATA
    int     SetDefaultOptionsCallback(int (*Func)(void *, PROFILESETTINGS *, const int),
                                      void *lpParam);
    int     SetOldProfileVersionCallback(int (*Func)(void *, unsigned char *, const unsigned short, const int),
                                         void *lpParam);
    PROFILESETTINGS *GetDashboardProfileSettings(int iPad);
    void    WriteToProfile(int iQuadrant, bool bGameDefinedDataChanged = false,
                           bool bOverride5MinuteLimitOnProfileWrites = false);
    void    ForceQueuedProfileWrites(int iPad = XUSER_INDEX_ANY);
    void   *GetGameDefinedProfileData(int iQuadrant);
    void    ResetProfileProcessState();
    void    Tick(void);

    // ACHIEVEMENTS & AWARDS
    void    RegisterAward(int iAwardNumber, int iGamerconfigID, eAwardType eType,
                          bool bLeaderboardAffected = false,
                          CXuiStringTable *pStringTable = nullptr,
                          int iTitleStr = -1, int iTextStr = -1, int iAcceptStr = -1,
                          char *pszThemeName = nullptr, unsigned int uiThemeSize = 0);
    int     GetAwardId(int iAwardNumber);
    eAwardType GetAwardType(int iAwardNumber);
    bool    CanBeAwarded(int iQuadrant, int iAwardNumber);
    void    Award(int iQuadrant, int iAwardNumber, bool bForce = false);
    bool    IsAwardsFlagSet(int iQuadrant, int iAward);

    // RICH PRESENCE
    void    RichPresenceInit(int iPresenceCount, int iContextCount);
    void    RegisterRichPresenceContext(int iGameConfigContextID);
    void    SetRichPresenceContextValue(int iPad, int iContextID, int iVal);
    void    SetCurrentGameActivity(int iPad, int iNewPresence, bool bSetOthersToIdle = false);

    // PURCHASE
    void    DisplayFullVersionPurchase(bool bRequired, int iQuadrant, int iUpsellParam = -1);
    void    SetUpsellCallback(void (*Func)(void *, eUpsellType, eUpsellResponse, int), void *lpParam);

    // Debug
    void    SetDebugFullOverride(bool bVal);
};

// Singleton
extern C_4JProfile ProfileManager;
