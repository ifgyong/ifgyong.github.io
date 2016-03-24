title: iOS高级开发runtime那点事实战（2）
date: 2016-03-24 11:01:56
tags:
- iOS
- iOS高级开发
categories: iOS
---
### 获取class的property属性List
```
-(void)printPropertyList{
    unsigned int count ;//存储属性的数量的
    objc_property_t * methodsVar = class_copyPropertyList([UINavigationController class], &count) ;
    for (int i = 0; i < count; i ++) {
        objc_property_t var = methodsVar[i] ;
        NSString * strName =[NSString stringWithUTF8String:property_getName(var)];
        NSString * str =[NSString stringWithUTF8String:property_getAttributes(var)];
        NSLog(@"属性 %@   名字  %@",str,strName);
    }
    free(methodsVar);
}
```
### 获取class的的名字
```
-(void)printfClassName{
    Class clas = NSClassFromString(@"NSString");
   printf("%s", class_getName(clas)); //当clas为空的话 return value 是nil
}

输出：NSString
```
### 获取类的父类并输出
```
-(void)printfClassName:(Class )clas{
   printf("%s", class_getName(clas));
}
-(Class)getSuperClass:(Class)clas{
    return class_getSuperclass(clas);
}

[self printfClassName:[self getSuperClass:NSClassFromString(@"UIView")]];
输出：UIResponder
```
### 设置类的父类
```
/** 
 * Sets the superclass of a given class.
 * 
 * @param cls The class whose superclass you want to set.
 * @param newSuper The new superclass for cls.
 * 
 * @return The old superclass for cls.
 * 
 * @warning You should not use this function. 警告不要用
 */
OBJC_EXPORT Class class_setSuperclass(Class cls, Class newSuper) 
     __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_5,__MAC_10_5, __IPHONE_2_0,__IPHONE_2_0);
     
    [self printfClassName:[self getSuperClass:NSClassFromString(@"FY")]];第一次输出NSObjec
    [self setClass:NSClassFromString(@"FY") newSuperClass:NSClassFromString(@"UIImageView")];//设置新的父类
    [self printfClassName:[self getSuperClass:NSClassFromString(@"FY")]];//再次输出是UIImageView 说明设置新的父类是可用的
    

-(void)printfClassName:(Class )clas{
   printf("%s\n", class_getName(clas));
}
-(Class)getSuperClass:(Class)clas{
    return class_getSuperclass(clas);
}
-(Class)setClass:(Class)clas newSuperClass:(Class)superClas{
   return   class_setSuperclass(clas, superClas);
}

```
### 对象和类的区分
```
-(void)isMetaClass{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    [arr addObject:[NSObject class]];
    [arr addObject:[NSValue class]];
    [arr addObject:[NSNumber class]];
    [arr addObject:[NSPredicate class]];
    [arr addObject:@"not a class object"];
    
    for (int i; i<[arr count]; i++) {
        id obj = [arr objectAtIndex:i];
        
        if(class_isMetaClass(object_getClass(obj)))
        {
            //do sth
            NSLog(@"Class: %@", obj);
        }
        else
        {
            NSLog(@"Instance: %@", obj);
        }
    }
}
输出：2016-03-18 15:46:56.235 runTimeObj[18396:2997316] Class: NSObject
2016-03-18 15:46:56.236 runTimeObj[18396:2997316] Class: NSValue
2016-03-18 15:46:56.236 runTimeObj[18396:2997316] Class: NSNumber
2016-03-18 15:46:56.236 runTimeObj[18396:2997316] Class: NSPredicate
2016-03-18 15:46:56.236 runTimeObj[18396:2997316] Instance: not a class object
```
### 获得类所占字节的大小
```
size_t size = class_getInstanceSize(NSClassFromString(@"UIView"));
    printf("%zu",size);
```
### 获得类的属性及其属性的类型
```
-(void)ivarList{
    unsigned int count;
    Ivar * vars = class_copyIvarList(NSClassFromString(@"UIViewController"), &count)//ivar 是结构体 包含 name,offset,type三个可读属性的结构体。
    ;
    for (int i = 0; i < count; i ++) {
        Ivar  var = vars[i];
        [self printIvar:var];
    }
    free(vars);
}
-(void)printIvar:(Ivar)var{//输出结构体
    const  char * name = ivar_getName(var);
    long  offset = ivar_getOffset(var);
    const  char * type = ivar_getTypeEncoding(var);
    printf("%s %ld %s\n",name,offset,type);
}
输出：
_storyboard 152 @"UIStoryboard"
_externalObjectsTableForViewLoading 160 @"NSDictionary"
_topLevelObjectsToKeepAliveFromStoryboard 168 @"NSArray"
_savedHeaderSuperview 176 @"UIView"
_savedFooterSuperview 184 @"UIView"

```
这些是apple [Objectice-C Runtime Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/index.html#//apple_ref/c/func/objc_msgSend),具体的更多的在这个网址可见。

上一篇说了一个方法 名字是`void method_exchangeImplementations(Method m1, Method m2)`
因为这个交换方法只能执行一次，所以解决了交换两次，就相当于没有交换了。具体代码：
```
static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        void (^__method_swizzling)(Class, SEL, SEL) = ^(Class cls, SEL sel, SEL _sel) {
            Method  method = class_getInstanceMethod(cls, sel);
            Method _method = class_getInstanceMethod(cls, _sel);
            method_exchangeImplementations(method, _method);
        };
      }
``` 
在这里是把这个方法封装了一个c函数，保证了只会执行一次，最好把这个`dispatch`放在`+ load`函数里面，保证加载次数的减少。
更多博客在www.fgyong.cn可见。
