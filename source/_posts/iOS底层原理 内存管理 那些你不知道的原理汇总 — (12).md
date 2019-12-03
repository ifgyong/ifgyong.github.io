title: iOS底层原理  内存管理 那些你不知道的原理汇总 --(12)
date: 2019-12-1 11:22:58
tags:
- iOS
categories: iOS
---

看完本文章你将了解到
> 1. DisplayLink和timer的使用和原理
> 2. 内存分配和内存管理
> 3. 自动释放池原理
> 4. weak指针原理和释放时机
> 5. 引用计数原理


### DisplayLink
`CADisplayLink`是将任务添加到`runloop`中，`loop`每次循环便会调用`target`的`selector`，使用这个也能监测卡顿问题。首先介绍下`API`

```
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel;
//runloop没循环一圈都会调用
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
//从runloop中删除
- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
//取消
- (void)invalidate;
```
我们在一个需要`push`的`VC`中运行来观察声明周期

```
@property (nonatomic,strong) CADisplayLink *link;

//初始化
self.link = [FYDisplayLink displayLinkWithTarget:self selector:@selector(test)];
[self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
dispatch_source_set_event_handler(timer, ^{
	@synchronized (self) {
		NSLog(@"FPS:%d",fps);
		fps = 0;
	}
});
dispatch_resume(timer);
//全局变量
dispatch_source_t timer;
static int fps;

- (void)test{
	
	@synchronized (self) {
		fps += 1;
	}
}
- (void)dealloc{
	[self.link invalidate];
	NSLog(@"%s",__func__);
}
//log
2019-07-30 17:44:37.217781+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:38.212477+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:39.706000+0800 day17-定时器[29637:6504821] FPS:89
2019-07-30 17:44:40.706064+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:41.705589+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:42.706268+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:43.705942+0800 day17-定时器[29637:6504821] FPS:60
2019-07-30 17:44:44.705792+0800 day17-定时器[29637:6504821] FPS:60
```

初始化之后，对`fps`使用了简单版本的读写锁，可以看到`fps`基本稳定在60左右，点击按钮返回之后，`link`和`VC`并没有正常销毁。我们分析一下，`VC（self）`->`link`->`target(self)`,导致了死循环，释放的时候，无法释放`self`和`link`,那么我们改动一下`link`->`target(self)`中的强引用，改成弱引用，代码改成下面的

```
@interface FYTimerTarget : NSObject
@property (nonatomic,weak) id target;
@end

@implementation FYTimerTarget
-(id)forwardingTargetForSelector:(SEL)aSelector{
	return self.target;
}
- (void)dealloc{
	NSLog(@"%s",__func__);
}
@end


FYProxy *proxy=[FYProxy proxyWithTarget:self];
self.link = [FYDisplayLink displayLinkWithTarget:self selector:@selector(test)];
[self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

- (void)test{
	NSLog(@"%s",__func__);
}

//log
2019-07-30 17:59:04.339934 -[ViewController test]
2019-07-30 17:59:04.356292 -[ViewController test]
2019-07-30 17:59:04.371428 -[FYTimerTarget dealloc]
2019-07-30 17:59:04.371634 -[ViewController dealloc]
```

`FYTimerTarget`对`target`进行了弱引用，`self`对`FYTimerTarget`进行强引用，在销毁了的时候，先释放`self`,然后检查`self`的`FYTimerTarget`,`FYTimerTarget`只有一个参数`weak`属性，可以直接释放，释放完`FYTimerTarget`，然后释放`self(VC)`，最终可以正常。


### NSTimer
使用`NSTimer`的时候，`timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo`会对`aTarget`进行强引用，所以我们对这个`aTarget`进行一个简单的封装

```
@interface FYProxy : NSProxy
@property (nonatomic,weak) id target;

+(instancetype)proxyWithTarget:(id)target;
@end
@implementation FYProxy
- (void)dealloc{
	NSLog(@"%s",__func__);
}
+ (instancetype)proxyWithTarget:(id)target{
	FYProxy *obj=[FYProxy alloc];
	obj.target = target;
	return obj;
}
//转发
- (void)forwardInvocation:(NSInvocation *)invocation{
	[invocation invokeWithTarget:self.target];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel{
	return [self.target methodSignatureForSelector:sel];
}
@end
```
`FYProxy`是继承`NSProxy`，而`NSProxy`不是继承`NSObject`的,而是另外一种基类，不会走`objc_msgSend()`的三大步骤，当找不到函数的时候直接执行`- (void)forwardInvocation:(NSInvocation *)invocation`，和`- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel`直接进入消息转发阶段。或者将继承关系改成`FYTimerTarget : NSObject`,这样子`target`找不到的函数还是会走消息转发的三大步骤，我们再`FYTimerTarget`添加消息动态解析
```
-(id)forwardingTargetForSelector:(SEL)aSelector{
	return self.target;
}
```
这样子`target`的`aSelector`转发给了`self.target`处理，成功弱引用了`self`和函数的转发处理。


```
FYTimerTarget *obj =[FYTimerTarget new];
obj.target = self;

self.timer = [NSTimer timerWithTimeInterval:1.0f
									target:obj
								   selector:@selector(test)
								   userInfo:nil
									repeats:YES];
[[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
[self.timer setFireDate:[NSDate distantPast]];

//log
2019-07-30 18:03:08.723433+0800 day17-定时器[30877:6556631] -[ViewController test]
2019-07-30 18:03:09.722611+0800 day17-定时器[30877:6556631] -[ViewController test]
2019-07-30 18:03:09.847540+0800 day17-定时器[30877:6556631] -[FYTimerTarget dealloc]
2019-07-30 18:03:09.847677+0800 day17-定时器[30877:6556631] -[ViewController dealloc]
```

或者使用`timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block`，然后外部使用`__weak self`调用函数，也不会产生循环引用。
使用`block`的情况，释放正常。

```
self.timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
	NSLog(@"123");
}];

//log
2019-07-30 18:08:24.678789+0800 day17-定时器[31126:6566530] 123
2019-07-30 18:08:25.659127+0800 day17-定时器[31126:6566530] 123
2019-07-30 18:08:26.107643+0800 day17-定时器[31126:6566530] -[ViewController dealloc]
```

