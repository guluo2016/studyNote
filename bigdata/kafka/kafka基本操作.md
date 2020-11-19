[TOC]

### 1 启动kafka

kafak依赖于zookeeper，因此在启动kafka之前，要首先启动zookeeper，最新版本的kafka安装包中已经自带了zookeeper服务，可以简单地使用该zookeeper作为kafka的依赖，启动zookeeper服务：

```shell
cd ${KAFKA_HOME}
bin/zookeeper-server-start.sh config/zookeeper.properties
```

再开启一个终端，用于启动kafka服务，实际上就是启动kafka broker。

```shell
cd ${KAFKA_HOME}
bin/kafka-server-start.sh config/server.properties
```

**什么是kafak broker**

kafka是一个分布式的发布-订阅消息系统，因此，一个kafka集群中会有多太台server，每一台server都是可以存储消息的，将kafak集群中的一个server称之为kafka实例，又称之为broker。

### 2 创建`topic`

**什么是event**

kafka中的event实际上就是指消息，因此又可以被称为records或者message。

**什么是topic**

kafka官网上是这么介绍的，topic用于保存event。topic就相当于操作系统中的文件夹，而event就相当于操作系统中的文件，我们通常情况下，会把同一类的文件放到同一个文件夹中，因此topic在kafka中起到一个分类的作用。

为了使得消费者和生产者能够对kafka生产和消费消息，首先要创建一个topic。创建命令如下：

```shell
cd ${KAFKA_HOME}
bin/kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092
```

上面的命令创建一个名字为`quickstart-events`的topic。

**什么是分区`partition`**

kafka中的每一个topic都可以分成多个分区。kafka是一个面向处理海量数据的分布式消息系统，为了保证其能够处理海量数据，一定是将数据分成多份，存储在不同的broker上。

采取分区的深层原因是：kafka是基于文件来进行消息存储的，当消息非常大的时候，对应的存储文件也一定会很大，很容易达到单节点的磁盘上限，因此采用分区的办法，一个分区对应一个文件，就可以将数据分成多跟，存储在不同的broker上，并且也有利于后期的扩展；另外一个访问，采用分区也可以进行负载均衡，使得kafka可以容纳更多的消费者。

为了保证数据的可靠性，kafka还引入了副本机制，副本时针对分区而言的。



在创建topic的时候，可以指定该topic的分区数，以及分区的副本数，命令如下：

```shell
bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 
--partitions 1 --topic topic-name
```



### 3 生产消费数据

要想消费数据，首先得生产数据，kafka中生产者生产数据的命令如下：

```shell
cd ${KAFKA_HOME}
bin/kafka-console-producer.sh --topic quickstart-events --bootstrap-server localhost:9092
This is my first event
This is my second event
```

可以通过按`Ctrl + C`来结束生产者客户端。上面的命令是生产者向`quickstart-events`的topic中生成两条events。

接下来就是消费者开始进行消费。消费命令如下：

```shell
cd ${KAFKA_HOME}
bin/kafka-console-consumer.sh --topic quickstart-events --from-beginning --bootstrap-server localhost:9092
##从指定topic中获取到消息
This is my first event
This is my second event
```

