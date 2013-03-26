//
// Created by dmitriy on 26.03.13.
//
#import "SDMapTransaction.h"

@interface SDDescendingMapTransaction : SDMapTransaction

- (void)invokeWithMapView:(SDMapView *)mapView;
- (void)mapView:(SDMapView *)mapView didAddAnnotationViews:(NSArray *)views;

@end