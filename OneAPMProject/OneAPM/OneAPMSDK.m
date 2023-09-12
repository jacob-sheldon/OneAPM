//
//  OneAPMSDK.m
//  OneAPM
//
//  Created by 施治昂 on 9/9/23.
//

#import "OneAPMSDK.h"
#import "StutterMonitor.h"

@implementation OneAPMSDK

+ (void)start {
    [StutterMonitor start];
}

@end
