title: MAC 重置MySQL root 密码
date: 2016-01-28 11:16:24
tags:
- iOS
categories: iOS
---


重置MySQL root 密码：
当忘记密码，或者想要强行重置 MySQL 密码的时候，可以像下面这样：

1.停止 MySQL 服务
```
sudo /usr/local/mysql/support-files/mysql.server stop
//当停止失败 见下边 如何用mac 活动指示器停止服务。
```

2.进入安全模式

```
sudo mysqld_safe --skip-grant-tables
```
这个地方，如果你 alias 了 mysqlld_safe 这个命令，那么可以直接复制粘贴；如果没有，则需要加上正确的路径。在 Linux/OS X 系统下，默认路径是 /usr/local/mysql/bin/mysqld/usafe。

说是安全模式，其实是超级危险模式！如果你是在本地修改，那没问题；如果是在服务器上，那你得保证这个时候没有任何人登录到系统。因为一旦进入了安全模式，任何人都可以使用任何密码通过 root 用户登录入到 MySQL ，可以执行任何想执行的操作。

这也是为什么，当我们密码忘记了的时候，我们可以这样来修改密码。凡事有利有弊，你可以用这种方式来做好事；而同样，可以用来做坏事。

3.新打开一个终端，进入 MySQL
```
-u root -p
```


这里也和 mysqld_safe 一样。如果你是 OS X 上新装的 MySQL ，那么很有可能并不能直接使用 mysql 这个命令。而是要使用它的绝对路径： `/usr/local/mysql/bin/mysql -u root -p`

然后输入任意密码就可以进入 MySQL 了。

修改密码
进入了之后先不要急着使用 update 命令修改密码，先看看表中的字段名。不同版本密码的字段名可能不一样。
```
MySQL 的用户信息是存在 mysql.user 这个表里面的。于是可以先选择 mysql 这个数据库，再看数据库中 user 表中的字段名称。
use mysql; //切换数据库
describe user; //查看user表的字段
```

 

 然后确定密码字段的名称，一般可能是 Password。然而在 OS X 的 MySQL 5.7 这个版本中，密码字段名称是 authentication_string 。记住这个字段名。

 然后修改密码啊：
 ```
 UPDATE mysql.user SET authentication_string=PASSWORD(‘123456’) where User=’root’; //将root用户密码改成 123456
 ```

  

  5.刷新权限，使配置生效
  ```
  flush privileges;
  ```

   

   最后再启动 MySQL
   ```
   sudo /usr/local/mysql/support-files/mysql.server start
   ```

   当启动失败的话，可以直接用mac工具活动监视器：
   搜索mysql 进程名称列表有mysql的话，直接双击出现：这里写图片描述
   点击退出即可。

   修改完之后记得刷新权限 和重新启动mysql服务才行。


