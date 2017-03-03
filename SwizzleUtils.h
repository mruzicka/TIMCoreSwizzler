// vim: filetype=objc

#import <Foundation/Foundation.h>


typedef void (*SULogger) (NSString *format, ...);


void SUNSLogvWithHeader (NSString *header, NSString *format, va_list args);

BOOL SUWrapBundle (NSString *bundlePath, NSBundle **wrappedBundle, SULogger logger);

BOOL SUUnwrapBundle (NSBundle **wrappedBundle, SULogger logger);
