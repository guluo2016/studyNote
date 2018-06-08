## Mybatis
Mybatis的流程比较简单：
1. 读取配置文件，构建一个SqlSessionFactory对象;需要明确一点，每一个给予Mybatis的应用都是围绕SqlSessionFactory对象展开的，一个应用对应一个SqlSessionFactory对象，通过该对象进行接下来的一系列操作
`new SqlSessionFactoryBuilder().build(Resources.getResourceAsStream("配置文件"))`
2. 获取SqlSession对象；SqlSession可以看做Mybatis给用户提供的一个可以进行具体数据库操作的工具，比如通过该对象进行增删改查操作
`sqlSessionFactory.openSession()；  //获取SqlSession`
3. 进行具体的数据库操作