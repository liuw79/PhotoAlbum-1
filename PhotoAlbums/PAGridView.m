//
//  PAGridView.m
//  PhotoAlbums
//
//  Created by zaker-7 on 12-8-17.
//
//

#import "PAGridView.h"
#import <QuartzCore/QuartzCore.h>
#define TotalColumnHR 7
#define TotalColumnVR 5

static const CGFloat kDefaultAnimationDuration = 0.3;
static const UIViewAnimationOptions kDefaultAnimationOptions = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

@interface PAGridView()
-(CGRect) makeFrameFromIndex:(int) i;
-(void) setUpCellViewFrame;
-(void) layoutSubviews;
-(void) setFrame:(CGRect)f;
-(NSInteger)getCurrentRowWithTagNum:(NSInteger)num;
-(NSInteger)getCurrentColumnWithTagNum:(NSInteger)num;
- (void)receivedMemoryWarningNotification:(NSNotification *)notification;
-(void)setUpSingleCellViewFrame;

@end

@implementation PAGridView
@synthesize cellArray = _cellArray;
@synthesize pageRow = _pageRow;
@synthesize pageCol = _pageCol;
@synthesize padding = _padding;
@synthesize scrollView = _scrollView;
@synthesize orientationIsPortrait = _orientationIsPortrait;
@synthesize dataSource = _dataSource;
@synthesize gridViewCellSize = _gridViewCellSize;
@synthesize gridViewCellNumber = _gridViewCellNumber;
@synthesize lastPosition = _lastPosition;
@synthesize lastScale = _lastScale;
@synthesize preScale = _preScale;
@synthesize deltaScale = _deltaScale;
@synthesize lastRotation = _lastRotation;
@synthesize contentHeight = _contentHeight;
@synthesize contentWidth = _contentWidth;
@synthesize ifSnapShotMode = _ifSnapShotMode;

#pragma mark - ======================Dealloc===============================
-(void) dealloc{
    
    if (_cellArray) {
        [_cellArray release];
        _cellArray = nil;
    }
    
    if (_scrollView) {
        [_scrollView release];
        _scrollView = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    [super dealloc];
}

#pragma mark - ======================ClassMethods==========================

- (void)initializeScrollView
{
    _scrollView = [[UIScrollView alloc]initWithFrame:self.bounds];
    [_scrollView setBackgroundColor:[UIColor clearColor]];
    _scrollView.contentSize = CGSizeMake(self.bounds.size.width, self.bounds.size.height);
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.scrollEnabled = YES;
    _scrollView.clipsToBounds = NO;
    _scrollView.delegate = self;
    [_scrollView setCanCancelContentTouches:YES];
    [self addSubview:_scrollView];
    [_scrollView release];
}

-(void)initializeData
{
    //**********初始化数据***********//
    self.lastScale = 1.0;
    self.lastRotation = 0.0;
    
    NSMutableArray* t_cellArr=[[NSMutableArray alloc] init];
    self.cellArray = t_cellArr;
    [t_cellArr release];
    
    //***************添加内存不足的监听**************//
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)receivedMemoryWarningNotification:(NSNotification *)notification
{
    NSLog(@"Receive memory warning!");
}

//*******************为PAGridViewCell添加旋转，捏合，移动和点击的手势识别****************//
-(void)addGestureRecognizersWithCell:(PAGridViewCell *)cell
{
    
    //*************添加UIRotateGestreRecognizer*******************//
    UIRotationGestureRecognizer *rotateGesture = [[UIRotationGestureRecognizer alloc]initWithTarget:self action:@selector(rotateGestureUpdated:)];
    rotateGesture.delegate = self;
    [cell addGestureRecognizer:rotateGesture];
    [rotateGesture release];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc]initWithTarget:self action:@selector(pinchGestureUpdated:)];
    pinchGesture.delegate = self;
    [cell addGestureRecognizer:pinchGesture];
    [pinchGesture release];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGestureUpdated:)];
    panGesture.delegate = self;
    [panGesture setMaximumNumberOfTouches:2];
    [panGesture setMinimumNumberOfTouches:2];
    [cell addGestureRecognizer:panGesture];
    [panGesture release];
    
    UITapGestureRecognizer* t_tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureUpdated:)];
    t_tapGesture.delegate = self;
    t_tapGesture.numberOfTapsRequired = 1;
    t_tapGesture.numberOfTouchesRequired = 1;
    [t_tapGesture requireGestureRecognizerToFail:panGesture];
    [cell addGestureRecognizer:t_tapGesture];
    [t_tapGesture release];
    
}

