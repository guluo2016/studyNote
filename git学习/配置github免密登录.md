## Windows上配置github免密clone

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


## 解决git status中文乱码问题
直接在输入指令：
```
git config --global core.quotepath false
```