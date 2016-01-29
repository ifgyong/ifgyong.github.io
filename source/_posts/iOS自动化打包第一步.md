title: iOS自动化打包第一步
date: 2016-01-28 17:32:06
tags:
- iOS
- Shell
- iOS自动化打包
categories: iOS
---
## shell入门初探
iOS打包有点烦人，现在就是想做个脚本一条命令执行之后打包然后上传到测试环境脚本。这是第一步在上传的基础上又写了一层上传只需要一条命令即可

``` 
 #!/bin/bash 
 if [ $# != 1 ] //判断输入参数
    then
     echo "请输入版本号"//没有参数直接报错
     exit             //退出
 else
     version=${1}    //获取输入的版本号
     shorder="./debug-publish.sh ${version} ios debug-${version}.ipa"//将要执行的shell脚本和命令


      $shorder //执行字符串脚本
      echo "正在执行命令。。。"
      if [ $? -eq 0 ]//判断执行命令的结果是否成功 0是成功
       then
       echo "push successed"
       else
            echo "push faild"
         fi

fi
                                                                                                 ```
                                                                                                 完成之后就可以使用了记得给这个脚本权限哦
                                                                                                 ```
                                                                                                 chmod +x yourShellFile //给执行权限

                                                                                                 ./yourShellFile 1.1.1 //执行脚本在本目录下面
                                                                                                 ```


                                                                                                 这是我的第一个脚本哦欢迎大虾指教。


