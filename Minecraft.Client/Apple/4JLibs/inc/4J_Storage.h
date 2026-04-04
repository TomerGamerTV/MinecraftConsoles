// 4J_Storage.h - Apple platform storage manager
// Same class API as the Windows C4JStorage but replaces Xbox/Windows types
// with Apple-compatible equivalents. Uses standard file I/O underneath.

#pragma once

#include "../../AppleTypes.h"
#include <vector>
#include <string>
#include <ctime>

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
class C4JStringTable;

// ---------------------------------------------------------------------------
// Save-file constants
// ---------------------------------------------------------------------------
#define MAX_DISPLAYNAME_LENGTH      128
#define MAX_DETAILS_LENGTH          128
#define MAX_SAVEFILENAME_LENGTH     32

// Xbox compat constants (not used on Apple but needed for API matching)
#define XUSER_INDEX_ANY             0x000000FF
#define XCONTENT_MAX_DISPLAYNAME_LENGTH 128
#define XCONTENT_MAX_FILENAME_LENGTH    42
#define XMARKETPLACE_OFFERING_TYPE_CONTENT 0x00000002

// ---------------------------------------------------------------------------
// Container metadata
// ---------------------------------------------------------------------------
typedef struct
{
    time_t          modifiedTime;
    unsigned int    dataSize;
    unsigned int    thumbnailSize;
}
CONTAINER_METADATA;

// ---------------------------------------------------------------------------
// Save info
// ---------------------------------------------------------------------------
typedef struct
{
    char                UTF8SaveFilename[MAX_SAVEFILENAME_LENGTH];
    char                UTF8SaveTitle[MAX_DISPLAYNAME_LENGTH];
    CONTAINER_METADATA  metaData;
    BYTE               *thumbnailData;
}
SAVE_INFO, *PSAVE_INFO;

typedef struct
{
    int         iSaveC;
    PSAVE_INFO  SaveInfoA;
}
SAVE_DETAILS, *PSAVE_DETAILS;

// ---------------------------------------------------------------------------
// Xbox Marketplace / Content stubs for API compatibility
// ---------------------------------------------------------------------------
typedef struct
{
    DWORD   dwContentType;
    WCHAR   wszDisplayName[XCONTENT_MAX_DISPLAYNAME_LENGTH];
    char    szFileName[XCONTENT_MAX_FILENAME_LENGTH];
    // Apple: mount path kept here for convenience
    char    szMountPath[512];
}
XCONTENT_DATA, *PXCONTENT_DATA;

typedef struct
{
    DWORD   dwOfferType;
    WCHAR   wszDisplayName[XCONTENT_MAX_DISPLAYNAME_LENGTH];
    char    szFileName[XCONTENT_MAX_FILENAME_LENGTH];
    uint64_t qwOfferID;
}
XMARKETPLACE_CONTENTOFFER_INFO, *PXMARKETPLACE_CONTENTOFFER_INFO;

typedef std::vector<PXMARKETPLACE_CONTENTOFFER_INFO> OfferDataArray;
typedef std::vector<PXCONTENT_DATA>                  XContentDataArray;

// DLC data creator version
#define CURRENT_DLC_VERSION_NUM 3

// ---------------------------------------------------------------------------
// C4JStorage
// ---------------------------------------------------------------------------
class C4JStorage
{
public:
    // Structs shared with the DLC_Creator tool
    typedef struct
    {
        unsigned int    uiFileSize;
        DWORD           dwType;
        DWORD           dwWchCount;
        WCHAR           wchFile[1];
    }
    DLC_FILE_DETAILS, *PDLC_FILE_DETAILS;

    typedef struct
    {
        DWORD   dwType;
        DWORD   dwWchCount;
        WCHAR   wchData[1];
    }
    DLC_FILE_PARAM, *PDLC_FILE_PARAM;

