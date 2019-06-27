#import <Cocoa/Cocoa.h>
#include "ModuleLoaderConstants.h"
#include "AEUtils.h"
#include "findModule.h"
#include "ModuleCondition.h"

#define useLog 0

static CFArrayRef MODULE_PATHS = NULL;
static char *SUFFIXES[5] = {"", ".scptd", ".scpt", ".app", ".applescript"};
static unsigned int NSUFFIXES = 5;

ModuleRef *findModuleWithEvent(const AppleEvent *ev, NSScriptCommand *command)
{
    OSErr err = noErr;
    NSMutableArray *searched_paths = nil;
    CFStringRef module_name = NULL;
    CFStringRef required_version = NULL;
    CFStringRef errmsg = NULL;
    ModuleCondition *module_condition = NULL;
    AEDesc direct_object = {typeNull, NULL};
    ModuleRef *module_ref = NULL;
#if useLog
    showAEDesc(ev);
#endif
    Boolean with_other_paths = true;
    err = getBoolValue(ev, kOtherPathsParam, &with_other_paths);
    NSMutableArray *path_array = CFBridgingRelease(
        CFMutableArrayCreatePOSIXPathsWithEvent(ev, kInDirectoryParam, &err));
    
    err = AEGetParamDesc(ev, keyDirectObject, typeWildCard, &direct_object);
    if (noErr != err) goto bail;
    switch (direct_object.descriptorType) {
        case typeAERecord:
        case typeModuleSpecifier:
            module_name = CFStringCreateWithEvent(&direct_object, keyAEName, &err);
            ev = &direct_object;
            break;
        default:
            module_name = CFStringCreateWithEvent(ev, keyDirectObject, &err);
            break;
    }
    
    if ((err != noErr) || (module_name == NULL)) {
        command.scriptErrorString = @"Failed to get a module name.";
        goto bail;
    }
    
    required_version = CFStringCreateWithEvent(ev, kVersionParam, &err);
    Boolean from_use = false;
    getBoolValue(ev, kFromUseParam,  &from_use);
    
    module_condition = ModuleConditionCreate(module_name,
                                             required_version,
                                             !from_use, &errmsg);
    if (!module_condition) {
        command.scriptErrorString = CFBridgingRelease(errmsg);
        command.scriptErrorNumber = kFailedToParseVersionCondition;
        goto bail;
    }
    
    err = findModule(module_condition, path_array,
                     !from_use, !with_other_paths,
                     &module_ref, &searched_paths);
    if (err != noErr) {
        NSString *error_message;
        NSString *pathlist = nil;
        if (searched_paths) {
            pathlist = [searched_paths componentsJoinedByString:@":"];
        }
        
        if (required_version) {
            error_message = [NSString stringWithFormat:@"\"%@ (%@)\" can not be found in %@",
                             module_name,required_version, pathlist];
        } else {
            error_message = [NSString stringWithFormat:@"\"%@\" can not be found in %@",
                             module_name, pathlist];
        }
        command.scriptErrorString = error_message;
        goto bail;
    }
bail:
    if (!noErr) command.scriptErrorNumber = err;
    safeRelease(module_name);
    safeRelease(required_version);
    safeRelease(errmsg);
    ModuleConditionFree(module_condition);
    AEDisposeDesc(&direct_object);
    return module_ref;
}

void setAdditionalModulePaths(CFArrayRef array)
{
	if (MODULE_PATHS) 
		CFRelease(MODULE_PATHS);

	MODULE_PATHS = array;	
	CFPreferencesSetAppValue(MODULE_PATHS_KEY, 
							MODULE_PATHS,
							BUNDLE_ID);
	CFPreferencesAppSynchronize(BUNDLE_ID);
	if (MODULE_PATHS) MODULE_PATHS = CFRetain(MODULE_PATHS);
}

NSArray *additionalModulePaths()
{
	if (MODULE_PATHS) goto bail;
	MODULE_PATHS = CFPreferencesCopyAppValue(MODULE_PATHS_KEY, BUNDLE_ID);
#if useLog	
	CFShow(MODULE_PATHS);
#endif
bail:
	return CFBridgingRelease(MODULE_PATHS);
}

void traverseDefaultLocations(BOOL (^block)(NSURL *))
{
    static NSUInteger domains[3] = {NSUserDomainMask, NSLocalDomainMask, NSNetworkDomainMask};
    NSArray *sub_pathes = @[@"Scripts/Modules", @"Script Libraries"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSUInteger n=0; n < 3; n++) {
        NSArray *dirs = [fm URLsForDirectory:NSLibraryDirectory inDomains:domains[n]];
        for (NSString *a_path in sub_pathes) {
            NSURL *url = [(NSURL *)dirs.lastObject URLByAppendingPathComponent:a_path];
            if (!block(url)) return;
        }
    }
}

