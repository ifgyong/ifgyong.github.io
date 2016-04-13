title: iOS线程之NSOperation
date: 2016-03-31 14:47:47
tags:
- iOS
- iOS高级
categories: iOS
---

前篇文章已经讲了GCD了，那么这两者有什么区别？
### GCD VS   NSOperation 
>"NSOperationQueue predates Grand Central Dispatch and on iOS it doesn't use GCD to execute operations (this is different on Mac OS X). It uses regular background threads which have a little more overhead than GCD dispatch queues.
On the other hand, NSOperationQueue gives you a lot more control over how your operations are executed. You can define dependencies between individual operations for example, which isn't possible with plain GCD queues. It is also possible to cancel operations that have been enqueued in an NSOperationQueue (as far as the operations support it). When you enqueue a block in a GCD dispatch queue, it will definitely be executed at some point.
To sum it up, NSOperationQueue can be more suitable for long-running operations that may need to be cancelled or have complex dependencies. GCD dispatch queues are better for short tasks that should have minimum performance and memory overhead."

简单来说就是GCD偏底层点，性能好，依赖关系少，并发耗费资源少。
NSOperation可观察状态，性能也不错，处理事务更简单操作。

对于这两种都熟练运用的人来说，无所谓了，APP大多数事务这两者都能完美解决。至于代码用哪个这个取决于你的兴趣了。

下面详细说一下NSOperation

```
@interface NSOperation : NSObject {

- (void)start; //开始执行 默认是同步执行的
- (void)main; //主任务的函数 

@property (readonly, getter=isCancelled) BOOL cancelled; //是否取消
- (void)cancel; //取消任务

@property (readonly, getter=isExecuting) BOOL executing;//是否正在执行
@property (readonly, getter=isFinished) BOOL finished; //是否完成
@property (readonly, getter=isConcurrent) BOOL concurrent; // To be deprecated; use and override 'asynchronous' below 是否并行
@property (readonly, getter=isAsynchronous) BOOL asynchronous NS_AVAILABLE(10_8, 7_0); //是否异步
@property (readonly, getter=isReady) BOOL ready; //是否正在等待

- (void)addDependency:(NSOperation *)op; //添加依赖
- (void)removeDependency:(NSOperation *)op; //删除依赖关系

@property (readonly, copy) NSArray<NSOperation *> *dependencies; //所有依赖关系的数组

typedef NS_ENUM(NSInteger, NSOperationQueuePriority) {
//队列优先级  优先级高的先执行 一般设置为0 即 NSOperationQueuePriorityNormal。
 NSOperationQueuePriorityVeryLow = -8L,
 NSOperationQueuePriorityLow = -4L,
 NSOperationQueuePriorityNormal = 0,
 NSOperationQueuePriorityHigh = 4,
 NSOperationQueuePriorityVeryHigh = 8
};

@property NSOperationQueuePriority queuePriority;//队列优先级

@property (nullable, copy) void (^completionBlock)(void)  NS_AVAILABLE(10_6, 4_0);//完成时候执行的代码块
//等待直到完成
- (void)waitUntilFinished NS_AVAILABLE(10_6, 4_0);
//线程优先级
@property double threadPriority NS_DEPRECATED(10_6, 10_10, 4_0, 8_0);

@property NSQualityOfService qualityOfService NS_AVAILABLE(10_10, 8_0);
NSQualityOfService 的几个枚举值：
  NSQualityOfServiceUserInteractive：最高优先级，主要用于提供交互UI的操作，比如处理点击事件，绘制图像到屏幕上
  NSQualityOfServiceUserInitiated：次高优先级，主要用于执行需要立即返回的任务
  NSQualityOfServiceDefault：默认优先级，当没有设置优先级的时候，线程默认优先级
  NSQualityOfServiceUtility：普通优先级，主要用于不需要立即返回的任务
  NSQualityOfServiceBackground：后台优先级，用于完全不紧急的任务


//名字
@property (nullable, copy) NSString *name NS_AVAILABLE(10_10, 8_0);
```
### NSBlockOperation 
```
- (void)print{
    NSLog(@"线程info : %@",[NSThread currentThread]);
}
- (void)test4{
    NSBlockOperation * blop = [[NSBlockOperation alloc]init];
    [blop addExecutionBlock:^{//添加同时执行的task
        NSLog(@"1 start");
        [self print];
        sleep(2);
        
        NSLog(@"1 end");
    }];
    [blop addExecutionBlock:^{ //添加同时执行的task
        NSLog(@"2 start");
        [self print];
        sleep(4);
        
        NSLog(@"2 end");
    }];
    [blop addExecutionBlock:^{ //添加同时执行的task
        NSLog(@"3 start");
        [self print];
        sleep(1);
        
        NSLog(@"3 end");
    }];
    [blop setCompletionBlock:^{ //添加同时执行的task
        NSLog(@"blop end");
    }];
    
    [blop start];
}
输出：
**2016-03-29 16:47:44.857 GCD_Demo[17555:562249] 1 start**
**2016-03-29 16:47:44.857 GCD_Demo[17555:562287] 3 start**
**2016-03-29 16:47:44.857 GCD_Demo[17555:562288] 2 start**
**2016-03-29 16:47:44.857 GCD_Demo[17555:562249] ****线程****info : <NSThread: 0x7fea68408b30>{number = 1, name = main}**
**2016-03-29 16:47:44.857 GCD_Demo[17555:562288] ****线程****info : <NSThread: 0x7fea6861fb30>{number = 3, name = (null)}**
**2016-03-29 16:47:44.857 GCD_Demo[17555:562287] ****线程****info : <NSThread: 0x7fea69300470>{number = 2, name = (null)}**
**2016-03-29 16:47:45.922 GCD_Demo[17555:562287] 3 end**
**2016-03-29 16:47:46.858 GCD_Demo[17555:562249] 1 end**
**2016-03-29 16:47:48.928 GCD_Demo[17555:562288] 2 end**
**2016-03-29 16:47:48.929 GCD_Demo[17555:562288] blop end**
```
可以看出来，NSBlockOperation当任务是1的时候在main线程中执行，任务大于1的时候，其他的个自独自开了线程，而且互不影响。

