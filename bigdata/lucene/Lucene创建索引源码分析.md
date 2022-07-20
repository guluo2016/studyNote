当用户往Lucene中添加一个文档时，Lucene会基于该文档创建倒排索引，具体是以文档中的字段`Field`为单位进行逐个处理的。

大致流程就是对文档中的内容以`Field`为单位，进行分词处理，并基于处理后的分词(`term`)建立倒排索引。lucene中不管对文档，还是对字段进行处理，实际上都是在`DefaultIndexingChain`中处理的。

#### 1 创建`DefaultIndexingChain`对象

`DefaultIndexingChain`对象在整个索引创建阶段仅存在一个。在创建`DefaultIndexingChain`对象的时候，比较重要的就是持有一个`TermsHash`对象

```java
public DefaultIndexingChain(DocumentsWriterPerThread docWriter) throws IOException {
    ...
    TermsHash termVectorsWriter = new TermVectorsConsumer(docWriter);
    //创建一个TermsHash对象
    this.termsHash = new FreqProxTermsWriter(docWriter, termVectorsWriter);
}
```

`TermsHash`对象中包含三大内存缓冲池，分别是：

- intPool缓冲池   ： 存储执行bytePool/termBytePool的指针
- bytePool缓冲池   ：  和termBytePool指向同一块内存空间
- termBytePool缓冲池：存储的是term的[长度，字节值，所在文档ID，词频，偏移量]等信息

```java
TermsHash(DocumentsWriterPerThread docWriter, boolean trackAllocations, TermsHash nextTermsHash) {
    this.intPool = new IntBlockPool(docWriter.intBlockAllocator);
    this.bytePool = new ByteBlockPool(docWriter.byteBlockAllocator);
    if (nextTermsHash != null) {
        this.termBytePool = this.bytePool;
        nextTermsHash.termBytePool = this.bytePool;
    }
}
```



#### 2 处理文档`processDocument`

用户往Lucene中添加一个文档后，Lucene会执行`DefaultIndexingChain`中的`processDocument`逻辑，具体代码如下：

```java
public void processDocument() throws IOException, AbortingException {
    ...
    while(true) {
        //遍历文档中包含的所有字段，以字段为单位，调用processField进行处理
        IndexableField field = (IndexableField)i$.next();
        fieldCount = this.processField(field, fieldGen, fieldCount);
    }
    ...
}
```

#### 2 处理文档字段`processField`

在处理每一个字段Field时，Lucene会首先创建一个PerField对象，这个对象的类型是`TermsHashPerField`,可以看`processField`方法。

```java
private int processField(IndexableField field, long fieldGen, int fieldCount) throws IOException, AbortingException {
    //地段名称
    String fieldName = field.name();
    //字段类型，eg：Stored
    IndexableFieldType fieldType = field.fieldType();
    //声明一个PerField对象
    DefaultIndexingChain.PerField fp = null;
	
    //这里比较重要，在这个方法中创建一个PerField对象
    fp = this.getOrAddField(fieldName, fieldType, true);

    //对字段的值进行分词处理，并建立倒排索引
    fp.invert(field, first);
}
```

`processField`方法中比较重要的逻辑就是创建`PerField`对象和分词建立倒排索引，下面分别来看。

##### 2.1 创建`PerField`对象

创建`PerField`对象，是在`getOrAddField`方法中实现的。`getOrAddField`方法代码如下。

```java 
private DefaultIndexingChain.PerField getOrAddField(String name, IndexableFieldType fieldType, boolean invert) {
    
    //方法中比较重要的逻辑就是new一个PerField对象。
    fp = new DefaultIndexingChain.PerField(fi, invert);
    
    //将PerField对象存放在fieldHash数组中
    this.fieldHash[hashPos] = fp;
	
    //返回给上层调用者一个PerField对象
    return fp;
}
```