    typedef struct
    {
        WCHAR   wchDisplayName[XCONTENT_MAX_DISPLAYNAME_LENGTH];
        char    szFileName[XCONTENT_MAX_FILENAME_LENGTH];
        DWORD   dwImageOffset;
        DWORD   dwImageBytes;
    }
    CACHEINFOSTRUCT;

    // Structure to hold DLC info (was TMS on Xbox)
    typedef struct
    {
        DWORD   dwVersion;
        DWORD   dwNewOffers;
        DWORD   dwTotalOffers;
        DWORD   dwInstalledTotalOffers;
        BYTE    bPadding[1024 - sizeof(DWORD) * 4];
    }
    DLC_TMS_DETAILS;

    // -----------------------------------------------------------------------
    // Enumerations
    // -----------------------------------------------------------------------
    enum eGTS_FileTypes
    {
        eGTS_Type_Skin = 0,
        eGTS_Type_Cape,
        eGTS_Type_MAX
    };

    enum eGlobalStorage
    {
        eGlobalStorage_Title = 0,
        eGlobalStorage_TitleUser,
        eGlobalStorage_Max
    };

    enum EMessageResult
    {
        EMessage_Undefined = 0,
        EMessage_Busy,
        EMessage_Pending,
        EMessage_Cancelled,
        EMessage_ResultAccept,
        EMessage_ResultDecline,
        EMessage_ResultThirdOption,
        EMessage_ResultFourthOption
    };

    enum ESaveGameControlState
    {
        ESaveGameControl_Idle = 0,
        ESaveGameControl_Save,
        ESaveGameControl_InternalRequestingDevice,
        ESaveGameControl_InternalGetSaveName,
        ESaveGameControl_InternalSaving,
        ESaveGameControl_CopySave,
        ESaveGameControl_CopyingSave,
    };

    enum ESaveGameState
    {
        ESaveGame_Idle = 0,
        ESaveGame_Save,
        ESaveGame_InternalRequestingDevice,
        ESaveGame_InternalGetSaveName,
        ESaveGame_InternalSaving,
        ESaveGame_CopySave,
        ESaveGame_CopyingSave,
        ESaveGame_Load,
        ESaveGame_GetSavesInfo,
        ESaveGame_Rename,
        ESaveGame_Delete,
        ESaveGame_GetSaveThumbnail
    };

    enum ELoadGameStatus
    {
        ELoadGame_Idle = 0,
        ELoadGame_InProgress,
        ELoadGame_NoSaves,
        ELoadGame_ChangedDevice,
        ELoadGame_DeviceRemoved
    };

    enum EDeleteGameStatus
    {
        EDeleteGame_Idle = 0,
        EDeleteGame_InProgress,
    };

    enum ESGIStatus
    {
        ESGIStatus_Error = 0,
        ESGIStatus_Idle,
        ESGIStatus_ReadInProgress,
        ESGIStatus_NoSaves,
    };

    enum EDLCStatus
    {
        EDLC_Error = 0,
        EDLC_Idle,
        EDLC_NoOffers,
        EDLC_AlreadyEnumeratedAllOffers,
        EDLC_NoInstalledDLC,
        EDLC_Pending,
        EDLC_LoadInProgress,
        EDLC_Loaded,
        EDLC_ChangedDevice
    };

    enum ESavingMessage
    {
        ESavingMessage_None = 0,
        ESavingMessage_Short,
        ESavingMessage_Long
    };

    enum ETMSStatus
    {
        ETMSStatus_Idle = 0,
        ETMSStatus_Fail,
        ETMSStatus_Fail_ReadInProgress,
        ETMSStatus_Fail_WriteInProgress,
        ETMSStatus_Pending,
    };

    enum eTMS_FileType
    {
        eTMS_FileType_Normal = 0,
        eTMS_FileType_Graphic,
    };

    enum eTMS_FILETYPEVAL
    {
        TMS_FILETYPE_BINARY,
        TMS_FILETYPE_CONFIG,
        TMS_FILETYPE_JSON,
        TMS_FILETYPE_MAX
    };

