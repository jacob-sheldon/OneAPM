//
//  OAMMachOCrashInspect.m
//  OneAPM
//
//  Created by 施治昂 on 9/14/23.
//

// https://www.jianshu.com/p/3f6775c02257

#import "OAMMachOCrashInspect.h"
#import <sys/sysctl.h>

// 判断是否正在使用xcode调试
bool ksdebug_isBeingTraced(void) {
    struct kinfo_proc procInfo;
}

void installExceptionHandler() {
    
}
