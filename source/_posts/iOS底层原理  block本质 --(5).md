---
title: iOS底层原理  block本质 --(5)
tags:
  - iOS
categories: iOS
abbrlink: 56eded6e
date: 2019-12-01 11:15:58
---

本章讲解block的用法和底层数据结构，以及使用过程中需要注意的点。

### block本质

前几篇文章讲过了，`class`是对象，元类也是对象，本质是结构体，那么block是否也是如此呢？`block`具有这几个特点：/

- block本质上也是一个OC对象，它内部也有isa指针
- block是封装了函数调用以及函数调用环境的oc对象

先简单来看一下`block`编译之后的样子

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void (^block)(void) = ^(void){
            NSLog(@"hello word");
        };
        block();

    }
    return 0;
}
```

命令行执行`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.mm -o main.cpp`,来到`main.cpp`内部，已经去除多余的转化函数，剩余骨架，可以看得更清晰。

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    //构造函数 类似OC init函数
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;//block类型
    impl.Flags = flags;
    impl.FuncPtr = fp;// 执行函数的地址
    Desc = desc;//desc 存储 __main_block_desc_0（0，sizeof(__main_block_impl_0)）的值
  }
};
    //block 内部代码封装成函数
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_main_b7cca8_mii_0);
        }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;//存储结构体占用空间的大小
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
//定义block
        void (*block)(void) = &__main_block_impl_0(__main_block_func_0, &__main_block_desc_0_DATA);
        //执行block
        block->FuncPtr(block);
    }
    return 0;
}
```

最终`block`转化成`__main_block_impl_0`结构体，赋值给变量`block`，传入参数是`__main_block_func_0`和`__main_block_desc_0_DATA`来执行`__main_block_impl_0`的构造函数，`__main_block_desc_0_DATA`函数赋值给`__main_block_impl_0->FuncPtr`，执行函数是`block->FuncPtr(block)`，删除冗余代码之前是`((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
`，那么为什么`block`可以直接强制转化成`__block_impl`呢？因为`__main_block_impl_0`结构体的第一行变量是`__block_impl`，相当于`__main_block_impl_0`的内存地址和`__block_impl`的内存地址一样，强制转化也不会有问题。
### 变量捕获
变量捕获分为3种：

|变量类型|是否会捕获到block内部|访问方式|内部变量假定是a|
|--------|-------|------|-----|
|局部变量 auto|会|值传递|a|
|局部变量 static|会|指针传递|*a|
|全局变量|不会|直接访问|空|

#### auto变量捕获

`auto` 变量，一般`auto`是省略不写的，访问方式是值传递，关于值传递不懂的话可以看[这篇博客](https://www.google.com/search?q=%E5%80%BC%E4%BC%A0%E9%80%92&oq=%E5%80%BC%E4%BC%A0%E9%80%92&aqs=chrome..69i57.5169j0j4&sourceid=chrome&ie=UTF-8)，
看下这个例子

```
int age = 10;
void (^block)(void) = ^(void){
    NSLog(@"age is %d",age);
};
age = 20;
block();
//实际输出是 age is 10
```

有没有疑问呢？在`block`执行之前`age =20`，为什么输出是10呢？
将这段代码转化成`c/c++`，如下所示：

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  int age;//多了一个变量age,存储值是10
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  int age = __cself->age; // bound by copy

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_main_baf352_mii_0,age);
        }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        int age = 10;
        void (*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, age));
        age = 20;
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);

    }
    return 0;
}
```

结构体`__main_block_impl_0`多了一个变量`age`，在`block`转化成`c`函数的时候`__main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _age, int flags=0) : age(_age)`直接将age的值存储在`__main_block_impl_0.age`中，此时`__main_block_impl_0.age`是存储在堆上的，之前的`age`是存储在数据段的，执行`block`访问的变量是堆上的``__main_block_impl_0.age`,所以最终输出来`age is 10`。


