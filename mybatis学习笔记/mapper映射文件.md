**Mybatis映射文件**

[TOC]

## 1 select
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

## 2 动态sql

if和标签内的test属性合用，test属性表示的是一个条件，如果条件为真的时候，采取执行if标签体。
if往往表达的是一种非此即彼的关系，但是有时候，情况往往会比这更加复杂，如：
- A为空的时候执行语句1
- A为空且B为空的时候执行执行语句2

这个时候如果还用if的话，就不行了，因为并没有else标签可用
这个时候可以选择使用choose,when,otherwise语句，实际上就是if-else的变体
```
where 
<choose>
	<when test="条件1">
    	sql语句1
    </when>
    <when test="条件2">
    	sql语句2
    </when>
    <otherwise>
    	sql语句3
    </otherwise>
</choose>
```
但是这个时候又会遇到一个问题，如果条件内的sql语句里面开头是and，or等sql关键字话，where后面又什么都不加话，当有一个条件满足的时候就会变成：
```
where and sql语句   //错误的sql
```
为什么会有这种需求呢？很简单，当where后面的条件可能是一个也可能是多个的时候，就需要and，or来连接，但是并不知道那个条件会被执行，因此就会出现上面所说的情况

mybatis给出了解决办法，使用where，trim标签
```
<select id="findActiveBlogLike"
     resultType="Blog">
  SELECT * FROM BLOG 
  <where> 
    <if test="state != null">
         state = #{state}
    </if> 
    <if test="title != null">
        AND title like #{title}
    </if>
    <if test="author != null and author.name != null">
        AND author_name like #{author.name}
    </if>
  </where>
</select>
```
- where 元素只会在至少有一个子元素的条件返回 SQL 子句的情况下才去插入“WHERE”子句。而且，若语句的开头为“AND”或“OR”，where 元素也会将它们去除。

```
<trim prefix="A" perfixOverrides="old_A" suffix="B" suffixOverride="old_B" >
	sql
</trim>
```
上面代码的意思就是说，把标签体里面的sql中开头出现的old_A替换成A，sql中结尾出现的old_B替换成B

还没有用到，用到的时候在说说用的体验

set
```
<update id="updateAuthorIfNecessary">
  update Author
    <set>
      <if test="username != null">username=#{username},</if>
      <if test="password != null">password=#{password},</if>
      <if test="email != null">email=#{email},</if>
      <if test="bio != null">bio=#{bio}</if>
    </set>
  where id=#{id}
</update>
```
set标签会自动把无关的d逗号删除掉

