> 前提条件： 
>
> - 安装python3， python3-pip、krb5-devel、python3-devel、cyrus-sasl-gssapi、gcc
> - 升级pip3 ： `pip3 install --upgrade pip`
> - 安装python模块 : `setuptools_rust`、`cryptography`、`pyspnego`、`krb5`、`gssapi`、`requests`



去github上下载项目[requests-kerberos](https://github.com/requests/requests-kerberos) , 在其项目内部编写python代码，用于访问es集群。

在此之前需要获取到ES集群的对应用户的principal、keytab文件以及krb5.conf文件。

python代码如下：

```python
import os
import requests
from requests_kerberos import HTTPKerberosAuth

os.environ["KRB5_CLIENT_KTNAME"] = "{keytab文件的路径}"
os.environ["KRB5_CONFIG"] = "{krb5.conf文件的路径}"

Kerberos_auth = HTTPKerberosAuth(principal="{对应用户的principal}")
#get请求
get_response = requests.get('http://localhost:9200/_cat/indices', auth=Kerberos_auth)
print(get_response.text)

#put请求
put_data = '''
{
	"settings":{
		"number_of_shards": 1
	}
}
'''
header = {
	"Content-Type": "application/json"
}

put_response = requests.put(http://localhost:9200/_cat/indices', auth=Kerberos_auth, 
                           headers=header, data=put_data)
print(put_response.text)
```

