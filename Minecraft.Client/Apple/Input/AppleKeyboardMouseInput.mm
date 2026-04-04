// AppleKeyboardMouseInput.mm - Keyboard and mouse input for Apple platforms
// macOS: installs NSEvent local monitors for key and mouse events.
// iOS:   uses GCKeyboard / GCMouse when available (iOS 14+).
// Compiled as Objective-C++ (.mm).

#include "stdafx.h"
#define Component CarbonComponent_Renamed
#import <Foundation/Foundation.h>
#undef Component
#include "AppleKeyboardMouseInput.h"
#include <cstring>
#include <cmath>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <GameController/GameController.h>
#endif

// ---------------------------------------------------------------------------
// Singleton instance
// ---------------------------------------------------------------------------
KeyboardMouseInput g_KBMInput;

// ---------------------------------------------------------------------------
// macOS keycode to VK translation table
// Apple keycodes (kVK_*) mapped to Windows VK_* equivalents.
// ---------------------------------------------------------------------------
#if TARGET_OS_OSX
static int MacKeyToVK(unsigned short keyCode)
{
    // macOS virtual keycodes -> Windows VK codes
    switch (keyCode)
    {
        case 0x00: return 'A';
        case 0x01: return 'S';
        case 0x02: return 'D';
        case 0x03: return 'F';
        case 0x04: return 'H';
        case 0x05: return 'G';
        case 0x06: return 'Z';
        case 0x07: return 'X';
        case 0x08: return 'C';
        case 0x09: return 'V';
        case 0x0B: return 'B';
        case 0x0C: return 'Q';
        case 0x0D: return 'W';
        case 0x0E: return 'E';
        case 0x0F: return 'R';
        case 0x10: return 'Y';
        case 0x11: return 'T';
        case 0x12: return '1';
        case 0x13: return '2';
        case 0x14: return '3';
        case 0x15: return '4';
        case 0x16: return '6';
        case 0x17: return '5';
        case 0x18: return VK_OEM_PLUS;     // =+
        case 0x19: return '9';
        case 0x1A: return '7';
        case 0x1B: return VK_OEM_MINUS;    // -_
        case 0x1C: return '8';
        case 0x1D: return '0';
        case 0x1E: return VK_OEM_6;        // ]}
        case 0x1F: return 'O';
        case 0x20: return 'U';
        case 0x21: return VK_OEM_4;        // [{
        case 0x22: return 'I';
        case 0x23: return 'P';
        case 0x24: return VK_RETURN;
        case 0x25: return 'L';
        case 0x26: return 'J';
        case 0x27: return VK_OEM_7;        // '"
        case 0x28: return 'K';
        case 0x29: return VK_OEM_1;        // ;:
        case 0x2A: return VK_OEM_5;        // backslash
        case 0x2B: return VK_OEM_COMMA;    // ,<
        case 0x2C: return VK_OEM_2;        // /?
        case 0x2D: return 'N';
        case 0x2E: return 'M';
        case 0x2F: return VK_OEM_PERIOD;   // .>
        case 0x30: return VK_TAB;
        case 0x31: return VK_SPACE;
        case 0x32: return VK_OEM_3;        // `~
        case 0x33: return VK_BACK;
        case 0x35: return VK_ESCAPE;

        // Modifier keys
        case 0x36: return VK_RWIN;         // Right Command
        case 0x37: return VK_LWIN;         // Left Command
        case 0x38: return VK_LSHIFT;
        case 0x39: return VK_CAPITAL;       // Caps Lock
        case 0x3A: return VK_LMENU;        // Left Option/Alt
        case 0x3B: return VK_LCONTROL;
        case 0x3C: return VK_RSHIFT;
        case 0x3D: return VK_RMENU;        // Right Option/Alt
        case 0x3E: return VK_RCONTROL;

        // Function keys
        case 0x60: return VK_F5;
        case 0x61: return VK_F6;
        case 0x62: return VK_F7;
        case 0x63: return VK_F3;
        case 0x64: return VK_F8;
        case 0x65: return VK_F9;
        case 0x67: return VK_F11;
        case 0x69: return VK_F13 + 0;  // F13 not used, just return raw
        case 0x6D: return VK_F10;
        case 0x6F: return VK_F12;
        case 0x72: return VK_INSERT;    // Help/Insert
        case 0x73: return VK_HOME;
        case 0x74: return VK_PRIOR;     // Page Up
        case 0x75: return VK_DELETE;     // Forward Delete
        case 0x76: return VK_F4;
        case 0x77: return VK_END;
        case 0x78: return VK_F2;
        case 0x79: return VK_NEXT;      // Page Down
        case 0x7A: return VK_F1;
        case 0x7B: return VK_LEFT;
        case 0x7C: return VK_RIGHT;
        case 0x7D: return VK_DOWN;
        case 0x7E: return VK_UP;

        // Numpad
        case 0x41: return VK_DECIMAL;
        case 0x43: return VK_MULTIPLY;
        case 0x45: return VK_ADD;
        case 0x47: return VK_NUMLOCK;
        case 0x4B: return VK_DIVIDE;
        case 0x4C: return VK_RETURN;    // numpad enter
        case 0x4E: return VK_SUBTRACT;
        case 0x52: return VK_NUMPAD0;
        case 0x53: return VK_NUMPAD1;
        case 0x54: return VK_NUMPAD2;
        case 0x55: return VK_NUMPAD3;
        case 0x56: return VK_NUMPAD4;
        case 0x57: return VK_NUMPAD5;
        case 0x58: return VK_NUMPAD6;
        case 0x59: return VK_NUMPAD7;
        case 0x5B: return VK_NUMPAD8;
        case 0x5C: return VK_NUMPAD9;

        default: return 0;
    }
}

