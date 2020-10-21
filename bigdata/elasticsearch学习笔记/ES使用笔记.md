#### 1 查询

 默认查询，它会查询索引中的所有文档，并且默认返回10个文档给用户
 ```shell
curl  -X PUT  node:9200/bank/_search？pretty

#相当于SQL中的查询表中的所有内容
select * from table;
 ```

##### 1.1 query查询

查询往往会跟随一定的条件，这个时候，可以使用ES的DSL查询语言

###### 1.1.1 查询所有文档`match_all`

```shell
#查询所有文档，默认情况下返回10个，使用size可以指定返回的文档数
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{"match_all":{}},
    "size" : 20 
}
'
```

###### 1.1.2 根据关键字进行查询`match`

```shell
#按照单个字段条件进行查询
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{
        "match":{"lastname":"Ayala"}
    }
}
'
```

以上的`match`查询如果想和Sql进行类比的话，相当于sql语句中的：

```sql
#相当于SQL中的where查询,但是like查询效率较低，原因在于like查询不走索引
select * from table where lastname like %Ayala%
```

###### 1.1.3 根据关键字搜索，并返回指定字段的内容`_source`

```shell
#查询，结果显示指定字段，如下仅显示文档中的lastname和age字段的内容
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{
        "match":{"lastname":"Ayala"}
    },
    "_source":["lastname","age"]
}
'
#SQL查询，并显示指定字段
select lastname , age from table where lastname like %Ayala%
```



###### 1.1.4 在多字段中搜索关键字`multi_match`

```shell
#参考关系型数据库，有时候查询的时候需要同事满足多个字段的匹配情况
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{
        "multi_match":{
            "query":"hello",     //这是查询关键字
            "fields":["lastname","city"]
         }
    }
}
'
#相当于SQL中多条件查询的特殊情况
select * from table where lastname like %hello% and city like %hello%
```

###### 1.1.5 多字段多条件查询

实际上multi_match使用比较不方便，因为它查询的是多个字段对一个关键字的匹配程度，大多数情况下，我们需要的是多个查询条件,并且这些条件还需要组合，这个时候，我们可以使用must、should、must_not关键字来进行查询，它们分别对用与与、或、非操作。使用这些关键字进行查询的时候，需要使用bool关键字进行组合，即使只有一种类型的查询，也需要bool关键字组合，否则报错

```shell
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{
        "bool":{
            "must":[
                {
                    "match":{
                        "lastname":"hello"
                    }
                },
                ...   //可以多个条件
            ],
            "should":[...]
        }
    }
}
'
#相当于SQL查询是：
select * from table where (lastname like %hello% and ...) or (... or ...)
```

###### 1.1.6 精确查询`match_phrase`

使用query查询的时候，可以使用match作为文档匹配的关键字，但是有时候需要进行精确查询，这个时候可以使用match_phrase或者term来进行查询，它们三者的区别在于

| match                                                        | match_phrase                                                 | term                                       |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------ |
| 对查询关键字进行分词处理                                     | 对查询关键字进行分词处理                                     | 不对查询关键字进行分词处理                 |
| 1. 文档中含有分词既可，不要求包含所有分词<br>2. 文档中包含的关键字的想对位置也不做要求。 | 1. 文档中指定字段包含所有分词<br>2. 文档中包含的关键字与查询关键字的想对位置保持一致。 | 由于不分词，因此只要文档中有这个词，即匹配 |

##### 1.2 filter查询

###### 1.2.1 filter的作用

filter和query虽然都是查询，但是他们的侧重点不同下面进行比较

| query                               | filter                                   |
| ----------------------------------- | ---------------------------------------- |
| query强调的是文档与关键字的匹配程度 | filter强调的是文档是否满足查询条件       |
| query根据搜索关键字对每个文档进行打 | filter仅仅会查询过滤，并不对文档进行打分 |

###### 1.2.2 filter的使用方法

