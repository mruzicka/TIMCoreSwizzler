#import "TextInputMenuSwizzle.h"


#ifndef TCS_WRAPPED_BUNDLE_PATH
#define TCS_WRAPPED_BUNDLE_PATH "/System/Library/CoreServices/Menu Extras/TextInput.menu/Contents/PrivateSupport/TIMCore.bundle"
#endif


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


static NSBundle *_wrappedBundle;
BOOL _swizzled;


__attribute__ ((constructor)) static void load (void) {
	{
		NSBundle *bundle;
		NSString *error;

		if (!(bundle = loadBundle (@TCS_WRAPPED_BUNDLE_PATH, &error)))
			NSLog (@"Failed to load the wrapped bundle - %s: %@", TCS_WRAPPED_BUNDLE_PATH, error);
		else
			_wrappedBundle = bundle;
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
		NSBundle *bundle = _wrappedBundle;
		if (bundle) {
			_wrappedBundle = nil;
			[bundle unload];
		}
	}
}
