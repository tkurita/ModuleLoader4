#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include "ModuleLoaderConstants.h"
#include "ExtractDependencies.h"
#include "AEUtils.h"
#import "AppleEventExtra.h"

#define useLog 0

const char *MODULE_SPEC_LABEL = "__module_specifier__";
const char *MODULE_DEPENDENCIES_LABEL = "__module_dependencies__";


OSErr ConvertToModuleSpecifier(AEDesc *ae_desc, AEDesc *modspec,
                               NSAppleEventDescriptor *reqested_items,
                               Boolean *ismodule, NSString **errmsg)
{
    OSErr err;
    AEKeyword desired_class;
    AEDesc a_pname = {typeNull, NULL};
    NSAppleEventDescriptor *vers = nil;
    NSString *libname = nil;
    *ismodule = false;
    
    err = AEGetKeyPtr(ae_desc, keyAEDesiredClass, typeType, NULL, &desired_class, sizeof(desired_class), NULL);
    if (noErr != err) goto bail;
    if (desired_class != typeScript) goto bail;
    err = AEGetKeyDesc(ae_desc, keyAEKeyData, typeUnicodeText, &a_pname);
    if (noErr != err) goto bail;
    libname = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&a_pname] stringValue];
    for (NSInteger n = 1; n <= [reqested_items numberOfItems]; n++) {
        NSAppleEventDescriptor *a_record = [reqested_items descriptorAtIndex:n];
        if ([libname isEqualToString:[[[a_record descriptorForKeyword:cObject] descriptorForKeyword:keyAEKeyData] stringValue]]) {
            vers = [a_record descriptorForKeyword: keyAEVersion];
            break;
        }
    }

    AEBuildError ae_err;
    if (vers) {
        err = AEBuildDesc(modspec, &ae_err, "MoSp{pnam:@, vers:@}",&a_pname, [vers aeDesc]);
    } else {
        err = AEBuildDesc(modspec, &ae_err, "MoSp{pnam:@}",&a_pname);
    }
    if (noErr != err) {
        *errmsg = [NSString stringWithFormat:@"Failed to AEBuildDesc in ConvertToModuleSpecifier with error %d", err];
        goto bail;
    }
    *ismodule = true;
bail:
    return err;
}

NSString *extractValue(NSString *text, NSString *label, BOOL *has_label)
{
#if useLog
    NSLog(@"start extractValue");
#endif
    NSInteger left;
    NSString *value = nil;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    [scanner scanUpToString:label intoString:nil];
    left = [scanner scanLocation];
    if ([text length] == left) {
        *has_label = NO;
        return nil;
    }
    [scanner setScanLocation:left + [label length]];
    [scanner scanUpToString:@"@" intoString:&value];
    *has_label = YES;
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];;
}

OSErr moduleSpecfierWithTextDesc(AEDesc *ae_desc, AEDesc *prop_name,
                                 AEDesc *modspec, Boolean *ismodule, NSString **errmsg)
{
#if useLog
    NSLog(@"start moduleSpecfierWithTextDesc");
#endif
    OSErr err = noErr;
    const AEDesc *pname_ptr;
    *ismodule = false;
    NSString *vers = nil;
    NSString *name = nil;
    NSString *text = nil;
    BOOL has_label;

    AEDesc aedesc_copy;
    
    err = AEDuplicateDesc(ae_desc, &aedesc_copy);
    if (noErr != err) {
        *errmsg = @"Failed to AEDuplicateDesc";
        goto bail;
    }
    text = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&aedesc_copy] stringValue];
    if (![text hasPrefix:@"@"]) goto bail;
    has_label = NO;
    name = extractValue(text, @"@module", &has_label);
    if (!has_label) goto bail;
    if (name) {
        pname_ptr = [[name appleEventDescriptor] aeDesc];
    } else {
        pname_ptr = prop_name;
    }
    vers = extractValue(text, @"@version", &has_label);
    
    AEBuildError ae_err;
    if (vers) {
        err = AEBuildDesc(modspec, &ae_err, "MoSp{pnam:@, vers:@}",
                          pname_ptr, [[vers appleEventDescriptor] aeDesc]);
    } else {
        err = AEBuildDesc(modspec, &ae_err, "MoSp{pnam:@}",pname_ptr);
    }
    if (noErr != err) {
        *errmsg = [NSString stringWithFormat: @"Failed to AEBuildDesc in moduleSpecfierWithTextDesc with error %d", err];
        goto bail;
    }
    *ismodule = true;
