//
//  ViewController.m
//  SDMapView
//
//  Created by dshe on 03/23/13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "ViewController.h"
#import "SDMapView.h"
#import "Airport.h"

@interface ViewController () <MKMapViewDelegate>

@property (nonatomic, weak) MKMapView *mapView;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

	MKMapView *mapView = [[SDMapView alloc] initWithFrame:self.view.bounds];
	[self.view addSubview:mapView];

	[mapView setDelegate:self];
	[self setMapView:mapView];

	[self.mapView addAnnotations:[Airport allAirports]];
}

- (void)viewDidUnload
{
	[super viewDidUnload];

	[self setMapView:nil];
}

@end