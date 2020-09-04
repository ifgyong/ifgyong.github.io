---
title: iOS底层原理  RunLoop基础总结和随心所欲掌握子线程RunLoop生命周期 --(9)
tags:
  - iOS
categories: iOS
abbrlink: 53c2ebb0
date: 2019-12-01 11:19:58
---

使用钩子实现了对字典和数组的赋值的校验，顺便随手撸了一个简单的`jsonToModel`,`iOS`除了`runtime`还有一个东西的叫做`runloop`，各位看官老爷一定都有了解，那么今天这篇文章初识一下`runloop`。

### 什么是runloop
简单来讲`runloop`就是一个循环，我们写的程序，一般没有循环的话，执行完就结束了，那么我们手机上的APP是如何一直运行不停止的呢？APP就是用到了`runloop`，保证程序一直运行不退出，在需要处理事件的时候处理事件，不处理事件的时候进行休眠，跳出循环程序就结束。用伪代码实现一个`runloop`其实是这样子的

```
int ret = 0;
do {
    //睡眠中等待消息
    int messgae = sleep_and_wait();
    //处理消息
    ret = process_message(messgae);
} while (ret == 0);
```


### 获取runloop

iOS中有两套可以获取runloop代码，一个是`Foundation`、一个是`Core Foundation`。
`Foundation`其实是对`Core Foundation`的一个封装，

```
NSRunLoop * runloop1 = [NSRunLoop currentRunLoop];
NSRunLoop *mainloop1 = [NSRunLoop mainRunLoop];

CFRunLoopRef runloop2= CFRunLoopGetCurrent();
CFRunLoopRef mainloop2 = CFRunLoopGetMain();
NSLog(@"%p %p %p %p",runloop1,mainloop1,runloop2,mainloop2);
NSLog(@"%@",runloop1);
//打印
runlopp1:0x600001bc58c0 
mainloop1:0x600001bc58c0 
runloop2:0x6000003cc300 
mainloop1:0x6000003cc300

runloop1:<CFRunLoop 0x6000003cc300 [0x10b2e9ae8]>.....

```
`runloop1`和`mainloop1`地址一致，说明当前的`runloop`是`mainrunloop`,`runloop1`作为对象输出的结果其实也是`runloop2`的地址，证明`Foundation runloop`是对`Core Foundation`的一个封装。

