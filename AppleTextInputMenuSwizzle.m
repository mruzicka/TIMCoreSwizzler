#import "AppleTextInputMenuSwizzle.h"
#include <objc/objc-runtime.h>


#define LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS "TIMPrivate"


Ivar _fSourceListContainsOnlyCurrentSource;
IMP _originalUpdateKeyboardInputSources;


// this method is used to handle the kTISNotifySelectedKeyboardInputSourceChanged notifications
void swizzledUpdateKeyboardInputSources (id self, SEL selector, NSNotification *notification) {
	if ((BOOL) object_getIvar (self, _fSourceListContainsOnlyCurrentSource)) {
		// if the input sources are not loaded yet, make sure we at least
		// re-set the initial input source, otherwise the notification is
		// effectively ignored
		objc_msgSend (self, @selector (createInitialInputSourceList));
		objc_msgSend (self, @selector (setInitialInputSource:), YES);
	} else {
		// if the input sources are already loaded, call the original method
		// as it works just fine in that case
		_originalUpdateKeyboardInputSources (self, selector, notification);
	}
}

BOOL swizzleTextInputMenuDelegate (void) {
	Class textInputMenuDelegateClass = objc_getClass (LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS);
	if (!textInputMenuDelegateClass) {
		NSLog (@"Could not find the class to swizzle: %s", LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS);
		return NO;
	}

	Method updateKeyboardInputSources_;
	if (
		!class_getInstanceMethod (textInputMenuDelegateClass, @selector (createInitialInputSourceList))
		||
		!class_getInstanceMethod (textInputMenuDelegateClass, @selector (setInitialInputSource:))
		||
		!(updateKeyboardInputSources_ = class_getInstanceMethod (textInputMenuDelegateClass, @selector (updateKeyboardInputSources:)))
		||
		!(_fSourceListContainsOnlyCurrentSource = class_getInstanceVariable (textInputMenuDelegateClass, "fSourceListContainsOnlyCurrentSource"))
	) {
		NSLog (@"The %s class doesn't contain the expected methods and/or variables. Bailing out.", LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS);
		return NO;
	}

	_originalUpdateKeyboardInputSources = method_setImplementation (updateKeyboardInputSources_, (IMP) &swizzledUpdateKeyboardInputSources);
	return YES;
}

BOOL unswizzleTextInputMenuDelegate (void) {
	if (!_originalUpdateKeyboardInputSources)
		return NO;

	Class textInputMenuDelegateClass = objc_getClass (LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS);
	if (!textInputMenuDelegateClass) {
		NSLog (@"Could not find the swizzled class: %s", LWIMU_TEXT_INPUT_MENU_DELEGATE_CLASS);
		return NO;
	}

	Method updateKeyboardInputSources_ = class_getInstanceMethod (textInputMenuDelegateClass, @selector (updateKeyboardInputSources:));
	if (!updateKeyboardInputSources_) {
		NSLog (@"Could not find the swizzled method: %s", sel_getName (@selector (updateKeyboardInputSources:)));
		return NO;
	}

	method_setImplementation (updateKeyboardInputSources_, _originalUpdateKeyboardInputSources);
	_originalUpdateKeyboardInputSources = NULL;
	return YES;
}
