#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface AVSystemController : NSObject
+ (id)sharedAVSystemController;
- (BOOL)getVolume:(float *)arg1 forCategory:(id)arg2;
- (BOOL)setVolumeTo:(float)arg1 forCategory:(id)arg2;
@end

@class Pixel17HUDWindow;

// --- HORIZONTAL SLIDER ROW FOR EXPANDED ANDROID 17 PANEL ---
@interface Pixel17SliderRow : UIView
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *trackBg;
@property (nonatomic, strong) UIView *trackFill;
@property (nonatomic, strong) UIView *thumbBar;
@property (nonatomic, strong) UIView *maxDot;
@property (nonatomic, weak) Pixel17HUDWindow *parentHUD;
@property (nonatomic, assign) float currentVolume;

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title symbol:(NSString *)symbol category:(NSString *)category parent:(Pixel17HUDWindow *)parent;
- (void)refreshFromSystem;
- (void)setSliderValue:(float)val animated:(BOOL)animated;
@end

// --- MAIN FROSTED-GLASS HUD WINDOW ---
@interface Pixel17HUDWindow : UIWindow
@property (nonatomic, strong) UIVisualEffectView *frostedContainer;
@property (nonatomic, strong) UIView *dynamicTintOverlay;

// Compact Mode Views
@property (nonatomic, strong) UIView *compactWrapper;
@property (nonatomic, strong) UIView *trackBackground;
@property (nonatomic, strong) UIView *trackFill;
@property (nonatomic, strong) UIView *handleBar;
@property (nonatomic, strong) UIView *topMaxDot;
@property (nonatomic, strong) UIImageView *speakerIconView;
@property (nonatomic, strong) UIButton *expandButton;

// Expanded Mode Views
@property (nonatomic, strong) UIView *expandedWrapper;
@property (nonatomic, strong) UILabel *sheetHeaderLabel;
@property (nonatomic, strong) NSMutableArray<Pixel17SliderRow *> *sliderRows;
@property (nonatomic, strong) UIButton *doneButton;

@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, strong) UIImpactFeedbackGenerator *hapticEdge;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) float lastVolume;

+ (instancetype)sharedHUD;
- (void)updateWithVolume:(float)volume fromTouch:(BOOL)fromTouch;
- (void)resetHideTimer;
- (void)collapseToCompact;
@end

@implementation Pixel17SliderRow

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title symbol:(NSString *)symbol category:(NSString *)category parent:(Pixel17HUDWindow *)parent {
    self = [super initWithFrame:frame];
    if (self) {
        _category = category;
        _parentHUD = parent;
        _currentVolume = 0.5f;

        // Row Header Label
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(34, 0, frame.size.width - 34, 16)];
        _titleLabel.text = title;
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [UIColor colorWithWhite:0.88 alpha:0.95];
        [self addSubview:_titleLabel];

        // Left Category SF Symbol Icon
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(2, 20, 22, 22)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:1.0];
        _iconView.image = [UIImage systemImageNamed:symbol withConfiguration:cfg];
        [self addSubview:_iconView];

        // Horizontal M3 Track Background
        CGFloat trackWidth = frame.size.width - 36;
        _trackBg = [[UIView alloc] initWithFrame:CGRectMake(34, 21, trackWidth, 20)];
        _trackBg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        _trackBg.layer.cornerRadius = 10.0;
        _trackBg.clipsToBounds = YES;
        [self addSubview:_trackBg];

        // Right Max-Volume Dot Indicator
        _maxDot = [[UIView alloc] initWithFrame:CGRectMake(trackWidth - 10, 8, 4, 4)];
        _maxDot.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.85];
        _maxDot.layer.cornerRadius = 2.0;
        [_trackBg addSubview:_maxDot];

        // Active Fill
        _trackFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, trackWidth * 0.5, 20)];
        _trackFill.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.92];
        _trackFill.layer.cornerRadius = 8.0;
        [_trackBg addSubview:_trackFill];

        // Vertical Expressive Handle Bar
        _thumbBar = [[UIView alloc] initWithFrame:CGRectMake(34 + (trackWidth * 0.5) - 2, 17, 4, 28)];
        _thumbBar.backgroundColor = [UIColor colorWithRed:0.92 green:0.96 blue:1.0 alpha:1.0];
        _thumbBar.layer.cornerRadius = 2.0;
        [self addSubview:_thumbBar];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRowPan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)refreshFromSystem {
    float vol = 0.5f;
    AVSystemController *avc = [objc_getClass("AVSystemController") sharedAVSystemController];
    if (avc && [avc respondsToSelector:@selector(getVolume:forCategory:)]) {
        if ([avc getVolume:&vol forCategory:self.category]) {
            [self setSliderValue:vol animated:NO];
        }
    }
}

