title: iOS线程之NSThread
date: 2016-04-13 11:23:40
tags:
- iOS
- iOS高级
categories: iOS
---
前两篇文章已经将了现在主流的GCD和NSOperationQueue,现在我们在聊一下NSThread。
### 创建NSThread 
方法一 类方法
```
+ (void)detachNewThreadSelector:(SEL)selector toTarget:(id)target withObject:(nullable id)argument;
```
方法二 实例方法
 ```
- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument NS_AVAILABLE(10_5, 2_0);
```
这两者的区别是 类方法是创建新的线程并且立即启动，而第二个方法是创建线程，但是没有启动，启动需要` [thread start]`。
### 获取线程的状态
```
正在执行
@property (readonly, getter=isExecuting) BOOL executing NS_AVAILABLE(10_5, 2_0);
完成
@property (readonly, getter=isFinished) BOOL finished NS_AVAILABLE(10_5, 2_0);
取消
@property (readonly, getter=isCancelled) BOOL cancelled NS_AVAILABLE(10_5, 2_0);
```
### 更改线程状态
```
取消
- (void)cancel NS_AVAILABLE(10_5, 2_0);
开始
- (void)start NS_AVAILABLE(10_5, 2_0);
线程的主函数
- (void)main NS_AVAILABLE(10_5, 2_0);
```
在子线程中想要更新UI怎么办，这里官方直接提供了在子线程执行方法的函数，很实用的。
```
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait modes:(nullable NSArray<NSString *> *)array;
在主线程执行
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;

 // equivalent to the first method with kCFRunLoopCommonModes
- (void)performSelector:(SEL)aSelector 
                        onThread:(NSThread *)thr 
                      withObject:(nullable id)arg 
                waitUntilDone:(BOOL)wait 
                              modes:(nullable NSArray<NSString *> *)array NS_AVAILABLE(10_5, 2_0);
- (void)performSelector:(SEL)aSelector 
                          onThread:(NSThread *)thr
                       withObject:(nullable id)arg 
                waitUntilDone:(BOOL)wait NS_AVAILABLE(10_5, 2_0);
 // equivalent to the first method with kCFRunLoopCommonModes
- (void)performSelectorInBackground:(SEL)aSelector
                                                  withObject:(nullable id)arg NS_AVAILABLE(10_5, 2_0);
```
### 代码
```
- (void)test6{
    NSThread * thread = [[NSThread alloc]initWithTarget:self selector:@selector(op1) object:nil];
    thread.name = @"test6";
    [thread start];
    [self performSelectorInBackground:@selector(print) withObject:nil];
}
- (void)print{
    NSLog(@"线程info : %@",[NSThread currentThread]);
}
- (void)op1{
    
     NSLog(@"op1 开始运行了");
     sleep(3);

     NSLog(@"op1 结束");
}
输出：
**2016-04-13 10:34:23.515 GCD_Demo[33904:647479] op1 ****开始运行了**
**2016-04-13 10:34:23.515 GCD_Demo[33904:647480] ****线程****info : <NSThread: 0x7fcc81a1abe0>{number = 3, name = (null)}**
**2016-04-13 10:34:26.521 GCD_Demo[33904:647479] op1 ****结束**
```
从输出结果看出来`[self performSelectorInBackground:@selector(print) withObject:nil];`又自动生成了子线程并且在子线程执行`print`函数。

把test6函数改成下面的情况
```
//当waitUntilDone 是yes的时候，是同步执行
 [self performSelectorOnMainThread:@selector(print) withObject:nil waitUntilDone:NO];
    _thread = [[NSThread alloc]initWithTarget:self selector:@selector(op1) object:nil];
    _thread.name = @"test6";
    [_thread start];
    [self performSelectorInBackground:@selector(print) withObject:nil];
```
输出：
```
**2016-04-13 10:41:32.534 GCD_Demo[34026:652753] test6 ****开始运行了**
**2016-04-13 10:41:32.534 GCD_Demo[34026:652754] ****线程****info : <NSThread: 0x7fb7320a1bf0>{number = 3, name = (null)}**
**2016-04-13 10:41:32.537 GCD_Demo[34026:652708] ****线程****info : <NSThread: 0x7fb730c05a20>{number = 1, name = main}**
**2016-04-13 10:41:35.539 GCD_Demo[34026:652753] test6 ****结束**
```
`[self performSelectorOnMainThread:@selector(print) 
                                                withObject:nil
                                         waitUntilDone:NO];`
waitUntilDone为YES的时候是同步执行代码，为NO的时候异步执行代码。
`[self performSelectorInBackground:@selector(print) withObject:nil];`开启子线程执行print函数。
### cancel thread
```
- (void)test6{
    _thread = [[NSThread alloc]initWithTarget:self selector:@selector(op1) object:nil];
    _thread.name = @"test6";
    [_thread start];
    sleep(2);
    [_thread cancel];
    if (_thread.cancelled) {
        NSLog(@"%@ canceld",_thread.name);
    } else if(_thread.executing){
        NSLog(@"%@ execuitng",_thread.name);
    }
}
```
输出：
```
**2016-04-13 10:50:46.685 GCD_Demo[34128:657263] test6 ****开始运行了**
**2016-04-13 10:50:48.686 GCD_Demo[34128:657214] test6 canceld**
**2016-04-13 10:50:48.692 GCD_Demo[34128:657214] ****线程****info : <NSThread: 0x7ffb34004fb0>{number = 1, name = main}**
**2016-04-13 10:51:16.689 GCD_Demo[34128:657263] test6 ****结束**
```
其实thread取消也是在执行中的线程是没办法直接取消的，`[thread cancel]`紧紧是改了状态，却没有终止线程。和`[NSOperation cancel]`类似，当你cancel之后，如果线程在执行，那么他会执行完毕，如果线程还没执行，那么他会终止执行。

关于thread的通知
```
//将要变成多线程 在有新的线程启动的时候会发送此通知
FOUNDATION_EXPORT NSString * const NSWillBecomeMultiThreadedNotification;
//将要变成单独线程  官方标注: Not implemented.【没有实现】
FOUNDATION_EXPORT NSString * const NSDidBecomeSingleThreadedNotification;
//线程退出
FOUNDATION_EXPORT NSString * const NSThreadWillExitNotification;

通过这三个通知可以监测线程的启动和现成的退出。
//监测线程启动，启动的线程是未知的所以object是nil
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(becomeMultiNsthread) name:NSWillBecomeMultiThreadedNotification object:nil];

//监测线程退出
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exit:) name:NSThreadWillExitNotification object:nil];
```
线程的讨论暂时就这么多，有问题我们一起讨论，欢迎留言。。