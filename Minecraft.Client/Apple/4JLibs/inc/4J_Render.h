// 4J_Render.h - Apple/Metal platform header
// Replaces D3D11 types with Metal-compatible void* pointers.
// API-compatible with the Windows/Durango/Orbis versions of C4JRender.

#pragma once

#include "../../AppleTypes.h"

class ImageFileBuffer
{
public:
    enum EImageType
    {
        e_typePNG,
        e_typeJPG
    };

    EImageType m_type;
    void*   m_pBuffer;
    int     m_bufferSize;

    int GetType()               { return m_type; }
    void *GetBufferPointer()    { return m_pBuffer; }
    int GetBufferSize()         { return m_bufferSize; }
    void Release()              { free(m_pBuffer); m_pBuffer = nullptr; }
    bool Allocated()            { return m_pBuffer != nullptr; }
};

// Image info structure (replaces D3DXIMAGE_INFO)
typedef struct
{
    int Width;
    int Height;
} D3DXIMAGE_INFO;

// Social preview image (replaces XSOCIAL_PREVIEWIMAGE)
typedef struct _XSOCIAL_PREVIEWIMAGE {
    BYTE *pBytes;
    DWORD Pitch;
    DWORD Width;
    DWORD Height;
} XSOCIAL_PREVIEWIMAGE, *PXSOCIAL_PREVIEWIMAGE;

// Metal rect type (replaces D3D11_RECT)
typedef RECT MetalRect;

class C4JRender
{
public:
    void Tick();
    void UpdateGamma(unsigned short usGamma);

    // Matrix stack
    void MatrixMode(int type);
    void MatrixSetIdentity();
    void MatrixTranslate(float x, float y, float z);
    void MatrixRotate(float angle, float x, float y, float z);
    void MatrixScale(float x, float y, float z);
    void MatrixPerspective(float fovy, float aspect, float zNear, float zFar);
    void MatrixOrthogonal(float left, float right, float bottom, float top, float zNear, float zFar);
    void MatrixPop();
    void MatrixPush();
    void MatrixMult(float *mat);
    const float *MatrixGet(int type);
    void Set_matrixDirty();

    // Core
    // Metal: pDevice = id<MTLDevice>, pSwapChain = CAMetalLayer*
    void Initialise(void *pDevice, void *pSwapChain);
    void InitialiseContext();
    void StartFrame();
    void DoScreenGrabOnNextPresent();
    void Present();
    void Clear(int flags, void *pRect = nullptr);
    void SetClearColour(const float colourRGBA[4]);
    bool IsWidescreen();
    bool IsHiDef();
    void CaptureThumbnail(ImageFileBuffer *pngOut);
    void CaptureScreen(ImageFileBuffer *jpgOut, XSOCIAL_PREVIEWIMAGE *previewOut);
    void BeginConditionalSurvey(int identifier);
    void EndConditionalSurvey();
    void BeginConditionalRendering(int identifier);
    void EndConditionalRendering();

    // Vertex data handling
    typedef enum
    {
        VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1,        // Position 3 x float, texture 2 x float, colour 4 x byte, normal 4 x byte, padding 1 DWORD = 36 bytes
        VERTEX_TYPE_COMPRESSED,                   // Compressed format
        VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_LIT,    // As above with lighting applied
        VERTEX_TYPE_PF3_TF2_CB4_NB4_XW1_TEXGEN, // As above with tex gen
        VERTEX_TYPE_COUNT
    } eVertexType;

    // Pixel shader types
    typedef enum
    {
        PIXEL_SHADER_TYPE_STANDARD,
        PIXEL_SHADER_TYPE_PROJECTION,
        PIXEL_SHADER_TYPE_FORCELOD,
        PIXEL_SHADER_COUNT
    } ePixelShaderType;

    // Viewport types for split-screen
    typedef enum
    {
        VIEWPORT_TYPE_FULLSCREEN,
        VIEWPORT_TYPE_SPLIT_TOP,
        VIEWPORT_TYPE_SPLIT_BOTTOM,
        VIEWPORT_TYPE_SPLIT_LEFT,
        VIEWPORT_TYPE_SPLIT_RIGHT,
        VIEWPORT_TYPE_QUADRANT_TOP_LEFT,
        VIEWPORT_TYPE_QUADRANT_TOP_RIGHT,
        VIEWPORT_TYPE_QUADRANT_BOTTOM_LEFT,
        VIEWPORT_TYPE_QUADRANT_BOTTOM_RIGHT,
    } eViewportType;

    // Primitive types
    typedef enum
    {
        PRIMITIVE_TYPE_TRIANGLE_LIST,
        PRIMITIVE_TYPE_TRIANGLE_STRIP,
        PRIMITIVE_TYPE_TRIANGLE_FAN,
        PRIMITIVE_TYPE_QUAD_LIST,
        PRIMITIVE_TYPE_LINE_LIST,
        PRIMITIVE_TYPE_LINE_STRIP,
        PRIMITIVE_TYPE_COUNT
    } ePrimitiveType;

