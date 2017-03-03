#import "SwizzleUtils.h"

static NSBundle *SULoadBundle (NSString *bundlePath, NSString **error) {
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

void SUNSLogvWithHeader (NSString *header, NSString *format, va_list args) {
	NSLog (@"%@: %@", header, [[NSString alloc] initWithFormat: format arguments: args]);
}

BOOL SUWrapBundle (NSString *bundlePath, NSBundle **wrappedBundle, SULogger logger) {
	if (*wrappedBundle)
		return YES;

	NSBundle *bundle;
	NSString *error;
	if (!(bundle = SULoadBundle (bundlePath, &error))) {
		logger (@"Failed to load the wrapped bundle - %@: %@", bundlePath, error);
		return NO;
	}

	// the casts are effectively a retain
	*wrappedBundle = (__bridge NSBundle *) (__bridge_retained void *) bundle;
	return YES;
}

BOOL SUUnwrapBundle (NSBundle **wrappedBundle, SULogger logger) {
	NSBundle *bundle = *wrappedBundle;
	if (!bundle)
		return YES;

	if (![bundle unload])
		return NO;

	// the casts are effectively a release
	bundle = (__bridge_transfer NSBundle *) (__bridge void *) *wrappedBundle;
	*wrappedBundle = nil;
	return YES;
}
