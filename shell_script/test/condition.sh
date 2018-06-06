#!/bin/bash

#for语句
for name in "zhangsan" "lisi" "wangwu" "zhaoqi"
do
	echo $name
done

small=1
big=2

#while循环
while(( $small<=5 ))
do 
	echo $small
	small=`expr $small + 1`
done


name=tencent
#case语句
case $name in
	"baidu")
		echo "baidu"
	;;
	"tencent")
		echo "tencent"
	;;
esac

a=1
b=5

#until 语句
until [ ! $a -lt $b ]
do
	echo "${a}"
	let "a++"
done
