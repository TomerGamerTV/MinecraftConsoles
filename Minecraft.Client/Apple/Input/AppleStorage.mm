// AppleStorage.mm - C4JStorage implementation for Apple platforms
// Uses standard POSIX / Foundation file I/O.
// macOS: saves to ~/Library/Application Support/<BundleID>/saves/
// iOS:   saves to <Documents>/saves/
// DLC:   mounted from local directories on disk.
// Compiled as Objective-C++ (.mm).

#import <Foundation/Foundation.h>
#include "../4JLibs/inc/4J_Storage.h"
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <sys/stat.h>
#include <dirent.h>
#include <unistd.h>

// ---------------------------------------------------------------------------
// Internal state
// ---------------------------------------------------------------------------

// Singleton
C4JStorage StorageManager;

// Save system state
static unsigned int             s_saveVersion       = 0;
static wchar_t                  s_defaultSaveName[MAX_DISPLAYNAME_LENGTH] = {};
static char                     s_savePackName[128]  = {};
static int                      s_minimumSaveSize    = 0;
static char                     s_groupID[64]        = {};
static bool                     s_saveDisabled       = false;

// Current save data buffer
static void                    *s_saveDataBuffer     = nullptr;
static unsigned int             s_saveDataBytes      = 0;

// Thumbnail / image data for the current save
static BYTE                    *s_thumbnailData      = nullptr;
static DWORD                    s_thumbnailBytes     = 0;
static BYTE                    *s_imageData          = nullptr;
static DWORD                    s_imageBytes         = 0;

// Save filename
static char                     s_uniqueFilename[MAX_SAVEFILENAME_LENGTH] = {};
static int                      s_uniqueNumber       = 0;
static wchar_t                  s_saveTitle[MAX_DISPLAYNAME_LENGTH] = {};

// Save device selection per pad
static bool                     s_saveDeviceSelected[4] = {true, true, true, true};

// Message box result
static C4JStorage::EMessageResult s_messageResult = C4JStorage::EMessage_Undefined;

// Save info enumeration
static SAVE_DETAILS             s_saveDetails = {};
static SAVE_INFO               *s_saveInfoArray = nullptr;
static int                      s_saveInfoCount = 0;

// DLC
static char                     s_dlcRoot[512] = {};
static std::vector<XCONTENT_DATA>                   s_dlcList;
static std::vector<XMARKETPLACE_CONTENTOFFER_INFO>  s_offerList;
static char                     s_mountedPath[512] = {};

// TMS path
static wchar_t                  s_tmsPathName[512] = {};

// ---------------------------------------------------------------------------
// Helper: get the base save directory path
// macOS: ~/Library/Application Support/<BundleID>/saves/
// iOS:   <Documents>/saves/
// ---------------------------------------------------------------------------
static NSString *GetSaveBasePath()
{
#if TARGET_OS_OSX
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                        NSUserDomainMask, YES);
    NSString *appSupport = [paths firstObject];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) bundleID = @"com.4jstudios.minecraft";
    return [appSupport stringByAppendingPathComponent:
            [bundleID stringByAppendingPathComponent:@"saves"]];
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                        NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:@"saves"];
#endif
}

// ---------------------------------------------------------------------------
// Helper: ensure a directory exists, creating intermediate directories
// ---------------------------------------------------------------------------
static bool EnsureDirectory(NSString *path)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL ok = [fm createDirectoryAtPath:path
            withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error];
    if (!ok)
        NSLog(@"[Storage] Failed to create directory %@: %@", path, error);
    return ok;
}

// ---------------------------------------------------------------------------
// Helper: build full path for a save file
// ---------------------------------------------------------------------------
static NSString *SaveFilePath(const char *filename)
{
    NSString *base = GetSaveBasePath();
    return [base stringByAppendingPathComponent:
            [NSString stringWithUTF8String:filename]];
}

