### 1 `::`用法

`::`双冒号的用法可以是：

- `{类名}::{对应类所属的静态方法}`
- `{实例对象}::{对象拥有的成员方法}`

例子：

```java
//定义一个接口
public interface ConlonInter{
    void print();
}

public class Java8ColonTest implements ColonInter{
    //定义一个方法，方法参数是ConlonInter
    public void print(ConlonInter colon){
        colon.print();
    }
    
    public static void test(){
        System.out.println("测试双冒号...");
    }
    
    public static void main(String[] args){
        Java8ColonTest colonTest = new Java8ColonTest();
        
        //调用Java8ColonTest的print方法,这里传入一个Java8ColonTest::test
        colonTest.print(Java8ColonTest::test);
    }
}
```

从上面的例子可以看出来，`Java8ColonTest.print`方法要求传入一个`ColonInter`类型的参数，传统的方式是：

```java
colonTest.print(new ColonTest(){
    @Override
    public void print(){
        System.out.println("测试双冒号...");
    }
});
```

在java8中可以使用`Java8ColonTest::test`代替，因此这里相当于实例化一个`ColonInter`对象，且重写`ConlonInter`中的方法`print`，在`print`方法中实现的是调用`Java8ColonTest.test`方法。



还有一种用法就是：

```java
public class Test{
    public void print(){
        System.out.println("测试Java8双冒号的另外一种用法");
    }
}

...
//定义一个List
List<String> list;
Test test;
//遍历List中的所有元素，并且打印出来
list.forEach(test::print)
```

在`List`对象的`forEach`方法中传入参数，这里传入了`test::print`，即意味着每遍历一个`list`中的元素，就调用`Test.print`方法一次，目的是为了将该元素打印出来。



> 需要注意的点：
>
> - 使用`{类名}::{对应类所属的静态方法}`，`{类名}`中需要仅定义一个方法，如果定义多个方法的话，不可以使用；
> - `{实例对象}::{对象拥有的成员方法}`，`{实例对象对应的类}`中可以定义不止一个方法，我们仅使用我们需要的方法即可。

