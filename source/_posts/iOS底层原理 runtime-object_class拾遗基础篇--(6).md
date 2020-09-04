---
title: iOS底层原理 runtime-object_class拾遗基础篇--(6)
tags:
  - iOS
categories: iOS
abbrlink: 87e5f745
date: 2019-12-01 11:16:58
---

### runtime 基础知识
`runtime`是运行时，在运行的时候做一些事请，可以动态添加类和交换函数，那么有一个基础知识需要了解，arm64架构前，isa指针是普通指针，存储class和meta-class对象的内存地址，从arm64架构开始，对isa进行了优化，变成了一个`union`共用体，还是用位域来存储更多的信息，我们首先看一下isa指针的结构：

```
struct objc_object {
private:
    isa_t isa;
public:
    // ISA() assumes this is NOT a tagged pointer object
    Class ISA();
    // getIsa() allows this to be a tagged pointer object
    Class getIsa();
    //****
}


#include "isa.h"
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};
```

`objc_object`是结构体，包含了私有属性`isa_t`,`isa_t isa`是一个共用体，包含了`ISA_BITFIELD`是一个宏(结构体)，`bits`是`uintptr_t`类型，`uintptr_t`其实是`unsign long`类型占用8字节，就是64位，我们进入到`ISA_BITFIELD`内部：

```
# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
#   define ISA_MAGIC_MASK  0x000003f000000001ULL
#   define ISA_MAGIC_VALUE 0x000001a000000001ULL
#   define ISA_BITFIELD                                         
      uintptr_t nonpointer        : 1;                              
      uintptr_t has_assoc         : 1;                                  
      uintptr_t has_cxx_dtor      : 1;                                  
      uintptr_t shiftcls          : 33; /*MACH_VM_MAX_ADDRESS 0x1000000000*/ \
      uintptr_t magic             : 6;                                  
      uintptr_t weakly_referenced : 1;                                  
      uintptr_t deallocating      : 1;                                  
      uintptr_t has_sidetable_rc  : 1;                                  
      uintptr_t extra_rc          : 19
#   define RC_ONE   (1ULL<<45)
#   define RC_HALF  (1ULL<<18)

# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x001f800000000001ULL
#   define ISA_MAGIC_VALUE 0x001d800000000001ULL
#   define ISA_BITFIELD                                                 
      uintptr_t nonpointer        : 1;                                  
      uintptr_t has_assoc         : 1;                                  
      uintptr_t has_cxx_dtor      : 1;                                  
      uintptr_t shiftcls          : 44; /*MACH_VM_MAX_ADDRESS 0x7fffffe00000*/ \
      uintptr_t magic             : 6;                                  
      uintptr_t weakly_referenced : 1;                                  
      uintptr_t deallocating      : 1;                                  
      uintptr_t has_sidetable_rc  : 1;                                  
      uintptr_t extra_rc          : 8
#   define RC_ONE   (1ULL<<56)
#   define RC_HALF  (1ULL<<7)
# else
#   error unknown architecture for packed isa
# endif
```

`ISA_BITFIELD`在`arm64`和`x86`是两种结构，存储了`nonpointer`,`has_assoc`,`has_cxx_dtor`,`shiftcls`,`magic`,`weakly_referenced`,`deallocating`,`has_sidetable_rc`,`extra_rc`这些信息，`:1`就占用了一位，`:44`就是占用了44位，`:6`就是占用了6位，`:8`就是占用了8位，那么共用体`isa_t`简化之后

```
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;
    struct {
      uintptr_t nonpointer        : 1;                                
      uintptr_t has_assoc         : 1;                                  
      uintptr_t has_cxx_dtor      : 1;                                  
      uintptr_t shiftcls          : 44; /*MACH_VM_MAX_ADDRESS 0x7fffffe00000*/ \
      uintptr_t magic             : 6;                                  
      uintptr_t weakly_referenced : 1;                                  
      uintptr_t deallocating      : 1;                                  
      uintptr_t has_sidetable_rc  : 1;                                  
      uintptr_t extra_rc          : 8
    };
};
```

`isa_t`是使用共用体结构，使用`bits`存储了结构体的数据，那么共用体是如何使用的？我们来探究一下
#### 共用体基础知识
首先我们定义一个`FYPerson`，添加2个属性

