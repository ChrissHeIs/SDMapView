//
// Created by dmitriy on 25.03.13.
//
#import <Foundation/Foundation.h>
#import "SDMapView.h"

@interface SDMapView (Package)

- (void)performAddAnnotation:(id <MKAnnotation>)annotation;
- (void)performAddAnnotations:(NSArray *)annotations;
- (void)performRemoveAnnotation:(id <MKAnnotation>)annotation;
- (void)performRemoveAnnotations:(NSArray *)annotations;

@end