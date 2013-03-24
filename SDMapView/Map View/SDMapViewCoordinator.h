//
// Created by dmitriy on 24.03.13.
//
#import <Foundation/Foundation.h>

#import <MapKit/MapKit.h>

@interface SDMapViewCoordinator : NSProxy <MKMapViewDelegate>

- (id)initWithTarget:(id <MKMapViewDelegate>)taget mapView:(MKMapView *)mapView;
+ (instancetype)coordinatorWithTarget:(id <MKMapViewDelegate>)target mapView:(MKMapView *)mapView;

@property (nonatomic, weak, readonly) IBOutlet MKMapView *mapView;
@property (nonatomic, weak, readonly) IBOutlet id <MKMapViewDelegate> target;



@end