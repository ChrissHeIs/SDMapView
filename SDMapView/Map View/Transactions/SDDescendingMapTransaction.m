//
// Created by dmitriy on 26.03.13.
//

#import "SDDescendingMapTransaction.h"
#import "SDMapView.h"
#import "SDQuadTree.h"
#import "NSValue+CLLocationCoordinate2D.h"
#import "NSMutableDictionary+SetInsertion.h"
#import "MKMapView+SDTransforms.h"
#import "SDMapView+SDMapTransaction.h"

@implementation SDDescendingMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView addAnnotations:[self.target allObjects] withinTransaction:self];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	[mapView lockForTransaction:self];

	NSUInteger capacity = views.count;
	NSMutableDictionary *affectedAnnotations = [[NSMutableDictionary alloc] initWithCapacity:capacity];

	NSMutableSet *affectedViews = [[NSMutableSet alloc] initWithCapacity:self.source.count];

	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
	{
		SDQuadTree *target = (id)view.annotation;

		[self.source enumerateObjectsUsingBlock:^(SDQuadTree *source, BOOL *s)
		{
			if (!MKMapRectContainsPoint(mapView.visibleMapRect, MKMapPointForCoordinate(source.coordinate))) return;

			if ([[target class] isSubclassOfClass:SDQuadTree.class] && [target contains:source])
			{
				[affectedViews addObject:view];
				[view setAlpha:0.f];

				NSValue *key = [NSValue valueWithCLLocationCoordinate2D:target.coordinate];
				[affectedAnnotations addObject:source toSetForKey:key];
			}
		}];
	}];

	[UIView animateWithDuration:0.3 animations:^
	{
		[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
		{
			for (id <MKAnnotation> annotation in set)
			{
				MKAnnotationView *view = [mapView viewForAnnotation:annotation];
				[view setTransform:[mapView translateTransformFrom:annotation.coordinate
																to:[key CLLocationCoordinate2DValue]
														withinView:view.superview]];
			}
		}];

		[affectedViews enumerateObjectsUsingBlock:^(UIView *view, BOOL *stop)
		{
			[view setAlpha:1.f];
		}];

	} completion:^(BOOL finished)
	{
		[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
		{
			for (id <MKAnnotation> annotation in set)
			{
				MKAnnotationView *view = [mapView viewForAnnotation:annotation];
				[view setTransform:CGAffineTransformIdentity];
			}
		}];

		[mapView removeAnnotations:[self.source allObjects] withinTransaction:self];
		[mapView unlockForTransaction:self];
	}];
}

@end