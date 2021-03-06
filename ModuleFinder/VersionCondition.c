#include <CoreFoundation/CoreFoundation.h>
#include "TXRegularExpression.h"
#include "VersionCondition.h"

#include "AEUtils.h"

#define useLog 0

#define SafeRelease(v) if(v) CFRelease(v)

#pragma mark VersoionCondition

TXRegexRef VersionConditionPattern(CFStringRef *errmsg)
{
	static TXRegexRef verpattern = NULL;
	if (!verpattern) {
		UParseError pe;
		UErrorCode status = U_ZERO_ERROR;
		verpattern = TXRegexCreate(kCFAllocatorDefault, CFSTR("\\s*(<|>|>=|<=)?\\s*([0-9\\.]+[a-z]?)\\s*"), 0, &pe, &status);
		if (U_ZERO_ERROR != status) {
			CFStringRef pemsg = CFStringCreateWithFormattingParseError(&pe);
			*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, 
												 CFSTR("Failed to compile pattern of VersionCondition. %@"),
												 pemsg);
			SafeRelease(pemsg);
			return NULL;
		}
	}
	
	UErrorCode status = U_ZERO_ERROR;
	TXRegexRef verpattern_wk = TXRegexCreateCopy(kCFAllocatorDefault, verpattern, &status);
	if (U_ZERO_ERROR != status) {
		*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, 
										   CFSTR("Failed to make pattern of with error : %d"),
										   status);		
	}
	return verpattern_wk;
}

VersionCondition *VersionConditionCreate(CFStringRef opstring, CFStringRef verstring)
{
	VersionCondition *vc = malloc(sizeof(VersionCondition));	
	if (CFStringCompare(opstring, CFSTR(""), 0) == kCFCompareEqualTo) {
		vc->less_or_greater = kCFCompareGreaterThan;
		vc->allow_equal = true;
		goto bail;
	}	
	if (CFStringCompare(opstring, CFSTR(">"), 0) == kCFCompareEqualTo) {
		vc->less_or_greater = kCFCompareGreaterThan;
		vc->allow_equal = false;
		goto bail;
	}
	
	if (CFStringCompare(opstring, CFSTR("<"), 0) == kCFCompareEqualTo) {
		vc->less_or_greater = kCFCompareLessThan;
		vc->allow_equal = false;
		goto bail;
	}
	if (CFStringCompare(opstring, CFSTR(">="), 0) == kCFCompareEqualTo) {
		vc->less_or_greater = kCFCompareGreaterThan;
		vc->allow_equal = true;
		goto bail;
	}
	if (CFStringCompare(opstring, CFSTR("<="), 0) == kCFCompareEqualTo) {
		vc->less_or_greater = kCFCompareLessThan;
		vc->allow_equal = true;
		goto bail;
	}
	free(vc);
	return NULL;
bail:
	vc->version_string = CFRetain(verstring);
	return vc;
}

VersionCondition *VersionConditionCreateWithString(CFStringRef condition, CFStringRef *errmsg)
{
	VersionCondition *vc = NULL;
	TXRegexRef verpattern =NULL;
	CFArrayRef matched = NULL;
	verpattern = VersionConditionPattern(errmsg);
	if (!verpattern) goto bail;
	UErrorCode status = U_ZERO_ERROR;
	 matched = CFStringCreateArrayWithFirstMatch(condition,  verpattern, 0, &status);
	if (!matched) goto bail;
	
	vc = VersionConditionCreate(CFArrayGetValueAtIndex(matched, 1), CFArrayGetValueAtIndex(matched, 2));	
bail:
	SafeRelease(matched);
	SafeRelease(verpattern);
    return vc;
}

void VersionConditionFree(VersionCondition *vc)
{
#if useLog
	fprintf(stderr, "start VersionConditionFree\n"); 
#endif	
	CFRelease(vc->version_string);
	free(vc);
#if useLog
	fprintf(stderr, "end VersionConditionFree\n"); 
#endif		
}

Boolean VersionConditionIsSatisfied(VersionCondition *condition, CFStringRef version)
{
	CFComparisonResult compresult = CFStringCompare(version, condition->version_string, kCFCompareNumerically);
	Boolean is_satisfy = false;
	switch (compresult) {
		case kCFCompareEqualTo:
			if (condition->allow_equal) is_satisfy =true;			
			break;
		default:
			if (compresult == condition->less_or_greater) is_satisfy = true;
			break;
	}
	
	return is_satisfy;
}

#pragma mark VersionConditionSet

VersionConditionSet *VersionConditionSetCreate(CFStringRef condition, CFStringRef *errmsg)
{
	CFArrayRef array = NULL;
	VersionConditionSet *vercond_set = NULL;
	VersionCondition **vercond_list = NULL;
	
	TXRegexRef verpattern = VersionConditionPattern(errmsg);
	if (!verpattern) goto bail;
	UErrorCode status = U_ZERO_ERROR;
	array = CFStringCreateArrayWithAllMatches(condition, verpattern, &status);
	if (U_ZERO_ERROR != status) {
		*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
							   CFSTR("Error in VersionCoditionSetCreate number : %d"), status);
		goto bail;
	}
	CFIndex len = 0;
	if (array) len = CFArrayGetCount(array);
	if (!len) {
		//*errmsg = CFSTR("No mathes in Version condition string.");
		*errmsg = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
										CFSTR("Failed to parse the version condition \"%@\"."), condition);
		goto bail;
	}
		
	vercond_list = (VersionCondition **)malloc(len*sizeof(VersionCondition *));
	if (!vercond_list) {
		*errmsg = CFSTR("Failed to allocate an array of VersionCondition");
		goto bail;
	}
	
	for (CFIndex n=0; n < len; n++) {
		CFArrayRef subarray = CFArrayGetValueAtIndex(array, n);
		VersionCondition *vercond = VersionConditionCreate(CFArrayGetValueAtIndex(subarray, 1),
														   CFArrayGetValueAtIndex(subarray, 2));
		vercond_list[n] = vercond;
	}
	
	vercond_set = malloc(sizeof(VersionConditionSet));
	if (!vercond_set) {
		*errmsg = CFSTR("Failed to allocate VersionConditionSet");
		for (CFIndex n=0; n < len; n++) {
			free(vercond_list[n]);
		}
		free(vercond_list);
		goto bail;
	}
	vercond_set->length = len;
	vercond_set->conditions = vercond_list;
	
bail:	
	SafeRelease(array);
	SafeRelease(verpattern);
	return vercond_set;
}
     
void VersionConditionSetFree(VersionConditionSet *vercond_set)
{
#if useLog
	fprintf(stderr, "VersionConditionSetFree\n"); 
#endif		
	if (!vercond_set) return;
	VersionCondition **vclist = vercond_set->conditions;
	for (CFIndex n = 0; n < vercond_set->length; n++) {
		VersionConditionFree(vclist[n]);
	}
	free(vclist);
	free(vercond_set);
#if useLog
	fprintf(stderr, "end VersionConditionSetFree\n"); 
#endif			
}

Boolean VersionConditionSetIsSatisfied(VersionConditionSet *vercond_set, CFStringRef version)
{
	VersionCondition **vclist = vercond_set->conditions;
	for (CFIndex n = 0; n < vercond_set->length; n++) {
		if (!VersionConditionIsSatisfied(vclist[n], version)) return false;
	}
	return true;
}
