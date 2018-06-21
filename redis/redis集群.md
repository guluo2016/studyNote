<!-- MarkdownTOC -->

- 1 基于Hash Slot的Redis集群
	- 1.1 配置基于Slot的Redis集群
	- 1.2 注意事项
	- 1.3 优缺点
- 2 结合主从架构与Hash Slot的Redis集群
	- 2.1 环境搭建
	- 2.2 测试

<!-- /MarkdownTOC -->


## 1 基于Hash Slot的Redis集群

Redis集群默认是把整个数据库分成16384个slot（*意味着一个集群上最多有16384个节点*），数据库中的所有key通过Hash函数都有唯一对应的一个slot；在Redis集群中，每一个节点都可以处理0到16384个Slot，这样Redis集群给集群中的每一个节点分配若干个Slot，由这些节点负责处理对应Slot，如：一个key-value对（“name”：“guluo”）通过Hash映射到100好slot，Slot由节点1处理，那么该key-value对最终就是由节点1上的redis数据库进行处理。这样的话Redis集群上的多个节点就可以并发执行读写操作，加快效率

当向Redis集群中新添加节点时，可以指定将那些Slot分配给该新节点，然后Redis集群会执行相关命令：

1. 判断这些Slot由那些节点处理，确定属于这些Slot的key-value对
2. 将这些key-value对迁移到新节点上，同时删除原有节点上对应的key-value对

在动态添加节点的时候，Redis无需停止，仍然可以提供服务，在这个过程中，可能存在客户正好要读取需要迁移的key-value对，这个时候，Redis集群采取的步骤是：

1. 首先在原来的节点上找key-value对，如果找不到，进行步骤2
2. 在新节点上找


### 1.1 配置基于Slot的Redis集群

**1 复制**

在单机上测试，分别创建6个文件夹（9001...9006），文件夹名也就是redis节点绑定的端口号

```
/usr/local/redis-cluster$ ls
9001  9002  9003  9004  9005  9006
```
分别往各个文件夹中拷贝redis目录下的src/\*,以及配置文件redis.conf，并在各个文件加下创建一个data目录用于存放rdb文件和aof文件，最终的结果是：

```
/usr/local/redis-cluster/9001$ ls
data  redis.conf  src
```

**2 修改配置文件**

对每个文件夹下的redis.conf文件均修改，修改如下：

```
bind 127.0.0.1  //绑定主机IP，我是在一台机器上测试的，因此全部是127.0.0.1
port 9001  //设定端口号，各个文件夹下的不一样
pidfile /var/run/redis_9001.pid  //与端口号一致
dir /usr/local/redis-cluster/9001/data/   //指定rdb和aof的存放目录
cluster-enabled yes   //开启集群
cluster-config-file nodes-9001.conf  //也是配置文件，目前还不清楚是干什么的
cluster-node-timeout 15000   //集群中的节点必须互联互通，如果消息发送之后15000ms还没有到达，认为该节点已经断开了
```

**3 启动集群**

```
//重点是加载的配置文件
sudo 9001/src/redis-server 9001/redis.conf
sudo 9001/src/redis-server 9002/redis.conf
sudo 9001/src/redis-server 9003/redis.conf
sudo 9001/src/redis-server 9004/redis.conf
sudo 9001/src/redis-server 9005/redis.conf
sudo 9001/src/redis-server 9006/redis.conf   
```

**4 连接redis集群**

任意启动一个redis客户端程序：

`9001/src/redis-cli -p 9005 //注意指端口号，否则连接失败；因为我是在本机，因此ip可以省略，如果连接其他电脑上的，ip不能省`

此时没不能进行redis的读写操作：
```
127.0.0.1:9005> set name guluo
(error) CLUSTERDOWN Hash slot not served 
```
原因：

- 此时虽然启动了6台redis服务器，但是实际上是6个集群，彼此之间互相独立，要想使用必须使得他们互通互联；
- 一个集群上有16384个slot，这些Slot并没有进行分派,因此进行写操作的时候，redis不知道这个key-value对应该交给那个节点处理

基于以上原因，还需要做两件事：互相连接这些节点，给节点分派slot

1. 互联：`cluster meet 127.0.0.1 900*`
2. 分派slot节点

