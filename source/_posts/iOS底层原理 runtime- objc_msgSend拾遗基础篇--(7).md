title: iOS底层原理 runtime- objc_msgSend拾遗基础篇--(7)
date: 2019-12-1 11:17:58
tags:
- iOS
categories: iOS
---

arm64之后isa是使用联合体使用更少的空间存储更多的数据，以及如何自定义和使用联合体，`objc_class->cache_t cache`是一个是缓存最近调用`class`的方法，当缓存剩余空间小余1/4则进行扩容，扩容为原来的两倍，扩容之后，已存储的`method_t`扩容之后之后被清空。今天我们在了解runtime的消息转发机制。
#### 基础知识

OC中的方法调用，其实都是转换为objc_msgSend函数的调用

objc_msgSend的执行流程可以分为3大阶段

1. 消息发送
2. 动态方法解析
3. 消息转发

那么我们根据这三块内容进行源码解读。源码执行的顺序大概如下

<!-- more -->

```
objc-msg-arm64.s
ENTRY _objc_msgSend
b.le	LNilOrTagged //<0则返回
CacheLookup NORMAL //缓存查找 未命中则继续查找
.macro CacheLookup// 通过宏 查找cache，命中直接call or return imp
.macro CheckMiss //miss 则跳转__objc_msgSend_uncached
STATIC_ENTRY __objc_msgSend_uncached 
.macro MethodTableLookup//方法中查找
__class_lookupMethodAndLoadCache3//跳转->__class_lookupMethodAndLoadCache3 在runtime-class-new.mm 4856行


objc-runtime-new.mm
_class_lookupMethodAndLoadCache3
lookUpImpOrForward
getMethodNoSuper_nolock、search_method_list、log_and_fill_cache
cache_getImp、log_and_fill_cache、getMethodNoSuper_nolock、log_and_fill_cache
_class_resolveInstanceMethod
_objc_msgForward_impcache


objc-msg-arm64.s
STATIC_ENTRY __objc_msgForward_impcache
ENTRY __objc_msgForward

Core Foundation
__forwarding__（不开源）
```

### 消息发送

`objc_msgSend`是汇编写的，在源码`objc-msg-arm64.s`304行，是`objc_msgSend`的开始，`_objc_msgSend`结束是351行,
进入到`objc_msgSend`函数内部一探究竟：

```
	ENTRY _objc_msgSend // _objc_msgSend 开始
	UNWIND _objc_msgSend, NoFrame

	cmp	p0, #0			// 检查p0寄存器是否是0  _objc_msgSend()第一个参数:self
#if SUPPORT_TAGGED_POINTERS
	b.le	LNilOrTagged		// if le < 0 ->  跳转到标签  LNilOrTagged
#else
	b.eq	LReturnZero // if le == 0 ->  跳转到标签  LReturnZero
#endif
	ldr	p13, [x0]		// p13 = isa
	GetClassFromIsa_p16 p13		// p16 = class
LGetIsaDone:
	CacheLookup NORMAL		// calls imp or objc_msgSend_uncached

#if SUPPORT_TAGGED_POINTERS
LNilOrTagged:
	b.eq	LReturnZero		// 如果==0 -> LReturnZero

	// tagged
	adrp	x10, _objc_debug_taggedpointer_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_classes@PAGEOFF
	ubfx	x11, x0, #60, #4
	ldr	x16, [x10, x11, LSL #3]
	adrp	x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGE
	add	x10, x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGEOFF
	cmp	x10, x16
	b.ne	LGetIsaDone

	// ext tagged
	adrp	x10, _objc_debug_taggedpointer_ext_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_ext_classes@PAGEOFF
	ubfx	x11, x0, #52, #8
	ldr	x16, [x10, x11, LSL #3]
	b	LGetIsaDone
// SUPPORT_TAGGED_POINTERS
#endif

LReturnZero:
	// x0 is already zero
	mov	x1, #0
	movi	d0, #0
	movi	d1, #0
	movi	d2, #0
	movi	d3, #0
	ret //return 返回结束掉

	END_ENTRY _objc_msgSend // _objc_msgSend 结束
```

当`objc_msgSend(id,SEL,arg)`的`id`为空的时候，跳转标签`LNilOrTagged`,进入标签内，当等于0则跳转`LReturnZero`,进入到`LReturnZero`内，清除数据和return。不等于零，获取isa和class，调用`CacheLookup NORMAL`,进入到`CacheLookup`内部

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

汇编代码左边是代码，右边是注释，大概都可以看懂的。
当命中则`return imp`,否则则跳转`CheckMiss`,进入到`CheckMiss`内部：

```
.macro CheckMiss
	// miss if bucket->sel == 0
.if $0 == GETIMP
	cbz	p9, LGetImpMiss
.elseif $0 == NORMAL
	cbz	p9, __objc_msgSend_uncached
.elseif $0 == LOOKUP
	cbz	p9, __objc_msgLookup_uncached
.else
.abort oops
.endif
.endmacro
```

刚才传的值是`NORMAL`，则跳转`__objc_msgSend_uncached`，进入到`__objc_msgSend_uncached`内部(484行)：

```
	STATIC_ENTRY __objc_msgSend_uncached
	UNWIND __objc_msgSend_uncached, FrameWithNoSaves
	MethodTableLookup
	TailCallFunctionPointer x17
	END_ENTRY __objc_msgSend_uncached
```

调用`MethodTableLookup`,我们查看`MethodTableLookup`内部：