- (void)setSliderValue:(float)val animated:(BOOL)animated {
    _currentVolume = fmaxf(0.0f, fminf(1.0f, val));
    CGFloat trackWidth = self.trackBg.bounds.size.width;
    CGFloat fillW = trackWidth * _currentVolume;

    void (^updateBlock)(void) = ^{
        self.trackFill.frame = CGRectMake(0, 0, fillW, 20);
        self.thumbBar.frame = CGRectMake(34 + fillW - 2.0, 17, 4, 28);
    };

    if (animated) {
        [UIView animateWithDuration:0.08 animations:updateBlock];
    } else {
        updateBlock();
    }
}

- (void)handleRowPan:(UIPanGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.trackBg];
    float progress = fmaxf(0.0f, fminf(1.0f, loc.x / self.trackBg.bounds.size.width));

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.parentHUD.isDragging = YES;
        [self.parentHUD.hideTimer invalidate];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        [self setSliderValue:progress animated:NO];
        [[objc_getClass("AVSystemController") sharedAVSystemController] setVolumeTo:progress forCategory:self.category];
        if ([self.category isEqualToString:@"Audio/Video"]) {
            [self.parentHUD updateWithVolume:progress fromTouch:YES];
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        self.parentHUD.isDragging = NO;
        [self.parentHUD resetHideTimer];
    }
}

@end

@implementation Pixel17HUDWindow

+ (instancetype)sharedHUD {
    static Pixel17HUDWindow *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        shared = [[Pixel17HUDWindow alloc] initWithFrame:CGRectMake(screen.size.width + 80, (screen.size.height - 236) / 2.0, 58, 236)];
    });
    return shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 300.0;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
        self.userInteractionEnabled = YES;
        self.lastVolume = -1.0f;
        self.hapticEdge = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

        // 1. Frosted-Glass Container (Morphs between Pill and Expanded Sheet)
        UIBlurEffect *glassBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        _frostedContainer = [[UIVisualEffectView alloc] initWithEffect:glassBlur];
        _frostedContainer.frame = self.bounds;
        _frostedContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _frostedContainer.layer.cornerRadius = 29.0;
        _frostedContainer.layer.cornerCurve = kCACornerCurveContinuous;
        _frostedContainer.clipsToBounds = YES;
        _frostedContainer.layer.borderWidth = 0.8;
        _frostedContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
        [self addSubview:_frostedContainer];

        _dynamicTintOverlay = [[UIView alloc] initWithFrame:self.bounds];
        _dynamicTintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _dynamicTintOverlay.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.09];
        _dynamicTintOverlay.userInteractionEnabled = NO;
        [_frostedContainer.contentView addSubview:_dynamicTintOverlay];

        [self setupCompactUI];
        [self setupExpandedUI];
    }
    return self;
}

- (void)setupCompactUI {
    _compactWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 58, 236)];
    [_frostedContainer.contentView addSubview:_compactWrapper];

    _trackBackground = [[UIView alloc] initWithFrame:CGRectMake(21, 18, 16, 144)];
    _trackBackground.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    _trackBackground.layer.cornerRadius = 8.0;
    _trackBackground.clipsToBounds = YES;
    [_compactWrapper addSubview:_trackBackground];

    _topMaxDot = [[UIView alloc] initWithFrame:CGRectMake(6, 5, 4, 4)];
    _topMaxDot.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.85];
    _topMaxDot.layer.cornerRadius = 2.0;
    [_trackBackground addSubview:_topMaxDot];

    _trackFill = [[UIView alloc] initWithFrame:CGRectMake(0, 72, 16, 72)];
    _trackFill.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.92];
    _trackFill.layer.cornerRadius = 6.0;
    [_trackBackground addSubview:_trackFill];

    _handleBar = [[UIView alloc] initWithFrame:CGRectMake(17, 88, 24, 4)];
    _handleBar.backgroundColor = [UIColor colorWithRed:0.90 green:0.95 blue:1.0 alpha:1.0];
    _handleBar.layer.cornerRadius = 2.0;
    [_compactWrapper addSubview:_handleBar];

    UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    _speakerIconView = [[UIImageView alloc] initWithFrame:CGRectMake(17, 170, 24, 22)];
    _speakerIconView.contentMode = UIViewContentModeScaleAspectFit;
    _speakerIconView.tintColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    _speakerIconView.image = [UIImage systemImageNamed:@"speaker.wave.2.fill" withConfiguration:symConfig];
    [_compactWrapper addSubview:_speakerIconView];

    // Android 17 Dial-Controls Overflow Button
    UIImageSymbolConfiguration *dialConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    _expandButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _expandButton.frame = CGRectMake(9, 194, 40, 34);
    [_expandButton setImage:[UIImage systemImageNamed:@"slider.horizontal.3" withConfiguration:dialConfig] forState:UIControlStateNormal];
    _expandButton.tintColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.95];
    [_expandButton addTarget:self action:@selector(expandToFullPanel) forControlEvents:UIControlEventTouchUpInside];
    [_compactWrapper addSubview:_expandButton];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCompactPan:)];
    [_compactWrapper addGestureRecognizer:pan];
}

