#### 1 logstash介绍

logstash用于监控文件的变化，并将文件的变化以行为单位显示出来，它和linux命令`tail`很像，但是相对于`tail`，logstash的功能更加丰富，它不仅能够监控文件的变化并输出，并且还可以借助于一些插件在内容输出之前对其进行自定义处理。

#### 2 logstash基本使用

##### 2.1 logstash入门例子

使用如下命令启动logstash：

```shell
//启动logstash，监控标准输入，并将标准输入打印到标准输出中
./logstash -e ""

hello  //在终端输入hello，下面是打印内容 
{           
	"host" => "master",       
	"@version" => "1",     
	"@timestamp" => 2019-11-07T11:51:18.468Z,        
	"message" => "hello" 
}
```

##### 2.2 通过配置文件启动logstash

ogstash三大组件分别是：

- input：用于控制logstash的监控信息来源
- output： 用于控制logstash的输出信息位置
- filter： 在logstash输出信息之前，对监控的内容进行处理

为了实现logstash的自定义配置，我们可以先编写一个logstash的启动配置文件，然后使用`./logstash -f {配置文件}`来启动logstash。

```ruby
##启动配置文件内容

##配置input
input {
    #由于是要从file中读取内容，因此这里使用file插件
    file {
        #path指定file的全路径，/*表示监控该路控该路径下的所有文件
        path => "/root/practice/es/logstash/log.log"
        #这里显示从文件的哪里开始读取内容
        start_position => "beginning"
        #处理文件数据的时候，为事件添加一个字段，并为其赋值
        add_field => {"test"=>"sdsadsa"} 
        #置新事件的标志，可以设置换行，也可以设置空格，默认就是\n
        delimiter => "\n" 
    }
}

#filter
filter {
    ...
}

#配置output
output {
    #将logstash的输出，输出到es中
    elasticsearch{
        #配置ES集群的信息
        hosts => "ip:port"
        #索引名字，监控到的数据，会写入到这个索引当中
        index => "logstashindex" 
    }
    #可以配置多个logstash，这里配置既往es中输出，还往标准输出中输出
    stdout {}
}
```

#### 3 logstash常用的插件

logstash往往配合ES使用，形成ELK技术栈。logstash负责搜集日志，并对日志进行自定义处理；ES负责存储内容，并建立索引；Kibana负责ES中的数据可视化展示。

logstash在搜集日志的时候，对日志内容进行自定义处理，往往借助于一些插件，常见的有`grok`、`date`、`mutate`插件，logstash配置插件非常简单，只需要在启动配置文件中添加`filter {}`模块即可。下面记录这些常用插件的使用方法。

##### 3.1 grok插件

grok 是 Logstash 最重要的插件。它可以解析任意文本并把它结构化。因此 **Grok 是将非结构化的日志数据解析为可查询的结构化数据的好方法** 

grok 使用正则表达式提取日志记录中的数据，这也正是 grok 强大的原因。Grok 使用的正则表达式语法与 Perl 和 Ruby 语言中的正则表达式语法类似。你还可以在 grok 里预定义好命名正则表达式，并在稍后(grok 参数或者其他正则表达式里)引用它。

详细可以看： [Logstash filter 插件之 grok](https://www.cnblogs.com/sparkdev/p/10606810.html)

grok的语法总是如下：

```shell
#grok会根据正则表达式，去提取数据，将匹配到的数据值赋给{字段名}
%{定义的正则表达式:字段名}
```

例如（省略input、output）：

```ruby
#在./mylog文件中定义正则表达式
MY_TIME %{YEAR}-%{MONTHNUM2}-%{MONTHDAY} %{HOUR}:%{MINUTE}:(?:(?:[0-5][0-9]|60),\d+)

##在logstash中的启动配置文件中配置filter
filter {
    #指定正则表达式定义文件的位置
    partterns_dir => ["./"]
    match => ["%{MY_TIME:time_tmp}" ]
    }
```

启动logstash，并且输入`2020-10-28 15:00:13,872`内容，会发现如下输出结果：

```shell
#匹配成功
{
    "@timestamp" => 2020-10-28T12:33:13.281Z,
          "host" => "master",
       "message" => "2020-10-28 15:00:13,872",
      "time_tmp" => "2020-10-28 15:00:13,872",
      "@version" => "1"
}

#输入“2020-10-28 15:00:13.872”匹配不成功
{
      "@version" => "1",
       "message" => "2020-10-28 15:00:13.872",
    "@timestamp" => 2020-10-28T12:35:59.702Z,
          "tags" => [
        [0] "_grokparsefailure"
    ],
          "host" => "master"
}
```

从结果中会发现，定义的正则表达式能够匹配到输入内容，因此将匹配到的内容赋值给`time_tmp`字段，匹配不成功，则不赋值。

有时候根据grok匹配成功与否，logstash的输出会进行不同的处理，那么可以在output模块定义如下内容：

```ruby
output {
    #匹配失败
    if "_grokparsefailure" in [tags] {
        #do something
    }else{
        #匹配成功，do somthing
    }
}
```

##### 3.4 mutate插件

有时候需要对logstash的输出字段内容进行修改，那么可以使用mutate插件来完成此功能。

**1 split**

对指定字段的内容进行切分处理。使用方式如下：

```ruby
filter{
	mutate {
		#以逗号为分隔符，对time_tmp中的数据进行切分处理
		split => ["time_tmp",","]
	}
}
```

切分后的结果如下：

```shell
{
      "time_tmp" => [
        [0] "2020-10-28 15:00:13",
        [1] "872"
    ],
       "message" => "2020-10-28 15:00:13,872",
          "host" => "master",
      "@version" => "1",
    "@timestamp" => 2020-10-28T12:43:54.943Z
}
```

从结果可以看出来，mutate.split对字段time_tmp中的内容进行切分，并以数组形式进行返回。如果想获取数组中的其中一个元素的值的话，可以使用`"%{[数组名][数组下标]}"`。

**2 update**

update用于修改制定字段的值。使用方式如下：

```ruby
filter{
	mutate {
		#以逗号为分隔符，对time_tmp中的数据进行切分处理
		split => ["time_tmp",","]
	}
    
    mutate {
        #更新time_tmp字段的内容，内容为上面切分后的结果数组中的第一个元素
        update => {"time_tmp" => "%{[time_tmp][0]}"}
    }
}
```

update后的结果如下所示：

```shell
{
      "@version" => "1",
          "host" => "master",
    "@timestamp" => 2020-10-28T12:53:26.666Z,
       "message" => "2020-10-28 15:00:13,872",
      "time_tmp" => "2020-10-28 15:00:13"
}
```

##### 3.3 date插件

date插件用于对日期进行处理。也是通过正则表达式进行配置，对于匹配成功的时间字符串进行时间格式化处理。

例如有时间字符串为`2020-10-28 15:00:13`,我们可以使用date插件对其进行时间格式化处理，从而使得输出的时间格式满足es的date类型。使用方法如下：

```ruby
date {	
    	#满足yyyy-MM-dd HH:mm:ss格式的字符串会进行格式化处理
        match => ["time_tmp", "yyyy-MM-dd HH:mm:ss"]
    	#处理后的结果赋给字段time
        target =>  "time"
    	#删除字段time_tmp
        remove_field => "time_tmp"
    }
```

结果如下：

```sh
{
      "@version" => "1",
          "time" => 2020-10-28T07:00:13.000Z,
          "host" => "master",
       "message" => "2020-10-28 15:00:13,872",
    "@timestamp" => 2020-10-28T12:58:35.983Z
}
```

