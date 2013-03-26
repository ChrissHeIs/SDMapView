//
// Created by dmitriy on 26.03.13.
//

#import "SDDescendingMapTransaction.h"
#import "SDMapView.h"

@implementation SDDescendingMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView removeAnnotations:[self.source allObjects]];
	[mapView addAnnotations:[self.target allObjects]];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	//	NSUInteger capacity = change.sourceAnnotations.count;
//	NSMutableDictionary *affectedAnnotations = [[NSMutableDictionary alloc] initWithCapacity:capacity];
//
//	NSMutableSet *affectedViews = [[NSMutableSet alloc] initWithCapacity:views.count];
//
//	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
//	{
//		SDQuadTree *target = (id)view.annotation;
//
//		[change.sourceAnnotations enumerateObjectsUsingBlock:^(SDQuadTree *source, NSUInteger i, BOOL *s)
//		{
//			if (!MKMapRectContainsPoint(self.visibleMapRect, MKMapPointForCoordinate(source.coordinate))) return;
//
//			if ([[target class] isSubclassOfClass:SDQuadTree.class] && [target contains:source])
//			{
//				[affectedViews addObject:view];
//				[view setAlpha:0.f];
//
//				NSValue *key = [NSValue valueWithCLLocationCoordinate2D:target.coordinate];
//				[affectedAnnotations addObject:source toSetForKey:key];
//			}
//		}];
//	}];
//
//	[UIView animateWithDuration:0.3 animations:^
//	{
//		[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
//		{
//			for (id <MKAnnotation> annotation in set)
//			{
//				MKAnnotationView *view = [self viewForAnnotation:annotation];
//				[view setTransform:[self translateTransformFrom:annotation.coordinate
//															 to:[key CLLocationCoordinate2DValue]
//													 withinView:view.superview]];
//			}
//		}];
//
//	} completion:^(BOOL finished)
//	{
//
//		[affectedAnnotations enumerateKeysAndObjectsUsingBlock:^(NSValue *key, NSMutableSet *set, BOOL *stop)
//		{
//			for (id <MKAnnotation> annotation in set)
//			{
//				MKAnnotationView *view = [self viewForAnnotation:annotation];
//				[view setTransform:CGAffineTransformIdentity];
//			}
//		}];
//
//		[super removeAnnotations:change.sourceAnnotations];
//
//		[affectedViews enumerateObjectsUsingBlock:^(UIView *view, BOOL *stop)
//		{
//			[view setAlpha:1.f];
//		}];
//	}];
}

@end