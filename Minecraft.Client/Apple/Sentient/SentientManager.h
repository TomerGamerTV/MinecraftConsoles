#pragma once
class CSentientManager {
public:
    HRESULT Init();
    HRESULT Tick();
    HRESULT Flush();
    BOOL RecordPlayerSessionStart(DWORD dwUserId);
    BOOL RecordPlayerSessionExit(DWORD dwUserId, int exitStatus);
    BOOL RecordHeartBeat(DWORD dwUserId);
    BOOL RecordLevelStart(DWORD dwUserId, ESen_FriendOrMatch, ESen_CompeteOrCoop, int, DWORD, DWORD);
    BOOL RecordLevelExit(DWORD dwUserId, ESen_LevelExitStatus);
    BOOL RecordLevelSaveOrCheckpoint(DWORD, INT, INT);
    BOOL RecordLevelResume(DWORD, ESen_FriendOrMatch, ESen_CompeteOrCoop, int, DWORD, DWORD, INT);
    BOOL RecordPauseOrInactive(DWORD);
    BOOL RecordUnpauseOrActive(DWORD);
    BOOL RecordMenuShown(DWORD, INT, INT);
    BOOL RecordAchievementUnlocked(DWORD, INT, INT);
    BOOL RecordMediaShareUpload(DWORD, ESen_MediaDestination, ESen_MediaType);
    BOOL RecordUpsellPresented(DWORD, ESen_UpsellID, INT);
    BOOL RecordUpsellResponded(DWORD, ESen_UpsellID, INT, ESen_UpsellOutcome);
    BOOL RecordPlayerDiedOrFailed(DWORD, INT, INT, INT, INT, INT, INT, ETelemetryChallenges);
    BOOL RecordEnemyKilledOrOvercome(DWORD, INT, INT, INT, INT, INT, INT, ETelemetryChallenges);
    BOOL RecordSkinChanged(DWORD, DWORD);
    BOOL RecordBanLevel(DWORD);
    BOOL RecordUnBanLevel(DWORD);
    INT GetMultiplayerInstanceID();
    INT GenerateMultiplayerInstanceId();
    void SetMultiplayerInstanceId(INT);
};
extern CSentientManager SentientManager;