#### static变量捕获
我们通过一个例子来讲解static和auto区别：

```
void(^block)(void);
void test(){
    int age = 10;
    static int level = 12;
    block = ^(void){
        NSLog(@"age is %d,level is %d",age,level);
    };
    age = 20;
    level = 13;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        test();
        block();
    }
    return 0;
}

//输出：age is 10,level is 13
```

转化成源码：

```
void(*block)(void);

struct __test_block_impl_0 {
  struct __block_impl impl;
  struct __test_block_desc_0* Desc;
  int age;
  int *level;
  __test_block_impl_0(void *fp, struct __test_block_desc_0 *desc, int _age, int *_level, int flags=0) : age(_age), level(_level) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __test_block_func_0(struct __test_block_impl_0 *__cself) {
  int age = __cself->age; // bound by copy
  int *level = __cself->level; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_main_b26797_mii_0,age,(*level));
    }

static struct __test_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __test_block_desc_0_DATA = { 0, sizeof(struct __test_block_impl_0)};
void test(){
    int age = 10;
    static int level = 12;
    block = ((void (*)())&__test_block_impl_0((void *)__test_block_func_0, &__test_block_desc_0_DATA, age, &level));
    age = 20;
    level = 13;
}

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        test();
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

当执行完`test()`函数，`age`变量已经被收回，但是`age`的值存储在`block`结构体中，`level`的地址存储在`__test_block_impl_0.level`,可以看到`level`类型是指针类型，读取值的时候也是`*level`，则不管什么时间改动`level`的值，读`level`的值都是最新的，因为它是从地址直接读的。所以结果是`age is 10,level is 13`。

#### 全局变量

全局不用捕获的，访问的时候直接访问。我们来测试下

```
int age = 10;
static int level = 12;
int main(int argc, const char * argv[]) {
    @autoreleasepool {

        void(^block)(void) = ^(void){
            NSLog(@"age is %d,level is %d",age,level);
        };
        age = 20;
        level = 13;
        block();
    }
    return 0;
}
```

转化成`c/c++`

```
int age = 10;
static int level = 12;

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {

            NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_main_45cab9_mii_0,age,level);
        }

static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
        age = 20;
        level = 13;
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

可以看出来编译之后仅仅是多了两行`int age = 10;
static int level = 12;`，结构体`__main_block_impl_0`内部和构造函数并没有专门来存储值或者指针，原因是当执行`__main_block_func_0`，可以直接访问变量`age `和 `level`，因为全局变量有效区域是全局，不会出了`main`函数就消失。
**基本概括来讲就是超出执行区域与可能消失的会捕获，一定不会消失的不会捕获。**

我们再看下更复杂的情况，对象类型的引用是如何处理的？

