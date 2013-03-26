//
// Created by dmitriy on 26.03.13.
//
#import "SDRegularMapTransaction.h"

#import "SDMapView+Package.h"

@implementation SDRegularMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView
{
	[mapView performRemoveAnnotations:[self.source allObjects]];
	[mapView performAddAnnotations:[self.target allObjects]];
}

@end