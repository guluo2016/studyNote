## Java IO
程序运行过程中不可避免的需要同磁盘打交道，有的时候资源可能还不在本地，这个时候还可能借助于网络，不管是和本地磁盘还是通过网络与远程磁盘交互，有必须用到IO，因此Java IO还是非常重要的。  
另外，基于Java IO又扩展了NIO，NIO又是netty框架的基础，netty框架又是dubbo框架的重点之一，因此有必要从根源学习一下Java IO。

在Java程序中，对磁盘操作可以分成两个类型：对文件整体进行操作和对文件中的内容进行操作两类。 
### 1 对文件进行操作
Java 提供了File类，基于该类可以对文件进行操作：创建文件、删除文件，修改文件名字等等。 
File类讲不同平台上的文件和目录进行统一封装，使我们感受不到底层平台的差异，并且以面向对象的思想来操作文件，注意利用File类并不能对文件内部就行修改。 
```
//将目标文件封装成一个File对象，并且屏蔽底层平台的差异
File file = new File(file_path)
//对文件进行操作
//删除、创建、重命名文件
file.delete();
file.craeteNewFile();
file.renameTo();
//获取文件的名字，获取文件的路径
file.getName()；
file.getPath();
...
```
### 2 对文件内部内容进行操作
这个才是重点，os中文件用于存放数据，程序运行的时候需要数据，就必须打开文件，从文件中读取所需数据，或者向文件中写入数据。  
Java IO是借助于流的概念从文件中读写数据。  
通过流，程序从文件中获取数据；   
通过流，程序向文件中写入数据。   
只要是通过Java 程序从文件中获取数据（不管这个文件在哪里，也不管以何种方式打开文件），最终都是通过流来进行数据交互的。  

根据流中数据单元的不同，Java提供了两种流：字符流和字节流，字符流中的数据的最小单元是字符，字节流中的最小单元是字节。 
根据流的流向的不同，Java提供了两种流：输入流和输出流，输入流是把文件中的数据读入到流中，形成一个输入流，为下一步程序读取数据做准备；输出流是程序把数据写入到流中，形成一个输出流，为下一步往文件中写数据做准备。

基于以上概念，Java提供了几个关于IO的基类：InputStream,OutputStream,Reader,Writer,分别是以字节为单位的输入输出流，和以字符为单位的输入输出流。  
下面学习下这些流的主要实现类。

#### 2.1 文件流
文件作为盛放数据的载体，很多时候，程序都需要从文件中读取数据，或者往文件中写入数据。   
对文件进行操作，往往借助于两个实现类：
`FileInputStream,FileOutputStream,FileReader,FileWriter`分别是上面四个基类的实现类。 
```
//以字节为单位
InputStream inputStream = new FileInputStream(file)  //基于目标文件创建一个输入流，可以将文件中的内容读出来
OutStream outStream = new FileOutputStream(file) //基于目标文件创建一个输出流，可以向文件中写入数据
//以字符为单位
Reader reader = new FileReader("/home/guluo/test.txt");
Writer writer = new FileWriter("/home/guluo/test.txt");
```
#### 2.2 缓冲流
IO速度是很慢的，貌似地球人都知道，人们也都在努力缩小IO速度与cpu速度之间的巨大差距。为了提高Java IO的速度，提出了缓冲区，当从文件中读写数据的时候，会首先将目标数据放入到缓冲区中，读取数据的时候，是把文件中的数据放入到缓冲区中暂存，写数据的时候，也是把程序产生的数据放入到缓冲区中暂存，这样可以有效缓解IO与CPU之间因速度而产生的矛盾。  
基于缓冲流的实现类是：`BufferedInputStream,BufferedOutputStream,BufferedReader,BufferedWriter`，分别是上面四个基类的实现类。  
需要说明一点，因为缓冲区实际上是套在流上的（data---流---buffer---cpu，data---buffer---流---文件），因此想使用缓冲流，需要确定目标是谁才行。  

```
//以字符为单位，缓冲区的目标是FileReader流和FileWriter流
BUfferedReader bufferReader =  BufferedReader(new FileReader("/home/guluo/test.txt"));
BufferedWriter bufferedWriter = new BufferedWriter(new FileWriter("/home/guluo/test.txt"));
//以字节为单位，
BufferedInputStream bufferedInputStream = new BufferedInputStream(new FileInputStream("/home/guluo/test.txt"));
BufferedOutputStream bufferedOutputStream = new BufferedOutputStream(new FileOutputStream("/home/guluo/test.txt"));
```
#### 2.3 转换流
文件中存放的数据可能是数字，也可能是文件，如果是文字的话，可能是西文，也可能是中文、日文、韩文，而且不同操作系统的默认编码格式不同，导致文件的编码格式也会不一样，如Ubuntu默认的是utf-8，Windows会根据国家地区，如在中国默认编码格式是gbk。  
并且Java默认是以utf-8格式从文件中读取数据的，如果这个时候文件的编码格式是gbk，那么就会产生乱码问题，为了解决这个问题，在读取非西文数据的时候，需要额外指定以何种编码格式来读取数据。    
另外，如果一个字节流中全部是字符的话，那么以字符方式来处理效率更高。
转换流可以提供了一套标准，在我们读入、写入数据的时候，可以按照我们自定义编码格式来进行，而且还可以将字节流转换成字符流：`InputStreamReader,OutputStreamWriter`
```
//将目标字节流转换成字符流，转换的时候按照指定编码格式进行
Writer writer =  OutputStreamWriter(OutputStream out,String charsetName)
```
#### 2.4 标准输入输出流

标准输入输出流有：标准输入流、标砖输出流；System.in是一个未经过包装的InputStream，因此如果向通过标准输入输入数据的话，必须进行二次封装才行，不能够直接使用：  
```

Scanner in=new Scanner(System.in);
```
而System.out和System.err是经过包装之后的输出流：PrintStream。标准输入输出可以允许我们从屏幕介入输入数据或者向屏幕输出数据,使用标准输出，因为该流已经被包装过了，因此可以直接使用，向屏幕输出数据。