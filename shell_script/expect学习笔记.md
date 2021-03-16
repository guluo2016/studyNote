有时候编写shell脚本时，可能需要进行交互，如执行ssh、scp等命令的时候，需要输入用户名、密码等信息。

这个时候可以借助于expect工具来实现。

编写expect脚本的方式和shell脚本类似，如下所示：

```shell
#!/usr/bin/expect   第一行声明使用expect解释器

#获取参数  获取第一个参数
set name [lindex $argv 0]

#条件语句,注意括号前后的空格
if { $name == "guluo" } {
	send_user "guluo"
}

#交互语句,意为遇到提示语句中含有password,且需要交互时，输入密码
expect {
	"password" {
		send "yes\r"
		exp_continue
	}
	eof {    #好像类似于case中的其他吧
		send_user "eof\r"
	}
}
```

