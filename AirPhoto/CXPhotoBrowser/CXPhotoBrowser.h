//
//  CXPhotoBrowser.h
//  CXPhotoBrowserDemo
//
//  Created by ChrisXu on 13/4/19.
//  Copyright (c) 2013年 ChrisXu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CXPhoto.h"
#import "CXPhotoProtocol.h"
#import "CXPhotoLoadingView.h"
#import "CXBrowserNavBarView.h"
#import "CXBrowserToolBarView.h"

typedef NS_ENUM(NSInteger, CXBrowserPlaybackState) {
    CXBrowserPlaybackStateUnknown,
    CXBrowserPlaybackStateStopped,
    CXBrowserPlaybackStatePlaying,
    CXBrowserPlaybackStatePaused,
    
};

@protocol CXPhotoBrowserDataSource;
@protocol CXPhotoBrowserDelegate;
@interface CXPhotoBrowser : UIViewController
<UIScrollViewDelegate>
{
    // Controls (NavigationBar & ToolBar)
    CXBrowserNavBarView *browserNavigationBarView;
    CXBrowserToolBarView *browserToolBarView;
}
//@property (nonatomic, assign) id<CXPhotoBrowserDataSource> dataSource;
//@property (nonatomic, assign) id<CXPhotoBrowserDelegate> delegate;
@property (nonatomic, readonly) NSUInteger photoCount;
@property (nonatomic, readonly) NSUInteger currentPageIndex;
@property (nonatomic, readonly) id<CXPhotoBrowserDelegate> delegate;
@property (readwrite, assign) CXBrowserPlaybackState playbackState;
- (id)initWithDataSource:(id <CXPhotoBrowserDataSource>)dataSource  delegate:(id <CXPhotoBrowserDelegate>)delegate;

// Reloads the photo browser and refetches data
- (void)reloadData;

// Set page that photo browser starts on
- (void)setInitialPageIndex:(NSUInteger)index;


// Navigation & control / Hiding / Showing
- (void)setToolBarViewsHidden:(BOOL)hidden animated:(BOOL)animated;

//Reload
//- (void)reloadCurrentPhoto; undone
- (void)playbackPhotos;

@end

@protocol CXPhotoBrowserDataSource <NSObject>
@required

/**
 @param photoBrowser The current photobrowser to present.
 
 @return number of photos.
 */
- (NSUInteger)numberOfPhotosInPhotoBrowser:(CXPhotoBrowser *)photoBrowser;

/**
 @param photoBrowser The current photobrowser to present.
 @param index index of the photo to present
 
 @return CXPhoto for showing.
 */
- (id <CXPhotoProtocol>)photoBrowser:(CXPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index;
@optional

/**
 *  Height for your customlize NavigationBarView.
 *
 *  @param orientation your current orientation
 *
 *  @return Height
 */
- (CGFloat)heightForNavigationBarInInterfaceOrientation:(UIInterfaceOrientation)orientation;

/**
 *  Height for your customlize ToolBarView.
 *
 *  @param orientation your current orientation
 *
 *  @return Height
 */
- (CGFloat)heightForToolBarInInterfaceOrientation:(UIInterfaceOrientation)orientation;

/**
 *  A customlize NavigationBarView to show on top.
 *
 *  @param photoBrowser The current photobrowser to present.
 *  @param size         NavigationBarView will be resize as this parameter. Make sure your view will fit the size.
 *
 *  @return NavBarView
 */
- (CXBrowserNavBarView *)browserNavigationBarViewOfOfPhotoBrowser:(CXPhotoBrowser *)photoBrowser withSize:(CGSize)size;

/**
 *  A customlize ToolBarView to show on bottom.
 *
 *  @param photoBrowser The current photobrowser to present.
 *  @param size         ToolBarView will be resize as this parameter. Make sure your view will fit the size.
 *
 *  @return ToolBarView.
 */
- (CXBrowserToolBarView *)browserToolBarViewOfPhotoBrowser:(CXPhotoBrowser *)photoBrowser withSize:(CGSize)size;
@end

@protocol CXPhotoBrowserDelegate <NSObject>

@optional

/**
 *  called when currentIndex will change
 *
 *  @param photoBrowser The current photobrowser to present.
 *  @param index        The current showing index in photoBrowser.
 */
- (void)photoBrowser:(CXPhotoBrowser *)photoBrowser didChangedToPageAtIndex:(NSUInteger)index;

/**
 *  called when the current image is finished loading.
 *
 *  @param photoBrowser The current photobrowser to present.
 *  @param currentImage currentImage
 */
- (void)photoBrowser:(CXPhotoBrowser *)photoBrowser didFinishLoadingWithCurrentImage:(UIImage *)currentImage;

/**
 *  called to check if support reload.
 *
 *  @return supportReload
 */
- (BOOL)supportReload;


@end
