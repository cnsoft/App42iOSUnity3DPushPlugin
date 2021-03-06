//
//  App42PushHandlerInternal.m
//  PushSDK
//
//  Created by Rajeev Ranjan on 06/08/13.
//  Copyright (c) 2013 ShepHertz Technologies Pvt Ltd. All rights reserved.
//

#import "App42PushHandlerInternal.h"
#import <objc/runtime.h>


void registerForRemoteNotifications()
{
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}



char * listenerGameObject = 0;
void setListenerGameObject(char * listenerName)
{
	free(listenerGameObject);
    listenerGameObject = 0;
	int len = strlen(listenerName);
	listenerGameObject = malloc(len+1);
	strcpy(listenerGameObject, listenerName);
}



@implementation UIApplication(App42PushHandlerInternal)

+(void)load
{
    NSLog(@"%s",__FUNCTION__);
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(setApp42Delegate:)));
	
	UIApplication *app = [UIApplication sharedApplication];
	NSLog(@"Initializing application: %@, %@", app, app.delegate);
}

BOOL app42RunTimeDidFinishLaunching(id self, SEL _cmd, id application, id launchOptions)
{
	BOOL result = YES;
	
	if ([self respondsToSelector:@selector(application:app42didFinishLaunchingWithOptions:)])
    {
		result = (BOOL) [self application:application app42didFinishLaunchingWithOptions:launchOptions];
	}
    else
    {
		[self applicationDidFinishLaunching:application];
		result = YES;
	}
	
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
	
	return result;
}


void app42RunTimeDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, id application, id devToken)
{
	if ([self respondsToSelector:@selector(application:app42didRegisterForRemoteNotificationsWithDeviceToken:)])
    {
		[self application:application app42didRegisterForRemoteNotificationsWithDeviceToken:devToken];
	}
	// Prepare the Device Token for Registration (remove spaces and < >)
	NSString *deviceToken = [[[[devToken description]
                            stringByReplacingOccurrencesOfString:@"<"withString:@""]
                           stringByReplacingOccurrencesOfString:@">" withString:@""]
                          stringByReplacingOccurrencesOfString: @" " withString: @""];
    NSLog(@"deviceToken=%@",deviceToken);
    const char * str = [deviceToken UTF8String];
    UnitySendMessage(listenerGameObject, "onDidRegisterForRemoteNotificationsWithDeviceToken", str);

}

void app42RunTimeDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, id application, id error)
{
	if ([self respondsToSelector:@selector(application:app42didFailToRegisterForRemoteNotificationsWithError:)])
    {
		[self application:application app42didFailToRegisterForRemoteNotificationsWithError:error];
	}
	NSString *errorString = [error description];
    const char * str = [errorString UTF8String];
    UnitySendMessage(listenerGameObject, "onDidFailToRegisterForRemoteNotificationsWithError", str);
	NSLog(@"Error registering for push notifications. Error: %@", error);
}

void app42RunTimeDidReceiveRemoteNotification(id self, SEL _cmd, id application, id userInfo)
{
	if ([self respondsToSelector:@selector(application:app42didReceiveRemoteNotification:)])
    {
		[self application:application app42didReceiveRemoteNotification:userInfo];
	}
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    NSString *jsonString = nil;
    if (! jsonData)
    {
        NSLog(@"Got an error: %@", error);
    }
    else
    {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"jsonString= %@",jsonString);
    }
    
    if (jsonString)
    {
        const char * str = [jsonString UTF8String];
        UnitySendMessage(listenerGameObject, "onPushNotificationsReceived", str);
    }
    else
    {
        UnitySendMessage(listenerGameObject, "onPushNotificationsReceived", nil);
    }
}



static void exchangeMethodImplementations(Class class, SEL oldMethod, SEL newMethod, IMP impl, const char * signature)
{
	Method method = nil;
    //Check whether method exists in the class
	method = class_getInstanceMethod(class, oldMethod);
	
	if (method)
    {
		//if method exists add a new method 
		class_addMethod(class, newMethod, impl, signature);
        //and then exchange with original method implementation
		method_exchangeImplementations(class_getInstanceMethod(class, oldMethod), class_getInstanceMethod(class, newMethod));
	}
    else
    {
		//if method does not exist, simply add as orignal method
		class_addMethod(class, oldMethod, impl, signature);
	}
}

- (void) setApp42Delegate:(id<UIApplicationDelegate>)delegate
{
    
	static Class delegateClass = nil;
	
	if(delegateClass == [delegate class])
	{
		[self setApp42Delegate:delegate];
		return;
	}
	
	delegateClass = [delegate class];
    
	exchangeMethodImplementations(delegateClass, @selector(application:didFinishLaunchingWithOptions:),
                                  @selector(application:app42didFinishLaunchingWithOptions:), (IMP)app42RunTimeDidFinishLaunching, "v@:::");
    exchangeMethodImplementations(delegateClass, @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:),
		   @selector(application:app42didRegisterForRemoteNotificationsWithDeviceToken:), (IMP)app42RunTimeDidRegisterForRemoteNotificationsWithDeviceToken, "v@:::");
    
	exchangeMethodImplementations(delegateClass, @selector(application:didFailToRegisterForRemoteNotificationsWithError:),
		   @selector(application:app42didFailToRegisterForRemoteNotificationsWithError:), (IMP)app42RunTimeDidFailToRegisterForRemoteNotificationsWithError, "v@:::");
    
	exchangeMethodImplementations(delegateClass, @selector(application:didReceiveRemoteNotification:),
		   @selector(application:app42didReceiveRemoteNotification:), (IMP)app42RunTimeDidReceiveRemoteNotification, "v@:::");
    
	[self setApp42Delegate:delegate];
}


@end
