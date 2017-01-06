#import "TextInputMenuSwizzle.h"
#import <objc/objc-runtime.h>


#define TCS_TEXT_INPUT_MENU_DELEGATE_CLASS "TIMPrivate"


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
	} else
		// if the input sources are already loaded, call the original method
		// as it works just fine in that case
		_originalUpdateKeyboardInputSources (self, selector, notification);
}

BOOL swizzleTextInputMenuDelegate (void) {
	if (_originalUpdateKeyboardInputSources)
		return NO;

	Class textInputMenuDelegateClass = objc_getClass (TCS_TEXT_INPUT_MENU_DELEGATE_CLASS);
	if (!textInputMenuDelegateClass) {
		NSLog (@"%s: Could not find the class to swizzle: %s", TCS_LOG_HEADER, TCS_TEXT_INPUT_MENU_DELEGATE_CLASS);
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
		NSLog (@"%s: The %s class doesn't define the expected methods and/or variables. Bailing out.",
			TCS_LOG_HEADER, class_getName (textInputMenuDelegateClass)
		);
		return NO;
	}

	_originalUpdateKeyboardInputSources = method_setImplementation (updateKeyboardInputSources_, (IMP) &swizzledUpdateKeyboardInputSources);
	return YES;
}

BOOL unswizzleTextInputMenuDelegate (void) {
	if (!_originalUpdateKeyboardInputSources)
		return NO;

	Class textInputMenuDelegateClass = objc_getClass (TCS_TEXT_INPUT_MENU_DELEGATE_CLASS);
	if (!textInputMenuDelegateClass) {
		NSLog (@"%s: Could not find the swizzled class: %s", TCS_LOG_HEADER, TCS_TEXT_INPUT_MENU_DELEGATE_CLASS);
		return NO;
	}

	Method updateKeyboardInputSources_ = class_getInstanceMethod (textInputMenuDelegateClass, @selector (updateKeyboardInputSources:));
	if (!updateKeyboardInputSources_) {
		NSLog (@"%s: Could not find the swizzled method: %s", TCS_LOG_HEADER, sel_getName (@selector (updateKeyboardInputSources:)));
		return NO;
	}

	method_setImplementation (updateKeyboardInputSources_, _originalUpdateKeyboardInputSources);
	_originalUpdateKeyboardInputSources = NULL;
	return YES;
}
