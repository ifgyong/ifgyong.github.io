title: hexo换了电脑处理方法
date: 2016-01-31 12:02:22
tags:
- 建站
- hexo
categories: 建站
---

## hexo换了电脑处理方法
为了可以在多个电脑上面都处理hexo博客，所以我把source文件和网站的文件分别放在hexo和master分支上面了。
克隆到本地你的仓库
```
git clone git@github.com:ifgyongifgyong.github.io.git
```
## 然后切换到hexo分支上面
```
git checkout hexo

运行 `hexo s --debug` 看看能不能正常启动。
在浏览器打开 `localhost:4000`
```
## 然后测试是否在新的电脑上面能不能发表新的文章
```
hexo new '测试'

hexo s --debug 然后打开`localhost:4000`就可以看见刚才发表的测试文章了
```
## 编译到git上面
```
hexo clean
hexo g
hexo d
然后打开你自己的网站，我的是fgyong.cn，查看文章上去没了没。
```
我执行`hexo d`好几次都成功了，但是 网站上面的内容都没有更新，我就纳闷了。
## 最终大招
最后在知乎偶尔看见一个答案说是 删除仓库中的`.deploy_git`文件夹，然后在重新编译，部署。OK，新的文章出现了。