```
@interface FYPerson : NSObject
@property (nonatomic,assign) BOOL rich;
@property (nonatomic,assign) BOOL tell;
@property (nonatomic,assign) BOOL handsome;
@end
```

然后查看该类的实例占用空间大小

```
FYPerson *p=[[FYPerson alloc]init];
		p.handsome = YES;
		p.rich = NO;
		NSLog(@"大小：%zu",class_getInstanceSize(FYPerson.class));
		//16
```

`FYPerson`定义了三个属性，占用空间是16字节，那么我们换一种方法实现这个三个属性的功能。
我们定义6个方法，3个set方法，3个get方法。

```
- (void)setTall:(BOOL)tall;
- (void)setRich:(BOOL)rich;
- (void)setHandsome:(BOOL)handsome;

- (BOOL)isTall;
- (BOOL)isRich;
- (BOOL)isHandsome;

//实现：
//使用0b00000000不是很易读，我们换成下边的写法1<<0
//#define FYHandsomeMask 0b00000001
//#define FYTallMask 0b00000010
//#define FYRichMask 0b00000001


#define FYHandsomeMask (1<<0)
#define FYTallMask (1<<1)
#define FYRichMask (1<<2)

@interface FYPerson()
{
	char _richTellHandsome;//0000 0000 rich tall handsome
}
@end


@implementation FYPerson

- (void)setRich:(BOOL)tall{
	if (tall) {
		_richTellHandsome = _richTellHandsome|FYRichMask;
	}else{
		_richTellHandsome = _richTellHandsome&~FYRichMask;
	}
	
}
- (void)setTall:(BOOL)tall{
	if (tall) {
		_richTellHandsome = _richTellHandsome|FYTallMask;
	}else{
		_richTellHandsome = _richTellHandsome&~FYTallMask;
	}
	
}
- (void)setHandsome:(BOOL)tall{
	if (tall) {
		_richTellHandsome = _richTellHandsome|FYHandsomeMask;
	}else{
		_richTellHandsome = _richTellHandsome&~FYHandsomeMask;

	}
}
- (BOOL)isRich{
	return !!(_richTellHandsome&FYRichMask);
}
- (BOOL)isTall{
	return !!(_richTellHandsome&FYTallMask);
}
- (BOOL)isHandsome{
	return !!(_richTellHandsome&FYHandsomeMask);
}
@end
```

我们定义了一个char类型的变量`_richTellHandsome`,4字节，32位，可以存储32个bool类型的变量。赋值是使用`_richTellHandsome = _richTellHandsome|FYRichMask`,或`_richTellHandsome = _richTellHandsome&~FYRichMask`,取值是`!!(_richTellHandsome&FYRichMask)`，前边加`!!`是转化成`bool`类型的，否则取值出来是`1 or  2 or 4 `。我们再换一种思路将三个变量定义成一个结构体，取值和赋值都是可以直接操作的。

```
@interface FYPerson()
{
//	char _richTellHandsome;//0000 0000 rich tall handsome
	//位域
	struct{
		char tall : 1;//高度
		char rich : 1;//富有
		char handsome : 1; //帅
	} _richTellHandsome; // 0b0000 0000
	//使用2位 yes就是0b01 转化成1字节8位就是:0o0101 0101 结果是1
	//使用1位 yes就是0b1 转化成1字节8位就是:0o1111 1111 所以结果是-1
}
@end


@implementation FYPerson

- (void)setRich:(BOOL)tall{
	_richTellHandsome.rich = tall;
}
- (void)setTall:(BOOL)tall{
	_richTellHandsome.tall = tall;
}
- (void)setHandsome:(BOOL)tall{
	_richTellHandsome.handsome = tall;
}
- (BOOL)isRich{
	return !!_richTellHandsome.rich;
}
- (BOOL)isTall{
	return !!_richTellHandsome.tall;
}
- (BOOL)isHandsome{
	return !!_richTellHandsome.handsome;
}
@end
	
```


结构体`_richTellHandsome`包含三个变量`char tall : 1;`,`char rich : 1;`,`char handsome : 1`。每一个变量占用空间为1位，3个变量占用3位。取值的时候使用`!!(_richTellHandsome&FYHandsomeMask)`，赋值使用

```
if (tall) {
		_richTellHandsome = _richTellHandsome|FYHandsomeMask;
	}else{
		_richTellHandsome = _richTellHandsome&~FYHandsomeMask
	}
```

