#### 1 编译HBase

```shell
mvn package -DskipTests assembly:single
```

#### 2 部署

编译成功后的HBase，在`${HBASE_SOURCE}/hbase-assembly/target`目录下，可以找到编译成功后的tar包。

##### 2.1 配置

对该tar包进行解压，然后进行伪分布式模式的部署。所谓伪分布式模式就是HBase的所有服务均在同一个节点上运行。

需要注意的是，部署HBase服务前，先确保Hadoop服务已经部署完成，这是因为HBase需要依赖Hadoop。需要使用外部ZK的话，也需要提前部署一套ZK服务。

解压完成之后，进入`${HBASE_HOME}/conf`目录下，修改hbase-site.xml文件：

```xml
<configuration>
    <!-- 是否开启集群,伪分布式也属于分布式 -->
   <property>
       <name>hbase.cluster.distributed</name>
       <value>true</value>
   </property>
    
   <!-- zookeeper信息，这里使用外部的Zookeeper -->
   <property>
       <name>hbase.zookeeper.quorum</name>
       <value>10.121.198.222:2181</value>
   </property>
    
    <!--设置HBase数据在HDFS上的存储位置-->
    <property>
      <name>hbase.rootdir</name>
      <value>hdfs://10.121.198.222:9002/hbase</value>
    </property>
    
    <!--设置临时数据在本地的存放位置-->
    <property>
      <name>hbase.tmp.dir</name>
      <value>/usr/local/hbase-2.2.2/tmp</value>
     </property>
</configuration>

```

在修改hbase-env.sh文件

```shell
#配置hbase的home目录
export HBASE_HOME=/usr/local/hbase-2.2.2/
#HBase需要依赖Hadoop，因此需要知道Hadoop的配置信息
export HBASE_CLASSPATH=/usr/local/hadoop-2.7.7/etc/hadoop
#设置pid文件的存放位置
export HBASE_PID_DIR={HBASE_HOME}/pids
#设置不使用自带的ZK
export HBASE_MANAGES_ZK=false                  
```

配置regionserver文件

```shell
#配置都有哪些节点上需要启动RS，这里是伪分布式，因此设置一个节点localhost
localhost
```

##### 2.2 启动

进入`${HBASE_HOME}/bin`目录下，执行`./start-hbase.sh`脚本，即可启动HBase服务。