//
//  AlertViewController.m
//  DuMaMay
//
//  Created by Thompson Vo on 11/29/17.
//  Copyright © 2017 t1_v0h!. All rights reserved.
//

#import "UIImage+animatedGIF.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "UIImage+animatedGIF.h"
#include "v0rtex.h"
#include "Utilities.h"
#include "unjail.h"
#include "kppless.h"

@interface AlertViewController : UIViewController
@property (retain, nonatomic) IBOutlet UIView *containerView;

@property (retain, nonatomic) IBOutlet UILabel *titleLabel;
@property (retain, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (retain, nonatomic) IBOutlet UIImageView *bloodView;

@property (assign) kern_return_t v0rtex_ret;@end

@interface AlertViewController ()
{
    AVAudioPlayer *player;
}

@end

@implementation AlertViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"failed" ofType:@"mp3"];
    NSURL *url3 = [NSURL URLWithString:path];
    player = [[AVAudioPlayer alloc]initWithContentsOfURL: url3 error:NULL];
    [player play];
    
    //once jailbroken, you can change gif to whatever...just make sure to name it "default.gif."
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"default" withExtension:@"gif"];
    self.bloodView.image = [UIImage animatedImageWithAnimatedGIFData:[NSData dataWithContentsOfURL:url]];
    self.bloodView.image = [UIImage animatedImageWithAnimatedGIFURL:url];
    
    url = [[NSBundle mainBundle] URLForResource:@"default" withExtension:@"gif"];
    self.bloodView.image = [UIImage animatedImageWithAnimatedGIFURL:url];
   
    [self.containerView setAlpha:0.0];
    self.containerView.transform = CGAffineTransformMakeTranslation(0, 50);
    
    self.v0rtex_ret = KERN_SUCCESS;
    
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [UIView animateWithDuration:0.8 animations:^{
        [self.view setAlpha:1];
        [self.containerView setAlpha:1.0];
        self.containerView.transform = CGAffineTransformMakeTranslation(0, 0);
    } completion:nil];
}

- (IBAction)rebootTapped:(id)sender {

    printf("[INFO]: idevice will reboot\n");
    extern task_t tfp0;
    extern uint64_t kernel_slide;
    self.v0rtex_ret = v0rtex(&tfp0, &kernel_slide);
    //exit(0);
    
    if (go_extra_recipe() == KERN_SUCCESS) {
        go_kppless() == KERN_SUCCESS;
    }
    int cydia_installed = is_cydia_installed();
    (cydia_installed == 0 || &install_cydia == 0); {
        install_cydia(install_cydia == KERN_SUCCESS);
        
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        kill_backboardd();
    });
}

- (void)dealloc {
    [_titleLabel release];
    [_descriptionLabel release];
    [_containerView release];
    [_bloodView release];
    [super dealloc];
}
@end