    // Draw calls
    // Metal: buffer parameter is id<MTLBuffer> cast to void*
    void DrawVertices(ePrimitiveType PrimitiveType, int count, void *dataIn, eVertexType vType, C4JRender::ePixelShaderType psType);
    void DrawVertexBuffer(ePrimitiveType PrimitiveType, int count, void *buffer, C4JRender::eVertexType vType, C4JRender::ePixelShaderType psType);

    // Command buffers
    void CBuffLockStaticCreations();
    int  CBuffCreate(int count);
    void CBuffDelete(int first, int count);
    void CBuffStart(int index, bool full = false);
    void CBuffClear(int index);
    int  CBuffSize(int index);
    void CBuffEnd();
    bool CBuffCall(int index, bool full = true);
    void CBuffTick();
    void CBuffDeferredModeStart();
    void CBuffDeferredModeEnd();

    // Texture formats
    typedef enum
    {
        TEXTURE_FORMAT_RxGyBzAw,         // Normal 32-bit RGBA texture, 8 bits per component
        MAX_TEXTURE_FORMATS
    } eTextureFormat;

    // Textures
    int TextureCreate();
    void TextureFree(int idx);
    void TextureBind(int idx);
    void TextureBindVertex(int idx);
    void TextureSetTextureLevels(int levels);
    int  TextureGetTextureLevels();
    void TextureData(int width, int height, void *data, int level, eTextureFormat format = TEXTURE_FORMAT_RxGyBzAw);
    void TextureDataUpdate(int xoffset, int yoffset, int width, int height, void *data, int level);
    void TextureSetParam(int param, int value);
    void TextureDynamicUpdateStart();
    void TextureDynamicUpdateEnd();
    HRESULT LoadTextureData(const char *szFilename, D3DXIMAGE_INFO *pSrcInfo, int **ppDataOut);
    HRESULT LoadTextureData(BYTE *pbData, DWORD dwBytes, D3DXIMAGE_INFO *pSrcInfo, int **ppDataOut);
    HRESULT SaveTextureData(const char *szFilename, D3DXIMAGE_INFO *pSrcInfo, int *ppDataOut);
    HRESULT SaveTextureDataToMemory(void *pOutput, int outputCapacity, int *outputLength, int width, int height, int *ppDataIn);
    void TextureGetStats();
    // Metal: returns id<MTLTexture> cast to void*
    void *TextureGetTexture(int idx);

    // State control
    void StateSetColour(float r, float g, float b, float a);
    void StateSetDepthMask(bool enable);
    void StateSetBlendEnable(bool enable);
    void StateSetBlendFunc(int src, int dst);
    void StateSetBlendFactor(unsigned int colour);
    void StateSetAlphaFunc(int func, float param);
    void StateSetDepthFunc(int func);
    void StateSetFaceCull(bool enable);
    void StateSetFaceCullCW(bool enable);
    void StateSetLineWidth(float width);
    void StateSetWriteEnable(bool red, bool green, bool blue, bool alpha);
    void StateSetDepthTestEnable(bool enable);
    void StateSetAlphaTestEnable(bool enable);
    void StateSetDepthSlopeAndBias(float slope, float bias);
    void StateSetFogEnable(bool enable);
    void StateSetFogMode(int mode);
    void StateSetFogNearDistance(float dist);
    void StateSetFogFarDistance(float dist);
    void StateSetFogDensity(float density);
    void StateSetFogColour(float red, float green, float blue);
    void StateSetLightingEnable(bool enable);
    void StateSetVertexTextureUV(float u, float v);
    void StateSetLightColour(int light, float red, float green, float blue);
    void StateSetLightAmbientColour(float red, float green, float blue);
    void StateSetLightDirection(int light, float x, float y, float z);
    void StateSetLightEnable(int light, bool enable);
    void StateSetViewport(eViewportType viewportType);
    void StateSetEnableViewportClipPlanes(bool enable);
    void StateSetTexGenCol(int col, float x, float y, float z, float w, bool eyeSpace);
    void StateSetStencil(int Function, uint8_t stencil_ref, uint8_t stencil_func_mask, uint8_t stencil_write_mask);
    void StateSetForceLOD(int LOD);

    // Event tracking
    void BeginEvent(LPCWSTR eventName);
    void EndEvent();

    // PLM event handling
    void Suspend();
    bool Suspended();
    void Resume();
};


// Matrix mode constants (OpenGL-style, used by the game code)
const int GL_MODELVIEW_MATRIX = 0;
const int GL_PROJECTION_MATRIX = 1;
const int GL_MODELVIEW = 0;
const int GL_PROJECTION = 1;
const int GL_TEXTURE = 2;

