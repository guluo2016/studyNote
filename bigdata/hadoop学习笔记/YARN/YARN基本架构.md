**YARN基本架构学习**

YARN从整体上来说由两部分组成：

- ResourceManager   (RM)
- NodeManager  (NM)

其中RM负责集群的整体集群管理，因此又被称之为全局资源管理器；NM负责管理集群中节点上的资源，因此由被称之为节点资源管理器。

YARN集群的整体结构是主从架构，也即一个集群有一个RM和若干个NM组成。有时候为了提高集群的可靠性，可能需要设定HA，那么一个YARN集群中可能就会有一个Active的RM和若干个standby的RM以及若干个NM。



### 1 ResourceManager

#### 1.1 RM的组成部分

从源码中可以看出来，RM实际上又由两部分组成：

- Application Manager (应用管理器)
- Resource Scheduler (资源调度器)

详细说明下这两者的作用。

##### 1.1.1 Application Manager

应用管理器的作用就是负责接收Client端传输过来的Job任务，为应用程序分配第一个Container，用于运行任务中的Application Master；另外一个任务就是负责监控Application Master，在其失败的时候负责重启Application Master。

Application Manager同时也维护了一个以完成的application的缓存（成功、失败的都会缓存下来），这样子就是在很长时间以后，也可以通过Web UI界面去查看提交给YARN的所有application情况。

##### 1.1.2  Scheduler

调度器的作用总的来说，其目的就是为了将集群中每个节点上的资源都充分利用起来，避免集群中有的节点负载过重，有的节点负载过小。

需要特说说明的是，调度器的作用非常纯粹，就是为了合理地分配集群中的资源。它不负责任何具体的和应用程序相关的工作。比如map任务、reduce任务应该怎么运行、监控程序状态等都不由他来管理。

调度其如果在细分的话，YARN中共有三类调度器：

- 容量调度器
- 公平调度器
- 队列调度器

### 2 NodeManager

NodeManager进程运行在YARN集群中节点上，YARN集群中的每一个节点上都会运行一个NM（RM节点除外，可以根据配置来选择该节点上是否也运行NM）。

NM的主要职责如下：

- 接受RM的资源分配请求，具体就是RM中的Application Manager发送过来的资源分配请求
- AM与NM进行通信，进行资源分配，这里的分配也是按照application manager的分配要求来进行的
- 监控容器，并且报告容器的使用情况给RM

### 3 Application Master

Application Master简称为AM，每个提交给YARN的application都会为其创建一个AM。它的主要职责就是负责和RM通信、和NM通信。

当一个任务提交到YARN上后，RM中的Application Manager首先给其分配一个资源容器，并确定该容器的NM，并告知NM。NM接收到请求之后，开辟一个容器，并且在容器中启动AM，AM一旦启动成功之后，就由AM来管理所提交的application。AM主要进行如下工作：

- AM开始启动任务，它会首先向RM发送请求，这个阶段可能有很多个AM给RM发送请求，所有的这些请求都会先交给RM的调度器进行处理
- RM中的调度器按照某种调度策略，来决定响应某一个AM，响应的结果就是给AM分配它需要的容器，并且告知这些容器应该再哪些NM中启动
- AM收到RM传送过来的响应之后，就会根据响应信息，去跟NM通信
- NM收到AM发送过来的请求之后，安装要求，开辟一个指定资源的容器（指定有CPU资源和内存资源），并且按照要求在容器中启动AM指定的map任务或者是reduce任务。
- AM同时也负责监控容器中各个任务的状态
- 当有容器中的任务启动失败时，AM还负责重启这些任务。







