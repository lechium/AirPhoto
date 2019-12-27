//
//  AppDelegate.m
//  AirPhoto
//
//  Created by Kevin Bradley on 12/27/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
@interface AppDelegate (){
    NSMutableArray <NSString *> *_airDropArray;
}
@end

@implementation AppDelegate



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
            
            ViewController *vc = (ViewController*)self.window.rootViewController;
            NSLog(@"vc: %@", vc);
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

- (NSString *)photosPath {
    
    NSFileManager *man = [NSFileManager defaultManager];
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Photos"];
    if (![man fileExistsAtPath:cache]){
        NSLog(@"this path wasnt found; %@",cache );
        NSDictionary *folderAttrs = @{NSFileGroupOwnerAccountName: @"staff",NSFileOwnerAccountName: @"mobile"};
        NSError *error = nil;
        [man createDirectoryAtPath:cache withIntermediateDirectories:YES attributes:folderAttrs error:&error];
        if (error){
            NSLog(@"error: %@", error);
        }
    }
    return cache;
}

- (NSString *)movedFileToCache:(NSString *)fileName {
    
    NSFileManager *man = [NSFileManager defaultManager];
    NSString *cache = [self photosPath];
    NSString *newPath = [cache stringByAppendingPathComponent:fileName.lastPathComponent];
    NSError *error = nil;
    
    if ([man fileExistsAtPath:newPath]){
        return newPath;
    }
    if ([man copyItemAtPath:fileName toPath:newPath error:&error]){
        if(!error){
            //[man removeItemAtPath:fileName error:nil];
            return newPath;
        }
    }
    return nil;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    return YES;
}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    NSLog(@"options: %@", options);
     [self handleAirdroppedFile:url.path options:options[@"UIApplicationOpenURLOptionsAnnotationKey"]];
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
