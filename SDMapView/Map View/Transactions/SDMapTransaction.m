//
// Created by dmitriy on 26.03.13.
//
#import "SDMapTransaction.h"
#import "SDMapView.h"


@implementation SDMapTransaction

- (id)initWithTarget:(NSSet *)target source:(NSSet *)source targetLevel:(NSNumber *)targetLevel sourceLevel:(NSNumber *)sourceLevel
{
	NSParameterAssert(targetLevel != nil && sourceLevel != nil);

	self = [super init];
	if (self)
	{
		_target = target;
		_source = source;
		_targetLevel = targetLevel;
		_sourceLevel = sourceLevel;

		_order = [sourceLevel compare:targetLevel];
	}

	return self;
}

+ (id)transactionWithTarget:(NSSet *)target source:(NSSet *)source targetLevel:(NSNumber *)targetLevel sourceLevel:(NSNumber *)sourceLevel
{
	return [[self alloc] initWithTarget:target source:source targetLevel:targetLevel sourceLevel:sourceLevel];
}

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[NSException raise:@"Subclass error" format:@"Subclass should override %@", NSStringFromSelector(_cmd)];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
}

@end