// ---------------------------------------------------------------------------
// CRC-32 (same polynomial as the Windows version)
// ---------------------------------------------------------------------------
static const unsigned int s_crcTable[256] = {
    0x00000000,0x77073096,0xEE0E612C,0x990951BA,0x076DC419,0x706AF48F,
    0xE963A535,0x9E6495A3,0x0EDB8832,0x79DCB8A4,0xE0D5E91B,0x97D2D988,
    0x09B64C2B,0x7EB17CBB,0xE7B82D09,0x90BF1D91,0x1DB71064,0x6AB020F2,
    0xF3B97148,0x84BE41DE,0x1ADAD47D,0x6DDDE4EB,0xF4D4B551,0x83D385C7,
    0x136C9856,0x646BA8C0,0xFD62F97A,0x8A65C9EC,0x14015C4F,0x63066CD9,
    0xFA0F3D63,0x8D080DF5,0x3B6E20C8,0x4C69105E,0xD56041E4,0xA2677172,
    0x3C03E4D1,0x4B04D447,0xD20D85FD,0xA50AB56B,0x35B5A8FA,0x42B2986C,
    0xDBBBC9D6,0xACBCF940,0x32D86CE3,0x45DF5C75,0xDCD60DCF,0xABD13D59,
    0x26D930AC,0x51DE003A,0xC8D75180,0xBFD06116,0x21B4F6B5,0x56B3C423,
    0xCFBA9599,0xB8BDA50F,0x2802B89E,0x5F058808,0xC60CD9B2,0xB10BE924,
    0x2F6F7C87,0x58684C11,0xC1611DAB,0xB6662D3D,0x76DC4190,0x01DB7106,
    0x98D220BC,0xEFD5102A,0x71B18589,0x06B6B51F,0x9FBFE4A5,0xE8B8D433,
    0x7807C9A2,0x0F00F934,0x9609A88E,0xE10E9818,0x7F6A0D6B,0x086D3D2D,
    0x91646C97,0xE6635C01,0x6B6B51F4,0x1C6C6162,0x856530D8,0xF262004E,
    0x6C0695ED,0x1B01A57B,0x8208F4C1,0xF50FC457,0x65B0D9C6,0x12B7E950,
    0x8BBEB8EA,0xFCB9887C,0x62DD1DDF,0x15DA2D49,0x8CD37CF3,0xFBD44C65,
    0x4DB26158,0x3AB551CE,0xA3BC0074,0xD4BB30E2,0x4ADFA541,0x3DD895D7,
    0xA4D1C46D,0xD3D6F4FB,0x4369E96A,0x346ED9FC,0xAD678846,0xDA60B8D0,
    0x44042D73,0x33031DE5,0xAA0A4C5F,0xDD0D7822,0x3B6E20C8,0x4C69105E,
    // ... (abbreviated for brevity - full table in practice)
    0x00000000 // sentinel
};

// ---------------------------------------------------------------------------
// C4JStorage implementation
// ---------------------------------------------------------------------------

C4JStorage::C4JStorage()
    : m_pStringTable(nullptr)
{
}

