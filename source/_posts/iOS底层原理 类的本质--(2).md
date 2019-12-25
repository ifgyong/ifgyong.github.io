title: iOS底层原理  类的本质 --(2)
date: 2019-12-1 11:12:58
tags:
- iOS
categories: iOS
---

### 底层原理 类的本质
复习一下[IOS 底层原理 对象的本质--(1)]()，可以看出来实例对象实际是上结构体，那么这个结构体是有类指针和成员变量组成的。

```
//Person
@interface Person : NSObject
{
	@public
	int _age;//4bytes
	int _level;//4bytes
	int _code;//4bytes
}
@end
@implementation Person
@end
```
<!-- more -->
经过`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main64.cpp`编译之后其实`Person`对象是:

```
struct Person_IMPL {
	struct NSObject_IMPL NSObject_IVARS;
	int _age;
	int _level;
	int _code;
};
```

`NSObject_IMPL`结构体：

```
struct NSObject_IMPL {
	Class isa;
};
```

那么`NSObject`在内存中包括
- `isa`指针
- 其他成员变量

![](/images/2-1.png)

`isa`地址就是`instance`的地址，其他成员变量排在后边，也就是`instance`的地址就是`isa`的地址。

那么这个`isa`指向的到底是什么呢？
请往下继续看：
先看下这段代码：

```
NSObject *ob1=[[NSObject alloc]init];
NSObject *ob2=[[NSObject alloc]init];

Class cl1 = object_getClass([ob1 class]);
Class cl2 = object_getClass([ob2 class]);

Class cl3 = ob1.class;
Class cl4 = ob2.class;

Class cl5 = NSObject.class;

NSLog(@" %p %p %p %p %p",cl1,cl2,cl3,cl4,cl5);
//0x7fff8e3ba0f0 0x7fff8e3ba0f0 
//0x7fff8e3ba140 0x7fff8e3ba140 0x7fff8e3ba140
```

这代码是输出了几个`NSObject`的对象的类和`NSObject`的类对象的地址，可以看到`cl1==cl2`、`cl3==cl4==cl5`。


#### Class的本质
我们知道不管是类对象还是元类对象，类型都是Class，class和mete-class的底层都是objc_class结构体的指针，内存中就是结构体。

```
Class objectClass = [NSObject class];        
Class objectMetaClass = object_getClass([NSObject class]);

```

点击class来到内部，可以发现

```
typedef struct objc_class *Class;
```

`class`对象其实是指向objc_class的结构体，因此我们可以说类对象或元类对象在内存中其实就是objc_class结构体。

来到`objc_class`内部，在源码中经常看到这段源码

```
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;//isa

#if !__OBJC2__
    Class _Nullable super_class                    //父类          OBJC2_UNAVAILABLE;
    const char * _Nonnull name                              //obj名字 OBJC2_UNAVAILABLE;
    long version                                            //版本 OBJC2_UNAVAILABLE;
    long info                                               //info OBJC2_UNAVAILABLE;
    long instance_size                                      // OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars             //成员变量链表     OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;//方法链表
    struct objc_cache * _Nonnull cache      //缓存链表                 OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols         //协议链表 OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```

这段代码明显是 已经`OBJC2_UNAVAILABLE`，说明代码已经不在使用了。那么`objc_class`结构体内部结构到底是什么呢？通过objc搜寻`runtime`的内容可以看到`objc_class`内部

```
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags

    class_rw_t *data() { 
        return bits.data();
    }
    void setData(class_rw_t *newData) {
        bits.setData(newData);
    }

    void setInfo(uint32_t set) {
        assert(isFuture()  ||  isRealized());
        data()->setFlags(set);
    }

    void clearInfo(uint32_t clear) {
        assert(isFuture()  ||  isRealized());
        data()->clearFlags(clear);
    }
    //**后边省略
```

我们发现这个结构体继承 `objc_object` 并且结构体内有一些函数，因为这是`c++`结构体，在c上做了扩展，因此结构体中可以包含函数。我们来到`objc_object`内，截取部分代码

```
struct objc_object {
private:
    isa_t isa;

public:

    // ISA() assumes this is NOT a tagged pointer object
    Class ISA();

    // getIsa() allows this to be a tagged pointer object
    Class getIsa();

    // initIsa() should be used to init the isa of new objects only.
    // If this object already has an isa, use changeIsa() for correctness.
    // initInstanceIsa(): objects with no custom RR/AWZ
    // initClassIsa(): class objects
    // initProtocolIsa(): protocol objects
    // initIsa(): other objects
    void initIsa(Class cls /*nonpointer=false*/);
    void initClassIsa(Class cls /*nonpointer=maybe*/);
    void initProtocolIsa(Class cls /*nonpointer=maybe*/);
    void initInstanceIsa(Class cls, bool hasCxxDtor);
```
那么我们之前了解到的，类中存储的类的成员变量信息，方法列表，协议列表，截取`class_rw_t`内部实现代码

