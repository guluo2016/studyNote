
## Mybatis学习笔记 ##
### Mybatis配置文件 ###
#### 1 `<properties>` ####
从外部引入资源文件，如配置文件中的数据库连接信息（账户，密码，地址等）从外部文件引入，此时需要使用`<properties>`预先声明
在`<properties>`标签体中也是可以进行属性声明赋值
对于这些属性的声明与复制也可以在方法中进行参数传递

*需要注意一点：当多个地方对同一个变量都有进行赋值动作，那么按照如下顺序进行读取：*
- 在 properties 元素体内指定的属性首先被读取
- 然后根据 properties 元素中的 resource 属性读取类路径下属性文件或根据 url 属性指定的路径读取属性文件，并覆盖已读取的同名属性。
- 最后读取作为方法参数传递的属性，并覆盖已读取的同名属性。

#### 2 `<typeAliases>` ####
为 Java 类型设置一个别名，有的名字比较长，不利于代码阅读和理解，因此可以为其起一个易记的别名。在Mybatis中别名分为两类，分别是：系统定义别名和自定义别名。*注意在mybatis中别名是不区分大小写的*
mybatis别名的实例是在解析mybatis配置文件的时候生成的，并且长期保存在Configuration对象中，用的时候直接去取就行了。

系统定义别名常用的有：
- int,long,double,float,boolean,等对应Java中的基本数据类型
- string，arraylist(对应与Java中的ArrayList),list，map,hashmap等等常用的引用数据类型

自定义别名的方式：
```
<typeAliases>
	<typeAlias alias = "person" type="com.test.Person" />
</typeAliases>
```