    enum eTMS_UGCTYPE
    {
        TMS_UGCTYPE_NONE,
        TMS_UGCTYPE_IMAGE,
        TMS_UGCTYPE_MAX
    };

    typedef struct
    {
        char                szFilename[256];
        int                 iFileSize;
        eTMS_FILETYPEVAL    eFileTypeVal;
    }
    TMSPP_FILE_DETAILS, *PTMSPP_FILE_DETAILS;

    typedef struct
    {
        int                 iCount;
        PTMSPP_FILE_DETAILS FileDetailsA;
    }
    TMSPP_FILE_LIST, *PTMSPP_FILE_LIST;

    typedef struct
    {
        DWORD   dwSize;
        BYTE   *pbData;
    }
    TMSPP_FILEDATA, *PTMSPP_FILEDATA;

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    C4JStorage();

    void    Tick(void);

    // Messages (Apple: stubbed / implemented as NSAlert on macOS)
    C4JStorage::EMessageResult  RequestMessageBox(UINT uiTitle, UINT uiText,
                                    UINT *uiOptionA, UINT uiOptionC,
                                    DWORD dwPad = XUSER_INDEX_ANY,
                                    int (*Func)(void *, int, const C4JStorage::EMessageResult) = nullptr,
                                    void *lpParam = nullptr,
                                    C4JStringTable *pStringTable = nullptr,
                                    WCHAR *pwchFormatString = nullptr,
                                    DWORD dwFocusButton = 0);

    C4JStorage::EMessageResult  GetMessageBoxResult();

    // Save device
    bool    SetSaveDevice(int (*Func)(void *, const bool), void *lpParam,
                          bool bForceResetOfSaveDevice = false);

    // Save game
    void    Init(unsigned int uiSaveVersion, const wchar_t *pwchDefaultSaveName,
                 char *pszSavePackName, int iMinimumSaveSize,
                 int (*Func)(void *, const ESavingMessage, int), void *lpParam,
                 const char *szGroupID);
    void    ResetSaveData();
    void    SetDefaultSaveNameForKeyboardDisplay(const wchar_t *pwchDefaultSaveName);
    void    SetSaveTitle(const wchar_t *pwchDefaultSaveName);
    bool    GetSaveUniqueNumber(int *piVal);
    bool    GetSaveUniqueFilename(char *pszName);
    void    SetSaveUniqueFilename(char *szFilename);
    void    SetState(ESaveGameControlState eControlState,
                     int (*Func)(void *, const bool), void *lpParam);
    void    SetSaveDisabled(bool bDisable);
    bool    GetSaveDisabled(void);
    unsigned int GetSaveSize();
    void    GetSaveData(void *pvData, unsigned int *puiBytes);
    void   *AllocateSaveData(unsigned int uiBytes);
    void    SetSaveImages(BYTE *pbThumbnail, DWORD dwThumbnailBytes,
                          BYTE *pbImage, DWORD dwImageBytes,
                          BYTE *pbTextData, DWORD dwTextDataBytes);

    C4JStorage::ESaveGameState  SaveSaveData(int (*Func)(void *, const bool), void *lpParam);
    void    CopySaveDataToNewSave(BYTE *pbThumbnail, DWORD cbThumbnail,
                                  WCHAR *wchNewName,
                                  int (*Func)(void *, bool), void *lpParam);
    void    SetSaveDeviceSelected(unsigned int uiPad, bool bSelected);
    bool    GetSaveDeviceSelected(unsigned int iPad);
    C4JStorage::ESaveGameState  DoesSaveExist(bool *pbExists);
    bool    EnoughSpaceForAMinSaveGame();

    void    SetSaveMessageVPosition(float fY);

    // Save enumeration
    C4JStorage::ESaveGameState  GetSavesInfo(int iPad,
                                    int (*Func)(void *, SAVE_DETAILS *, const bool),
                                    void *lpParam, char *pszSavePackName);
    PSAVE_DETAILS   ReturnSavesInfo();
    void            ClearSavesInfo();
    C4JStorage::ESaveGameState  LoadSaveDataThumbnail(PSAVE_INFO pSaveInfo,
                                    int (*Func)(void *, BYTE *, DWORD), void *lpParam);