bail:
#if useLog
    NSLog(@"end moduleSpecfierWithTextDesc");
#endif
    return err;
}

OSErr hasModuleLoadedHandler(ComponentInstance component, OSAID scriptID,
                             BOOL *result, NSString **errmsg)
{
    OSErr err;
    AEDescList handler_names = {typeNull, NULL};
    err = OSAGetHandlerNames(component, kOSAModeNull, scriptID, &handler_names);
    if (err != noErr) {
        *errmsg = @"Failed to OSAGetHandlerName in hasModuleLoadedHandler.";
        goto bail;
    }
    
    long count = 0;
    err = AECountItems(&handler_names, &count);
    if (err != noErr) goto bail;
    
    AEKeyword a_keyword;
    for (long n = 1; n <= count; n++) {
        AEDesc hname = {typeNull, NULL};
        err = AEGetNthDesc(&handler_names, n, typeWildCard, &a_keyword, &hname);
        if (err != noErr) goto loopbail;
        
        #if useLog
        NSLog(@"%@", [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&hname]);
        #endif
        switch (hname.descriptorType) {
            case typeUnicodeText:
                if ([[[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&hname] stringValue] isEqualToString:@"module_loaded_by"]) {
                    *result = YES;
                }
                break;
            case 'evnt':
                break;
        }
    loopbail:
        AEDisposeDesc(&hname);
        if (noErr != err) goto bail;
        if (*result) goto bail;
    }
bail:
    AEDisposeDesc(&handler_names);
    return err;
}

