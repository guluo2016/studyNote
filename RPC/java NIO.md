## Java NIO
昨天学习的Java IO是传统的IO，使得程序与存放在磁盘上的文件能够很方便的进行交互。但是它也存在一定的问题，问题的根源在于速度，由于磁盘IO速度远远小于CPU处理速度，这导致程序在进行IO操作的时候，不得不进行阻塞线程，等待IO操作完成。  
在这种情况下，想象一种场景，如果一个线程除了进行IO操作之外，还有其他重要的事情需要处理（给用户响应，并且不是IO的内容），但是现在遇到了IO，就必须停下来等IO，完了之后才进行下一步的操作，这有时候会使得用户觉得这个程序的处理速度太慢了，不能接受。

Java IO就是一种阻塞IO，当它遇到read和write操作的时候，就想愚公一样，非要把这件事情完成才行，否则誓不罢休（一直阻塞在那里）。这在程序中有时候可能并不是必须的，有时候可能需要快速返回借口，不要阻塞（原因是我还有其他事情要处理呢，等不起），这个时候就需要设计一种非阻塞IO，于是提出了Java NIO，可以称之为新IO，也可以称之为非阻塞IO。

Java NIO在进行read和write操作的时候，并不阻塞，会立即返回。以读操作为例，如果缓冲区中正好有目标数据，那么立马拿过来，并返回；如果缓冲区中没有数据，也立马返回，只不过此时读取的数据为空而已。因为没有阻塞，所以线程继续往下执行，完成其他业务。  
Java NIO的非阻塞设计模式，也存一定的缺点，就是如果IO的数据是线程必须的数据的话，按照这种模式，可能使得线程不能继续执行，因为可能读取的是空。这个时候就需要设计一个循环，不断的从缓冲区中读取数据，直至读到线程所需数据。因此在Java NIO下，也可以使用阻塞模式，具体是通过Channel来实现的


Java NIO中有三个非常重要的对象：Buffer、Channel和Selector，分别学习下。
### 1 Channel
channel是一个通道，它和Java IO中的流很像，用于连接文件实体。Java通过NIO来从文件中读写数据的时候，必须建立一个通道，通过这个通道将数据写入到文件中，或者从文件中读取数据。  
这里需要注意一点，Channel不能够直接被程序操作，channel中要么和文件打交道（网络上的资源也看做文件），要么和缓冲区打交道，除此之外，其他对象不能喝Channel交互。   

Channel有两种模式，一种是非阻塞模式，在这种方式下，read和write操作都会立即返回不等待，当然了有的时候需要阻塞，Channel也实现了阻塞模式，在此模式下，read和write操作都是会阻塞的。FileChannel就是一种阻塞模式，SocketChannel既有阻塞模式又有非阻塞模式。

Channel可以是双向的，也就是通过该通道既可以往文件中写入数据，也可以从文件中读取数据。  
*下面这段话摘自：[java NIO详解](http://www.importnew.com/22623.html):http://www.importnew.com/22623.html*   
**通道可以是单向或者双向的。一个 channel 类可能实现定义read( )方法的 ReadableByteChannel 接口,而另一个 channel 类也许实现 WritableByteChannel 接口以提供 write( )方法。实现这两种接口其中之一的类都是单向的,只能在一个方向上传输数据。如果一个类同时实现这两个接口,那么它是双向的,可以双向传输数据。  
每一个 file 或 socket 通道都实现全部三个接口。从类定义的角度而言,这意味着全部 file 和 socket 通道对象都是双向的。这对于 sockets 不是问题,因为它们一直都是双向的,不过对于 files 却是个问题了。我们知道,一个文件可以在不同的时候以不同的权限打开。从 FileInputStream 对象的getChannel( )方法获取的 FileChannel 对象是只读的,不过从接口声明的角度来看却是双向的,因为FileChannel 实现 ByteChannel 接口。在这样一个通道上调用 write( )方法将抛出未经检查的NonWritableChannelException 异常,因为 FileInputStream 对象总是以 read-only 的权限打开文件。**

所有的Channel对象都不能通过构造器来获得，必须通过相应的流来获取。
```
//获取FileChannel
FileChannel fileChannel = new FileInputStream("/home/guluo/test.txt").getChannel();
FileChannel fileChannel = new RandomAccessFile("/home/guluo/test.txt", "rw").getChannel();
```
通道主要的几种有：
```
FileChannel          // 可以从文件中读写数据
DatagramChannel      //可以从UDP连接中读写数据
SocketChannel        //可以从TCP连接中读写数据
ServerSocketChannel  //用于监听TCP连接，一旦有连接来了之后，接受连接，并创建一个SocketChannel 
```

### 2 Buffer
缓冲区是程序和通道之间的桥梁，程序有数据要写入文件的时候，会首先将数据写入到缓冲区中，之后在由缓冲区与Channel交互，将这些数据写入到文件中，反过来就是讲Channel从文件中读取的数据先放到缓冲区中，之后程序从缓冲区中拿数据。  

缓冲区类型,基本上就是按照Java类型来分的，很容易记忆：
```
ByteBuffer
MappedByteBuffer
CharBuffer
DoubleBuffer
FloatBuffer
IntBuffer
LongBuffer
ShortBuffer
```

获取缓冲区对象的方法：
```
//获取以字节缓冲区对象
ByteBuffer byteBuffer = ByteBuffer.allocate(48);
```

Java NIO中的缓冲区实际上一块内存区域，Java将其封装成对象，并提供一组方法，供我们来操作这个缓冲区。 缓冲区有几个关键属性：capacity,limit,position,mark。

**capacity**  
capacity表示的是一块缓冲区的总容量，它一旦被设定好之后就不在变化。

**position**
表示当前指针位置，缓冲区目前所处的状态不同，它所表示的含义也不同，当在往缓冲区中写入数据的时候，position只想最后写入的位置；当从缓冲区中读取数据的时候，position表示目前已经读到哪个位置了。

**limit**
冲区目前所处的状态不同，它所表示的含义也不同，当在往缓冲区中写入数据的时候，limit表示缓冲区还有多少未用空间；当从缓冲区中读取数据的时候，limit表示的是在读数据之前，最后写入数据的位置。

**mark()/reset()**
mark在对缓冲区进行操作过程中，对缓冲区打个标记点，在继续对缓冲区操作一会，调用reset()方法，就会使得position指向到刚刚打标记点的那个位置。

**缓冲区的状态**
缓冲区有两种状态，写状态和读状态，当之前一直在往缓冲区中写入数据，此时想从缓冲区中读取数据，此时不能够直接调用get()方法，必须首先调用flip（）进行缓冲区翻转，之后才能够读取。
```
//一直在写数据
...
//首先翻转
buffer.flip();
//读取数据
buffer.get()
```
原因：从缓冲区中读取数据是根据position来读取的。当一直写数据的时候，position会不断变化，一直指向当前正在操作的位置，此时想从缓冲区中读取数据的话，不翻转直接读，那么读取position的下一位，要么是脏数据要么就没有数据，为了避免这种情况，NIO设计师们设计不翻转直接读的时候会报错。  
调用flip()之后,limit的值将会置为position，position将会置为0。然后在将缓冲区清空或者清空已经读取的数据位置，为下一次往缓冲区中写入数据腾出位置。
```
```

因此操作缓冲区的步骤：
1.往缓冲区中写数据
2.buffer.flip()
3.从缓冲区中读取数据
2.清空缓冲区（clear()/compact()）
