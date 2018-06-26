## join on 多条件失效问题
join on通常用在对多个表进行连接查询，最常见的是left join on和right join on
- left join on 以左表为基准，不符合条件的右表行均为null
- right join on 以右表为基准，不符合条件的左表行均为null

**现在存在问题就是当on后边跟多个条件时，往往表现为除第一个条件外，其他条件失效的现象**

实际上是我们的意思没有表达清楚，并且没有理解on与where后面加条件句的区别

如现在有两张表A(id,name) 和 B(id,dept,address)
当进行连接查询是：
`select * from A left join B on A.id = B.id;`该查询语句是没有任何问题的，但是下面语句可能存在问题：
`select * from A left join B on A.id = B.id and A.name = '令狐冲'`会查出不是我们需要的结果，这个时候就要想想你你到底向查什么？
- 从连接表中查询指定A.name = ‘令狐冲’的行
- 根据条件A.id = B.id和A.name = '令狐冲'，来匹配两表中满足条件的行

如果是第二种，恭喜你，你将获得正确结果，然而第一种，你将不能获得正确结果，原因在于，on 后面的条件（不管是一个还是多个）都是作为筛选两表中满足条件的行，并不是在条件1的情况下进行二次筛选，三次筛选，正确的做法就是：
`select * from A left join B on A.id = B.id where A.name = '令狐冲'`
该查询语句首先进行左连接查询，然后在查询结果基础上根据where条件进行二次筛选，最终得出满足条件的结果。


## ifnull()函数
`select ifnull(s1,s2)`
上面所表示的意思是：如果s1不为null,显示s1的结果，如果为null，则显示s2的结果
**然而MySQL中的ifnull()函数，oracle中并没有同名函数，如果想用的话，可以使用oracle中国的nvl()函数，和ifnull()函数表示的意思一样**

## 以关键字做字段名
在oracle中如果以data,char等类型声明关键字为字段，会报错(我在pl/sql上操作)
如：
`select create_time as data from table1` //会出错，不能以data为字段名
*同时char也不可以做为字段名，但是比较奇怪的是，我测试int 做字段名竟然不报错*
如果非想使用这些关键字做字段名，可以使用双引号将关键字包起来就行了，注意，单引号不行

同样的问题在mysql中并不会出现，我测试了一下，在建表的时候可以使用关键字（date，int，char）作为字段名，并不会报错
