// AppleProfile.mm - C_4JProfile stub implementation for Apple platforms
// There is no Xbox Live, PSN, or equivalent online service integration on
// Apple, so most methods are stubbed to return safe defaults.
// The primary player is always signed in as a local user.
// Compiled as Objective-C++ (.mm).

#include "stdafx.h"
// Workaround: CarbonCore defines 'Component' which conflicts with a game type
// Rename it before Foundation pulls in CarbonCore
#define Component CarbonComponent_Renamed
#import <Foundation/Foundation.h>
#undef Component
#include "../4JLibs/inc/4J_Profile.h"
#include <cstring>
#include <cstdlib>

// ---------------------------------------------------------------------------
// Singleton
// ---------------------------------------------------------------------------
C_4JProfile ProfileManager;

// ---------------------------------------------------------------------------
// Internal state
// ---------------------------------------------------------------------------
static const int MAX_PADS = 4;

static int              s_primaryPad     = 0;
static int              s_lockedProfile  = -1;
static bool             s_fullVersion    = true;
static bool             s_trialMode      = false;

// Simple gamertag per pad (used by GetGamertag / GetDisplayName)
static char             s_gamertag[MAX_PADS][64];
static PlayerUID        s_playerUIDs[MAX_PADS];

// Profile settings per pad
static C_4JProfile::PROFILESETTINGS s_profileSettings[MAX_PADS] = {};

// Game-defined profile data per pad
static void            *s_gameDefinedData[MAX_PADS] = {};
static int              s_gameDefinedDataSize = 0;
static unsigned int    *s_gameDefinedDataChangedBitmask = nullptr;

// Callbacks (stored but never invoked asynchronously on Apple)
static int  (*s_defaultOptionsCallback)(void *, C_4JProfile::PROFILESETTINGS *, const int) = nullptr;
static void  *s_defaultOptionsCallbackParam = nullptr;
static int  (*s_oldProfileVersionCallback)(void *, unsigned char *, const unsigned short, const int) = nullptr;
static void  *s_oldProfileVersionCallbackParam = nullptr;
static void (*s_signInChangeCallback)(void *, bool, unsigned int) = nullptr;
static void  *s_signInChangeCallbackParam = nullptr;
static void (*s_notificationsCallback)(void *, DWORD, unsigned int) = nullptr;
static void  *s_notificationsCallbackParam = nullptr;
static void (*s_profileReadErrorCallback)(void *) = nullptr;
static void  *s_profileReadErrorCallbackParam = nullptr;
static void (*s_upsellCallback)(void *, eUpsellType, eUpsellResponse, int) = nullptr;
static void  *s_upsellCallbackParam = nullptr;

// Award tracking (simple bitmask, supports up to 64 awards)
static const int MAX_AWARDS = 64;
static uint64_t         s_awardFlags[MAX_PADS] = {};
static int              s_awardIDs[MAX_AWARDS] = {};
static eAwardType       s_awardTypes[MAX_AWARDS] = {};
static int              s_registeredAwardCount = 0;

// ---------------------------------------------------------------------------
// Initialise
// ---------------------------------------------------------------------------
void C_4JProfile::Initialise(DWORD /*dwTitleID*/, DWORD /*dwOfferID*/,
                              unsigned short /*usProfileVersion*/,
                              UINT /*uiProfileValuesC*/,
                              UINT /*uiProfileSettingsC*/,
                              DWORD * /*pdwProfileSettingsA*/,
                              int iGameDefinedDataSizeX4,
                              unsigned int *puiGameDefinedDataChangedBitmask)
{
    s_gameDefinedDataChangedBitmask = puiGameDefinedDataChangedBitmask;
    s_gameDefinedDataSize = iGameDefinedDataSizeX4 / MAX_PADS;

    for (int i = 0; i < MAX_PADS; ++i)
    {
        // Allocate game-defined data per pad
        if (s_gameDefinedDataSize > 0)
        {
            if (s_gameDefinedData[i]) free(s_gameDefinedData[i]);
            s_gameDefinedData[i] = calloc(1, s_gameDefinedDataSize);
        }

        // Default profile settings
        s_profileSettings[i].iYAxisInversion = 0;
        s_profileSettings[i].iControllerSensitivity = 5;
        s_profileSettings[i].iVibration = 1;
        s_profileSettings[i].bSwapSticks = false;

        // Default gamertag
        snprintf(s_gamertag[i], sizeof(s_gamertag[i]), "Player%d", i + 1);

        // Player UIDs
        s_playerUIDs[i] = PlayerUID((uint64_t)(i + 1));
    }

    // The primary player is always "signed in" on Apple
    s_primaryPad = 0;
    s_fullVersion = true;
    s_trialMode = false;
}

