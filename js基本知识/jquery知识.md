## JQuery

### 基本语法
`$(selector).action()`
其中selector可以是html中的相关元素或者属性（能够标识一个或若干个html元素），通过"#vlaue"获得id=value的元素，通过“元素名”获得对应一直元素
action表示的是操作


### $(document).ready()
一般jQuery函数都是在该函数内部定义的，其原因在于：防止在html文档还没有加载完毕，就执行jQuery函数，否则会造成后果：
- 因为html还没有加载完毕，所以可能获得一个找不到对应元素
- 对于图片而言，加载速度比较慢，过早执行可能无法获得图片大小

### jquery事件
hide()//隐藏
show()//显示
toggle() //如果对应元素已经隐藏，则显示，如果已经显示则隐藏

CallBack函数
通常是在action动作100%完成之后，开始执行CallBack函数