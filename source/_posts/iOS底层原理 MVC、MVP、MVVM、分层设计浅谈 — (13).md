 
title: MVC、MVP、MVVM、分层设计浅谈 — (13)
date: 2019-12-1 11:23:58
tags:
- iOS
categories: iOS
---

这篇文章主要讲解关于架构的一些思考，通过这篇文章你将了解到
> 1. MVC
> 2. MVC变种
> 3. MVP
> 4. MVVM
> 5. 分层设计的优缺点

没有最好的架构，只有最适合业务的架构。

### MVC
苹果版本的`MVC`是`Model`和`VC`和交互，`VC`和`View`交互

- 优点：`View`和`Model`可以重复利用，可以独立使用

- 缺点：`Controller`的代码过于臃肿

![](/images/13-1.png)

代码：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadData];
}
- (void)loadData{
    self.data=[NSMutableArray array];
    for (int i = 0; i < 20; i ++) {
        FYNews *item=[FYNews new];
        item.title =[NSString stringWithFormat:@"title-%d",i];
        item.name =[NSString stringWithFormat:@"name-%d",i];
        [self.data addObject:item];
    }
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    // Configure the cell...
    FYNews *item =[self.data objectAtIndex:indexPath.row];
    cell.detailTextLabel.text =item.title;
    cell.textLabel.text = item.name;
    return cell;
}

//model

@interface FYNews : NSObject
@property (nonatomic,copy) NSString *title;
@property (nonatomic,copy) NSString *name;
@end
```

这里是`VC`中组装了`tableview`，`model`的数据在`VC`中在`view`中显示出来，当需要另外的数据的时候，只需要将`model`改成需要的`model`而无需更改`tableview`的代码兼容性较好。

### MVC变种

`MVC`变种，其实就是将`model`和`view`建立了联系，`view`依据`Model`来展示数据，`VC`组装`Model`，组装展示是在`view`中实现。

- 优点：对Controller进行瘦身，将View的内部细节封装起来了，外界不知道View内部的具体实现

- 缺点：view依赖于Model



![](/images/13-2.png)

代码实现

```
//.h
@class FYItemModel;
@interface FYAppleView : UIView
@property (nonatomic,strong) FYItemModel *model;
@end

//.m
@interface FYAppleView()
@property (nonatomic,strong) UILabel *nameLabel;
@end

@implementation FYAppleView
-(instancetype)initWithFrame:(CGRect)frame{
    if (self =[super initWithFrame:frame]) {
        _nameLabel=[[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
        [self addSubview:_nameLabel];
    }
    return self;
}
/*
  mvc的变种
 */
- (void)setModel:(FYItemModel *)model{
    _model = model;
    _nameLabel.textColor = model.bgColor;
    _nameLabel.text = model.name;
}
@end

//FYItemModel
@interface FYItemModel : NSObject
@property (nonatomic,copy) NSString *name;
@property (nonatomic,strong) UIColor *bgColor;
@end


//ViewController
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadViewOtherMVC];
}
//变种MVC 把View和Model建立起连接
//等以后更新view数据只需要 view.model = item;Controllr少了许多代码
- (void)loadViewOtherMVC{
    FYAppleView * view =[[FYAppleView alloc]initWithFrame:CGRectMake(200, 200, 100, 30)];
    FYItemModel *item=[[FYItemModel alloc]init];
    item.name = @"校长来了";
    item.bgColor = [UIColor redColor];
    view.model = item;
    [self.view addSubview:view];
}
@end
```

可以看到`model`组装到`view`展示内容是在`view`实现的，外部不知道细节，只需要将`model`给`view`即可，但是只能传输过来`model`或者他子类，业务更改的话，需要修改`view`的内部`model`才能将变更过的数据重新展示出来。

想要监听view的点击事件来做一些操作，那么我们可以使用代理和`block`,这里`id`是实现了`FYAppleViewProtocol`协议的，`weak`修饰防止循环引用，使用协议实现了和`VC`的通信。

```
@class FYAppleView;
@protocol FYAppleViewProtocol <NSObject>
- (void)FYAppleViewDidClick:(FYAppleView*)view;
@end

