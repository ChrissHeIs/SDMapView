//
// Created by dmitriy on 24.03.13.
//
#import <Foundation/Foundation.h>


@interface SDDelegateMultiplier : NSProxy

- (id)initWithTargets:(NSArray *)targets;

@property (nonatomic, strong, readonly) NSArray *targets;

- (void)addTarget:(id)target;
- (void)addTargets:(NSArray *)targets;

- (void)removeTarget:(id)target;
- (void)removeTargets:(NSArray *)targets;
- (void)removeAllTargets;

@end