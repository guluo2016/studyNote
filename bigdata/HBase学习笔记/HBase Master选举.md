HBase是通过Zookeeper来实现HMaster的选举。

主要的做法就是多个有资格成为master的节点，竞争去往zookeeper中的特定路径写入特定数据，zookeeper中的这个路径有配置`zookeeper.znode.master`控制，写入的数据就是HMaster服务的信息，包括所在的主机名以及HMaster所占用的端口号信息。一旦其中一个写入成功之后，其他竞争的节点就不再竞争往这个路径下写入数据了，而是转为backup，并且监控着`zookeeper.znode.master`，只要`zookeeper.znode.master`节点停止或者异常的时候，就会再次进行竞争写入状态。



具体的代码就是，先执行`HMaster`中的`startActiveMasterManager`方法，具体就是去执行如下代码：

```java
if (activeMasterManager.blockUntilBecomingActiveMaster(timeout, status)) {
	finishActiveMasterInitialization(status);
}
```



在这里会首先调用方法`blockUntilBecomingActiveMaster`,该方法属于`ActiveMasterManager`，顾名思义，该方法的作用就是在一直阻塞、直至成为主节点。

具体代码就是

```java
/**
   * Block until becoming the active master.
   *
   * Method blocks until there is not another active master and our attempt
   * to become the new active master is successful.
   *
   * This also makes sure that we are watching the master znode so will be
   * notified if another master dies.
   * @param checkInterval the interval to check if the master is stopped
   * @param startupStatus the monitor status to track the progress
   * @return True if no issue becoming active master else false if another
   *   master was running or if some other problem (zookeeper, stop flag has been
   *   set on this Master)
   * 从这个注释中也可以看出来，这个方法实际上就是一直监控ZK上的特定节点信息，一旦发生变化，
   * 就往里面写入自己的信息，一旦写入成功，就变成了master，返回true，跳出循环
   * 没有写入成功，就先wait，一旦master出现异常，就再次进入竞争状态
   */
  boolean blockUntilBecomingActiveMaster(
      int checkInterval, MonitoredTask startupStatus) {
    String backupZNode = ZNodePaths.joinZNode(
      this.watcher.getZNodePaths().backupMasterAddressesZNode, this.sn.toString());
    while (!(master.isAborted() || master.isStopped())) {
      try {
        /**
        * 努力往ZK中的masterAddressZNode路径中写入数据，写入成功之后，进入if代码块
        * 执行完毕之后，返回true，并且跳出循环
        */
        if (MasterAddressTracker.setMasterAddress(this.watcher,
            this.watcher.getZNodePaths().masterAddressZNode, this.sn, infoPort)) {
          ...
          return true;
        }
	  
      /**
      * 没有竞选成功的话，最终会执行下面的代码，进入wait状态
      * 一旦master是isAborted()或者isStopped()就会被唤醒，再次进行往ZK中竞争写入操作。
      */  
        while (clusterHasActiveMaster.get() && !master.isStopped()) {
            ...
            clusterHasActiveMaster.wait(checkInterval);
            ...
        }
     }
  }

```