- (void)setupExpandedUI {
    _expandedWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 336, 360)];
    _expandedWrapper.alpha = 0.0;
    _expandedWrapper.hidden = YES;
    [_frostedContainer.contentView addSubview:_expandedWrapper];

    _sheetHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, 18, 200, 24)];
    _sheetHeaderLabel.text = @"Sound & vibration";
    _sheetHeaderLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _sheetHeaderLabel.textColor = [UIColor whiteColor];
    [_expandedWrapper addSubview:_sheetHeaderLabel];

    // Android 17's 5 Core Audio Streams (including Assistant)
    NSArray *streams = @[
        @{@"title": @"Media", @"symbol": @"music.note", @"cat": @"Audio/Video"},
        @{@"title": @"Call", @"symbol": @"phone.fill", @"cat": @"PhoneCall"},
        @{@"title": @"Ring & notification", @"symbol": @"bell.fill", @"cat": @"Ringtone"},
        @{@"title": @"Alarm", @"symbol": @"alarm.fill", @"cat": @"Alarm"},
        @{@"title": @"Assistant", @"symbol": @"mic.fill", @"cat": @"VoiceCommand"}
    ];

    _sliderRows = [NSMutableArray array];
    CGFloat startY = 52.0;
    for (NSDictionary *info in streams) {
        Pixel17SliderRow *row = [[Pixel17SliderRow alloc] initWithFrame:CGRectMake(22, startY, 292, 46)
                                                                  title:info[@"title"]
                                                                 symbol:info[@"symbol"]
                                                               category:info[@"cat"]
                                                                 parent:self];
        [_expandedWrapper addSubview:row];
        [_sliderRows addObject:row];
        startY += 50.0;
    }

    // Done Pill Button
    _doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _doneButton.frame = CGRectMake(232, 310, 82, 34);
    _doneButton.backgroundColor = [UIColor colorWithRed:0.659 green:0.780 blue:0.980 alpha:0.95];
    [_doneButton setTitle:@"Done" forState:UIControlStateNormal];
    [_doneButton setTitleColor:[UIColor colorWithRed:0.08 green:0.12 blue:0.20 alpha:1.0] forState:UIControlStateNormal];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _doneButton.layer.cornerRadius = 17.0;
    [_doneButton addTarget:self action:@selector(collapseToCompact) forControlEvents:UIControlEventTouchUpInside];
    [_expandedWrapper addSubview:_doneButton];
}

- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}

- (void)expandToFullPanel {
    if (self.isExpanded) return;
    self.isExpanded = YES;
    [self.hapticEdge impactOccurred];

    for (Pixel17SliderRow *row in self.sliderRows) {
        [row refreshFromSystem];
    }

    self.expandedWrapper.hidden = NO;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect targetFrame = CGRectMake((screen.size.width - 336) / 2.0, screen.size.height - 400, 336, 360);

    // Android 17 Extra-Bounce Jelly Morph Animation
    [UIView animateWithDuration:0.46 delay:0 usingSpringWithDamping:0.68 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.frame = targetFrame;
        self.frostedContainer.layer.cornerRadius = 32.0;
        self.compactWrapper.alpha = 0.0;
        self.expandedWrapper.alpha = 1.0;
    } completion:^(BOOL finished) {
        self.compactWrapper.hidden = YES;
    }];

    [self resetHideTimer];
}

- (void)collapseToCompact {
    if (!self.isExpanded) return;
    self.isExpanded = NO;
    [self.hapticEdge impactOccurred];

    self.compactWrapper.hidden = NO;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGRect compactFrame = CGRectMake(screen.size.width - 70, (screen.size.height - 236) / 2.0, 58, 236);

    [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.frame = compactFrame;
        self.frostedContainer.layer.cornerRadius = 29.0;
        self.expandedWrapper.alpha = 0.0;
        self.compactWrapper.alpha = 1.0;
    } completion:^(BOOL finished) {
        self.expandedWrapper.hidden = YES;
    }];

    [self resetHideTimer];
}

