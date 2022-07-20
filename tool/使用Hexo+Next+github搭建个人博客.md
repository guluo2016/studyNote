Hexo 是一个快速、简洁且高效的博客框架。Hexo使用Markdown解析文章，在几秒内，即可利用靓丽的主题生成静态网页。这些静态资源文件可以托管在github或者其他服务器，形成我们自己的个人博客网站。

next是Hexo框架内的一套主题。

github作为生成的静态资源文件的托管平台。实际上我们通过Hexo也可以实现这些静态资源的托管，但是这样只能发布在本地，如果想通过互联网发布，则需要自己购买服务器，并自行申请域名之类的操作。而github中提供github pages功能，可以免费托管我们发布的内容，另外github pages还会自动为其创建一个域名。

<!--more-->

## hexo框架

### 安装hexo

由于hexo是基于Node.js的框架，因此安装hexo之前，首先需要安装node.js。  
node.js和hexo之间存在版本要求，具体如下所示。

![image-20220711173853678](https://github.com/guluo2016/picture/raw/dev/img/image-20220711173853678.png)

待node.js安装之后，可以通过npm命令去安装hexo。

建议使用如下方式进行hexo安装

```shell
npm install -g hexo-cli
```
安装成功之后，可以通过如下方式验证hexo的效果。

![image-20220714134809507](https://github.com/guluo2016/picture/raw/dev/img/image-20220714134809507.png)

### hexo基本操作

#### 初始化一个hexo项目

```shell
# 初始化一个hexo 博客
hexo init blog_test
```

![image-20220712134610287](https://github.com/guluo2016/picture/raw/dev/img/image-20220712134610287.png)

在生成一个hexo_test文件夹后，hexo会自动创建如下内容：

![image-20220712134828979](https://github.com/guluo2016/picture/raw/dev/img/image-20220712134828979.png)

其中比较重要的是：

- source，文件夹，我们的原始文件内容会存放在这里

- _config.yml，文件，称之为站点配置文件，用于配置一些全局性的配置

- public，文件夹，生成的静态资源文件，会放到public文件夹下，默认按照时间进行分类（初始化时，未创建，在执行完下面的hexo g之后，会自动生成）

#### 生成静态资源

```shell
# 一键生成静态资源
hexo g
```

![image-20220712135315014](https://github.com/guluo2016/picture/raw/dev/img/image-20220712135315014.png)

上面的命令会自动生成静态资源文件，并将source下的markdown文件生成为html文件，存放在public文件中，如图所示。

![image-20220712135737455](https://github.com/guluo2016/picture/raw/dev/img/image-20220712135737455.png)



#### 启动服务器，发布

```shell
# 启动hexo服务，用于在本地浏览器查看hexo生成的网页内容
hexo s
```

![image-20220712140942030](https://github.com/guluo2016/picture/raw/dev/img/image-20220712140942030.png)

然后打开浏览器，输入http://localhost:4000/就可以访问博客了。

![image-20220712141114021](https://github.com/guluo2016/picture/raw/dev/img/image-20220712141114021.png)

## next主题

hexo默认的主题，不是太好看，使用比较多的hexo主题是next。

### 安装next主题

切换到hexo项目目录，会有一个theme文件夹，用于存放各种主题，hexo默认是没有安装next主题的，我们需要通过git clone从github上将next主题clone到theme文件夹中。

```shell
git clone https://github.com/iissnan/hexo-theme-next themes/next
```

同时，修改hexo项目的站点配置文件内容

```shell
# 将主题修改为next
theme: next

# 修改语言，由于next中语言包中对应的中文简体为zh-Hans,因此进行如下修改
language: zh-Hans

# title用于标明网站的名字
title: guluo

# author
author: 孤落
```

接下来执行如下命令进行重新发布。

```shell
# clean之后重新生成静态文件，然后发布
hexo clean && hexo g && hexo s
```

此时从浏览器访问，可能会出现如下错误，原因是hexo在5.0之后把swig给删除了需要自己手动安装。

![image-20220712141716057](https://github.com/guluo2016/picture/raw/dev/img/image-20220712141716057.png)

此时在项目中安装swig可以解决问题：` npm i hexo-renderer-swig`，再次重新发布后，登录博客页面。

![image-20220712143133581](https://github.com/guluo2016/picture/raw/dev/img/image-20220712143133581.png)

![image-20220712143043445](https://github.com/guluo2016/picture/raw/dev/img/image-20220712143043445.png)

从博客页面上来看，对站点配置文件的修改配置也生效了


### 配置next

next主题下同样有一个_config.yml文件，称之为主题配置文件。通过修改主题配置文件，可以进行一些自定义配置。

- 更改next的scheme。

next提供四种scheme，这里我选择的是：`scheme: Gemini`，修改完配置文件，保存并刷新浏览器，可以查看修改后的效果。

![image-20220712143620514](https://github.com/guluo2016/picture/raw/dev/img/image-20220712143620514.png)

- 设置博客头像

```shell
# 配置用户头像
avatar: https://github.com/guluo2016/picture/raw/dev/img/guluo.jpg

# 用户头像下的名字
author: 孤落

# 用户头像名字下的说明
description: 大漠孤烟直，长河落日圆
```

修改并保存好主题配置文件后，刷新浏览器，可查看效果。

![image-20220712143917357](https://github.com/guluo2016/picture/raw/dev/img/image-20220712143917357.png)

- 将博客头像设置为圆形

方形的用户头像不太好看，可以通过如下修改，将头像修改为圆形的。

切换至`next\source\css_common\components\sidebar`目录下，将sidebar-author.styl中的内容替换为如下内容。

```shell
.site-author-image {
  margin: 0 auto;
  padding: $site-author-image-padding;
  max-width: $site-author-image-width;
  height: $site-author-image-height;
  border: $site-author-image-border-width solid $site-author-image-border-color;

  border-radius: 50%;
  -webkit-border-radius: 50%;
  -moz-border-radius: 50%;
}

.site-author-image:hover {
    -webkit-transform: rotate(360deg);
    -moz-transform: rotate(360deg);
    -ms-transform: rotate(360deg);
    -transform: rotate(360deg);
}

.site-author-name {
  margin: $site-author-name-margin;
  text-align: $site-author-name-align;
  color: $site-author-name-color;
  font-weight: $site-author-name-weight;
}

.site-description {
  margin-top: $site-description-margin-top;
  text-align: $site-description-align;
  font-size: $site-description-font-size;
  color: $site-description-color;
}
```

保存，并刷新浏览器查看效果。

![image-20220712144235301](https://github.com/guluo2016/picture/raw/dev/img/image-20220712144235301.png)

## 博客个性化配置


### 为博客增加标签、分类页

在hexo项目的根目录下，执行如下命令，进行创建：

```shell
# 创建分类页
hexo new page categories 

# 创建标签页
hexo new page tags
```

执行上面的命令后，hexo会在post下自动创建目录，如图所示。

![image-20220712170844909](https://github.com/guluo2016/picture/raw/dev/img/image-20220712170844909.png)

同时更新next主题配置文件,注意要去掉||前面的空格，否则点击页面会跳转失败。

```shell
menu:
  home: /|| home
  tags: /tags/|| tags
  categories: /categories/|| th
  archives: /archives/|| archive
```

保存配置，并刷新浏览器，查看效果。

![image-20220714103032946](https://github.com/guluo2016/picture/raw/dev/img/image-20220714103032946.png)

### 增加站内搜索功能

要实现博客的站内搜索功能，需要借助于插件`hexo-generator-searchdb`，因此在hexo项目下，安装该插件：  
```shell
npm install hexo-generator-searchdb --save
```

修改站点配置文件，增加如下内容：

```yaml
search:
  path: search.xml
  field: post
  format: html
  limit: 10000
```

然后再更新next主题配置文件：

```yaml
local_search:
  enable: true    #将此设为true
  # if auto, trigger search by changing input
  # if manual, trigger search by pressing enter key or search button
  trigger: auto
  # show top n results per article, show all results by setting to -1
  top_n_per_article: 1
```

保存，并重启hexo，打开浏览器，查看效果。

![image-20220714141357379](https://github.com/guluo2016/picture/raw/dev/img/image-20220714141357379.png)

![image-20220714141451682](https://github.com/guluo2016/picture/raw/dev/img/image-20220714141451682.png)

### 设置博客文章展示部分

在hexo的source目录下的博客源markdown文件中，合适的位置增加一样md语法，即可实现。

![image-20220714103321987](https://github.com/guluo2016/picture/raw/dev/img/image-20220714103321987.png)

在浏览器中的显示效果如图所示。

![image-20220714103449990](https://github.com/guluo2016/picture/raw/dev/img/image-20220714103449990.png)

## 将hexo项目部署到github page

首先得在github上创建一个仓库，仓库名字是`{github昵称}.github.io`。然后查看该仓库的settings，并选择pages页面，可以查看到网址，我们通过该网址可以直接访问该仓库中的静态html资源。

![image-20220714104338520](https://github.com/guluo2016/picture/raw/dev/img/image-20220714104338520.png)

目前还访问不了，原因是这个仓库中没有任何文件，我们需要将前面hexo生成的静态资源上传至该仓库。

为了能够将数据上传至该仓库，我们需要再hexo的站点配置文件中增加有关github的配置。

```yaml
# 这里有个前提，就是本机已经配置了有关github的认证信息
deploy:
    type: git
    repository: https://github.com/guluo2016/guluo2016.github.io.git
    branch: main
```

在hexo项目下执行如下命令，安装hexo的git工具。

```shell
npm install hexo-deployer-git --save
```

接着执行如下命令，完成在github上的部署。

```shell
# 清空缓存
hexo clean 

# 生成静态资源
hexo g

# 部署至github
hexo d
```

接着，就可以登录前面所述的github pages页面的网址，查看博客网站了。

## 设置评论功能模块

这里采用gitalk插件，来实现自建博客的评论功能。

他实际上就是借助于github仓库提供的issue功能来实现的评论功能，如果我们增加了gitalk插件，那么他会为博客中的所有文章在指定仓库的issue上创建一个以该博客文章名命名的问题，后面所有任何关于该博客文章的评论都会记录在这个issue下。

同时当我们打开这个博客文章时，gitalk会自动从issue中加载数据，将关于这个博客的评论展示在评论区。

为了实现上述功能，需要进行如下操作。

### 申请OAuth 认证

登录github，在个人账户settings下，选择 `Developer settings` -- `OAuth Apps`,进行OAuth认证。

![image-20220714110420653](https://github.com/guluo2016/picture/raw/dev/img/image-20220714110420653.png)

注意homepageurl和callback url都填写前面的github page网址。

接着通过如下方式，获取到client id和ClientSecret，后面会用到。

![image-20220714110622403](https://github.com/guluo2016/picture/raw/dev/img/image-20220714110622403.png)

### 在next主题配置文件中配置gitalk

```yaml
gitalk:
  enable: true
  githubID: guluo2016
  repo: guluo2016.github.io  #指定存放评论的仓库名，评论存放在仓库的issue上，因此仓库必须开启issue功能才行
  ClientID: {clientid}
  ClientSecret: {ClientSecret}
  adminUser: guluo2016 #指定可初始化评论账户
  distractionFreeMode: true
```

### 增加gitalk相关内容

在`netx\layout\_third-party\comments`目录下，新建gitalk.swig文件，并添加如下内容

```shell
{% if page.comments && theme.gitalk.enable %}
  <link rel="stylesheet" href="https://unpkg.com/gitalk/dist/gitalk.css">
  <script src="/js/src/md5.min.js"></script>
  <script src="https://unpkg.com/gitalk/dist/gitalk.min.js"></script>
   <script type="text/javascript">
        var gitalk = new Gitalk({
          clientID: '{{ theme.gitalk.ClientID }}',
          clientSecret: '{{ theme.gitalk.ClientSecret }}',
          repo: '{{ theme.gitalk.repo }}',
          owner: '{{ theme.gitalk.githubID }}',
          admin: ['{{ theme.gitalk.adminUser }}'],
          id: md5(location.pathname),
          distractionFreeMode: '{{ theme.gitalk.distractionFreeMode }}'
        })
        gitalk.render('gitalk-container')
       </script>
{% endif %}
```

*这里需要说明一下，这里引入了md5.min.js文件，并对博客的pathname进行MD5处理，原因是由于github限制，不能创建超过50字符长度的issue？？？反正就是长度太长就是创建不了。*

[md5.min.js文件可以在github上下载](https://github.com/blueimp/JavaScript-MD5/tree/master/js)，下载后放到`next\source\js\src`目录下即可。

在next主题的`\layout\_third-party\comments`目录中，更新index.swig文件，在文件末尾增加一行。

```shell
{% include 'gitalk.swig' %}
```

在next主题的`\layout\_partials`目录中，更新comments.swig文件，如下增加gitalk部分即可。

```js
  {% elseif theme.valine.appid and theme.valine.appkey %}
    <div class="comments" id="comments">
    </div>
  
  {% elseif theme.gitalk.enable %}
    <div id="gitalk-container"></div>
```

待所有内容修改完毕之后，保存并执行如下命令，进行发布。

```shell
hexo clean && hexo g && hexo d
```

然后登陆github pages网页查看效果。

![image-20220714113512240](https://github.com/guluo2016/picture/raw/dev/img/image-20220714113512240.png)