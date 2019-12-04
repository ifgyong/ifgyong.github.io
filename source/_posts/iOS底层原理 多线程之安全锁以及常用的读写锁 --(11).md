title: iOS底层原理  多线程之安全锁以及常用的读写锁 --(11)
date: 2019-12-1 11:21:58
tags:
- iOS
categories: iOS
---

只要提到了多线程就应该想到线程安全，那么怎么做才能做到在多个线程中保证安全呢？
这篇文章主要讲解线程安全。

### 线程安全
线程安全是什么呢？摘抄一段[百度百科](https://baike.baidu.com/item/%E7%BA%BF%E7%A8%8B%E5%AE%89%E5%85%A8/9747724?fr=aladdin)的一段话
> 线程安全是多线程编程时的计算机程序代码中的一个概念。在拥有共享数据的多条线程并行执行的程序中，线程安全的代码会通过同步机制保证各个线程都可以正常且正确的执行，不会出现数据污染等意外情况。

#### 为什么需要线程安全
ATM肯定用过，你要是边取钱，边存钱，会出问题吗？当你取钱的时候，正在取，结果有人汇款正好到账，本来1000块取了100剩下900，结果到账200，1000+200=1200，因为你取的时候，还没取完，汇款到账了结果数字又加上去了。你取的钱跑哪里去了，这里就需要取钱的时候不能写入数据，就是汇款需要在你取钱完成之后再汇款，不能同时进行。

那么在iOS中，锁是如何使用的呢？
### 自旋锁 OS_SPINLOCK
#### 什么是优先级反转
简单从字面上来说，就是低优先级的任务先于高优先级的任务执行了，优先级搞反了。那在什么情况下会生这种情况呢？

假设三个任务准备执行，A，B，C，优先级依次是A>B>C；

首先：C处于运行状态，获得CPU正在执行，同时占有了某种资源；

其次：A进入就绪状态，因为优先级比C高，所以获得CPU，A转为运行状态；C进入就绪状态；

第三：执行过程中需要使用资源，而这个资源又被等待中的C占有的，于是A进入阻塞状态，C回到运行状态；

第四：此时B进入就绪状态，因为优先级比C高，B获得CPU，进入运行状态；C又回到就绪状态；

第五：如果这时又出现B2，B3等任务，他们的优先级比C高，但比A低，那么就会出现高优先级任务的A不能执行，反而低优先级的B，B2，B3等任务可以执行的奇怪现象，而这就是优先反转。

`OS_SPINLOCK`叫做`自旋锁`，等待锁的进程会处于忙等(busy-wait)状态，一直占用着CPU资源，目前已经不安全，可能会出现优先级翻转问题。

`OS_SPINLOCK`API

```
//初始化 一般是0，或者直接数字0也是ok的。
#define	OS_SPINLOCK_INIT    0
//锁的初始化
OSSpinLock lock = OS_SPINLOCK_INIT;
//尝试加锁
bool ret = OSSpinLockTry(&lock);
//加锁
OSSpinLockLock(&lock);
//解锁
OSSpinLockUnlock(&lock);
```

`OSSpinLock`简单实现12306如何卖票

```
//基类实现的卖票
- (void)__saleTicket{
    NSInteger oldCount = self.ticketsCount;
	if (isLog) {
		sleep(sleepTime);
	}
    oldCount --;
    self.ticketsCount = oldCount;
	if (isLog) {
	printf("还剩% 2ld 张票 - %s \n",(long)oldCount,[NSThread currentThread].description.UTF8String);
	}
	
}



- (void)ticketTest{
    self.ticketsCount = 10000;
	NSInteger count = self.ticketsCount/3;
	dispatch_queue_t queue = dispatch_queue_create("tick.com", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
		if (time1 == 0) {
			time1 = CFAbsoluteTimeGetCurrent();
		}
        for (int i = 0; i < count; i ++) {
            [self __saleTicket];
        }
    });
    
    dispatch_async(queue, ^{
		if (time1 == 0) {
			time1 = CFAbsoluteTimeGetCurrent();
		}
        for (int i = 0; i < count; i ++) {
            [self __saleTicket];
        }
    });
    dispatch_async(queue, ^{
		if (time1 == 0) {
			time1 = CFAbsoluteTimeGetCurrent();
		}
        for (int i = 0; i < count; i ++) {
            [self __saleTicket];
        }
    });
	dispatch_barrier_async(queue, ^{
		CFAbsoluteTime time = CFAbsoluteTimeGetCurrent() - time1;
		printf("tick cost time:%f",time);
	});
}
- (void)__getMonery{
    OSSpinLockLock(&_moneyLock);
    [super __getMonery];
    OSSpinLockUnlock(&_moneyLock);
}
- (void)__saleTicket{
    OSSpinLockLock(&_moneyLock);
    [super __saleTicket];
    OSSpinLockUnlock(&_moneyLock);
}
- (void)__saveMonery{
    OSSpinLockLock(&_moneyLock);
    [super __saveMonery];
    OSSpinLockUnlock(&_moneyLock);
}

- (void)__saleTicket{
    NSInteger oldCount = self.ticketsCount;
    oldCount --;
    self.ticketsCount = oldCount;
}
//log
还剩 9 张票 - <NSThread: 0x600003dc6080>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x600003dc6080>{number = 3, name = (null)} 
还剩 7 张票 - <NSThread: 0x600003dc6080>{number = 3, name = (null)} 
还剩 6 张票 - <NSThread: 0x600003df3a00>{number = 4, name = (null)} 
还剩 5 张票 - <NSThread: 0x600003df3a00>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x600003df3a00>{number = 4, name = (null)} 
还剩 3 张票 - <NSThread: 0x600003dc0000>{number = 5, name = (null)} 
还剩 2 张票 - <NSThread: 0x600003dc0000>{number = 5, name = (null)} 
还剩 1 张票 - <NSThread: 0x600003dc0000>{number = 5, name = (null)} 
```

#### 汇编分析

```
for (NSInteger i = 0; i < 5; i ++) {
	[[[NSThread alloc]initWithTarget:self selector:@selector(__saleTicket) object:nil] start];
}

然后将睡眠时间设置为600s，方便我们调试。
- (void)__saleTicket{
    OSSpinLockLock(&_moneyLock);//此行打断点
    [super __saleTicket];
    OSSpinLockUnlock(&_moneyLock);
}
```
到了断点进入`Debug->Debug WorkFlow ->Always Show Disassembly`，到了汇编界面，在`LLDB`输入`stepi`，然后一直按`enter`，一直重复执行上句命令，直到进入了循环，就是类似下列的三行，发现`ja`跳转到地址`0x103f3d0f9`，每次执行到`ja`总是跳转到`0x103f3d0f9`，直到线程睡眠结束。

```
->  0x103f3d0f9 <+241>: movq   %rcx, (%r8)
0x103f3d0fc <+244>: addq   $0x8, %r8
0x103f3d100 <+248>: cmpq   %r8, %r9
0x103f3d103 <+251>: ja     0x103f3d0f9
```
可以通过汇编分析了解到`自旋锁`是真的`忙等`，闲不住的锁。
### os_unfair_lock
`os_unfair_lock`被系统定义为低级锁，一般低级锁都是闲的时候在睡眠，在等待的时候被内核唤醒，目的是替换已弃用的`OSSpinLock`，而且必须使用`OS_UNFAIR_LOCK_INIT`来初始化，加锁和解锁必须在相同的线程，否则会中断进程，使用该锁需要系统在`__IOS_AVAILABLE(10.0)`，锁的数据结构是一个结构体

```
OS_UNFAIR_LOCK_AVAILABILITY
typedef struct os_unfair_lock_s {
	uint32_t _os_unfair_lock_opaque;
} os_unfair_lock, *os_unfair_lock_t;
```

`os_unfair_lock`使用非常简单，只需要在任务前加锁，任务后解锁即可。

```
@interface FYOSUnfairLockDemo : FYBaseDemo
@property (nonatomic,assign) os_unfair_lock lock;
@end

@implementation FYOSUnfairLockDemo
- (instancetype)init{
	if (self = [super init]) {
		self.lock = OS_UNFAIR_LOCK_INIT;
	}
	return self;
}

- (void)__saveMonery{
	os_unfair_lock_lock(&_unlock);
	[super __saveMonery];
	os_unfair_lock_unlock(&_unlock);
}
- (void)__getMonery{
	os_unfair_lock_lock(&_unlock);
	[super __getMonery];
	os_unfair_lock_unlock(&_unlock);
}
- (void)__saleTicket{
	os_unfair_lock_lock(&_unlock);
	[super __saleTicket];
	os_unfair_lock_unlock(&_unlock);
}
@end
//log
还剩 9 张票 - <NSThread: 0x600002eb4bc0>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x600002eb4bc0>{number = 3, name = (null)} 
还剩 7 张票 - <NSThread: 0x600002eb4bc0>{number = 3, name = (null)} 
还剩 6 张票 - <NSThread: 0x600002eb1500>{number = 4, name = (null)} 
还剩 5 张票 - <NSThread: 0x600002eb1500>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x600002eb1500>{number = 4, name = (null)} 
还剩 3 张票 - <NSThread: 0x600002ed4340>{number = 5, name = (null)} 
还剩 2 张票 - <NSThread: 0x600002ed4340>{number = 5, name = (null)} 
还剩 1 张票 - <NSThread: 0x600002ed4340>{number = 5, name = (null)} 
```
#### 汇编分析

`LLDB` 中命令`stepi`遇到函数会进入到函数，`nexti`会跳过函数。我们将断点打到添加锁的位置

```
- (void)__saleTicket{
 	os_unfair_lock_lock(&_unlock);//断点位置
	[super __saleTicket];
	os_unfair_lock_unlock(&_unlock);
}
```

执行`si`,一直`enter`，最终是停止该位子，模拟器缺跳出来了，再`enter`也没用了，因为线程在睡眠了。`syscall`是调用系统函数的命令。

```
libsystem_kernel.dylib`__ulock_wait:
    0x107a3b9d4 <+0>:  movl   $0x2000203, %eax          ; imm = 0x2000203 
    0x107a3b9d9 <+5>:  movq   %rcx, %r10
->  0x107a3b9dc <+8>:  syscall
```


### 互斥锁 pthread_mutex_t
`mutex`叫互斥锁，等待锁的线程会处于休眠状态。



```
-(void)dealloc{
	pthread_mutex_destroy(&_plock);
	pthread_mutexattr_destroy(&t);
}
-(instancetype)init{
	if (self =[super init]) {
		//初始化锁的属性 
//		pthread_mutexattr_init(&t);
//		pthread_mutexattr_settype(&t, PTHREAD_MUTEX_NORMAL);
//		//初始化锁
//		pthread_mutex_init(&_plock, &t);
		
		pthread_mutex_t plock = PTHREAD_MUTEX_INITIALIZER;
		self.plock = plock;
	}
	return self;
}
-(void)__saleTicket{
	pthread_mutex_lock(&_plock);
	[super __saleTicket];
	pthread_mutex_unlock(&_plock);
}
- (void)__getMonery{
	pthread_mutex_lock(&_plock);
	[super __getMonery];
	pthread_mutex_unlock(&_plock);
}
- (void)__saveMonery{
	pthread_mutex_lock(&_plock);
	[super __saveMonery];
	pthread_mutex_unlock(&_plock);
}
//log

还剩 9 张票 - <NSThread: 0x6000014e3600>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x6000014c8d80>{number = 4, name = (null)} 
还剩 7 张票 - <NSThread: 0x6000014c8f40>{number = 5, name = (null)} 
还剩 4 张票 - <NSThread: 0x6000014c8f40>{number = 5, name = (null)} 
还剩 3 张票 - <NSThread: 0x6000014c8f40>{number = 5, name = (null)} 
还剩 5 张票 - <NSThread: 0x6000014c8d80>{number = 4, name = (null)} 
还剩 6 张票 - <NSThread: 0x6000014e3600>{number = 3, name = (null)} 
还剩 2 张票 - <NSThread: 0x6000014c8d80>{number = 4, name = (null)} 
还剩 1 张票 - <NSThread: 0x6000014e3600>{number = 3, name = (null)} 
```
互斥锁有三个类型

```
/*
 * Mutex type attributes
 */
 普通锁
#define PTHREAD_MUTEX_NORMAL		0
//检查错误
#define PTHREAD_MUTEX_ERRORCHECK	1
//递归锁
#define PTHREAD_MUTEX_RECURSIVE		2
//普通锁
#define PTHREAD_MUTEX_DEFAULT		PTHREAD_MUTEX_NORMAL
```
当我们这样子函数调用函数会出现死锁的问题，这是怎么出现的呢？第一把锁是锁住状态，然后进入第二个函数，锁在锁住状态，在等待，但是这把锁需要向后执行才会解锁，到时无限期的等待。

```
- (void)otherTest{
	pthread_mutex_lock(&_plock);
	NSLog(@"%s",__func__);
	[self otherTest2];
	pthread_mutex_unlock(&_plock);
}
- (void)otherTest2{
	pthread_mutex_lock(&_plock);
	NSLog(@"%s",__func__);
	pthread_mutex_unlock(&_plock);
}

//log
-[FYPthread_mutex2 otherTest]
```
上面这个需求需要使用两把锁，或者使用递归锁来解决问题。

```
- (void)otherTest{
	pthread_mutex_lock(&_plock);
	NSLog(@"%s",__func__);
	[self otherTest2];
	pthread_mutex_unlock(&_plock);
}
- (void)otherTest2{
	pthread_mutex_lock(&_plock2);
	NSLog(@"%s",__func__);
	pthread_mutex_unlock(&_plock2);
}

//log
-[FYPthread_mutex2 otherTest]
-[FYPthread_mutex2 otherTest2]
```
从使用2把锁是可以解决这个问题的。
递归锁是什么锁呢？允许同一个线程对一把锁重复加锁。

### NSLock、NSRecursiveLosk

`NSLock`是对`mutex`普通锁的封装

使用`(LLDB) si`可以跟踪`[myLock lock];`的内部函数最终是`pthread_mutex_lock`

```
Foundation`-[NSLock lock]:
    0x1090dfb5a <+0>:  pushq  %rbp
    0x1090dfb5b <+1>:  movq   %rsp, %rbp
    0x1090dfb5e <+4>:  callq  0x1092ca3fe               ; symbol stub for: object_getIndexedIvars
    0x1090dfb63 <+9>:  movq   %rax, %rdi
    0x1090dfb66 <+12>: popq   %rbp
->  0x1090dfb67 <+13>: jmp    0x1092ca596   ;
//  symbol stub for: pthread_mutex_lock
```

`NSLock API`大全

```
//协议NSLocking
@protocol NSLocking

- (void)lock;
- (void)unlock;

@end

@interface NSLock : NSObject <NSLocking> {
@private
    void *_priv;
}
- (BOOL)tryLock;//尝试加锁
- (BOOL)lockBeforeDate:(NSDate *)limit;//在某个日期前加锁，
@property (nullable, copy) NSString *name API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0));
@end
```
用法也很简单

```
@interface FYNSLock(){
	NSLock *_lock;
}
@end

@implementation FYNSLock
- (instancetype)init{
	if (self = [super init]) {
		//封装了mutex的普通锁
		_lock=[[NSLock alloc]init];
	}
	return self;
}

- (void)__saveMonery{
	[_lock lock];
	[super __saveMonery];
	[_lock unlock];
}
- (void)__saleTicket{
	[_lock lock];
	[super __saleTicket];
	[_lock unlock];
}
- (void)__getMonery{
	[_lock lock];
	[super __getMonery];
	[_lock unlock];
}
@end
//log

还剩 9 张票 - <NSThread: 0x600003d4dc40>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x600003d4dc40>{number = 3, name = (null)} 
还剩 7 张票 - <NSThread: 0x600003d4dc40>{number = 3, name = (null)} 
还剩 6 张票 - <NSThread: 0x600003d7bfc0>{number = 4, name = (null)} 
还剩 5 张票 - <NSThread: 0x600003d7bfc0>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x600003d7bfc0>{number = 4, name = (null)} 
还剩 3 张票 - <NSThread: 0x600003d66c00>{number = 5, name = (null)} 
还剩 2 张票 - <NSThread: 0x600003d66c00>{number = 5, name = (null)} 
还剩 1 张票 - <NSThread: 0x600003d66c00>{number = 5, name = (null)} 
```
`NSRecursiveLock`也是对`mutex递归锁`的封装，`API`跟`NSLock`基本一致

```
- (BOOL)tryLock;//尝试加锁
- (BOOL)lockBeforeDate:(NSDate *)limit;//日期前加锁
```


递归锁可以对相同的线程进行反复加锁

```
@implementation FYRecursiveLockDemo
- (instancetype)init{
	if (self = [super init]) {
		//封装了mutex的递归锁
		_lock=[[NSRecursiveLock alloc]init];
	}
	return self;
}
- (void)otherTest{
	static int count = 10;
	[_lock lock];
	while (count > 0) {
		count -= 1;
		printf("循环% 2d次 - %s \n",count,[NSThread currentThread].description.UTF8String);
		[self otherTest];
	}
	[_lock unlock];
}
@end

//log
循环 9次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 8次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 7次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 6次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 5次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 4次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 3次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 2次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 1次 - <NSThread: 0x60000274e900>{number = 1, name = main} 
循环 0次 - <NSThread: 0x60000274e900>{number = 1, name = main}
```
### NSCondition 条件

```
- (void)wait;//等待
- (BOOL)waitUntilDate:(NSDate *)limit;
- (void)signal;//唤醒一个线程
- (void)broadcast;//唤醒多个线程
```

`NSCondition`是对`mutex`和`cond`的封装

```
- (instancetype)init{
	if (self = [super init]) {
		//遵守的 lock协议 的 条件🔐
		_lock=[[NSCondition alloc]init];
		self.array =[NSMutableArray array];
	}
	return self;
}
- (void)otherTest{
	[[[NSThread alloc]initWithTarget:self selector:@selector(__remove) object:nil] start];
	[[[NSThread alloc]initWithTarget:self selector:@selector(__add) object:nil] start];
}
- (void)__add{
	[_lock lock];
	[self.array addObject:@"Test"];
	NSLog(@"添加成功");
	sleep(1);
	[_lock signal];//唤醒一个线程
	[_lock unlock];
}
- (void)__remove{
	[_lock lock];
	if (self.array.count == 0) {
		[_lock wait];
	}
	[self.array removeLastObject];
	NSLog(@"删除成功");

	[_lock unlock];
}
@end
//Log

2019-07-29 10:06:48.904648+0800 day16--线程安全[43603:4402260] 添加成功
2019-07-29 10:06:49.907641+0800 day16--线程安全[43603:4402259] 删除成功
```
可以看到时间上差了1秒，正好是我们设定的`sleep(1);`。优点是可以让线程之间形成依赖，缺点是没有明确的条件。


### NSConditionLock 可以实现线程依赖的锁
`NSConditionLock`是可以实现多个子线程进行线程间的依赖，A依赖于B执行完成，B依赖于C执行完毕则可以使用`NSConditionLock`来解决问题。
首先看下`API`

```
@property (readonly) NSInteger condition;//条件值
- (void)lockWhenCondition:(NSInteger)condition;//当con为condition进行锁住
//尝试加锁
- (BOOL)tryLock;
//当con为condition进行尝试锁住
- (BOOL)tryLockWhenCondition:(NSInteger)condition;
//当con为condition进行解锁
- (void)unlockWithCondition:(NSInteger)condition;
//NSDate 小余 limit进行 加锁
- (BOOL)lockBeforeDate:(NSDate *)limit;
//条件为condition 在limit之前进行加锁
- (BOOL)lockWhenCondition:(NSInteger)condition beforeDate:(NSDate *)limit;
```

条件锁的使用，在`lockWhenCondition:(NSInteger)condition`的条件到达的时候才能进行正常的加锁和`unlockWithCondition:(NSInteger)condition`解锁，否则会阻塞线程。

```
- (void)otherTest{
	[[[NSThread alloc]initWithTarget:self selector:@selector(__test2) object:nil] start];
	[[[NSThread alloc]initWithTarget:self selector:@selector(__test1) object:nil] start];
	[[[NSThread alloc]initWithTarget:self selector:@selector(__test3) object:nil] start];

}
- (void)__test1{
	[_lock lockWhenCondition:1];
	NSLog(@"%s",__func__);
	[_lock unlockWithCondition:2];//解锁 并赋值2
}
- (void)__test2{
	[_lock lockWhenCondition:2];
	NSLog(@"%s",__func__);
	[_lock unlockWithCondition:3];//解锁 并赋值3
}
- (void)__test3{
	[_lock lockWhenCondition:3];
	NSLog(@"%s",__func__);
	[_lock unlockWithCondition:4];//解锁 并赋值4
}
@end
//log
-[FYCondLockDemo2 __test1]
-[FYCondLockDemo2 __test2]
-[FYCondLockDemo2 __test3]
```

当`con = 1`进行`test1`加锁和执行任务`A`，任务`A`执行完毕，进行解锁，并把值2赋值给`lock`，这是当`con = 2`的锁开始加锁，进入任务`B`，开始执行任务`B`，当任务`B`执行完毕，进行解锁并赋值为3，然后`con=3`的锁进行加锁，解锁并赋值4来进行线程之间的依赖。
### dispatch_queue 特殊的锁
其实直接使用GCD的串行队列，也是可以实现线程同步的。串行队列其实就是线程的任务在队列中按照顺序执行，达到了锁的目的。

```
@interface FYSerialQueueDemo(){
	dispatch_queue_t _queue;
}@end
@implementation FYSerialQueueDemo
- (instancetype)init{
	if (self =[super init]) {
		_queue = dispatch_queue_create("fyserial.queue", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}
- (void)__saleTicket{
	dispatch_sync(_queue, ^{
		[super __saleTicket];
	});
}
- (void)__getMonery{
	dispatch_sync(_queue, ^{
		[super __getMonery];
	});
}
- (void)__saveMonery{
	dispatch_sync(_queue, ^{
		[super __saveMonery];
	});
}
@end
//log
还剩 9 张票 - <NSThread: 0x600001211b40>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x600001243700>{number = 4, name = (null)} 
还剩 7 张票 - <NSThread: 0x60000121dd80>{number = 5, name = (null)} 
还剩 6 张票 - <NSThread: 0x600001211b40>{number = 3, name = (null)} 
还剩 5 张票 - <NSThread: 0x600001243700>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x60000121dd80>{number = 5, name = (null)} 
还剩 3 张票 - <NSThread: 0x600001211b40>{number = 3, name = (null)} 
还剩 2 张票 - <NSThread: 0x600001243700>{number = 4, name = (null)} 
还剩 1 张票 - <NSThread: 0x60000121dd80>{number = 5, name = (null)}
```

### dispatch_semaphore 信号量控制并发数量
当我们有大量任务需要并发执行，而且同时最大并发量为5个线程，这样子又该如何控制呢？`dispatch_semaphore`信号量正好可以满足我们的需求。
`dispatch_semaphore`可以控制并发线程的数量，当设置为1时，可以作为同步锁来用，设置多个的时候，就是异步并发队列。

```
//初始化信号量 值为2，就是最多允许同时2个线程执行
_semaphore = dispatch_semaphore_create(2);
//生成多个线程进行并发访问test
- (void)otherTest{
	for (int i = 0; i < 10; i ++) {
		[[[NSThread alloc]initWithTarget:self selector:@selector(test) object:nil]start];
	}
}
- (void)test{
//如果信号量>0 ，让信号量-1，继续向下执行。
//如果信号量 <= 0;就会等待，等待时间是 DISPATCH_TIME_FOREVER
	dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
	sleep(2);//睡眠时间2s
	NSLog(@"%@",[NSThread currentThread]);
	//释放一个信号量
	dispatch_semaphore_signal(_semaphore);
}
//log

2019-07-29 11:17:53.233318+0800 day16--线程安全[47907:4529610] <NSThread: 0x600002c45240>{number = 4, name = (null)}
2019-07-29 11:17:53.233329+0800 day16--线程安全[47907:4529609] <NSThread: 0x600002c45200>{number = 3, name = (null)}
2019-07-29 11:17:55.233879+0800 day16--线程安全[47907:4529616] <NSThread: 0x600002c45540>{number = 10, name = (null)}
2019-07-29 11:17:55.233879+0800 day16--线程安全[47907:4529612] <NSThread: 0x600002c45440>{number = 6, name = (null)}
2019-07-29 11:17:57.238860+0800 day16--线程安全[47907:4529613] <NSThread: 0x600002c45480>{number = 7, name = (null)}
2019-07-29 11:17:57.238867+0800 day16--线程安全[47907:4529614] <NSThread: 0x600002c454c0>{number = 8, name = (null)}
2019-07-29 11:17:59.241352+0800 day16--线程安全[47907:4529615] <NSThread: 0x600002c45500>{number = 9, name = (null)}
2019-07-29 11:17:59.241324+0800 day16--线程安全[47907:4529611] <NSThread: 0x600002c45400>{number = 5, name = (null)}
2019-07-29 11:18:01.245790+0800 day16--线程安全[47907:4529618] <NSThread: 0x600002c455c0>{number = 12, name = (null)}
2019-07-29 11:18:01.245790+0800 day16--线程安全[47907:4529617] <NSThread: 0x600002c45580>{number = 11, name = (null)}
```

一次最多2个线程同时执行任务，暂停时间是2s。
使用信号量实现线程最大并发锁，
同时只有2个线程执行的。

```
- (instancetype)init{
	if (self =[super init]) {
		_semaphore = dispatch_semaphore_create(1);
	}
	return self;
}
- (void)__saleTicket{
	dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
	[super __saleTicket];
	dispatch_semaphore_signal(_semaphore);
}
//log
还剩 9 张票 - <NSThread: 0x6000022e0c00>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x6000022e0dc0>{number = 4, name = (null)} 
还剩 7 张票 - <NSThread: 0x6000022ce880>{number = 5, name = (null)} 
还剩 6 张票 - <NSThread: 0x6000022e0c00>{number = 3, name = (null)} 
还剩 5 张票 - <NSThread: 0x6000022e0dc0>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x6000022ce880>{number = 5, name = (null)} 
还剩 3 张票 - <NSThread: 0x6000022e0c00>{number = 3, name = (null)} 
还剩 2 张票 - <NSThread: 0x6000022e0dc0>{number = 4, name = (null)} 
还剩 1 张票 - <NSThread: 0x6000022ce880>{number = 5, name = (null)} 
```

### @synchronized
`@synchronized(id obj){}`锁的是对象`obj`，使用该锁的时候，底层是对象计算出来的值作为`key`，生成一把锁，不同的资源的读写可以使用不同`obj`作为锁对象。

```
- (void)__saleTicket{
	@synchronized (self) {
		[super __saleTicket];
	}
 }
 //log
还剩 9 张票 - <NSThread: 0x60000057d5c0>{number = 3, name = (null)} 
还剩 8 张票 - <NSThread: 0x60000056f340>{number = 4, name = (null)} 
还剩 7 张票 - <NSThread: 0x60000057d500>{number = 5, name = (null)} 
还剩 6 张票 - <NSThread: 0x60000057d5c0>{number = 3, name = (null)} 
还剩 5 张票 - <NSThread: 0x60000056f340>{number = 4, name = (null)} 
还剩 4 张票 - <NSThread: 0x60000057d500>{number = 5, name = (null)} 
还剩 3 张票 - <NSThread: 0x60000057d5c0>{number = 3, name = (null)} 
还剩 2 张票 - <NSThread: 0x60000056f340>{number = 4, name = (null)} 
还剩 1 张票 - <NSThread: 0x60000057d500>{number = 5, name = (null)} 
```

### atmoic 原子操作
给属性添加`atmoic`修饰，可以保证属性的`setter`和`getter`都是原子性操作，也就保证了`setter`和`getter`的内部是线程同步的。
原子操作是最终调用了`static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy) objc-accessors.mm 48行`，我们进入到函数内部

```
//设置属性原子操作
void objc_setProperty_atomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, true, false, false);
}
//非原子操作设置属性
void objc_setProperty_nonatomic(id self, SEL _cmd, id newValue, ptrdiff_t offset)
{
    reallySetProperty(self, _cmd, newValue, offset, false, false, false);
}

static inline void reallySetProperty(id self, SEL _cmd, id newValue, ptrdiff_t offset, bool atomic, bool copy, bool mutableCopy)
{//偏移量等于0则是class指针
    if (offset == 0) {
        object_setClass(self, newValue);
        return;
    }
//其他的value
    id oldValue;
    id *slot = (id*) ((char*)self + offset);

    if (copy) {
    //如果是copy 用copyWithZone:
        newValue = [newValue copyWithZone:nil];
    } else if (mutableCopy) {
        //mutableCopy则调用mutableCopyWithZone:
        newValue = [newValue mutableCopyWithZone:nil];
    } else {
    //如果赋值和原来的相等 则不操作
        if (*slot == newValue) return;
        newValue = objc_retain(newValue);
    }

    if (!atomic) {//非原子操作 直接赋值
        oldValue = *slot;
        *slot = newValue;
    } else {//原子操作 加锁
    //锁和属性是一一对应的->自旋锁
        spinlock_t& slotlock = PropertyLocks[slot];
        slotlock.lock();
        oldValue = *slot;
        *slot = newValue;//赋值
        slotlock.unlock();//解锁
    }
    objc_release(oldValue);
}


id objc_getProperty(id self, SEL _cmd, ptrdiff_t offset, BOOL atomic) {
    if (offset == 0) {
        return object_getClass(self);
    }

    // Retain release world
    id *slot = (id*) ((char*)self + offset);
    if (!atomic) return *slot;//非原子操作 直接返回值
        
    // Atomic retain release world
	//原子操作 加锁->自旋锁
    spinlock_t& slotlock = PropertyLocks[slot];
    slotlock.lock();//加锁
    id value = objc_retain(*slot);
    slotlock.unlock();//解锁
    
    // for performance, we (safely) issue the autorelease OUTSIDE of the spinlock.
    return objc_autoreleaseReturnValue(value);
}

//以属性的地址为参数计算出key ，锁为value
StripedMap<spinlock_t> PropertyLocks;
```
从源码了解到设置属性读取是`self`+属性的偏移量，当`copy`或`mutableCopy`会调用到`[newValue copyWithZone:nil]`或`[newValue mutableCopyWithZone:nil]`，如果新旧值相等则不进行操作，非原子操作直接赋值，原子操作则获取`spinlock_t& slotlock = PropertyLocks[slot]`进行加锁、赋值、解锁操作。而且`PropertyLocks`是一个类，类有一个数组属性，使用`*p`计算出来的值作为`key`。

我们提取出来关键代码

```
//原子操作 加锁
spinlock_t& slotlock = PropertyLocks[slot];
slotlock.lock();
oldValue = *slot;
*slot = newValue;//赋值
slotlock.unlock();//解锁
```
使用自旋锁对赋值操作进行加锁，保证了`setter()`方法的安全性

```
//原子操作 加锁 ->自旋锁
spinlock_t& slotlock = PropertyLocks[slot];
slotlock.lock();//加锁
id value = objc_retain(*slot);
slotlock.unlock();//解锁
```
取值之前进行加锁，取值之后进行解锁，保证了`getter()`方法的安全。

由上面得知`atmoic`仅仅是对方法`setter()`和`getter()`安全，对成员变量不保证安全，对于属性的读写一般使用`nonatomic`，性能好，`atomic`读取频率高的时候会导致线程都在排队，浪费CPU时间。

大概使用者几种锁分别对卖票功能进行了性能测试，
性能分别1万次、100万次、1000万次锁花费的时间对比，单位是秒。(仅供参考，不同环境时间略有差异)

|锁类型|1万次|100万次|1000万次|
|:-:|:-:|:-:|:-:|
|pthread_mutex_t|0.000309|0.027238|0.284714|
|os_unfair_lock|0.000274|0.028266|0.285685|
|OSSpinLock|0.030688|0.410067|0.437702|
|NSCondition|0.005067 |0.323492|1.078636|
|NSLock|0.038692|0.151601|1.322062|
|NSRecursiveLock|0.007973|0.151601|1.673409|
|@synchronized|0.008953|0.640234|2.790291|
|NSConditionLock|0.229148  |5.325272|10.681123|
|semaphore|0.094267|0.415351|24.699100|
|SerialQueue|0.213386|9.058581|50.820202|

### 建议
平时我们简单使用的话没有很大的区别，还是推荐使用`NSLock`和信号量,最简单的是`@synchronized`，不用声明和初始化，直接拿来就用。

### 自旋锁、互斥锁比较
自旋锁和互斥锁各有优劣，代码执行频率高，CPU充足，可以使用互斥锁，频率低，代码复杂则需要互斥锁。
#### 自旋锁
- 自旋锁在等待时间比较短的时候比较合适
- 临界区代码经常被调用，但竞争很少发生
- CPU不紧张
- 多核处理器
#### 互斥锁
- 预计线程等待时间比较长
- 单核处理器
- 临界区IO操作
- 临界区代码比较多、复杂，或者循环量大
- 临界区竞争非常激烈

## 锁的应用
#### 简单读写锁
一个简单的读写锁，读写互斥即可，我们使用信号量，值设定为1.同时只能一个线程来操作文件,读写互斥。

```
- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	self.semaphore = dispatch_semaphore_create(1);
	
	for (NSInteger i = 0; i < 10; i ++) {
		[[[NSThread alloc]initWithTarget:self selector:@selector(read) object:nil]start];
		[[[NSThread alloc]initWithTarget:self selector:@selector(write) object:nil]start];
	}
}

- (void)read{
	dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
	NSLog(@"%s",__func__);
	dispatch_semaphore_signal(self.semaphore);
}
- (void)write{
	dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
	NSLog(@"%s",__func__);
	dispatch_semaphore_signal(self.semaphore);
}
```

当读写都是一个线程来操作，会降低性能，当多个线程在读资源的时候，其实不需要同步操作的，有读没写，理论上说不用限制异步数量，写入的时候不能读，才是真正限制线程性能的地方，读写锁具备以下特点
1. 同一时间，只能有1个线程进行写操作
2. 同一时间，允许有多个线程进行读的操作
3. 同一时间，不允许读写操作同时进行

典型的`多读单写`，经常用于文件等数据的读写操作，我们实现2种

#### 读写锁 pthread_rwlock
这是有c语言封装的读写锁

```
//初始化读写锁
int pthread_rwlock_init(pthread_rwlock_t * __restrict,
		const pthread_rwlockattr_t * _Nullable __restrict)
//读上锁
pthread_rwlock_rdlock(pthread_rwlock_t *)
//尝试加锁读
pthread_rwlock_tryrdlock(pthread_rwlock_t *)
//尝试加锁写
int pthread_rwlock_trywrlock(pthread_rwlock_t *)
//写入加锁
pthread_rwlock_wrlock(pthread_rwlock_t *)
//解锁
pthread_rwlock_unlock(pthread_rwlock_t *)
//销毁锁属性
pthread_rwlockattr_destroy(pthread_rwlockattr_t *)
//销毁锁
pthread_rwlock_destroy(pthread_rwlock_t * )
```

`pthread_rwlock_t`使用很简单，只需要在读之前使用`pthread_rwlock_rdlock`，读完解锁`pthread_rwlock_unlock`,写入前需要加锁`pthread_rwlock_wrlock`，写入完成之后解锁`pthread_rwlock_unlock`，任务都执行完了可以选择销毁`pthread_rwlock_destroy`或者等待下次使用。

```
@property (nonatomic,assign) pthread_rwlock_t rwlock;


- (void)dealloc{
	pthread_rwlock_destroy(&_rwlock);//销毁锁
}
//初始化读写锁
pthread_rwlock_init(&_rwlock, NULL);
	
dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	for (NSInteger i = 0; i < 5; i ++) {
		dispatch_async(queue, ^{
			[[[NSThread alloc]initWithTarget:self selector:@selector(readPthreadRWLock) object:nil]start];
			[[[NSThread alloc]initWithTarget:self selector:@selector(writePthreadRWLock) object:nil]start];
		});
	}
	
	
- (void)readPthreadRWLock{
    pthread_rwlock_rdlock(&_rwlock);
    NSLog(@"读文件");
    sleep(1);
    pthread_rwlock_unlock(&_rwlock);
}
- (void)writePthreadRWLock{
    pthread_rwlock_wrlock(&_rwlock);
    NSLog(@" 写入文件");
    sleep(1);
    pthread_rwlock_unlock(&_rwlock);
}

//log
2019-07-30 10:47:16 读文件
2019-07-30 10:47:16 读文件
2019-07-30 10:47:17 写入文件
2019-07-30 10:47:18 写入文件
2019-07-30 10:47:19 读文件
2019-07-30 10:47:19 读文件
2019-07-30 10:47:19 读文件
2019-07-30 10:47:20 写入文件
2019-07-30 10:47:21 写入文件
2019-07-30 10:47:22 写入文件
```
读文件会出现同一秒读多次，写文件同一秒只有一个。

#### 异步栅栏调用 dispatch_barrier_async
栅栏大家都见过，为了分开一个地区而使用的，线程的栅栏函数是分开任务的执行顺序

|操作|任务|任务|任务|
|:-:|:-:|:-:|:-:|
|读|A|B||
|读|A|B||
|写|||C|
|写|||C|
|读|A|||
|读|A|B||


这个函数传入的并发队列必须是通过`dispatch_queue_create`创建，如果传入的是一个串行的或者全局并发队列，这个函数便等同于`dispatch_async`的效果。

```
//初始化 异步队列
self.rwqueue = dispatch_queue_create("rw.thread", DISPATCH_QUEUE_CONCURRENT);
dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
for (NSInteger i = 0; i < 5; i ++) {
	dispatch_async(queue, ^{
		[self readBarryier];
		[self readBarryier];
		[self readBarryier];
		[self writeBarrier];
	});
}

- (void)readBarryier{
//添加任务到rwqueue
	dispatch_async(self.rwqueue, ^{
		NSLog(@"读文件 %@",[NSThread currentThread]);
		sleep(1);
	});
}
- (void)writeBarrier{
//barrier_async添加任务到self.rwqueue中
	dispatch_barrier_async(self.rwqueue, ^{
		NSLog(@"写入文件 %@",[NSThread currentThread]);
		sleep(1);
	});
}

//log

2019-07-30 11:16:53 读文件 <NSThread: 0x600001ae0740>{number = 9, name = (null)}
2019-07-30 11:16:53 读文件 <NSThread: 0x600001ae8500>{number = 10, name = (null)}
2019-07-30 11:16:53 读文件 <NSThread: 0x600001ae8040>{number = 8, name = (null)}
2019-07-30 11:16:53 读文件 <NSThread: 0x600001ac3a80>{number = 11, name = (null)}
2019-07-30 11:16:54 写入文件<NSThread: 0x600001ac3a80>{number = 11, name = (null)}
2019-07-30 11:16:55 写入文件<NSThread: 0x600001ac3a80>{number = 11, name = (null)}
2019-07-30 11:16:56 写入文件<NSThread: 0x600001ac3a80>{number = 11, name = (null)}
```
读文件会出现同一秒读多个，写文件同一秒只有一个。


读写任务都添加到异步队列`rwqueue`中，使用栅栏函数`dispatch_barrier_async`拦截一下，实现读写互斥，读可以异步无限读，写只能一个同步写的功能。


### 总结
- 普通线程锁本质就是同步执行
- `atomic`原子操作只限制`setter`和`getter`方法，不限制成员变量
- 读写锁高性能可以使用`pthread_rwlock_t`和`dispatch_barrier_async`
### 参考资料
- [优先级反转](https://blog.csdn.net/Fly_as_tadpole/article/details/86436161 )
- [iOS多线程：『GCD』详尽总结](https://juejin.im/post/5a90de68f265da4e9b592b40#heading-16)
- [小码哥视频](http://www.520it.com/zt/ios_mj/)
- [任务调度](http://awayqu.1024ul.com/ios/2018/05/02/gcd-3.html)
- [libdispatch](https://opensource.apple.com/tarballs/libdispatch/)
- iOS和OS多线程与内存管理
### 资料下载
- [学习资料下载git](https://github.com/ifgyong/iOSDataFactory)
- [demo code git](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码git](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](/images/0.png)