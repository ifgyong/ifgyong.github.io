title: iOS高级开发runtime那点事实战（3）
date: 2016-03-24 11:15:48
tags:
- iOS
- iOS高级开发
categories: iOS
---
###  添加类
```
objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)
添加类 superclass 类是父类   name 类的名字  size_t 类占的空间

void objc_disposeClassPair(Class cls) 销毁类


void objc_registerClassPair(Class cls) 注册类


objc_duplicateClass
 Used by Foundation's Key-Value Observing.官方说法是不让自己调用
Do not call this function yourself. 
```
具体代码：
```
- (void)allocClass{
    Class clas = objc_allocateClassPair(NSClassFromString(@"FY"), "FYss", 0);
   
    objc_property_attribute_t type = {"T", "@\"NSString\""};
    objc_property_attribute_t ownership = { "C", "" };
    objc_property_attribute_t backingivar = { "V", "_ivar1"};
    objc_property_attribute_t attrs[] = {type, ownership, backingivar};
 
 bool success =    class_addProperty(clas, "nameIvar", attrs, 3);
    if (success) {
        NSLog(@"addIvar success");
        if (class_isMetaClass(clas)) {
            NSLog(@"是一个类");
        }
    }
     objc_registerClassPair(clas);
    [self printPropreListClass:clas];
}
```
###  实例化类
```
// 创建类实例

id class_createInstance ( Class cls, size_t extraBytes );



// 在指定位置创建类实例

id objc_constructInstance ( Class cls, void *bytes );



// 销毁类实例

void * objc_destructInstance ( id obj );
```

###  实例
```
id object_copy(id obj, size_t size) //拷贝obj

id object_dispose(id obj)   //释放obj

Ivar object_setInstanceVariable(id obj, const char *name, void *value) //修改实例的值

Ivar object_getInstanceVariable(id obj, const char *name, void **outValue) //获取实例

OBJC_EXPORT void *object_getIndexedIvars(id obj) //获取obj的index

id object_getIvar(id object, Ivar ivar) //获取obj的ivar

void object_setIvar(id object, Ivar ivar, id value) //赋值ivar给obj默认值是value

const char *object_getClassName(id obj) //获取类的名字

Class object_getClass(id object) //获得 类

Class object_setClass(id object, Class cls)  //把obj 改到cls的类下

int objc_getClassList(Class *buffer, int bufferLen) //获取class列表

Class *objc_copyClassList(unsigned int *outCount) //拷贝类数组

id objc_lookUpClass(const char *name) // 看看是否 注册了类

id objc_getClass(const char *name) //获取类

id objc_getRequiredClass(const char *name) //要是没有这个类就kill 这个类 

const char * ivar_getName( Ivar ivar) //获取var的名字

const char * ivar_getTypeEncoding( Ivar ivar) //获取ivar 的 type

ptrdiff_t ivar_getOffset( Ivar ivar) //

void objc_setAssociatedObject(id object, void *key, id value, objc_AssociationPolicy policy) //给类别添加 属性

id objc_getAssociatedObject(id object, void *key) //获取属性

void objc_removeAssociatedObjects(id object) //删除属性

```
###  发送消息
```
id objc_msgSend(id self, SEL op, ...)// id 发送消息给SEL op

double objc_msgSend_fpret(id self, SEL op, ...)// 和上边的一样这个用i386平台，PPC和PPC64不能用。

void objc_msgSend_stret(void * stretAddr, id theReceiver, SEL theSelector, ...)// 有返回值的消息  stretAddr 是返回值 theReceiver接收消息的id SEL 是方法名

id objc_msgSendSuper(struct objc_super *super, SEL op, ...)//给父类方法发送消息

void objc_msgSendSuper_stret(struct objc_super *super, SEL op, ...)//给父类添加消息 
```
当我们用OC调用方法的时候，其实底层是obj发送消息的过程，就够obj发送消息给SEL，然后objruntime中会在objSELList中寻找，当然不是每次都去遍历所有的方法的，而是在methodCache，它会先去常用的方法cache在中查找，要是cache中没有这个方法，再去遍历所有的方法。参考：[Runtime源码点这里](http://www.opensource.apple.com/tarballs/objc4/)

###  具体测试
```
    objc_msgSend(self,@selector(msgTest));

-(void)msgTest{
    NSLog(@"调用了我 objc_msgSend");
}

输出：2016-03-23 15:06:18.011 runTimeObj[46084:3861049] 调用了我 objc_msgSend
```

```
id method_invoke(id receiver, Method m, ...) 调用receiver的方法 id 不能是nil

void method_invoke_stret(id receiver, Method m, ...) //Using this function to call the implementation of a method is faster than calling method_getImplementation and method_getName. 官方描述就是比method_getName和method_getImplementation块

IMP method_getImplementation( Method method) //指向IMP的方法指针
IMP是什么？本质上是一个指针，指向方法的指针，俗名就是函数指针。

const char * method_getTypeEncoding( Method method) //方法type 返回一个c字符串

char * method_copyReturnType( Method method) 方法返回的类型 一个c字符串 用完要free(char *)的

unsigned method_getNumberOfArguments( Method method) //方法的元素数量

void method_getArgumentType( Method method, unsigned int index, char *dst, size_t dst_len) 获取method 索引是index的参数 值赋给dst 要是dst = nil；系统自动调用strncpy(dst, "", dst_len)

IMP method_setImplementation( Method method, IMP imp) 把imp赋给method 

void method_exchangeImplementations( Method m1, Method m2) 交换两个方法
例如：IMP imp1 = method_getImplementation(m1);
     IMP imp2 = method_getImplementation(m2);
         method_setImplementation(m1, imp2);
         method_setImplementation(m2, imp1);
const char * * objc_copyImageNames(unsigned int *outCount)//返回所有加载的Objective-C框架和动态库的名字。

const char *class_getImageName(Class cls)//获取class的动态库的名字

const char * *objc_copyClassNamesForImage(const char *image, unsigned int *outCount) //拷贝动态库

const char* sel_getName(SEL aSelector) //获取SEL的字符串名字

SEL sel_registerName(const char *str) //注册SEL 名字是str 返回注册成功的SEL

SEL sel_getUid(const char *str) //获取str的方法SEL指针

BOOL sel_isEqual(SEL lhs, SEL rhs) //判断两个SEL是否是同一个SEL 


```
今天就到这吧，明天吧协议和属性看了。更多文章在www.fgyong.cn
