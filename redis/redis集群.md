<!-- MarkdownTOC -->

- 1 基于Hash Slot的Redis集群
	- 1.1 配置基于Slot的Redis集群
	- 1.2 优缺点
- 2 基于主从节点的Redis集群

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





### 1.2 优缺点

- 优点：集群中的多个节点可以并行执行读写操作，尤其是写操作，可以加快效率；扩展比较方便
- 缺点：在新添加或者删除节点后，需要进行数据迁移，重新分配Slot，又会降低效率

## 2 基于主从节点的Redis集群

一个Redis集群中有多个几点，但是其中有且仅有一个master节点，和若干个salve节点，主节点负责写操作和同步数据到从节点上，从节点仅仅负责进行读操作。实施的是读写分离操作，提高了并发读能力（可以同时从多个从数据库中读取数据）

主数据库负责维护整个集群以及所有的从节点，一旦有新节点连接进来后，总是会和主数据库通信，进行数据同步，从而保证与主数据库的数据一致性