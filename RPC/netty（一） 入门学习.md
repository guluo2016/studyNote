## netty 入门
使用Java NIO就可以进行高性能网络编程，但是利用jdk原生的NIO API的话，在编程的时候必须很小心，需要自己来规避一些可能的异常情况，如：epoll bug问题就是其中之一，理论上想Selector注册的所有Channel都没有IO操作的话，Selector.select（）将会被阻塞，直至有Channel有IO操作，但是epoll bug可能会使得即使没有Channel进行IO操作的时候，执行select()被阻塞的线程也会被唤醒，从而使得CPU空转，造成资源浪费； 另外利用原生NIO编程的话，代码复杂繁重，导致编写的代码非常不简洁，代码多了不可避免的增大了引入新bug的可能性。

在这种情况下，大神们设计了netty框架，它基于Java NIO，但是对Java 原生的nio进行了封装，并且想人所想，对一些易引入bug的地方提前做了规避；简化了网络编程，降低其复杂程度；代码少了，引入bug的可能性也就少了。总的来说，netty框架就是在网络编程的时候，替我们把一些脏活累活给承包了，然后使得程序员们可以以一种很舒服的方式来进行网络编程。当然了，即使不适用netty框架，仅仅使用Java NIO也是可以编写一个优秀的高性能的网络程序，但是对于我这种没有丰富NIO编程经验的新手而言，还是喜欢站在巨人的肩膀上往前走。

### 1 编写Server程序

1.声明两个线程池：group，worker，group负责接收客户端的连接，worker负责处理客户端过来的请求
```
EventLoopGroup group = new NioEventLoopGroup();
EventLoopGroup worker = new NioEventLoopGroup();
```

2.创建一个启动类对象
```
ServerBootstrap serverBootstrap = new ServerBootstrap();
```

3.借助ServerBootstrap为服务端程序添加相关配置
```
//绑定线程池
serverBootstrap.group(group,worker)
    //绑定服务端的Channel
    .channel(NioServerSocketChannel.claa)
    //绑定本地端口8888
    .localAddress(new InetSocketAddress(8888));
    //绑定handler，hanler负责处理业务逻辑，可以自定义
    .childhandler(new ChildChannelHandler());
```

4.编写业务处理类,客户端的请求了，应该怎么处理，在这里写
```
public class ChildChannelHandler extends ChannelInboundHandlerAdapter {
    //重写channelRead（）方法，在收到客户端传过来的消息的时候，netty会自动调用该方法
    public void channelRead(ChannelHandlerContext ctx,Object msg) throws Exception{
        //和Java NIO上的ByteBuffer差不多，但是netty提供的ByteBuf功能更加强大，使用也方便
        ByteBuf in = (ByteBuf)msg;
        System.out.println("接收到客户端的消息是：" + in.toString(CharsetUtil.UTF_8));
        String str = "你好，netty，这是Server端返回的响应";
        ByteBuf resp = Unpooled.copiedBuffer(str.getBytes(CharsetUtil.UTF_8));
        //写到输出流中，传给客户端
        ctx.write(resp);
    }
    
    //在channelRead完成后，netty会自动调用该方法
    public void channelReadComplete(ChannelHandlerContext ctx,Object msg) throws Exception{
        //将换区中的数据刷至传输流中，传给客户端
        ctx.flush();
    }
    
    //在发生异常的时候，netty会自动调用
    public void exceptionCaught(ChannelHandlerContext ctx,Throwable cause) throws Exception{
        ctx.close();
    }
}
```

5.调用同步阻塞方法，等待客户端过来的连接请求
```
//ChannelFuture可以获取线程异步执行后的结果
ChannelFuture future = serverBootstrap.bind().sync();
```

6.等待服务端监听的端口关闭
```
//一直阻塞mian线程，直至ServerSocketChannel关闭之后
//这样可以保证main线程最后结束
future.channel().closeFuture().sync();
```

7.关闭线程池,避免资源浪费
```
group.shutdownGracegully().sync();
worker.shutdownGracegully().sync();
```

8.完整代码
```
public ServerNetty{
    public static void main(String[] args){
        EventLoopGroup group = new NioEventLoopGroup();
        EventLoopGroup worker = new NioEventLoopGroup();
        try{
            ServerBootstrap serverBootstrap = new ServerBootstrap();
            serverBootstrap.group(group,worker)
                .channel(NioServerSocketChannel.claa)
                .localAddress(new InetSocketAddress(8888));
                .childhandler(new ChildChannelHandler());
            ChannelFuture future = serverBootstrap.bind().sync();
            future.channel().closeFuture().sync();
        }finally{
            group.shutdownGracegully().sync();
            worker.shutdownGracegully().sync();
        }
    }
}
```

### 2 编写Client程序
客户端程序和服务端程序差不多一样。

1.编写客户端处理类
```
public class ClientHandler extends SimpleChannelInboundHandler(ByteBuf){
    //收到服务器传过来的数据之后，netty自动调用此方法
    public void channelRead0(ChannelHandlerContext ctx,ByteBuf byteBuf) throws Exception{
        System.out.println("收到服务器传过来的数据：" + byteBuf.toString(CharsetUtil.UTF_8));
    }
    
    //连接建立成功之后，netty自动调用此方法
    public void channelActive(ChannelHandlerContext ctx){
        //这里想服务器发送个消息
        ctx.writeAndFlush(Unpooled.copiedBuffer("hello，Netty",CharsetUtil.UTF_8))；
    }
    
    //在发生异常的时候，netty会自动调用
    public void exceptionCaught(ChannelHandlerContext ctx,Throwable cause) throws Exception{
        ctx.close();
    }
}
```

看完整代码：
```
public ClientNetty{
    public static void main(String[] args){
        //客户端只需要一个线程池就行了，因此客户端不需要监听连接
        EventLoopGroup group = new NioEventLoopGroup();
        try{
            /**
            *这个地方和服务端不一样
            *但是想想Java网络编程，就会明白
            *服务端对应的是ServerSocket，客户端ServerSocket
            */
            Bootstrap bootstrap = new Bootstrap();
            
            serverBootstrap.group(group,worker)
                .channel(NioServerSocketChannel.claa)
                //绑定要连接的远程服务器的IP 端口号
                .localAddress(new InetSocketAddress(localhost,8888));
                .handler(new ChildInitializer<SocketChannel>(){
                    //重写方法，用户绑定handler,处理业务逻辑
                    protected void initChannel(SocketChannel socketChannel) throws Exception{
                        socketChannel.pipeline().addLast(new ClinetHandler());
                    }
                });
            ChannelFuture future = bootstrap.bind().sync();
            future.channel().closeFuture().sync();
        }finally{
            group.shutdownGracegully().sync();
        }
    }
}
```
完成。

### 3 参考资料   
**《Netty 权威指南》**
