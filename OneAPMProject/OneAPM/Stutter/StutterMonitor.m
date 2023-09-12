//
//  StutterMonitor.m
//  OneAPM
//
//  Created by 施治昂 on 9/12/23.
//

#import "StutterMonitor.h"

@implementation StutterMonitor

+ (void)start
{
    dispatch_queue_t stutterMonitorQueue = dispatch_queue_create("oam_stutter_monitor_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSTimeInterval timeThreshold = 0.4;
    NSLock *lock = [[NSLock alloc] init];
    __block BOOL normal = NO;
    
    dispatch_async(stutterMonitorQueue, ^{
        while (YES) {
            NSDate *beginDate = [NSDate date];
            BOOL stuttered = NO;
            [lock lock];
            normal = NO;
            [lock unlock];
            dispatch_async(dispatch_get_main_queue(), ^{
                [lock lock];
                normal = YES;
                [lock unlock];
                dispatch_semaphore_signal(semaphore);
            });
            
            [NSThread sleepForTimeInterval:timeThreshold];
            
            stuttered = !normal;
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            if (stuttered) {
                NSLog(@"卡顿了，卡顿时长：%f", [[NSDate date] timeIntervalSinceDate:beginDate]);
            } else {
                NSLog(@"没有卡顿");
            }
        }
    });
}

@end
