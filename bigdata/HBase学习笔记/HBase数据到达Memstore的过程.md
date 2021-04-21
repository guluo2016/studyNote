往HBase表中写入数据的主要流程。

#### 1 RegionServer启动的初始化工作

启动`RegionServer`进程的入口类是`HRegionServer`，通过执行该类的`main`方法开始。

其简单流程如下：

```java
//通过main方法的执行流程
//main()
new HRegionServerCommandLine(regionServerClass).doMain(args);

//doMain
int ret = ToolRunner.run(HBaseConfiguration.create(), this, args);

//ToolRunner.run, 启动的tool就是HRegionServerCommandLine对象
run(tool.getConf);

//HRegionServerCommandLine.run  HRegionServerCommandLine.start
//构造一个HRegionServer线程对象，并启动
HRegionServer hrs = HRegionServer.constructRegionServer(regionServerClass, conf);
hrs.start();
handleReportForDutyResponse(w);
startServices();
initializeMemStoreChunkCreator();

//这里定义chunksize的默认大小为2M
int chunkSize = conf.getInt(MemStoreLAB.CHUNK_SIZE_KEY, MemStoreLAB.CHUNK_SIZE_DEFAULT);
// init the chunkCreator
ChunkCreator.initialize(chunkSize, offheap, globalMemStoreSize, poolSizePercentage,
                        initialCountPercentage, this.hMemManager);

//initialize
instance = new ChunkCreator(chunkSize, offheap, globalMemStoreSize, poolSizePercentage,
            initialCountPercentage, heapMemoryManager,
            MemStoreLABImpl.INDEX_CHUNK_PERCENTAGE_DEFAULT);

//ChunkCreator构造方法
this.chunkSize = chunkSize; // in case pools are not allocated
initializePools(chunkSize, globalMemStoreSize, poolSizePercentage, indexChunkSizePercentage,
                initialCountPercentage, heapMemoryManager);

//initializePools
//在这里定义了dataChunk、indexChunk的size大小，默认为2M
this.dataChunksPool = initializePool("data", globalMemStoreSize,
            (1 - indexChunkSizePercentage) * poolSizePercentage,
            initialCountPercentage, chunkSize, heapMemoryManager);
// The index chunks pool is needed only when the index type is CCM.
// Since the pools are not created at all when the index type isn't CCM,
// we don't need to check it here.
this.indexChunksPool = initializePool("index", globalMemStoreSize,
                                      indexChunkSizePercentage * poolSizePercentage,
                                      initialCountPercentage, (int) (indexChunkSizePercentage * chunkSize),
                                      heapMemoryManager);
```

#### 2 put操作的流程

当往HBase表中put数据时，最终会调用`HRgion`中的`doMiniBatchMutate`方法，接下来的调用流程如下所示。