```
.macro MethodTableLookup
	// push frame
	SignLR
	stp	fp, lr, [sp, #-16]!
	mov	fp, sp

	// save parameter registers: x0..x8, q0..q7
	sub	sp, sp, #(10*8 + 8*16)
	stp	q0, q1, [sp, #(0*16)]
	stp	q2, q3, [sp, #(2*16)]
	stp	q4, q5, [sp, #(4*16)]
	stp	q6, q7, [sp, #(6*16)]
	stp	x0, x1, [sp, #(8*16+0*8)]
	stp	x2, x3, [sp, #(8*16+2*8)]
	stp	x4, x5, [sp, #(8*16+4*8)]
	stp	x6, x7, [sp, #(8*16+6*8)]
	str	x8,     [sp, #(8*16+8*8)]

	// receiver and selector already in x0 and x1
	mov	x2, x16
	bl	__class_lookupMethodAndLoadCache3//跳转->__class_lookupMethodAndLoadCache3 在runtime-class-new.mm 4856行

	// IMP in x0
	mov	x17, x0
	
	// restore registers and return
	ldp	q0, q1, [sp, #(0*16)]
	ldp	q2, q3, [sp, #(2*16)]
	ldp	q4, q5, [sp, #(4*16)]
	ldp	q6, q7, [sp, #(6*16)]
	ldp	x0, x1, [sp, #(8*16+0*8)]
	ldp	x2, x3, [sp, #(8*16+2*8)]
	ldp	x4, x5, [sp, #(8*16+4*8)]
	ldp	x6, x7, [sp, #(8*16+6*8)]
	ldr	x8,     [sp, #(8*16+8*8)]

	mov	sp, fp
	ldp	fp, lr, [sp], #16
	AuthenticateLR
.endmacro

```

最终跳转到`__class_lookupMethodAndLoadCache3`,去掉一个下划线就是c函数，在`runtime-class-new.mm 4856行`,
调用了函数`lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);`,第一次会初始化`cls`和`resolver`的值，
中最终跳转到`c/c++`函数`lookUpImpOrForward`，该函数是最终能看到的`c/c++`,现在我们进入到`lookUpImpOrForward`内部查看：

```
/***********************************************************************
* lookUpImpOrForward.
* initialize==NO 尽量避免调用，有时可能也会调用。
* cache==NO 跳过缓存查找，其他地方可能会不调过
* 大多数人会传值 initialize==YES and cache==YES
*   如果cls是非初始化的元类，则非Non-nil会快点
* May return _objc_msgForward_impcache. IMPs destined for external use 
*   must be converted to _objc_msgForward or _objc_msgForward_stret.
* 如果你不想用forwarding，则调用lookUpImpOrNil()代替
**********************************************************************/
IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;

    runtimeLock.assertUnlocked();
    // Optimistic cache lookup
    if (cache) { //从汇编过来是NO
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }

    runtimeLock.lock();
    checkIsKnownClass(cls);

    if (!cls->isRealized()) {
        realizeClass(cls);
    }

    if (initialize  &&  !cls->isInitialized()) {
		//当cls需要初始化和没有初始化的时候 进行cls初始化，
		//初始化会加入到一个线程，同步执行，先初始化父类，再初始化子类
		//数据的大小最小是4，扩容规则是：n*2+1;
        runtimeLock.unlock();
        _class_initialize (_class_getNonMetaClass(cls, inst));
        runtimeLock.lock();
    }

    
 retry:    
    runtimeLock.assertLocked();

//再次获取imp
    imp = cache_getImp(cls, sel);
    if (imp) goto done;

    //尝试在本类中查找method
    {//从cls->data()->methods查找method
        Method meth = getMethodNoSuper_nolock(cls, sel);
        if (meth) {//找到添加到cache中
            log_and_fill_cache(cls, meth->imp, sel, inst, cls);
            imp = meth->imp;
            goto done;
        }
    }

    // Try superclass caches and method lists.
	//从cls->superclass->data()->methods查找methd，supercls没有查找出来，再查找父类的父类。
    {
        unsigned attempts = unreasonableClassCount();
        for (Class curClass = cls->superclass;
             curClass != nil;
             curClass = curClass->superclass)
        {
            // Halt if there is a cycle in the superclass chain.
            if (--attempts == 0) {
                _objc_fatal("Memory corruption in class list.");
            }
            
            // Superclass cache.
            imp = cache_getImp(curClass, sel);
            if (imp) {
                if (imp != (IMP)_objc_msgForward_impcache) {
                    // Found the method in a superclass. Cache it in this class.
					//将父类添加到 子类的缓存中
                    log_and_fill_cache(cls, imp, sel, inst, curClass);
                    goto done;
                }
                else {
                    // Found a forward:: entry in a superclass.
                    // Stop searching, but don't cache yet; call method 
                    // resolver for this class first.
                    break;
                }
            }
            
            // Superclass method list.
            Method meth = getMethodNoSuper_nolock(curClass, sel);
            if (meth) {
                log_and_fill_cache(cls, meth->imp, sel, inst, curClass);
                imp = meth->imp;
                goto done;
            }
        }
    }

	//如果还没有找到imp，进入动态方法解析阶段
    if (resolver  &&  !triedResolver) {
        runtimeLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        runtimeLock.lock();
        triedResolver = YES;
        goto retry;
    }

    //如果没找到resolveInstanceMethod 和resolveClassMethod，
//	进行消息转发 阶段
    imp = (IMP)_objc_msgForward_impcache;
	//填充 cache
    cache_fill(cls, sel, imp, inst);
 done:
    runtimeLock.unlock();
    return imp;
}


```
`SUPPORT_INDEXED_ISA`是在`arm64`和`LP64` 还有`arm_arch_7k>2`为1，`iphone`属于`arm64`、`mac os`属于`LP64`,所以`SUPPORT_INDEXED_ISA = 1`.

