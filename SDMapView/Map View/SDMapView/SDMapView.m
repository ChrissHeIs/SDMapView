//
// Created by dmitriy on 24.03.13.
//
#import "SDMapView.h"
#import "SDMapView+Package.h"

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


@property (nonatomic) NSUInteger annotationsLevel;
- (void)updateAnnotationsToLevel:(NSNumber *)toLevel;


@property (nonatomic) NSUInteger zoomLevel;
- (void)updateZoomLevel;

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
	[self updateZoomLevel];
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

- (void)updateZoomLevel
{
	CLLocationDegrees longitudeDelta = self.region.span.longitudeDelta;
	CGFloat mapWidthInPixels = self.bounds.size.width;

	double zoomScale = longitudeDelta * SDMapViewMercatorRadius * M_PI / (180.0 * mapWidthInPixels);
	NSUInteger zoomLevel = (NSUInteger)ceil(SDMapViewMaxZoomLevel - log2(zoomScale));

	[self setZoomLevel:MAX(0, zoomLevel)];
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

- (void)updateAnnotationsToLevel:(NSNumber *)toLevel
{
	NSParameterAssert(toLevel != nil);

	if ([self isLockedForTransaction]) return;

	MKMapRect rect = self.visibleMapRect;
	if (rect.origin.x + 10.0 > MKMapRectWorld.size.width)
	{
		rect.origin.x = 0.0;
	}

	NSUInteger level = [toLevel unsignedIntegerValue];
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
																	   targetLevel:toLevel
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
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateAnnotationsToLevel:) object:nil];

	[self performSelector:@selector(updateAnnotationsToLevel:)
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
	if ([self isLockedForTransaction])
	{
		NSParameterAssert([self isLockedForTransaction:self.activeTransaction]);
	}

	[self.activeTransaction mapView:self didAddAnnotationViews:views];
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	[_updateAnnotationsTimer invalidate];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	[self updateZoomLevel];

	NSInvocation *invocation = [NSInvocation invocationForTarget:self
														selector:@selector(updateAnnotationsToLevel:)
													   arguments:@(self.zoomLevel), nil];

	_updateAnnotationsTimer = [NSTimer timerWithTimeInterval:SDMapViewUpdateDelay invocation:invocation repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:_updateAnnotationsTimer forMode:NSRunLoopCommonModes];
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

@implementation SDMapView (Package)

- (void)performAddAnnotation:(id <MKAnnotation>)annotation
{
	[super addAnnotation:annotation];
}

- (void)performAddAnnotations:(NSArray *)annotations
{
	[super addAnnotations:annotations];
}

- (void)performRemoveAnnotation:(id <MKAnnotation>)annotation
{
	[super removeAnnotation:annotation];
}

- (void)performRemoveAnnotations:(NSArray *)annotations
{
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