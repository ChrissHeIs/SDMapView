//
// Created by dmitriy on 26.03.13.
//
#import <MapKit/MKAnnotationView.h>

#import "SDQuadTree.h"
#import "SDAscendingMapTransaction.h"
#import "MKMapView+SDTransforms.h"
#import "SDMapView.h"
#import "SDMapView+SDMapTransaction.h"

const NSTimeInterval _SDAscendingMapTransactionDuration = 0.2;

@implementation SDAscendingMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView removeAnnotations:[self.source allObjects] withinTransaction:self];
	[mapView addAnnotations:[self.target allObjects] withinTransaction:self];
}

- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
	[mapView lockForTransaction:self];

	[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
	{
		id <MKAnnotation> target = view.annotation;

		[self.source enumerateObjectsUsingBlock:^(SDQuadTree *source, BOOL *s)
		{
			if ([[source class] isSubclassOfClass:SDQuadTree.class] && [source contains:target])
			{
				[view setTransform:[mapView translateTransformFrom:source.coordinate
																to:target.coordinate
													 withinView:view.superview]];
			}
		}];
	}];

	[UIView animateWithDuration:_SDAscendingMapTransactionDuration animations:^
	{
		[views enumerateObjectsUsingBlock:^(MKAnnotationView *view, NSUInteger idx, BOOL *stop)
		{
			[view setTransform:CGAffineTransformIdentity];
		}];

	} completion:^(BOOL finished)
	{
		[mapView unlockForTransaction:self];
	}];
}

@end