我们采用位域来存储信息，
位域是指信息在存储时，并不需要占用一个完整的字节， 而只需占几个或一个二进制位。例如在存放一个开关量时，只有0和1 两种状态， 用一位二进位即可。为了节省存储空间，并使处理简便，C语言又提供了一种数据结构，称为“位域”或“位段”。所谓“位域”是把一个字节中的二进位划分为几 个不同的区域， 并说明每个区域的位数。每个域有一个域名，允许在程序中按域名进行操作。 这样就可以把几个不同的对象用一个字节的二进制位域来表示。

另外一个省空间的思路是使用`联合`,
使用`union`，可以更省空间，“联合”是一种特殊的类，也是一种构造类型的数据结构。在一个“联合”内可以定义多种不同的数据类型， 一个被说明为该“联合”类型的变量中，允许装入该“联合”所定义的任何一种数据，这些数据共享同一段内存，以达到节省空间的目的（还有一个节省空间的类型：位域）。 这是一个非常特殊的地方，也是联合的特征。另外，同struct一样，联合默认访问权限也是公有的，并且，也具有成员函数。

```
@interface FYPerson()
{
	union {
		char bits; //一个字节8位 ricH /tall/handsome都是占用的bits的内存空间
		struct{
			char tall : 1;//高度
			char rich : 1;//富有
			char handsome : 1; //帅
		}; // 0b0000 0000
	}_richTellHandsome;
}
@end


@implementation FYPerson

- (void)setRich:(BOOL)tall{
	if (tall) {
		_richTellHandsome.bits |= FYRichMask;
	}else{
		_richTellHandsome.bits &= ~FYRichMask;
	}
}
- (void)setTall:(BOOL)tall{
	if (tall) {
		_richTellHandsome.bits |= FYTallMask;
	}else{
		_richTellHandsome.bits &= ~FYTallMask;
	}
}
- (void)setHandsome:(BOOL)tall{
	if (tall) {
		_richTellHandsome.bits |= FYHandsomeMask;
	}else{
		_richTellHandsome.bits &= ~FYHandsomeMask;
	}
}
- (BOOL)isRich{
	return !!(_richTellHandsome.bits & FYRichMask);
}
- (BOOL)isTall{
	return !!(_richTellHandsome.bits & FYTallMask);
}
- (BOOL)isHandsome{
	return (_richTellHandsome.bits & FYHandsomeMask);
}
```

使用`联合`共用体，达到省空间的目的，`runtime`源码中是用来很多`union`和位运算。
例如KVO 的NSKeyValueObservingOptions
```
typedef NS_OPTIONS(NSUInteger, NSKeyValueObservingOptions){
        NSKeyValueObservingOptionNew = 0x01,
    NSKeyValueObservingOptionOld = 0x02,
    NSKeyValueObservingOptionInitial = 0x04,
    NSKeyValueObservingOptionPrior = 0x08
}
```
这个`NSKeyValueObservingOptions`使用位域，当传进去的时候`NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld`,则传进去的值为`0x3`,转化成二进制就是`0b11`，则两位都是`1`可以包含2个值。
那么我们来设计一个简单的可以使用或来传值的枚举

```
typedef enum {
	FYOne = 1,//  0b 0001
	FYTwo = 2,//  0b 0010
	FYTHree = 4,//0b 0100
	FYFour = 8,// 0b 1000
}FYOptions;

- (void)setOptions:(FYOptions )ops{
	if (ops &FYOne) {
		NSLog(@"FYOne is show");
	}
	if (ops &FYTwo) {
		NSLog(@"FYTwo is show");
	}
	if (ops &FYTHree) {
		NSLog(@"FYTHree is show");
	}
	if (ops &FYFour) {
		NSLog(@"FYFour is show");
	}
}

[self setOptions:FYOne|FYTwo|FYTHree];

//输出是：
FYOne is show
FYTwo is show
FYTHree is show

```
这是一个名字为`FYOptions`的枚举，第一个是十进制是1，二进制是`0b 0001`,第二个十进制是2，二进制是`0b 0010`,第三个十进制是4，二进制是`0b 0100`,第四个十进制是8，二进制是`0b 1000`。
那么我们使用的时候可以`FYOne|FYTwo|FYTHree`，打包成一个值，相当于`1|2|4 = 7`,二进制表示是`0b0111`，后三位都是1，可以通过&mask取出对应的每一位的数值。

