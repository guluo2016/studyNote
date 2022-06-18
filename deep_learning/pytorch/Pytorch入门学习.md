### 1 Pytorch安装

#### 1.1 前提条件

pytorch要求的python版本至少是python3.6，如果使用pip安装的话，需要使用python3-pip,因此需要在本机上安装:

```shell
python3.6
python3-pip
```

修改pip使用的源，改为国内源,，这里使用豆瓣源：

```properties
[global]
timeout = 60
index-url = https://pypi.doubanio.com/simple
```

#### 1.2 开始安装

根据官网，可以使用如下方式安装pytorch,这里选择了不带GPU的版本，如果机器有GPU的话，可以选择带GPU的版本。

![img](./images/pytorch官网安装方法.png)

由于使用官网方式安装，需要从国外下载软件版本，比较慢，而且总是会失败；使用国内源进行安装的时候（如豆瓣源，清华源），由于是安装不带GPU版本，因此往往会报如下错误：

```shell
WARNING: Running pip install with root privileges is generally not a good idea. Try `pip install --user` instead.
Collecting torch==1.7.1+cpu
  Could not find a version that satisfies the requirement torch==1.7.1+cpu (from versions: 0.1.2, 0.1.2.post1, 0.1.2.post2, 0.3.1, 0.4.0, 0.4.1, 1.0.0, 1.0.1, 1.0.1.post2, 1.1.0, 1.2.0, 1.3.0, 1.3.1, 1.4.0, 1.5.0, 1.5.1, 1.6.0, 1.7.0, 1.7.1)
No matching distribution found for torch==1.7.1+cpu
```

为了解决该错误，可以选择离线安装办法

1. 去官网，通过浏览器下载指定版本

   官方网址为：`https://download.pytorch.org/whl/torch_stable.html`,去该网址上选择指定版本安装包。如图所示。

   ![image](./images/pytorch-1.7.1+cpu.png)

   `torchvision==0.8.2+cpu`安装包的下载方式也是如此.

2. 在本机通过pip进行离线安装

   ```shell
   pip install ./torch-1.7.1+cpu-cp36-cp36m-linux_x86_64.whl   ./torchvision-0.8.2+cpu-cp36-cp36m-linux_x86_64.whl
   ```

### 2 验证是否安装成功

打开python3交互界面，输入如下命令

```shell
python3

>>>
>>> import torch
>>> x = torch.randn(3,3)
>>> print(x)
tensor([[-1.6084, -0.2238, -0.0331],
        [-0.1377,  0.8870, -1.3570],
        [ 0.0420,  2.1854, -0.5726]])
>>>
```

