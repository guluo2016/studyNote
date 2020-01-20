## 1 概述
ES启动非常简单,在Linux环境下，进入{ES_HOME}/bin目录，执行：`./elasticsearch`,即可启动ES服务，这个时候，启动ES进程是在前台显示的，而且会打印启动的相关日志到前台。如果想在把ES进程放到后台，可以使用命令`./elasticsearch -d`。

ES启动的时候，会预先做很多工作，比如集群选主、初始化节点，基于Netty框架启动监听服务等等。

基于ES 6.7.1进行启动源码分析。

## 2 启动流程
启动脚本elasticsearch是ES最方便的启动入口，这个脚本最终会执行Elasticsearch.java程序，真正开始ES的启动的启动工作：
```
//在main方法中会调用Elasticsearch的重载方法main
public static void main(String[] args){
	int status = main(args,Terminal.DEFAULT);
}

static int main(final String[] args, final Elasticsearch elasticsearch, final Terminal terminal) throws Exception {
    //在这里，会调用Elasticsearch的父类Command中的main方法
    return elasticsearch.main(args, terminal);
}

//最终会执行Command的execute方法，由于Elasticsearch重写了这个方法，因此会执行的Elasticsearch中的execute方法
 @Override
protected void execute(Terminal terminal, OptionSet options, Environment env) throws UserException {
    init(daemonize, pidFile, quiet, env);
}

在执行init方法，在init方法中会调用Bootstrap中的init方法，
 /**
 * This method is invoked by {@link Elasticsearch#main(String[])} to startup elasticsearch.
 */
static void init(
        final boolean foreground,
        final Path pidFile,
        final boolean quiet,
        final Environment initialEnv) throws BootstrapException, NodeValidationException, UserException {
    // force the class initializer for BootstrapInfo to run before
    // the security manager is installed
    BootstrapInfo.init();

    INSTANCE = new Bootstrap();

    //这里会进行一些配置操作，这里会完成对Node的初始化操作
    INSTANCE.setup(true, environment);

    //这里就开始真正意义上的启动了，因为这里仅仅是对一个ES实例而言的，因此这里会最终
    //调用Node中的start方法
    INSTANCE.start();
}
```

接下来再看看Node这个类，Node类中运用了Google Guice框架来进行对象的初始化操作和依赖注入操作。

在对Node进行start操作时，不仅会启动这个ES服务，而且还为完成一些额外的操作，个人认为比较重要的有：

- 基于Netty框架启动监听服务，他会处理用户发送非ES服务的REST请求，并返回何时的值
- 启动选主操作，为ES集群选举一个master节点，这里会根据配置文件ping所有的ES节点，然后与每个ping通的节点建立联系。这里多提一点，正是由于每个节点都与其他能够ping通的节点有联系，因此Client连接ES集群中的任一节点，就可以基于该节点获知整个ES集群的所有信息。

## 3 选主机制
在Node类中的start方法代码如下：
```
public Node start() throws NodeValidationException {
	// start before cluster service so that it can set initial state on ClusterApplierService
	discovery.startInitialJoin(); 
}
```
通过注释也可看出来，这是在启动ES服务之前进行的操作，目的是为了在ES集群真正能够提供服务的时候，集群中一定存在master节点，从代码中可以看出他实际上调用的是Discovery中的startInitialJoin方法来进行主节点的选举操作的，由于ES默认使用Discovery的实现类：ZenDiscovery，在这里会调用`ZenDiscovery.startInitialJoin()`,然后在在这个类中调用几个方法，最终会调用innerJoinCluster方法,在这个方法中会调用findMaster()方法，进行master节点发现操作。

在看这段源码之前，先学习一下ES选主机制：

ES没有借助于其他工具来实现master节点选举（很多集群服务倾向于借助Zookeeper来实现master节点的选举），而是自己实现了一套选举机制。

** 1）节点是否有资格成为master **   
首先，根据配置文件，可以配置如下内容：  
```
node.master: true
```
只有配置为true的节点才有资格被选举成master节点，否则没有资格