```java
//doMiniBatchMutate
//在此方法内，会先将修改写入到WAl中
// STEP 3. Build WAL edit
List<Pair<NonceKey, WALEdit>> walEdits = batchOp.buildWALEdits(miniBatchOp);

// STEP 4. Append the WALEdits to WAL and sync.
for(Iterator<Pair<NonceKey, WALEdit>> it = walEdits.iterator(); it.hasNext();) {
    Pair<NonceKey, WALEdit> nonceKeyWALEditPair = it.next();
    walEdit = nonceKeyWALEditPair.getSecond();
    NonceKey nonceKey = nonceKeyWALEditPair.getFirst();

    if (walEdit != null && !walEdit.isEmpty()) {
        writeEntry = doWALAppend(walEdit, batchOp.durability, batchOp.getClusterIds(), now,
               nonceKey.getNonceGroup(), nonceKey.getNonce(), batchOp.getOrigLogSeqNum());
	}
    
    // Complete mvcc for all but last writeEntry (for replay case)
    if (it.hasNext() && writeEntry != null) {
        mvcc.complete(writeEntry);
        writeEntry = null;
    }
}

//再将数据写入到Memstore中
writeEntry = batchOp.writeMiniBatchOperationsToMemStore(miniBatchOp, writeEntry);

//writeMiniBatchOperationsToMemStore
super.writeMiniBatchOperationsToMemStore(miniBatchOp, writeEntry.getWriteNumber());

//writeMiniBatchOperationsToMemStore
applyFamilyMapToMemStore(familyCellMaps[index], memStoreAccounting);

//applyFamilyMapToMemStore
region.applyToMemStore(region.getStore(family), cells, false, memstoreAccounting);

//applyToMemStore  修改或者添加分别走upsert add逻辑，其实差不多，这里以add为例
if (upsert) {
    store.upsert(cells, getSmallestReadPoint(), memstoreAccounting);
} else {
    store.add(cells, memstoreAccounting);
}

//add
this.memstore.add(cell, memstoreSizing);

//add  遍历Cells集合，对每一个cell进行处理
for (Cell cell : cells) {
    add(cell, memstoreSizing);
}

// add -> doAddOrUpsert -> doAdd
//第一步尝试去为Cell分配一个Chunk
Cell toAdd = maybeCloneWithAllocator(currentActive, cell, false);
//将Cell写入到Chunk中，并最终加入到ConcurrentSkipList对象中
internalAdd(currentActive, toAdd, mslabUsed, memstoreSizing);
```

从这里开始就分开了，先看下是如何分配Chunk对象的。

##### 2.1 分配Chunk

```java
//maybeCloneWithAllocator
currentActive.maybeCloneWithAllocator(cell, forceCloneOfBigCell);

//maybeCloneWithAllocator -> copyCellInto -> copyCellInto
private Cell copyCellInto(Cell cell, int maxAlloc) {
    //...
    Chunk c = null;
    int allocOffset = 0;
    while (true) {
        //开始分配一个Chunk
        c = getOrMakeChunk();
        
        //为Chunk申请内存空间
        if (c != null) {
            allocOffset = c.alloc(size);
            //一旦申请完毕，就跳出循环
            if (allocOffset != -1) {
                break;
            }
            //否则尝试重新分配
            tryRetireChunk(c);
        }
    }
    //将Cell中的数据拷贝到新申请的Chunk上
    return copyToChunkCell(cell, c.getData(), allocOffset, size);
}
```

###### 2.1.1 如何申请Chunk

> 这里的主要思路就是：
>
> 1 获取当前正在使用的Chunk对象，不为null，则表示已经申请到，直接返回
>
> 2 为null，表示当前环境中没有Chunk对象，需要申请 getChunk
>
> 3 创建一个Chunk对象，并为其分配指定大小的一段连续内存空间buf，默认2M，返回

**直接获取Chunk或创建一个Chunk**

```java


private Chunk getOrMakeChunk() {
    //currChunk代表当前正在使用的chunk对象的原子引用
    Chunk c = currChunk.get();
    
    //如果已经存在Chunk，那么直接返回Chunk对象即可
    if (c != null) {
        return c;
    }
    
    //如果Chunk为null，则需要从ChunkPool中申请新的Chunk，申请Chunk需要上锁
    if (lock.tryLock()) {
        try {
            // 类似于双重锁定，防止其他线程已经成功申请了Chunk
            c = currChunk.get();
            if (c != null) {
                return c;
            }
            
            //通过chunkCreator对象去创建Chunk       
            c = this.chunkCreator.getChunk(idxType);
            //Chunk创建成功之后，就会使用currChunk来引用，表示目前正在使用的chunk
            //同时，将创建的chunk放到Set集合chunks中
            if (c != null) {
                // set the curChunk. No need of CAS as only one thread will be here
                currChunk.set(c);
                chunks.add(c.getId());
                return c;
            }
        } finally {
            lock.unlock();
        }
    }
    return null;
}
```

**创建Chunk对象**

`ChunkCreator`创建Chunk的步骤如下

