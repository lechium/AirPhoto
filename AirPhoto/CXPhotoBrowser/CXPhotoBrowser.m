//
//  CXPhotoBrowser.m
//  CXPhotoBrowserDemo
//
//  Created by ChrisXu on 13/4/19.
//  Copyright (c) 2013年 ChrisXu. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>
#import "CXPhotoBrowser.h"
#import "CXZoomingScrollView.h"
//#import <MediaRemote/MediaRemote.h>
#import "SDWebImageManager.h"
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#define PADDING                 10
#define PAGE_INDEX_TAG_OFFSET   1000
#define PAGE_INDEX(page)        ([(page) tag] - PAGE_INDEX_TAG_OFFSET)

@interface CXBrowserNavBarView ()
- (void)assignPhotoBrowser:(CXPhotoBrowser *)browser;
@end;

@interface CXBrowserToolBarView ()
- (void)assignPhotoBrowser:(CXPhotoBrowser *)browser;
@end;

@interface CXPhotoBrowser ()
{
    // Data & Delegate
    id <CXPhotoBrowserDataSource> _dataSource;
    id <CXPhotoBrowserDelegate> _delegate;
    NSUInteger _photoCount;
    NSMutableArray *_photos;
    NSTimer *_playbackTimer;
    // Views
	UIScrollView *_pagingScrollView; //container
    
    // Paging
	NSMutableSet *_visiblePages, *_recycledPages;
	NSUInteger _currentPageIndex;
	NSUInteger _pageIndexBeforeRotation;
    NSTimer *_scrollDetectingTimer;
    
    //Previous
    UIBarButtonItem *_previousViewControllerBackButton;
    UIColor *_previousNavBarTintColor;
    UIImage *_previousNavBarBackgroundImageDefault,
    *_previousNavBarBackgroundImageLandscapePhone;
    
    //flags
    BOOL _performingLayout;
	BOOL _rotating;
    BOOL _viewIsActive;
    BOOL _didSavePreviousStateOfNavBar;
    BOOL _shouldUseDefaultUINavigationBar;
    BOOL _supportReload;
    BOOL _scrolling;
    BOOL _wasPlayingBack; //experimental
}

// Layout
- (void)performLayout;

// Nav Bar Appearance
- (void)setNavBarAppearance:(BOOL)animated;
- (void)storePreviousNavBarAppearance;
- (void)restorePreviousNavBarAppearance:(BOOL)animated;

