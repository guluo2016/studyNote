## EventLoop学习

昨天我开始学习netty框架，写了一个小例子，今天学习下其中比较重要的技术之一：EventLoop。

netty是基于Java NIO的框架，昨天学习的时候（包括前天学习Java NIO的时候）一直在想，当服务器线程没有客户端连接请求或者通道中没有IO操作的时候，就会陷入阻塞，一旦有感兴趣的动作发生的时候，线程就会被重新唤醒，继续执行，那么阻塞的线程为什么能够在事件发生的时候被唤醒？这里实际上是用到了Reactor模型（事件驱动）。

### 1 Reactor模型
Reactor是一个事件驱动模型，当没有任何IO操作的时候，线程调用Selector.select()方法将会被阻塞，让出CPU。一旦IO来临之后，也就意味着线程等待的资源来了，那么线程自然就会从阻塞状态转为就绪状态，一旦获得CPU的话，那么线程就会重新执行，此时select()方法的返回值将是一个大于0的整数。

#### 1.1 Reactor单线程模型
服务端：由一个线程来处理客户端传过来的所有连接。这个线程既要处理客户的连接请求，还要处理服务端与客户端之间的IO操作。由于是基于Java NIO的，所有即使线程在进行IO的时候，也不会阻塞。

客户端：负责向服务端发送连接请求，以及与服务端进行IO操作。

对于服务端而言，由于Java NIO的非阻塞性，理论上一条线程确实是可以处理所有客户端传过来的所有请求以及IO操作。但是：  
**摘自《Netty 权威指南》**：  
一个java NIO线程负载过多的时候，会知道其自身性能的下降，它处理请求、IO的速度回变得很慢。于是人们提出了Reactor多线程模型。

#### 1.2 Reactor多线程模型
客户端没有什么大的变化。

服务端：创建两类线程，处理连接的线程和处理IO的线程。

其中处理连接的线程是一个，专门用于创建监听服务器端口，等待接受客户顿传过来的连接请求。    
处理IO的线程是一组，由一个线程池来负责维护。当客户端和服务端建立SocketChannel连接之后，都会注册到其中一个线程负责的Selector上，每个线程都可以处理多个SocketChannel连接。

这样可以很好的缓解前面单线程模型存在的问题，每个IO线程负责有限的SocketChannel，这样既可以提高提高线程的处理能力，又不会使得它由于负载过多导致性能下降。

但是如果一个应用的连接数很多的话，负责处理连接的线程也会负载过重，导致线程性能下降。于是又有了主从Reactor多线程模型。

#### 1.3 主从Reactor多线程模型
和Reactor多线程模型，区别就是，负责连接的不再是一个线程，而是也是一组线程来负责，并且交由一个线程池来维护这些线程，其他的没有区别。

### 2 Netty的线程模型
netty完全支持上面所说的三种reactor线程模型，对于服务器端而言，它会创建两个线程池：
```
//线程池，里面的线程负责连接
EventLoopGroup group = new NioEventLoopGroup();
//线程池，里面的线程负责IO
EventLoopGroup worker = new NioEventLoopGroup();
```
这两个线程池里面维护的线程是：NioEventLoop。NioEventLoop并不是一个简单的线程，它还是ScheduledExecutorService的子类。  
作为Netty框架下的线程，NioEventLoop负责处理两件事情：连接，网络IO。它实际上内部封装了Selector，SocketChannel，然后对上层透明。因此它内部会首先调用select()方法，阻塞等待连接时间、IO事件。在NioEventLoop的run方法中，可以看到：
```
//阻塞,等待事件
this.select(this.wakenUp.getAndSet(false));
this.processSelectedKeys();


//processSelectedKeys()方法
private void processSelectedKeys() {
    if (this.selectedKeys != null) {
        this.processSelectedKeysOptimized();
    } else {
        this.processSelectedKeysPlain(this.selector.selectedKeys());
    }
}

...
```
根据源码，以及《Netty权威指南》的介绍，会发现NioEventLoop干了一下几件事情（源码上太绕了，所以看了资料）：  
1.select()阻塞等待事件来临   
2.事件来临之后，唤醒，执行连接、IO操作（以IO操作为例）   
3.获取对应的SelectionKey事件   
4.获取对应的Channel通道   
5.建立一个缓冲区，从Channel中写数据到缓冲区中，此处应用java NIO，非阻塞   
6.程序获取数据   

**Netty 规避bug**  

从上面可以看出来，netty中的NioEventLoop实际上是对Java Nio网络编程的一系列动作进行封装，简化了编程。   

另外，昨天学习提到的epoll bug问题，netty的NioEventLoop也对其做了规避，源码没有仔细看，但是看《Netty 权威指南》上面还是详细说明了，NioEventLoop会探测在某一时间段内，如果CPU连续发生了N次空转的话，那么就认为发生了epoll bug，那么NioEventLoop认为此时的这个Selector对象就不可用了，为此那么新建一个Selector对象，并把注册在原来的那个Selector上的SocketChannel全部转移到新建的这个Selector对象上，然后销毁出现问题的那个Selector对象。

### 3 参考资料
**《Netty 权威指南》**