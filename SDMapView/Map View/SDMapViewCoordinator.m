//
// Created by dmitriy on 24.03.13.
//
#import <MapKit/MapKit.h>
#import "SDMapViewCoordinator.h"


@implementation SDMapViewCoordinator

#pragma mark - Init

- (id)initWithTarget:(id <MKMapViewDelegate>)taget mapView:(MKMapView *)mapView
{
	_target = taget;
	_mapView = mapView;

	return self;
}

+ (instancetype)coordinatorWithTarget:(id <MKMapViewDelegate>)target mapView:(MKMapView *)mapView
{
	return [[self alloc] initWithTarget:target mapView:mapView];
}

#pragma mark -

@end