*这里需要说明一下，教程上说，可以客气客户端之后，在客户端上分派Slot，`cluster addslots {0..1000}/0 1 2 3 ... 1000`但是一直出错，我用的是`9001/src/redis-cli -p 9005 cluster addslots {0..2500}`方式进行分派*

**5 成功**

成功之后，在任一客户端下执行cluster nodes，可以看到如下结果：
```
3becfdcb9aebaffc0841b4ab8100709eb7038394 127.0.0.1:9001@19001 master - 0 1529562815000 1 connected 0-2500
360f1f67fbc45ccab1f1c44744d99cf4bbc6e127 127.0.0.1:9006@19006 master - 0 1529562816390 5 connected 12501-16383
b9facdb0456e2d8678c64c0471dd1ce98d4caa17 127.0.0.1:9005@19005 master - 0 1529562815386 0 connected 10001-12500
39bf67d26e1465769b7a2a77c3e1e3924152b2f3 127.0.0.1:9003@19003 myself,master - 0 1529562813000 2 connected 5001-7500
449bf28cf9ad9ddb3665f03d2afafaa12f0f045f 127.0.0.1:9002@19002 master - 0 1529562817393 3 connected 2501-5000
84df9bd7400fa250e3c0a4968f6f0a6878ff54e6 127.0.0.1:9004@19004 master - 0 1529562816000 4 connected 7501-10000
```
执行cluster info，可以看到该节点的具体情况：
```
127.0.0.1:9001> CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:6
cluster_current_epoch:5
cluster_my_epoch:1
cluster_stats_messages_ping_sent:3862
cluster_stats_messages_pong_sent:4014
cluster_stats_messages_meet_sent:5
cluster_stats_messages_sent:7881
cluster_stats_messages_ping_received:4014
cluster_stats_messages_pong_received:3867
cluster_stats_messages_received:7881
```

*注意一点：开启客户端的时候，最好以集群模式开启：`9001/src/redis-cli -p 9001 -c`,如果以单机形式开启：`9001/src/redis-cli -p 9001`,那么当执行写操作的时候，如果该key的Slot不是本节点时，会出现MOVED错误，redis并不会帮我们自动转到对应节点，以集群模式打开的话，出现这种情况，redis会自动跳转到目标节点*


### 1.2 注意事项
通过当启动redis集群服务器后，通过cluster meet使得各个节点互通互联，通过cluster addslots手动给每个节点分派Slots，这样可以实现一个纯粹的基于Hash Slot的redis集群，基于Hash slot的redis集群的思想就是去中心化，这也意味着集群中的节点没有主从之分，可以看做都是主节点（实际上通过cluster nodes也可以看出来默认所有节点都是主节点）

在这种情况下，一旦其中一个节点崩掉，那么整个集群中的所有节点都不能被访问，我做了个实验：启动其中的五台redis节点，在这种情况下，客户可以连接redis集群，但是不能进行任何读写操作。


### 1.3 优缺点

- 优点：集群中的多个节点可以并行执行读写操作，尤其是写操作，可以加快效率；扩展比较方便
- 缺点：在新添加或者删除节点后，需要进行数据迁移，重新分配Slot，又会降低效率

## 2 结合主从架构与Hash Slot的Redis集群

上面已经说了基于Hash Slot的redis集群存在的巨大问题，就是一旦一个节点崩了，那么整个集群都不能用了，为了弥补这个缺点，可以结合主从架构和Hash Slot的优点，建立一种基于主从和Hash Slot的redis集群。

多个master节点互通互联，形成一个集群，每个master节点负责处理若干个Slot嘈，每一个master节点又有一到多个slave节点互通互联。

这样即使redis集群中的一个master节点崩掉了，也不会导致整个集群不可用，因为该master所述的slaves经过投票，会使其中一个slave节点升级成master节点，继续工作，因此集群仍然处于可控状态。这种架构的redis集群不仅可以实现读写分离（在master进行写操作，在对应的slave上进行读操作），还可以实现并发写操作，极大提高效率。

### 2.1 环境搭建

搭建方法：

配置文件和基于Hash Slot的redis集群一样，一样需要首先启动所有节点上的redis服务器，然后创建集群：

`sudo src/redis-trib.rb check 127.0.0.1:900[1,2,3]//创建拥有三个节点的redis集群`

这三个节点都是主节点，此时的redis集群和仅仅基于Hash Slot的redis集群并没有区别

往集群里添加从节点：

