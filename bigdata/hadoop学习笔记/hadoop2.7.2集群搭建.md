##Hadoop 2.7.1集群搭建##

这里搭建hadoop集群，使用了三台电脑，分别是：  
192.168.0.11  
192.168.0.12  
192.168.0.13

各个主机名分别是： master,salve1,salve2

###1配置hosts各个主机###
修改hosts文件：  
```
127.0.0.1 localhost
192.168.0.11    master
192.168.0.12    slave1
192.168.0.13    slave2
```

###2 免密登录###
安装ssh服务，这里使用的centos环境，需要安装：  
```
#安装ssh服务端
yum install openssh-server -y
#安装ssh客户端
yum install openssh-clients -y
```
使用命令:`ssh-keygen`生成本机密钥和公钥，这些文件在{USER_HOME}/.ssh目录下，进入该目录，执行命令：
```
#authorized_keys文件若没有，首先创建一个
cat id_rsa.pub >> authorized_keys
```
将authorize_keys文件分发到其他主机上，并追加到对应的authorized_keys文件中。即可实现在master主机上，免密登录其他主机。
```
ssh slave1   //免密登录
```

###3 安装jdk###
下载jdk安装包：jdk-XXX.tar.gz,解压安装  
```
tar zxvf jdk-XXX.tar.gz -C /opt

#修改/etc/profile，添加如下语句
export JAVA_HOME=/opt/jdk-XXX
export PATH={JABA_HOME}/bin:${PATH}

source /etc/profile
```

###4 安装hadoop###
下载hadoop安装包：hadoop-2.7.1.XXX.tar.gz,解压进行安装：
```
tar zxvf hadoop-2.7.1.XXX.tar.gz -C /opt
```

进入hadoop安装目录，修改etc/hadoop目录下的各个配置文件：  
修改core-site.xml文件：  
```
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://master:9002</value>
    </property>
    <property>
        <name>fs.default.name</name>
        <value>hdfs://master:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>file:/home/hadoop/tmp</value>
    </property>
</configuration>
```

修改hdfs-site.xml文件：  
```
<configuration>
   <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>master:9001</value>
   </property>
   <property>
         <name>dfs.namenode.name.dir</name>
         <value>file:/home/hadoop/dfs/name</value>
   </property>
   <property>
          <name>dfs.datanode.data.dir</name>
          <value>file:/home/hadoop/dfs/data</value>
   </property>
   <property>
           <name>dfs.replication</name>
           <value>3</value>
   </property>
</configuration>
```

修改mapred-site.xml文件：
```
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>master10020</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>master:19888</value>
    </property>
</configuration>
```

修改yarn-site.xml文件：
```
<configuration>
    <property>
            <name>yarn.nodemanager.aux-services</name>
            <value>mapreduce_shuffle</value>
    </property>
    <property>
            <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
            <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
    <property>
            <name>yarn.resourcemanager.address</name>
            <value>master:8032</value>
    </property>
    <property>
            <name>yarn.resourcemanager.scheduler.address</name>
            <value>master:8030</value>
    </property>
    <property>
            <name>yarn.resourcemanager.resource-tracker.address</name>
            <value>master:8031</value>
    </property>
    <property>
            <name>yarn.resourcemanager.admin.address</name>
            <value>master:8033</value>

    </property>
    <property>
            <name>yarn.resourcemanager.webapp.address</name>
            <value>master:8088</value>
    </property>
</configuration>
```

修改slaves文件,用于指定slave节点：
```
slave1 
slave2
```

修改hadoop-env.sh文件：  
```
#将export JAVA_HOME行修改成如下：
export JAVA_HOME=/opt/jdk.XXX
```

修改/etc/profile文件：   
```
export HADOOP_HOME=/opt/hadoop-2.7.1
export PATH={HADOOP_HOME}/bin:${JAVA_HOME}/bin:${PATH}


#指令命令：
source /etc/profile
```

到此，hadoop已经配置成功了，通过scp命令将hadoop解压包分发到各个节点上：  
```
scp /opt/hadoop-2.7.1 slave1@salve1:/opt
scp /opt/hadoop-2.7.1 slave1@salve1:/opt
```
到此，hadoop集群搭建完毕，开始进行hdfs文件系统的格式化操作：  
```
hadoop namenode -format
```
当出现如下日志信息时，表示格式化hdfs成功：
```
...
Storage directory /home/hadoop/dfs/name has been successfully formated.
...
```

###5 测试hadoop集群###
在hdfs上新建一个文件夹/input,并上传测试文件word.txt:  
```
hdfs dfs -mkdir  /input

hdfs dfs -put /home/word.txt /input
```

使用hadoop自带的wordcount类来统计word.txt中的字数：  
```
hadoop jar /opt/hadoop-2.7.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.7.1.XX.jar worcount /input/* /out

使用如下指令查看统计结果：
hdfs dfs -cat /out/*
```