// Paging
- (void)tilePages;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;
- (CXZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index;
- (CXZoomingScrollView *)pageDisplayingPhoto:(id<CXPhotoProtocol>)photo;
- (CXZoomingScrollView *)dequeueRecycledPage;
- (void)configurePage:(CXZoomingScrollView *)page forIndex:(NSUInteger)index;
- (void)didStartViewingPageAtIndex:(NSUInteger)index;
- (void)changeToPageAtIndex:(NSUInteger)index;

// Frames
- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;
- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index;

// Loadingview

// Navigation
- (void)currentPageDidUpdatedWithIndex:(NSUInteger)index;

// Controls (NavigationBar & ToolBar)
- (BOOL)shouldUseDefaultUINavigationBar;
- (BOOL)isNavBarHidden;
- (BOOL)isToolBarHidden;
- (BOOL)areControlsHidden;
- (void)toggleControls;
- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated;
- (void)setToolBarHidden:(BOOL)hidden animated:(BOOL)animated;

// Data
- (NSUInteger)numberOfPhotos;
- (id<CXPhotoProtocol>)photoAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfPhoto:(id<CXPhotoProtocol>)photo;
- (UIImage *)imageForPhoto:(id<CXPhotoProtocol>)photo;
- (void)loadAdjacentPhotosIfNecessary:(id<CXPhotoProtocol>)photo;
- (void)unloadAllUnderlyingPhotos;

// Notify Handle
- (void)handleCXPhotoImageDidStartLoad:(NSNotification *)notification;
- (void)handleCXPhotoImageDidFinishLoad:(NSNotification *)notification;
- (void)handleCXPhotoImageDidFailLoadWithError:(NSNotification *)notification;
- (void)handleCXPhotoImageDidStartReload:(NSNotification *)notification;
// Action
- (void)doneButtonPressed:(id)sender;

@end

static CGFloat kNavigationBarViewHeightPortrait = 44;
static CGFloat kNavigationBarViewHeightLadnScape = 32;

static CGFloat kToolBarViewHeightPortrait = 100;
static CGFloat kToolBarViewHeightLadnScape = 100;

@implementation CXPhotoBrowser
@synthesize photoCount = _photoCount;
@synthesize currentPageIndex = _currentPageIndex;
@synthesize delegate = _delegate;
- (id)init
{
    self = [super init];
    if (self)
    {
        //self.wantsFullScreenLayout = YES;
        //self.hidesBottomBarWhenPushed = YES;
        _performingLayout = NO; // Reset on view did appear
		_rotating = NO;
        _viewIsActive = NO;
        _scrolling = NO;
        _didSavePreviousStateOfNavBar = NO;
        _shouldUseDefaultUINavigationBar = NO;
        _supportReload = YES;
        _photoCount = NSNotFound;
        _currentPageIndex = 0;
        _visiblePages = [[NSMutableSet alloc] init];
        _recycledPages = [[NSMutableSet alloc] init];
        _photos = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCXPhotoImageDidStartLoad:)
                                                     name:NFCXPhotoImageDidStartLoad
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCXPhotoImageDidFinishLoad:)
                                                     name:NFCXPhotoImageDidFinishLoad
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCXPhotoImageDidFailLoadWithError:)
                                                     name:NFCXPhotoImageDidFailLoadWithError
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCXPhotoImageDidStartReload:)
                                                     name:NFCXPhotoImageDidStartReload
                                                   object:nil];
    }
    return self;
}

- (id)initWithDataSource:(id <CXPhotoBrowserDataSource>)dataSource  delegate:(id <CXPhotoBrowserDelegate>)delegate
{
    self = [self init];
    if (self)
    {
        _dataSource = dataSource;
        _delegate = delegate;
    }
    return self;
}

#pragma mark - Lifecycle
- (void)viewDidLoad
{
    // View
	self.view.backgroundColor = [UIColor blackColor];
    
    // Setup paging scrolling view
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
	_pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
	_pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	//_pagingScrollView.pagingEnabled = YES;
	_pagingScrollView.delegate = self;
	_pagingScrollView.showsHorizontalScrollIndicator = NO;
	_pagingScrollView.showsVerticalScrollIndicator = NO;
	_pagingScrollView.backgroundColor = [UIColor blackColor];
    _pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    _pagingScrollView.panGestureRecognizer.allowedTouchTypes = @[@(UITouchTypeIndirect)];
    _playbackState = CXBrowserPlaybackStateUnknown;
	[self.view addSubview:_pagingScrollView];

    [super viewDidLoad];
    /*
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
        //NSLog(@"We got the information: %@", info);
        
        //This key may not be available, if its is not, we defer to ignoring the alert.
        NSString *mediaType = [(NSDictionary *)CFBridgingRelease(info) valueForKey:@"kMRMediaRemoteNowPlayingInfoMediaType"];
        
        if (info != nil){
            if ([mediaType containsString:@"Music"]){
                self->_wasPlayingBack = true;
            } else {
                self->_wasPlayingBack = false;
            }
            
        } else { //info is null, nothing is currently playing, call original implementation.
            self->_wasPlayingBack = false;
        }
        
    });
     */
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    //LOG_SELF;
    NSLog(@"pressesBegan: %@", presses);
    
    for (UIPress *press in presses)
    {
        if (press.type == UIPressTypePlayPause || press.type == UIPressTypeSelect)
        {
            NSLog(@"bro...");
            [self togglePlaybackState];
        } else {
            [super pressesBegan:presses withEvent:event];
        }
    }
    
}


- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event
{
    //LOG_SELF;
    NSLog(@"pressesEnded: %@", presses);
    
    for (UIPress *press in presses)
    {
        if (press.type == UIPressTypePlayPause)
        {
            NSLog(@"toggle state?");
           // [self togglePlaybackState];
        } else {
            [super pressesEnded:presses withEvent:event];
        }
    }
}

- (void)pausePlayback {
    
    if (self.playbackState == CXBrowserPlaybackStatePlaying){
        if (_playbackTimer != nil){
            [_playbackTimer invalidate];
            _playbackTimer = nil;
        }
        self.playbackState = CXBrowserPlaybackStatePaused;
    }
}

- (void)togglePlaybackState {
    
    switch (self.playbackState) {
        case CXBrowserPlaybackStatePaused:
            [self playbackPhotos];
            break;
        case CXBrowserPlaybackStatePlaying:
            //pause
            [self pausePlayback];
            break;
        case CXBrowserPlaybackStateStopped: //start over?
            [self changeToPageAtIndex:0];
            break;
        case CXBrowserPlaybackStateUnknown:
            //start playing?
            [self playbackPhotos];
            break;
            
        default:
            break;
    }
    
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    /*
    if (self.wantsFullScreenLayout && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        _previousStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:animated];
    }
    */
    [browserNavigationBarView removeFromSuperview];
    //Setup navigationbar view
    _shouldUseDefaultUINavigationBar = [self shouldUseDefaultUINavigationBar];
    if (!_shouldUseDefaultUINavigationBar)
    {
        //[self resetCustomlizeBrowserNavigationBarView];
        [self.view addSubview:browserNavigationBarView];
    }
    
    //Set up tool view
    //[self resetCustomlizeBrowserToolBarView];
    [self.view addSubview:browserToolBarView];
    
    // Update
    [self reloadData];
    
    if (!_viewIsActive && [self.navigationController.viewControllers objectAtIndex:0] != self) {
        [self storePreviousNavBarAppearance];
    }
    [self setNavBarAppearance:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    if (_playbackTimer){
        [_playbackTimer invalidate];
        _playbackTimer = nil;
        if (!_wasPlayingBack){
            //MRMediaRemoteSendCommand(kMRStop, 0);
        }
    }
    // Check that we're being popped for good
    if ([self.navigationController.viewControllers objectAtIndex:0] != self &&
        ![self.navigationController.viewControllers containsObject:self]) {
        
        // State
        _viewIsActive = NO;
        
        // Bar state / appearance
        [self restorePreviousNavBarAppearance:animated];
        
    }
    
    // Controls
    [self.navigationController.navigationBar.layer removeAllAnimations]; // Stop all animations on nav bar
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // Cancel any pending toggles from taps
    [self setToolBarViewsHidden:NO animated:NO];
    
    /*
    // Status bar
    if (self.wantsFullScreenLayout && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
    }
    */
	// Super
	[super viewWillDisappear:animated];
   // exit(0);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _viewIsActive = YES;
}

- (void)viewWillLayoutSubviews {
    
    // Super
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5")) [super viewWillLayoutSubviews];
	
	// Flag
	_performingLayout = YES;
	
	// Remember index
	NSUInteger indexPriorToLayout = _currentPageIndex;
	
	// Get paging scroll view frame to determine if anything needs changing
	CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    
	// Frame needs changing
	_pagingScrollView.frame = pagingScrollViewFrame;
	
	// Recalculate contentSize based on current orientation
	_pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
	
	// Adjust frames and configuration of each visible page
	for (CXZoomingScrollView *page in _visiblePages) {
        NSUInteger index = PAGE_INDEX(page);
		page.frame = [self frameForPageAtIndex:index];
		[page setMaxMinZoomScalesForCurrentBounds];
	}
	
	// Adjust contentOffset to preserve page location based on values collected prior to location
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:indexPriorToLayout];
	[self didStartViewingPageAtIndex:_currentPageIndex]; // initial
    
	// Reset
	_currentPageIndex = indexPriorToLayout;
	_performingLayout = NO;
    
}

