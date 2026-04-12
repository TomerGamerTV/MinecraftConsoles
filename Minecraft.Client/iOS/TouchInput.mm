// TouchInput.mm — Virtual touch controls implementation for iOS
// Draws translucent joystick and button overlays, converts touches
// to the same format the 4J InputManager / C4JInput expects.

#import "TouchInput.h"
#include <cmath>

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - TouchInputConfig
// ══════════════════════════════════════════════════════════════════════════════

@implementation TouchInputConfig

+ (instancetype)defaultConfig
{
    TouchInputConfig* cfg = [[TouchInputConfig alloc] init];
    cfg.joystickOpacity  = 0.4f;
    cfg.buttonOpacity    = 0.5f;
    cfg.joystickRadius   = 60.0f;
    cfg.buttonSize       = 50.0f;
    cfg.lookSensitivity  = 1.0f;
    return cfg;
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Internal button view
// ══════════════════════════════════════════════════════════════════════════════

@interface TouchButton : UIView
@property (nonatomic) TouchButtonID buttonID;
@property (nonatomic, copy) NSString* label;
@property (nonatomic) BOOL pressed;
@end

@implementation TouchButton

- (instancetype)initWithFrame:(CGRect)frame buttonID:(TouchButtonID)bid label:(NSString*)lbl
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _buttonID = bid;
        _label    = lbl;
        _pressed  = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // parent handles touches
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    // Draw circle background
    UIColor* fillColor = self.pressed
        ? [UIColor colorWithWhite:1.0 alpha:0.5]
        : [UIColor colorWithWhite:1.0 alpha:0.3];
    CGContextSetFillColorWithColor(ctx, fillColor.CGColor);
    CGContextFillEllipseInRect(ctx, rect);

    // Draw border
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.6].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGRect insetRect = CGRectInset(rect, 2, 2);
    CGContextStrokeEllipseInRect(ctx, insetRect);

    // Draw label text
    if (self.label.length > 0)
    {
        NSDictionary* attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:14],
            NSForegroundColorAttributeName: [UIColor whiteColor]
        };
        CGSize textSize = [self.label sizeWithAttributes:attrs];
        CGPoint textOrigin = CGPointMake(
            (rect.size.width  - textSize.width)  / 2.0,
            (rect.size.height - textSize.height) / 2.0
        );
        [self.label drawAtPoint:textOrigin withAttributes:attrs];
    }
}

@end

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - TouchInputOverlay
// ══════════════════════════════════════════════════════════════════════════════

@interface TouchInputOverlay ()
{
    // Joystick tracking
    UITouch*  _joystickTouch;
    CGPoint   _joystickCenter;    // where the finger first touched (left half)
    CGPoint   _joystickCurrent;

    // Look tracking
    UITouch*  _lookTouch;
    CGPoint   _lookPrev;
    float     _lookDeltaX;
    float     _lookDeltaY;

    // Buttons
    TouchButton* _buttons[TouchButton_Count];
    BOOL         _buttonPressed[TouchButton_Count];
    BOOL         _buttonPressedThisFrame[TouchButton_Count];

    // Safe area
    UIEdgeInsets _safeInsets;
}
@end

@implementation TouchInputOverlay

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.multipleTouchEnabled = YES;
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];

        _config = [TouchInputConfig defaultConfig];

        _joystickTouch = nil;
        _lookTouch     = nil;
        _lookDeltaX    = 0.0f;
        _lookDeltaY    = 0.0f;
        _safeInsets    = UIEdgeInsetsZero;

        // Reset button state
        for (int i = 0; i < TouchButton_Count; i++)
        {
            _buttonPressed[i]          = NO;
            _buttonPressedThisFrame[i] = NO;
        }

        [self createButtons];
    }
    return self;
}

