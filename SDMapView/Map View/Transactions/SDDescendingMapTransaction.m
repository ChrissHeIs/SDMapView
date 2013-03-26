//
// Created by dmitriy on 26.03.13.
//

#import "SDDescendingMapTransaction.h"
#import "SDMapView.h"
#import "SDMapView+SDMapTransaction.h"

const NSTimeInterval _SDDescendingMapTransactionDuration = 0.2;

@implementation SDDescendingMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView addAnnotations:[self.target allObjects] withinTransaction:self];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	[mapView lockForTransaction:self];

	NSMutableSet *removingViews = [[NSMutableSet alloc] initWithCapacity:self.source.count];
	[self.source enumerateObjectsUsingBlock:^(id <MKAnnotation> obj, BOOL *stop)
	{
		UIView *view = [mapView viewForAnnotation:obj];
		if (view != nil)
		{
			[removingViews addObject:view];
		}
	}];

	[views makeObjectsPerformSelector:@selector(setAlpha:) withObject:nil];

	[UIView animateWithDuration:_SDDescendingMapTransactionDuration animations:^
	{
		[removingViews makeObjectsPerformSelector:@selector(setAlpha:) withObject:nil];

		[views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop)
		{
			[view setAlpha:1.f];
		}];

	} completion:^(BOOL finished)
	{
		[removingViews enumerateObjectsUsingBlock:^(UIView *view, BOOL *stop)
		{
			[view setAlpha:1.f];
		}];

		[mapView removeAnnotations:[self.source allObjects] withinTransaction:self];
		[mapView unlockForTransaction:self];
	}];
}

@end