@class FYItemModel;
@interface FYAppleView : UIView
@property (nonatomic,strong,readonly) UILabel *nameLabel;
@property (nonatomic,weak) id<FYAppleViewProtocol> delegate;
@property (nonatomic,strong) FYItemModel *model;
@end
```

稍作更改还是`apple-MVC`

```
// .h
@class FYItemModel;
@interface FYAppleView : UIView
@property (nonatomic,strong,readonly) UILabel *nameLabel;
@end
```
将`View`属性`nameLabel`暴露出来，但是不允许外界进行更改，去掉`model`则是`MVC`。



###  MVP

`MVP`和`MVC`很像，只是将`VC`换成了`Presenter`，`vc`和`Present`做的事情基本一致，将`view`和`Model`通信改到了都和`Presenter`通信。

![](/images/13-3.png)
代码

```
//MVP
//.h
@interface FYNewsPresenter : NSObject

@property (nonatomic,weak) UIViewController *vc;
//初始化
- (void)setup;
@end

.m
#import "FYNewsPresenter.h"
@interface FYNewsPresenter()<FYAppleViewProtocol>
@end

@implementation FYNewsPresenter
- (void)setup{
	FYAppleView * view =[[FYAppleView alloc]initWithFrame:CGRectMake(200, 200, 100, 30)];
	FYItemModel *item=[[FYItemModel alloc]init];
	item.name = @"校长来了";
	item.bgColor = [UIColor redColor];
	view.model = item;
	[self.vc.view addSubview:view];
}
- (void)FYAppleViewDidClick:(FYAppleView *)view{
	NSLog(@"点击了我");
}
@end


//VC中
@interface ViewController ()
@property (nonatomic,strong) FYNewsPresenter *presenter;
@end

- (void)viewDidLoad {
    [super viewDidLoad];
	_presenter=[FYNewsPresenter new];
	_presenter.vc = self;
	[_presenter setup];
}
@end
```
再次对`VC`进行了瘦身，将更多的业务逻辑搬到了`FYNewsPresenter`处理，其实全部搬过去，意义比不大，`FYNewsPresenter`也会臃肿，也会出现和`VC`一样的困惑。

###  MVVM
`MVVM`是将`FYNewsPresenter`都搬到了`FYNewsViewModel`中，然后对`FYNewsViewModel`和`View`进行了一个双向绑定，双向绑定可以使用代理，`block`或者`KVO`实现。
![](/images/13-4.png)
代码实现

```
@interface FYNewsViewModel : NSObject

@property (nonatomic,copy) NSString *name;
@property (nonatomic,strong) UIColor *bgColor;

@property (nonatomic,weak) UIViewController *vc;

- (instancetype)initWithController:(UIViewController *)vc;
@end



#import "FYNewsViewModel.h"
@interface FYNewsViewModel()<FYAppleViewProtocol>


@end
@implementation FYNewsViewModel
- (instancetype)initWithController:(UIViewController *)vc{
    if (self =[super init]) {
        self.vc = vc;
        
        FYAppleView * view =[[FYAppleView alloc]initWithFrame:CGRectMake(100, 200, 100, 50)];
        //    view.model = item;
        view.delegate = self;
        view.viewModel = self; //建立kvo
        
        view.backgroundColor = [UIColor lightGrayColor];
        [vc.view addSubview:view];
        
        
        
        FYItemModel *item=[[FYItemModel alloc]init];
        item.name = @"校长来了";
        item.bgColor = [UIColor redColor];
        
        self.name = item.name;
        self.bgColor = item.bgColor;
    }
    return self;
}
- (void)FYAppleViewDidClick:(FYAppleView *)view{
	NSLog(@"点击了我");
}
@end
```
在`view`实现

```
@class FYAppleView,FYNewsViewModel;
@protocol FYAppleViewProtocol <NSObject>

- (void)FYAppleViewDidClick:(FYAppleView*)view;

@end

@class FYItemModel;

@interface FYAppleView : UIView
@property (nonatomic,strong,readonly) UILabel *nameLabel;

@property (nonatomic,weak) id<FYAppleViewProtocol> delegate;
@property (nonatomic,weak) FYNewsViewModel *viewModel;

