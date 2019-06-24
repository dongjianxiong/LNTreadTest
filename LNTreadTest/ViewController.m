//
//  ViewController.m
//  LNTreadTest
//
//  Created by ioser on 2018/11/6.
//  Copyright © 2018年 Lenny. All rights reserved.
//

#import "ViewController.h"
#import <pthread/pthread.h>
#import <libkern/OSAtomic.h>
#import <os/lock.h>
#import <objc/runtime.h>
#import "LNSafePropertySetting.h"
static pthread_mutex_t mutex_t;
static dispatch_semaphore_t test_signal;
static NSLock *nslock;
static OSSpinLock osspinLock = OS_SPINLOCK_INIT;
API_AVAILABLE(ios(10.0))
static os_unfair_lock unfair_lock = OS_UNFAIR_LOCK_INIT;


@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray *array;

//@property (nonatomic, strong) NSMutableArray *testArray;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) BOOL isNeedNewQueue;
@property (nonatomic, assign) BOOL isLog;
@property (nonatomic, copy) NSString *str;


@end


@implementation ViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.tableView];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.count = 1000;
    self.isNeedNewQueue = YES;
    self.isLog = YES;
    self.array = [NSArray arrayWithObjects:@"信号量",@"OSSpinLock",@"os_unfair_lock", @"pthread_mutex", @"NSLock", @"@synchronized", @"同步串行", @"异步串行", @"all",nil];
    // Do any additional setup after loading the view, typically from a nib.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = self.array[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *text = self.array[indexPath.row];
    if ([text isEqualToString:@"信号量"]) {
        [self signalTest];
        
    }else if ([text isEqualToString:@"OSSpinLock"]) {
        [self osSpinLockTest];
    }else if ([text isEqualToString:@"os_unfair_lock"]){
        [self osUnfairLockTest];
    }
    else if ([text isEqualToString:@"pthread_mutex"]){
        [self pthreadTest];
    }else if ([text isEqualToString:@"NSLock"]) {
        [self nsLockTest];
    }
    else if ([text isEqualToString:@"@synchronized"]){
        [self synchronizedTest];
    }else if ([text isEqualToString:@"同步串行"]){
        [self syncSerialQueueTest];
    }
    else if ([text isEqualToString:@"异步串行"]){
        [self asyncSerialQueueTest];
    }else
    {
        [self allTest];
    }
}

- (void)allTest
{
    NSLog(@"开始统计啦！");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           [self signalTest];
    });
 
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self osSpinLockTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [self osUnfairLockTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
         [self pthreadTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nsLockTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self synchronizedTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(70 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self syncSerialQueueTest];
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(80 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self asyncSerialQueueTest];
    });
}

- (NSMutableArray *)arrWithCount:(NSInteger)count
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger index = 0; index < count ; index++) {
        [arr addObject:@(index)];
    }
    return arr;
}

- (void)removeObjectInArray:(NSMutableArray *)arr
{
    if (self.isLog) {
        NSLog(@"i is :%@",@(arr.count));
    }
    if (arr.count > 0) {
        NSNumber *number = [arr firstObject];
        [arr removeObject:number];
    }
}

//信号量
- (void)signalTest
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        test_signal = dispatch_semaphore_create(1); //传入值必须 >=0, 若传入为 0 则阻塞线程并等待timeout,时间到后会执行其后的语句
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 3.0f * NSEC_PER_SEC);
        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            [self handlerBlock:^{
                dispatch_semaphore_wait(test_signal, time);//可以理解为 lock,会使得 signal 值
                if (testArray.count > 0) {
                    [self removeObjectInArray:testArray];
                }else{
                    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                    NSLog(@"signal total_time:%@",@(end - start));
                }
                dispatch_semaphore_signal(test_signal);//可以理解为 unlock,会使得 signal 值 +1
            } needNewQueue:self.isNeedNewQueue];
        }
//    }
                   );
}


- (void)osSpinLockTest
{
    dispatch_queue_t queque = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queque, ^{

        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        LNSafePropertySetting *object = [[LNSafePropertySetting alloc] init];
        object.array = [NSArray array];
        object.isRight = YES;
        object.str = @"name";
        [self handlerBlock:^{
            object.array = [NSArray array];
            object.isRight = YES;
            object.str = @"name";

            // 加锁
            OSSpinLockLock(&osspinLock);
            if (testArray.count > 0) {
                [self removeObjectInArray:testArray];
            }else{
                CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                NSLog(@"osSpinLockTest total_time:%@",@(end - start));
            }
            
            OSSpinLockUnlock(&osspinLock);
        } needNewQueue:self.isNeedNewQueue];
    });
}

