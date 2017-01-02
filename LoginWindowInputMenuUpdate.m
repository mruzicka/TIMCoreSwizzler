#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import <objc/objc-runtime.h>


#ifndef LWIMU_WRAPPED_BUNDLE_PATH
#define LWIMU_WRAPPED_BUNDLE_PATH "/System/Library/LoginPlugins/DisplayServices.original.loginPlugin"
#endif

#ifndef LWIMU_BUNDLE_PRINCIPAL_CLASS
#define LWIMU_BUNDLE_PRINCIPAL_CLASS "LWIMUObserverSubClass"
#endif


static id LWIMUObserverSubClassInitImpl (id self, SEL selector) {
	struct objc_super super = {
		.receiver    = self,
		.super_class = class_getSuperclass (object_getClass (self))
	};
	id instance = objc_msgSendSuper (&super, selector);
	if (!instance) {
		NSLog (@"Failed to initialize subclass of the original DisplayServices login plugin principal class.");
		return nil;
	}

	[[NSDistributedNotificationCenter defaultCenter]
		addObserver: instance
		selector:    @selector (_LWIMU_handlekInputSourceChangedNotification:)
		name:        (__bridge NSString *) kTISNotifySelectedKeyboardInputSourceChanged
		object:      nil
	];

	return instance;
}

static void LWIMUObserverSubClassDeallocImpl (id self, SEL selector) {
	[[NSDistributedNotificationCenter defaultCenter]
		removeObserver: self
		name:           (__bridge NSString *) kTISNotifySelectedKeyboardInputSourceChanged
		object:         nil
	];

	struct objc_super super = {
		.receiver    = self,
		.super_class = class_getSuperclass (object_getClass (self))
	};
	objc_msgSendSuper (&super, selector);
}

static id LWIMUTraverseInstanceVariables (id object, NSArray *variableNames) {
	for (NSString *variableName in variableNames) {
		if (!(object = [object valueForKey: variableName]))
			return nil;
	}
	return object;
}

static void LWIMUObserverSubClassInputSourceChangedNotificationHandlerImpl (id self, SEL selector, NSNotification *notification) {
	Class class = NSClassFromString (@"LWBuiltInScreenLockAuthLion");
	if (!class) {
		NSLog (@"The LWBuiltInScreenLockAuthLion class is not known.");
		return;
	}

	id object;
	if (!(object = [class performSelector: @selector (sharedBuiltInAuthLion)])) {
		NSLog (@"Failed to obtain the shared LWBuiltInScreenLockAuthLion instance reference.");
		return;
	}

	if (!((BOOL) [object performSelector: @selector (lockUIIsOnScreen)]))
		return;

	if (!(object = LWIMUTraverseInstanceVariables (object,
		@[@"_screenLockWindowController", @"_statusController", @"_statusControllers"]
	))) {
		NSLog (@"Failed to obtain list of lock screen status controllers.");
		return;
	}

	if (![object isKindOfClass: [NSArray class]]) {
		NSLog (@"The list of the lock screen status controllers is not a NSArray.");
		return;
	}

	class = NSClassFromString (@"LUIIMStatusController");
	for (object in (NSArray *) object) {
		if ([object isKindOfClass: class])
			goto status_controller_found;
	}
	NSLog (@"LUIIMStatusController not found in the list of the lock screen status controllers.");
	return;

status_controller_found:
	// get the input menu UI object reference
	if (!(object = LWIMUTraverseInstanceVariables (object,
		@[@"_textInputMenu", @"_private"]
	))) {
		NSLog (@"Failed to obtain the Input Menu UI reference.");
		return;
	}

	// finally call update on the input menu UI
	[object performSelector: @selector (update)];
}


static NSBundle *_originalBundle;


__attribute__ ((constructor)) static void load (void) {
	NSBundle *originalBundle = [NSBundle bundleWithPath: @LWIMU_WRAPPED_BUNDLE_PATH];
	if (!originalBundle) {
		NSLog (@"Failed to load the wrapped bundle: %s", LWIMU_WRAPPED_BUNDLE_PATH);
		return;
	}

	Class superClass = originalBundle.principalClass;
	if (!superClass) {
		NSLog (@"Failed to load original DisplayServices login plugin principal class.");
		return;
	}

	Class subClass = objc_allocateClassPair (superClass, LWIMU_BUNDLE_PRINCIPAL_CLASS, 0);
	if (!subClass) {
		NSLog (@"Failed to create subclass of the original DisplayServices login plugin principal class.");
		return;
	}

	if (!(
		class_addMethod (subClass, sel_getUid ("init"), (IMP) &LWIMUObserverSubClassInitImpl, "@@:")
		&&
		class_addMethod (subClass, sel_getUid ("dealloc"), (IMP) &LWIMUObserverSubClassDeallocImpl, "v@:")
		&&
		class_addMethod (subClass, sel_getUid ("_LWIMU_handlekInputSourceChangedNotification:"), (IMP) &LWIMUObserverSubClassInputSourceChangedNotificationHandlerImpl, "v@:@")
	)) {
		NSLog (@"Failed to add methods to the subclass of the original DisplayServices login plugin principal class.");
		return;
	}

	objc_registerClassPair (subClass);

	// keep a reference to the original bundle
	_originalBundle = originalBundle;
}

__attribute__ ((destructor)) static void unload (void) {
	NSBundle *originalBundle = _originalBundle;
	if (originalBundle) {
		_originalBundle = nil;
		[originalBundle unload];
	}
}