#### Class的结构

isa详解 – 位域存储的数据及其含义

|参数|含义|
|---|---|
|nonpointer|0->代表普通的指针，存储着Class、Meta-Class对象的内存地址。1->代表优化过，使用位域存储更多的信息|
|has_assoc|是否有设置过关联对象，如果没有，释放时会更快|
|has_cxx_dtor|是否有C++的析构函数（.cxx_destruct），如果没有，释放时会更快|
|shiftcls|存储着Class、Meta-Class对象的内存地址信息|
|magic|用于在调试时分辨对象是否未完成初始化|
|weakly_referenced|是否有被弱引用指向过，如果没有，释放时会更快|
|deallocating|对象是否正在释放|
|extra_rc|里面存储的值是引用计数器减1|
|has_sidetable_rc|引用计数器是否过大无法存储在isa中
如果为1，那么引用计数会存储在一个叫SideTable的类的属性中|

class结构

```
struct fy_objc_class : xx_objc_object {
	Class superclass;
	cache_t cache;
	class_data_bits_t bits;
public:
	class_rw_t* data() {
		return bits.data();
	}
	
	fy_objc_class* metaClass() { // 提供metaClass函数，获取元类对象
		// 上一篇我们讲解过，isa指针需要经过一次 & ISA_MASK操作之后才得到真正的地址
		return (fy_objc_class *)((long long)isa & ISA_MASK);
	}
};
struct class_rw_t {
	uint32_t flags;
	uint32_t version;
	const class_ro_t *ro;//只读 数据
	method_list_t * methods;    // 方法列表
	property_list_t *properties;    // 属性列表
	const protocol_list_t * protocols;  // 协议列表
	Class firstSubclass;
	Class nextSiblingClass;
	char *demangledName;
};


struct class_ro_t {
	uint32_t flags;
	uint32_t instanceStart;
	uint32_t instanceSize;  // instance对象占用的内存空间
#ifdef __LP64__
	uint32_t reserved;
#endif
	const uint8_t * ivarLayout;
	const char * name;  // 类名
	method_list_t * baseMethodList;
	protocol_list_t * baseProtocols;
	const ivar_list_t * ivars;  // 成员变量列表
	const uint8_t * weakIvarLayout;
	property_list_t *baseProperties;
};
```

`class_ro_t`是只读的，`class_rw_t`是读写的，在源码中`runtime`->`Source`->`objc-runtime-new.mm`->`static Class realizeClass(Class cls) 1869行`

```

    const class_ro_t *ro;
    class_rw_t *rw;
    Class supercls;
    Class metacls;
    bool isMeta;

    if (!cls) return nil;
    //如果已注册 就返回
    if (cls->isRealized()) return cls;
    assert(cls == remapClass(cls));

    // fixme verify class is not in an un-dlopened part of the shared cache?
//只读ro
    ro = (const class_ro_t *)cls->data();
    if (ro->flags & RO_FUTURE) {
        // This was a future class. rw data is already allocated.
        rw = cls->data();//初始化ro
        ro = cls->data()->ro;
        cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
    } else {
        // Normal class. Allocate writeable class data.
        //初始化 rw 
        rw = (class_rw_t *)calloc(sizeof(class_rw_t), 1);
        rw->ro = ro;
        rw->flags = RW_REALIZED|RW_REALIZING;
        //指针指向rw 一开始是指向ro的
        cls->setData(rw);
    }

    isMeta = ro->flags & RO_META;

    rw->version = isMeta ? 7 : 0;  // old runtime went up to 6
````

开始`cls->data`指向的是`ro`，初始化之后，指向的`rw`,`rw->ro`指向的是原来的`ro`。
`class_rw_t`中的`method_array_t`是存储的方法列表，我们进入到`method_array_t`看下它的数据结构：

```
class method_array_t : 
    public list_array_tt<method_t, method_list_t> 
{
    typedef list_array_tt<method_t, method_list_t> Super;

 public:
    method_list_t **beginCategoryMethodLists() {
        return beginLists();
    }
    
    method_list_t **endCategoryMethodLists(Class cls);

    method_array_t duplicate() {
        return Super::duplicate<method_array_t>();
    }
};
```

`method_array_t`是一个类，存储了`method_t`二维数组，那么我们看下`method_t`的结构

```
struct method_t {
    SEL name;
    const char *types;
    MethodListIMP imp;