NSArray *copyDefaultModulePaths()
{
    __block NSMutableArray *array = [NSMutableArray arrayWithCapacity:6];
    traverseDefaultLocations(^(NSURL *url) {
        [array addObject:[url path]];
        return YES;
    });
    
    return array;
}

OSErr scanFolder(CFURLRef container_url, ModuleCondition *module_condition,
                 Boolean searchSubFolders, ModuleRef **outRef)
{
#if useLog
    fprintf(stderr, "start scanFolder\n");
#endif
	OSErr err = kModuleIsNotFound;
	
	CFStringRef fname = NULL;
	CFMutableArrayRef subfolders = NULL;
	ModuleRef *module_ref_candidate = NULL;
	ModuleRef *module_ref = NULL;
	TXFileRef txfile = NULL;
    CFErrorRef error = NULL;
    CFURLEnumeratorRef enumerator = NULL;
	err = pickupModuleAtFolder(container_url, module_condition, outRef);
	if (noErr == err) {
		goto bail;
	} 
		
	/* start to search subfolders */
	if (searchSubFolders) subfolders = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    CFStringRef keys[] = {kCFURLIsDirectoryKey, kCFURLIsPackageKey,
                            kCFURLIsAliasFileKey, kCFURLNameKey};
    CFArrayRef prefetch_info = CFArrayCreate(kCFAllocatorDefault,
                                             (const void **)keys,
                                              4, NULL);
    enumerator = CFURLEnumeratorCreateForDirectoryURL(kCFAllocatorDefault,
                                            container_url, kCFURLEnumeratorSkipInvisibles, prefetch_info);
    CFURLRef child_url = NULL;
    CFURLEnumeratorResult enumerator_result;
    do {
        enumerator_result = CFURLEnumeratorGetNextURL(enumerator, &child_url, NULL);
        if (enumerator_result == kCFURLEnumeratorSuccess) {
            txfile = TXFileCreateWithURL(kCFAllocatorDefault, child_url);
            if (!TXFileResolveAlias(txfile, &error)) {
                if (error) CFShow(error);
                goto loopbail;
            }
            
            Boolean is_folder = TXFileIsDirectory(txfile, &error)
                                    && (! error)
                                    && (! TXFileIsPackage(txfile, &error));
            if (error) {
                CFShow(error);
                goto loopbail;
            }
            
            if (is_folder) {
                if (searchSubFolders) {
                    CFArrayAppendValue(subfolders, child_url);
                }
            } else {
                module_ref = ModuleRefCreateWithCondition(txfile, module_condition);
                if (module_ref) {
#if useLog
                    ShowModuleRef(module_ref);
#endif
                    if (module_ref_candidate) {
                        CFComparisonResult cr = ModuleRefCompareVersion(module_ref, module_ref_candidate);
                        if (cr ==  kCFCompareGreaterThan) {
                            ModuleRefFree(module_ref_candidate);
                            module_ref_candidate = module_ref;
                        } else {
                            ModuleRefFree(module_ref);
                        }
                    } else {
                        module_ref_candidate = module_ref;
                    }
                }		
            }
            
        } else if (enumerator_result == kCFURLEnumeratorError) {
            // A possible enhancement would be to present error-based items to the user.
        }
    loopbail:
        safeRelease(txfile); txfile = NULL;
        safeRelease(error); error = NULL;
    } while (enumerator_result != kCFURLEnumeratorEnd);
    
	if (module_ref_candidate) {
		*outRef = module_ref_candidate;
        err = noErr;
		goto bail;
	}
	
	if (searchSubFolders) {
		for (CFIndex n = 0; n < CFArrayGetCount(subfolders); n++) {
            CFURLRef sub_url = CFArrayGetValueAtIndex(subfolders, n);
			err = scanFolder(sub_url, module_condition,
                             searchSubFolders, outRef);
			if (err == noErr) goto bail;
		}
	} 
	err = kModuleIsNotFound;
bail:
#if useLog	
	fprintf(stderr, "scanFolder will end with err :%d.\n", err);
#endif
    safeRelease(error);
	safeRelease(enumerator);
    safeRelease(subfolders);
	safeRelease(fname);
	safeRelease(txfile);
#if useLog
    fprintf(stderr, "end scanFolder\n");
#endif
	return err;
}

OSErr findModuleWithName(NSURL *container_url,
                         ModuleCondition *module_condition,
                         Boolean searchSubFolders,
                         ModuleRef** module_ref)
{
    return scanFolder((__bridge CFURLRef)(container_url),
                      module_condition, searchSubFolders, module_ref);
}

