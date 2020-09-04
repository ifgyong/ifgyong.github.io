# fgyong的技术博客


![travis build](https://travis-ci.com/ifgyong/ifgyong.github.io.svg?branch=hexo)

可以直接在本地运行的，步骤如下：


# 安装

当前`hexo`版本是 `4.2.1`,配置在`package.json`中，

只需要`npm install`安装一下包即可，修改完了文件。

```
hexo clean//删除历史记录文件
hexo g// 打包
hexo d //部署

hexo s -p 4000 本地跑起来，在4000端口

hexo s --debug 本地测试查看
```

`next`主题是clone之后删除了`.git`文件夹，将next文件夹拖到其他地方，在`hexo`分支提交下之后，然后将`next`提交到原来的地方，在`git add themes/next`来提交一次即可。

