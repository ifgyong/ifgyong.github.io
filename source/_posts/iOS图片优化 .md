title: iOS图片优化 
date: 2019-12-13 11:15:58
tags:
- iOS
categories: iOS
---

基于现在iOS11新生成的图片都是`HEIF`，该图片使用`[UIImage image:name]`已不在那么优雅，图片大小为1.8m大小的，读进手机内存，直接飙升了45M，这是我们不想看到的结果，一个页面有多个这样子的图的话，恐怕就是灾难了。

既然原图不能读入，那么如何可以用更少的内存和CPU来解决呢?

这就要先了解该图片的编码了。
## HEIC HEIF

> 带有元数据的HEIF的另一种形式。HEIC文件包含一个或多个以“高效图像格式”（HEIF）保存的图像，该格式通常用于在移动设备上存储照片。它可能包含单个图像或图像序列以及描述每个图像的元数据。最常使用文件扩展名“ .heic”，但HEIC文件也可能显示为.HEIF文件

`heic`和`heif`是广色域图片的格式，广色域比`sRGB`表示范围大25%，在广色域设备中能显示更广的色彩，`sRGB 8bit/dept`，广色域达到`16bit/dept`。广色域只是在硬件支持的情况下才能显示的。
其实就是苹果搞的一个更高效体积更小效率更高的压缩方式。

<!-- more -->

## 加载
加载`image`，只是把**文件信息**加载到内存中，下一步就是解码。在代码中体现就是
```
let image = UIImage(contentsOfFile: url.path)
或 加载图片到内存 会常驻内存
let image = UIImage(named: name)!
```

## 解码
其实是发生在添加到要显示的view上面才会解码
```
let imageV = UIImageView.init(image: image)
imageV.frame = CGRect(x: 50, y: (250 * i) + 100, width: 200, height: 200)
self.view.addSubview(imageV)
```
最后一行不写，则不会解码。

## 渲染
当`view`显示出来则是渲染。过程是解码的`data buffer` 复制到`frame buffer`,硬件从帧缓冲区读取数据显示到屏幕上。
```
self.view.addSubview(imageV)
```

## 内存暴涨原因
一部分图片加载到内存，在解码过程中出现了内存暴涨问题，今天探究一下原因和解决方案。

首先有请我们准备的素材和设备(6s 64g版本)
```
A:jpg
20M 12000*12000

B:jpg
2.8M 3024*4032

C:HEIC
1.8M 3024*4032
```
素材A
```
APP运行内存：13.8M
加载Image: 240.3M之后稳定到220M
CPU：峰值5%，随后降低到0%
image占内存：226.5M
```

素材B
```
APP运行内存：13.7M
加载Image: 31.5
CPU：峰值5%，随后降低到0%
image占内存：17.8M
```

素材C
```
APP运行内存：13.8M
加载Image: 32.3
CPU：峰值4%，随后降低到0%
image占内存：18.5M
```

我们猜测是否是`imageView`的大小影响内存的呢？
`size`改为原来的1/10结果运行内存还是和以前一样。

为什么呢？
> 内存大小不是取决于`view`的`size`，而是原始文件**image size**。

![](/images/14-1.png)
### 渲染格式
#### SRGB
每个像素4字节，包含红黄蓝和透明度，每个通道是1字节8位。
#### display p3 宽色域
每个像素8字节，包含红黄蓝和透明度，每个通道是2字节16位。使用机型iphone7 、iphone8、iphone X及以后的设备，不支持该格式的机型无法显示该效果。
#### 亮度和透明度
每个像素2字节，单一的色调和透明度，只能来显示白色和黑色之间的色值，没有其他颜色。
#### Alpha 8 Format
每个像素1字节，用来表示透明度，一般用作蒙版和文字。
相比sRGB容量小了75%，详细 宽色域 容量小了87.5%


### 渲染图片大小计算
图片大小 = 图片格式容量 * 像素个数
当我们把大小是20\*20使用`Alpha 8 format`渲染到20\*20的view上面，和40\*40的image使用`p3`渲染到20\*20的view中，后着占用内存是前者的8倍。

使用sRGB色域进行渲染所占用的大小为
```
imageWidth*imageHeight*4 字节
```
每个像素占用了4字节，每个字节8位，

使用`display p3`则每个通道占用16位，那么占用内存大小是 
```
imageWidth*imageHeight*8 字节
```

### 如何选择正确的图片格式
> 不要主动选择图片格式，让格式选择你。

