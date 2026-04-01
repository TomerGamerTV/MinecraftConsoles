// AppleInput.mm - C_4JInput implementation for Apple platforms
// Uses the GameController framework (GCController, GCExtendedGamepad) to
// support MFi, DualShock 4, DualSense, and Xbox Wireless controllers.
// Compiled as Objective-C++ (.mm).

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <cstring>
#include <cmath>
#include <ctime>

#include "../4JLibs/inc/4J_Input.h"

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
static const int MAX_PADS           = 4;
static const int MAX_ACTIONS        = 256;
static const int MAX_MAPS           = 4;
static const float DEFAULT_DEADZONE = 0.20f;  // normalised 0..1
static const float STICK_ANALOG_DIGITAL_THRESHOLD = 0.5f;
static const unsigned char TRIGGER_DIGITAL_THRESHOLD = 128; // 0..255

// ---------------------------------------------------------------------------
// Per-pad internal state
// ---------------------------------------------------------------------------
struct PadState
{
    // The GCController object (retained via ARC / __strong in the array)
    bool            connected;

    // Raw analog values from the controller (range -1..1 for sticks, 0..1 for triggers)
    float           stickLX;
    float           stickLY;
    float           stickRX;
    float           stickRY;
    float           triggerL;   // 0..1
    float           triggerR;   // 0..1

    // Digital button bitmask (current and previous frame)
    unsigned int    buttons;
    unsigned int    buttonsPrev;

    // Axis / trigger remapping
    unsigned int    axisMap[4];     // indices into {LX, LY, RX, RY}
    unsigned int    triggerMap[2];  // indices into {L, R}

    unsigned char   mapVal;         // current map style
    float           sensitivity;    // joypad sensitivity multiplier
    bool            menuDisplayed;

    // Idle tracking
    double          lastInputTime;
};

// ---------------------------------------------------------------------------
// Module-level state
// ---------------------------------------------------------------------------
static PadState             s_pads[MAX_PADS];
static GCController* __strong s_controllers[MAX_PADS];
static unsigned int         s_joypadMaps[MAX_MAPS][MAX_ACTIONS]; // [map][action] -> button bitmask

// Deadzone (normalised 0..1)
static float                s_deadzone        = DEFAULT_DEADZONE;
static float                s_movementRangeMax = 1.0f;

// Key repeat
static float                s_repeatDelaySecs = 0.4f;
static float                s_repeatRateSecs  = 0.1f;

// Virtual keyboard
static EKeyboardResult      s_keyboardResult  = EKeyboard_Cancelled;
static uint16_t             s_keyboardText[256];

// Notification observers
static id                   s_connectObserver    = nil;
static id                   s_disconnectObserver = nil;

// Singleton
C_4JInput InputManager;

// ---------------------------------------------------------------------------
// Helper: current time in seconds (monotonic)
// ---------------------------------------------------------------------------
static double CurrentTimeSec()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

// ---------------------------------------------------------------------------
// Helper: apply deadzone to a stick axis value
// ---------------------------------------------------------------------------
static float ApplyDeadzone(float value, float deadzone)
{
    if (fabsf(value) < deadzone)
        return 0.0f;

    // Remap the remaining range to 0..1
    float sign = (value > 0.0f) ? 1.0f : -1.0f;
    float adjusted = (fabsf(value) - deadzone) / (1.0f - deadzone);
    if (adjusted > 1.0f) adjusted = 1.0f;
    return sign * adjusted;
}

// ---------------------------------------------------------------------------
// Helper: find an empty slot for a newly connected controller
// ---------------------------------------------------------------------------
static int FindEmptySlot()
{
    for (int i = 0; i < MAX_PADS; ++i)
    {
        if (!s_pads[i].connected)
            return i;
    }
    return -1; // no room
}

