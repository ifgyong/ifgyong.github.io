 title: iOS底层原理 Category与关联对象本质--(4)
date: 2019-12-1 11:14:58
tags:
- iOS
categories: iOS
---
 今天我们再看一下`Category`的底层原理。
 先看一下`Category`的简单使用，首先新增一个类的`Category`，然后添加需要的函数，然后在使用的文件中导入就可以直接使用了。代码如下:
 
 
```
@interface FYPerson : NSObject
- (void)run;
@end
@implementation FYPerson
-(void)run{
	NSLog(@"run is run");
}
@end


//类别
@interface FYPerson (test)
- (void)test;
@end
@implementation FYPerson (test)
- (void)test{
	NSLog(@"test is run");
}
@end


//使用
#import "FYPerson.h"
#import "FYPerson+test.h"


FYPerson *person=[[FYPerson alloc]init];
[person test];
[person run];
```
  类别使用就是这么简单。
  那么类别的本质是什么呢？类的方法是存储在什么地方呢？
  第一篇[类的本质](https://juejin.im/post/5d15887ee51d45108126d28d)已经讲过了，运行时中，类对象是有一份，方法都存储在类对象结构体`fy_objc_class`中的`class_data_bits_t->data()->method_list_t`中的，那么类别方法也是存储在`method_list_t`和取元类对象的`method_list_t`中的。编译的时候类别编译成结构体`_category_t`,然后`runtime`在运行时动态将方法添加到`method_list_t`中。运行`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc FYPerson+test.m -o FYPerson+test.cpp`进入到`FYPerson+test.cpp`内部查看编译之后的代码
  
```
  struct _category_t {
	const char *name; //"FYPerson"
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
//存储 test方法
static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[1];
} _OBJC_$_CATEGORY_INSTANCE_METHODS_FYPerson_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	1,
	{{(struct objc_selector *)"test", "v16@0:8", (void *)_I_FYPerson_test_test}}
};

extern "C" __declspec(dllimport) struct _class_t OBJC_CLASS_$_FYPerson;

//_category_t 存储FYPerson的分类的数据
static struct _category_t _OBJC_$_CATEGORY_FYPerson_$_test __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"FYPerson",
	0, // &OBJC_CLASS_$_FYPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_FYPerson_$_test,//instace方法
	0,//类方法
	0,//协议方法
	0,//属性
};
```

存储在`_category_t`中的数据是什么时间加载到`FYPerson`的`class_data_bits_t.data`呢？我们探究一下，打开[源码](https://opensource.apple.com/tarballs/objc4/)下载打开工程阅读源码找到`objc-os.mm`,通过查找函数运行顺序得到`_objec_init->map_images->map_images_noljock->_read_images->remethodizeClass(cls)->attachCategories(cls, cats, true /*flush caches*/)`，最终进入到`attachCategories`关键函数内部：
  
```
  // Attach method lists and properties and protocols from categories to a class.
// Assumes the categories in cats are all loaded and sorted by load order, 
// oldest categories first.
static void 
attachCategories(Class cls, category_list *cats, bool flush_caches)
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
    //最后的编译文件放到最前边
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
`attachCategories`是将所有的分类方法和协议，属性倒序添加到类中，具体添加的优先级是怎么操作的？进入到`rw->protocols.attachLists`内部：

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
            memmove(array()->lists + addedCount/*指针移动到数组末尾*/, array()->lists/*数组*/,
                    oldCount * sizeof(array()->lists[0])/*移动数据的大小*/);
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

可以看出来：
1. 首先通过`runtime`加载某个类的所有Category数据
2. 把所有Category的方法，属性，协议数据合并到一个大数组中，后面参与编译的数组会出现在数组前边
3. 将合并后的分类数组(方法，属性，协议)插入到类原来的数据的前面。

具体的编译顺序是project文件中->Build Phases->Complile Sources的顺序。

### 调用顺序
#### +load加载顺序 

每个类和分类都会加载的时候调用`+load`方法，具体是怎么调用呢？我们查看源码`_objc_init->load_images->call_load_methods`


```
void call_load_methods(void)
{
    static bool loading = NO;
    bool more_categories;

    loadMethodLock.assertLocked();

    // Re-entrant calls do nothing; the outermost call will finish the job.
    if (loading) return;
    loading = YES;

    void *pool = objc_autoreleasePoolPush();

    do {
        // 1. Repeatedly call class +loads until there aren't any more
        //执行class+load直到完成
        while (loadable_classes_used > 0) {
            call_class_loads();
        }
//执行Category +load 一次
        // 2. Call category +loads ONCE
        more_categories = call_category_loads();

        // 3. Run more +loads if there are classes OR more untried categories
    } while (loadable_classes_used > 0  ||  more_categories);

    objc_autoreleasePoolPop(pool);

    loading = NO;
}
```

类`+load`在`Category+load`前边执行，当类的`+load`执行完毕然后再去执行`Category+load`,而且只有一次。
当class有子类的时候加载顺序呢？其实所有类都是基于`NSObject`，那么我们假设按照编译顺序加载`Class+load`，就有一个问题是父类+load执行的操作岂不是在子类执行的时候还没有执行吗？这个假设明显不对，基类`+load`中的操作是第一个执行的，其他子类是按照`superclass->class->sonclass`的顺序执行的。
查看源码`_objc_init->load_images->prepare_load_methods((const headerType *)mh)->schedule_class_load`在`objc-runtime-new.mm`2856行

```
/***********************************************************************
* Schedule +load for classes in this image, any un-+load-ed 
* superclasses in other images, and any categories in this image.
**********************************************************************/
// Recursively schedule +load for cls and any un-+load-ed superclasses.
// cls must already be connected.
static void schedule_class_load(Class cls)
{
    if (!cls) return;
    assert(cls->isRealized());  // _read_images should realize

    if (cls->data()->flags & RW_LOADED) return;

    // Ensure superclass-first ordering
    //递归调用自己直到调用clas->self
    schedule_class_load(cls->superclass);
//添加class
    add_class_to_loadable_list(cls);
    cls->setInfo(RW_LOADED); 
}
```

可以了解到该函数递归调用自己，直到`+load`方法已经调用过为止，所以不管编译顺序是高低，`+load`的加载顺序始终是`NSObject->FYPrson->FYStudent`。多个类平行关系的话，按照编译顺序加载。
下边是稍微复杂点的类关系：

```

NSObject
    Person
        Student
NSObjet
    Car
        BigCar
            BigOrSmallCar
```

编译顺序是

```
Person
Student
Car
BigOrSmallCar
```

那么他们`+load`的加载顺序是：

```

NSobject->Person->Student->Car->BigCar->BigOrSmallCar

```

看着不是很明白的 可以再看一下刚才的`schedule_class_load`函数。
加载成功之后，是按照`objc_msgsend()`流程发送的吗？我们进入到`call_class_loads`内部

```
static void call_class_loads(void)
{
    int i;
    
    // Detach current loadable list.
    struct loadable_class *classes = loadable_classes;
    int used = loadable_classes_used;
    loadable_classes = nil;
    loadable_classes_allocated = 0;
    loadable_classes_used = 0;
    
    // Call all +loads for the detached list.
    for (i = 0; i < used; i++) {
        Class cls = classes[i].cls;
        load_method_t load_method = (load_method_t)classes[i].method;
        if (!cls) continue; 

        if (PrintLoading) {
            _objc_inform("LOAD: +[%s load]\n", cls->nameForLogging());
        }
        (*load_method)(cls, SEL_load);
    }
    if (classes) free(classes);
}
```

可以找到` (*load_method)(cls, SEL_load);`该函数，该函数是直接使用`IMP`执行的，`IMP`就是函数地址，可以直接访问函数而不用消息的转发流程。

####  +initialize调用
- +initialize方法会在类第一次接收到消息时调用
- 先调用父类的+initialize，再调用子类的+initialize
- 先初始化父类，再初始化子类，每个类只会初始化1次

`objc`源码解读过程`objc-msg-arm64.x->objc_msgSend->objc->runtime-new->class_getinstanceMethod->lookUpImpOrNil->lookUpImpOrForward->_clas_initialize->callInitialize->objc_msgSend(cls,SEL_Initialize)`
在`runtime-new.h`4819行

```
Method class_getInstanceMethod(Class cls, SEL sel)
{
    if (!cls  ||  !sel) return nil;

    lookUpImpOrNil(cls, sel, nil, 
                   NO/*initialize*/, NO/*cache*/, YES/*resolver*/);


    return _class_getMethod(cls, sel);
}
```

根据`lookUpImpOrNil`查看4916行

```
IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;

    runtimeLock.assertUnlocked();

    // Optimistic cache lookup
    if (cache) {
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }

    runtimeLock.lock();
    checkIsKnownClass(cls);

    if (!cls->isRealized()) {
        realizeClass(cls);
    }

    if (initialize  &&  !cls->isInitialized()) {
        runtimeLock.unlock();
        _class_initialize (_class_getNonMetaClass(cls, inst));
        runtimeLock.lock();
      //当第一次收到消息，cls没有初始化，则调用_class_initialize进行初始化
      }
 retry:    
    runtimeLock.assertLocked();
    imp = cache_getImp(cls, sel);
    if (imp) goto done;
   // Try this class's method lists.
    //在本类中查找method
    {
        Method meth = getMethodNoSuper_nolock(cls, sel);
        if (meth) {
            log_and_fill_cache(cls, meth->imp, sel, inst, cls);
            imp = meth->imp;
            goto done;
        }
    }

    // Try superclass caches and method lists.
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

    // No implementation found. Try method resolver once.

    if (resolver  &&  !triedResolver) {
        runtimeLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        runtimeLock.lock();
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
        triedResolver = YES;
        goto retry;
    }

    // No implementation found, and method resolver didn't help. 
    // Use forwarding.

    imp = (IMP)_objc_msgForward_impcache;
    cache_fill(cls, sel, imp, inst);

 done:
    runtimeLock.unlock();

    return imp;
}
```

当第一次收到消息，cls没有初始化，则调用`_class_initialize`进行初始化
我们进入到`_class_initialize`内部`objc-initialize.mm`484行

```
void _class_initialize(Class cls)
{
    assert(!cls->isMetaClass());

    Class supercls;
    bool reallyInitialize = NO;

    // Make sure super is done initializing BEFORE beginning to initialize cls.
    // See note about deadlock above.
    //递归调用父类是否有初始化和是否有父类
    supercls = cls->superclass;
    if (supercls  &&  !supercls->isInitialized()) {
        _class_initialize(supercls);
    }
    
    // Try to atomically set CLS_INITIALIZING.
    {
        monitor_locker_t lock(classInitLock);
        if (!cls->isInitialized() && !cls->isInitializing()) {
            cls->setInitializing();
            reallyInitialize = YES;
        }
    }
    
    if (reallyInitialize) {
        // We successfully set the CLS_INITIALIZING bit. Initialize the class.
        
        // Record that we're initializing this class so we can message it.
        _setThisThreadIsInitializingClass(cls);

        if (MultithreadedForkChild) {
            // LOL JK we don't really call +initialize methods after fork().
            performForkChildInitialize(cls, supercls);
            return;
        }
        
        // Send the +initialize message.
        // Note that +initialize is sent to the superclass (again) if 
        // this class doesn't implement +initialize. 2157218
        if (PrintInitializing) {
            _objc_inform("INITIALIZE: thread %p: calling +[%s initialize]",
                         pthread_self(), cls->nameForLogging());
        }

        // Exceptions: A +initialize call that throws an exception 
        // is deemed to be a complete and successful +initialize.
        //
        // Only __OBJC2__ adds these handlers. !__OBJC2__ has a
        // bootstrapping problem of this versus CF's call to
        // objc_exception_set_functions().
#if __OBJC2__
        @try
#endif
        {
            callInitialize(cls);

            if (PrintInitializing) {
                _objc_inform("INITIALIZE: thread %p: finished +[%s initialize]",
                             pthread_self(), cls->nameForLogging());
            }
        }
#if __OBJC2__
        @catch (...) {
            if (PrintInitializing) {
                _objc_inform("INITIALIZE: thread %p: +[%s initialize] "
                             "threw an exception",
                             pthread_self(), cls->nameForLogging());
            }
            @throw;
        }
        @finally
#endif
        {
            // Done initializing.
            lockAndFinishInitializing(cls, supercls);
        }
        return;
    }
    
    else if (cls->isInitializing()) {
        // We couldn't set INITIALIZING because INITIALIZING was already set.
        // If this thread set it earlier, continue normally.
        // If some other thread set it, block until initialize is done.
        // It's ok if INITIALIZING changes to INITIALIZED while we're here, 
        //   because we safely check for INITIALIZED inside the lock 
        //   before blocking.
        if (_thisThreadIsInitializingClass(cls)) {
            return;
        } else if (!MultithreadedForkChild) {
            waitForInitializeToComplete(cls);
            return;
        } else {
            // We're on the child side of fork(), facing a class that
            // was initializing by some other thread when fork() was called.
            _setThisThreadIsInitializingClass(cls);
            performForkChildInitialize(cls, supercls);
        }
    }
    
    else if (cls->isInitialized()) {
        // Set CLS_INITIALIZING failed because someone else already 
        //   initialized the class. Continue normally.
        // NOTE this check must come AFTER the ISINITIALIZING case.
        // Otherwise: Another thread is initializing this class. ISINITIALIZED 
        //   is false. Skip this clause. Then the other thread finishes 
        //   initialization and sets INITIALIZING=no and INITIALIZED=yes. 
        //   Skip the ISINITIALIZING clause. Die horribly.
        return;
    }
    
    else {
        // We shouldn't be here. 
        _objc_fatal("thread-safe class init in objc runtime is buggy!");
    }
}
```

可以看出来，和`+load`方法一样，先父类后子类。然后赋值`reallyInitialize = YES;`，后边使用`try`主动调用`callInitialize(cls);`，来到`callInitialize(cls);`内部：

```
void callInitialize(Class cls)
{
    ((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize);
    asm("");
}
```

可以看到最终还是使用`((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize)`主动调用了该函数。
### 区别
`+initialize`和`+load`的很大区别是，`+initialize`是通过`objc_msgSend`进行调用的，所以有以下特点
如果子类没有实现`+initialize`，会调用父类的`+initialize`（所以父类的`+initialize`可能会被调用多次）
如果分类实现了`+initialize`，就覆盖类本身的`+initialize`调用

用伪代码实现以下思路：

```
    if(class 没有初始化){
        父类初始化
        子类初始化
        调用initialize
    }
    如果子类没有实现initialize，则去调用父类initialize。
```

至于子类没有实现的话是直接调用父类的`initialize`，是使用`objc-msgsend`的原因。

### 验证

```
@interface FYPerson : NSObject

@end
+(void)initialize{
	printf("\n%s",__func__);

}
+(void)load{
	printf("\n%s",__func__);

}
@interface FYPerson (test1)

@end

+(void)initialize{
	printf("\n%s",__func__);

}
+(void)load{
	printf("\n%s",__func__);

}
//输出
+[FYPerson load]
+[FYPerson(test2) load]
+[FYPerson(test1) load]

```
### 总结
- `+load`是根据函数地址直接调用，`initialize`是通过`objc_msgSend`调用
- `+load`是runtime加载类、分类时候调用（只会调用一次）
- `initialize`是第一次接受消息的时候调用，每个类只会调用一次（子类没实现，父类可能被调用多次）
- `+load`调用优先于`initialize`,子类调用`+load`之前会调用父类的`+load`，再调用分类的`+load`,分类之间先编译，先调用。
- `initialize`先初始化父类，再初始化子类（可能最终调用父类的`initialize`）

### 关联对象本质
#### 关联对象的本质-结构体
继承`NSObject`是可以可以直接使用`@property (nonatomic,assign) int age;
`，但是在`Category`中会报错，那么怎么实现和继承基类一样的效果呢？
我们查看`Category`结构体

```
  struct _category_t {
	const char *name; //"FYPerson"
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```

其中`const struct _prop_list_t *properties;`是存储属性的，但是缺少成员变量，而我们也不能主动在`_category_t`插入`ivar`，那么我们可以使用`objc_setAssociatedObject`将属性的值存储全局的`AssociationsHashMap`中，使用的时候`objc_getAssociatedObject(id object, const void *key) `,不使用的时候删除使用`objc_removeAssociatedObjects`删除。

我们进入到`objc_setAssociatedObject`内部,`objc-references.mm`275行

```
void _object_set_associative_reference(id object, void *key, id value, uintptr_t policy) {
    // retain the new value (if any) outside the lock.
    ObjcAssociation old_association(0, nil);
	//根据key value 处理
    id new_value = value ? acquireValue(value, policy) : nil;
    {
        AssociationsManager manager;
		//生成一个全局的 HashMap
        AssociationsHashMap &associations(manager.associations());
        disguised_ptr_t disguised_object = DISGUISE(object);
		//有value 就处理
        if (new_value) {
            // break any existing association.
//			遍历 hashMap是否有该obj
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i != associations.end()) {
                // secondary table exists
				//有的话 更新其 value
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    j->second = ObjcAssociation(policy, new_value);
                } else {
                    (*refs)[key] = ObjcAssociation(policy, new_value);
                }
            } else {
                // create the new association (first time).
				//没有的话 赋值给 refs
                ObjectAssociationMap *refs = new ObjectAssociationMap;
                associations[disguised_object] = refs;
                (*refs)[key] = ObjcAssociation(policy, new_value);
                object->setHasAssociatedObjects();
            }
        } else {
            // setting the association to nil breaks the association.
            AssociationsHashMap::iterator i = associations.find(disguised_object);
            if (i !=  associations.end()) {
                ObjectAssociationMap *refs = i->second;
                ObjectAssociationMap::iterator j = refs->find(key);
                if (j != refs->end()) {
                    old_association = j->second;
                    //删除refs 
                    refs->erase(j);
                }
            }
        }
    }
    // release the old value (outside of the lock).
    if (old_association.hasValue()) ReleaseValue()(old_association);
}

```

通过该函数我们了解到
- 关联对象并不是存储在关联对象的本身内存中
- 关联对象是存储在全局统一的`AssociationsManager`管理的`AssociationsHashMap`中
- 传入value =nil，会移除该关联对线
`AssociationsManager`其实是管理了已`key为id object`对应的`AssociationsHashMap`，`AssociationsHashMap`存储了`key`对应的`ObjcAssociation`，`ObjcAssociation`是存储了`value` 和`policy`，`ObjcAssociation`的数据结构如下：

```
class ObjcAssociation {
        uintptr_t _policy;
        id _value;
        *****
        }
```
具体抽象关系见下图

```
AssociationsManager --> AssociationsHashMap --> ObjectAssociationMap
-->void * ObjectAssociation -->uintprt_t _policy ,id _value;
```

简单来讲就是一个全局变量保存了以`class`为`key`对应的`AssociationsHashMap`，这个`AssociationsHashMap`存储了一个`key`对应的`ObjectAssociation`，`ObjectAssociation`包含了`value`和`_policy`。通过2层map保存了数据。

#### 关联对象的使用

|objc_setAssociatedObject|obj,key,value,policy|
|------------------------|-------------------|
|objc_getAssociatedObject|根据 obj 和 key获取值|
|void objc_removeAssociatedObjects(id object)|根据obj 删除关联函数|

`objc_AssociationPolicy`的类型：

|OBJC_ASSOCIATION_ASSIGN|weak 引用|
|------|--------|
|OBJC_ASSOCIATION_RETAIN_NONATOMIC|非原子强引用|
|OBJC_ASSOCIATION_COPY_NONATOMIC|非原子相当于copy|
|OBJC_ASSOCIATION_RETAIN|强引用|
|OBJC_ASSOCIATION_COPY| 原子操作，相当于copy|

#### 代码示例

```
@interface NSObject (test)
@property (nonatomic,assign) NSString * name;
@end

#import "NSObject+test.h"
#import "objc/runtime.h"
@implementation NSObject (test)
-(void)setName:(NSString *)name{
	objc_setAssociatedObject(self, @selector(name), name, OBJC_ASSOCIATION_COPY);
}
- (NSString *)name{
	return  objc_getAssociatedObject(self, @selector(name));
}
@end



NSObject *obj =[[NSObject alloc]init];
obj.name = @"老弟来了";
printf("%s",obj.name.UTF8String);
//老弟来了
```

这段代码我们实现了给基类添加一个成员变量`name`，然后又成功取出了值，标示我们做新增的保存成员变量的值是对的。

### 总结
- Category `+load`在冷启动时候执行，执行顺序和编译顺序成弱相关，先父类，后子类，而且每个类执行一次，执行是直接调用函数地址。
- Category `+initialize`在第一次接受消息执行，先父类，后子类，子类没实现，会调用父类，利用`objc-msgsend`机制调用。
- Category 可以利用`Associative`添加和读取属性的值

#### 资料下载
- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo code](https://github.com/ifgyong/demo/tree/master/OC)
- [runtime可运行的源码](https://github.com/ifgyong/demo/tree/master/OC/objc4-750)

  本文章之所以图片比较少，我觉得还是跟着代码敲一遍，印象比较深刻。

 ---
最怕一生碌碌无为，还安慰自己平凡可贵。

  广告时间

![](../images/0.png)