- (void)createButtons
{
    // Button labels and identifiers
    struct { TouchButtonID bid; NSString* label; } buttonDefs[] = {
        { TouchButton_Jump,      @"Jump"  },
        { TouchButton_Sneak,     @"Snk"   },
        { TouchButton_Attack,    @"Atk"   },
        { TouchButton_Use,       @"Use"   },
        { TouchButton_Inventory, @"Inv"   },
        { TouchButton_Pause,     @"| |"   },
        { TouchButton_Drop,      @"Drop"  },
        { TouchButton_Crafting,  @"Crf"   },
    };

    for (int i = 0; i < TouchButton_Count; i++)
    {
        CGRect btnFrame = CGRectMake(0, 0, 50, 50); // positioned in layoutSubviews
        _buttons[i] = [[TouchButton alloc] initWithFrame:btnFrame
                                                buttonID:buttonDefs[i].bid
                                                   label:buttonDefs[i].label];
        [self addSubview:_buttons[i]];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat btnSize = _config.buttonSize;
    CGFloat margin  = 12.0f;
    CGFloat safeR   = _safeInsets.right  + margin;
    CGFloat safeB   = _safeInsets.bottom + margin;
    CGFloat safeT   = _safeInsets.top    + margin;

    // ── Right side: action buttons layout ────────────────────────────────
    // Jump: bottom-right area, prominent
    _buttons[TouchButton_Jump].frame = CGRectMake(
        w - safeR - btnSize - 10,
        h - safeB - btnSize - 10,
        btnSize, btnSize);

    // Sneak: left of jump
    _buttons[TouchButton_Sneak].frame = CGRectMake(
        w - safeR - btnSize * 2 - 20,
        h - safeB - btnSize - 10,
        btnSize, btnSize);

    // Attack: above jump
    _buttons[TouchButton_Attack].frame = CGRectMake(
        w - safeR - btnSize - 10,
        h - safeB - btnSize * 2 - 20,
        btnSize, btnSize);

    // Use: above sneak
    _buttons[TouchButton_Use].frame = CGRectMake(
        w - safeR - btnSize * 2 - 20,
        h - safeB - btnSize * 2 - 20,
        btnSize, btnSize);

    // Inventory: top-right
    _buttons[TouchButton_Inventory].frame = CGRectMake(
        w - safeR - btnSize - 10,
        safeT + 10,
        btnSize, btnSize);

    // Pause: top-center-right
    _buttons[TouchButton_Pause].frame = CGRectMake(
        w / 2.0 - btnSize / 2.0,
        safeT + 6,
        btnSize * 0.8, btnSize * 0.8);

    // Drop: left of inventory
    _buttons[TouchButton_Drop].frame = CGRectMake(
        w - safeR - btnSize * 2 - 20,
        safeT + 10,
        btnSize, btnSize);

    // Crafting: left of drop
    _buttons[TouchButton_Crafting].frame = CGRectMake(
        w - safeR - btnSize * 3 - 30,
        safeT + 10,
        btnSize, btnSize);

    // Update opacity
    for (int i = 0; i < TouchButton_Count; i++)
        _buttons[i].alpha = _config.buttonOpacity;
}

- (void)updateSafeAreaInsets:(UIEdgeInsets)insets
{
    _safeInsets = insets;
    [self setNeedsLayout];
}

- (void)consumeFrameDeltas
{
    _lookDeltaX = 0.0f;
    _lookDeltaY = 0.0f;

    for (int i = 0; i < TouchButton_Count; i++)
        _buttonPressedThisFrame[i] = NO;
}

- (BOOL)isButtonDown:(TouchButtonID)buttonID
{
    if (buttonID < 0 || buttonID >= TouchButton_Count) return NO;
    return _buttonPressed[buttonID];
}

- (BOOL)isButtonPressed:(TouchButtonID)buttonID
{
    if (buttonID < 0 || buttonID >= TouchButton_Count) return NO;
    return _buttonPressedThisFrame[buttonID];
}

- (TouchJoystickState)joystickState
{
    TouchJoystickState state = {};
    if (_joystickTouch)
    {
        float dx = _joystickCurrent.x - _joystickCenter.x;
        float dy = _joystickCurrent.y - _joystickCenter.y;
        float radius = _config.joystickRadius;

        // Clamp to circle
        float dist = sqrtf(dx * dx + dy * dy);
        if (dist > radius)
        {
            dx = dx / dist * radius;
            dy = dy / dist * radius;
        }

        state.axisX = dx / radius;        // -1.0 to 1.0
        state.axisY = -(dy / radius);     // Invert Y: up = positive
        state.active = true;
    }
    return state;
}

- (TouchLookState)lookState
{
    TouchLookState state = {};
    state.deltaX = _lookDeltaX * _config.lookSensitivity;
    state.deltaY = _lookDeltaY * _config.lookSensitivity;
    state.active = (_lookTouch != nil);
    return state;
}

// ── Touch handling ───────────────────────────────────────────────────────────

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    CGFloat halfWidth = self.bounds.size.width / 2.0;

    for (UITouch* touch in touches)
    {
        CGPoint loc = [touch locationInView:self];

        // Check if touch is on a button first
        BOOL hitButton = NO;
        for (int i = 0; i < TouchButton_Count; i++)
        {
            if (CGRectContainsPoint(_buttons[i].frame, loc))
            {
                _buttonPressed[i]          = YES;
                _buttonPressedThisFrame[i] = YES;
                _buttons[i].pressed        = YES;
                [_buttons[i] setNeedsDisplay];
                hitButton = YES;
                break;
            }
        }
        if (hitButton) continue;

        // Left half: joystick
        if (loc.x < halfWidth && !_joystickTouch)
        {
            _joystickTouch   = touch;
            _joystickCenter  = loc;
            _joystickCurrent = loc;
        }
        // Right half: look
        else if (loc.x >= halfWidth && !_lookTouch)
        {
            _lookTouch = touch;
            _lookPrev  = loc;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    for (UITouch* touch in touches)
    {
        CGPoint loc = [touch locationInView:self];

        if (touch == _joystickTouch)
        {
            _joystickCurrent = loc;
        }
        else if (touch == _lookTouch)
        {
            _lookDeltaX += (loc.x - _lookPrev.x);
            _lookDeltaY += (loc.y - _lookPrev.y);
            _lookPrev = loc;
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    for (UITouch* touch in touches)
    {
        CGPoint loc = [touch locationInView:self];

        if (touch == _joystickTouch)
        {
            _joystickTouch = nil;
        }
        else if (touch == _lookTouch)
        {
            _lookTouch = nil;
        }

        // Release buttons
        for (int i = 0; i < TouchButton_Count; i++)
        {
            if (CGRectContainsPoint(_buttons[i].frame, loc) && _buttonPressed[i])
            {
                _buttonPressed[i]   = NO;
                _buttons[i].pressed = NO;
                [_buttons[i] setNeedsDisplay];
            }
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event
{
    [self touchesEnded:touches withEvent:event];
}

// ── Drawing the joystick circle ──────────────────────────────────────────────

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    if (_joystickTouch)
    {
        CGFloat radius = _config.joystickRadius;

        // Outer circle (joystick area)
        CGRect outerRect = CGRectMake(
            _joystickCenter.x - radius,
            _joystickCenter.y - radius,
            radius * 2.0,
            radius * 2.0
        );
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:_config.joystickOpacity * 0.3].CGColor);
        CGContextFillEllipseInRect(ctx, outerRect);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:_config.joystickOpacity].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGContextStrokeEllipseInRect(ctx, outerRect);

        // Inner circle (thumb position)
        CGFloat thumbRadius = radius * 0.4;
        float dx = _joystickCurrent.x - _joystickCenter.x;
        float dy = _joystickCurrent.y - _joystickCenter.y;
        float dist = sqrtf(dx * dx + dy * dy);
        if (dist > radius)
        {
            dx = dx / dist * radius;
            dy = dy / dist * radius;
        }
        CGFloat thumbX = _joystickCenter.x + dx;
        CGFloat thumbY = _joystickCenter.y + dy;

        CGRect thumbRect = CGRectMake(
            thumbX - thumbRadius,
            thumbY - thumbRadius,
            thumbRadius * 2.0,
            thumbRadius * 2.0
        );
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:_config.joystickOpacity].CGColor);
        CGContextFillEllipseInRect(ctx, thumbRect);
    }
}

@end