```
// Define SUPPORT_INDEXED_ISA=1 on platforms that store the class in the isa 
// field as an index into a class table.
// Note, keep this in sync with any .s files which also define it.
// Be sure to edit objc-abi.h as well.
// __ARM_ARCH_7K__ 处理器架构指令集版本
//__arm64__ 架构
//__LP64__ uinx 和uinx  mac os
#if __ARM_ARCH_7K__ >= 2  ||  (__arm64__ && !__LP64__)
#   define SUPPORT_INDEXED_ISA 1
#else
#   define SUPPORT_INDEXED_ISA 0
#endif

```
`lookUpImpOrForward`函数的 大概思路如下：

首次已经从缓存中查过没有命中所以不再去缓存中查了，然后判断`cls`是否已经实现，`cls->isRealized()`，没有实现的话进行实现`realizeClass(cls)`，主要是将初始化`read-write data`和其他的一些数据，后续会细讲。然后进行`cls`的初始化`_class_initialize()`，当`cls`需要初始化和没有初始化的时候进行cls初始化，初始化会加入到一个线程，同步执行，先初始化父类，再初始化子类,数据的大小最小是4，扩容规则是：`n*2+1`;然后再次获取imp`cache_getImp`,然后在`cls`方法中查找该`method`，然后就是在`superclass`中查找方法，直到父类是nil，找到的话，获取`imp`并将`cls`和`sel`加入到`cache`中，否则进入到消息解析阶段`_class_resolveMethod`，在转发阶段，不是元类的话，进入到`_class_resolveInstanceMethod`是元类的话调用`_class_resolveClassMethod`,这两种分别都会进入到`lookUpImpOrNil`，再次查找`IMP`，当没找到的话就返回，找到的话用`objc_msgSend`发送消息实现调用`SEL_resolveInstanceMethod`并标记`triedResolver`为已动态解析标志。然后进入到消息动态转发阶段`_objc_msgForward_impcache`,至此`runtime`发送消息结束。

借用网上找一个图， 可以更直观的看出流程运转。


![](/images/7-1.png)


#### realizeClass()解析
`realizeClass`是初始化了很多数据，包括`cls->ro`赋值给`cls->rw`，添加元类`version`为7,`cls->chooseClassArrayIndex()`设置`cls`的索引，`supercls = realizeClass(remapClass(cls->superclass));
    metacls = realizeClass(remapClass(cls->ISA()))`初始化`superclass`和`cls->isa`,后边针对没有优化的结构进行赋值这里不多讲，然后协调实例变量偏移布局，设置`cls->setInstanceSize`,拷贝`flags`从`ro`到`rw`中，然后添加`subclass`和`rootclass`，最后添加类别的方法，协议，和属性。

```
/***********************************************************************
* realizeClass
 cls第一次初始化会执行，包括cls->rw->data(),返回真实的cls 结构体
 runtimelock 必须有调用者把写入锁锁起来
**********************************************************************/
static Class realizeClass(Class cls)
{
    runtimeLock.assertLocked();

    const class_ro_t *ro;
    class_rw_t *rw;
    Class supercls;
    Class metacls;
    bool isMeta;

    if (!cls) return nil;
    if (cls->isRealized()) return cls;
    assert(cls == remapClass(cls));

    // fixme verify class is not in an un-dlopened part of the shared cache?
//首先将tw赋值给to，因为数据结构一样可以直接强制转化
    ro = (const class_ro_t *)cls->data();
    if (ro->flags & RO_FUTURE) {//是否已经初始化过，初始化过的哈 则 cls->rw 已经初始化过
        rw = cls->data();
        ro = cls->data()->ro;
        cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
    } else {
        // 正常情况下 申请class_rw_t空间
        rw = (class_rw_t *)calloc(sizeof(class_rw_t), 1);
        rw->ro = ro;//cls->rw->ro 指向现在的ro
        rw->flags = RW_REALIZED|RW_REALIZING;//realized = 1 and  realizing = 1
        cls->setData(rw);//赋值
    }

    isMeta = ro->flags & RO_META;//是否是元类
	

    rw->version = isMeta ? 7 : 0;  // 元类版本是7，旧版的6，否就是0


    // Choose an index for this class.
//设置cls的索引
	cls->chooseClassArrayIndex();

    if (PrintConnecting) {
        _objc_inform("CLASS: realizing class '%s'%s %p %p #%u", 
                     cls->nameForLogging(), isMeta ? " (meta)" : "", 
                     (void*)cls, ro, cls->classArrayIndex());
    }

    // 如果父类没有初始化则进行初始化
    // root_class 做完需要设置RW_REALIZED=1，
    // root metaclasses 需要执行完.
	//从NXMapTable 获取cls ，然后进行初始化
	//从NXMapTable 获取cls->isa ，然后进行初始化
    supercls = realizeClass(remapClass(cls->superclass));
    metacls = realizeClass(remapClass(cls->ISA()));
//没有经过优化的isa执行的，现在已经是version=7，在arm64上是优化过的，这个先不看了。
#if SUPPORT_NONPOINTER_ISA
    // Disable non-pointer isa for some classes and/or platforms.
    // Set instancesRequireRawIsa.
    bool instancesRequireRawIsa = cls->instancesRequireRawIsa();
    bool rawIsaIsInherited = false;
    static bool hackedDispatch = false;

    if (DisableNonpointerIsa) {
        // Non-pointer isa disabled by environment or app SDK version
        instancesRequireRawIsa = true;
    }
    else if (!hackedDispatch  &&  !(ro->flags & RO_META)  &&  
             0 == strcmp(ro->name, "OS_object")) 
    {
        // hack for libdispatch et al - isa also acts as vtable pointer
        hackedDispatch = true;
        instancesRequireRawIsa = true;
    }
    else if (supercls  &&  supercls->superclass  &&  
             supercls->instancesRequireRawIsa()) 
    {
        // This is also propagated by addSubclass() 
        // but nonpointer isa setup needs it earlier.
        // Special case: instancesRequireRawIsa does not propagate 
        // from root class to root metaclass
        instancesRequireRawIsa = true;
        rawIsaIsInherited = true;
    }
    
    if (instancesRequireRawIsa) {
        cls->setInstancesRequireRawIsa(rawIsaIsInherited);
    }
// SUPPORT_NONPOINTER_ISA
#endif

    // Update superclass and metaclass in case of remapping
    cls->superclass = supercls;
    cls->initClassIsa(metacls);

	// 协调实例变量偏移/布局
	//可能重新申请空间 class_ro_t,更新我们的class_ro_t
    if (supercls  &&  !isMeta) reconcileInstanceVariables(cls, supercls, ro);

    // 设置setInstanceSize 从ro->instanceSize
    cls->setInstanceSize(ro->instanceSize);

	//拷贝flags 从ro到rw中
    if (ro->flags & RO_HAS_CXX_STRUCTORS) {
        cls->setHasCxxDtor();
        if (! (ro->flags & RO_HAS_CXX_DTOR_ONLY)) {
            cls->setHasCxxCtor();
        }
    }
//添加superclass指针
    if (supercls) {
        addSubclass(supercls, cls);
    } else {
        addRootClass(cls);
    }

    // Attach categories
	//类别的方法 在编译的时候没有添加到二进制文件中，在运行的时候添加进去的
    methodizeClass(cls);

    return cls;
}
```

