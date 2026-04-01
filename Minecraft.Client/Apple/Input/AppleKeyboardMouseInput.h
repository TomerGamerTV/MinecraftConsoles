// AppleKeyboardMouseInput.h - Keyboard and mouse input for Apple platforms
// macOS: uses NSEvent monitoring
// iOS:   uses GCKeyboard / GCMouse (iOS 14+)
// Provides the same API as the Windows KeyboardMouseInput class with
// Windows VK-compatible key codes.

#pragma once

#include "../AppleTypes.h"
#include <cstdint>

// ---------------------------------------------------------------------------
// Virtual-key codes matching the Windows VK_* values so that the rest of the
// engine can use the same constants on every platform.
// ---------------------------------------------------------------------------
#ifndef VK_BACK
#define VK_BACK         0x08
#define VK_TAB          0x09
#define VK_RETURN       0x0D
#define VK_SHIFT        0x10
#define VK_CONTROL      0x11
#define VK_MENU         0x12    // Alt
#define VK_PAUSE        0x13
#define VK_CAPITAL      0x14
#define VK_ESCAPE       0x1B
#define VK_SPACE        0x20
#define VK_PRIOR        0x21    // Page Up
#define VK_NEXT         0x22    // Page Down
#define VK_END          0x23
#define VK_HOME         0x24
#define VK_LEFT         0x25
#define VK_UP           0x26
#define VK_RIGHT        0x27
#define VK_DOWN         0x28
#define VK_INSERT       0x2D
#define VK_DELETE       0x2E
// 0-9 are the same as ASCII ('0' = 0x30 .. '9' = 0x39)
// A-Z are the same as ASCII ('A' = 0x41 .. 'Z' = 0x5A)
#define VK_LWIN         0x5B
#define VK_RWIN         0x5C
#define VK_NUMPAD0      0x60
#define VK_NUMPAD1      0x61
#define VK_NUMPAD2      0x62
#define VK_NUMPAD3      0x63
#define VK_NUMPAD4      0x64
#define VK_NUMPAD5      0x65
#define VK_NUMPAD6      0x66
#define VK_NUMPAD7      0x67
#define VK_NUMPAD8      0x68
#define VK_NUMPAD9      0x69
#define VK_MULTIPLY     0x6A
#define VK_ADD          0x6B
#define VK_SUBTRACT     0x6D
#define VK_DECIMAL      0x6E
#define VK_DIVIDE       0x6F
#define VK_F1           0x70
#define VK_F2           0x71
#define VK_F3           0x72
#define VK_F4           0x73
#define VK_F5           0x74
#define VK_F6           0x75
#define VK_F7           0x76
#define VK_F8           0x77
#define VK_F9           0x78
#define VK_F10          0x79
#define VK_F11          0x7A
#define VK_F12          0x7B
#define VK_NUMLOCK      0x90
#define VK_SCROLL       0x91
#define VK_LSHIFT       0xA0
#define VK_RSHIFT       0xA1
#define VK_LCONTROL     0xA2
#define VK_RCONTROL     0xA3
#define VK_LMENU        0xA4
#define VK_RMENU        0xA5
#define VK_OEM_1        0xBA    // ;:
#define VK_OEM_PLUS     0xBB    // =+
#define VK_OEM_COMMA    0xBC    // ,<
#define VK_OEM_MINUS    0xBD    // -_
#define VK_OEM_PERIOD   0xBE    // .>
#define VK_OEM_2        0xBF    // /?
#define VK_OEM_3        0xC0    // `~
#define VK_OEM_4        0xDB    // [{
#define VK_OEM_5        0xDC    // backslash
#define VK_OEM_6        0xDD    // ]}
#define VK_OEM_7        0xDE    // '"
#endif // VK_BACK

// ---------------------------------------------------------------------------
// Mouse wheel normalisation (Windows uses 120 per notch)
// ---------------------------------------------------------------------------
#ifndef WHEEL_DELTA
#define WHEEL_DELTA 120
#endif

// ---------------------------------------------------------------------------
// KeyboardMouseInput class
// ---------------------------------------------------------------------------
class KeyboardMouseInput
{
public:
    static const int MAX_KEYS = 256;

    static const int MOUSE_LEFT   = 0;
    static const int MOUSE_RIGHT  = 1;
    static const int MOUSE_MIDDLE = 2;
    static const int MAX_MOUSE_BUTTONS = 3;