`RunLoop`底层我们猜测应该是结构体，我们都了解到其实`OC`就是封装了`c/c++`，那么c厉害之处就是指针和结构体基本解决常用的所有东西。我们窥探一下`runloop`的真是模样，通过`CFRunLoopRef *runloop = CFRunLoopGetMain();`查看`CFRunloop`是`typedef struct CF_BRIDGED_MUTABLE_TYPE(id) __CFRunLoop * CFRunLoopRef;`，我们常用的`CFRunLoopRef`是`__CFRunLoop *`类型的，那么再在[源码(可以下载最新的源码)](https://opensource.apple.com/tarballs/CF/)中搜索一下 `struct __CFRunLoop {`在`runloop.c 637行`如下所示：

```
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;			/* model list 锁 */
    __CFPort _wakeUpPort;			// 接受 CFRunLoopWakeUp的端口
    Boolean _unused;//是否使用
    volatile _per_run_data *_perRunData;              // reset for runs of the run loop
    pthread_t _pthread; //线程
    uint32_t _winthread;//win线程
    CFMutableSetRef _commonModes; //modes
    CFMutableSetRef _commonModeItems; //modeItems
    CFRunLoopModeRef _currentMode; //当前的mode
    CFMutableSetRef _modes; //所有的modes
    struct _block_item *_blocks_head; //待执行的block列表头部
    struct _block_item *_blocks_tail; //待执行的block 尾部
    CFAbsoluteTime _runTime; //runtime
    CFAbsoluteTime _sleepTime; //sleeptime
    CFTypeRef _counterpart; //
};
```

经过简化之后：

```
struct __CFRunLoop {
    pthread_t _pthread; //线程
    CFMutableSetRef _commonModes; //modes
    CFMutableSetRef _commonModeItems; //modeItems
    CFRunLoopModeRef _currentMode; //当前的mode
    CFMutableSetRef _modes; //所有的modes
}
```

1. `runloop`中包含一个线程`_pthread`，一一对应的
2. `CFMutableSetRef _modes`可以有多个`mode`
3. `CFRunLoopModeRef _currentMode`当前`mode`只能有一个

那么mode里边有什么内容呢？我们猜测他应该和`runloop`类似，在源码中搜索`CFRuntimeBase _base`看到在`runloop.c  line 524`看到具体的内容：

```
struct __CFRunLoopMode {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;	/* must have the run loop locked before locking this */
    CFStringRef _name;
    Boolean _stopped;
    char _padding[3];
    CFMutableSetRef _sources0;
    CFMutableSetRef _sources1;
    CFMutableArrayRef _observers;
    CFMutableArrayRef _timers;
    CFMutableDictionaryRef _portToV1SourceMap;
    __CFPortSet _portSet;
    CFIndex _observerMask;
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;
    dispatch_queue_t _queue;
    Boolean _timerFired; // set to true by the source when a timer has fired
    Boolean _dispatchTimerArmed;
#endif
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;
    Boolean _mkTimerArmed;
#endif
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;
    void (*_msgPump)(void);
#endif
    uint64_t _timerSoftDeadline; /* TSR */
    uint64_t _timerHardDeadline; /* TSR */
};
```

经过简化之后是：

```
struct __CFRunLoopMode {
    CFStringRef _name;//当前mode的名字
    CFMutableSetRef _sources0;//souces0
    CFMutableSetRef _sources1;//sources1
    CFMutableArrayRef _observers;//observers
    CFMutableArrayRef _timers;//timers
}
```

一个`mode`可以有多个`timer`、`souces0`、`souces1`、`observers`、`timers`
那么使用图更直观的来表示：

![](/images/9-1.png)

一个`runloop`包含多个`mode`，但是同时只能运行一个`mode`，这点和大家开车的驾驶模式类似，运动模式和环保模式同时只能开一个模式，不能又运动又环保，明显相悖。多个`mode`被隔离开有点是处理事情更专一，不会因为多个同时处理事情造成卡顿或者资源竞争导致的一系列问题。
#### souces0
- 触摸事件
- performSelector:onThread:

测试下点击事件处理源

```
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	NSLog(@"%s",__func__);//此处断点
}

(LLDB) bt //输出当前调用栈
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
  * frame #0: 0x000000010c5bb66d CFRunloop`::-[ViewController touchesBegan:withEvent:](self=0x00007fc69ec087e0, _cmd="touchesBegan:withEvent:", touches=1 element, event=0x00006000012a01b0) at ViewController.mm:22:2
    frame #1: 0x0000000110685a09 UIKitCore`forwardTouchMethod + 353
    frame #2: 0x0000000110685897 UIKitCore`-[UIResponder touchesBegan:withEvent:] + 49
    frame #3: 0x0000000110694c48 UIKitCore`-[UIWindow _sendTouchesForEvent:] + 1869
    frame #4: 0x00000001106965d2 UIKitCore`-[UIWindow sendEvent:] + 4079
    frame #5: 0x0000000110674d16 UIKitCore`-[UIApplication sendEvent:] + 356
    frame #6: 0x0000000110745293 UIKitCore`__dispatchPreprocessedEventFromEventQueue + 3232
    frame #7: 0x0000000110747bb9 UIKitCore`__handleEventQueueInternal + 5911
    frame #8: 0x000000010d8eabe1 CoreFoundation`__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__ + 17
    frame #9: 0x000000010d8ea463 CoreFoundation`__CFRunLoopDoSources0 + 243
    frame #10: 0x000000010d8e4b1f CoreFoundation`__CFRunLoopRun + 1231
    frame #11: 0x000000010d8e4302 CoreFoundation`CFRunLoopRunSpecific + 626
    frame #12: 0x0000000115ddc2fe GraphicsServices`GSEventRunModal + 65
    frame #13: 0x000000011065aba2 UIKitCore`UIApplicationMain + 140
    frame #14: 0x000000010c5bb760 CFRunloop`main(argc=1, argv=0x00007ffee3643f68) at main.m:14:13
    frame #15: 0x000000010f1cb541 libdyld.dylib`start + 1
    frame #16: 0x000000010f1cb541 libdyld.dylib`start + 1
```

`#1`看到现在是在队列queue = 'com.apple.main-thread'中，`#10` `Runloop`启动，`#9`进入到`__CFRunLoopDoSources0`,最终`__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__`调用了`__handleEventQueueInternal`->`[UIApplication sendEvent:]`->`[UIWindow sendEvent:]`->`[UIWindow _sendTouchesForEvent:]`->`[UIResponder touchesBegan:withEvent:]`->`-[ViewController touchesBegan:withEvent:](self=0x00007fc69ec087e0, _cmd="touchesBegan:withEvent:", touches=1 element, event=0x00006000012a01b0) at ViewController.mm:22:2`，可以看到另外一个知识点，手势的传递是从上往下的，顺序是`UIApplication -> UIWindow -> UIResponder -> ViewController`。
#### Source1
- 基于Port的线程间通信
- 系统事件捕捉


#### Timers
- NSTimer
- performSelector:withObject:afterDelay:

```
	timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
	static int count = 5;
	dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
	dispatch_source_set_event_handler(timer, ^{
		NSLog(@"-------：%d \n",count++);
	});
	dispatch_resume(timer);
	//log
	(lldb) bt
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
  * frame #0: 0x0000000101f26457 CFRunloop`::__29-[ViewController viewDidLoad]_block_invoke(.block_descriptor=0x0000000101f28100) at ViewController.mm:72:33
    frame #1: 0x0000000104ac2db5 libdispatch.dylib`_dispatch_client_callout + 8
    frame #2: 0x0000000104ac5c95 libdispatch.dylib`_dispatch_continuation_pop + 552
    frame #3: 0x0000000104ad7e93 libdispatch.dylib`_dispatch_source_invoke + 2249
    frame #4: 0x0000000104acfead libdispatch.dylib`_dispatch_main_queue_callback_4CF + 1073
    frame #5: 0x00000001032568a9 CoreFoundation`__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__ + 9
    frame #6: 0x0000000103250f56 CoreFoundation`__CFRunLoopRun + 2310
    frame #7: 0x0000000103250302 CoreFoundation`CFRunLoopRunSpecific + 626
	
```

最终进入函数`__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__`调用了[libdispatch](https://opensource.apple.com/tarballs/libdispatch/)的`_dispatch_main_queue_callback_4CF`函数，具体实现有兴趣的大佬可以看下源码的实现。

#### Observers
- 用于监听RunLoop的状态
- UI刷新（BeforeWaiting）
- Autorelease pool（BeforeWaiting）




`Mode`类型都多个,系统暴露在外的就两个，

```
CF_EXPORT const CFRunLoopMode kCFRunLoopDefaultMode;
CF_EXPORT const CFRunLoopMode kCFRunLoopCommonModes;
```

那么这两个Mode都是在什么情况下运行的呢？
1. `kCFRunLoopDefaultMode（NSDefaultRunLoopMode）`：`App`的默认`Mode`，通常主线程是在这个`Mode`下运行
2. `UITrackingRunLoopMode`：界面跟踪` Mode`，用于`ScrollView` 追踪触摸滑动，保证界面滑动时不受其他`Mode`影响

进入到某个`Mode`，处理事情也应该有先后顺序和休息的时间，那么现在需要一个状态来表示此时此刻的`status`，系统已经准备了`CFRunLoopActivity`来表示当前的状态

```
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry = (1UL << 0), //即将进入loop
    kCFRunLoopBeforeTimers = (1UL << 1),//即将处理timers
    kCFRunLoopBeforeSources = (1UL << 2), //即将处理sourcs
    kCFRunLoopBeforeWaiting = (1UL << 5),//即将进入休眠
    kCFRunLoopAfterWaiting = (1UL << 6),//即将从休眠中唤醒
    kCFRunLoopExit = (1UL << 7),//即将退出
    kCFRunLoopAllActivities = 0x0FFFFFFFU//所有状态
};
```

`1UL`表示无符号长整形数字`1`，再次看到这个`(1UL << 1)`我么猜测用到了[位域或者联合体](https://juejin.im/post/5d2bcf3df265da1b67213d69)，达到省空间的目的。`kCFRunLoopAllActivities = 0x0FFFFFFFU`转换成二进制就是28个`1`，再进行`mask`的时候，所有的值都能取出来。


现在我们了解到：
1. `CFRunloopRef`代表`RunLoop`的运行模式
2. 一个`Runloop`包含若干个`Mode`,每个`Mode`包含若干个`Source0/Source1/Timer/Obser`
3. `Runloop`启动只能选择一个`Mode`作为`currentMode`
4. 如果需要切换`Mode`，只能退出当前`Loop`，再重新选择一个`Mode`进入
5. 不同组的`Source0/Source1/Timer/Observer`能分隔开来，互不影响
6. 如果`Mode`没有任何`Source0/Source1/Timer/Observer`，`Runloop`立马退出。

##### runloop切换Mode

```
CFRunLoopObserverRef obs= CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
    switch (activity) {
    	case kCFRunLoopEntry:{
    		CFRunLoopMode m = CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent());
    		NSLog(@"即将进入 mode:%@",m);
    		CFRelease(m);
    		break;
    	}
    		
    	case kCFRunLoopExit:
    	{
    		CFRunLoopMode m = CFRunLoopCopyCurrentMode(CFRunLoopGetCurrent());
    		NSLog(@"即将退出 mode:%@",m);
    		CFRelease(m);
    		break;
    	}
    	default:
    		break;
    }
	});
	CFRunLoopAddObserver(CFRunLoopGetMain(), obs, kCFRunLoopCommonModes);
	CFRelease(obs);
	
	//当滑动tb的时候log
	