- (BOOL)playMusicDefault {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"APSettingsPlayMusic"];
}

- (NSInteger)timePerPhotoDefault{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"APSettingsTimePerPhoto"];
}


- (void)playbackPhotos {
    
    self.playbackState = CXBrowserPlaybackStatePlaying;
    if ([self playMusicDefault] == true){
        //MRMediaRemoteSendCommand(kMRPlay, 0);
    }
    NSInteger timePerPhoto = [self timePerPhotoDefault];
    if (timePerPhoto == 0){
        timePerPhoto = 5;
    }
    _playbackTimer = [NSTimer scheduledTimerWithTimeInterval:timePerPhoto repeats:true block:^(NSTimer * _Nonnull timer) {
       
        [self goToNextPhoto];
        
    }];
    
    
}

- (void)goToNextPhoto {
    
    NSLog(@"currentPhoto Index: %lu", self.currentPageIndex);
    NSLog(@"photo count: %lu", self.photoCount);
    if (self.currentPageIndex < self.photoCount){
        [self changeToPageAtIndex:self.currentPageIndex+1];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Layout
- (void)performLayout
{
    // Setup
    _performingLayout = YES;
    
	// Setup pages
    [_visiblePages removeAllObjects];
    [_recycledPages removeAllObjects];
    
    // Navigation
    [self changeToPageAtIndex:_currentPageIndex];
    
    // Content offset
	_pagingScrollView.contentOffset = [self contentOffsetForPageAtIndex:_currentPageIndex];
    [self tilePages];
    _performingLayout = NO;
}

#pragma Nav Bar Appearance
- (void)setNavBarAppearance:(BOOL)animated
{
    self.navigationController.navigationBar.tintColor = nil;
    //self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    if ([[UINavigationBar class] respondsToSelector:@selector(appearance)])
    {
        [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsCompact];
    }
}

- (void)storePreviousNavBarAppearance
{
    _didSavePreviousStateOfNavBar = YES;
    _previousNavBarTintColor = self.navigationController.navigationBar.tintColor;
    if ([[UINavigationBar class] respondsToSelector:@selector(appearance)])
    {
        _previousNavBarBackgroundImageDefault = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsDefault];
        _previousNavBarBackgroundImageLandscapePhone = [self.navigationController.navigationBar backgroundImageForBarMetrics:UIBarMetricsCompact];
    }
}

- (void)restorePreviousNavBarAppearance:(BOOL)animated
{
    if (_didSavePreviousStateOfNavBar)
    {
        self.navigationController.navigationBar.tintColor = _previousNavBarTintColor;
        //self.navigationController.navigationBar.barStyle = _previousNavBarStyle;
        if ([[UINavigationBar class] respondsToSelector:@selector(appearance)]) {
            [self.navigationController.navigationBar setBackgroundImage:_previousNavBarBackgroundImageDefault forBarMetrics:UIBarMetricsDefault];
            [self.navigationController.navigationBar setBackgroundImage:_previousNavBarBackgroundImageLandscapePhone forBarMetrics:UIBarMetricsCompact];
        }
        
        if (_previousViewControllerBackButton) {
            UIViewController *previousViewController = [self.navigationController topViewController]; // We've disappeared so previous is now top
            //previousViewController.navigationItem.backBarButtonItem = _previousViewControllerBackButton;
            _previousViewControllerBackButton = nil;
        }
    }
}

#pragma mark - Paging
- (void)setInitialPageIndex:(NSUInteger)index
{
    if (index >= [self numberOfPhotos]) index = [self numberOfPhotos]-1;
    _currentPageIndex = index;
	if ([self isViewLoaded]) {
//        [self changeToPageAtIndex:index];
        if (!_viewIsActive) [self tilePages]; // Force tiling if view is not visible
    }
}

- (void)tilePages
{
    CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger iFirstIndex = (NSInteger)floorf((CGRectGetMinX(visibleBounds)+PADDING*2) / CGRectGetWidth(visibleBounds));
	NSInteger iLastIndex  = (NSInteger)floorf((CGRectGetMaxX(visibleBounds)-PADDING*2-1) / CGRectGetWidth(visibleBounds));
    if (iFirstIndex < 0) iFirstIndex = 0;
    if (iFirstIndex > [self numberOfPhotos] - 1) iFirstIndex = [self numberOfPhotos] - 1;
    if (iLastIndex < 0) iLastIndex = 0;
    if (iLastIndex > [self numberOfPhotos] - 1) iLastIndex = [self numberOfPhotos] - 1;
	
	// Recycle no longer needed pages
    NSInteger pageIndex;
	for (CXZoomingScrollView *page in _visiblePages) {
        pageIndex = PAGE_INDEX(page);
		if (pageIndex < (NSUInteger)iFirstIndex || pageIndex > (NSUInteger)iLastIndex) {
			[_recycledPages addObject:page];
            [page prepareForReuse];
			[page removeFromSuperview];
		}
	}
	[_visiblePages minusSet:_recycledPages];
    while (_recycledPages.count > 2) // Only keep 2 recycled pages
        [_recycledPages removeObject:[_recycledPages anyObject]];
	
	// Add missing pages
	for (NSUInteger index = (NSUInteger)iFirstIndex; index <= (NSUInteger)iLastIndex; index++) {
		if (![self isDisplayingPageForIndex:index]) {
            
            // Add new page
			CXZoomingScrollView *page = [self dequeueRecycledPage];
			if (!page) {
				page = [[CXZoomingScrollView alloc] initWithPhotoBrowser:self];
			}
			[self configurePage:page forIndex:index];
			[_visiblePages addObject:page];
			[_pagingScrollView addSubview:page];
		}
	}
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
	for (CXZoomingScrollView *page in _visiblePages)
		if (PAGE_INDEX(page) == index) return YES;
	return NO;
}

- (CXZoomingScrollView *)pageDisplayedAtIndex:(NSUInteger)index
{
    CXZoomingScrollView *thePage = nil;
    thePage.isPhotoSupportedReload = _supportReload;
	for (CXZoomingScrollView *page in _visiblePages) {
		if (PAGE_INDEX(page) == index) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (CXZoomingScrollView *)pageDisplayingPhoto:(id <CXPhotoProtocol>)photo
{
    CXZoomingScrollView *thePage = nil;
    thePage.isPhotoSupportedReload = _supportReload;
	for (CXZoomingScrollView *page in _visiblePages) {
		if (page.photo == photo) {
			thePage = page; break;
		}
	}
	return thePage;
}

- (CXZoomingScrollView *)dequeueRecycledPage
{
    CXZoomingScrollView *page = [_recycledPages anyObject];
    page.isPhotoSupportedReload = _supportReload;
	if (page) {
		[_recycledPages removeObject:page];
	}
	return page;
}

- (void)configurePage:(CXZoomingScrollView *)page forIndex:(NSUInteger)index
{
    page.index = index;
    if (!_scrolling) {
        [self currentPageDidUpdatedWithIndex:index];
    }
    page.isPhotoSupportedReload = _supportReload;
    page.frame = [self frameForPageAtIndex:index];
    page.tag = PAGE_INDEX_TAG_OFFSET + index;
    page.photo = [self photoAtIndex:index];
}

- (void)didStartViewingPageAtIndex:(NSUInteger)index
{
    // Release images further away than +/-1
    NSUInteger i;
    if (index > 0) {
        // Release anything < index - 1
        for (i = 0; i < index-1; i++) {
            id photo = [_photos objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_photos replaceObjectAtIndex:i withObject:[NSNull null]];
            }
        }
    }
    if (index < [self numberOfPhotos] - 1) {
        // Release anything > index + 1
        for (i = index + 2; i < _photos.count; i++) {
            id photo = [_photos objectAtIndex:i];
            if (photo != [NSNull null]) {
                [photo unloadUnderlyingImage];
                [_photos replaceObjectAtIndex:i withObject:[NSNull null]];
            }
        }
    }
    
    // Load adjacent images if needed and the photo is already
    // loaded. Also called after photo has been loaded in background
    id <CXPhotoProtocol> currentPhoto = [self photoAtIndex:index];
    if ([currentPhoto underlyingImage]) {
        // photo loaded so load ajacent now
        [self loadAdjacentPhotosIfNecessary:currentPhoto];
    }
}

- (void)changeToPageAtIndex:(NSUInteger)index
{
    if (index < [self numberOfPhotos]) {
		CGRect pageFrame = [self frameForPageAtIndex:index];
        [UIView animateWithDuration:0.5 animations:^{
            [self->_pagingScrollView setContentOffset:CGPointMake(pageFrame.origin.x - PADDING, 0) animated:false];
            //self->_pagingScrollView.contentOffset = CGPointMake(pageFrame.origin.x - PADDING, 0);

        }];
//        [self currentPageDidUpdated];
	} else {
        self.playbackState = CXBrowserPlaybackStateStopped;
        
    }
}
#pragma mark - Frame Calculations

- (CGRect)frameForPagingScrollView
{
    CGRect frame = self.view.bounds;// [[UIScreen mainScreen] bounds];
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index
{
    CGRect bounds = _pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView
{
    CGRect bounds = _pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self numberOfPhotos], bounds.size.height);
}

- (CGPoint)contentOffsetForPageAtIndex:(NSUInteger)index
{
    CGFloat pageWidth = _pagingScrollView.bounds.size.width;
	CGFloat newOffset = index * pageWidth;
	return CGPointMake(newOffset, 0);
}


#pragma mark - Navigation & control
- (void)setToolBarViewsHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (self.extendedLayoutIncludesOpaqueBars) {
        
        // Get status bar height if visible
        CGFloat statusBarHeight = 0;
        
        // Set navigation bar frame
        CGRect navBarFrame = self.navigationController.navigationBar.frame;
        navBarFrame.origin.y = statusBarHeight;
        self.navigationController.navigationBar.frame = navBarFrame;
    }
    
    [self setNavigationBarHidden:hidden animated:animated];
    [self setToolBarHidden:hidden animated:animated];
	
}

//Reload
- (void)reloadCurrentPhoto
{
    id <CXPhotoProtocol> currentPhoto = [self photoAtIndex:_currentPageIndex];
    [currentPhoto loadUnderlyingImageAndNotify];
}

// Navigation
- (void)currentPageDidUpdatedWithIndex:(NSUInteger)index
{
    if (_delegate && [_delegate respondsToSelector:@selector(photoBrowser:didChangedToPageAtIndex:)])
    {
        [_delegate photoBrowser:self didChangedToPageAtIndex:index];
    }
    
    if (_shouldUseDefaultUINavigationBar)
    {
        self.title = [NSString stringWithFormat:@"%lu of %lu", index+1, (unsigned long)_photoCount];
    }
}

- (BOOL)shouldUseDefaultUINavigationBar
{
    if (!self.navigationController)
    {
        return NO;
    }
    
    if ([self.navigationController.viewControllers objectAtIndex:0] == self) {
        if (_dataSource && [_dataSource respondsToSelector:@selector(browserNavigationBarViewOfOfPhotoBrowser:withSize:)])
        {
            return NO;
        }
        else
        {
            // We're first on stack so show done button
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStylePlain target:self action:@selector(doneButtonPressed:)];
            // Set appearance
            if ([UIBarButtonItem respondsToSelector:@selector(appearance)]) {
                [doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
                [doneButton setBackgroundImage:nil forState:UIControlStateNormal barMetrics:UIBarMetricsCompact];
                [doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
                [doneButton setBackgroundImage:nil forState:UIControlStateHighlighted barMetrics:UIBarMetricsCompact];
                [doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateNormal];
                [doneButton setTitleTextAttributes:[NSDictionary dictionary] forState:UIControlStateHighlighted];
            }
            self.navigationItem.rightBarButtonItem = doneButton;
            
            return YES;
        }
    } else
    {
        return YES;
    }
}

- (BOOL)isNavBarHidden
{
    if (_shouldUseDefaultUINavigationBar)
    {
        return (self.navigationController.navigationBar.alpha == 0);
    }
    else
    {
        return (browserNavigationBarView.alpha == 0);
    }
}

- (BOOL)isToolBarHidden
{
    return (browserToolBarView.alpha == 0);
}

- (BOOL)areControlsHidden
{
    return ([self isNavBarHidden] && [self isToolBarHidden]);
}

- (void)toggleControls
{
    [self setToolBarViewsHidden:![self areControlsHidden] animated:YES];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.35];
    }
    
    if (_shouldUseDefaultUINavigationBar)
    {
        [self.navigationController.navigationBar setAlpha:hidden ? 0. : 1.];
    }
    else
    {
        [browserNavigationBarView setAlpha:hidden ? 0. : 1.];
    }
    
    if (animated) [UIView commitAnimations];
}