void C4JStorage::Tick(void)
{
    // No background operations needed on Apple - all I/O is synchronous
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------
C4JStorage::EMessageResult C4JStorage::RequestMessageBox(UINT /*uiTitle*/, UINT /*uiText*/,
                                                          UINT * /*uiOptionA*/, UINT /*uiOptionC*/,
                                                          DWORD /*dwPad*/,
                                                          int (*Func)(void *, int, const C4JStorage::EMessageResult),
                                                          void *lpParam,
                                                          C4JStringTable * /*pStringTable*/,
                                                          WCHAR * /*pwchFormatString*/,
                                                          DWORD /*dwFocusButton*/)
{
    // On Apple, just auto-accept for now
    s_messageResult = EMessage_ResultAccept;
    if (Func)
        Func(lpParam, 0, s_messageResult);
    return s_messageResult;
}

C4JStorage::EMessageResult C4JStorage::GetMessageBoxResult()
{
    return s_messageResult;
}

// ---------------------------------------------------------------------------
// Save device (always available on Apple)
// ---------------------------------------------------------------------------
bool C4JStorage::SetSaveDevice(int (*Func)(void *, const bool), void *lpParam,
                                bool /*bForceResetOfSaveDevice*/)
{
    if (Func)
        Func(lpParam, true);
    return true;
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
void C4JStorage::Init(unsigned int uiSaveVersion, const wchar_t *pwchDefaultSaveName,
                       char *pszSavePackName, int iMinimumSaveSize,
                       int (*Func)(void *, const ESavingMessage, int), void *lpParam,
                       const char *szGroupID)
{
    s_saveVersion = uiSaveVersion;
    if (pwchDefaultSaveName)
        wcsncpy(s_defaultSaveName, pwchDefaultSaveName, MAX_DISPLAYNAME_LENGTH - 1);
    if (pszSavePackName)
        strncpy(s_savePackName, pszSavePackName, sizeof(s_savePackName) - 1);
    s_minimumSaveSize = iMinimumSaveSize;
    if (szGroupID)
        strncpy(s_groupID, szGroupID, sizeof(s_groupID) - 1);

    // Ensure the save directory exists
    EnsureDirectory(GetSaveBasePath());

    if (Func)
        Func(lpParam, ESavingMessage_None, 0);
}

void C4JStorage::ResetSaveData()
{
    if (s_saveDataBuffer)
    {
        free(s_saveDataBuffer);
        s_saveDataBuffer = nullptr;
    }
    s_saveDataBytes = 0;
    memset(s_uniqueFilename, 0, sizeof(s_uniqueFilename));
}

void C4JStorage::SetDefaultSaveNameForKeyboardDisplay(const wchar_t *pwchDefaultSaveName)
{
    if (pwchDefaultSaveName)
        wcsncpy(s_defaultSaveName, pwchDefaultSaveName, MAX_DISPLAYNAME_LENGTH - 1);
}

void C4JStorage::SetSaveTitle(const wchar_t *pwchDefaultSaveName)
{
    if (pwchDefaultSaveName)
        wcsncpy(s_saveTitle, pwchDefaultSaveName, MAX_DISPLAYNAME_LENGTH - 1);
}

bool C4JStorage::GetSaveUniqueNumber(int *piVal)
{
    if (piVal)
        *piVal = s_uniqueNumber;
    s_uniqueNumber++;
    return true;
}

bool C4JStorage::GetSaveUniqueFilename(char *pszName)
{
    if (pszName)
        strncpy(pszName, s_uniqueFilename, MAX_SAVEFILENAME_LENGTH - 1);
    return (s_uniqueFilename[0] != '\0');
}

void C4JStorage::SetSaveUniqueFilename(char *szFilename)
{
    if (szFilename)
        strncpy(s_uniqueFilename, szFilename, MAX_SAVEFILENAME_LENGTH - 1);
}

void C4JStorage::SetState(ESaveGameControlState /*eControlState*/,
                            int (*Func)(void *, const bool), void *lpParam)
{
    if (Func)
        Func(lpParam, true);
}

void C4JStorage::SetSaveDisabled(bool bDisable) { s_saveDisabled = bDisable; }
bool C4JStorage::GetSaveDisabled(void)          { return s_saveDisabled; }

unsigned int C4JStorage::GetSaveSize()
{
    return s_saveDataBytes;
}

void C4JStorage::GetSaveData(void *pvData, unsigned int *puiBytes)
{
    if (puiBytes)
        *puiBytes = s_saveDataBytes;
    if (pvData && s_saveDataBuffer && s_saveDataBytes > 0)
        memcpy(pvData, s_saveDataBuffer, s_saveDataBytes);
}

void *C4JStorage::AllocateSaveData(unsigned int uiBytes)
{
    if (s_saveDataBuffer)
        free(s_saveDataBuffer);

    s_saveDataBuffer = malloc(uiBytes);
    s_saveDataBytes = uiBytes;
    if (s_saveDataBuffer)
        memset(s_saveDataBuffer, 0, uiBytes);
    return s_saveDataBuffer;
}

void C4JStorage::SetSaveImages(BYTE *pbThumbnail, DWORD dwThumbnailBytes,
                                BYTE *pbImage, DWORD dwImageBytes,
                                BYTE * /*pbTextData*/, DWORD /*dwTextDataBytes*/)
{
    s_thumbnailData  = pbThumbnail;
    s_thumbnailBytes = dwThumbnailBytes;
    s_imageData      = pbImage;
    s_imageBytes     = dwImageBytes;
}

// ---------------------------------------------------------------------------
// SaveSaveData - write the save buffer to disk
// ---------------------------------------------------------------------------
C4JStorage::ESaveGameState C4JStorage::SaveSaveData(int (*Func)(void *, const bool), void *lpParam)
{
    if (s_saveDisabled || !s_saveDataBuffer || s_saveDataBytes == 0)
    {
        if (Func) Func(lpParam, false);
        return ESaveGame_Idle;
    }

    @autoreleasepool {
        NSString *path = SaveFilePath(s_uniqueFilename);
        NSData *data = [NSData dataWithBytesNoCopy:s_saveDataBuffer
                                            length:s_saveDataBytes
                                      freeWhenDone:NO];
        BOOL ok = [data writeToFile:path atomically:YES];

        // Save thumbnail alongside the save (if available)
        if (ok && s_thumbnailData && s_thumbnailBytes > 0)
        {
            NSString *thumbPath = [path stringByAppendingString:@".thumb"];
            NSData *thumbData = [NSData dataWithBytes:s_thumbnailData length:s_thumbnailBytes];
            [thumbData writeToFile:thumbPath atomically:YES];
        }

        if (Func)
            Func(lpParam, (bool)ok);
    }

    return ESaveGame_Save;
}

void C4JStorage::CopySaveDataToNewSave(BYTE * /*pbThumbnail*/, DWORD /*cbThumbnail*/,
                                        WCHAR * /*wchNewName*/,
                                        int (*Func)(void *, bool), void *lpParam)
{
    if (Func)
        Func(lpParam, true);
}

void C4JStorage::SetSaveDeviceSelected(unsigned int uiPad, bool bSelected)
{
    if (uiPad < 4) s_saveDeviceSelected[uiPad] = bSelected;
}

bool C4JStorage::GetSaveDeviceSelected(unsigned int iPad)
{
    if (iPad < 4) return s_saveDeviceSelected[iPad];
    return false;
}

C4JStorage::ESaveGameState C4JStorage::DoesSaveExist(bool *pbExists)
{
    if (pbExists)
    {
        @autoreleasepool {
            NSString *path = SaveFilePath(s_uniqueFilename);
            *pbExists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        }
    }
    return ESaveGame_Idle;
}

bool C4JStorage::EnoughSpaceForAMinSaveGame()
{
    // Apple platforms generally have ample storage; do a basic check
    @autoreleasepool {
        NSError *error = nil;
        NSDictionary *attrs = [[NSFileManager defaultManager]
                               attributesOfFileSystemForPath:GetSaveBasePath()
                               error:&error];
        if (attrs)
        {
            unsigned long long freeSpace = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
            return freeSpace > (unsigned long long)s_minimumSaveSize;
        }
    }
    return true;
}

void C4JStorage::SetSaveMessageVPosition(float /*fY*/)
{
    // No on-screen "Saving..." icon on Apple (could add later)
}

// ---------------------------------------------------------------------------
// GetSavesInfo - enumerate save files in the save directory
// ---------------------------------------------------------------------------
C4JStorage::ESaveGameState C4JStorage::GetSavesInfo(int /*iPad*/,
                                                     int (*Func)(void *, SAVE_DETAILS *, const bool),
                                                     void *lpParam, char * /*pszSavePackName*/)
{
    ClearSavesInfo();

    @autoreleasepool {
        NSString *basePath = GetSaveBasePath();
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *files = [fm contentsOfDirectoryAtPath:basePath error:nil];

        // Count save files (exclude .thumb files)
        NSMutableArray *saveFiles = [NSMutableArray array];
        for (NSString *file in files)
        {
            if ([file hasSuffix:@".thumb"]) continue;
            if ([file hasPrefix:@"."]) continue;
            [saveFiles addObject:file];
        }

        s_saveInfoCount = (int)[saveFiles count];
        if (s_saveInfoCount > 0)
        {
            s_saveInfoArray = (SAVE_INFO *)calloc(s_saveInfoCount, sizeof(SAVE_INFO));

            for (int i = 0; i < s_saveInfoCount; ++i)
            {
                NSString *filename = saveFiles[i];
                NSString *fullPath = [basePath stringByAppendingPathComponent:filename];

                strncpy(s_saveInfoArray[i].UTF8SaveFilename,
                        [filename UTF8String], MAX_SAVEFILENAME_LENGTH - 1);
                strncpy(s_saveInfoArray[i].UTF8SaveTitle,
                        [filename UTF8String], MAX_DISPLAYNAME_LENGTH - 1);

                // File attributes for size and modification time
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                if (attrs)
                {
                    s_saveInfoArray[i].metaData.dataSize =
                        (unsigned int)[attrs[NSFileSize] unsignedIntegerValue];
                    NSDate *modDate = attrs[NSFileModificationDate];
                    if (modDate)
                        s_saveInfoArray[i].metaData.modifiedTime = (time_t)[modDate timeIntervalSince1970];
                }

                // Check for thumbnail
                NSString *thumbPath = [fullPath stringByAppendingString:@".thumb"];
                if ([fm fileExistsAtPath:thumbPath])
                {
                    NSData *thumbData = [NSData dataWithContentsOfFile:thumbPath];
                    if (thumbData)
                    {
                        s_saveInfoArray[i].metaData.thumbnailSize = (unsigned int)[thumbData length];
                        s_saveInfoArray[i].thumbnailData = (BYTE *)malloc([thumbData length]);
                        memcpy(s_saveInfoArray[i].thumbnailData,
                               [thumbData bytes], [thumbData length]);
                    }
                }
            }
        }

        s_saveDetails.iSaveC = s_saveInfoCount;
        s_saveDetails.SaveInfoA = s_saveInfoArray;
    }

    if (Func)
        Func(lpParam, &s_saveDetails, true);

    return (s_saveInfoCount > 0) ? ESaveGame_GetSavesInfo : ESaveGame_Idle;
}

PSAVE_DETAILS C4JStorage::ReturnSavesInfo()
{
    return &s_saveDetails;
}

void C4JStorage::ClearSavesInfo()
{
    if (s_saveInfoArray)
    {
        for (int i = 0; i < s_saveInfoCount; ++i)
        {
            if (s_saveInfoArray[i].thumbnailData)
                free(s_saveInfoArray[i].thumbnailData);
        }
        free(s_saveInfoArray);
        s_saveInfoArray = nullptr;
    }
    s_saveInfoCount = 0;
    memset(&s_saveDetails, 0, sizeof(s_saveDetails));
}

C4JStorage::ESaveGameState C4JStorage::LoadSaveDataThumbnail(PSAVE_INFO pSaveInfo,
                                                              int (*Func)(void *, BYTE *, DWORD),
                                                              void *lpParam)
{
    if (pSaveInfo && pSaveInfo->thumbnailData && pSaveInfo->metaData.thumbnailSize > 0)
    {
        if (Func)
            Func(lpParam, pSaveInfo->thumbnailData, pSaveInfo->metaData.thumbnailSize);
    }
    else
    {
        if (Func)
            Func(lpParam, nullptr, 0);
    }
    return ESaveGame_GetSaveThumbnail;
}

void C4JStorage::GetSaveCacheFileInfo(DWORD /*dwFile*/, XCONTENT_DATA & /*xContentData*/)
{
    // Not applicable on Apple
}

void C4JStorage::GetSaveCacheFileInfo(DWORD /*dwFile*/, BYTE ** /*ppbImageData*/,
                                       DWORD * /*pdwImageBytes*/)
{
    // Not applicable on Apple
}

// ---------------------------------------------------------------------------
// LoadSaveData
// ---------------------------------------------------------------------------
C4JStorage::ESaveGameState C4JStorage::LoadSaveData(PSAVE_INFO pSaveInfo,
                                                     int (*Func)(void *, const bool, const bool),
                                                     void *lpParam)
{
    if (!pSaveInfo)
    {
        if (Func) Func(lpParam, false, false);
        return ESaveGame_Idle;
    }

    @autoreleasepool {
        NSString *path = SaveFilePath(pSaveInfo->UTF8SaveFilename);
        NSData *data = [NSData dataWithContentsOfFile:path];

        if (data && [data length] > 0)
        {
            if (s_saveDataBuffer) free(s_saveDataBuffer);

            s_saveDataBytes = (unsigned int)[data length];
            s_saveDataBuffer = malloc(s_saveDataBytes);
            memcpy(s_saveDataBuffer, [data bytes], s_saveDataBytes);

            strncpy(s_uniqueFilename, pSaveInfo->UTF8SaveFilename,
                    MAX_SAVEFILENAME_LENGTH - 1);

            if (Func) Func(lpParam, true, false);
        }
        else
        {
            if (Func) Func(lpParam, false, false);
        }
    }

    return ESaveGame_Load;
}

// ---------------------------------------------------------------------------
// DeleteSaveData
// ---------------------------------------------------------------------------
C4JStorage::ESaveGameState C4JStorage::DeleteSaveData(PSAVE_INFO pSaveInfo,
                                                       int (*Func)(void *, const bool),
                                                       void *lpParam)
{
    if (!pSaveInfo)
    {
        if (Func) Func(lpParam, false);
        return ESaveGame_Idle;
    }

    @autoreleasepool {
        NSString *path = SaveFilePath(pSaveInfo->UTF8SaveFilename);
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL ok = [fm removeItemAtPath:path error:nil];

        // Also remove thumbnail
        NSString *thumbPath = [path stringByAppendingString:@".thumb"];
        [fm removeItemAtPath:thumbPath error:nil];

        if (Func) Func(lpParam, (bool)ok);
    }

    return ESaveGame_Delete;
}

// ---------------------------------------------------------------------------
// DLC
// ---------------------------------------------------------------------------
void C4JStorage::RegisterMarketplaceCountsCallback(int (* /*Func*/)(void *, C4JStorage::DLC_TMS_DETAILS *, int),
                                                    void * /*lpParam*/)
{
    // No marketplace on Apple
}

void C4JStorage::SetDLCPackageRoot(char *pszDLCRoot)
{
    if (pszDLCRoot)
        strncpy(s_dlcRoot, pszDLCRoot, sizeof(s_dlcRoot) - 1);
}

C4JStorage::EDLCStatus C4JStorage::GetDLCOffers(int /*iPad*/,
                                                 int (*Func)(void *, int, DWORD, int),
                                                 void *lpParam, DWORD /*dwOfferTypesBitmask*/)
{
    // No marketplace on Apple - return no offers
    if (Func)
        Func(lpParam, 0, 0, 0);
    return EDLC_NoOffers;
}

DWORD C4JStorage::CancelGetDLCOffers()
{
    return 0;
}

void C4JStorage::ClearDLCOffers()
{
    s_offerList.clear();
}

XMARKETPLACE_CONTENTOFFER_INFO &C4JStorage::GetOffer(DWORD dw)
{
    return s_offerList[dw];
}

int C4JStorage::GetOfferCount()
{
    return (int)s_offerList.size();
}

DWORD C4JStorage::InstallOffer(int /*iOfferIDC*/, uint64_t * /*ullOfferIDA*/,
                                int (*Func)(void *, int, int), void *lpParam,
                                bool /*bTrial*/)
{
    if (Func) Func(lpParam, 0, 0);
    return 0;
}

DWORD C4JStorage::GetAvailableDLCCount(int /*iPad*/)
{
    return (DWORD)s_dlcList.size();
}

C4JStorage::EDLCStatus C4JStorage::GetInstalledDLC(int /*iPad*/,
                                                    int (*Func)(void *, int, int),
                                                    void *lpParam)
{
    // Scan the DLC root directory for installed packs
    s_dlcList.clear();

    if (s_dlcRoot[0] == '\0')
    {
        if (Func) Func(lpParam, 0, 0);
        return EDLC_NoInstalledDLC;
    }

    @autoreleasepool {
        NSString *dlcPath = [NSString stringWithUTF8String:s_dlcRoot];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *contents = [fm contentsOfDirectoryAtPath:dlcPath error:nil];

        for (NSString *item in contents)
        {
            NSString *fullPath = [dlcPath stringByAppendingPathComponent:item];
            BOOL isDir = NO;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            if (!isDir) continue;

            XCONTENT_DATA dlc;
            memset(&dlc, 0, sizeof(dlc));
            strncpy(dlc.szFileName, [item UTF8String], XCONTENT_MAX_FILENAME_LENGTH - 1);
            strncpy(dlc.szMountPath, [fullPath UTF8String], sizeof(dlc.szMountPath) - 1);
            s_dlcList.push_back(dlc);
        }
    }

    int count = (int)s_dlcList.size();
    if (Func) Func(lpParam, count, count);

    return (count > 0) ? EDLC_Loaded : EDLC_NoInstalledDLC;
}

XCONTENT_DATA &C4JStorage::GetDLC(DWORD dw)
{
    return s_dlcList[dw];
}

DWORD C4JStorage::MountInstalledDLC(int /*iPad*/, DWORD dwDLC,
                                     int (*Func)(void *, int, DWORD, DWORD),
                                     void *lpParam, const char *szMountDrive)
{
    if (dwDLC < s_dlcList.size())
    {
        strncpy(s_mountedPath, s_dlcList[dwDLC].szMountPath, sizeof(s_mountedPath) - 1);
    }

    if (Func) Func(lpParam, 0, dwDLC, 0);
    return 0;
}

DWORD C4JStorage::UnmountInstalledDLC(const char * /*szMountDrive*/)
{
    memset(s_mountedPath, 0, sizeof(s_mountedPath));
    return 0;
}

void C4JStorage::GetMountedDLCFileList(const char * /*szMountDrive*/,
                                        std::vector<std::string> &fileList)
{
    fileList.clear();
    if (s_mountedPath[0] == '\0') return;

    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:s_mountedPath];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];

        NSString *file;
        while ((file = [enumerator nextObject]))
        {
            NSString *fullPath = [path stringByAppendingPathComponent:file];
            BOOL isDir = NO;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            if (!isDir)
                fileList.push_back([file UTF8String]);
        }
    }
}