// NSEvent monitor handles (stored so we can remove them later)
static id s_keyDownMonitor   = nil;
static id s_keyUpMonitor     = nil;
static id s_flagsMonitor     = nil;
static id s_mouseMovedMonitor = nil;
static id s_scrollMonitor    = nil;
static id s_mouseDownMonitor = nil;
static id s_mouseUpMonitor   = nil;
static id s_rightDownMonitor = nil;
static id s_rightUpMonitor   = nil;
static id s_otherDownMonitor = nil;
static id s_otherUpMonitor   = nil;

// Track modifier key states for detecting transitions
static NSEventModifierFlags s_prevModifierFlags = 0;

// Helper: handle modifier flag transitions
static void HandleModifierChange(NSEventModifierFlags newFlags)
{
    // Left Shift (bit 1 of deviceIndependentModifierFlags is not granular enough,
    // so we check specific flag bits if available)
    auto check = [&](NSEventModifierFlags flag, int vk) {
        bool wasDown = (s_prevModifierFlags & flag) != 0;
        bool isDown  = (newFlags & flag) != 0;
        if (isDown && !wasDown) g_KBMInput.OnKeyDown(vk);
        if (!isDown && wasDown) g_KBMInput.OnKeyUp(vk);
    };

    check(NSEventModifierFlagShift,   VK_LSHIFT);
    check(NSEventModifierFlagControl, VK_LCONTROL);
    check(NSEventModifierFlagOption,  VK_LMENU);
    check(NSEventModifierFlagCommand, VK_LWIN);
    check(NSEventModifierFlagCapsLock, VK_CAPITAL);

    s_prevModifierFlags = newFlags;
}

#endif // TARGET_OS_OSX

