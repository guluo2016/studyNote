**activeMQ综述**

<!-- MarkdownTOC -->

- 1 JMS
- 2 activeMQ架构
	- 2.1 p2p模式
	- 2.2 Pub/Sub模式
- 3 activeMQ的使用场景
- 4 active使用方法

<!-- /MarkdownTOC -->


### 1 JMS

jms是Java message service,java消息服务，其诞生背景：

在没有JMS的时候,服务器与客户端进行通信的方式是直接通信，造成的结果就是服务端模块与客户端模块之间产生紧耦合；另外在没有JMS的时候，服务端程序与客户端程序进行通信是一对一模式（如果群发的话就是和多个客户端模块进行通信）

为了解决以上所述的不足，提出了JMS，JMS规定了一套标准，具体就是：客户端和服务端通信的时候不要直接通信，消息发给第三方，接受者从这个第三方手里读取消息，这样就使得客户端与服务端解耦，有利于开发。
具体到JMS中，就是消息发送者将消息发送给MQ（消息队列，也就是刚刚所说的第三方），消息接受者从MQ中读取消息，这样可以做到消息发送者和接受者互相解耦，面向MQ进行编程，使得模块与模块之间区分的更加明显。

*JMS的架构就是这么简单*

### 2 activeMQ架构

active就是根据JMS标准实现的一套Java消息中间件，目的就是使得模块与模块之间解耦，**MQ被称为解耦神器**。activeMQ就是消息发送者将消息发送给MQ，消息接受者（可能是一个也可能是多个）从MQ中获取消息。
消息接受者从MQ中接收消息可以

通过activeMQ发送消息，可以发送给一个消息接受者（p2p模式），也可以发送给多个消息接受者（Pub/sub模式）

#### 2.1 p2p模式

就是消息发送者发送一条消息，只能被一个消息接受者接收，一旦该消息被其中一个消息接受者接收，那么意味着该消息失效，其他消息接受者不能再接收此消息

#### 2.2 Pub/Sub模式

消息发送这发送一条消息，可以被多个消息接受者接收。

### 3 activeMQ的使用场景

试想一下，现在有两个功能模块A和B，如果A产生变化之后B需要也随之变化,并且A和B不强相关

**不用activeMQ**

A发生变化之后，主动调用B（目的通知B该变化了），但是如果一旦在调用B的过程中发生异常或者调用时间太长，不仅B的变化没有完成，A也会因此陷入异常状态

**用activeMQ**

A发生变化之后，将需要B改变的消息发送给MQ，之后A继续自己的工作，B在合适的时候以合适的方式从MQ中获知需要自己改变的消息，然后改变自己。

从上面的场景可以看出来，使用activeMQ不仅可以使得模块之间解耦，而且还可以提高系统效率（A无须等待B完成再去干其他事情）


**activeMQ不适用场景**

但是activeMQ并不是放之四海而皆准，他有他的适用场景，如果功能模块之间存在同步关系，activeMQ就不适用。
还以Ａ和Ｂ两个功能模块为例说明，A需要在B模块结果的基础上进行相关操作，此时A主动调用B，快速产生结果的方式就会更好一点。

就是说A与B存在依赖关系，且调用者依赖被调用者的结果，此时activeMQ不适用。

### 4 active使用方法

1. 创建ConnectionFactory工厂对象
2. 通过ConnectionFactory工厂对象创建Connection对象，该对象代表了应用程序与MQ消息服务器之间的通信链路
3. 创建Session对象，用于发送和接收消息`connection.createSession()`
4. 创建Destination对象，用于指定消息发送和接收的目标,`session.createQueue()/session.createTopic()`
5. 创建消息发送者和消息接受者 `session.createProducer()/session.createConsumer`
5. 发送/接收消息`MessageProducer.send()/MessageConsumer()` 
6. 释放连接 `connection.close()`