即将退出 mode:kCFRunLoopDefaultMode
即将进入 mode:UITrackingRunLoopMode
即将退出 mode:UITrackingRunLoopMode
即将进入 mode:kCFRunLoopDefaultMode
```

当`runloop`切换`mode`的时候，会退出当前`kCFRunLoopDefaultMode`，加入到其他的`UITrackingRunLoopMode`，当前`UITrackingRunLoopMode`完成之后再退出之后再加入到`kCFRunLoopDefaultMode`。

我们再探究下`runloop`的循环的状态到底是怎样来变更的。

```
//	//获取loop
	CFRunLoopRef ref = CFRunLoopGetMain();
	//获取obs
	CFRunLoopObserverRef obs = CFRunLoopObserverCreate(kCFAllocatorDefault,kCFRunLoopAllActivities, YES, 0, callback, NULL);
	//添加监听
	CFRunLoopAddObserver(ref, obs, CFRunLoopCopyCurrentMode(ref));
	CFRelease(obs);
	
	
int count = 0;//定义全局变量来计算一个mode中状态切换的统计数据
void callback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
	printf("- ");
	count ++;
	printf("%d",count);
	switch (activity) {
		case kCFRunLoopEntry:
			printf("即将进入 \n");
			count = 0;
			break;
		case kCFRunLoopExit:
			printf("即将退出 \n");
			break;
		case kCFRunLoopAfterWaiting:
			printf("即将从休眠中唤醒 \n");
			break;
		case kCFRunLoopBeforeTimers:
			printf("即将进入处理 timers \n");
			break;
		case kCFRunLoopBeforeSources:
			printf("即将进入 sources \n");
			break;
		case kCFRunLoopBeforeWaiting:
			printf("即将进入 休眠 \n");
			count = 0;
			break;
		default:
			break;
	}
}

//点击的时候 会出发loop来处理触摸事件
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	NSLog(@"%s",__func__);
}

//log

