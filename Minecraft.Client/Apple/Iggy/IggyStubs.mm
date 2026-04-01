// IggyStubs.mm - Stub implementations of all Iggy API functions for Apple
//
// These stubs allow the game to link and run without the actual Iggy
// Flash rendering library. The game world renders normally; UI elements
// that depend on Flash/SWF will be non-functional (invisible) until a
// real Iggy implementation is provided.
//
// In debug builds, each stub logs its call for tracing and debugging.

#include "include/iggy.h"
#include "include/iggyexpruntime.h"
#include "include/iggyperfmon.h"
#include "include/rrCore.h"

#include <stdlib.h>
#include <string.h>

// ========================================================================
// Debug logging
// ========================================================================
#if defined(DEBUG) || defined(_DEBUG)
   #include <stdio.h>
   #define IGGY_STUB_LOG(func_name) printf("[Iggy Stub] %s\n", func_name)
#else
   #define IGGY_STUB_LOG(func_name) ((void)0)
#endif

// ========================================================================
// Internal state for the stub Iggy "player"
// ========================================================================

// Dummy player struct -- just enough to return a valid pointer
// so callers can check for non-null and pass it around
struct Iggy
{
    void            *user_data;         // User-provided data pointer
    IggyProperties   properties;        // Movie properties (zeroed)
    IggyValuePath    root_path;         // Root value path for AS3 access
    IggyValuePath    callback_result;   // Callback result path
    rrbool           is_valid;          // Whether this player is alive
};

// ========================================================================
// Static allocator storage (set by IggyInit)
// ========================================================================
static IggyAllocator g_stub_allocator = {};
static rrbool g_stub_initialized = 0;

// Helper: allocate memory using the registered allocator, or fallback to malloc
static void * stub_alloc(size_t size)
{
    if (g_stub_allocator.mem_alloc)
    {
        size_t actual_size = 0;
        return g_stub_allocator.mem_alloc(g_stub_allocator.user_callback_data, size, &actual_size);
    }
    return malloc(size);
}

// Helper: free memory using the registered allocator, or fallback to free
static void stub_free(void *ptr)
{
    if (g_stub_allocator.mem_free)
    {
        g_stub_allocator.mem_free(g_stub_allocator.user_callback_data, ptr);
        return;
    }
    free(ptr);
}

// ========================================================================
// Initialization and shutdown
// ========================================================================

void IggyInit(IggyAllocator *allocator)
{
    IGGY_STUB_LOG("IggyInit");
    if (allocator)
    {
        g_stub_allocator = *allocator;
    }
    g_stub_initialized = 1;
}

void IggyShutdown(void)
{
    IGGY_STUB_LOG("IggyShutdown");
    memset(&g_stub_allocator, 0, sizeof(g_stub_allocator));
    g_stub_initialized = 0;
}

// ========================================================================
// Configuration
// ========================================================================

void IggyConfigureBool(IggyConfigureBoolName prop, rrbool value)
{
    IGGY_STUB_LOG("IggyConfigureBool");
    (void)prop; (void)value;
}

void IggyConfigureVersionedBehavior(IggyVersionedBehaviorName prop, IggyVersionNumber value)
{
    IGGY_STUB_LOG("IggyConfigureVersionedBehavior");
    (void)prop; (void)value;
}

void IggyUseTmLite(void *context, IggyTelemetryAmount amount)
{
    IGGY_STUB_LOG("IggyUseTmLite");
    (void)context; (void)amount;
}

void IggyUseTelemetry(void *context, IggyTelemetryAmount amount)
{
    IGGY_STUB_LOG("IggyUseTelemetry");
    (void)context; (void)amount;
}

// ========================================================================
// Translation stubs
// ========================================================================

