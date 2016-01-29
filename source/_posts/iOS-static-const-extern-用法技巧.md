title: iOS static const extern 用法技巧
date: 2016-01-28 11:07:58
tags:
- iOS
---
## 通俗的讲：

extern字段使用的时候，声明的变量为全局变量，都可以调用，也有这样一种比较狭义的说法：extern可以扩展一个类中的变量到另一个类中；

static声明的变量是静态变量，变量值改变过之后，保存这次改变，每次使用的时候都要读取一遍值；

const声明过得变量值是不可改变的，是readonly的属性，不可以改变变量的值。<!--more-->

## 具体用法：

1.static的用法：static NSString *str = @"哈哈";

2.const的用法：NSString *const str = @"哈哈";

3.extern的用法：在A.h里边声明一个变量extern NSString *str = @"123";

 这样就声明了一个全局变量，在B.h里边同样写入代码extern NSString *str；然后再B.m里边直接打印str就可以打印出123来，使用的时候不需要导入A.h文件头，也不区分类是否已经创建等等因素。

 希望对大家有所帮助，以后写代码的时候可以更加高大上一些，也是一种技巧。
