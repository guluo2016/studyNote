#!/bin/bash
name="lupeng"
age=23
echo $age $name

#获取参数
echo "一共有$#个参数"
echo 第二个参数$1

#运算
a=2
b=3
c=`expr $a + $b`
echo $c


if [ $a -eq $b ] 
then
	echo "dengyu"
else
	echo "不等于"
fi

array=(a b c d)

echo "for循环"
for loop in ${array[@]}
do
	echo ${loop}
done