```
@interface FYPerson : NSObject
@property (nonatomic,copy) NSString * name;
@end

@implementation FYPerson
- (void)test{
    void (^block)(void) = ^{
        NSLog(@"person is %@",self);
    };
    
    void (^block2)(void) = ^{
        NSLog(@"name is %@",_name);
    };
}
@end




struct __FYPerson__test_block_impl_0 {
  struct __block_impl impl;
  struct __FYPerson__test_block_desc_0* Desc;
  FYPerson *self;
  __FYPerson__test_block_impl_0(void *fp, struct __FYPerson__test_block_desc_0 *desc, FYPerson *_self, int flags=0) : self(_self) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __FYPerson__test_block_func_0(struct __FYPerson__test_block_impl_0 *__cself) {
  FYPerson *self = __cself->self; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_FYPerson_c624e0_mi_0,self);
    }
static void __FYPerson__test_block_copy_0(struct __FYPerson__test_block_impl_0*dst, struct __FYPerson__test_block_impl_0*src) {_Block_object_assign((void*)&dst->self, (void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __FYPerson__test_block_dispose_0(struct __FYPerson__test_block_impl_0*src) {_Block_object_dispose((void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __FYPerson__test_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __FYPerson__test_block_impl_0*, struct __FYPerson__test_block_impl_0*);
  void (*dispose)(struct __FYPerson__test_block_impl_0*);
} __FYPerson__test_block_desc_0_DATA = { 0, sizeof(struct __FYPerson__test_block_impl_0), __FYPerson__test_block_copy_0, __FYPerson__test_block_dispose_0};

struct __FYPerson__test_block_impl_1 {
  struct __block_impl impl;
  struct __FYPerson__test_block_desc_1* Desc;
  FYPerson *self;
  __FYPerson__test_block_impl_1(void *fp, struct __FYPerson__test_block_desc_1 *desc, FYPerson *_self, int flags=0) : self(_self) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __FYPerson__test_block_func_1(struct __FYPerson__test_block_impl_1 *__cself) {
  FYPerson *self = __cself->self; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_FYPerson_c624e0_mi_1,(*(NSString * _Nonnull *)((char *)self + OBJC_IVAR_$_FYPerson$_name)));
    }
static void __FYPerson__test_block_copy_1(struct __FYPerson__test_block_impl_1*dst, struct __FYPerson__test_block_impl_1*src) {_Block_object_assign((void*)&dst->self, (void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __FYPerson__test_block_dispose_1(struct __FYPerson__test_block_impl_1*src) {_Block_object_dispose((void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __FYPerson__test_block_desc_1 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __FYPerson__test_block_impl_1*, struct __FYPerson__test_block_impl_1*);
  void (*dispose)(struct __FYPerson__test_block_impl_1*);
} __FYPerson__test_block_desc_1_DATA = { 0, sizeof(struct __FYPerson__test_block_impl_1), __FYPerson__test_block_copy_1, __FYPerson__test_block_dispose_1};

static void _I_FYPerson_test(FYPerson * self, SEL _cmd) {
    void (*block)(void) = ((void (*)())&__FYPerson__test_block_impl_0((void *)__FYPerson__test_block_func_0, &__FYPerson__test_block_desc_0_DATA, self, 570425344));

    void (*block2)(void) = ((void (*)())&__FYPerson__test_block_impl_1((void *)__FYPerson__test_block_func_1, &__FYPerson__test_block_desc_1_DATA, self, 570425344));
}
```

`block`和`block2`都是结构体`__FYPerson__test_block_impl_1`内部引用了一个`FYPerson`对象指针，`FYPerson`对象属于局部变量，需要捕获。第2个`block`访问`_name`捕捉的也是`FYPerson`对象，访问`_name`，需要先访问`FYPerson`对象，然后再访问`_name`，本质上是访问`person.name`,所以捕捉的是`FYPerson`对象。

#### 验证block是对象类型：

```
//ARC环境下
void(^block)(void)=^{
			NSLog(@"Hello, World!");
		};
		NSLog(@"自己class：%@ 它爹class:%@  它爷爷class:%@ 它老爷爷的tclass:%@",[block class],[[block class] superclass],[[[block class] superclass]superclass],[[[[block class] superclass]superclass] superclass]);
		//输出是：自己class：__NSGlobalBlock__ 它爹class:__NSGlobalBlock  它爷爷class:NSBlock 它老爷爷的tclass:NSObject
```

可以了解到`block`是继承与基类的，所以`block`也是OC对象。

#### block的分类
`block`有3种类型，如下所示，可以通过调用`class`方法或者`isa`指针查看具体类型，最终都是继承来自`NSBlock`类型。
- __NSGlobalBLock__（_NSConcreteGLobalBlock）
- __NSStackBlock__（_NSConcreteStackBlock）
- __NSMallocBLock__（_NSConcreteMallocBlock）

在应用程序中内存分配是这样子的：

