#import "AppleTextInputMenuSwizzle.h"


#ifndef LWIMU_WRAPPED_BUNDLE_PATH
#define LWIMU_WRAPPED_BUNDLE_PATH "/System/Library/LoginPlugins/DisplayServices.loginPlugin"
#endif

#define LWIMU_TIM_CORE_BUNDLE_PATH "/System/Library/CoreServices/Menu Extras/TextInput.menu/Contents/SharedSupport/TIMCore.bundle"


static NSBundle *loadBundle (NSString *bundlePath, NSString **error) {
	NSBundle *bundle = [NSBundle bundleWithPath: bundlePath];
	if (!bundle) {
		if (error)
			*error = @"Bundle could not be found/opened.";
		return nil;
	}

	NSError *frameworkError;
	if (![bundle loadAndReturnError: &frameworkError]) {
		if (error)
			*error = [frameworkError localizedFailureReason];
		return nil;
	}

	return bundle;
}


static NSBundle *_originalBundle;
BOOL _swizzled;


__attribute__ ((constructor)) static void load (void) {
	{
		NSBundle *bundle;
		NSString *error;

		if (!(bundle = loadBundle (@LWIMU_WRAPPED_BUNDLE_PATH, &error)))
			NSLog (@"Failed to load the wrapped bundle - %s: %@", LWIMU_WRAPPED_BUNDLE_PATH, error);
		else
			_originalBundle = bundle;

		if (!(bundle = loadBundle (@LWIMU_TIM_CORE_BUNDLE_PATH, &error))) {
			NSLog (@"Failed to load the TIMCore bundle - %s: %@", LWIMU_TIM_CORE_BUNDLE_PATH, error);
			return;
		}
	}

	if ((_swizzled = swizzleTextInputMenuDelegate ()))
		NSLog (@"Successfully swizzled TIMCore");
}

__attribute__ ((destructor)) static void unload (void) {
	if (_swizzled) {
		if (!(_swizzled = !unswizzleTextInputMenuDelegate ()))
			NSLog (@"Successfully unswizzled TIMCore");
	}

	{
		NSBundle *bundle = _originalBundle;
		if (bundle) {
			_originalBundle = nil;
			[bundle unload];
		}
	}
}
