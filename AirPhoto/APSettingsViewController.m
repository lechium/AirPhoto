//
//  APSettingsViewController.m
//  AirPhoto
//
//  Created by Kevin Bradley on 1/1/20.
//  Copyright © 2020 nito. All rights reserved.
//

#import "APSettingsViewController.h"
#import "MetadataPreviewView.h"
#import "SDWebImageManager.h"



#define UD [NSUserDefaults standardUserDefaults]

@interface APSettingsViewController ()
@property UIImage *ourIcon;
@end

@implementation APSettingsViewController

- (UIImage *)icon {
    
    if (_ourIcon == nil){
        _ourIcon = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:@"AppIcon"];
        NSLog(@"ourIcon: %@", _ourIcon);
    }
    return _ourIcon;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"Settings";
    
    [self _populateItems];
    
  

}

- (void)_populateItems {

    //NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger timePerSlide = [UD integerForKey:kAPSettingsTimePerPhoto];
    if (timePerSlide == 0){ //no defaults set yet
        timePerSlide = 5;
        [UD setInteger:5 forKey:kAPSettingsTimePerPhoto];
        [UD setBool:YES forKey:kAPSettingsPlayMusic];
        [UD synchronize];
    }
    NSString *playMusic = @"Enabled";
    if ([UD boolForKey:kAPSettingsPlayMusic] == false){
        playMusic = @"Disabled";
    }
    NSMutableArray *_items = [NSMutableArray new];
    MetaDataAsset *spsAsset = [MetaDataAsset new];
    spsAsset.name = @"Seconds per slide";
    spsAsset.detail = [NSString stringWithFormat:@"%lu", timePerSlide];
    spsAsset.detailOptions = @[@"1", @"5", @"10", @"15", @"20", @"30", @"60"];
    spsAsset.accessory = false;
    spsAsset.forcedImage = [self icon];//  [self ourIcon];
    spsAsset.selectorName = @"changeSlideSeconds";
    spsAsset.assetDescription = @"Change the amount of time a photo is shown when playing a folder as a slideshow";
    [_items addObject:spsAsset];
    MetaDataAsset *toggleMusic = [MetaDataAsset new];
    toggleMusic.name = @"Play music";
    toggleMusic.selectorName = @"toggleMusic";
    toggleMusic.accessory = false;
    toggleMusic.detail = playMusic;
    toggleMusic.forcedImage = [self icon];//  [self ourIcon];

    toggleMusic.assetDescription = @"Attempt to play music from your catalog when viewing a slideshow. (Experimental)";
    [_items addObject:toggleMusic];
    [self setItems:_items];
    [self safeReloadData];
    
}



- (void)changeSlideSeconds {
    
    NSInteger currentTime = [UD integerForKey:kAPSettingsTimePerPhoto];
    switch (currentTime) {
        case 1:
            currentTime = 5;
            break;
        case 5:
            currentTime = 10;
            break;
        case 10:
            currentTime = 15;
            break;
        case 15:
            currentTime = 20;
            break;
        case 20:
            currentTime = 30;
            break;
        case 30:
            currentTime = 60;
            break;
        case 60:
            currentTime = 1;
            break;
            
        default:
            currentTime = 5;
            break;
    }
    
    [UD setInteger:currentTime forKey:kAPSettingsTimePerPhoto];
    [UD synchronize];
    
    
}

- (void)toggleMusic {
    
    BOOL currentMusicPref = [UD boolForKey:kAPSettingsPlayMusic];
    [UD setBool:!currentMusicPref forKey:kAPSettingsPlayMusic];
    [UD synchronize];
    [self _populateItems];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
