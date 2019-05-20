##match 和 term的区别##

通过match和term关键字都可以对ES中的数据进行查询，但是他们之间存在一定的区别。

**match查询**

进行match查询时，ES会自动把其中的关键字进行分词处理，如：
```
{
	"query":{
		"match":{
			"content":"very good"
		}
	}
}
```
由于使用的是match关键字，因此在进行查询才时候，ES会对查询关键字"very good"进行分词处理：very,good。因此ES中只要是包含very，good任一词汇的文档都会被搜索出来。   
由于match此特性，match查询适合进行模糊查询。

**term查询**

通过term关键字进行查询时，ES不会对查询关键字进行分词，如：
```
{
	"query":{
		"term":{
			"content":"very good"
		}
	}
}
```
由于term不会对查询关键字进行分词，因此只有包含“very good”的文档才会被搜索出来。由于term此特性，适合进行精确查询。