在`new PerField`时，会在PerField的构造方法中执行一些额外的逻辑，其中重要的就是将`fieldInfo`对象中的信息添加到`termsHash`中，并为每一个`Field`创建一个`TermsHashPerField`对象，该对象由`PerField`持有，并最终存在`DefaultIndexingChain`的成员变量`fieldHash`数组中。`PerField`中的关键代码如下：

```java
public PerField(FieldInfo fieldInfo, boolean invert) {
        this.setInvertState();
}

void setInvertState() {
    //创建一个TermsHashPerField对象，并由PerField对象持有
    this.termsHashPerField = DefaultIndexingChain.this.termsHash.addField(this.invertState, ,this.fieldInfo);
}
```

需要注意的是在执行`addFiled()`方法的时候，会创建一个`FreqProxTermsWriterPerField`对象，在创建此对象的时候，执行其父类构造器时，会引用`TermsHash`中 的三大缓冲池。引用缓冲池的目的是为了将每一个term信息存储在这些缓冲池中。代码如下：

```java
public FreqProxTermsWriterPerField(FieldInvertState invertState, TermsHash termsHash, FieldInfo fieldInfo, TermsHashPerField nextPerField) {
     //调用父类TermsHashPerField的构造方法
     super(fieldInfo.getIndexOptions().compareTo(IndexOptions.DOCS_AND_FREQS_AND_POSITIONS) >= 0 ? 2 : 1, invertState, termsHash, nextPerField, fieldInfo);
 }

public TermsHashPerField(int streamCount, FieldInvertState fieldState, TermsHash termsHash, TermsHashPerField nextPerField, FieldInfo fieldInfo) {
    //引用TermsHash中的缓冲池
    this.intPool = termsHash.intPool;
    this.bytePool = termsHash.bytePool;
    this.termBytePool = termsHash.termBytePool;
   
    //创建一个BytesRefHash对象，这个后面会用到
    TermsHashPerField.PostingsBytesStartArray byteStarts = new TermsHashPerField.PostingsBytesStartArray(this, this.bytesUsed);
    this.bytesHash = new BytesRefHash(this.termBytePool, 4, byteStarts);
}
```

##### 2.2 创建倒排索引阶段

建立倒排索引的主要逻辑是在`DefaultIndexingChain.PerField.invert()`方法中进行的。在`processField()`方法中会先创建`PerField fp`对象，然后执行`fp.invert()`方法。此方法的主要逻辑就是，先基于分词器对Filed的值进行分词处理，得到一个个的Term对象，在对erm建立一个倒排表，倒排表中存放的主要信息就是Term的长度、字节值、所在文档ID、词频、在文档中的偏移量等信息。

```java
public void invert(IndexableField field, boolean first) throws IOException, AbortingException {
     //基于分词器获取分词后的字节流，称之为token流
     TokenStream stream = this.tokenStream = field.tokenStream(DefaultIndexingChain.this.docState.analyzer, this.tokenStream);
	 
     //对每一个分词，都执行一遍相同的逻辑
     while(true){
         //得到分词term
         stream.reset();
         this.invertState.setAttributeSource(stream);

         //将token信息保存在termsHashPerField对象中
         //具体是保存在payloadAttribute和offsetAttribute中
         this.termsHashPerField.start(field, first);
		
         //具体的倒排索引建立工作，在这里执行
         this.termsHashPerField.add();
     }
}
```

具体的倒排索引工作是在`this.termsHashPerField.add()`中完成的，在这一步主要进行了如下操作：

1. 从BytesRefHash中获取termID，同一个字段中的不同term都有一个唯一termID
2. 根据termID，将term相关信息存放在PostingsArray中。具体的做法就是：
   1. 将term的词频记录在`PostingsArray.termFreqs[termID]`中
   2. 将term所在的文档信息记录在`PostingsArray.lastDocIDs[termID]`和`PostingsArray.lastDocIDs[termID]`中
   3. 将term的偏移量信息存放在`PostingsArray.lastPosition[termID]`和`PostingsArray.lastOffset[termID]`中
   4. 其中1和2中的信息是每处理完一个文档之后，将其写入到`TermsHash`中的bytePool缓冲池中。
   5. term的偏移量信息，每处理一个就会往`TermsHash`中的bytePool缓冲池中写入一次。
