//
// Created by dmitriy on 24.03.13.
//
#import <MapKit/MapKit.h>
#import "SDMapView.h"
#import "SDQuadTree.h"
#import "SDDelegateMultiplier.h"


const NSUInteger SDMapViewMaxZoomLevel = 20;
const double  SDMapViewMercatorRadius = 85445659.44705395;

@interface SDAnnotationsChange : NSObject

@property (nonatomic, strong, readonly) NSNumber *targetLevel;
@property (nonatomic, strong, readonly) NSNumber *sourceLevel;
@property (nonatomic, copy, readonly) NSArray *sourceAnnotations;
@property (nonatomic, copy, readonly) NSArray *targetAnnotations;

- (id)initWithTargetAnnotations:(NSArray *)targetAnnotations
					targetLevel:(NSNumber *)targetLevel
			  sourceAnnotations:(NSArray *)sourceAnnotations
					sourceLevel:(NSNumber *)sourceLevel;

@end

@implementation SDAnnotationsChange

- (id)initWithTargetAnnotations:(NSArray *)targetAnnotations
					targetLevel:(NSNumber *)targetLevel
			  sourceAnnotations:(NSArray *)sourceAnnotations
					sourceLevel:(NSNumber *)sourceLevel
{
	self = [super init];
	if (self)
	{
		_targetLevel = targetLevel;
		_sourceAnnotations = sourceAnnotations;
		_targetAnnotations = targetAnnotations;
		_sourceLevel = sourceLevel;
	}

	return self;
}

@end

@interface SDMapView () <MKMapViewDelegate>
{
	__weak id <MKMapViewDelegate> _targetDelegate;
	SDDelegateMultiplier *_delegateMultiplier;

	__weak NSInvocation *_updateInvocation;
	NSMutableArray *_changes;
}

- (void)commonInitialization;

@property (nonatomic, strong) SDQuadTree *tree;

- (void)updateAnnotationsToLevel:(NSNumber *)toLevel fromLevel:(NSNumber *)fromLevel;
- (void)setNeedsUpdateAnnotationsToLevel:(NSNumber *)toLevel fromLevel:(NSNumber *)fromLevel;
- (void)setNeedsUpdateAnnotations;

@property (nonatomic) NSUInteger zoomLevel;
- (void)updateZoomLevel;

- (void)registerChange:(SDAnnotationsChange *)change;
- (SDAnnotationsChange *)unregisterChange;

@end

@implementation SDMapView

#pragma mark - Init

- (void)commonInitialization
{
	_delegateMultiplier = [[SDDelegateMultiplier alloc] initWithTargets:@[self]];
	[super setDelegate:(id)_delegateMultiplier];

	[self setTree:[[SDQuadTree alloc] initWithRect:MKMapRectWorld maxDepth:SDMapViewMaxZoomLevel]];

	[self setZoomLevel:NSUIntegerMax];

	_changes = [NSMutableArray new];
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
	return;

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

- (void)registerChange:(SDAnnotationsChange *)change
{
	[_changes addObject:change];
}

- (SDAnnotationsChange *)unregisterChange
{
	if (_changes.count == 0) return nil;

	SDAnnotationsChange *change = [_changes objectAtIndex:0];

	[_changes removeObjectAtIndex:0];

	return change;
}

- (void)updateAnnotationsToLevel:(NSNumber *)toLevel fromLevel:(NSNumber *)fromLevel
{
	MKMapRect rect = self.visibleMapRect;
	if (MKMapRectWorld.size.width <= rect.origin.x + 10)
	{
		rect.origin.x = 0.0;
	}
	NSArray *sourceAnnotations = [super annotations];
	NSArray *targetAnnotations = [[self.tree annotationsInRect:rect maxTraversalDepth:[toLevel unsignedIntegerValue]] allObjects];

	SDAnnotationsChange *change = [[SDAnnotationsChange alloc] initWithTargetAnnotations:targetAnnotations
																			 targetLevel:toLevel
																	   sourceAnnotations:sourceAnnotations
																			 sourceLevel:fromLevel];
	[self registerChange:change];

	[super removeAnnotations:sourceAnnotations];
	[super addAnnotations:targetAnnotations];
}

- (void)setNeedsUpdateAnnotationsToLevel:(NSNumber *)toLevel fromLevel:(NSNumber *)fromLevel
{
	if (_updateInvocation != nil)
	{
		[_updateInvocation setArgument:&toLevel atIndex:2];
		[_updateInvocation setArgument:&fromLevel atIndex:3];

		return;
	}

	SEL updateSelector = @selector(updateAnnotationsToLevel:fromLevel:);
	[NSInvocation cancelPreviousPerformRequestsWithTarget:_updateInvocation selector:updateSelector object:nil];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:updateSelector]];
	[invocation setSelector:updateSelector];
	[invocation setTarget:self];
	[invocation setArgument:&toLevel atIndex:2];
	[invocation setArgument:&fromLevel atIndex:3];
	[invocation retainArguments];

	[invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0 inModes:@[NSRunLoopCommonModes]];

	_updateInvocation = invocation;
}

- (void)setNeedsUpdateAnnotations
{
	NSNumber *level = @(self.zoomLevel);
	[self setNeedsUpdateAnnotationsToLevel:level fromLevel:level];
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
	SDAnnotationsChange *change = [self unregisterChange];

	if (change.sourceAnnotations.count == 0) return;

	NSComparisonResult order = [change.sourceLevel compare:change.targetLevel];
	if (order == NSOrderedSame) return;

	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
	{
		[change.sourceAnnotations enumerateObjectsUsingBlock:^(SDQuadTree *annotation, NSUInteger idx, BOOL *stop)
		{
			SDQuadTree *target = (id)view.annotation;
			SDQuadTree *source = annotation;
			if (order == NSOrderedDescending)
			{
				target = source;
				source = (id)view.annotation;
			}

			if ([[source class] isSubclassOfClass:SDQuadTree.class] && [source contains:target])
			{
				CGPoint sourcePoint = [self convertCoordinate:source.coordinate toPointToView:view.superview];
				CGPoint targetPoint = [self convertCoordinate:target.coordinate toPointToView:view.superview];

				CGPoint delta = (CGPoint){(sourcePoint.x - targetPoint.x), sourcePoint.y - targetPoint.y};

				[view setTransform:CGAffineTransformMakeTranslation(delta.x, delta.y)];
			}
		}];
	}];

	[UIView animateWithDuration:0.3 animations:^
	{
		[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
		{
			[view setTransform:CGAffineTransformIdentity];
		}];
	}];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	NSNumber *previousZoomLevel = @(self.zoomLevel);
	[self updateZoomLevel];
	[self setNeedsUpdateAnnotationsToLevel:@(self.zoomLevel) fromLevel:previousZoomLevel];
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