这里最后添加类别的数据是调用了`methodizeClass`函数，这个函数首先添加`method_list_t *list = ro->baseMethods()`到`rw->methods.attachLists(&list, 1)`，然后将属性`property_list_t *proplist=ro->baseProperties`添加到`rw->properties.attachLists(&proplist, 1)`,最后将协议列表`protocol_list_t *protolist = ro->baseProtocols`追加到`rw->protocols.attachLists(&protolist, 1)`，如果是`metaclass`则添加`SEL_initialize`,然后从全局`NXMapTable *category_map`删除已经加载的`category_list`,最后调用`attachCategories(cls, cats, false /*don't flush caches*/)`将已经加载的`cats`的方法添加到`cls->rw`上面并且不刷新`caches`。

```
/***********************************************************************
* methodizeClass
 修复cls方法列表想，协议列表和属性列表
* 加锁
**********************************************************************/
static void methodizeClass(Class cls)
{
    runtimeLock.assertLocked();

    bool isMeta = cls->isMetaClass();
    auto rw = cls->data();
    auto ro = rw->ro;

    // Methodizing for the first time
    if (PrintConnecting) {
        _objc_inform("CLASS: methodizing class '%s' %s", 
                     cls->nameForLogging(), isMeta ? "(meta)" : "");
    }

	//方法列表
    method_list_t *list = ro->baseMethods();
    if (list) {
        prepareMethodLists(cls, &list, 1, YES, isBundleClass(cls));
	//将对象的方法追加到cls->rw->methods后面
        rw->methods.attachLists(&list, 1);
    }

    property_list_t *proplist = ro->baseProperties;
    if (proplist) {
	//将对象的属性追加到rw->properties后面
        rw->properties.attachLists(&proplist, 1);
    }

    protocol_list_t *protolist = ro->baseProtocols;
    if (protolist) {
	//将对象的协议追加到rw->protocols后面
        rw->protocols.attachLists(&protolist, 1);
    }

    // Root classes get bonus method implementations if they don't have 
    // them already. These apply before category replacements.
    if (cls->isRootMetaclass()) {
        // root metaclass
        addMethod(cls, SEL_initialize, (IMP)&objc_noop_imp, "", NO);
    }

    // Attach categories.
	//类别 从全局NXMapTable *category_map 已经加载过了。
    category_list *cats = unattachedCategoriesForClass(cls, true /*realizing*/);
	//收集所有的cats到cls -> rw中
    attachCategories(cls, cats, false /*don't flush caches*/);

    if (PrintConnecting) {
        if (cats) {
            for (uint32_t i = 0; i < cats->count; i++) {
                _objc_inform("CLASS: attached category %c%s(%s)", 
                             isMeta ? '+' : '-', 
                             cls->nameForLogging(), cats->list[i].cat->name);
            }
        }
    }
    
    if (cats) free(cats);//释放cats

#if DEBUG
    // Debug: sanity-check all SELs; log method list contents
    for (const auto& meth : rw->methods) {
        if (PrintConnecting) {
            _objc_inform("METHOD %c[%s %s]", isMeta ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(meth.name));
        }
        assert(sel_registerName(sel_getName(meth.name)) == meth.name); 
    }
#endif
}
```

#### attachCategories()解析
`methodizeClass`之前`rw`初始化的时候并没有将其他数据都都复制给`rw`,现在`methodizeClass`实现了将本来的`ro`数据拷贝给`rw`,然后`attachCategories`将
分类的方法，属性，协议追加到`cls->data->rw`，我们进入`attachCategories`内部

