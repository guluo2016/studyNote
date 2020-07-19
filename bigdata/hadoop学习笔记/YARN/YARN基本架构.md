**YARN基本架构学习**

YARN从整体上来说由两部分组成：

- ResourceManager   (RM)
- NodeManager  (NM)

其中RM负责集群的整体集群管理，因此又被称之为全局资源管理器；NM负责管理集群中节点上的资源，因此由被称之为节点资源管理器。



### 1 ResourceManager

#### 1.1 RM的组成部分

从源码中可以看出来，RM实际上又由两部分组成：

- Application Manager (应用管理器)
- Resource Scheduler (资源调度器)

详细说明下这两者的作用。

##### 1.1.1 Application Manager

应用管理器的作用就是负责接收Client端传输过来的Job任务，为应用程序分配第一个Container，用于运行任务中的Application Master；另外一个任务就是负责监控Application Master，在其失败的时候负责重启Application Master。

##### 1.1.2  Scheduler

调度器的作用总的来说，其目的就是为了将集群中每个节点上的资源都充分利用起来，避免集群中有的节点负载过重，有的节点负载过小。

需要特说说明的是，调度器的作用非常纯粹，就是为了合理地分配集群中的资源。它不负责任何具体的和应用程序相关的工作。比如map任务、reduce任务应该怎么运行、监控程序状态等都不由他来管理。

调度其如果在细分的话，YARN中共有三类调度器：

- 容量调度器
- 公平调度器
- 队列调度器、