// ---------------------------------------------------------------------------
// Helper: find the slot index for a given GCController, or -1
// ---------------------------------------------------------------------------
static int FindControllerSlot(GCController *controller)
{
    for (int i = 0; i < MAX_PADS; ++i)
    {
        if (s_controllers[i] == controller)
            return i;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// Helper: read all inputs from a GCExtendedGamepad into a PadState
// ---------------------------------------------------------------------------
static void ReadExtendedGamepad(GCExtendedGamepad *gp, PadState &pad)
{
    if (!gp) return;

    // Sticks
    pad.stickLX = gp.leftThumbstick.xAxis.value;
    pad.stickLY = gp.leftThumbstick.yAxis.value;
    pad.stickRX = gp.rightThumbstick.xAxis.value;
    pad.stickRY = gp.rightThumbstick.yAxis.value;

    // Triggers (0..1 float)
    pad.triggerL = gp.leftTrigger.value;
    pad.triggerR = gp.rightTrigger.value;

    // Build digital button bitmask
    unsigned int btn = 0;

    if (gp.buttonA.pressed)             btn |= _360_JOY_BUTTON_A;
    if (gp.buttonB.pressed)             btn |= _360_JOY_BUTTON_B;
    if (gp.buttonX.pressed)             btn |= _360_JOY_BUTTON_X;
    if (gp.buttonY.pressed)             btn |= _360_JOY_BUTTON_Y;

    if (gp.leftShoulder.pressed)        btn |= _360_JOY_BUTTON_LB;
    if (gp.rightShoulder.pressed)       btn |= _360_JOY_BUTTON_RB;

    // Menu / Options = Start, buttonOptions = Back (when available)
    if (gp.buttonMenu.pressed)          btn |= _360_JOY_BUTTON_START;
    if (@available(macOS 10.15, iOS 13.0, *))
    {
        if (gp.buttonOptions != nil && gp.buttonOptions.pressed)
            btn |= _360_JOY_BUTTON_BACK;
    }

    // Thumbstick buttons (iOS 12.1+, macOS 10.14.1+)
    if (@available(macOS 10.14.1, iOS 12.1, *))
    {
        if (gp.leftThumbstickButton != nil && gp.leftThumbstickButton.pressed)
            btn |= _360_JOY_BUTTON_LTHUMB;
        if (gp.rightThumbstickButton != nil && gp.rightThumbstickButton.pressed)
            btn |= _360_JOY_BUTTON_RTHUMB;
    }

    // D-Pad
    if (gp.dpad.up.pressed)             btn |= _360_JOY_BUTTON_DPAD_UP;
    if (gp.dpad.down.pressed)           btn |= _360_JOY_BUTTON_DPAD_DOWN;
    if (gp.dpad.left.pressed)           btn |= _360_JOY_BUTTON_DPAD_LEFT;
    if (gp.dpad.right.pressed)          btn |= _360_JOY_BUTTON_DPAD_RIGHT;

    // Fake digital from analog sticks
    float lx = ApplyDeadzone(pad.stickLX, s_deadzone);
    float ly = ApplyDeadzone(pad.stickLY, s_deadzone);
    float rx = ApplyDeadzone(pad.stickRX, s_deadzone);
    float ry = ApplyDeadzone(pad.stickRY, s_deadzone);

    if (lx >  STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_LSTICK_RIGHT;
    if (lx < -STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_LSTICK_LEFT;
    if (ly >  STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_LSTICK_UP;
    if (ly < -STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_LSTICK_DOWN;
    if (rx >  STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_RSTICK_RIGHT;
    if (rx < -STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_RSTICK_LEFT;
    if (ry >  STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_RSTICK_UP;
    if (ry < -STICK_ANALOG_DIGITAL_THRESHOLD) btn |= _360_JOY_BUTTON_RSTICK_DOWN;

    // Digital trigger buttons
    if (pad.triggerL > 0.5f) btn |= _360_JOY_BUTTON_LT;
    if (pad.triggerR > 0.5f) btn |= _360_JOY_BUTTON_RT;

    pad.buttons = btn;

    // Track idle
    if (btn != 0 || fabsf(lx) > 0.01f || fabsf(ly) > 0.01f ||
        fabsf(rx) > 0.01f || fabsf(ry) > 0.01f ||
        pad.triggerL > 0.05f || pad.triggerR > 0.05f)
    {
        pad.lastInputTime = CurrentTimeSec();
    }
}

// ---------------------------------------------------------------------------
// C_4JInput implementation
// ---------------------------------------------------------------------------

void C_4JInput::Initialise(int iInputStateC, unsigned char ucMapC,
                            unsigned char ucActionC, unsigned char ucMenuActionC)
{
    memset(s_pads, 0, sizeof(s_pads));
    memset(s_joypadMaps, 0, sizeof(s_joypadMaps));

    for (int i = 0; i < MAX_PADS; ++i)
    {
        s_controllers[i] = nil;
        s_pads[i].connected = false;
        s_pads[i].sensitivity = 1.0f;
        s_pads[i].menuDisplayed = false;
        s_pads[i].lastInputTime = CurrentTimeSec();

        // Default axis mapping (identity)
        s_pads[i].axisMap[0] = AXIS_MAP_LX;
        s_pads[i].axisMap[1] = AXIS_MAP_LY;
        s_pads[i].axisMap[2] = AXIS_MAP_RX;
        s_pads[i].axisMap[3] = AXIS_MAP_RY;
        s_pads[i].triggerMap[0] = TRIGGER_MAP_0;
        s_pads[i].triggerMap[1] = TRIGGER_MAP_1;
    }

    // Register for controller connect / disconnect notifications
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    s_connectObserver = [center addObserverForName:GCControllerDidConnectNotification
                                            object:nil
                                             queue:[NSOperationQueue mainQueue]
                                        usingBlock:^(NSNotification *note)
    {
        GCController *controller = (GCController *)note.object;
        if (!controller.extendedGamepad) return; // require extended gamepad

        int slot = FindControllerSlot(controller);
        if (slot >= 0) return; // already tracked

        slot = FindEmptySlot();
        if (slot < 0) return; // no room

        s_controllers[slot] = controller;
        s_pads[slot].connected = true;
        s_pads[slot].lastInputTime = CurrentTimeSec();

        NSLog(@"[4JInput] Controller connected in slot %d: %@", slot, controller.vendorName);
    }];

    s_disconnectObserver = [center addObserverForName:GCControllerDidDisconnectNotification
                                               object:nil
                                                queue:[NSOperationQueue mainQueue]
                                           usingBlock:^(NSNotification *note)
    {
        GCController *controller = (GCController *)note.object;
        int slot = FindControllerSlot(controller);
        if (slot < 0) return;

        s_controllers[slot] = nil;
        memset(&s_pads[slot], 0, sizeof(PadState));
        s_pads[slot].sensitivity = 1.0f;

        NSLog(@"[4JInput] Controller disconnected from slot %d", slot);
    }];

    // Pick up any controllers that were already connected at launch
    NSArray<GCController *> *existing = [GCController controllers];
    for (GCController *controller in existing)
    {
        if (!controller.extendedGamepad) continue;
        int slot = FindEmptySlot();
        if (slot < 0) break;

        s_controllers[slot] = controller;
        s_pads[slot].connected = true;
        s_pads[slot].lastInputTime = CurrentTimeSec();
    }

    // Start wireless controller discovery
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
}

void C_4JInput::Tick(void)
{
    for (int i = 0; i < MAX_PADS; ++i)
    {
        PadState &pad = s_pads[i];
        pad.buttonsPrev = pad.buttons;

        if (!pad.connected || s_controllers[i] == nil)
        {
            pad.buttons = 0;
            pad.stickLX = pad.stickLY = 0.0f;
            pad.stickRX = pad.stickRY = 0.0f;
            pad.triggerL = pad.triggerR = 0.0f;
            continue;
        }

        GCExtendedGamepad *gp = s_controllers[i].extendedGamepad;
        ReadExtendedGamepad(gp, pad);
    }
}

void C_4JInput::SetDeadzoneAndMovementRange(unsigned int uiDeadzone,
                                             unsigned int uiMovementRangeMax)
{
    // Input values are in the 0..32767 range like XInput
    s_deadzone = (float)uiDeadzone / 32767.0f;
    s_movementRangeMax = (float)uiMovementRangeMax / 32767.0f;
    if (s_movementRangeMax < 0.01f) s_movementRangeMax = 1.0f;
}

void C_4JInput::SetGameJoypadMaps(unsigned char ucMap, unsigned char ucAction,
                                   unsigned int uiActionVal)
{
    if (ucMap < MAX_MAPS && ucAction < MAX_ACTIONS)
        s_joypadMaps[ucMap][ucAction] = uiActionVal;
}

unsigned int C_4JInput::GetGameJoypadMaps(unsigned char ucMap, unsigned char ucAction)
{
    if (ucMap < MAX_MAPS && ucAction < MAX_ACTIONS)
        return s_joypadMaps[ucMap][ucAction];
    return 0;
}

void C_4JInput::SetJoypadMapVal(int iPad, unsigned char ucMap)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        s_pads[iPad].mapVal = ucMap;
}

unsigned char C_4JInput::GetJoypadMapVal(int iPad)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        return s_pads[iPad].mapVal;
    return 0;
}

void C_4JInput::SetJoypadSensitivity(int iPad, float fSensitivity)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        s_pads[iPad].sensitivity = fSensitivity;
}

// ---------------------------------------------------------------------------
// GetValue: look up the mapped button bitmask for an action and return
//           which bits are active on the current frame.
// ---------------------------------------------------------------------------
unsigned int C_4JInput::GetValue(int iPad, unsigned char ucAction, bool bRepeat)
{
    if (iPad < 0 || iPad >= MAX_PADS) return 0;
    if (!s_pads[iPad].connected) return 0;

    unsigned char map = s_pads[iPad].mapVal;
    if (map >= MAX_MAPS) map = 0;
    if (ucAction >= MAX_ACTIONS) return 0;

    unsigned int mask = s_joypadMaps[map][ucAction];
    return s_pads[iPad].buttons & mask;
}

bool C_4JInput::ButtonPressed(int iPad, unsigned char ucAction)
{
    if (iPad < 0 || iPad >= MAX_PADS) return false;
    if (!s_pads[iPad].connected) return false;

    const PadState &pad = s_pads[iPad];

    if (ucAction == 255)
    {
        // Any button pressed this frame that was not pressed last frame
        unsigned int pressed = pad.buttons & ~pad.buttonsPrev;
        return pressed != 0;
    }

    unsigned char map = pad.mapVal;
    if (map >= MAX_MAPS) map = 0;
    if (ucAction >= MAX_ACTIONS) return false;

    unsigned int mask = s_joypadMaps[map][ucAction];
    unsigned int pressedBits = pad.buttons & ~pad.buttonsPrev;
    return (pressedBits & mask) != 0;
}

bool C_4JInput::ButtonReleased(int iPad, unsigned char ucAction)
{
    if (iPad < 0 || iPad >= MAX_PADS) return false;
    if (!s_pads[iPad].connected) return false;

    const PadState &pad = s_pads[iPad];

    unsigned char map = pad.mapVal;
    if (map >= MAX_MAPS) map = 0;
    if (ucAction >= MAX_ACTIONS) return false;

    unsigned int mask = s_joypadMaps[map][ucAction];
    unsigned int releasedBits = pad.buttonsPrev & ~pad.buttons;
    return (releasedBits & mask) != 0;
}

bool C_4JInput::ButtonDown(int iPad, unsigned char ucAction)
{
    if (iPad < 0 || iPad >= MAX_PADS) return false;
    if (!s_pads[iPad].connected) return false;

    const PadState &pad = s_pads[iPad];

    if (ucAction == 255)
    {
        return pad.buttons != 0;
    }

    unsigned char map = pad.mapVal;
    if (map >= MAX_MAPS) map = 0;
    if (ucAction >= MAX_ACTIONS) return false;

    unsigned int mask = s_joypadMaps[map][ucAction];
    return (pad.buttons & mask) != 0;
}

void C_4JInput::SetJoypadStickAxisMap(int iPad, unsigned int uiFrom, unsigned int uiTo)
{
    if (iPad >= 0 && iPad < MAX_PADS && uiFrom < 4)
        s_pads[iPad].axisMap[uiFrom] = uiTo;
}

void C_4JInput::SetJoypadStickTriggerMap(int iPad, unsigned int uiFrom, unsigned int uiTo)
{
    if (iPad >= 0 && iPad < MAX_PADS && uiFrom < 2)
        s_pads[iPad].triggerMap[uiFrom] = uiTo;
}

void C_4JInput::SetKeyRepeatRate(float fRepeatDelaySecs, float fRepeatRateSecs)
{
    s_repeatDelaySecs = fRepeatDelaySecs;
    s_repeatRateSecs  = fRepeatRateSecs;
}

float C_4JInput::GetIdleSeconds(int iPad)
{
    if (iPad < 0 || iPad >= MAX_PADS) return 999.0f;
    if (!s_pads[iPad].connected) return 999.0f;
    return (float)(CurrentTimeSec() - s_pads[iPad].lastInputTime);
}

bool C_4JInput::IsPadConnected(int iPad)
{
    if (iPad < 0 || iPad >= MAX_PADS) return false;
    return s_pads[iPad].connected;
}

// ---------------------------------------------------------------------------
// Analog stick getters with axis remapping
// ---------------------------------------------------------------------------

// Helper: get raw stick value by axis index
static float GetRawStickValue(const PadState &pad, unsigned int axis)
{
    switch (axis)
    {
        case AXIS_MAP_LX: return pad.stickLX;
        case AXIS_MAP_LY: return pad.stickLY;
        case AXIS_MAP_RX: return pad.stickRX;
        case AXIS_MAP_RY: return pad.stickRY;
        default:          return 0.0f;
    }
}

// Helper: get raw trigger value by trigger index
static float GetRawTriggerValue(const PadState &pad, unsigned int trigger)
{
    switch (trigger)
    {
        case TRIGGER_MAP_0: return pad.triggerL;
        case TRIGGER_MAP_1: return pad.triggerR;
        default:            return 0.0f;
    }
}

float C_4JInput::GetJoypadStick_LX(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0.0f;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0.0f;

    unsigned int mappedAxis = s_pads[iPad].axisMap[AXIS_MAP_LX];
    float raw = GetRawStickValue(s_pads[iPad], mappedAxis);
    return ApplyDeadzone(raw, s_deadzone) * s_pads[iPad].sensitivity;
}

float C_4JInput::GetJoypadStick_LY(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0.0f;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0.0f;

    unsigned int mappedAxis = s_pads[iPad].axisMap[AXIS_MAP_LY];
    float raw = GetRawStickValue(s_pads[iPad], mappedAxis);
    return ApplyDeadzone(raw, s_deadzone) * s_pads[iPad].sensitivity;
}

float C_4JInput::GetJoypadStick_RX(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0.0f;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0.0f;

    unsigned int mappedAxis = s_pads[iPad].axisMap[AXIS_MAP_RX];
    float raw = GetRawStickValue(s_pads[iPad], mappedAxis);
    return ApplyDeadzone(raw, s_deadzone) * s_pads[iPad].sensitivity;
}

float C_4JInput::GetJoypadStick_RY(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0.0f;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0.0f;

    unsigned int mappedAxis = s_pads[iPad].axisMap[AXIS_MAP_RY];
    float raw = GetRawStickValue(s_pads[iPad], mappedAxis);
    return ApplyDeadzone(raw, s_deadzone) * s_pads[iPad].sensitivity;
}

unsigned char C_4JInput::GetJoypadLTrigger(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0;

    unsigned int mappedTrigger = s_pads[iPad].triggerMap[TRIGGER_MAP_0];
    float raw = GetRawTriggerValue(s_pads[iPad], mappedTrigger);
    // Convert 0..1 to 0..255
    int val = (int)(raw * 255.0f);
    if (val < 0) val = 0;
    if (val > 255) val = 255;
    return (unsigned char)val;
}

unsigned char C_4JInput::GetJoypadRTrigger(int iPad, bool bCheckMenuDisplay)
{
    if (iPad < 0 || iPad >= MAX_PADS || !s_pads[iPad].connected) return 0;
    if (bCheckMenuDisplay && s_pads[iPad].menuDisplayed) return 0;

    unsigned int mappedTrigger = s_pads[iPad].triggerMap[TRIGGER_MAP_1];
    float raw = GetRawTriggerValue(s_pads[iPad], mappedTrigger);
    int val = (int)(raw * 255.0f);
    if (val < 0) val = 0;
    if (val > 255) val = 255;
    return (unsigned char)val;
}

void C_4JInput::SetMenuDisplayed(int iPad, bool bVal)
{
    if (iPad >= 0 && iPad < MAX_PADS)
        s_pads[iPad].menuDisplayed = bVal;
}

// ---------------------------------------------------------------------------
// Virtual keyboard - Apple implementation
// On macOS we could use NSAlert with an NSTextField; on iOS we would use
// UIAlertController.  For now this stores the result and calls the callback.
// ---------------------------------------------------------------------------
EKeyboardResult C_4JInput::RequestKeyboard(const wchar_t *pwchTitle,
                                            const wchar_t *pwchText,
                                            unsigned int dwPad,
                                            unsigned int uiMaxChars,
                                            int (*Func)(void *, const bool),
                                            void *lpParam,
                                            C_4JInput::EKeyboardMode eMode)
{
    // Copy default text into the keyboard text buffer
    memset(s_keyboardText, 0, sizeof(s_keyboardText));
    if (pwchText)
    {
        for (unsigned int i = 0; i < uiMaxChars && i < 255 && pwchText[i]; ++i)
            s_keyboardText[i] = (uint16_t)pwchText[i];
    }

#if TARGET_OS_OSX
    // macOS: present a simple NSAlert with a text field on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSAlert *alert = [[NSAlert alloc] init];

            // Convert wchar_t title to NSString
            NSString *titleStr = @"Input";
            if (pwchTitle)
                titleStr = [[NSString alloc] initWithBytes:pwchTitle
                                                    length:wcslen(pwchTitle) * sizeof(wchar_t)
                                                  encoding:NSUTF32LittleEndianStringEncoding];
            [alert setMessageText:titleStr];

            NSTextField *inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
            if (pwchText)
            {
                NSString *defaultStr = [[NSString alloc] initWithBytes:pwchText
                                                                length:wcslen(pwchText) * sizeof(wchar_t)
                                                              encoding:NSUTF32LittleEndianStringEncoding];
                [inputField setStringValue:defaultStr];
            }
            [alert setAccessoryView:inputField];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];

            NSModalResponse response = [alert runModal];
            if (response == NSAlertFirstButtonReturn)
            {
                NSString *result = [inputField stringValue];
                // Convert NSString to uint16_t buffer
                memset(s_keyboardText, 0, sizeof(s_keyboardText));
                NSUInteger len = [result length];
                if (len > uiMaxChars) len = uiMaxChars;
                if (len > 255) len = 255;
                for (NSUInteger idx = 0; idx < len; ++idx)
                    s_keyboardText[idx] = (uint16_t)[result characterAtIndex:idx];

                s_keyboardResult = EKeyboard_ResultAccept;
            }
            else
            {
                s_keyboardResult = EKeyboard_Cancelled;
            }

            if (Func)
                Func(lpParam, (s_keyboardResult == EKeyboard_ResultAccept));
        }
    });
#else
    // iOS / tvOS: for now, auto-accept with the default text
    s_keyboardResult = EKeyboard_ResultAccept;
    if (Func)
        Func(lpParam, true);
#endif

    return EKeyboard_Pending;
}

void C_4JInput::GetText(uint16_t *UTF16String)
{
    if (UTF16String)
        memcpy(UTF16String, s_keyboardText, sizeof(s_keyboardText));
}

// ---------------------------------------------------------------------------
// String verification stubs (no Xbox Live on Apple)
// ---------------------------------------------------------------------------
bool C_4JInput::VerifyStrings(wchar_t ** /*pwStringA*/, int /*iStringC*/,
                               int (* /*Func*/)(void *, STRING_VERIFY_RESPONSE *),
                               void * /*lpParam*/)
{
    return true; // always pass
}

void C_4JInput::CancelQueuedVerifyStrings(int (*)(void *, STRING_VERIFY_RESPONSE *), void *)
{
    // No-op on Apple
}

void C_4JInput::CancelAllVerifyInProgress(void)
{
    // No-op on Apple
}