由于`link`和`timer`是添加到`runloop`中使用的，每次一个循环则访问`timer`或者`link`，然后执行对应的函数，在时间上有相对少许误差的，每此循环，要刷新UI(在主线程)，要执行其他函数，要处理系统端口事件，要处理其他的计算。。。总的来说，误差还是有的。

### GCD中timer
`GCD`中的`dispatch_source_t`的定时器是基于内核的，时间误差相对较少。

```
//timer 需要强引用 或者设置成全局变量
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    //设置
    dispatch_source_set_event_handler(timer, ^{
  //code 定时器执行的代码
 
    });
    //开始定时器
    dispatch_resume(timer);
```

或者使用函数`dispatch_source_set_event_handler_f(timer, function_t);`

```
dispatch_source_set_event_handler_f(timer, function_t);
void function_t(void * p){
    //code here    
}
```

业务经常使用定时器的话，还是封装一个简单的功能比较好，封装首先从需求开始分析，我们使用定时器常用的参数都哪些？需要哪些功能？

首先需要开始的时间，然后执行的频率，执行的任务(函数或block)，是否重复执行，这些都是需要的。
先定义一个函数

```
+ (NSString *)exeTask:(dispatch_block_t)block
    	  start:(NSTimeInterval)time
       interval:(NSTimeInterval)interval
    	 repeat:(BOOL)repeat
    	  async:(BOOL)async;
+ (NSString *)exeTask:(id)target
		  sel:(SEL)aciton
		start:(NSTimeInterval)time
	 interval:(NSTimeInterval)interval
	   repeat:(BOOL)repeat
		async:(BOOL)async;
//取消
+ (void)exeCancelTask:(NSString *)key;
```

然后将刚才写的拿过来，增加了一些判断。有任务的时候才会执行，否则直接返回`nil`，当循环的时候，需要间隔大于0，否则返回，同步或异步，就或者主队列或者异步队列，然后用生成的`key`,`timer`为`value`存储到全局变量中，在取消的时候直接用`key`取出`timer`取消，这里使用了信号量，限制单线程操作。在存储和取出（取消timer）的时候进行限制，提高其他代码执行的效率。

```
+ (NSString *)exeTask:(dispatch_block_t)block start:(NSTimeInterval)time interval:(NSTimeInterval)interval repeat:(BOOL)repeat async:(BOOL)async{
	if (block == nil) {
		return nil;
	}
	if (repeat && interval <= 0) {
		return nil;
	}
	
	NSString *name =[NSString stringWithFormat:@"%d",i];
	//主队列
	dispatch_queue_t queue = dispatch_get_main_queue();
	if (async) {
		queue = dispatch_queue_create("async.com", DISPATCH_QUEUE_CONCURRENT);
	}
	//创建定时器
	dispatch_source_t _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
	//设置启动时间
	dispatch_source_set_timer(_timer,
							  dispatch_time(DISPATCH_TIME_NOW, time*NSEC_PER_SEC), interval*NSEC_PER_SEC, 0);
	//设定回调
	dispatch_source_set_event_handler(_timer, ^{
		block();
		if (repeat == NO) {
			dispatch_source_cancel(_timer);
		}
	});
	//启动定时器
	dispatch_resume(_timer);
	//存放到字典
	if (name.length && _timer) {
		dispatch_semaphore_wait(samephore, DISPATCH_TIME_FOREVER);
		timers[name] = _timer;
		dispatch_semaphore_signal(samephore);
	}
	return name;
}



+ (NSString *)exeTask:(id)target
				  sel:(SEL)aciton
				start:(NSTimeInterval)time
			 interval:(NSTimeInterval)interval
			   repeat:(BOOL)repeat
				async:(BOOL)async{
	if (target == nil || aciton == NULL) {
		return nil;
	}
	if (repeat && interval <= 0) {
		return nil;
	}
	
	NSString *name =[NSString stringWithFormat:@"%d",i];
	//主队列
	dispatch_queue_t queue = dispatch_get_main_queue();
	if (async) {
		queue = dispatch_queue_create("async.com", DISPATCH_QUEUE_CONCURRENT);
	}
	//创建定时器
	dispatch_source_t _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
	//设置启动时间
	dispatch_source_set_timer(_timer,
							  dispatch_time(DISPATCH_TIME_NOW, time*NSEC_PER_SEC), interval*NSEC_PER_SEC, 0);
	//设定回调
	dispatch_source_set_event_handler(_timer, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Warc-performSelector-leaks"
		//这里是会报警告的代码
		if ([target respondsToSelector:aciton]) {
			[target performSelector:aciton];
		}
#pragma clang diagnostic pop

		if (repeat == NO) {
			dispatch_source_cancel(_timer);
		}
	});
	//启动定时器
	dispatch_resume(_timer);
	//存放到字典
	if (name.length && _timer) {
		dispatch_semaphore_wait(samephore, DISPATCH_TIME_FOREVER);
		timers[name] = _timer;
		dispatch_semaphore_signal(samephore);
	}
	return name;
}
+ (void)exeCancelTask:(NSString *)key{
	if (key.length == 0) {
		return;
	}
	dispatch_semaphore_wait(samephore, DISPATCH_TIME_FOREVER);
	if ([timers.allKeys containsObject:key]) {
		dispatch_source_cancel(timers[key]);
		[timers removeObjectForKey:key];
	}
	dispatch_semaphore_signal(samephore);
}
```

用的时候很简单

```
key = [FYTimer exeTask:^{
        NSLog(@"123");
    } start:1
    interval:1 
    repeat:YES 
    async:NO];
```

或者

```
key = [FYTimer exeTask:self sel:@selector(test) start:0 interval:1 repeat:YES async:YES];
```

取消执行的时候

```
[FYTimer exeCancelTask:key];
```

测试封装的定时器

