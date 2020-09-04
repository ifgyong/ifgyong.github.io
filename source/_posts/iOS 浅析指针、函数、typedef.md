---
title: iOS 浅析指针、函数、typedef
tags:
  - 指针
  - iOS
categories: iOS
abbrlink: 66f667ef
date: 2019-06-24 16:39:24
---
#### 指针函数和函数指针

顾名思义，指针函数即返回指针的函数。其一般定义形式如下：

```
类型名 *函数名(函数参数表列);  
```
其中，后缀运算符括号`“()”`表示这是一个函数，其前缀运算符星号`“*”`表示此函数为指针型函数，其函数值为指针，即它带回来的值的类型为指针，当调用这个函数后，将得到一个“指向返回值为…的指针（地址），“类型名”表示函数返回的指针指向的类型”。

`“(函数参数表列)”`中的括号为函数调用运算符，在调用语句中，即使函数不带参数，其参数表的一对括号也不能省略。其示例如下：

```
int *pfun(int, int);
```
由于`“*”`的优先级低于`“()”`的优先级，因而pfun首先和后面的`“()”`结合，也就意味着，pfun是一个函数。即：

```
int *(pfun(int, int));
```
接着再和前面的`“*”`结合，说明这个函数的返回值是一个指针。由于前面还有一个int，也就是说，pfun是一个返回值为整型指针的函数。
我们不妨来再看一看，指针函数与函数指针有什么区别？

```
int (*pfun)(int, int);
```
通过括号强行将pfun首先与`“*”`结合，也就意味着，pfun是一个指针，接着与后面的`“()”`结合，说明该指针指向的是一个函数，然后再与前面的int结合，也就是说，该函数的返回值是int。由此可见，pfun是一个指向返回值为int的函数的指针。

虽然它们只有一个括号的差别，但是表示的意义却截然不同。函数指针的本身是一个指针，指针指向的是一个函数。指针函数的本身是一个函数，其函数的返回值是一个指针。

用函数指针作为指针函数的返回值
在上面提到的指针函数里面，有这样一类函数，它们也返回指针型数据（地址），但是这个指针不是指向int、char之类的基本类型，而是指向函数。对于初学者，别说写出这样的函数声明，就是看到这样的写法也是一头雾水。比如,下面的语句：

```
int (*ff(int))(int *, int);
```
我们用上面介绍的方法分析一下，ff首先与后面的`“()”`结合，即：

```
int (*(ff(int)))(int *, int);
```
用括号将`ff(int)`再括起来也就意味着，`ff`是一个函数。
接着与前面的`“*”`结合，说明`ff`函数的返回值是一个指针。然后再与后面的`“()”`结合，也就是说，该指针指向的是一个函数。

这种写法确实让人非常难懂，以至于一些初学者产生误解，认为写出别人看不懂的代码才能显示自己水平高。而事实上恰好相反，能否写出通俗易懂的代码是衡量程序员是否优秀的标准。一般来说，用typedef关键字会使该声明更简单易懂。在前面我们已经见过：

```
int (*PF)(int *, int);
```
也就是说，PF是一个函数指针“变量”。当使用typedef声明后，则PF就成为了一个函数指针`“类型”`，即：

```
typedef int (*PF)(int *, int);
```
这样就定义了返回值的类型。然后，再用PF作为返回值来声明函数:

```
PF ff(int);
```


#### 深入理解 typedef
平时我们在OC中的使用写法，但是对`typedef`困惑。
```
typedef <#returnType#>(^<#name#>)(<#arguments#>);//typedefBlock Code Snippets

typedef void (^RWAlertViewCompletionBlock)(UIAlertView *alertView, NSInteger buttonIndex);

```
然后可以通过`RWAlertViewCompletionBlock`当成block类型直接使用了。
然后看下`libffi`的用法：
```
typedef enum {
  FFI_OK = 0,
  FFI_BAD_TYPEDEF,
  FFI_BAD_ABI
} ffi_status;
typedef int INT64;//INT64 其实是int
```
使用起来的话：
```
ffi_status status;//声明一个类型是ffi_status的参数
INT64 age;//声明一个age 类型是INT64
```
现在block也可以是函数指针了
```
int (*PF)(int *, int);
//也就是说，PF是一个函数指针“变量”。当使用typedef声明后，则PF就成为了一个函数指针“类型”，即：
typedef int (*PF)(int *, int);
```
**typedef的语法规则其实很简单，一句话来说就是定义对象的语法前加关键字typedef，剩下的不变，原本定义的对象标识符换成类型标识符，对应语义从定义一个对象改成定义一个类型别名。typedef看起来复杂根本原因是对象定义的语法比较复杂，例如分隔符*和[]的用法。**
针对经典的const来个例子
```
typedef char * pStr;
char string[4] = "abc";
const char *p1 = string;
const pStr p2 = string;
p1++;
p2++;//error
```
那么为什么`p2++`为什么会报错呢？
我们来分析一下，`const char *p1 = string;`是声明了一个`const char `的指针，不可变的是`char`,相当于`(const char)*p=string`,所以`p1++`不会报错。`p2++`报错根本原因是`p2`是不可变的，`const pStr p2 = string`相当于`const (char *) p2 = string`,`const`修饰的是`char *`，所以`p2`不可改变。`p1`是数组，`p2`是固定的值。
#### `typedef`如何使用呢？
我们具体看几个案例分析一下。

案例1：
```
int (*b) (void (*)());
```
简化一下是：
```
typedef  void (*func)()
typedef  int (*ifunc)(func)
```
最终简化成`ifunc b;`。可以理解成`(void (*)())`是一个`func`,然后替换`func`成了最终的形参是`func`，返回值是`int`。

案例2分析：
```
int (*func)(int *p);
```
首先找到`func`，`func`左边是`*`，说明`func`是个指针，然后跳出这个圆括号，先看右边，又遇到圆括号，这说明`(*func)`是一个函数，所以
func是一个指向这类函数的指针，即函数指针，这类函数具有`int*`类型的形参，返回值类型是`int`。

综合案例：
```
SEL didload = @selector(viewDidLoad);
Method md = class_getInstanceMethod(aclass, didload);
IMP load = method_getImplementation(md);
void(*loadFunc)(id,SEL) = (void *)load;
```
这是将SEL获取了Method之后将IMP转化成`void(*loadFunc)(id,SEL)`，调用的时候可以直接调用。
```
//执行ViewDidLoad IMP
 loadFunc(aclass,NULL);
```
Method可以这样使用，block同样也可以这样使用:
```
void (^block)(id _self) = ^(id _self){
    //code here
};
void(*func)(id,SEL) = (void*)imp_implementationWithBlock(block);
class_replaceMethod(aclass, didload, (IMP)func, method_getTypeEncoding(md));
```
这可以直接使用`runtime/message.h`函数`imp_implementationWithBlock`将`block`转化成`IMP`,使用`class_replaceMethod`替换某个函数的`IMP`。那么再调用该函数的时候，则是调用的`block`的`IMP`。获取`method`和`block`参数后续再分析。



资料参考：

[玉令天下博客地址](http://yulingtianxia.com/blog/2014/04/17/han-shu-zhi-zhen-yu-zhi-zhen-han-shu/)
