title: iOS线程之GCD初探
date: 2016-03-28 17:47:47
tags:
- iOS
- iOS高级
categories: iOS
---

简述：
       说道线程，离不开并行和串行，所谓并行，就是100赛跑，每个赛道就是一个线程，每个线程之间互不影响，同时都可以运行事件，就是10个赛道都可以有运动员跑步了，谁跑的慢或者跑的快，都不影响其他的人。串行就不一样了，串行是1个赛道10个运动员再跑接力赛，第一个跑到终点第二个在接着跑，依次类推，前边的不走，后边的也走不了的，所以串行上面的事件是一个一个运行的，同时只能是一个人再跑。

在iOS或者OS里面，一般用GCD就能吃处理较多的事务，下面就谈一下GCD的用法。

### 什么是GCD？
全称是Grand Central Dispatch，可译为“牛逼的中枢调度器”
纯C语言，提供了非常多强大的函数

### methodList info
```

//获取主线程 就是更新UI的线程
dispatch_queue_t dispatch_get_main_queue(void);

 //获取全局队列
dispatch_queue_t dispatch_get_global_queue( long identifier, unsigned long flags);

//创建一个队列 名字是label 属性可以写为NULL  
dispatch_queue_t dispatch_queue_create( const char *label dispatch_queue_attr_t attr);
dispatch_release(queue)//释放队列

//获取代码现在运行的queue
dispatch_queue_t dispatch_get_current_queue( void);

 //获取队列的名字
const char * dispatch_queue_get_label(dispatch_queue_t queue);

//异步把代码块block交给queue队列中处理
dispatch_async(dispatch_queue_t queue, dispatch_block_t block);

// 同步将block加入到queue中并且执行。
void dispatch_sync( dispatch_queue_t queue, dispatch_block_t block);

 //block 在指定时间在queue中执行
void dispatch_after( dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block);

 
//几个调度事件同事加入到queue中去，最好是全局队列才行。
void dispatch_apply( size_t iterations, dispatch_queue_t queue, void (^block)( size_t));

// block 是否执行过
void dispatch_once( dispatch_once_t *predicate, dispatch_block_t block);
 
//在分组group中的queue队列执行block
void dispatch_group_async( dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);

//创建线程分组
dispatch_group_t dispatch_group_create( void);

 //分组的计数+1
void dispatch_group_enter( dispatch_group_t group);

//分组计数 -1
void dispatch_group_leave( dispatch_group_t group);

// 当分组中的事务处理完了执行block
void dispatch_group_notify( dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);

//等待timeout时间后执行 group中的事务
long dispatch_group_wait( dispatch_group_t group, dispatch_time_t timeout);

 //并行状态下 queue前面的并行事务处理完成了在执行block，然后执行下边的并行代码
//比如 ABCDEF D事务等到ABC都完成了在执行EF事务的
void dispatch_barrier_async( dispatch_queue_t queue, dispatch_block_t block);

```
### 实战演练全局队列

