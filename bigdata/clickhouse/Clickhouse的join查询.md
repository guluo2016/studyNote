Clickhouse的分布式join查询，涉及到的表总的来说有两类。   

- 分布式表与分布式表的join查询    
- 分布式表与本地表的join查询    

clickhouse分布式join查询有`join`和`global join`之分，clickhouse在执行这两种join的流程是不一样的。

### 1 join查询
#### 1.1 查询流程
单纯的join查询，如下所示。
```sql
select A.name, B.address from A join B on A.id = B.id
```
当用户连接clickhouse集群节点（将该节点认为是协调节点），并输入上述查询命令，clickhouse对该sql的处理逻辑如下：

- **左表是本地表，右表是分布式表**

1. 协调节点解析Sql，由于左表是本地表，不触发分布式查询，针对右表（分布式表），触发分布式查询， 针对右表转换为本地表查询（S1），并下发至clickhouse集群各节点（右表是分布式表）
2. clickhouse集群各节点收到S1之后，发现涉及到的查询表均为本地表，则直接执行查询命令，并返回查询结果
3. 协调节点汇总各个节点的查询结果，并返回给用户

- **左表是分布式表，右表是本地表**

1. 协调节点解析sql，发现左表是分布式表，触发分布式查询，将原sql中的左表转换为本地表查询(S1),并下发至clickhouse集群各个节点
2. Clickhouse集群各个节点收到S1后，发现涉及到的查询表均为本地表，则直接执行查询命令，并返回查询结果
3. 协调节点汇总各个节点的查询结果，并返回给用户

- **左右表均是分布式表**

