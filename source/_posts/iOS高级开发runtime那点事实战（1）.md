title: iOS高级开发runtime那点事实战（1）
date: 2016-03-24 10:36:14
tags:
- iOS
- iOS高级开发
categories: iOS
---

## runtime 给类别添加属性浅析
很多时候因为需求想着给一个类添加属性，就是给一个类添加成员变量了，这样子方便了用这个类的时候，有了自己添加的属性，做什么事都是 信手捏来了。
## 源码
```
 

#import <Foundation/Foundation.h>
#import <objc/runtime.h> //千万别忘记添加哦
@interfaceNSObject(FY)
@property(nonatomic,copy)NSString* name;//像平时一样的添加属性
@end
```
下面是在.m中实现的
```
staticvoid* FYKeyName = (void*)"FYKeyName";//声明这个变量要存储的key的名字
@implementationNSObject(FY)
- (void)setName:(NSString*)name{
objc_setAssociatedObject(self, FYKeyName, name, OBJC_ASSOCIATION_COPY);//把这个值存储起来类型是copy，值是name，存储的键值是"FYKeyName",存储到self的属性里面
}
- (NSString*)name{
returnobjc_getAssociatedObject(self, FYKeyName);//获取self的key为FYKeyName的值
}
@end
```
到此为止这个属性已经添加完成了。
其实为毛添加属性啊，我们公司的按钮不能连续点击，是所有按钮。。。没错是all not some。我问Google大神了，搜到了消息是runtime解决问题，但是没找到如何解决。在我努力寻找。。。。一万字。。
终于知道runtime是运行时，什么是运行时呢？就是我们写的OC代码会让runtime翻译并且执行，runtime是一套比较底层的纯C语言API, 属于1个C语言库, 包含了很多底层的C语言API。
在我们平时编写的OC代码中, 程序运行过程时, 其实最终都是转成了runtime的C语言代码, runtime算是OC的幕后工作者。
所以给类添加属性就派上用场了，我解决思路是这样子的，给按钮添加类别就是点击事件间隔，执行点击事件的时候判断一下是否时间到了，如果时间不到，那么拦截点击事件。
怎么拦截点击事件呢？
其实点击事件在runtime里面是obj发送消息，我们可以把要发送的消息的SEL 和自己写的SEL交换一下，然后在自己写的SEL里面判断是否执行点击事件。【有点绕】
代码：
```
#import
#import
@interfaceUIControl(FY)
@property(nonatomic,assign)NSTimeIntervalacceptEventInterval;
@property(nonatomic)BOOLignoreEvent;
@end
@implementationUIControl(FYControl)
staticconstchar*UIControl_acceptEventInterval="UIControl_acceptEventInterval";
staticconstchar*UIControl_ignoreEvent="UIControl_ignoreEvent";
@end
@implementationUIControl(FY)
- (void)setAcceptEventInterval:(NSTimeInterval)acceptEventInterval
{
objc_setAssociatedObject(self,UIControl_acceptEventInterval, @(acceptEventInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSTimeInterval)acceptEventInterval {
return[objc_getAssociatedObject(self,UIControl_acceptEventInterval) doubleValue];
}
-(void)setIgnoreEvent:(BOOL)ignoreEvent{
objc_setAssociatedObject(self,UIControl_ignoreEvent, @(ignoreEvent), OBJC_ASSOCIATION_ASSIGN);
}
-(BOOL)ignoreEvent{
return[objc_getAssociatedObject(self,UIControl_ignoreEvent) boolValue];
}
+(void)load {
Method a = class_getInstanceMethod(self,@selector(sendAction:to:forEvent:));
Method b = class_getInstanceMethod(self,@selector(_sendAction:to:forEvent:));
method_exchangeImplementations(a, b);//交换方法
}
- (void)_sendAction:(SEL)action to:(id)target forEvent:(UIEvent*)event
{
if(self.ignoreEvent)return;
if(self.acceptEventInterval>0)
{
self.ignoreEvent=YES;
[selfperformSelector:@selector(setIgnoreEventWithNo)  withObject:nilafterDelay:self.acceptEventInterval];
}
[self_sendAction:action to:target forEvent:event];
}
-(void)setIgnoreEventWithNo{
self.ignoreEvent=NO;
}
@end
```
用的时候很好用的

```
-(void)click{
btn =[[UIButton alloc]initWithFrame:CGRectMake(100,100,100,40)];
[btnsetTitle:@"btn"forState:UIControlStateNormal];
[btnsetTitleColor:[UIColor redColor]forState:UIControlStateNormal];
btn.touchTimeValue =3;
[self.viewaddSubview:btn];
[btnaddTarget:selfaction:@selector(objcName)forControlEvents:UIControlEventTouchUpInside];
}


输出：2016-03-1713:14:20.365runTimeObj[9297:2669428] 测试
2016-03-1713:14:23.717runTimeObj[9297:2669428] 测试
2016-03-1713:14:26.876runTimeObj[9297:2669428] 测试
```
这个例子是利用了两个参数，一个参数Bool判断是否往下执行，一个时间用来修改Bool的值，最后就是执行方法b。有些同学纳闷，这执行方法b，不是执行自身方法吗？难道不是递归？其实不是，在load函数里面已经把a，b方法交换了。
这样子就可以操作一些系统方法了。后续还会出runtime在项目中的实际应用。
