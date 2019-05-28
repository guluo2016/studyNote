## 概述
依赖注入最著名的莫过于Spring框架中的依赖注入了，但是Spring框架启动起来速度比较慢，而且此框架比较庞大，因此对于仅仅只使用依赖注入这一个功能的需求而言，Google提供的Google Guice框架是一个比较好的选择，它相对于Spring框架而言，功能比较单一，仅仅关注依赖注入这一个功能，因此它比Spring框架要轻很多，启动速度也比Spring要快很多。

正是由于Google Guice框架的这些个优点，应用还是比较广泛的。我所知道的就有：hadoop框架、Ambari平台、Xtext框架。这些项目的特点就是在一些方面仅仅需要依赖注入，因此它们选择了Google Guice，而不是Spring。

## Google Guice使用方法
Google Guice一个最大特点就是零配置。仅仅可以通过注释，就可以完成Java世界的依赖注入。要使用Google Guice框架，首先需要导入Google Guice的依赖：
```
<!-- https://mvnrepository.com/artifact/com.google.inject/guice -->
<dependency>
    <groupId>com.google.inject</groupId>
    <artifactId>guice</artifactId>
    <version>4.0</version>
</dependency>

```

下面介绍一个入门例子：

```
//定义一个功能类
public class Add{
	public int add(int a,int b){
		return (a + b);
	}
}

//基于Google Guice框架，进行依赖注入
public class Client{
	public static void main(String[] args){
		Injector injector = Guice.createInjector();
		Add add = injector.getInstance(Add.class);
		int result = add.add(1,2);
		System.out.println(result);
	}
}
```
基于上面的例子，可以看到，基于Google Guice框架可以实现零配置的依赖注入。其中：  
```
Injector injector = Guice.createInjector();
```
这行语句，就是问Google Guice框架要一个Injector，然后通过这个injector就可以对目标类，进行反射操作，并返回给用户对应类的实例化对象：  
```
Add add = injector.getInstance(Add.class);
```

以上所述，仅可以作为一个Demo。在实际编程中，更推荐面向接口编程，Google Guice框架在这种模式，使用也是非常方面。和前面不同的是，需要创建一个Module，用于配置接口和实现类的映射关系，这个和Spring中依赖注入指定实现类有点相似：
```
@Autowired
@Qualifier("userServiceImp")                 //将名字为userServiceImp注入到userService属性中
private UserSerevice userService;
```

来具体看一下：  
```
//定义一个接口
public interface Add{
	int add(int a,int b);
}

//有两个实现类
public class AddImplOne implements Add{
	public int add(int a,int b){
		System.out.print("One .....");
		return (a + b);
	}
}

public class AddImplTwo implements Add{
	public int add(int a,int b){
		System.out.print("Two .....");
		return (a + b);
	}
}
```
假如现在想使用第一个实现类，那么可以定义个Module类，这个类需要继承Google Guice的AbstractModule类，来定义接口和我们需要的实现类之间的映射关系：
```
public class AddModule extends AbstractModule{
	@Override
	public void configure(){
		bind(Add.class).to(AddImplOne.class);
	}
}
```
在定义的这个子类当中，需要重新configure方法，在这个方法中定义接口和实现类的映射关系。   
接下来进行测试：  
```
public class Client{
	public static void main(String[] args){
		Injector injector = Guice.createInjector(new AddModule());
		Add add = injector.getInstance(Add.class);
		int result = add.add(1,2);    //在这里实际上使用的是Add接口的第一个实现类
		System.out.println(result);
	}
}
```

为了方便使用，Google Guice还提供了注解。比较常用的注解有：  

- @Inject 这个和Spring中的@Autowired十分像，它会把Google Guice管理的实例化对象注入该该注释修饰的属性当中，当修饰的属性声明时使用接口类型声明，那么接口中应该事先使用注释@ImplementBy声明，并绑定该接口的事先类，否则会出错
- @ImplementBy用于注释接口，并且指明这个接口的实现类
- @Singleton被该注释声明的类，将在Google Guice框架中仅存放一个，即单例模式，不被@Singleton声明的类，客户每次去获取对象的时候，Google Guice都为其创建一个新对象