- 1即将从休眠中唤醒 
- 2即将进入处理 timers 
- 3即将进入 sources 
-[ViewController touchesBegan:withEvent:]
- 4即将进入处理 timers 
- 5即将进入 sources 
- 6即将进入处理 timers 
- 7即将进入 sources 
- 8即将进入处理 timers 
- 9即将进入 sources 
- 10即将进入 休眠 
- 1即将从休眠中唤醒 
- 2即将进入处理 timers 
- 3即将进入 sources 
- 4即将进入处理 timers 
- 5即将进入 sources 
- 6即将进入 休眠 
- 1即将从休眠中唤醒 
- 2即将进入处理 timers 
- 3即将进入 sources 
- 4即将进入 休眠 
```

`runloop`唤醒之后不是立马处理事件的，而是看看`timer`有没有事情，然后是`sources`,发现有触摸事件就处理了，然后又循环查看`timer`和`sources`一般循环2次进入休眠状态，处理`source`之后是循环三次。
##### RunLoop在不获取的时候不存在,获取才生成
`RunLoop`是在主动获取的时候才会生成一个，主线程是系统自己调用生成的，子线程开发者调用，我们看下`CFRunLoopGetCurrent`

```
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CHECK_FOR_FORK();
    CFRunLoopRef rl = (CFRunLoopRef)_CFGetTSD(__CFTSDKeyRunLoop);
    if (rl) return rl;
    return _CFRunLoopGet0(pthread_self());
}
```

看到到这里相信大家已经对`runloop`有了基本的认识，那么我们再探究一下底层`runloop`是怎么运转的。

首先看官方给的图：

![](/images/9-2.png)
那我又整理了一个表格来更直观的了解状态运转

|步骤|任务|
|:-:|:-:|
|1|通知Observers:进入Loop|
|2|通知Observers:即将处理Timers|
|3|通知Observers:即将处理Sources|
|4|处理blocks|
|5|处理Source0(可能再处理Blocks)|
|6|如果存在Source1，跳转第8步|
|7|通知Observers:开始休眠|
|8|通知Observers:结束休眠1.处理Timer2.处理GCD Asyn To Main Queue 3.处理Source1|
|9|处理Blocks|
|10|根据前面的执行结果，决定如何操作1.返回第2步，2退出loop|
|11|通知Observers:退出Loop|

查看[runloop源码](https://opensource.apple.com/tarballs/CF/)中`runloop.c`2333行

```
//入口函数
static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, CFTimeInterval seconds, Boolean stopAfterHandle, CFRunLoopModeRef previousMode) {
    uint64_t startTSR = mach_absolute_time();

    if (__CFRunLoopIsStopped(rl)) {
        __CFRunLoopUnsetStopped(rl);
	return kCFRunLoopRunStopped;
    } else if (rlm->_stopped) {
	rlm->_stopped = false;
	return kCFRunLoopRunStopped;
    }
    
    mach_port_name_t dispatchPort = MACH_PORT_NULL;
    Boolean libdispatchQSafe = pthread_main_np() && ((HANDLE_DISPATCH_ON_BASE_INVOCATION_ONLY && NULL == previousMode) || (!HANDLE_DISPATCH_ON_BASE_INVOCATION_ONLY && 0 == _CFGetTSD(__CFTSDKeyIsInGCDMainQ)));
    if (libdispatchQSafe && (CFRunLoopGetMain() == rl) && CFSetContainsValue(rl->_commonModes, rlm->_name)) dispatchPort = _dispatch_get_main_queue_port_4CF();
    
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    mach_port_name_t modeQueuePort = MACH_PORT_NULL;
    if (rlm->_queue) {
        modeQueuePort = _dispatch_runloop_root_queue_get_port_4CF(rlm->_queue);
        if (!modeQueuePort) {
            CRASH("Unable to get port for run loop mode queue (%d)", -1);
        }
    }
#endif
    
    dispatch_source_t timeout_timer = NULL;
    struct __timeout_context *timeout_context = (struct __timeout_context *)malloc(sizeof(*timeout_context));
    if (seconds <= 0.0) { // instant timeout
        seconds = 0.0;
        timeout_context->termTSR = 0ULL;
    } else if (seconds <= TIMER_INTERVAL_LIMIT) {
	dispatch_queue_t queue = pthread_main_np() ? __CFDispatchQueueGetGenericMatchingMain() : __CFDispatchQueueGetGenericBackground();
	timeout_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_retain(timeout_timer);
	timeout_context->ds = timeout_timer;
	timeout_context->rl = (CFRunLoopRef)CFRetain(rl);
	timeout_context->termTSR = startTSR + __CFTimeIntervalToTSR(seconds);
	dispatch_set_context(timeout_timer, timeout_context); // source gets ownership of context
	dispatch_source_set_event_handler_f(timeout_timer, __CFRunLoopTimeout);
        dispatch_source_set_cancel_handler_f(timeout_timer, __CFRunLoopTimeoutCancel);
        uint64_t ns_at = (uint64_t)((__CFTSRToTimeInterval(startTSR) + seconds) * 1000000000ULL);
        dispatch_source_set_timer(timeout_timer, dispatch_time(1, ns_at), DISPATCH_TIME_FOREVER, 1000ULL);
        dispatch_resume(timeout_timer);
    } else { // infinite timeout
        seconds = 9999999999.0;
        timeout_context->termTSR = UINT64_MAX;
    }
    Boolean didDispatchPortLastTime = true;
    int32_t retVal = 0;
    do {
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
        voucher_mach_msg_state_t voucherState = VOUCHER_MACH_MSG_STATE_UNCHANGED;
        voucher_t voucherCopy = NULL;
#endif
        uint8_t msg_buffer[3 * 1024];
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
        mach_msg_header_t *msg = NULL;
        mach_port_t livePort = MACH_PORT_NULL;
#endif
	__CFPortSet waitSet = rlm->_portSet;

        __CFRunLoopUnsetIgnoreWakeUps(rl);
//通知即将处理Timers
        if (rlm->_observerMask & kCFRunLoopBeforeTimers)
			__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
//通知即将处理Sources
        if (rlm->_observerMask & kCFRunLoopBeforeSources)
			__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);
//处理Blocks
	__CFRunLoopDoBlocks(rl, rlm);
//处理Source0
        Boolean sourceHandledThisLoop = __CFRunLoopDoSources0(rl, rlm, stopAfterHandle);
        if (sourceHandledThisLoop) {
	//处理Block
            __CFRunLoopDoBlocks(rl, rlm);
	}
        Boolean poll = sourceHandledThisLoop || (0ULL == timeout_context->termTSR);

        if (MACH_PORT_NULL != dispatchPort && !didDispatchPortLastTime) {
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
            msg = (mach_msg_header_t *)msg_buffer;
	//y判断是否有Source1
            if (__CFRunLoopServiceMachPort(dispatchPort, &msg, sizeof(msg_buffer), &livePort, 0, &voucherState, NULL)) {
	//有则去 handle_msg
                goto handle_msg;
            }
#endif
        }
        didDispatchPortLastTime = false;
//即将进入休眠
	if (!poll && (rlm->_observerMask & kCFRunLoopBeforeWaiting)) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);
	//开始休眠
	__CFRunLoopSetSleeping(rl);

    __CFPortSetInsert(dispatchPort, waitSet);
        
	__CFRunLoopModeUnlock(rlm);
	__CFRunLoopUnlock(rl);

        CFAbsoluteTime sleepStart = poll ? 0.0 : CFAbsoluteTimeGetCurrent();