//************************调用Delegate方法，刷新数据******************************//
-(void)reloadData
{
    
    if ([_dataSource respondsToSelector:@selector(updateOrientationState)]) {
        
        self.orientationIsPortrait = [_dataSource updateOrientationState];
        
        //********************更新ContentView数据********************//
        [self setNeedsLayout];
    }
    
    if ([_dataSource respondsToSelector:@selector(numberOfItemsInGridView:)]) {
        
        self.gridViewCellNumber = [_dataSource numberOfItemsInGridView:self];
    }
    
    if ([_dataSource respondsToSelector:@selector(sizeForItemsInGridView:)]) {
        
        self.gridViewCellSize = [_dataSource sizeForItemsInGridView:self];
    }
    
    if ([_dataSource respondsToSelector:@selector(numberOfPageRow)]) {
        
        self.pageRow = [_dataSource numberOfPageRow];
    }
    
    if ([_dataSource respondsToSelector:@selector(numberOfPageColumn)]) {
        
        self.pageCol = [_dataSource numberOfPageColumn];
    }
    
    if ([_dataSource respondsToSelector:@selector(paddingForCell)]) {
        
        self.padding = [_dataSource paddingForCell];
        
        CGSize size = [self setScrollViewContentSizeWithWidth:_gridViewCellSize.width andHeight:(_gridViewCellSize.height + _padding)];
        [_scrollView setContentSize:size];

    }
    
    if ([_dataSource respondsToSelector:@selector(PAGridView:cellForItemAtIndex:)]) {
        
        //**********清空CellArray的数据，移除scrollView的sunbViews**************//
        [self.cellArray removeAllObjects];
        
        for (PAGridViewCell *cell in [_scrollView subviews]) {
            
            [cell removeFromSuperview];
        }
        
        //************重设 PaGridViewCell's 属性数据*****************//
        CGRect tFrame;
        int currentRow, currentColumn;
        for (int i = 0; i < self.gridViewCellNumber; i++) {
            
            PAGridViewCell *cell = [_dataSource PAGridView:self cellForItemAtIndex:i];
            tFrame=[self makeFrameFromIndex:i + 1];
            [cell setFrame:tFrame];
            currentRow = [self getCurrentRowWithTagNum:cell.tag + 1];
            currentColumn = [self getCurrentColumnWithTagNum:cell.tag + 1];
            cell.row = currentRow;
            cell.column = currentColumn;
            
            //**************为每个cell添加手势识别*****************//
            [self addGestureRecognizersWithCell:cell];
            
            //**************添加cell到cellArray数组中*****************//
            [self.cellArray addObject:cell];
            [cell setUserInteractionEnabled:YES];
            [_scrollView addSubview:cell];
            
            //*****************根据设备转向更新Cell的Frame****************************//
            if (self.orientationIsPortrait) {
                
            }else
            {
                
            }
            
        }
        
    }
    
}