```
static void attachCategories(Class cls, category_list *cats, bool flush_caches)
{
    if (!cats) return;
    if (PrintReplacedMethods) printReplacements(cls, cats);

    bool isMeta = cls->isMetaClass();

    // fixme rearrange to remove these intermediate allocations
	//方法数组[[1,2,3],[4,5,6],[7,8,9]]
    method_list_t **mlists = (method_list_t **)
        malloc(cats->count * sizeof(*mlists));
	//属性数组
    property_list_t **proplists = (property_list_t **)
        malloc(cats->count * sizeof(*proplists));
	//协议数组
    protocol_list_t **protolists = (protocol_list_t **)
        malloc(cats->count * sizeof(*protolists));

    // Count backwards through cats to get newest categories first
    int mcount = 0;
    int propcount = 0;
    int protocount = 0;
    int i = cats->count;
    bool fromBundle = NO;
    while (i--) {
		//取出某个分类
        auto& entry = cats->list[i];
//取出分类 的 instance方法或者class方法
        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        if (mlist) {
            mlists[mcount++] = mlist; //mlists 接受所有分类方法
            fromBundle |= entry.hi->isBundle();
        }
//proplist 接受所有分类属性
        property_list_t *proplist = 
            entry.cat->propertiesForMeta(isMeta, entry.hi);
        if (proplist) {
            proplists[propcount++] = proplist;
        }
//proplist 接受所有协议方法
        protocol_list_t *protolist = entry.cat->protocols;
        if (protolist) {
            protolists[protocount++] = protolist;
        }
    }
//收集了所有协议 分类方法
    auto rw = cls->data();

    prepareMethodLists(cls, mlists, mcount, NO, fromBundle);
	//追加所有分类方法
    rw->methods.attachLists(mlists, mcount);
	//释放数组
    free(mlists);
	//刷新该类的缓存
    if (flush_caches  &&  mcount > 0) flushCaches(cls);
//追加所有分类属性
    rw->properties.attachLists(proplists, propcount);
    free(proplists);//释放数组
//追加所有分类协议
    rw->protocols.attachLists(protolists, protocount);
    free(protolists);//释放数组
}
```

#### rw->list->attachLists()解析
添加`attachLists`函数规则是后来的却添加到内存的前部分，这里就清楚为什么后编译类别能后边的类别覆盖前边的类别的相同名字的方法。

```
 void attachLists(List* const * addedLists, uint32_t addedCount) {
        if (addedCount == 0) return;

        if (hasArray()) {
            // many lists -> many lists
            uint32_t oldCount = array()->count;
			//一共需要的数量
            uint32_t newCount = oldCount + addedCount;
			//分配内存 内存不够用了，需要扩容
            setArray((array_t *)realloc(array(), array_t::byteSize(newCount)));
			//赋值count
            array()->count = newCount;
			// array()->lists：原来的方法列表向后移动 oldCount * sizeof(array()->lists[0]个长度
            memmove(array()->lists + addedCount/*数组末尾*/, array()->lists/*数组*/,
                    oldCount * sizeof(array()->lists[0])/*移动的大小*/);
			//空出来的 内存使用addedLists拷贝过去 大小是:addedCount * sizeof(array()->lists[0])
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
			/*
			图示讲解：
			array()->lists:A->B->C->D->E
		addedCount:3
		addedLists:P->L->V
			memmove之后：nil->nil->nil->A->B->C->D->E
			然后再讲addedLists插入到数组前边,最终array()->lists的值是：
			P->L->V->A->B->C->D->E
			 */
        }
        else if (!list  &&  addedCount == 1) {
            // 0 lists -> 1 list
            list = addedLists[0];
        } 
        else {
            // 1 list -> many lists
            List* oldList = list;
            uint32_t oldCount = oldList ? 1 : 0;
            uint32_t newCount = oldCount + addedCount;
            setArray((array_t *)malloc(array_t::byteSize(newCount)));
            array()->count = newCount;
            if (oldList) array()->lists[addedCount] = oldList;
            memcpy(array()->lists, addedLists, 
                   addedCount * sizeof(array()->lists[0]));
        }
    }
```

`class`初始化完成了，然后再次尝试获取`imp = cache_getImp`,由于缓存没有中间也没添加进去，所以这里也是空的，然后从`getMethodNoSuper_nolock`获取该`cls`的方法列表中查找，没有的话再从`superclass`查找`cache`和`method`,找到的话，进行`log_and_fill_cache`至此消息发送完成。

### 消息动态解析

动态解析函数`_class_resolveMethod(cls, sel, inst)`，如果不是元类调用`_class_resolveInstanceMethod`,如果是的话调用`_class_resolveClassMethod`

```
/***********************************************************************
* _class_resolveMethod
* 调用 +resolveClassMethod 或者 +resolveInstanceMethod
* 如果存在了则不检查
**********************************************************************/
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
    if (! cls->isMetaClass()) {//不是元类则调用 实例的
	//首先调用
		_class_resolveInstanceMethod(cls, sel, inst);
    } 
    else {
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
		//寻找classMethod
        _class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                            NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}

```

在`resolveInstanceMethod`，查找`SEL_resolveInstanceMethod`，传值不用初始化，不用消息解析，但是`cache`要查找。没有找到的直接返回，找到的话使用`objc_msgSend`发送消息调用`SEL_resolveInstanceMethod`。

```
/***********************************************************************
* _class_resolveInstanceMethod
* 调用 class添加的函数 +resolveInstanceMethod
* 有可能是元类
* 如果方法存在则不检查
**********************************************************************/
static void _class_resolveInstanceMethod(Class cls, SEL sel, id inst)
{
    if (! lookUpImpOrNil(cls->ISA(), SEL_resolveInstanceMethod, cls, 
                         NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
    {
        // Resolver not implemented.
        return;
    }
//如果找到SEL_resolveInstanceMethod 则使用objc_msgSend函数
    BOOL (*msg)(Class, SEL, SEL) = (typeof(msg))objc_msgSend;
    bool resolved = msg(cls, SEL_resolveInstanceMethod, sel);

    // Cache the result (good or bad) so the resolver doesn't fire next time.
    // +resolveInstanceMethod adds to self a.k.a. cls
    IMP imp = lookUpImpOrNil(cls, sel, inst, 
                             NO/*initialize*/, YES/*cache*/, NO/*resolver*/);

    if (resolved  &&  PrintResolving) {
        if (imp) {
            _objc_inform("RESOLVE: method %c[%s %s] "
                         "dynamically resolved to %p", 
                         cls->isMetaClass() ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(sel), imp);
        }
        else {
            // Method resolver didn't add anything?
            _objc_inform("RESOLVE: +[%s resolveInstanceMethod:%s] returned YES"
                         ", but no new implementation of %c[%s %s] was found",
                         cls->nameForLogging(), sel_getName(sel), 
                         cls->isMetaClass() ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(sel));
        }
    }
}
```

