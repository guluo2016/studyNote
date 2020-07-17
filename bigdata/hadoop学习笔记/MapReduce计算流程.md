MapReduce的计算阶段总体来说分为三个阶段：

Map阶段  --> shuffle阶段  --> reduce阶段

shuffle阶段从map阶段的输出开始，一直到reduce阶段的输入结束

shuffle阶段如果细分的话，包括对map的输出结果进行combine、



1. map任务从HDFS中读取数据，默认情况下，HDFS文件中的一个Block对对应一个map任务，当然也可以多个Block对应一个map任务

2. map任务读取数据，并进行计算之后，会得出map计算结果，map的数据结果最终是要发送给reduce进行reduce处理，但是由于MapReduce是一个分布式计算框架，map和reduce往往不是在同一个节点上处理的，一次map的输出结果往往会暂存在当前节点上，后面工reduce任务拉取作为reduce的输入数据

3. map任务的处理结果是K-V形式，输出的数据会首先写入到缓冲区中，达到一定条件之后，会将缓冲区中的数据溢写到磁盘中。
4. 缓冲区是一个幻想缓冲区，map的结果会序列化成字节数组，并不停的写入到这个缓冲区中，默认情况下，当写入数据量占缓冲区总容量的80%的时候，会启动一个线程，将缓冲区中的数据写入到磁盘中，在此过程中，并不阻塞map继续往缓冲区中写入数据，当剩下的20%空间也被写满后，map输出数据如果还没有写完的话，会阻塞等待写入线程将缓冲区的数据全部写入到磁盘并清空缓冲区之后，才能停止阻塞再次往缓冲区中写入数据。
5. 写入线程将数据写入到磁盘的时候，其路径由`mapreduce.cluster.local.dir`属性指定，在溢写的时候会依次进行如下过程：对输出结果进行分区、分区内对K-V进行排序，会首先按照某种规则对K-V进行排序（比如以key为标准进行排序），如果设置了Combine的话对K-V数据进行combine、如果设置了压缩的话对K-V数据进行压缩、对溢写文件进行归并操作。
   - 分区：在将缓存区中的数据写入磁盘之前，均会以K-V为参数，调用`getPartition()`函数，默认情况下，是计算Key的hash值，并基于reduce的个数对这个hash值进行取模操作。`getPartition()`值一样的K-V放在同一个分区中，将来会将其发到同一个reduce任务中进行处理。
   - Combine：combine的作用实际上就是对单个的map结果进行reduce操作，在MR术语中称之为combine。如在wordcount的MR任务中，一个map的输出结果是`<word,1>, <word,1>,<cup,1>`,设置了combine的话，会对输出的数据进行reduce操作，即`<word,2>,<cup,1>`,这样做的目的是可以有效减少map的数据输出量，将来reduce来拉取更少的数据即可获取到完整的数据，从而减少了网络带宽；另外数据量少了，IO就会加快。从而从整体上来减少MR的计算时间。
   - 压缩：其目的也是为了减少数据量，减少IO，减少网络带宽，从而缩短MR的计算时间。
   - map任务完成之后，会对产生的所有临时溢写文件进行merge操作并生成正式的输出文件，map任务执行过程中，可能会生成很多溢写文件，相同的key可能存在于多个溢写文件中，merge的作用就是将相同分区的K-V合并到一起，就在分区内按照一定规则在对其进行一次排序（默认是按照Key值进行排序的）。

6. map阶段的任务完成，进行reduce shuffle阶段
7. 不定的从各个map阶段去拉取属于自己的分区中的数据，并将从各个map节点中拉取的数据进行merge，合并成一个分区相同的大文件，然后对文件中的K-V数据按照某种规则进行排序（默认按照key执行进行排序），排序完成之后还会对K-V数据进行分组，之后才将该文件传给reduce进行处理。
   - reduce copy数据：一个reduce可以对应于一个分区，也可以对应于多个分区。根据实际情况将不同节点的map输出数据属于自己处理的分区中的数据拉取到本地。
     - **这里涉及到一个reduce何时开始拉取数据？由于一个MR任务中可能有多个map，至少有一个map任务结束，reduce的Copy就可以开始**。
     - **map任务结束后，输出数据放在节点本地，reduce如何知道一些文件的位置？map任务结束之后，会将信息告知AM，reduce在copy之前会先和AM沟通，获取到必要信息之后，在去对应的节点Copy数据源**。
     - reduce在Copy的时候，是启动一些专门的线程去拉取数据的，为了加快拉取数据的速度，reduce可以并行去Copy数据，默认情况下，reduce是启动5个线程去Copy数据，用户可以通过`mapreduce.reduce.shuffle.parallelcopies`属性去配置线程数。
   - reduce的merge：reduce从不同map节点拉取的数据会首先放到reduce节点的缓冲区中，这个缓冲区的大小是基于JVM的Heap size来设定的，这是因为此时reduce任务还没运行，JVM的内存可以更多的倾向于缓冲区。一旦缓冲区中的数据达到一定的阈值之后，也是会溢写到磁盘上的。
     - 和map一样，在溢写的时候如果设置了combine的话，会进行combine操作。
     - 其内存缓冲区的阈值可以通过属性`mapred.job.shuffle.input.buffer.percent`来配置，默认是JVM堆内存的70%。
   - reduce的Sort：reduce从map节点Copy数据完成之后，可能会在reduce节点生成多个文件。此时会将这些文件整体进行一次merge，并且基于某种规则进行排序，最终形成一个整体有序的输出文件。由于在整体merge之前，各个临时文件也是有序的，因此该阶段的排序默认是基于归并排序算法来进行的，并且是基于key值进行排序的。
   - reduce的分组：基于上面的整体有序的文件，在根据某种规则对K-V数据进行分组，默认基于key值执行分组，相同的key值分成一组，最终形成`<key,key对应的values的迭代器>`，如`<hello，{1,1,1,1}>`。当然也可以通过`job.setGroupingComparatorClass()`方法设置自定义的分组方式。

8. reduce计算，MR计算框架将分组后的数据做为输入参数，传递给reduce任务，有多少个分组这个reduce方法就被调用多少次。

   - reduce函数的格式：输入参数就是分组后的一组key以及随对应的迭代器。

     ```java
     protected void reduce(KEYIN key, Iterable<VALUEIN> values, Reducer<KEYIN, VALUEIN, KEYOUT, VALUEOUT>.Context context) throws IOException, InterruptedException {
         ...
     }
     ```

   - reduce将数据处理完毕之后，就得到了我们想要的结果，可以通过`FileOutputFormat.setOutputPath(job,new Path(outputPath))`来控制结果的输出位置，默认是输出到HDFS上的。

​           reduce函数的格式：输入参数就是分组后的一组key以及随对应的迭代器。

MapReduce的计算阶段总体来说分为三个阶段：

Map阶段  --> shuffle阶段  --> reduce阶段

shuffle阶段从map阶段的输出开始，一直到reduce阶段的输入结束