filter查询es5.x之后又很大的改动，因此形如下面的filter查询会报错,这事因为在es5.x之后，纯粹的filter查询已经被弃用了。

```shell
{	
	"query":{
		"filtered":{
			"query":{
				"match":{
					"lastname":"Harding"
				}
			}
		},
		"filter":{
			"range":{
				"age":{
					"gte":30
				}
			}
		}
	}
}

#报错信息
{
  "error": {
    "root_cause": [
      {
        "type": "parsing_exception",
        "reason": "no [query] registered for [filtered]",
        "line": 3,
        "col": 22
      }
    ],
    "type": "parsing_exception",
    "reason": "no [query] registered for [filtered]",
    "line": 3,
    "col": 22
  },
  "status": 400
}
```

现在可以使用bool查询组合filter查询，方式是：

```shell
{
	"query":{
		"bool":{
			"filter":{
				"range":{
					"age":{"lte":30}
				}
			}
		}
	}
}
```

也可以使用query和filter进行组合查询

```shell
//当然也可以filter和query进行组合查询
{
	"query":{
		"bool":{
            "must":{
                "match":{ 
                    "lastname":"hello"
                }
            },
			"filter":{
				"range":{
					"age":{"lte":30}
				}
			}
		}
	}
}
```

相当于Sql语句：

```shell
select * from table where age <= 30 and lastname like '%hello%'
```

filter查询更多是用于过滤掉无用信息，最常用的就是查询某个范围内的数据，可以使用range关键字来进行表示，上面有。表示大于小于的有：  
gt：大于，gte：大于等于，lt：小于，lte：小于等于

###### 1.2.3 filter的执行顺序

聚合查询和filter查询结合使用时的执行顺序

1 聚合在前面，filter在后面

```shell
{
	"aggs":{
		"test":{
			"terms":{
				"field":"gender.keyword"
			}
		}
	},
	"query":{
		"bool":{
			"filter":{
				"term":{
					"gender.keyword":"F"
				}
			}
		}
	},
	"size":1
}

#查询结果
{
    "took": 2,
    "timed_out": false,
    "_shards": {
        "total": 5,
        "successful": 5,
        "skipped": 0,
        "failed": 0
    },
    "hits": {
        "total": 493,
        "max_score": 0.0,
        "hits": [
            {
            "_index": "bank",
            "_type": "account",
            "_id": "25",
            "_score": 0.0,
            "_source": {
                "account_number": 25,
                "balance": 40540,
                "firstname": "Virginia",
                "lastname": "Ayala",
                "age": 39,
                "gender": "F",
                "address": "171 Putnam Avenue",
                "employer": "Filodyne",
                "email": "virginiaayala@filodyne.com",
                "city": "Nicholson",
                "state": "PA"
            }
            }
        ]
     },
    "aggregations": {
        "test": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
                {
                "key": "F",
                "doc_count": 493
                }
            ]
        }
    }
}
```

2 过滤在前，查询在后

```shell
{
	"query":{
		"bool":{
			"filter":{
				"term":{
					"gender.keyword":"F"
				}
			}
		}
	},
	"aggs":{
		"test":{
			"terms":{
				"field":"gender.keyword"
			}
		}
	},
	"size":1
}
# 结果和前者一样
```
通过上面的两种方式操作以及结果，可以验证的是es内部对DSL语法的执行顺序和我们书写的顺序无关，无论filter在前还是在后，都是会先执行filter，再执行聚合。

###### 1.2.4 后过滤器`post_filter`

如果使用了过滤器，那么会首先对查询的数据集进行过滤，然后再对其进行聚合处理，但是有时候，我们需要在保留对原数据的聚合结果，并且还需要进行过滤查询；

典型的例子如美团页面，先按照美食进行聚合查询，会显示美食分类：粥、西餐、火锅等等，这个时候再点击火锅的时候，会要求在页面头部仍然保留对美食的分类。

这个时候，就会需要用到后处理器post_filter   

