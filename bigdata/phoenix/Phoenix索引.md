### Phoenix简单介绍

Phoenix是HBase的sql层，基于Phoenix可以通过sql命令操作HBase，降低了学习HBase的成本，同时方便与代码迁移，之前面向关系型数据库的代码，只需要换下数据库的连接及驱动即可。

通过Phoenix创建表，必须制定一个主键，内部实际上会以该主键作为rowkey，在HBase中创建一张表。

在基于Phoenix创建表时，如果没有指定列族的话，会默认自动创建一个名字为0列族。  

同时也可以指定列族，指定列族的时候需要注意，主键列不能指定，否则会报错。

```sql
# 会默认将这三列均放置在列族0下
create table test (id integer, name varchar(10), age integer, constraint my_pk primary key (id));

# 指定列族名
create table test ( "id" integer, "person"."name" varchar(10), "person"."age" integer, constraint my_pk primary key (id));
```

Phoenix最有用功能就是为HBase表创建二级索引。在Phoenix表没有二级索引，我们又没有基于主键进行查询的时候，会进行全表扫描，如下图所示。

![image-20220719194147590](https://github.com/guluo2016/picture/raw/dev/img/image-20220719194147590.png)

但是通过Phoenix创建二级索引，可以避免全表扫描，从而提高检索速度。

### Phoenix二级索引

基于Phoenix可以创建二级索引，二级索引主要由以下几种类型：

#### 全局索引

创建全局索引的命令如下图所示。

![image-20220719195321460](https://github.com/guluo2016/picture/raw/dev/img/image-20220719195321460.png)

创建的全局索引，会在HBase中创建一个真实的表，该索引表的rowkey是原表的索引列和rowkey组合而来的。

**当我们对原表进行select查询时，只有索引列中包含要查询的列时，才会走索引，否则走全表扫描。**

![image-20220719195907177](https://github.com/guluo2016/picture/raw/dev/img/image-20220719195907177.png)

全局索引适合用于读多写少的场景，因为索引表是一个真实存在的表，因此每次的更新都会连带着对全局索引表的更新。

#### 本地索引

创建本地索引的命令如下图所示。  

![image-20220719201051475](C:\Users\l19813\AppData\Roaming\Typora\typora-user-images\image-20220719201051475.png)

本地索引的特点是，不会额外在hbase中创建一张新表，而是在原表中新增一行，用于存储索引数据，如下图所示。

![image-20220719201337293](https://github.com/guluo2016/picture/raw/dev/img/image-20220719201337293.png)

新增的这行数据的rowkey是由原表中的rowkey，索引列组成的。

本地索引适合写多读少的场景，因为索引数据和真实数据都是在同一张表中的。

本地索引的特点就是不管查询的数据索引表中有没有，都会先走索引，如下图所示。

![image-20220719201709014](https://github.com/guluo2016/picture/raw/dev/img/image-20220719201709014.png)

#### 覆盖索引

所谓覆盖索引就是，就是把原数据再索引表中也存储一份，这样仅扫描索引表就可以读取到我们所需要的全部数据，不必再对原表进行扫描，只有从索引表中拿不到的数据，才会去原表中获取，从而提高检索速度。

覆盖索引同样也会在HBase中创建一张真实的表，创建覆盖索引的命令如下，通过`include`关键字，将原表中我们需要的列写入到索引表中。

![image-20220719202149788](https://github.com/guluo2016/picture/raw/dev/img/image-20220719202149788.png)

覆盖索引的特点，只有基于索引列的查询才会走索引，否则全部扫描，另外能从索引中全部数据的话，就不会去原表再次读取数据。

![image-20220719202919611](https://github.com/guluo2016/picture/raw/dev/img/image-20220719202919611.png)

### 删除索引

删除索引命令如下图所示。

![image-20220719200242734](https://github.com/guluo2016/picture/raw/dev/img/image-20220719200242734.png)