```
//该从节点的master节点有redis随机分配，127.0.0.1:9006是要往集群里添加的节点，127.0.0.1:9001是集群中的任一个节点
sudo src/redis-trib.rb  add-node --slave 127.0.0.1:9006 127.0.0.1:9001

//该从节点的master的redis集群中id为node-id的节点，
sudo src/redis-trib.rb  add-node --slave --master-id node-id 127.0.0.1:9006 127.0.0.1:9001
```
从而形成redis主从架构集群。

*遇到的问题：*

- 添加节点的时候，显示节点不为空
`[ERR] Node 127.0.0.1:9002 is not empty. Either the node already knows other nodes (check with CLUSTER NODES) or contains some key in database 0.`

1) 可能启动该节点的redis服务器的时候，自动加载了rdb文件和appendonly.aof文件，从而导致节点不是一个空白节点，因此添加不了，把这两个文件删除，重新启动即可；

2) 可能是该节点已经是一个master的从节点了，你在把它送个别人，它肯定不愿意啦


### 2.2 测试

redis集群搭建好了，测试一下。

**测试可用性**

向数据库进行写操作的时候，redis会根据key的Hash Slot找到对应的master节点，由该master节点上的redis服务器进行实际写操作，该master所属的slave节点没有进行写操作，但是数据库里面也会存放master写操作的结果。来看一下：

```
//写操作，实际上是在9004节点上的redis上执行的set操作
127.0.0.1:9002> set test "用于测试集群"
-> Redirected to slot [6918] located at 127.0.0.1:9004
OK

//查看9004节点的appedonly.aof文件，可以看到进行了一次写操作
$3
set
$4
test
$18
用于测试集群

//查看9004节点的从节点9005中的appendonly.aof文件
$3
set
$4
test
$18
用于测试集群

//在集群中的任一节点进行读操作，找到test对应的值，是中文，所以才是下面的样子
127.0.0.1:9002> get test
-> Redirected to slot [6918] located at 127.0.0.1:9004
"\xe7\x94\xa8\xe4\xba\x8e\xe6\xb5\x8b\xe8\xaf\x95\xe9\x9b\x86\xe7\xbe\xa4"
```

从上面的测试可以看出，该架构的redis集群能够读写操作，并将其分派到对应的节点上具体执行，另外master上面的所有写操作，其所属的slave都会在自己的redis上进行一次相同的操作，以保证数据的一致性。


**测试可扩展性**

向集群中添加节点，可以添加主节点，也可以是从节点（上面已经说过了）

添加主节点:

`sudo src/redis-trib.rb add-node 127.0.0.1:9006 127.0.0.1:9001`

此时，一个节点就已经添加到集群中了，但是redis集群没有给他分配任何Slot，也就是说此时它还不能用。上面已经说了，集群中的每一个master节点redis都会给他分派对应的slot(为0也可以，但是该节点不能进行任何操作)，因此要向让新加入的节点能用，必须给他分配Slot，问题是集群已经分配完了，怎么办？*重新再分配一次，这可能会涉及到集群中的所有master节点*

`sudo src/redis-trib.rb reshard 127.0.0.1:9006`

此命令会根据我们的定义（从其中一个或多个节点中拿走一部分Slot分给新节点，还是从集群中所有节点中拿出一部分），分配给新节点若干Slot，并将这些Slot所属的key-value对从原redis中迁移到新节点中，此过程还是比较耗时的。然后新节点就可以工作了。

删除主节点：

`sudo src/redis-trib.rb del-node 127.0.0.1:9006 node-id //node-id是该节点对应的id`

如果直接用此命令删除一个master节点，会报错，原因是该master存在数据，以及对应的Slot，因此需要把Slot重新分配到其他节点，并把对应数据也迁移走，之后才可以删除。

`sudo src/redis-trib.rb reshard 127.0.0.1:9006 //根据提示操作即可` 重新分配之后，该master节点所述的slave也会被分配走的

之后进行删除就可以把master节点从集群中删除。当下次该节点在此启动后 

删除slave节点：

删除slave节点就相对简单很多，直接删除即可，无须进行数据迁移。只要该节点的appendonly.aof以及rdb文件没有被删除，下次该节点启动之后，会自动加入到集群中，并且上次它是那个master的节点，这次还是。

**测试可靠性**

现在集群是这样子的

