### HBase中的meta表

meta表的命名空间是hbase，因此其全称为hbase:meta，它的信息是不显示在hbase的Master UI中的，但是在hbase shell中的可以通过`scan 'hbase:meta'`来查看meta表中的信息。

meta表的表结构是：

![hbase META表结构](https://github.com/guluo2016/picture/raw/dev/img/hbase%20META%E8%A1%A8%E7%BB%93%E6%9E%84.png) 

meta表内容示例是：

![meta表内容示例](https://github.com/guluo2016/picture/raw/dev/img/meta%E8%A1%A8%E5%86%85%E5%AE%B9%E7%A4%BA%E4%BE%8B.png) 

从这个内容中也可以看出来，rowkey是由（表名，region信息[以startkey表示]，创建的时间戳.分区的uuid）组成。接下来展示的就是[(列族:列名，时间戳)，再接下来就是(value值)] 这个可能有多个。



用户去新版的hbase中查询数据过程就是：

1. 从zookeeper中读取数据，默认情况下是去`/hbase`节点中读取数据。如果不是该节点的话，可以通过配置`zookeeper.znode.parent`去指定。
2. 从zookeeper中的`/hbase/meta-region-server`中获取到meta表的regionserver信息
3. 用户去对应的regionserver中去读取region数据，并缓存下来，从而获取到要查找的表的一些信息，包括info:region信息（要查找的表都在那些region上、每个region的startkey和endkey是多少）；info:sn信息，这个列包含的就是regionserver的信息
4. 用后在根据查找的RowKey，找到对应的region信息，并且去对应的regionserver中去取既可获取目标数据