void IggySetLoadtimeTranslationFunction(Iggy_TranslateFunctionUTF16 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetLoadtimeTranslationFunction"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetLoadtimeTranslationFunctionUTF16(Iggy_TranslateFunctionUTF16 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetLoadtimeTranslationFunctionUTF16"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetLoadtimeTranslationFunctionUTF8(Iggy_TranslateFunctionUTF8 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetLoadtimeTranslationFunctionUTF8"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetRuntimeTranslationFunction(Iggy_TranslateFunctionUTF16 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetRuntimeTranslationFunction"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetRuntimeTranslationFunctionUTF16(Iggy_TranslateFunctionUTF16 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetRuntimeTranslationFunctionUTF16"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetRuntimeTranslationFunctionUTF8(Iggy_TranslateFunctionUTF8 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetRuntimeTranslationFunctionUTF8"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetTextfieldTranslationFunctionUTF16(Iggy_TextfieldTranslateFunctionUTF16 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetTextfieldTranslationFunctionUTF16"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetTextfieldTranslationFunctionUTF8(Iggy_TextfieldTranslateFunctionUTF8 *func, void *callback_data, Iggy_TranslationFreeFunction *freefunc, void *free_callback_data)
{ IGGY_STUB_LOG("IggySetTextfieldTranslationFunctionUTF8"); (void)func; (void)callback_data; (void)freefunc; (void)free_callback_data; }

void IggySetLanguage(IggyLanguageCode lang)
{ IGGY_STUB_LOG("IggySetLanguage"); (void)lang; }

// ========================================================================
// Player creation and destruction
// ========================================================================

Iggy * IggyPlayerCreateFromFileAndPlay(char const *filename, IggyPlayerConfig const *config)
{
    IGGY_STUB_LOG("IggyPlayerCreateFromFileAndPlay");
    (void)filename; (void)config;

    // Allocate a stub player so callers get a valid, non-null handle
    Iggy *player = (Iggy *)stub_alloc(sizeof(Iggy));
    if (player)
    {
        memset(player, 0, sizeof(Iggy));
        player->is_valid = 1;
        // Initialize root path to point to this player
        player->root_path.f = player;
        player->callback_result.f = player;
    }
    return player;
}

Iggy * IggyPlayerCreateFromMemory(void const *data, U32 data_size_in_bytes, IggyPlayerConfig *config)
{
    IGGY_STUB_LOG("IggyPlayerCreateFromMemory");
    (void)data; (void)data_size_in_bytes; (void)config;

    Iggy *player = (Iggy *)stub_alloc(sizeof(Iggy));
    if (player)
    {
        memset(player, 0, sizeof(Iggy));
        player->is_valid = 1;
        player->root_path.f = player;
        player->callback_result.f = player;
    }
    return player;
}

IggyLibrary IggyLibraryCreateFromMemory(char const *url_utf8_null_terminated, void const *data, U32 data_size_in_bytes, IggyPlayerConfig *config)
{
    IGGY_STUB_LOG("IggyLibraryCreateFromMemory");
    (void)url_utf8_null_terminated; (void)data; (void)data_size_in_bytes; (void)config;
    // Return a valid library handle (just a non-negative number)
    return 0;
}

IggyLibrary IggyLibraryCreateFromMemoryUTF16(IggyUTF16 const *url_utf16_null_terminated, void const *data, U32 data_size_in_bytes, IggyPlayerConfig *config)
{
    IGGY_STUB_LOG("IggyLibraryCreateFromMemoryUTF16");
    (void)url_utf16_null_terminated; (void)data; (void)data_size_in_bytes; (void)config;
    return 0;
}

void IggyPlayerDestroy(Iggy *player)
{
    IGGY_STUB_LOG("IggyPlayerDestroy");
    if (player)
    {
        player->is_valid = 0;
        stub_free(player);
    }
}

void IggyLibraryDestroy(IggyLibrary lib)
{
    IGGY_STUB_LOG("IggyLibraryDestroy");
    (void)lib;
}

// ========================================================================
// Warning and trace callbacks
// ========================================================================

void IggySetWarningCallback(Iggy_WarningFunction *error, void *user_callback_data)
{
    IGGY_STUB_LOG("IggySetWarningCallback");
    (void)error; (void)user_callback_data;
}

void IggySetTraceCallbackUTF8(Iggy_TraceFunctionUTF8 *trace_utf8, void *user_callback_data)
{
    IGGY_STUB_LOG("IggySetTraceCallbackUTF8");
    (void)trace_utf8; (void)user_callback_data;
}

void IggySetTraceCallbackUTF16(Iggy_TraceFunctionUTF16 *trace_utf16, void *user_callback_data)
{
    IGGY_STUB_LOG("IggySetTraceCallbackUTF16");
    (void)trace_utf16; (void)user_callback_data;
}

// ========================================================================
// Player properties and state
// ========================================================================

IggyProperties * IggyPlayerProperties(Iggy *player)
{
    IGGY_STUB_LOG("IggyPlayerProperties");
    if (!player) return nullptr;
    return &player->properties;
}

void * IggyPlayerGetUserdata(Iggy *player)
{
    IGGY_STUB_LOG("IggyPlayerGetUserdata");
    if (!player) return nullptr;
    return player->user_data;
}

void IggyPlayerSetUserdata(Iggy *player, void *userdata)
{
    IGGY_STUB_LOG("IggyPlayerSetUserdata");
    if (player) player->user_data = userdata;
}

rrbool IggyPlayerGetValid(Iggy *f)
{
    IGGY_STUB_LOG("IggyPlayerGetValid");
    return f ? f->is_valid : 0;
}

// ========================================================================
// Playback control
// ========================================================================

void IggyPlayerInitializeAndTickRS(Iggy *player)
{
    IGGY_STUB_LOG("IggyPlayerInitializeAndTickRS");
    (void)player;
}

rrbool IggyPlayerReadyToTick(Iggy *player)
{
    // Always report ready so the game loop keeps advancing
    (void)player;
    return 1;
}

void IggyPlayerTickRS(Iggy *player)
{
    // No-op: no Flash timeline to advance
    (void)player;
}

void IggyPlayerPause(Iggy *player, IggyAudioPauseMode pause_audio)
{
    IGGY_STUB_LOG("IggyPlayerPause");
    (void)player; (void)pause_audio;
}

void IggyPlayerPlay(Iggy *player)
{
    IGGY_STUB_LOG("IggyPlayerPlay");
    (void)player;
}

void IggyPlayerSetFrameRate(Iggy *player, F32 frame_rate_in_fps)
{
    IGGY_STUB_LOG("IggyPlayerSetFrameRate");
    if (player)
    {
        player->properties.movie_frame_rate_current_in_fps = frame_rate_in_fps;
    }
}

void IggyPlayerGotoFrameRS(Iggy *f, S32 frame, rrbool stop)
{
    IGGY_STUB_LOG("IggyPlayerGotoFrameRS");
    (void)f; (void)frame; (void)stop;
}

// ========================================================================
// Explorer and Perfmon stubs
// ========================================================================

void IggyInstallPerfmon(void *perfmon_context)
{ IGGY_STUB_LOG("IggyInstallPerfmon"); (void)perfmon_context; }

void IggyUseExplorer(Iggy *swf, void *context)
{ IGGY_STUB_LOG("IggyUseExplorer"); (void)swf; (void)context; }

void IggyPlayerSendFrameToExplorer(Iggy *f)
{ IGGY_STUB_LOG("IggyPlayerSendFrameToExplorer"); (void)f; }

// ========================================================================
// Font stubs
// ========================================================================

void IggySetInstalledFontMaxCount(S32 num) { IGGY_STUB_LOG("IggySetInstalledFontMaxCount"); (void)num; }
void IggySetIndirectFontMaxCount(S32 num) { IGGY_STUB_LOG("IggySetIndirectFontMaxCount"); (void)num; }

void IggyFontInstallTruetypeUTF8(const void *ts, S32 ttc, const char *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallTruetypeUTF8"); (void)ts; (void)ttc; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallTruetypeUTF16(const void *ts, S32 ttc, const U16 *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallTruetypeUTF16"); (void)ts; (void)ttc; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallTruetypeFallbackCodepointUTF8(const char *fn, S32 len, U32 ff, S32 fb)
{ IGGY_STUB_LOG("IggyFontInstallTruetypeFallbackCodepointUTF8"); (void)fn; (void)len; (void)ff; (void)fb; }

void IggyFontInstallTruetypeFallbackCodepointUTF16(const U16 *fn, S32 len, U32 ff, S32 fb)
{ IGGY_STUB_LOG("IggyFontInstallTruetypeFallbackCodepointUTF16"); (void)fn; (void)len; (void)ff; (void)fb; }

void IggyFontInstallVectorUTF8(const IggyVectorFontProvider *vfp, const char *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallVectorUTF8"); (void)vfp; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallVectorUTF16(const IggyVectorFontProvider *vfp, const U16 *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallVectorUTF16"); (void)vfp; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallBitmapUTF8(const IggyBitmapFontProvider *bmf, const char *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallBitmapUTF8"); (void)bmf; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallBitmapUTF16(const IggyBitmapFontProvider *bmf, const U16 *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallBitmapUTF16"); (void)bmf; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallBitmapOverrideUTF8(const IggyBitmapFontOverride *bmf, const char *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallBitmapOverrideUTF8"); (void)bmf; (void)fn; (void)nl; (void)ff; }

void IggyFontInstallBitmapOverrideUTF16(const IggyBitmapFontOverride *bmf, const U16 *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontInstallBitmapOverrideUTF16"); (void)bmf; (void)fn; (void)nl; (void)ff; }

void IggyFontRemoveUTF8(const char *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontRemoveUTF8"); (void)fn; (void)nl; (void)ff; }

void IggyFontRemoveUTF16(const U16 *fn, S32 nl, U32 ff)
{ IGGY_STUB_LOG("IggyFontRemoveUTF16"); (void)fn; (void)nl; (void)ff; }

void IggyFontSetIndirectUTF8(const char *rn, S32 rnl, U32 rf, const char *rsn, S32 rsnl, U32 rsf)
{ IGGY_STUB_LOG("IggyFontSetIndirectUTF8"); (void)rn; (void)rnl; (void)rf; (void)rsn; (void)rsnl; (void)rsf; }

void IggyFontSetIndirectUTF16(const U16 *rn, S32 rnl, U32 rf, const U16 *rsn, S32 rsnl, U32 rsf)
{ IGGY_STUB_LOG("IggyFontSetIndirectUTF16"); (void)rn; (void)rnl; (void)rf; (void)rsn; (void)rsnl; (void)rsf; }

void IggyFontSetFallbackFontUTF8(const char *fn, S32 fnl, U32 ff)
{ IGGY_STUB_LOG("IggyFontSetFallbackFontUTF8"); (void)fn; (void)fnl; (void)ff; }

void IggyFontSetFallbackFontUTF16(const U16 *fn, S32 fnl, U32 ff)
{ IGGY_STUB_LOG("IggyFontSetFallbackFontUTF16"); (void)fn; (void)fnl; (void)ff; }

void IggyFlushInstalledFonts(void)
{ IGGY_STUB_LOG("IggyFlushInstalledFonts"); }

// ========================================================================
// Audio stubs (all no-ops on Apple -- no DirectSound, XAudio2, etc.)
// ========================================================================

void IggyAudioSetDriver(IGGYSND_OPEN_FUNC driver_open, U32 flags)
{ IGGY_STUB_LOG("IggyAudioSetDriver"); (void)driver_open; (void)flags; }

void IggyAudioUseDirectSound(void) { IGGY_STUB_LOG("IggyAudioUseDirectSound (no-op on Apple)"); }
void IggyAudioUseWaveOut(void)     { IGGY_STUB_LOG("IggyAudioUseWaveOut (no-op on Apple)"); }
void IggyAudioUseXAudio2(void)     { IGGY_STUB_LOG("IggyAudioUseXAudio2 (no-op on Apple)"); }
void IggyAudioUseLibAudio(void)    { IGGY_STUB_LOG("IggyAudioUseLibAudio (no-op on Apple)"); }
void IggyAudioUseAX(void)          { IGGY_STUB_LOG("IggyAudioUseAX (no-op on Apple)"); }
void IggyAudioUseCoreAudio(void)   { IGGY_STUB_LOG("IggyAudioUseCoreAudio"); }
void IggyAudioUseDefault(void)     { IGGY_STUB_LOG("IggyAudioUseDefault"); }

IggyGetMP3Decoder* IggyAudioGetMP3Decoder(void)
{ IGGY_STUB_LOG("IggyAudioGetMP3Decoder"); return nullptr; }

void IggyAudioInstallMP3DecoderExplicit(IggyGetMP3Decoder *init)
{ IGGY_STUB_LOG("IggyAudioInstallMP3DecoderExplicit"); (void)init; }

rrbool IggyAudioSetMaxBufferTime(S32 ms)
{ IGGY_STUB_LOG("IggyAudioSetMaxBufferTime"); (void)ms; return 1; }

void IggyAudioSetLatency(S32 ms)
{ IGGY_STUB_LOG("IggyAudioSetLatency"); (void)ms; }

void IggyPlayerSetAudioVolume(Iggy *iggy, F32 attenuation)
{ IGGY_STUB_LOG("IggyPlayerSetAudioVolume"); (void)iggy; (void)attenuation; }

void IggyPlayerSetAudioDevice(Iggy *iggy, S32 device)
{ IGGY_STUB_LOG("IggyPlayerSetAudioDevice"); (void)iggy; (void)device; }

// ========================================================================
// Rendering stubs
// ========================================================================

void IggySetCustomDrawCallback(Iggy_CustomDrawCallback *custom_draw, void *user_callback_data)
{ IGGY_STUB_LOG("IggySetCustomDrawCallback"); (void)custom_draw; (void)user_callback_data; }

void IggySetTextureSubstitutionCallbacks(Iggy_TextureSubstitutionCreateCallback *tc, Iggy_TextureSubstitutionDestroyCallback *td, void *ud)
{ IGGY_STUB_LOG("IggySetTextureSubstitutionCallbacks"); (void)tc; (void)td; (void)ud; }

void IggySetTextureSubstitutionCallbacksUTF8(Iggy_TextureSubstitutionCreateCallbackUTF8 *tc, Iggy_TextureSubstitutionDestroyCallback *td, void *ud)
{ IGGY_STUB_LOG("IggySetTextureSubstitutionCallbacksUTF8"); (void)tc; (void)td; (void)ud; }

void IggyTextureSubstitutionFlush(GDrawTexture *handle, IggyTextureSubstitutionFlushMode mode)
{ IGGY_STUB_LOG("IggyTextureSubstitutionFlush"); (void)handle; (void)mode; }

void IggyTextureSubstitutionFlushAll(IggyTextureSubstitutionFlushMode mode)
{ IGGY_STUB_LOG("IggyTextureSubstitutionFlushAll"); (void)mode; }

void IggySetGDraw(GDrawFunctions *gdraw)
{
    IGGY_STUB_LOG("IggySetGDraw");
    (void)gdraw;
    // In a real implementation, this stores the GDraw function table for Iggy's renderer.
    // The stub does nothing since we have no Flash rendering.
}

void IggyPlayerGetBackgroundColor(Iggy *player, F32 output_color[3])
{
    IGGY_STUB_LOG("IggyPlayerGetBackgroundColor");
    (void)player;
    if (output_color)
    {
        output_color[0] = 0.0f;
        output_color[1] = 0.0f;
        output_color[2] = 0.0f;
    }
}

void IggyPlayerSetDisplaySize(Iggy *f, S32 w, S32 h)
{
    IGGY_STUB_LOG("IggyPlayerSetDisplaySize");
    if (f)
    {
        f->properties.movie_width_in_pixels  = w;
        f->properties.movie_height_in_pixels = h;
    }
}

void IggyPlayerSetPixelShape(Iggy *swf, F32 pixel_x, F32 pixel_y)
{ IGGY_STUB_LOG("IggyPlayerSetPixelShape"); (void)swf; (void)pixel_x; (void)pixel_y; }

void IggyPlayerSetStageRotation(Iggy *f, Iggy90DegreeRotation rot)
{ IGGY_STUB_LOG("IggyPlayerSetStageRotation"); (void)f; (void)rot; }

void IggyPlayerDraw(Iggy *f)
{
    // No-op: no Flash content to render
    (void)f;
}

void IggyPlayerSetStageSize(Iggy *f, S32 w, S32 h)
{ IGGY_STUB_LOG("IggyPlayerSetStageSize"); (void)f; (void)w; (void)h; }

void IggyPlayerSetFaux3DStage(Iggy *f, F32 *tl, F32 *tr, F32 *bl, F32 *br, F32 ds)
{ IGGY_STUB_LOG("IggyPlayerSetFaux3DStage"); (void)f; (void)tl; (void)tr; (void)bl; (void)br; (void)ds; }

void IggyPlayerForceMipmaps(Iggy *f, rrbool force_mipmaps)
{ IGGY_STUB_LOG("IggyPlayerForceMipmaps"); (void)f; (void)force_mipmaps; }

void IggyPlayerDrawTile(Iggy *f, S32 x0, S32 y0, S32 x1, S32 y1, S32 padding)
{ (void)f; (void)x0; (void)y0; (void)x1; (void)y1; (void)padding; }

void IggyPlayerDrawTilesStart(Iggy *f)
{ (void)f; }

void IggyPlayerDrawTilesEnd(Iggy *f)
{ (void)f; }

void IggyPlayerSetRootTransform(Iggy *f, F32 mat[4], F32 tx, F32 ty)
{ IGGY_STUB_LOG("IggyPlayerSetRootTransform"); (void)f; (void)mat; (void)tx; (void)ty; }

void IggyPlayerFlushAll(Iggy *player)
{ IGGY_STUB_LOG("IggyPlayerFlushAll"); (void)player; }

void IggyLibraryFlushAll(IggyLibrary h)
{ IGGY_STUB_LOG("IggyLibraryFlushAll"); (void)h; }

void IggySetTextCursorPixelWidth(S32 width)
{ IGGY_STUB_LOG("IggySetTextCursorPixelWidth"); (void)width; }

void IggyForceBitmapSmoothing(rrbool force_on)
{ IGGY_STUB_LOG("IggyForceBitmapSmoothing"); (void)force_on; }

void IggyFastTextFilterEffects(rrbool enable)
{ IGGY_STUB_LOG("IggyFastTextFilterEffects"); (void)enable; }

void IggyPlayerSetAntialiasing(Iggy *f, IggyAntialiasing antialias_mode)
{ IGGY_STUB_LOG("IggyPlayerSetAntialiasing"); (void)f; (void)antialias_mode; }

void IggyPlayerSetBitmapFontCaching(Iggy *f, S32 tw, S32 th, S32 mcpw, S32 mcph)
{ IGGY_STUB_LOG("IggyPlayerSetBitmapFontCaching"); (void)f; (void)tw; (void)th; (void)mcpw; (void)mcph; }

void IggySetFontCachingCalculationBuffer(S32 max_chars, void *buf, S32 buf_size)
{ IGGY_STUB_LOG("IggySetFontCachingCalculationBuffer"); (void)max_chars; (void)buf; (void)buf_size; }

IggyGeneric * IggyPlayerGetGeneric(Iggy *player)
{ IGGY_STUB_LOG("IggyPlayerGetGeneric"); (void)player; return nullptr; }

IggyGeneric * IggyLibraryGetGeneric(IggyLibrary lib)
{ IGGY_STUB_LOG("IggyLibraryGetGeneric"); (void)lib; return nullptr; }

void IggyGenericInstallResourceFile(IggyGeneric *g, void *data, S32 data_length, rrbool *can_free_now)
{
    IGGY_STUB_LOG("IggyGenericInstallResourceFile");
    (void)g; (void)data; (void)data_length;
    if (can_free_now) *can_free_now = 1;
}

IggyTextureResourceMetadata * IggyGenericGetTextureResourceMetadata(IggyGeneric *f)
{ IGGY_STUB_LOG("IggyGenericGetTextureResourceMetadata"); (void)f; return nullptr; }

void IggyGenericSetTextureFromResource(IggyGeneric *f, U16 id, GDrawTexture *handle)
{ IGGY_STUB_LOG("IggyGenericSetTextureFromResource"); (void)f; (void)id; (void)handle; }

// ========================================================================
// AS3 interface stubs
// ========================================================================

void IggySetAS3ExternalFunctionCallbackUTF8(Iggy_AS3ExternalFunctionUTF8 *cb, void *ud)
{ IGGY_STUB_LOG("IggySetAS3ExternalFunctionCallbackUTF8"); (void)cb; (void)ud; }

void IggySetAS3ExternalFunctionCallbackUTF16(Iggy_AS3ExternalFunctionUTF16 *cb, void *ud)
{ IGGY_STUB_LOG("IggySetAS3ExternalFunctionCallbackUTF16"); (void)cb; (void)ud; }

IggyName IggyPlayerCreateFastName(Iggy *f, IggyUTF16 const *name, S32 len)
{
    IGGY_STUB_LOG("IggyPlayerCreateFastName");
    (void)f; (void)name; (void)len;
    return 0;
}

IggyName IggyPlayerCreateFastNameUTF8(Iggy *f, char const *name, S32 len)
{
    IGGY_STUB_LOG("IggyPlayerCreateFastNameUTF8");
    (void)f; (void)name; (void)len;
    return 0;
}

IggyResult IggyPlayerCallFunctionRS(Iggy *player, IggyDataValue *result, IggyName function, S32 numargs, IggyDataValue *args)
{
    IGGY_STUB_LOG("IggyPlayerCallFunctionRS");
    (void)player; (void)function; (void)numargs; (void)args;
    if (result)
    {
        memset(result, 0, sizeof(*result));
        result->type = IGGY_DATATYPE_undefined;
    }
    return IGGY_RESULT_SUCCESS;
}

IggyResult IggyPlayerCallMethodRS(Iggy *f, IggyDataValue *result, IggyValuePath *target, IggyName methodname, S32 numargs, IggyDataValue *args)
{
    IGGY_STUB_LOG("IggyPlayerCallMethodRS");
    (void)f; (void)target; (void)methodname; (void)numargs; (void)args;
    if (result)
    {
        memset(result, 0, sizeof(*result));
        result->type = IGGY_DATATYPE_undefined;
    }
    return IGGY_RESULT_SUCCESS;
}

void IggyPlayerGarbageCollect(Iggy *player, S32 strength)
{ IGGY_STUB_LOG("IggyPlayerGarbageCollect"); (void)player; (void)strength; }

void IggyPlayerConfigureGCBehavior(Iggy *player, Iggy_GarbageCollectionCallback *notify_callback, IggyGarbageCollectorControl *control)
{ IGGY_STUB_LOG("IggyPlayerConfigureGCBehavior"); (void)player; (void)notify_callback; (void)control; }

void IggyPlayerQueryGCSizes(Iggy *player, IggyPlayerGCSizes *sizes)
{
    IGGY_STUB_LOG("IggyPlayerQueryGCSizes");
    (void)player;
    if (sizes) memset(sizes, 0, sizeof(*sizes));
}

// ========================================================================
// Value path and variable access stubs
// ========================================================================

rrbool IggyValueRefCheck(IggyValueRef ref) { (void)ref; return 0; }
void IggyValueRefFree(Iggy *p, IggyValueRef ref) { (void)p; (void)ref; }
IggyValueRef IggyValueRefFromPath(IggyValuePath *var, IggyValueRefType reftype) { (void)var; (void)reftype; return nullptr; }
rrbool IggyIsValueRefSameObjectAsTempRef(IggyValueRef vr, IggyTempRef tr) { (void)vr; (void)tr; return 0; }
rrbool IggyIsValueRefSameObjectAsValuePath(IggyValueRef vr, IggyValuePath *p, IggyName sn, char const *su) { (void)vr; (void)p; (void)sn; (void)su; return 0; }
void IggySetValueRefLimit(Iggy *f, S32 max) { (void)f; (void)max; }
S32 IggyDebugGetNumValueRef(Iggy *f) { (void)f; return 0; }
IggyValueRef IggyValueRefCreateArray(Iggy *f, S32 num_slots) { (void)f; (void)num_slots; return nullptr; }
IggyValueRef IggyValueRefCreateEmptyObject(Iggy *f) { (void)f; return nullptr; }
IggyValueRef IggyValueRefFromTempRef(Iggy *f, IggyTempRef tr, IggyValueRefType rt) { (void)f; (void)tr; (void)rt; return nullptr; }

IggyValuePath * IggyPlayerRootPath(Iggy *f)
{
    if (!f) return nullptr;
    return &f->root_path;
}

IggyValuePath * IggyPlayerCallbackResultPath(Iggy *f)
{
    if (!f) return nullptr;
    return &f->callback_result;
}

rrbool IggyValuePathMakeNameRef(IggyValuePath *result, IggyValuePath *parent, char const *text_utf8)
{
    (void)text_utf8;
    if (result)
    {
        memset(result, 0, sizeof(*result));
        if (parent) result->f = parent->f;
        result->parent = parent;
    }
    return 1;
}

void IggyValuePathFromRef(IggyValuePath *result, Iggy *iggy, IggyValueRef ref)
{
    if (result)
    {
        memset(result, 0, sizeof(*result));
        result->f = iggy;
        result->ref = ref;
    }
}

void IggyValuePathMakeNameRefFast(IggyValuePath *result, IggyValuePath *parent, IggyName name)
{
    if (result)
    {
        memset(result, 0, sizeof(*result));
        if (parent) result->f = parent->f;
        result->parent = parent;
        result->name = name;
    }
}

void IggyValuePathMakeArrayRef(IggyValuePath *result, IggyValuePath *array_path, int array_index)
{
    if (result)
    {
        memset(result, 0, sizeof(*result));
        if (array_path) result->f = array_path->f;
        result->parent = array_path;
        result->index = array_index;
    }
}

void IggyValuePathSetParent(IggyValuePath *result, IggyValuePath *new_parent)
{
    if (result) result->parent = new_parent;
}

void IggyValuePathSetArrayIndex(IggyValuePath *result, int new_index)
{
    if (result) result->index = new_index;
}

void IggyValuePathSetName(IggyValuePath *result, IggyName name)
{
    if (result) result->name = name;
}

// Value getters -- all return "undefined" / zero
IggyResult IggyValueGetTypeRS(IggyValuePath *var, IggyName sn, char const *su, IggyDatatype *result)
{ (void)var; (void)sn; (void)su; if (result) *result = IGGY_DATATYPE_undefined; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetF64RS(IggyValuePath *var, IggyName sn, char const *su, F64 *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0.0; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetF32RS(IggyValuePath *var, IggyName sn, char const *su, F32 *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0.0f; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetS32RS(IggyValuePath *var, IggyName sn, char const *su, S32 *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetU32RS(IggyValuePath *var, IggyName sn, char const *su, U32 *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetStringUTF8RS(IggyValuePath *var, IggyName sn, char const *su, S32 max_len, char *utf8_result, S32 *result_len)
{
    (void)var; (void)sn; (void)su;
    if (utf8_result && max_len > 0) utf8_result[0] = '\0';
    if (result_len) *result_len = 0;
    return IGGY_RESULT_SUCCESS;
}

IggyResult IggyValueGetStringUTF16RS(IggyValuePath *var, IggyName sn, char const *su, S32 max_len, IggyUTF16 *utf16_result, S32 *result_len)
{
    (void)var; (void)sn; (void)su;
    if (utf16_result && max_len > 0) utf16_result[0] = 0;
    if (result_len) *result_len = 0;
    return IGGY_RESULT_SUCCESS;
}

IggyResult IggyValueGetBooleanRS(IggyValuePath *var, IggyName sn, char const *su, rrbool *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0; return IGGY_RESULT_SUCCESS; }

IggyResult IggyValueGetArrayLengthRS(IggyValuePath *var, IggyName sn, char const *su, S32 *result)
{ (void)var; (void)sn; (void)su; if (result) *result = 0; return IGGY_RESULT_SUCCESS; }

// Value setters -- all succeed silently
rrbool IggyValueSetF64RS(IggyValuePath *var, IggyName sn, char const *su, F64 v)
{ (void)var; (void)sn; (void)su; (void)v; return 1; }

rrbool IggyValueSetF32RS(IggyValuePath *var, IggyName sn, char const *su, F32 v)
{ (void)var; (void)sn; (void)su; (void)v; return 1; }

rrbool IggyValueSetS32RS(IggyValuePath *var, IggyName sn, char const *su, S32 v)
{ (void)var; (void)sn; (void)su; (void)v; return 1; }

rrbool IggyValueSetU32RS(IggyValuePath *var, IggyName sn, char const *su, U32 v)
{ (void)var; (void)sn; (void)su; (void)v; return 1; }

rrbool IggyValueSetStringUTF8RS(IggyValuePath *var, IggyName sn, char const *su, char const *str, S32 len)
{ (void)var; (void)sn; (void)su; (void)str; (void)len; return 1; }

rrbool IggyValueSetStringUTF16RS(IggyValuePath *var, IggyName sn, char const *su, IggyUTF16 const *str, S32 len)
{ (void)var; (void)sn; (void)su; (void)str; (void)len; return 1; }

rrbool IggyValueSetBooleanRS(IggyValuePath *var, IggyName sn, char const *su, rrbool v)
{ (void)var; (void)sn; (void)su; (void)v; return 1; }

rrbool IggyValueSetValueRefRS(IggyValuePath *var, IggyName sn, char const *su, IggyValueRef vr)
{ (void)var; (void)sn; (void)su; (void)vr; return 1; }

rrbool IggyValueSetUserDataRS(IggyValuePath *result, void const *userdata)
{ (void)result; (void)userdata; return 1; }

IggyResult IggyValueGetUserDataRS(IggyValuePath *result, void **userdata)
{ (void)result; if (userdata) *userdata = nullptr; return IGGY_RESULT_SUCCESS; }

// ========================================================================
// Input event stubs
// ========================================================================

void IggyMakeEventNone(IggyEvent *event)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_None; } }

void IggyMakeEventResize(IggyEvent *event)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_Resize; } }

void IggyMakeEventActivate(IggyEvent *event, IggyActivestate event_type)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = (S32)event_type; } }

void IggyMakeEventMouseLeave(IggyEvent *event)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_MouseLeave; } }

void IggyMakeEventMouseMove(IggyEvent *event, S32 x, S32 y)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_MouseMove; event->x = x; event->y = y; } }

void IggyMakeEventMouseButton(IggyEvent *event, IggyMousebutton event_type)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = (S32)event_type; } }