** 2）预防脑裂 **   
一个ES集群中如果同时存在两个master节点，那么就是出现了脑裂，为了防止出现脑裂，ES采用少数服从多数机制，来避免这种情况的出现，具体的做法就是在配置文件中设定如下字段的值：
```
discovery.zen.minimum_master_nodes: 2（默认值是1）
discovery.zen.ping.timeout: 3s （默认值是3s）
```
discovery.zen.minimum_master_nodes参数决定在选主过程中，最少需要多少个几点来进行选举，为了防止出现脑裂，推荐这个参数的值为（N/2 + 1），这保证了在任何情况下选主，都会有超过半数的节点参与，从而避免出现脑裂。*这里的N指的是集群中的总节点数，如ES有3个节点，那么discovery.zen.minimum_master_nodes的建议值为2*  
discovery.zen.ping.timeou这个值也与预防脑裂有点关系，它的作用是设置发现节点的超时时间，如果超过规定时间还没有发现对应节点，那么就认为该节点不存在。在网络差的环境下，可以适当地将该参数的值设置大一点，从而保证集群中有足够可用的节点，来参与选主。当然该参数不仅仅在选主的时候，有此作用。

** 3）选举发起 **  
只有node.master: true的节点有资格成为Master节点，也有资格来发起Master选举。当ES集群首次启动的时候，如果对应节点有资格成为master节点，那么此时会发起master选举操作，它首先会ping集群中的其他节点，是根据配置文件参数来确定ping哪些节点的：
```
discovery.zen.ping.multicast.enabled: false
discovery.zen.ping.unicast.hosts: ["node1", "node2", "node2"]
```
ES会默认以多播的形式，在同一网段内发送消息，以此来发现其他节点，但是当ES集群中的节点不再同一个网段，或者不允许使用多播的时候，可以使用单播形式发现其他节点，这个时候就需要把参数discovery.zen.ping.multicast.enabled: false设置为false  
这个时候，ES会根据discovery.zen.ping.unicast.hosts的值，一个一个地给对应的节点发送消息，查看对应节点是否有效。

** 4）选举规则 **
经存在，那么它会申请加入这个集群，成功之后就算是完成了；如果此时ES集群中还没有master节点，它们


```
 /**
 * the main function of a join thread. This function is guaranteed to join the cluster
 * or spawn a new join thread upon failure to do so.
 */
private void innerJoinCluster() {
    DiscoveryNode masterNode = null;
    final Thread currentThread = Thread.currentThread();
    nodeJoinController.startElectionContext();
    while (masterNode == null && joinThreadControl.joinThreadActive(currentThread)) {
        masterNode = findMaster();
    }

    if (!joinThreadControl.joinThreadActive(currentThread)) {
        logger.trace("thread is no longer in currentJoinThread. Stopping.");
        return;
    }

    if (transportService.getLocalNode().equals(masterNode)) {
        final int requiredJoins = Math.max(0, electMaster.minimumMasterNodes() - 1); // we count as one
        logger.debug("elected as master, waiting for incoming joins ([{}] needed)", requiredJoins);
        nodeJoinController.waitToBeElectedAsMaster(requiredJoins, masterElectionWaitForJoinsTimeout,
                new NodeJoinController.ElectionCallback() {
                    @Override
                    public void onElectedAsMaster(ClusterState state) {
                        synchronized (stateMutex) {
                            joinThreadControl.markThreadAsDone(currentThread);
                        }
                    }

                    @Override
                    public void onFailure(Throwable t) {
                        logger.trace("failed while waiting for nodes to join, rejoining", t);
                        synchronized (stateMutex) {
                            joinThreadControl.markThreadAsDoneAndStartNew(currentThread);
                        }
                    }
                }

        );
    } else {
        // process any incoming joins (they will fail because we are not the master)
        nodeJoinController.stopElectionContext(masterNode + " elected");

        // send join request
        final boolean success = joinElectedMaster(masterNode);

        synchronized (stateMutex) {
            if (success) {
                DiscoveryNode currentMasterNode = this.clusterState().getNodes().getMasterNode();
                if (currentMasterNode == null) {
                    // Post 1.3.0, the master should publish a new cluster state before acking our join request. we now should have
                    // a valid master.
                    logger.debug("no master node is set, despite of join request completing. retrying pings.");
                    joinThreadControl.markThreadAsDoneAndStartNew(currentThread);
                } else if (currentMasterNode.equals(masterNode) == false) {
                    // update cluster state
                    joinThreadControl.stopRunningThreadAndRejoin("master_switched_while_finalizing_join");
                }

                joinThreadControl.markThreadAsDone(currentThread);
            } else {
                // failed to join. Try again...
                joinThreadControl.markThreadAsDoneAndStartNew(currentThread);
            }
        }
    }
}
```