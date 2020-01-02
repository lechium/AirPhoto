//
//  ViewController.m
//  AirPhoto
//
//  Created by Kevin Bradley on 12/27/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "ViewController.h"
#import "SDWebImageManager.h"
#import "APSettingsViewController.h"

@interface ViewController ()
@property NSArray <CXPhoto *> *photos;
@property (nonatomic, strong) NSString *currentPath;
@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    LOG_SELF;
    self.view.alpha = 1;
    
    if (self.currentPath == nil){
        self.currentPath = [self ourCacheFolder];
    }
    self.items = [self currentItems];
    self.title = self.currentPath.lastPathComponent;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editSelected:)];
    
    UIImage *image = [UIImage imageNamed:@"gear-small"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(showSettings:)];
}

- (void)showSettings:(id)sender {
    
    APSettingsViewController *settingsView = [APSettingsViewController new];
    [self presentViewController:settingsView animated:true completion:nil];
    
}

- (void)editSelected:(id)sender {
    
    [self.tableView setEditing:!self.tableView.editing animated:true];
    
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self.tableView isEditing]){
        return UITableViewCellEditingStyleNone;
    }
    NSFileManager *man = [NSFileManager defaultManager];
    MetaDataAsset  *mda = self.items[indexPath.row];
    NSString *fullPath = [[self currentPath] stringByAppendingPathComponent:mda.name];
    NSDictionary *attrs = [man attributesOfItemAtPath:fullPath error:nil];
    BOOL isDirectory = [attrs[NSFileType] isEqual:NSFileTypeDirectory];
    if (!isDirectory){
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    LOG_SELF;
    //NSLog(@"editingStyle : %li, indexPath: %@", (long)editingStyle, indexPath);
    NSFileManager *man = [NSFileManager defaultManager];
    MetaDataAsset  *mda = self.items[indexPath.row];
    NSString *fullPath = [[self currentPath] stringByAppendingPathComponent:mda.name];
    NSString *messageString = [NSString stringWithFormat:@"Are you sure you want to delete '%@'? This is permanent and cannot be undone.", mda.name];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Delete Item?" message:messageString preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        
        [man removeItemAtPath:fullPath error:nil];
        [self refreshList];
        //DLog(@"do it");
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
    
    [ac addAction: cancel];
    [ac addAction:action];
    [self presentViewController:ac animated:TRUE completion:nil];
}

- (id)initWithDirectory:(NSString *)directory {
    
    self = [super init];
    self.currentPath = directory;
    self.title = directory.lastPathComponent;
    return self;
    
}

- (NSArray *)approvedExtensions {
    
    return @[@"jpg", @"jpeg", @"png", @"gif", @"pct"];
    
}

- (void)enterDirectory {
    
    LOG_SELF;
    NSIndexPath *ip = [self savedIndexPath];
    MetaDataAsset  *mda = self.items[ip.row];
    NSString *fullPath = [[self currentPath] stringByAppendingPathComponent:mda.name];
    ViewController *vc = [[ViewController alloc] initWithDirectory:fullPath];
    [[self navigationController] pushViewController:vc animated:true];
    
}

- (void)playFromIndex {
    
    LOG_SELF;
    
    NSIndexPath *ip = [self savedIndexPath];
    MetaDataAsset  *mda = self.items[ip.row];
    NSString *fullPath = [[self currentPath] stringByAppendingPathComponent:mda.name];
    //NSLog(@"fullPath: %@", fullPath);
    [self showPhotoBrowserAtIndex:ip.row];
    //[self showPlayerViewWithFile:fullPath];
    

}

- (NSArray *)currentItems { //kinda hacky will also generate photo array (might as well)
    
    
    __block NSMutableArray *_photoArray = [NSMutableArray new];
    NSFileManager *man = [NSFileManager defaultManager];
    NSArray *contents = [man contentsOfDirectoryAtPath:self.currentPath error:nil];
    __block NSMutableArray *itemArray = [NSMutableArray new];
    [contents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSString *fullPath = [self.currentPath stringByAppendingPathComponent:obj];
        NSDictionary *attrs = [man attributesOfItemAtPath:fullPath error:nil];
        BOOL isDirectory = [attrs[NSFileType] isEqual:NSFileTypeDirectory];
        
        if ([[self approvedExtensions] containsObject:[obj pathExtension].lowercaseString] || isDirectory){
            MetaDataAsset *currentAsset = [MetaDataAsset new];
            currentAsset.name = obj;
            
            if (isDirectory){
                currentAsset.selectorName = @"enterDirectory";
                currentAsset.defaultImageName = @"folder";
                
            } else {
                
                __block UIImage *currentImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:currentAsset.name];
                
                //NSLog(@"image from cache: %@", currentImage);
                
                if (!currentImage){
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                        
                         currentImage = [UIImage imageWithContentsOfFile:fullPath];
                        [[SDImageCache sharedImageCache] storeImage:currentImage forKey:currentAsset.name];
                    });
                }
                CXPhoto *photo = [CXPhoto photoWithFilePath:fullPath];
                if (photo){
                    [_photoArray addObject:photo];
                }
                currentAsset.selectorName = @"playFromIndex";
                currentAsset.defaultImageName = @"generic-icon";
                currentAsset.accessory = false;
            }
            [itemArray addObject:currentAsset];
        }
        
    }];
    self.photos = _photoArray;
    return itemArray;
    
}


- (void)refreshList {
    
    self.items = [self currentItems];
    [[self tableView] reloadData];
}



- (id)initWithArray:(NSArray <NSString *> *)inputPhotos {
    
    self = [super init];
    [self processPhotos:inputPhotos];
    return self;
}


- (void)processPhotos:(NSArray <NSString *> *)input {
    
    __block NSMutableArray *_photoArray = [NSMutableArray new];
    
    [input enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        CXPhoto *photo = [CXPhoto photoWithFilePath:obj];
        if (photo){
            [_photoArray addObject:photo];
        }
        
    }];
    self.photos = _photoArray;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    [self refreshList];
    //[self showPhotoBrowserAtIndex:0];
}

- (void)showPhotoBrowserAtIndex:(NSInteger)index {
    
    CXPhotoBrowser *photoBrowser = [[CXPhotoBrowser alloc] initWithDataSource:self delegate:self];
    [photoBrowser setInitialPageIndex:index];
    [self presentViewController:photoBrowser animated:YES completion:nil];
    [photoBrowser playbackPhotos];
    
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
