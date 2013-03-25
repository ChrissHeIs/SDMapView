//
// Created by dmitriy on 24.03.13.
//
#import "SDMapView.h"

#import <MapKit/MapKit.h>

#import "SDQuadTree.h"
#import "SDDelegateMultiplier.h"

#import "NSMutableDictionary+SetInsertion.h"
#import "NSValue+CLLocationCoordinate2D.h"

const NSUInteger SDMapViewMaxZoomLevel = 20;
const double  SDMapViewMercatorRadius = 85445659.44705395;

@interface SDAnnotationsChange : NSObject

/**
* NSOrderedAscending equals to zoom in
* NSOrderedSame equals to no changes in zoom
* NSOrderedDescending equals to zoom out
*/
@property (nonatomic, readonly) NSComparisonResult order;


@property (nonatomic, copy, readonly) NSArray *sourceAnnotations;
@property (nonatomic, copy, readonly) NSArray *targetAnnotations;

- (id)initWithTargetAnnotations:(NSArray *)targetAnnotations
			  sourceAnnotations:(NSArray *)sourceAnnotations
						  order:(NSComparisonResult)order;

@end

@implementation SDAnnotationsChange

- (id)initWithTargetAnnotations:(NSArray *)targetAnnotations
			  sourceAnnotations:(NSArray *)sourceAnnotations
						  order:(NSComparisonResult)order
{
	self = [super init];
	if (self)
	{
		_sourceAnnotations = sourceAnnotations;
		_targetAnnotations = targetAnnotations;
		_order = order;
	}

	return self;
}

@end

#pragma mark - SDMapView

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

@property (nonatomic) NSUInteger zoomLevel;
- (void)updateZoomLevel;

- (void)processChange:(SDAnnotationsChange *)change;
- (void)enqueueChange:(SDAnnotationsChange *)change;
- (SDAnnotationsChange *)dequeueChange;

- (void)didZoomInWithChange:(SDAnnotationsChange *)change annotationViews:(NSArray *)views;
- (void)didZoomOutWithChange:(SDAnnotationsChange *)change annotationViews:(NSArray *)views;

- (CGAffineTransform)translateTransformFrom:(CLLocationCoordinate2D)fromCoordinate
										 to:(CLLocationCoordinate2D)toCoordinate
								 withinView:(UIView *)view;

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

- (void)enqueueChange:(SDAnnotationsChange *)change
{
	[_changes addObject:change];
}

- (SDAnnotationsChange *)dequeueChange
{
	if (_changes.count == 0) return nil;

	SDAnnotationsChange *change = [_changes objectAtIndex:0];

	[_changes removeObjectAtIndex:0];

	return change;
}

- (void)updateAnnotationsToLevel:(NSNumber *)toLevel fromLevel:(NSNumber *)fromLevel
{
	NSParameterAssert(toLevel != nil && fromLevel != nil);

	MKMapRect rect = self.visibleMapRect;
	if (rect.origin.x + 10.0 > MKMapRectWorld.size.width)
	{
		rect.origin.x = 0.0;
	}

	NSSet *targetAnnotations = [self.tree annotationsInRect:rect maxTraversalDepth:[toLevel unsignedIntegerValue]];
	NSMutableSet *sourceAnnotations = [[NSMutableSet alloc] initWithArray:[super annotations]];
	[sourceAnnotations minusSet:targetAnnotations];

	SDAnnotationsChange *change = [[SDAnnotationsChange alloc] initWithTargetAnnotations:[targetAnnotations allObjects]
																	   sourceAnnotations:[sourceAnnotations allObjects]
																				   order:[fromLevel compare:toLevel]];
	[self processChange:change];
}

- (void)processChange:(SDAnnotationsChange *)change
{
	[self enqueueChange:change];

	if (change.order != NSOrderedDescending)
	{
		[super removeAnnotations:change.sourceAnnotations];
	}

	[super addAnnotations:change.targetAnnotations];
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

#pragma mark - Annotation Views Animation

- (CGAffineTransform)translateTransformFrom:(CLLocationCoordinate2D)fromCoordinate
										 to:(CLLocationCoordinate2D)toCoordinate
								 withinView:(UIView *)view
{
	CGPoint sourcePoint = [self convertCoordinate:fromCoordinate toPointToView:view];
	CGPoint targetPoint = [self convertCoordinate:toCoordinate toPointToView:view];

	CGPoint delta = (CGPoint){(sourcePoint.x - targetPoint.x), sourcePoint.y - targetPoint.y};

	return CGAffineTransformMakeTranslation(delta.x, delta.y);
}

- (void)didZoomInWithChange:(SDAnnotationsChange *)change annotationViews:(NSArray *)views
{
	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
	{
		id <MKAnnotation> target = view.annotation;

		[change.sourceAnnotations enumerateObjectsUsingBlock:^(SDQuadTree *source, NSUInteger i, BOOL *s)
		{
			if ([[source class] isSubclassOfClass:SDQuadTree.class] && [source contains:target])
			{
				[view setTransform:[self translateTransformFrom:source.coordinate
															 to:target.coordinate
													 withinView:view.superview]];
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

- (void)didZoomOutWithChange:(SDAnnotationsChange *)change annotationViews:(NSArray *)views
{
	NSUInteger capacity = change.sourceAnnotations.count;
	NSMutableDictionary *affectedAnnotations = [[NSMutableDictionary alloc] initWithCapacity:capacity];

	NSMutableSet *affectedViews = [[NSMutableSet alloc] initWithCapacity:views.count];

	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
	{
		SDQuadTree *target = (id)view.annotation;

		[change.sourceAnnotations enumerateObjectsUsingBlock:^(SDQuadTree *source, NSUInteger i, BOOL *s)
		{
			if (!MKMapRectContainsPoint(self.visibleMapRect, MKMapPointForCoordinate(source.coordinate))) return;

			if ([[target class] isSubclassOfClass:SDQuadTree.class] && [target contains:source])
			{
				[affectedViews addObject:view];
				[view setAlpha:0.f];

				NSValue *key = [NSValue valueWithCLLocationCoordinate2D:target.coordinate];
				[affectedAnnotations addObject:source toSetForKey:key];
			}
		}];
	}];

	[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
	{
		for (id <MKAnnotation> annotation in set)
		{
			MKAnnotationView *view = [self viewForAnnotation:annotation];
			[view setTransform:[self translateTransformFrom:annotation.coordinate
														 to:[key CLLocationCoordinate2DValue]
												 withinView:view.superview]];
		}
	}];

	[UIView animateWithDuration:0.3 animations:^
	{
		[affectedViews enumerateObjectsUsingBlock:^(UIView *view, BOOL *stop)
		{
			[view setAlpha:1.f];
		}];

		[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
		{
			for (id <MKAnnotation> annotation in set)
			{
				MKAnnotationView *view = [self viewForAnnotation:annotation];
				[view setTransform:[self translateTransformFrom:annotation.coordinate
															 to:[key CLLocationCoordinate2DValue]
													 withinView:view.superview]];
			}
		}];

	} completion:^(BOOL finished)
	{
		[super removeAnnotations:change.sourceAnnotations];
	}];
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	SDAnnotationsChange *change = [self dequeueChange];

	if (change.sourceAnnotations.count == 0) return;

	switch (change.order)
	{
		case NSOrderedAscending:
			[self didZoomInWithChange:change annotationViews:views];
			break;

		case NSOrderedDescending:
			[self didZoomOutWithChange:change annotationViews:views];
			break;

		default:
			break;
	}
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