```
- (void)viewDidLoad {
	[super viewDidLoad];
	key = [FYTimer exeTask:self sel:@selector(test) start:0 interval:1 repeat:YES async:YES];
}
-(void)test{
	NSLog(@"%@",[NSThread currentThread]);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	[FYTimer exeCancelTask:key];
}
//log
2019-07-30 21:16:48.639486+0800 day17-定时器2[48817:1300897] <NSThread: 0x6000010ec000>{number = 4, name = (null)}
2019-07-30 21:16:49.640177+0800 day17-定时器2[48817:1300897] <NSThread: 0x6000010ec000>{number = 4, name = (null)}
2019-07-30 21:16:50.639668+0800 day17-定时器2[48817:1300897] <NSThread: 0x6000010ec000>{number = 4, name = (null)}
2019-07-30 21:16:51.639590+0800 day17-定时器2[48817:1300897] <NSThread: 0x6000010ec000>{number = 4, name = (null)}
2019-07-30 21:16:52.156004+0800 day17-定时器2[48817:1300845] -[ViewController touchesBegan:withEvent:]
```

在点击`VC`的时候进行取消操作，`timer`停止。

### NSProxy实战
`NSProxy`其实是除了`NSObject`的另外一个基类，方法比较少，当找不到方法的时候执行消息转发阶段(因为没有父类)，调用函数的流程更短，性能则更好。

问题：`ret1`和`ret2`分别是多少？

```
ViewController *vc1 =[[ViewController alloc]init];
FYProxy *pro1 =[FYProxy proxyWithTarget:vc1];

FYTimerTarget *tar =[FYTimerTarget proxyWithTarget:vc1];
BOOL ret1 = [pro1 isKindOfClass:ViewController.class];
BOOL ret2 = [tar isKindOfClass:ViewController.class];
NSLog(@"%d %d",ret1,ret2);
```


我们来分析一下，`-(bool)isKindOfClass:(cls)`对象函数是判断该对象是否的`cls`的子类或者该类的实例，这点不容置疑，那么`ret1`应该是`0`,`ret2`应该也是`0`



首先看`FYProxy`的实现，`forwardInvocation`和`methodSignatureForSelector`，在没有该函数的时候进行消息转发，转发对象是`self.target`，在该例子中`isKindOfClass`不存在与`FYProxy`，所以讲该函数转发给了`VC`，则`BOOL ret1 = [pro1 isKindOfClass:ViewController.class];`相当于`BOOL ret1 = [ViewController.class isKindOfClass:ViewController.class];`，所以答案是1

然后`ret2`是0，`tar`是继承于`NSObject`的，本身有`-(bool)isKindOfClass:(cls)`函数，所以答案是0。

答案是：`ret1`是`1`，`ret2`是`0`。


### 内存分配
内存分为保留段、数据段、堆(↓)、栈(↑)、内核区。

数据段包括
- 字符串常量：比如NSString * str = @"11"
- 已初始化数据：已初始化的全局变量、静态变量等
- 未初始化数据：未初始化的全局变量、静态变量等

栈：函数调用开销、比如局部变量，分配的内存空间地址越来越小。

堆：通过alloc、malloc、calloc等动态分配的空间，分配的空间地址越来越大。

验证：

```
int a = 10;
int b ;
int main(int argc, char * argv[]) {
    @autoreleasepool {
        static int c = 20;
        static int d;
        int e = 10;
        int f;
        NSString * str = @"123";
        NSObject *obj =[[NSObject alloc]init];
        NSLog(@"\na:%p \nb:%p \nc:%p \nd:%p \ne:%p \nf:%p \nobj:%p\n str:%p",&a,&b,&c,&d,&e,&f,obj,str);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

//log

a:0x1063e0d98 
b:0x1063e0e64 
c:0x1063e0d9c 
d:0x1063e0e60 
e:0x7ffee9820efc 
f:0x7ffee9820ef8 
obj:0x6000013541a0
str:0x1063e0068
```
### Tagged Pointer

从64bit开始，iOS引入`Tagged Pointer`技术，用于优化`NSNumber、NSDate、NSString`等小对象的存储，在没有使用之前，他们需要动态分配内存，维护计数，使用`Tagged Pointer`之后，`NSNumber`指针里面的数据变成了`Tag+Data`，也就是将数值直接存储在了指针中，只有当指针不够存储数据时，才会动态分配内存的方式来存储数据，而且`objc_msgSend()`能够识别出`Tagged Pointer`，比如`NSNumber`的`intValue`方法，直接从指针提取数据，节省了以前的调用的开销。
在iOS中，最高位是1(第64bit)，在Mac中，最低有效位是1。
在`runtime`源码中`objc-internal.h 370行`判断是否使用了优化技术

```
static inline void * _Nonnull
_objc_encodeTaggedPointer(uintptr_t ptr)
{
    return (void *)(objc_debug_taggedpointer_obfuscator ^ ptr);
}
```

我们拿来这个可以判断对象是否使用了优化技术。
#### NSNumbe Tagged Pointer
我们使用几个`NSNumber`的大小数字来验证

```
#if (TARGET_OS_OSX || TARGET_OS_IOSMAC) && __x86_64__ //mac开发
// 64-bit Mac - tag bit is LSB
#   define OBJC_MSB_TAGGED_POINTERS 0
#else
// Everything else - tag bit is MSB
#   define OBJC_MSB_TAGGED_POINTERS 1//iOS开发
#endif

#if OBJC_MSB_TAGGED_POINTERS
#   define _OBJC_TAG_MASK (1UL<<63)
#else
#   define _OBJC_TAG_MASK 1UL
#endif
bool objc_isTaggedPointer(const void * _Nullable ptr)
{
    return ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
}
int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSNumber *n1 = @2;
        NSNumber *n2 = @3;
        NSNumber *n3 = @(4);
        NSNumber *n4 = @(0x4fffffffff);
        NSLog(@"\n%p \n%p \n%p \n%p",n1,n2,n3,n4);
        BOOL n1_tag = objc_isTaggedPointer((__bridge const void * _Nullable)(n1));
        BOOL n2_tag = objc_isTaggedPointer((__bridge const void * _Nullable)(n2));
        BOOL n3_tag = objc_isTaggedPointer((__bridge const void * _Nullable)(n3));
        BOOL n4_tag = objc_isTaggedPointer((__bridge const void * _Nullable)(n4));

        NSLog(@"\nn1:%d \nn2:%d \nn3:%d \nn4:%d ",n1_tag,n2_tag,n3_tag,n4_tag);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
//log

0xbf4071e2657ccb95 
0xbf4071e2657ccb85 
0xbf4071e2657ccbf5 
0xbf40751d9a833444
2019-07-30 21:55:52.626317+0800 day17-TaggedPointer[49770:1328036] 
n1:1 
n2:1 
n3:1 
n4:0
```