    struct SortBySELAddress :
        public std::binary_function<const method_t&,const method_t&, bool>
    {
        bool operator() (const method_t& lhs,
                         const method_t& rhs)
        { return lhs.name < rhs.name; }
    };
};
```

`method_t`是存储了3个变量的结构体，`SEL`是方法名，`types`是编码(方法返回类型，参数类型)， `imp`函数指针(函数地址)。
##### SEL
- SEL代表方法\函数名，一般叫做选择器，底层结构跟char *类似
- 可以通过@selector()和sel_registerName()获得
- 可以通过sel_getName()和NSStringFromSelector()转成字符串
- 不同类中相同名字的方法，所对应的方法选择器是相同的

##### Type Encoding

iOS中提供了一个叫做@encode的指令，可以将具体的类型转成字符编码，[官方网站插件encodeing](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html)

|code|Meaning|
|---|---|
|c|A char|
|i  | An int|
|s|A short|
|l|A long|
|l| is treated as a 32-bit quantity on 64-bit programs.|
|q|A long long|
|C|An unsigned char|
|I|An unsigned int|
|S|An unsigned short|
|L|An unsigned long|
|Q|An unsigned long long|
|f|A float|
|d|A double|
|B|A C++ bool or a C99 _Bool|
|v|A void|
|*|A character string (char *)|
|@|An object (whether statically typed or typed id)|
|#|A class object (Class)|
|:|A method selector (SEL)|
|[array type]|An array|
|{name=type...}|A structure|
|(name=type...)|A union|
|bnum|A bit field of num bits|
|^type|A pointer to type|
|?|An unknown type (among other things, this code is used for function pointers)|


我们通过一个例子来了解encode

```
-(void)test:(int)age heiht:(float)height{
}


FYPerson *p=[[FYPerson alloc]init];
	SEL sel = @selector(test:heiht:);
	Method m1= class_getInstanceMethod(p.class, sel);
	const char *type = method_getTypeEncoding(m1);
	NSLog(@"%s",type);
	
	//输出
	v24@0:8i16f20
	//0id 8 SEL 16 int 20 float = 24
```

`v24@0:8i16f20`是encoding的值，我们来分解一下，前边是`v24`是函数返回值是`void`，所有参数占用了`24`字节,`@0:8`是从第0开始，长度是8字节的位置，`i16`是从16字节开始的`int`类型，`f20`是从20字节开始，类型是`float`。

#### 方法缓存
Class内部结构中有个方法缓存（cache_t），用散列表（哈希表）来缓存曾经调用过的方法，可以提高方法的查找速度。
我们来到`cache_t`内部

```
struct cache_t {
    struct bucket_t *_buckets;//散列表
    mask_t _mask;//散列表长度-1
    mask_t _occupied;//已经存储的方法数量
}

struct bucket_t {
#if __arm64__
    MethodCacheIMP _imp;
    cache_key_t _key;
#else
    cache_key_t _key;//SEL作为key 
    MethodCacheIMP _imp; //函数地址
#endif
}
```

散列表的数据结构表格所示

|索引|bucket_t|
|---|---|
|0|bucket_t(_key,_imp)|
|1|bucket_t(_key,_imp)|
|2|bucket_t(_key,_imp)|
|3|bucket_t(_key,_imp)|
|4|bucket_t(_key,_imp)|
|...|...|
通过`cache_getImp(cls, sel)`获取`IMP`。具体在`cache_t::find`函数中

```
bucket_t * cache_t::find(cache_key_t k, id receiver)
{
    assert(k != 0);

    bucket_t *b = buckets();
    mask_t m = mask();
	//key&mask 得到索引
    mask_t begin = cache_hash(k, m);
    mask_t i = begin;
    do {
        if (b[i].key() == 0  ||  b[i].key() == k) {
            return &b[i];
        }
    } while ((i = cache_next(i, m)) != begin);

    // hack
    Class cls = (Class)((uintptr_t)this - offsetof(objc_class, cache));
    cache_t::bad_cache(receiver, (SEL)k, cls);
}

// Class points to cache. SEL is key. Cache buckets store SEL+IMP.
// Caches are never built in the dyld shared cache.

