//
//  Item.m
//  ObjectiveC-UIKit
//

#import "Item.h"

@implementation Item

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                          subtitle:(nullable NSString *)subtitle {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _title = [title copy];
        _subtitle = [subtitle copy];
    }
    return self;
}

+ (nullable instancetype)itemFromJSON:(NSDictionary<NSString *, id> *)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    // Accept both string and numeric ids; coerce to string.
    id rawId = json[@"id"];
    NSString *identifier = nil;
    if ([rawId isKindOfClass:[NSString class]]) {
        identifier = rawId;
    } else if ([rawId isKindOfClass:[NSNumber class]]) {
        identifier = [(NSNumber *)rawId stringValue];
    }

    id rawTitle = json[@"title"];
    NSString *title = [rawTitle isKindOfClass:[NSString class]] ? rawTitle : nil;

    // Required fields must be present.
    if (identifier.length == 0 || title.length == 0) {
        return nil;
    }

    id rawSubtitle = json[@"subtitle"];
    NSString *subtitle =
        [rawSubtitle isKindOfClass:[NSString class]] ? rawSubtitle : nil;

    return [[self alloc] initWithIdentifier:identifier
                                      title:title
                                   subtitle:subtitle];
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p id=%@ title=%@>",
            NSStringFromClass([self class]), self, self.identifier, self.title];
}

@end
