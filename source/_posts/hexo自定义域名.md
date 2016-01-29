title: hexo自定义域名
date: 2016-01-28 11:44:52
tags:
- 建站
categories: 建站
---
## 注册购买域名
就像买淘宝的宝贝一样简单，[阿里云域名购买](http://wanwang.aliyun.com/domain/?spm=5176.200001.n2.13.iyigkk)

## 设置DNS
 设置IP地址的时候设置成github的IP具体获取方法是
  ```
    $ nslookup fgyong.github.io//这个地址是你自己的地址下边的是输出来的，其中103.245.222.144便是上边需要的IP。
     Server:        211.162.96.1
     Address:    211.162.96.1#53

     Non-authoritative answer: 
     fgyong.github.io    canonical name = github.map.fastly.net.
     Name:    github.map.fastly.net
     Address: 103.245.222.133
     ```
## 新建CNAME
           在hexo文件目录source下边执行
           ```
           vi CNAME //新建文件并打开
           然后把你买的域名写入文件退出并保存。
           比如我的是 http://fgyong.cn,写入文件的 网址是fgyong.cn.`没有http字样的`
           ```

           然后
           ```
           编译 hexo g
           上传github hexo d
           ```

           大功告成，可以测试查看成果了。
            
             