3. 完成`term -> PostingsArray`倒排索引的建立工作。

查看详细代码如下：

```java
void add() throws IOException {
    //  <<1>> 
    /**
    在BytesRefHash中为term分配一个唯一id
    并同时做了其他的工作：将term信息写入到缓冲区中、PostingsArray中
    **/
    int termID = this.bytesHash.add(this.termAtt.getBytesRef());
    
    //之前没有处理过这个term
    if (termID >= 0) {        
        //判断是否需要开辟一个新空间，初始情况下都是需要的
        if (this.numPostingInt + this.intPool.intUpto > 8192) {
            this.intPool.nextBuffer();
        }        
        /**
        这里的主要目的就是：
        1）往intPool缓冲池中写入信息，存指针信息，指针指向的是term信息在bytePool中的存储位置
        2）往PostingsArray.intStarts[termID]中存储指针信息，指针指向term信息在iniPool中的存储位置
        3）往PostingsArray.byteStarts[termID]中存储指针信息，指针指向term信息[term长度,term字节值]在
        	bytePool中的结尾位置
        **/
        
        // 2)
        this.postingsArray.intStarts[termID] = this.intUptoStart + this.intPool.intOffset;
		
        // 3）
        this.postingsArray.byteStarts[termID] = this.intUptos[this.intUptoStart];
        
        // 1)     <<2>>
        this.newTerm(termID);
    } else {
        //下面是之前已经处理过这个term，直接执行addTerm()方法即可
        
        //获取termID
        termID = -termID - 1;
        //根据termID从PostingsArray找到term的所属信息，从intStarts中获取term在initPool中的起始位置
        i = this.postingsArray.intStarts[termID];
        //从intPool中获取当前使用的buffer
        this.intUptos = this.intPool.buffers[i >> 13];
        this.intUptoStart = i & 8191;
        //执行addTerm操作     <<3>>
        this.addTerm(termID);
    }
}

```

从上面的这段代码可以看出，Lucene对term的处理是先去执行`TermsHashPerField`中的`add()`方法，在`add()`方法中主要进行如下处理：

1. <<1>> 执行`bytesHash.add（）`方法
   1. 判断之前是否处理过这个term，判断的依据是term值、term所属Field是否都相同，是则判定之前处理过，执行`addTerm()`逻辑；不是则判定是一个新的term，执行`newTerm()`逻辑。
   2. 并获取termID，之前没有处理过term的话，则生成一个唯一ID返回，之前处理过的话，将termID返回
   3. 如果是新来的term的话，在intPool开辟两个字节的空间，用于存储term信息；在bytePool中开辟一块内存空间，用于存储term信息
2. 设定`PostingsArray.initStarts`和`PostingsArray.byteStarts`中有关term的值
3. 执行`newTerm`<<2>>或者`addTerm`<<3>>方法

###### 2.2.1 `newTerm`

当term之前从未处理过的话，就执行`newTerm`逻辑，主要的工作就是在缓冲池`intPool`和`bytePool`中开辟一段内存空间，存储term信息。

由于term是第一次出现，因此term的词频信息和文档id信息并不会再`newTerm`阶段中写入到缓冲池`bytePool`中，原因是：

- 词频统计在同一个文档中的出现次数，由于该文档还未处理完，因此词频数还未统计出来。
- `PostingsArray.lastDocID`记录的是term最后一次出现的文档id，只有在开始处理下一个文档的该term的时候，才会把这个文档id写入到`bytePool`中。