```
---------------
程序区域 .text区
---------------
数据区域 .data区     <--------- _NSConcreteGlobalBlock(存储全局变量)
---------------
堆                  <--------- _NSConcreteMallocBlock(动态申请释放内存区域)
---------------
栈                  <--------- _NSConcreteStackBlock(存储存局部变量)
---------------

```


|block类型|环境|
|---|----|
|__NSGlobalBLock__|没有访问auto变量|
|__NSStackBlock__|访问auto变量|
|__NSMallocBLock__|__NSStackBlock__ 调用copy|



验证需要设置成MRC，找到工程文件，设置`project->Object-C Automatic Reference Counting=`为`NO`

```
int age = 10;

void(^block1)(void)=^{
	NSLog(@"block1");
};
void(^block2)(void)=^{
	NSLog(@"block2 %d",age);
};
void(^block3)(void)=[block2 copy];
NSLog(@"block1:%@   block2:%@ block3:%@ ",[block1 class],[block2 class],[block3 class]);

//输出
block1:__NSGlobalBlock__   
block2:__NSStackBlock__ 
block3:__NSMallocBlock__
```

没有访问`auto`变量的`block`属于`__NSGlobalBlock__`，访问了auto变量的是`__NSStackBlock__`，手动调用了`copy`的`block`属于`__NSMallocBlock__`。`__NSMallocBlock__`是在堆上，需要程序员手动释放`[block3 release];`，不释放会造成内存泄露。



每一种类型的`block`调用`copy`后的结果如下

|block类型|副本源的配置存储域|复制效果|
|---|----|---------|
|__NSGlobalBLock__|堆|从栈复制到堆|
|__NSStackBlock__|程序的数据区域|什么也不做|
|__NSMallocBLock__|堆|引用计数+1|

#### 在ARC环境下，编译器会根据自身情况自动将栈上的block复制到堆上，比如下列情况

- block作为函数返回值时
- 将block赋值给__strong指针时
- block作为Cocoa API中方法名含有usingBlock的方法参数时
- block作为GCD API的方法参数时


在ARC环境下测试:

```
typedef void (^FYBlock)(void);
typedef void (^FYBlockInt)(int);
FYBlock myBlock(){
	return ^{
		NSLog(@"哈哈");
	};
};
FYBlock myBlock2(){
	int age = 10;
	return ^{
		NSLog(@"哈哈 %d",age);
	};
};
int main(int argc, const char * argv[]) {
	@autoreleasepool {
		FYBlock block = myBlock();
		FYBlock block2 = myBlock2();
		int age = 10;
		FYBlock block3= ^{
			NSLog(@"强指针block %d",age);
		};
		NSLog(@"没访问变量:%@ 访问布局变量：%@ 强指针:%@",[block class],[block2 class],[block3 class]);
	}
	return 0;
}
//输出
没访问变量:__NSGlobalBlock__ 
访问局部变量：__NSMallocBlock__ 
强指针:__NSMallocBlock__
```

`arc`环境下，没访问变量的`block`是`__NSGlobalBlock__`，访问了局部变量是`__NSMallocBlock__`,有强指针引用的是`__NSMallocBlock__`,强指针系统自动执行了copy操作，由栈区复制到堆区，由系统管理改为开发者手动管理。

**所以有以下建议：**

MRC下block属性的建议写法
- @property (copy, nonatomic) void (^block)(void);

ARC下block属性的建议写法
- @property (strong, nonatomic) void (^block)(void);
- @property (copy, nonatomic) void (^block)(void);


### 对象类型数据和block交互

平时我们使用`block`，对象类型来传递数据的比较多，对象类型读取到`block`中用`__block`修饰符，会把对象地址直接读取到`block`结构体内，`__weak`修饰的对象是弱引用，默认是强引用，我们看下这段代码