在`_class_resolveClassMethod`中，第一步先去`lookUpImpOrNil`查找`+SEL_resolveClassMethod`方法，没找到的就结束，找到则调用`objc_msgsend(id,sel)`

```
static void _class_resolveClassMethod(Class cls, SEL sel, id inst)
{
    assert(cls->isMetaClass());

    if (! lookUpImpOrNil(cls, SEL_resolveClassMethod, inst, 
                         NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
    {
        // Resolver not implemented.
        return;
    }

    BOOL (*msg)(Class, SEL, SEL) = (typeof(msg))objc_msgSend;
    bool resolved = msg(_class_getNonMetaClass(cls, inst), 
                        SEL_resolveClassMethod, sel);

    // Cache the result (good or bad) so the resolver doesn't fire next time.
    // +resolveClassMethod adds to self->ISA() a.k.a. cls
    IMP imp = lookUpImpOrNil(cls, sel, inst, 
                             NO/*initialize*/, YES/*cache*/, NO/*resolver*/);

    if (resolved  &&  PrintResolving) {
        if (imp) {
            _objc_inform("RESOLVE: method %c[%s %s] "
                         "dynamically resolved to %p", 
                         cls->isMetaClass() ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(sel), imp);
        }
        else {
            // Method resolver didn't add anything?
            _objc_inform("RESOLVE: +[%s resolveClassMethod:%s] returned YES"
                         ", but no new implementation of %c[%s %s] was found",
                         cls->nameForLogging(), sel_getName(sel), 
                         cls->isMetaClass() ? '+' : '-', 
                         cls->nameForLogging(), sel_getName(sel));
        }
    }
}
```

动态解析至此完成。

### 消息转发
`_objc_msgForward_impcache`是转发的函数地址，在搜索框搜索发现，这个函数除了`.s`文件中有，其他地方均只是调用，说明这个函数是汇编实现，在`objc-msg-arm64.s 531 行`发现一点踪迹

```
STATIC_ENTRY __objc_msgForward_impcache //开始__objc_msgForward_impcache
	// No stret specialization.
	b	__objc_msgForward//跳转->__objc_msgForward
	END_ENTRY __objc_msgForward_impcache // 结束__objc_msgForward_impcache

	
	ENTRY __objc_msgForward // 开始 __objc_msgForward

	adrp	x17, __objc_forward_handler@PAGE
	ldr	p17, [x17, __objc_forward_handler@PAGEOFF]//p17= x17 和 __objc_forward_handler@PAGEOFF的和
	TailCallFunctionPointer x17 //跳转-> TailCallFunctionPointer

	END_ENTRY __objc_msgForward//结束 __objc_msgForward
```

当跳转到`adrp	x17, __objc_forward_handler@PAGE`这一行，搜搜索函数`_objc_forward_handler`，看到只是个打印函数，并没有其他函数来替代这个指针，那么我们用其他方法来探究。

```
__attribute__((noreturn)) void 
objc_defaultForwardHandler(id self, SEL sel)
{
    _objc_fatal("%c[%s %s]: unrecognized selector sent to instance %p "
                "(no message forward handler is installed)", 
                class_isMetaClass(object_getClass(self)) ? '+' : '-', 
                object_getClassName(self), sel_getName(sel), self);
}
void *_objc_forward_handler = (void*)objc_defaultForwardHandler;
```

网上有大神总结的点我们先参考下

