//
//  Item.h
//  ObjectiveC-UIKit
//
//  Lightweight model object representing a single feed item.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Item : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *subtitle;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             title:(NSString *)title
                          subtitle:(nullable NSString *)subtitle NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Builds an Item from a decoded JSON object, or returns nil if required
/// fields are missing / of the wrong type.
+ (nullable instancetype)itemFromJSON:(NSDictionary<NSString *, id> *)json;

@end

NS_ASSUME_NONNULL_END
