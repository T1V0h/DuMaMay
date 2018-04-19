////
//  DuMaMayViewController.m
//  DuMaMay
//
//  Created by Thompson Vo on 11/29/17.
//  Copyright © 2017 t1_v0h!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "UIImage+animatedGIF.h"
#include "v0rtex.h"
#include "Utilities.h"
#include "unjail.h"
#include "kppless.h"

@interface DuMaMayViewController : UIViewController

@property (retain, nonatomic) IBOutlet UIButton *helpButton;
@property (retain, nonatomic) IBOutlet UIButton *jailbreakButton;
@property (retain, nonatomic) IBOutlet NSLayoutConstraint *jailbreakButtonWidth;
@property (retain, nonatomic) IBOutlet UILabel *warningLabel;
@property (retain, nonatomic) IBOutlet UILabel *deviceInfoLabel;
@property (retain, nonatomic) IBOutlet UIProgressView *progressView;
@property (retain, nonatomic) IBOutlet UILabel *deviceType;
@property (retain, nonatomic) IBOutlet UILabel *runningIos;
@property (retain, nonatomic) IBOutlet UILabel *warning;
@property (retain, nonatomic) IBOutlet UILabel *warning2;
@property (retain, nonatomic) IBOutlet UIButton *reCydia;
@property (retain, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) IBOutlet UIButton *exit;
@property (retain, nonatomic) IBOutlet UIImageView *illuminateView;
@property (retain, nonatomic) IBOutlet UIImageView *loadingView;
@property (retain, nonatomic) IBOutlet UIImageView *respringView;
@property (retain, nonatomic) IBOutlet UILabel *warningLabel2;
@property (retain, nonatomic) IBOutlet UIButton *stopMusic;

@property (assign) kern_return_t v0rtex_ret;
@end

@interface DuMaMayViewController ()
{
    AVAudioPlayer *player;
}
@end

@implementation DuMaMayViewController

bool autoRespring = false;
int reinstallCydia = 1; // false by default

NSString *error_message;

- (void)addGradient {
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    
    gradient.frame = view.bounds;
    
    gradient.colors = @[(id)[UIColor colorWithRed:0.07 green:0.30 blue:0.32 alpha:1.0].CGColor, (id)[UIColor colorWithRed:0.04 green:0.16 blue:0.28 alpha:1.0].CGColor];
    
    [view.layer insertSublayer:gradient atIndex:0];
    [self.view insertSubview:view atIndex:0];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addGradient];
    
    NSString *version = [[UIDevice currentDevice] systemVersion];
    self.runningIos.text = version;
    NSString *device = [[UIDevice currentDevice] model];
    self.deviceType.text = device;
    
    self.v0rtex_ret = KERN_SUCCESS;
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    //get device info
    [self.deviceInfoLabel setText:[NSString stringWithFormat:@"%s - %@", get_internal_model_name(), [[UIDevice currentDevice] systemVersion]]];
    
    if (ami_jailbroken() == 1) {
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"successDuMa" ofType:@"mp3"];
        NSURL *url3 = [NSURL URLWithString:path];
        player = [[AVAudioPlayer alloc]initWithContentsOfURL: url3 error:NULL];
        [player play];
        
        if (player.play) {
            printf("[INFO]: Success Music\n");
        }
        
        printf("[INFO]: already jailbroken\n");
        self.stopMusic.hidden = NO;
        [self.jailbreakButton setEnabled:NO];
        [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
        [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
        [self.jailbreakButton setTitle:@"you're jailbroken" forState:UIControlStateDisabled];
        self.reCydia.hidden = NO;
        self.loadingView.hidden = YES;
        self.illuminateView.hidden = NO;
        self.imageView.hidden = YES;
        [self.jailbreakButton setAlpha:0.4];
        [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
        return;
        
    }
    
    if (offsets_init() != KERN_SUCCESS) {
        
        printf("[INFO]: idevice or firmware isn't supported\n");
        [self.jailbreakButton setEnabled:NO];
        [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
        [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
        [self.jailbreakButton setTitle:@"device not supported" forState:UIControlStateDisabled];
        [self.jailbreakButton setAlpha:0.4];
        self.reCydia.hidden = YES;
        self.illuminateView.hidden = NO;
        [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
        return;
    }
    
}

- (IBAction)helpTapped:(id)sender {
    
    printf("[INFO]: idevice showing jailbreak help\n");
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"InfoViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (IBAction)jailbreakTapped:(id)sender {
    
    [UIView animateWithDuration:0.2 animations:^{
        self.jailbreakButton.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}

- (IBAction)jailbreakHold:(id)sender {
    
    if(reinstallCydia == 1 && is_cydia_installed() == 1) {
        
        printf("[INFO]:                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                reinstall Cydia\n");
        reinstallCydia = 0;
        
        [self.warningLabel setHidden:NO];
        
        [UIView animateWithDuration:0.9 animations:^{
            [self.warningLabel setAlpha:0.30];
        } completion:^(BOOL finished){
            [self.warningLabel setAlpha:0];
        }];
        
    }
    
}

- (IBAction)jailbreakReleased:(id)sender {
    
    printf("[INFO]: starting jailbreak proccess\n");
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"buffer-loading" withExtension:@"gif"];
    self.loadingView.image = [UIImage animatedImageWithAnimatedGIFData:[NSData dataWithContentsOfURL:url]];
    self.loadingView.image = [UIImage animatedImageWithAnimatedGIFURL:url];
    
    url = [[NSBundle mainBundle] URLForResource:@"buffer-loading" withExtension:@"gif"];
    self.loadingView.image = [UIImage animatedImageWithAnimatedGIFURL:url];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.jailbreakButton.transform = CGAffineTransformMakeScale(1, 1);
    } completion:nil];
    
    [self.helpButton setEnabled:NO];
    [self.jailbreakButton setEnabled:NO];
    [self.jailbreakButtonWidth setConstant:[self.jailbreakButtonWidth constant] + 100];
    [self.jailbreakButton setFrame:CGRectMake(self.jailbreakButton.frame.origin.x, self.jailbreakButton.frame.origin.y, self.jailbreakButton.frame.size.width + 60, self.jailbreakButton.frame.size.height)];
    [self.jailbreakButton setTitle:@"running exploit.." forState:UIControlStateNormal];
    self.loadingView.hidden = NO;
    [self.jailbreakButton setAlpha:0.4];
    [self.jailbreakButton setBackgroundColor:[UIColor colorWithWhite:1 alpha:0.0]];
    
    [self.progressView setHidden:NO];
    [self.progressView setProgress:0.4 animated:YES];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        
        extern task_t tfp0;
        extern uint64_t kernel_slide;
        self.v0rtex_ret = v0rtex(&tfp0, &kernel_slide);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(self.v0rtex_ret != KERN_SUCCESS) {
                error_message = @"running exploit";
                [self show_failure];
                
            } else {
                // show kpp bypass
                [self show_kpp_bypass];
            }
            
        });
        
    });
    
}

