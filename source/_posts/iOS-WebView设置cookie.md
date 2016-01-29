title: iOS WebView设置cookie
date: 2016-01-28 11:13:58
tags:
- iOS
categories: iOS
---

## 添加cookie的时候必须先设置可以接受cookie
```
[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
```
然后设置cookie内容


```
NSMutableDictionary *cookiePropertiesUser = [NSMutableDictionary dictionary];
NSString *cook = [[MDUserCache getInstance].user objectForKey:@"cookie_key"];
if ([cook length]) {
    [cookiePropertiesUser setObject:@"user_info" forKey:NSHTTPCookieName];//cookie的名字
    [cookiePropertiesUser setObject:cook forKey:NSHTTPCookieValue];//cookie的值
    [cookiePropertiesUser setObject:[[NSDate date] dateByAddingTimeInterval:2629743] forKey:NSHTTPCookieExpires];//过期时间
    [cookiePropertiesUser setObject:@"baidu.com" forKey:NSHTTPCookieDomain];//给那个网址设置
    [cookiePropertiesUser setObject:@"/" forKey:NSHTTPCookiePath];
    [cookiePropertiesUser setObject:@"0" forKey:NSHTTPCookieVersion];
}

NSHTTPCookie *cookieuser = [NSHTTPCookie cookieWithProperties:cookiePropertiesUser];
```


## 删除cookie
```
[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookieuser];
删除cookie

- (nullable NSArray *)cookiesForURL:(NSURL *)URL;//先获取某个域名下的cookie然后删除

- (void)deleteCookie:(NSHTTPCookie *)cookie; //删除cookie
```
