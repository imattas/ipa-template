#import "HomeViewController.h"

#include <initializer_list>  // for the range-based-for seed list below

// We only need the pure-ObjC bridge here. Because the bridge header is
// C++-free, this controller would compile even as a plain .m. We keep it as
// .mm to illustrate that UIKit code can sit in an Objective-C++ TU.
#import "EngineBridge.h"

@interface HomeViewController ()
@property(nonatomic, strong) EngineBridge *engine;
@property(nonatomic, strong) UILabel *countLabel;
@property(nonatomic, strong) UILabel *meanLabel;
@property(nonatomic, strong) UILabel *stdDevLabel;
@end

@implementation HomeViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [[EngineBridge alloc] init];
        // Seed with a few known samples so the screen is non-empty on launch.
        for (double sample : {4.0, 8.0, 15.0, 16.0, 23.0, 42.0}) {
            [_engine addSample:sample];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Compute Engine";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.countLabel = [self makeValueLabel];
    self.meanLabel = [self makeValueLabel];
    self.stdDevLabel = [self makeValueLabel];

    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [addButton setTitle:@"Add Random Sample" forState:UIControlStateNormal];
    [addButton addTarget:self
                  action:@selector(addRandomSample)
        forControlEvents:UIControlEventTouchUpInside];

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [resetButton addTarget:self
                    action:@selector(resetSamples)
          forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        [self captionedRow:@"Samples" value:self.countLabel],
        [self captionedRow:@"Mean" value:self.meanLabel],
        [self captionedRow:@"Std Dev" value:self.stdDevLabel],
        addButton,
        resetButton,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:guide.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:24.0],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-24.0],
    ]];

    [self refresh];
}

#pragma mark - Actions

- (void)addRandomSample {
    const double value = (double)arc4random_uniform(100);
    [self.engine addSample:value];
    [self refresh];
}

- (void)resetSamples {
    [self.engine reset];
    [self refresh];
}

#pragma mark - Rendering

- (void)refresh {
    self.countLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)[self.engine count]];
    self.meanLabel.text = [NSString stringWithFormat:@"%.2f", [self.engine mean]];
    self.stdDevLabel.text = [NSString stringWithFormat:@"%.2f", [self.engine standardDeviation]];
}

#pragma mark - View helpers

- (UILabel *)makeValueLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont monospacedDigitSystemFontOfSize:20.0 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentRight;
    label.text = @"--";
    return label;
}

- (UIView *)captionedRow:(NSString *)caption value:(UILabel *)valueLabel {
    UILabel *captionLabel = [[UILabel alloc] init];
    captionLabel.text = caption;
    captionLabel.font = [UIFont systemFontOfSize:20.0];
    captionLabel.textColor = UIColor.secondaryLabelColor;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ captionLabel, valueLabel ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFill;
    return row;
}

@end
