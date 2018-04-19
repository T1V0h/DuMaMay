//
//  InfoViewController.m
//  DuMaMay
//
//  Created by Thompson Vo on 11/29/17.
//  Copyright © 2017 t1_v0h!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "Utilities.h"

@interface InfoViewController : UIViewController


@end

@interface InfoViewController ()

@end

@implementation InfoViewController


- (IBAction)dismissTapped:(id)sender {

    printf("[INFO]: back to main page\n");
    [self dismissViewControllerAnimated:YES completion:nil];

}


@end