- (void) show_kpp_bypass {
    
    [self.progressView setProgress:0.7 animated:YES];
    [self.jailbreakButton setTitle:@"bypassing kpp" forState:UIControlStateNormal];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if (go_extra_recipe() == KERN_SUCCESS) {
            [self show_install_cydia];
        } else {
            // show failure (bypassing KPP)
            error_message = @"bypassing KPP";
            [self show_failure];
            
            // try going kppless then
            //printf("[ERROR]: kpp bypass failed!\n");
            //printf("[INFO]: trying to use kppless method..\n");
            //[self show_kpp_bypass];
        }
        
    });
}

- (void) show_kppless {
    
    [self.progressView setProgress:0.9 animated:YES];
    [self.jailbreakButton setTitle:@"going kppless" forState:UIControlStateNormal];
    [self.warningLabel setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        if (go_kppless() == KERN_SUCCESS) {
            
            [self.progressView setProgress:1.0 animated:YES];
            [self respring];
            
        } else {
            // show failure (going kppless)
            error_message = @"going kppless";
            [self show_failure];
        }
        
    });
    
}

- (void) show_install_cydia {
    
    int cydia_installed = is_cydia_installed();
    
    if (cydia_installed == 0 || reinstallCydia == 0) {
        self.imageView.hidden = NO;
        self.illuminateView.hidden = YES;
        [self.jailbreakButton setTitle:@"installing Cydia" forState:UIControlStateNormal];
        reinstallCydia = 0; // install Cydia
    } else {
        [self.jailbreakButton setTitle:@"respringing" forState:UIControlStateNormal];
    }
    
    [self.progressView setProgress:0.9 animated:YES];
    [self.warningLabel setHidden:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        // Untar bootstrap & install Cydia (final step)
        if (install_cydia(reinstallCydia) == KERN_SUCCESS) {
            
            [self.progressView setProgress:1.0 animated:YES];
            [self respring];
            
            
        } else {
            // show failure (installing Cydia)
            error_message = @"installing Cydia";
            [self show_failure];
        }
        
    });
}