void IggyMakeEventMouseWheel(IggyEvent *event, S16 mousewheel_delta)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_MouseWheel; event->keycode = mousewheel_delta; } }

void IggyMakeEventKey(IggyEvent *event, IggyKeyevent event_type, IggyKeycode keycode, IggyKeyloc keyloc)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = (S32)event_type; event->keycode = keycode; event->keyloc = keyloc; } }

void IggyMakeEventChar(IggyEvent *event, S32 charcode)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_Char; event->keycode = charcode; } }

void IggyMakeEventFocusLost(IggyEvent *event)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_FocusLost; } }

void IggyMakeEventFocusGained(IggyEvent *event, S32 focus_direction)
{ if (event) { memset(event, 0, sizeof(*event)); event->type = IGGY_EVENTTYPE_Activate; event->keycode = focus_direction; } }

rrbool IggyPlayerDispatchEventRS(Iggy *player, IggyEvent *event, IggyEventResult *result)
{
    (void)player; (void)event;
    if (result) memset(result, 0, sizeof(*result));
    return 1;
}

void IggyPlayerSetShiftState(Iggy *f, rrbool shift, rrbool control, rrbool alt, rrbool command)
{ (void)f; (void)shift; (void)control; (void)alt; (void)command; }

void IggySetDoubleClickTime(S32 time_in_ms)
{ IGGY_STUB_LOG("IggySetDoubleClickTime"); (void)time_in_ms; }