```
struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;//方法列表
    property_array_t properties;//属性列表
    protocol_array_t protocols;//协议列表

    Class firstSubclass;
    Class nextSiblingClass;
**
//后边省略
}
```

而`class_rw_t`是通过`bits.data()`获取的，截取`bits.data()`查看内部实现,而仅仅是`bits&FAST_DATA_MASK`。

```
    class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
```

而成员变量则是存储在`class_ro_t`内部中的，我们来到`class_ro_t`内部查看：

```
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;
    
    const char * name;
    method_list_t * baseMethodList;//方法列表
    protocol_list_t * baseProtocols;//协议列表
    const ivar_list_t * ivars;//成员变量列表

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;//属性列表

    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};
```

最后通过一张图总结一下：

![](/images/2-2.png)

那么我们来证明一下：
我们可以自定义一下一个和系统一样的结构体，那么我们当我们强制转化的时候，他们赋值会一一对应，此时我们就可以拿到结构体的内部的值。
下边代码是我们自定义的值：

```
//
//  Header.h
//  day02-类的本质1
//
//  Created by Charlie on 2019/7/2.
//  Copyright © 2019 www.fgyong.cn. All rights reserved.
//

#ifndef Header_h
#define Header_h

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

struct bucket_t {
	cache_key_t _key;
	IMP _imp;
};

struct cache_t {
	bucket_t *_buckets;
	mask_t _mask;
	mask_t _occupied;
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
	class_rw_t* data() { // 提供data()方法进行 & FAST_DATA_MASK 操作
		return (class_rw_t *)(bits & FAST_DATA_MASK);
	}
};

/* OC对象 */
struct xx_objc_object {
	void *isa;
};

/* 类对象 */
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
#endif /* Header_h */

```

这段代码亲测可用，直接复制自己新建`.h`文件导入'main.m'即可，将`main.m`改成`main.mm`或者将其他某一个`.m`改成`.mm`运行就可以运行了。

那么我们再拿出来经典的那张图挨着分析`isa` 和`superclass`的指向

![](/images/2-2.png)
#### instance 对象验证
使用 `p/x`输出`obj`16进制的地址，然后**isa指针需要经过一次 & ISA_MASK操作之后才得到真正的地址**。实施之后：

```
//object

Printing description of student:
<Student: 0x1021729c0>
(lldb) p/x object->isa //查看isa指针地址
(Class) $0 = 0x001dffff8e3ba141 NSObject 
(lldb) p/x objectClass//输出 objectClass的地址
(fy_objc_class *) $1 = 0x00007fff8e3ba140
(lldb) p/x 0x001dffff8e3ba141&0x00007ffffffffff8//计算得出object->isa真正的地址
(long) $2 = 0x00007fff8e3ba140 //0x00007fff8e3ba140是 objectClass地址和object->isa地址一样


//person

Printing description of person: <Person: 0x102175300>
(lldb) p/x person->isa
(Class) $3 = 0x001d800100002469 Person
(lldb) p/x 0x001d800100002469&0x00007ffffffffff8
(long) $4 = 0x0000000100002468
(lldb) p/x personClass
(fy_objc_class *) $5 = 0x0000000100002468//isa 和personclass地址都是0x0000000100002468

//student

(lldb) p/x student->isa
(Class) $6 = 0x001d8001000024b9 Student
(lldb) p/x 0x001d8001000024b9&0x00007ffffffffff8
(long) $7 = 0x00000001000024b8
(lldb) p/x studentClass
(fy_objc_class *) $8 = 0x00000001000024b8//studentclass 和isa地址都是0x00000001000024b8
(lldb) 
```
从面的输出结果中我们可以发现instance对象中确实存储了isa指针和其成员变量，同时将instance对象的isa指针经过&运算之后计算出的地址确实是其相应类对象的内存地址。由此我们证明isa，superclass指向图中的1，2，3号线。



#### class 对象验证
接着我们来看`class`对象，同样通过上一篇文章，我们明确`class`对象中存储着`isa`指针，`superclass`指针，以及类的属性信息，类的成员变量信息，类的对象方法，和类的协议信息，而通过上面对`object`源码的分析，我们知道这些信息存储在`class`对象的`class_rw_t`中，我们通过强制转化来窥探其中的内容