1. 协调节点解析sql，由于左表是分布式表，因此触发分布式查询，将左表转换为本地表查询(S1)，并下发至clickhouse集群各个节点
2. clickhouse的每一个节点(I')收到S1命令后，直接执行该查询命令并返回结果，跳转至步骤6（右表为本地表））；或者继续执行步骤3,解析S1（右表为分布式表）
3. 针对右表,将其转换为本地表查询(S2),并下发至每个节点执行
4. clickhouse每一个节点(I'')收到S2之后，发现涉及到的查询表均为本地表，直接执行该命令并返回结果
5. I'节点汇总结果I''的返回结果（subquery_set），将其放到I'节点内存中，与本地左表进行联合查询，并返回结果，执行步骤6
6. I节点汇总I'节点的查询结果，并返回给用户

下面进行示例说明。
##### 1.1.1 本地表与分布式表的联合查询
假如参与联合查询的表是一张本地表和一张分布式表，如下所示。
```sql
select A.name, B.address from A_local A join B on A.id = B.id
```

1. 协调节点发现join左表为本地表；因此会执行针对右表B的查询，发现右表是分布式表，因此将其重写为本地表查询(将重写后的Sql设定为S1)
    ```sql
    select B.id, B.address from B_local B
    ```
2. 协调节点将S1分发到Clickhouse集群的每个节点上
3. Clickhouse集群的每个节点收到协调节点发送过来的查询命令后，会在本节点执行本地查询命令，获取到本地查询结果并返回给协调节点
4. 协调节点汇总各个节点的查询结果形成subquery_set，并放到该节点内存，然后再与左表A进行join查询
    ```sql
    select A.name, B.address from A_local A join subquery_set B on A.id = B.id
    ```
5. 上述sql涉及到的表均为本地表，因此在当前节点直接执行即可，最终将查询结果返回给用户
##### 1.1.2 分布式表与本地表联合查询
假如参与联合查询的表是一张分布式表和一张本地表，如下所示。
```sql
select A.name, B.address from A join B_local B on A.id = B.id
```

1. 协调节点发现join左表分布式表，因此将左表转换为本地表查询(S1),并下发至clickhouse集群各个节点
    ```sql
    select A.name, B.address from A_local A join B_local B on A.id = B.id
    ```
2. clickhouse集群各个节点收到S1后，发现左右表均为本地表，则直接执行查询命令，并返回结果
3. 协调节点汇总各节点的查询结果后，返回给用户

##### 1.1.3 分布式表与分布式表联合查询
假如参与联合查询的表是两张分布式表，如下所示。
```sql
select A.name, B.address from A join B on A.id = B.id
```

1. 协调节点发现join左表时分布式表，会将其重写为本地表查询(将重写后的Sql设定为S1)
    ```sql
    select A.name, B.address from A_local A join B on A.id = B.id
    ```
2. 协调节点将S1分发到Clickhouse集群的每个节点上(I')
3. Clickhouse集群的每个节点收到协调节点发送过来的查询命令后,发现join右表也是分布式表，会再次出发一次对右表的分布式查询
4. Clickhouse的每个节点会基于右表B，将分布式B表查询转换为本地表B的查询(假定为S2),并将其分发到Clickhouse的每个节点上
    ```sql
    select B.id, B.address from B_local B
    ```
5. Clickhouse的每个节点(I'')收到上面的sql查询命令之后，发现查询的是本地表，因此会直接执行查询，并将查询结果返回给I'
6. Clickhouse集群的节点I'收到集群对分布式表B的查询结果后，进行汇总形成数据集放在节点的内存中，假设是subquery_set
7. I'再次对S1 sql进行重写(假定为S3)
    ```sql
    select A.name, B.address from A_local A join subquery_set B on A.id = B.id
    ```
8. I'解析S3，左右表都是本地表，因此直接在本地执行查询，获取到查询结果，并将其返回给协调节点I
9. 协调节点收到所有集群所有节点的查询结果后进行汇总，并返回给用户
#### 1.2 join查询存在的问题

分布式表与本地表的join查询不存在优化问题。

本地表与分布式表的join查询、分布式表与分布式表的join查询存在如下问题：每个节点都要拉取subquery_set全量数据，会占用过多的网络带宽，且如果subquery_set过大会影响查询性能甚至会出错

分布式表与分布式表查询还存在读放大问题，即对右表存在重复查询问题。假定clickhouse有N个节点，那么对分布式表B所对应的本地表进行了`N*N`次查询，S1分发到N个节点上，每个节点又将S2再次分发到N个节点上，那么对本地表B进行了`N*N`次查询    
### 2 `global join`查询
#### 2.1 执行流程
global join查询，如下所示。
```sql
select A.name, B.address from A global join B on A.id = B.id
```
当用户连接clickhouse集群节点（将该节点认为是协调节点），并输入上述查询命令，`global join`的流程如下。

1. 协调节点(I)收到命令之后，发现是`global join`查询，先解析针对右表的sql查询，针对右表构建sql(S1)：`select B.id, B.address from B` 
2. 协调节点执行S1，直接查询并返回结果，执行步骤4（右表是本地表）；协调节点将S1转化为本地表查询(S2):`select B.id, B.address from B_local B`,并分发至所有节点（右表是分布式表）
3. clickhouse集群节点收到S2命令后，执行并返回查询结果
4. 协调节点汇总所有节点的右表查询结果形成结果集(subquery_set),并与左表进行联合查询(S4):`select A.name, B.address from A global join subquery_set B on A.id = B.id`
5. 协调节点执行S4，并返回结果，结束流程（左表是本地表）；协调节点将S4转换为本地表查询(S5):`select A.name, B.address from A_local A global join subquery_set B on A.id = B.id`,并将subquery_set数据集连带S5分发至所有节点
6. clickhouse集群节点收到S5之后，执行执行并返回结果
7. 协调节点汇总结果并返回给用户

下面进行示例说明。
##### 2.1.1 本地表与分布式表的联合查询
其执行流程和`join查询`一样，因此使不使用`global`，其查询效率都是一样的。
##### 2.1.2 分布式表与本地表的联合查询
查询sql如下所示。
```sql
select A.name, B.address from A global join B_local B on A.id = B.id
```

1. clickhouse协调节点发现是`gobal join`查询，会先对右表进行解析查询，发现右表是本地表，因此不触发分布式查询，直接在当前节点上执行针对B本地表的查询(S1),并返回查询结果。
    ```sql
    select B.id, B.address from B_local B
    ```
2. 协调节点收到针对右表的查询结果假设为subquery_set,会写入当前节点内存，并与左表进行联合查询,发现左表是分布表，因此触发分布式查询，将A表转换为本地表(S2)，并下发至clickhouse各节点
    ```sql
    select A.name, B.address from A_local A join subquery_set B on A.id = B.id
    ```
3. clickhouse集群各节点收到S2后，发现左右表均为本地表，因此直接执行命令，并返回结果
4. 协调节点汇总各节点的查询结果，并返回给用户

**这里和`join查询`是有区别的：**

- `join查询`是先将左表转换为本地表，然后下发至各个节点，每个节点执行当前节点上的A_local和B_local的查询
- `global join`是先在当前节点查出来B_local数据(subquery_set)，然后再讲左边转换为本地表，连带subquery_set发下至各个节点，集群节点执行的当前节点上的A_local和subquery_set的联合查询
##### 2.1.3 分布式表与分布式表联合查询
假如参与联合查询的表是两张分布式表，如下所示。
```sql
select A.name, B.address from A global join B on A.id = B.id
```

1. clickhouse协调节点发现是`global join`查询，则会先进行右表查询
2. 协调节点发现右表B是一张分布式表，因此会将对该表的分布式查询转换为本地表查询sql(S1),并分发至clickhouse集群的每个节点上
    ```sql
    select B.id, B.address from B_local B
    ```
3. clickhouse中的每个节点收到S1之后，发现需要查询的表全部是本地表，因此直接执行查询命令，获取查询结果，并返回给协调节点
4. 协调节点汇总所有节点返回的对B表查询的结果，并形成结果subquery_set
5. 协调节点集合subquery_set对A表进行查询，发现A表是分布式表，因此将sql转换为S2，并分发至clickhouse集群的每个节点上
    ```sql
    select A.name, B.address from A_local A join subquery_set B on on A.id = B.id
    ```
6. clickhouse每个节点收到S2时，发现涉及查询的表均为本地表，因此直接执行查询，并将查询结果返回给协调节点
7. 协调节点汇总各节点的查询结果，并返回给用户
#### 2.2 `global join`存在的问题
从上面的流程可以看出，`global join`可以有效避免读放大问题。

但是`global join`也存在一定的问题：

- 如果左表为分布式表，则需要将右表的查询结果作为数据集分发至集群每个节点，会占用过多的带宽资源，甚至如果右表的查询结果过大会出现内存超限、溢写磁盘问题；因此当当右表过大时，`global join`也不一定能够完成查询工作
- 如果左边为分布式表，将右表的查询结果分发至每个节点，存在数据冗余问题，如果减少分发至各个节点的右表查询数据集，将可以减少网络传输的数据量

### 3 `colocate join`查询
#### 3.1 `colocate join`查询原理
`colocate join`的原理就是：**相同的join key必定相同分片**。

对于clickhouse分布式表，分片键(`sharding_key`)确定了用户插入的数据最终插入到哪个分片中，常用的规则有：

- 字段名，该字段必须是Int类型，clickhouse基于分片数，对该字段值取余确定数据所在的分片
- intHash(字段名)， 该字段必须是Int类型，按照字段的散列+取余确定数据所在的分片
- rand(),向分布式表插入一条数据，clickhouse会生成一个随机数，由该随机数+取余确定这条数据所在的分片

因此在设计clickhouse分布式表时，可以将join查询的表按照`join key`进行分片，那么`join key`相同的数据一定会落到同一个节点的分片上，然后再进行join联合查询时，将右表转换为本地表：
```sql
-- 原sql
select A.name, B.address from A global join B on A.id = B.id

-- 右表转换为本地表
select A.name, B.address from A global join B_local B on A.id = B.id
```
注意这里不要使用`global join`，因为使用`global join`会仅仅查询当前节点上的B表分片，而`join`查询会查询每个节点上的B表分片。

`colocate join`查询避免了过多的数据在节点之间进行网络传输，每个节点仅仅执行两个本地表的联合查询即可，协调节点汇总所有节点的查询结果返回给用户即为正确数据。

#### 3.2 `colocate join`查询的不足
`colocate join`查询并不是所有场景都可以使用，需要提前对分布式表按照`join key`进行预分区处理，否则查询出来的结果会不正确。