void C_4JProfile::SetTrialTextStringTable(CXuiStringTable * /*pStringTable*/,
                                           int /*iAccept*/, int /*iReject*/)
{
    // No-op on Apple
}

void C_4JProfile::SetTrialAwardText(eAwardType /*AwardType*/, int /*iTitle*/, int /*iText*/)
{
    // No-op on Apple
}

int C_4JProfile::GetLockedProfile()
{
    return s_lockedProfile;
}

void C_4JProfile::SetLockedProfile(int iProf)
{
    s_lockedProfile = iProf;
}

// ---------------------------------------------------------------------------
// Sign-in status (always signed in locally on Apple)
// ---------------------------------------------------------------------------
bool C_4JProfile::IsSignedIn(int iQuadrant)
{
    // Pad 0 is always signed in; others only if the game added them
    return (iQuadrant == s_primaryPad);
}

bool C_4JProfile::IsSignedInLive(int /*iProf*/)
{
    // No Xbox Live / online service on Apple
    return false;
}

bool C_4JProfile::IsGuest(int /*iQuadrant*/)
{
    return false;
}

UINT C_4JProfile::RequestSignInUI(bool /*bFromInvite*/, bool /*bLocalGame*/,
                                   bool /*bNoGuestsAllowed*/, bool /*bMultiplayerSignIn*/,
                                   bool /*bAddUser*/,
                                   int (*Func)(void *, const bool, const int),
                                   void *lpParam, int /*iQuadrant*/)
{
    // Auto-succeed sign-in for the primary pad
    if (Func)
        Func(lpParam, true, s_primaryPad);
    return 0;
}

UINT C_4JProfile::DisplayOfflineProfile(int (*Func)(void *, const bool, const int),
                                         void *lpParam, int /*iQuadrant*/)
{
    if (Func)
        Func(lpParam, true, s_primaryPad);
    return 0;
}

UINT C_4JProfile::RequestConvertOfflineToGuestUI(int (*Func)(void *, const bool, const int),
                                                  void *lpParam, int /*iQuadrant*/)
{
    if (Func)
        Func(lpParam, false, s_primaryPad);
    return 0;
}

void C_4JProfile::SetPrimaryPlayerChanged(bool /*bVal*/)
{
    // No-op on Apple
}

bool C_4JProfile::QuerySigninStatus(void)
{
    return true; // primary player is always signed in
}

void C_4JProfile::GetXUID(int iPad, PlayerUID *pXuid, bool /*bOnlineXuid*/)
{
    if (pXuid && iPad >= 0 && iPad < MAX_PADS)
        *pXuid = s_playerUIDs[iPad];
}

BOOL C_4JProfile::AreXUIDSEqual(PlayerUID xuid1, PlayerUID xuid2)
{
    return (xuid1 == xuid2) ? TRUE : FALSE;
}

BOOL C_4JProfile::XUIDIsGuest(PlayerUID /*xuid*/)
{
    return FALSE;
}

bool C_4JProfile::AllowedToPlayMultiplayer(int /*iProf*/)
{
    return true; // no parental restrictions on Apple (handled by Screen Time separately)
}

bool C_4JProfile::GetChatAndContentRestrictions(int /*iPad*/, bool *pbChatRestricted,
                                                 bool *pbContentRestricted, int *piAge)
{
    if (pbChatRestricted) *pbChatRestricted = false;
    if (pbContentRestricted) *pbContentRestricted = false;
    if (piAge) *piAge = 18;
    return true;
}

void C_4JProfile::StartTrialGame()
{
    s_trialMode = true;
}

void C_4JProfile::AllowedPlayerCreatedContent(int /*iPad*/, bool /*thisQuadrantOnly*/,
                                               BOOL *allAllowed, BOOL *friendsAllowed)
{
    if (allAllowed) *allAllowed = TRUE;
    if (friendsAllowed) *friendsAllowed = TRUE;
}

BOOL C_4JProfile::CanViewPlayerCreatedContent(int /*iPad*/, bool /*thisQuadrantOnly*/,
                                               PPlayerUID /*pXuids*/, DWORD /*dwXuidCount*/)
{
    return TRUE;
}

