## 1 背景
这个背景在dubbo的官网上有写，是英文的；网上也有很多人将其翻译成中文。

大致意思就是dubbo是应实际需求诞生的，根据互联网系统的演进过程来看，刚开始的时候，是一种单一用用框架，这个时候，系统中的所有功能模块是部署在同一节点上的；后来随着流量的不断增大，逐渐演化出了分布式系统，这个时候各个功能模块分属于不同的节点，这些节点有的甚至不在一个物理区域内，每个节点都是一个子系统，可以独立运行，作为服务中心提供服务，在此过程中，就出现了一个问题，各个子节点之间可能存在交互，如节点A需要调用节点B所提供的方法，这个时候就不能像调用本地方法那样直接调用了，因为两个应用不在同一个进程空间内。需要考虑网络传输、对方是否有此方法等等一系列问题。

这个时候人们提出了RPC，远程过程调用，基于此，当A需要调用B上的方法的时候，就可以像调用本地方法那样调用，RPC为我们屏蔽了底层的一些细节，极为方便。Dubbo就是一个实现RPC的框架。

##2 Dubbo的例子
###2.1 部署Zookeeper
使用dubbo框架，需要首先部署一个zookeeper，用户作为注册中心，不管是远程过程调用者，还是远程过程提供者，只要想基于Dubbo框架进行服务，就必须在Zookeeper上先注册。

下载Zookpeer包，修改zookeeper目录下conf/下的配置文件zoo_simple.cfg名字，修改成zoo.cfg,否则启动不了，原因是启动Zookeeper的时候，会自动去conf目录下读取zoo.cfg配置文件。  
启动Zookeeper,切换到zookeeper目录下的bin目录中，
```
./zkServer.sh start  //启动
./zkServer.sh stop 关闭
```

### 2.2 编写一个服务提供程序
编写一个接口：
```
public interface DemoService {

    String sayHello(String name);

}
```
然后编写该借口的实现类：
```
public class DemoServiceImpl implements DemoService{
    public String sayHello(String name) {
        return "Hello " + name;
    }
}
```
编写spring配置文件：
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://code.alibabatech.com/schema/dubbo http://code.alibabatech.com/schema/dubbo/dubbo.xsd">

    <bean id="demoService" class="com.dubbo.provider.DemoServiceImpl"></bean>

    <!--给该服务起个名字-->
    <dubbo:application name="anyname_provider"></dubbo:application>

    <!--把服务注册到Zookeeper中-->
    <dubbo:registry address="zookeeper://127.0.0.1:2181"></dubbo:registry>

    <!--协议配置，由服务提供者指定，消费者被动接受;使用dubbo协议在20880端口暴露服务-->
    <dubbo:protocol name="dubbo" port="20880" />

    <!--生命对外提供服务的借口-->
    <dubbo:service interface="com.dubbo.provider.DemoService"
                   ref="demoService" />
</beans>
```
开启服务：
```
public class ServerClient {
    public static void main(String[] args) throws IOException {
    	//读取配置文件
        ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("server.xml");
        //启动
        context.start();
        System.out.println("app run");
        System.in.read();
    }
}
```

### 2.3 编写一个服务消费者程序
编写spring配置文件
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:dubbo="http://code.alibabatech.com/schema/dubbo"
       xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd http://code.alibabatech.com/schema/dubbo http://code.alibabatech.com/schema/dubbo/dubbo.xsd">

    <dubbo:application name="consumer_app" />

    <dubbo:registry address="zookeeper://127.0.0.1:2181" />

    <dubbo:consumer timeout="5000" />

    <dubbo:reference id="demoService" interface="com.dubbo.provider.DemoService" />
</beans>
```
启动服务消费者:
```
public class ConsumerClient {
    public static void main(String[] args) {
        ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("consumer.xml");
        context.start();
        DemoService demoService = (DemoService) context.getBean("demoService");
        //此时调用的实际上是服务提供者端的方法，但是服务消费者感觉想调用本地程序一样
        String result = demoService.sayHello("dubbo");
        System.out.println(result);
    }
}
```
## 3 技术
dubbo是一个优秀的RPC框架，咨询考虑了一下，在进行远程调用的时候，会涉及到哪写技术？   
1. 消息服务者调用了远程的方法，感觉想是调用本地方法一样，此处是使用代理模式，对远程服务进行一个代理，从而屏蔽了底层细节。

2. 进行远程调用的时候，会进行网络传输，有时候传输的参数还可能是一个Java对象，dubbo内部是使用netty框架来进行网络消息传输    
2.1 netty框架在使用的是NIO技术
2.2 netty框架在网络传输的时候，涉及到序列化与反序列化的技术