// ---------------------------------------------------------------------------
// Helper: modifier key aggregation (same logic as Windows version)
// ---------------------------------------------------------------------------
static bool IsModifierKeyDown(const bool *keyState, int vkCode)
{
    switch (vkCode)
    {
        case VK_SHIFT:   return keyState[VK_LSHIFT]   || keyState[VK_RSHIFT];
        case VK_CONTROL: return keyState[VK_LCONTROL] || keyState[VK_RCONTROL];
        case VK_MENU:    return keyState[VK_LMENU]    || keyState[VK_RMENU];
        default:         return false;
    }
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
void KeyboardMouseInput::Init()
{
    memset(m_keyDown, 0, sizeof(m_keyDown));
    memset(m_keyDownPrev, 0, sizeof(m_keyDownPrev));
    memset(m_keyPressedAccum, 0, sizeof(m_keyPressedAccum));
    memset(m_keyReleasedAccum, 0, sizeof(m_keyReleasedAccum));
    memset(m_keyPressed, 0, sizeof(m_keyPressed));
    memset(m_keyReleased, 0, sizeof(m_keyReleased));
    memset(m_mouseButtonDown, 0, sizeof(m_mouseButtonDown));
    memset(m_mouseButtonDownPrev, 0, sizeof(m_mouseButtonDownPrev));
    memset(m_mouseBtnPressedAccum, 0, sizeof(m_mouseBtnPressedAccum));
    memset(m_mouseBtnReleasedAccum, 0, sizeof(m_mouseBtnReleasedAccum));
    memset(m_mouseBtnPressed, 0, sizeof(m_mouseBtnPressed));
    memset(m_mouseBtnReleased, 0, sizeof(m_mouseBtnReleased));
    m_mouseX = 0;
    m_mouseY = 0;
    m_mouseDeltaX = 0;
    m_mouseDeltaY = 0;
    m_mouseDeltaAccumX = 0;
    m_mouseDeltaAccumY = 0;
    m_mouseWheelAccum = 0;
    m_mouseWheelConsumed = false;
    m_mouseGrabbed = false;
    m_cursorHiddenForUI = false;
    m_windowFocused = true;
    m_hasInput = false;
    m_kbmActive = true;
    m_screenWantsCursorHidden = false;
    m_charBufferHead = 0;
    m_charBufferTail = 0;

#if TARGET_OS_OSX
    // Install local event monitors for keyboard and mouse events
    NSEventMask keyMask = NSEventMaskKeyDown;
    s_keyDownMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:keyMask
                                                            handler:^NSEvent *(NSEvent *event)
    {
        int vk = MacKeyToVK([event keyCode]);
        if (vk > 0 && vk < MAX_KEYS)
            g_KBMInput.OnKeyDown(vk);

        // Also feed characters into the char buffer
        NSString *chars = [event characters];
        if (chars.length > 0)
        {
            unichar ch = [chars characterAtIndex:0];
            if (ch >= 32) // skip control characters except printable
                g_KBMInput.OnChar((wchar_t)ch);
        }
        return event;
    }];

    s_keyUpMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyUp
                                                          handler:^NSEvent *(NSEvent *event)
    {
        int vk = MacKeyToVK([event keyCode]);
        if (vk > 0 && vk < MAX_KEYS)
            g_KBMInput.OnKeyUp(vk);
        return event;
    }];

    s_flagsMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged
                                                          handler:^NSEvent *(NSEvent *event)
    {
        HandleModifierChange([event modifierFlags]);
        return event;
    }];

    // Mouse movement (includes mouseMoved and mouseDragged)
    NSEventMask mouseMask = NSEventMaskMouseMoved | NSEventMaskLeftMouseDragged |
                            NSEventMaskRightMouseDragged | NSEventMaskOtherMouseDragged;
    s_mouseMovedMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mouseMask
                                                               handler:^NSEvent *(NSEvent *event)
    {
        // Screen coordinates for position
        NSPoint loc = [event locationInWindow];
        g_KBMInput.OnMouseMove((int)loc.x, (int)loc.y);

        // Raw delta for mouse look
        g_KBMInput.OnRawMouseDelta((int)[event deltaX], (int)[event deltaY]);
        return event;
    }];

    // Scroll wheel
    s_scrollMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel
                                                           handler:^NSEvent *(NSEvent *event)
    {
        // deltaY is in "lines" on macOS; normalise to WHEEL_DELTA units
        float dy = (float)[event scrollingDeltaY];
        if ([event hasPreciseScrollingDeltas])
            dy /= 10.0f; // trackpad sends much finer values
        int delta = (int)(dy * (float)WHEEL_DELTA);
        if (delta != 0)
            g_KBMInput.OnMouseWheel(delta);
        return event;
    }];

    // Mouse buttons
    s_mouseDownMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown
                                                              handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonDown(MOUSE_LEFT);
        return event;
    }];
    s_mouseUpMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp
                                                            handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonUp(MOUSE_LEFT);
        return event;
    }];
    s_rightDownMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskRightMouseDown
                                                              handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonDown(MOUSE_RIGHT);
        return event;
    }];
    s_rightUpMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskRightMouseUp
                                                            handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonUp(MOUSE_RIGHT);
        return event;
    }];
    s_otherDownMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskOtherMouseDown
                                                              handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonDown(MOUSE_MIDDLE);
        return event;
    }];
    s_otherUpMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskOtherMouseUp
                                                            handler:^NSEvent *(NSEvent *event)
    {
        g_KBMInput.OnMouseButtonUp(MOUSE_MIDDLE);
        return event;
    }];