```shell
{
	"aggs":{
		"test":{
			"terms":{
				"field":"gender.keyword"
			}
		}
	},
	"post_filter":{
		"range":{
			"age":{
				"lte":20
			}
		}
	},
   "size":1
}

#结果
{
    "took": 2,
    "timed_out": false,
    "_shards": {
        "total": 5,
        "successful": 5,
        "skipped": 0,
        "failed": 0
    },
    "hits": {
        "total": 44,
        "max_score": 1.0,
        "hits": [
            {
            "_index": "bank",
            "_type": "account",
            "_id": "963",
            "_score": 1.0,
            "_source": {
                "account_number": 963,
                "balance": 30461,
                "firstname": "Griffin",
                "lastname": "Sheppard",
                "age": 20,
                "gender": "M",
                "address": "682 Linden Street",
                "employer": "Zanymax",
                "email": "griffinsheppard@zanymax.com",
                "city": "Fannett",
                "state": "NM"
            }
            }
        ]
	},
    #聚合仍然是作用于原数据
    "aggregations": {
        "test": {
            "doc_count_error_upper_bound": 0,
            "sum_other_doc_count": 0,
            "buckets": [
                {
                    "key": "M",
                    "doc_count": 507
                },
                {
                    "key": "F",
                    "doc_count": 493
                }
            ]
        }
    }
}
```

#### 2 排序   
排序也是ES比较常用的用法

```shell
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "query":{"match_all":{}},
    "sort":{
		"age":{
			"order":"desc"  #降序排序，asc是升序排序
		}
	}
 }
'
#相当于SQL中的order by
select * from table where ... order by age
```

#### 3 聚合查询

再次参考关系型数据库，有时候需要对存储的数据进行查询，完了之后基于查询数据做聚合查询，这就是为什么es是一个数据分析引擎，使用聚合查询所使用的关键字就是aggs
```shell
curl  -X PUT  node:9200/bank/_search？pretty -d
'
{
    "aggs":{
        "aggstest":{     		#聚合名字
            "max":{				#聚合的类型
                "field":"age"   #聚合的标准，以age字段为标准进行聚合
            }
        }
    }
 }
'
#SQL查询相当于
select max(age) from table

{
    "aggs":{
        "aggstest":{     #聚合名字，这是桶聚合，桶聚合就是把同一类的放一组聚合
            "terms":{
                "field":"gender.keyword"  
            }
        }
    }
 }

#SQL中的分组查询
select count(*) from table group by gender
```

#### 4 查询集群状况

通常使用的是`_cat`接口,基于该接口可以进行如下操作：

```shell
 curl master:9200/_cat
=^.^=
/_cat/allocation
/_cat/shards
/_cat/shards/{index}
/_cat/master
/_cat/nodes
/_cat/tasks
/_cat/indices
/_cat/indices/{index}
/_cat/segments
/_cat/segments/{index}
/_cat/count
/_cat/count/{index}
/_cat/recovery
/_cat/recovery/{index}
/_cat/health
/_cat/pending_tasks
/_cat/aliases
/_cat/aliases/{alias}
/_cat/thread_pool
/_cat/thread_pool/{thread_pools}
/_cat/plugins
/_cat/fielddata
/_cat/fielddata/{fields}
/_cat/nodeattrs
/_cat/repositories
/_cat/snapshots/{repository}
/_cat/templates
```

##### 4.1 查看索引的分片情况

查看索引的分片情况，可以使用如下命令：  
```shell
[root@master es]# curl master:9200/_cat/shards/bank?v
index shard prirep state   docs  store ip             node
bank  4     p      STARTED  201 95.4kb 10.121.198.117 -6fGx7M
bank  4     r      STARTED  201 95.4kb 10.121.198.118 v1Yo6me
bank  1     p      STARTED  191 91.2kb 10.121.198.117 -6fGx7M
bank  1     r      STARTED  191 91.2kb 10.121.198.222 O5yzw5H
bank  3     p      STARTED  200   95kb 10.121.198.117 -6fGx7M
bank  3     r      STARTED  200   95kb 10.121.198.118 v1Yo6me
bank  2     r      STARTED  211 99.4kb 10.121.198.117 -6fGx7M
bank  2     p      STARTED  211 99.4kb 10.121.198.222 O5yzw5H
bank  0     r      STARTED  197   94kb 10.121.198.222 O5yzw5H
bank  0     p      STARTED  197   94kb 10.121.198.118 v1Yo6me
```
上面展示的是索引bank所拥有的所有分片情况，包括主分片和副本分片的分布节点，以及对应分片上的文档数量及数据存储量。