static inline mask_t cache_hash(cache_key_t key, mask_t mask) 
{
    return (mask_t)(key & mask);
}
```

首先获取`buckets()`获取`butket_t`,然后获取`_mask`，通过
`cache_hash(k, m)`获取第一次访问的索引`i`，`cache_hash`通过`(mask_t)(key & mask)`得出具体的`索引`,当第一次成功获取到`butket_t`则直接返回,否则执行`cache_next(i, m)`获取下一个索引，直到获取到或者循环一遍结束。
那么我们来验证一下已经执行的函数的确是存在cache中的，我们自定义了`class_rw_t`

```
#import <Foundation/Foundation.h>

#ifndef MJClassInfo_h
#define MJClassInfo_h

# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
# endif

#if __LP64__
typedef uint32_t mask_t;
#else
typedef uint16_t mask_t;
#endif
typedef uintptr_t cache_key_t;

#if __arm__  ||  __x86_64__  ||  __i386__
// objc_msgSend has few registers available.
// Cache scan increments and wraps at special end-marking bucket.
#define CACHE_END_MARKER 1
static inline mask_t cache_next(mask_t i, mask_t mask) {
    return (i+1) & mask;
}

#elif __arm64__
// objc_msgSend has lots of registers available.
// Cache scan decrements. No end marker needed.
#define CACHE_END_MARKER 0
static inline mask_t cache_next(mask_t i, mask_t mask) {
    return i ? i-1 : mask;
}

#else
#error unknown architecture
#endif

struct bucket_t {
    cache_key_t _key;
    IMP _imp;
};

struct cache_t {
    bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
    
    IMP imp(SEL selector)
    {
        mask_t begin = _mask & (long long)selector;
        mask_t i = begin;
        do {
            if (_buckets[i]._key == 0  ||  _buckets[i]._key == (long long)selector) {
                return _buckets[i]._imp;
            }
        } while ((i = cache_next(i, _mask)) != begin);
        return NULL;
    }
};

struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    uint32_t count;
};

struct method_t {
    SEL name;
    const char *types;
    IMP imp;
};

struct method_list_t : entsize_list_tt {
    method_t first;
};

struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    uint32_t alignment_raw;
    uint32_t size;
};

struct ivar_list_t : entsize_list_tt {
    ivar_t first;
};

struct property_t {
    const char *name;
    const char *attributes;
};

struct property_list_t : entsize_list_tt {
    property_t first;
};

struct chained_property_list {
    chained_property_list *next;
    uint32_t count;
    property_t list[0];
};

typedef uintptr_t protocol_ref_t;
struct protocol_list_t {
    uintptr_t count;
    protocol_ref_t list[0];
};

struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;  // instance对象占用的内存空间
#ifdef __LP64__
    uint32_t reserved;
#endif
    const uint8_t * ivarLayout;
    const char * name;  // 类名
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;  // 成员变量列表
    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;
};

struct class_rw_t {
    uint32_t flags;
    uint32_t version;
    const class_ro_t *ro;
    method_list_t * methods;    // 方法列表
    property_list_t *properties;    // 属性列表
    const protocol_list_t * protocols;  // 协议列表
    Class firstSubclass;
    Class nextSiblingClass;
    char *demangledName;
};

#define FAST_DATA_MASK          0x00007ffffffffff8UL
struct class_data_bits_t {
    uintptr_t bits;
public:
    class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
};

/* OC对象 */
struct mj_objc_object {
    void *isa;
};

/* 类对象 */
struct mj_objc_class : mj_objc_object {
    Class superclass;
    cache_t cache;
    class_data_bits_t bits;
public:
    class_rw_t* data() {
        return bits.data();
    }
    
    mj_objc_class* metaClass() {
        return (mj_objc_class *)((long long)isa & ISA_MASK);
    }
};

#endif
```

测试代码是

```
FYPerson *p = [[FYPerson alloc]init];
		Method test1Method = class_getInstanceMethod(p.class, @selector(test));
		Method test2Method = class_getInstanceMethod(p.class, @selector(test2));
		IMP imp1= method_getImplementation(test1Method);
		IMP imp2= method_getImplementation(test2Method);

		mj_objc_class *cls = (__bridge mj_objc_class *)p.class;
		NSLog(@"-----");
		[p test];
		[p test2];
		cache_t cache = cls->cache;
		bucket_t *buck = cache._buckets;
		
		
		for (int i = 0; i <= cache._mask; i ++) {
			bucket_t item = buck[i];
			if (item._key != 0) {
				NSLog(@"key:%lu imp:%p",item._key,item._imp);
			}
		}
		
		
		//输出
