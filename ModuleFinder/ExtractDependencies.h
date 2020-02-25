OSErr extractDependencies(ComponentInstance component, OSAID scriptID,
                          AEDescList *dependencies, NSString **errmsg);

OSErr hasModuleLoadedHandler(ComponentInstance component, OSAID scriptID,
                            BOOL *result, NSString **errmsg);
