//
//  LNSafePropertySetting.m
//  LNTreadTest
//
//  Created by ioser on 2019/1/29.
//  Copyright © 2019年 Lenny. All rights reserved.
//

#import "LNSafePropertySetting.h"
#import <objc/runtime.h>

static dispatch_queue_t initQueue;
static void* initQueueKey;
static void* initQueueContext;

@implementation LNSafePropertySetting

void swizzleMethod(Class class, SEL originSetter, SEL newSetter)
{
    Method originMethod = class_getInstanceMethod(class, originSetter);
    Method newMethod = class_getInstanceMethod(class, newSetter);
    method_exchangeImplementations(originMethod, newMethod);
}


+ (void)load
{
  [self hookAllPropertiesSetter];
}

+ (void)hookAllPropertiesSetter{
    
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    NSMutableArray *readWriteProperties = [[NSMutableArray alloc] initWithCapacity:outCount];
    for (unsigned int i =0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [[NSString alloc] initWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        unsigned int attrCount;
        objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
        // !!!!!!!!!!!!!!!!!!特别注意!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!特别注意!!!!!!!!!!!!!!!!!!
        BOOL isReadOnlyProperty = NO;
        for (unsigned int j =0; j < attrCount; j++) {
            if (attrs[j].name[0] =='R') {
                isReadOnlyProperty = YES;
                break;
            }
        }
        if (!isReadOnlyProperty && attrs[0].value[0] == '@') {
            [readWriteProperties addObject:propertyName];
        }
        free(attrs);
    }
    free(properties);
    for (NSString *propertyName in readWriteProperties) {
        NSString *setterName = [NSString stringWithFormat:@"set%@%@:", [propertyName substringToIndex:1].uppercaseString, [propertyName substringFromIndex:1]];
        // !!!!!!!!!!!!!!!!!!特别注意!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!特别注意!!!!!!!!!!!!!!!!!!
        NSString *hookSetterName = [NSString stringWithFormat:@"hook_set%@:", propertyName];
        SEL originSetter = NSSelectorFromString(setterName);
        SEL newSetter = NSSelectorFromString(hookSetterName);
        swizzleMethod([self class], originSetter, newSetter);
    }
}

+ (BOOL)resolveInstanceMethod:(SEL)sel{
    
    NSString *selName = NSStringFromSelector(sel);
    if([selName hasPrefix:@"hook_"])
    {
        Method proxyMethod = class_getInstanceMethod([self class],@selector(hook_proxy:));
        class_addMethod([self class],sel,method_getImplementation(proxyMethod), method_getTypeEncoding(proxyMethod));
        return YES;
    }
    return[super resolveInstanceMethod:sel];
    
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        NSLog(@"init[NSOperationQueue currentQueue] : %@",[NSOperationQueue currentQueue]);
        [self p_setUp];
    }
    return self;
}

- (void)p_setUp{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 1. 主队列
        if([NSOperationQueue currentQueue] == [NSOperationQueue mainQueue]) {
            initQueue = dispatch_get_main_queue();
            const char*label = dispatch_queue_get_label(initQueue);//(__bridge void *)([UIApplication mainQueueKey]);
            initQueueKey = &label;
            initQueueContext = dispatch_queue_get_specific(initQueue, initQueueKey);//(__bridge void *)([UIApplication mainQueueContext]);
        }else{// 2. 非主队列
            const char*label = [NSStringFromSelector(_cmd) UTF8String];
            initQueueKey = &initQueueKey;
            initQueueContext = &initQueueContext;
            initQueue = dispatch_queue_create(label,nil);
            dispatch_queue_set_specific(initQueue, initQueueKey, initQueueContext,nil);
        }
    });
}


- (void)hook_proxy:(NSObject *)proxyObject{
    // 只是实现被换了，但是selector还是没变
    NSString *originSelector = NSStringFromSelector(_cmd);
    NSString *propertyName = [[originSelector stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]]stringByReplacingOccurrencesOfString:@"set"withString:@""];
    if(propertyName.length <=0)return;
    NSString *ivarName = [NSString stringWithFormat:@"_%@%@", [propertyName substringToIndex:1].lowercaseString, [propertyName substringFromIndex:1]];
    //
//    NSLog(@"hook_proxy is %@ for property %@", proxyObject, propertyName);// 重复之前步骤即可。


    void * context = dispatch_get_specific(initQueueKey);
//    NSLog(@"currentContext: %@, initContext:%@",context,initQueueContext);
    if (context == initQueueContext) {
        NSLog(@"currentQueue hook_proxy is %@ for property %@", proxyObject, propertyName);

        [self setValue:proxyObject forKey:ivarName];
    }else{
        dispatch_sync(initQueue, ^{
            NSLog(@"otherQueue hook_proxy is %@ for property %@", proxyObject, propertyName);
            [self setValue:proxyObject forKey:ivarName];
        });
    }
}

@end
