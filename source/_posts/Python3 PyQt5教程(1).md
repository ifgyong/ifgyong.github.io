title: Python3 PyQt5教程(1)
date: 2018-5-9 16:39:24
tags: 
- Python3 
- 开发
- 建站
categories: Python3
---


Python的GUI库，新手可以先从PyQt5入手，一周精通。
1.HelloWord
2.添加button
3.菜单栏
4.textEdit
5.打包
### 1.helloWord
```
#!/usr/bin/env python
# -*- coding: utf-8 -*-
# @Time    : 2018/5/9 下午1:36
# @Author  : fgyong 简书:_兜兜转转_  https://www.jianshu.com/u/6d1254c1d145
# @Site    : http://fgyong.cn 兜兜转转的技术博客
# @File    : 12.py
# @Software: PyCharm
import sys,time,datetime
from PyQt5.QtWidgets import (QMainWindow,QMessageBox,QWidget, QToolTip, QPushButton, QApplication, QGestureEvent,QLabel,QDesktopWidget)
from PyQt5.QtGui import QFont,QIcon


class Example(QWidget):
  #构造函数
    def __init__(self):
        super().__init__()
        self.initGUI();
#初始化函数
    def initGUI(self):
#设置窗体frame
         self.setGeometry(500, 300, 300, 300)
#窗体title
        self.setWindowTitle('我的第一个程序')
#添加label
        self.lable = QLabel('helloword!',self)
#自动换行
        self.lable.setWordWrap(True)
#lable的frame
        self.lable.setGeometry(50,100,200,150)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = Example()
    ex.show()
    sys.exit(app.exec_())

```
### 2.添加按钮
```
class Example(QWidget):
    lable = ''
    def __init__(self):
        super().__init__()
        self.initGUI();

    def initGUI(self):
        # QToolTip.setFont('SanSerif',10)
#提示文字
        self.setToolTip('<b>这是第一个QWidget</b>')
#更新时间的button
        btn = QPushButton('更新时间', self)
#button的提示文字
        btn.setToolTip('这是个btn')
#设置默认大小
        btn.resize(btn.sizeHint())

        btn2 = QPushButton('alert', self)
        btn2.setToolTip('这是弹出alert的btn')
        btn2.resize(btn.sizeHint())
        btn2.move(0,60)
        btn2.clicked.connect(self.showMessage)

        size = self.geometry()
   #绑定button的点击函数   self.showTime是函数名字后边没有（）
        btn.clicked.connect(self.showTime)

        self.setGeometry(1500, 300, 300, 300)
        self.setWindowTitle('我的第一个程序')

        self.lable = QLabel('时间：',self)
        self.lable.setWordWrap(True)#自动换行
        self.lable.setGeometry(50,100,200,150)
        self.lable.setText('时间:'+datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        icon = QIcon("/Users/Jerry/PycharmProjects/Flask_dmeo_1/App/icons/cry.png")
        btn.setIcon(icon)
        self.setWindowIcon(icon)
    def showTime(self):
        nowTime=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        self.lable.setText("时间:"+nowTime)

    def showMessage(self):
        self.showBox("alert message")
    def showBox(self,message):
        box=QMessageBox.question(self,'温馨提示',message,QMessageBox.Yes|QMessageBox.No,QMessageBox.No)
        if box == QMessageBox.Yes:
            self.lable.setText(self.lable.text()+'YES')
        else:
            self.lable.setText(self.lable.text() + 'NO')
if __name__ == '__main__':
    app = QApplication(sys.argv)
    ex = Example()
    ex.show()
    sys.exit(app.exec_())
```
### 3.菜单栏
```
    def showMenu(self):
        # 生成母菜单栏
        menubar = self.menuBar()
        #添加菜单
        p = menubar.addMenu('p')
        #菜单 p2
        impMenu = QMenu('p2', self)
        # 子菜单 p2 click
        impAct = QAction('p2 click', self)
        #绑定 action
        impAct.triggered.connect(self.p2)
        # 添加菜单 p2 click
        impMenu.addAction(impAct)
        # 添加菜单 p2
        p.addMenu(impMenu)


        newAct = QAction('p1', self)
        newAct.triggered.connect(self.p1)
        p.addAction(newAct)


    def p1(self):
        print("p1")

    def p2(self):
        print("p2")
```


### 4.文本框 QTextEdit
```
    def showTextView(self):
        self.b=QTextEdit(self)
        self.b.setPlaceholderText('我是默认文字')
        self.b.setGeometry(20,150,200,100)

        btn3 = QPushButton('提交', self)
        btn3.resize(btn3.sizeHint())
        btn3.clicked.connect(self.print)
        btn3.move(110,260)
    def print(self):
        #输出来文本框的汉字
        print(self.b.toPlainText())
```

### 5.打包成可执行文件
这里说是打包，不是exe和dmg，而是可执行文件
```
********************************************************************
pyinstaller -F path 
编译成可执行文件
path是想编译文件的路径

会生成 dist文件夹和build文件夹,在dist文件夹下边生成一个可执行文件，
文件的名字和编译文件的名字一样。双击就可以执行这个程序了。
********************************************************************
```
学习的小伙伴可以下载来看哦[仓库地址](git@github.com:ifgyong/PYDemo.git)