```
//objectClass and objectMetaClass

(lldb) p/x objectClass->isa
(__NSAtom *) $6 = 0x001dffff8e3ba0f1
(lldb) p/x 0x001dffff8e3ba0f1&0x00007ffffffffff8
(long) $7 = 0x00007fff8e3ba0f0
(lldb) p/x objectMetaClass
(fy_objc_class *) $8 = 0x00007fff8e3ba0f0

//personClass and personMetaClass

(lldb) p/x personClass->isa
(__NSAtom *) $9 = 0x001d800100002441
(lldb) p/x personMetaClass
(fy_objc_class *) $10 = 0x0000000100002440
(lldb) p/x 0x001d800100002441&0x00007ffffffffff8
(long) $11 = 0x0000000100002440

//sutdentClass and studentMetaClass

(lldb) p/x studentClass->isa
(__NSAtom *) $12 = 0x001d800100002491
(lldb) p/x 0x001d800100002491&0x00007ffffffffff8
(long) $13 = 0x0000000100002490
(lldb) p/x studentMetaClass
(fy_objc_class *) $14 = 0x0000000100002490

```
有此结果得知`objectMetaClass==objectClass->isa==0x00007fff8e3ba0f0`,`personClass->isa==personMetaClass==0x0000000100002440`,`studentClass->isa==studentMetaClass==0x0000000100002490`。
由此我们证明isa，superclass指向图中，isa指针的4，5，6号线，以及superclass指针的7,8,9号线。

#### meta-class对象验证

最后我们来看`meta-class`元类对象，上文提到`meta-class`中存储着`isa`指针，`superclass`指针，以及类的类方法信息。同时我们知道`meta-class`元类对象与`class`类对象，具有相同的结构，只不过存储的信息不同，并且元类对象的`isa`指针指向基类的元类对象，基类的元类对象的`isa`指针指向自己。元类对象的`superclass`指针指向其父类的元类对象，基类的元类对象的`superclass`指针指向其类对象。
与`class`对象相同，我们同样通过模拟对`person`元类对象调用`.data`函数，即对`bits`进行`&FAST_DATA_MASK(0x00007ffffffffff8UL)`运算，并转化为`class_rw_t`。

```
// objectMetaClass->superclass = 0x00007fff8e3ba140  NSObject
//objectMetaClass->isa =   0x00007fff8e3ba0f0
//objectMetaClass = 0x00007fff8e3ba0f0

(lldb) p/x objectMetaClass->superclass
(Class) $20 = 0x00007fff8e3ba140 NSObject
(lldb) p/x objectMetaClass->isa
(__NSAtom *) $21 = 0x001dffff8e3ba0f1
(lldb) p/x 0x001dffff8e3ba0f1&0x00007ffffffffff8
(long) $22 = 0x00007fff8e3ba0f0
(lldb) p/x objectMetaClass
(fy_objc_class *) $23 = 0x00007fff8e3ba0f0

// personMetaClass->superclas=0x00007fff8e3ba0f0
//personMetaClass->isa=0x00007fff8e3ba0f0
//personMetaClass = 0x0000000100002440

(lldb) p/x personMetaClass->superclass
(Class) $25 = 0x00007fff8e3ba0f0
(lldb) p/x personMetaClass->isa
(__NSAtom *) $26 = 0x001dffff8e3ba0f1
(lldb) p/x personMetaClass
(fy_objc_class *) $30 = 0x0000000100002440

// studentMetaClass->superclas=0x0000000100002440
//studentMetaClass->isa=0x00007fff8e3ba0f0


(lldb) p/x studentMetaClass->superclass
(Class) $27 = 0x0000000100002440
(lldb) p/x studentMetaClass->isa
(__NSAtom *) $28 = 0x001dffff8e3ba0f1
(lldb) p/x 0x001dffff8e3ba0f1 & 0x00007ffffffffff8
(long) $29 = 0x00007fff8e3ba0f0
```

由上面可以看出，`studentMetaClass->isa`,`personMetaClass->isa`,`objectMetaClass->isa`结果`mask`之后都是`0x00007fff8e3ba0f0`，与`p/x objectMetaClass`结果一致，则验证了13，14，15号线，`studentMetaClass->superclass =0x0000000100002440 `,`personMetaClass = 0x0000000100002440`验证12号线，`personMetaClass->isa=0x00007fff8e3ba0f0
`和`objectMetaClass = 0x00007fff8e3ba0f0`验证了11号线，`objectMetaClass->superclass = 0x00007fff8e3ba140  NSObject`验证10号线。

#### 总结：
对象的isa指向哪里？
- instance对象的isa指向class对象
- class对象的isa指向meta-class对象
- meta-class对象的isa指向基类的meta-class对象
- class和meta-class的内存结构一样的，只是值不一样


OC的类信息存放在哪里？
- 对象方法、属性、成员变量、协议信息存放在class对象中
- 类方法存放在meta-class对象中
- 成员变量具体值存放在instance对象中


#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)

---
最怕一生碌碌无为，还安慰自己平凡可贵。

本文章之所以图片比较少，我觉得还是跟着代码敲一遍，印象比较深刻。



![](/images/0.png)









/