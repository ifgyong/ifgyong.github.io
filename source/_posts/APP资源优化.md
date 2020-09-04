---
title: APP 资源管理优化
tags:
  - iOS优化
categories: iOS
abbrlink: 1a49f150
date: 2019-12-05 11:15:58
---

在APP中，使用 X1、X2、X3已经是司空见惯的事情了，网上出了清空不再使用的图片和类，是不是做完这些不能再进一步优化了，答案是否定的，当然可以的，今天再探究一下资源管理优化。

资源大部分是图片，说到图片必须讲一下位图和矢量图

 
### 位图
> 位图图像（bitmap），亦称为点阵图像或栅格图像，是由称作像素（图片元素）的单个点组成的。这些点可以进行不同的排列和染色以构成图样。当放大位图时，可以看见赖以构成整个图像的无数单个方块。扩大位图尺寸的效果是增大单个像素，从而使线条和形状显得参差不齐。

### 矢量图
> 矢量图，也称为面向对象的图像或绘图图像，在数学上定义为一系列由线连接的点。矢量文件中的图形元素称为对象。每个对象都是一个自成一体的实体，它具有颜色、形状、轮廓、大小和屏幕位置等属性。
矢量图是根据几何特性来绘制图形，矢量可以是一个点或一条线，矢量图只能靠软件生成，文件占用内在空间较小，因为这种类型的图像文件包含独立的分离图像，可以自由无限制的重新组合。

### 说人话
> 位图就是无数个点组成的图片，基本元素是像素；矢量图有多个图形组成的，基本元素是图像。当相同尺寸的位图和矢量图绘制在大屏幕上，位图的弊端出现了，图像看着像素颗粒很大，而矢量图基本效果还是很好的。

矢量图在绘制到不同的屏幕上有着天然的优势。

## 开始使用矢量图

在Xcdoe 9、iOS11 中已经开始支持了矢量图，只需要设置打钩`Preserve Cector Dadta`。
![](http://blog.fgyong.cn/FhF6-GTsthDXMlsX9ezQ1PaXalIa.png-a)

**前提图片格式是矢量图哦**

矢量图在资源大小中相比和一倍、两倍、三倍图总和，大小下降**60%**，这算是不错的提升了。


## Stretchable Images
从iOS11、Xcode 9就开始支持了该工具，该工具可实现在`building`中将图片元数据格栅化，儿不是在运行时处理，降低图片在显示时候的CPU压力。
当渲染的尺寸大于当前的尺寸的时候才会重新渲染，否则使用优化过的预渲染位图。
效果是这样子的

![](http://blog.fgyong.cn/FpZhgVvqS711QZZnYYptKr40Pc9U-a)
#### Slicing
##### Slices
- None 无
- Horizontal 水平
- Vertical 竖直
- Horizontal and Vertical 水平和竖直 

##### Center
- Tiles 平铺
- Streches 拉伸

使用这两组参数可以达到绝大部分需求了



![](http://blog.fgyong.cn/FrtLZrygVGyJAqlV6Q412foMQgRk-a)

当我们使用下图这种图片，提前和UI讲清楚，作出一个小图，在设备上使用`Stretchable Images`功能，可以达到大图的效果。

![](http://blog.fgyong.cn/FvHCZgiiwONF_5Y01HOVP_-d9d3_-a)
白色部分表示可拉伸和舍弃的
![](http://blog.fgyong.cn/Fh6BK-44VNuB2PDdQUjaA-2iOF_J-a)

最终效果是这样的

![](http://blog.fgyong.cn/1.mp4)

👏👏👏👏

更多用法可以参考[WWDC2018/227](https://developer.apple.com/videos/play/wwdc2018/227)

## Bundle
大项目可能会有很多框架，当多个框架使用的图片名字发生重复时，使用`Bundle`是不错的选择，`Bundle`相当于文件夹，相同`Bundle`下边没有重复的文件即可。

```
// Get the app's main bundle
let mainBundle = Bundle.main

//获取本地Bundle 图片
let me = Bundle.init(identifier: "me")
let path = me?.path(forResource: "fgyong.cn 技术博客", ofType: "png")

```

## Namespace

当APP有50个类似的功能，但是每个功能都用类似的图片，那么他们名字也一致，我们使用`Namespace`来解决这个问题。
![](http://blog.fgyong.cn/FqvcOJHbjHBdE04jl78PlT3pAA4l-a)

使用起来也是很简单

```
let image = UIImage(named: "me/4.png")
```

## APP Thining

### Memory Classes && Graphics Classes
使用内存和Metal来适配不同机型，达到最优性能。

![](http://blog.fgyong.cn/FgJGgpqcA-K_kSKY6e9LDZapOiYT-a)


首先机型先去找4GB的资源，4GB没找到，则向下寻找3GB，一直寻找到1GB对应的资源。

内存和GPU相比，内存有着更高的优先级，我们确定内存是表现设备整体性能的标准。

## NSSData set
`Data set`容器可以放任何东西。
可以是`plist`文件，可以是`video`、可以是`mp3`，可以是其他任何格式的文件。


```
open class func preloadTextureAtlasesNamed(_ atlasNames: [String], withCompletionHandler completionHandler: @escaping (Error?, [SKTextureAtlas]) -> Void)
```
使用该函数立刻调用大量I/O和内存来解码或读入数据，预先放在内存中，你需要在紧急需要的时候调用该函数。不要随意调用该API，以为它会按照你说的**立马**去做！⚠️⚠️⚠️当你调用该函数，请确保立即使用资源，否则API会消耗大量的I/O和内存来加载所有这些图像。

`Sprite Atlases`强大之处是会根据不同设备和屏幕来渲染不同的图像，并传送到正确的设备。

## 总结
![](http://blog.fgyong.cn/Fld0tbjb_RgbF9QWnzTXUYrZJzhG-a)


- 在iOS12上采用最新的算法，这些图像资源会减少10%-20%的空间，
- 使用Xcode的资源目录是不错的选择