```
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

dispatch_async(queue, ^{
        //异步执行
        dispatch_sync(dispatch_get_main_queue(), ^{
            //这里面更新UI
        });
    });
    dispatch_sync(queue, ^{
       //同步执行
    });
```
### 自定义队列
```
dispatch_queue_t queue = dispatch_queue_create("com.apple.fgyong", DISPATCH_QUEUE_SERIAL);
    //
//#define DISPATCH_QUEUE_SERIAL   同步队列
//#define DISPATCH_QUEUE_CONCURRENT 异步队列
    dispatch_async(queue, ^{
        NSLog(@"下载图片1=====%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        NSLog(@"下载图片2=====%@",[NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        NSLog(@"下载图片3=====%@",[NSThread currentThread]);
    });
    NSLog(@"main:%@",[NSThread mainThread]);
当queue属性为 DISPATCH_QUEUE_CONCURRENT输出：
**2016-03-28 16:53:25.848 GCD_Demo[12338:347984] ****下载图片****3=====<NSThread: 0x7fabda100250>{number = 4, name = (null)}**
**2016-03-28 16:53:25.848 GCD_Demo[12338:347982] ****下载图片****2=====<NSThread: 0x7fabda2008a0>{number = 3, name = (null)}**
**2016-03-28 16:53:25.848 GCD_Demo[12338:347937] main:<NSThread: 0x7fabd8c04ee0>{number = 1, name = main}**
**2016-03-28 16:53:25.848 GCD_Demo[12338:347981] ****下载图片****1=====<NSThread: 0x7fabd8c0a010>{number = 2, name = (null)}** 线程达到了4个
当queue属性为DISPATCH_QUEUE_SERIAL输出：
**2016-03-28 16:46:54.501 GCD_Demo[12272:344348] main:<NSThread: 0x7fd379704cf0>{number = 1, name = main}**
**2016-03-28 16:46:54.501 GCD_Demo[12272:344382] ****下载图片****1=====<NSThread: 0x7fd37971bda0>{number = 2, name = (null)}**
**2016-03-28 16:46:54.502 GCD_Demo[12272:344382] ****下载图片****2=====<NSThread: 0x7fd37971bda0>{number = 2, name = (null)}**
**2016-03-28 16:46:54.502 GCD_Demo[12272:344382] ****下载图片****3=====<NSThread: 0x7fd37971bda0>{number = 2, name = (null)}**
线程只有2个

 ```