    void    GetSaveCacheFileInfo(DWORD dwFile, XCONTENT_DATA &xContentData);
    void    GetSaveCacheFileInfo(DWORD dwFile, BYTE **ppbImageData, DWORD *pdwImageBytes);

    // Load / delete
    C4JStorage::ESaveGameState  LoadSaveData(PSAVE_INFO pSaveInfo,
                                    int (*Func)(void *, const bool, const bool), void *lpParam);
    C4JStorage::ESaveGameState  DeleteSaveData(PSAVE_INFO pSaveInfo,
                                    int (*Func)(void *, const bool), void *lpParam);

    // DLC
    void    RegisterMarketplaceCountsCallback(int (*Func)(void *, C4JStorage::DLC_TMS_DETAILS *, int),
                                              void *lpParam);
    void    SetDLCPackageRoot(char *pszDLCRoot);
    C4JStorage::EDLCStatus  GetDLCOffers(int iPad,
                                int (*Func)(void *, int, DWORD, int), void *lpParam,
                                DWORD dwOfferTypesBitmask = XMARKETPLACE_OFFERING_TYPE_CONTENT);
    DWORD   CancelGetDLCOffers();
    void    ClearDLCOffers();
    XMARKETPLACE_CONTENTOFFER_INFO &GetOffer(DWORD dw);
    int     GetOfferCount();
    DWORD   InstallOffer(int iOfferIDC, uint64_t *ullOfferIDA,
                         int (*Func)(void *, int, int), void *lpParam,
                         bool bTrial = false);
    DWORD   GetAvailableDLCCount(int iPad);

    C4JStorage::EDLCStatus  GetInstalledDLC(int iPad,
                                int (*Func)(void *, int, int), void *lpParam);
    XCONTENT_DATA &GetDLC(DWORD dw);
    DWORD   MountInstalledDLC(int iPad, DWORD dwDLC,
                              int (*Func)(void *, int, DWORD, DWORD), void *lpParam,
                              const char *szMountDrive = nullptr);
    DWORD   UnmountInstalledDLC(const char *szMountDrive = nullptr);
    void    GetMountedDLCFileList(const char *szMountDrive, std::vector<std::string> &fileList);
    std::string GetMountedPath(std::string szMount);

    // Global title storage (TMS)
    C4JStorage::ETMSStatus  ReadTMSFile(int iQuadrant, eGlobalStorage eStorageFacility,
                                C4JStorage::eTMS_FileType eFileType,
                                WCHAR *pwchFilename, BYTE **ppBuffer, DWORD *pdwBufferSize,
                                int (*Func)(void *, WCHAR *, int, bool, int) = nullptr,
                                void *lpParam = nullptr, int iAction = 0);
    bool    WriteTMSFile(int iQuadrant, eGlobalStorage eStorageFacility,
                         WCHAR *pwchFilename, BYTE *pBuffer, DWORD dwBufferSize);
    bool    DeleteTMSFile(int iQuadrant, eGlobalStorage eStorageFacility,
                          WCHAR *pwchFilename);
    void    StoreTMSPathName(WCHAR *pwchName = nullptr);

    // TMS++
    C4JStorage::ETMSStatus  TMSPP_ReadFile(int iPad, C4JStorage::eGlobalStorage eStorageFacility,
                                C4JStorage::eTMS_FILETYPEVAL eFileTypeVal, const char *szFilename,
                                int (*Func)(void *, int, int, PTMSPP_FILEDATA, const char *) = nullptr,
                                void *lpParam = nullptr, int iUserData = 0);

    unsigned int    CRC(unsigned char *buf, int len);

    // String table for storage UI
    C4JStringTable *m_pStringTable;
};

extern C4JStorage StorageManager;
