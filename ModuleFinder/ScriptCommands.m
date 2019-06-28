#import "ScriptCommands.h"
#include "ModuleLoaderConstants.h"
#include "findModule.h"
#include "AEUtils.h"
#import <OSAKit/OSAKit.h>
#include "ExtractDependencies.h"
#import "AppDelegate.h"

#define useLog 0

@implementation MeetTheVersionCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    OSErr err = noErr;
    NSString *version = nil;
    NSString *condition = nil;
    VersionConditionSet *vercond_set = NULL;
    CFStringRef errmsg = NULL;
    
    version = [self directParameter];
    condition = [self arguments][@"condition"];
    
    
    vercond_set = VersionConditionSetCreate((__bridge CFStringRef)(condition),
                                            &errmsg);
    if (errmsg) {
        err = kFailedToParseVersionCondition;
        goto bail;
    }
    Boolean result = VersionConditionSetIsSatisfied(vercond_set,
                                                    (__bridge CFStringRef)(version));
    
bail:
    VersionConditionSetFree(vercond_set);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        self.scriptErrorString = CFBridgingRelease(errmsg);
    }
    return [NSNumber numberWithBool:result];
}
@end

@implementation ModuleSpecCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    OSErr err = noErr;
    AEDesc module_name = {typeNull, NULL};
    AEDesc module_spec = {typeNull, NULL};
    AEDesc required_version = {typeNull, NULL};
    AEDesc with_reloading = {typeFalse, NULL};
    AEBuildError ae_err;
    NSString *errmsg = nil;
    
    const AEDesc *ev = [[self appleEvent] aeDesc];
    err = AEGetParamDesc(ev, keyDirectObject, typeWildCard, &module_name);
    if ((err == noErr) && (typeNull != module_name.descriptorType)) {
        err = AEBuildDesc(&module_spec, &ae_err, "MoSp{pnam:@}",&module_name);
        if (err != noErr) {
            errmsg = @"Failed to AEBuildDesc in ModuleSpecCommand.";
            goto bail;
        }
    } else {
        err = AEBuildDesc(&module_spec, &ae_err, "MoSp{}");
        if (err != noErr) {
            errmsg = @"Failed to AEBuildDesc in ModuleSpecCommand.";
            goto bail;
        }
    }
    
    err = AEGetParamDesc(ev, kVersionParam, typeUnicodeText, &required_version);
    if ((err == noErr) && (typeNull != required_version.descriptorType)) {
        err = AEPutKeyDesc (&module_spec, kVersionParam, &required_version);
        if (noErr != err) {
            errmsg = @"Faild to AEPutKeyDesc in ModuleSpecCommand.";
            goto bail;
        }
    } else {
        // -1701 : An Apple event description was not found.
        if (-1701 == err ) err = noErr;
    }
    
    err = AEGetParamDesc(ev, kReloadingParam, typeBoolean, &with_reloading);
    if ((err == noErr) && (typeNull != with_reloading.descriptorType)) {
        err = AEPutKeyDesc (&module_spec, kReloadingParam, &with_reloading);
        if (noErr != err) {
            errmsg = @"Faild to AEPutKeyDesc in ModuleSpecCommand.";
            goto bail;
        }
    } else {
        // -1701 : An Apple event description was not found.
        if (-1701 == err ) err = noErr;
    }
    
bail:
    AEDisposeDesc(&module_name);
    AEDisposeDesc(&required_version);
    AEDisposeDesc(&with_reloading);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        self.scriptErrorString = errmsg;
    }

    return [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&module_spec];
}
@end

@implementation SetAdditionalModulePathsToCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    OSErr err = noErr;
    CFMutableArrayRef module_paths = NULL;
    Boolean ismsg;
    const AEDesc *ev = [[self appleEvent] aeDesc];
    err = isMissingValue(ev, keyDirectObject, &ismsg);
    if (!ismsg) {
        module_paths = CFMutableArrayCreatePOSIXPathsWithEvent(ev, keyDirectObject, &err);
    }
    if (err != noErr) goto bail;
    if (module_paths && CFArrayGetCount(module_paths)) {
        setAdditionalModulePaths(module_paths);
    } else {
        setAdditionalModulePaths(NULL);
    }
bail:
    safeRelease(module_paths);
    if (noErr == err) {
        return [NSNumber numberWithBool:YES];
    } else {
        self.scriptErrorNumber = err;
        return [NSNumber numberWithBool:NO];
    }
}
@end

@implementation ModulePathsCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    NSMutableArray *all_paths = [NSMutableArray arrayWithCapacity:6];
    NSArray *additional_paths = additionalModulePaths();
    if (additional_paths) {
        [all_paths addObjectsFromArray:additional_paths];
    }
    
    NSArray *default_paths = copyDefaultModulePaths();
    if (default_paths) {
        [all_paths addObjectsFromArray:default_paths];
    }
    
    return all_paths;
}
@end

@implementation ExtractDepedenciesCommand
OSErr extractDependenciesASObjC(AEDesc *script_data_ptr, AEDesc *dependencies, NSString **errmsg);

- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    OSErr err;
    AEDesc script_data = {typeNull, NULL};
    AEDescList dependencies = {typeNull, NULL};
    NSAppleEventDescriptor *reply = nil;
    NSString *errmsg = nil;
    
    err = AEGetParamDesc([[self appleEvent] aeDesc], 'frso', typeWildCard, &script_data);
    if (noErr != err ) {
        self.scriptErrorString = @"Faild to AEGetParamDesc in extractDependenciesHandler";
        self.scriptErrorNumber = err;
        return nil;
    }
    AEKeyword desired_class;
    OSAID script_id = kOSANullScript;
    ComponentInstance scriptingComponent = NULL;
    switch (script_data.descriptorType) {
        case typeScript:
            scriptingComponent = [[[OSALanguage defaultLanguage] sharedLanguageInstance]
                                  componentInstance];
            
            err = OSACoerceFromDesc(scriptingComponent, &script_data, kOSAModeNull, &script_id);
            if (err != noErr) goto bail;
            break;
        case typeObjectSpecifier:
            err = AEGetKeyPtr(&script_data, keyAEDesiredClass, typeType, NULL, &desired_class, sizeof(desired_class), NULL);
            if (desired_class != 'ocid') {
                err = 1804;
                break;
            }
            err = extractDependenciesASObjC(&script_data, &dependencies, &errmsg);
            if (noErr != err) {
                self.scriptErrorNumber = err;
                self.scriptErrorString = errmsg;
                goto bail;
            }
            goto putparam;
            break;
        default:
            err = 1804;
    }
    if (err != noErr) {
        self.scriptErrorString = @"Faild to AEGetParamDesc in extractDependenciesHandler";
        self.scriptErrorNumber = err;
        //showAEDesc(ev);
        goto bail;
    }
    
    err = extractDependencies(scriptingComponent, script_id, &dependencies, &errmsg);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        self.scriptErrorString = errmsg;
        goto bail;
    }
putparam:
    reply = [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&dependencies];
bail:
    OSADispose(scriptingComponent, script_id);
    AEDisposeDesc(&script_data);
#if useLog
    NSLog(@"end performDefaultImplementation of ExtractDepedenciesCommand");
#endif
    return reply;
}
@end

@implementation LoadModuleCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    OSErr err = noErr;
    OSAID script_id = kOSANullScript;
    ComponentInstance scriptingComponent = NULL;
    AEDescList dependencies = {typeNull, NULL};
    AEDesc furl_desc = {typeNull, NULL};
    AEDesc script_desc = {typeNull, NULL};
    AEDesc version_desc = {typeNull, NULL};
    AEDesc result_desc = {typeNull, NULL};
    NSAppleEventDescriptor *result = nil;
    NSString *errmsg = nil;
    
    ModuleRef* module_ref = NULL;
    module_ref = findModuleWithEvent([[self appleEvent] aeDesc],
                                     self);
    if (!module_ref) goto bail;
    
    OSAError osa_err = noErr;
    
    
    scriptingComponent = [[[OSALanguage defaultLanguage] sharedLanguageInstance]
                          componentInstance];
    
    
    osa_err = OSALoadFile(scriptingComponent, &(module_ref->fsref), NULL, kOSAModeCompileIntoContext, &script_id);
    if (osa_err != noErr) {
        self.scriptErrorNumber = osa_err;
        self.scriptErrorString = @"Fail to load a script.";
        goto bail;
    }
    
    err = AEDescCreateWithCFURL(module_ref->url, &furl_desc);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        goto bail;
    }
    err = extractDependencies(scriptingComponent, script_id, &dependencies, &errmsg);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        self.scriptErrorString = errmsg;
        goto bail;
    }
    
    osa_err = OSACoerceToDesc(scriptingComponent, script_id, typeWildCard,kOSAModeNull, &script_desc);
    if (osa_err != noErr) {
        self.scriptErrorNumber = osa_err;
        self.scriptErrorString = @"Fail to OSACoerceToDesc.";
        goto bail;
    }
    
    if (module_ref->version) {
        AEDisposeDesc(&version_desc); // required to avoid memory leak. the reason is unknown.
        err = AEDescCreateWithCFString(module_ref->version, kCFStringEncodingUTF8, &version_desc);
        if (noErr != err) {
            self.scriptErrorNumber = err;
            self.scriptErrorString = @"Fail to AEDescCreateWithCFString.";
            goto bail;
        }
    } else {
        AEDisposeDesc(&version_desc); // required to avoid memory leak. the reason is unknown.
        err = AEDescCreateMissingValue(&version_desc);
        if (noErr != err) {
            self.scriptErrorNumber = err;
            self.scriptErrorString = @"Fail to AEDescCreateMissingValue.";
            goto bail;
        }
    }
    
    AEBuildError ae_err;
    err = AEBuildDesc(&result_desc, &ae_err, "{file:@, scpt:@, DpIf:@, vers:@}",
                      &furl_desc, &script_desc, &dependencies, &version_desc);
    if (noErr != err) {
        self.scriptErrorNumber = err;
        goto bail;
    }
    result = [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&result_desc];

bail:
    AEDisposeDesc(&script_desc);
    AEDisposeDesc(&version_desc);
    AEDisposeDesc(&furl_desc);
    AEDisposeDesc(&dependencies);
    ModuleRefFree(module_ref);
    OSADispose(scriptingComponent, script_id);
    return result;
}
@end

@implementation FindModuleCommand
- (id)performDefaultImplementation
{
    [AppDelegate updateLastAccess];
    ModuleRef *module_ref = findModuleWithEvent([[self appleEvent] aeDesc],
                                                self);
    NSURL *url = nil;
    if (!module_ref) goto bail;
    url = CFBridgingRelease(module_ref->url);
    ModuleRefFree(module_ref);
bail:
    return url;
}
@end