    // Default key bindings (same as Windows version)
    static const int KEY_FORWARD        = 'W';
    static const int KEY_BACKWARD       = 'S';
    static const int KEY_LEFT           = 'A';
    static const int KEY_RIGHT          = 'D';
    static const int KEY_JUMP           = VK_SPACE;
    static const int KEY_SNEAK          = VK_LSHIFT;
    static const int KEY_SPRINT         = VK_CONTROL;
    static const int KEY_INVENTORY      = 'E';
    static const int KEY_DROP           = 'Q';
    static const int KEY_CRAFTING       = 'C';
    static const int KEY_CRAFTING_ALT   = 'R';
    static const int KEY_CHAT           = 'T';
    static const int KEY_CONFIRM        = VK_RETURN;
    static const int KEY_CANCEL         = VK_ESCAPE;
    static const int KEY_PAUSE          = VK_ESCAPE;
    static const int KEY_TOGGLE_HUD     = VK_F1;
    static const int KEY_DEBUG_INFO     = VK_F3;
    static const int KEY_DEBUG_MENU     = VK_F4;
    static const int KEY_THIRD_PERSON   = VK_F5;
    static const int KEY_DEBUG_CONSOLE  = VK_F6;
    static const int KEY_HOST_SETTINGS  = VK_TAB;
    static const int KEY_FULLSCREEN     = VK_F11;
    static const int KEY_SCREENSHOT     = VK_F2;

    void Init();
    void Tick();
    void ClearAllState();

    // Event callbacks (called from platform layer)
    void OnKeyDown(int vkCode);
    void OnKeyUp(int vkCode);
    void OnMouseButtonDown(int button);
    void OnMouseButtonUp(int button);
    void OnMouseMove(int x, int y);
    void OnMouseWheel(int delta);
    void OnRawMouseDelta(int dx, int dy);

    // Query key state
    bool IsKeyDown(int vkCode) const;
    bool IsKeyPressed(int vkCode) const;
    bool IsKeyReleased(int vkCode) const;
    int  GetPressedKey() const;

    // Query mouse button state
    bool IsMouseButtonDown(int button) const;
    bool IsMouseButtonPressed(int button) const;
    bool IsMouseButtonReleased(int button) const;

    int  GetMouseX() const { return m_mouseX; }
    int  GetMouseY() const { return m_mouseY; }

    int  GetMouseDeltaX() const { return m_mouseDeltaX; }
    int  GetMouseDeltaY() const { return m_mouseDeltaY; }

    int  GetMouseWheel();
    int  PeekMouseWheel() const { return m_mouseWheelAccum; }
    void ConsumeMouseWheel() { if (m_mouseWheelAccum != 0) m_mouseWheelConsumed = true; m_mouseWheelAccum = 0; }
    bool WasMouseWheelConsumed() const { return m_mouseWheelConsumed; }

    // Per-frame delta consumption for low-latency mouse look
    void ConsumeMouseDelta(float &dx, float &dy);

    void SetMouseGrabbed(bool grabbed);
    bool IsMouseGrabbed() const { return m_mouseGrabbed; }

    void SetCursorHiddenForUI(bool hidden);
    bool IsCursorHiddenForUI() const { return m_cursorHiddenForUI; }

    void SetWindowFocused(bool focused);
    bool IsWindowFocused() const { return m_windowFocused; }

    bool HasAnyInput() const { return m_hasInput; }

    void SetKBMActive(bool active) { m_kbmActive = active; }
    bool IsKBMActive() const { return m_kbmActive; }

    void SetScreenCursorHidden(bool hidden) { m_screenWantsCursorHidden = hidden; }
    bool IsScreenCursorHidden() const { return m_screenWantsCursorHidden; }

    // Text input: buffer characters typed while the native keyboard scene is open
    void OnChar(wchar_t c);
    bool ConsumeChar(wchar_t &outChar);
    void ClearCharBuffer();

    // Movement / look helpers
    float GetMoveX() const;
    float GetMoveY() const;
    float GetLookX(float sensitivity) const;
    float GetLookY(float sensitivity) const;

private:
    bool m_keyDown[MAX_KEYS];
    bool m_keyDownPrev[MAX_KEYS];

    bool m_keyPressedAccum[MAX_KEYS];
    bool m_keyReleasedAccum[MAX_KEYS];
    bool m_keyPressed[MAX_KEYS];
    bool m_keyReleased[MAX_KEYS];

    bool m_mouseButtonDown[MAX_MOUSE_BUTTONS];
    bool m_mouseButtonDownPrev[MAX_MOUSE_BUTTONS];

    bool m_mouseBtnPressedAccum[MAX_MOUSE_BUTTONS];
    bool m_mouseBtnReleasedAccum[MAX_MOUSE_BUTTONS];
    bool m_mouseBtnPressed[MAX_MOUSE_BUTTONS];
    bool m_mouseBtnReleased[MAX_MOUSE_BUTTONS];

    int m_mouseX;
    int m_mouseY;

    int m_mouseDeltaX;
    int m_mouseDeltaY;
    int m_mouseDeltaAccumX;
    int m_mouseDeltaAccumY;

    int  m_mouseWheelAccum;
    bool m_mouseWheelConsumed;

    bool m_mouseGrabbed;
    bool m_cursorHiddenForUI;
    bool m_windowFocused;
    bool m_hasInput;
    bool m_kbmActive;
    bool m_screenWantsCursorHidden;

    static const int CHAR_BUFFER_SIZE = 32;
    wchar_t m_charBuffer[CHAR_BUFFER_SIZE];
    int m_charBufferHead;
    int m_charBufferTail;
};

extern KeyboardMouseInput g_KBMInput;