- (void)setToolBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.35];
    }

    [browserToolBarView setAlpha:hidden ? 0. : 1.];
    
    if (animated) [UIView commitAnimations];
}
#pragma mark - Data
- (void)reloadData {

    // Reset
    _photoCount = NSNotFound;
    
    if ([_delegate respondsToSelector:@selector(supportReload)])
    {
        _supportReload = [_delegate supportReload];
    }
    // Get data
    NSUInteger numberOfPhotos = [self numberOfPhotos];
    [self unloadAllUnderlyingPhotos];
    [_photos removeAllObjects];
    for (int i = 0; i < numberOfPhotos; i++) [_photos addObject:[NSNull null]];
    
    // Update
    [self performLayout];
    
    // Layout
    [self.view setNeedsLayout];
    
}

- (NSUInteger)numberOfPhotos
{
    if (_photoCount == NSNotFound) {
        if ([_dataSource respondsToSelector:@selector(numberOfPhotosInPhotoBrowser:)]) {
            _photoCount = [_dataSource numberOfPhotosInPhotoBrowser:self];
        }
    }
    if (_photoCount == NSNotFound) _photoCount = 0;
    return _photoCount;
}

- (id<CXPhotoProtocol>)photoAtIndex:(NSUInteger)index
{
    id <CXPhotoProtocol> photo = nil;
    if (index < _photos.count) {
        if ([_photos objectAtIndex:index] == [NSNull null]) {
            if ([_dataSource respondsToSelector:@selector(photoBrowser:photoAtIndex:)]) {
                photo = [_dataSource photoBrowser:self photoAtIndex:index];
            }
            if (photo) [_photos replaceObjectAtIndex:index withObject:photo];
        } else {
            photo = [_photos objectAtIndex:index];
        }
    }
    return photo;
}