#elif __IPHONE_OS_VERSION_MIN_REQUIRED >= 140000
    // iOS 14+: use GCKeyboard / GCMouse
    if (@available(iOS 14.0, *))
    {
        GCKeyboard *keyboard = GCKeyboard.coalescedKeyboard;
        if (keyboard && keyboard.keyboardInput)
        {
            keyboard.keyboardInput.keyChangedHandler =
                ^(GCKeyboardInput *input, GCControllerButtonInput *key,
                  GCKeyCode keyCode, BOOL pressed)
            {
                // GCKeyCode values map closely to USB HID; convert to VK
                int vk = (int)keyCode; // simplified mapping
                if (vk >= 0 && vk < KeyboardMouseInput::MAX_KEYS)
                {
                    if (pressed)
                        g_KBMInput.OnKeyDown(vk);
                    else
                        g_KBMInput.OnKeyUp(vk);
                }
            };
        }

        GCMouse *mouse = GCMouse.current;
        if (mouse && mouse.mouseInput)
        {
            mouse.mouseInput.mouseMovedHandler =
                ^(GCMouseInput *mouseInput, float deltaX, float deltaY)
            {
                g_KBMInput.OnRawMouseDelta((int)deltaX, (int)deltaY);
            };

            mouse.mouseInput.leftButton.pressedChangedHandler =
                ^(GCControllerButtonInput *button, float value, BOOL pressed)
            {
                if (pressed)
                    g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_LEFT);
                else
                    g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_LEFT);
            };

            mouse.mouseInput.rightButton.pressedChangedHandler =
                ^(GCControllerButtonInput *button, float value, BOOL pressed)
            {
                if (pressed)
                    g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_RIGHT);
                else
                    g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_RIGHT);
            };

            mouse.mouseInput.middleButton.pressedChangedHandler =
                ^(GCControllerButtonInput *button, float value, BOOL pressed)
            {
                if (pressed)
                    g_KBMInput.OnMouseButtonDown(KeyboardMouseInput::MOUSE_MIDDLE);
                else
                    g_KBMInput.OnMouseButtonUp(KeyboardMouseInput::MOUSE_MIDDLE);
            };

            mouse.mouseInput.scroll.yAxis.valueChangedHandler =
                ^(GCControllerAxisInput *axis, float value)
            {
                int delta = (int)(value * (float)WHEEL_DELTA);
                if (delta != 0)
                    g_KBMInput.OnMouseWheel(delta);
            };
        }
    }
#endif
}

