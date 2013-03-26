//
// Created by dmitriy on 24.03.13.
//
#import "SDMapView.h"
#import "SDMapView+SDMapTransaction.h"

#import <MapKit/MapKit.h>

#import "SDQuadTree.h"
#import "SDDelegateMultiplier.h"
#import "SDMapTransactionFactory.h"

#import "NSInvocation+SDExtension.h"

const NSUInteger SDMapViewMaxZoomLevel = 20;
const double  SDMapViewMercatorRadius = 85445659.44705395;
const NSTimeInterval SDMapViewUpdateDelay = 0.3;


@interface SDMapView () <MKMapViewDelegate>
{
	__weak id <MKMapViewDelegate> _targetDelegate;
	SDDelegateMultiplier *_delegateMultiplier;

	__weak NSTimer *_updateAnnotationsTimer;

	SDMapTransaction *_lockTransaction;
}

- (void)commonInitialization;

@property (nonatomic, strong) SDQuadTree *tree;
@property (nonatomic, weak) SDMapTransaction *activeTransaction;
- (void)processTransaction:(SDMapTransaction *)transaction;
- (void)confirmTransactionActions:(SDMapTransaction *)transaction;

@property (nonatomic) NSUInteger annotationsLevel;

- (void)updateAnnotations;


@property (nonatomic, readonly) NSUInteger zoomLevel;

@end

@implementation SDMapView

#pragma mark - Init

- (void)commonInitialization
{
	_delegateMultiplier = [[SDDelegateMultiplier alloc] initWithTargets:@[self]];
	[super setDelegate:(id)_delegateMultiplier];

	[self setTree:[[SDQuadTree alloc] initWithRect:MKMapRectWorld maxDepth:SDMapViewMaxZoomLevel]];

	[self setTransactionFactory:[SDMapTransactionFactory new]];

	[self setAnnotationsLevel:NSUIntegerMax];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self != nil)
	{
		[self commonInitialization];
	}

	return self;
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
	{
		[self commonInitialization];
	}

	return self;
}

#pragma mark - Message Forwarding

- (void)setDelegate:(id <MKMapViewDelegate>)delegate
{
	if (_targetDelegate != nil)
	{
		[_delegateMultiplier removeTarget:_targetDelegate];
	}

	_targetDelegate = delegate;

	if (_targetDelegate != nil)
	{
		[_delegateMultiplier addTarget:_targetDelegate];
	}
}

#pragma mark - Zoom Level

- (NSUInteger)zoomLevel
{
	CLLocationDegrees longitudeDelta = self.region.span.longitudeDelta;
	CGFloat mapWidthInPixels = self.bounds.size.width;

	double zoomScale = longitudeDelta * SDMapViewMercatorRadius * M_PI / (180.0 * mapWidthInPixels);
	return (NSUInteger)ceil(SDMapViewMaxZoomLevel - log2(zoomScale));
}

#pragma mark - Transactions

- (void)confirmTransactionActions:(SDMapTransaction *)transaction
{
	if ([self isLockedForTransaction])
	{
		NSParameterAssert([self isLockedForTransaction:transaction]);
	}
}

#pragma mark - Annotations Update

- (NSUInteger)annotationsLevel
{
	if (_annotationsLevel == NSUIntegerMax)
	{
		_annotationsLevel = [self zoomLevel];
	}

	return _annotationsLevel;
}

- (void)updateAnnotations
{
	if ([self isLockedForTransaction])
	{
#ifdef DEBUG
		NSLog(@"Ignore transaction");
#endif
		return;
	}

	MKMapRect rect = self.visibleMapRect;
	if (rect.origin.x + 10.0 > MKMapRectWorld.size.width)
	{
		rect.origin.x = 0.0;
	}

	NSUInteger level = [self zoomLevel];
	NSSet *targetAnnotations = [self.tree annotationsInRect:rect maxTraversalDepth:level];
	NSMutableSet *sourceAnnotations = [[NSMutableSet alloc] initWithArray:[super annotations]];

	NSMutableSet *intersect = [[NSMutableSet alloc] initWithSet:targetAnnotations];
	[intersect intersectSet:sourceAnnotations];
	[sourceAnnotations minusSet:intersect];

	if (intersect.count == targetAnnotations.count)
	{
		targetAnnotations = nil;
	}

	SDMapTransaction *transaction = [self.transactionFactory transactionWithTarget:targetAnnotations
																			source:sourceAnnotations
																	   targetLevel:@(level)
																	   sourceLevel:@(self.annotationsLevel)];
	[self setActiveTransaction:transaction];
	[self processTransaction:transaction];
}