```
//FYPerson.h
@interface FYPerson : NSObject
@property (nonatomic,assign) int age;
@end

//FYPerson.m
@implementation FYPerson
@end

//main.m
typedef void (^FYBlock)(void);

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		FYBlock block ;
			FYPerson *person = [[FYPerson alloc]init];
			person.age = 10;
		__weak typeof(person) __weakPerson = person;
			block = ^{
				NSLog(@" %d",__weakPerson.age);
			};
		
		block();
	}
	return 0;
}
```

使用下面该命令转化成`cpp`

```
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m -o main.cpp
```

摘取关键结构体代码：

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  FYPerson *__weak __weakPerson;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, FYPerson *__weak ___weakPerson, int flags=0) : __weakPerson(___weakPerson) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  FYPerson *__weak __weakPerson = __cself->__weakPerson; // bound by copy

    NSLog((NSString *)&__NSConstantStringImpl__var_folders_c0_7nm4_r7s4xd0mbs67ljb_b8m0000gn_T_main_7f0272_mi_0,((int (*)(id, SEL))(void *)objc_msgSend)((id)__weakPerson, sel_registerName("age")));
   }
```

`FYPerson *__weak __weakPerson`是`__weak`修饰的对象
当block内部换成`block = ^{
				NSLog(@" %d",person.age);
			};`，转换源码之后是

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  FYPerson *__strong person;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, FYPerson *__strong _person, int flags=0) : person(_person) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

`person`默认是使用`__storng`来修饰的，`arc`中，`block`引用外界变量，系统执行了`copy`操作，将`block` `copy`到堆上，由开发者自己管理，转`c/c++`中结构体描述为

```
static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)

static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->__weakPerson, (void*)src->__weakPerson, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->__weakPerson, 3/*BLOCK_FIELD_IS_OBJECT*/);}


```

有对象的使用，则有内存管理，既然是arc，则是系统帮开发者管理内存，函数`void (*copy)`和`void (*dispose)`就是对block的引用计数的`+1`和`-1`。

如果block被拷贝到堆上

- 会调用block内部的copy函数
- copy函数内部会调用_Block_object_assign函数
- _Block_object_assign函数会根据auto变量的修饰符（__strong、__weak、__unsafe_unretained）做出相应的操作，形成强引用（retain）或者弱引用

如果block从堆上移除
- 会调用block内部的dispose函数
- dispose函数内部会调用_Block_object_dispose函数
- _Block_object_dispose函数会自动释放引用的auto变量（release，引用计数-1，若为0，则销毁）

|函数|调用时机|
|:-:|:-:|
|copy函数|栈上的Block复制到堆时|
|dispose函数|堆上的Block被废弃时|

#### 题目
person什么时间释放？

```
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
FYPerson *person = [[FYPerson alloc]init];
person.age = 10;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	NSLog(@"---%d",person.age);
});
}
```

3s后释放，`dispatch`对`block`强引用，`block`强引用`person`，在`block`释放的时候，`person`没其他的引用，就释放掉了。

变换1：`person`什么时间释放

```
FYPerson *person = [[FYPerson alloc]init];
person.age = 10;
__weak FYPerson *__weakPerosn = person;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	NSLog(@"---%d",__weakPerosn.age);
});
```

`__weak`没有对`perosn`进行强引用，咋执行完dispatch_block则立马释放，答案是立即释放。
变换2：`person`什么时间释放

```
FYPerson *person = [[FYPerson alloc]init];
person.age = 10;
__weak typeof(person) __weakPerson = person;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	NSLog(@"---%d",__weakPerson.age);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSLog(@"---%d",person.age);
	});
});
```

`person`被内部`block`强引用，则`block`销毁之前`person`不会释放，`__weakPerson`执行完`person`不会销毁，`NSLog(@"---%d",person.age)`执行完毕之后，`person`销毁。答案是4秒之后`NSLog(@"---%d",person.age)`执行完毕之后，`person`销毁。

变换3：`person`什么时间释放

```
FYPerson *person = [[FYPerson alloc]init];
person.age = 10;
__weak typeof(person) __weakPerson = person;
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	NSLog(@"---%d",person.age);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSLog(@"---%d",__weakPerson.age);
	});
});
```

`person`被强引用于第一层`block`，第二层弱引用`person`，仅仅当第一层block执行完毕的时候，`person`释放。



#### 修改block外部变量
想要修改变量，首先要变量的有效区域，或者block持有变量的地址。
例子1：

```
int age = 10;
FYBlock block = ^{
    age = 20;//会报错
};
```

报错的原因是`age`是值传递，想要不报错只需要将`int age = 10`改成`static int age = 10`，就由值传递变成地址传递，有了`age`的地址，在`block`的内部就可以更改`age`的值了。或者将`int age = 10`改成全局变量，全局变量在`block`中不用捕获，`block`本质会编译成`c`函数，`c`函数访问全局变量在任意地方都可以直接访问。

#### __block本质
`__block`本质上是修饰的对象或基本类型，编译之后会生成一个结构体`__Block_byref_age_0`,结构体中`*__forwarding`指向结构体自己，通过
`(age->__forwarding->age) = 20`来修改变量的值。

```
struct __Block_byref_age_0 {
  void *__isa;
__Block_byref_age_0 *__forwarding;
 int __flags;
 int __size;
 int age;//10
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __Block_byref_age_0 *age; // by ref
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_age_0 *_age, int flags=0) : age(_age->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  __Block_byref_age_0 *age = __cself->age; // bound by ref
            (age->__forwarding->age) = 20;
            NSLog((NSString *)&__NSConstantStringImpl__var_folders_5p_cwsr3ytd5md9r_kgb2fv_2c40000gn_T_main_043d00_mi_0,(age->__forwarding->age));
        }