// ---------------------------------------------------------------------------
// ClearAllState
// ---------------------------------------------------------------------------
void KeyboardMouseInput::ClearAllState()
{
    memset(m_keyDown, 0, sizeof(m_keyDown));
    memset(m_keyDownPrev, 0, sizeof(m_keyDownPrev));
    memset(m_keyPressedAccum, 0, sizeof(m_keyPressedAccum));
    memset(m_keyReleasedAccum, 0, sizeof(m_keyReleasedAccum));
    memset(m_keyPressed, 0, sizeof(m_keyPressed));
    memset(m_keyReleased, 0, sizeof(m_keyReleased));
    memset(m_mouseButtonDown, 0, sizeof(m_mouseButtonDown));
    memset(m_mouseButtonDownPrev, 0, sizeof(m_mouseButtonDownPrev));
    memset(m_mouseBtnPressedAccum, 0, sizeof(m_mouseBtnPressedAccum));
    memset(m_mouseBtnReleasedAccum, 0, sizeof(m_mouseBtnReleasedAccum));
    memset(m_mouseBtnPressed, 0, sizeof(m_mouseBtnPressed));
    memset(m_mouseBtnReleased, 0, sizeof(m_mouseBtnReleased));
    m_mouseDeltaX = 0;
    m_mouseDeltaY = 0;
    m_mouseDeltaAccumX = 0;
    m_mouseDeltaAccumY = 0;
    m_mouseWheelAccum = 0;
    m_mouseWheelConsumed = false;
}

// ---------------------------------------------------------------------------
// Tick - snapshot accumulators and advance frame state
// ---------------------------------------------------------------------------
void KeyboardMouseInput::Tick()
{
    memcpy(m_keyDownPrev, m_keyDown, sizeof(m_keyDown));
    memcpy(m_mouseButtonDownPrev, m_mouseButtonDown, sizeof(m_mouseButtonDown));

    memcpy(m_keyPressed, m_keyPressedAccum, sizeof(m_keyPressedAccum));
    memcpy(m_keyReleased, m_keyReleasedAccum, sizeof(m_keyReleasedAccum));
    memset(m_keyPressedAccum, 0, sizeof(m_keyPressedAccum));
    memset(m_keyReleasedAccum, 0, sizeof(m_keyReleasedAccum));

    memcpy(m_mouseBtnPressed, m_mouseBtnPressedAccum, sizeof(m_mouseBtnPressedAccum));
    memcpy(m_mouseBtnReleased, m_mouseBtnReleasedAccum, sizeof(m_mouseBtnReleasedAccum));
    memset(m_mouseBtnPressedAccum, 0, sizeof(m_mouseBtnPressedAccum));
    memset(m_mouseBtnReleasedAccum, 0, sizeof(m_mouseBtnReleasedAccum));

    m_mouseDeltaX = m_mouseDeltaAccumX;
    m_mouseDeltaY = m_mouseDeltaAccumY;
    m_mouseDeltaAccumX = 0;
    m_mouseDeltaAccumY = 0;
    m_mouseWheelConsumed = false;

    // Detect any input activity this frame
    m_hasInput = (m_mouseDeltaX != 0 || m_mouseDeltaY != 0 || m_mouseWheelAccum != 0);
    if (!m_hasInput)
    {
        for (int i = 0; i < MAX_KEYS; ++i)
        {
            if (m_keyDown[i]) { m_hasInput = true; break; }
        }
    }
    if (!m_hasInput)
    {
        for (int i = 0; i < MAX_MOUSE_BUTTONS; ++i)
        {
            if (m_mouseButtonDown[i]) { m_hasInput = true; break; }
        }
    }

#if TARGET_OS_OSX
    // On macOS, re-center the cursor when mouse is grabbed
    if ((m_mouseGrabbed || m_cursorHiddenForUI) && m_windowFocused)
    {
        // CGWarpMouseCursorPosition centers the cursor
        NSRect screenFrame = [[NSScreen mainScreen] frame];
        CGPoint center;
        center.x = screenFrame.origin.x + screenFrame.size.width  * 0.5;
        center.y = screenFrame.origin.y + screenFrame.size.height * 0.5;
        CGWarpMouseCursorPosition(center);
        CGAssociateMouseAndMouseCursorPosition(true);
    }
#endif
}

// ---------------------------------------------------------------------------
// Event callbacks
// ---------------------------------------------------------------------------
void KeyboardMouseInput::OnKeyDown(int vkCode)
{
    if (vkCode >= 0 && vkCode < MAX_KEYS)
    {
        if (!m_keyDown[vkCode])
            m_keyPressedAccum[vkCode] = true;
        m_keyDown[vkCode] = true;
    }
}