OSErr pickupModuleAtFolder(CFURLRef container_url, ModuleCondition *module_condition, ModuleRef **out_module_ref)
{
	OSErr err = kModuleIsNotFound;
	CFMutableStringRef filename = NULL;
	ModuleRef *module_ref = NULL;
	CFStringRef module_name = module_condition->name;
	TXFileRef txfile = NULL;
    CFURLRef candidaite_url = NULL;
	for (int n = 0; n < NSUFFIXES; n++) {
		filename = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, module_name);
		CFStringAppendCString(filename, SUFFIXES[n], kCFStringEncodingUTF8);
        candidaite_url = CFURLCreateCopyAppendingPathComponent(NULL,
                                                               container_url,
                                                               filename,
                                                               false);
        if (CFURLResourceIsReachable(candidaite_url, NULL)) {
            txfile = TXFileCreateWithURL(kCFAllocatorDefault, candidaite_url);
            module_ref = ModuleRefCreate(txfile);
            if (module_ref) {
                if (ModuleConditionVersionIsSatisfied(module_condition, module_ref)) {
                    *out_module_ref=module_ref;
                    err = noErr;
                    break;
                }
            }
            CFRelease(txfile); txfile = NULL;
            ModuleRefFree(module_ref);module_ref = NULL;
        }
#if useLog
        CFShow(candidaite_url);
#endif
        CFRelease(candidaite_url);candidaite_url = NULL;
		CFRelease(filename);filename = NULL;
	}
	
bail:
	safeRelease(filename);
	safeRelease(txfile);
	return err;
}

OSErr findModuleWithSubPath(NSURL *container_url,
                            ModuleCondition *module_condition,
                            Boolean searchSubFolders,
                            ModuleRef** module_ref)
{
	OSErr err;
	CFArrayRef path_comps = module_condition->subpath;
	for (CFIndex n=0; n<(CFArrayGetCount(path_comps) -1); n++) {
		CFStringRef path_elem = CFArrayGetValueAtIndex(path_comps, n);
		if (!CFStringGetLength(path_elem)) continue;
        container_url = [container_url URLByAppendingPathComponent:(__bridge NSString * _Nonnull)(path_elem)];
	}
    if ([container_url checkResourceIsReachableAndReturnError:NULL]) {
        err = pickupModuleAtFolder((__bridge CFURLRef)(container_url), module_condition, module_ref);
        if (err != noErr) {
            err = scanFolder((__bridge CFURLRef)(container_url), module_condition, false, module_ref);
        }
        if (err == noErr) return err;
    }
    
	return kModuleIsNotFound;
}



OSErr findModule(ModuleCondition *module_condition, NSArray *additionalPaths,
                 Boolean searchSubFolders, Boolean ignoreDefaultPaths,
				 ModuleRef** moduleRef, NSMutableArray** searchedPaths)
{
	OSErr (*findModuleAtFolder)(NSURL *container_url, ModuleCondition *module_condition,
                                Boolean searchSubFolders, ModuleRef** moduleRef);
#if useLog
	fprintf(stderr, "ignoreDefaultPaths : %d\n", ignoreDefaultPaths);
	CFShow(additionalPaths);
#endif	
	if (ModuleConditionHasSubpath(module_condition)) {
		findModuleAtFolder = findModuleWithSubPath;
	} else {
		findModuleAtFolder = findModuleWithName;
	}
    __block ModuleRef *found_moduleref = NULL;
    __block NSMutableArray *path_list = [NSMutableArray arrayWithCapacity:6];
    
    if (additionalPaths) {
        [path_list addObjectsFromArray:additionalPaths];
	}
	
	if (!ignoreDefaultPaths) {
		NSArray *tmp_pathlist = additionalModulePaths();
		if (tmp_pathlist) {
            [path_list addObjectsFromArray:tmp_pathlist];
		}
	}
    
    __block OSErr err = kModuleIsNotFound;
    for (NSString *path in path_list) {
        NSURL *url = [NSURL fileURLWithPath:path];
        err = findModuleAtFolder(url, module_condition,
                                 searchSubFolders, &found_moduleref);
		if (err == noErr) {
#if useLog			
			fprintf(stderr, "Module is found\n");
#endif			
			goto bail;
		}
	}
	
	if (ignoreDefaultPaths) {
		goto bail;
	}
    
    traverseDefaultLocations(^(NSURL *url) {
        if ([url checkResourceIsReachableAndReturnError:NULL]) {
            err = findModuleAtFolder(url, module_condition,
                                     searchSubFolders, &found_moduleref);
        }
        [path_list addObject:[url path]];
        if (err == noErr) {
#if useLog
            fprintf(stderr, "Module Found\n");
#endif
            return NO;
        } else {
            return YES;
        }
    });
    
bail:
    if ([path_list count] > 0) *searchedPaths = path_list;
    *moduleRef = found_moduleref;
	return err;
}
