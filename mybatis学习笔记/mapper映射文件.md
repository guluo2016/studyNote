**Mybatis映射文件**

[TOC]

### 1 select
查询是数据库中使用最最频繁的操作。
Mybatis中最常见的sql定义方式如下：
```
<select paraType="参数类型全路径名" resultType="返回类型全路径名" >
	sql语句（select ...）
</select>
```
- 在查询的时候需要传过来的参数时，可以使用`#{参数名}`来获取，Mybatis会自动从参数对象中获取同名参数，并将其值赋值sql语句。
- 查询后获得的结果可以是一条记录，也可以是多条记录，如果是后者，则返回一个集合类型，集合中的元素类型为resultType指定的类型
- 插叙结果中的各个字段会根据字段名赋给返回类型中的同名参数。

举个例子：
```
<select paraType="com.test.User" resultType="com.test.Result" >
	select name,dept,city from table1 where name=#{name} and age = #{age}
</select>

//User
public class User{
	private String name;
    private int age;
    ....
}

//Result
public class Result{
	private String name;
    private String dept;
    private String city;
    ...
}

```
那么在执行这条sql语句时候，Mybatis会自动从传入参数（User类型）中获取其属性name和age的值，查询结果得到的值按照字段名与Result属性名对应赋值，每条记录一个Result对象，如果多条，其结果是一个List<Result>集合
