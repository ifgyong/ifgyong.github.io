title: iOS底层原理  多线程之GCD看我就够了 --(10)
date: 2019-12-1 11:20:58
tags:
- iOS
categories: iOS
---

`RunLoop`和线程的关系，以及`Thread`如何保活和控制生命周期，今天我们再探究下另外的一个线程`GCD`，揭开蒙娜丽莎的面纱。
### GCD 基础知识
GCD是什么呢？我们引用[百度百科](https://baike.baidu.com/item/GCD)的一段话。
> Grand Central Dispatch (GCD)是Apple开发的一个多核编程的较新的解决方法。它主要用于优化应用程序以支持多核处理器以及其他对称多处理系统。它是一个在线程池模式的基础上执行的并行任务。在Mac OS X 10.6雪豹中首次推出，也可在IOS 4及以上版本使用。

GCD有哪些优点
- GCD自动管理线程
- 开发者只需要将task加入到队列中，不用关注细节，然后将task执行完的block传入即可
- GCD 自动管理线程，线程创建，挂起，销毁。

那么我们研究下如何更好的使用GCD，首先要了解到串行队列、并行队列、并发
#### 串行队列
串行是基于队列的，队列会自己控制线程，在串行队列中，任务一次只能执行一个，执行完当前任务才能继续执行下个任务。
#### 并行队列
并行有通过新建线程来实现并发执行任务，并行队列中同时是可能执行多个任务，当并行数量没有限制的时候，理论上所有任务可以同时执行。
#### 并发
并发是基于线程的，同一个线程只能串行(同一时刻)执行，要想实现并发，只能多个线程一起干活

**串行队列**相当于工厂1条流水线4个工人生产设备，从开始到结束，一个人只能干一件事，甲做A不做B。

**并行队列**是一条流水线4个工人，当工人干活速度不够的时候可以再申请一条流水线，实现两条流水线同时干活，这就实现了并发。

**并发**是多个流水线在同时加工产品。


#### GCD中的串行队列()
##### 串行队列（Serial Dispatch Queue）：
按照**FIFO**(First In First Out先进先出)原则，先添加的任务在队首，后添加的任务在队尾，执行任务的时候按照队列的从首到尾一个挨着一个执行，一次只能执行一个任务，不具备开辟新线程的能力。


![](/images/10-1.png)
#####  并发队列（Concurrent Dispatch Queue）：
按照**FIFO**(First In First Out先进先出)原则，先添加的任务在队首，后添加的任务在队尾，执行任务的时候按照队列的从首到若干个，执行到队尾，一次可以执行多个任务，具备开辟新线程的能力。



![](/images/10-2.png)

### GCD使用步骤
GCD的使用非常简单，创建队列或者在全局队列中新加任务就可以了。

下边来看看 **队列的创建方法/获取方法**，以及 **任务的创建方法**。
#### 获取主队列
主队列是一种特殊的队列，也是串行队列，负责UI的更新，也可以做其他事情，可以通过`dispatch_get_main_queue()`，一般写的代码没有声明多线程或者添加到其他队列中的代码都是在主队列中运行的。

```
//获取主队列
dispatch_queue_t main_queue= dispatch_get_main_queue();
```

#### 获取全局队列
全局队列是一个特殊的并行队列，系统已经创建好了，使用的时候通过`dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)`,第一个参数是`identifier`，表示队列的优先级，一般传入`DISPATCH_QUEUE_PRIORITY_DEFAULT`，第二个参数`flags`，官方说法是必须是0，否则返回NULL。暂且传入0。下边摘自[libdispatch](https://opensource.apple.com/tarballs/libdispatch/)
> Use the
.Fn dispatch_get_global_queue
function to obtain the global queue of given priority. The
.Fa flags
argument is reserved for future use and must be zero. Passing any value other
than zero may result in a NULL return value.

```
//获取全局队列
dispatch_queue_t main_queue= dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
```

#### 任务的创建
GCD 提供了同步执行任务的创建方法`dispatch_sync`和异步执行任务创建方法的`spatch_async`。

```
// 同步执行任务创建方法
dispatch_sync(queue, ^{
    // 这里放同步执行任务代码
});
// 异步执行任务创建方法
dispatch_async(queue, ^{
    // 这里放异步执行任务代码
});
```

虽然是只有同步异步但是他们组合的多变的

||并发队列|创建的串行队列|主队列|
|:-:|:-:|:-:|:-:|
|同步(sync)|没开启新线程，串行执行|没开启新线程，串行执行任务|没开启新线程，串行执行任务|
|异步(async)|能开启新线程，并发执行|能开启新线程，串行执行任务|没开启新线程，串行执行任务|

### GCD的使用
#### 主队列+同步
在主队列中执行任务，并同步添加任务

```
//主队列+同步
-(void)syn_main{
	NSLog(@"1");
	dispatch_queue_t main_queue = dispatch_get_main_queue();
	dispatch_sync(main_queue, ^{
		NSLog(@"2");
	});
	NSLog(@"3");
}
//log
1
```

看到日志只输出了1就崩溃了提示`exc_bad_instuction`,为什么出问题呢？
主队列是同步的，任务前后执行的任务是在主队列中，添加的任务也是在主队列中，而且添加是同步添加。
**what**???在同步队列中添加同步任务，到底是想让队列执行任务还是添加任务。队列遵循FIFO原则，假如要大家都在排队等打饭，新来的员工叫的A,后边代码叫B,然后都在一个队列中，突然来了个插队的，你说B能同意吗？明显和A干起来了，结果系统老师过来拉架了说了一句`exc_bad_instuction`，意思是你俩吵起来大家都吃不上饭了，结果他俩还是接着吵，把系统吵崩溃了。
那么我们能在主队列中同步添加任务吗？答案是可以的。看到答案不要笑哦

```
//主队列+同步
-(void)syn_main2{
	NSLog(@"1任务执行");
	sleep(1);
	NSLog(@"2任务执行");
	sleep(1);
	NSLog(@"3任务执行");
}
//log
1任务执行
2任务执行
3任务执行
```

没看错，保证在主队列中调用该函数，那么他就是主队列同步执行的,如果在其他队列中调用，那它则是在调用者队列中同步执行。

#### 主队列+异步
在主队列中异步添加任务并执行任务

```
//主队列+异步
	NSLog(@"start");
	dispatch_queue_t main_queue = dispatch_get_main_queue();
	dispatch_async(main_queue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			NSLog(@"%@ %d",[NSThread currentThread],i);
		}
	});
	dispatch_async(main_queue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			NSLog(@"%@ %d",[NSThread currentThread],i);
		}
	});
	dispatch_async(main_queue, ^{
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			NSLog(@"%@ %d",[NSThread currentThread],i);
		}
	});
	NSLog(@"end");
//log
2019-07-24 15:12:24.73 start
2019-07-24 15:12:24.73 end

<NSThread: 0x600002f9a940>{number = 1, name = main} 0
2019-07-24 15:18:14.971795+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 1
2019-07-24 15:18:15.972421+0800 day15-GCDo[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 2
2019-07-24 15:18:16.973529+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 3
2019-07-24 15:18:17.974978+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 4
2019-07-24 15:18:18.975800+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 5
2019-07-24 15:18:19.977185+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 7
2019-07-24 15:18:20.978615+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 8
2019-07-24 15:18:21.979958+0800 day15-GCD[31837:35880409] <NSThread: 0x600002f9a940>{number = 1, name = main} 9
```

在主队列异步执行任务，从日志看出来`end`早于任务的执行，符合FIFO原则，都是在主线程执行，可以看到
- 主线程多个任务异步不能创建新线程
- 主线程异步也是串行执行


#### 全局队列+同步
全局队列是并行队列，和同步配合就是串行执行了。

```
//全局队列+同步
-(void)sync_global{
	printf("\n start");
	dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_sync(global_queue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_sync(global_queue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_sync(global_queue, ^{
		NSThread *thread = [NSThread currentThread];
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,thread.description.UTF8String,i);
		}
	});
	printf("\n end");
}
//log
start
 2019-07-24 15:35:36 <NSThread: 0x600000592900>{number = 1, name = main} 0
 2019-07-24 15:35:37 <NSThread: 0x600000592900>{number = 1, name = main} 1
 2019-07-24 15:35:38 <NSThread: 0x600000592900>{number = 1, name = main} 2
 2019-07-24 15:35:39 <NSThread: 0x600000592900>{number = 1, name = main} 3
 2019-07-24 15:35:40 <NSThread: 0x600000592900>{number = 1, name = main} 4
 2019-07-24 15:35:41 <NSThread: 0x600000592900>{number = 1, name = main} 5
 2019-07-24 15:35:42 <NSThread: 0x600000592900>{number = 1, name = main} 7
 2019-07-24 15:35:43 <NSThread: 0x600000592900>{number = 1, name = main} 8
 2019-07-24 15:35:44 <NSThread: 0x600000592900>{number = 1, name = main} 9
 end
```

在全局队列中使用串行添加多个任务并没有新建子线程来解决问题，同步其实就是串行，使用FIFO原则，一个任务解决完再解决下一个任务。
#### 全局队列+异步
全局队列有创建子线程的能力，但是需要异步`async`去执行。

```
//全局队列+异步
-(void)async_global{
	printf("\n start");
	dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(global_queue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(global_queue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(global_queue, ^{
		NSThread *thread = [NSThread currentThread];
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,thread.description.UTF8String,i);
		}
	});
	printf("\n end");
}
-(NSString *)currentDateString{
	NSDate *date=[NSDate new];
	NSDateFormatter *format = [[NSDateFormatter alloc]init];
	[format setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	return [format stringFromDate:date];
}
//log

 start
 end
 2019-07-24 15:40:21 <NSThread: 0x600003b43dc0>{number = 5, name = (null)} 3
 2019-07-24 15:40:21 <NSThread: 0x600003b44e80>{number = 4, name = (null)} 0
 2019-07-24 15:40:21 <NSThread: 0x600003b45880>{number = 3, name = (null)} 7
 2019-07-24 15:40:22 <NSThread: 0x600003b44e80>{number = 4, name = (null)} 1
 2019-07-24 15:40:22 <NSThread: 0x600003b45880>{number = 3, name = (null)} 8
 2019-07-24 15:40:22 <NSThread: 0x600003b43dc0>{number = 5, name = (null)} 4
 2019-07-24 15:40:23 <NSThread: 0x600003b45880>{number = 3, name = (null)} 9
 2019-07-24 15:40:23 <NSThread: 0x600003b44e80>{number = 4, name = (null)} 2
 2019-07-24 15:40:23 <NSThread: 0x600003b43dc0>{number = 5, name = (null)} 5
```

全局队列当搭配`async`的时候，追加多个任务，这次是使用3个线程，而且不用我们来维护线程的生命周期，而且执行的顺序是无序的。
#### 创建串行队列+同步
开发者自己创建的串行队列同步调用和系统主队列有类似的地方，也有区别。一样都是串行执行，区别是追加任务的时候一般是在主队列向串行队列添加。

```
//创建串行队列+同步
-(void)sync_cust_queue{
	printf("\n start");
	dispatch_queue_t custQueue = dispatch_queue_create("cust-queue", DISPATCH_QUEUE_SERIAL);
	dispatch_sync(custQueue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_sync(custQueue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_sync(custQueue, ^{
		NSThread *thread = [NSThread currentThread];
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,thread.description.UTF8String,i);
		}
	});
	printf("\n end");
}

//log

start
 2019-07-24 15:53:15 <NSThread: 0x6000017ea940>{number = 1, name = main} 0
 2019-07-24 15:53:16 <NSThread: 0x6000017ea940>{number = 1, name = main} 1
 2019-07-24 15:53:17 <NSThread: 0x6000017ea940>{number = 1, name = main} 2
 2019-07-24 15:53:18 <NSThread: 0x6000017ea940>{number = 1, name = main} 3
 2019-07-24 15:53:19 <NSThread: 0x6000017ea940>{number = 1, name = main} 4
 2019-07-24 15:53:20 <NSThread: 0x6000017ea940>{number = 1, name = main} 5
 2019-07-24 15:53:21 <NSThread: 0x6000017ea940>{number = 1, name = main} 7
 2019-07-24 15:53:22 <NSThread: 0x6000017ea940>{number = 1, name = main} 8
 2019-07-24 15:53:23 <NSThread: 0x6000017ea940>{number = 1, name = main} 9
 end
```

同步向串行队列添加任务并没有死锁！原因是添加任务是在`main_queue`执行的，添加的任务是在`cust-queue`中执行，符合FIFO原则，先添加的先执行，具体执行的线程由他们自己分配。执行的任务是在`main`线程中。

#### 创建串行队列+异步
会开启新线程，但是因为任务是串行的，执行完一个任务，再执行下一个任务

```
//创建串行队列+异步
-(void)async_cust_queue{
	printf("\n start");
	dispatch_queue_t custQueue = dispatch_queue_create("cust-queue", DISPATCH_QUEUE_SERIAL);
	dispatch_async(custQueue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(custQueue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(custQueue, ^{
		NSThread *thread = [NSThread currentThread];
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,thread.description.UTF8String,i);
		}
	});
	printf("\n end");
}
//log

 start
 end
 2019-07-24 16:12:57 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 0
 2019-07-24 16:12:58 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 1
 2019-07-24 16:12:59 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 2
 2019-07-24 16:13:00 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 3
 2019-07-24 16:13:01 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 4
 2019-07-24 16:13:02 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 5
 2019-07-24 16:13:03 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 7
 2019-07-24 16:13:04 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 8
 2019-07-24 16:13:05 <NSThread: 0x600002b346c0>{number = 3, name = (null)} 9
```

在`异步 + 串行队列`可以看到：

开启了一条新线程（异步执行具备开启新线程的能力，串行队列只开启一个线程）。
所有任务是在打印的`end`之后才开始执行的（异步执行不会做任何等待，可以继续执行任务）。
任务是按顺序执行的（串行队列每次只有一个任务被执行，任务一个接一个按顺序执行）。
#### 创建并行队列+同步
在当前线程中执行任务，不会开启新线程，执行完一个任务，再执行下一个任务

```
 start
 2019-07-24 16:21:24 <NSThread: 0x6000031d1380>{number = 1, name = main} 0
 2019-07-24 16:21:25 <NSThread: 0x6000031d1380>{number = 1, name = main} 1
 2019-07-24 16:21:26 <NSThread: 0x6000031d1380>{number = 1, name = main} 2
 2019-07-24 16:21:27 <NSThread: 0x6000031d1380>{number = 1, name = main} 3
 2019-07-24 16:21:28 <NSThread: 0x6000031d1380>{number = 1, name = main} 4
 2019-07-24 16:21:29 <NSThread: 0x6000031d1380>{number = 1, name = main} 5
 2019-07-24 16:21:30 <NSThread: 0x6000031d1380>{number = 1, name = main} 7
 2019-07-24 16:21:31 <NSThread: 0x6000031d1380>{number = 1, name = main} 8
 2019-07-24 16:21:32 <NSThread: 0x6000031d1380>{number = 1, name = main} 9
 end
```

全局队列其实就是特殊的并行队列，这里结果和`全局队列+同步`一致。

#### 创建并行队列+异步
在当前线程中执行任务，会开启新线程，可以同时执行多个任务。

```
//创建并行队列+异步
-(void)async_queue{
	printf("\n start");
	dispatch_queue_t custQueue = dispatch_queue_create("cust-queue", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(custQueue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(custQueue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
		}
	});
	dispatch_async(custQueue, ^{
		NSThread *thread = [NSThread currentThread];
		for (int i = 7; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self currentDateString].UTF8String,thread.description.UTF8String,i);
		}
	});
	printf("\n end");
}
//log
start
 end
 2019-07-24 16:22:09 <NSThread: 0x6000004280c0>{number = 3, name = (null)} 7
 2019-07-24 16:22:09 <NSThread: 0x6000004104c0>{number = 5, name = (null)} 0
 2019-07-24 16:22:09 <NSThread: 0x600000422300>{number = 4, name = (null)} 3
 2019-07-24 16:22:10 <NSThread: 0x6000004104c0>{number = 5, name = (null)} 1
 2019-07-24 16:22:10 <NSThread: 0x6000004280c0>{number = 3, name = (null)} 8
 2019-07-24 16:22:10 <NSThread: 0x600000422300>{number = 4, name = (null)} 4
 2019-07-24 16:22:11 <NSThread: 0x6000004280c0>{number = 3, name = (null)} 9
 2019-07-24 16:22:11 <NSThread: 0x6000004104c0>{number = 5, name = (null)} 2
 2019-07-24 16:22:11 <NSThread: 0x600000422300>{number = 4, name = (null)} 5
```

`并行队列+异步`和`全局队列+异步`一致，也会新建线程执行任务，且是并发执行。
### GCD其他高级用法
#### 子线程执行任务 主线程刷新UI

```
- (void)backToMain{
	dispatch_queue_t main = dispatch_get_main_queue();
	dispatch_queue_t glo = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(glo, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
		dispatch_sync(main, ^{
			printf("\n %s %s 我在刷新UI",[self dateUTF8],[self threadInfo]);
		});
	});	
}
//log
 2019-07-24 16:45:07 <NSThread: 0x600001e84380>{number = 3, name = (null)} 0
 2019-07-24 16:45:08 <NSThread: 0x600001e84380>{number = 3, name = (null)} 1
 2019-07-24 16:45:09 <NSThread: 0x600001e84380>{number = 3, name = (null)} 2
 2019-07-24 16:45:09 <NSThread: 0x600001ef2940>{number = 1, name = main} 我在刷新UI
```

#### 队列分组 dispatch_group_t
##### dispatch_group_notify 
GCD有有分组的概念，当所有加入分组的队列中的任务都执行完成的时候，通过`dispatch_group_notify`完成回调，第一个参数`group`是某个分组的回调。

```
-(void)group{
	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t queue= dispatch_queue_create("cust.queue.com", DISPATCH_QUEUE_CONCURRENT);
	dispatch_queue_t queue2= dispatch_queue_create("cust2.queue.com", DISPATCH_QUEUE_CONCURRENT);
	dispatch_group_async(group, queue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
	dispatch_group_async(group, queue2, ^{
		for (int i = 4; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		printf("\n %s %s ---end1----",[self dateUTF8],[self threadInfo]);
	});
	dispatch_group_async(group, queue, ^{
		for (int i = 6; i < 8; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
	dispatch_group_async(group, queue2, ^{
		for (int i = 8; i < 10; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
}
```

##### dispatch_group_wait && dispatch_group_enter && dispatch_group_leave
`dispatch_group_enter`和`dispatch_group_leave`需要成对使用，否则`dispatch_group_wait`在缺少`leave`的情况下会等待到死，造成线程阻塞。

```
static	dispatch_group_t group ;
if (group == nil) {
	group = dispatch_group_create();
}
dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//	dispatch_group_enter(group);
dispatch_group_async(group, queue, ^{
	[self print];
	[NSThread sleepForTimeInterval:2];
//		dispatch_group_leave(group);//当注释掉  阻塞在wait不继续向下执行
});
dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

dispatch_group_enter(group);
dispatch_group_async(group, queue, ^{
	[self print];
	[NSThread sleepForTimeInterval:2];
	dispatch_group_leave(group);
});
//log
2019-07-25 10:58:50 <NSThread: 0x600002d84180>{number = 3, name = (null)} 
2019-07-25 10:58:52 <NSThread: 0x600002d84180>{number = 3, name = (null)} 

```

#### 栅栏函数 dispatch_barrier_sync
栅栏函数实现了异步的队列中在多个任务结束的时候实行回调，回调分异步和同步，同步回调在主线程，异步在其他线程。


```
- (void)barry{
	dispatch_queue_t queue= dispatch_queue_create("cust.queue.com", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(queue, ^{
		for (int i = 0; i < 3; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
	dispatch_barrier_sync(queue, ^{
		printf("\n %s %s ---中间暂停一下----",[self dateUTF8],[self threadInfo]);
	});
	dispatch_async(queue, ^{
		for (int i = 3; i < 6; i ++) {
			[NSThread sleepForTimeInterval:1];
			printf("\n %s %s %d",[self dateUTF8],[self threadInfo],i);
		}
	});
	dispatch_barrier_async(queue, ^{
		printf("\n %s %s ---中间第二次暂停一下----",[self dateUTF8],[self threadInfo]);
	});
}
//log
 2019-07-24 16:52:33 <NSThread: 0x600003158440>{number = 3, name = (null)} 0
 2019-07-24 16:52:34 <NSThread: 0x600003158440>{number = 3, name = (null)} 1
 2019-07-24 16:52:35 <NSThread: 0x600003158440>{number = 3, name = (null)} 2
 2019-07-24 16:52:35 <NSThread: 0x6000031293c0>{number = 1, name = main} ---中间暂停一下----
 2019-07-24 16:52:36 <NSThread: 0x600003158440>{number = 3, name = (null)} 3
 2019-07-24 16:52:37 <NSThread: 0x600003158440>{number = 3, name = (null)} 4
 2019-07-24 16:52:38 <NSThread: 0x600003158440>{number = 3, name = (null)} 5
 2019-07-24 16:52:38 <NSThread: 0x600003158440>{number = 3, name = (null)} ---中间第二次暂停一下----
```

#### 单例-执行一次的函数 dispatch_once_t
单例可以通过这个函数实现，只执行一次的函数。

```
//只执行一次的dispatch_once
-(void)exc_once{
	static dispatch_once_t onceToken;
	static NSObject *obj;
	dispatch_once(&onceToken, ^{
		obj=[NSObject new];
		printf("\n just once %s %s",[self dateUTF8],obj.description.UTF8String);
	});
	printf("\n %s %s",[self dateUTF8],obj.description.UTF8String);
}
调用4次
dispatch_apply(4, dispatch_get_global_queue(0, 0), ^(size_t idx) {
		[self exc_once];
	});
	
//log
just once 2019-07-25 14:46:00 <NSObject: 0x60000378b100>
2019-07-25 14:46:00 <NSObject: 0x60000378b100>
2019-07-25 14:46:00 <NSObject: 0x60000378b100>
2019-07-25 14:46:00 <NSObject: 0x60000378b100>
```

当调用4次的时候，日志打印的四次`obj`均为同一个地址，证明`block`回调四次但是只执行了一次。
#### 延迟执行 dispatch_after
当记录日志或者点击事件的方法我们不希望立即执行，则会用到延迟

```
//延迟执行
-(void)delayTimeExc{
	printf("\n %s %s begin",[self dateUTF8],[self threadInfo]);
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	
		printf("\n %s %s",[self dateUTF8],[self threadInfo]);
		
	});
	printf("\n %s %s end",[self dateUTF8],[self threadInfo]);
}
//log
2019-07-24 17:07:48 <NSThread: 0x600003cc6940>{number = 1, name = main} begin
2019-07-24 17:07:48 <NSThread: 0x600003cc6940>{number = 1, name = main} end
2019-07-24 17:07:50 <NSThread: 0x600003cc6940>{number = 1, name = main}
```

#### 信号量  dispatch_semaphore_t
信号量为1可以作为线程锁来用，当N>1的时候，同时执行的有N个任务。
`dispatch_apply`可以通知创建多个线程来执行任务，用它来测试信号量再好不过了。

```
//信号量 当信号量为1 可以未做锁来用，当N>1，t通知执行的数量则是数字N。
- (void)semaphore{
	static dispatch_semaphore_t sem;
	if (sem == NULL) {
		sem = dispatch_semaphore_create(1);
	}
	dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
	static int i = 0;
	int currentI = i +2;
	for (; i < currentI; i ++) {
		[NSThread sleepForTimeInterval:1];
		printf("\n %s %s %d",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,i);
	}
	dispatch_semaphore_signal(sem);
}
-(void)asyn_semaphore{
	dispatch_apply(3, dispatch_get_global_queue(0, 0), ^(size_t idx) {
		[self semaphore];
	});
}
//log

2019-07-24 17:25:04 <NSThread: 0x6000002a2940>{number = 1, name = main} 0
2019-07-24 17:25:05 <NSThread: 0x6000002a2940>{number = 1, name = main} 1
2019-07-24 17:25:06 <NSThread: 0x6000002e2b40>{number = 3, name = (null)} 2
2019-07-24 17:25:07 <NSThread: 0x6000002e2b40>{number = 3, name = (null)} 3
2019-07-24 17:25:08 <NSThread: 0x6000002d4740>{number = 4, name = (null)} 4
2019-07-24 17:25:09 <NSThread: 0x6000002d4740>{number = 4, name = (null)} 5
```

设计一个经典问题，火车票窗口买票，火车站卖票一般有多个窗口，排队是每个窗口排一个队列，一个窗口同时只能卖一张票，那我们设计一下如何实现多队列同时访问多个窗口的的问题。

```
-(void)muchQueueBuyTick{
	dispatch_queue_t queue= dispatch_queue_create("com.buy.tick", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(queue, ^{
		for (NSInteger i = 0; i < 5; i ++) {
			[self semaphore_buy_ticks:4];
		}
	});
	dispatch_queue_t queue2= dispatch_queue_create("com.buy2.tick", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(queue2, ^{
		for (NSInteger i = 0; i < 5; i ++) {
			[self semaphore_buy_ticks:2];
		}
	});
}
- (void)semaphore_buy_ticks:(NSInteger)windowsCount{
	static dispatch_semaphore_t sem;
	if (sem == NULL) {
		sem = dispatch_semaphore_create(windowsCount);
	}
	//信号量-1
	dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
	self.count--;
	if (self.count > 0) {
		printf("\n %s %s 第%ld个人买到票了",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,(long)self.count);
		[NSThread sleepForTimeInterval:0.2];
	}
	//信号量+1
	dispatch_semaphore_signal(sem);
}
//log

2019-07-24 18:01:44 <NSThread: 0x600003935e00>{number = 4, name = (null)} 第8个人买到票了
 2019-07-24 18:01:44 <NSThread: 0x600003904c40>{number = 3, name = (null)} 第8个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003904c40>{number = 3, name = (null)} 第6个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003935e00>{number = 4, name = (null)} 第6个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003935e00>{number = 4, name = (null)} 第4个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003904c40>{number = 3, name = (null)} 第4个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003935e00>{number = 4, name = (null)} 第2个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003904c40>{number = 3, name = (null)} 第2个人买到票了
 2019-07-24 18:01:45 <NSThread: 0x600003935e00>{number = 4, name = (null)} 第0个人买到票了
```

两个窗口(两个队列)，每个窗口排了5(循环5次)个人，一共10(count=10)张票。
当同时一张票可以分割2次，卖票的错乱了，明显错误了，现在把每张票都锁起来，同时只能允许同一个人卖。

```
-(void)muchQueueBuyTick{
	dispatch_queue_t queue= dispatch_queue_create("com.buy.tick", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(queue, ^{
		for (NSInteger i = 0; i < 5; i ++) {
			[self semaphore_buy_ticks:1];
		}
	});
	dispatch_queue_t queue2= dispatch_queue_create("com.buy2.tick", DISPATCH_QUEUE_CONCURRENT);
	dispatch_async(queue2, ^{
		for (NSInteger i = 0; i < 5; i ++) {
			[self semaphore_buy_ticks:1];
		}
	});
}
//log
2019-07-24 18:03:56 <NSThread: 0x600000e1cac0>{number = 3, name = (null)} 第9个人买到票了
 2019-07-24 18:03:57 <NSThread: 0x600000e1e0c0>{number = 4, name = (null)} 第8个人买到票了
 2019-07-24 18:03:57 <NSThread: 0x600000e1cac0>{number = 3, name = (null)} 第7个人买到票了
 2019-07-24 18:03:57 <NSThread: 0x600000e1e0c0>{number = 4, name = (null)} 第6个人买到票了
 2019-07-24 18:03:57 <NSThread: 0x600000e1cac0>{number = 3, name = (null)} 第5个人买到票了
 2019-07-24 18:03:57 <NSThread: 0x600000e1e0c0>{number = 4, name = (null)} 第4个人买到票了
 2019-07-24 18:03:58 <NSThread: 0x600000e1cac0>{number = 3, name = (null)} 第3个人买到票了
 2019-07-24 18:03:58 <NSThread: 0x600000e1e0c0>{number = 4, name = (null)} 第2个人买到票了
 2019-07-24 18:03:58 <NSThread: 0x600000e1cac0>{number = 3, name = (null)} 第1个人买到票了
```

顺序是对了，数量也对了。

再换一种思路实现锁住窗口，我们使用串行队列也是可以的。

```
//使用同步队列卖票
- (void)sync_buy_tick{
	dispatch_async(dispatch_get_main_queue(), ^{
		self.count--;
		if (self.count > 0) {
			printf("\n %s %s 第%ld个人买到票了",[self currentDateString].UTF8String,[NSThread currentThread].description.UTF8String,(long)self.count);
			[NSThread sleepForTimeInterval:0.2];
		}
	});
}
//log
2019-07-25 09:31:56 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第9个人买到票了
 2019-07-25 09:31:56 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第8个人买到票了
 2019-07-25 09:31:56 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第7个人买到票了
 2019-07-25 09:31:56 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第6个人买到票了
 2019-07-25 09:31:57 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第5个人买到票了
 2019-07-25 09:31:57 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第4个人买到票了
 2019-07-25 09:31:57 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第3个人买到票了
 2019-07-25 09:31:57 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第2个人买到票了
 2019-07-25 09:31:57 <NSThread: 0x6000034d2e40>{number = 1, name = main} 第1个人买到票了
```

串行队列不创建子线程，所有任务都在同一个线程执行，那么他们就会排队，其实不管多少人同时点击买票，票的分割还是串行的，所以线程锁的可以使用串行队列来解决。

#### 快速迭代方法：dispatch_apply
快速迭代就是同时创建很多线程来在做事情，现在工厂收到一个亿的订单，工厂本来只有2条生产线，现在紧急新建很多生产线来生产产品。

```
/*
同时新建了多条线程来做任务
*/
	dispatch_apply(10, dispatch_get_global_queue(0, 0), ^(size_t idx) {
		printf("\n %s %s ",[self dateUTF8],[self threadInfo]);
	});
	
	//log
2019-07-25 09:38:38 <NSThread: 0x600000966180>{number = 4, name = (null)} 
2019-07-25 09:38:38 <NSThread: 0x60000094a3c0>{number = 3, name = (null)} 
2019-07-25 09:38:38 <NSThread: 0x600000979dc0>{number = 5, name = (null)} 
2019-07-25 09:38:38 <NSThread: 0x60000090d3c0>{number = 1, name = main} 
2019-07-25 09:38:38 <NSThread: 0x60000095cfc0>{number = 6, name = (null)} 
2019-07-25 09:38:38 <NSThread: 0x600000950140>{number = 8, name = (null)} 
 2019-07-25 09:38:38 <NSThread: 0x60000095d0c0>{number = 9, name = (null)} 
 2019-07-25 09:38:38 <NSThread: 0x60000094a400>{number = 7, name = (null)} 
 2019-07-25 09:38:38 <NSThread: 0x600000966180>{number = 4, name = (null)} 
 2019-07-25 09:38:38 <NSThread: 0x60000094a3c0>{number = 3, name = (null)} 
```

可以看到新建了`3`、`4`、`5`、`6`、`7`、`8`、`9`、`main`来执行任务。
### 多线程RunLoop实战
问题一：请问下边代码输出什么？

```
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    dispatch_queue_t  que= dispatch_get_global_queue(0, 0);
    dispatch_async(que, ^{
        NSLog(@"1");
        [self performSelector:@selector(test) withObject:nil afterDelay:.0];
        NSLog(@"3");
    });
}
- (void)test{
    NSLog(@"2");
}
```

- 猜想1：结果是`123`
- 猜想2：结果是`132`

有没有第三种结果呢？

猜想1分析：
因为是延迟`0`s执行，当然是先执行`2`，再执行`3`了。

猜想2分析：

我们来分析一下，异步加入全局队列中，单个任务的时候会加入到子线程中，那么会先输出`1`，然后输出`3`，最后输出`2`.

最后验证一下：

```
1
3
```

为什么2没有出来呢？在看一下代码，全局队列，延迟执行，点进去函数查看，原来是在`runloop.h`文件中，我们猜测延迟执行是`timer`添加到`runloop`中了，添加进去也应该输出`132`的。因为在子线程中，没有主动调用不会有`runloop`的，及时调用了也需要保活技术，那么代码改进一下

```
    dispatch_queue_t  que= dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(que, ^{
        NSLog(@"1");
        // 相当于[self test];
//       [self performSelector:@selector(test) withObject:nil];
        [self performSelector:@selector(test) withObject:nil afterDelay:.0];
        
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
        NSLog(@"3");
    });
```

经测试输出了`12`，这和我们猜想的还是不对，原来输出`3`放在了最后，导致的问题，`RunLoop`运行起来，进入了循环，则后面的就不会执行了，除非停止当前`RunLoop`，我们再改进一下

```
    dispatch_queue_t  que= dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(que, ^{
        NSLog(@"1");
        // 相当于[self test];
//       [self performSelector:@selector(test) withObject:nil];
        [self performSelector:@selector(test) withObject:nil afterDelay:.0];
         NSLog(@"3");
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSRunLoopCommonModes];
        [[NSRunLoop currentRunLoop] run];
    });
```

最后终于输出了`132`。缺点是子线程成了**死待**，不死之身，关于怎么杀死**死待**请看[上篇优雅控制RunLoop生命周期](https://juejin.im/post/5d35b347f265da1b8608c49b)。
关于`performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay`中有延迟的，都是添加到当前你线程的`RunLoop`，如果没有启动`RunLoop`和保活恐怕也不能一直执行。`[self performSelector:@selector(test) withObject:nil]`是在`Foudation`中，源码是直接`objc_msgSend()`，相当于直接`[self test]`，不会有延迟。

问题2：请问输出什么？

```
NSThread *thread=[[NSThread alloc]initWithBlock:^{
    NSLog(@"1");
}];
[thread start];
[self performSelector:@selector(test)
             onThread:thread
           withObject:nil
        waitUntilDone:YES];
```

这个和上面的类似，结果是打印了`1`就崩溃了，原因是`thread start`之后执行完`block`就结束了，没有`runloop`的支撑。当执行`performSelector`的时候，线程已经死掉。解决这个问题只需要向子线程中添加`RunLoop`，而且保证`RunLoop`不停止就行了。



### 总结
- GCD异步负责执行耗时任务(例如下载，复杂计算)，main线程负责更新UI
- 队列多任务异步执行最后全局执行完毕可以使用`group_notify`来监听执行完毕时间
- 队列多任务异步执行结束时间，中间拦截更新UI，然后再异步执行可以使用`dispatch_barrier_sync`
- 当多线程访问同一个资源，可以使用信号量来限制同时访问资源的线程数量

### 参考资料
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