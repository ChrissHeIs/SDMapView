//
// Created by dmitriy on 23.03.13.
//
#import <MapKit/MapKit.h>
#import "SDQuadTree.h"

const NSUInteger _SDQuadTreeLeavesCount = 4;

typedef enum
{
	SDQuadTreeChangeInsert,
	SDQuadTreeChangeRemove,
	SDQuadTreeChangeRemoveAll,
} SDQuadTreeChangeType;

@interface SDQuadTree ()
{
	NSArray *_leaves;

	__weak SDQuadTree *_parent;
}

- (id)initWithParent:(SDQuadTree *)parent rect:(MKMapRect)rect depth:(NSUInteger)depth maxDepth:(NSUInteger)maxDepth;

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic) MKMapPoint centroid;
- (void)updateCentroidWithPoint:(MKMapPoint)point changeType:(SDQuadTreeChangeType)changeType;
- (NSInteger)annotationDeltaForChangeType:(SDQuadTreeChangeType)changeType;

- (void)processChange:(id <MKAnnotation>)annotation ofType:(SDQuadTreeChangeType)type;

@property (nonatomic) NSInteger count;
- (void)updateCount;


@property (nonatomic, strong) NSMutableSet *annotations;
- (void)appendAnnotations:(NSMutableSet *)container inRect:(MKMapRect)rect maxTraversalDepth:(NSUInteger)maxTraversalDepth;
- (void)appendAnnotations:(NSMutableSet *)container;

- (void)subdivide;
- (MKMapRect)leaveRectAtIndex:(NSUInteger)index;
- (NSInteger)leaveIndexForAnnotation:(id <MKAnnotation>)annotation;

- (BOOL)containsLeave:(SDQuadTree *)leave;

@end

@implementation SDQuadTree

#pragma mark - Init

- (id)initWithParent:(SDQuadTree *)parent rect:(MKMapRect)rect depth:(NSUInteger)depth maxDepth:(NSUInteger)maxDepth
{
	NSAssert(!MKMapRectIsEmpty(rect), @"Rect can't be empty or null", nil);
	NSAssert(depth <= maxDepth, @"Depth %d can't be more that max depth %d", depth, maxDepth);

	self = [super init];
	if (self != nil)
	{
		_parent = parent;
		_rect = rect;
		_depth = depth;
		_maxDepth = maxDepth;
	}

	return self;
}

- (id)initWithRect:(MKMapRect)rect maxDepth:(NSUInteger)maxDepth
{
	return [self initWithParent:nil rect:rect depth:0 maxDepth:maxDepth];
}

#pragma mark - Properties

- (NSMutableSet *)annotations
{
	if (_annotations == nil)
	{
		_annotations = [[NSMutableSet alloc] initWithCapacity:SDQuadTreeAnnotationsLimit + 1];
	}

	return _annotations;
}

#pragma mark - Private

- (void)subdivide
{
	if (_leaves != nil) return;

	NSMutableArray *leaves = [[NSMutableArray alloc] initWithCapacity:_SDQuadTreeLeavesCount];
	for (NSUInteger i = 0; i < _SDQuadTreeLeavesCount; i++)
	{
		SDQuadTree *leave = [[[self class] alloc] initWithParent:self
															rect:[self leaveRectAtIndex:i]
														   depth:self.depth + 1
														maxDepth:self.maxDepth];
		[leaves addObject:leave];
	}

	_leaves = leaves;
}

- (MKMapRect)leaveRectAtIndex:(NSUInteger)index
{
	double width = _rect.size.width * 0.5;
	double height = _rect.size.height * 0.5;

	return (MKMapRect)
	{
		_rect.origin.x + (index & 1) * width,
		_rect.origin.y + ((index & 2) >> 1) * height,
		width,
		height
	};
}