```java
//chunkCreator.getChunk -> getChunk -> getChunk  这里以DataChunk为例
//这里需要说明的是chunksize的默认大小为2M
//dataChunksPool前面已经说过了，dataChunksPool.getChunkSize()的值默认就是chunksize
Chunk getChunk(CompactingMemStore.IndexType chunkIndexType, ChunkType chunkType) {
    switch (chunkType) {
        case INDEX_CHUNK:
            if (indexChunksPool != null) {
                return getChunk(chunkIndexType, indexChunksPool.getChunkSize());
            }
        case DATA_CHUNK:
            if (dataChunksPool == null) {
                return getChunk(chunkIndexType, chunkSize);
            } else {
                return getChunk(chunkIndexType, dataChunksPool.getChunkSize());
            }
        default:
            throw new IllegalArgumentException(
                "chunkType must either be INDEX_CHUNK or DATA_CHUNK");
    }
}

//getChunk，创建Chunk对象，完成之后，对Chunk对象进行初始化工作
if (chunk == null) {
    chunk = createChunk(false, chunkIndexType, size);
}
chunk.init();
return chunk;

//这里根据配置，可以创建两种类型的Chunk，这里以OnheapChunk
private Chunk createChunk(boolean pool, CompactingMemStore.IndexType chunkIndexType, int size) {
    Chunk chunk = null;

    if (pool && this.offheap) {
        chunk = new OffheapChunk(size, id, pool);
    } else {
        chunk = new OnheapChunk(size, id, pool);
    }

    return chunk;
}

//OnHeapChunk -> Chunk 构造方法，至此创建一个成员变量size为2M的Chunk对象
//此时并没有 为Chunk对象分配2M的内存空间
//Chunk对象创建成功之后，借由上面的getChunk进行init工作，分配内存空间，并返回
public Chunk(int size, int id, boolean fromPool) {
    this.size = size;
    this.id = id;
    this.fromPool = fromPool;
}

//init   -> allocateDataBuffer
//在这里为Chunk持有的data开辟2M的内存空间
void allocateDataBuffer() {
    if (data == null) {
        data = ByteBuffer.allocate(this.size);
        data.putInt(0, this.getId());
    }
}
```

###### 2.1.2 从Chunk中申请内存空间，用于Cell数据的写入

> 主要思路
>
> 1 根据Cell，从已经申请到的Chunk对象中申请一段内存空间，用于Cell数据的存储
>
> 2 获取到Chunk的buf中已经使用的偏移量offset
>
> 3 Cell中的数据，写入到buf中的offset 至 (offset+size) 的位置

申请完chunk之后，接下来就是在已经申请的这个chunk中分配一段内存空间，用于存储当前cell。

```java
//copyCellInto
//先获取要写入的cell的大小
int size = Segment.getCellLength(cell);
//从已经申请的chunk中的分配一段内存空间，size的大小视Cell而定
allocOffset = c.alloc(size);

//alloc
public int alloc(int size) {
    while (true) {
        //先获取当前Chunk已经使用的偏移量
        int oldOffset = nextFreeOffset.get();
        //说明Chunk还在初始化，再等等啊再等等
        if (oldOffset == UNINITIALIZED) {
            Thread.yield();
            continue;
        }
        
        if (oldOffset == OOM) {
            // doh we ran out of ram. return -1 to chuck this away.
            return -1;
        }
		
        //当当前Chunk剩余的空间不足以盛放该Cell时，返回-1
        if (oldOffset + size > data.capacity()) {
            return -1; // alloc doesn't fit
        }
        
        //计算要写入的cell要占多少空间，预留下来，不再进行分配，同时返回chunk以使用的偏移量
        if (nextFreeOffset.compareAndSet(oldOffset, oldOffset + size)) {
            // we got the alloc
            allocCount.incrementAndGet();
            return oldOffset;
        }
    }
}
```

###### 2.1.3 Cell数据写入到Chunk的buf

分配完内存空间之后，就开始往Chunk中写入Cell数据了。