void IggySetTextCursorFlash(U32 cycle_time_in_ms, U32 visible_time_in_ms)
{ IGGY_STUB_LOG("IggySetTextCursorFlash"); (void)cycle_time_in_ms; (void)visible_time_in_ms; }

rrbool IggyPlayerHasFocusedEditableTextfield(Iggy *f)
{ (void)f; return 0; }

rrbool IggyPlayerPasteUTF16(Iggy *f, U16 *string, S32 stringlen)
{ (void)f; (void)string; (void)stringlen; return 0; }

rrbool IggyPlayerPasteUTF8(Iggy *f, char *string, S32 stringlen)
{ (void)f; (void)string; (void)stringlen; return 0; }

rrbool IggyPlayerCut(Iggy *f)
{ (void)f; return 0; }

S32 IggyPlayerCopyUTF16(Iggy *f, U16 *buffer, S32 bufferlen)
{ (void)f; (void)buffer; (void)bufferlen; return IGGY_PLAYER_COPY_no_focused_textfield; }

S32 IggyPlayerCopyUTF8(Iggy *f, char *buffer, S32 bufferlen)
{ (void)f; (void)buffer; (void)bufferlen; return IGGY_PLAYER_COPY_no_focused_textfield; }

// IME stubs
void IggyPlayerSetIMEFontUTF8(Iggy *f, const char *font_name_utf8, S32 namelen_in_bytes)
{ IGGY_STUB_LOG("IggyPlayerSetIMEFontUTF8"); (void)f; (void)font_name_utf8; (void)namelen_in_bytes; }

