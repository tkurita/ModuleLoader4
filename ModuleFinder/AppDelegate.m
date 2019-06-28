//
//  AppDelegate.m
//  ModuleFinder
//
//  Created by 栗田 哲郎 on 2019/06/14.
//  Copyright © 2019年 tkurita. All rights reserved.
//

#import "AppDelegate.h"
#define tinterval 60.0*10.0

@interface AppDelegate ()
    @property (weak) IBOutlet NSWindow *window;
    @property (strong)NSTimer *timer;
@end

static time_t LASTACCESS;

@implementation AppDelegate
+ (void)updateLastAccess {
    LASTACCESS = time(NULL);
}

- (void)timerFired:(NSTimer *)t {
    time_t current_time = time(NULL);
    if (current_time - LASTACCESS > tinterval) {
        [NSApp terminate:self];
    }
}
    
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [AppDelegate updateLastAccess];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:tinterval
                                                  target:self
                                                selector:@selector(timerFired:)
                                                userInfo:nil
                                                 repeats:YES];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
