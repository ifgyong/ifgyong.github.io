title: iOS底层原理 runtime - super、hook、以及简单应用--(8)
date: 2019-12-1 11:18:58
tags:
- iOS
categories: iOS
---

### 关键字 super
关键字`super`,在调用`[super init]`的时候，`super`会转化成结构体`__rw_objc_super`

```
struct __rw_objc_super { 
	struct objc_object *object; //消息接受者
	struct objc_object *superClass; //父类
	__rw_objc_super(struct objc_object *o, struct objc_object *s) : object(o), superClass(s) {} 
};
```

`[super init]`使用命令`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 Student.m`转化成`cpp`
打开`cpp`大概在底部的位置找到

```
(Student *(*)(__rw_objc_super *, SEL))(void *)objc_msgSendSuper)((__rw_objc_super){(id)self, (id)class_getSuperclass(objc_getClass("Student"))}, sel_registerName("init"))
```

简化之后是

```
(void *)objc_msgSendSuper((__rw_objc_super){self, class_getSuperclass(objc_getClass("Student"))}, sel_registerName("init"))
```

`void
objc_msgSendSuper(void /* struct objc_super *super, SEL op, ... */ )`
    其实是向父类发送消息，参数是`struct objc_super *super, SEL op, ...`，我们源码中找到了该函数的实现在`objc-msg-arm64.s`
    
```
ENTRY _objc_msgSendSuper
UNWIND _objc_msgSendSuper, NoFrame
//根据结构体struct __rw_objc_super 
{ 
	//struct objc_object *object; //消息接受者
	//struct objc_object *superClass; //父类
}占用空间16字节，objc_msgSendSuper参数是__rw_objc_super，
//使x0偏移16字节，就是两个指针的空间，赋值给p0 和p16
ldp	p0, p16, [x0]		// p0 = self , p16 = superclass

CacheLookup NORMAL		// calls imp or objc_msgSend_uncached

END_ENTRY _objc_msgSendSuper

```
将`self`和`superclass`赋值给 `p0, p16`调用`CacheLookup NORMAL`

```
.macro CacheLookup //.macro 是一个宏 使用 _cmd&mask 查找缓存中的方法
	// p1 = SEL, p16 = isa
	ldp	p10, p11, [x16, #CACHE]	// p10 = buckets, p11 = occupied|mask
#if !__LP64__
	and	w11, w11, 0xffff	// p11 = mask
#endif
	and	w12, w1, w11		// x12 = _cmd & mask
	add	p12, p10, p12, LSL #(1+PTRSHIFT)
		             // p12 = buckets + ((_cmd & mask) << (1+PTRSHIFT))

	ldp	p17, p9, [x12]		// {imp, sel} = *bucket
1:	cmp	p9, p1			// if (bucket->sel != _cmd)
	b.ne	2f			//     scan more
	CacheHit $0			// call or return imp 命中 调用或者返回imp
	
2:	// not hit: p12 = not-hit bucket 没有命中
	CheckMiss $0			// miss if bucket->sel == 0
	cmp	p12, p10		// wrap if bucket == buckets
	b.eq	3f
	ldp	p17, p9, [x12, #-BUCKET_SIZE]!	// {imp, sel} = *--bucket
	b	1b			// loop

3:	// wrap: p12 = first bucket, w11 = mask
	add	p12, p12, w11, UXTW #(1+PTRSHIFT)
		                        // p12 = buckets + (mask << 1+PTRSHIFT)

	// Clone scanning loop to miss instead of hang when cache is corrupt.
	// The slow path may detect any corruption and halt later.

	ldp	p17, p9, [x12]		// {imp, sel} = *bucket
1:	cmp	p9, p1			// if (bucket->sel != _cmd)
	b.ne	2f			//     scan more
	CacheHit $0			// call or return imp
	
2:	// not hit: p12 = not-hit bucket
	CheckMiss $0			// miss if bucket->sel == 0
	cmp	p12, p10		// wrap if bucket == buckets
	b.eq	3f
	ldp	p17, p9, [x12, #-BUCKET_SIZE]!	// {imp, sel} = *--bucket
	b	1b			// loop

3:	// double wrap
	JumpMiss $0
	
.endmacro
```

