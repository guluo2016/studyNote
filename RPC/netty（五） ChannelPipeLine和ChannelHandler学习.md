## ChannelPipeline和ChannelHandler学习
根据java NIO思想，不管是从文件中读写数据还是从网络中读写数据，都是借助于一个Channel来进行的。   
即：File <--> Channel <--> 程序  
在netty框架中，netty将Channel的数据管道（Channel中包含很多信息）抽象成一个ChannelPipeline，用于描述数据在管道中的流入流出。类比Java Web中的Filter和拦截器，可以在消息最终到达目的地之前可以对消息进行一个过滤和处理，那么netty框架中的消息在ChannelPipeline中流动和传递的时候，也是可以加一些“拦截器”对消息进行拦截并进行加工，在netty框架中起拦截消息作用的就是ChannelHandler。

### 1 ChannelPipeLine
ChannelPipeline是对数据管道的一个抽象，数据要想从网络达到程序或者从程序达到网络，必须经过ChannelPipeline才可以。   
但是在前面的例子中并没有直接绑定ChannelPipeline，从前面的描述当中可以猜测ChannelPipeline和Channel有关，因此可以猜想当绑定Channel的时候，可能也绑定了ChannelPipeline，即，当创建NioServerSocketChannel对象的时候会随带着创建一个ChannelPipeline对象，那么可以先看看当创建NioServerSocketChannel的时候都干了什么事情。会发现当创建NioServerSocketChannel对象的时候，会首先执行父类构造器，那么一直找，会发现会先执行NioServerSocketChannel的父类AbstractChannel的构造器。
```
//实例化NioServerSocketChannel
public NioServerSocketChannel(java.nio.channels.ServerSocketChannel channel) {
    super((Channel)null, channel, 16);
    this.config = new NioServerSocketChannel.NioServerSocketChannelConfig(this, this.javaChannel().socket());
}

//父类
protected AbstractNioMessageChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
    super(parent, ch, readInterestOp);
}

//父类
protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
    super(parent);
    ...
}

//父类
protected AbstractChannel(Channel parent) {
    this.parent = parent;
    this.unsafe = this.newUnsafe();
    this.pipeline = this.newChannelPipeline();
}
```
从这里可以发现，当创建一个NioServerSocketChannel对象的时候，会首先创建一个ChannelPipeline对象（DefaultChannelPipeline是ChannelPipeline的子类）：
```
//创建一个双向链表
protected DefaultChannelPipeline(Channel channel) {
    this.channel = (Channel)ObjectUtil.checkNotNull(channel, "channel");
    this.tail = new DefaultChannelPipeline.TailContext(this);
    this.head = new DefaultChannelPipeline.HeadContext(this);
    this.head.next = this.tail;
    this.tail.prev = this.head;
}
```
这个双向链表上的节点其实就是一个个的ChannelHandler。

因此，可以这么说，当客户端向服务端发送一个连接请求，或者客户端与服务端建立一个网络连接进行IO操作的时候，会首先创建一个Channel，前者创建的时NioServerSocketChannel,后者会创建一个NioSocketChannel，不管是何种Channel，在创建Channel对象的时候，会首先创建一个ChannelPipeline对象用于描述数据传输通道，并将其作为Channel的一个属性；在创建ChannelPipeline对象的时候，其内部又创建了一个双向链表，用于存储多个ChannelHandler，在数据从CHannelPipeline中流动的时候，对其进行拦截并进行加工或者处理。   
它们之间的关系如图所示：  
![](../image/rpc/Channel，ChannelPipeline和ChannelHandler的关系.jpg)

### 2 inbound事件和outbound事件
在netty框架中，事件整体可以分为两大类inbound事件和outbound事件，inbound事件对应的就是链路的建立，读操作，链路关闭，异常通知等事件；outbound事件对应的是发起IO操作，写操作，绑定，消息发送等事件，虽然只有这两类，但是有时候会记不住，这个时候可以类比Java IO中的输入输出流，inbound事件基本上都是从通道中拿数据，相当于in；outbound基本上都是往通道里发送数据，因此相当于out。

