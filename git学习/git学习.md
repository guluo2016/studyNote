#### 1 分支操作 

- git branch  //查看当前仓库中一共有多少个分支，并显示出来

- git branch 分知名  //创建一个新分支，如果该分支已经存在，则报错

- git branch --set-upstream-to=origin/{branch} {本地分支} 将本地分支与远程分支branch关联1起来
  例子如下：

  ```shell
  //将本地分支dev与远程分支dev关联起来
  git branch --set-upstream-to=origin/dev dev 
  ```

- git branch -vv //查看本地分支与远程的哪个分支进行关联

  ```shell
  git branch -vv 
  
  * basic  3bad49b [origin/basic] git 配置代理的方式     //与远程basic关联
    master e062af3 [origin/master]   					  //与远程master关联
  ```

- git branch -d 分支名  //删除指定分支
- git checkout 分支名  //切换到指定分支

#### 2 提交/拉取操作

- git add [文件名]  //用于将工作区中的指定文件添加到缓存区中，以备提交，如果没有指定文件名，就是添加所有文件

- git commit -m "messgae"  //将缓存区中的修改信息提交到本地版本库，-m "message" 可以在提交的时候加一些说明信息

- **git远程推送**

  - 当远程仓库中有与之同名的分支时，可以使用`git push origin 分支名`进行远程推送
  - 当要删除远程分支时，可以使用`git push origin --delete 远程分支名`
  - 当远程仓库中没有与之匹配的分支时，使用`git push --set-upstream origin 自定分支名` 进行远程推送，推送完毕之后，并不会自动将本地分支与远程的自定义分支关联上，如果想管理，还需要执行`git branch --set-upstream-to=origin/{branch} {本地分支} `操作
  
- **git clone/git pull**

  - git clone是从远程仓库克隆一个完整的仓库到本地（包含了所有的分支）
  - git pull是从远程仓库中拉取指定分支与当前分支进行合并，如果当前分支的修改没有被提交，使用该指令会覆盖修改，如果修改已经提交，则不会覆盖修改

