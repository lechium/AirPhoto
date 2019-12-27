//
//  ViewController.h
//  AirPhoto
//
//  Created by Kevin Bradley on 12/27/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CXPhotoBrowser.h"

@interface ViewController : UIViewController <CXPhotoBrowserDelegate, CXPhotoBrowserDataSource>

- (id)initWithArray:(NSArray <NSString *> *)inputPhotos;
- (void)processPhotos:(NSArray <NSString *> *)input;
- (void)showPhotoBrowserAtIndex:(NSInteger)index;
@end

