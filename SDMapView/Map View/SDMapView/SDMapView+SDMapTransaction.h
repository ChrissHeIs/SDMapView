//
// Created by dmitriy on 25.03.13.
//
#import <Foundation/Foundation.h>
#import "SDMapView.h"

@class SDMapTransaction;

@interface SDMapView (SDMapTransaction)

/**
* Transaction can add annotations ONLY by this methods.
* Usage of public addAnnotation: addAnnotations: removeAnnotation: removeAnnotations: will leads to assertion.
*/
- (void)addAnnotation:(id <MKAnnotation>)annotation withinTransaction:(SDMapTransaction *)transaction;
- (void)addAnnotations:(NSArray *)annotations withinTransaction:(SDMapTransaction *)transaction;
- (void)removeAnnotation:(id <MKAnnotation>)annotation withinTransaction:(SDMapTransaction *)transaction;
- (void)removeAnnotations:(NSArray *)annotations withinTransaction:(SDMapTransaction *)transaction;

/**
* Transaction lock should be used only if transaction is continuous.
* For example: transaction modify somehow map annotations and after animation completion
* perform additional changes. This require immutable map state.
* For this example you have to:
* [mapView lockForTransaction:self];
*
* // perform animation
*
* // on animation completion
* [mapView unlockForTransaction:self];
*/

- (BOOL)isLockedForTransaction;
- (BOOL)isLockedForTransaction:(SDMapTransaction *)transaction;
- (void)lockForTransaction:(SDMapTransaction *)transaction;
- (void)unlockForTransaction:(SDMapTransaction *)transaction;

@end