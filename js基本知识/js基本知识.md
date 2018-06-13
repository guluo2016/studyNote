## 普通对象与函数对象及区别

*js是面向对象语言，也是认为万物皆对象，对于字符串，boolean等可以看做不可变对象???存疑*

现在仅仅讨论不包含上面所说的对象，对象分为普通对象和函数对象
- 函数对象 通过new function声明的对象（包括function methodName(),new Function(参数)）属于函数对象
- 普通对象，除函数对象之外的对象属于普通对象

函数对象和普通对象的构造函数是不同的

- 函数对象的构造函数是Function()，是Function对象
- 普通对象的构造函数是Object()，是Object对象

例子：
```
//普通对象
var normal_obj = {
    name:"河南",
    age:5000
}
//函数对象
function fun_obj(){
    name:"中国"
}

//普通对象
var fun_instance = new fun_obj();

console.log(normal_obj.constructor)
console.log(fun_obj.constructor)
console.log(fun_instance.constructor)
```
查看结果：
```
//fun_obj的构造函数
Function(){[native code]}
//normal_obj的构造函数
Object(){[native code]}
//函数实例的构造函数
function fun_obj(){
    name:"中国"
}
```
## 原型对象
每一个函数对象都会包含一个prototype对象，这个prototype对象又有自己的相关属性，普通对象没有这个属性，看代码：
```
console.log("普通对象:"+normal_obj.prototype)
console.log("函数对象："+fun_obj.prototype)
console.log("普通对象："+fun_instance.prototype)
结果：
普通对象：undefined
函数对象：[object Object]  
普通对象：undefined
```
并且js规定每一个prototype默认带一个constructor属性，该属性指向函数对象自身
```
console.log(fun_obj.prototype.constructor)
//结果
function fun_obj(){
    name:"中国"
}
```

## _proto_属性
每一个对象都拥有一个_proto_属性，用于指向创建该对象的构造函数的prototype对象
```
//fun_obj对象由Function构造函数创建，因此该对象的_proto_属性指向Function函数对象的prototype对象，即Function对象的实例
一大串...
//fun_instance对象是由fun_obj创建的，因此
fun_instance._proto_ = fun_obj.prototype
//normal
normal._proto_ = Object.prototype
```

## 原型链
js中实际上没有继承的概念，但是每个对象都有一个_proro_属性，通过该属性，可以找到创建该对象的函数对象的原型对象，通常最终都是指向Object.prototype._proto_  null，从而形成了基于原型的原型链，这实际上就是js的集成体系，他们的共同父类是null


## 原型的作用
使用原型的好处是，基于该函数对象的实例所拥有的属性仅仅是一个引用，而并非属性全部，在运行的时候可以节约大量内存
```
```