#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
#if USE_DISPATCH_SOURCE_FOR_TIMERS
        do {
            if (kCFUseCollectableAllocator) {

                memset(msg_buffer, 0, sizeof(msg_buffer));
            }
            msg = (mach_msg_header_t *)msg_buffer;
            //等待消息来唤醒当前线程
            __CFRunLoopServiceMachPort(waitSet, &msg, sizeof(msg_buffer), &livePort, poll ? 0 : TIMEOUT_INFINITY, &voucherState, &voucherCopy);
			
            if (modeQueuePort != MACH_PORT_NULL && livePort == modeQueuePort) {
          (_dispatch_runloop_root_queue_perform_4CF(rlm->_queue));
                if (rlm->_timerFired) {

                    rlm->_timerFired = false;
                    break;
                } else {
                    if (msg && msg != (mach_msg_header_t *)msg_buffer) free(msg);
                }
            } else {
                // Go ahead and leave the inner loop.
                break;
            }
        } while (1);
#else
        if (kCFUseCollectableAllocator) {
            memset(msg_buffer, 0, sizeof(msg_buffer));
        }
        msg = (mach_msg_header_t *)msg_buffer;
        __CFRunLoopServiceMachPort(waitSet, &msg, sizeof(msg_buffer), &livePort, poll ? 0 : TIMEOUT_INFINITY, &voucherState, &voucherCopy);
#endif
        
        __CFRunLoopLock(rl);
        __CFRunLoopModeLock(rlm);

        rl->_sleepTime += (poll ? 0.0 : (CFAbsoluteTimeGetCurrent() - sleepStart));

        __CFPortSetRemove(dispatchPort, waitSet);
        
        __CFRunLoopSetIgnoreWakeUps(rl);

        // user callouts now OK again
	__CFRunLoopUnsetSleeping(rl);
	if (!poll && (rlm->_observerMask & kCFRunLoopAfterWaiting))
	//结束休眠
		__CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);
//标签 handle_msg
        handle_msg:;
        __CFRunLoopSetIgnoreWakeUps(rl);
		
        if (MACH_PORT_NULL == livePort) {
            CFRUNLOOP_WAKEUP_FOR_NOTHING();
            // handle nothing
        } else if (livePort == rl->_wakeUpPort) {
            CFRUNLOOP_WAKEUP_FOR_WAKEUP();
			
        }
#if USE_DISPATCH_SOURCE_FOR_TIMERS
        else if (modeQueuePort != MACH_PORT_NULL && livePort == modeQueuePort) {
	//被timer唤醒
			CFRUNLOOP_WAKEUP_FOR_TIMER();
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }
        }
#endif
#if USE_MK_TIMER_TOO
        else if (rlm->_timerPort != MACH_PORT_NULL && livePort == rlm->_timerPort) {
            CFRUNLOOP_WAKEUP_FOR_TIMER();
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }
        }
#endif
	//被GCD换醒
        else if (livePort == dispatchPort) {
            CFRUNLOOP_WAKEUP_FOR_DISPATCH();
            __CFRunLoopModeUnlock(rlm);
            __CFRunLoopUnlock(rl);
            _CFSetTSD(__CFTSDKeyIsInGCDMainQ, (void *)6, NULL);
	//处理GCD
            __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
            _CFSetTSD(__CFTSDKeyIsInGCDMainQ, (void *)0, NULL);
            __CFRunLoopLock(rl);
            __CFRunLoopModeLock(rlm);
            sourceHandledThisLoop = true;
            didDispatchPortLastTime = true;
        } else {
	//处理Source1
            CFRUNLOOP_WAKEUP_FOR_SOURCE();
			
            voucher_t previousVoucher = _CFSetTSD(__CFTSDKeyMachMessageHasVoucher, (void *)voucherCopy, os_release);

            CFRunLoopSourceRef rls = __CFRunLoopModeFindSourceForMachPort(rl, rlm, livePort);
            if (rls) {
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
		mach_msg_header_t *reply = NULL;
		sourceHandledThisLoop = __CFRunLoopDoSource1(rl, rlm, rls, msg, msg->msgh_size, &reply) || sourceHandledThisLoop;
		if (NULL != reply) {
		    (void)mach_msg(reply, MACH_SEND_MSG, reply->msgh_size, 0, MACH_PORT_NULL, 0, MACH_PORT_NULL);
		    CFAllocatorDeallocate(kCFAllocatorSystemDefault, reply);
		}
#endif
	    }
            
            _CFSetTSD(__CFTSDKeyMachMessageHasVoucher, previousVoucher, os_release);
        }
        //处理bBlock
	__CFRunLoopDoBlocks(rl, rlm);
        
//设置返回值
	if (sourceHandledThisLoop && stopAfterHandle) {
	    retVal = kCFRunLoopRunHandledSource;
        } else if (timeout_context->termTSR < mach_absolute_time()) {
            retVal = kCFRunLoopRunTimedOut;
	} else if (__CFRunLoopIsStopped(rl)) {
            __CFRunLoopUnsetStopped(rl);
	    retVal = kCFRunLoopRunStopped;
	} else if (rlm->_stopped) {
	    rlm->_stopped = false;
	    retVal = kCFRunLoopRunStopped;
	} else if (__CFRunLoopModeIsEmpty(rl, rlm, previousMode)) {
	    retVal = kCFRunLoopRunFinished;
	}
#if DEPLOYMENT_TARGET_MACOSX || DEPLOYMENT_TARGET_EMBEDDED || DEPLOYMENT_TARGET_EMBEDDED_MINI
        voucher_mach_msg_revert(voucherState);
        os_release(voucherCopy);