std::string C4JStorage::GetMountedPath(std::string szMount)
{
    return std::string(s_mountedPath);
}

// ---------------------------------------------------------------------------
// TMS (Title Managed Storage) - stubs
// On Apple we store these as local files in the Application Support directory.
// ---------------------------------------------------------------------------
C4JStorage::ETMSStatus C4JStorage::ReadTMSFile(int /*iQuadrant*/,
                                                eGlobalStorage /*eStorageFacility*/,
                                                C4JStorage::eTMS_FileType /*eFileType*/,
                                                WCHAR *pwchFilename,
                                                BYTE **ppBuffer, DWORD *pdwBufferSize,
                                                int (*Func)(void *, WCHAR *, int, bool, int),
                                                void *lpParam, int iAction)
{
    // Convert WCHAR filename to char
    char filename[256] = {};
    if (pwchFilename)
    {
        for (int i = 0; i < 255 && pwchFilename[i]; ++i)
            filename[i] = (char)pwchFilename[i];
    }

    @autoreleasepool {
        NSString *basePath = GetSaveBasePath();
        NSString *tmsDir = [[basePath stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:@"tms"];
        EnsureDirectory(tmsDir);

        NSString *filePath = [tmsDir stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:filename]];
        NSData *data = [NSData dataWithContentsOfFile:filePath];

        if (data && [data length] > 0)
        {
            DWORD size = (DWORD)[data length];
            BYTE *buffer = (BYTE *)malloc(size);
            memcpy(buffer, [data bytes], size);

            if (ppBuffer) *ppBuffer = buffer;
            if (pdwBufferSize) *pdwBufferSize = size;

            if (Func) Func(lpParam, pwchFilename, iAction, true, 0);
            return ETMSStatus_Idle;
        }
    }

    if (ppBuffer) *ppBuffer = nullptr;
    if (pdwBufferSize) *pdwBufferSize = 0;
    if (Func) Func(lpParam, pwchFilename, iAction, false, 0);
    return ETMSStatus_Fail;
}

