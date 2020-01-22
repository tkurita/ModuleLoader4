#ifndef findModule_h
#define findModule_h

#include "ModuleCondition.h"

void setAdditionalModulePaths(CFArrayRef array);
NSArray *additionalModulePaths(void);
NSArray *copyDefaultModulePaths(void);
OSErr findModuleWithName(NSURL *container_url,
                         ModuleCondition *module_condition,
                         Boolean searchSubFolders,
                         ModuleRef** moudle_ref);
OSErr findModuleWithSubPath(NSURL *container_url,
                            ModuleCondition *module_condition,
                            Boolean searchSubFolders,
                            ModuleRef** module_ref);
OSErr findModule(ModuleCondition *module_condition,
                 NSArray *additionalPaths,
                 Boolean searchSubFolders,
                 Boolean ignoreDefaultPaths,
				 ModuleRef** moduleRef,
                 NSMutableArray** searchedPaths);
OSErr pickupModuleAtFolder(CFURLRef container_url, ModuleCondition* module_condition, ModuleRef** out_module_ref);

ModuleRef *findModuleWithEvent(const AppleEvent *ev, NSScriptCommand *command);

#endif
