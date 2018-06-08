## Servlet的声明周期

### 1 Servlet实例化
实例化Servlet的时机：
- 启动web容器的时候
- 启动web容器后规定的时间内
- 第一次请求该Servlet的时候

当在web.xml文件中配置`<load-on-startup>时，会在规定的时间内实例化Servlet；当没有配置该属性时，在第一次请求该Servlet时对其进行实例化，当Servlet开始实例化时，会首先调用Servlet中的init()方法，该方法在整个Servlet声明周期中仅仅调用一次。

看一个例子：

重写Servlet中的init()方法：
```
@Override
public void init() throws ServletException {
    super.init();
    System.out.println("正在调用该init方法");
}
```

**在web.xml指定启动时间**
在web.xml中配置`<load-on-startup>0</load-on-startup>`，会在web容器启动时实例化Servlet，来看看结果：
```
Connected to server
[2018-06-08 04:47:32,198] Artifact web_test:war exploded: Artifact is being deployed, please wait...
六月 08, 2018 4:47:32 下午 org.apache.catalina.deploy.WebXml setVersion
警告: Unknown version string [3.1]. Default version will be used.
**正在调用该init方法**
[2018-06-08 04:47:32,920] Artifact web_test:war exploded: Artifact is deployed successfully
[2018-06-08 04:47:32,920] Artifact web_test:war exploded: Deploy took 722 milliseconds
```
在web.xml中没有指定时间，那么在第一次请求来临时，实例化Servlet，看看结果：
```
//启动的时候并没有实例化Servlet
Connected to server
[2018-06-08 04:49:32,422] Artifact web_test:war exploded: Artifact is being deployed, please wait...
六月 08, 2018 4:49:32 下午 org.apache.catalina.deploy.WebXml setVersion
警告: Unknown version string [3.1]. Default version will be used.
[2018-06-08 04:49:33,229] Artifact web_test:war exploded: Artifact is deployed successfully
[2018-06-08 04:49:33,229] Artifact web_test:war exploded: Deploy took 807 milliseconds
六月 08, 2018 4:49:42 下午 org.apache.catalina.startup.HostConfig deployDirectory
信息: Deploying web application directory /opt/apache-tomcat-7.0.73/webapps/manager
六月 08, 2018 4:49:42 下午 org.apache.catalina.startup.HostConfig deployDirectory
信息: Deployment of web application directory /opt/apache-tomcat-7.0.73/webapps/manager has finished in 115 ms
//第一次请求来临时，开始实例化
**正在调用该init方法**
```
### 2 业务处理
当Servlet实例化之后，并且有对应请求需要处理时，该Servlet对象就会调用service()方法进行具体的业务逻辑处理
注意：HttpServlet对service()进行重写，在该方法内会根据请求方法的不同(GET,POST...)调用不同的doXxx()方法进行处理，并生HttpResponse对象返回给用户。

这里进行模拟一下：
重写service()方法：
```
@Override
protected void service(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
    super.service(req, resp);
    System.out.println("正在执行service()方法");
}
```
当请求过来后，结果：
```
正在调用该init方法
[2018-06-08 05:01:28,956] Artifact web_test:war exploded: Artifact is deployed successfully
[2018-06-08 05:01:28,956] Artifact web_test:war exploded: Deploy took 612 milliseconds
//请求过来后
正在执行service()方法
```
### 3 注意
Servlet对象处理完用户请求后，并不会死亡，我看好多资料，说是tomcat里面的Servlet容器中会有一个Servlet池，用于存放实例化后的Servlet对象，以便反复使用，因此，Servlet对象可以被多个线程并发使用，而且Servlet还是一个非线程安全的类，一次在进行业务逻辑处理的时候（service，以及doXxx方法），应该尽量避免使用成员变量（是线程共享的，容易产生线程安全问题），尽量使用局部变量（如在方法内部定义的变量）

### 4 servlet死亡
当Servlet实例话后，该对象就会一直存活在服务器容器中，期间可以不断接收对应请求并给出响应，当停止服务器的时候，会在停止之前，调用每一个Servlet对象的destory()方法，我们可以在此方法内自定义动作，比如释放资源等等。
只有执行完该方法之后，该对象才彻底宣告死亡。

重写destory():
```
@Override
public void destroy() {
    super.destroy();
    System.out.println("执行该destory方法");
}
```
停止服务器，看结果：
```
六月 08, 2018 5:14:07 下午 org.apache.catalina.core.StandardServer await
信息: A valid shutdown command was received via the shutdown port. Stopping the Server instance.
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol pause
信息: Pausing ProtocolHandler ["http-bio-8080"]
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol pause
信息: Pausing ProtocolHandler ["ajp-bio-8009"]
六月 08, 2018 5:14:07 下午 org.apache.catalina.core.StandardService stopInternal
信息: Stopping service Catalina
**执行该destory方法**
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol stop
信息: Stopping ProtocolHandler ["http-bio-8080"]
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol stop
信息: Stopping ProtocolHandler ["ajp-bio-8009"]
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol destroy
信息: Destroying ProtocolHandler ["http-bio-8080"]
六月 08, 2018 5:14:07 下午 org.apache.coyote.AbstractProtocol destroy
信息: Destroying ProtocolHandler ["ajp-bio-8009"]
Disconnected from server
```
到此，Servlet的生命周期结束。

### 5 总结
Servlet实例化时机是可以控制的，在实例化后可以停留在服务器中不断处理请求，并且给用户响应结果，且是非线程安全类，它会在服务器停止时自动调用destory()方法，调用完destory()方法后的Servlet对象不再可用，因为已经死亡了，此时生命周期结束。

理解Servlet生命周期后，去理解Spring MVC中的DispatcherServlet就比较方便。