- (void)processTransaction:(SDMapTransaction *)transaction
{
	NSParameterAssert(transaction != nil);

	[self setAnnotationsLevel:[transaction.targetLevel unsignedIntegerValue]];
	[transaction invokeWithMapView:self];
}

- (void)setNeedsUpdateAnnotations
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateAnnotations) object:nil];

	[self performSelector:@selector(updateAnnotations)
			   withObject:@(self.zoomLevel)
			   afterDelay:0.0
				  inModes:@[NSRunLoopCommonModes]];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	static NSString *identifier = @"annotation";
	MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:identifier];
	if (view == nil)
	{
		view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
	}
	else
	{
		[view setAnnotation:annotation];
	}

	return view;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	[self confirmTransactionActions:self.activeTransaction];

	[self.activeTransaction mapView:self didAddAnnotationViews:views];
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	[_updateAnnotationsTimer invalidate];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	NSInvocation *invocation = [NSInvocation invocationForTarget:self selector:@selector(updateAnnotations)];

	_updateAnnotationsTimer = [NSTimer scheduledTimerWithTimeInterval:SDMapViewUpdateDelay
														   invocation:invocation
															  repeats:NO];
}

#pragma mark - MKMapView

- (void)addAnnotations:(NSArray *)annotations
{
	for (id <MKAnnotation> annotation in annotations)
	{
		[self.tree insert:annotation];
	}

	[self setNeedsUpdateAnnotations];
}

- (void)addAnnotation:(id <MKAnnotation>)annotation
{
	[self.tree insert:annotation];

	[self setNeedsUpdateAnnotations];
}

- (void)removeAnnotations:(NSArray *)annotations
{
	for (id <MKAnnotation> annotation in annotations)
	{
		[self.tree remove:annotation];
	}

	[self setNeedsUpdateAnnotations];
}

- (void)removeAnnotation:(id <MKAnnotation>)annotation
{
	[self.tree remove:annotation];

	[self setNeedsUpdateAnnotations];
}

- (NSArray *)annotations
{
	return [[self.tree allAnnotations] allObjects];
}

@end

@implementation SDMapView (SDMapTransaction)

- (void)addAnnotation:(id <MKAnnotation>)annotation withinTransaction:(SDMapTransaction *)transaction
{
	[self confirmTransactionActions:transaction];

	[super addAnnotation:annotation];
}

- (void)addAnnotations:(NSArray *)annotations withinTransaction:(SDMapTransaction *)transaction
{
	[self confirmTransactionActions:transaction];

	[super addAnnotations:annotations];
}

- (void)removeAnnotation:(id <MKAnnotation>)annotation withinTransaction:(SDMapTransaction *)transaction
{
	[self confirmTransactionActions:transaction];

	[super removeAnnotation:annotation];
}

- (void)removeAnnotations:(NSArray *)annotations withinTransaction:(SDMapTransaction *)transaction
{
	[self confirmTransactionActions:transaction];

	[super removeAnnotations:annotations];
}

#pragma mark - Transactions

- (BOOL)isLockedForTransaction
{
	return _lockTransaction != nil;
}

- (BOOL)isLockedForTransaction:(SDMapTransaction *)transaction
{
	if (![self isLockedForTransaction]) return NO;

	return _lockTransaction == transaction;
}

- (void)lockForTransaction:(SDMapTransaction *)transaction
{
	NSParameterAssert(_lockTransaction == nil);

	_lockTransaction = transaction;
}

- (void)unlockForTransaction:(SDMapTransaction *)transaction
{
	NSParameterAssert(transaction != nil);
	NSParameterAssert(_lockTransaction == transaction);

	_lockTransaction = nil;
}

@end