//
// Created by dmitriy on 24.03.13.
//
#import <MapKit/MapKit.h>
#import "SDMapView.h"
#import "SDQuadTree.h"

const NSUInteger SDMapViewMaxZoomLevel = 21;
const double  SDMapViewMercatorRadius = 85445659.44705395;


@interface SDMapView () <MKMapViewDelegate>

- (void)commonInitialization;

@property (nonatomic, strong) SDQuadTree *tree;

@property (nonatomic, weak) id <MKMapViewDelegate> targetDelegate;

- (void)updateVisibleAnnotations;
- (void)setNeedsUpdateVisibleAnnotations;

- (double)mapZoomLevel;

@end

@implementation SDMapView

#pragma mark - Init

- (void)commonInitialization
{
	[super setDelegate:self];
	[self setTree:[[SDQuadTree alloc] initWithRect:MKMapRectWorld maxDepth:SDMapViewMaxZoomLevel]];
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

	[super setDelegate:self];
//	[self setTargetDelegate:delegate];
}

//- (BOOL)respondsToSelector:(SEL)aSelector
//{
//	if ([super respondsToSelector:aSelector])
//	{
//		return YES;
//	}
//
//	return [self.targetDelegate respondsToSelector:aSelector];
//}
//
//- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
//{
//	NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
//	if (signature == nil)
//	{
//		signature = [(NSObject *)self.targetDelegate methodSignatureForSelector:aSelector];
//	}
//
//	return signature;
//}
//
//- (void)forwardInvocation:(NSInvocation *)anInvocation
//{
//	SEL selector = [anInvocation selector];
//
//	if ([self respondsToSelector:selector])
//	{
//		[anInvocation invokeWithTarget:self];
//	}
//
//	if ([self.targetDelegate respondsToSelector:selector])
//	{
//		[anInvocation invokeWithTarget:self.targetDelegate];
//	}
//}

#pragma mark - Zoom Level

- (double)mapZoomLevel
{
	CLLocationDegrees longitudeDelta = self.region.span.longitudeDelta;
	CGFloat mapWidthInPixels = self.bounds.size.width;
	double zoomScale = longitudeDelta * SDMapViewMercatorRadius * M_PI / (180.0 * mapWidthInPixels);
	double zoomer = SDMapViewMaxZoomLevel - log2( zoomScale );
	if ( zoomer < 0 ) zoomer = 0;

	return zoomer;
}

#pragma mark - Annotations Update

- (void)updateVisibleAnnotations
{
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	[super removeAnnotations:[super annotations]];

	[super addAnnotations:[[self.tree annotationsInRect:self.visibleMapRect maxTraversalDepth:ceil([self mapZoomLevel])] allObjects]];
}

- (void)setNeedsUpdateVisibleAnnotations
{
	SEL selector = @selector(updateVisibleAnnotations);
	[self performSelector:selector withObject:nil afterDelay:0.0 inModes:@[NSRunLoopCommonModes]];
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
	NSLog(@"%@", views);
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	NSLog(@"zoom level %f", [self mapZoomLevel]);

	[self setNeedsUpdateVisibleAnnotations];
}

- (void)addAnnotations:(NSArray *)annotations
{
	for (id <MKAnnotation> annotation in annotations)
	{
		[self.tree insert:annotation];
	}

	[self setNeedsUpdateVisibleAnnotations];
}

- (void)addAnnotation:(id <MKAnnotation>)annotation
{
	[self.tree insert:annotation];

	[self setNeedsUpdateVisibleAnnotations];
}

- (void)removeAnnotations:(NSArray *)annotations
{
	for (id <MKAnnotation> annotation in annotations)
	{
		[self.tree remove:annotation];
	}

	[self setNeedsUpdateVisibleAnnotations];
}

- (void)removeAnnotation:(id <MKAnnotation>)annotation
{
	[self.tree remove:annotation];

	[self setNeedsUpdateVisibleAnnotations];
}

- (NSArray *)annotations
{
	return [[self.tree allAnnotations] allObjects];
}

@end