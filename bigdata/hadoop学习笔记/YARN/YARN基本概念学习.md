## 1 YARN中的主要角色
YARN全称是：Yet Another Resource Negotiator，由雅虎研发的集群资源调度器，用于改善MRV1中存在的不足。

YARN中有几个比较重要的角色：    

- Resource Manager（RM）：负责管理集群资源，一个集群中只有一个Resource Manager，HA架构可能还会有一个备用的Resource Manager
- Application Master（AM）：负责管理运行任务的生命周期，一个Job任务对应一个Application Master
- NodeManager（NM）：集群中每个节点上都有一个NodeManager，负责管理节点资源，响应处理AM的任务启动、停止请丢
- Container：对资源的抽象，RM为AM分配资源时，会把资源封装成Container对象返回给AM

## 2 各角色说明
### 2.1 RM
一个YARN集群中只有一个RM,HA架构会有一个备用的。RM主要有两部分组成：

+ 调度器  
由于集群资源的限制（CPU、内存、磁盘空间等有限），提交到RM上的任务可能并不会立即被执行，而是放在一个队列当中，由调度器按照某种调度策略，一次从队列中取出任务，并分配相关资源去执行；  
调度器不负责具体应用程序的相关工作，比如监控任务执行状态、不负责重启失败任务等。 

+ 应用管理器ASM  
`//TODO`
ASM负责管理提交到RM的所有Application

### 2.2 AM
AM主要协调管理App的所有task