void C_4JProfile::ShowProfileCard(int /*iPad*/, PlayerUID /*targetUid*/)
{
    // No profile card UI on Apple
}

bool C_4JProfile::GetProfileAvatar(int /*iPad*/,
                                    int (*Func)(void *, BYTE *, DWORD), void *lpParam)
{
    // No avatar system on Apple - return no image
    if (Func)
        Func(lpParam, nullptr, 0);
    return false;
}

void C_4JProfile::CancelProfileAvatarRequest()
{
    // No-op
}

// ---------------------------------------------------------------------------
// SYS
// ---------------------------------------------------------------------------
int C_4JProfile::GetPrimaryPad()
{
    return s_primaryPad;
}

void C_4JProfile::SetPrimaryPad(int iPad)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        s_primaryPad = iPad;
}

char *C_4JProfile::GetGamertag(int iPad)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        return s_gamertag[iPad];
    return s_gamertag[0];
}

std::wstring C_4JProfile::GetDisplayName(int iPad)
{
    if (iPad < 0 || iPad >= MAX_PADS) iPad = 0;

    // Convert char gamertag to wstring
    std::wstring result;
    const char *tag = s_gamertag[iPad];
    while (*tag)
    {
        result += (wchar_t)*tag;
        ++tag;
    }
    return result;
}

bool C_4JProfile::IsFullVersion()
{
    return s_fullVersion && !s_trialMode;
}

void C_4JProfile::SetSignInChangeCallback(void (*Func)(void *, bool, unsigned int), void *lpParam)
{
    s_signInChangeCallback = Func;
    s_signInChangeCallbackParam = lpParam;
}

void C_4JProfile::SetNotificationsCallback(void (*Func)(void *, DWORD, unsigned int), void *lpParam)
{
    s_notificationsCallback = Func;
    s_notificationsCallbackParam = lpParam;
}

bool C_4JProfile::RegionIsNorthAmerica(void)
{
    @autoreleasepool {
        NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        return [countryCode isEqualToString:@"US"] ||
               [countryCode isEqualToString:@"CA"] ||
               [countryCode isEqualToString:@"MX"];
    }
}

bool C_4JProfile::LocaleIsUSorCanada(void)
{
    @autoreleasepool {
        NSString *countryCode = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
        return [countryCode isEqualToString:@"US"] ||
               [countryCode isEqualToString:@"CA"];
    }
}

long C_4JProfile::GetLiveConnectionStatus()
{
    // S_OK equivalent - no Xbox Live, but not an error
    return 0;
}

bool C_4JProfile::IsSystemUIDisplayed()
{
    return false;
}

void C_4JProfile::SetProfileReadErrorCallback(void (*Func)(void *), void *lpParam)
{
    s_profileReadErrorCallback = Func;
    s_profileReadErrorCallbackParam = lpParam;
}

// ---------------------------------------------------------------------------
// Profile data
// ---------------------------------------------------------------------------
int C_4JProfile::SetDefaultOptionsCallback(int (*Func)(void *, PROFILESETTINGS *, const int),
                                            void *lpParam)
{
    s_defaultOptionsCallback = Func;
    s_defaultOptionsCallbackParam = lpParam;
    return 0;
}

int C_4JProfile::SetOldProfileVersionCallback(int (*Func)(void *, unsigned char *,
                                                           const unsigned short, const int),
                                               void *lpParam)
{
    s_oldProfileVersionCallback = Func;
    s_oldProfileVersionCallbackParam = lpParam;
    return 0;
}

C_4JProfile::PROFILESETTINGS *C_4JProfile::GetDashboardProfileSettings(int iPad)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        return &s_profileSettings[iPad];
    return &s_profileSettings[0];
}

void C_4JProfile::WriteToProfile(int /*iQuadrant*/, bool /*bGameDefinedDataChanged*/,
                                  bool /*bOverride5MinuteLimitOnProfileWrites*/)
{
    // Profile data is kept in memory only on Apple; could persist to NSUserDefaults
    // or a file if needed in the future.
}

void C_4JProfile::ForceQueuedProfileWrites(int /*iPad*/)
{
    // No queued writes on Apple
}

void *C_4JProfile::GetGameDefinedProfileData(int iQuadrant)
{
    if (iQuadrant >= 0 && iQuadrant < MAX_PADS)
        return s_gameDefinedData[iQuadrant];
    return nullptr;
}