- (NSUInteger)indexOfPhoto:(id<CXPhotoProtocol>)photo
{
    NSUInteger index = 0;
    for (int i = 0; i < _photos.count; i++)
    {
        if ([[_photos objectAtIndex:i] isEqual:photo])
        {
            index = i;
            break;
        }
    }
    //NSLog(@"%lu,%lu",(unsigned long)index,(unsigned long)_currentPageIndex);
    return index;
}

- (UIImage *)imageForPhoto:(id<CXPhotoProtocol>)photo
{
    if (photo) {
		// Get image or obtain in background
		if ([photo underlyingImage]) {
			return [photo underlyingImage];
		} else {
            [photo loadUnderlyingImageAndNotify];
		}
	}
	return nil;
}

- (void)loadAdjacentPhotosIfNecessary:(id<CXPhotoProtocol>)photo
{
    CXZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        // If page is current page then initiate loading of previous and next pages
        NSUInteger pageIndex = PAGE_INDEX(page);
        if (_currentPageIndex == pageIndex) {
            if (pageIndex > 0) {
                // Preload index - 1
                id <CXPhotoProtocol> photo = [self photoAtIndex:pageIndex-1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                }
            }
            if (pageIndex < [self numberOfPhotos] - 1) {
                // Preload index + 1
                id <CXPhotoProtocol> photo = [self photoAtIndex:pageIndex+1];
                if (![photo underlyingImage]) {
                    [photo loadUnderlyingImageAndNotify];
                }
            }
        }
    }
}

