### HBase入库慢问题分析

通过查看HBase的regionserver日志信心，可以看到，HBase内部频繁的进行flush操作和Compaction操作。

- flush操作

如图所示，regionserver日志中显示在进行flush操作。

![image-20211229135507549](https://github.com/guluo2016/picture/raw/dev/img/image-20211229135507549.png)  

- compaction操作

如图所示，regionserver日志中显示在进行compaction

![image-20211229135339837](https://github.com/guluo2016/picture/raw/dev/img/image-20211229135339837.png)



#### flush操作

hbase中会触发进行flush操作的情况：

1. 用户层面
   - 手动执行flush命令
2. Memstore层面
   - 当单个memstore的大小达到`hbase.hregion.memstore.flush.size`所配置的值，默认值时128M
3. Region层面
   - 当一个region中的所有memstore的总大小，达到`hbase.hregion.memstore.block.multiplier * hbase.hregion.memstore.flush.size ` 时，**阻塞该Region下的所有请求，并进行flush操作**，`hbase.hregion.memstore.block.multiplier`的默认值时4
   - 出现上述情况的现象是：*往其中一个表中写入数据时非常慢，其他表不受影响。此时可以优先考虑这种情况。比较的可能的原因就是，hbase表的列族数设置过多。*
4. RegionServer级别
   - RegionServer会将一部分内存分配给写缓存，写缓存的大小取决于`RS堆内存 * hbase.regionserver.global.memstore.size`， 默认情况下，是将堆内存的40%分配给写缓存
   - 当RS中的所有memstore大小达到写缓存的`hbase.regionserver.global.memstore.size.lower.limit` 时，会触发 MemStore 的刷写。其中 `hbase.regionserver.global.memstore.size.lower.limit` 的默认值为 0.95
   - RegionServer 级别的 Flush 策略是每次找到 RS 中占用内存最大的 Region 对他进行刷写，这个操作是循环进行的，所有memstore的大小低于写内存的95%时，才会停止
   - 达到了 RegionServer 级别的 Flush，那么当前 RegionServer 的所有写操作将会被阻塞，而且这个阻塞可能会持续到分钟级别。(*对于32GB的RS，一般写缓存使用率超过11.4GB的话，就会触发RS级别的flush*)

通过HBase的日志信息可以查看HBase的Flush操作，上图可以确定HBase在频繁的进行Flush。可以通过如下步骤来进行原因分析：

- 用户频繁且大量的写入数据，此时属于正常现象。因为大量频繁地写数据，必然会经常地导致Memstore中的数据量达到阈值，从而触发flush。

- 在用户的写操作不频繁的情况下，仍然频繁Flush。

  > flush日志中会显示flush的哪张表。如果是很多表都有flush日志且很频繁，此时可能是因为memstore太小。
  >
  > 仅仅显示其中一张表频繁flush，则可能是因为改表列族过多，经常触发region级别的flush阈值。

- 用户是否在进行频繁的手动flush操作，此时可以适当减少手动flush操作次数。



用户往HBase某一张特定的表读写数据非常慢，甚至会出现阻塞现象。可能的原因如下。

> hbase表的列族过多 && memstore过小 && memstore.multiplier过小
>
> 解决办法：
>
> 1. 重构HBase表，一般一个HBase表的列族不超过2个
> 2. 增大memstore的size
> 3. 增加memstore.multiplier
>
> 
>
> 另外一种可能： 写缓存达到阈值
>
> 查看HBase UI界面，查看对应表的详细信息，查看每个region对应的memstore size，并预估同一个RS上该表的memstore的总大小
>
> 如果总大小超过 (`RS堆内存 * 0.4 * 0.95` ),则考虑可能的原因是因为达到RS级别的flush，此时会阻塞该RS上的所有请求。
>
> 出现这种情况的原因，经常是因为写操作非常频繁（包括正常地频繁写操作或者热点写操作都可能）
>
> 解决办法：
>
> 1. 增大RS的堆内存
> 2. 调整写缓存的占比
> 3. 如果存在写热点问题，通过调整Rowkey来实现写操作可以均衡到表的每一个region上





#### Compaction操作

compaction分为Mnior Compaction和Major Compaction。对于HBase的Mnior Compaction而言，日志中打印Compaction操作是正常的。但是频繁地进行Compaction操作的话，需要深入探究下原因。

触发Mnior Compaction的因素有：

1. Memstore达到阈值，进行flush

   Memstore达到阈值，进行flush，会在HDFS上生成一个新的HFile，此时HBase会判断当前Store下的HFile文件数量是否达到需要进行compaction的阈值，一旦达到，就会进行Mnior Compaction。这个阈值在HBase1.X中由参数`hbase.hstore.compactionThreshold`控制，在HBase2.x中由参数`hbase.hstore.compaction.min`控制，默认值是3，即一个Store下的HFile文件数量超过3个就会触发Compaction。

2. 用户显式执行flush操作

3. HBase后台线程周期性检查

   HBase的RegionServer会启动一个线程，周期性地检查Store中的HFile文件数量，一旦发现超过定义的阈值，就会进行Compaction。线程的检查周期由参数`hbase.server.thread.wakefrequency * hbase.server.compactchecker.interval.multiplier`控制，前者的默认值为10000ms，后者的默认值为1000，因此线程每隔10000s检查一次，这两个值一般不用动，保持默认即可几乎满足所有需求。

   检查线程在发现上述条件不满足时，会继续进行检查，主要检查是否满足触发Major Compaction的条件。检查方式是查看Store下的HFile文件中的最早更新值是否早于一个配置值，该值是一个区间值，由参数`hbase.hregion.majorcompaction`控制，区间范围为 ：`[x - x*0.2, x + x*0.2]`。一般情况下我们将该参数值设置为0表示禁用，或者设置为一周以上的值，如604800000（一周）。

当HBase的RegionServer中频繁地打印Compaction日志，而且用户感受HBase的读写速度明显变慢时，可以通过如下方式进行分析：

> 1 用户程序是否经常性地进行Flush调用，如果是的话，可以调整代码，不要每次put都进行一次flush操作，可以再写入结束时，进行一次flush。
>
> 2 在写入频繁的场景下，Memstore的size是否设置过小，导致其经常性地达到阈值进行flush操作。如果是的话，可以调整Memstore的大小，参数上面一经说明。
>
> 3 HBase日志中不仅Compaction频繁，而且Flush频繁，可以结合Flush定位思路，一起分析。