```java
//copyCellInto
return copyToChunkCell(cell, c.getData(), allocOffset, size);

//copyToChunkCell
//往Chunk（实际上是内部持有的的Buffer）中写入Cell数据
private static Cell copyToChunkCell(Cell cell, ByteBuffer buf, int offset, int len) {
    //先写入数据
    ((ExtendedCell) cell).write(buf, offset);
    
    //写入完成之后，包装成一个Chunk返回
    return createChunkCell(buf, offset, len, tagsLen, cell.getSequenceId());
}
```

**Cell数据写入过程**

```java
((ExtendedCell) cell).write(buf, offset);

//write
KeyValueUtil.appendTo(this, buf, offset, true);

//appendTo 
//实际的写入操作
public static int appendTo(Cell cell, ByteBuffer buf, int offset, boolean withTags) {
    //记录key的长度
    offset = ByteBufferUtils.putInt(buf, offset, keyLength(cell));// Key length
    //记录value的长度
    offset = ByteBufferUtils.putInt(buf, offset, cell.getValueLength());// Value length
    //记录key值包括时间戳、列族、列名这些信息，全部写入到key中
    offset = appendKeyTo(cell, buf, offset);
    //写入value的值
    offset = CellUtil.copyValueTo(cell, buf, offset);// Value bytes
    int tagsLength = cell.getTagsLength();
    if (withTags && (tagsLength > 0)) {
        offset = ByteBufferUtils.putAsShort(buf, offset, tagsLength);// Tags length
        offset = PrivateCellUtil.copyTagsTo(cell, buf, offset);// Tags bytes
    }
    return offset;
}
```

**基于已写入Cell数据的buf，封装新Cell对象**

当把Cell数据写入到buf中之后，接着封装成chunk Cell对象，并返回。

```java
//写入完成之后，包装成一个Chunk返回
return createChunkCell(buf, offset, len, tagsLen, cell.getSequenceId());

//createChunkCell
return createChunkCell(buf, offset, len, tagsLen, cell.getSequenceId());

//实际上就是基于写入数据的buf，再次将其封装为一个Cell对象，并返回
private static Cell createChunkCell(ByteBuffer buf, int offset, int len, int tagsLen,
                                    long sequenceId) {
    if (tagsLen == 0) {
        return new NoTagByteBufferChunkKeyValue(buf, offset, len, sequenceId);
    } else {
        return new ByteBufferChunkKeyValue(buf, offset, len, sequenceId);
    }
}
```

> **这里有个疑问，每写入一个cell，均会在这里new一个对象？那海量数据的写入，是否会导致内存激增？？？**

##### 2.2 将新Cell对象加入到Memostore中

封装成Cell对象返回之后，接下来就是将该cell对象加入到Memostore持有的`ConcurrentSkipListMap`中。

```java
private void doAdd(MutableSegment currentActive, Cell cell, MemStoreSizing memstoreSizing) {
    //申请Chunk，并往其中的buf中写入Cell数据，之后封装成新的Cell对象返回
    Cell toAdd = maybeCloneWithAllocator(currentActive, cell, false);
    
    if (!mslabUsed) {
      toAdd = deepCopyIfNeeded(toAdd);
    }
    
    //开始往Memstore中添加
    internalAdd(currentActive, toAdd, mslabUsed, memstoreSizing);
  }
```

主要流程如下：

```java
//internalAdd
currentActive.add(toAdd, mslabUsed, memstoreSizing, sizeAddedPreOperation);

//add
internalAdd(cell, mslabUsed, memStoreSizing, sizeAddedPreOperation);

//internalAdd
protected void internalAdd(Cell cell, boolean mslabUsed, MemStoreSizing memstoreSizing,
                           boolean sizeAddedPreOperation) {
    //将构建的cell添加到ConcurrentSkipListMap中
    boolean succ = getCellSet().add(cell);
    
    //接着就是更新元数据信息
    updateMetaInfo(cell, succ, mslabUsed, memstoreSizing, sizeAddedPreOperation);
}

//getCellSet().add(Cell)
public boolean add(Cell e) {
   //this.delegatee = new ConcurrentSkipListMap<>(c.getSimpleComparator());
    return this.delegatee.put(e, e) == null;
}

//todo
protected void updateMetaInfo()
```