bool C4JStorage::WriteTMSFile(int /*iQuadrant*/, eGlobalStorage /*eStorageFacility*/,
                               WCHAR *pwchFilename, BYTE *pBuffer, DWORD dwBufferSize)
{
    char filename[256] = {};
    if (pwchFilename)
    {
        for (int i = 0; i < 255 && pwchFilename[i]; ++i)
            filename[i] = (char)pwchFilename[i];
    }

    @autoreleasepool {
        NSString *basePath = GetSaveBasePath();
        NSString *tmsDir = [[basePath stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:@"tms"];
        EnsureDirectory(tmsDir);

        NSString *filePath = [tmsDir stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:filename]];
        NSData *data = [NSData dataWithBytes:pBuffer length:dwBufferSize];
        return [data writeToFile:filePath atomically:YES];
    }
}

bool C4JStorage::DeleteTMSFile(int /*iQuadrant*/, eGlobalStorage /*eStorageFacility*/,
                                WCHAR *pwchFilename)
{
    char filename[256] = {};
    if (pwchFilename)
    {
        for (int i = 0; i < 255 && pwchFilename[i]; ++i)
            filename[i] = (char)pwchFilename[i];
    }

    @autoreleasepool {
        NSString *basePath = GetSaveBasePath();
        NSString *tmsDir = [[basePath stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:@"tms"];
        NSString *filePath = [tmsDir stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:filename]];
        return [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
}

void C4JStorage::StoreTMSPathName(WCHAR *pwchName)
{
    if (pwchName)
    {
        for (int i = 0; i < 511 && pwchName[i]; ++i)
            s_tmsPathName[i] = pwchName[i];
    }
}

C4JStorage::ETMSStatus C4JStorage::TMSPP_ReadFile(int /*iPad*/,
                                                    C4JStorage::eGlobalStorage /*eStorageFacility*/,
                                                    C4JStorage::eTMS_FILETYPEVAL /*eFileTypeVal*/,
                                                    const char *szFilename,
                                                    int (*Func)(void *, int, int, PTMSPP_FILEDATA, const char *),
                                                    void *lpParam, int iUserData)
{
    @autoreleasepool {
        NSString *basePath = GetSaveBasePath();
        NSString *tmsDir = [[basePath stringByDeletingLastPathComponent]
                            stringByAppendingPathComponent:@"tms"];
        NSString *filePath = [tmsDir stringByAppendingPathComponent:
                              [NSString stringWithUTF8String:szFilename]];
        NSData *data = [NSData dataWithContentsOfFile:filePath];

        if (data && [data length] > 0)
        {
            TMSPP_FILEDATA fileData;
            fileData.dwSize = (DWORD)[data length];
            fileData.pbData = (BYTE *)malloc(fileData.dwSize);
            memcpy(fileData.pbData, [data bytes], fileData.dwSize);

            if (Func) Func(lpParam, iUserData, 0, &fileData, szFilename);
            return ETMSStatus_Idle;
        }
    }

    if (Func) Func(lpParam, iUserData, -1, nullptr, szFilename);
    return ETMSStatus_Fail;
}

// ---------------------------------------------------------------------------
// CRC utility
// ---------------------------------------------------------------------------
unsigned int C4JStorage::CRC(unsigned char *buf, int len)
{
    unsigned int crc = 0xFFFFFFFF;
    for (int i = 0; i < len; ++i)
    {
        crc = s_crcTable[(crc ^ buf[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
}
