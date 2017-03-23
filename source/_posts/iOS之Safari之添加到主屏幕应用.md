title: iOS之Safari之添加到主屏幕应用
date: 2016-11-21 16:39:24
tags: iOS高级开发
categories: iOS
---

先写好的DemoHtml先需要在手机上试验一下，结果mac上面的文件不能用手机打开，我就想了个办法，直接开一个服务，把mac当成服务器访问服务器上面的文件，这个问题就解决了。

### 1.启动mac py 服务
首先进入到你要共享的文件夹，直接运行下边的命令，然后就可以再手机浏览器中查看mac上面的电脑了。
```
python -m SimpleHTTPServer 8000  启动本地端口8000
```

### 2.查看电脑IP[局域网的ip]
```
我的是：192.168.99.1
```
### 3.手机Safari打开
```
192.168.99.1:8000
```

![IMG_0853.PNG](http://upload-images.jianshu.io/upload_images/783986-f559dd371ab3227d.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 4.js代码
html代码和正常的布局一样，想要什么样子自己可以随意写，这里只是提供了比较特殊的 js代码。
```
<script>
    var alone = window.navigator.standalone;//是否是从桌面启动
   var url = "taobao"; //url可以换成自己的
        if(alone){
        window.open(url+":",'_self');//打开淘宝app url可以换成自己的app scheme
    }     else {  
      window.open(url+":",'_self');  
  }</script>
```
打开这个html文件点击Safari保存到主屏幕。
在此打开之后的效果：

![IMG_0854.PNG](http://upload-images.jianshu.io/upload_images/783986-bb3c3fadbd9cf618.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

其实做这个功能就是方面用户直接点击icon启动app并且调用某个功能，省了不少时间。