```

`age`在`block`外部有一个，在`block`内部有一个，他们是同一个吗？我们来探究一下：

```
typedef   void (^FYBlock)(void);
struct __Block_byref_age_0 {
    void *__isa;
    struct __Block_byref_age_0 *__forwarding;
    int __flags;
    int __size;
    int age;//10
};
struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(void);
    void (*dispose)(void);
};
struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    struct __Block_byref_age_0 *age; // by ref
};

int main(int argc, const char * argv[]) {
	@autoreleasepool {
	    // insert code here...
	__block	int age = 10;
        NSLog(@" age1:%p",&age);
        FYBlock block = ^{
            age = 20;
            NSLog(@"age is %d",age);
        };
        struct __main_block_impl_0 *main= (__bridge struct __main_block_impl_0 *)block;
        NSLog(@" age1:%p age2:%p",&age,&(main->age->__forwarding->age));
	}
	return 0;
}
输出：
age1:0x7ffeefbff548
age1:0x100605358 age2:0x100605358
```

经过`__block`修饰之后，之后访问的`age`和结构体`__Block_byref_age_0`中的`age`地址是一样的，可以判定`age`被系统`copy`了一份。

例子：

```
	__block	int age = 10;
        NSLog(@" age1:%p",&age);
        NSObject *obj=[[NSObject alloc]init];
        FYBlock block = ^{
            
            NSLog(@"age is %d,obj is %p",age,&obj);
        };
```

使用命令编译

```
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m
```

摘录主要函数：

```
struct __Block_byref_age_0 {
  void *__isa;
__Block_byref_age_0 *__forwarding;
 int __flags;
 int __size;
 int age;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  NSObject *__strong obj;
  __Block_byref_age_0 *age; // by ref
};
``` 

`__main_block_impl_0`结构体对`age`进行了一个强引用并持有该结构体的地址，将`age`复制到了堆上，`age`转化成`__Block_byref_age_0`对象，`__main_block_impl_0`可以对`__Block_byref_age_0->__forwarding->age`进行赋值。`__Block_byref_age_0`既然是对象，就需要内存管理，`__main_block_copy_0`出现了`_Block_object_assign`和`_Block_object_dispose`对`__Block_byref_age_0`进行内存管理的代码。

```
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
    _Block_object_assign((void*)&dst->age, (void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);
    _Block_object_assign((void*)&dst->obj, (void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}
    
    static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);
    _Block_object_dispose((void*)src->obj, 3/*BLOCK_FIELD_IS_OBJECT*/);}