汇编比较多，只看到第二行`p1 = SEL, p16 = isa`，查找缓存是从`p16`,也就是`superclass`开始查找，后边的都和`objc_msgSend`一样。
大致上比较清楚了，`super`本质上调用了`objc_msgSendSuper`，`objc_msgSendSuper`是查找从父类开始查找方法。

`[super init]`就是`self`直接调用父类`init`的方法，但是`objc_msgSend`接受者是`self`，假如是`[self init]`则会产生死循环。`[super test]`则是执行父类的`test`。
使用`Debug Workflow->Always Show Disassemdly`发现`super`其实调用了汇编的`objc_msgSendSuper2`，进入`objc_msgSendSuper2 objc-msg-arm64.s 422 行`发现和`objc_msgSendSuper`其实基本一致的

```
//_objc_msgSendSuper 开始
	ENTRY _objc_msgSendSuper
	UNWIND _objc_msgSendSuper, NoFrame
//x0偏移16字节，就是两个指针的空间，赋值给p0 和p16
	ldp	p0, p16, [x0]		// p0 = self , p16 = superclass
	CacheLookup NORMAL		// calls imp or objc_msgSend_uncached
	END_ENTRY _objc_msgSendSuper  //_objc_msgSendSuper 结束
	
//objc_msgLookupSuper2 开始
	ENTRY _objc_msgSendSuper2 
	UNWIND _objc_msgSendSuper2, NoFrame

	ldp	p0, p16, [x0]		// p0 = real receiver, p16 = class
	//将存储器地址为x16+8的字数据读入寄存器p16。
	ldr	p16, [x16, #SUPERCLASS]	// p16 = class->superclass
	CacheLookup NORMAL
	END_ENTRY _objc_msgSendSuper2
```

也可以使用`LLVM`转化成中间代码来查看，`clang -emit-llvm -S FYCat.m`查看关键函数

```
define internal void @"\01-[FYCat forwardInvocation:]"(%1*, i8*, %2*) #1 {
    call void bitcast (i8* (%struct._objc_super*, i8*, ...)* @objc_msgSendSuper2 to void (%struct._objc_super*, i8*, %2*)*)(%struct._objc_super* %7, i8* %18, %2* %12)
}
```
这是`forwardInvocation`函数的调用代码，简化之后是`objc_msgSendSuper2(self,struct._objc_super i8*,%2*)`，就是`objc_msgSendSuper2(self,superclass,@selector(forwardInvocation),anInvocation)`。

验证

```
@interface FYPerson : NSObject
@property (nonatomic,copy) NSString *name;
- (int)age;
-(void)test;
@end

@implementation FYPerson
- (void)test{
    ;    NSLog(@"%s",__func__);
}
- (int)age{
    NSLog(@"%s",__func__);
    return 10;
}
- (NSString *)name{
    return [_name stringByAppendingString:@" eat apple"];
}
@end


@interface FYStudent : FYPerson

@end
@implementation FYStudent
- (void)test{
    [super test]; //执行父类的test
    int age = [super age]; //获取父类的方法 返回值
    NSLog(@"age is %d",age);
    NSString * name = [self name]; //从父类开始寻找name的值，但返回的是self.name的值
    NSLog(@"%@",name);
}
-(int)age{
    return 12;
}
@end
//输出
-[FYPerson test]
-[FYPerson age]
age is 10
小李子 eat apple

```

`test`是执行父类的方法，`[super age]`获取父类中固定的`age`,
`[self name]`从父类开始寻找`name`的值，但返回的是`self.name`的值。

###  isMemberOfClass &  isKindOfClass

