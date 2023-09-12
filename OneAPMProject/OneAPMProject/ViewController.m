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
    sleep(1);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"ViewController viewDidAppear");
}


@end