```

`age`和`obj`是一个对象结构体，`obj`只是一个强引用而没有地址变换原因是`obj`本身就在堆上，`block`也在堆上，故无需复制出新的`obj`来进行管理。

看一下循环引用是反面教材

```
typedef   void (^FYBlock)(void);
@interface FYPerson : NSObject

@property (nonatomic,copy) FYBlock blcok;
@end

@implementation FYPerson
- (void)dealloc{
	NSLog(@"%s",__func__);
}
@end


int main(int argc, const char * argv[]) {
	@autoreleasepool {
        NSLog(@" age1:%p",&age);
        FYPerson *obj=[[FYPerson alloc]init];
		[obj setBlcok:^{
			NSLog(@"%p",&obj);
		}];
		NSLog(@"--------------");
	}
	return 0;
}
```

输出是：

```
age1:0x7ffeefbff4e8
block 执行完毕--------------
```

`obj`通过`copy`操作强引用`block`,`block`通过默认`__strong`强制引用`obj`,这就是`A<---->B`，相互引用导致执行结束应该释放的时候无法释放。
将`main`改成

```
FYPerson *obj=[[FYPerson alloc]init];
		__weak typeof(obj) weakObj = obj;
		[obj setBlcok:^{
			NSLog(@"%p",&weakObj);
		}];
```

结果是

```
age1:0x7ffeefbff4e8
block 执行完毕--------------
-[FYPerson dealloc]
```

使用`__weak`或`__unsafe__unretain`弱引用`obj`,在`block`执行完毕的时候，`obj`释放，`block`释放，无相互强引用，正常释放。
#### `__weak`和`__unsafe__unretain`
`__weak`和`__unsafe__unretain`都是弱引用`obj`,都是不影响`obj`正常释放，区别是`__weak`在释放之后会将值为nil，`__unsafe__unretain`不对该内存处理。
下面我们来具体验证一下该结论：

```
typedef   void (^FYBlock)(void);
@interface FYPerson : NSObject
@property (nonatomic,assign) int age ;
@end
@implementation FYPerson
-(void)dealloc{
	NSLog(@"%s",__func__);
}
@end
struct __Block_byref_age_0 {
	void *__isa;
	struct __Block_byref_age_0 *__forwarding;
	int __flags;
	int __size;
	int age;
};
struct __block_impl {
	void *isa;
	int Flags;
	int Reserved;
	void *FuncPtr;
};
struct __main_block_desc_0 {
	size_t reserved;
	size_t Block_size;
	void (*copy)(void);
	void (*dispose)(void);
};
struct __main_block_impl_0 {
	struct __block_impl impl;
	struct __main_block_desc_0* Desc;
	FYPerson *__unsafe_unretained __unsafe_obj;
};

int main(int argc, const char * argv[]) {
	@autoreleasepool {
	    // insert code here...
		FYBlock block;
		{
			FYPerson *obj=[[FYPerson alloc]init];
			obj.age = 5;
			__weak typeof(obj) __unsafe_obj = obj;
			block = ^{
				
				NSLog(@"obj->age is %d obj:%p",__unsafe_obj.age,&__unsafe_obj);
			};
			struct __main_block_impl_0 *suct = (__bridge struct __main_block_desc_0 *)block;
			NSLog(@"inside struct->obj:%p",suct->__unsafe_obj);//断点1
		}
		struct __main_block_impl_0 *suct = (__bridge struct __main_block_desc_0 *)block;
		NSLog(@"outside struct->obj:%p",suct->__unsafe_obj);//断点2
		block();
		NSLog(@"----end------");
	}
	return 0;
}
```

根据文中提示断点1处使用`lldb`打印`obj`命令

```
(lldb) p suct->__unsafe_obj->_age
(int) $0 = 5 //年龄5还是存储在这里的
inside struct->obj:0x102929d80

