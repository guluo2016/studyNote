转自：[索引存储文件介绍](https://niyanchun.com/lucene-learning-7.html)



一个Lucene索引可能会包含多个segment，每个segment又包含多个文件，相同segment的索引文件的前缀是相同的，如下所示。

```shell
[root@master index]# ls
_12w_1.liv  _12w_Lucene50_0.doc  _1jc_1.liv  _1jc_Lucene50_0.doc  _1wx_1.liv  _1x7.cfs    _1xj_1.liv  _1xk.si   _2xe_Lucene50_0.doc  _2xo.cfe  _2y8.cfe  _2yl.cfe
_12w.dii    _12w_Lucene50_0.tim  _1jc.dii    _1jc_Lucene50_0.tim  _1wx.cfe    _1x7.si     _1xj.cfe    _2xe.dii  _2xe_Lucene50_0.tim  _2xo.cfs  _2y8.cfs  _2yl.cfs
_12w.dim    _12w_Lucene50_0.tip  _1jc.dim    _1jc_Lucene50_0.tip  _1wx.cfs    _1xi_1.liv  _1xj.cfs    _2xe.dim  _2xe_Lucene50_0.tip  _2xo.si   _2y8.si   _2yl.si
_12w.fdt    _12w_Lucene70_0.dvd  _1jc.fdt    _1jc_Lucene70_0.dvd  _1wx.si     _1xi.cfe    _1xj.si     _2xe.fdt  _2xe_Lucene70_0.dvd  _2xy.cfe  _2yk.cfe  segments_3
_12w.fdx    _12w_Lucene70_0.dvm  _1jc.fdx    _1jc_Lucene70_0.dvm  _1x7_1.liv  _1xi.cfs    _1xk.cfe    _2xe.fdx  _2xe_Lucene70_0.dvm  _2xy.cfs  _2yk.cfs  write.lock
_12w.fnm    _12w.si              _1jc.fnm    _1jc.si              _1x7.cfe    _1xi.si     _1xk.cfs    _2xe.fnm  _2xe.si              _2xy.si   _2yk.si
```

Lucen在存储segment时，有两种方式：

- **multifile模式**，这种模式下，每个segment会产生很多文件，每个文件均有不同的作用，存储不同的信息，这种模式存在的弊端就是在读取索引的时候，可能会打开很多个文件，造成在一台机器上打开的文件描述符达到上限。
- **compound模式**，这种模式下，每个segment产生的文件相较于multifile模式而言，比较少。其目的就是为了减少对文件描述符的使用。



在一个segment中，每个文件的作用如下：

1. `write.lock`：每个index目录都会有一个该文件，用于防止多个IndexWriter同时写一个文件。
2. `segments_N`：该文件记录index所有segment的相关信息，比如该索引包含了哪些segment。IndexWriter每次commit都会生成一个（N的值会递增），新文件生成后旧文件就会删除。所以也说该文件用于保存commit point信息。

**上面这两个文件是针对当前index的，所以每个index目录下都只会有1个（segments_N可能因为旧的没有及时删除临时存在两个）。下面介绍的文件都是针对segment的，每个segment就会有1个。**

3. `.si`：*Segment Info*的缩写，用于记录segment的一些元数据信息。
4. `.fnm`：*Fields*，用于记录fields设置类信息，比如字段的index option信息，是否存储了norm信息、DocValue等。
5. `.fdt`：*Field Data*，存储字段信息。当通过`StoredField`或者`Field.Store.YES`指定存储原始field数据时，这些数据就会存储在该文件中。
6. `.fdx`：*Field Index*，`.fdt`文件的索引/指针。通过该文件可以快速从`.fdt`文件中读取field数据。
7. `.doc`：*Frequencies*，存储了一个documents列表，以及它们的term frequency信息。
8. `.pos`：*Positions*，和`.doc`类似，但保存的是position信息。
9. `.pay`：Payloads*，和*`.doc`类似，但保存的是payloads和offset信息。
10. `.tim`：*Term Dictionary*，存储所有文档analyze出来的term信息。同时还包含term对应的document number以及若干指向`.doc`, `.pos`, `.pay`的指针，从而可以快速获取term的term vector信息。。
11. `.tip`：*Term Index*，该文件保存了Term Dictionary的索引信息，使得可以对Term Dictionary进行随机访问。
12. `.nvd`, `.nvm`：*Norms*，这两个都是用来存储Norms信息的，前者用于存储norms的数据，后者用于存储norms的元数据。
13. `.dvd`, `.dvm`：*Per-Document Values*，这两个都是用来存储DocValues信息的，前者用于数据，后者用于存储元数据。
14. `.tvd`：*Term Vector Data*，用于存储term vector数据。
15. `.tvx`：*Term Vector Index*，用于存储Term Vector Data的索引数据。
16. `.liv`：*Live Documents*，用于记录segment中哪些documents没有被删除。**一般不存在该文件，表示segment内的所有document都是live的。如果有documents被删除，就会产生该文件。以前是使用一个`.del`后缀的文件来记录被删除的documents，现在改为使用该文件了。**
17. `.dim`,`.dii`：*Point values*，这两个文件用于记录indexing的Point信息，前者保存数据，后者保存索引/指针，用于快速访问前者。

如果一个index的segment非常多，那将会有非常非常多的文件，检索时，这些文件都是要打开的，很可能会造成文件描述符不够用，所以Lucene引入了前面介绍的CFS格式，它把上述每个segment的众多文件做了一个合并压缩（`.liv`和`.si`没有被合并，依旧单独写文件），最终形成了两个新文件：`.cfs`和`.cfe`，前者用于保存数据，后者保存了前者的一个Entry Table，用于快速访问。所以，如果使用CFS的话，最终对于每个segment，最多就只存在`.cfs`, `.cfe`, `.si`, `.liv`4个文件了。Lucene从1.4版本开始，默认使用CFS来保存segment数据，但开发者仍然可以选择使用multifile格式。一般来说，对于小的segment使用CFS，对于大的segment，使用multifile格式。



**例子**

首先在ES中创建一个索引：

```json
PUT nyc-test
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "refresh_interval": -1
  }
}
```

复制

这里设置1个shard，0个副本，并且将refresh_interval设置为-1，表示不自动刷新。创建完之后就可以在es的数据目录找到该索引，es的后台索引的目录结构为：`<数据目录>/nodes/0/indices/<索引UUID>//index`，这里的shard就是Lucene的index。我们看下刚创建的index的目录：

```shell
-> % ll
总用量 4.0K
-rw-rw-r-- 1 allan allan 230 10月 11 21:45 segments_2
-rw-rw-r-- 1 allan allan   0 10月 11 21:45 write.lock
```

复制

可以看到，现在还没有写入任何数据，所以只有index级别的`segments_N`和`write.lock`文件，没有segment级别的文件。写入1条数据并查看索引目录的变化：

```shell
PUT nyc-test/doc/1
{
  "name": "Jack"
}

# 查看索引目录
-> % ll
总用量 4.0K
-rw-rw-r-- 1 allan allan   0 10月 11 22:20 _0.fdt
-rw-rw-r-- 1 allan allan   0 10月 11 22:20 _0.fdx
-rw-rw-r-- 1 allan allan 230 10月 11 22:19 segments_2
-rw-rw-r-- 1 allan allan   0 10月 11 22:19 write.lock
```

可以看到出现了1个segment的数据，因为ES把数据缓存在内存里面，所以文件大小为0。然后再写入1条数据，并查看目录变化：

```shell
PUT nyc-test/doc/2
{
  "name": "Allan"
}

# 查看目录
-> % ll
总用量 4.0K
-rw-rw-r-- 1 allan allan   0 10月 11 22:20 _0.fdt
-rw-rw-r-- 1 allan allan   0 10月 11 22:20 _0.fdx
-rw-rw-r-- 1 allan allan 230 10月 11 22:19 segments_2
-rw-rw-r-- 1 allan allan   0 10月 11 22:19 write.lock
```

因为ES缓存机制的原因，目录没有变化。显式的refresh一下，让内存中的数据落地：

```
POST nyc-test/_refresh

-> % ll
总用量 16K
-rw-rw-r-- 1 allan allan  405 10月 11 22:22 _0.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:22 _0.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:22 _0.si
-rw-rw-r-- 1 allan allan  230 10月 11 22:19 segments_2
-rw-rw-r-- 1 allan allan    0 10月 11 22:19 write.lock
```

ES的refresh操作会将内存中的数据写入到一个新的segment中，所以refresh之后写入的两条数据形成了一个segment，并且使用CFS格式存储了。然后再插入1条数据，接着update这条数据：

```
PUT nyc-test/doc/3
{
  "name": "Patric"
}

# 查看
-> % ll
总用量 16K
-rw-rw-r-- 1 allan allan  405 10月 11 22:22 _0.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:22 _0.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:22 _0.si
-rw-rw-r-- 1 allan allan    0 10月 11 22:23 _1.fdt
-rw-rw-r-- 1 allan allan    0 10月 11 22:23 _1.fdx
-rw-rw-r-- 1 allan allan  230 10月 11 22:19 segments_2
-rw-rw-r-- 1 allan allan    0 10月 11 22:19 write.lock

# 更新数据
PUT nyc-test/doc/3?refresh=true
{
  "name": "James"
}

# 查看
-> % ll
总用量 32K
-rw-rw-r-- 1 allan allan  405 10月 11 22:22 _0.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:22 _0.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:22 _0.si
-rw-rw-r-- 1 allan allan   67 10月 11 22:24 _1_1.liv
-rw-rw-r-- 1 allan allan  405 10月 11 22:24 _1.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:24 _1.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:24 _1.si
-rw-rw-r-- 1 allan allan  230 10月 11 22:19 segments_2
-rw-rw-r-- 1 allan allan    0 10月 11 22:19 write.lock
```

可以看到，再次refresh的时候又形成了一个新的segment，并且因为update，导致删掉了1条document，所以产生了一个`.liv`文件。但前面的这些流程中，segments_N文件也就是segments_2一直没有变过，这是因为一直没有Lucene概念中的commit操作发生过。ES的flush操作对应的是Lucene的commit，我们触发一次Lucene commit看下变化：

```
# 触发Lucene commit
POST nyc-test/_flush?wait_if_ongoing

# 查看目录
-> % ll
总用量 32K
-rw-rw-r-- 1 allan allan  405 10月 11 22:22 _0.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:22 _0.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:22 _0.si
-rw-rw-r-- 1 allan allan   67 10月 11 22:24 _1_1.liv
-rw-rw-r-- 1 allan allan  405 10月 11 22:24 _1.cfe
-rw-rw-r-- 1 allan allan 2.5K 10月 11 22:24 _1.cfs
-rw-rw-r-- 1 allan allan  393 10月 11 22:24 _1.si
-rw-rw-r-- 1 allan allan  361 10月 11 22:25 segments_3
-rw-rw-r-- 1 allan allan    0 10月 11 22:19 write.lock

# 查看segment信息
GET _cat/segments/nyc-test?v

index    shard prirep ip        segment generation docs.count docs.deleted  size size.memory committed searchable version compound
nyc-test 0     p      10.8.4.42 _0               0          2            0 3.2kb        1184 true      true       7.4.0   true
nyc-test 0     p      10.8.4.42 _1               1          1            2 3.2kb        1184 true      true       7.4.0   true
```

触发Lucene commit之后，可以看到segments_2变成了segments_3。然后调用`_cat`接口查看索引的segment信息也能看到目前有2个segment，而且都已经commit过了，并且compound是true，表示是CFS格式存储的。

**ES中的refresh和flush的区别：每次refresh，就会形成一个新的segment，默认情况下1s中fresh一次，segment一旦形成就不再改变，刚开始的时候是放在OS的缓存中，由OS确定何时刷新到磁盘；flush操作，会将缓存在OS Cache中的segment刷新到磁盘中，同时清空translog日志文件，默认情况下是30分钟flush一次，或者translog文件的大小达到512MB的时候也会触发flush操作。**

当然Lucene的segment是可以合并的。

**在ES中，内部会维护一个线程，定期合并segment，在合并segment的时候，那些被标记为删除的文档并不会合并到新生成的segment，因此ES（Lucene）中文档的真正删除时机就是此时。**

另外，我们也可通过ES的forcemerge接口进行合并，并且将所有segment合并成1个segment，forcemerge的时候会自动调用flush，即会触发Lucene commit：

```
POST nyc-test/_forcemerge?max_num_segments=1

-> % ll
总用量 60K
-rw-rw-r-- 1 allan allan  69 10月 11 22:27 _2.dii
-rw-rw-r-- 1 allan allan 123 10月 11 22:27 _2.dim
-rw-rw-r-- 1 allan allan 142 10月 11 22:27 _2.fdt
-rw-rw-r-- 1 allan allan  83 10月 11 22:27 _2.fdx
-rw-rw-r-- 1 allan allan 945 10月 11 22:27 _2.fnm
-rw-rw-r-- 1 allan allan 110 10月 11 22:27 _2_Lucene50_0.doc
-rw-rw-r-- 1 allan allan  80 10月 11 22:27 _2_Lucene50_0.pos
-rw-rw-r-- 1 allan allan 287 10月 11 22:27 _2_Lucene50_0.tim
-rw-rw-r-- 1 allan allan 145 10月 11 22:27 _2_Lucene50_0.tip
-rw-rw-r-- 1 allan allan 100 10月 11 22:27 _2_Lucene70_0.dvd
-rw-rw-r-- 1 allan allan 469 10月 11 22:27 _2_Lucene70_0.dvm
-rw-rw-r-- 1 allan allan  59 10月 11 22:27 _2.nvd
-rw-rw-r-- 1 allan allan 100 10月 11 22:27 _2.nvm
-rw-rw-r-- 1 allan allan 572 10月 11 22:27 _2.si
-rw-rw-r-- 1 allan allan 296 10月 11 22:27 segments_4
-rw-rw-r-- 1 allan allan   0 10月 11 22:19 write.lock


GET _cat/segments/nyc-test?v

index    shard prirep ip        segment generation docs.count docs.deleted  size size.memory committed searchable version compound
nyc-test 0     p      10.8.4.42 _2               2          3            0 3.2kb        1224 true      true       7.4.0   false
```

可以看到，force merge之后只有一个segment了，并且使用了multifile格式存储，而不是compound。当然这并非Lucene的机制，而是ES自己的设计。