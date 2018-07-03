## 1 demo的主要思路

- redi作为spring框架中的缓存
- 当需要热点数据的时候，会首先从redis缓存数据库中获取，如果没有获取，进行第3步
- 从mysql获取数据，如果获取结果不为空，返回结果，与此同时将结果存入到redis缓存中

## 2 基于redis设计spring缓存

自定义Spring缓存需要实现Cache接口：
```
public class RedisCacheByMyself implements Cache {
    private String name;

    //缓存容器是redis，因此使用RedisTemplate，操作redi数据库的接口
    @Autowired
    private RedisTemplate redisTemplate;

    //缓存名字
    @Override
    public String getName() {
        return this.name;
    }

    public void setName(String name) {
        this.name = name;
    }

    //获取该缓存
    @Override
    public Object getNativeCache() {
        return this.redisTemplate;
    }

    //从缓存中获取数据，此时就是一个简单例子，因此仅仅实现了对字符串类型数据的操作
    @Override
    public ValueWrapper get(Object key) {
        System.out.println("get key........");
        Object value =  redisTemplate.opsForValue().get(key);
        if(value == null){
            return  null;
        }
        return  new SimpleValueWrapper(value);
    }

    //将查询结果缓存到redis缓存中，o1（value）是一个Users的bean对象（实现序列化接口的），此处我们将其序列化为字符串了
    @Override
    public void put(Object o, Object o1) {
        System.out.println("put key .....");
        redisTemplate.opsForValue().set(o,o1);
    }
}
```
接下来实现业务逻辑：
```
@Service("userService")
public class UserService {
	
	//操作mysql数据库的接口
    @Autowired
    private SqlSessionTemplate sessionTemplate;

    /**
    *此处根本不用考虑用不用缓存，我们就直接从mysql中查询数据就行了，
    *从这里也可以看出了spring可以实现缓存代码与业务逻辑代码的解耦;
    *myCache就是告诉Spring框架，数据应该从哪个缓存中去获取
    **/
    @Cacheable("myCache")
    public Object getObject(String key){
        System.out.println("从数据库中查询数据。。。。");
        return fromDB(key);
    }

    private Object fromDB(String field){
        System.out.println("开始从数据库中获取数据。。。。。");
        return sessionTemplate.selectOne("guluo.getOneUser",field);
    }
}
```
接下来修改配置文件：

```
<!--启用基于注解的缓存驱动-->
<context:component-scan base-package="com.cache" />

<!--启动注解驱动-->
<cache:annotation-driven />

<!--配置mysql数据库数据源-->
<bean id="dataSource" class="org.apache.commons.dbcp.BasicDataSource"
      p:driverClassName="com.mysql.jdbc.Driver"
      p:url="jdbc:mysql://localhost:3306/cache?useSSL=false"
      p:username="${username}"
      p:password="${password}"
/>

<!--spring与mybatis框架的整合-->
<bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean"
      p:dataSource-ref="dataSource"
      p:configLocation="classpath:mybatis-conf.xml"
/>

<bean class="org.mybatis.spring.SqlSessionTemplate">
    <constructor-arg ref="sqlSessionFactory" />
</bean>


<!--spring整合redis数据库，我的redis没有配置密码且没有额外的配置，因此其他的属性我没有配置-->
<bean id="jedisConnectionFactory" class="org.springframework.data.redis.connection.jedis.JedisConnectionFactory"
      p:hostName="localhost" p:port="6379"
/>

<bean id="redisTemplate" class="org.springframework.data.redis.core.RedisTemplate">
    <property name="connectionFactory" ref="jedisConnectionFactory" />
    <property name="keySerializer" >
        <bean class="org.springframework.data.redis.serializer.StringRedisSerializer" />
    </property>
    <property name="valueSerializer">
        <bean class="org.springframework.data.redis.serializer.JdkSerializationRedisSerializer" />
    </property>
</bean>

<!--p配置缓存管理器，这里使用spring提供的SimpleCacheManager，缓存使用上面我们自定义的redis缓存，并将其命名为myCache-->
<bean id="cacheManager" class="org.springframework.cache.support.SimpleCacheManager">
    <property name="caches">
        <set>
            <bean class="com.cache.RedisCacheByMyself" p:name="myCache" />
        </set>
    </property>
</bean>
```
## 3 验证有效性
编写测试代码：
```
public class Client {
    public static void main(String[] args) {
        ApplicationContext context = new ClassPathXmlApplicationContext("conf-myCache.xml");
        UserService userService= (UserService) context.getBean("userService");
        Users user = (Users) userService.getObject("1");
        System.out.println(user.getName());
    }
}
```
结果：
```
//没有运行程序的时候，redis缓存中没有数据，因此第一次查询的时候肯定是从数据库中查询
127.0.0.1:6379> keys *
(empty list or set)

//第一次运行程序，从mysql中查询数据
get key........   //在这里没有查到
从数据库中查询数据。。。。 //于是开始从数据库中查询
开始从数据库中获取数据。。。。。
put key .....    //结果不为空，将结果以key-value存入到redis中了
张三丰      //返回结果

//此时redis缓存中已经有数据了
127.0.0.1:6379> keys *
1) "1"

//第二次运行程序，执行与上次相同的查询
get key........  //直接从缓存中获取，根本没有去mysql中查询
张三丰
```

## 4 遇到的问题

在这里需要额外注意一点：Users这个Java Bean必须实现Serializable接口，使其成为能够被序列化的对象，否则无法存入到redis数据库中：

```
public class Users implements Serializable{
    private int id;
    private String name;
    private String username;
    private String password;

    ...
}
```

原因：  
在前面配置文件中，配置操作redis的RedisTemplate接口的时候，指定存入到redis中的key,value都需要进行序列化，因此，此时Users对象也必能够序列化。

## 5 总结
使用缓存，能够大大降低获取数据所需要的时间，尤其是从数据库中获取数据，此时可能会进行IO操作，更加耗费时间，此时可以考虑把热点数据存入到缓存中；

我测试了一下，一个表中大约有64w行记录，直接从数据库中随机获取一条数据所需要的时间是270ms（没有使用索引），如果直接中缓存中获取数据的话是2ms，可见使用缓存可以降低时间大约100倍；使用索引直接从数据库中获取，需要的时间是4ms，也比直接从缓存中获取时间慢。
