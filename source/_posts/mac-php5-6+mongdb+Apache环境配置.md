title: PHP5.6+YII+MongoDB环境搭建
date: 2018-4-16 15:39:24
tags:  
- PHP环境配置
- YII
- MongoDB
categories: 数据结构 
---
### 1.安装php5.6
##### 1.先安装brew，要是不确定是否已经安装了brew，可以先运行`brew -v`查看版本，有版本号的话直接下一步，报错的话安装brew。
安装命令是`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
`有其他问题可以查看[brew官方安装方法](https://brew.sh/index_zh-cn)。
##### 2.搜索PHP
```
brew search php
```
![brew search php](https://upload-images.jianshu.io/upload_images/783986-58be6a637b83983b.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


### 3.安装PHP
```
brew install php@5.6
```
OK，安装完成。
### 2.安装MongoDB
```
sudo brew install mongodb #安装MongoDB

sudo mongod #启动

# 如果没有创建全局路径 PATH，需要进入以下目录
cd /usr/local/mongodb/bin
sudo ./mongod


$ cd /usr/local/mongodb/bin 
$ ./mongo
MongoDB shell version v3.4.2
connecting to: mongodb://127.0.0.1:27017
MongoDB server version: 3.4.2
Welcome to the MongoDB shell.
……
> 1 + 1
2
> 
```
### 3.配置Apache
不知道mac的Apache目录的可以使用命令`which apache`，一般的配置文件目录是`/etc/apache2`，Apahce启动的时候读的文件是http.conf，现在我们配置http.conf
```
因为我配置了两个web，所以监听 80 和 81
  Listen 80
  Listen 81
#加载PHP动态库的配置，如果是用的PHP7.1或者其他版本，路径改为相对应版本的路径。加入是使用brew安装的PHP5.6的话，路径应该是我的路径。
#PHP7.1的路径
LoadModule php7_module libexec/apache2/libphp7.so
#php5.6的路径
 LoadModule php5_module /usr/local/opt/php@5.6/lib/httpd/modules/libphp5.so

<VirtualHost *:81>    #ServerAdmin demo@demo.com    
 DocumentRoot "/Users/Jerry/Desktop/s/api/web"    
 ServerName demo.com         
<Directory "/Users/Jerry/Desktop/s/api/web">   
      Options +Indexes +Includes +FollowSymLinks +MultiViews     
    AllowOverride All         Require local         Require all granted       
  IndexIgnore */*         RewriteEngine on         RewriteCond %
{REQUEST_FILENAME} !-f         RewriteCond %
{REQUEST_FILENAME} !-d         RewriteRule . index.php       
</Directory>    
 ErrorLog "/private/var/log/apache2/demo.com-
error_log"    
 CustomLog "/private/var/log/apache2/demo.com-
access_log" common
 </VirtualHost>
            AllowOverride None         Require all granted    
     IndexIgnore */*         RewriteEngine on         RewriteCond %
{REQUEST_FILENAME} !-f         RewriteCond %
{REQUEST_FILENAME} !-d         RewriteRule . index.php     
</Directory>  
   ErrorLog "/private/var/log/apache2/demo2.com-error_log"  
   CustomLog "/private/var/log/apache2/demo2.com-access_log" 
common </VirtualHost>
```
配置好Apache需要重新启动，
```
sudo /usr/sbin/apachectl restart #重新启动
sudo /usr/sbin/apachectl start#启动
sudo /usr/sbin/apachectl stop#停止
```
在
`/Users/Jerry/Desktop/s/api/web`新建index.html，内容是
```
<?php
phpinfo();
>
```
添加url到hosts
```
vi  /etc/hosts
#添加 
127.0.0.7 demo.com
#保存退出
:wq
#刷新hosts立即生效
source /etc/hosts
```
在浏览器中输入http://demo.com/,回车，出来的界面是
![PHPinfo](https://upload-images.jianshu.io/upload_images/783986-e1b5fda1f7385967.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
这就代表运行成功了，其实这个界面包含很多配置信息，左边是参数，右边是值，例如：
Server API 值是Apache 2.0Handler。

已经有项目的，可以
```
git clone git地址 dirName #克隆仓库
cd ./dicNme #进入工程文件
composer install #安装 composer
```

有什么疑问的小伙伴可以留言哦。
更多博客在www.fgyong.cn可见。