```
+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [self class] == cls;
}

+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        printf("%s %s\n",class_getName(tcls),class_getName(cls));
        if (tcls == cls)
        {return YES;}else{
            printf("%s",class_getName(tcls));
        }
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        
        printf(" %s %s\n",class_getName(tcls),class_getName(cls));
        if (tcls == cls) return YES;
    }
    return NO;
}

+ (BOOL)isSubclassOfClass:(Class)cls {
    for (Class tcls = self; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}
```

`- (BOOL)isMemberOfClass`和`- (BOOL)isKindOfClass:(Class)cls`比较简单，都是判断`self.class` 和`cls`，`+ (BOOL)isMemberOfClass:(Class)cls`是判断`self.class->isa`是否和`cls`相等，`+ (BOOL)isKindOfClass:(Class)cls`判断`cls->isa`和`cls->isa->isa`有没有可能和`cls`相等？只有基类是，其他的都不是。
#### 验证 实例方法

```
Class cls = NSObject.class;
Class pcls = FYPerson.class;
FYPerson *p=[FYPerson new];
NSObject *obj=[NSObject new];
BOOL res11 =[p isKindOfClass:pcls];
BOOL res12 =[p isMemberOfClass:pcls];
BOOL res13 =[obj isKindOfClass:cls];
BOOL res14 =[obj isMemberOfClass:cls];
NSLog(@"instance:%d %d %d %d",res11,res12,res13,res14);
//log
//instance:1 1 1 1
```

`p`是`pcls`的子类，`obj` 是`cls`的子类，在明显不过了。

#### 验证 类方法

```

//isKindOfClass cls->isa 和cls/cls->superclass相等吗?
//元类对象和类对象不相等，但是最后一个元类的isa->superclass是指向NSObject的class 所以res1 = YES;
//cls->isa:元类对象 cls->isa->superclass: NSObject类对象
//cls:类对象
BOOL res1 =[cls isKindOfClass:cls];
//cls->isa 和cls相等吗？ 不相等 cls->isa是元类对象,cls是类对象，不可能相等。
BOOL res2 =[cls isMemberOfClass:cls];
//pcls->isa:person的元类对象 cls->isa->superclass: NSObject元类类对象 ->superclass:NSObject类对象 ->superclass:nil
//pcls:person类对象
BOOL res3 =[pcls isKindOfClass:pcls];
//pcls->isa:person的元类对象
//pcls:person类对象
BOOL res4 =[pcls isMemberOfClass:pcls];
NSLog(@"%d %d %d %d",res1,res2,res3,res4);
结果：
1 0 0 0
```

