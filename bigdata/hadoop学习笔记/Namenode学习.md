## 1 概述
HDFS是一个主从架构，其核心就是Namenode，Namenode主要作用是存储整个集群的元数据信息，包括存储文件的详细信息、每个文件的Block及副本在Datanode上的位置；Namnode还被用于协调客户端对文件的访问，记录文件的改动，以及客户端对文件的操作历史。为了节约资源，Namenode不记录客户端对HDFS中文件的查询操作。

Namenode作为HDFS中的Master，是整个系统的中枢。这就使得他必须能够及时响应各种需求，因此它里面存储的数据基本上都是存放在内存中的。但是为了保证Namenode在重启之后内存数据不丢失,Namenode实际上又在磁盘中维护了两个文件：edits.log和fsimage。

## 2 Namenode的启动流程
当Namenode启动的时候，会首先去指定目录下，读取两个文件edits.log和fsimage。这两个文件的作用：  

- fsimage:上一次Namenode的内存快照
- edits.log:记录用户对HDFS上的文件的写操作

通过对这两个文件的解析，在根据这两个文件的就可以吧Namenode还原到上次停止服务前的内存状态，从而保证Namenode中存储数据的可靠性。原理还是比较简单的。

fsimage实际上就是对Namenode的一次内存快照，在Namenode运行过程中，每隔一段时间，就会对Namenode的内存打一次快照。我们知道，如果仅仅依靠这个快照，只能保障Namenode在重启后，恢复到历史中的某一时刻，在这之后的数据并不能恢复。因此为了解决这个问题，Namenode又维护了一个edits.log文件，每打一次快照之后，Namenode就会新建一个edits.log,用于记录在这之后，用户对HDFS中的写操作。这样，根据这两个文件，就可以保证Namenode里的数据不丢失。


## 3 Secondary Namenode
刚开始的时候还以为是Namenode的备份，但是了解之后才发现Secondary Namenode根本不是Namenode的备份，更多的可以看做是它的助手。   

为了保证Namenode的数据可靠性，Namenode维护了两个文件：edits.log和fsimage。当打一次快照后，在这之后的对HDFS的写操作都会被记录到edits.log中。当在下一次快照的这个时间间隔中，写操作非常频繁时，就会导致edits.log非常大，这就会存在如下几个问题： 

- 如果此时Namenode需要重启，那么就会需要非常多的时间去读取edits.log文件
- edits.log文件非常大，存储起来也不方便
- edits.log中的数据越多，就代表着快照fsimage越旧，那么此时edits.log文件损坏，就会丢失更多的数据。

为了解决以上的问题，Hadoop设计团队提出了Secondary Namenode，用于辅助Namenode，来管理edits.log和fsimage，其主要任务就是定期地将edits.log和fsimage合并，形成一个新的fsimage文件，使得快照更新的更新的位置，从而防止edits.log文件过大带来一系列负面影响，这个过程可以叫做checkpoint。


Secondary Namenode的工作流程：

- Secondary Namenode会询问Namenode是否需要checkpoint，并将获取的结果返回给Secondary Namenode。是否需要checkpoint的条件是：时间到或者edits.log文件大小达到一定程度
- 如果需要checkpoint的话，Secondary Namenode会请求Namenode执行checkpoint操作，此时Namenode会首先生成一个新的日志文件edits.new，用于记录之后的写操作，这称之为滚动编辑日志；Secondary Namenode会把滚动前的edits.log文件和fsimage一同通过HTTP拿到Secondary Namenode所在节点
- Secondary Namenode读取edits.log和fsimage文件，并将这两个文件合并成一个新的文件，名字叫fsimage.ckpt,这实际上是一个镜像文件，但是比fsimage要更新
- Secondary Namenode通过HTTP POST方式，将fsimage.ckpt,传回到Namenode节点
- Namenode收到fsimage.ckpt快照文件后，会进行重命名操作，将fsimage.ckpt和edits.new文件分别重命名为fsimage和edits.log

前面提到的Secondary Namenode会定期进行一次checkpoint，其时间可以在hdfs-site.xml中设定,默认是一小时进行一次：
```
<property>
    <name>dfs.namenode.checkpoint.period</name>
    <value>3600</value>
</property>
```
