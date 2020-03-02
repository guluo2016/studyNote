## Windows上SSH协议下配置github免密clone

1 首先配置git:
```
git config --global user.name "guluo"
git config --global user.email "xxx@xx.com"
```

2 生成ssh公钥与秘钥
```
ssh-keygen -t rsa -C "guluo"
```

3 找到id_rsa.pub，将文件中的内容粘贴到github中的ssh中

## Windows下https协议下配置github免密登录

之所以要使用https协议去clone仓库的原因在于，由于一些原因，github clone是非常慢的，有时候干脆下载速度为0，这个时候就不得不借助一些工具去代理下载。而ssh协议是不支持ssr代理，http却是支持。

1 在当前用户目录下，创建一个认证文件，并填写内容
```
#创建一个文件
vim ~/.git-credentials

#在文件中添加内容，这里的username，password就是github上的账号密码
https://{username}:{passwd}@github.com
```

2 进行认证
```
git config --global credential.helper store
```

3 认证成功之后，查看～/.gitconfig文件，会发现`helper = store`
```
[credential]
        helper = store
```

至此之后，就可以基于https协议去免密clone仓库，并且进行push、pull

ps:项目clone下来后第一次push，仍然需要输入账号密码；输入一次之后，之后就不再输入了

**此处的参考博客**  
Git之SSH与HTTPS免密码配置:[https://www.jianshu.com/p/b5ec092fc1d1](https://www.jianshu.com/p/b5ec092fc1d1)


## github配置代理，clone速度飞起来
即使代理开起来，发现git clone项目还是很慢，网上说的修改hosts文件的方法提升效果几乎没有，还是使用代理速度肉眼可见提升。

这里使用的代理是ss/ssr,其他代理方式没有试过，ss的默认本地端口是1080，为了使github clone变快，需要进行如下配置：
```
git config --global http.proxy 'socks5://127.0.0.1:1080'
git config --global https.proxy 'socks5://127.0.0.1:1080'
```
当执行上面的命令之后，去查看`~/.gitconf`文件，会发现多了如下内容：
```
[http]
        proxy = socks5://127.0.0.1:1080
[https]
        proxy = socks5://127.0.0.1:1080
```
这里的意思就是说，在基于http/https协议进行github相关操作的时候，使用socks5代理。

开启代理，进行git clone操作的时候，会发现速度提高不少。  
这里给出我的测试数据，再不配置代理的情况下，下载速度不会超过10KB;配置代理后，下载速度能够达到300KB，提升还是很明显的。

取消代理的方式是：
```
git config --global --unset http.proxy
git config --global --unset https.proxy
```

## 解决git status中文乱码问题
直接在输入指令：
```
git config --global core.quotepath false
```