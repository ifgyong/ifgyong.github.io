title: iOS 手动做一个自动打包部署神器
date: 2019-6-25 16:39:24
tags: 
- iOS 
- 自动打包
categories: iOS
---
之前使用的fastlane添加pgyer自动打包的，最近发现更新总是有问题，所以产生了自己shell做一个的想法。虽然代码比较少，但是很实用。
- 打包
- 导出ipa
- 上传pgyer

#### 打包自动上传pgyer
```
#!/bin/bash

#xcodebuild archive -project 'test.xcodeproj' -configuration 'Debug' -scheme 'BLTSZY' -archivePath './app.xcarchive' LIBRARY_SEARCH_PATHS="./Pods/../build/**  ./BLTSZY/**"
proName='your project name'
proURL="your project path"#like /Users/Jerry/Desktop/ios_afu
api_key=''#pgyer api_key
configuration='Debug' #Release 
autoPlus(){
path=${proURL}/${proName}/${proName}/Info.plist
number=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${path}")
BundleVersion=$(( $number + 1 ))
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $BundleVersion" "${path}"
}
#打包
arch(){
    echo '开始编译Pods'
    xcodebuild -project Pods/Pods.xcodeproj build
    echo '开始编译project'

xcodebuild -archivePath "./build/${proName}.xcarchive" -workspace $proName.xcworkspace -sdk iphoneos -scheme $proName -configuration $configuration archive
autoPlus
}
#导出ipa
exportIPA(){
    echo '开始导出ipa'
    xcodebuild -exportArchive -archivePath "./build/${proName}.xcarchive" -exportPath './app' -exportOptionsPlist './ExportOptions.plist'
}
#上传ipa到蒲公英
upload(){
if [ -e "${proURL}/app/${proName}.ipa" ]
then
    echo '开始上传ipa/apk到蒲公英'
    curl -F "file=@${proURL}/app/${proName}.ipa" -F "_api_key=${api_key}" 'http://www.pgyer.com/apiv2/app/upload'
else
    echo "在目录：${proURL}/app/${proName}.ipa 不存在"
fi
}
startarch(){
    arch
    if (($? == 0))
    then
        echo 'archive success🍺'
        startExportIPA
    else
        echo 'archive faild❌'
    fi
}
startExportIPA(){
    exportIPA
    if(($? == 0))
    then
        echo 'exportIPA success🍺🍺'
        startUPLoadIPA
    else
        echo 'exportIPA faild ❌'
    fi
}
startUPLoadIPA(){
    upload
    if(($? == 0))
    then
        echo 'uploadIPA success'
    else
        echo 'uploadIPA faild ❌'
    fi
}


if (($# == 0))
#then
#    startarch
#elif (($# == 1))
then
        while :
        do
        echo '🍺🍺🍺***********************🍺🍺🍺'
        echo  "输入 1 到 4 之间的数字:"
        echo  "输入 1:从编译打包开始至结束"
        echo  "输入 2:从导出IPA开始至结束"
        echo  "输入 3:从上传ipa开始至结束"
        echo  "输入 4:退出"
        read a
        case $a in
            1)startarch
            break;;
            2)startExportIPA
            break;;
            3)startUPLoadIPA
            break;;
            4) break;;
        esac
        done
fi

```
将该文件和plis拖到project目录下，然后配置
plis文件：
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>ad-hoc</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>your bundle id</key>
		<string>your .mobileprovsion</string>
	</dict>
	<key>signingCertificate</key>
	<string>iPhone Distribution</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>your_team_id</string>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
```
下载`setup.sh`拖到项目文件夹内，然后
运行`./setup.sh`，即可完成上传到pgyer网站。
具体的配置属性见源码下载页面。
[查看源码](https://github.com/ifgyong/autoAEU)

```