可以看到`n1 n2 n3`是经过优化的，而`n4`是大数字，指针容不下该数值，不能优化。
#### NSString Tagged Pointer
看下面一道题,运行`test1`和`test2`会出现什么问题？

```
- (void)test1{
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	for (NSInteger i = 0; i < 1000; i ++) {
		dispatch_async(queue, ^{
			self.name = [NSString stringWithFormat:@"abc"];
		});
	}
}
- (void)test2{
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	for (NSInteger i = 0; i < 1000; i ++) {
		dispatch_async(queue, ^{
			self.name = [NSString stringWithFormat:@"abcsefafaefafafaefe"];
		});
	}
}
```
我们先不运行，先分析一下。

首先全局队列异步添加任务会出现多线程并发问题，在并发的时候进行写操作会出现资源竞争问题，另外一个小字符串会出现指针优化问题，小字符串和大字符串切换导致`_name`结构变化，多线程同时写入和读会导致访问坏内存问题，我们来运行一下

```
Thread: EXC_BAD_ACCESS(code = 1)
```
直接在子线程崩溃了，崩溃函数是`objc_release`。符合我们的猜想。

验证`NSString Tagged Pointer`

```
- (void)test{
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	for (NSInteger i = 0; i < 1; i ++) {
		dispatch_async(queue, ^{
			self.name = [NSString stringWithFormat:@"abc"];
			NSLog(@"test1 class:%@",self.name.class);
		});
	}
}
- (void)test2{
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	for (NSInteger i = 0; i < 1; i ++) {
		dispatch_async(queue, ^{
			self.name = [NSString stringWithFormat:@"abcsefafaefafafaefe"];
			NSLog(@"test2 class:%@",self.name.class);
		});
	}
}
//log
test1 class:NSTaggedPointerString
test2 class:__NSCFString
```
可以看到`NSString Tagged Pointer`在小字符串的时候类是`NSTaggedPointerString`，经过优化的类，大字符串的类是`__NSCFString`，


### copy
拷贝分为浅拷贝和深拷贝，浅拷贝只是引用计数+1，深拷贝是拷贝了一个对象，和之前的 互不影响， 引用计数互不影响。

拷贝目的：产生一个副本对象，跟源对象互不影响
 修改源对象，不会影响到副本对象
 修改副本对象，不会影响源对象
 
 iOS提供了2中拷贝方法
 1. copy 拷贝出来不可变对象
 2. mutableCopy 拷贝出来可变对象
 
 
```
void test1(){
	NSString *str = @"strstrstrstr";
	NSMutableString *mut1 =[str mutableCopy];
	[mut1 appendFormat:@"123"];
	NSString *str2 = [str copy];
	NSLog(@"%p %p %p",str,mut1,str2);
}
//log
str:0x100001040 
mut1:0x1007385f0 
str2:0x100001040
```

可以看到`str`和`str2`地址一样，没有重新复制出来一份，`mut1`地址和`str`不一致，是深拷贝，重新拷贝了一份。

我们把字符串换成其他常用的数组

```
void test2(){
	NSArray *array = @[@"123",@"123",@"123",@"123",@"123",@"123",@"123"];
	NSMutableArray *mut =[array mutableCopy];
	NSString *array2 = [array copy];
	NSLog(@"\n%p \n%p\n%p",array,mut,array2);
}
//log
0x102840800 
0x1028408a0
0x102840800

void test3(){
	NSArray *array = [@[@"123",@"123",@"123",@"123",@"123",@"123",@"123"] mutableCopy];
	NSMutableArray *mut =[array mutableCopy];
	NSString *array2 = [array copy];
	NSLog(@"\n%p \n%p\n%p",array,mut,array2);
}
//log
0x102808720 
0x1028088a0
0x1028089a0
```

从上面可以总结看出来，不变数组拷贝出来不变数组，地址不改变，拷贝出来可变数组地址改变，可变数组拷贝出来不可变数组和可变数组，地址会改变。

我们再换成其他的常用的字典

```
void test4(){
	NSDictionary *item = @{@"key":@"value"};
	NSMutableDictionary *mut =[item mutableCopy];
	NSDictionary *item2 = [item copy];
	NSLog(@"\n%p \n%p\n%p",item,mut,item2);
}

//log
0x1007789c0 
0x100779190
0x1007789c0

void test5(){
	NSDictionary *item = [@{@"key":@"value"}mutableCopy];
	NSMutableDictionary *mut =[item mutableCopy];
	NSDictionary *item2 = [item copy];
	NSLog(@"\n%p \n%p\n%p",item,mut,item2);
}
//log

0x1007041d0 
0x1007042b0
0x1007043a0
```

从上面可以总结看出来，不变字典拷贝出来不变字典，地址不改变，拷贝出来可变字典地址改变，可变字典拷贝出来不可变字典和可变字典，地址会改变。

由这几个看出来，总结出来下表

|类型|copy|mutableCopy|
|:-:|:-:|:-:|
|NSString|浅拷贝|深拷贝|
|NSMutableString|浅拷贝|深拷贝|
|NSArray|浅拷贝|深拷贝|
|NSMutableArray|深拷贝|深拷贝|
|NSDictionary|浅拷贝|深拷贝|
|NSMutableDictionary|深拷贝|深拷贝|

#### 自定义对象实现协议NSCoping
自定义的对象使用copy呢？系统的已经实现了，我们自定义的需要自己去实现，自定义的类继承`NSCopying`

```
@protocol NSCopying

- (id)copyWithZone:(nullable NSZone *)zone;

@end

@protocol NSMutableCopying

- (id)mutableCopyWithZone:(nullable NSZone *)zone;

@end

```

看到`NSCopying`和`NSMutableCopying`这两个协议，对于自定义的可变对象，其实没什么意义，本来自定义的对象的属性，基本都是可变的，所以只需要实现`NSCopying`协议就好了。

