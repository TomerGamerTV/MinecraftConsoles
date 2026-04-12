#pragma once

// TouchInput.h — Virtual touch controls for iOS
// Provides a left-side joystick, right-side camera look area, and action buttons.
// Auto-hides when a physical controller is connected.

#import <UIKit/UIKit.h>

// ── Touch control button identifiers ─────────────────────────────────────────
// These map to the same action IDs used by the 4J InputManager.

typedef NS_ENUM(NSInteger, TouchButtonID)
{
    TouchButton_Jump = 0,
    TouchButton_Sneak,
    TouchButton_Attack,
    TouchButton_Use,
    TouchButton_Inventory,
    TouchButton_Pause,
    TouchButton_Drop,
    TouchButton_Crafting,
    TouchButton_Count
};

// ── Touch joystick data (converted to same format as controller input) ───────

typedef struct
{
    float axisX;     // -1.0 to 1.0 (left/right)
    float axisY;     // -1.0 to 1.0 (up/down)
    bool  active;    // true while finger is on the joystick
} TouchJoystickState;

// ── Touch look data ──────────────────────────────────────────────────────────

typedef struct
{
    float deltaX;    // pixels dragged this frame (horizontal)
    float deltaY;    // pixels dragged this frame (vertical)
    bool  active;    // true while finger is on the look area
} TouchLookState;

// ── Configuration ────────────────────────────────────────────────────────────

@interface TouchInputConfig : NSObject

@property (nonatomic) float joystickOpacity;       // 0.0 - 1.0 (default 0.4)
@property (nonatomic) float buttonOpacity;         // 0.0 - 1.0 (default 0.5)
@property (nonatomic) float joystickRadius;        // points (default 60)
@property (nonatomic) float buttonSize;            // points (default 50)
@property (nonatomic) float lookSensitivity;       // multiplier (default 1.0)

+ (instancetype)defaultConfig;

@end

// ── Overlay view ─────────────────────────────────────────────────────────────

@interface TouchInputOverlay : UIView

// Current state (read every frame by the game loop)
@property (nonatomic, readonly) TouchJoystickState joystickState;
@property (nonatomic, readonly) TouchLookState     lookState;

// Configuration
@property (nonatomic, strong) TouchInputConfig* config;

// Called when safe area changes so buttons stay inside the usable region
- (void)updateSafeAreaInsets:(UIEdgeInsets)insets;

// Call once per frame to reset per-frame deltas (look delta)
- (void)consumeFrameDeltas;

// Query whether a specific button is currently held down
- (BOOL)isButtonDown:(TouchButtonID)buttonID;

// Query whether a specific button was pressed this frame
- (BOOL)isButtonPressed:(TouchButtonID)buttonID;

@end
