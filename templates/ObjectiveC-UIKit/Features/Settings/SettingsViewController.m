//
//  SettingsViewController.m
//  ObjectiveC-UIKit
//

#import "SettingsViewController.h"
#import "UIView+Extensions.h"

// NSUserDefaults keys backing each toggle. Keep these stable across releases.
static NSString *const kDefaultsNotificationsEnabled = @"settings.notificationsEnabled";
static NSString *const kDefaultsHapticsEnabled = @"settings.hapticsEnabled";
static NSString *const kDefaultsAnalyticsEnabled = @"settings.analyticsEnabled";

static NSString *const kCellReuseIdentifier = @"SettingsToggleCell";

@interface SettingsViewController () <UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

// Each row is described by a title + the defaults key it toggles.
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *rows;

@end

@implementation SettingsViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _rows = @[
            @{ @"title": @"Notifications", @"key": kDefaultsNotificationsEnabled },
            @{ @"title": @"Haptic Feedback", @"key": kDefaultsHapticsEnabled },
            @{ @"title": @"Share Analytics", @"key": kDefaultsAnalyticsEnabled },
        ];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Settings";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    UITableView *tableView =
        [[UITableView alloc] initWithFrame:CGRectZero
                                     style:UITableViewStyleInsetGrouped];
    tableView.dataSource = self;
    [tableView registerClass:[UITableViewCell class]
      forCellReuseIdentifier:kCellReuseIdentifier];
    [self.view addSubview:tableView];
    [tableView pinEdgesToView:self.view];
    self.tableView = tableView;
}

#pragma mark - Toggle Handling

- (void)switchValueChanged:(UISwitch *)sender {
    NSDictionary<NSString *, NSString *> *row = self.rows[(NSUInteger)sender.tag];
    NSString *key = row[@"key"];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    // TODO: React to specific setting changes (register for notifications,
    // toggle analytics SDK, etc.).
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.rows.count;
}

- (nullable NSString *)tableView:(UITableView *)tableView
         titleForFooterInSection:(NSInteger)section {
    return @"Preferences are stored on this device.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier
                                        forIndexPath:indexPath];

    NSDictionary<NSString *, NSString *> *row = self.rows[(NSUInteger)indexPath.row];

    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = row[@"title"];
    cell.contentConfiguration = content;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.tag = indexPath.row;
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:row[@"key"]];
    [toggle addTarget:self
               action:@selector(switchValueChanged:)
     forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;

    return cell;
}

@end
