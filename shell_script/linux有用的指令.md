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

参考：[批量修改dos文件到unix](https://www.cnblogs.com/qiumingcheng/p/6519622.html)