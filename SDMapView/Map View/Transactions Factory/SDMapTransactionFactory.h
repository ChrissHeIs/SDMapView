//
// Created by dmitriy on 26.03.13.
//
#import <Foundation/Foundation.h>

#import "SDMapTransaction.h"

@interface SDMapTransactionFactory : NSObject

- (SDMapTransaction *)transactionWithTarget:(NSSet *)target
									 source:(NSSet *)source
								targetLevel:(NSNumber *)targetLevel
								sourceLevel:(NSNumber *)sourceLevel;

@end