##### 4.2 查看索引具体情况

查看ES索引级别的状况，通常使用的是如下接口：  
```
[root@master 0]# curl master:9200/_cat/indices?v
health status index         uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   bank          MftRISiPTAqku6b5TSqGQA   5   1       1000            0    950.3kb        475.1kb
```
在这里会展示索引级别的健康状况：  
1. 索引的健康状况
2. 索引名字，在同一个ES系统中，该名字也是唯一的
3. 索引的uuid可以唯一表示该索引
4. 索引的主分片数
5. 索引的副本分片数，注意这里的副本分片数是针对一个主分片而言的
6. 索引的文档数
7. 索引中删除的文档数
8. 索引的总存储大小
9. 主分片的总存储大小

##### 4.3 查看集群的线程情况

使用`_cat/thread_pool`接口 可以查看ES集群的线程池情况：

```shell
curl master:9200/_cat/thread_pool
0EWUhXe bulk                0 0 0
0EWUhXe fetch_shard_started 0 0 0
0EWUhXe fetch_shard_store   0 0 0
0EWUhXe flush               0 0 0
0EWUhXe force_merge         0 0 0
0EWUhXe generic             0 0 0
0EWUhXe get                 0 0 0
0EWUhXe index               0 0 0
0EWUhXe listener            0 0 0
0EWUhXe management          1 0 0
0EWUhXe refresh             0 0 0
0EWUhXe search              0 0 0
0EWUhXe snapshot            0 0 0
0EWUhXe warmer              0 0 0
```

第一列是节点名

```shell
node_name
0EWUhXe
```

第二列是线程池名:ES中大致有如下几类线程池。

```shell
name
bulk
fetch_shard_started
fetch_shard_store
flush
force_merge
generic
get
index
listener
management
refresh
search
snapshot
warmer
```

查看ES的源码也可以看到几类线程的定义：

```java
public static class Names {
    public static final String SAME = "same";
    public static final String GENERIC = "generic";
    public static final String GET = "get";
    public static final String ANALYZE = "analyze";
    public static final String WRITE = "write";
    public static final String SEARCH = "search";
    public static final String SEARCH_THROTTLED = "search_throttled";
    public static final String MANAGEMENT = "management";
    public static final String FLUSH = "flush";
    public static final String REFRESH = "refresh";
    public static final String WARMER = "warmer";
    public static final String SNAPSHOT = "snapshot";
    public static final String FORCE_MERGE = "force_merge";
    public static final String FETCH_SHARD_STARTED = "fetch_shard_started";
    public static final String FETCH_SHARD_STORE = "fetch_shard_store";
    public static final String SYSTEM_READ = "system_read";
    public static final String SYSTEM_WRITE = "system_write";
}
```

接下来的三列是所有线程池的 **actinve**（活跃的），**queue**（队列中的）和 **reject**（拒绝的）的统计信息。

```
active queue rejected
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
     1     0        0
     0     0        0
     0     0        0
     0     0        0
     0     0        0
```

通过第三大列，可以看到三类信息，active的任务数，在队列中等待执行的任务、提交被决绝的任务，需要重点关注reject的统计信息，正常情况下为0，当ES集群压力过大时，如有有大量数据写入时，可能存在reject信息，值有可能不为0 。当客户端的写入请求有很多倍reject、集群中的节点频繁掉线的时候，可以考虑是否是reject的统计信息过大。

