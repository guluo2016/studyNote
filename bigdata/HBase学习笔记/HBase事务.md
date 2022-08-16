### 综述

HBase支持行级事务，也即用户对于HBase的一条数据的读写，HBase可以保证其原子性。对于多行事务，HBase并不能保证其原子性。

为了保证行级事务，需要考虑写写控制和读写控制，对于读读操作，由于不涉及到数据的修改，因此无须进行并发控制。如果不考虑这两种控制，可能会出现数据不一致情况，也就不是事务了。

下面对于写写控制和读写控制，分别考虑。

### 写写控制

#### 无并发控制

先考虑不进行并发控制的情况。

假设有两个写线程，同一时间段内，对一行数据进行修改，由于HBase的写入需要经过好两个步骤：

- 写WAL
- 写入memstore

如果不进行并发，那么在更新完WAL之后，在更新memstore时，可能第二个写线程先更新info:company,第一个写线程后更新info:company； 第一个线程先更新info:role，第二个线程后更新info:role，如下图所示。

![img](https://github.com/guluo2016/picture/raw/dev/img/7effbc3f-0c1c-4135-9dc3-f310e9c8b652)

那么我们最终读取到的数据就是下面这样，即数据出现不一致。

![img](https://github.com/guluo2016/picture/raw/dev/img/1194e8c1-7a84-4da1-9953-1a6d74d07a4f)

#### 并发控制

为了解决上面的问题，HBase引入了行锁机制，以rowkey为锁，当写线程需要更新数据时，需要先获取行锁，然后才能更新，对于没有获取到行锁的写线程，只能等待，直至获取到行锁。具体的流程如下。

- 写操作开始
- 获取行锁
- 更新WAL
- 更新memstore
- 释放锁

### 读写控制

#### 无并发控制

读写场景，同样先考虑不进行并发控制，可能会出现的情况。

假如现在有两个写线程要更新同一行数据，同时一个读线程要对该行数据进行读取操作。读线程读取的时机是红线部分，此时第一个写线程已经完成，第二个写线程更新了一部分，如下图所示。

![img](https://github.com/guluo2016/picture/raw/dev/img/30530bc9-0305-47a1-a5c2-86281119799c)

那么读线程读取的数据就是下面这样子，同样会出现数据不一致情况。

![img](https://github.com/guluo2016/picture/raw/dev/img/1194e8c1-7a84-4da1-9953-1a6d74d07a4f)

#### 并发控制

为了解决上面的问题，HBas引入了MVCC机制，采用无锁机制，实现读写控制。为了实现该机制，HBase在进行写操作时，会进行如下操作：

- 获取行锁
- 分配一个写事务id
- 更新WAL
- 更新memstore
- 完成写事务id
- 释放锁

与此同时，对于每一次的读操作，HBase都会为其分配一个已经完成、且值最大的写事务id。

如图所示，两个写线程开启写事务时，HBase分别为其分配一个写id，当读事务开启时，由于写事务1已经完成，而写事务2还未完成，因此分配的已完成、其值最大的写事务id是1，称之为read point。因此对该读事务而言，所有小于等于read point的数据都是对其可见的，大于read point的数据是不可见的。

![image-20220815203852275](https://github.com/guluo2016/picture/raw/dev/img/image-20220815203852275.png)

因此，在这种情况下，读线程最终读取的结果是这个样子。

![img](https://github.com/guluo2016/picture/raw/dev/img/12b2c8a4-551b-4aa5-8629-874e220a91bd)

### 参考

- [**Apache HBase Internals: Locking and Multiversion Concurrency Control**](https://blogs.apache.org/hbase/entry/apache_hbase_internals_locking_and)
- [**数据库事务系列－HBase行级事务模型**](http://hbasefly.com/2017/07/26/transaction-2/)