/**
* Leaves could be described in next way:
* 00 | 01
* 10 | 11
* It means, that by 'OR' operation we can reach any leave:)
*/
- (NSInteger)leaveIndexForAnnotation:(id <MKAnnotation>)annotation
{
	MKMapPoint point = MKMapPointForCoordinate(annotation.coordinate);

	if (!MKMapRectContainsPoint(_rect, point)) return NSNotFound;

	NSUInteger index = 0;
	if (MKMapRectGetMidX(self.rect) < point.x)
	{
		index |= 1; // | 01
	}
	if (MKMapRectGetMidY(self.rect) < point.y)
	{
		index |= 2; // | 10
	}

	return index;
}

#pragma mark - Annotations Count

- (void)setCount:(NSInteger)count
{
	if (_count == count) return;

	[self willChangeValueForKey:@"count"];
	_count = count;
	[self didChangeValueForKey:@"count"];
}

- (void)updateCount
{
	__block NSUInteger leavesCount = _annotations.count;

	for (SDQuadTree *leave in _leaves)
	{
		leavesCount += leave.count;
	}

	[self setCount:leavesCount];
}

#pragma mark - Centroid

- (void)setCentroid:(MKMapPoint)centroid
{
	if (MKMapPointEqualToPoint(_centroid, centroid)) return;

	_centroid = centroid;

	CLLocationCoordinate2D coordinate2D = MKCoordinateForMapPoint(centroid);
	[self setCoordinate:coordinate2D];
}

- (NSInteger)annotationDeltaForChangeType:(SDQuadTreeChangeType)changeType
{
	switch (changeType)
	{
		case SDQuadTreeChangeInsert:	return 1;
		case SDQuadTreeChangeRemove:	return -1;
		case SDQuadTreeChangeRemoveAll:	return -self.count;
	}
}

- (void)updateCentroidWithPoint:(MKMapPoint)point changeType:(SDQuadTreeChangeType)changeType
{
	NSInteger delta = [self annotationDeltaForChangeType:changeType];

	if (self.count + delta <= 0)
	{
		[self setCentroid:(MKMapPoint){INFINITY, INFINITY}];
		return;
	}

	MKMapPoint centroid = self.centroid;
	double count = self.count;
	double endingCount = count + delta;
	double sign = delta >= 0 ? 1 : -1;
	// ((среднее значени * количество) + новое значение) / количество + 1
	// ((среднее значени * количество) - старое значение) / количество - 1
	centroid.x = ((centroid.x * count) + (sign * point.x)) / endingCount;
	centroid.y = ((centroid.y * count)+ (sign * point.y)) / endingCount;

	[self setCentroid:centroid];
}

#pragma mark - Changes Processing

- (void)processChange:(id <MKAnnotation>)annotation ofType:(SDQuadTreeChangeType)type
{
	[self updateCentroidWithPoint:MKMapPointForCoordinate(annotation.coordinate) changeType:type];

	[self updateCount];

#ifdef SDQUADTREE_TRIM_EMPTY_BRANCH
	if (self.count == 0)
	{
		_leaves = nil;
	}
#endif
}

#pragma mark - Insert

- (void)insert:(id <MKAnnotation>)annotation
{
	NSAssert(annotation != nil, @"Illegal annotation for insert:%@", annotation);
	NSAssert(![[annotation class] isSubclassOfClass:[SDQuadTree class]], @"Illegal insert class:%@", annotation);

	if (!MKMapRectContainsPoint(self.rect, MKMapPointForCoordinate(annotation.coordinate))) return;

	if (_leaves != nil)
	{
		[[_leaves objectAtIndex:[self leaveIndexForAnnotation:annotation]] insert:annotation];
	}
	else
	{
		[self.annotations addObject:annotation];

		if (self.depth < self.maxDepth && SDQuadTreeAnnotationsLimit < self.annotations.count)
		{
			[self subdivide];

			for (id <MKAnnotation> obj in self.annotations)
			{
				[[_leaves objectAtIndex:[self leaveIndexForAnnotation:obj]] insert:obj];
			}

			[self setAnnotations:nil];
		}
	}

	[self processChange:annotation ofType:SDQuadTreeChangeInsert];
}

#pragma mark - Remove