```
// 伪代码
int __forwarding__(void *frameStackPointer, int isStret) {
    id receiver = *(id *)frameStackPointer;
    SEL sel = *(SEL *)(frameStackPointer + 8);
    const char *selName = sel_getName(sel);
    Class receiverClass = object_getClass(receiver);

    // 调用 forwardingTargetForSelector:
    if (class_respondsToSelector(receiverClass, @selector(forwardingTargetForSelector:))) {
        id forwardingTarget = [receiver forwardingTargetForSelector:sel];
        if (forwardingTarget && forwardingTarget != receiver) {
            if (isStret == 1) {
                int ret;
                objc_msgSend_stret(&ret,forwardingTarget, sel, ...);
                return ret;
            }
            return objc_msgSend(forwardingTarget, sel, ...);
        }
    }

    // 僵尸对象
    const char *className = class_getName(receiverClass);
    const char *zombiePrefix = "_NSZombie_";
    size_t prefixLen = strlen(zombiePrefix); // 0xa
    if (strncmp(className, zombiePrefix, prefixLen) == 0) {
        CFLog(kCFLogLevelError,
              @"*** -[%s %s]: message sent to deallocated instance %p",
              className + prefixLen,
              selName,
              receiver);
        <breakpoint-interrupt>
    }

    // 调用 methodSignatureForSelector 获取方法签名后再调用 forwardInvocation
    if (class_respondsToSelector(receiverClass, @selector(methodSignatureForSelector:))) {
        NSMethodSignature *methodSignature = [receiver methodSignatureForSelector:sel];
        if (methodSignature) {
            BOOL signatureIsStret = [methodSignature _frameDescriptor]->returnArgInfo.flags.isStruct;
            if (signatureIsStret != isStret) {
                CFLog(kCFLogLevelWarning ,
                      @"*** NSForwarding: warning: method signature and compiler disagree on struct-return-edness of '%s'.  Signature thinks it does%s return a struct, and compiler thinks it does%s.",
                      selName,
                      signatureIsStret ? "" : not,
                      isStret ? "" : not);
            }
            if (class_respondsToSelector(receiverClass, @selector(forwardInvocation:))) {
                NSInvocation *invocation = [NSInvocation _invocationWithMethodSignature:methodSignature frame:frameStackPointer];

                [receiver forwardInvocation:invocation];

                void *returnValue = NULL;
                [invocation getReturnValue:&value];
                return returnValue;
            } else {
                CFLog(kCFLogLevelWarning ,
                      @"*** NSForwarding: warning: object %p of class '%s' does not implement forwardInvocation: -- dropping message",
                      receiver,
                      className);
                return 0;
            }
        }
    }

    SEL *registeredSel = sel_getUid(selName);

    // selector 是否已经在 Runtime 注册过
    if (sel != registeredSel) {
        CFLog(kCFLogLevelWarning ,
              @"*** NSForwarding: warning: selector (%p) for message '%s' does not match selector known to Objective C runtime (%p)-- abort",
              sel,
              selName,
              registeredSel);
    } // doesNotRecognizeSelector
    else if (class_respondsToSelector(receiverClass,@selector(doesNotRecognizeSelector:))) {
        [receiver doesNotRecognizeSelector:sel];
    }
    else {
        CFLog(kCFLogLevelWarning ,
              @"*** NSForwarding: warning: object %p of class '%s' does not implement doesNotRecognizeSelector: -- abort",
              receiver,
              className);
    }

    // The point of no return.
    kill(getpid(), 9);
}
```


### 验证动态解析
我们简单定义一个`test`函数，然后并执行这个函数。

```
@interface Person : NSObject
- (void)test;
@end
@implementation Person
+(BOOL)resolveInstanceMethod:(SEL)sel{
	NSLog(@"%s",__func__);
	if (sel == @selector(test)) {
		Method me = class_getInstanceMethod(self, @selector(test2));
		class_addMethod(self, sel,
						method_getImplementation(me),
						method_getTypeEncoding(me));
		return YES;
	}
	return [super resolveInstanceMethod:sel];
}
-(void)test2{
	NSLog(@"来了，老弟");
}
@end

Person *p = [[Person alloc]init];
[p test];
[p test];
 //输出
+[FYPerson resolveInstanceMethod:]
 -[FYPerson test3]
 -[FYPerson test3]
```

`[p test]`在第一次执行的时候会走到消息动态解析的这一步,然后通过`objc_msgsend`调用了`test`，并且把`test`添加到了缓存中，所以输出了`+[FYPerson resolveInstanceMethod:]`，在第二次调用的时候，会从缓存中查到`imp`，所以直接输出了` -[FYPerson test3]`。

在`+resolveInstanceMethod`可以拦截掉实例方法的动态解析，在`+resolveClassMethod`可以拦截类方法。

```

@interface Person : NSObject
+ (void)test;
@end

+ (void)test3{
	NSLog(@"来了，老弟");
}
+ (BOOL)resolveClassMethod:(SEL)sel{
	NSLog(@"%s",__func__);
	if (sel == @selector(test)) {
		Method me = class_getClassMethod(self, @selector(test3));//获取method
		//给sel 添加方法实现 @selecter(test3)
		class_addMethod(object_getClass(self), sel,
						method_getImplementation(me),
						method_getTypeEncoding(me));
		return YES;
	}
	return [super resolveInstanceMethod:sel];
}

[Person test];

//输出
+[Person resolveClassMethod:]
来了，老弟
```

拦截`+resolveClassMethod`,在条件为`sel==@selector(test)`的时候，将函数实现`+test3()`的`IMP`使用`class_addMethod`添加到`Person`上，待下次调用`test`的时候直接通过`imp = cache_getImp(cls, sel);`获取到`imp`函数指针并且执行。
我们也可以通过添加c函数的imp来实现给class添加函数实现。

```
+(BOOL)resolveInstanceMethod:(SEL)sel{
    NSLog(@"%s",__func__);
    if (sel == @selector(test)) {
//        Method me = class_getInstanceMethod(self, @selector(test3));
//        class_addMethod(self.class, sel, method_getImplementation(me), method_getTypeEncoding(me));
        class_addMethod(self.class, sel, (IMP)test3, "v16@0:8");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}
void test3(id self,SEL sel){
    NSLog(@"test3:%s",NSStringFromSelector(sel).UTF8String);
}

//输出
+[FYPerson resolveInstanceMethod:]
test3:test
test3:test
```

`v16@0:8`是返回值为`void`参数占用16字节大小，第一个是从0开始，第二个从8字节开始。
这段代码和上面的其实本质上是一样的，一个是给`class`添加函数实现，使`sel`和`imp`对应起来，这个是将`c`函数的`imp`和`sel`进行关联，添加缓存之后，使用`objc_msgsend()`效果是一样的。

###  验证消息转发
消息转发可分为3步，第一步根据`- (id)forwardingTargetForSelector:(SEL)aSelector`返回的类对象或者元类对象，将方法转发给该对象。假如第一步没实现，则第二步根据返回的`-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`或`+ (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`函数签名，在第三步` (void)forwardInvocation:(NSInvocation *)anInvocation`调用函数`[anInvocation invoke]`进行校验成功之后进行调用函数。

