//
// Created by dmitriy on 26.03.13.
//

#ifndef SDMAP_TRANSACTION_UTILITY_H
#define SDMAP_TRANSACTION_UTILITY_H

#import <CoreLocation/CLLocation.h>
#import <UIKit/UIView.h>


CGAffineTransform SDCoordinateTranslate(CLLocationCoordinate2D from, CLLocationCoordinate2D to, UIView *view)
{
	CGPoint sourcePoint = [self convertCoordinate:fromCoordinate toPointToView:view];
	CGPoint targetPoint = [self convertCoordinate:toCoordinate toPointToView:view];

	CGPoint delta = (CGPoint){(sourcePoint.x - targetPoint.x), sourcePoint.y - targetPoint.y};

	return CGAffineTransformMakeTranslation(delta.x, delta.y);
}

#endif