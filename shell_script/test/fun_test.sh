#!/bin/bash

function m1(){
	echo "第一个函数声明"
}

m1
echo $?

#传入参数
function m2(){
	name=$1
	echo $name
}

m2 "lupeng"

#返回参数
function m3(){
	return 56
}

m3
echo $?

#超过10个参数
function m4(){
	echo $9
	echo ${10}
}

array=(a b c d e f g h i j k o p q)
m4 ${array[@]}

