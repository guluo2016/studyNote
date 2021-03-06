## 1 基本概念 ##

**索引**：ES数据管理的顶层单位就是索引，它相当于关系型数据库中的数据库概念，注意:索引的名字必须是小写字母，否则会报错；  
**文档**：文档用于存储一条记录（相当于关系型数据库中的一行记录，文档是存放在索引中的；   
**类型**：类型用于给文档分类，一般情况下而言，同一类型的文档应该具有相似或相同的数据结构；  

**节点**：这事对于集群而言，ES可以是分布式的，这样ES可以运行在多个服务器上，每个运行在服务器上的ES实例就被称为节点；  
**集群**：一组节点构成一个集群。

## 2 基本指令 ##
### 2.1 新建/删除索引 ###
和数据库一样，想往ES上存储数据，首先需要创建索引（index），创建索引指令是：  
```
#后面加pretty是为了让显示结果易读
curl -X PUT http://node:9200/testindex?pretty
{
  "acknowledged":true,
  "shares_acknowledged":true
}
```
删除索引的指令:
```
curl -X DELETE http://node:9200/testindex?pretty
{
  "acknowledged":true
}
```

查看ES服务中已有的索引指令：
```
curl -X GET http://node:9200/_cat/indices?pretty
```

### 2.2 增删改查 ###
新增数据，实际上就向ES中添加一个文档：  
```
#注意请求体是一个json字段，必须用''括起来，否则会报错
curl -X PUT http://node:9200/testindex/person/1 -d '{"name":"teser"}'
```
查看数据：
```
#根据文档ID来查询对应文档中的内容
curl -XGET http://node:9200/testindex/person/1?pretty

#有时候想查询某个索引下的所有文档
#列出testindex索引下的所有文档
curl -X GET http://node:9200/testindex/_search?pretty

#按照某种条件去查询
#默认情况下查询会显示10个文档的诗句，我们可以通过size字段去设定一次显示多少个文档
curl -X POST http://node:9200/testindex/_search?pretty -d '{"query":{"match_all":{}},"szie":5}'
```
删除记录
```
curl -XDELETE http://node:9200/testindex/person/1
```
更新记录
```
#实际上更新记录，就是对原记录的一次覆盖，因此当进行更新操作的时候，即使有些字段没有
#改动，也需要原样添加
curl -X PUT http://node:9200/testindex/person/1 -d '{"name":"test1"}'
```
另外更新有一点需要注意，ES中的每一个文档都是一个版本号的version，首次添加，会是1；之后每对其进行一次修改，那么这个版本号就会加1

##3 再说查询##
ES最核心的功能就是查询了。  
它能够在在极短的时间内，从海量数据中找到我们需要的数据；   
在搜索的时候，相似的结果也有可能被搜索出来，比如像搜索drink的时候，drunk也有可能被搜索出来；  
关键就是靠它的索引机制。  

举个例子：现在有10亿个网页，通过关键字如何快速找到想要的网页？
每个网页可以看做是一个文档，每个文档里都存放着若干字符串。有两种方式：顺序扫描和全文检索

**顺序扫描**:一个网页一个网页的进行扫描，然后和读取网页内容和已知关键字进行比照，从而找到目标网页。这种方法，结果可靠，但是效率低下，不能够被接受；   
**全文检索**：在每创建一个网页的时候，都会提取网页的关键字，进行重新组织，形成{若干个关键字}--{网页文档}映射关系，这种映射关系就被称之为索引。而这种
先建立索引，然后在根据索引进行查询的操作就叫做全文索引。这样的话，只要通过索引快速定位关键字，然后根据映射关系，快速定位网页，就可以找到目标网页。  

ES实际上就是基于这种机制，来建立索引的。由于通过字符串映射字符串所在文档是通过文档映射文档中字符串的反向过程，因此这种索引被称之为倒排索引。
为了加快对索引的查询，还可以像mysql数据库中的索引那样，对倒排索引按照某种数据结构方式进行存储，这样在查询的时候，速度更快。

那么为什么相似的内容也有可能会被搜索出来呢？  
这事因为ES是基于Apache Lucene的，Lucene在建立索引的时候，会由语言处理组件，将文档中的关键词都转换成它的原生状态，比如cars--car,went--go等等。
因此如果网页A中频繁的出现cars单词的话，那么我们对一组网页集合按照关键字car进行搜索的时候，网页A可能会搜索结果当中。