- (void)osUnfairLockTest
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            // 加锁
            if (@available(iOS 10.0, *)) {
                os_unfair_lock_lock(&unfair_lock);
            } else {
                // Fallback on earlier versions
            }
            if (testArray.count > 0) {
                [self removeObjectInArray:testArray];
            }else{
                CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                NSLog(@"osUnfairLockTest total_time:%@",@(end - start));
            }
            // 解锁
            if (@available(iOS 10.0, *)) {
                os_unfair_lock_unlock(&unfair_lock);
            } else {
                // Fallback on earlier versions
            }
        } needNewQueue:self.isNeedNewQueue];
    });
}

//pthread
- (void)pthreadTest
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //    1.普通初始化
    pthread_mutex_init(&mutex_t, NULL);
    NSMutableArray *testArray = [self arrWithCount:self.count];
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            // 加锁
            pthread_mutex_lock(&mutex_t);
            if (testArray.count > 0) {
                [self removeObjectInArray:testArray];
            }else{
                CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                NSLog(@"pthreadTest total_time:%@",@(end - start));
            }
            // 解锁
            pthread_mutex_unlock(&mutex_t);
        } needNewQueue:self.isNeedNewQueue];
    });
}

//NSLock
- (void)nsLockTest
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        nslock = [[NSLock alloc] init];
        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            [nslock lock];
            if (testArray.count > 0) {
                [self removeObjectInArray:testArray];
            }else{
                CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                NSLog(@"nsLockTest total_time:%@",@(end - start));
            }
            [nslock unlock];
        } needNewQueue:self.isNeedNewQueue];
    });
}

//@synchronized
- (void)synchronizedTest
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            @synchronized(testArray){
                if (testArray.count > 0) {
                    [self removeObjectInArray:testArray];
                }else{
                    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                    NSLog(@"synchronizedTest total_time:%@",@(end - start));
                }
            }
            
        } needNewQueue:self.isNeedNewQueue];
    });
}


//异步串行
- (void)asyncSerialQueueTest
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        dispatch_queue_t serialQueue = dispatch_queue_create("com.sohu.treadtest.serial_queue", DISPATCH_QUEUE_SERIAL);
        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            dispatch_async(serialQueue, ^{
                if (testArray.count > 0) {
                    [self removeObjectInArray:testArray];
                }else{
                    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                    NSLog(@"asyncSerialQueueTest total_time:%@",@(end - start));
                }
            });
            
        } needNewQueue:self.isNeedNewQueue];
    });
}

//同步串行
- (void)syncSerialQueueTest
{

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        const char *kSCADDispatchQueueSpecificKey = "kSCADDispatchQueueSpecificKey";
        dispatch_queue_t serialQueue = dispatch_queue_create([[NSString stringWithFormat:@"com.sohu.treadtest.%@", self] UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(serialQueue, kSCADDispatchQueueSpecificKey, (__bridge void *)self, NULL);
        NSMutableArray *testArray = [self arrWithCount:self.count];
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        [self handlerBlock:^{
            UIViewController *currentSyncQueue = (__bridge id)dispatch_get_specific(kSCADDispatchQueueSpecificKey);
            assert(currentSyncQueue != self && "HandlerBlock: was called reentrantly on the same queue, which would lead to a deadlock");
            dispatch_sync(serialQueue, ^() {
                if (testArray.count > 0) {
                    [self removeObjectInArray:testArray];
                }else{
                    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
                    NSLog(@"syncSerialQueueTest total_time:%@",@(end - start));
                }
            });
            
        } needNewQueue:self.isNeedNewQueue];
    });
}

- (void)handlerBlock:( void (^)(void))handlerBlock needNewQueue:(BOOL)isNeedNewQueue
{
    for (int index = 0; index <= self.count; index++) {
        if (isNeedNewQueue) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (handlerBlock) {
                    handlerBlock();
                };
            });
        }else{
            if (handlerBlock) {
                handlerBlock();
            };
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