void KeyboardMouseInput::OnKeyUp(int vkCode)
{
    if (vkCode >= 0 && vkCode < MAX_KEYS)
    {
        if (m_keyDown[vkCode])
            m_keyReleasedAccum[vkCode] = true;
        m_keyDown[vkCode] = false;
    }
}

void KeyboardMouseInput::OnMouseButtonDown(int button)
{
    if (button >= 0 && button < MAX_MOUSE_BUTTONS)
    {
        if (!m_mouseButtonDown[button])
            m_mouseBtnPressedAccum[button] = true;
        m_mouseButtonDown[button] = true;
    }
}

void KeyboardMouseInput::OnMouseButtonUp(int button)
{
    if (button >= 0 && button < MAX_MOUSE_BUTTONS)
    {
        if (m_mouseButtonDown[button])
            m_mouseBtnReleasedAccum[button] = true;
        m_mouseButtonDown[button] = false;
    }
}

void KeyboardMouseInput::OnMouseMove(int x, int y)
{
    m_mouseX = x;
    m_mouseY = y;
}

void KeyboardMouseInput::OnMouseWheel(int delta)
{
    m_mouseWheelAccum += delta / WHEEL_DELTA;
}

void KeyboardMouseInput::OnRawMouseDelta(int dx, int dy)
{
    m_mouseDeltaAccumX += dx;
    m_mouseDeltaAccumY += dy;
}

// ---------------------------------------------------------------------------
// Key state queries
// ---------------------------------------------------------------------------
bool KeyboardMouseInput::IsKeyDown(int vkCode) const
{
    if (vkCode == VK_SHIFT || vkCode == VK_CONTROL || vkCode == VK_MENU)
        return IsModifierKeyDown(m_keyDown, vkCode);
    if (vkCode >= 0 && vkCode < MAX_KEYS)
        return m_keyDown[vkCode];
    return false;
}

bool KeyboardMouseInput::IsKeyPressed(int vkCode) const
{
    if (vkCode == VK_SHIFT || vkCode == VK_CONTROL || vkCode == VK_MENU)
        return IsModifierKeyDown(m_keyPressed, vkCode);
    if (vkCode >= 0 && vkCode < MAX_KEYS)
        return m_keyPressed[vkCode];
    return false;
}

bool KeyboardMouseInput::IsKeyReleased(int vkCode) const
{
    if (vkCode == VK_SHIFT || vkCode == VK_CONTROL || vkCode == VK_MENU)
        return IsModifierKeyDown(m_keyReleased, vkCode);
    if (vkCode >= 0 && vkCode < MAX_KEYS)
        return m_keyReleased[vkCode];
    return false;
}

int KeyboardMouseInput::GetPressedKey() const
{
    for (int i = 0; i < MAX_KEYS; ++i)
        if (m_keyPressed[i]) return i;
    return 0;
}

// ---------------------------------------------------------------------------
// Mouse button queries
// ---------------------------------------------------------------------------
bool KeyboardMouseInput::IsMouseButtonDown(int button) const
{
    if (button >= 0 && button < MAX_MOUSE_BUTTONS)
        return m_mouseButtonDown[button];
    return false;
}

bool KeyboardMouseInput::IsMouseButtonPressed(int button) const
{
    if (button >= 0 && button < MAX_MOUSE_BUTTONS)
        return m_mouseBtnPressed[button];
    return false;
}

bool KeyboardMouseInput::IsMouseButtonReleased(int button) const
{
    if (button >= 0 && button < MAX_MOUSE_BUTTONS)
        return m_mouseBtnReleased[button];
    return false;
}

// ---------------------------------------------------------------------------
// Mouse wheel
// ---------------------------------------------------------------------------
int KeyboardMouseInput::GetMouseWheel()
{
    int val = m_mouseWheelAccum;
    if (val != 0)
        m_mouseWheelConsumed = true;
    m_mouseWheelAccum = 0;
    return val;
}

