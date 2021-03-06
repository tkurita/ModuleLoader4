#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include "ModuleCondition.h"
#include "AEUtils.h"

#define useLog 0

CFStringRef CFStringCreateWithEscapingRegex(CFStringRef text, CFStringRef *errmsg)
{
	static TXRegexRef regexp = NULL;
	CFStringRef result = NULL;
	UErrorCode status = U_ZERO_ERROR;
	if (!regexp) {
		UParseError parse_error;
		regexp = TXRegexCreate(kCFAllocatorDefault, CFSTR("([\\.\\+\\(\\)\\*\\?\\[\\]\\^\\$\\\\])"),
                               0, &parse_error, &status);
		if (U_ZERO_ERROR != status) {
			CFStringRef parse_error_msg = CFStringCreateWithFormattingParseError(&parse_error);
			*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
						   CFSTR("Failed to compile regular expression. \n%@"), parse_error_msg);
			if (!parse_error_msg) CFRelease(parse_error_msg);
			return NULL;
		}
	} 
	TXRegexRef regexp_wk = TXRegexCreateCopy(kCFAllocatorDefault, regexp, &status);
	if (U_ZERO_ERROR != status) goto error;
	result = CFStringCreateByReplacingAllMatches(text, regexp_wk, CFSTR("\\\\$1"), &status);
	if (U_ZERO_ERROR != status) goto error;
	
	goto bail;
error:	
	*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
									   CFSTR("Failed to regex escaping with error : %d"), status);
bail:
	safeRelease(regexp_wk);
	return result;
}

ModuleCondition *ModuleConditionCreate(CFStringRef module_name, CFStringRef required_version, CFStringRef *errmsg)
{
	CFStringRef escaped_name = NULL;
	CFStringRef verpattern = NULL;
	CFMutableArrayRef subpath = NULL;
	ModuleCondition *module_condition = NULL;
    
	module_condition = malloc(sizeof(ModuleCondition));
	if (!module_condition) {
		fprintf(stderr, "Failed to allocate ModuleCondition.\n");
		goto bail;
	}
	module_condition->required_version = NULL;
	module_condition->pattern = NULL;
	module_condition->subpath = subpath;
	module_condition->name = CFRetain(module_name);
	if (required_version) {
		if (! (module_condition->required_version = VersionConditionSetCreate(required_version, errmsg))) {
			ModuleConditionFree(module_condition);module_condition = NULL;
			goto bail;
		}
	} else {
		module_condition->required_version = NULL;
	}
		
	if (! (escaped_name = CFStringCreateWithEscapingRegex(module_name, errmsg))) {
		ModuleConditionFree(module_condition);module_condition = NULL;
		goto bail;
	}
	
	verpattern = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, 
								CFSTR("^%@(-([0-9\\.]*\\d[a-z]?))?(\\.(scptd|scpt|applescript|app))?$"), escaped_name);
	UParseError parse_error;
	UErrorCode status = U_ZERO_ERROR;
	module_condition->pattern = TXRegexCreate(kCFAllocatorDefault,
                                              verpattern, UREGEX_CASE_INSENSITIVE, &parse_error, &status);
	if (U_ZERO_ERROR != status) {
		ModuleConditionFree(module_condition);module_condition = NULL;
	}
	
bail:	
	safeRelease(escaped_name);
	safeRelease(verpattern);
	return module_condition;
}

void ModuleConditionFree(ModuleCondition *module_condition)
{
#if useLog
	fprintf(stderr, "start ModuleConditionFree\n"); 
#endif	
	if (!module_condition) return;
	safeRelease(module_condition->name);
	safeRelease(module_condition->subpath);
	VersionConditionSetFree(module_condition->required_version);
	safeRelease(module_condition->pattern);
	free(module_condition);
#if useLog
	fprintf(stderr, "end ModuleConditionFree\n"); 
#endif		
}

Boolean ModuleConditionVersionIsSatisfied(ModuleCondition *module_condition, ModuleRef *module_ref)
{
	if (!module_condition->required_version) return true;
    CFStringRef version = ModuleRefGetVersion(module_ref);
	if (!version) return false;
	return VersionConditionSetIsSatisfied(module_condition->required_version, version);
}

Boolean ModuleConditionHasSubpath(ModuleCondition *module_condition)
{
	return (module_condition->subpath != NULL);
}

CFArrayRef ModuleConditionParseName(ModuleCondition *module_condition, CFStringRef name)
{
	UErrorCode status = U_ZERO_ERROR;
	CFArrayRef result = CFStringCreateArrayWithFirstMatch(name, module_condition->pattern, 0, &status);
	if (U_ZERO_ERROR != status) {
		safeRelease(result);
		result = NULL;
	}
	return result;
}