```
@interface FYPerson : NSObject
@property (nonatomic,assign) int age;
@property (nonatomic,assign) int level;

@end

@interface FYPerson()<NSCopying>
@end

@implementation FYPerson
-(instancetype)copyWithZone:(NSZone *)zone{
	FYPerson *p=[[FYPerson alloc]init];
	p.age = self.age;
	p.level = self.level;
	return p;
}

@end


FYPerson *p =[[FYPerson alloc]init];
p.age = 10;
p.level = 11;
FYPerson *p2 =[p copy];
NSLog(@"%d %d",p2.age,p2.level);
//log
10 11
```

自己实现了`NSCoping`协议完成了对对象的深拷贝，成功将对象的属性复制过去了，当属性多了怎么办？我们可以利用`runtime`实现一个一劳永逸的方案。

然后将`copyWithZone`利用`runtime`遍历所有的成员变量，将所有的变量都赋值，当变量多的时候，这里也不用修改。

```
@implementation NSObject (add)
-(instancetype)copyWithZone:(NSZone *)zone{
    Class cls = [self class];
    NSObject * p=[cls new];
    //成员变量个数
    unsigned int count;
    //赋值成员变量数组
    Ivar *ivars = class_copyIvarList(self.class, &count);
    //遍历数组
    for (int i = 0; i < count; i ++) {
        Ivar var = ivars[i];
        //获取成员变量名字
        const char * name = ivar_getName(var);
        if (name != nil) {
            NSString *v = [NSString stringWithUTF8String:name];
            id value = [self valueForKey:v];
            //给新的对象赋值
            if (value != NULL) {
                [p setValue:value forKey:v];
            }
        }
    }
    free(ivars);
    return p;
}
@end

FYPerson *p =[[FYPerson alloc]init];
p.age = 10;
p.level = 11;
p.name = @"xiaowang";
FYPerson *p2 =[p copy];
NSLog(@"%d %d %@",p2.age,p2.level,p2.name);
		
//log
10 
11 
xiaowang
```

根据启动顺序，类别的方法在类的方法加载后边，类别中的方法会覆盖类的方法，所以
在基类`NSObject`在类别中重写了`-(instancetype)copyWithZone:(NSZone *)zone`方法，子类就不用重写了。达成了一劳永逸的方案。


