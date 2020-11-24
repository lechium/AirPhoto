//
//  AppDelegate.m
//  AirPhoto
//
//  Created by Kevin Bradley on 12/27/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import <UIKit/UIKit.h>
#import "UIViewController+Additions.h"
#import "SDWebImageManager.h"


@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface AppDelegate (){
    NSMutableArray <NSString *> *_airDropArray;
}
@end

@implementation AppDelegate

- (void)_storeAppIcon {
    __block UIImage *currentImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:@"AppIcon"];
    if (currentImage == nil){
        currentImage = [UIImage _applicationIconImageForBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier] format:0 scale:0];
        //[[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/TVKit.framework/"] load];
        //id proxy = [LSApplicationProxy applicationProxyForIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
        //_ourIcon = [proxy tv_applicationFlatIcon];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            //currentImage = [proxy tv_applicationFlatIcon];
            [[SDImageCache sharedImageCache] storeImage:currentImage forKey:@"AppIcon"];
        });
    }
}

- (void)handleAirdroppedFile:(NSString *)path options:(NSDictionary *)options {
    
    NSInteger docCount = [options[@"LSDocumentDropCount"] integerValue];
    NSInteger docIndex = [options[@"LSDocumentDropIndex"] integerValue];
    NSLog(@"processing %li of %li", docIndex+1, docCount);
    if (_airDropArray == nil){
        _airDropArray = [NSMutableArray new];
    }
    NSString *movedPath = [self movedFileToCache:path];
    NSLog(@"adding file: %@ to array", movedPath);
    if (movedPath != nil){
        [_airDropArray addObject:movedPath];
    }
    if (docIndex == (docCount-1)){
        if (_airDropArray.count > 0){
            
            ViewController *vc = (ViewController*)[self topViewController];
            if ([vc respondsToSelector:@selector(showPhotoBrowserAtIndex:)]){
                [vc processPhotos:_airDropArray];
                [vc showPhotoBrowserAtIndex:0];
                [_airDropArray removeAllObjects];
            }
        } else {
            NSLog(@"error processing airdropped files");
        }
    }
}

- (NSString *)movedFileToCache:(NSString *)fileName {
    NSFileManager *man = [NSFileManager defaultManager];
    NSString *cache = [self photosPath];
    NSString *newPath = [cache stringByAppendingPathComponent:fileName.lastPathComponent];
    NSError *error = nil;
    
    if ([man fileExistsAtPath:newPath]){
        [man removeItemAtPath:fileName error:nil];
        return newPath;
    }
    if ([man copyItemAtPath:fileName toPath:newPath error:&error]){
        if(!error){
            [man removeItemAtPath:fileName error:nil];
            return newPath;
        }
    }
    return nil;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
//     [[SDImageCache sharedImageCache] cleanDisk];
//     [[SDImageCache sharedImageCache] clearMemory];
     

    [self _storeAppIcon];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    NSLog(@"[AirPhoto] app: %@ app openURL: %@ url, options: %@", app, url, options);
    NSLog(@"[AirPhoto] options: %@", options);
    [self handleAirdroppedFile:url.path options:options[UIApplicationOpenURLOptionsAnnotationKey]];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
 
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
