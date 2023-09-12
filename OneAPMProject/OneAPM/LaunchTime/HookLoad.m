//
//  HookLoad.m
//  LaunchProfile
//
//  Created by 施治昂 on 9/7/23.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef void (*ClassMethodIMP)(Class, SEL);

// 递归遍历所有类及其子类
static void oneapm_hookAllLoadMethods(void) {
    // 递归遍历子类
    Class *subclasses = NULL;
    int numSubclasses = objc_getClassList(NULL, 0);
    if (numSubclasses > 0) {
        subclasses = (__unsafe_unretained Class *)malloc(sizeof(Class) * numSubclasses);
        numSubclasses = objc_getClassList(subclasses, numSubclasses);
        for (int i = 0; i < numSubclasses; i++) {
            Class class = subclasses[i];
            NSString *className = NSStringFromClass(class);
            Class metaClass = objc_getMetaClass(object_getClassName(class));
            
            // 这样来区分是自己的类
            if ([className hasPrefix:@"XYZ"]) {
                unsigned int outCnt = 0;
                Method *methods = class_copyMethodList(metaClass, &outCnt);
                for (int i = 0; i < outCnt; i++) {
                    Method m = methods[i];
                    SEL methodSelector = method_getName(m);
                    NSString *methodName = NSStringFromSelector(methodSelector);
                    if ([methodName isEqualToString:@"load"]) {
                        ClassMethodIMP methodIMP = (ClassMethodIMP)method_getImplementation(m);
                        // 记录方法执行前的时间戳
                        NSDate *start = [NSDate date];
                        methodIMP(metaClass, methodSelector);
                        // 计算耗时
                        NSTimeInterval executeTime = -[start timeIntervalSinceNow];
                        NSLog(@"Class %@ +load method took %.4f seconds to execute", NSStringFromClass(class), executeTime);
                    }
                }
            }
        }
        free(subclasses);
    }
}

__attribute__((constructor))
static void oneapm_hook_all_load(void) {
    oneapm_hookAllLoadMethods();
}
