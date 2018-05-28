title: Python3 Flask bootstrap教程(1)
date: 2018-05-27 12:02:22
tags:
- Flask
- Python3
categories: Python3
---

1.安装Flask
2.安装bootstrap
3.HelloWord

### 安装Flask
我用的py3，所以安装命令是：
`pip3 install Flask`，安装之后，在Pycharm里边看到是这样子的，
![py3第三方库列表](https://upload-images.jianshu.io/upload_images/783986-a4a6c6ec9ceee10a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 安装bootstrap
安装bootstrap，看这里[官方教程](https://v2.bootcss.com/index.html),
或者[下载](http://getbootstrap.com/2.3.2/assets/bootstrap.zip
)，然后解压，放到Flask的目录下边。我的目录是这样子的
![目录](https://upload-images.jianshu.io/upload_images/783986-be66520f42984dda.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### HelloWord
初始化Flask，
新建app.py
代码如下：
```
from flask import Flask, request, jsonify
import os
from api.v1 import config
from api.v1.user import user
from flask_bootstrap import Bootstrap

app = Flask(__name__)
Bootstrap(app)
app.config.from_object(config)
app.register_blueprint(user,url_prefix='/user')

if __name__ == '__main__':
    app.run()
```
选中文件，右键->run。这样子就跑起来了，好像现在没接口，那我们添加一个路由.
完整代码如下:
```
app = Flask(__name__)
Bootstrap(app)
app.config.from_object(config)
app.register_blueprint(user,url_prefix='/user')
@app.route('/index')//添加路由
def my_index()://路由执行的函数
    return jsonify({"key":'helloWord'})//返回数据
if __name__ == '__main__':
    app.run()//app运行
```
![helloword](https://upload-images.jianshu.io/upload_images/783986-435882bd99cf0aa0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