-(CGRect) makeFrameFromIndex:(int) i{
    
    CGRect reRect=CGRectZero;
    
    reRect.size = CGSizeMake(self.gridViewCellSize.width, self.gridViewCellSize.height);

    CGSize bSize = _scrollView.contentSize;
    
    CGPoint centerPoint = CGPointZero;
    
    float t_width = bSize.width/_pageCol;
    float t_height = bSize.height/_pageRow;
    
    int t_col, t_row;
    
    //***********Get Column***********//
    if (i % _pageCol == 0) {
        
        t_col = _pageCol;
        
    }else {
        
        t_col = i % _pageCol;
    }
    
    //***********Get Row***************//
    if (i % _pageCol == 0) {
        
        t_row = i/_pageCol;
        
    }else
    {
        t_row = i/_pageCol +1;
    }

    centerPoint.x = t_width * t_col - (t_width/2);
    centerPoint.y = t_height * t_row - (t_height/2);
            
    reRect.origin.x = centerPoint.x - t_width/2;
    reRect.origin.y = centerPoint.y - t_height/2;
        
    reRect = CGRectInset(reRect, _padding, _padding);
    
    return reRect;
}


-(NSInteger)getCurrentRowWithTagNum:(NSInteger)num
{
    int t_row;
    
    if (num%_pageCol == 0) {
        
        t_row = num/_pageCol;
        
    }else
    {
        t_row = num/_pageCol +1;
    }
        
    return t_row;
}

-(NSInteger)getCurrentColumnWithTagNum:(NSInteger)num
{
    int t_col;
    
    if (num % _pageCol == 0) {
        
        t_col = _pageCol;
        
    }else {
        
        t_col = num % _pageCol;
    }
    
    return t_col;
}

-(void)setUpCellViewFrame{
        
    PAGridViewCell* tCell;
    CGRect reRect;
    for (int i = 0,len = [_cellArray count]; i<len; i++) {
        
        tCell = [_cellArray objectAtIndex:i];
        reRect = [self makeFrameFromIndex:i+1];
        tCell.frame = reRect;
    }
}

-(void)setUpSingleCellViewFrame {
    
    PAGridViewCell* tCell;
    for (int i = 0,len = [_cellArray count]; i<len; i++) {
        
        tCell = [_cellArray objectAtIndex:i];
        tCell.frame = CGRectMake(0, 0, _gridViewCellSize.width, _gridViewCellSize.height);
    }
}

-(CGSize)setScrollViewContentSizeWithWidth:(float)width andHeight:(float)height
{
    float sizeWidth = _pageCol * width;
    float sizeHeight = _pageRow * height;

    return CGSizeMake(sizeWidth, sizeHeight);
}

-(void) layoutSubviews{
    
    if (_ifSnapShotMode) {
        
        [self setUpSingleCellViewFrame];
        [_scrollView setFrame:CGRectMake(_scrollView.frame.origin.x, _scrollView.frame.origin.y, _gridViewCellSize.width, _gridViewCellSize.height)];
        
    }else
    {
        [self setUpCellViewFrame];
        [_scrollView setFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        
    }
    
}

-(void) setFrame:(CGRect)f{
    BOOL changed = CGSizeEqualToSize(self.scrollView.contentSize, f.size);
    [super setFrame:f];
    if (changed) {
        [self setNeedsLayout];
    }
}

#pragma mark - ======================UIScrollViewDelegte=======================================
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    //    NSLog(@"The scrollView's content offset is %@", NSStringFromCGPoint(scrollView.contentOffset));
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    //    NSLog(@"EndDecelerating content offset is %@", NSStringFromCGPoint(scrollView.contentOffset));
}

#pragma mark - ======================UIGestureRecognizerDelegate==================================
-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer.view == otherGestureRecognizer.view) {
        
        return YES;
    }
    
    return NO;
}

-(BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    
    return YES;
}

-(void)tapGestureUpdated:(UITapGestureRecognizer *)tapGesture
{
    
    switch (tapGesture.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            
            //****************延迟0.2秒执行transformingGestureDidFinishWithGesture函数***************//
            [self performSelector:@selector(transformingGestureDidFinishWithGesture:) withObject:tapGesture afterDelay:0.2];
            
            //*********允许滚动操作********//
            _scrollView.scrollEnabled = YES;
            
            break;
        }
            
        case UIGestureRecognizerStateBegan:
        {
            
            //*********禁止滚动操作********//
            _scrollView.scrollEnabled = NO;
            
            break;
        }
            
        default:
            break;
    }
}