- (void)handleCompactPan:(UIPanGestureRecognizer *)gesture {
    CGPoint loc = [gesture locationInView:self.trackBackground];
    CGFloat maxTrackHeight = 144.0;
    float progress = fmaxf(0.0f, fminf(1.0f, 1.0f - (loc.y / maxTrackHeight)));

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
        [self.hideTimer invalidate];
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        [self updateWithVolume:progress fromTouch:YES];
        [[objc_getClass("AVSystemController") sharedAVSystemController] setVolumeTo:progress forCategory:@"Audio/Video"];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        self.isDragging = NO;
        [self resetHideTimer];
    }
}

- (void)updateWithVolume:(float)volume fromTouch:(BOOL)fromTouch {
    if (self.isDragging && !fromTouch) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat clamped = fmaxf(0.0f, fminf(1.0f, volume));
        CGFloat maxTrackHeight = 144.0;
        CGFloat fillHeight = maxTrackHeight * clamped;
        CGFloat topY = 18.0 + (maxTrackHeight - fillHeight);

        if ((clamped <= 0.001f && self.lastVolume > 0.001f) || (clamped >= 0.999f && self.lastVolume < 0.999f)) {
            [self.hapticEdge impactOccurred];
        }
        self.lastVolume = clamped;

        NSString *symbolName = @"speaker.wave.3.fill";
        if (clamped <= 0.005f) {
            symbolName = @"speaker.slash.fill";
        } else if (clamped < 0.35f) {
            symbolName = @"speaker.wave.1.fill";
        } else if (clamped < 0.70f) {
            symbolName = @"speaker.wave.2.fill";
        }
        UIImageSymbolConfiguration *symConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
        self.speakerIconView.image = [UIImage systemImageNamed:symbolName withConfiguration:symConfig];

        NSTimeInterval duration = fromTouch ? 0.03 : 0.12;
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^{
            self.trackFill.frame = CGRectMake(0, maxTrackHeight - fillHeight, 16, fillHeight);
            self.handleBar.frame = CGRectMake(17, topY - 2.0, 24, 4);
        } completion:nil];

        if (self.isExpanded && self.sliderRows.count > 0 && !fromTouch) {
            [self.sliderRows[0] setSliderValue:clamped animated:YES];
        }

        [self showHUD];
    });
}

- (void)resetHideTimer {
    [self.hideTimer invalidate];
    NSTimeInterval timeout = self.isExpanded ? 4.5 : 2.2;
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(hideHUD) userInfo:nil repeats:NO];
}

- (void)showHUD {
    if (!self.isDragging) {
        [self resetHideTimer];
    }
    if (!self.isShowing) {
        self.isShowing = YES;
        CGRect screen = [UIScreen mainScreen].bounds;
        [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.76 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
            if (self.isExpanded) {
                self.frame = CGRectMake((screen.size.width - 336) / 2.0, screen.size.height - 400, 336, 360);
            } else {
                self.frame = CGRectMake(screen.size.width - 70, (screen.size.height - 236) / 2.0, 58, 236);
            }
        } completion:nil];
    }
}

- (void)hideHUD {
    if (self.isDragging) return;
    self.isShowing = NO;
    CGRect screen = [UIScreen mainScreen].bounds;

    [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        if (self.isExpanded) {
            self.frame = CGRectMake((screen.size.width - 336) / 2.0, screen.size.height + 50, 336, 360);
        } else {
            self.frame = CGRectMake(screen.size.width + 80, (screen.size.height - 236) / 2.0, 58, 236);
        }
    } completion:^(BOOL finished) {
        // Reset back to compact pill state while off-screen
        self.isExpanded = NO;
        self.expandedWrapper.hidden = YES;
        self.expandedWrapper.alpha = 0.0;
        self.compactWrapper.hidden = NO;
        self.compactWrapper.alpha = 1.0;
        self.frostedContainer.layer.cornerRadius = 29.0;
        self.frame = CGRectMake(screen.size.width + 80, (screen.size.height - 236) / 2.0, 58, 236);
    }];
}

@end

// --- IOS 16.7.16 VOLUME HUD HOOKS ---
@interface SBVolumeHUDViewController : UIViewController
@end
%hook SBVolumeHUDViewController
- (void)viewDidLoad {
    %orig;
    self.view.hidden = YES;
    self.view.alpha = 0.0;
}
%end

%hook SBVolumeControl
- (void)_presentVolumeHUDWithVolume:(float)volume {
    [[Pixel17HUDWindow sharedHUD] updateWithVolume:volume fromTouch:NO];
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [Pixel17HUDWindow sharedHUD];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        NSNumber *vol = note.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
        if (vol) {
            [[Pixel17HUDWindow sharedHUD] updateWithVolume:[vol floatValue] fromTouch:NO];
        }
    }];
}
%end
