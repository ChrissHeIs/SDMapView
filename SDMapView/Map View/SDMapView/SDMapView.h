//
// Created by dmitriy on 24.03.13.
//
#import <Foundation/Foundation.h>

#import <MapKit/MKMapView.h>

@class SDMapTransactionFactory;

@interface SDMapView : MKMapView

- (void)setNeedsUpdateAnnotations;

@property (nonatomic, strong) SDMapTransactionFactory *transactionFactory;

@end