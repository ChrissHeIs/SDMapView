//
// Created by dmitriy on 26.03.13.
//
#import "SDRegularMapTransaction.h"

#import "SDMapView+SDMapTransaction.h"

@implementation SDRegularMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView removeAnnotations:[self.source allObjects] withinTransaction:self];
	[mapView addAnnotations:[self.target allObjects] withinTransaction:self];
}

@end