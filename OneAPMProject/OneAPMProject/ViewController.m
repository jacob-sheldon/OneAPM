//
//  ViewController.m
//  OneAPMProject
//
//  Created by 施治昂 on 9/9/23.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self sleep];
}

- (void)sleep {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sleep(2);
        [self sleep];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"ViewController viewDidAppear");
}


@end