- **git clone ---depth**

  git clone --depth {数字} *** 当远程仓库是GB大小时，直接clone会非常慢，特别是github，在国内下载本来就很慢，就会经常出现clone失败，这个时候可以在clone的时候加上--depth参数。

  例子：

  ```shell
  1 将自己github上的elasticsearch仓库clone到本地，作为本地仓库
  	git clone https://github.com/guluo2016/elasticsearch.git
  	此时，本地仓库的origin就是自己github上的elasticsearch仓库
  	远程github上的elasticsearch仓库相对于本地仓库而言，就是upstream
  2 执行git remote -v
  	origin  https://github.com/guluo2016/elasticsearch.git (fetch)
  	origin  https://github.com/guluo2016/elasticsearch.git (push)
  	可以发现目前的本地仓库仅仅与origin关联
  3 为了使得本地仓库与upstream关联，执行如下命令
  	git remote add upstream https://github.com/elastic/elasticsearch.git
  4 再次执行git remote -v
  	origin  https://github.com/guluo2016/elasticsearch.git (fetch)
      origin  https://github.com/guluo2016/elasticsearch.git (push)
      upstream        https://github.com/elastic/elasticsearch.git (fetch)
      upstream        https://github.com/elastic/elasticsearch.git (push)
      可以发现本地仓库与origin和upstream产生了关联
      默认情况下，git push/pull都是与origin交互，如果本地仓库想与upstream交互，需要显示指明upstream
  5 从upstream中的master分支拉取最新代码，合并到本地仓库的master分支
  	git checkout master
  	git pull upstream master
  6 如果想取消与upstream的关联，可以执行如下命令
  	 git remote remove upstream
  ```

  参考文档：

  [使用 git upstream 从其他远程仓库同步分支](http://jalan.space/2019/05/28/2019/git-upstream/)

#### 3 关联操作

- git remote与远程仓库产生关联，当我们在本地新建一个git仓库，并且想把这个仓库推送到远程服务器上(如github)，这个时候，可以使用该指令。 
  例子：

  ```shell
  // 1 在本地创建一个git仓库
  mkdir git-test
  cd git-test
  git init
  
  // 2 在github上创建一个git仓库
  
  // 3 将本地仓库与github上的仓库关联起来
  git remote add origin git@github.com:guluo2016/luceneCodeStudy.git
  
  // 4 同步本地仓库与github仓库
  git fetch 
  
  // 5 推送本地修改到github上指定分支，如果github上不存在该分支，在推送过程中会创建一个新分支
  git push -u origin test
  ```

#### 4 merge操作

- git merge 分支名   //用于把指定分支合并到当前所在分支上
	在进行merge的时候，可能会会出现冲突，这个时候merge是没有完成的；这个是时候需要修改冲突文件，并再次提交修改，此时merge才算是完成  
	
	例子：
	
	```shell
	branch:test1 test2
	将test1中的修改merge到test2分支
	
	//将当前分支置位test2
	git checkout test2
	//merge
	git merge test1
	//在merge的时候，可能会出现冲突：CONFLICT:Merge conflict in XXX
	//此时，可以使用git status发现哪些文件存在conflict
	git status
	//对存在conflict的文件进行修改，重新提交
	git add .
	git commit -m "修改冲突"
	
	//merge 完成
	```
	
- git merge单一一个文件 `git checkout -p branchName fileName`
  通过git merge是将某一个分支，整体合入当前分支。有时候，我们不需要合入整个分支，而是只将某一个文件的修改合入到当前分支，那么可以采用如下方式进行

  例子：

  ```shell
  # -p 即--patch, branchName即要将哪个分支的文件合入，分支可以是本地分支，也可是远程分支(origin/branchName)， fileName即要合入的文件名字  
  git checkout -p branchName fileName
```


#### 5 git log 

主要是用于查看分支的提交情况。

- git log 查看当前分支的提交记录
- git log 分支1 ^分支2 查看分支1有的，而分支2没有的提交记录
- git log 分支1..分支2 查看分支2比分支1多提交的情况
- git log 分支1 ... 分支2 查看分支1和分支2各自提交的情况
- git log --left-right 分支1 ... 分支2 查看分支1和分支2各自提交的情况，并且以左箭头和右箭头区分

#### 6 git diff

- git diff 分支(test)  

	与test分支比较，当前所在分支增加了什么内容，减少了什么内容。增加的用+号表示，减少的用-好表示
	
	例子：
	
	```shell
	git diff dev
	diff --git a/readme b/readme
	index 773c218..11d045a 100644
	--- a/readme
	+++ b/readme       //当前分支与dev分支比较，存在不同内容的文件是哪个
	@@ -1 +1 @@
	-hello git  you are my lover      //相比于dev分支，当前分支中的readme删除了-号所表示的内容，增加了+号所表示的内容
	+hello git   my name is guluo
	```

#### 7 版本回退

当commit之后，觉得不对，可以进行版本回退。

为了进行版本回退，我们首先需要知道commit id，使用git  log.

```shell
git log

##获取结果
commit 3dcd20b563f9e4df649eaa9f3f91068959e5b617
Author: guluo <guluo@gamil.com>
Date:   Tue May 26 20:26:18 2020 +0800

    HBase整体架构原理讲解文章，这边博文非常好，HBase架构讲解的非常清楚

commit 063e09c1028135e476c86e5482641104cdc65650
Author: guluo <guluo@gamil.com>
Date:   Tue May 26 10:33:51 2020 +0800

    HBase Memstore基本原理学习
    
#这个时候，发现，最新的一次提交，存在一点问题，那么就可以进行回退
#回退到上一次提交，可以使用HEAD^,HEAD表示当前版本，HEAD^表示上一个版本，HEAD^^上上版本，一次类推
git reset --hard HEAD^
#或者
git reset --soft HEAD^
```

`git reset`常用的参数是`--hard`和`--soft`，两者的区别：

`--hard`:回退版本，且不保留这次版本的修改在工作区

`--soft`:回退版本，但是保留这次版本的修改在工作区

#### 8 github上clone一个仓库之后，如何保持最新代码一致

在github上看到一个好的项目如elasticsearch，将其fork为自己的仓库，那么如何保持自己的elasticsearch代码与远程elasticsearch仓库的代码保持一致呢？可以采取如下办法：

```shell
1 将自己github上的elasticsearch仓库clone到本地，作为本地仓库
	git clone https://github.com/guluo2016/elasticsearch.git
	此时，本地仓库的origin就是自己github上的elasticsearch仓库
	远程github上的elasticsearch仓库相对于本地仓库而言，就是upstream
2 执行git remote -v
	origin  https://github.com/guluo2016/elasticsearch.git (fetch)
	origin  https://github.com/guluo2016/elasticsearch.git (push)
	可以发现目前的本地仓库仅仅与origin关联
3 为了使得本地仓库与upstream关联，执行如下命令
	git remote add upstream https://github.com/elastic/elasticsearch.git
4 再次执行git remote -v
	origin  https://github.com/guluo2016/elasticsearch.git (fetch)
    origin  https://github.com/guluo2016/elasticsearch.git (push)
    upstream        https://github.com/elastic/elasticsearch.git (fetch)
    upstream        https://github.com/elastic/elasticsearch.git (push)
    可以发现本地仓库与origin和upstream产生了关联
    默认情况下，git push/pull都是与origin交互，如果本地仓库想与upstream交互，需要显示指明upstream
5 从upstream中的master分支拉取最新代码，合并到本地仓库的master分支
	git checkout master
	git pull upstream master
6 如果想取消与upstream的关联，可以执行如下命令
	 git remote remove upstream
```

参考文档：

[使用 git upstream 从其他远程仓库同步分支](http://jalan.space/2019/05/28/2019/git-upstream/)

#### Problem

1. 在github上配置了ssh，但是在Windows上进行远程push时，会出现如下问题： 
```
Fatal: HttpRequestException encountered.
Username for 'https://github.com':
```
解决办法：  
去这里`https://github.com/microsoft/Git-Credential-Manager-for-Windows`下载`GCMW-1.19.0.exe`到本地，并且运行即可解决该问题。

