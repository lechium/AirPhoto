//
//  ViewController.m
//  AirPhoto
//
//  Created by Kevin Bradley on 12/27/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property NSArray <CXPhoto *> *photos;
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (id)initWithArray:(NSArray <NSString *> *)inputPhotos {
    
    self = [super init];
    [self processPhotos:inputPhotos];
    return self;
}


- (void)processPhotos:(NSArray <NSString *> *)input {
    
    __block NSMutableArray *_photoArray = [NSMutableArray new];
    
    [input enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        CXPhoto *photo = [CXPhoto photoWithURL:[NSURL fileURLWithPath:obj]];
        if (photo){
            [_photoArray addObject:photo];
        }
        
    }];
    self.photos = _photoArray;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    //[self showPhotoBrowserAtIndex:0];
}

- (void)showPhotoBrowserAtIndex:(NSInteger)index {
    
    CXPhotoBrowser *photoBrowser = [[CXPhotoBrowser alloc] initWithDataSource:self delegate:self];
    [photoBrowser setInitialPageIndex:index];
    [self presentViewController:photoBrowser animated:YES completion:nil];
    
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(CXPhotoBrowser *)photoBrowser {
    
    return self.photos.count;
}

/**
 @param photoBrowser The current photobrowser to present.
 @param index the index of the currently visible photo
 
 @return CXPhoto for showing.
 */
- (id <CXPhotoProtocol>)photoBrowser:(CXPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    
    return self.photos[index];
    
}


@end
