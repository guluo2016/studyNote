**Linux中很有用的工具**

## dos2unix
把Windows上创建的文件，拷贝到Linux机器上，通常会出现文件格式不正确问题，从而导致会出现一些问题，最明显的就是shell脚本，这事因为Windows中的换行符是`\r\n`,而在Linux中，文件换行符是`\n`

- Windows中的文件格式为dos  
- Linux中的文件格式为unix

为了把dos文件转换成unix，可以使用dos2unix工具，不仅可以对单个文件进行转换，还可以批量转换，很好用
```
#单个文件转换
dos2unix fileName

#批量转换
find ./ -type f | xargs dos2unix
```

## sed
sed可以对文件进行编辑，功能非常多，能够满足几乎所有的对文件的操作  

- 1 替换文本内容
```
	#将文本test.txt中的所有old字符串替换成new字符串
	sed -i 's:old:new:g' test.txt

	#通过正则表达式方式替换内容
	#仅仅替换正则表达式2匹配到的内容，正则1/2的内容还保持原样
	sed -Ei 's/(正则表达式1)(正则表达式2)(正则表达式3)/\1AAA\3/g' test.txt
```

- 2 删除匹配行
```
	#将文本中的包含“delete_conent”字符串的行删除掉
	sed -i '/delete_conent/d' test.txt

	##删除匹配行的下一行
	sed -ni 'p;/target_content/n' test.txt
```

- 3 插入
```
	#在匹配行的下一行添加新内容，，，a代表的是after
	sed -i '/target_conent/a\new_add_content' test.txt

	#在匹配行的上一行添加新内容，，，i代表的是in front
	sed -i '/target_content/i\new_add_content' test.txt
```