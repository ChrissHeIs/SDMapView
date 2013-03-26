//
// Created by dmitriy on 23.03.13.
//
#import <Foundation/Foundation.h>

#import <MapKit/MKGeometry.h>
#import <MapKit/MKAnnotation.h>

#import "SDAnnotation.h"

#define SDQUADTREE_TRIM_EMPTY_BRANCH 1

/**
* When this limit exceed - tree will subdivide itself.
* 1 means PR Quadtree.
*/
static const NSUInteger SDQuadTreeAnnotationsLimit = 1;

@interface SDQuadTree : NSObject <SDAnnotation>

- (id)initWithRect:(MKMapRect)rect maxDepth:(NSUInteger)maxDepth;

@property (nonatomic, readonly) NSUInteger maxDepth;
@property (nonatomic, readonly) NSUInteger depth;
@property (nonatomic, readonly) MKMapRect rect;

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) NSInteger count;

- (void)insert:(id <MKAnnotation>)annotation;
- (BOOL)remove:(id <MKAnnotation>)annotation;

- (void)removeAll;

- (BOOL)contains:(id <MKAnnotation>)annotation;

- (NSSet *)annotationsInRect:(MKMapRect)rect;
- (NSSet *)annotationsInRect:(MKMapRect)rect maxTraversalDepth:(NSUInteger)maxTraversalDepth;

- (NSSet *)allAnnotations;

- (NSString *)description;

@end