#endif
    } while (0 == retVal);
    if (timeout_timer) {
        dispatch_source_cancel(timeout_timer);
        dispatch_release(timeout_timer);
    } else {
        free(timeout_context);
    }
    return retVal;
}
```

经过及进一步精简

```
//入口函数
static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, CFTimeInterval seconds, Boolean stopAfterHandle, CFRunLoopModeRef previousMode) {
    uint64_t startTSR = mach_absolute_time();

    if (__CFRunLoopIsStopped(rl)) {
        __CFRunLoopUnsetStopped(rl);
	return kCFRunLoopRunStopped;
    } else if (rlm->_stopped) {
	rlm->_stopped = false;
	return kCFRunLoopRunStopped;
    }

    Boolean didDispatchPortLastTime = true;
    int32_t retVal = 0;
    do {
        __CFRunLoopUnsetIgnoreWakeUps(rl);
//通知即将处理Timers
        if (rlm->_observerMask & kCFRunLoopBeforeTimers)
			__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
//通知即将处理Sources
        if (rlm->_observerMask & kCFRunLoopBeforeSources)
			__CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);
//处理Blocks
	__CFRunLoopDoBlocks(rl, rlm);
//处理Source0
        Boolean sourceHandledThisLoop = __CFRunLoopDoSources0(rl, rlm, stopAfterHandle);
        if (sourceHandledThisLoop) {
	//处理Block
            __CFRunLoopDoBlocks(rl, rlm);
	}
            msg = (mach_msg_header_t *)msg_buffer;
	//y判断是否有Source1
            if (__CFRunLoopServiceMachPort(dispatchPort, &msg, sizeof(msg_buffer), &livePort, 0, &voucherState, NULL)) {
	//有则去 handle_msg
                goto handle_msg;
            }

//即将进入休眠
	if (!poll && (rlm->_observerMask & kCFRunLoopBeforeWaiting)) __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);
	//开始休眠
	__CFRunLoopSetSleeping(rl);
        do {
    //等待消息来唤醒当前线程
            __CFRunLoopServiceMachPort(waitSet, &msg, sizeof(msg_buffer), &livePort, poll ? 0 : TIMEOUT_INFINITY, &voucherState, &voucherCopy);
        } while (1);
#else
	if (!poll && (rlm->_observerMask & kCFRunLoopAfterWaiting))
	//结束休眠
		__CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);
//标签 handle_msg
        handle_msg:;
	//被timer唤醒
			CFRUNLOOP_WAKEUP_FOR_TIMER();
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }

#if USE_MK_TIMER_TOO
        else if (rlm->_timerPort != MACH_PORT_NULL && livePort == rlm->_timerPort) {
            CFRUNLOOP_WAKEUP_FOR_TIMER();
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }
        }
#endif
	//被GCD换醒
        else if (livePort == dispatchPort) {
	//处理GCD
            __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
        } else {
            CFRunLoopSourceRef rls = __CFRunLoopModeFindSourceForMachPort(rl, rlm, livePort);
	//处理Source1
		sourceHandledThisLoop = __CFRunLoopDoSource1(rl, rlm, rls, msg, msg->msgh_size, &reply) || sourceHandledThisLoop;
            // Restore the previous voucher
            _CFSetTSD(__CFTSDKeyMachMessageHasVoucher, previousVoucher, os_release);
        }
        //处理bBlock
	__CFRunLoopDoBlocks(rl, rlm);
        
    //设置返回值
	if (sourceHandledThisLoop && stopAfterHandle) {
	    retVal = kCFRunLoopRunHandledSource;
        } else if (timeout_context->termTSR < mach_absolute_time()) {
            retVal = kCFRunLoopRunTimedOut;
	} else if (__CFRunLoopIsStopped(rl)) {
            __CFRunLoopUnsetStopped(rl);
	    retVal = kCFRunLoopRunStopped;
	} else if (rlm->_stopped) {
	    rlm->_stopped = false;
	    retVal = kCFRunLoopRunStopped;
	} else if (__CFRunLoopModeIsEmpty(rl, rlm, previousMode)) {
	    retVal = kCFRunLoopRunFinished;
	}
    } while (0 == retVal);
    return retVal;
}
```

精简到这里基本都能看懂了，还写了很多注释，基本和上面整理的表格一致。
这里的线程休眠`__CFRunLoopServiceMachPort`是调用内核函数[mach_msg()](http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/mach_msg.html)进行休眠，和我们平时`while(1)`大不同，`while(1)`叫死循环，其实系统每时每刻都在判断是否符合条件，耗费很高的CPU，内核则不同，Mach内核提供面向消息，基于基础的进程间通信。


#### 保活机制
一个程序运行完毕结束了就死掉了，`timer`和变量也一样，运行完毕就结束了，那么我们怎么可以保证`timer`一直活跃和线程不结束呢？
##### timer保活和多mode运行
`timer`可以添加到`self`的属性保证一直活着，只要`self`不死，`timer`就不死。`timer`默认是添加到`NSDefaultRunLoopMode`模式中，因为`RunLoop`同时运行只能有一个模式，那么在滑动`scroller`的时候怎`Timer`会卡顿停止直到再次切换回来，那么如何保证同时两个模式都可以运行呢？
`Foundation`提供了一个API`(void)addTimer:(NSTimer *)timer forMode:(NSRunLoopMode)mode`添加上，`mode`值为`NSRunLoopCommonModes`可以保证同时兼顾2种模式。




测试代码：

```
static int i = 0;
NSTimer *timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
	NSLog(@"%d",++i);
}];
//NSRunLoopCommonModes 并不是一个真正的模式，它这还是一个标记
//timer在设置为common模式下能运行
//NSRunLoopCommonModes 能在 _commentModes中数组中的模式都可以运行
//[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];//默认的模式
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

//log
	
2019-07-23 15:14:31 CFRunloop[62358:34093079] 1
2019-07-23 15:14:32 CFRunloop[62358:34093079] 2
2019-07-23 15:14:33 CFRunloop[62358:34093079] 3
2019-07-23 15:14:34 CFRunloop[62358:34093079] 4
2019-07-23 15:14:35 CFRunloop[62358:34093079] 5
2019-07-23 15:14:36 CFRunloop[62358:34093079] 6
2019-07-23 15:14:37 CFRunloop[62358:34093079] 7
2019-07-23 15:14:38 CFRunloop[62358:34093079] 8
```

当滑动的时候`timer`的时候，`timer`还是如此丝滑，没有一点停顿。
没有卡顿之后我们`VC -> dealloc`中`timer`还是在执行，那么需要在`dealloc`中去下和删除观察者

```
-(void)dealloc{
	NSLog(@"%s",__func__);
	CFRunLoopRemoveObserver(CFRunLoopGetMain(), obs, m);
	dispatch_source_cancel(timer);
}
```

退出`vc`之后`dealloc`照常执行，日志只有`-[ViewController dealloc]`，而且数字没有继续输出，说明删除观察者和取消`source`都成功了。

那么`NSRunLoopCommonModes`是另外一种模式吗？

通过源码查看得知，在`runloop.c line:1632  line:2608 `

```
if (CFStringGetTypeID() == CFGetTypeID(curr->_mode)) {
    doit = CFEqual(curr->_mode, curMode) || (CFEqual(curr->_mode, kCFRunLoopCommonModes) && CFSetContainsValue(commonModes, curMode));
    } else {
    doit = CFSetContainsValue((CFSetRef)curr->_mode, curMode) || (CFSetContainsValue((CFSetRef)curr->_mode, kCFRunLoopCommonModes) && CFSetContainsValue(commonModes, curMode));
    }
