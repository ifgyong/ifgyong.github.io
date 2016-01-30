title: Module version mismatch
date: 2016-01-30 20:32:53
tags:
- 建站
- hexo
categories: 建站 
---
# Module version mismatch
就是模块 版本不匹配了，我这个电脑是很久没用了`npm -v //2.*.*`，我在官网查了一下 npm 都已经3.*了，就索性把npm更新了一下`sudo npm i -g npm //更新npm`。然后在执行 `hexo s` 竟然还报错，错误如下

```
MacBook:ifgyong.github.io fgy$ hexo -v
[Error: Module version mismatch. Expected 46, got 47.]
{ [Error: Cannot find module './build/default/DTraceProviderBindings'] code: 'MODULE_NOT_FOUND' }
{ [Error: Cannot find module './build/Debug/DTraceProviderBindings'] code: 'MODULE_NOT_FOUND' }
hexo: 3.1.1
os: Darwin 15.3.0 darwin x64
http_parser: 2.5.0
node: 4.2.4
v8: 4.5.103.35
uv: 1.7.5
zlib: 1.2.8
ares: 1.10.1-DEV
icu: 56.1
modules: 46
openssl: 1.0.2e
```
在Google了好久终于发现一条解决这个问题的命令【出现这个的原因是装hexo的时候有些包没有下载下来】，执行下面的命令在查看hexo 版本的时候就不报错了。
```
npm install hexo --no-optional --save 
```