```

在断点2处再次查看`obj`的值，报错不可读取该内存

```
-[FYPerson dealloc]
outside struct->obj:0x0
p suct->__unsafe_obj->_age
error: Couldn't apply expression side effects : Couldn't dematerialize a result variable: couldn't read its memory
```

已经超出了`obj`的有效范围，`obj`已经重置为nil，也就是`0x0000000000000000`。
上文代码`__weak`改为`__unsafe_unretained`再次在`obj`断点1查看地址：

```
(lldb) p suct->__unsafe_obj->_age
(int) $0 = 5
inside struct->obj:0x10078c0c0

```

在断点2出再次查看地址并查看`age`的值

```
-[FYPerson dealloc]
outside struct->obj:0x10078c0c0
(lldb) p suct->__unsafe_obj->_age
(int) $1 = 5
```

`__unsafe_unretained`在`obj`销毁之后内存并没有及时重置为空。


当我们离开某个页面需要再执行的操作，那么我们改怎么办？
实际应用A:

```
-(void)test{
	__weak typeof(self) __weakself = self;
	[self setBlcok:^{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			NSLog(@"perosn :%p",__weakself);
		});
	}];
	self.blcok();
}

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		{
        	FYPerson *obj=[[FYPerson alloc]init];
			[obj test];
			NSLog(@"block 执行完毕--------------");
		}
		NSLog(@"person 死了");
	}
	return 0;
}
输出：
block 执行完毕--------------
-[FYPerson dealloc]
person 死了
```

猛的一看，哪里都对！使用`__weak`对`self`进行弱引用，不会导致死循环，在`self`死的时候，`block`也会死，就会导致一个问题，`self`和`block`共存亡，但是这个需要3秒后再执行，3秒后，`self`已经死了，`block`也死了，显然不符合我们的业务需求。
那么我们剥离`block`和`self`的关系，让`block`强引用`self`,`self`不持有`block`就能满足业务了。如下所示：

```
    __block typeof(self) __weakSelf = self;//__block或者没有修饰符
    dispatch_async(dispatch_get_main_queue(), ^{
        sleep(2);
        NSLog(@"obj:%@",__weakSelf->_obj);
    });
//perosn :0x0
```

当`self`不持用`block`的时候，`block`可以强引用`self`,`block`执行完毕自己释放，也会释放`self`，当`self`持有`block`，`block`必须弱引用`self`,则释放`self`,`block`也会释放，否则会循环引用。


### 总结
- `block`本质是一个封装了函数调用以及调用环境的`结构体`对象
- `__block`修饰的变量会被封装成`结构体`对象，之前在数据段的会被复制到堆上，之前在堆上的则不受影响，解决`auto`对象在`block`内部无法修改的问题，在`MRC`环境下,`__block`不会对变量产生强引用.
- `block`不使用`copy`则不会从全局或者栈区域移动到堆上，使用`copy`之后有由发者管理
- 使用`block`要注意不能产生循环引用，引用不能变成一个环，主动使其中一个引用成弱引用，则不会产生循环引用。
- `__weak`修饰的对象，`block`不会对对象强引用，在执行`block`的时候有可能会值已经被系统置为`nil`,`__unsafe_unretained`修饰的销毁之后内存不会及时重置为空。


我们看的`cpp`是编译之后的代码，`runtime`是否和我们看到的一致呢？请听下回分解。

#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

 本文章之所以图片比较少，我觉得还是跟着代码敲一遍，印象比较深刻。

 ---
最怕一生碌碌无为，还安慰自己平凡可贵。










广告时间

![](/images/0.png)