-(void)rotateGestureUpdated: (UIRotationGestureRecognizer *)rotateGesture
{
    switch (rotateGesture.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            
            //****************延迟0.2秒执行transformingGestureDidFinishWithGesture函数***************//
            [self performSelector:@selector(transformingGestureDidFinishWithGesture:) withObject:rotateGesture afterDelay:0.2];
            
            break;
        }
            
        case UIGestureRecognizerStateBegan:
        {
            
            //*********禁止滚动操作********//
            _scrollView.scrollEnabled = NO;
            self.lastRotation = rotateGesture.rotation;
            
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            
            //设置PAGridViewCell的旋转动画************//
            PAGridViewCell *cell = (PAGridViewCell *)rotateGesture.view;
            [_scrollView bringSubviewToFront:cell];
            
            self.lastRotation = rotateGesture.rotation;
            CGAffineTransform transform = cell.transform;
            transform = CGAffineTransformRotate(transform, self.lastRotation);
            cell.transform = transform;
            
            break;
        }
            
        default:
            break;
    }
    
}

-(void)pinchGestureUpdated:(UIPinchGestureRecognizer *)pinchGesture
{
    
    switch (pinchGesture.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            const CGFloat kMaxScale = 3;
            const CGFloat kMinScale = 0.5;
            
            if ([pinchGesture scale] >= kMinScale && [pinchGesture scale] <= kMaxScale)
            {
                
                [self performSelector:@selector(transformingGestureDidFinishWithGesture:) withObject:pinchGesture afterDelay:0.2];
                
            }else {
                
                PAGridViewCell *cell = (PAGridViewCell *)pinchGesture.view;
                [cell setHidden:YES];
                
                if ([_dataSource respondsToSelector:@selector(presentPhotoView:andPhotoArray:)]) {
                    
                    [_dataSource presentPhotoView:cell andPhotoArray:self.cellArray];
                }
                
                cell.transform = CGAffineTransformMakeScale(1, 1);
                [cell.layer setBorderColor:[UIColor colorWithWhite:1.0 alpha:1.0].CGColor];
                
            }
            
            //*********允许滚动操作********//
            _scrollView.scrollEnabled = YES;
            
            break;
        }
            
        case UIGestureRecognizerStateBegan:
        {
            //*********禁止滚动操作********//
            _scrollView.scrollEnabled = NO;
            
            //*********更新lastScale和preScale的值*************//
            self.lastScale = pinchGesture.scale;
            self.preScale = pinchGesture.scale;
            
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            PAGridViewCell *cell = (PAGridViewCell *)pinchGesture.view;
            
            [_scrollView bringSubviewToFront:cell];
            
            self.lastScale = pinchGesture.scale;
            
            //**************取差值的绝对值*********************//
            self.deltaScale = fabs(_lastScale - _preScale);
            
            //************进行缩小操作****************//
            if (_preScale > _lastScale) {
                
                //****************当进行缩小操作时，减少cell的白色边框的透明度*********//
                [cell.layer setBorderColor:[UIColor colorWithWhite:1.0 alpha:1 - cell.frame.size.width/1000].CGColor];
                
                //*********进行放大操作************//
            }else {
                
                //****************当进行放大操作时，增加cell的白色边框的透明度*********//
                [cell.layer setBorderColor:[UIColor colorWithWhite:1.0 alpha:1 - cell.frame.size.width/1000].CGColor];
                
            }
            
            self.preScale = [pinchGesture scale];
            
            //***************处理cell的缩放和旋转动画****************//
            cell.transform = CGAffineTransformMakeScale(_lastScale,_lastScale);
            CGAffineTransform transform = cell.transform;
            transform = CGAffineTransformRotate(transform, self.lastRotation);
            cell.transform = transform;
            
            //*************进行背景变暗设置**********************//
            //      [self controlBackgroundColorWithGesture:pinchGesture andView:_scrollView];
            
            break;
            
        }
        default:
            break;
    }
    
}