### 依赖关系
```
- (void)print{
    NSLog(@"线程info : %@",[NSThread currentThread]);
}
- (void)test4{
    NSBlockOperation * blop = [[NSBlockOperation alloc]init];
    [blop addExecutionBlock:^{
        NSLog(@"blop1_1 start");
        [self print];
        sleep(2);
        NSLog(@"blop1_1 end");
    }];
    [blop addExecutionBlock:^{
        NSLog(@"blop1_2 start");
        [self print];
        sleep(4);
        NSLog(@"blop1_2 end");
    }];
    NSLog(@"blop will start");
    [blop start];
    NSLog(@"blop did start");
    
    NSBlockOperation * blop2 =[NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"blop2 start");
        [self print];
        sleep(2);
        NSLog(@"blop2 end");
    }];
   // [blop2 addDependency:blop];//blop2 依赖blop 就是blopExecutionBlock 执行完之后再执行blop2的任务【blop2 执行task和blop 的CompletionBlock基本是同时执行的】
    [blop2 start];
输出：
**2016-03-29 17:06:53.217 GCD_Demo[17806:574416] blop will start**
**2016-03-29 17:06:53.217 GCD_Demo[17806:574416] blop1_1 start**
**2016-03-29 17:06:53.217 GCD_Demo[17806:574455] blop1_2 start**
**2016-03-29 17:06:53.217 GCD_Demo[17806:574416] ****线程****info : <NSThread: 0x7f839a004ff0>{number = 1, name = main}**
**2016-03-29 17:06:53.218 GCD_Demo[17806:574455] ****线程****info : <NSThread: 0x7f8398416d80>{number = 2, name = (null)}**
**2016-03-29 17:06:55.219 GCD_Demo[17806:574416] blop1_1 end**
**2016-03-29 17:06:57.272 GCD_Demo[17806:574455] blop1_2 end**
**2016-03-29 17:06:57.272 GCD_Demo[17806:574416] blop did start**
**2016-03-29 17:06:57.273 GCD_Demo[17806:574416] blop2 start**
**2016-03-29 17:06:57.273 GCD_Demo[17806:574416] ****线程****info : <NSThread: 0x7f839a004ff0>{number = 1, name = main}**
**2016-03-29 17:06:59.274 GCD_Demo[17806:574416] blop2 end**

```
从输出的信息可以看出来，block是同步执行的，虽然多任务是多线程，但是主线程还是在阻塞中，只有上一个所有 task 执行完的时候，才会执行下边的task。所以在这里依赖关系不那么重要了，注释掉运行结果也一样的。
###   NSInvocationOperation
```
NSInvocationOperation 是NSOperation的子类，负责实现operation的SEL方法。
这样子operation就可以start的时候执行一些函数了。
在swift中已经废弃
看文档：
NS_SWIFT_UNAVAILABLE("NSInvocation and related APIs not available")
```