```
sudo src/redis-trib.rb check 127.0.0.1:9004
>>> Performing Cluster Check (using node 127.0.0.1:9004)
M: 4cb95070d2b3ea4d490d98700344adcd4f7caa55 127.0.0.1:9004
   slots:0-1364,5461-12287 (8192 slots) master
   1 additional replica(s)
S: a92a1e253c6908777bfa6ad7d7823b3fd82d86c1 127.0.0.1:9006
   slots: (0 slots) slave
   replicates 943822ad4e0822c4bd94beb9bb4c3be80f1881d7
S: 51430136eaa89fb3420b1867fe8680d64cf02efe 127.0.0.1:9002
   slots: (0 slots) slave
   replicates 9a1afbd2d8f778ea8e6987bad00f8a0f3a2d4913
S: 30b026a576691b88750157885c7634e0d8bdd1b4 127.0.0.1:9005
   slots: (0 slots) slave
   replicates 4cb95070d2b3ea4d490d98700344adcd4f7caa55
M: 9a1afbd2d8f778ea8e6987bad00f8a0f3a2d4913 127.0.0.1:9001
   slots:1365-5460 (4096 slots) master
   1 additional replica(s)
M: 943822ad4e0822c4bd94beb9bb4c3be80f1881d7 127.0.0.1:9003
   slots:12288-16383 (4096 slots) master
   1 additional replica(s)
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

现在让集群中的一个master节点崩掉，让9001节点崩掉:


```
ps aux | grep redis
root      5364  0.2  0.0  44720  4540 ?        Ssl  16:52   0:24 src/redis-server 127.0.0.1:9001 [cluster]
root      5376  0.2  0.0  44636  4448 ?        Ssl  16:52   0:24 src/redis-server 127.0.0.1:9003 [cluster]
root      5382  0.2  0.0  44684  4516 ?        Ssl  16:52   0:26 src/redis-server 127.0.0.1:9004 [cluster]
root      5394  0.1  0.0  44636  4380 ?        Ssl  16:52   0:19 src/redis-server 127.0.0.1:9006 [cluster]
root      5841  0.2  0.0  44636  4368 ?        Ssl  17:31   0:15 src/redis-server 127.0.0.1:9002 [cluster]
root      5866  0.2  0.0  44656  4256 ?        Ssl  17:32   0:15 src/redis-server 127.0.0.1:9005 [cluster]

sudo kill -9 5364

ps aux | grep redis
root      5376  0.2  0.0  44636  4448 ?        Ssl  16:52   0:24 src/redis-server 127.0.0.1:9003 [cluster]
root      5382  0.2  0.0  44684  4516 ?        Ssl  16:52   0:27 src/redis-server 127.0.0.1:9004 [cluster]
root      5394  0.1  0.0  44636  4380 ?        Ssl  16:52   0:19 src/redis-server 127.0.0.1:9006 [cluster]
root      5841  0.2  0.0  44636  4368 ?        Ssl  17:31   0:15 src/redis-server 127.0.0.1:9002 [cluster]
root      5866  0.2  0.0  44656  4256 ?        Ssl  17:32   0:15 src/redis-server 127.0.0.1:9005 [cluster]
```

现在集群是这样子的：

```
sudo src/redis-trib.rb check 127.0.0.1:9004
>>> Performing Cluster Check (using node 127.0.0.1:9004)
M: 4cb95070d2b3ea4d490d98700344adcd4f7caa55 127.0.0.1:9004
   slots:0-1364,5461-12287 (8192 slots) master
   1 additional replica(s)
S: a92a1e253c6908777bfa6ad7d7823b3fd82d86c1 127.0.0.1:9006
   slots: (0 slots) slave
   replicates 943822ad4e0822c4bd94beb9bb4c3be80f1881d7
M: 51430136eaa89fb3420b1867fe8680d64cf02efe 127.0.0.1:9002
   slots:1365-5460 (4096 slots) master
   0 additional replica(s)
S: 30b026a576691b88750157885c7634e0d8bdd1b4 127.0.0.1:9005
   slots: (0 slots) slave
   replicates 4cb95070d2b3ea4d490d98700344adcd4f7caa55
M: 943822ad4e0822c4bd94beb9bb4c3be80f1881d7 127.0.0.1:9003
   slots:12288-16383 (4096 slots) master
   1 additional replica(s)
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```
9001的slave节点9004升级为master，代替9001继续工作