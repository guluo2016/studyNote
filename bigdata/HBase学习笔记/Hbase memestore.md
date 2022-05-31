转载自：[HBase – Memstore Flush深度解析](http://hbasefly.com/2016/03/23/hbase-memstore-flush/)

### 1 Memstore

HBase中，Region是集群节点上的最小数据单元，用户数据表由一个或多个Region组成。在Region中每个ColumnFamily的数据组成一个Store。每个Store由一个Memstore和多个HFile组成，如下如所示：

![region](https://github.com/guluo2016/picture/raw/dev/img/region.png)

HBase是基于**LSM-Tree**模型的，所有的数据更新插入操作都**首先写入Memstore中**（同时会顺序写到日志HLog中），**达到指定大小之后再将这些修改操作批量写入磁盘**，生成一个新的HFile文件，这种设计可以极大地提升HBase的写入性能；另外，HBase为了方便按照RowKey进行检索，**要求HFile中数据都按照RowKey进行排序**，Memstore数据在flush为HFile之前会进行一次排序，将数据有序化。



因此往HBase中写入数据时，并不是立即在HDFS上可见的。HBase会将数据缓存到Memstore中，在一定时机刷新到HDFS中。触发Memstore中数据写入HDFS的条件如下：

**1) Memstore级别的限制**

当Memstore的大小达到了上限值，会触发Memstore的写入操作。这个上限值由参数*`hbase.hregion.memstore.flush.size`*决定，默认值是128MB。

**2) Region级别的限制**

由于一个Region可以管理多个Memstore，且都在同一个节点上，

因此当一个Region管理的Memstore总大小达到一个阈值，也会触发Memstore的写入操作。这个阈值由参数`hbase.hregion.memstore.block.multiplier`和`hbase.hregion.memstore.flush.size`共同控制，当达到两者之积时，就会触发写入操作，默认识2*128=256MB.

**3) Region Server级别的限制**

由于一个Region Server可能管理多个Region，因此当Region Server下的所有Memstore总量达到上限，会触发写入操作。又参数`hbase.regionserver.global.memstore.upperLimit * hbase_heapsize`控制，默认 40%的JVM内存使用量。Flush顺序是按照Memstore由大到小执行，先Flush Memstore最大的Region，再执行次大的，直至总体Memstore内存使用量低于阈值（`hbase.regionserver.global.memstore.lowerLimit * hbase_heapsize`，默认 38%的JVM内存使用量）。

**4) HLog限制**

```java
//todo
```

当一个Region Server中的

**5) HBase定期刷新限制**

HBase默认1小时flush一次，确保Memstore不会长时间没有持久化。为避免所有的MemStore在同一时间都进行flush导致的问题，定期的flush操作有20000左右的随机延时。

**6) 手动执行flush**

用户可以通过shell命令 flush ‘tablename’或者flush ‘region name’分别对一个表或者一个Region进行flush。

### 2 Memstore Flush流程

为了减少flush过程对读写的影响，HBase采用了类似于两阶段提交的方式，将整个flush过程分为三个阶段：

**1)   prepare阶段**

遍历当前Region中的所有Memstore，将Memstore中当前数据集kvset做一个快照snapshot，然后再新建一个新的kvset。后期的所有写入操作都会写入新的kvset中，而整个flush阶段读操作会首先分别遍历kvset和snapshot，如果查找不到再会到HFile中查找。prepare阶段需要加一把updateLock对写请求阻塞，结束之后会释放该锁。因为此阶段没有任何费时操作，因此持锁时间很短

**2) flush阶段**

遍历所有Memstore，将prepare阶段生成的snapshot持久化为临时文件，临时文件会统一放到HDFS文件系统下的目录.tmp中。这个过程因为涉及到磁盘I/O操作，因此相对比较耗时。

**3) commit阶段**

遍历所有的Memstore，将flush阶段生成的临时文件移到指定的ColumnFamily目录下，针对HFile生成对应的storefile和Reader，把storefile添加到HStore的storefiles列表中，最后再清空prepare阶段生成的snapshot。