### NSOperationQueue 
```
//添加操作
- (void)addOperation:(NSOperation *)op;
//添加操作数组 在完成操作的时候
- (void)addOperations:(NSArray<NSOperation *> *)ops waitUntilFinished:(BOOL)wait NS_AVAILABLE(10_6, 4_0);
//添加携带代码块的operation
- (void)addOperationWithBlock:(void (^)(void))block NS_AVAILABLE(10_6, 4_0);
//所有的操作 组成的数组 可读属性
@property (readonly, copy) NSArray<__kindof NSOperation *> *operations;
//操作个数
@property (readonly) NSUInteger operationCount NS_AVAILABLE(10_6, 4_0);
//设置最大并行的任务数 ps:operation 其实 一个operation可以同时开启几个线程的。
@property NSInteger maxConcurrentOperationCount;
//挂起
@property (getter=isSuspended) BOOL suspended;
//队列的名字
@property (nullable, copy) NSString *name NS_AVAILABLE(10_6, 4_0);
//优先级
@property NSQualityOfService qualityOfService NS_AVAILABLE(10_10, 8_0);
队列
@property (nullable, assign /* actually retain */) dispatch_queue_t underlyingQueue NS_AVAILABLE(10_10, 8_0);
//取消所有的操作
- (void)cancelAllOperations;
//等到他们的操作结束
- (void)waitUntilAllOperationsAreFinished;
//当前的队列
+ (nullable NSOperationQueue *)currentQueue NS_AVAILABLE(10_6, 4_0);
//主队列
+ (NSOperationQueue *)mainQueue NS_AVAILABLE(10_6, 4_0);

 
# 队列的例子
#队列中添加的operation都是在子线程中执行的。
- (void)print{
    NSLog(@"线程info : %@",[NSThread currentThread]);
}
- (void)op1{
     NSLog(@"op1 开始运行了");
     sleep(3);
     NSLog(@"op1 结束");
}

- (void)test5{
    NSInvocationOperation * op1 =[[NSInvocationOperation alloc]initWithTarget:self selector:@selector(op1) object:nil];
    NSOperationQueue * queue =[[NSOperationQueue alloc]init];
    [queue addOperation:op1]; //添加操作
    queue.maxConcurrentOperationCount = 1;//同时允许一个operation运行
    NSBlockOperation *block = [self test4];//任务块
    [queue addOperation:block];//添加任务块并运行

// sleep(2);  
   // [queue cancelAllOperations];
}
- (NSBlockOperation *)test4{
    NSBlockOperation * blop = [[NSBlockOperation alloc]init];
    [blop addExecutionBlock:^{
        NSLog(@"blop1_1 start");
        [self print];
        sleep(2);
        NSLog(@"blop1_1 end");
    }];
    [blop addExecutionBlock:^{
        NSLog(@"blop1_2 start");
        [self print];
        sleep(4);
        NSLog(@"blop1_2 end");
    }];
    return blop;
}
输出：
**2016-03-31 11:22:16.663 GCD_Demo[26038:889212] op1 ****开始运行了**
**2016-03-31 11:22:19.737 GCD_Demo[26038:889212] op1 ****结束**
**2016-03-31 11:22:19.738 GCD_Demo[26038:889213] blop1_1 start**
**2016-03-31 11:22:19.738 GCD_Demo[26038:889226] blop1_2 start**
**2016-03-31 11:22:19.738 GCD_Demo[26038:889213] ****线程****info : <NSThread: 0x7fea3061d110>{number = 2, name = (null)}**
**2016-03-31 11:22:19.738 GCD_Demo[26038:889226] ****线程****info : <NSThread: 0x7fea31800140>{number = 3, name = (null)}**
**2016-03-31 11:22:21.808 GCD_Demo[26038:889213] blop1_1 end**
**2016-03-31 11:22:23.784 GCD_Demo[26038:889226] blop1_2 end**
# 从输出的信息可以看出来，当设置最大的operation为1的时候，相当于这个队列同步运行了，不过这个同步的单位不是线程，而是operation。

当把这两句代码加到 test5最后边输出结果是：
**2016-03-31 11:28:59.267 GCD_Demo[26113:892737] op1 ****开始运行了**
**2016-03-31 11:29:02.341 GCD_Demo[26113:892737] op1 ****结束**
从输出结果得出：正在执行的Operation无法stop，正在ready的operation直接跳过start，执行complateBlock.状态由ready改为canceld。ps：注意看官方文档
`Canceling the operations does not automatically remove them from the queue or stop those that are currently executing.`
正在执行的不会从队列中删除也不会stop。
`For operations that are queued and waiting execution, the queue must still attempt to execute the operation before recognizing that it is canceled and moving it to the finished state. 
For operations that are already executing, the operation object itself must check for cancellation and stop what it is doing so that it can move to the finished state. 
In both cases, a finished (or canceled) operation is still given a chance to execute its completion block before it is removed from the queue.` 
正在队列中等待的operation执行的时候会检测是否被cancenld，如果状态是canceld，那么直接执行completion block 在它被队列删除的时候。
```
### 在子线程中耗时的操作完成了，那么该在主线程中更新UI
```
#将上面的test5 改成下面的代码
- (void)test5{
    NSInvocationOperation * op1 =[[NSInvocationOperation alloc]initWithTarget:self selector:@selector(op1) object:nil];
    NSOperationQueue * queue =[[NSOperationQueue alloc]init];
    [queue addOperation:op1];
    queue.maxConcurrentOperationCount = 3;//根据需要设置数量
    NSBlockOperation *block = [self test4];
    [queue addOperation:block];
//这句话一定要添加，这句话的意思等到所有的operation都完成了在执行后面的代码，
其实就是上面的操作执行到这里要等待他们直到他们都完成了。
#     [queue waitUntilAllOperationsAreFinished]; 
    NSBlockOperation * blockUpdateMainUI=[NSBlockOperation blockOperationWithBlock:^{
        NSLog(@"update UI");
    }];
    [[NSOperationQueue mainQueue] addOperation:blockUpdateMainUI];//在主队列中执行更新UI的操作
}
上面的代码 和GCD中的分组有些类似，但是 这个OperationQueue基本单位是operation而不是线程，一定要理解。
operation和线程的关系是 一个operation可能对应多个线程，也可能对应一个线程。
```
关于NSOperationQueue的了解和使用我想到的基本就这么多场景，后期有其他的场景再补充。
预告：下期节目是NSThread的介绍和使用。
ps:广告时间
- - -
有问题可以发我邮箱讨论共同交流技术。
fgyong@yeah.net