- (void) respring {
    
    printf("[INFO]: idevice will respring\n");
    NSURL *url2 = [[NSBundle mainBundle] URLForResource:@"respring" withExtension:@"gif"];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFData:[NSData dataWithContentsOfURL:url2]];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFURL:url2];
    
    url2 = [[NSBundle mainBundle] URLForResource:@"respring" withExtension:@"gif"];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFURL:url2];
    
    self.warningLabel.hidden = NO;
    self.warningLabel.text = @"restarting, please wait";
    self.loadingView.hidden = YES;
    self.respringView.hidden = NO;
    [self.jailbreakButton setTitle:@"respringing" forState:UIControlStateDisabled];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [UIView animateWithDuration:2.0 animations:^{
            [self.view setAlpha:0];
        } completion:^(BOOL finished){
            if(finished)
                kill_backboardd();
            self.imageView.hidden = YES;
            self.illuminateView.hidden = NO;
        }];
    });
    printf("[INFO]: successfully jailbroken\n");
}

- (void) show_failure {
    
    // hide other elements
    [self.jailbreakButton setHidden:YES];
    [self.progressView setHidden:YES];
    [self.view setAlpha:0.7];
    self.loadingView.hidden = YES;
    
    // we failed badly :(
    UIViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AlertViewController"];
    viewController.providesPresentationContextTransitionStyle = YES;
    viewController.definesPresentationContext = YES;
    [viewController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)dealloc {
    
    [_jailbreakButton release];
    [_progressView release];
    [_jailbreakButtonWidth release];
    [_warningLabel release];
    [_deviceInfoLabel release];
    [_helpButton release];
    [_deviceType release];
    [_runningIos release];
    [_warning release];
    [_warning2 release];
    [_reCydia release];
    [_exit release];
    [_illuminateView release];
    [_loadingView release];
    [_respringView release];
    [_respringView release];
    [_warningLabel2 release];
    [_stopMusic release];
    [super dealloc];
}

- (IBAction)reinstallCydia:(id)sender {
    
    [player stop];
    printf("[INFO]: stupid dumasong stopped\n");
    self.warningLabel.hidden = YES;
    self.stopMusic.hidden = YES;
    self.illuminateView.hidden = NO;
    self.imageView.hidden = NO;
    self.reCydia.hidden = NO; {
        self.warning2.hidden = NO;
    }
    
    if(reinstallCydia == 1 && is_cydia_installed() == 1) {
        
        printf("[INFO]: will reinstall Cydia\n");
        reinstallCydia = 0;
        
        self.imageView.hidden = NO;
        self.illuminateView.hidden = YES;
        [self.warningLabel2 setHidden:NO];
        
        [UIView animateWithDuration:0.9 animations:^{
            [self.warningLabel2 setAlpha:0.30];
        } completion:^(BOOL finished){
            [self.warningLabel2 setAlpha:0];
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            // Untar bootstrap & install Cydia (final step)
            if (install_cydia(reinstallCydia) == KERN_SUCCESS) {
                
                [self.progressView setProgress:1.0 animated:YES];
                [self respring2];
            }
        });
    }
}

- (void) respring2 {
    
    printf("[INFO]: respringing\n");
    NSURL *url2 = [[NSBundle mainBundle] URLForResource:@"respring" withExtension:@"gif"];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFData:[NSData dataWithContentsOfURL:url2]];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFURL:url2];
    
    url2 = [[NSBundle mainBundle] URLForResource:@"respring" withExtension:@"gif"];
    self.respringView.image = [UIImage animatedImageWithAnimatedGIFURL:url2];
    
    self.warningLabel.hidden = YES;
    self.warningLabel2.hidden = NO;
    self.warningLabel2.text = @"please wait";
    self.loadingView.hidden = YES;
    self.respringView.hidden = NO;
    [self.jailbreakButton setTitle:@"respringing" forState:UIControlStateDisabled];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [UIView animateWithDuration:2.0 animations:^{
            [self.view setAlpha:0];
        } completion:^(BOOL finished){
            if(finished)
                kill_backboardd();
            self.imageView.hidden = YES;
            self.illuminateView.hidden = NO;
            
        }];
    });
    
}

- (void)crashMe {
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        // Untar bootstrap & install Cydia (final step)
        if (install_cydia(reinstallCydia) == KERN_SUCCESS) {
            
            [self.progressView setProgress:1.0 animated:YES];
            [self respring2];
        }
    });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            printf("[INFO]: crashing app to SpringBoard\n");
            exit(0);
        });
}

-(IBAction)cutmusic:(id)sender {

    [player stop];
    printf("[INFO]: Music Stopped\n");
    self.stopMusic.hidden = YES;
    
}

-(IBAction)exit:(id)sender {
    
    printf("[INFO]: exiting\n");
    exit(0);
    
}
@end
