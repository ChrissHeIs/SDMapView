//
// Created by dmitriy on 26.03.13.
//
#import "SDMapTransactionFactory.h"

#import "SDRegularMapTransaction.h"
#import "SDAscendingMapTransaction.h"
#import "SDDescendingMapTransaction.h"

@implementation SDMapTransactionFactory

- (SDMapTransaction *)transactionWithTarget:(NSSet *)target
									 source:(NSSet *)source
								targetLevel:(NSNumber *)targetLevel
								sourceLevel:(NSNumber *)sourceLevel
{
	NSParameterAssert(targetLevel != nil && sourceLevel != nil);

	Class transactionClass = nil;
	switch ([sourceLevel compare:targetLevel])
	{
		case NSOrderedSame:
			transactionClass = [SDRegularMapTransaction class];
			break;

		case NSOrderedAscending:
			transactionClass = [SDAscendingMapTransaction class];
			break;

		case NSOrderedDescending:
			transactionClass = [SDDescendingMapTransaction class];
			break;
	}

	return [[transactionClass alloc] initWithTarget:target
											 source:source
										targetLevel:targetLevel
										sourceLevel:sourceLevel];
}


@end