### 堆栈 对象本质 class本质实战
网上看到了一个比较有意思的面试题，今天我们就借此机会分析一下,虽然网上很多博文已经讲了，但是好像都不很对，或者没有讲到根本的东西，所以今天再来探讨一下究竟。
其实这道题考察了对象在内存中的布局，类和对象的关系，和堆上的内存布局。基础知识不很牢固的同学可以看一下我历史的博文[obj_msgsend基础](https://juejin.im/post/5d2d200be51d4510a7328161)、[类的本质](https://juejin.im/post/5d19c59e6fb9a07f04205f95)、[对象的本质](https://juejin.im/post/5d15887ee51d45108126d28d)。

```
@interface FYPerson : NSObject
@property (nonatomic,copy) NSString *name;
- (void)print;
@end
@implementation FYPerson
- (void)print{
    NSLog(@"my name is %@",self.name);
}
@end


- (void)viewDidLoad {
    [super viewDidLoad];
    NSObject *fix =[NSObject new]; // 16字节 0x60000219b030
    id cls  = [FYPerson class];针
    void * obj = &cls; 
    [(__bridge id)obj print];
}
```

#### 问题一 能否编译成功？
当大家看到第二个问题的时候，不傻的话都会回答能编译成功，否则还问结果干嘛。我们从之前学的只是来分析一下，调用方法成功需要有`id self `和`SEL sel`，现在`cls`和`obj`都在栈区，`obj` 指针指向`cls`的内存地址，访问`obj`相当于直接访问`cls`内存存储的值，`cls`存储的是`Person.class`,`[obj print]` 相当于`objc_msgSend(cls,@selector(print))`,`cls`是有`print`方法的，所以会编译成功。
#### 输出什么？
`fix/cls/obj`这三个对象都是存储在栈上，`fix/cls/obj`地址是连续从高到低的，而且他们地址相差都是`8`字节，一个指针大小是`8`字节。他们三个地址如下所示：

使用图来表示`fix`和`obj`：
|对象|地址|地址高低|
|:-:|:-:|:-:|:-:|
|fix|0x7ffeec3df920| 高 |
|cls|0x7ffeec3df918|中|
|obj|0x7ffeec3df910|低|

寻找属性先是寻找`isa`，然后再在`isa`地址上+`8`则是属性的值，所以根据`obj`寻找`cls`地址是`0x7ffeec3df918`,然后`cls`地址+8字节则是`_name`的地址，`cls`地址是`0x7ffeec3df918`，加上`8`字节正好是`fix`的地址`0x7ffeec3df920`，因为都是指针，所以都是`8`字节,所以最后输出是结果是`fix`对象的地址的数据。

情况再复杂一点，`FYPerson`结构改动一下
```
@interface FYPerson : NSObject
@property (nonatomic,copy) NSString *name;
@property (nonatomic,copy) NSString *name2;
@property (nonatomic,copy) NSString *name3;
- (void)print;
@end
```
则他们的`_name`、`_name2`、`_name3`则在`cls`的地址基础上再向上寻找`8*1=8/8*2=16/8*3=24`字节，就是向上寻找第1个，第2个，第3个指向对象的指针。


测试代码：

```
@interface FYPerson : NSObject
@property (nonatomic,copy) NSString *name;
@property (nonatomic,copy) NSString *name2;
@property (nonatomic,copy) NSString *name3;
- (void)print;
@end
@implementation FYPerson
- (void)print{
    NSLog(@"name1:%@ name2:%@ name3:%@",self.name1,self.name2,self.name3);
}
@end

//主函数

NSObject *fix =[NSObject new];
FYPerson *fix2 =[FYPerson new];

id cls  = [FYPerson class];
void * obj = &cls; 
[(__bridge id)obj print];//objc_msgSend(self,sel);
NSLog(@"fix:%p fix2:%p cls:%p obj:%p",&fix,&fix2,&cls,&obj);

//log
name1:<FYPerson: 0x6000033a38a0> 
name2:<NSObject: 0x6000031f5380> 
name3:<ViewController: 0x7f8307505580>

fix: 0x7ffeec3d f9 28 
fix2:0x7ffeec3d f9 20 
cls: 0x7ffeec3d f9 18 
obj: 0x7ffeec3d f9 10
```

再变形：

```
- (void)viewDidLoad {
    [super viewDidLoad];
	/*
	 objc_msgSuperSend(self,ViewController,sel)
	 */
NSLog(@"self:%p ViewController.class:%p SEL:%p",self,ViewController.class,@selector(viewDidLoad));
    id cls  = [FYPerson class];//cls 是类指针
    void * obj = &cls; //obj 
    [(__bridge id)obj print];//objc_msgSend(self,sel);
    
 NSLog(@"cls:%p obj:%p",&cls,&obj);
 //log
 
 name1:<ViewController: 0x7fad03e04ea0> 
 name2:ViewController
 
 self:                  0x7fad03e04ea0 
 ViewController.class:  0x10d0edf00 
 SEL:                   0x1117d5687
 
 cls:0x7ffee2b11908 
 obj:0x7ffee2b11900
 
}
```

`_name1`是`cls`地址向上+8字节，`_name2`是向上移动16字节，`[super viewDidLoad]`本质上是`objc_msgSuperSend(self,ViewController.class,sel)`，`self`、`ViewController.class`、`SEL`是同一块连续内存，布局由低到高，看了下图的内存布局就会顿悟，
结构体如下图所示：

|对象|地址高低|
|:-:|:-:|
|self|低|
|ViewController.class|中|
|SEL|高|


### 常用的runtimeAPI 

|method|desc|
|:-:|:-:|
|Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)|动态创建一个类（参数：父类，类名，额外的内存空间|
|void objc_registerClassPair(Class cls))|注册一个类|
|void objc_disposeClassPair(Class cls)|销毁一个类|
|Class objcect_getClass(id obj)|获取isa指向的class|
|Class object_setClass (id obj,Class cls)|设置isa指向的class|
|BOOL object_isClass(id class)|判断oc对象是否为Class|
|BOOL class_isMetaClass(Class cls)|是否是元类|
|Class class_getSuperclass(Class cls)|获取父类|
|Ivar class_getInstanceVariable(Class cls ,const char * name|获取一个实例变量信息|
|Ivar * class_copyIvarList(Class cls,unsigned int * outCount)|拷贝实例变量列表，需要free|
|void object_setIvar(id obj,Ivar ivar,id value|设置获取实例变量的值|
|id object_getIvar(id obj,Ivar ivar)|获取实例变量的值|
|BOOL class_addIvar(Class cls,const cahr * name ,size_t size,uint_t alignment,const char * types)|动态添加成员变量（已注册的类不能动态添加成员变量）|
|const char * ivar_getName（Ivar v)|获取变量名字|
|const char * ivar_getTypeEncoding(Ivar v)|变量的encode|
|objc_property_t class_getProperty(Class cls,const char* name)|获取一个属性|
|objc_property_t _Nonnull * _Nullable class_copyPropertyList(Class _Nullable cls, unsigned int * _Nullable outCount)|拷贝属性列表|
|objc_property_t _Nullable class_getProperty(Class _Nullable cls, const char * _Nonnull name)|获取属性列表|
| BOOL class_addProperty(Class _Nullable cls, const char * _Nonnull name,const objc_property_attribute_t * _Nullable attributes,unsigned int attributeCount)|添加属性|
| void class_replaceProperty(Class _Nullable cls, const char * _Nonnull name,const objc_property_attribute_t * _Nullable attributes, unsigned int attributeCount)|替换属性|
|void class_replaceProperty(Class cls, const char *name, const objc_property_attribute_t *attributes,unsigned int attributeCount)|动态替换属性|
|const char * _Nonnull property_getName(objc_property_t _Nonnull property) |获取name|
|const char * _Nullable property_getAttributes(objc_property_t _Nonnull property) |获取属性的属性|
|IMP imp_implementationWithBlock(id block)|获取block的IMP|
|id imp_getBlock(IMP anIMP)|通过imp 获取block|
|BOOL imp_removeBlock(IMP anIMP)|IMP是否被删除|
|...|...|
在业务上有些时候需要给系统控件的某个属性赋值，但是系统没有提供方法，只能靠自己了，那么我们
获取`class`的所有成员变量,可以获取`Ivar`查看是否有该变量，然后可以通过`KVC`来赋值。

```

@interface FYCat : NSObject
@property (nonatomic,copy) NSString * name;
@property (nonatomic,assign) int  age;
@end

FYCat *cat=[FYCat new];
unsigned int count = 0;
Ivar *vars= class_copyIvarList(cat.class, &count);
for (int i = 0; i < count; i ++) {
	Ivar item = vars[i];
	const char *name = ivar_getName(item);
	NSLog(@"%s",name);
}
free(vars);

Method *m1= class_copyMethodList(cat.class, &count);
for (int i = 0; i < count; i ++) {
	Method item = m1[i];
	SEL name = method_getName(item);
	printf("method:%s \n",NSStringFromSelector(name).UTF8String);
}
free(m1);
		
//log
_age
_name

method:.cxx_destruct 
method:name 
method:setName: 
method:methodSignatureForSelector: 
method:forwardInvocation: 
method:age 
method:setAge:
```

大家常用的一个功能是`JsonToModel`，那么我们已经了解到了`runtime`的基础知识，现在可以自己撸一个`JsonToModel`了。

```
@interface NSObject (Json)
+ (instancetype)fy_objectWithJson:(NSDictionary *)json;
@end
@implementation NSObject (Json)
+ (instancetype)fy_objectWithJson:(NSDictionary *)json{
	id obj = [[self alloc]init];
	unsigned int count = 0;
	Ivar *vars= class_copyIvarList(self, &count);
	for (int i = 0; i < count; i ++) {
		Ivar item = vars[i];
		const char *name = ivar_getName(item);
		NSString * nameOC= [NSString stringWithUTF8String:name];
		if (nameOC.length>1) {
			nameOC = [nameOC substringFromIndex:1];
			NSString * value = json[nameOC];
			if ([value isKindOfClass:NSString.class] && value.length) {
				[obj setValue:value forKey:nameOC];
			}else if ([value isKindOfClass:NSArray.class]){
				[obj setValue:value forKey:nameOC];
			}else if ([value isKindOfClass:NSDictionary.class]){
				[obj setValue:value forKey:nameOC];
			}else if ([value isKindOfClass:[NSNull class]] || [value isEqual:nil])
			{
				printf("%s value is nil or null \n",name);
			}else if ([value integerValue] > 0){
				[obj setValue:value forKey:nameOC];
			}else{
				printf("未知错误 \n");
			}
		}
	}
	free(vars);
	return obj;
}
@end
```

然后自己定义一个字典，来测试一下这段代码

```
@interface FYCat : NSObject
@property (nonatomic,copy) NSString * name;
@property (nonatomic,assign) int  age;

- (void)run;
@end

NSDictionary * info = @{@"age":@"10",@"value":@10,@"name":@"小明"};
		FYCat *cat=[FYCat fy_objectWithJson:info];
//log
age:10 name:小明
```

#### hook钩子(method_exchangeImplementations)
由于业务需求需要在某些按钮点击事件进行记录日志，那么我们可以利用钩子来实现拦截所有button的点击事件。

```
@implementation UIButton (add)
+ (void)load{
	Method m1= class_getInstanceMethod(self.class, @selector(sendAction:to:forEvent:));
	Method m2= class_getInstanceMethod(self.class, @selector(fy_sendAction:to:forEvent:));
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		method_exchangeImplementations(m1, m2);
	});
}
- (void)fy_sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event{
	NSLog(@"%@ ",NSStringFromSelector(action));
	/*
	 code here
	 */
	 //sel IMP 已经交换过了，所以不会死循环
	[self fy_sendAction:action to:target forEvent:event];
}
@end
```

可以在`code here`添加需要处理的代码，一般记录日志和延迟触发都可以处理。`[self fy_sendAction:action to:target forEvent:event];`不会产生死循环，原因是在`+load`中已经将`m1`和`m2`已经交换过了`IMP`。我们进入到`method_exchangeImplementations`内部：

```
void method_exchangeImplementations(Method m1, Method m2)
{
    if (!m1  ||  !m2) return;

    mutex_locker_t lock(runtimeLock);

//交换IMP
    IMP m1_imp = m1->imp;
    m1->imp = m2->imp;
    m2->imp = m1_imp;

//刷新缓存
    flushCaches(nil);

    updateCustomRR_AWZ(nil, m1);
    updateCustomRR_AWZ(nil, m2);
}

struct method_t {
    SEL name;
    const char *types;
    MethodListIMP imp;
};
using MethodListIMP = IMP;
```

`m1`和`m2`交换了`IMP`，交换的是`method_t->imp`，然后刷新缓存(清空缓存)，等下次调用`IMP`则需要在`cls->rw->data->method`中去寻找。

#### 数组越界和nil处理

```
@implementation NSMutableArray (add)
+ (void)load{
	Class cls= NSClassFromString(@"__NSArrayM");
	Method m1= class_getInstanceMethod(cls, @selector(insertObject:atIndex:));
	SEL sel = @selector(fy_insertObject:atIndex:);
	Method m2= class_getInstanceMethod(cls, sel);
	
	Method m3= class_getInstanceMethod(cls, @selector(objectAtIndexedSubscript:));
	Method m4= class_getInstanceMethod(cls, @selector(fy_objectAtIndexedSubscript:));

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		method_exchangeImplementations(m1, m2);
		method_exchangeImplementations(m3, m4);
	});
}

- (void)fy_insertObject:(id)anObject atIndex:(NSUInteger)index{
	if (anObject != nil) {
		[self fy_insertObject:anObject atIndex:index];
	}else{
		printf(" anObject is nil \n");
	}
}
- (id)fy_objectAtIndexedSubscript:(NSUInteger)idx{
	if (self.count > idx) {
		return [self fy_objectAtIndexedSubscript:idx];
	}else{
		printf(" %ld is outof rang \n",(long)idx);
		return nil;
	}
}
@end



NSMutableArray *array=[NSMutableArray array];
id obj = nil;
[array addObject:obj];
array[1];

//log
 anObject is nil 
 1 is outof rang 
```

`NSMutableArray`是类簇，使用工厂模式，`NSMutableArray`不是数组实例，而是生产数组对象的工厂。
真实的数组对象是`__NSArrayM`,然后给`__NSArrayM`钩子，交换`objectAtIndexedSubscript:(NSUInteger)idx`和`insertObject:(id)anObject atIndex:(NSUInteger)index`方法，实现崩溃避免。


#### 字典nil处理

```
@interface NSMutableDictionary (add)

@end

@implementation NSMutableDictionary (add)
+ (void)load{
    Class cls= NSClassFromString(@"__NSDictionaryM");
    Method m1= class_getInstanceMethod(cls, @selector(setObject:forKey:));
//    __NSDictionaryM
    SEL sel = @selector(fy_setObject:forKey:);
    Method m2= class_getInstanceMethod(cls, sel);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        method_exchangeImplementations(m1, m2);
    });
}
- (void)fy_setObject:(id)anObject forKey:(id<NSCopying>)aKey{
    if (anObject) {
        [self fy_setObject:anObject forKey:aKey];
    }else{
        NSString * key = (NSString *)aKey;
        printf("key:%s anobj is nil \n",key.UTF8String);
    }
}
@end
```

利用类别`+load`给`__NSDictionaryM`添加方法，然后交换`IMP`，实现给`NSMutableDictionary setObject:Key:`的时候进行`nil`校验,`+load`虽然系统启动的自动调用一次的，但是为防止开发者再次调用造成`IMP`和`SEL`混乱，使用`dispatch_once`进行单次运行。

### 总结
1. `super`本质上是`self`调用函数，不过查找函数是从`sueprclass`开始查找的
2. `+isKandOfClass`是判断`self`是否是`cls`的子类，`+isMemberOfClass:`是判断`self`是否和`cls`相同。
3. 了解`+load`在`Category`是启动的时候使用运行时编译的，而且只会加载一次,然后利用`objc/runtime.h`中`method_exchangeImplementations`实现交换两个函数的`IMP`，可以实现拦截`nil`，降低崩溃率。
4. `NSMutableDictionary`、`NSMutableArray`是类簇，先找到他们的类然后再交换该类的函数的`IMP`。

### 资料参考
- [小码哥视频](http://www.520it.com/zt/ios_mj/)

#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)


---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](../images/0.png)