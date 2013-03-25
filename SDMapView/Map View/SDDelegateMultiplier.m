//
// Created by dmitriy on 24.03.13.
//
#import "SDDelegateMultiplier.h"

@interface SDDelegateMultiplier ()
{
	NSMutableArray *_targets;
}

@end

@implementation SDDelegateMultiplier

@dynamic targets;

- (id)initWithTargets:(NSArray *)targets
{
	if (self != nil)
	{
		_targets = (__bridge_transfer NSMutableArray *) CFArrayCreateMutable(kCFAllocatorDefault, targets.count, NULL);

		if (targets != nil)
		{
			[_targets addObjectsFromArray:targets];
		}
	}

	return self;
}

#pragma mark - Modification

- (void)addTarget:(id)target
{
	[_targets addObject:target];
}

- (void)addTargets:(NSArray *)targets
{
	[_targets addObjectsFromArray:targets];
}

- (void)removeTarget:(id)target
{
	[_targets removeObject:target];
}

- (void)removeTargets:(NSArray *)targets
{
	[_targets removeObjectsInArray:targets];
}

- (void)removeAllTargets
{
	[_targets removeAllObjects];
}

#pragma mark - Message forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	__block NSMethodSignature *signature = nil;
	[[_targets copy] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
	{
		signature = [obj methodSignatureForSelector:sel];
		*stop = signature != nil;
	}];

	return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	char const *type = invocation.methodSignature.methodReturnType;
	BOOL returnVoid = strcmp(type, "v") == 0;

	for (id target in _targets)
	{
		if ([target respondsToSelector:[invocation selector]])
		{
			[invocation invokeWithTarget:target];

			if (!returnVoid) return;
		}
	}
}

@end