@property (nonatomic,strong) FYItemModel *model;
@end


@interface FYAppleView()
@property (nonatomic,strong) UILabel *nameLabel;
@end
@implementation FYAppleView
-(instancetype)initWithFrame:(CGRect)frame{
    if (self =[super initWithFrame:frame]) {
        _nameLabel=[[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
        [self addSubview:_nameLabel];
    }
    return self;
}
/*
  mvc的变种
 */
- (void)setModel:(FYItemModel *)model{
    _model = model;
    _nameLabel.textColor = model.bgColor;
    _nameLabel.text = model.name;
	
 
}

- (void)setViewModel:(FYNewsViewModel *)viewModel{
    _viewModel = viewModel;
   [_viewModel addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
   //使用FBKVO实现 或者自己使用KVO实现
//    __weak typeof(self) waekSelf = self;
//    [self.KVOController observe:viewModel keyPath:@"name"
//                        options:NSKeyValueObservingOptionNew
//                          block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSKeyValueChangeKey,id> * _Nonnull change) {
//        waekSelf.nameLabel.text = change[NSKeyValueChangeNewKey];
//    }];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"name"]) {
        self.nameLabel.text = change[NSKeyValueChangeNewKey];
    }
}

//添加点击事件
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
	if ([self.delegate respondsToSelector:@selector(FYAppleViewDidClick:)]) {
		[self.delegate FYAppleViewDidClick:self];
	}
}

-(void)dealloc{
    [_viewModel removeObserver:self
                    forKeyPath:@"name"];
}
@end
```
使用`KVO`或者`FBKVO`或者`RAC`都是可以的，本章节例子给出了`FBKVO`或者自己使用`KVO`的实现。



### 分层设计
三层架构：
> 三层架构(3-tier architecture) 通常意义上的三层架构就是将整个业务应用划分为：界面层（User Interface layer）、业务逻辑层（Business Logic Layer）、数据访问层（Data access layer）。区分层次的目的即为了“高内聚低耦合”的思想。在软件体系架构设计中，分层式结构是最常见，也是最重要的一种结构。微软推荐的分层式结构一般分为三层，从下至上分别为：数据访问层、业务逻辑层（又或称为领域层）、表示层

- 目的: “高内聚，低耦合”的思想 

- 优点: 降低层与层之间的依赖 标准化 

- 缺点: 系统架构复杂，不适合小型项目

#### 三层原理
> 3个层次中，系统主要功能和业务逻辑都在业务逻辑层进行处理。
所谓三层体系结构，是在客户端与数据库之间加入了一个`中间层`，也叫组件层。这里所说的三层体系，不是指物理上的三层，不是简单地放置三台机器就是三层体系结构，也不仅仅有`B/S`应用才是三层体系结构，三层是指逻辑上的三层，即把这三个层放置到一台机器上。

> 三层体系的应用程序将业务规则、数据访问、合法性校验等工作放到了中间层进行处理。通常情况下，客户端不直接与数据库进行交互，而是通过`COM/DCOM`通讯与中间层建立连接，再经由中间层与数据库进行交互。

> 三层架构中主要功能与业务逻辑一般要在业务逻辑层进行信息处理和实现，其中三层体系架构中的客户端和数据库要预设中间层，成为组建层。三层架构中的三层具有一定的逻辑性，即是将三层设置到同一个计算机系统中，把业务协议、合法校验以及数据访问等程序归置到中间层进行信息处理，一般客户端无法和数据库进行数据传输，主要是利用`COM/DCOM`通讯和中间层构建衔接通道，实现中间层与数据库的数据传输，进而实现客户端与是数据库的交互

`MVC`、`MVVM`、`MVP`属于界面层，
当业务复杂，网络请求和db操作达到了一个新的高度，界面复杂到需要好多人来做，那么界面、业务、数据需要分层了

分层之后，得到了一个三层架构或四层架构

![三层架构](/images/13-5.png)

数据层也可以分为两层，分为网络请求和db层。

![四层架构](/images/13-6.png)

具体在工程中我们通常这样体现

![](/images/13-7.png)

在`vc`中获取数据

```
@interface ViewController ()
@property (nonatomic,strong) FYDBPool *db;
@property (nonatomic,strong) FYHttpPool *http;
@end

@implementation ViewController
- (void)viewDidLoad {
	[super viewDidLoad];

	//当有业务层
	[[FYNewsService new] loadNewsWithInfo:nil success:^(NSArray * _Nonnull) {
		
	} fail:^{
		
	}];
	//当没有有业务层
	self.db=[FYDBPool new];
	self.http=[FYHttpPool new];
	[self.db loadNewsWithInfo:@{} success:^(NSArray * _Nonnull ret) {
		if ([ret count]) {
			NSLog(@"数据获取成功");
		}else{
			[self.http loadNewsWithInfo:@{} success:^(NSArray * _Nonnull ret) {
				NSLog(@"数据获取成功");
			} fail:^{
				NSLog(@"数据获取失败");
			}];
		}
	} fail:^{
		[self.http loadNewsWithInfo:@{} success:^(NSArray * _Nonnull ret) {
			NSLog(@"数据获取成功");
		} fail:^{
			NSLog(@"数据获取失败");
		}];
	}];
}

```
在业务层

```
@interface FYNewsService ()
@property (nonatomic,strong) FYDBPool *db;
@property (nonatomic,strong) FYHttpPool *http;

@end
@implementation FYNewsService
-(instancetype)init{
	if (self = [super init]) {
		self.db=[FYDBPool new];
		self.http=[FYHttpPool new];
	}
	return self;
}
- (void)loadNewsWithInfo:(NSDictionary *)info
				 success:(succcessCallback )succblock
					fail:(dispatch_block_t)failBlock{
	[self.db loadNewsWithInfo:info success:^(NSArray * _Nonnull ret) {
		if ([ret count]) {
			succblock(ret);
		}else{
			[self.http loadNewsWithInfo:info success:^(NSArray * _Nonnull ret) {
				succblock(ret);
			} fail:failBlock];
		}
	} fail:^{
		[self.http loadNewsWithInfo:info success:^(NSArray * _Nonnull ret) {
			succblock(ret);
		} fail:failBlock];
	}];
}
@end
```
在db层

```
typedef void(^succcessCallback)(NSArray *);
@interface FYDBPool : NSObject
- (void)loadNewsWithInfo:(NSDictionary *)info
				 success:(succcessCallback )succblock
					fail:(dispatch_block_t)failBlock;
@end
```
在网络请求层

```
typedef void(^succcessCallback)(NSArray *);
@interface FYHttpPool : NSObject
- (void)loadNewsWithInfo:(NSDictionary *)info
				 success:(succcessCallback )succblock
					fail:(dispatch_block_t)failBlock;
@end
```

分层目的是瘦身，逻辑清晰，业务清晰，降低耦合，当某一块足够复杂时候，都可以进行分层，不局限于网络或`db`，当`db`足够复杂，也需要进行一个分层来解决复杂调用和处理的问题。
不同的人来处理不同的分层，相互影响也比较小，降低耦合。


**当逻辑层足够完善，则UI层如何变动都不需要更改逻辑层。**

### 后记
优雅的代码总是伴随着各种传统设计模式的搭配
#### 设计模式
> 设计模式（Design Pattern）
是一套被反复使用、代码设计经验的总结
使用设计模式的好处是：可重用代码、让代码更容易被他人理解、保证代码可靠性
一般与编程语言无关，是一套比较成熟的编程思想

设计模式可以分为三大类
1. 创建型模式：对象实例化的模式，用于解耦对象的实例化过程
单例模式、工厂方法模式，等等

2. 结构型模式：把类或对象结合在一起形成一个更大的结构
代理模式、适配器模式、组合模式、装饰模式，等等

3. 行为型模式：类或对象之间如何交互，及划分责任和算法
观察者模式、命令模式、责任链模式，等等


### 总结
- 适合项目的才是最好的架构

### 资料参考
- [三层架构](https://baike.baidu.com/item/%E4%B8%89%E5%B1%82%E6%9E%B6%E6%9E%84)
### 资料下载
- [学习资料下载git](https://github.com/ifgyong/iOSDataFactory)
- [demo code git](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码git](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](/images/0.png)