// ---------------------------------------------------------------------------
// Mouse delta consumption
// ---------------------------------------------------------------------------
void KeyboardMouseInput::ConsumeMouseDelta(float &dx, float &dy)
{
    dx = static_cast<float>(m_mouseDeltaAccumX);
    dy = static_cast<float>(m_mouseDeltaAccumY);
    m_mouseDeltaAccumX = 0;
    m_mouseDeltaAccumY = 0;
}

// ---------------------------------------------------------------------------
// Mouse grab / cursor control
// ---------------------------------------------------------------------------
void KeyboardMouseInput::SetMouseGrabbed(bool grabbed)
{
    if (m_mouseGrabbed == grabbed)
        return;

    m_mouseGrabbed = grabbed;

#if TARGET_OS_OSX
    if (grabbed)
    {
        [NSCursor hide];
        CGAssociateMouseAndMouseCursorPosition(false);
        m_mouseDeltaAccumX = 0;
        m_mouseDeltaAccumY = 0;
    }
    else if (!m_cursorHiddenForUI)
    {
        [NSCursor unhide];
        CGAssociateMouseAndMouseCursorPosition(true);
    }
#endif
}

void KeyboardMouseInput::SetCursorHiddenForUI(bool hidden)
{
    if (m_cursorHiddenForUI == hidden)
        return;

    m_cursorHiddenForUI = hidden;

#if TARGET_OS_OSX
    if (hidden)
    {
        [NSCursor hide];
        CGAssociateMouseAndMouseCursorPosition(false);
        m_mouseDeltaAccumX = 0;
        m_mouseDeltaAccumY = 0;
    }
    else if (!m_mouseGrabbed)
    {
        [NSCursor unhide];
        CGAssociateMouseAndMouseCursorPosition(true);
    }
#endif
}

void KeyboardMouseInput::SetWindowFocused(bool focused)
{
    m_windowFocused = focused;

#if TARGET_OS_OSX
    if (focused)
    {
        if (m_mouseGrabbed || m_cursorHiddenForUI)
        {
            [NSCursor hide];
            CGAssociateMouseAndMouseCursorPosition(false);
        }
        else
        {
            [NSCursor unhide];
            CGAssociateMouseAndMouseCursorPosition(true);
        }
    }
    else
    {
        [NSCursor unhide];
        CGAssociateMouseAndMouseCursorPosition(true);
    }
#endif
}

// ---------------------------------------------------------------------------
// Movement / look helpers
// ---------------------------------------------------------------------------
float KeyboardMouseInput::GetMoveX() const
{
    float x = 0.0f;
    if (m_keyDown[KEY_LEFT])  x += 1.0f;
    if (m_keyDown[KEY_RIGHT]) x -= 1.0f;
    return x;
}

float KeyboardMouseInput::GetMoveY() const
{
    float y = 0.0f;
    if (m_keyDown[KEY_FORWARD])  y += 1.0f;
    if (m_keyDown[KEY_BACKWARD]) y -= 1.0f;
    return y;
}

float KeyboardMouseInput::GetLookX(float sensitivity) const
{
    return static_cast<float>(m_mouseDeltaX) * sensitivity;
}

float KeyboardMouseInput::GetLookY(float sensitivity) const
{
    return static_cast<float>(-m_mouseDeltaY) * sensitivity;
}

// ---------------------------------------------------------------------------
// Text input buffer
// ---------------------------------------------------------------------------
void KeyboardMouseInput::OnChar(wchar_t c)
{
    int next = (m_charBufferHead + 1) % CHAR_BUFFER_SIZE;
    if (next != m_charBufferTail)
    {
        m_charBuffer[m_charBufferHead] = c;
        m_charBufferHead = next;
    }
}

bool KeyboardMouseInput::ConsumeChar(wchar_t &outChar)
{
    if (m_charBufferTail == m_charBufferHead)
        return false;
    outChar = m_charBuffer[m_charBufferTail];
    m_charBufferTail = (m_charBufferTail + 1) % CHAR_BUFFER_SIZE;
    return true;
}

void KeyboardMouseInput::ClearCharBuffer()
{
    m_charBufferHead = 0;
    m_charBufferTail = 0;
}
