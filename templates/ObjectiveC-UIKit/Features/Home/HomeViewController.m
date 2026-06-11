//
//  HomeViewController.m
//  ObjectiveC-UIKit
//

#import "HomeViewController.h"
#import "SettingsViewController.h"
#import "APIClient.h"
#import "Item.h"
#import "UIView+Extensions.h"

static NSString *const kCellReuseIdentifier = @"HomeItemCell";

@interface HomeViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Model backing the table.
@property (nonatomic, copy) NSArray<Item *> *items;

@end

@implementation HomeViewController

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _items = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Home";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(didTapSettings)];

    [self configureTableView];
    [self configureLoadingIndicator];

    [self reloadItemsShowingSpinner:YES];
}

#pragma mark - View Configuration

- (void)configureTableView {
    UITableView *tableView =
        [[UITableView alloc] initWithFrame:CGRectZero
                                     style:UITableViewStylePlain];
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerClass:[UITableViewCell class]
      forCellReuseIdentifier:kCellReuseIdentifier];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(didPullToRefresh:)
             forControlEvents:UIControlEventValueChanged];
    tableView.refreshControl = refreshControl;

    [self.view addSubview:tableView];
    [tableView pinEdgesToView:self.view];

    self.tableView = tableView;
}

- (void)configureLoadingIndicator {
    UIActivityIndicatorView *indicator =
        [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.hidesWhenStopped = YES;
    [self.view addSubview:indicator];
    [indicator centerInView:self.view];
    self.loadingIndicator = indicator;
}

#pragma mark - Actions

- (void)didTapSettings {
    SettingsViewController *settings = [[SettingsViewController alloc] init];
    [self.navigationController pushViewController:settings animated:YES];
}

- (void)didPullToRefresh:(UIRefreshControl *)sender {
    [self reloadItemsShowingSpinner:NO];
}

#pragma mark - Data Loading

- (void)reloadItemsShowingSpinner:(BOOL)showSpinner {
    if (showSpinner) {
        [self.loadingIndicator startAnimating];
    }

    __weak typeof(self) weakSelf = self;
    // Completion is delivered on the main queue by APIClient, so it is safe
    // to update UIKit directly here.
    [[APIClient sharedClient] fetchItemsWithCompletion:^(NSArray<Item *> *_Nullable items,
                                                          NSError *_Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        [strongSelf.loadingIndicator stopAnimating];
        [strongSelf.tableView.refreshControl endRefreshing];

        if (error != nil) {
            [strongSelf presentLoadError:error];
            return;
        }

        strongSelf.items = items ?: @[];
        [strongSelf.tableView reloadData];
    }];
}

- (void)presentLoadError:(NSError *)error {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Couldn't Load Items"
                                            message:error.localizedDescription
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Retry"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *_Nonnull action) {
        [self reloadItemsShowingSpinner:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier
                                        forIndexPath:indexPath];

    Item *item = self.items[(NSUInteger)indexPath.row];
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = item.title;
    content.secondaryText = item.subtitle;
    cell.contentConfiguration = content;

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // TODO: Push a detail view controller for the selected item.
}

@end
