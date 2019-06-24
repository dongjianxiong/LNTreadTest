//
//  LNSafePropertySetting.h
//  LNTreadTest
//
//  Created by ioser on 2019/1/29.
//  Copyright © 2019年 Lenny. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LNSafePropertySetting : NSObject

@property (nonatomic, strong) NSArray *array;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) BOOL isRight;
@property (nonatomic, copy) NSString *str;
@property (nonatomic, strong) id object;

@end

NS_ASSUME_NONNULL_END
