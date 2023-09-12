//
//  HookMain.cpp
//  OneAPM
//
//  Created by 施治昂 on 9/9/23.
//

#import <Foundation/Foundation.h>
#import "oam_fishhook.h"
#import <sys/sysctl.h>

long processStartTime;

int (*oneapm_origin_applicationMain)(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);

int oneapm_myApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName) {
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:processStartTime]];
    NSLog(@"pre-main阶段耗时 = %f", interval);
    return oneapm_origin_applicationMain(argc, argv, principalClassName, delegateClassName);
}

/// 进程创建时间
void oneapm_get_process_start_time(void) {
    struct kinfo_proc proc;
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    int cmd[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    size_t size = sizeof(proc);
    if (sysctl(cmd, sizeof(cmd)/sizeof(*cmd), &proc, &size, NULL, 0) == 0) {
        long seconds =  proc.kp_proc.p_un.__p_starttime.tv_sec;
        processStartTime = seconds;
    }
}

__attribute__((constructor))
void oneapm_hookMain(void) {
    oneapm_get_process_start_time();
    oam_rebind_symbols((struct oam_rebinding[1]){{"UIApplicationMain", oneapm_myApplicationMain, (void **)&oneapm_origin_applicationMain}}, 1);
}




