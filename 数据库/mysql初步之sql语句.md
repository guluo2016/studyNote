## 1 增删改操作
**1 创建数据库**  
`create database database_name;`

**2 创建表**  
`create table table_name (字段)`  

创建表实际上是就是定义表的结构，定义表中的各个字段名以及字段类型（必须）；定义主键，指定存储引擎，指定编码格式，创建索引（非必须），如果没有指定就按照默认，我们可以在mysql配置文件my.cnf(/etc/mysql/my.cnf)中定义默认项；  
例子：
``` 	
craete table t1(
	id int,name char(10),
	address varchar(20),    	
	primary key(id))engine=innodb,charset=gbk;   
```	



**3 查看表结构**      
`show create table table_name \G`或者`desc table_name`

两者的不同支出在于desc语句仅仅列出表结构（字段，字段类型，默认值，主键），前者不仅列出表结构，还显示这张表使用的存储引擎，默认编码格式等等；实际上从这里也可以看出mysql中的存储引擎是针对表而言的，并不是针对数据库而言的


**4 插入数据**  
`insert into table_name (字段) values (要插入的数据)` //可以一次插入多条数据，要插入的数据以逗号分割

**5 修改表中的数据**  
`update table_name set age=25 where name='张三';` //修改满足条件的列数据

**6 删除记录**  
`delete from table_name where 列=条件` //删除满足条件的某一行记录  
`delete from table_name` //删除表中的所有记录，但是保留表结构

**7 删除数据库或表**  
`drop database_name`//删除数据库  
`drop table table_name`//删除表结构操作

**8 alter对表结构进行修改**  
`alter table table_name drop 列名` //删除表中的某一列  
`alter table table_name add 列名 类型` //向表中添加一列  
`alter table table_name change old_列名 new_列名 类型` //对表中的某一列进行修改，既可以修改名字，也可以修改数据类型  
`alter table table_name rename new_table_name` //修改表的名字  

alter非常重要，利用它可以对已经存在的表进行几乎所有涉及结构的修改

## 2 查询操作
select用于对数据库中的某个表进行查询操作，主要语法就是:`select * from table_name 条件`

### 2.1 连接查询
对关系型数据库的查询往往不是针对一个表进行查询，查询的时候可能会涉及到多个表，这个时候，就需要进行连接查询，连接插叙分为内连接和外链接。

**1 内连接**  
内连接查询使用的关键字是join(inner join,两者一样)，内连接就是在涉及多个表查询的时候，只显示满足条件的记录，不满足条件的记录一律不显示  
如创建两个表t1和t2,如下所示：
```
//t1
+------+--------+-------+       
|   id | name   |   age |   
|------+--------+-------|
|    1 | 令狐冲 |    30 |
|    2 | 任盈盈 |    28 |
+------+--------+-------+         
//t2
+--------+--------+
| name   | dept   |
|--------+--------|
| 张三丰 | 武当派 |
| 令狐冲 | 华山   |
+--------+--------+
```
对其进行内连接查询：`select * from t1 inner JOIN t2 on t1.name = t2.name`，显示如下：
```
+------+--------+-------+--------+--------+
|   id | name   |   age | name   | dept   |
|------+--------+-------+--------+--------|
|    1 | 令狐冲 |    30 | 令狐冲 | 华山   |
+------+--------+-------+--------+--------+
```
**2 外连接**

有时候进行多表查询的时候，可能会以其中某一个表为基准，进行数据显示，那么这个时候就需要使用外连接，left join on和right join on,前者以第一个表为基准，后者以第二个表为基准进行显示。

**3 union合并查询**  
union可以把多个select的查询结果合并到一个表中显示

### 2.2 对查询结果进行统计

**1 指定显示多少行记录或是显示指定行记录**  
此时可以使用limit关键字，它可以对查询结果进行限定，指定显示多少航查询结果：

- limit n表示显示前农行
- limit n,m ，n表示偏移量，m表示要显示的记录行数，如显示第5-10行记录，可以使用 limit 4,5

**2 对查询结果按照指定标准进行排序**

此时可以使用order by,可以使得查询结果按照指定的列进行排序，DESC逆序排序和ASC正序排序（默认是正序排序）

```
mysql root@localhost:study> select * from t1 order by age DESC // 逆序显示
+------+--------+-------+
|   id | name   |   age |
|------+--------+-------|
|    1 | 令狐冲 |    30 |
|    2 | 任盈盈 |    28 |
+------+--------+-------+
```

**3 对查询结果进行分组**  
此时可以使用group by关键字，按照某一列进行分组，group by通常总是和count(*)结合使用，就是对每一组的数量进行统计 
having也是和group by联合使用的关键字，用作连接条件，使得我们的查询显示结果更加精简，注意它是先分组，之后再进行的条件筛选

## 3 索引

创建表的时候可以创建索引：
```
craete table t1(
	id int,
	name char(10),
	index [索引名(非必须)] (id)
	)
```
对已有表创建索引：`alter table table_name add index index_name(id)`  
删除索引：`drop index index_name on table_name`  //删除指定表上的指定索引  
显示表上的索引信息：`show index from table_name`