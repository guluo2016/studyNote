### bean
#### 1 bean作用域
**singleton的作用域**

在Spring IOC容器中仅仅存在一个该bean实例，bean以单例形式存在。

如果不想在启动容器的时候就对单例bean进行实例化，可以进行如下配置：
`<bean id="beanID" class="className" lazy-init="true" />；`
但是需要说明的该配置并非在任何时候都生效，因为如果该bean被其他bean所引用，并且那个bean没有进行实例化限制，那么会出发该bean提前进行实例化。

*注意：在默认情况下，会在启动SpringContext容器时，自动实例化所有singleton类型的bean，并将其缓存在容器中。这样做的好处是：对单例bean提前实例化，当需要用的时候无需花费时间等待其进行实例化，可以提高效率；提前实例化可以及早发现潜在的配置问题。当然也存在缺点：启动时候就实例化单例bean，使得启动Spring容器耗费时间更长；因为提前实例化，需要更多的内存空间来存放这些bean。但是总的来说，缺点我们可以接收，而优点却很大。*

被声明为singleton的bean，其整个声明周期有spring容器进行管理。

**prototype的作用域**

当bean被声明为prototype类型时，就意味者每次通过getBean()方法获取的bean对象都是全新的。另外需要注意一旦，该类型的bean，Spring容器仅仅负责对其进行实例化，一旦将其交给调用者之后，Spring容器不在管理其声明周期。

声明为prototype类型的bean，Spring容器启动时，并不对该bean进行实例化，而是在需要的时候才对其进行实例化。