不要再使用`UIGraphicsBeginImageContextWithOptions`,该方法总是使用sRGB格式，你想节约内存是不行的，在支持`p3`的设备上想绘制出来`p3`色域的图片也是不行的。那么使用`UIGraphicsImageRenderer`系统可以自动为你选择格式，如果绘制`image`，自己再添加单色蒙版，是不需要另外单独分配内存的。
```
if let im = imageV {
//第二次添加蒙版
	im.tintColor = UIColor.black
}else{
//绘制一个红色矩形
	let bounds = CGRect(x: 0, y: 0, width: width, height: height)
	let renderer = UIGraphicsImageRenderer(bounds: bounds)
	 let image = renderer.image { (coxt) in
		UIColor.red.setFill()
		let path = UIBezierPath(roundedRect: bounds,
								cornerRadius: 20)
		path.addClip()
		UIRectFill(bounds)
	}
	imageV = UIImageView(image: image)
	imageV?.frame = bounds
	self.view.addSubview(imageV!)
}
```

`UIImage` 直接读出来需要将所有`UIImage`的`data`全部解码到内存，很耗费内存和性能。为了节省内存和降低CPU使用率，可以采用**下采样**。
### 下采样
当`image`素材大小是`1000*1000`，但是在手机上显示出来只有`200*200`，我们其实是没必要将`1000*1000`的数据都解码的，只需要缩小成`200*200`的大小即可，这样子节省了内存和CPU，用户感官也没有任何影响。
在`UIKit`中使用`UIGraphicsImageRenderer`会有瞬间很高的内存和CPU峰值，那么
#### 1.UIKit  UIGraphicsImageRenderer
使用素材A下采样技术，使用`UIKit`中的`UIGraphicsImageRenderer`

```
Memory 
High:16.4M
normal:14.8M
CPU:
Hight:29%
normal:0%
```

```
func resizedImage(at url: URL, for size: CGSize) -> UIImage? {
	guard let image = UIImage(contentsOfFile: url.path) else {
		return nil
	}
	if #available(iOS 10.0, *) {
		let renderer = UIGraphicsImageRenderer(size: size)
	
		return renderer.image { (context) in
			image.draw(in: CGRect(origin: .zero, size: size))
		}
	}else{
		UIGraphicsBeginImageContext(size)
		image.draw(in: CGRect(origin: .zero, size: size))
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image
	}
}
```

用子线程绘制，会出现CPU略微升高，当`image size`大很多的时候会出现内存飙升然后慢慢恢复到`normal`。

#### 2.CoreGraphics CGContext上下文绘制缩略图

使用上下文绘制 `cpu` 和内存变化如下,`CPU`和内存没有大的变动解决了该问题，也做到省电、顺滑。
```
Memory 
High:42.3M
normal:14.1M
CPU:
Hight:6%
normal:0%
```
```
func resizedImage2(at url: URL, for size: CGSize) -> UIImage?{
	guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
		let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
	else{
		return nil;
	}
	let cxt = CGContext(data: nil,
						width: Int(size.width),
						height: Int(size.height),
						bitsPerComponent: image.bitsPerComponent,
						bytesPerRow: image.bytesPerRow,
						space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
		,
						bitmapInfo: image.bitmapInfo.rawValue)
	cxt?.interpolationQuality = .high
	cxt?.draw(image, in: CGRect(origin: .zero, size: size))
	guard let scaledImage = cxt?.makeImage() else {
		return nil
	}
	let ima = UIImage(cgImage: scaledImage)
	return ima
	
}
```

#### 3.ImageIO 创建缩略图
使用`ImageIO` 中创建图像，CPU和内存记录反而更高了，内存也居高不下，时间上基本2s才将图像绘制出来。
```
Memory 
High:320M
normal:221M
CPU:
Hight:73%
normal:0%
```

```
func resizedImage3(at url: URL, for size: CGSize) -> UIImage?{
	
	let ops:[CFString:Any] = [kCGImageSourceCreateThumbnailFromImageIfAbsent:true,
							  kCGImageSourceCreateThumbnailWithTransform:true,
							  kCGImageSourceShouldCacheImmediately:true,
							  kCGImageSourceThumbnailMaxPixelSize:max(size.width, size.height)]
	guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
		let image = CGImageSourceCreateImageAtIndex(imageSource, 0, ops as CFDictionary) else {
			return nil;
	}
	let ima = UIImage(cgImage: image)
	printImageCost(image: ima)
	return ima
}
```
#### 4.CoreImage 滤镜
使用滤镜处理反而有点麻烦，在iOS不是专业处理图像的APP中略微臃肿，而且性能不是很好。在重复删除添加操作，第二次出现了APP闪退问题。
```
Memory 
High:1.04G
normal:566M
CPU:
Hight:73%
normal:0%
```
```
	func resizedImage4(at url: URL, for size: CGSize) -> UIImage?{
		let shareContext = CIContext(options: [.useSoftwareRenderer:false])
		
		 guard let image = CIImage(contentsOf: url) else { return nil }
		let fillter = CIFilter(name: "CILanczosScaleTransform")
		fillter?.setValue(image, forKey: kCIInputImageKey)
		fillter?.setValue(1, forKey: kCIInputScaleKey)
		guard let outPutCIImage = fillter?.outputImage,let outputCGImage = shareContext.createCGImage(outPutCIImage, from: outPutCIImage.extent) else { return nil }
		
		return UIImage(cgImage: outputCGImage)
	}
```

