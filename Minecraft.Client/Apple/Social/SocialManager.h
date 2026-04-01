#pragma once
enum ESocialNetwork { eSocialNetwork_None = 0 };
class CSocialManager {
public:
    bool IsTitleAllowedToPostAnything();
    bool AreAllUsersAllowedToPostImages();
    bool IsTitleAllowedToPostImages();
    bool PostLinkToSocialNetwork(ESocialNetwork, DWORD, bool);
    bool PostImageToSocialNetwork(ESocialNetwork, DWORD, bool);
    static CSocialManager* Instance();
    void SetSocialPostText(LPCWSTR, LPCWSTR, LPCWSTR);
};