```

还有很多地方均可以看出，当是`currentMode`需要和`_mode`相等才去执行，当是`kCFRunLoopCommonModes`的时候，只需要包含`curMode`即可执行。可见`kCFRunLoopCommonModes`其实是一个集合，不是某个特定的`mode`。

##### 线程保活
线程为什么需要保活？性能其实很大的瓶颈是在于空间的申请和释放，当我们执行一个任务的时候创建了一个线程，任务结束就释放掉该线程，如果任务频率比较高，那么一个一直活跃的线程来执行我们的任务就省去申请和释放空间的时间和性能。上边已经讲过了
`runloop`需要有任务才能不退出，总不可能直接让他执行`while(1)`吧，这种方法明显不对的，由源码得知，当有监测端口的时候，也不会退出，也不会影响应能。所以在线程初始化的时候使用

```
[[NSRunLoop currentRunLoop] addPort:[NSPort port] 
                            forMode:NSRunLoopCommonModes];
```

来保活。
在主线程使用是没有意义的，系统已经在APP启动的时候进行了调用，则已经加入到全局的字典中了。

验证线程保活

```
@property (nonatomic,strong) FYThread *thread;


- (void)viewDidLoad {
	[super viewDidLoad];
	self.thread=[[FYThread alloc]initWithTarget:self selector:@selector(test) object:nil];
	_thread.name = @"test thread";
	[_thread start];
}
- (void)test {
//添加端口
	[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
	
	NSLog(@"%@",[NSThread currentThread]);
	NSLog(@"--start--");
	[[NSRunLoop currentRunLoop] run];
	NSLog(@"--end--");
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	NSLog(@"%s",__func__);
	[self performSelector:@selector(alive) onThread:self.thread withObject:nil waitUntilDone:NO];
	NSLog(@"执行完毕了子线程");//不执行 因为子线程保活了 不会执行完毕
}
//测试子线程是否还活着
- (void)alive{
	NSLog(@"我还活着呢->%@",[NSThread currentThread]);
}
//log
//注释掉添加端口代码
<FYThread: 0x6000013a9540>{number = 3, name = test thread}
--start--
--end--
-[ViewController touchesBegan:withEvent:]
执行完毕了子线程



//注释放开的时候点击触发log
<FYThread: 0x6000013a9540>{number = 3, name = test thread}
--start--

-[ViewController touchesBegan:withEvent:]
执行完毕了子线程
我还活着呢-><FYThread: 0x6000017e5c80>{number = 3, name = test thread}
```

`[[NSRunLoop currentRunLoop] addPort:[NSPort port]forMode:NSDefaultRunLoopMode]`添加端口注释掉，直接执行了`--end--`，线程虽然`strong`强引用，但是`runloop`已经退出了，所以函数`alive`没有执行，不注释的话，`alive`还会执行，`end`一直不会执行，因为进入了`runloop`，而且没有退出，代码就不会向下执行。

那我们测试下该线程声明周期多长？

```
- (void)viewDidLoad {
	[super viewDidLoad];
	self.thread=[[FYThread alloc]initWithTarget:self selector:@selector(test) object:nil];
	_thread.name = @"test thread";
	[_thread start];
}
- (void)test {
	[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
	//获取obs
	NSLog(@"%@",[NSThread currentThread]);
	NSLog(@"--start--");
	/*
	 If no input sources or timers are attached to the run loop, this method exits immediately; otherwise, it runs the receiver in the NSDefaultRunLoopMode by repeatedly invoking runMode:beforeDate:. In other words, this method effectively begins an infinite loop that processes data from the run loop’s input sources and timers.
	 */
	[[NSRunLoop currentRunLoop] run];
	NSLog(@"--end--");
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	NSLog(@"%s",__func__);
	[self performSelector:@selector(alive) onThread:self.thread withObject:nil waitUntilDone:NO];
	NSLog(@"执行完毕了子线程");//不执行 因为子线程保活了 不会执行完毕
}
//返回上页
- (IBAction)popVC:(id)sender {
	[self performSelector:@selector(stop) onThread:self.thread withObject:nil waitUntilDone:NO];
}
//测试子线程是否还活着
- (void)alive{
	NSLog(@"我还活着呢->%@",[NSThread currentThread]);
}
//停止子线程线程
- (void)stop{
	CFRunLoopStop(CFRunLoopGetCurrent());
	NSLog(@"%s",__func__);
}
- (void)dealloc{
	NSLog(@"%s",__func__);
}

//log

<FYThread: 0x600003394780>{number = 3, name = test thread}
--start--
-[ViewController stop]
-[ViewController stop]

```

拥有该线程的是`VC`，点击`pop`的时候，但是`VC`和`thread`没释放掉,好像`thread`和`VC`建立的循环引用，当`self.thread=[[FYThread alloc]initWithTarget:self selector:@selector(test) object:nil];`注释了，则`VC`可以进行正常释放。

通过测试了解到
这个线程达到了**永生**，就是你杀不死他，简直了**死待**。查找了不少资料才发现官方文档才是最稳的。有对这句`[[NSRunLoop currentRunLoop] run]`的解释
> If no input sources or timers are attached to the run loop, this method exits immediately; otherwise, it runs the receiver in the NSDefaultRunLoopMode by repeatedly invoking runMode:beforeDate:. In other words, this method effectively begins an infinite loop that processes data from the run loop’s input sources and timers.

就是系统写了以一个死循环但是没有阻止他的参数，相当于一直在循环调用
`runMode:beforeDate:`，那么该怎么办呢？
官方文档给出了解决方案

```

BOOL shouldKeepRunning = YES; // global
NSRunLoop *theRL = [NSRunLoop currentRunLoop];
while (shouldKeepRunning && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
```

将代码改成下面的成功将**死待**杀死了。

```
- (void)test {
	[[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
	//获取obs
	NSLog(@"%@",[NSThread currentThread]);
	NSLog(@"--start--");
	self.shouldKeepRunning = YES;//默认运行
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	while (_shouldKeepRunning && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
	NSLog(@"--end--");
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	NSLog(@"%s",__func__);
	[self performSelector:@selector(alive) onThread:self.thread withObject:nil waitUntilDone:NO];
	NSLog(@"执行完毕了子线程");//不执行 因为子线程保活了 不会执行完毕
}
//返回上页
- (IBAction)popVC:(id)sender {
	self.shouldKeepRunning = NO;
	[self performSelector:@selector(stop) onThread:self.thread withObject:nil waitUntilDone:NO];
}
//测试子线程是否还活着
- (void)alive{
	NSLog(@"我还活着呢->%@",[NSThread currentThread]);
}
//停止子线程线程
- (void)stop{
	CFRunLoopStop(CFRunLoopGetCurrent());
	NSLog(@"%s",__func__);
	[self performSelectorOnMainThread:@selector(pop) withObject:nil waitUntilDone:NO];
}
- (void)pop{
	[self.navigationController popViewControllerAnimated:YES];

}
- (void)dealloc{
	NSLog(@"%s",__func__);
}

//log

<FYThread: 0x600002699fc0>{number = 3, name = test thread}
--start--
-[ViewController stop]
--end--
-[ViewController dealloc]
-[FYThread dealloc]
```

点击`popVC:`首先将`self.shouldKeepRunning = NO`，然后**子线程**执行`CFRunLoopStop(CFRunLoopGetCurrent())`，然后在**主线程**执行`pop`函数，最终返回上级页面而且成功杀死`VC`和**死待**。
当然这个**死待**其实也是有用处的，当使用单例模式作为下载器的时候使用**死待**也没问题。这样子处理比较复杂，我们可以放在`VC`的`dealloc`看看是否能成功。
关键函数稍微更改：

```
//停止子线程线程
- (void)stop{
    if (self.thread == nil) {
        return;
    }
	NSLog(@"%s",__func__);
        [self performSelector:@selector(stopThread) onThread:self.thread withObject:nil waitUntilDone:NO];
}
- (void)stopThread{
    self.shouldKeepRunning = NO;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)dealloc{
    [self stop];
	NSLog(@"%s",__func__);
}
```

当点击返回按钮`VC`和线程都没死，原来他们形成了强引用无法释放,就是`VC`始终无法执行`dealloc`。将函数改成`block`实现

```
    __weak typeof(self) __weakSelf = self;
    self.thread = [[FYThread alloc]initWithBlock:^{
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        NSLog(@"%@",[NSThread currentThread]);
        NSLog(@"--start--");
        __weakSelf.shouldKeepRunning = YES;//默认运行
        NSRunLoop *theRL = [NSRunLoop currentRunLoop];
        while (__weakSelf && __weakSelf.shouldKeepRunning  ){
            [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        };
        NSLog(@"--end--");
    }];
```

测试下崩溃了，崩溃到了：

```
while (__weakSelf.shouldKeepRunning  ){
        [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];//崩溃的地方
    };
```

怎么想感觉不对劲啊，怎么会不行呢？`VC`销毁的时候调用子线程`stop`,最后打断点发现到了崩溃的地方`self`已经不存在了，说明是异步执行的，往前查找使用异步的函数最后出现在了`    [self performSelector:@selector(stopThread) onThread:self.thread withObject:nil waitUntilDone:NO];`，表示不用等待`stopThread`函数执行时间，直接向前继续执行，所以`VC`释放掉了，`while (__weakSelf.shouldKeepRunning )`是`true`，还真进去了，访问了`exe_bad_access`，所以改成`while (__weakSelf&&__weakSelf.shouldKeepRunning )`再跑一下

```
//log

--start--
-[ViewController stop]
-[ViewController dealloc]
--end--
-[FYThread dealloc]
```

如牛奶般丝滑，解决了释放问题，也解决了复杂操作。本文章所有代码均在底部链接可以下载。
使用这个思路自己封装了一个简单的功能，大家可以自己封装一下然后对比一下我的思路，说不定有惊喜！

### 资料参考
- [runloop源码](https://opensource.apple.com/tarballs/CF/)
- [小码哥视频](http://www.520it.com/zt/ios_mj/)
- [任务调度](http://awayqu.1024ul.com/ios/2018/05/02/gcd-3.html)
- [libdispatch](https://opensource.apple.com/tarballs/libdispatch/)
### 资料下载
- [学习资料下载git](https://github.com/ifgyong/iOSDataFactory)
- [demo code git](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码git](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)
- [thread保活c语言版本](https://github.com/ifgyong/demo/tree/master/OC/OC%E6%9C%AC%E8%B4%A8/day14-CFRunloop%E7%BA%BF%E7%A8%8B%E4%BF%9D%E6%B4%BB%E5%B0%81%E8%A3%85%E7%9A%84c%E8%AF%AD%E8%A8%80)
- [thread 保活](https://github.com/ifgyong/demo/tree/master/OC/OC%E6%9C%AC%E8%B4%A8/day14-CFRunloop%E7%BA%BF%E7%A8%8B%E4%BF%9D%E6%B4%BB%E5%B0%81%E8%A3%85)

---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](/images/0.png)