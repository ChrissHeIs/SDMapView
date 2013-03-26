//
// Created by dmitriy on 26.03.13.
//
#import "SDRegularMapTransaction.h"

#import "SDMapView+SDMapTransaction.h"

const NSTimeInterval _SDRegularMapTransactionDuration = 0.2;

@implementation SDRegularMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView addAnnotations:[self.target allObjects] withinTransaction:self];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	[mapView lockForTransaction:self];

	[views makeObjectsPerformSelector:@selector(setAlpha:) withObject:nil];

	[UIView animateWithDuration:_SDRegularMapTransactionDuration animations:^
	{
		[views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop)
		{
			[view setAlpha:1.f];
		}];

	} completion:^(BOOL finished)
	{
		[mapView removeAnnotations:[self.source allObjects] withinTransaction:self];
		[mapView unlockForTransaction:self];
	}];
}

@end