- (BOOL)remove:(id <MKAnnotation>)annotation
{
	NSAssert(annotation != nil, @"Illegal annotation for remove:%@", annotation);
	NSAssert(![annotation.class isSubclassOfClass:[SDQuadTree class]], @"Illegal remove class:%@", annotation);

	BOOL annotationRemoved = NO;
	if (_leaves != nil)
	{
		NSInteger leaveIndex = [self leaveIndexForAnnotation:annotation];
		if (leaveIndex != NSNotFound)
		{
			annotationRemoved = [[_leaves objectAtIndex:leaveIndex] remove:annotation];
		}
	}
	else
	{
		NSUInteger count = _annotations.count;
		[_annotations removeObject:annotation];
		annotationRemoved = count < _annotations.count;
	}

	if (annotationRemoved)
	{
		[self processChange:annotation ofType:SDQuadTreeChangeRemove];
	}

	return annotationRemoved;
}

- (void)removeAll
{
	[self setAnnotations:nil];

	for (SDQuadTree *leave in _leaves)
	{
		[leave removeAll];
	}

	[self processChange:nil ofType:SDQuadTreeChangeRemoveAll];
}

#pragma mark - Traversal

- (void)appendAnnotations:(NSMutableSet *)container inRect:(MKMapRect)rect maxTraversalDepth:(NSUInteger)maxTraversalDepth
{
	if (!MKMapRectIntersectsRect(self.rect, rect) || self.count == 0) return;

	if (maxTraversalDepth < self.depth)
	{
		[container addObject:self];
		return;
	}

	if (_leaves != nil)
	{
		for (SDQuadTree *leave in _leaves)
		{
			[leave appendAnnotations:container inRect:rect maxTraversalDepth:maxTraversalDepth];
		}

		return;
	}

	switch (self.count)
	{
		case 1 ... SDQuadTreeAnnotationsLimit:
			[container unionSet:_annotations];
			break;

		default:
			[container addObject:self];
			break;

	}
}

#pragma mark - Data Access

- (BOOL)containsLeave:(SDQuadTree *)leave
{
	if (self == leave) return YES;

	while (leave != nil)
	{
		if (leave->_parent == self) return YES;

		leave = leave->_parent;
	}

	return NO;
}

- (BOOL)contains:(id <MKAnnotation>)annotation
{
	if ([annotation.class isSubclassOfClass:[SDQuadTree class]])
	{
		return [self containsLeave:(SDQuadTree *)annotation];
	}

	if (_leaves != nil)
	{
		NSInteger leaveIndex = [self leaveIndexForAnnotation:annotation];
		if (leaveIndex != NSNotFound)
		{
			return [[_leaves objectAtIndex:leaveIndex] contains:annotation];
		}

		return NO;
	}

	return [_annotations containsObject:annotation];
}

- (NSSet *)annotationsInRect:(MKMapRect)rect
{
	return [self annotationsInRect:rect maxTraversalDepth:self.maxDepth];
}

- (NSSet *)annotationsInRect:(MKMapRect)rect maxTraversalDepth:(NSUInteger)maxTraversalDepth
{
	NSMutableSet *results = [NSMutableSet new];

	[self appendAnnotations:results inRect:rect maxTraversalDepth:maxTraversalDepth];

	return results;
}

#pragma mark - All Annotations

- (void)appendAnnotations:(NSMutableSet *)container
{
	if (self.count == 0) return;

	if (_leaves != nil)
	{
		for (SDQuadTree *leave in _leaves)
		{
			[leave appendAnnotations:container];
		}
	}

	[container unionSet:_annotations];
}

- (NSSet *)allAnnotations
{
	NSMutableSet *results = [NSMutableSet new];

	[self appendAnnotations:results];

	return results;
}

#pragma mark - Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"\n%@ %p\ncount:%d, depth:%d, max depth:%d\nlat:%G, lng:%G\n",
			NSStringFromClass(self.class),(__bridge void *)self,
			self.count, self.depth, self.maxDepth,
			self.coordinate.latitude, self.coordinate.longitude];
}

@end