*git指令*  

- git merge 分支名   //用于把指定分支合并到当前所在分支上
	在进行merge的时候，可能会会出现冲突，这个时候merge是没有完成的；这个是时候需要修改冲突文件，并再次提交修改，此时merge才算是完成   
	例子：
```
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

- git branch  //查看当前仓库中一共有多少个分支，并显示出来
- git branch 分知名  //创建一个新分支，如果该分支已经存在，则报错
- git add [文件名]  //用于将工作区中的指定文件添加到缓存区中，以备提交，如果没有指定文件名，就是添加所有文件
- git commit -m "messgae"  //将缓存区中的修改信息提交到本地版本库，-m "message" 可以在提交的时候加一些说明信息
- git checkout 分支名  //切换到指定分支
- git branch -d 分支名  //删除指定分支

*git远程推送*
- 当远程仓库中有与之同名的分支时，可以使用`git push origin 分支名`进行远程推送
- 当要删除远程分支时，可以使用`git push origin --delete 远程分支名`
- 当远程仓库中没有与之匹配的分支时，使用`git push --set-upstream origin 自定分支名` 进行远程推送

*git clone/git pull*
- git clone是从远程仓库克隆一个完整的仓库到本地（包含了所有的分支）
- git pull是从远程仓库中拉取指定分支与当前分支进行合并，如果当前分支的修改没有被提交，使用该指令会覆盖修改，如果修改已经提交，则不会覆盖修改


*git log*
git log 主要是用于查看分支的提交情况，
- git log 查看当前分支的提交记录
- git log 分支1 ^分支2 查看分支1有的，而分支2没有的提交记录
- git log 分支1..分支2 查看分支2比分支1多提交的情况
- git log 分支1 ... 分支2 查看分支1和分支2各自提交的情况
- git log --left-right 分支1 ... 分支2 查看分支1和分支2各自提交的情况，并且以左箭头和右箭头区分

*git diff*
- git diff 分支(test)  比较当前分支与指定分支test，以test分支为主，比较test分支相比于当前分支，缺少什么修改，增加了什么修改
