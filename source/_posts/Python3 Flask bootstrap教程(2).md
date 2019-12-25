title: Python3 Flask bootstrap教程(2)
date: 2018-05-28 12:02:22
tags:
- Flask
- Python3
categories: Python3
---

1.蓝图
2.Nav的使用
3.mysql使用
4.模板的使用
### 蓝图使用
新建user文件夹,在user文件夹下变新建tamplates，还有__init__.py和views.py
__init.py__
<!-- more -->
```
from flask import Blueprint
//声明蓝图
user = Blueprint('user', __name__,template_folder='templates')

from api.v1.user import views
```
然后在run.py中注册蓝图
```
先导入
from api.v1.user import user

app.register_blueprint(user,url_prefix='/user') 后边的是路径
```
然后在user的views中就可以写方法了。
```
from flask import Flask, request, jsonify,render_template
from flask.json import tojson_filter
from api.v1.user import user
from api.v1 import first
import pymysql
import sys
import json
from flask_bootstrap import Bootstrap
//路由
@user.route('/',methods=['GET','POST'])
//方法
def my_index():
    args = request.args;
    age = ''
    name = ''
    if args.__contains__('name'):
        name = request.args.getlist(key='name')
    if args.__contains__('age'):
        age = request.args.__getitem__('age')
//返回数据是json
    return jsonify({'method':sys._getframe().f_code.co_name,
                    'name':str(name),
                    'age':age})
```
现在我们想返回一个html，那么就在tamplates中新建一个index.html
代码如下:
```
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>结果</title>
</head>
<body>
<h1>helloword</h1>
</body>
</html>
```
然后在views中增加路由
```
@user.route('/helloword')
def helloword():
    return render_template('helloword.html')
```
运行程序,输入地址`127.0.0.1：5000/helloword`，出现helloword，就算我们的程序跑起来了。
###  Nav的使用
nav就是html的头部或者banner，我们写一个简单的例子
```
<ul class="nav nav-tabs">
    <li role="presentation" class="dropdown" id="myDropdown">
        <a class="dropdown-toggle" data-toggle="dropdown"  data-target="#" role="button" aria-haspopup="true"
           aria-expanded="false">
            主页 <span class="caret" id="page1"></span>
        </a>
        <ul class="dropdown-menu" role="menu" aria-labelledby="page1">
            <li role="presentation">
                <a role="menuitem" href="add">添加</a></li>
            <li role="presentation">
                <a role="menuitem" href="list">列表</a></li>
            </li>
        </ul>
    </li>
    <li class="dropdown"  >
        <a class="dropdown-toggle" id="group2" data-toggle="dropdown" href="#" role="button">
            文章 <span class="caret"></span>
        </a>
        <ul class="dropdown-menu" role="menu" aria-labelledby="group2">
            <li role="presentation">
                 <a role="menuitem" href="add">添加</a>
            </li>
            <li role="presentation">
                 <a role="menuitem" href="list">列表</a>
            </li>
            <li role="presentation">
                 <a role="menuitem" href="list">列表</a>
            </li>
        </ul>
    </li>

    <li class="active" role="presentation">
        <a class="dropdown-toggle" data-toggle="" href="#" role="button" aria-haspopup="true" aria-expanded="false">
            关于
        </a>
    </li>
</ul>
```
这里边有一个ul 套着一个li，一个li套着一个ul，第二个 ul就是二级菜单。
###  mysql使用
本地需要装环境mysql，用户是root，密码是123456，数据库是test，格式是utf8。下边是我们一个函数返回查询到的表中所有user的名字和年龄。
```
def userList():
    con = pymysql.connect('127.0.0.1', 'root', '123456', 'test', charset='utf8')  # 添加utf8 否则中文乱码
    cur = con.cursor()
    cur.execute('select * from user')
    nums = cur.rownumber
    all = cur.fetchall()
    data = []
    for i in range(len(all)):
        one = all[i]
        data.append({'name': str(one[1]),
                     'age': one[2]})

    con.close()
    return data

```
###  模板的使用
模板是需要我们在模板中先定义一个空的block，然后在继承这个html，把这个block给添加上，等于把一个html文件分拆成多个文件，也可以理解成组件化。添加一个base.html
代码：
```
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <!-- 上述3个meta标签*必须*放在最前面，任何其他内容都*必须*跟随其后！ -->
    <title>Bootstrap 101 Template</title>
    <!-- jQuery (Bootstrap 的所有 JavaScript 插件都依赖 jQuery，所以必须放在前边) -->
<script src="https://cdn.bootcss.com/jquery/1.12.4/jquery.min.js"></script>
<!-- 加载 Bootstrap 的所有 JavaScript 插件。你也可以根据需要只加载单个插件。 -->
<script src="https://cdn.bootcss.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>

    <!-- Bootstrap -->
    <link href="https://cdn.bootcss.com/bootstrap/3.3.7/css/bootstrap.min.css" rel="stylesheet">

    <!-- HTML5 shim 和 Respond.js 是为了让 IE8 支持 HTML5 元素和媒体查询（media queries）功能 -->
    <!-- 警告：通过 file:// 协议（就是直接将 html 页面拖拽到浏览器中）访问页面时 Respond.js 不起作用 -->
    <!--[if lt IE 9]>
      <script src="https://cdn.bootcss.com/html5shiv/3.7.3/html5shiv.min.js"></script>
      <script src="https://cdn.bootcss.com/respond.js/1.4.2/respond.min.js"></script>
    <![endif]-->
</head>
<ul class="nav nav-tabs">
    <li role="presentation" class="dropdown" id="myDropdown">
        <a class="dropdown-toggle" data-toggle="dropdown"  data-target="#" role="button" aria-haspopup="true"
           aria-expanded="false">
            主页 <span class="caret" id="page1"></span>
        </a>
        <ul class="dropdown-menu" role="menu" aria-labelledby="page1">
            <li role="presentation">
                <a role="menuitem" href="add">添加</a></li>
            <li role="presentation">
                <a role="menuitem" href="list">列表</a></li>
            </li>
        </ul>
    </li>
    <li class="dropdown"  >
        <a class="dropdown-toggle" id="group2" data-toggle="dropdown" href="#" role="button">
            文章 <span class="caret"></span>
        </a>
        <ul class="dropdown-menu" role="menu" aria-labelledby="group2">
            <li role="presentation">
                 <a role="menuitem" href="add">添加</a>
            </li>
            <li role="presentation">
                 <a role="menuitem" href="list">列表</a>
            </li>
            <li role="presentation">
                 <a role="menuitem" href="list">列表</a>
            </li>
        </ul>
    </li>

    <li class="active" role="presentation">
        <a class="dropdown-toggle" data-toggle="" href="#" role="button" aria-haspopup="true" aria-expanded="false">
            关于
        </a>
    </li>
</ul>
这下边就是定义的缺少的block
{% block page_content %}
{% endblock %}
```
然后我们在子网页中继承这个模板并且添加上去block
```
//继承刚才的网页
{% extends 'base.html' %}
//下边的block的对应刚才定义的代码块，对应不上的话，会展现不出来下边的代码
{% block page_content %}
<div class="pager">
    <h1 align="center">用户列表</h1>

    <table class="table nav-tabs">
        {% for i in data %}
            <tr>
                <td>名字：{{ i.name }}</td>
                <td>年龄：{{ i.age }}</td>
            </tr>
        {% endfor %}
        <tr>
            <td align="center">
                <a href="add">
                    <input type="button" value="添加用户"  align="center" style="width: 200px">
                </a>
            </td>
            <td align="center">
                <a href="list" >
                    <input type="button"  value="用户列表" style="width: 200px">
                </a>
            </td>
        </tr>
    </table>
</div>
{% endblock %}
```