#### 1 Thread.sleep()的作用

在执行`Thread.sleep(1000)`代码之后，当前线程会让出CPU资源，陷入阻塞状态；在1s之后，线程会被自动唤醒，进入就绪状态，重新开始竞争CPU资源。

#### 2 使用方法

执行`Thread.sleep(1000)`代码有可能会抛出`InterruptedException`异常。

假设现在有两个线程`threadSleep`和`threadNoSleep`，后者持有前者对象，那么在`threadsleep`处于sleep的时候，执行`threadSleep.interrupt()`方法，会使得`threadSleep`身上打上中断标志，并且抛出`InterruptException`异常，异常一旦抛出之后，`threadSleep`的中断标志又被清理，成为false。

> **需要特别注意的是：**
>
> *只有线程在处于阻塞状态时（调用sleep、join、wait方法），调用interrupt方法才会抛出异常，没有处于阻塞状态，调用该方法不会抛出异常，直至遇到线程调用上述方法，才会抛出异常。*

例如如下代码：

```java
public static void main(String[] args) throws IOException {
      Thread threadSleep = new Thread("thread-sleep"){
          @Override
          public void run() {
              while(true) {
                  try {
                      Thread.sleep(1000);
                  } catch (InterruptedException e) {
                      System.out.println(Thread.currentThread().getName() + "遇到InterruptedException异常");
                      System.out.println(Thread.currentThread().isInterrupted());
                  }
              }
          }
      };
    //启动线程
     threadSleep.start();

     System.out.println("主线程调用threadSleep的interrupt方法");
     threadSleep.interrupt();

}
```

执行得到的结果是：

```shell
主线程调用threadSleep的interrupt方法
#在线程对象处于sleep时，调用interrupt时，就会抛出该异常
thread-sleep遇到InterruptedException异常
#抛出异常之后，threadSleep的中断标志就会被重新置为false
false
```

#### 3 不要忽视InterruptException异常

在使用`Thread.sleep()`时，如上代码所示，使用代码扫描工具扫描，会显示：

```shell
Either re-interrupt this method or rethrow the "InterruptedException"
```

这是因为`sleep`方法在抛出异常的时候，线程的中断标志位重新置为false，这会导致上层无法获知该线程的真是状态，这是不可取的，为了反映线程的真是状态，应该再`catch`代码块找那个加上如下代码：

```java
try {
    Thread.sleep(1000);
} catch (InterruptedException e) {
    System.out.println(Thread.currentThread().getName() + "遇到InterruptedException异常");
    System.out.println(Thread.currentThread().isInterrupted());
    //添加的内容
    Thread.currentThread().interrupt();
}
```

参考内容：

**有时候阻塞的方法抛出InterruptedException异常并不合适，例如在Runnable中调用了可中断的方法，因为你的程序是实现了Runnable接口，然后在重写Runnable接口的run方法的时候，那么子类抛出的异常要小于等于父类的异常。而在Runnable中run方法是没有抛异常的。**所以此时是不能抛出InterruptedException异常**。如果此时你只是记录日志的话，那么就是一个不负责任的做法，因为在捕获InterruptedException异常的时候自动的将是否请求中断标志置为了false。至少在捕获了InterruptedException异常之后，如果你什么也不想做，那么就将标志重新置为true，以便栈中更高层的代码能知道中断，并且对中断作出响应。**

参考文章：[不学无数——InterruptedException异常处理](https://blog.csdn.net/weixin_33998125/article/details/89627134?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-8.channel_param&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-8.channel_param)

#### 4 (扩展) 如何中断线程

1. 正常终止

   线程执行完run方法中的逻辑后，会自动终止

2. 根据标志位终止

   设置一个线程共享变量，线程根据该该变量的变化来决定是否终止run逻辑。

   因为涉及到线程共享变量，因此可能会出现线程安全问题，为了能够让线程感知到该变量的变化，应该将该变量声明为volitile类型

3. 通过interrupt抛出异常方式来终止线程

   通过调用线程对象的interrupt()方法，可使得线程抛出InterruptedException方法。通过判断线程的状态来确定是否终止该线程。
   ```java
  Thread t1 = new Thread(() -> {
       int num = 1;
       //当线程被中断时，跳出循环
       while (!Thread.currentThread().isInterrupted()) {
           System.out.println("打印 : " + num);
           num ++;
           try {
               Thread.sleep(100);
           }catch (InterruptedException e){
               System.out.println("线程被中断");
               System.out.println("当前线程的状态: " + Thread.currentThread().getName() + " , " + Thread.currentThread().isInterrupted());
               Thread.currentThread().interrupt();
               System.out.println("当前线程的状态: " + Thread.currentThread().getName() + " , " + Thread.currentThread().isInterrupted());
           }
       }
  }, "thread-1");
  t1.start();
  Thread.sleep(1000);
  t1.interrupt();
  ```