```
@interface Person : NSObject
- (void)test;
@end

#import "Person.h"
#import "Student.h"

@implementation Person
- (id)forwardingTargetForSelector:(SEL)aSelector{
	if (aSelector == @selector(test)) {
		//objc_msgSend([[Struent alloc]init],test)
		return [[Struent alloc]init];
	}
	return [super forwardingTargetForSelector:aSelector];
}
@end
//输出
-[Student test]
```

我们定义了一个`Person`只声明了`test`没有实现，然后在消息转发第一步`forwardingTargetForSelector`将要处理的对象返回，成功调用了`Student`的`test`方法。

第一步没拦截，可以在第二步拦截。
```
//消息转发第二步 没有对象来处理方法，那将函数签名来实现
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	if (aSelector == @selector(test)) {
		NSMethodSignature *sign = [NSMethodSignature signatureWithObjCTypes:"v16@0:8"];
		return sign;
	}
	return [super methodSignatureForSelector:aSelector];
}
// 函数签名已返回，到了函数调用的地方
//selector 函数的sel
//target   函数调用者
//methodSignature 函数签名
//NSInvocation  封装数据的对象
- (void)forwardInvocation:(NSInvocation *)anInvocation{
    NSLog(@"%s",__func__);
}
//输出
-[Person forwardInvocation:]
```

打印出了`-[Person forwardInvocation:]`而且没有崩溃，在`forwardInvocation:(NSInvocation *)anInvocation`怎么操作看开发者怎么处理了，探究下都可以做什么事情。
看到`NSInvocation`的属性和函数,`sel`和`target`是读写，函数签名是必须的，所以`(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`必须将函数签名返回。

```
@property (readonly, retain) NSMethodSignature *methodSignature;//只读
- (void)retainArguments;
@property (readonly) BOOL argumentsRetained;
@property (nullable, assign) id target;//读写
@property SEL selector;//读写
```

当拦截方法是类方法的时候，可以用`+ (id)forwardingTargetForSelector:(SEL)aSelecto`拦截，

```
//class 转发
// 消息转发第一步 拦截是否有转发的class对象处理方法
+ (id)forwardingTargetForSelector:(SEL)aSelector{
	if (aSelector == @selector(test3)) {
		//objc_msgSend([[Struent alloc]init],test)
		return [Student class];
	}
	return [super forwardingTargetForSelector:aSelector];
}

+ (void)test3{
//	NSLog(@"+[Student test3]");
//当[Person test3]上一行写这么一行，Person *p = [[Person alloc]init] 这句报错
//暂时不懂为什么不能调用NSLog，但是已经进来了所以调用了test2。
//注释掉 [[Person alloc]init]，一切正常。 有大佬了解吗
}
- (void)test2{
	NSLog(@"%s",__func__);
}

// 输出
-[Student test2]
```

也可以用返回`return [[Student alloc]init];`将`class`类方法转化成实例方法,最后调用了`Student`的对象方法`test3`。其实本质上都是`objc_msgSend(id,SEL,...)`，我们修改的只是`id`的值，`id`类型在这段代码中本质是对象，所以我们可以`return instance`也可以`reurn class`。

```
+ (id)forwardingTargetForSelector:(SEL)aSelector{
	if (aSelector == @selector(test3)) {
		//objc_msgSend([[Struent alloc]init],test)
		return [[Student alloc]init];
	}
	return [super forwardingTargetForSelector:aSelector];
}

- (void)test3{
	NSLog(@"%s",__func__);
}
//输出
-[Student test3]
```

将刚才写的`methodSignatureForSelector`和`forwardInvocation`改成类方法，也是同样可以拦截类方法的。我们看下

```
//消息转发第二步 没有class来处理方法，那将函数签名来实现
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	if (aSelector == @selector(test3)) {
		NSMethodSignature *sign = [NSMethodSignature signatureWithObjCTypes:"v16@0:8"];
		return sign;
	}
	return [super methodSignatureForSelector:aSelector];
}
// 函数签名已返回，到了函数调用的地方
//selector 函数的sel
//target   函数调用者
//methodSignature 函数签名
//NSInvocation  封装数据的对象
+ (void)forwardInvocation:(NSInvocation *)anInvocation{
//	anInvocation.selector = @selector(test2);
//此处换成[Student class]同样可以
//	anInvocation.target = (id)[[Student alloc]init];

//	[anInvocation invoke];
	NSLog(@"%s",__func__);
}

//输出
+[Person forwardInvocation:]

```
测过其实对象方法和类方法都是用同样的流程拦截的，对象方法是用`-`方法,类方法是用`+`方法。

### 总结
- objc_msgSend发送消息，会首先在cache中查找，查找不到则去方法列表(顺序是`cache->class_rw_t->supclass cache ->superclass class_rw_t ->动态解析`)
- 第二步是动态解析，能在resolveInstanceMethod或+ (BOOL)resolveClassMethod:(SEL)sel来来拦截，可以给class新增实现函数，达到不崩溃目的
- 第三步是消息转发，转发第一步可以在`+ (id)forwardingTargetForSelector:(SEL)aSelector`或`- (id)forwardingTargetForSelector:(SEL)aSelector`拦截类或实例方法，能将对象方法转发给其他对象，也能将对象方法转发给类方法，也可以将类方法转发给实例方法
- 第三步消息转发的第二步可以在`+ (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`或`- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`实现拦截类和实例方法并返回函数签名
- 第三步消息转发的第三步可以`+ (void)forwardInvocation:(NSInvocation *)anInvocation`或`- (void)forwardInvocation:(NSInvocation *)anInvocation`实现类方法和实例方法的调用和获取返回值


#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)



本文章之所以图片比较少，我觉得还是跟着代码敲一遍，印象比较深刻。

---
最怕一生碌碌无为，还安慰自己平凡可贵。

广告时间

![](/images/0.png)