### 引用计数原理
摘自[百度百科](https://baike.baidu.com/item/%E5%BC%95%E7%94%A8%E8%AE%A1%E6%95%B0/10205507?fr=aladdin)

> 引用计数是计算机编程语言中的一种内存管理技术，是指将资源（可以是对象、内存或磁盘空间等等）的被引用次数保存起来，当被引用次数变为零时就将其释放的过程。使用引用计数技术可以实现自动资源管理的目的。同时引用计数还可以指使用引用计数技术回收未使用资源的垃圾回收算法

在iOS中，使用引用计数来管理`OC`对象内存，一个新创建的OC对象的引用计数默认是1，当引用计数减为0，`OC`对象就会销毁，释放其他内存空间，调用`retain`会让`OC`对象的引用计数+1，调用`release`会让`OC`对象的引用计数-1。
当调用`alloc、new、copy、mutableCopy`方法返回一个对象，在不需要这个对象时，要调用`release`或者`autorelease`来释放它，想拥有某个对象，就让他的引用计数+1，不再拥有某个对象，就让他引用计数-1.

在MRC中我们经常都是这样子使用的

```
FYPerson *p=[[FYPerson alloc]init];
FYPerson *p2 =[p retain];
//code here
[p release];
[p2 release];
```

但是在ARC中是系统帮我们做了自动引用计数，不用开发者做很多繁琐的事情了，我们就探究下引用计数是怎么实现的。


引用计数存储在`isa`指针中的`extra_rc`，存储值大于这个范围的时候，则`bits.has_sidetable_rc=1`然后将剩余的`RetainCount`存储到全局的`table`，`key`是`self`对应的值。

`Retain`的`runtime`源码查找函数路径`objc_object::retain()`->`objc_object::rootRetain()`->`objc_object::rootRetain(bool, bool)`

```
//大概率x==1 提高读取指令的效率
#define fastpath(x) (__builtin_expect(bool(x), 1))
//大概率x==0 提高读取指令的效率
#define slowpath(x) (__builtin_expect(bool(x), 0))


//引用计数+1
//tryRetain 尝试+1
//handleOverflow 是否覆盖
ALWAYS_INLINE id  objc_object::rootRetain(bool tryRetain, bool handleOverflow)
{
	//优化的指针 返回this
    if (isTaggedPointer()) return (id)this;

    bool sideTableLocked = false;
    bool transcribeToSideTable = false;

    isa_t oldisa;
    isa_t newisa;

    do {
        transcribeToSideTable = false;
		//old bits
        oldisa = LoadExclusive(&isa.bits);
        newisa = oldisa;
		//使用联合体技术
        if (slowpath(!newisa.nonpointer)) {
            ClearExclusive(&isa.bits);//nothing
            if (!tryRetain && sideTableLocked) sidetable_unlock();//解锁
            if (tryRetain) return sidetable_tryRetain() ? (id)this : nil;
			else return sidetable_retain();////sidetable 引用计数+1
        }
        // don't check newisa.fast_rr; we already called any RR overrides
		//不尝试retain 和 正在销毁 什么都不做 返回 nil
        if (slowpath(tryRetain && newisa.deallocating)) {
            ClearExclusive(&isa.bits);
            if (!tryRetain && sideTableLocked) sidetable_unlock();
            return nil;
        }
        uintptr_t carry;
		//引用计数+1 (bits.extra_rc++;)
        newisa.bits = addc(newisa.bits, RC_ONE, 0, &carry);  // extra_rc++

        if (slowpath(carry)) {
            // newisa.extra_rc++ 溢出处理
            if (!handleOverflow) {
                ClearExclusive(&isa.bits);
                return rootRetain_overflow(tryRetain);
            }
			//为拷贝到side table 做准备
            if (!tryRetain && !sideTableLocked) sidetable_lock();
            sideTableLocked = true;
            transcribeToSideTable = true;
            newisa.extra_rc = RC_HALF;
            newisa.has_sidetable_rc = true;
        }
    } while (slowpath(!StoreExclusive(&isa.bits, oldisa.bits, newisa.bits)));

    if (slowpath(transcribeToSideTable)) {
		//拷贝 平外一半的 引用计数到 side table
        sidetable_addExtraRC_nolock(RC_HALF);
    }

    if (slowpath(!tryRetain && sideTableLocked)) sidetable_unlock();
    return (id)this;
}

//sidetable 引用计数+1
id objc_object::sidetable_retain()
{
#if SUPPORT_NONPOINTER_ISA
    assert(!isa.nonpointer);
#endif
	//取出table key=this
    SideTable& table = SideTables()[this];
    
    table.lock();
    size_t& refcntStorage = table.refcnts[this];
    if (! (refcntStorage & SIDE_TABLE_RC_PINNED)) {
        refcntStorage += SIDE_TABLE_RC_ONE;
    }
    table.unlock();

    return (id)this;
}
```

引用计数+1，判断了需要是指针没有优化和`isa`有没有使用的联合体技术，然后将判断是否溢出，溢出的话，将`extra_rc`的值复制到`side table`中，设置参数`isa->has_sidetable_rc=true`。

引用计数-1，在`runtime`源码中查找路径是`objc_object::release()`->`objc_object::rootRelease()`->`objc_object::rootRelease(bool performDealloc, bool handleUnderflow)`,我们进入到函数内部

```
ALWAYS_INLINE bool  objc_object::rootRelease(bool performDealloc, bool handleUnderflow)
{
    if (isTaggedPointer()) return false;//指针优化的不存在计数器

    bool sideTableLocked = false;

    isa_t oldisa;
    isa_t newisa;

 retry:
    do {//isa
        oldisa = LoadExclusive(&isa.bits);
        newisa = oldisa;
        if (slowpath(!newisa.nonpointer)) {
            ClearExclusive(&isa.bits);
            if (sideTableLocked) sidetable_unlock();
			//side table -1
            return sidetable_release(performDealloc);
        }
        uintptr_t carry;
        newisa.bits = subc(newisa.bits, RC_ONE, 0, &carry);  // extra_rc--
        if (slowpath(carry)) {
            // don't ClearExclusive()
            goto underflow;
        }
    } while (slowpath(!StoreReleaseExclusive(&isa.bits, 
                                             oldisa.bits, newisa.bits)));

    if (slowpath(sideTableLocked)) sidetable_unlock();
    return false;

 underflow:
    newisa = oldisa;

    if (slowpath(newisa.has_sidetable_rc)) {
        if (!handleUnderflow) {
            ClearExclusive(&isa.bits);
            return rootRelease_underflow(performDealloc);
        }

        if (!sideTableLocked) {
            ClearExclusive(&isa.bits);
            sidetable_lock();
            sideTableLocked = true;
            goto retry;
        }

		//side table 引用计数-1
        size_t borrowed = sidetable_subExtraRC_nolock(RC_HALF);

        if (borrowed > 0) {
            newisa.extra_rc = borrowed - 1;  // redo the original decrement too
            bool stored = StoreReleaseExclusive(&isa.bits, 
                                                oldisa.bits, newisa.bits);
            if (!stored) {
                isa_t oldisa2 = LoadExclusive(&isa.bits);
                isa_t newisa2 = oldisa2;
                if (newisa2.nonpointer) {
                    uintptr_t overflow;
                    newisa2.bits = 
                        addc(newisa2.bits, RC_ONE * (borrowed-1), 0, &overflow);
                    if (!overflow) {
                        stored = StoreReleaseExclusive(&isa.bits, oldisa2.bits, 
                                                       newisa2.bits);
                    }
                }
            }

            if (!stored) {
                // Inline update failed.
                // Put the retains back in the side table.
                sidetable_addExtraRC_nolock(borrowed);
                goto retry;
            }

            sidetable_unlock();
            return false;
        }
        else {
            // Side table is empty after all. Fall-through to the dealloc path.
        }
    }

	//真正的销毁

    if (slowpath(newisa.deallocating)) {
        ClearExclusive(&isa.bits);
        if (sideTableLocked) sidetable_unlock();
        return overrelease_error();
        // does not actually return
    }
	//设置正在销毁
    newisa.deallocating = true;
    if (!StoreExclusive(&isa.bits, oldisa.bits, newisa.bits)) goto retry;

    if (slowpath(sideTableLocked)) sidetable_unlock();

    __sync_synchronize();
    if (performDealloc) {
		//销毁
        ((void(*)(objc_object *, SEL))objc_msgSend)(this, SEL_dealloc);
    }
    return true;
}
```
看了上边了解到引用计数分两部分，`extra_rc`和`side table`，探究一下
`rootRetainCount()`的实现

```
inline uintptr_t  objc_object::rootRetainCount()
{
	//优化指针 直接返回
    if (isTaggedPointer()) return (uintptr_t)this;
//没优化则 到SideTable 读取
    sidetable_lock();
	//isa指针
    isa_t bits = LoadExclusive(&isa.bits);
    ClearExclusive(&isa.bits);//啥都没做
    if (bits.nonpointer) {//使用联合体存储更多的数据 
        uintptr_t rc = 1 + bits.extra_rc;//计数数量
        if (bits.has_sidetable_rc) {//当大过于 联合体存储的值 则另外在SideTable读取数据
	//读取table的值 相加
            rc += sidetable_getExtraRC_nolock();
        }
        sidetable_unlock();
        return rc;
    }

    sidetable_unlock();
	//在sidetable 中存储的count
    return sidetable_retainCount();
}
```
当是存储小数据的时候，指针优化，则直接返回`self`,大数据的话，则`table`加锁，
`class`优化的之后[使用联合体存储更多的数据](https://juejin.im/post/5d2bcf3df265da1b67213d69),`class`没有优化则直接去`sizedable`读取数据。
优化了则在`sidetable_getExtraRC_nolock()`读取数据

```
//使用联合体
size_t  objc_object::sidetable_getExtraRC_nolock()
{
	//不是联合体技术 则报错
    assert(isa.nonpointer);
	//key是 this，存储了每个对象的table
    SideTable& table = SideTables()[this];
	//找到 it 否则返回0
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it == table.refcnts.end()) return 0;
    else return it->second >> SIDE_TABLE_RC_SHIFT;
}
```
没有优化的是直接读取

```
//未使用联合体的情况，
uintptr_t objc_object::sidetable_retainCount()
{//没有联合体存储的计数器则直接在table中取出来
    SideTable& table = SideTables()[this];
    size_t refcnt_result = 1;
    table.lock();
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it != table.refcnts.end()) {
        refcnt_result += it->second >> SIDE_TABLE_RC_SHIFT;
    }
    table.unlock();
    return refcnt_result;
}
```

### weak指针原理

当一个对象要销毁的时候会调用`dealloc`,调用轨迹是`dealloc`->`_objc_rootDealloc`->`object_dispose`->`objc_destructInstance`->`free`
我们进入到`objc_destructInstance`内部

```
void *objc_destructInstance(id obj) 
{
    if (obj) {
        // Read all of the flags at once for performance.
		//c++析构函数
        bool cxx = obj->hasCxxDtor();
		//关联函数
        bool assoc = obj->hasAssociatedObjects();

        // This order is important.
        if (cxx) object_cxxDestruct(obj);
        if (assoc) _object_remove_assocations(obj);
        obj->clearDeallocating();
    }
    return obj;
}
```
销毁了c++析构函数和关联函数最后进入到`clearDeallocating`，我们进入到函数内部

```
//正在清除side table 和weakly referenced
inline void 
objc_object::clearDeallocating()
{
    if (slowpath(!isa.nonpointer)) {
        // Slow path for raw pointer isa.
		//释放weak
        sidetable_clearDeallocating();
    }
    else if (slowpath(isa.weakly_referenced  ||  isa.has_sidetable_rc)) {
        // Slow path for non-pointer isa with weak refs and/or side table data.
		//释放weak 和引用计数
        clearDeallocating_slow();
    }
    assert(!sidetable_present());
}
```
最终调用了`sidetable_clearDeallocating`和`clearDeallocating_slow`实现销毁`weak`和引用计数`side table`。

```
NEVER_INLINE void
objc_object::clearDeallocating_slow()
{
    assert(isa.nonpointer  &&  (isa.weakly_referenced || isa.has_sidetable_rc));

    SideTable& table = SideTables()[this];
    table.lock();
	//清除weak
    if (isa.weakly_referenced) {
		//table.weak_table 弱引用表
        weak_clear_no_lock(&table.weak_table, (id)this);
    }
	//引用计数
    if (isa.has_sidetable_rc) {
		//擦除 this
        table.refcnts.erase(this);
    }
    table.unlock();
}
```
其实`weak`修饰的对象会存储在全局的`SideTable`，当对象销毁的时候会在`SideTable`进行查找，时候有`weak`对象，有的话则进行销毁。

### Autoreleasepool 原理
`Autoreleasepool`中文名自动释放池，里边装着一些变量，当池子不需要（销毁）的时候，`release`里边的对象(引用计数-1)。
我们将下边的代码转化成c++

```
@autoreleasepool {
		FYPerson *p = [[FYPerson alloc]init];
	}
```
使用`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -f  main.m`
转成c++

```
 /* @autoreleasepool */ {
  __AtAutoreleasePool __autoreleasepool;
  FYPerson *p = ((FYPerson *(*)(id, SEL))(void *)objc_msgSend)((id)((FYPerson *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("FYPerson"), sel_registerName("alloc")), sel_registerName("init"));

 }
```
`__AtAutoreleasePool`是一个结构体

```
struct __AtAutoreleasePool {
	__AtAutoreleasePool() {//构造函数 生成结构体变量的时候调用
		atautoreleasepoolobj = objc_autoreleasePoolPush();
	}
	~__AtAutoreleasePool() {//析构函数 销毁的时候调用
		objc_autoreleasePoolPop(atautoreleasepoolobj);
	}
	void * atautoreleasepoolobj;
};
```

然后将上边的代码和c++整合到一起就是这样子

```
{
    __AtAutoreleasePool pool = objc_autoreleasePoolPush();
    FYPerson *p = [[FYPerson alloc]init];
    objc_autoreleasePoolPop(pool)
}
```

在进入大括号生成一个释放池，离开大括号则释放释放池，我们再看一下释放函数是怎么工作的,在`runtime`源码中`NSObject.mm 1848 行`

```
void objc_autoreleasePoolPop(void *ctxt)
{
    AutoreleasePoolPage::pop(ctxt);
}
```

`pop`实现了`AutoreleasePoolPage`中的对象的释放，想了解怎么释放的可以研究下源码`runtime NSObject.mm 1063行`。


其实`AutoreleasePool`是`AutoreleasePoolPage`来管理的，`AutoreleasePoolpage`结构如下

```
class AutoreleasePoolPage {
    magic_t const magic;
    id *next;//下一个存放aotoreleass对象的地址
    pthread_t const thread;//线程
    AutoreleasePoolPage * const parent; //父节点
    AutoreleasePoolPage *child;//子节点
    uint32_t const depth;//深度
    uint32_t hiwat;
}
```

`AutoreleasePoolPage`在初始化在`autoreleaseNewPage`申请了`4096`字节除了自己变量的空间，`AutoreleasePoolPage`是一个`C++`实现的类
- 内部使用`id *next`指向了栈顶最新`add`进来的`autorelease`对象的下一个位置
- 一个`AutoreleasePoolPage`的空间被占满时，会新建一个`AutoreleasePoolPage`对象，连接链表，后来的`autorelease`对象在新的`page`加入
- `AutoreleasePoolPage`每个对象会开辟4096字节内存（也就是虚拟内存一页的大小），除了上面的实例变量所占空间，剩下的空间全部用来储存`autorelease`对象的地址
- `AutoreleasePool`是按线程一一对应的（结构中的`thread`指针指向当前线程）
- `AutoreleasePool`并没有单独的结构，而是由若干个`AutoreleasePoolPage`以双向链表的形式组合而成（分别对应结构中的`parent`指针和`child`指针）


其他的都是自动释放池的其他对象的指针，我们使用`_objc_autoreleasePoolPrint()`可以查看释放池的存储内容

```
extern void _objc_autoreleasePoolPrint(void);
int main(int argc, const char * argv[]) {
	@autoreleasepool {//r1 = push()

		FYPerson *p = [[FYPerson alloc]init];
		_objc_autoreleasePoolPrint();
		printf("\n--------------\n");
	}//pop(r1)
	return 0;
}
//log

objc[23958]: ##############
objc[23958]: AUTORELEASE POOLS for thread 0x1000aa5c0
objc[23958]: 3 releases pending.
objc[23958]: [0x101000000]  ................  PAGE  (hot) (cold)
objc[23958]: [0x101000038]  ################  POOL 0x101000038
objc[23958]: [0x101000040]       0x10050cfa0  FYPerson
objc[23958]: [0x101000048]       0x10050cdb0  FYPerson
objc[23958]: ##############

--------------
```

可以看到存储了`3 releases pending`一个对象，而且大小都8字节。再看一个复杂的,自动释放池嵌套自动释放池

```
int main(int argc, const char * argv[]) {
	@autoreleasepool {//r1 = push()

		FYPerson *p = [[[FYPerson alloc]init] autorelease];
		FYPerson *p2 = [[[FYPerson alloc]init] autorelease];
		@autoreleasepool {//r1 = push()
			
			FYPerson *p3 = [[[FYPerson alloc]init] autorelease];
			FYPerson *p4 = [[[FYPerson alloc]init] autorelease];
			
			_objc_autoreleasePoolPrint();
			printf("\n--------------\n");
		}//pop(r1)
	}//pop(r1)
	return 0;
}
//log
objc[24025]: ##############
objc[24025]: AUTORELEASE POOLS for thread 0x1000aa5c0
objc[24025]: 6 releases pending.
objc[24025]: [0x100803000]  ................  PAGE  (hot) (cold)
objc[24025]: [0x100803038]  ################  POOL 0x100803038
objc[24025]: [0x100803040]       0x100721580  FYPerson
objc[24025]: [0x100803048]       0x100721b10  FYPerson
objc[24025]: [0x100803050]  ################  POOL 0x100803050
objc[24025]: [0x100803058]       0x100721390  FYPerson
objc[24025]: [0x100803060]       0x100717620  FYPerson
objc[24025]: ##############
```
看到了2个`POOL`和四个`FYPerson`对象，一共是6个对象，当出了释放池会执行`release`。

当无优化的指针调用`autorelease`其实是调用了`AutoreleasePoolPage::autorelease((id)this)`->`autoreleaseFast(obj)`

```
   static inline id *autoreleaseFast(id obj)
    {
        AutoreleasePoolPage *page = hotPage();
        //当有分页而且分页没有满就添加
        if (page && !page->full()) {
            return page->add(obj);
        } else if (page) {
            //满则新建一个page进行添加obj和设置hotpage
            return autoreleaseFullPage(obj, page);
        } else {
            //没有page则新建page进行添加
            return autoreleaseNoPage(obj);
        }
    }
```

在`MRC`中
`autorealease`修饰的是的对象在没有外部添加到自动释放池的时候，在`runloop`循环的时候会销毁

```

typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry = (1UL << 0),
    kCFRunLoopBeforeTimers = (1UL << 1),
    kCFRunLoopBeforeSources = (1UL << 2),
    kCFRunLoopBeforeWaiting = (1UL << 5),
    kCFRunLoopAfterWaiting = (1UL << 6),
    kCFRunLoopExit = (1UL << 7),
    kCFRunLoopAllActivities = 0x0FFFFFFFU
};

//activities = 0xa0转化成二进制 0b101 0000
系统监听了mainRunloop 的 kCFRunLoopBeforeWaiting 和kCFRunLoopExit两种状态来更新autorelease的数据
//回调函数是 _wrapRunLoopWithAutoreleasePoolHandler

"<CFRunLoopObserver 0x600002538320 [0x10ce45ae8]>{valid = Yes, activities = 0xa0, 
repeats = Yes, order = 2147483647, 
callout = _wrapRunLoopWithAutoreleasePoolHandler (0x10f94087d), 
context = <CFArray 0x600001a373f0 [0x10ce45ae8]>{type = mutable-small, count = 1, 
values = (\n\t0 : <0x7fb6dc004058>\n)}}"
```

`activities = 0xa0`转化成二进制 `0b101 0000`
系统监听了`mainRunloop` 的 `kCFRunLoopBeforeWaiting` 和`kCFRunLoopExit`两种状态来更新`autorelease`的数据
回调函数是 `_wrapRunLoopWithAutoreleasePoolHandler`。

```
void test(){
    FYPerson *p =[[FYPerson alloc]init];
}
```

`p`对象在某次循环中`push`，在循环到`kCFRunLoopBeforeWaiting`进行一次`pop`，则上次循环的`autolease`对象没有其他对象`retain`的进行释放。并不是出了`test()`立马释放。

在ARC中则执行完毕`test()`会马上释放。
### 总结
- 当重复创建对象或者代码段不容易管理生命周期使用自动释放池是不错的选择。
- 存在在全局的`SideTable`中weak修饰的对象会在`dealloc`函数执行过程中检测或销毁该对象。
- 可变对象拷贝一定会生成已新对象，不可变对象拷贝成不可变对象则是引用计数+1。
- 优化的指向对象的指针，不用走`objc_msgSend()`的消息流程从而提高性能。
- `CADisplayLink`和`Timer`本质是加到`loop`循环当中，依附于循环，没有`runloop`，则不能正确执行，使用`runloop`需要注意循环引用和`runloop`所在的线程的释放问题。

### 参考资料
- [黑幕背后的Autorelease
](http://blog.sunnyxx.com/2014/10/15/behind-autorelease/)
- 小码哥视频
- iOS和OS多线程与内存管理
- iOS和macOS性能优化
### 资料下载
- [学习资料下载git](https://github.com/ifgyong/iOSDataFactory)
- [demo code git](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码git](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

---
最怕一生碌碌无为，还安慰自己平凡可贵。


广告时间

![](../images/0.png)