void C_4JProfile::ResetProfileProcessState()
{
    // Reset to defaults
    for (int i = 0; i < MAX_PADS; ++i)
    {
        s_profileSettings[i].iYAxisInversion = 0;
        s_profileSettings[i].iControllerSensitivity = 5;
        s_profileSettings[i].iVibration = 1;
        s_profileSettings[i].bSwapSticks = false;
    }
}

void C_4JProfile::Tick(void)
{
    // No background processing needed on Apple
}

// ---------------------------------------------------------------------------
// Achievements & Awards (local tracking only)
// ---------------------------------------------------------------------------
void C_4JProfile::RegisterAward(int iAwardNumber, int iGamerconfigID, eAwardType eType,
                                 bool /*bLeaderboardAffected*/,
                                 CXuiStringTable * /*pStringTable*/,
                                 int /*iTitleStr*/, int /*iTextStr*/, int /*iAcceptStr*/,
                                 char * /*pszThemeName*/, unsigned int /*uiThemeSize*/)
{
    if (iAwardNumber >= 0 && iAwardNumber < MAX_AWARDS)
    {
        s_awardIDs[iAwardNumber] = iGamerconfigID;
        s_awardTypes[iAwardNumber] = eType;
        if (iAwardNumber >= s_registeredAwardCount)
            s_registeredAwardCount = iAwardNumber + 1;
    }
}

int C_4JProfile::GetAwardId(int iAwardNumber)
{
    if (iAwardNumber >= 0 && iAwardNumber < MAX_AWARDS)
        return s_awardIDs[iAwardNumber];
    return 0;
}

eAwardType C_4JProfile::GetAwardType(int iAwardNumber)
{
    if (iAwardNumber >= 0 && iAwardNumber < MAX_AWARDS)
        return s_awardTypes[iAwardNumber];
    return eAwardType_Achievement;
}

bool C_4JProfile::CanBeAwarded(int iQuadrant, int iAwardNumber)
{
    if (iQuadrant < 0 || iQuadrant >= MAX_PADS) return false;
    if (iAwardNumber < 0 || iAwardNumber >= MAX_AWARDS) return false;

    // Can be awarded if not already awarded
    return !(s_awardFlags[iQuadrant] & (1ULL << iAwardNumber));
}

void C_4JProfile::Award(int iQuadrant, int iAwardNumber, bool /*bForce*/)
{
    if (iQuadrant < 0 || iQuadrant >= MAX_PADS) return;
    if (iAwardNumber < 0 || iAwardNumber >= MAX_AWARDS) return;

    s_awardFlags[iQuadrant] |= (1ULL << iAwardNumber);
    NSLog(@"[Profile] Award %d given to pad %d", iAwardNumber, iQuadrant);
}

bool C_4JProfile::IsAwardsFlagSet(int iQuadrant, int iAward)
{
    if (iQuadrant < 0 || iQuadrant >= MAX_PADS) return false;
    if (iAward < 0 || iAward >= MAX_AWARDS) return false;

    return (s_awardFlags[iQuadrant] & (1ULL << iAward)) != 0;
}

// ---------------------------------------------------------------------------
// Rich Presence (no-op on Apple)
// ---------------------------------------------------------------------------
void C_4JProfile::RichPresenceInit(int /*iPresenceCount*/, int /*iContextCount*/)
{
}

void C_4JProfile::RegisterRichPresenceContext(int /*iGameConfigContextID*/)
{
}

void C_4JProfile::SetRichPresenceContextValue(int /*iPad*/, int /*iContextID*/, int /*iVal*/)
{
}

void C_4JProfile::SetCurrentGameActivity(int /*iPad*/, int /*iNewPresence*/,
                                          bool /*bSetOthersToIdle*/)
{
}

// ---------------------------------------------------------------------------
// Purchase (no-op on Apple - would use StoreKit in a full implementation)
// ---------------------------------------------------------------------------
void C_4JProfile::DisplayFullVersionPurchase(bool /*bRequired*/, int /*iQuadrant*/,
                                              int /*iUpsellParam*/)
{
    // Could integrate with StoreKit here
}

void C_4JProfile::SetUpsellCallback(void (*Func)(void *, eUpsellType, eUpsellResponse, int),
                                     void *lpParam)
{
    s_upsellCallback = Func;
    s_upsellCallbackParam = lpParam;
}

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------
void C_4JProfile::SetDebugFullOverride(bool bVal)
{
    s_fullVersion = bVal;
}
