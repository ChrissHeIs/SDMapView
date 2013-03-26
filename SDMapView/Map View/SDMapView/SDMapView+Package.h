//
// Created by dmitriy on 25.03.13.
//
#import <Foundation/Foundation.h>
#import "SDMapView.h"

@class SDMapTransaction;

@interface SDMapView (Package)

- (void)performAddAnnotation:(id <MKAnnotation>)annotation;
- (void)performAddAnnotations:(NSArray *)annotations;
- (void)performRemoveAnnotation:(id <MKAnnotation>)annotation;
- (void)performRemoveAnnotations:(NSArray *)annotations;


- (BOOL)isLockedForTransaction;
- (BOOL)isLockedForTransaction:(SDMapTransaction *)transaction;
- (void)lockForTransaction:(SDMapTransaction *)transaction;
- (void)unlockForTransaction:(SDMapTransaction *)transaction;

@end