- (void)unloadAllUnderlyingPhotos
{
    for (id p in _photos) { if (p != [NSNull null]) [p unloadUnderlyingImage]; } 
}

#pragma mark - Notify Handle
- (void)handleCXPhotoImageDidStartLoad:(NSNotification *)notification
{
    id <CXPhotoProtocol> photo = [notification object];
    //show loading view
//    NSUInteger index = [self indexOfPhoto:photo];
    
    CXZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page)
    {
        if ([photo underlyingImage])
        {
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        }
        else
        {
            [page displayImageStartLoading];
        }
    }
}

- (void)handleCXPhotoImageDidFinishLoad:(NSNotification *)notification
{
    id <CXPhotoProtocol> photo = [notification object];
    CXZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page) {
        if ([photo underlyingImage]) {
            // Successful load
            [page displayImage];
            [self loadAdjacentPhotosIfNecessary:photo];
        } else {
            // Failed to load
            [page displayImageFailure];
        }
    }
}

- (void)handleCXPhotoImageDidFailLoadWithError:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    id <CXPhotoProtocol> photo = [notification object];
    NSError *error = [info objectForKey:@"error"];
    NSLog(@"error:%@",error);
    //show failure view
    CXZoomingScrollView *page = [self pageDisplayingPhoto:photo];
    if (page)
    {
        [page displayImageFailure];
    }
}

