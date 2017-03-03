#import "SwizzleUtils.h"
#import <objc/objc-runtime.h>

#ifndef TCS_WRAPPED_BUNDLE_PATH
#define TCS_WRAPPED_BUNDLE_PATH "/System/Library/CoreServices/Menu Extras/TextInput.menu/Contents/PrivateSupport/TIMCore.bundle"
#endif

#ifndef TCS_LOG_HEADER
#define TCS_LOG_HEADER "TIMCoreSwizzler"
#endif

#define TCS_TIM_PRIVATE_CLASS "TIMPrivate"


static Ivar _fSourceListContainsOnlyCurrentSource;
static IMP _originalUpdateKeyboardInputSources;


// this method is used to handle the kTISNotifySelectedKeyboardInputSourceChanged notifications
static void swizzledUpdateKeyboardInputSources (id self, SEL selector, NSNotification *notification) {
	if ((BOOL) object_getIvar (self, _fSourceListContainsOnlyCurrentSource)) {
		// if the input sources are not loaded yet, make sure we at least
		// re-set the initial input source, otherwise the notification is
		// effectively ignored
		objc_msgSend (self, @selector (createInitialInputSourceList));
		objc_msgSend (self, @selector (setInitialInputSource:), YES);
	} else
		// if the input sources are already loaded, call the original method
		// as it works just fine in that case
		_originalUpdateKeyboardInputSources (self, selector, notification);
}

static void logWithHeader (NSString *format, ...) {
	va_list args;

	va_start (args, format);
	SUNSLogvWithHeader (@TCS_LOG_HEADER, format, args);
	va_end (args);
}

static BOOL swizzleTIMPrivateClass (void) {
	if (_originalUpdateKeyboardInputSources)
		return NO;

	Class swizzleTargetClass = objc_getClass (TCS_TIM_PRIVATE_CLASS);
	if (!swizzleTargetClass) {
		logWithHeader (@"Could not find the class to swizzle: %s", TCS_TIM_PRIVATE_CLASS);
		return NO;
	}

	Method updateKeyboardInputSources_;
	if (
		!class_getInstanceMethod (swizzleTargetClass, @selector (createInitialInputSourceList))
		||
		!class_getInstanceMethod (swizzleTargetClass, @selector (setInitialInputSource:))
		||
		!(updateKeyboardInputSources_ = class_getInstanceMethod (swizzleTargetClass, @selector (updateKeyboardInputSources:)))
		||
		!(_fSourceListContainsOnlyCurrentSource = class_getInstanceVariable (swizzleTargetClass, "fSourceListContainsOnlyCurrentSource"))
	) {
		logWithHeader (@"The %s class doesn't define the expected methods and/or variables. Bailing out.", class_getName (swizzleTargetClass));
		return NO;
	}

	_originalUpdateKeyboardInputSources = method_setImplementation (updateKeyboardInputSources_, (IMP) &swizzledUpdateKeyboardInputSources);
	return YES;
}

static BOOL unswizzleTIMPrivateClass (void) {
	if (!_originalUpdateKeyboardInputSources)
		return NO;

	Class swizzleTargetClass = objc_getClass (TCS_TIM_PRIVATE_CLASS);
	if (!swizzleTargetClass) {
		logWithHeader (@"Could not find the swizzled class: %s", TCS_TIM_PRIVATE_CLASS);
		return NO;
	}

	Method updateKeyboardInputSources_ = class_getInstanceMethod (swizzleTargetClass, @selector (updateKeyboardInputSources:));
	if (!updateKeyboardInputSources_) {
		logWithHeader (@"Could not find the swizzled method: %s", sel_getName (@selector (updateKeyboardInputSources:)));
		return NO;
	}

	method_setImplementation (updateKeyboardInputSources_, _originalUpdateKeyboardInputSources);
	_originalUpdateKeyboardInputSources = NULL;
	return YES;
}


static NSBundle *_wrappedBundle;
static BOOL _swizzled;


static void __attribute__ ((constructor)) swizzle (void) {
	if (!SUWrapBundle (@TCS_WRAPPED_BUNDLE_PATH, &_wrappedBundle, &logWithHeader))
		return;

	if (!_swizzled && (_swizzled = swizzleTIMPrivateClass ()))
		logWithHeader (@"Successfully swizzled %@", _wrappedBundle.infoDictionary[(__bridge NSString *) kCFBundleNameKey]);
}

static void __attribute__ ((destructor)) unswizzle (void) {
	if (_swizzled && !(_swizzled = !unswizzleTIMPrivateClass ()))
		logWithHeader (@"Successfully unswizzled %@", _wrappedBundle.infoDictionary[(__bridge NSString *) kCFBundleNameKey]);

	SUUnwrapBundle (&_wrappedBundle, &logWithHeader);
}