OSErr extractDependencies(ComponentInstance component, OSAID scriptID,
                          AEDescList *dependencies, NSString **errmsg)
{
#if useLog
    NSLog(@"start extractDependencies");
#endif
    OSErr err;
	
    AEDescList property_names = {typeNull, NULL};
    OSAID reqitems_id = kOSANullScript;
    AEDescList reqitems_desc = {typeNull, NULL};;
    NSAppleEventDescriptor *reqested_items = nil;
	AEDesc moduleSpecLabel;
	err = AECreateDesc(typeChar, MODULE_SPEC_LABEL, strlen(MODULE_SPEC_LABEL), &moduleSpecLabel);
	AEDesc moduleDependenciesLabel;
	err = AECreateDesc(typeChar, MODULE_DEPENDENCIES_LABEL, strlen(MODULE_DEPENDENCIES_LABEL), &moduleDependenciesLabel);

	err = AECreateList(NULL, 0, false, dependencies);
	if (err != noErr) goto bail;
	
	OSAID deplist_id = kOSANullScript;
	err = OSAGetProperty(component, kOSAModeNull, scriptID, &moduleDependenciesLabel, &deplist_id);
	if (noErr == err) {
#if useLog
		NSLog(@"%@", @"Found __module_dependencies__");
#endif
		err = OSACoerceToDesc(component, deplist_id, typeWildCard, kOSAModeNull, dependencies);
		goto bail;
	}
#if useLog
	NSLog(@"%@", @"Not Found __module_dependencies__");
#endif	
	err = OSAGetPropertyNames(component, kOSAModeNull, scriptID, &property_names);
	if (err != noErr) {
        *errmsg = @"Failed to OSAGetPropertyName in extractDependencies.";
		goto bail;
	}
#if useLog
	showAEDesc(&property_names);
#endif	
	long count = 0;
	err = AECountItems(&property_names, &count);
	if (err != noErr) goto bail;
	
	AEKeyword a_keyword;
	for (long n = 1; n <= count; n++) {
        AEDesc a_pname = {typeNull, NULL};
        OSAID prop_value_id = kOSANullScript;
        AEDesc dep_info = {typeNull, NULL};
        AEDesc prop_desc = {typeNull, NULL};
        AEDesc modspec_desc = {typeNull, NULL};
        AEDesc true_desc = {typeNull, NULL};
            
        err = AEGetNthDesc(&property_names, n, typeWildCard, &a_keyword, &a_pname);
        if (err != noErr) goto loopbail;
#if useLog
        showAEDesc(&a_pname);
#endif
        if (typeType == a_pname.descriptorType) {
            a_pname.descriptorType = typeProperty;
            OSType type_data;
            err = AEGetDescData(&a_pname, &type_data, sizeof(type_data));
            if (noErr != err) goto loopbail;
            if (type_data != 'pimr') {
                // if a_pname is not user defined property, skip
                goto loopbail;
            }
            err = OSAGetProperty(component, kOSAModeNull, scriptID, &a_pname, &reqitems_id);
            if (noErr != err) {
                *errmsg = [NSString stringWithFormat:@"Failed to OSAGetProperty for requested import items with error %d. Ignored.", err];
                goto loopbail;
            }
            err = OSACoerceToDesc(component, reqitems_id, typeWildCard, kOSAModeNull, &reqitems_desc);
            if (noErr != err) {
                *errmsg = [NSString stringWithFormat:@"Failed to OSACoerceToDesc for requested import items with error %d", err];
                goto loopbail;
            }
            reqested_items = [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&reqitems_desc];
            goto loopbail;
        }
        err = OSAGetProperty(component, kOSAModeNull, scriptID, &a_pname, &prop_value_id);
        if (noErr != err) {
            if (-1753 == err) {
                // class "CocoaClass" causes error in some cases.
                NSAppleEventDescriptor *pname_desc = [[NSAppleEventDescriptor alloc] initWithAEDescNoCopy:&a_pname];
                NSLog(@"Failed to OSAGetProperty for %@ in extractDependencies with error %d", [pname_desc stringValue], err);
                err = noErr;
            } else {
                *errmsg = [NSString stringWithFormat:@"Failed to OSAGetProperty in extractDependencies with error %d", err];
            }
            goto loopbail;
        }
        long is_script;
        err = OSAGetScriptInfo(component, prop_value_id, kOSAScriptIsTypeScriptContext, &is_script);
        if (err != noErr) goto loopbail;
        if (is_script) {
            goto loopbail;
        } else {
            err = OSACoerceToDesc(component, prop_value_id, typeWildCard, kOSAModeNull, &prop_desc);
            if (err != noErr) goto loopbail;
            DescType type_code;
            Size data_size = 0;
            Boolean ismodule = false;
            AEBuildError ae_err;
            switch (prop_desc.descriptorType) {
                case typeObjectSpecifier:
                    err = ConvertToModuleSpecifier(&prop_desc, &modspec_desc,
                                                   reqested_items, &ismodule, errmsg);
                    if (noErr != err) {
                        NSLog(@"Failed to ConvertToModuleSpecifier with error %d", err);
                    }
                    if (!ismodule) goto loopbail;
                    AECreateDesc(typeTrue, NULL, 0, &true_desc);
                    err = AEBuildDesc(&dep_info, &ae_err, "DpIf{pnam:@, MoSp:@, fmUs:@}",&a_pname, &modspec_desc, &true_desc);
                    if (noErr != err) {
                        NSLog(@"Failed to AEBuildDesc from typeObjectSpecifier with error %d", err);
                    }
                    break;
                case typeModuleSpecifier:
                    err = AESizeOfKeyDesc(&prop_desc, keyAEName, &type_code, &data_size);
                    if (!data_size) {
                        err = AEPutKeyDesc(&prop_desc, keyAEName, &a_pname);
                        if (noErr != err) goto loopbail;
                    }
                    err = AEBuildDesc(&dep_info, &ae_err, "DpIf{pnam:@, MoSp:@}",&a_pname, &prop_desc);
                    if (noErr != err) {
                        NSLog(@"Failed to AEBuildDesc from typeModuleSpecifier with error %d", err);
                    }
                    break;
                case typeUnicodeText:
                    err = moduleSpecfierWithTextDesc(&prop_desc, &a_pname, &modspec_desc, &ismodule, errmsg);
                    if (!ismodule) goto loopbail;
                    err = AEBuildDesc(&dep_info, &ae_err, "DpIf{pnam:@, MoSp:@}",&a_pname, &modspec_desc);
                    if (noErr != err) {
                        NSLog(@"Failed to AEBuildDesc from typeUnicodeText with error %d", err);
                    }
                    break;
                default:
                    goto loopbail;
            }
            
        }
        
        if (err != noErr) {
            *errmsg = @"Error in loop in extractDependencies";
            goto loopbail;
        }
        AEPutDesc(dependencies, 0, &dep_info);
        
    loopbail:
        AEDisposeDesc(&a_pname);
        AEDisposeDesc(&prop_desc);
        AEDisposeDesc(&dep_info);
        AEDisposeDesc(&modspec_desc);
        AEDisposeDesc(&true_desc);
        OSADispose(component, prop_value_id);
        if (noErr != err) goto bail;
	}
bail:
	AEDisposeDesc(&property_names);
	AEDisposeDesc(&moduleSpecLabel);
	AEDisposeDesc(&moduleDependenciesLabel);
    OSADispose(component, reqitems_id);
#if useLog
    NSLog(@"end extractDependencies");
#endif
    return err;
}