- (void)handleCXPhotoImageDidStartReload:(NSNotification *)notification
{
    [self reloadCurrentPhoto];
}

#pragma mark - Rotation;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	// Remember page index before rotation
	_pageIndexBeforeRotation = _currentPageIndex;
	_rotating = YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	_currentPageIndex = _pageIndexBeforeRotation;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	_rotating = NO;
}
#pragma clang diagnostic pop
#pragma mark - Actions
- (void)doneButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollView Delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Checks
	if (!_viewIsActive || _performingLayout || _rotating) return;
	_scrolling = YES;
	// Tile pages
	[self tilePages];
	
	// Calculate current page
	CGRect visibleBounds = _pagingScrollView.bounds;
	NSInteger index = (NSInteger)(floorf(CGRectGetMidX(visibleBounds) / CGRectGetWidth(visibleBounds)));
    if (index < 0) index = 0;
	if (index > [self numberOfPhotos] - 1) index = [self numberOfPhotos] - 1;
	NSUInteger previousCurrentPage = _currentPageIndex;
	_currentPageIndex = index;
	if (_currentPageIndex != previousCurrentPage) {
        [self didStartViewingPageAtIndex:index];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        _scrolling = NO;
        [self currentPageDidUpdatedWithIndex:_currentPageIndex];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _scrolling = NO;
    [self currentPageDidUpdatedWithIndex:_currentPageIndex];
}

@end
