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
public final Buffer flip() {
	limit = position;
	position = 0;
	mark = -1;
	return this;
}
```

因此操作缓冲区的步骤：
1.往缓冲区中写数据
2.buffer.flip()
3.从缓冲区中读取数据
2.清空缓冲区（clear()/compact()）

### 3 Selector
在学习过程中，Selector更多的是用于网络连接方面，和本地文件的IO倒是没有看到应用Selector的例子。  

传统的服务器监听连接方式：  
1.服务器开启一个线程，监听客户端发来的请求，一旦有用户请求来临之后，就进行相关处理，由于IO是阻塞IO，导致线程需要花大量时间等待IO操作（从网络传输流中读写数据），等把这个请求处理完毕并给用户返回响应之后，在进行处理下一个连接。这中系统一旦用户多那么一点点，就可能够受不了了，因为一次只能处理一个用户的请求，显然不能够满足需求。   
2.为了解决这个问题，人们又设计了另外一种方式，就是一个线程一直不断地监听连接，一旦又连接来临时，就开启一个线程，专门为这个一个用户负责，来几个用户就开启几个线程，这样就是其中一个线程因为IO阻塞了，也不为影响其他线程的数据处理，大大提高了系统的数据处理能力。但是这也存在一个问题，就是一个线程只为一个用户负责未免显得有点浪费，因为不断的创建、销毁线程是很耗费资源的，另外一台服务器也不能无限制创建线程（一个系统能够创建的线程总数是有限的），这导致了在用户量巨大的情况下，如果每个用户的IO时间很长的话，后来的用户将迟迟得不到处理。  

这归根究底都是IO速度太慢给闹的(网络上的可能是由于数据迟迟穿不过来)，但是直接采用非阻塞IO，可能又会读取不到数据（上面说过），基于以上两个方面的考虑，人们提出了Selector。

Selector可以用于管理Channel，此时Channel需要向Selector进行注册，只有注册之后，Selector才会真正的去管理Channel。一个Selector可以管理多个通道，Selector通过select()方法不断的轮休这些Channel，当所有的Channel上都没有IO操作的时候，select()会阻塞，当注册在Selector上的Channel至少有一个需要进行IO操作的是偶，正在执行select()方法的线程将会被唤醒，并且返回一个整数，代表有几个Channel需要进行IO操作。

这样的话，每当有用户连接时，就会创建一个SocketChannel，并将其注册到Selector上。服务器只需要开启一个线程就可以处理多个用户连接：这条线程执行Selector，如果没有连接，阻塞，有连接的话，建立通道并注册到Selector上，交由Selector管理，Selector不管轮询注册在其上的Channel，有IO操作的话，就进行处理，当数据没有完全到来的时候也可以处理，此时read操作非阻塞不需要等待，立即返回，这样就可以使得一条线程处理多个用户，大大提高了线程的数据处理能力，也减轻了服务器端的压力。（netty框架据说可以一条线程处理成千上完个用户连接，还没有学习到，到时候看看是如何做到的）

这种方式，实际上就是把传统的多条线程阻塞转嫁到一条线程阻塞上了，一旦有IO操作就不再阻塞，进行数据处理。

获取Selector对象：
```
Selector selector = Selector.open();
```

在向Selector注册的时候，可以设置Selector需要关注Channel上的什么动作，有以下几种：  
```
SelectionKey.OP_CONNECT    //关注连接
SelectionKey.OP_ACCEPT     //呜呜呜
SelectionKey.OP_READ       //关注读IO
SelectionKey.OP_WRITE      //关注写IO
```
注册方法：
```
//Selector关注Channel的读IO操作
channel.register(selector,Selectionkey.OP_READ);
//当对于同一个Channel需要关注多个动作的时候
channel.register(selector,Selectionkey.OP_READ | SelectionKey.OP_WRITE);
```
一旦Channel有关注的动作发生，那么select()停止阻塞，并返回一个整数，这个时候可以调用：
```
//返回有IO动作的类型的集合
Set<SelectionKey> keys = selector.selectedKeys()；
//便利集合，获得集合中一个元素key，通过可以获取发生IO动作的对应的Channel
ServerSocketChannel server =(ServerSocketChannel) key.channel();
//基于该通道，根据Channel上的动作进行读、写、建立连接等等IO操作
...
```

具体代码：
```
Selector selector = Selector.open();
ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
ServerSocket serverSocket = serverSocketChannel.socket();
serverSocket.bind(new InetSocketAddress(8888));
serverSocketChannel.configureBlocking(false);
serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT | SelectionKey.OP_READ);

while (selector.select() > 0){
    Set<SelectionKey> keys = selector.selectedKeys();
    for (SelectionKey key : keys){
        selector.selectedKeys().remove(key);  //手动移除，Selector不会自动帮忙移除的
        if (key.isAcceptable()){
            ServerSocketChannel server = (ServerSocketChannel) key.channel();
            //建立一个用户连接
            SocketChannel socketChannel = server.accept();
            socketChannel.register(selector,SelectionKey.OP_READ);
        }

        //...
    }
}
```

### 4 参考资料
[java NIO详解](http://www.importnew.com/22623.html):http://www.importnew.com/22623.html       
[Java NIO系列教程（三） Buffer](http://ifeve.com/buffers/):http://ifeve.com/buffers/      
[Java NIO系列教程（六） Selector](http://ifeve.com/selectors/):http://ifeve.com/selectors/    