void IggyPlayerSetIMEFontUTF16(Iggy *f, const IggyUTF16 *font_name_utf16, S32 namelen_in_2byte_words)
{ IGGY_STUB_LOG("IggyPlayerSetIMEFontUTF16"); (void)f; (void)font_name_utf16; (void)namelen_in_2byte_words; }

// ========================================================================
// IggyExpRuntime stubs
// ========================================================================

HIGGYEXP IggyExpCreate(char *ip_address, S32 port, void *storage, S32 storage_size_in_bytes)
{
    IGGY_STUB_LOG("IggyExpCreate");
    (void)ip_address; (void)port; (void)storage; (void)storage_size_in_bytes;
    return nullptr;  // No explorer connection
}

void IggyExpDestroy(HIGGYEXP p)
{
    IGGY_STUB_LOG("IggyExpDestroy");
    (void)p;
}

rrbool IggyExpCheckValidity(HIGGYEXP p)
{
    (void)p;
    return 0;  // Connection never valid in stub
}

// ========================================================================
// IggyPerfmon stubs
// ========================================================================

HIGGYPERFMON IggyPerfmonCreate(iggyperfmon_malloc *perf_malloc, iggyperfmon_free *perf_free, void *callback_handle)
{
    IGGY_STUB_LOG("IggyPerfmonCreate");
    (void)perf_malloc; (void)perf_free; (void)callback_handle;
    return nullptr;
}

void IggyPerfmonTickAndDraw(HIGGYPERFMON p, GDrawFunctions *gdraw_funcs,
                             const IggyPerfmonPad *pad,
                             int ul_x, int ul_y, int lr_x, int lr_y)
{
    (void)p; (void)gdraw_funcs; (void)pad;
    (void)ul_x; (void)ul_y; (void)lr_x; (void)lr_y;
}

void IggyPerfmonDestroy(HIGGYPERFMON p, GDrawFunctions *iggy_draw)
{
    IGGY_STUB_LOG("IggyPerfmonDestroy");
    (void)p; (void)iggy_draw;
}
