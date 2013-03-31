//
// Created by dmitriy on 26.03.13.
//
#import <MapKit/MKAnnotation.h>

@protocol SDAnnotation <MKAnnotation>

@property (nonatomic, readonly) NSInteger count;
- (BOOL)contains:(id <MKAnnotation>)annotation;
- (NSSet *)allAnnotations;
- (id)anyAnnotation; // for search optimization

@end