title: Git到CocoaPods看我就够了
date: 2016-04-22 16:39:24
tags: Git
categories: Git
---
### 看了这篇文章你可能
+ 学会Git基本使用
+ 学会在mac上装CocoaPods
+ 提交代码到CocoaPods
+ 代码在CocoaPods的版本迭代

### git 基本使用
在[github](https://github.com)注册账号,然后新建仓库，
```
git clone git@github.com:ifgyong/FYAlbum.git
//这里git仓库地址分为https和ssh两种，我是用的ssh的地址。
```

然后 `cd FYAlbum/`目录.这个目录就是仓库了，连着github的地址的仓库。

```
git branch -l //查看所有分支
git branch 'branchName' 新建本地分支
git status //查看文件状态，哪个修改的会显示出来的
git add .  //添加所有文件到缓存
git commit -m '注释' //把添加到缓存的文件提交到本地 仓库
git push origin master //提交本地的master到远程仓库。
git tag 'tagName' 设置一个tag
git push --tags //把本地 的tags推送到远程仓库
git tag  //tag 列表
git log //git的日志，每次修改的记录

git config --global user.name "YOUR NAME" //配置全局的name
git config --global user.email "YOUR EMAIL ADDRESS" //配置全局的email
以后每次提交的时候都是会用这个账号。
单独为某个仓库配置账号的时候去掉`--glocal`
就是
git config   user.name "YOUR NAME" //配置 name
git config   user.email "YOUR EMAIL ADDRESS" //配置 email

git config -l //查看配置

合并分支：
git checkout -b dev 
//创建并切换到dev分支 相当于 git branch dev gitcheckout dev 两条命令
 git merge dev //将dev分支合并到当前分支
这种方式叫快速合并。
git branch -d dev //删除分支

用git log --graph命令可以看到分支合并图。

 git merge dev --no-ff// 后边加上`--no-ff`是合并的时候有历史记录，比较稳定。
当然在合并的时候有冲突怎么办？

解决冲突：
git status//查看文件状态  冲突文件在这里会有显示的

git diff 文件一  文件二  //对比两个文件，哪个有问题修改哪个。

修改完成之后就可以合并了。` git merge dev --no-ff`

别人提交的文件更新到本地：
git pull 

在每个操作后边可以加上 `--verbose`可以观看过程，就是日志了。
暂时一般常用的就这么多了。
```

### 在mac上装CocoaPods

```
sudo gem install cocoapods
```
搜索第三方库
```
pod search AFNetworking
```

装好了pod 直接`cd /user/工作目录`,新建`Podfile`文件

```
pod init
```
新建Podfile
```
vi Podfile
```
修改podfile文件内容
```
platform :ios, '8.0'
use_frameworks!
target 'MyApp' do
  pod 'AFNetworking', '~> 2.6'
  pod 'ORStackView', '~> 3.0'
  pod 'SwiftyJSON', '~> 2.3'
end
上边的AFNetworking，ORStackView，SwiftyJSON 都是名字，后边是版本号。
```
修改完之后保存
```
：wq
```

```
pod setup ///初始化pod仓库
pod update //更新仓库
```
### 提交代码到CocoaPods
#### 注册trunk 
具体步骤看[这里：](https://guides.cocoapods.org/making/getting-setup-with-trunk.html)
```
pod trunk register fgyong@fgyong.cn 'fgyong' --verbose
```
然后检查注册成功了没
```
pod trunk me
成功应该是这样的：
- Name: fgyong 
- Email: fgyong@fgyong.cn
 - Since: xxxxxxx 
- Pods:  
- Sessions: - xxxxxx 
```
#### [配置Podspec](https://guides.cocoapods.org/syntax/podspec.html)
```
pod spec create FYong//新建podSpec文件

vi FYong.podspec //用vi 打开

```
里面有很多注释，你可以把需要的填写一下或者复制我的修改一下就可以用了。
文件里面的必要是属性：
```
Pod::Spec.new do |s|

  s.name          = "FYAlbum"
  s.version       = "1.0.1"
  s.license       = "MIT"
  s.summary       = "Fast encryption string used on iOS, which implement by Objective-C."
  s.homepage      = "https://github.com/ifgyong/FYAlbum"
  s.author        = { "fgyong" => "fgyong@yeah.net" } 
  s.source        = { :git => "https://github.com/ifgyong/FYAlbum.git", :tag => s.version }
  s.requires_arc  = true           
   s.source_files  = "FYAlbum/*/*"
   s.platform      = :ios, '8.0'        
   s.framework     = 'Foundation', 'UIKit'  
end
```
上边的`s.source_files`容易出错，这个路径是相对于podspec的文件路径。`FYAbul/*`代表FYAbul一级目录下所有文件`FYAlbum/*/*`代表FYAlbum一级和二级目录下所有文件。
+ tag 和s.version要对应的，不然报错的。
+ framework直接写上名字就好了。
+ license是证书类型哦

做完这些可以给仓库打上tag 和version了
```
git tag 1.0.0 // 加上tag
git push --tags//推到remote
```
```
pod spec lint --verbose  //验证是否成功
pod lib lint --verbose      //验证是否成功
git trunk push FYong.spec --verbose //将文件和配置推到trunk上面
```
现在验证pod秒就ok了，等到成功了，直接`pod search FYong`就出现了。大功告成！！！
###   代码在CocoaPods的版本迭代
中间验证的时候，你的工程修改文件了，那么这个tag要修改才可以了，否则即使你修改了文件也报同样的错误！！！具体的要求看[这里](https://guides.cocoapods.org/)
```
git tag 1.0.1
git push --tags
修改FYong.spec 文件里边的`s.version = 1.0.1`
git trunk push FYong.spec --verbose //将文件和配置推到trunk上面
这次就可以成功了！！！
```
我参考的博文：
+ [廖雪峰](http://www.liaoxuefeng.com/wiki/0013739516305929606dd18361248578c67b8067c8c017b000)
+ [guides.cocoapods.org](https://guides.cocoapods.org)
+ [【原】iOS：手把手教你发布代码到CocoaPods(Trunk方式)](http://www.cnblogs.com/wengzilin/p/4742530.html)

基本到这里就结束了，是不是还是感觉意犹未尽啊！
有什么问题欢迎留言啊！
[我的项目](https://github.com/ifgyong/FYAlbum),如果觉得不错，欢迎✨啊。
 欢迎来吐槽啊！！！
