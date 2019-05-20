## Query DSL ##

ES最核心的内容就是查询了，借助于DSL可以进行复杂的查询。  

**1 查询指定索引的所有数据**
```
curl node:9200/testindex/_search?pretty -d
`
{
	"query":{"match_all":{}}
}
`
```
这里默认是显示10个结果文档，也可以自定义显示结果文档数：
```
curl node:9200/testindex/_search?pretty -d
`
{
	"query":{"match_all":{}},
	"size":2,
	"from":5 
}
`
```
size字段表示要显示的结果文档数；  
from字段表示从哪个文档开始算起。

**2 指定显示查询结果字段**  
如下，仅仅显示查询结果的name字段  
```
curl node:9200/testindex/_search?pretty -d
`
{
	"query":{"match_all":{}},
	"size":2,
	"from":5,
	"_source":[
		"name" 
	]
}
`
```

**3 按照指定条件来查询**  
一些特殊符号表示的含义如下表：  

| 符号 | 表示含义 |
|------|----------|
| gte  | 大于等于 |
| gt   | 大于     |
| lte  | 小于等于 |
| lt   | 小于     |

假如搜索索引testindex中商品类型的文档中，售价在400~700之间（闭区间）的商品：
```
curl -XGET node:9200/testindex/products/_search?pretty -d 
`
{
	"query":{"match_all":{}},
	"size":2,
	"from":5,
	"filter":{
		"range":{
			"price":{
				"gte":400,
				"lte":700
			}
		}
	}
}
` 
```

**4 全文检索**  
name字段必须包含“H”或者“C”的文档数据：
```
curl -XGET node:9200/testindex/products/_search?pretty -d 
`
{
	"query":{
		"match":{
			"name":"H C"
		}
	},
	"size":2,
}
` 
```

name字段必须包含"H"和"C"的文档数据：
```
curl -XGET node:9200/testindex/products/_search?pretty -d 
`
{
	"query":{
		"match_phrase":{
			"name":"H C"
		}
	},
	"size":2,
}
` 
```