```java
void newTerm(int termID) {
    //使用postings引用Filed层面的freqProxPostingsArray对象，每一个Field都拥有一个词对象。
    FreqProxTermsWriterPerField.FreqProxPostingsArray postings = this.freqProxPostingsArray;
    //记录当前term当前的文档id
    postings.lastDocIDs[termID] = this.docState.docID;
    
    //判断是否记录词频
    if (!this.hasFreq) {
        postings.lastDocCodes[termID] = this.docState.docID;
    } else {
        postings.lastDocCodes[termID] = this.docState.docID << 1;
        //由于term是第一次出现，因此词频为1
        postings.termFreqs[termID] = 1;
        //判断是否记录term在文档中的位置信息
        if (this.hasProx) {
            //这里将term的位置信息写入到bytePool中去  (注1)
            this.writeProx(termID, this.fieldState.position);
            //判断是否记录term的偏移量信息
            if (this.hasOffsets) {
                this.writeOffsets(termID, this.fieldState.offset);
            }
        } else {
            assert !this.hasOffsets;
        }
    }
	//将词频值1赋予fieldState.maxTermFrequency 
    this.fieldState.maxTermFrequency = Math.max(1, this.fieldState.maxTermFrequency);
}
```

在`newTerm`的时候，只会讲tem的位置信息写入到缓冲池中去。如注1所示。

```java
void writeProx(int termID, int proxCode) {
    //Lucene并不直接存储term的位置信息，而是存储的是位置的差值信息，再<<1操作的值
    this.writeVInt(1, proxCode << 1);
}
    
void writeVInt(int stream, int i) {
    this.writeByte(stream, (byte)i);
}
    
void writeByte(int stream, byte b) {
    //term的位置信息应该写入到bytePool中的位置，是由intPool中的有关该term的第二个元素决定的
    int upto = this.intUptos[this.intUptoStart + stream];
    //指向了bytePool缓冲池中当前使用的buffer
    byte[] bytes = this.bytePool.buffers[upto >> 15];
    //确定位置信息要写入的位置
    int offset = upto & 32767;
    //buffer不够的话，先扩容
    if (bytes[offset] != 0) {
        offset = this.bytePool.allocSlice(bytes, offset);
        bytes = this.bytePool.buffer;
        this.intUptos[this.intUptoStart + stream] = offset + this.bytePool.byteOffset;
    }
	
    //写入
    bytes[offset] = b;
    //intPool中有关该term的第二个元素值加1
    int var10002 = this.intUptos[this.intUptoStart + stream]++;
}
```

###### 2.2.2 `addTerm`

如果term之前都已经处理过的话，会执行`addTerm`逻辑。其主要思路就是判断当前term的docID与term的上一个docID是否一致，不一致的话，说明上一个文档已经处理完了，可以将有关上一个文档的该term的词频，docID写入到缓冲池中了。如果一致的话，说明属于同一个文档，且当前文档没有处理完，词频继续累加，docID继续暂存在lastDocIDs[termID]中。

```java
void addTerm(int termID) {
    //使用postings引用Filed层面的freqProxPostingsArray对象，每一个Field都拥有一个词对象。
    FreqProxTermsWriterPerField.FreqProxPostingsArray postings = this.freqProxPostingsArray;
    //是否记录词频
    if (!this.hasFreq) {
        if (this.docState.docID != postings.lastDocIDs[termID]) {
            assert this.docState.docID > postings.lastDocIDs[termID];

            this.writeVInt(0, postings.lastDocCodes[termID]);
            postings.lastDocCodes[termID] = this.docState.docID - postings.lastDocIDs[termID];
            postings.lastDocIDs[termID] = this.docState.docID;
            ++this.fieldState.uniqueTermCount;
        }
    } else if (this.docState.docID != postings.lastDocIDs[termID]) {
		//记录词频，且当前文档id与term的上一个docID不一致，说明上一个文档已经处理完了
        
        /**
        Lucene在倒排索引中并不直接存储文档的docID，而是存储的docCodes
        **/
        
        //如果文档中的term词频为1的话，词频信息和docID信息存在一个字节中
        if (1 == postings.termFreqs[termID]) {
            this.writeVInt(0, postings.lastDocCodes[termID] | 1);
        } else {
            //如果term的词频不为1的话，使用2个字节存储词频和docID
            this.writeVInt(0, postings.lastDocCodes[termID]);
            this.writeVInt(0, postings.termFreqs[termID]);
        }
		
        //因为又是一个新文档，因此词频重新计数
        postings.termFreqs[termID] = 1;
        this.fieldState.maxTermFrequency = Math.max(1, this.fieldState.maxTermFrequency);
        //docCodes大致可以理解为记录的是docID与上一个docID的差值
        postings.lastDocCodes[termID] = this.docState.docID - postings.lastDocIDs[termID] << 1;
        postings.lastDocIDs[termID] = this.docState.docID;
        if (this.hasProx) {
            //继续写入term的位置信息到缓冲区中
            this.writeProx(termID, this.fieldState.position);
            if (this.hasOffsets) {
                postings.lastOffsets[termID] = 0;
                this.writeOffsets(termID, this.fieldState.offset);
            }
        } else {
            assert !this.hasOffsets;
        }
        ++this.fieldState.uniqueTermCount;
    } else {
        //如果还是在处理同一个文档，那么执行此段逻辑
        this.fieldState.maxTermFrequency = Math.max(this.fieldState.maxTermFrequency, ++postings.termFreqs[termID]);
        if (this.hasProx) {
            this.writeProx(termID, this.fieldState.position - postings.lastPositions[termID]);
            if (this.hasOffsets) {
                this.writeOffsets(termID, this.fieldState.offset);
            }
        }
    }

}
```



