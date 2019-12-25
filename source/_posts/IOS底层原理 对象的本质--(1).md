
title: iOS底层原理  对象的本质 --(1)
date: 2019-12-1 11:11:58
tags:
- iOS
categories: iOS
---

### 对象的本质
探寻OC对象的本质，我们平时编写的Objective-C代码，底层实现其实都是C\C++代码。
那么一个OC对象占用多少内存呢？看完这篇文章你将了解OC/对象的内存布局和内存分配机制。

使用的[代码下载](https://github.com/ifgyong/demo/tree/master/OC)
要用的工具:

- [Xcode 10.2](https://developer.apple.com/cn/support/xcode/)
- [gotoShell](https://zipzapmac.com/Go2Shell)
- [linux-glibc-2.29源码](http://ftp.gnu.org/gnu/glibc/)
- [libmalloc源码](https://opensource.apple.com/tarballs/libmalloc/)

首先我们使用最基本的代码验证对象是什么?
<!-- more -->

```
int main(int argc, const char * argv[]) {
	@autoreleasepool {
	    // insert code here...
		NSObject *obj=[[NSObject alloc]init];
	    NSLog(@"Hello, World!");
	}
	return 0;
}
```

使用`clang`编译器编译成`cpp`，
执行`clang -rewrite-objc main.m -o main.cpp`之后生成的`cpp`，这个生成的`cpp`我们不知道是跑在哪个平台的，现在我们指定`iphoeos`和`arm64`重新编译一下。`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main64.cpp`，将`main64.cpp`拖拽到Xcode中并打开。
|clang|编译器|
|--------------|-------|
|xcrun|命令|
|sdk|指定编译的平台|
|arch|arm64架构|
|-rewrite-objc|重写|
|main.m|重写的文件|
|main64.cpp|导出的文件|
|-o|导出|

`command + F`查找`int main`,找到关键代码，这就是`main`函数的转化成`c/c++`的代码：

```
int main(int argc, const char * argv[]) {
 /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

  NSObject *obj=((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)((NSObject *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("NSObject"), sel_registerName("alloc")), sel_registerName("init"));

     NSLog((NSString *)&__NSConstantStringImpl__var_folders_c0_7nm4_r7s4xd0mbs67ljb_b8m0000gn_T_main_1b47c1_mi_0);
 }
 return 0;
}
```

然后搜索

```
struct NSObject_IMPL {
	Class isa;
};
```

那么这个结构体是什么呢？
其实我们`Object-C`编译之后对象会编译成结构体，如图所示：
![](/images/1-1.png)
那么`isa`是什么吗？通过查看源码得知：

```
typedef struct objc_class *Class; 
```

`class`其实是一个指向结构体的指针，然后`com+点击class`得到：

```
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;

#if !__OBJC2__
    Class _Nullable super_class                              OBJC2_UNAVAILABLE;
    const char * _Nonnull name                               OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars                  OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache * _Nonnull cache                       OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols          OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
```

`class`是一个指针，那么占用多少内存呢？大家都知道**指针在32位是4字节，在64位是8字节。**

```
NSObject *obj=[[NSObject alloc]init];
```

可以理解成实例对象是一个指针,指针占用8或者4字节，那么暂时假设机器是64位，记为对象占用8字节。
`obj`就是指向结构体`class`的一个指针。
那么我们来验证一下：

```
int main(int argc, const char * argv[]) {
	@autoreleasepool {
	    // insert code here...
		NSObject *obj=[[NSObject alloc]init];
		//获得NSobject对象实例大小
		size_t size = class_getInstanceSize(obj.class);
		//获取NSObjet指针的指向的内存大小
		//需要导入：#import <malloc/malloc.h>
		size_t size2 = malloc_size((__bridge const void *)(obj));
		NSLog(@"size:%zu size2:%zu",size,size2);
	}
	return 0;
}
```

得出结果是：

```
size:8 size2:16
```

结论是：**指针是8字节，指针指向的的内存大小为16字节。**
查看源码得知`[[NSObject alloc]init]`的函数运行顺序是:

```
class_createInstance
    -_class_createInstanceFromZone
```

```
id
_class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone, 
                              bool cxxConstruct = true, 
                              size_t *outAllocatedSize = nil)
{
    if (!cls) return nil;
    **
    size_t size = cls->instanceSize(extraBytes);
    **
    return obj;
}

```
这个函数前边后边省略，取出关键代码，其实`size`是`cls->instanceSize(extraBytes)`执行的结果。那么我们再看下`cls->instanceSize`的源码：

```
//成员变量大小 8bytes
    uint32_t alignedInstanceSize() {
        return word_align(unalignedInstanceSize());
    }
    
    size_t instanceSize(size_t extraBytes) {
        size_t size = alignedInstanceSize() + extraBytes;
        // CF requires all objects be at least 16 bytes.
        if (size < 16) size = 16;
        return size;
    }
```
可以通过源码注释得知：CF要求所有的objects 最小是16bytes。

`class_getInstanceSize`函数的内部执行顺序是`class_getInstanceSize->cls->alignedInstanceSize()`
查阅源码：
```
//成员变量大小 8bytes
    uint32_t alignedInstanceSize() {
        return word_align(unalignedInstanceSize());
    }
```
所以最终结论是：**对象指针实际大小为8bytes，内存分配为16bytes，其实是空出了8bytes**。

验证：
在刚才 的代码打断点和设置`Debug->Debug Workflow->View Memory`,然后运行程序，

![](/images/1-2.png)

![](/images/1-3.png)
点击`obj->view *objc`得到上图所示的内存布局，从`address`看出和`obj`内存一样，左上角是16字节，8个字节有数据，8个字节是空的，默认是0.

使用lldb命令`memory read 0x100601f30`输出内存布局，如下图：
![](/images/1-4.png)
或者使用`x/4xg 0x100601f30`输出：

![](/images/1-5.png)
`x/4xg 0x100601f30`中`4`是输出`4`个数据,`x` 是16进制,后边`g`是8字节为单位。可以验证刚才的出的结论。

那么我们再使用复杂的一个对象来验证：
```
@interface Person : NSObject
{
	int _age;
	int _no;
}
@end
```
使用`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main64.cpp`编译之后对应的源码是：

```
struct NSObject_IMPL {
 Class isa;
};
struct Person_IMPL {
	struct NSObject_IMPL NSObject_IVARS;// 8 bytes
	int _age;//4 bytes
	int _no;//4 bytes
};
```

`Person——IMPL`**结构体占用16bytes**

```
Person *obj=[[Person alloc]init];
		obj->_age = 15;
		obj->_no = 14;
```

使用代码验证：

```
		Person *obj=[[Person alloc]init];
		obj->_age = 15;
		obj->_no = 14;
		
		struct Person_IMPL *p =(__bridge struct Person_IMPL*)obj;
		NSLog(@"age:%d no:%d",p->_age,p->_no);
		
		//age:15 no:14
```
使用内存布局验证：

![](/images/1-6.png)
以十进制输出每个4字节
![](/images/1-7.png)
使用内存布局查看数据验证，`Person`占用16 bytes。

下边是一个直观的内存布局图：

![](/images/1-8.png)

#### 再看一下更复杂的继承关系的内存布局：

```
@interface Person : NSObject
{
	@public
	int _age;//4bytes 
}
@end
@implementation Person
@end

//Student
@interface Student : Person
{
@public
	int _no;//4bytes
}
@end
@implementation Student
@end
```

那小伙伴可能要说这一定是32字节，因为`Person`上边已经证明是16字节，`Student`又多了个成员变量`_no`，由于内存对齐，一定是16的整倍数，那就是16+16=32字节。
其实不然，`Person`是内存分配16字节，其实占用了8+4=12字节，剩余4字节位子空着而已，`Student`是一个对象，不可能在成员变量和指针中间有内存对齐的，参数和指针是对象指针+偏移量得出来的，多个不同的对象才会存在内存对齐。所以`Student`是占用了16字节。

那么我们来证明一下：

```
Student *obj=[[Student alloc]init];
		obj->_age = 6;
		obj->_no = 7;
		
		//获得NSobject对象实例成员变量占用的大小 ->8
		size_t size = class_getInstanceSize(obj.class);
		//获取NSObjet指针的指向的内存大小 ->16
		size_t size2 = malloc_size((__bridge const void *)(obj));
		NSLog(@"size:%zu size2:%zu",size,size2);
		//size:16 size2:16
		
		
```

再看一下LLDB查看的内存布局：

```
(lldb) x/8xw 0x10071ae30
0x10071ae30: 0x00001299 0x001d8001 0x00000006 0x00000007
0x10071ae40: 0xa0090000 0x00000007 0x8735e0b0 0x00007fff

(lldb) memory read 0x10071ae30
0x10071ae30: 99 12 00 00 01 80 1d 00 06 00 00 00 07 00 00 00  ................
0x10071ae40: 00 00 09 a0 07 00 00 00 b0 e0 35 87 ff 7f 00 00  ..........5.....

(lldb) x/4xg 0x10071ae30
0x10071ae30: 0x001d800100001299 0x0000000700000006
0x10071ae40: 0x00000007a0090000 0x00007fff8735e0b0

```
可以看出来`0x00000006`和`0x00000007`就是两个成员变量的值，占用内存是16字节。

我们将`Student`新增一个成员变量：
```
//Student
@interface Student : Person
{
@public
	int _no;//4bytes
	int _no2;//4bytes
}
@end
@implementation Student
@end
```
然后查看内存布局：
```
(lldb) x/8xg 0x102825db0
0x102825db0: 0x001d8001000012c1 0x0000000700000006
0x102825dc0: 0x0000000000000000 0x0000000000000000
0x102825dd0: 0x001dffff8736ae71 0x0000000100001f80
0x102825de0: 0x0000000102825c60 0x0000000102825890

```
从`LLDB`可以看出来，**内存变成了32字节。(0x102825dd0-0x102825db0=0x20)**


我们再增加一个属性看下:
```
@interface Person : NSObject
{
	@public
	int _age;//4bytes 
}
@property (nonatomic,assign) int level; //4字节
@end
@implementation Person
@end

//InstanceSize:16 malloc_size:16 
```
为什么新增了一个属性，内存还是和没有新增的时候一样呢？
因为`property`=`setter`+`getter`+`ivar`,`method`是存在类对象中的，所以实例`Person`占用的内存还是`_age`,`_level`和一个指向类的指针，最后结果是`4+4+8=16bytes`。

再看下成员变量是3个的时候是多少呢？看结果之前先猜测一下：三个`int`成员变量是12，一个指针是8，最后是20，由于内存是8的倍数，所以是24。

```
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

Person *obj=[[Person alloc]init];
		obj->_age = 6;
		
		
		//获得NSobject对象实例成员变量占用的大小 ->24
		Class ocl = obj.class;
		size_t size = class_getInstanceSize(ocl);
		//获取NSObjet指针的指向的内存大小 ->32
		size_t size2 = malloc_size((__bridge const void *)(obj));
		printf("InstanceSize:%zu malloc_size:%zu \n",size,size2);
		
InstanceSize:24 malloc_size:32
```

为什么和我们猜测的不一样呢？
那么我们再探究一下：
实例对象占用多少内存，当然是在申请内存的时候创建的，则查找源码`NSObject.mm 2306行`得到创建对象函数调用顺序`allocWithZone->_objc_rootAllocWithZone->_objc_rootAllocWithZone->class_createInstance->_class_createInstanceFromZone->_class_createInstanceFromZone`最后查看下`_class_createInstanceFromZone`的源码，其他已省略，只留关键代码：

```
id
_class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone, 
                              bool cxxConstruct = true, 
                              size_t *outAllocatedSize = nil)
{
    if (!cls) return nil;
**
    size_t size = cls->instanceSize(extraBytes);
    if (outAllocatedSize) *outAllocatedSize = size;
    **
    obj = (id)calloc(1, size);
   **
    return obj;
}

```

那么我们在看一下`instanceSize`中的实现：

```
	//对象指针的大小
    uint32_t alignedInstanceSize() {
        return word_align(unalignedInstanceSize());
    }

    size_t instanceSize(size_t extraBytes) {
        size_t size = alignedInstanceSize() + extraBytes;
        // CF requires all objects be at least 16 bytes.
        if (size < 16) size = 16;
        return size;
    }
```

最后调用的`obj = (id)calloc(1, size);`传进去的值是24，但是结果是申请了32字节的内存，这又是为什么呢？
因为这是`c`函数，我们去[苹果开源官网下载源码看下](https://opensource.apple.com/tarballs/libmalloc/),可以找到这句代码：

```
define NANO_MAX_SIZE			256 /* Buckets sized {16, 32, 48, 64, 80, 96, 112, ...} */
```

看来`NANO_MAX_SIZE`在申请空间的时候做完优化就是16的倍数,并且最大是256。所以`size = 24 ;obj = (id)calloc(1, size);`申请的结果是32字节。
然后再看下`Linux`空间申请的机制是什么？
[下载gnu资料](http://ftp.gnu.org/gnu/glibc/)，
得到：

```
#ifndef _I386_MALLOC_ALIGNMENT_H
#define _I386_MALLOC_ALIGNMENT_H

#define MALLOC_ALIGNMENT 16

#endif /* !defined(_I386_MALLOC_ALIGNMENT_H) */


/* MALLOC_ALIGNMENT is the minimum alignment for malloc'ed chunks.  It
   must be a power of two at least 2 * SIZE_SZ, even on machines for
   which smaller alignments would suffice. It may be defined as larger
   than this though. Note however that code and data structures are
   optimized for the case of 8-byte alignment.  */
   //最少是2倍的SIZE_SZ 或者是__alignof__(long double)
#define MALLOC_ALIGNMENT (2 * SIZE_SZ < __alignof__ (long double) \
			  ? __alignof__ (long double) : 2 * SIZE_SZ)
			  
			  
/* The corresponding word size.  */
#define SIZE_SZ (sizeof (INTERNAL_SIZE_T))

#ifndef INTERNAL_SIZE_T
# define INTERNAL_SIZE_T size_t
#endif
```
在i386中是16，在其他系统中按照宏定义计算，
`__alignof__ (long double)`在iOS中是16,`size_t`是8，则上面的代码简写为`#define MALLOC_ALIGNMENT (2*8 < 16 ? 16:2*8)`最终是16字节。

总结：
> 实例对象其实是结构体，占用的内存是16的倍数，最少是16，由于内存对齐，实际使用的内存为M,则实际分配内存为(M%16+M/16)*16。实例对象的大小不受方法影响，受实例变量影响。

- [学习资料下载](https://github.com/ifgyong/iOSDataFactory)
- [demo 查看](https://github.com/ifgyong/demo/tree/master/OC)

---
广告时间

![](/images/0.png)





