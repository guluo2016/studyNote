## ServerBootstrap学习

ServerBootstrap是一个启动辅助类，和普通Java网络编程一样，它的服务端和客户端所有的启动类是有一点差别的。Java网络编程中服务端用的是ServerSocket，而客户端使用的是Socket。和这个进行类比，netty框架的服务端和客户端使用的启动类辅助分别是：
```
ServerBootstrap
Bootstrap
```
ServerBootstrap虽然是辅助类，但是也很重要，因为没有它的话，通过ServerBootstrap对NioEventLoopGroup的绑定，就可以顺利对NioEventLoopGroup进行相关操作，比如借助NioEventLoopGroup启动NioEventLoop线程池中的线程。

从前面编写的入门例子，也可以看出来了，ServerBootstrap主要干的事情有：   
1.绑定线程池EventLoopGroup，为EventLoopGroup中的EventLoop工作提供前提条件
2.绑定Channel，这一步主要就是为了将Channel注册到对应的EventLoop上，使其进行监控
3.绑定handler，hanler负责处理业务逻辑，我们可以自定义
4.启动线程池EventLoopGroup，开始提供服务

### 1 绑定线程池EventLoopGroup
netty完全支持Reactor模型，为了使服务端以更加高效的方式提供服务，最好使用主从Reactor多线程模型，因此需要绑定创建两个EventLoopGroup线程池，一个负责连接，一个负责IO操作，然后将其绑定到ServerBootstrap。
```
serverBootstrap.group(group,worker);

public ServerBootstrap group(EventLoopGroup parentGroup, EventLoopGroup childGroup) {
	//调用父类的group方法
    super.group(parentGroup);

    //在这里，worker直接赋值，说明负责IO工作的线程池是由ServerBootstrap直接确定的
    this.childGroup = childGroup;
}

//父类AbstractBootstrap的group方法
public B group(EventLoopGroup group) {

	//这里确定负责连接的线程池
    this.group = group;
}
```

### 2 绑定Channel
在这里直接使用的是NioServerSocketChannel：
```
serverBootstrap.channel(NioServerSocketChannel.class);

//调用channel
public B channel(Class<? extends C> channelClass) {
 	
 	//看名字就知道channel工厂，肯定是用来创建Channel的
 	//这里程序使用的是NioServerSocketChannel，因此这个工厂会创建一个NioServerSocketChannel对象
    return this.channelFactory(new AbstractBootstrap.BootstrapChannelFactory(channelClass));
}
```

### 3 绑定handler，拦截并处理具体的业务逻辑
。。。

### 4 启动
启动很简单，就是调用bind()方法，既可：
```
//启动，并且绑定本地端口号，group中的线程就是监控这个端口号，
//来查看是否有连接过来
bootstrap.bind(port)

//这里会创建一个InetSocketAddress对象，并与指定端口绑定
public ChannelFuture bind(int inetPort) {
    return this.bind(new InetSocketAddress(inetPort));
}

//经过一系列调用，会跑到这个方法这里
private ChannelFuture doBind(final SocketAddress localAddress) {
	
	//执行1
    final ChannelFuture regFuture = this.initAndRegister();
    
    //执行2
    AbstractBootstrap.doBind0(regFuture, channel, localAddress, (ChannelPromise)promise);
           
}

//1
final ChannelFuture initAndRegister() {
	//通过Channel工程创建一个Channel，就是上面程序指定的那个NioServerSocketChannel
    Channel channel = this.channelFactory().newChannel();
    
    //初始化channel
    this.init(channel);

    //this.group会返回一个NioEventLoop对象
    //register会把channel对象注册到这个NioEventLoop中的Selector对象上
    ChannelFuture regFuture = this.group().register(channel);

    //返回异步结果
    return regFuture;
}

//2
private static void doBind0(final ChannelFuture regFuture, final Channel channel, final SocketAddress localAddress, final ChannelPromise promise) {

	//启动线程，开始等待连接
    channel.eventLoop().execute(new Runnable() {
        public void run() {
            if (regFuture.isSuccess()) {
                channel.bind(localAddress, promise).addListener(ChannelFutureListener.CLOSE_ON_FAILURE);
            } else {
                promise.setFailure(regFuture.cause());
            }

        }
    });
}
```
ok

注：另外Bootstrap的方式和ServerBootstrap启动方式基本一样，可以类比ServerSocket和Socket。