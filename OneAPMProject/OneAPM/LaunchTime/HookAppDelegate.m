//
//  HookAppDelegate.m
//  OneAPM
//
//  Created by 施治昂 on 9/10/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

IMP _oam_willFinishOriginalImp;
IMP _oam_didFinishOriginalImp;

NSDate *_oam_before_willFinish_time;
extern NSDate *_oam_after_DidFinish_time;

static void __OAM_Application_WillFinishLaunchingWithOptions(id self, SEL selector, UIApplication *application, NSDictionary *launchOptions) {
    _oam_before_willFinish_time = [NSDate date];
    // 调用原始方法的实现
    ((void (*)(id, SEL, UIApplication *, NSDictionary *))_oam_willFinishOriginalImp)(self, selector, application, launchOptions);
}

static void __OAM_Application_DidFinishLaunchingWithOptions(id self, SEL selector, UIApplication *application, NSDictionary *launchOptions) {
    // 调用原始方法的实现
    ((void (*)(id, SEL, UIApplication *, NSDictionary *))_oam_didFinishOriginalImp)(self, selector, application, launchOptions);
    
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:_oam_before_willFinish_time];
    printf("appDelegate used time: %f\n", interval);
    _oam_after_DidFinish_time = [NSDate date];
}

// Hook before willFinishLaunchingWithOptions and after didFinishLaunchingWithOptions to calculate this time used in this two methods
__attribute__((constructor))
void oam_hook_appdelegate(void) {
    // willFinish
    Class appDelegate = NSClassFromString(@"AppDelegate");
    SEL willFinish = @selector(application:willFinishLaunchingWithOptions:);
    _oam_willFinishOriginalImp = class_getMethodImplementation(appDelegate, willFinish);
    
    Method willFinishMethod = class_getInstanceMethod(appDelegate, willFinish);
    const char *willFinishTypeEncoding = method_getTypeEncoding(willFinishMethod);
    class_replaceMethod(appDelegate, willFinish, (IMP)__OAM_Application_WillFinishLaunchingWithOptions, willFinishTypeEncoding);
    
    // didFinish
    SEL didFinish = @selector(application:didFinishLaunchingWithOptions:);
    _oam_didFinishOriginalImp = class_getMethodImplementation(appDelegate, didFinish);
    
    Method didFinishMethod = class_getInstanceMethod(appDelegate, didFinish);
    const char *didFinishTypeEncoding = method_getTypeEncoding(didFinishMethod);
    class_replaceMethod(appDelegate, didFinish, (IMP)__OAM_Application_DidFinishLaunchingWithOptions, didFinishTypeEncoding);
}