###### 2.2.3 创建索引阶段总结

Lucene创建倒排索引是以Field为单位进行创建的，每个Field中的不同term都对应一个唯一termID，每个Field中都持有`PostingsArray`对象，该对象中维护了几个数组`byteStarts[]`、`intStarts[]`、`textStarts[]`。基于这几个数组，根据termID可以很快速的定位到`PerField.term`在缓冲池中存储信息的位置。

##### 2.3 图片描述

Lucene创建索引的内存细节可以用下图来进行说明。

![Lucene创建索引细节图](https://github.com/guluo2016/picture/raw/dev/img/Lucene%E5%88%9B%E5%BB%BA%E7%B4%A2%E5%BC%95%E7%BB%86%E8%8A%82%E5%9B%BE.jpg)

bytePool和termBytePool指向的是同一块内存区域。内存结构如下

```shell
# 有两部分组成，第一部分存储的是term信息、docID、词频，启动docID信息属于间接的docID
# 第二部分存储的term的位置信息，存储的是位置的差值
|termA_length|termA字节值|docID信息|词频|...|termA的位置信息|   
```

```shell
# 每个term占有两个字节
#termA_1指向bytePool/termBytePool第一部分的结尾的下一个字节
#termA_2指向bytePool/termBytePool第二部分的结尾的下一个字节
|termA_1|termA_2|		
```

```shell
# textStarts[termAID]指向bytePool/termBytePool第一部分的起始位置
# intStarts[termAID]指向intPool中termA_1位置
# byteStarts[termAID]指向bytePool/termBytePool中{termA字节值}结尾的下一个字节
```



#### 3 遗留问题

1 `bytePool`和`termBytePool`指向的是同一块内存区域，为什么需要两个？

2 根据`termAID`去`PostingsArray`中的各种数组中可以很快定位到：

​	1)	term长度、字面值，这个可以通过`textStarts[termAID]`获取

​	2)	term的docID信息和词频信息，可以通过结合`byteStarts[termAID]`和`intPool[termA_1]`的值获取

​	但是termA在文档中的位置信息并不能快速获取，Lucene是如何获取这部分的信息的？

#### 4 参考

1. [【Lucene3.0 初窥】索引创建(5)：索引数据池及内存数据细节](https://www.iteye.com/blog/hxraid-642737)
2. [番外篇：Lucene索引流程与倒排索引实现](https://mp.weixin.qq.com/s?__biz=MzI4Njk3NjU1OQ==&mid=2247484065&idx=1&sn=d9f058d48b8526117f91194b0643322b&chksm=ebd5fde1dca274f72495cde5b995842d7279eed80cfc7ef1bcb468b48766dfeb9bac2e164cd9&scene=21#wechat_redirect)

