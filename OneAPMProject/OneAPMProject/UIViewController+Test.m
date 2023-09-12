//
//  UIViewController+Test.m
//  OneAPMProject
//
//  Created by 施治昂 on 9/12/23.
//

#import "UIViewController+Test.h"
#import <objc/runtime.h>

@implementation UIViewController (Test)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        // 原始方法的选择器和实现
        SEL originalSelector = @selector(viewDidAppear:);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        
        // 替换方法的选择器和实现
        SEL swizzledSelector = @selector(swizzled_viewDidAppear:);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        // 尝试添加新方法，如果原方法不存在则添加成功
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        // 如果添加成功，直接交换方法实现
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            // 如果添加失败，说明原始方法已经存在，直接交换实现
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)swizzled_viewDidAppear:(BOOL)animated {
    // 在这里可以添加你的自定义逻辑
    
    // 调用原始的viewDidAppear方法
    [self swizzled_viewDidAppear:animated];
}

@end
