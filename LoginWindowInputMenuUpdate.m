#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>


#ifndef LWIMU_WRAPPED_BUNDLE_PATH
#define LWIMU_WRAPPED_BUNDLE_PATH "/System/Library/LoginPlugins/DisplayServices.loginPlugin"
#endif

#ifndef LWIMU_SCREEN_LOCK_AUTH_CLASS_NAME
#define LWIMU_SCREEN_LOCK_AUTH_CLASS_NAME "LWBuiltInScreenLockAuthLion"
#endif

#ifndef LWIMU_STATUS_CONTROLLER_CLASS_NAME
#define LWIMU_STATUS_CONTROLLER_CLASS_NAME "LUIIMStatusController"
#endif


@interface LWIMUInputSourceChangedObserver : NSObject
@end

@implementation LWIMUInputSourceChangedObserver {
	BOOL _observing;
	id __weak _sharedScreenLockAuthInstance;
	Class __weak _statusControllerClass;
}
	- (instancetype) init {
		if (self = [super init]) {
			[[NSDistributedNotificationCenter defaultCenter]
				addObserver: self
				selector:    @selector (handleInputSourceChangedNotification:)
				name:        (__bridge NSString *) kTISNotifySelectedKeyboardInputSourceChanged
				object:      nil
			];
			_observing = YES;

			// this causes the internal UI not to be used
			// cache these or log errors
			// [self getSharedScreenLockAuthInstance] && [self getStatusControllerClass];
		}
		return self;
	}

	- (id) getSharedScreenLockAuthInstance {
		id instance = _sharedScreenLockAuthInstance;
		while (!instance) {
			Class screenLockAuthClass = getClass (@LWIMU_SCREEN_LOCK_AUTH_CLASS_NAME);
			if (!screenLockAuthClass)
				break;

			if (!(instance = [screenLockAuthClass performSelector: @selector (sharedBuiltInAuthLion)])) {
				NSLog (@"Failed to obtain the shared %@ instance reference.",
					NSStringFromClass (screenLockAuthClass)
				);
				break;
			}

			_sharedScreenLockAuthInstance = instance;
			break;
		}
		return instance;
	}

	- (Class) getStatusControllerClass {
		Class class = _statusControllerClass;
		while (!class) {
			if (!(class = getClass (@LWIMU_STATUS_CONTROLLER_CLASS_NAME)))
				break;

			_statusControllerClass = class;
			break;
		}
		return class;
	}

	- (void) handleInputSourceChangedNotification: (NSNotification *) notification {
		id object = [self getSharedScreenLockAuthInstance];
		if (!object)
			return;

		if (!((BOOL) [object performSelector: @selector (lockUIIsOnScreen)]))
			return;

#ifdef LWIMU_DEBUG
		describeObject (object);
#endif

		if (!(object = traverseInstanceVariables (object,
			@[@"_screenLockWindowController", @"_statusController", @"_statusControllers"]
		))) {
			NSLog (@"Failed to obtain the list of lock screen status controllers.");
			return;
		}
		if (![object isKindOfClass: [NSArray class]]) {
			NSLog (@"The list of the lock screen status controllers is not a NSArray.");
			return;
		}

		{
			Class statusControllerClass = [self getStatusControllerClass];
			if (!statusControllerClass)
				return;

			for (object in (NSArray *) object) {
#ifdef LWIMU_DEBUG
				describeObject (object);
#endif
				if ([object isKindOfClass: statusControllerClass])
					goto status_controller_found;
			}
			NSLog (@"No %@ instance found among the lock screen status controllers.",
				NSStringFromClass (statusControllerClass)
			);
			return;
		}

	status_controller_found:
		// get the Text Input Menu delegate reference
		if (!(object = traverseInstanceVariables (object,
			@[@"_textInputMenu", @"_private"]
		))) {
			NSLog (@"Failed to obtain the Text Input Menu delegate reference.");
			return;
		}

		// if the menu is not fully initialized, it doesn't handle the input source changed
		// notifications well, here we make up for that by partially re-doing its initial
		// initialization
		if ([[object valueForKey: @"fSourceListContainsOnlyCurrentSource"] boolValue]) {
			[object performSelector: @selector (createInitialInputSourceList)];
			[object
				performSelector: @selector (setInitialInputSource:)
				withObject:      (__bridge id) (void *) ((uint8_t *) NULL + YES)
			];
		}
	}

	- (void) dealloc {
		if (_observing)
			[[NSDistributedNotificationCenter defaultCenter]
				removeObserver: self
				name:           (__bridge NSString *) kTISNotifySelectedKeyboardInputSourceChanged
				object:         nil
			];
	}

	static Class getClass (NSString *className) {
		Class class = NSClassFromString (className);
		if (!class)
			NSLog (@"The %@ class is not known.", className);
		return class;
	}

#ifdef LWIMU_DEBUG
	static NSString *describeObjectRecursively (id object, NSString *indent) {
		NSMutableArray *classes = [NSMutableArray new];

		for (Class class = [object class];;) {
			[classes addObject: NSStringFromClass (class)];

			if (!(class = [class superclass]))
				break;
		}

		NSMutableString *description = [NSMutableString new];
		[
			[NSString stringWithFormat: @"%@\n%@",
				[classes componentsJoinedByString: @" : "], object
			]
				enumerateLinesUsingBlock: ^ (NSString *line, BOOL *stop) {
					[description appendFormat: @"%@%@\n",
						[description length] ? indent : @"", line
					];
				}
		];

		if ([object respondsToSelector: @selector (delegate)])
			[description appendFormat: @"%@Delegate: %@",
				indent,
				describeObjectRecursively (
					[object performSelector: @selector (delegate)],
					[indent stringByAppendingString: @"        "]
				)
			];

		return description;
	}

	static void describeObject (id object) {
		NSLog (@"Object: %@", describeObjectRecursively (object, @""));
	}
#endif

	static id traverseInstanceVariables (id object, NSArray *variableNames) {
		for (NSString *variableName in variableNames) {
			if (!(object = [object valueForKey: variableName]))
				break;
#ifdef LWIMU_DEBUG
			describeObject (object);
#endif
		}
		return object;
	}
@end


static NSBundle *_originalBundle;
static LWIMUInputSourceChangedObserver *_observer;


__attribute__ ((constructor)) static void load (void) {
	NSBundle *originalBundle = [NSBundle bundleWithPath: @LWIMU_WRAPPED_BUNDLE_PATH];
	id error;
	if (
		(!originalBundle && (error = @"Bundle could not be found/opened."))
		||
		(![originalBundle loadAndReturnError: &error] && (error = [error localizedFailureReason]))
	)
		NSLog (@"Failed to load the wrapped bundle - %s: %@", LWIMU_WRAPPED_BUNDLE_PATH, error);
	else
		_originalBundle = originalBundle;

	if (!(_observer = [LWIMUInputSourceChangedObserver new]))
		NSLog (@"Failed to setup the Input Source Changed notification observer.");
}

__attribute__ ((destructor)) static void unload (void) {
	{
		LWIMUInputSourceChangedObserver *observer = _observer;
		if (observer)
			_observer = nil;
	}

	{
		NSBundle *originalBundle = _originalBundle;
		if (originalBundle) {
			_originalBundle = nil;
			[originalBundle unload];
		}
	}
}
