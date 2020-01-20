**1 往本地maven仓库里打入一个可以被引用的jar**   
假如现在自己编译了一个jar包，maven本地仓库和中心仓库中都没有，而又想在项目中通过maven仓库引入这个jar，可以通过maven指令将jar打入到本地仓库中去。  
```
/**
-Dfile指定要导入的jar的位置
-DgroupId指定groupId
-DartifactId指定jar的名字
-Dversion指定版本号
-Dpackaging指定要导入的文件是一个jar包
**/
mvn install:install-file -Dfile=*.jar -DgroupId=com.guluo -DartifactId=test  -Dversion=1.0.1 -Dpackaging=jar
```

****