在netty框架中，当inbound事件发生时，会触发以下方法： 
```
ChannelInboundHandler.fireChannelRegistered()    //Channel注册的时候会被调用
ChannelInboundHandler.fireChannelActive()      //TCP链路建立成功时，会被调用
ChannelInboundHandler.fireChannelRead(Object)   //读事件发生时调用
ChannelInboundHandler.fireChannelReadComplete()   //读事件完成的时候调用
ChannelInboundHandler.fireException()     //发生异常的时候会被调用
ChannelInboundHandler.fireUserEventTriggered(Object)  //用户自定义事件发生的时候被调用
ChannelInboundHandler.fireChannelInactive()   //TCP链路关闭的时候会被调用
ChannelInboundHandler.fireChannelWritabilityChanged()  //写状态变化事件时被调用
```
以上这些方法
在netty框架中，当outbound事件发生时，会触发以下方法：
```
ChannelOutboundHandler.bind（）   //bind事件
ChannelOutboundHandler.connect    //连接事件
ChannelOutboundHandler.write()   //写操作事件
ChannelOutboundHandler.read()    //读事件
ChannelOutboundHandler.flush()    //刷新事件
ChannelOutboundHandler.disconnect()   //断开连接事件
ChannelOutboundHandler.writeAndFlush   
ChannelOutboundHandler.deregister()  //注销
ChannelOutboundHandler.close()    //关闭事件
```

*有点疑惑：就是read事件的时候为什么outbound事件所属方法被调用？没有理解*    

ChannelHandler相当于一个拦截器，对数据进行加工和处理，但是如果没有触发事件的话，这些ChannelHandler是不会被执行的，我想这就是学习inbound事件和outbound事件的原因吧。

### 3 ChannelHandler
ChannelHandler相当与Java Web应用的拦截器，在请求到来前后和响应回去前后，进行连接做一些我们自己想要它做的操作，通常情况一个ChannelHandler仅仅会处理特定的事件，对于其他事件它是不处理的，会交给下一个ChannelHandler处理，比如：在Channel上发生读操作时，想及时获取客户端传过来的消息，并做必要的处理等等。

由于netty中事件分为inbound事件和outbound事件，而handler又是因事件而出发的，因此handler是分类的：能够被inbound事件触发的handler，能够被outbound事件触发的handler，能够被inbound和outbound事件触发的handler

就像netty（一）中的例子那样，如果关注与inbound事件的话，那么就可以集成ChannelInboundHandlerAdapter类，并重写对应的方法，比如当channel注册事件发生时，想进行一些处理，那么就重写channelRegistered()方法即可，在Channel注册的时候会自动调用该方法，那么重写的业务逻辑就会被执行。

当需要关注于多个事件的时候，为了保证ChannelHandler的专注性，可以建立多个ChannelHandler，然后添加到Pipeline中的那个双向链表中，当数据从通道流动的时候，依据事件会因此触发这个双向链表中的各个handler。

