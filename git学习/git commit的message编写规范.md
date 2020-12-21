## Commit message 的作用

格式化的Commit message，有几个好处。

**（1）提供更多的历史信息，方便快速浏览。**

比如，下面的命令显示上次发布后的变动，每个commit占据一行。你只看行首，就知道某次 commit 的目的。

> ```bash
> $ git log <last tag> HEAD --pretty=format:%s
> ```



![img](http://www.ruanyifeng.com/blogimg/asset/2016/bg2016010604.png)

**（2）可以过滤某些commit（比如文档改动），便于快速查找信息。**

比如，下面的命令仅仅显示本次发布新增加的功能。

> ```bash
> $ git log <last release> HEAD --grep feature
> ```

**（3）可以直接从commit生成Change log。**

Change Log 是发布新版本时，用来说明与上一个版本差异的文档，详见后文。

![img](http://www.ruanyifeng.com/blogimg/asset/2016/bg2016010603.png)