elasticsearch是用Java写的，因此在安装es之前，必须首先部署Java环境

下载es安装包，我这里下载的是elasticsearch 5.5.2版本

**1 解压**

```
tar -zxvf elasticsearch-5.5.2.tar.gz -C /opt
```



**2 启动**

切换到{elasticsearch_home}/bin目录下，启动es：`./elasticsearch`，即可启动es。

**3 遇到的问题及解决办法**

1 `can not run eleasticsearch as root`  
这事因为es默认情况下是不允许以超级管理用户启动es，解决办法如下：  
```
#添加一个用户
adduser es
#初始化,期间需要设定新用户es的密码
passwd es
#切换到普通用户es
su es
#在es用户下启动elasticsearch
./elasticsearch
```

2 部分文件没有权限去访问  
因为启动es是以普通用户启动的，因此es目录下的文件必须设定权限，以便于普通用户es能够访问

3 `CONFIG_SECCOMP not compiled into kernel, CONFIG_SECCOMP and CONFIG_SECCOMP_FILTER are needed`  
修改配置文件elasticsearch.yml，添加如下两行：  
```
bootstrap.memory_lock: false
bootstrap.system_call_filter: false
```

4 `max file descriptors [4096] for elasticsearch process likely too low, increase to at least [65536]`  
这是由于用户可创建的最大文件数太少引起的，只需要修改文件/etc/security/limits.conf即可：  
```
*    soft    nofile   65536
*    hard    nofile   65536
```

5 `max number of threads [1024] for user [es] likely too low, increase to at least [4069]`  
这是由于用户可以创建的最大线程数太少引起的，只需要修改文件/etc/security/limits.d/90-nproc.conf即可：  
```
*    soft    nproc   4096
*    hard    nproc   4096
```

6 `max virtual memory areas vm.max_map_count [65530] likely too low, increase to at least [262144]`  
这是由于最大虚拟内存太小引起的，只需要修改/etc/sysctl.conf即可：  
```
vm.max_map_count=262144
```
修改完之后，需要执执行指令：`sysctl -p`