### 4 ChannelHandler的触发流程
#### 4.1 handler处理outbound事件流程
bind(）事件，当该Channel上bind事件发生之后，因为bind事件时outbout事件，会找到该Channel中的那个handler构成的双向链表，从尾节点开始，一次查找每一个Handler，如果发现这个handler能够处理outbound事件，那么，调用基于这个handler对象调用bind()方法，如果这个handler使我们自己新建的handler，并且重写了其中的bind()方法，那么根据多态就会执行我们自己重写的业务逻辑，因此就会按照我们自己的意志来完成一些操作。   
来看看代码：
```
//1
serverBootstrap.bind();

//2
serverBootstrap.doBdind();

//3
private static void doBind0(final ChannelFuture regFuture, final Channel channel, final SocketAddress localAddress, final ChannelPromise promise) {
    //这里会调用一个NioEventLoop线程去执行bind操作
    channel.eventLoop().execute(new Runnable() {
        public void run() {
            if (regFuture.isSuccess()) {
                //调用的时Channel的bind()方法
                channel.bind(localAddress, promise).addListener(ChannelFutureListener.CLOSE_ON_FAILURE);
            } else {
                promise.setFailure(regFuture.cause());
            }

        }
    });
}

...

//调用Channel所属的pipeline的bind()方法
public ChannelFuture bind(SocketAddress localAddress, ChannelPromise promise) {
    return this.pipeline.bind(localAddress, promise);
}

//从这里可以看出来，会从pipeline中的双向链表中找，
//入口是tail即尾节点
public final ChannelFuture bind(SocketAddress localAddress, ChannelPromise promise) {
    return this.tail.bind(localAddress, promise);
}

//上面也已经解释过了
public ChannelFuture bind(final SocketAddress localAddress, final ChannelPromise promise) {
    if (localAddress == null) {
        throw new NullPointerException("localAddress");
    } else if (this.isNotValidPromise(promise, false)) {
        return promise;
    } else {
        //找到能够处理outbound事件的handler
        final AbstractChannelHandlerContext next = this.findContextOutbound();
        EventExecutor executor = next.executor();
        if (executor.inEventLoop()) {
            next.invokeBind(localAddress, promise);
        } else {
            safeExecute(executor, new Runnable() {
                public void run() {
                    next.invokeBind(localAddress, promise);
                }
            }, promise, (Object)null);
        }

        return promise;
    }
}

//执行handler的invokeBind
private void invokeBind(SocketAddress localAddress, ChannelPromise promise) {
    if (this.invokeHandler()) {
        try {
            //这里就会执行hendler的bind()方法，如果重写了的话，就会执行我们重写的bind
            ((ChannelOutboundHandler)this.handler()).bind(this, localAddress, promise);
        } catch (Throwable var4) {
            notifyOutboundHandlerException(var4, promise);
        }
    } else {
        this.bind(localAddress, promise);
    }

}
```

#### 4.2 handler处理inbound事件流程
以链路建立为例，前面已经说过了，在Server端创建了两个线程池NioEventLoop，其中AbstractBootstrap.parentGroup用于监听端口，在启动的时候会创建一个ServerNioSocketChannel通道，一旦这个Channel通道建立的时候就会出发
```
serverBootstrap.bind();

//serverBootstrap.initAndRegister
final ChannelFuture initAndRegister() {

    ChannelFuture regFuture = this.group().register(channel);
}

//调用NioEventLoopGroup中的register
 public ChannelFuture register(Channel channel) {
    return this.next().register(channel);
}

//调用NioEventLoop的register
public ChannelFuture register(Channel channel, ChannelPromise promise) {
    if (channel == null) {
        throw new NullPointerException("channel");
    } else if (promise == null) {
        throw new NullPointerException("promise");
    } else {
        channel.unsafe().register(this, promise);
        return promise;
    }
}

//AbstractUnsafe.register -> AbstractUnsafe.register0
private void register0(ChannelPromise promise) {
    try {
        if (!promise.setUncancellable() || !this.ensureOpen(promise)) {
            return;
        }

        boolean firstRegistration = this.neverRegistered;
        AbstractChannel.this.doRegister();
        this.neverRegistered = false;
        AbstractChannel.this.registered = true;
        AbstractChannel.this.pipeline.invokeHandlerAddedIfNeeded();
        this.safeSetSuccess(promise);
        //Channel注册事件触发
        AbstractChannel.this.pipeline.fireChannelRegistered();
        if (AbstractChannel.this.isActive()) {
            if (firstRegistration) {
                //链路建立成功事件，触发此方法
                AbstractChannel.this.pipeline.fireChannelActive();
            } else if (AbstractChannel.this.config().isAutoRead()) {
                this.beginRead();
            }
        }
    } catch (Throwable var3) {
        this.closeForcibly();
        AbstractChannel.this.closeFuture.setClosed();
        this.safeSetFailure(promise, var3);
    }

}
```
### 5 总结
SocketChannel包含pipeline，pipeline包含handler，它们的关系就是这样，客户端与服务端交互的时候实际上走的就是SocketChannel中的Pipeline，在数据流动的过程中会形成一个个的事件，并依次会触发pipeline中的handler，handler会根据事件，触发不同的方法。

因此，我们可以通过重写handler，将我们定义的业务逻辑加到这里面，在合适的时机被执行。

netty框架中的事件有inbounf事件和outbound事件，如果我们对inbound事件感兴趣的话，那么可以继承ChannelInboundHandler,并重写其中的特定动作能够触发的方法，比如我们对inbound事件中的读事件感兴趣，那么就可以重写channelRead()方法，从通道中读取客户端传过来的数据。如果对outbound事件感兴趣，可以继承ChannelOutboundHandler，并重写其中的特定动作能够触发的方法。


### 6 参考资料
**《Netty权威指南》**