#### 5.使用 vImage 优化图片渲染
使用`vImage`创建图像性能略低，内存使用较多，步骤麻烦，是我们该舍弃的。在内存只有1G的手机上恐怕要`crash`了。
```
Memory 
High:998.7M
normal:566M
CPU:
Hight:78%
normal:0%
```

```
func resizedImage5(at url: URL, for size: CGSize) -> UIImage? {
    // 解码源图像
    guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
        let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
        let imageWidth = properties[kCGImagePropertyPixelWidth] as? vImagePixelCount,
        let imageHeight = properties[kCGImagePropertyPixelHeight] as? vImagePixelCount
    else {
        return nil
    }

    // 定义图像格式
    var format = vImage_CGImageFormat(bitsPerComponent: 8,
                                      bitsPerPixel: 32,
                                      colorSpace: nil,
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
                                      version: 0,
                                      decode: nil,
                                      renderingIntent: .defaultIntent)

    var error: vImage_Error

    // 创建并初始化源缓冲区
    var sourceBuffer = vImage_Buffer()
    defer { sourceBuffer.data.deallocate() }
    error = vImageBuffer_InitWithCGImage(&sourceBuffer,
                                         &format,
                                         nil,
                                         image,
                                         vImage_Flags(kvImageNoFlags))
    guard error == kvImageNoError else { return nil }

    // 创建并初始化目标缓冲区
    var destinationBuffer = vImage_Buffer()
    error = vImageBuffer_Init(&destinationBuffer,
                              vImagePixelCount(size.height),
                              vImagePixelCount(size.width),
                              format.bitsPerPixel,
                              vImage_Flags(kvImageNoFlags))
    guard error == kvImageNoError else { return nil }

    // 优化缩放图像
    error = vImageScale_ARGB8888(&sourceBuffer,
                                 &destinationBuffer,
                                 nil,
                                 vImage_Flags(kvImageHighQualityResampling))
    guard error == kvImageNoError else { return nil }

    // 从目标缓冲区创建一个 CGImage 对象
    guard let resizedImage =
        vImageCreateCGImageFromBuffer(&destinationBuffer,
                                      &format,
                                      nil,
                                      nil,
                                      vImage_Flags(kvImageNoAllocate),
                                      &error)?.takeRetainedValue(),
        error == kvImageNoError
    else {
        return nil
    }

    return UIImage(cgImage: resizedImage)
}
```
### 内存优化
图片解码后加载在内存中的数据需要在恰当的时机删除掉，在合适的时机添加上，也是保持低内存使用率的手段。

在用户拨打电话或者进入到其他APP中可以先删除掉大图片，等回来的时候再次添加也是不错的选择。
```
# 1
NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
									   object: nil,
									   queue: .main)
{[weak self] (note) in
	self?.unloadImage()
}
NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
									   object: nil,
									   queue: .main)
{[weak self] (note) in
	self?.loadImage()
}
# 2

override func viewWillAppear(_ animated: Bool) {
	super.viewWillAppear(animated)
	self.loadImage()
}
override func viewWillDisappear(_ animated: Bool) {
	super.viewWillDisappear(animated)
	self.unloadImage()
}
```

### 总结
- 基于性能综合考虑方法1是最简单最合适的
- 使用滤镜和`vImage`略微复杂点，平时开发过程中可以不用考虑了。
- 图片解码缓存和图片大小有关，适当的下采样是不错的选择。





### 参考
- [session 2018 416 iOS Memory Deep Dive](https://developer.apple.com/videos/play/wwdc2018/416)
- [219_image_and_graphics_best_practices](https://developer.apple.com/videos/play/wwdc2018/219)
- [WWDC 中文字幕下载](https://github.com/ifgyong/iOSDataFactory)
- [swift gg 图像优化](https://juejin.im/post/5daaf8b3f265da5b6f074c98#heading-1)

- [学习资料下载git](https://github.com/ifgyong/iOSDataFactory)
- [demo code git](https://github.com/ifgyong/demo/tree/master)

 
 
**唯有实践才是检验真理的唯一标准**
 ---
最怕一生碌碌无为，还安慰自己平凡可贵。




广告时间

![](/images/0.png)