p imp1
(IMP) $0 = 0x0000000100000df0 (day11-runtime1`-[FYPerson test] at FYPerson.m:12)
(lldb) p imp2
(IMP) $1 = 0x0000000100000e20 (day11-runtime1`-[FYPerson test2] at FYPerson.m:15)
p/d @selector(test)             //输出 test方法的sel地址
(SEL) $6 = 140734025103231 "test"
(lldb) p/d @selector(test2)     //输出 test2方法的sel地址
(SEL) $7 = 4294971267 "test2"

key1:140733954181041 imp1:0x7fff59fc4cd1
key2:4294971267 imp2:0x100000e20         //对应test2
key3:140734025103231 imp3:0x100000df0    //对应test1
```

可以看出来`IMP1`和`IMP2`、`key1` 和`key2`分别对应了`bucket_t`中的`key2`,`key3`和`imp2`和`imp3`。


```
static void cache_fill_nolock(Class cls, SEL sel, IMP imp, id receiver)
{
    cacheUpdateLock.assertLocked();

    //当initialized 没有执行完毕的时候不缓存
    if (!cls->isInitialized()) return;

    // Make sure the entry wasn't added to the cache by some other thread 
    // before we grabbed the cacheUpdateLock.
    if (cache_getImp(cls, sel)) return;

    cache_t *cache = getCache(cls);
    cache_key_t key = getKey(sel);

    // Use the cache as-is if it is less than 3/4 full
    mask_t newOccupied = cache->occupied() + 1;
    mask_t capacity = cache->capacity();
    if (cache->isConstantEmptyCache()) {
        // Cache is read-only. Replace it.
        cache->reallocate(capacity, capacity ?: INIT_CACHE_SIZE);
    }
    else if (newOccupied <= capacity / 4 * 3) {
        // Cache <= 3/4 
    }
    else {
        扩容 之后，缓存清空
        cache->expand();
    }
//bucket_t 最小是4，当>3/4时候，扩容，空间扩容之后是之前的2️倍。
    bucket_t *bucket = cache->find(key, receiver);
    if (bucket->key() == 0) cache->incrementOccupied();
    bucket->set(key, imp);
}
```

`cache_t`初始化是大小是4，当大于3/4时，进行扩容，扩容之后是之前的2倍，数据被清空，`cacha->_occupied`恢复为0。
验证代码如下：

```
FYPerson *p = [[FYPerson alloc]init];
mj_objc_class *cls = (__bridge mj_objc_class *)p.class;
NSLog(@"-----");
[p test];
/*
 key:init imp:0x7fff58807c2d
 key:class imp:0x7fff588084b7
 key:(null) imp:0x0
 key:test imp:0x100000bf0
 Program ended with exit code: 0
 */
[p test2]; //当执行该函数的时候
/*
 key:(null) imp:0x0
 key:(null) imp:0x0
 key:(null) imp:0x0
 key:(null) imp:0x0
 key:(null) imp:0x0
 key:(null) imp:0x0
 key:test2 imp:0x100000c20
 key:(null) imp:0x0
 */

cache_t cache = cls->cache;
bucket_t *buck = cache._buckets;


for (int i = 0; i <= cache._mask; i ++) {
	bucket_t item = buck[i];
//            if (item._key != 0) {
////                printf("key:%s imp:%p \n",(const char *)item._key,item._imp);
//            }
    printf("key:%s imp:%p \n",(const char *)item._key,item._imp);

}
```

### 总结
- arm64之后isa使用联合体用更少的空间存储更多的数据，arm64之前存储class和meta-class指针。
- 函数执行会先从cache中查找，没有的话，当再次找到该函数会添加到cache中
- 从`class->cache`查找`bucket_t`的key需要先`&_mask`之后再判断是否有该`key`
- cache扩容在大于3/4进行2倍扩容，扩容之后，旧数据删除，`imp`个数清空
- `class->rw`在初始化中讲`class_ro_t`值赋值给`rw`,然后`rw->ro`指向之前的`ro`。



#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

 ---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](/images/0.png)



