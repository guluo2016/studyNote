## Spring缓存

<!-- MarkdownTOC -->

- 1 为什么要用Spring缓存？
- 2 Spring缓存使用方法
	- 2.1 第一个Spring缓存Demo
	- 2.2 Spring缓存级别
	- 2.3 Cacheable属性
	- 2.4 清除缓存数据

<!-- /MarkdownTOC -->


### 1 为什么要用Spring缓存？
缓存可以大大提高程序处理速度。目前的技术水平导致的问题就是：从硬盘中读写数据的速度远远小于CPU的处理速度，为了缓解这种矛盾，人们引入了内存，再程序运行的时候，会根据一定规则（比如程序的局部性原则），把要用的数据从硬盘中提前调入到内存中，不需要的数据及时调出内存，保证内存中空间不被无用数据塞满，CPU用的时候直接从内存中读取就行了，不需要从硬盘中话费大量时间去读取，大大缓解了IO等待时间，在这里内存实际上就是一种缓存。  
因此，缓存的目的就是为了缓解因速度不匹配导致的性能问题，把经常使用的数据放入到能够进行高速缓存中，下一次如果还用同样的数据的时候，就不必从IO速度很慢的存储介质上读取了。这对于要求高相应的应用而言，至关重要。

缓存这么好用，因此再很多应用中都有所运用，但是如果由我们自己来实现整个缓存机制，有点太费事，一是因为，缓存机制太复杂，需要考虑存的问题，如存那些数据才能够使得命中率最高；二是还需要考虑如何删的问题，什么时候删除无效数据，何时删除；三是自己实现整个功能模块，有很大的可能性会因为考虑不周存在bug，指不定什么时候就出来作妖了。

可能是基于以上的问题把，Spring提供了缓存机制，Spring缓存给我们提供了缓存存储方式，删除缓存数据方式，而且还提供了可扩展的借口，最重要的是我们仅仅只需要少量的几行代码就能够实现缓存，所以说再项目中使用Spring缓存非常方便。

### 2 Spring缓存使用方法

#### 2.1 第一个Spring缓存Demo
注释`@Cacheable`声明了方法的返回值是可以被缓存的，它有一个必须要指明的属性，就是缓存名，即要将返回值数据缓存在哪里。  
制定缓存名的方法：`@Cacheable("cacaheName")`或者是`@Cacheable(cacheNames = "cacheName")`
```
public class CacheTest{
	@Cacheable(cacheNames = "users")
    public Integer getValue(String key){
        System.out.println("真实的查询，，" + key);
        return 12345;
    }
}
```
配置缓存区:
```
<!--启动给予注解的缓存驱动（必须）-->
<cache:annotation-driven />

<!--声明一个缓存管理器，用于管理缓冲区-->
<bean id="cacheManager" class="org.springframework.cache.support.SimpleCacheManager">
    <property name="caches">
        <set>
        	<!--声明users缓存区的存储方式，这里使用ConcurrentHashMap作为缓存区的存储介质（内存），当然也可以使用redis来存储-->
            <bean class="org.springframework.cache.concurrent.ConcurrentMapCacheFactoryBean"
                  p:name="users" />
        </set>
    </property>
</bean>
```
测试,当UserService对象调用getValue()方法时，由于启动了缓存，因此Spring容器会首先检测缓存中是否由对应的value值，如果有的话，就直接返回给用户，没有的时候才会真正的去调用getValue()方法。
```
UserService service = context.getBean("userService",UserService.class);
service.getValue("name"); 
service.getValue("name");

UserService service2 = new UserService();
service2.getValue("name");
service2.getValue("name");
```
**这里需要注意一点：Spring缓存是针对Spring容器所管理的同一实例对象，如上代码，service2对象并不由Spring容器管理，因此连续调用两次，都是执行真正的方法getValue()。**
#### 2.2 Spring缓存级别
Spring缓存级别分类两种：类界别的缓存和方法级别的缓存。  

类级别的缓存，将会缓存类下的所有方法的返回值，下一次，不管是调用该类下的哪个方法，只要传入的参数一样，那么它都会直接返回缓存中已有的数据，不会真正区调用目标方法，看代码：
```
@Cacheable("classCache")
public class ClassCache {
    public String getAge(String name,int age) {
        System.out.println("正在执行getAge方法");
        return "调用getAge方法";
    }

    public String getAddress(String name,int age){
        System.out.println("正在执行getAddress方法");
        return "调用getAddress方法";
    }
}
```
上面的方法，如果同一个ClassCache连续调用两个方法：
```
System.out.println(classCache.getAge("xiaoming",20));
System.out.println(classCache.getAddress("xiaoming",20));

//返回结果
正在执行getAge方法
调用getAge方法
调用getAge方法
```
发现结果没有调用getAddress()方法。Spring默认把目标数据以key-value对的形式放入到缓存中，其中value就是方法的返回值，而key默认就是根据方法调用参数生成的，因此调用两个方法所传入的参数一样，因此，在调用getAddress()时，Spring容器发现缓存中有现成数据，就直接返回了，压根没有调用getAddress方法。

方法级别的缓存，所定义的缓冲区只对所修饰的方法起作用，不同的方法可以设置不同的缓冲区，当然了，也可以设置同一个缓冲区，这个时候如果类下面的所有方法都设置了缓存机制，且缓存区一样，就和类界别缓存没两样了。

#### 2.3 Cacheable属性
Cacheable有三个常用属性，cacheNames指定缓存区的名字,key属性指定缓存区中key-value对的key生成策略，上面也提到了，Spring默认是根据传入的方法参数来生成key的，没有参数的时候会返回SimpleKey.EMPTY作为key值。
```
//仅根据name来生成key
@Cacheable(cacheNames = "users",key = "#name")
public Integer getValue(String name,int age){
    System.out.println("真实的查询");
    return 12345;
}
```
初次之外,Cacheable还可以指定带条件的缓存，使用属性condition来指定
```
//根据name和age来生成key,同时仅仅缓存age小于等于20岁的数据
@Cacheable(cacheNames = "users",condition = "#age<=20")
public Integer getValue(String name,int age){
    System.out.println("真实的查询");
    return 12345;
}
```
#### 2.4 清除缓存数据
使用注解`@CacheEvict`来清除缓存中的数据，其中`@CacheEvict`由几个属性，allEntries是否清除整个缓存区，默认是false;  
beforeInvocation是否再执行方法之前就清除缓存区，默认是再方法执行之后清除缓存区的；  
condition有条件的清除缓存，与Cacheable中的condition一样的意思，不过这个是满足条件的会从缓存区中移除。