// Tex gen coordinate constants
const int GL_S = 0;
const int GL_T = 1;
const int GL_R = 2;
const int GL_Q = 3;

const int GL_TEXTURE_GEN_S = 0;
const int GL_TEXTURE_GEN_T = 1;
const int GL_TEXTURE_GEN_Q = 2;
const int GL_TEXTURE_GEN_R = 3;

const int GL_TEXTURE_GEN_MODE = 0;
const int GL_OBJECT_LINEAR = 0;
const int GL_EYE_LINEAR = 1;
const int GL_OBJECT_PLANE = 0;
const int GL_EYE_PLANE = 1;

// glEnable/glDisable constants (must be unique and non-zero)
const int GL_TEXTURE_2D = 1;
const int GL_BLEND = 2;
const int GL_CULL_FACE = 3;
const int GL_ALPHA_TEST = 4;
const int GL_DEPTH_TEST = 5;
const int GL_FOG = 6;
const int GL_LIGHTING = 7;
const int GL_LIGHT0 = 8;
const int GL_LIGHT1 = 9;

// Clear flags
const int CLEAR_DEPTH_FLAG = 1;
const int CLEAR_COLOUR_FLAG = 2;

const int GL_DEPTH_BUFFER_BIT = CLEAR_DEPTH_FLAG;
const int GL_COLOR_BUFFER_BIT = CLEAR_COLOUR_FLAG;

// Metal blend factor constants (platform-specific values)
// These map to MTLBlendFactor enum values
const int GL_SRC_ALPHA = 4;              // MTLBlendFactorSourceAlpha
const int GL_ONE_MINUS_SRC_ALPHA = 5;    // MTLBlendFactorOneMinusSourceAlpha
const int GL_ONE = 1;                    // MTLBlendFactorOne
const int GL_ZERO = 0;                   // MTLBlendFactorZero
const int GL_DST_ALPHA = 6;              // MTLBlendFactorDestinationAlpha
const int GL_SRC_COLOR = 2;              // MTLBlendFactorSourceColor
const int GL_DST_COLOR = 8;              // MTLBlendFactorDestinationColor
const int GL_ONE_MINUS_DST_COLOR = 9;    // MTLBlendFactorOneMinusDestinationColor
const int GL_ONE_MINUS_SRC_COLOR = 3;    // MTLBlendFactorOneMinusSourceColor
const int GL_CONSTANT_ALPHA = 12;        // MTLBlendFactorBlendAlpha
const int GL_ONE_MINUS_CONSTANT_ALPHA = 13; // MTLBlendFactorOneMinusBlendAlpha

// Comparison function constants (map to MTLCompareFunction)
const int GL_GREATER = 4;               // MTLCompareFunctionGreater
const int GL_EQUAL = 2;                 // MTLCompareFunctionEqual
const int GL_LEQUAL = 3;               // MTLCompareFunctionLessEqual
const int GL_GEQUAL = 5;               // MTLCompareFunctionGreaterEqual
const int GL_ALWAYS = 7;               // MTLCompareFunctionAlways

// Texture parameter constants
const int GL_TEXTURE_MIN_FILTER = 1;
const int GL_TEXTURE_MAG_FILTER = 2;
const int GL_TEXTURE_WRAP_S = 3;
const int GL_TEXTURE_WRAP_T = 4;

// Filter mode constants
const int GL_NEAREST = 0;
const int GL_LINEAR = 1;
const int GL_EXP = 2;
const int GL_NEAREST_MIPMAP_LINEAR = 0;

// Wrap mode constants
const int GL_CLAMP = 0;
const int GL_REPEAT = 1;

// Fog constants
const int GL_FOG_START = 1;
const int GL_FOG_END = 2;
const int GL_FOG_MODE = 3;
const int GL_FOG_DENSITY = 4;
const int GL_FOG_COLOR = 5;

// Light constants
const int GL_POSITION = 1;
const int GL_AMBIENT = 2;
const int GL_DIFFUSE = 3;
const int GL_SPECULAR = 4;

const int GL_LIGHT_MODEL_AMBIENT = 1;

// Primitive type aliases (OpenGL-style names)
const int GL_LINES = C4JRender::PRIMITIVE_TYPE_LINE_LIST;
const int GL_LINE_STRIP = C4JRender::PRIMITIVE_TYPE_LINE_STRIP;
const int GL_QUADS = C4JRender::PRIMITIVE_TYPE_QUAD_LIST;
const int GL_TRIANGLE_FAN = C4JRender::PRIMITIVE_TYPE_TRIANGLE_FAN;
const int GL_TRIANGLE_STRIP = C4JRender::PRIMITIVE_TYPE_TRIANGLE_STRIP;

// Singleton instance
extern C4JRender RenderManager;
