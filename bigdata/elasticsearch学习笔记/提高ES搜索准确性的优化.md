#### 1 构建索引

创建一个2分片，0副本的索引：

```shell
PUT query_test
{
  "settings": {
    "number_of_shards": 2,
    "number_of_replicas": 0
  }
}
```

分别往这两个分片上添加2个文档，id为1，2的文档在同一个分片，id为3，4的文档在同一个分片。

```shell
### 1，2号文档在同一个分片上
POST query_test/_doc/1?routing=A&refresh
{
  "content":"school"
}

POST query_test/_doc/2?routing=A&refresh
{
  "content":"good school"
}

### 3，4号文档在同一个分片上
POST query_test/_doc/3?routing=A&refresh
{
  "content":"good school"
}

POST query_test/_doc/4?routing=A&refresh
{
  "content":"good"
}

###查看各个分片上的文档数
GET _cat/shards/query_test?v

```

查看该索引中各个分片上的文档情况

```shell
GET _cat/shards/query_test?v
##获取结果
index      shard prirep state   docs  store ip             node
query_test 1     p      STARTED    2  7.3kb 10.121.198.223 node-1
query_test 0     p      STARTED    2 12.1kb 10.121.198.223 node-1
```

#### 2 搜索，并发现问题

再次重述四个文档的内容，且文档1，2位于同一个分片，文档3，4位于同一个分片：

```shell
1 {"content":"school"}
2 {"content":"good school"}
3 {"content":"good school"}
4 {"content":"good"}
```

现在执行如下搜索：

```shell
GET query_test/_search
{
  "query": {
    "match": {
      "content": "school"
    }
  }
}
```

先不看搜索结果，从直观上来看，文档1和搜索关键字完全匹配，因此相关性应该最高，应该排在第一位，文档2，3内容相同，且包含搜索关键字`school`，因此两者的相关性应该一样，文档4不相关。

但是，实际的搜索结果却是，文档3的相关性最高：

```shell
{
    "_index" : "query_test",
    "_type" : "_doc",
    "_id" : "3",
    "_score" : 0.60996956,
    "_routing" : "B",
    "_source" : {
    	"content" : "good school"
    }
},
{
    "_index" : "query_test",
    "_type" : "_doc",
    "_id" : "1",
    "_score" : 0.21110919,
    "_routing" : "A",
    "_source" : {
   	 	"content" : "school"
    }
},
{
    "_index" : "query_test",
    "_type" : "_doc",
    "_id" : "2",
    "_score" : 0.160443,
    "_routing" : "A",
    "_source" : {
    	"content" : "good school"
    }
}
```

#### 3 问题分析

之所以出现这种问题的原因在于ES默认使用`QUERY_THEN_FETCH`搜索类型，该搜索类型的机制是：

1. 发送请求到索引的每个分片上
2. 在每个分片上执行搜索，并对匹配的文档进行打分，打分是依据词频(tf)、出现关键字的文档数(df)来进行的
3. 每个分片将结果的元数据信息返回给协调者，元数据信息包括匹配文档的id、每个文档的匹配分数等
4. 协调者合并所有分片的响应，并进行排序，再次向各个分片发送请求获取对应文档的内容
5. 结果返回给用户。

注意第2步，进行打分时用到的`df`并不是该term在整个索引中出现关键字的文档数，而是该分片上（一个Lucene索引）出现该关键字的文档数，因此对于ES而言是一个局部`df`，正是由于这个问题，导致上面的搜索结果和预期不同。

ES对文档的打分是根据`f(tf/df)`来确定的，简单起见，大致可以认为`tf/df`的值越大，那么得分就越高，反之则越低。

因为文档1、2在同一个分片上且均匹配搜索关键字，文档1的打分是`1/2=0.5`，文档2的打分是`1/2=0.5`；文档3，4在同一个分片上，且只有文档3匹配关键字，文档3的打分是`1/1=1`，根据打分情况可以看出来文档3的得分最高，因此ES的返回结果也必然是文档3排在第一位。

#### 4 解决办法

从上面的分析可以看出来，出现此问题的原因在于ES对每个分片上的匹配文档进行打分的时候，使用了局部的`df`（分片级的`df`），因此只要使用全局全局的`df`（索引级的`df`），既可解决问题。

ES提供了另外一种搜索类型:`DFS_QUERY_THEN_FEATCH`，此类型的搜索原理是：

1. 先预查询每一个分片，得到匹配的分片级的`df`，从而得到搜索关键字的索引级的`df`
2. 在发送请求在每个分片上执行搜索，并对每个匹配文档进行打分，打分时使用的`df`，是预查询时得到的索引级别的`df`
3. 每个分片将结果的元数据信息返回给协调者，元数据信息包括匹配文档的id、每个文档的匹配分数等
4. 协调者合并所有分片的响应，并进行排序，再次向各个分片发送请求获取对应文档的内容
5. 结果返回给用户。

基于此类型查询，可以得到与预期相符的结果。

```shell
GET query_test/_search?search_type=dfs_query_then_fetch
{
  "query": {
    "match": {
      "content": "school"
    }
  }
}
```

获取结果：

```shell
 {
     "_index" : "query_test",
     "_type" : "_doc",
     "_id" : "1",
     "_score" : 0.41299206,
     "_routing" : "A",
     "_source" : {
    	 "content" : "school"
     }
 },
 {
     "_index" : "query_test",
     "_type" : "_doc",
     "_id" : "3",
     "_score" : 0.31387398,
     "_routing" : "B",
     "_source" : {
     	"content" : "good school"
     }
 },
 {
     "_index" : "query_test",
     "_type" : "_doc",
     "_id" : "2",
     "_score" : 0.31387398,
     "_routing" : "A",
     "_source" : {
     	"content" : "good school"
     }
 }
```

