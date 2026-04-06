#pragma once

// Apple_UIController.h — Metal-based UIController for macOS and iOS
// Matches the ConsoleUIController / Windows64_UIController interface,
// but uses GDraw Metal context instead of GDraw D3D11.

#include "../../Common/UI/UIController.h"

// Forward-declare Metal types so this header compiles in pure C++ TUs.
// The .mm implementation file imports <Metal/Metal.h> for the real types.
#ifdef __OBJC__
@protocol MTLDevice;
@protocol MTLCommandQueue;
@protocol MTLTexture;
#else
typedef void* id;
#endif

class Apple_UIController : public UIController
{
private:
    // Metal render targets (opaque pointers in C++ TUs, real ids in ObjC++)
    void* m_metalDevice;           // id<MTLDevice>
    void* m_metalCommandQueue;     // id<MTLCommandQueue>
    void* m_colorTexture;          // id<MTLTexture> (current render target)
    void* m_depthStencilTexture;   // id<MTLTexture>

public:
    // Initialise with Metal device and render targets
    // width/height = backbuffer dimensions in pixels
    void init(void* metalDevice, void* metalCommandQueue,
              void* colorTexture, void* depthStencilTexture,
              S32 width, S32 height);

    // Per-frame rendering of all Iggy/Flash UI scenes
    virtual void render() override;

    // Iggy custom draw callbacks (stubs until GDraw Metal is integrated)
    void beginIggyCustomDraw4J(IggyCustomDrawCallbackRegion* region, CustomDrawData* customDrawRegion) override;
    virtual CustomDrawData* setupCustomDraw(UIScene* scene, IggyCustomDrawCallbackRegion* region) override;
    virtual CustomDrawData* calculateCustomDraw(IggyCustomDrawCallbackRegion* region) override;
    virtual void endCustomDraw(IggyCustomDrawCallbackRegion* region) override;

    // Update render targets after a resize
    void updateRenderTargets(void* colorTexture, void* depthStencilTexture);

protected:
    virtual void setTileOrigin(S32 xPos, S32 yPos) override;

public:
    GDrawTexture* getSubstitutionTexture(int textureId);
    void destroySubstitutionTexture(void* destroyCallBackData, GDrawTexture* handle);

    // Override tick/render to be safe without Iggy
    virtual void tick() override;
    void CheckMenuDisplayed();

public:
    void shutdown();
};

extern Apple_UIController ui;
