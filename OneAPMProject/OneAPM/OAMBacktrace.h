//
//  OAMBacktrace.h
//  OneAPM
//
//  Created by 施治昂 on 9/12/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OAMBacktrace : NSObject

+ (NSString *)oam_backtraceOneThread:(NSThread *)thread;
+ (NSString *)oam_backtraceAllThreads;

@end

NS_ASSUME_NONNULL_END
