#import "HelpBookScriptCommands.h"
#import "AppDelegate.h"
#include <Carbon/Carbon.h>

enum {
    NoCFBundleHelpBookName = 1852 /*No CFBundleHelpBookName in Info.plist*/
};

@implementation ShowHelpBookCommand
- (id)performDefaultImplementation
{
    NSString *book_name = nil;
    [AppDelegate updateLastAccess];
    OSStatus status = noErr;
    NSURL* bundle_url = self.directParameter;
    status = AHRegisterHelpBookWithURL((__bridge CFURLRef)(bundle_url));
    if (noErr != status) {
        self.scriptErrorString = [NSString stringWithFormat:
                                  @"Failed to register HelpBook for \"%@\".", bundle_url.path];
        self.scriptErrorNumber = status;
        goto bail;
    }
    book_name = [[NSBundle bundleWithURL:bundle_url] objectForInfoDictionaryKey:@"CFBundleHelpBookName"];
    if (!book_name) {
        self.scriptErrorNumber = NoCFBundleHelpBookName;
        self.scriptErrorString = [NSString stringWithFormat:
                                  @"No CFBundleHelpBookName in Info.plist of \"%@\".", bundle_url.path];
        goto bail;
    }
    status = AHGotoPage((__bridge CFStringRef)(book_name), NULL, NULL);
    if (noErr != status) {
        self.scriptErrorNumber = status;
        self.scriptErrorString = [NSString stringWithFormat:
                                  @"Failed to open a help book : \"%@\".", book_name];;
    }
bail:
    return book_name;
}
@end
