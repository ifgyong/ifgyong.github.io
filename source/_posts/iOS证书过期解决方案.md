title: iOS证书过期解决方案
date: 2016-01-28 10:36:27
tags: 
- iOS
- 疑难杂症
categories: iOS
---
关于证书过期还有描述文件不匹配的问题见解：

## 平时问题下列步骤都能解决
大牛（ps英语好的）[请去苹果开发文档中心](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/Troubleshooting/Troubleshooting.html)
证书过期一般都是先去开发者中心重新创建证书，不过现在的证书过期之后直接被官方删除了，倒是省事了。创建证书不懂的可以自行百度。
删除配置文件【删除哪些？】那些有关过期证书的描述文件都删了
重新生成配置文件【ps怎么生成？ 去这里】
删除Xcode【我用的7.2】本地的描述文件【ps怎么删？去哪里删？】
去目录 `/Users/用户名/Library/MobileDevice/Provisioning Profiles`文件夹下边删除所有的描述文件
然后 下载刚才新生成的描述文件，然后双击下载好的描述文件装到电脑和资料库---------------------------------看到这里如果还不行的话，看我放大招--------------------

## 假如你用的是Xcode 7.2的话
大牛[是去这里](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/Troubleshooting/Troubleshooting.html)
上面的步骤你测试了都不行，然后给你大招解决问题去app工程文件用编辑器打开搜索关键字`PROVISIONING_PROFILE`、`command` +` F` 搜搜有关这关键字的都删除了，然后重启Xcode，重新编译即可
## 问题还没解决怎么办？
看看国际友人怎么处理的
```
I've also the same problem, in Xcode 7.2

It solved by followings steps: 1) Open Xcode preference, 2) Select the appropriate team, 3) Click the "View Details..". 4) In section "Signing Identities": click on "Reset" for each of them.

5) In section "Provisioning Profiles". Click on "Download All".

6) Click on "Done."

7) Go in Xcode, build settings, select it. In General tab, the issues should get removed.

8) Restart the Xcode.

9) Do the Final build.

That's all.
```
我是翻译：

打开Xcode的preference，选择你的账号，点击账号下边的view detail。。然后选择你们的开发证书 reset按钮，之后下载全部的描述文件，点击done按钮。重启和编译Xcode之后，这个问题应该没有了。

--------------------------------------邪恶的分割线----------------------------------------------

这是我对于这个问题的一些总结，希望可以帮到一些人，不懂的可以评论问我。