### 多个异步线程问题
```
# 当ABC 3个异步线程，要求前两个个执行完再去执行后面的三个的时候例子：
     dispatch_queue_t queue = dispatch_queue_create("com.apple.fgyong", DISPATCH_QUEUE_CONCURRENT);

    dispatch_async(queue, ^{
        NSLog(@"queue1 begin");
        sleep(2);
        NSLog(@"queue1 end");
    });
    dispatch_async(queue, ^{
        NSLog(@"queue2 begin");
        sleep(2);
        NSLog(@"queue2 end");
    });
    dispatch_barrier_sync(queue, ^{
        NSLog(@"main:%@",[NSThread mainThread]);
    });
    dispatch_async(queue, ^{
        NSLog(@"queue3 begin");
        sleep(2);
        NSLog(@"queue3 end");
    });
输出：

**2016-03-28 17:01:01.319 GCD_Demo[12463:353702] queue2 begin**
**2016-03-28 17:01:01.319 GCD_Demo[12463:353703] queue1 begin**
**2016-03-28 17:01:03.324 GCD_Demo[12463:353703] queue1 end**
**2016-03-28 17:01:03.324 GCD_Demo[12463:353702] queue2 end**
**2016-03-28 17:01:03.325 GCD_Demo[12463:353657] main:<NSThread: 0x7f97ea604bf0>{number = 1, name = main}**
**2016-03-28 17:01:03.325 GCD_Demo[12463:353702] queue3 begin**
**2016-03-28 17:01:05.330 GCD_Demo[12463:353702] queue3 end**
```
### 线程分组
```
# 当多个任务同时进行的时候，也可以用group，ABCD任务进行完成的时候，最后在执行task。
 

  dispatch_queue_t queue = dispatch_queue_create("com.apple.fgyong", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task1 begin");
        sleep(2);
        NSLog(@"task1 end");
    });
    
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task2 begin");
        sleep(2);
        NSLog(@"task2 end");
    });
    dispatch_group_notify(group, queue, ^{
        NSLog(@"=================");
    });
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task3 begin");
        sleep(2);
        NSLog(@"task3 end");
    });
    
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task4 begin");
        sleep(2);
        NSLog(@"task4 end");
    });
输出：
**2016-03-28 17:08:45.002 GCD_Demo[12557:357162] task1 begin**
**2016-03-28 17:08:45.002 GCD_Demo[12557:357164] task4 begin**
**2016-03-28 17:08:45.002 GCD_Demo[12557:357161] task2 begin**
**2016-03-28 17:08:45.002 GCD_Demo[12557:357163] task3 begin**
**2016-03-28 17:08:47.005 GCD_Demo[12557:357162] task1 end**
**2016-03-28 17:08:47.005 GCD_Demo[12557:357163] task3 end**
**2016-03-28 17:08:47.005 GCD_Demo[12557:357164] task4 end**
**2016-03-28 17:08:47.005 GCD_Demo[12557:357161] task2 end**
**2016-03-28 17:08:47.006 GCD_Demo[12557:357161] =================**
一个组内的所有任务都进行完了才会执行task的函数。


# 分组多任务等待 ABCDEF ，ABCD执行5秒，5秒之后就执行EF任务，不管ABCD是否成功。

    dispatch_queue_t queue = dispatch_queue_create("com.apple.fgyong", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task1 begin");
        sleep(2);
        NSLog(@"task1 end");
    });
    
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task2 begin");
        sleep(2);
        NSLog(@"task2 end");
    });
    dispatch_group_notify(group, queue, ^{
        NSLog(@"=================");
    });
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task3 begin");
        sleep(6);
        NSLog(@"task3 end");
    });
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5*NSEC_PER_SEC)));
    NSLog(@"all end");
    dispatch_group_async(group, queue, ^{
        
        NSLog(@"task4 begin");
        sleep(2);
        NSLog(@"task4 end");
    });
输出：
# 代码执行到wait的时候会等待5秒之后再执行wait下边的代码，和sleep有点相似。
**2016-03-28 17:26:31.335 GCD_Demo[12745:366983] task3 begin**
**2016-03-28 17:26:31.335 GCD_Demo[12745:366978] task1 begin**
**2016-03-28 17:26:31.335 GCD_Demo[12745:366979] task2 begin**
**2016-03-28 17:26:33.340 GCD_Demo[12745:366978] task1 end**
**2016-03-28 17:26:33.340 GCD_Demo[12745:366979] task2 end**
**2016-03-28 17:26:36.336 GCD_Demo[12745:366894] all end**
**2016-03-28 17:26:36.336 GCD_Demo[12745:366979] task4 begin**
**2016-03-28 17:26:37.340 GCD_Demo[12745:366983] task3 end**
**2016-03-28 17:26:38.342 GCD_Demo[12745:366979] task4 end**
**2016-03-28 17:26:38.342 GCD_Demo[12745:366983] =================**
```
### 同时处理多数据不管顺序
```
          dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    
          /*! dispatch_apply函数说明
           10      *
           11      *  @brief  dispatch_apply函数是dispatch_sync函数和Dispatch Group的关联API
           12      *         该函数按指定的次数将指定的Block追加到指定的Dispatch Queue中,并等到全部的处理执行结束
           13      *
           14      *  @param 10    指定重复次数  指定10次
           15      *  @param queue 追加对象的Dispatch Queue
           16      *  @param index 带有参数的Block, index的作用是为了按执行的顺序区分各个Block
           17      *
           18      */
          dispatch_apply(10, queue, ^(size_t index) {
                  NSLog(@"%d", index);
              
              });
          NSLog(@"done");
输出：
# 这个和上边讲的分组类似，多事务处理，处理结束后再执行代码。
# 这个是同步的，代码按顺序执行，分组的是异步执行的block
**2016-03-28 17:36:35.698 GCD_Demo[12857:372458] 1**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372463] 5**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372429] 4**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372464] 6**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372465] 7**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372462] 2**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372457] 0**
**2016-03-28 17:36:35.698 GCD_Demo[12857:372461] 3**
**2016-03-28 17:36:35.699 GCD_Demo[12857:372458] 8**
**2016-03-28 17:36:35.699 GCD_Demo[12857:372429] 9**
**2016-03-28 17:36:35.699 GCD_Demo[12857:372429] done**
    
```
参考文章：[Grand Central Dispatch (GCD) Reference](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/index.html#//apple_ref/c/macro/DISPATCH_QUEUE_CONCURRENT)
GCD提供的接口蛮多的,适用场景还是要熟练掌握，才能运用自如。