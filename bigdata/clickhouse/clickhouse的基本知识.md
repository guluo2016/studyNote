#### MergeTree

MergeTree及其变种是clickhouse最常用的表存储引擎。MergeTree是一个完全列式的存储系统。

有几个重要的概念：

主键，默认情况下和排序键一致（order by）,对于主键，clickhouse会为其构建一个主键稀疏索引primary.idx，所谓稀疏的意思，就是并不是表中的主键列的所有数据均为出现该稀疏索引文件中，而是按照固定的间隔行数来进行记录的，这个间隔行数由index_granularity配置控制，默认是8192行，进行一次记录。   
主键稀疏索引实际上记录的是主键字段所在的行与其他列对应行的关系
clickhouse中，允许主键列的数据存在重复

clickhouse针对每一列，均会创建两个文件mrk文件和bin文件

mrk文件，列标记文件，用于记录数据在bin文件中的偏移量  
bin文件，数据文件，通常以压缩的方式进行存储  


primary.idx、mrk、bin文件的关系

mrk文件中的行与primary.idx文件是一一对应的，同样也是每index_granularity行采集一次，不同的是mrk文件中记录的是该列对应行数据在bin文件中偏移量 
primary.idx根据主键index_granularity行采集一次，记录主键列对应数据所在的行号

查询过程

如查询`select name from person where age >= 20 `，假设表为person，主键列为age  
在进行查询时，clockhouse会首先打开primary.idx文件，找到age>=20的行，并确定他们的行号；然后根据确定的行号打开对应name列的mrk文件，找到这些行在bin文件中的偏移量；最后根据偏移量打开bin文件，并直接跳转到bin文件的对应位置，读取相关的数据即可。


对于clickhouse而言，他采取类似于HBase的LSM机制，每一次的数据从内存刷新到磁盘，都伴随着一个新文件的产生，如此往复，会造成后台的小文件后多。MergeTree会在后台开启一个merge线程，当小文件达到一定数量的时候，该merge线程就会开始讲这些小文件合并成一个大的文件，这也就是MergeTree名字的由来。