-(void)panGestureUpdated:(UIPanGestureRecognizer *)panGesture
{
    switch (panGesture.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            
            [self performSelector:@selector(transformingGestureDidFinishWithGesture:) withObject:panGesture afterDelay:0.2];
            
            //*********Enable scroll action********//
            _scrollView.scrollEnabled = YES;
            
            break;
        }
            
        case UIGestureRecognizerStateBegan:
        {
            PAGridViewCell *cell = (PAGridViewCell *)panGesture.view;
            self.lastPosition = CGPointMake(cell.center.x,cell.center.y);
            
            //*********Disable scroll action*********//
            _scrollView.scrollEnabled = NO;
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            
            PAGridViewCell *cell = (PAGridViewCell *)panGesture.view;
            [_scrollView bringSubviewToFront:cell];
            CGPoint translate = [panGesture translationInView:_scrollView];
            [cell setCenter:CGPointMake(cell.center.x + translate.x, cell.center.y + translate.y)];
            [panGesture setTranslation:CGPointZero inView:_scrollView];
            break;
            
        }
            
        default:
            break;
    }
    
}

-(void)transformingGestureDidFinishWithGesture:(UIGestureRecognizer *)recognizer
{
    if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
        
        //***************添加结束动画********************//
        [UIView animateWithDuration:kDefaultAnimationDuration
                              delay:0
                            options:kDefaultAnimationOptions
                         animations:^{
                             
                             PAGridViewCell *cell = (PAGridViewCell *)recognizer.view;
                             cell.transform = CGAffineTransformMakeRotation(0);
                         }
                         completion:nil
         ];
        
    }else if([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        
        //***************添加结束动画********************//
        [UIView animateWithDuration:kDefaultAnimationDuration
                              delay:0
                            options:kDefaultAnimationOptions
                         animations:^{
                             
                             PAGridViewCell *cell = (PAGridViewCell *)recognizer.view;
                             cell.transform = CGAffineTransformMakeScale(1, 1);
                             [cell.layer setBorderColor:[UIColor colorWithWhite:1.0 alpha:1.0].CGColor];
                             
                         }
                         completion:nil
         ];
        
    }else if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        
        //***************添加结束动画********************//
        [UIView animateWithDuration:kDefaultAnimationDuration
                              delay:0
                            options:kDefaultAnimationOptions
                         animations:^{
                             
                             PAGridViewCell *cell = (PAGridViewCell *)recognizer.view;
                             cell.center = CGPointMake(self.lastPosition.x, self.lastPosition.y);
                         }
                         completion:nil
         ];
        
    }else if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        
        [UIView animateWithDuration:kDefaultAnimationDuration
                              delay:0
                            options:kDefaultAnimationOptions
                         animations:^{
                             
                             //***************添加结束动画********************//
                             [UIView animateWithDuration:kDefaultAnimationDuration
                                                   delay:0
                                                 options:kDefaultAnimationOptions
                                              animations:^{
                                                  
                                                  PAGridViewCell *cell = (PAGridViewCell *)recognizer.view;
                                                  
                                                  if ([_dataSource respondsToSelector:@selector(presentPhotoView:andPhotoArray:)]) {
                                                      
                                                      [_dataSource presentPhotoView:cell andPhotoArray:self.cellArray];
                                                  }
                                              }
                                              completion:nil
                              ];
                             
                             
                         }
                         completion:nil
         ];
        
    }
    
}

#pragma mark - ======================InheritMethods========================
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self initializeScrollView];
        [self initializeData];
        
    }
    return self;
}


@end
